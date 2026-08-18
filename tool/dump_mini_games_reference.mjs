// Reference output from the JS mini-games data and engine.
//
// Nothing here draws a random number. What it pins instead is arithmetic that
// is easy to get subtly wrong and impossible to spot afterwards: seven
// difficulty curves interpolated across the divisions and rounded, a payout
// that runs the division base through two club-asset multipliers before
// rounding to whole coins, and the 30-second grid every cooldown is snapped up
// to — which means a cooldown does NOT end one cooldown after the tap, and a
// port that assumes it does is wrong by up to thirty seconds every time.
//
// The constants are dumped verbatim as well. They are balance numbers, and a
// retune on the JS side that never reaches the port is a game paying different
// money on the two platforms.
//
//   node tool/dump_mini_games_reference.mjs > test/fixtures/mini_games_reference.json

// Date.now is pinned so every stamp is a number both runtimes agree on. The
// readiness matrix moves it deliberately, which is the only way to ask "is this
// ready" of more than one instant.
let NOW = 0;
Date.now = () => NOW;

const mgData = await import('../../merge-empire-fc/src/data/miniGames.js');
const mge = await import('../../merge-empire-fc/src/engine/miniGamesEngine.js');

const clone = (v) => JSON.parse(JSON.stringify(v));

const DIVISIONS = [
  'sunday_league', 'amateur_cup', 'regional_league', 'national_league',
  'elite_league', 'continental', 'champions_cup',
];

const KINDS = ['penalty', 'training', 'keepy_uppys', 'through_ball', 'whack', 'pairs', 'boot_room'];

const makeState = ({
  division = 'sunday_league',
  trainingTier = 0,
  mediaTier = 0,
  stats = true,
  energyCurrent = 0,
  miniGames = undefined,
} = {}) => {
  const state = {
    resources: { fanCoins: 0, gems: 0, trophies: 0 },
    energy: { current: energyCurrent, lastRegenAt: 0 },
    shop: {},
    progression: { currentDivision: division },
    clubAssets: {
      TRAINING: { owned: trainingTier > 0, tier: trainingTier, invested: 0, tapCount: 0 },
      MEDIA: { owned: mediaTier > 0, tier: mediaTier, invested: 0, tapCount: 0 },
    },
  };
  if (stats) state.stats = {};
  if (miniGames !== undefined) state.miniGames = miniGames;
  return state;
};

const out = {};

// ── The constants ───────────────────────────────────────────────────────────
out.constants = {
  penalty: mgData.PENALTY,
  training: mgData.TRAINING,
  throughBall: mgData.THROUGH_BALL,
  keepyUppys: mgData.KEEPY_UPPYS,
  pairs: mgData.PAIRS,
  whack: mgData.WHACK,
  bootRoom: mgData.BOOT_ROOM,
};
out.skipKinds = mge.SKIP_KINDS;

// ── The difficulty curves ───────────────────────────────────────────────────
// Out-of-range indices are included on purpose: both ends clamp, and a port
// that interpolates past them gives a Champions-Cup player an impossible game.
out.curves = {};
for (let divIdx = -1; divIdx <= 7; divIdx++) {
  out.curves[divIdx] = {
    keeperSmart: mgData.penaltyKeeperSmartChance(divIdx),
    training: mgData.trainingDifficulty(divIdx),
    throughBall: mgData.throughBallDifficulty(divIdx),
    pairs: mgData.pairsDifficulty(divIdx),
    whack: mgData.whackDifficulty(divIdx),
    whackMaxCatches: mgData.whackMaxCatches(divIdx),
    bootRoom: mgData.bootRoomDifficulty(divIdx),
  };
}

// ── The reward base ─────────────────────────────────────────────────────────
// The tapered mini-game curve, not the match revenue base — and an unknown
// division has to fall through to the ladder's first rung rather than to NaN.
out.rewardBase = [];
for (const division of [...DIVISIONS, 'not_a_division']) {
  for (const mediaTier of [0, 1, 3, 6]) {
    out.rewardBase.push({
      division, mediaTier,
      base: mge.miniGameRewardBase(makeState({ division, mediaTier })),
    });
  }
}

