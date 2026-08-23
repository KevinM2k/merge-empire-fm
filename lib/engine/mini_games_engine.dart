/// The mini-game cooldowns, payouts and stat counters, ported from
/// `../merge-empire-fc/src/engine/miniGamesEngine.js`.
///
/// The JS spells out `penaltyReady`, `msUntilPenalty`,
/// `effectivePenaltyCooldown` and their six identical siblings, all of which
/// differ only in which constant and which save key they read. Here those are
/// one table and four functions taking a kind, which is also how the callers
/// already work: `getUnlockedMinigames` hands back a list of kind strings and
/// the panel loops over it.
///
/// What is NOT collapsed is the `record*Result` family: every game banks a
/// different shape of session and writes a different set of counters, and the
/// counters are quest and achievement targets, so a wrong key is a quest that
/// can never be finished.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/engine/energy_engine.dart' show getEnergyMax;
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/mini_games.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

Map<String, dynamic> _branch(Map<String, dynamic> owner, String key) {
  final existing = _map(owner[key]);
  if (existing != null) return existing;
  final fresh = <String, dynamic>{};
  owner[key] = fresh;
  return fresh;
}

/// The mini-game kinds, in LADDER order — the order Training Ground unlocks
/// them, the order the panel renders them, and the order the skip clears them.
class MiniGameKind {
  const MiniGameKind._();

  static const String penalty = 'penalty';
  static const String training = 'training';
  static const String keepyUppys = 'keepy_uppys';
  static const String throughBall = 'through_ball';
  static const String whack = 'whack';
  static const String pairs = 'pairs';
  static const String bootRoom = 'boot_room';

  static const List<String> all = [
    penalty,
    training,
    keepyUppys,
    throughBall,
    whack,
    pairs,
    bootRoom,
  ];
}

/// Every kind one skip clears. The same list as the ladder — a skip that missed
/// a game would leave the player still waiting on it.
const List<String> skipKinds = MiniGameKind.all;

typedef _Game = ({int cooldownMs, String lastPlayedKey});

const Map<String, _Game> _games = {
  MiniGameKind.penalty: (
    cooldownMs: Penalty.cooldownMs,
    lastPlayedKey: 'penaltyLastPlayed',
  ),
  MiniGameKind.training: (
    cooldownMs: Training.cooldownMs,
    lastPlayedKey: 'trainingLastPlayed',
  ),
  MiniGameKind.keepyUppys: (
    cooldownMs: KeepyUppys.cooldownMs,
    lastPlayedKey: 'keepyUppysLastPlayed',
  ),
  MiniGameKind.throughBall: (
    cooldownMs: ThroughBall.cooldownMs,
    lastPlayedKey: 'throughBallLastPlayed',
  ),
  MiniGameKind.whack: (
    cooldownMs: Whack.cooldownMs,
    lastPlayedKey: 'whackLastPlayed',
  ),
  MiniGameKind.pairs: (
    cooldownMs: Pairs.cooldownMs,
    lastPlayedKey: 'pairsLastPlayed',
  ),
  MiniGameKind.bootRoom: (
    cooldownMs: BootRoom.cooldownMs,
    lastPlayedKey: 'bootRoomLastPlayed',
  ),
};

/// The `miniGames` branch, back-filled.
///
/// The key ORDER here is the order the save writes them in, so the two games
/// the schema knows about come first and the five added later follow — same as
/// the JS, whose back-fill runs after the branch is created.
Map<String, dynamic> _mg(Map<String, dynamic> state) {
  var mg = _map(state['miniGames']);
  if (mg == null) {
    mg = <String, dynamic>{
      'penaltyLastPlayed': 0,
      'trainingLastPlayed': 0,
      'throughBallLastPlayed': 0,
      'pairsLastPlayed': 0,
      'keepyUppysLastPlayed': 0,
    };
    state['miniGames'] = mg;
  }
  mg['throughBallLastPlayed'] ??= 0;
  mg['pairsLastPlayed'] ??= 0;
  mg['keepyUppysLastPlayed'] ??= 0;
  mg['whackLastPlayed'] ??= 0;
  mg['bootRoomLastPlayed'] ??= 0;
  return mg;
}

