// The stray ball's physics, dumped frame by frame from the JS.
//
//   node tool/dump_pitch_ball_reference.mjs > test/fixtures/pitch_ball.json
//
// `PitchBallSim` is UI, but the part worth pinning is pure integration and a
// state machine, and both of the bugs its own test guards against were
// invisible in review: they present as "the ball just sits there sometimes".
// So the same trick its test uses — a fake DOM, a fake clock, and the rAF chain
// driven by hand.
//
// **The randomness is a LIST, and it goes in the fixture.** Every draw the sim
// takes is `Math.random()`, so the only way two runtimes can agree is for both
// to read the same numbers in the same order. That also makes the draw ORDER
// part of what is pinned, which matters more here than the formulae: an extra
// draw anywhere shifts every later number, and the port has been bitten by
// exactly that four times (see the fixture notes in docs/REMAINING.md).
//
// The scene is deliberately left UNLAID-OUT, so `_edgeX` falls back to its 230
// and `_computeExitX` to its `-(edgeX·45/55) - 120`. Both are then constants
// the Dart side can be handed, which keeps this a test of the PHYSICS rather
// than of two different ways of measuring a viewport — the port derives its
// frame edges exactly and the JS estimates one and measures the other.

const FRAME_MS = 1000 / 60;
const FRAMES = 2400; // forty seconds: several whole ball visits

// A plain LCG, so the sequence is reproducible and short enough to ship.
let seed = 20260820;
const lcg = () => {
  seed = (seed * 1103515245 + 12345) % 2147483648;
  return seed / 2147483648;
};

let reel = [];
let drawAt = 0;
Math.random = () => {
  const v = reel[drawAt] ?? 0;
  drawAt += 1;
  return v;
};

let now = 0;
let frames = [];
globalThis.requestAnimationFrame = (cb) => {
  frames.push(cb);
  return frames.length;
};
globalThis.cancelAnimationFrame = () => {};
globalThis.performance = { now: () => now };
globalThis.setInterval = () => 1;
globalThis.clearInterval = () => {};

const { PitchBallSim } = await import('../../merge-empire-fc/src/ui/components/PitchBallSim.js');

const style = () => ({ transform: '', opacity: '' });
const round = (v) => Number(v.toFixed(6));

/**
 * One run. TWO moods, because the play is a mood-weighted roll and a neutral
 * manager almost never lets one go past him — so `ignore`, the whole `past`
 * phase and the cue that fires as the ball draws level with his boot would
 * never be exercised. A crushed one leaves them and boots them into the stand.
 */
const runTrace = (mood) => {
  reel = Array.from({ length: 6000 }, lcg);
  drawAt = 0;
  now = 0;
  frames = [];
  const ball = {
    style: style(),
    // No scene: the sim takes its unlaid-out fallbacks, which are constants.
    closest: () => null,
    querySelector: () => ({ style: style() }),
    getBoundingClientRect: () => ({ left: 0, right: 0, width: 0 }),
  };
  const cues = [];
  const sim = new PitchBallSim(ball, { style: style() }, {
    getMood: () => mood,
    onEvent: (ev) => cues.push({ frame: Math.round(now / FRAME_MS), cue: ev }),
  });
  sim.start();
  const trace = [];
  for (let i = 0; i < FRAMES; i++) {
    now += FRAME_MS;
    const pending = frames;
    frames = [];
    for (const cb of pending) if (cb) cb(now);
    trace.push({
      phase: sim._phase,
      x: round(sim._x),
      y: round(sim._y),
      vx: round(sim._vx),
      vy: round(sim._vy),
      rot: round(sim._rot),
      grounded: sim._grounded,
      play: sim._play,
    });
  }
  return { mood, draws: reel, cues, trace };
};

const runs = [runTrace('neutral'), runTrace('crushed')];

process.stdout.write(
  JSON.stringify(
    {
      // What the sim was standing on. GROUND_SCROLL_PX_S / WALKER_SCALE with the
      // stylesheet unread, which is the constant pace the JS assumes throughout.
      playerSpeed: 84 / 1.35,
      // `_edgeX()` and `_computeExitX()` with no scene to measure.
      edgeX: 230,
      exitX: -((230 * 45) / 55) - 120,
      frameMs: FRAME_MS,
      runs,
    },
    null,
    0,
  ) + '\n',
);
