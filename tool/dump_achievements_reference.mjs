// Reference output from the JS achievement catalogue and engine.
//
// The catalogue is eighty-odd PREDICATES over the save. Most take one line to
// write and one line to get subtly wrong — `>=` for `>`, the wrong stat, a career
// total where a per-run one was meant — and none of it is visible until a player
// reports a trophy that will not unlock. So every predicate is fired against a
// battery of crafted states and the answers compared, rather than the definitions
// being eyeballed.
//
// For each achievement the script builds:
//   • the state the JS says should unlock it (from `unlockers` below), and
//   • a blank state, which must NOT unlock it,
// then asserts the whole set of ids that fire, so a predicate that is too LOOSE
// shows up as well as one that is too tight.
//
//   node tool/dump_achievements_reference.mjs > test/fixtures/achievements_reference.json

const FIXED_NOW = 1700000000000;
Date.now = () => FIXED_NOW;

const ach = await import('../../merge-empire-fc/src/data/achievements.js');
const ae = await import('../../merge-empire-fc/src/engine/achievementEngine.js');
const ca = await import('../../merge-empire-fc/src/data/clubAssets.js');

const clone = (v) => JSON.parse(JSON.stringify(v));

// A save with nothing achieved. Deliberately minimal: anything an achievement
// needs has to be added by its own case, or the case is not testing what it says.
const blankState = () => ({
  progression: { currentDivision: 'sunday_league', achievements: [], achievementIdsThisRun: [] },
  grid: { cells: [] },
  stats: {},
  resources: { fanCoins: 0 },
  clubAssets: {},
  settings: { hardMode: false },
  careerStats: {},
  prestige: { level: 0 },
});

const card = (over = {}) => ({ instanceId: 'c0', definitionId: 'player_t3_mid', seasonsPlayed: 0, ...over });

const allAssetsOwned = () => Object.fromEntries(
  Object.values(ca.CATEGORIES).map((c) => [c, { owned: true, tier: 1 }]),
);