/// The mini-game coin scale for the player's division.
///
/// This is the TAPERED curve, not the match revenue base: mini-game drip is
/// meant to stay a trickle rather than drown out the match and IAP economies at
/// Continental and Champions Cup.
num _divBase(Map<String, dynamic>? state) {
  final divId = _map(state?['progression'])?['currentDivision'];
  return Minigame.baseByDiv['$divId'] ?? getDivision('$divId').matchRevenueBase;
}

/// The full effective base, for the launcher tiles' reward previews. The same
/// formula the payouts use, so a preview cannot promise what a session will not
/// pay.
double miniGameRewardBase(Map<String, dynamic>? state) =>
    _divBase(state) * getMiniGameCoinMult(state);

/// Where the player's division sits in the ladder, for the difficulty curves.
int _divIdx(Map<String, dynamic>? state) {
  final id = _map(state?['progression'])?['currentDivision'] ?? divisions.first.id;
  final idx = divisions.indexWhere((d) => d.id == id);
  return idx < 0 ? 0 : idx;
}

/// The most a PERFECT session of [kind] can pay at this division, with the
/// club's own multipliers already in it — or null for a drill with no ceiling.
///
/// **The launcher never said what a drill was worth**, which is the one figure
/// a player deciding whether to spend three minutes on one actually wants.
/// Reported straight off the Training tab, and [miniGameRewardBase]'s own doc
/// says it exists "for the launcher tiles' reward previews" while nothing drew
/// one.
///
/// Every arm is the payout function's own arithmetic at its maximum, so a
/// preview cannot promise what a session will not pay — including the two
/// bonuses, because a perfect board earns both. **Keepy Uppys answers null**:
/// taps are unbounded, so there is no honest number to quote.
int? miniGameBestPayout(Map<String, dynamic>? state, String kind) {
  final base = miniGameRewardBase(state);
  final divIdx = _divIdx(state);
  return switch (kind) {
    MiniGameKind.penalty => roundCoins(
      base * Penalty.rewardPerGoalMult * Penalty.attempts,
    ),
    // Scales with the FRACTION hit rather than the count, so a perfect session
    // is the whole multiplier however many drills the division spawns.
    MiniGameKind.training => roundCoins(base * Training.rewardBaseMult),
    MiniGameKind.throughBall => roundCoins(
      base * ThroughBall.rewardPerRoundMult * ThroughBall.rounds,
    ),
    MiniGameKind.whack => roundCoins(
      base * Whack.rewardPerCatchMult * whackMaxCatches(divIdx),
    ),
    MiniGameKind.pairs => roundCoins(
      roundCoins(base * Pairs.rewardPerPairMult * pairsDifficulty(divIdx).pairs) *
          Pairs.clearBonusMult,
    ),
    MiniGameKind.bootRoom => roundCoins(
      roundCoins(
            base * BootRoom.rewardPerTileMult * bootRoomDifficulty(divIdx).target,
          ) *
          BootRoom.targetBonusMult,
    ),
    _ => null,
  };
}

/// Cooldowns land on a shared 30-second grid — :00 and :30 of each minute —
/// rather than exactly one cooldown after the tap.
///
/// The ready time is rounded UP to the next boundary, so every game coming off
/// cooldown in the same window refreshes together on a clean marker instead of
/// at the arbitrary second-offset of whenever each was last played.
const int _alignMs = 30 * 1000;

int _readyAt(num lastPlayed, double cooldownMs) =>
    ((lastPlayed + cooldownMs) / _alignMs).ceil() * _alignMs;

/// One game's cooldown after the Training Ground discount. Zero for a kind that
/// does not exist, which reads as permanently ready.
double effectiveMiniGameCooldown(Map<String, dynamic> state, String kind) =>
    (_games[kind]?.cooldownMs ?? 0) * getMiniGameCooldownMult(state);

num _lastPlayed(Map<String, dynamic> state, String kind) {
  final key = _games[kind]?.lastPlayedKey;
  if (key == null) return 0;
  return _num(_mg(state)[key]) ?? 0;
}

