// Keepy Uppys' physics, dumped frame by frame from the JS.
//
//   node tool/dump_keepy_uppys_reference.mjs > test/fixtures/keepy_uppys.json
//
// Three stages of ball with three sets of constants, a wall bounce with
// damping, a ceiling that reflects, a floor that ends the session, a spin the
// balloon does not have, and a deflection whose sideways component is taken
// from WHERE on the ball the tap landed. None of that is checkable by reading
// it, and all of it is arithmetic — which is what a fixture is for.
//
// **The randomness is a LIST, and it goes in the fixture.** The only draw the
// physics takes is the opening `vx`, but the draw ORDER matters as much as the
// formula and the port has been bitten by a shifted stream four times already.
//
// The taps are a SCRIPT: a fixed frame number and a fixed point in the arena.
// Some are deliberate near-misses just outside the hit radius, so the fixture
// pins the radius too and not merely the bounce.
//
// The game is a DOM component, so the same trick the stray ball's dump uses —
// a fake document, a fake clock, and the rAF chain driven by hand.

const FRAME_MS = 1000 / 60;
const ARENA_W = 320;
const ARENA_H = 280;

let seed = 20260821;
const lcg = () => {
  seed = (seed * 1103515245 + 12345) % 2147483648;
  return seed / 2147483648;
};

const reel = Array.from({ length: 400 }, lcg);
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
globalThis.setTimeout = () => 1;
globalThis.clearTimeout = () => {};
globalThis.setInterval = () => 1;
globalThis.clearInterval = () => {};

// A fake element that swallows everything the component does to the page and
// remembers only the handlers, so a tap can be delivered.
class El {
  constructor(cls = '') {
    this.className = cls;
    this.style = new Proxy({ cssText: '' }, { get: (t, k) => t[k] ?? '', set: (t, k, v) => (t[k] = v, true) });
    this.dataset = {};
    this.children = [];
    this.handlers = {};
    this._cache = new Map();
    this.textContent = '';
    this.innerHTML = '';
  }
  appendChild(child) { this.children.push(child); return child; }
  removeChild() {}
  remove() {}
  animate() { return { cancel() {} }; }
  contains() { return false; }
  closest() { return null; }
  addEventListener(type, fn) { (this.handlers[type] ??= []).push(fn); }
  removeEventListener() {}
  // The same element back for the same selector, so the tap reaches the arena
  // the component actually bound to.
  querySelector(sel) {
    if (!this._cache.has(sel)) this._cache.set(sel, new El(sel));
    return this._cache.get(sel);
  }
  querySelectorAll() { return []; }
  getBoundingClientRect() { return { left: 0, top: 0, right: ARENA_W, bottom: ARENA_H, width: ARENA_W, height: ARENA_H }; }
}

const head = new El('head');
const body = new El('body');
globalThis.document = {
  head,
  body,
  createElement: (tag) => new El(tag),
  getElementById: () => null,
};
globalThis.window = { addEventListener() {}, removeEventListener() {} };

const { KeepyUppysGame } = await import('../../merge-empire-fc/src/ui/components/KeepyUppysGame.js');

// Nine places, not six. The Dart side compares to 1e-6, and at six the
// fixture's own rounding is already that big — the comparison would be
// measuring the dump's formatting rather than the physics.
const round = (v) => Number(v.toFixed(9));

// The taps are taken RELATIVE TO THE BALL, on a fixed cadence, with a cycling
// list of offsets. Absolute points cannot work: the ball moves, and a script
// that misses it every time pins nothing.
//
// The offsets are the point of the exercise. The sideways kick is
// `clamp(-4, (ball.x - tapX) * 0.12, 4)`, so tapping left of centre and right
// of centre must send it opposite ways — and the two long offsets are beyond
// even the balloon's 44px reach, so the fixture pins the hit RADIUS as well as
// the bounce. As the ball hardens that radius tightens to 34 and then 26, and
// offsets that landed on the balloon start missing.
const TAP_EVERY = 9;
const TAP_OFFSETS = [
  [0, 0], [-14, 6], [22, -4], [60, 0], [8, 12],
  [-26, -8], [0, -55], [16, 8], [-9, -3], [30, 10],
];

const game = new KeepyUppysGame({ progression: { currentDivision: 'sunday_league' } });
game._arenaEl = new El('arena');
game._ballEl = new El('ball');
game._tapsLabelEl = new El('taps');
game._stageLabelEl = new El('stage');
game._missOverlay = new El('miss');
game._hintEl = new El('hint');
game._collectRow = new El('collect');
game._sheet = new El('sheet');
game._arenaW = ARENA_W;
game._arenaH = ARENA_H;
game._initBall();
game._bindInput();
game._lastTime = 0;
game._raf = requestAnimationFrame((ts) => game._loop(ts));

const trace = [];
const taps = [];
let tapIndex = 0;

for (let frame = 0; frame < 4000 && !game._done; frame++) {
  if (frame > 0 && frame % TAP_EVERY === 0) {
    const [dx, dy] = TAP_OFFSETS[tapIndex % TAP_OFFSETS.length];
    tapIndex += 1;
    const at = [round(game._ball.x + dx), round(game._ball.y + dy)];
    const before = game._taps;
    for (const fn of game._arenaEl.handlers.mousedown ?? []) {
      fn({ clientX: at[0], clientY: at[1] });
    }
    taps.push({
      frame,
      offset: [dx, dy],
      at,
      landed: game._taps > before,
      vx: round(game._ball.vx),
      vy: round(game._ball.vy),
    });
  }
  // The `dt` the loop actually used, recorded rather than assumed. The fake
  // clock accumulates `1000/60` and that is not exactly `1000/60` in binary,
  // so the JS's dt sits a hair off 1 — and the spin, which integrates it over
  // five hundred frames, amplifies the difference into something a 1e-6
  // comparison can see. Handing Dart the same dt pins the frame-rate scaling
  // as well, which is the point of having one.
  const lastTime = game._lastTime;
  now += FRAME_MS;
  const dt = Math.min((now - lastTime) / (1000 / 60), 3);
  const pending = frames;
  frames = [];
  for (const cb of pending) if (cb) cb(now);
  trace.push({
    dt,
    x: round(game._ball.x),
    y: round(game._ball.y),
    vx: round(game._ball.vx),
    vy: round(game._ball.vy),
    angle: round(game._angle),
    taps: game._taps,
  });
}

process.stdout.write(JSON.stringify({
  note: 'Generated by tool/dump_keepy_uppys_reference.mjs — do not hand-edit.',
  arena: { w: ARENA_W, h: ARENA_H },
  frameMs: FRAME_MS,
  // NOT rounded. These are the numbers both runtimes read, and rounding them
  // put a difference into the opening drift that the next five hundred frames
  // then amplified.
  reel: reel.slice(0, 8),
  taps,
  tapsByStage: game._tapsByStage,
  weightedTaps: game._weightedTaps(),
  bonus: game._bonus,
  done: game._done,
  frames: trace,
}, null, 1) + '\n');