// What it takes to unlock each achievement: a state patch, and an optional event.
// Keyed by id so a new achievement with no entry is reported rather than skipped.
const unlockers = {
  reach_amateur:      { state: { progression: { currentDivision: 'amateur_cup' } } },
  reach_regional:     { state: { progression: { currentDivision: 'regional_league' } } },
  reach_national:     { state: { progression: { currentDivision: 'national_league' } } },
  reach_elite:        { state: { progression: { currentDivision: 'elite_league' } } },
  reach_continental:  { state: { progression: { currentDivision: 'continental' } } },
  reach_champions:    { state: { progression: { currentDivision: 'champions_cup' } } },
  prestige_level_1:   { state: { prestige: { level: 1 } } },
  prestige_level_3:   { state: { prestige: { level: 3 } } },
  prestige_level_5:   { state: { prestige: { level: 5 } } },
  prestige_level_10:  { state: { prestige: { level: 10 } } },

  first_promotion:    { event: { type: 'season:ended', data: { outcome: 'promoted' } } },
  relegated_once:     { event: { type: 'season:ended', data: { outcome: 'relegated' } } },
  first_league_title: { state: { progression: { leagueTrophies: [{}] } } },
  five_league_titles: { state: { progression: { leagueTrophies: [{}, {}, {}, {}, {}] } } },
  play_5_seasons:     { state: { progression: { seasonCount: 5 } } },
  play_10_seasons:    { state: { progression: { seasonCount: 10 } } },
  play_20_seasons:    { state: { progression: { seasonCount: 20 } } },
  win_league_undefeated: { event: { type: 'season:ended', data: { position: 1, seasonLosses: 0 } } },

  first_cup_win:      { state: { careerStats: { cupWins: 1 } } },
  cup_treble:         { state: { careerStats: { cupWins: 3 } } },
  cup_dynasty:        { state: { careerStats: { cupWins: 10 } } },

  first_merge:        { event: { type: 'merge:happened' } },
  merge_50:           { state: { careerStats: { totalMerges: 50 } } },
  merge_200:          { state: { careerStats: { totalMerges: 200 } } },
  merge_500:          { state: { careerStats: { totalMerges: 500 } } },
  merge_to_silver:    { state: { stats: { highestTier: 3 } } },
  merge_to_gold:      { state: { stats: { highestTier: 5 } } },
  merge_to_superstar: { state: { stats: { highestTier: 6 } } },
  merge_to_legend:    { state: { stats: { highestTier: 7 } } },
  merge_to_world:     { state: { stats: { highestTier: 8 } } },

  first_win:          { event: { type: 'match:complete', data: { won: true } } },
  win_25_matches:     { state: { careerStats: { matchesWon: 25 } } },
  win_100_matches:    { state: { careerStats: { matchesWon: 100 } } },
  win_500_matches:    { state: { careerStats: { matchesWon: 500 } } },
  comeback_win:       { event: { type: 'match:complete', data: { won: true, wasBehindAtHalftime: true } } },
  tactician:          { event: { type: 'match:complete', data: { strategyChanged: true } } },
  mind_games:         { event: { type: 'match:complete', data: { won: true, strategyChanged: true } } },
  gaffers_call:       { event: { type: 'match:complete', data: { won: true, followedCoachSuggestion: true } } },
  iron_curtain:       { event: { type: 'match:complete', data: { won: true, theirGoals: 0, strategiesUsed: ['parkTheBus'] } } },

  hard_debut:         { state: { settings: { hardMode: true } } },
  hard_first_win:     { state: { settings: { hardMode: true } }, event: { type: 'match:complete', data: { won: true } } },
  hard_marathon:      { state: { grid: { cells: [card({ trait: { id: 'iron_lungs', level: 1 } })] } } },
  hard_title:         { state: { settings: { hardMode: true } }, event: { type: 'season:ended', data: { position: 1 } } },
  hard_champions:     { state: { settings: { hardMode: true } }, event: { type: 'season:ended', data: { position: 1, oldDivision: 'champions_cup' } } },
  hard_25_wins:       { state: { careerStats: { hardModeWins: 25 } } },
  hard_100_wins:      { state: { careerStats: { hardModeWins: 100 } } },

  use_veteran_7s:     { state: { grid: { cells: [card({ seasonsPlayed: 7 })] } } },
  use_veteran_10s:    { state: { grid: { cells: [card({ seasonsPlayed: 10 })] } } },
  full_squad_16:      { state: { grid: { cells: Array.from({ length: 16 }, (_, i) => card({ instanceId: `c${i}` })) } } },
  first_sponsor:      { state: { grid: { cells: [card({ sponsor: { multiplier: 1.5 } })] } } },
  three_sponsors:     { state: { grid: { cells: Array.from({ length: 3 }, (_, i) => card({ instanceId: `c${i}`, sponsor: { multiplier: 1.5 } })) } } },
  scout_25:           { state: { stats: { totalScouts: 25 } } },
  scout_100:          { state: { stats: { totalScouts: 100 } } },

  own_tier3_asset:    { state: { clubAssets: { TRAINING: { owned: true, tier: 3 } } } },
  own_tier6_asset:    { state: { clubAssets: { TRAINING: { owned: true, tier: 6 } } } },
  own_all_categories: { state: { clubAssets: allAssetsOwned() } },

  coins_10k:          { state: { stats: { maxCoinsReached: 10_000 } } },
  coins_100k:         { state: { stats: { maxCoinsReached: 100_000 } } },
  coins_1m:           { state: { stats: { maxCoinsReached: 1_000_000 } } },
  coins_1b:           { state: { stats: { maxCoinsReached: 1_000_000_000 } } },

  first_transfer_accept:  { state: { stats: { transfersAccepted: 1 } } },
  five_transfer_accept:   { state: { stats: { transfersAccepted: 5 } } },
  first_transfer_decline: { state: { stats: { transfersDeclined: 1 } } },
  first_sponsor_decline:  { state: { stats: { sponsorsDeclined: 1 } } },
  grudge_revenge:     { event: { type: 'match:complete', data: { won: true, grudgeBoost: 5 } } },
  sell_tier5_player:  { event: { type: 'player:sold', data: { definitionId: 'player_t5_fwd' } } },

  penalty_perfect:    { state: { stats: { perfectPenalties: 1 } } },
  penalty_ten_rounds: { state: { stats: { penaltyRounds: 10 } } },
  training_perfect:   { state: { stats: { perfectTrainings: 1 } } },
  training_streak_10: { state: { dailyReward: { longestStreak: 10 } } },
  training_streak_30: { state: { dailyReward: { longestStreak: 30 } } },
  through_ball_perfect: { state: { stats: { perfectThroughBalls: 1 } } },
  whack_clean:        { state: { stats: { whackCleanRounds: 1 } } },
  whack_dogs_10:      { state: { stats: { whackDogs: 10 } } },
  boot_room_cascade:  { state: { stats: { bootRoomBestCascade: 4 } } },

  wc_win:             { state: { events: { progress: { wc2026: { firstWin: { playerNation: 'BRA' } } } } } },

  reset_first:          { state: { stats: { resetCount: 1 } } },
  reset_with_legendary: { state: { stats: { everHadLegendaryAtReset: true } } },
  reset_veteran:        { state: { stats: { maxSeasonsAtReset: 10 } } },
  reset_top_division:   { state: { stats: { everResetFromTopDivision: true } } },
  reset_after_prestige: { state: { stats: { maxPrestigeLevelAtReset: 1 } } },
};