/// Is one mini-game off cooldown?
///
/// An unknown kind reads as ready: a game that does not exist is not something
/// the player is waiting on.
bool miniGameReady(Map<String, dynamic> state, String kind) =>
    now() >=
    _readyAt(_lastPlayed(state, kind), effectiveMiniGameCooldown(state, kind));

/// How long until [kind] can be played again, never negative.
int msUntilMiniGame(Map<String, dynamic> state, String kind) => math.max(
  0,
  _readyAt(_lastPlayed(state, kind), effectiveMiniGameCooldown(state, kind)) -
      now(),
);

/// Spend the attempt when the session STARTS.
///
/// Stamping the cooldown on the payout alone let a player close a bad round and
/// replay it for free.
void startMiniGame(Map<String, dynamic> state, String kind) {
  // The branch is back-filled before the kind is checked, matching the JS —
  // which means even a call naming a game that does not exist leaves the save
  // with a complete `miniGames` branch.
  final mg = _mg(state);
  final key = _games[kind]?.lastPlayedKey;
  if (key == null) return;
  mg[key] = now();
}

/// Clear one game's cooldown — the rewarded-ad "skip" hook. Winds the stamp
/// back far enough that the game reads as ready.
void resetMiniGameCooldown(Map<String, dynamic> state, String kind) {
  final mg = _mg(state);
  final key = _games[kind]?.lastPlayedKey;
  if (key == null) return;
  mg[key] = 0;
}

/// Is every game the player can actually PLAY cooling down?
///
/// Unlocked only. A locked game has never been played, so it reads as ready
/// forever — count those and a save below Training tier 6 could never satisfy
/// this, which is precisely the save that gets the most out of a skip.
bool allMiniGamesOnCooldown(Map<String, dynamic> state) {
  final unlocked = getUnlockedMinigames(_map(state['clubAssets']));
  return unlocked.isNotEmpty &&
      unlocked.every((kind) => !miniGameReady(state, kind));
}

/// Free skips spent today.
///
/// The ledger resets on a date STRING rather than a rolling window — the same
/// "comes back tomorrow" every other daily uses.
int skipAdsUsedToday(Map<String, dynamic>? state, [String? today]) {
  final shop = _map(state?['shop']);
  final day = today ?? dateString();
  if (shop?['skipAdDay'] != day) return 0;
  return _num(shop?['skipAdCount'])?.toInt() ?? 0;
}

int skipAdsLeftToday(Map<String, dynamic>? state, [String? today]) =>
    math.max(0, Minigame.skipCapPerDay - skipAdsUsedToday(state, today));

/// Spend one of the day's free skips.
void recordSkipAd(Map<String, dynamic> state, [String? today]) {
  final day = today ?? dateString();
  final shop = _branch(state, 'shop');
  if (shop['skipAdDay'] != day) {
    shop['skipAdDay'] = day;
    shop['skipAdCount'] = 0;
  }
  shop['skipAdCount'] = (_num(shop['skipAdCount'])?.toInt() ?? 0) + 1;
}

/// Should the Play tab warm the rewarded ad for the skip button?
///
/// Only when the tap is actually coming: everything the player owns is cooling
/// down, so the button is live, and there is a free video left to spend on it —
/// past that the button is a gem purchase and shows no ad at all. The plugin
/// caches ONE rewarded ad globally, so warming it earlier evicts a placement
/// the player was more likely to reach.
bool shouldPrefetchSkipAd(Map<String, dynamic> state) =>
    allMiniGamesOnCooldown(state) && skipAdsLeftToday(state) > 0;

// ── Banking a session ───────────────────────────────────────────────────────

int _payout(Map<String, dynamic> state, num amount) {
  final coins = roundCoins(amount);
  final resources = _branch(state, 'resources');
  resources['fanCoins'] = (_num(resources['fanCoins']) ?? 0) + coins;
  return coins;
}

/// Bump a counter, creating the branch if the save has none.
void _bump(Map<String, dynamic> stats, String key, num by) {
  stats[key] = (_num(stats[key]) ?? 0) + by;
}