// ── Cooldowns ───────────────────────────────────────────────────────────────
const EFFECTIVE = {
  penalty: mge.effectivePenaltyCooldown,
  training: mge.effectiveTrainingCooldown,
  keepy_uppys: mge.effectiveKeepyUppysCooldown,
  through_ball: mge.effectiveThroughBallCooldown,
  whack: mge.effectiveWhackCooldown,
  pairs: mge.effectivePairsCooldown,
  boot_room: mge.effectiveBootRoomCooldown,
};

out.effectiveCooldowns = [];
for (const kind of KINDS) {
  for (const trainingTier of [0, 1, 3, 6]) {
    out.effectiveCooldowns.push({
      kind, trainingTier,
      ms: EFFECTIVE[kind](makeState({ trainingTier })),
    });
  }
}

// The 30-second grid. `lastPlayed` values are deliberately off-grid so the snap
// is visible, and each is asked at several instants around its own ready time.
out.readiness = [];
for (const kind of KINDS) {
  for (const trainingTier of [0, 3]) {
    for (const lastPlayed of [0, 1, 17_000, 61_234, 999_999]) {
      const cooldown = EFFECTIVE[kind](makeState({ trainingTier }));
      const readyAt = Math.ceil((lastPlayed + cooldown) / 30_000) * 30_000;
      for (const offset of [-30_000, -1, 0, 1]) {
        NOW = readyAt + offset;
        const state = makeState({ trainingTier, miniGames: { [
          { penalty: 'penaltyLastPlayed', training: 'trainingLastPlayed',
            keepy_uppys: 'keepyUppysLastPlayed', through_ball: 'throughBallLastPlayed',
            whack: 'whackLastPlayed', pairs: 'pairsLastPlayed',
            boot_room: 'bootRoomLastPlayed' }[kind]
        ]: lastPlayed } });
        out.readiness.push({
          kind, trainingTier, lastPlayed, offset,
          ready: mge.miniGameReady(state, kind),
        });
      }
    }
  }
}
NOW = 0;

// msUntil, read at one fixed instant so the whole ladder is comparable.
out.msUntil = [];
NOW = 400_000;
for (const kind of KINDS) {
  const state = makeState({
    miniGames: {
      penaltyLastPlayed: 100_000, trainingLastPlayed: 100_000,
      keepyUppysLastPlayed: 100_000, throughBallLastPlayed: 100_000,
      whackLastPlayed: 100_000, pairsLastPlayed: 100_000,
      bootRoomLastPlayed: 100_000,
    },
  });
  const MS_UNTIL = {
    penalty: mge.msUntilPenalty, training: mge.msUntilTraining,
    keepy_uppys: mge.msUntilKeepyUppys, through_ball: mge.msUntilThroughBall,
    whack: mge.msUntilWhack, pairs: mge.msUntilPairs,
    boot_room: mge.msUntilBootRoom,
  };
  out.msUntil.push({ kind, ms: MS_UNTIL[kind](state) });
}
NOW = 0;

// An unknown kind is not something the player is waiting on.
out.unknownKind = (() => {
  const state = makeState();
  mge.startMiniGame(state, 'not_a_game');
  mge.resetMiniGameCooldown(state, 'not_a_game');
  return { ready: mge.miniGameReady(state, 'not_a_game'), miniGames: clone(state.miniGames) };
})();

// ── The miniGames branch ────────────────────────────────────────────────────
// Key order matters: it is the order the save writes them in.
out.ensureBranch = {
  fromNothing: (() => {
    const state = makeState();
    NOW = 5_000;
    mge.startMiniGame(state, 'penalty');
    NOW = 0;
    return { keys: Object.keys(state.miniGames), values: clone(state.miniGames) };
  })(),
  fromSchemaPair: (() => {
    const state = makeState({ miniGames: { penaltyLastPlayed: 7, trainingLastPlayed: 9 } });
    mge.startMiniGame(state, 'boot_room');
    return { keys: Object.keys(state.miniGames), values: clone(state.miniGames) };
  })(),
};