const deepMerge = (base, patch) => {
  for (const [k, v] of Object.entries(patch ?? {})) {
    if (v && typeof v === 'object' && !Array.isArray(v)
        && base[k] && typeof base[k] === 'object' && !Array.isArray(base[k])) {
      deepMerge(base[k], v);
    } else {
      base[k] = clone(v);
    }
  }
  return base;
};

const out = { fixedNow: FIXED_NOW };

// ── the catalogue's shape ─────────────────────────────────────────────────
// The icons are the one thing NOT compared verbatim: four of them are raw HTML/SVG
// strings in the JS, which a Flutter data file has no business carrying. Their
// KIND is recorded instead, so the port can name a drawn icon and still be pinned.
const iconKind = (icon) => (icon?.startsWith?.('<span') ? (icon.includes('wcg') ? 'wcTrophy' : 'coin') : 'emoji');

out.catalogue = ach.ACHIEVEMENTS.map((a) => ({
  id: a.id,
  title: a.title,
  description: a.description,
  category: a.category,
  iconKind: iconKind(a.icon),
  icon: iconKind(a.icon) === 'emoji' ? a.icon : null,
  hasProgress: typeof a.progress === 'function',
  hasProgressText: typeof a.progressText === 'function',
  availability: a.availability ?? null,
  availabilityKey: a.availabilityKey ?? null,
}));
out.categories = ach.ACHIEVEMENT_CATEGORIES;
out.categoryLabels = ach.CATEGORY_LABELS;
out.assetCategoryCount = Object.values(ca.CATEGORIES).length;
out.getByIdKnown = ach.getAchievementDef('reach_amateur')?.id ?? null;
out.getByIdUnknown = ach.getAchievementDef('nope');

// Anything in the catalogue with no unlocker above — a new achievement nobody
// has written a case for, which the Dart side reports rather than skipping.
out.missingUnlockers = ach.ACHIEVEMENTS.map((a) => a.id).filter((id) => !unlockers[id]);

// ── every predicate, fired ────────────────────────────────────────────────
// For each achievement: the state that should unlock it, and a blank one that
// should not. Recording the WHOLE set that fires catches a predicate that is too
// loose as well as one that is too tight.
out.predicates = [];
for (const def of ach.ACHIEVEMENTS) {
  const u = unlockers[def.id];
  if (!u) continue;
  const state = deepMerge(blankState(), u.state ?? {});
  const event = u.event ?? { type: 'boot' };
  const unlocked = ae.checkAchievements(state, event).map((a) => a.id).sort();

  const blank = blankState();
  const onBlank = ae.checkAchievements(blank, { type: 'boot' }).map((a) => a.id).sort();

  out.predicates.push({
    id: def.id,
    event,
    unlocked,
    firesForItself: unlocked.includes(def.id),
    // The reward each id paid, so the table is pinned alongside the predicates.
    rewards: Object.fromEntries(
      state.progression.achievements.map((a) => [a.id, a.coinsRewarded]),
    ),
    blankUnlocks: onBlank,
  });
}

