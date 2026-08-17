/// Deciding which achievements have just been earned. Ported from
/// `../merge-empire-fc/src/engine/achievementEngine.js`.
///
/// [checkAchievements] is a sweep, not a subscription: the caller hands it what
/// just happened and it runs every predicate that has not already fired. That is
/// why a predicate has to be cheap and total — one that throws is treated as "not
/// met" rather than taking the boot sequence down with it.
///
/// The coin grant is NOT applied here. It is applied by the listener on
/// `achievement:unlocked`, which has the state-mutation wrapper needed to trigger
/// a save.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/achievements.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

/// What an achievement pays, by rough rarity within its category. Anything not
/// listed pays [defaultAchievementReward].
///
/// NOTE the gaps: every cup achievement, all seven Pro-mode ones, the mini-game
/// ones, the reset ones and the event one have no entry, so they all pay the
/// default 100 — which puts `hard_100_wins` at 100 against `win_100_matches` at
/// 1,000. That reads like an oversight rather than a decision, but it is tuning,
/// so it is reproduced rather than corrected. See docs/REMAINING.md.
const Map<String, int> achievementCoinRewards = {
  // Progression milestones — reaching higher divisions.
  'reach_amateur': 200,
  'reach_regional': 500,
  'reach_national': 1000,
  'reach_elite': 2500,
  'reach_continental': 5000,
  'reach_champions': 10000,
  // Prestige grants NO coins — the reward is the stacking income multiplier from
  // prestiging itself, and coins here would trivialise the new run.
  'prestige_level_1': 0,
  'prestige_level_3': 0,
  'prestige_level_5': 0,
  'prestige_level_10': 0,
  // Seasons.
  'first_promotion': 300,
  'relegated_once': 100,
  'first_league_title': 1000,
  'five_league_titles': 3000,
  'play_5_seasons': 200,
  'play_10_seasons': 500,
  'play_20_seasons': 1500,
  'win_league_undefeated': 5000,
  // Merges.
  'first_merge': 50,
  'merge_50': 200,
  'merge_200': 500,
  'merge_500': 1500,
  'merge_to_silver': 150,
  'merge_to_gold': 400,
  'merge_to_superstar': 1000,
  'merge_to_legend': 2500,
  'merge_to_world': 5000,
  // Matches.
  'first_win': 100,
  'win_25_matches': 300,
  'win_100_matches': 1000,
  'win_500_matches': 5000,
  'comeback_win': 500,
  // Squad.
  'use_veteran_7s': 300,
  'use_veteran_10s': 1000,
  'full_squad_16': 500,
  'first_sponsor': 200,
  'three_sponsors': 500,
  'scout_25': 200,
  'scout_100': 750,
  'own_tier3_asset': 300,
  'own_tier6_asset': 1500,
  'own_all_categories': 2000,
  // Economy.
  'coins_10k': 500,
  'coins_100k': 2000,
  'coins_1m': 10000,
  // Transfers and rivalries.
  'first_transfer_accept': 200,
  'five_transfer_accept': 500,
  'first_transfer_decline': 100,
  'grudge_revenge': 400,
  'sell_tier5_player': 750,
  // Mini-games.
  'penalty_perfect': 300,
  'penalty_ten_rounds': 500,
  'training_perfect': 300,
};

/// What an achievement with no entry in the table pays.
const int defaultAchievementReward = 100;

/// An achievement that has just fired.
class UnlockedAchievement {
  const UnlockedAchievement({
    required this.def,
    required this.coinsRewarded,
    required this.isReUnlock,
    required this.count,
  });

  final Achievement def;
  final int coinsRewarded;

  /// True when this id had been earned before, in an earlier run.
  ///
  /// Always FALSE today — see the note in [checkAchievements].
  final bool isReUnlock;

  /// How many times this id has now been earned. Always 1 today, for the same
  /// reason.
  final int count;

  String get id => def.id;
}