void _keepBest(Map<String, dynamic> stats, String key, num value) {
  stats[key] = math.max(_num(stats[key]) ?? 0, value);
}

/// Record a completed Pitch Invaders session.
///
/// [catches] is already net of any stewards tapped — the UI applies the foul
/// cost as it happens so the player watches the counter drop, and this banks
/// whatever survived.
int recordWhackResult(
  Map<String, dynamic> state, {
  num catches = 0,
  num fouls = 0,
  num dogs = 0,
}) {
  final mg = _mg(state);
  final safeCatches = math.max(0, catches.floor());
  final coins = _payout(
    state,
    _divBase(state) *
        Whack.rewardPerCatchMult *
        safeCatches *
        getMiniGameCoinMult(state),
  );
  mg['whackLastPlayed'] = now();

  final stats = _branch(state, 'stats');
  _bump(stats, 'whackRounds', 1);
  _keepBest(stats, 'whackBest', safeCatches);
  // Cumulative, which is what the season quest counts. A best-of stat cannot be
  // a quest target: it stops moving the moment the player has a good session.
  _bump(stats, 'whackCatches', safeCatches);
  _bump(stats, 'whackDogs', math.max(0, dogs.floor()));
  // A clean sheet needs something caught — sitting the session out is not one.
  if (fouls == 0 && safeCatches > 0) _bump(stats, 'whackCleanRounds', 1);
  return coins;
}

/// Record a completed Boot Room session. Coins are per tile cleared, with a
/// flat bonus for meeting the division's tile target.
({int coins, bool hitTarget}) recordBootRoomResult(
  Map<String, dynamic> state, {
  num tilesCleared = 0,
  num target = 0,
  num bestCascade = 0,
}) {
  final mg = _mg(state);
  final safeTiles = math.max(0, tilesCleared.floor());
  final hitTarget = target > 0 && safeTiles >= target;
  var amount = roundCoins(
    _divBase(state) *
        BootRoom.rewardPerTileMult *
        safeTiles *
        getMiniGameCoinMult(state),
  );
  if (hitTarget) amount = roundCoins(amount * BootRoom.targetBonusMult);
  final coins = _payout(state, amount);
  mg['bootRoomLastPlayed'] = now();

  final stats = _branch(state, 'stats');
  _bump(stats, 'bootRoomRounds', 1);
  _keepBest(stats, 'bootRoomBest', safeTiles);
  _keepBest(stats, 'bootRoomBestCascade', math.max(0, bestCascade.floor()));
  if (hitTarget) _bump(stats, 'bootRoomTargets', 1);
  return (coins: coins, hitTarget: hitTarget);
}

/// Record a completed Pairs game, with a bonus when the board is cleared.
int recordPairsResult(
  Map<String, dynamic> state, {
  num pairsMatched = 0,
  num totalPairs = 0,
  bool cleared = false,
}) {
  final mg = _mg(state);
  final safeMatched = math.max(0, math.min(pairsMatched, totalPairs));
  var amount = roundCoins(
    _divBase(state) *
        Pairs.rewardPerPairMult *
        safeMatched *
        getMiniGameCoinMult(state),
  );
  if (cleared) amount = roundCoins(amount * Pairs.clearBonusMult);
  final coins = _payout(state, amount);
  mg['pairsLastPlayed'] = now();

  final stats = _branch(state, 'stats');
  _bump(stats, 'pairsRounds', 1);
  if (cleared) _bump(stats, 'pairsCleared', 1);
  return coins;
}

/// Record a completed Keepy Uppys session.
int recordKeepyUppysResult(Map<String, dynamic> state, {num taps = 0}) {
  final mg = _mg(state);
  final safeTaps = math.max(0, taps.floor());
  final coins = _payout(
    state,
    _divBase(state) *
        KeepyUppys.rewardPerTapMult *
        safeTaps *
        getMiniGameCoinMult(state),
  );
  mg['keepyUppysLastPlayed'] = now();

  final stats = _branch(state, 'stats');
  _bump(stats, 'keepyUppysRounds', 1);
  _keepBest(stats, 'keepyUppysBest', safeTaps);
  return coins;
}

