// Reference output from the JS dugout cam policy — WHEN the camera cuts to the
// manager during a match, and WHAT he does when it does.
//
// Two halves are worth pinning for different reasons.
//
// `shouldCutIn` is a chain of five refusals in a fixed ORDER, and the order is
// load-bearing: reduced motion beats the settings, the settings beat the
// full-time exemption, and the budget beats the gap. Getting the rules right
// and the order wrong gives a policy that agrees on most inputs and drops the
// one shot the whole feature exists for.
//
// `camMood` is arithmetic over a scoreline with a late-winner override on top
// of it, and it hands a DRAW straight to `moodForScore` — which is already
// pinned in `manager_mood_reference.json`, so what matters here is that the
// four context fields reach it unmangled.
//
// The rota's gaps are a roll into a per-mood band, so they go in as a roll and
// a millisecond count: an off-by-one in the band table reads as the right
// tempo for the wrong mood, which nobody would ever notice by playing.
//
//   node tool/dump_dugout_cam_reference.mjs > test/fixtures/dugout_cam_reference.json

const p = await import('../../merge-empire-fc/src/ui/components/dugoutCamPolicy.js');

const out = {
  gapMins: p.CAM_GAP_MINS,
  maxGoalCuts: p.CAM_MAX_GOAL_CUTS,
  triggers: p.CAM_TRIGGERS,
  inMs: p.CAM_IN_MS,
  holdMs: p.CAM_HOLD_MS,
  outMs: p.CAM_OUT_MS,
  lateWinnerMins: p.LATE_WINNER_MINS,
  rotaGapMs: p.CAM_ROTA_GAP_MS,
  rotaMemory: p.CAM_ROTA_MEMORY,
};

// ── The window, and whether it fits ─────────────────────────────────────────
out.camWindowMs = [0, 1500, 2800].map((gestureMs) => ({
  gestureMs, ms: p.camWindowMs(gestureMs),
}));
out.camFitsBeforeFullTime = [];
for (const gestureMs of [0, 1500, 2800]) {
  // Straddling the window either side, plus null — "no clock, so it fits".
  for (const msToFullTime of [null, 0, 1000, 2000, 2620, 3000, 4419, 4420, 5000, 9000]) {
    out.camFitsBeforeFullTime.push({
      gestureMs, msToFullTime, fits: p.camFitsBeforeFullTime(gestureMs, msToFullTime),
    });
  }
}

// ── Which switch governs which trigger ──────────────────────────────────────
out.camSettingKey = ['goal_for', 'goal_against', 'full_time', 'kickoff'].map(
  (trigger) => ({ trigger, key: p.camSettingKey(trigger) ?? null }),
);

// ── Should it cut in at all ─────────────────────────────────────────────────
// Every refusal, and every combination that reaches past it.
const SETTINGS = [
  ['both on', { cutawayOurTeam: true, cutawayOpponent: true }],
  ['ours off', { cutawayOurTeam: false, cutawayOpponent: true }],
  ['theirs off', { cutawayOurTeam: true, cutawayOpponent: false }],
  ['both off', { cutawayOurTeam: false, cutawayOpponent: false }],
  ['unset', {}],
];
out.shouldCutIn = [];
for (const trigger of ['goal_for', 'goal_against', 'full_time', 'kickoff', '']) {
  for (const [settingsLabel, settings] of SETTINGS) {
    for (const reducedFx of [false, true]) {
      // lastCutMin straddles CAM_GAP_MINS at minute 40; goalCuts straddles the
      // ceiling.
      for (const [minute, lastCutMin] of [[0, null], [40, null], [40, 27], [40, 28], [40, 29], [40, 40]]) {
        for (const goalCuts of [0, 2, 3]) {
          out.shouldCutIn.push({
            trigger, settingsLabel, reducedFx, minute, lastCutMin, goalCuts,
            cut: p.shouldCutIn({ trigger, minute, lastCutMin, goalCuts, settings, reducedFx }),
          });
        }
      }
    }
  }
}
// Nothing passed at all — the shape a caller with no arguments gets.
out.shouldCutInBare = p.shouldCutIn();

// ── Was it a late winner ────────────────────────────────────────────────────
out.isLateWinner = [];
for (const duration of [90, 95]) {
  for (const minute of [0, 44, 84, 85, 86, 90, 95]) {
    for (const [ourGoals, theirGoals] of [[1, 0], [2, 1], [2, 0], [1, 1], [0, 1], [4, 0], [3, 4]]) {
      out.isLateWinner.push({
        minute, duration, ourGoals, theirGoals,
        late: p.isLateWinner({ minute, duration, ourGoals, theirGoals }),
      });
    }
  }
}
out.isLateWinnerBare = p.isLateWinner();

// ── How he is feeling, at this moment of this match ─────────────────────────
out.camMood = [];
for (const trigger of ['goal_for', 'goal_against', 'full_time', 'kickoff']) {
  for (const [ourGoals, theirGoals] of [
    [0, 0], [1, 0], [2, 0], [3, 1], [1, 1], [2, 2], [0, 1], [1, 3], [0, 4],
  ]) {
    for (const lateWinner of [false, true]) {
      for (const trophiesEarned of [0, 1]) {
        // Draw context only reaches moodForDraw, and only at full time.
        for (const [ctxLabel, ctx] of [
          ['none', {}],
          ['away to a better side', { ratingGap: 10, isHome: false }],
          ['pegged back at home', { ratingGap: -10, isHome: true, led: true }],
          ['came back', { ratingGap: 0, isHome: true, trailed: true }],
          ['swung both ways', { ratingGap: 0, isHome: null, led: true, trailed: true }],
        ]) {
          out.camMood.push({
            trigger, ourGoals, theirGoals, lateWinner, trophiesEarned, ctxLabel,
            mood: p.camMood({
              trigger, ourGoals, theirGoals, lateWinner, trophiesEarned, ...ctx,
            }),
          });
        }
      }
    }
  }
}
out.camMoodBare = p.camMood();

// ── The gesture he plays into the lens ──────────────────────────────────────
// A thin wrapper over pickGesture, so this pins the wiring rather than the
// weights: that the fullTime flag reaches it and the mood is not remapped.
out.camGesture = [];
for (const mood of ['elated', 'pleased', 'neutral', 'glum', 'crushed']) {
  for (const fullTime of [false, true]) {
    for (let i = 0; i <= 10; i++) {
      const roll = i / 10;
      out.camGesture.push({
        mood, fullTime, roll,
        id: p.camGesture(mood, () => roll, null, fullTime)?.id ?? null,
      });
    }
  }
}

// ── The rota that keeps him reacting while the shot is up ───────────────────
out.camRotaBeat = [];
for (const mood of ['elated', 'pleased', 'neutral', 'glum', 'crushed', 'nonsense']) {
  for (const [excludeLabel, recent] of [
    ['nothing', []],
    ['one', ['armsfolded']],
    ['two', ['armsfolded', 'handsonhips']],
    // Longer than the memory: only the first CAM_ROTA_MEMORY count.
    ['three', ['armsfolded', 'handsonhips', 'handsonhead']],
    ['a bare string rather than a list', 'armsfolded'],
    ['nulls', [null, 'armsfolded', undefined]],
  ]) {
    for (const roll of [0, 0.25, 0.5, 0.99]) {
      const beat = p.camRotaBeat(mood, () => roll, null, recent);
      out.camRotaBeat.push({
        mood, excludeLabel, roll,
        id: beat.gesture?.id ?? null,
        gapMs: beat.gapMs,
      });
    }
  }
}

process.stdout.write(`${JSON.stringify(out, null, 2)}\n`);