/// The achievement bucket, created and repaired on the way past.
List<Object?> _ensureBucket(Map<String, dynamic> state) {
  final prog = _map(state['progression']) ??
      (state['progression'] = <String, dynamic>{});
  if (prog['achievements'] is! List) prog['achievements'] = <Object?>[];
  if (prog['achievementIdsThisRun'] is! List) {
    prog['achievementIdsThisRun'] = <Object?>[];
  }

  // Defensive dedupe, keeping the entry with the highest count — which is the
  // latest unlock.
  final bucket = prog['achievements'] as List;
  final seen = <String, Map<String, dynamic>>{};
  for (final raw in bucket) {
    final a = _map(raw);
    final id = a?['id'];
    if (a == null || id is! String) continue;
    final prev = seen[id];
    if (prev == null || (_num(a['count']) ?? 1) > (_num(prev['count']) ?? 1)) {
      seen[id] = a;
    }
  }
  if (seen.length != bucket.length) {
    prog['achievements'] = seen.values.toList();
  }
  return prog['achievements'] as List;
}

/// Every achievement id ever earned on this save.
Set<String> getUnlockedIds(Map<String, dynamic>? state) {
  final arr = _map(state?['progression'])?['achievements'];
  return {
    if (arr is List)
      for (final a in arr)
        if (_map(a)?['id'] case final String id) id,
  };
}

/// Runs every predicate that has not already fired, and returns what just
/// unlocked.
///
/// ── THE RE-UNLOCK PATH IS DEAD, and deliberately left that way ──────────────
///
/// There are two guards below. `thisRunIds` gates on ids earned in the CURRENT
/// run, and is cleared on prestige or reset — the JS comment on it says that is
/// what makes achievements "become re-unlockable in new runs". `everUnlocked`
/// gates on ids earned EVER. The second subsumes the first: an id in the bucket
/// is always in `everUnlocked`, so the branch below that increments a count and
/// reports `isReUnlock` can never run, `count` is always 1, and clearing the
/// per-run list achieves nothing.
///
/// So the JS contradicts its own comment, and this port reproduces it rather than
/// switching it on: removing the `everUnlocked` guard would make every achievement
/// re-payable on every reset, which is a coin faucet and an economy decision, not
/// a mechanical fix. A test pins the current behaviour so the change is visible if
/// it is ever made deliberately. See docs/REMAINING.md.
List<UnlockedAchievement> checkAchievements(
  Map<String, dynamic>? state, [
  AchievementEvent event = (type: 'boot', data: null),
]) {
  if (state == null) return const [];
  final bucket = _ensureBucket(state);
  final prog = _map(state['progression'])!;

  final thisRunList = prog['achievementIdsThisRun'] as List;
  final thisRunIds = <String>{
    for (final id in thisRunList)
      if (id is String) id,
  };
  final everUnlocked = getUnlockedIds(state);
  final newlyUnlocked = <UnlockedAchievement>[];

  for (final def in achievements) {
    if (thisRunIds.contains(def.id)) continue;
    if (everUnlocked.contains(def.id)) continue;

    var passed = false;
    try {
      passed = def.check(state, event);
    } catch (_) {
      // A predicate that throws is "not met". Eighty of these run on boot, and
      // one bad read on a half-migrated save must not stop the app starting.
      passed = false;
    }
    if (!passed) continue;

    // Reentrancy guard: the emit below is synchronous and may trigger another
    // sweep before this iteration settles.
    if (thisRunIds.contains(def.id)) continue;

    final reward = achievementCoinRewards[def.id] ?? defaultAchievementReward;
    final existingIdx = bucket.indexWhere((a) => _map(a)?['id'] == def.id);
    int count;
    if (existingIdx >= 0) {
      // Unreachable while the `everUnlocked` guard stands — see above.
      final entry = _map(bucket[existingIdx])!;
      count = ((_num(entry['count']) ?? 1) + 1).toInt();
      entry['count'] = count;
      entry['unlockedAt'] = now();
    } else {
      count = 1;
      bucket.add(<String, dynamic>{
        'id': def.id,
        'unlockedAt': now(),
        'coinsRewarded': reward,
        'count': 1,
      });
    }

    thisRunList.add(def.id);
    thisRunIds.add(def.id);

    final unlocked = UnlockedAchievement(
      def: def,
      coinsRewarded: reward,
      isReUnlock: existingIdx >= 0,
      count: count,
    );
    newlyUnlocked.add(unlocked);
    // The coin grant is applied by the listener, which has the mutation wrapper
    // needed to trigger a save.
    emit('achievement:unlocked', {
      'id': def.id,
      'title': def.title,
      'description': def.description,
      'category': def.category,
      'coinsRewarded': reward,
      'isReUnlock': existingIdx >= 0,
      'count': count,
    });
  }

  return newlyUnlocked;
}