/// Record a completed Through Ball session.
int recordThroughBallResult(
  Map<String, dynamic> state, {
  num roundsPassed = 0,
}) {
  final mg = _mg(state);
  final clamped = math.max(0, math.min(roundsPassed, ThroughBall.rounds));
  final coins = _payout(
    state,
    _divBase(state) *
        ThroughBall.rewardPerRoundMult *
        clamped *
        getMiniGameCoinMult(state),
  );
  mg['throughBallLastPlayed'] = now();

  final stats = _branch(state, 'stats');
  _bump(stats, 'throughBallRounds', 1);
  if (clamped == ThroughBall.rounds) _bump(stats, 'perfectThroughBalls', 1);
  return coins;
}

/// Record a completed round of Penalty Training — the arcade game, never a
/// cup-tie shootout, which never touches these counters.
///
/// Alone in this family, it will not CREATE the stats branch: the JS guards the
/// whole block on the branch already existing, so a save without one banks the
/// coins and counts nothing.
int recordPenaltyResult(Map<String, dynamic> state, {num? scored, num? total}) {
  final mg = _mg(state);
  final totalShots = total ?? Penalty.attempts;
  final clampedScored = math.max(0, math.min(scored ?? 0, totalShots));
  final coins = _payout(
    state,
    _divBase(state) *
        Penalty.rewardPerGoalMult *
        clampedScored *
        getMiniGameCoinMult(state),
  );
  mg['penaltyLastPlayed'] = now();

  final stats = _map(state['stats']);
  if (stats != null) {
    _bump(stats, 'penaltyRounds', 1);
    // Penalties CONVERTED, not rounds played. A perfect round is a lottery that
    // gets longer the higher you climb — the keeper reads 5% of shots in Sunday
    // League and 30% in Champions — so the quest bank counts goals instead. See
    // `season_penalties_scored`.
    _bump(stats, 'penaltiesScored', clampedScored);
    if (clampedScored == totalShots) _bump(stats, 'perfectPenalties', 1);
  }
  return coins;
}

/// Record a completed Goalkeeper Practice session.
///
/// [drillTotal] is how many drills were spawned, which varies by division. The
/// payout scales with how many were hit; the energy grant is zero, because the
/// only energy this game pays comes from the daily streak milestones.
({int coins, int energyGranted}) recordTrainingComplete(
  Map<String, dynamic> state, {
  num? drillsHit,
  num? drillTotal,
}) {
  final mg = _mg(state);
  final total = math.max(1, drillTotal ?? Training.drillsBase);
  final hit = math.max(0, math.min(drillsHit ?? total, total));
  final coins = _payout(
    state,
    _divBase(state) *
        Training.rewardBaseMult *
        (hit / total) *
        getMiniGameCoinMult(state),
  );

  // **AGAINST THE PLAYER'S OWN CAP, which it was not.** It clamped to
  // `Energy.max` (10) rather than `getEnergyMax(state)` (15 with the Energy
  // Director), so a player sitting above ten pips had them taken away by a
  // game that grants no energy at all — and `energyGranted` came back NEGATIVE,
  // reported as a grant. The grant being zero is what hid it: nothing on the
  // summary said a number, so the only sign was the tank.
  //
  // The clamp stays rather than going, because the grant is a tunable and a
  // future one must not be able to overfill the tank. It is the CAP that was
  // wrong, not the clamping.
  final cap = getEnergyMax(state);
  final energy =
      _map(state['energy']) ??
      (state['energy'] = <String, dynamic>{'current': 0, 'lastRegenAt': now()});
  final before = _num(energy['current'])?.toInt() ?? 0;
  final energyGranted = math.max(
    0,
    math.min(Training.energyGrant, cap - before),
  );
  energy['current'] = math.min(before + Training.energyGrant, cap);

  mg['trainingLastPlayed'] = now();
  final stats = _map(state['stats']);
  if (stats != null && hit == total) _bump(stats, 'perfectTrainings', 1);

  return (coins: coins, energyGranted: energyGranted);
}