// ── near misses ───────────────────────────────────────────────────────────
//
// An event that ALMOST matches. Without these a predicate that drops one of its
// conditions still passes every positive case — the clean sheet in iron_curtain,
// the half-time deficit in comeback_win, and so on.
out.nearMisses = [];
for (const [label, patch, event] of [
  ['comeback without being behind', {}, { type: 'match:complete', data: { won: true } }],
  ['comeback but lost', {}, { type: 'match:complete', data: { won: false, wasBehindAtHalftime: true } }],
  ['iron curtain but conceded', {}, { type: 'match:complete', data: { won: true, theirGoals: 1, strategiesUsed: ['parkTheBus'] } }],
  ['iron curtain on another tactic', {}, { type: 'match:complete', data: { won: true, theirGoals: 0, strategiesUsed: ['balanced'] } }],
  ['iron curtain but lost', {}, { type: 'match:complete', data: { won: false, theirGoals: 0, strategiesUsed: ['parkTheBus'] } }],
  ['mind games but lost', {}, { type: 'match:complete', data: { won: false, strategyChanged: true } }],
  ['gaffers call but lost', {}, { type: 'match:complete', data: { won: false, followedCoachSuggestion: true } }],
  ['grudge win with no grudge', {}, { type: 'match:complete', data: { won: true, grudgeBoost: 0 } }],
  ['undefeated with a loss', {}, { type: 'season:ended', data: { position: 1, seasonLosses: 1 } }],
  ['undefeated but second', {}, { type: 'season:ended', data: { position: 2, seasonLosses: 0 } }],
  ['undefeated with losses unreported', {}, { type: 'season:ended', data: { position: 1 } }],
  ['season ended, no outcome', {}, { type: 'season:ended', data: {} }],
  ['hard win in casual mode', { settings: { hardMode: false } }, { type: 'match:complete', data: { won: true } }],
  ['hard title in casual mode', { settings: { hardMode: false } }, { type: 'season:ended', data: { position: 1 } }],
  ['hard champions from another division', { settings: { hardMode: true } }, { type: 'season:ended', data: { position: 1, oldDivision: 'continental' } }],
  ['sold a tier 4 player', {}, { type: 'player:sold', data: { definitionId: 'player_t4_fwd' } }],
  ['sold, no definition', {}, { type: 'player:sold', data: {} }],
  // A non-string definition id. The JS shrugs it off; a typed port has to as
  // well, which is what the try/catch around each predicate is for.
  ['sold, definition id is a number', {}, { type: 'player:sold', data: { definitionId: 42 } }],
  ['a tier below silver', { stats: { highestTier: 2 } }, { type: 'boot' }],
  ['one short of five titles', { progression: { leagueTrophies: [{}, {}, {}, {}] } }, { type: 'boot' }],
  ['one coin short of 10k', { stats: { maxCoinsReached: 9_999 } }, { type: 'boot' }],
  ['an asset owned at a lower tier', { clubAssets: { TRAINING: { owned: true, tier: 2 } } }, { type: 'boot' }],
  ['an asset at tier but NOT owned', { clubAssets: { TRAINING: { owned: false, tier: 9 } } }, { type: 'boot' }],
  ['all categories but one', {
    clubAssets: Object.fromEntries(Object.values(ca.CATEGORIES).slice(1).map((c) => [c, { owned: true, tier: 1 }])),
  }, { type: 'boot' }],
  ['a veteran one season short', { grid: { cells: [card({ seasonsPlayed: 6 })] } }, { type: 'boot' }],
  ['fifteen players', { grid: { cells: Array.from({ length: 15 }, (_, i) => card({ instanceId: `c${i}` })) } }, { type: 'boot' }],
  ['a different trait', { grid: { cells: [card({ trait: { id: 'tough', level: 1 } })] } }, { type: 'boot' }],
  ['an unknown division', { progression: { currentDivision: 'nonsense' } }, { type: 'boot' }],
]) {
  const state = deepMerge(blankState(), patch);
  out.nearMisses.push({
    label, event,
    unlocked: ae.checkAchievements(state, event).map((a) => a.id).sort(),
  });
}