out.startAndReset = (() => {
  const state = makeState();
  NOW = 1_234_567;
  for (const kind of KINDS) mge.startMiniGame(state, kind);
  const started = clone(state.miniGames);
  for (const kind of KINDS) mge.resetMiniGameCooldown(state, kind);
  NOW = 0;
  return { started, reset: clone(state.miniGames) };
})();

// ── The skip button ─────────────────────────────────────────────────────────
out.allOnCooldown = [];
for (const trainingTier of [0, 1, 4, 6]) {
  for (const played of [false, true]) {
    NOW = 1_000_000;
    const state = makeState({ trainingTier });
    if (played) for (const kind of KINDS) mge.startMiniGame(state, kind);
    out.allOnCooldown.push({
      trainingTier, played,
      unlocked: (await import('../../merge-empire-fc/src/data/clubAssets.js')).getUnlockedMinigames(state),
      all: mge.allMiniGamesOnCooldown(state),
      prefetch: mge.shouldPrefetchSkipAd(state),
    });
  }
}
NOW = 0;

out.skipLedger = (() => {
  const today = 'Tue Aug 18 2026';
  const yesterday = 'Mon Aug 17 2026';
  const state = makeState();
  const steps = [];
  const snap = (label) => steps.push({
    label,
    used: mge.skipAdsUsedToday(state, today),
    left: mge.skipAdsLeftToday(state, today),
    shop: clone(state.shop),
  });
  snap('fresh');
  mge.recordSkipAd(state, today);
  snap('one');
  mge.recordSkipAd(state, today);
  mge.recordSkipAd(state, today);
  snap('capped');
  mge.recordSkipAd(state, today);
  snap('past the cap');
  // A stale ledger from another day is not counted, and the next spend resets it.
  state.shop.skipAdDay = yesterday;
  state.shop.skipAdCount = 3;
  snap('yesterday');
  mge.recordSkipAd(state, today);
  snap('rolled over');
  return { today, steps, noShopBranch: (() => {
    const s = makeState();
    delete s.shop;
    mge.recordSkipAd(s, today);
    return clone(s.shop);
  })() };
})();

// ── Banking a session ───────────────────────────────────────────────────────
const banked = (label, division, mediaTier, fn, extra = {}) => {
  NOW = 9_000_000;
  const state = makeState({ division, mediaTier, ...extra });
  const returned = fn(state);
  NOW = 0;
  return {
    label, division, mediaTier, returned,
    coins: state.resources.fanCoins,
    stats: clone(state.stats ?? null),
    miniGames: clone(state.miniGames),
    energy: clone(state.energy),
  };
};

out.whack = [];
for (const [label, opts] of [
  ['clean', { catches: 12, fouls: 0, dogs: 2 }],
  ['fouled', { catches: 12, fouls: 1, dogs: 2 }],
  ['blank', { catches: 0, fouls: 0, dogs: 0 }],
  ['negative', { catches: -4, fouls: 0, dogs: -2 }],
  ['fractional', { catches: 7.9, fouls: 0, dogs: 1.9 }],
  ['default', {}],
]) {
  for (const division of ['sunday_league', 'champions_cup']) {
    out.whack.push(banked(label, division, 0, (s) => mge.recordWhackResult(s, opts)));
  }
}
out.whack.push(banked('media6', 'elite_league', 6, (s) => mge.recordWhackResult(s, { catches: 20, dogs: 3 })));

out.bootRoom = [];
for (const [label, opts] of [
  ['hitTarget', { tilesCleared: 90, target: 88, bestCascade: 7 }],
  ['missedTarget', { tilesCleared: 40, target: 88, bestCascade: 3 }],
  ['noTarget', { tilesCleared: 40, target: 0, bestCascade: 0 }],
  ['default', {}],
]) {
  for (const division of ['sunday_league', 'champions_cup']) {
    out.bootRoom.push(banked(label, division, 0, (s) => mge.recordBootRoomResult(s, opts)));
  }
}