// ── the engine's bookkeeping ──────────────────────────────────────────────

// A blank save unlocks nothing at all.
out.blankBoot = (() => {
  const state = blankState();
  const got = ae.checkAchievements(state, { type: 'boot' });
  return { unlocked: got.map((a) => a.id), stored: clone(state.progression.achievements) };
})();

// Running twice does not pay twice.
out.idempotent = (() => {
  const state = deepMerge(blankState(), { progression: { currentDivision: 'champions_cup' } });
  const first = ae.checkAchievements(state, { type: 'boot' }).map((a) => a.id).sort();
  const second = ae.checkAchievements(state, { type: 'boot' }).map((a) => a.id);
  return {
    first, second,
    stored: clone(state.progression.achievements),
    thisRun: clone(state.progression.achievementIdsThisRun),
  };
})();

// THE RE-UNLOCK PATH. The engine keeps a per-run list that is cleared on reset so
// achievements "become re-unlockable in new runs", and a branch that increments a
// count when one fires again. Both are recorded here against a save that has the
// record but an empty per-run list — which is exactly the post-reset shape.
out.afterReset = (() => {
  const state = deepMerge(blankState(), {
    progression: {
      currentDivision: 'amateur_cup',
      achievements: [{ id: 'reach_amateur', unlockedAt: 1, coinsRewarded: 200, count: 1 }],
      achievementIdsThisRun: [],
    },
  });
  const got = ae.checkAchievements(state, { type: 'boot' });
  return {
    unlocked: got.map((a) => ({ id: a.id, isReUnlock: a.isReUnlock, count: a.count })),
    stored: clone(state.progression.achievements),
  };
})();

// A wrecked bucket is repaired rather than thrown on, keeping the highest count.
out.dedupe = (() => {
  const state = deepMerge(blankState(), {
    progression: {
      achievements: [
        { id: 'dup', unlockedAt: 1, count: 1 },
        { id: 'dup', unlockedAt: 2, count: 4 },
        { id: 'dup', unlockedAt: 3, count: 2 },
        null,
        { noId: true },
      ],
    },
  });
  ae.checkAchievements(state, { type: 'boot' });
  return clone(state.progression.achievements);
})();

// A predicate that throws is treated as "not met" rather than taking the run down.
out.throwingCheck = (() => {
  const state = blankState();
  // grid.cells is not an array, so every predicate reading it blows up.
  state.grid = { cells: null };
  let threw = false;
  let got = [];
  try {
    got = ae.checkAchievements(state, { type: 'boot' }).map((a) => a.id);
  } catch { threw = true; }
  return { threw, unlocked: got };
})();

out.nullState = ae.checkAchievements(null, { type: 'boot' });

out.getUnlockedIds = (() => {
  const state = deepMerge(blankState(), {
    progression: { achievements: [{ id: 'a' }, { id: 'b' }] },
  });
  return [...ae.getUnlockedIds(state)].sort();
})();

// ── progress bars ─────────────────────────────────────────────────────────
// Shown on locked tiles, so a wrong target reads as a goal that never fills.
out.progress = [];
for (const def of ach.ACHIEVEMENTS) {
  if (typeof def.progress !== 'function') continue;
  const u = unlockers[def.id];
  const state = deepMerge(blankState(), u?.state ?? {});
  out.progress.push({
    id: def.id,
    onBlank: def.progress(blankState()),
    onUnlocking: def.progress(state),
    text: typeof def.progressText === 'function' ? def.progressText(state) : null,
  });
}

process.stdout.write(JSON.stringify(out));