out.pairs = [];
for (const [label, opts] of [
  ['cleared', { pairsMatched: 6, totalPairs: 6, cleared: true }],
  ['partial', { pairsMatched: 3, totalPairs: 6, cleared: false }],
  ['overMatched', { pairsMatched: 9, totalPairs: 6, cleared: false }],
  ['default', {}],
]) {
  for (const division of ['sunday_league', 'champions_cup']) {
    out.pairs.push(banked(label, division, 0, (s) => mge.recordPairsResult(s, opts)));
  }
}

out.keepyUppys = [];
for (const [label, opts] of [
  ['long', { taps: 47 }],
  ['fractional', { taps: 12.7 }],
  ['negative', { taps: -3 }],
  ['default', {}],
]) {
  for (const division of ['sunday_league', 'champions_cup']) {
    out.keepyUppys.push(banked(label, division, 0, (s) => mge.recordKeepyUppysResult(s, opts)));
  }
}

out.throughBall = [];
for (const [label, opts] of [
  ['perfect', { roundsPassed: 5 }],
  ['partial', { roundsPassed: 2 }],
  ['overRun', { roundsPassed: 9 }],
  ['default', {}],
]) {
  for (const division of ['sunday_league', 'champions_cup']) {
    out.throughBall.push(banked(label, division, 0, (s) => mge.recordThroughBallResult(s, opts)));
  }
}

out.penalty = [];
for (const [label, opts] of [
  ['perfect', { scored: 5, total: 5 }],
  ['partial', { scored: 2, total: 5 }],
  ['overScored', { scored: 9, total: 5 }],
  ['shortRound', { scored: 3, total: 3 }],
  ['default', {}],
]) {
  for (const division of ['sunday_league', 'champions_cup']) {
    out.penalty.push(banked(label, division, 0, (s) => mge.recordPenaltyResult(s, opts)));
  }
}
// Alone in the family, penalty will not CREATE the stats branch.
out.penalty.push(banked('noStatsBranch', 'sunday_league', 0,
  (s) => mge.recordPenaltyResult(s, { scored: 5, total: 5 }), { stats: false }));

out.training = [];
for (const [label, opts, extra] of [
  ['perfect', { drillsHit: 8, drillTotal: 8 }, {}],
  ['partial', { drillsHit: 3, drillTotal: 8 }, {}],
  ['overHit', { drillsHit: 99, drillTotal: 8 }, {}],
  ['zeroTotal', { drillsHit: 4, drillTotal: 0 }, {}],
  ['default', {}, {}],
  // The grant is zero, so the only thing the energy line does is clamp a tank
  // that the Energy Director upgrade let past ten back down to ten.
  ['upgradedTank', { drillsHit: 4, drillTotal: 4 }, { energyCurrent: 15 }],
  ['noStatsBranch', { drillsHit: 4, drillTotal: 4 }, { stats: false }],
]) {
  for (const division of ['sunday_league', 'champions_cup']) {
    out.training.push(banked(label, division, 0,
      (s) => mge.recordTrainingComplete(s, opts), extra));
  }
}

// Stats accumulate across sessions rather than being overwritten, and the
// best-of counters only move upward.
out.repeated = (() => {
  NOW = 9_000_000;
  const state = makeState({ division: 'regional_league' });
  mge.recordWhackResult(state, { catches: 10, fouls: 0, dogs: 1 });
  mge.recordWhackResult(state, { catches: 4, fouls: 2, dogs: 0 });
  mge.recordKeepyUppysResult(state, { taps: 30 });
  mge.recordKeepyUppysResult(state, { taps: 12 });
  mge.recordBootRoomResult(state, { tilesCleared: 90, target: 88, bestCascade: 9 });
  mge.recordBootRoomResult(state, { tilesCleared: 20, target: 88, bestCascade: 2 });
  mge.recordPenaltyResult(state, { scored: 5, total: 5 });
  mge.recordPenaltyResult(state, { scored: 1, total: 5 });
  NOW = 0;
  return { coins: state.resources.fanCoins, stats: clone(state.stats) };
})();

process.stdout.write(JSON.stringify(out));
