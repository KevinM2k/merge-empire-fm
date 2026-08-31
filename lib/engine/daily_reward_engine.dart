/// The daily login reward — a seven-day repeating calendar. Ported from
/// `../merge-empire-fc/src/engine/dailyRewardEngine.js`.
///
/// The streak advances just by opening the app and claiming, with no friction,
/// unlike the training streak which wants a mini-game played. Missing a day
/// breaks it: the player either restarts at day 1 or watches a rewarded ad to
/// repair it and carry on where they left off.
///
/// Coin amounts are division-scaled through the mini-game reward base, so the
/// reward stays meaningful from Sunday League to Champions Cup. Day 7 pays GEMS,
/// which makes this the only repeating gem faucet in the game.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/engine/gem_engine.dart';
import 'package:merge_empire_fc/engine/lineup_engine.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/engine/player_energy_engine.dart';
import 'package:merge_empire_fc/util/analytics.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
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

/// One day of the calendar.
///
/// `coinsMult` is applied to the mini-game reward base. Energy stacks over the
/// cap — it is an earned reward, the same as a streak milestone or an IAP energy
/// pack.
typedef DailyReward = ({
  num coinsMult,
  int energy,
  int gems,
  bool freeScout,
  bool healOne,
});

DailyReward _day({
  num coinsMult = 0,
  int energy = 0,
  int gems = 0,
  bool freeScout = false,
  bool healOne = false,
}) => (
  coinsMult: coinsMult,
  energy: energy,
  gems: gems,
  freeScout: freeScout,
  healOne: healOne,
);

/// The calendar.
///
/// Day 4 was the Scout Voucher day — a free taste of a paid product, on the
/// theory that sampling drives conversion. The voucher went and its value came
/// back as coins, so the day is not a dud without it.
///
/// Day 7 pays GEMS: the payoff for a full week and the ONLY recurring gem faucet
/// in the game, roughly value-neutral against the Scout Voucher it replaced.
/// Know what recurring means here — 2 gems a week is about 104 a year, against a
/// 14-gem LIFETIME total from every other faucet combined. That makes the login
/// streak by a wide margin the main way a non-paying player gets gems: a
/// deliberate call, but the first number to revisit if gem sales look soft.
///
/// `freeScout` and `healOne` are still supported by every function here and are
/// simply unused above, so a day can pick either back up with no new plumbing.
final Map<int, DailyReward> dailyRewards = {
  1: _day(coinsMult: 2),
  2: _day(coinsMult: 1, energy: 2),
  3: _day(coinsMult: 4),
  4: _day(coinsMult: 3),
  5: _day(coinsMult: 2, energy: 3),
  6: _day(coinsMult: 6),
  7: _day(coinsMult: 10, energy: 4, gems: 2),
};

const int cycleDays = 7;

/// Trained-yesterday synergy: completing any training mini-game the previous day
/// — or earlier today, for players who train before claiming — bumps the coin
/// component. It keeps the training streak's identity relevant without gating
/// the login reward behind a task.
const double trainedBonusMult = 1.5;

/// Pro mode has no team pip pool, so energy rewards top up squad fitness
/// instead, mirroring the training-streak milestones. Day 7's four pips make a
/// 20% squad top-up.
const double _fitnessPctPerPip = 0.05;

/// The local-day key, midnight to midnight in the player's own timezone — the
/// same shape the training streak uses, so both systems agree on what a day is.
String _dayKey(int ts) => dateString(ts);

String _prevDayKey(int ts) => dateString(ts - 24 * 60 * 60 * 1000);

/// **HOW LONG UNTIL THE NEXT ONE, in milliseconds.**
///
/// The cycle turns over at LOCAL midnight, because [_dayKey] is `dateString` and
/// that is a local-time day — so this is the wall clock to the next one, not a
/// fixed 24 hours from the last claim. Those two differ by up to a day and the
/// local one is what the player experiences: claim at 23:55 and the next reward
/// is five minutes away, which is the rule the training streak already plays by.
///
/// `DateTime(y, m, d + 1)` rather than adding 86,400,000: the constructor
/// normalises a rolled-over day, month and year, and it lands on local midnight
/// through a daylight-saving change, which the arithmetic does not.
///
/// It answers for a state that has already claimed and for one that has not —
/// the question is about the calendar, not about the save — so a caller that
/// wants "when can I claim again" must ask [getDailyRewardStatus] whether today
/// is spent first.
int msUntilNextReward([int? ts]) {
  final at = ts ?? now();
  final d = DateTime.fromMillisecondsSinceEpoch(at);
  final midnight = DateTime(d.year, d.month, d.day + 1);
  final left = midnight.millisecondsSinceEpoch - at;
  return left > 0 ? left : 0;
}

Map<String, dynamic> _dr(Map<String, dynamic> state) {
  final existing = _map(state['dailyReward']);
  if (existing != null) return existing;
  final fresh = <String, dynamic>{
    // 1-7 position of the LAST claimed reward; 0 means never claimed.
    'cycleDay': 0,
    'lastClaimDayKey': null,
    'streak': 0,
    'longestStreak': 0,
    'totalClaims': 0,
    // The popup's auto-show gate, set by the UI layer.
    'lastAutoPopupDayKey': null,
  };
  state['dailyReward'] = fresh;
  return fresh;
}

/// True if any training mini-game was completed yesterday or earlier today.
bool _trainedRecently(Map<String, dynamic> state, int ts) {
  final mg = _map(state['miniGames']) ?? const {};
  final keys = {_dayKey(ts), _prevDayKey(ts)};
  for (final key in const [
    'penaltyLastPlayed',
    'trainingLastPlayed',
    'throughBallLastPlayed',
    'pairsLastPlayed',
    'keepyUppysLastPlayed',
  ]) {
    final played = _num(mg[key]);
    if (played != null &&
        played > 0 &&
        keys.contains(_dayKey(played.toInt()))) {
      return true;
    }
  }
  return false;
}

/// What one calendar day is actually worth at the player's current division.
typedef DailyRewardPreview = ({
  int day,
  int coins,
  int energy,
  bool freeScout,
  bool healOne,
  int gems,
});

DailyRewardPreview? getDailyRewardPreview(Map<String, dynamic> state, int day) {
  final def = dailyRewards[day];
  if (def == null) return null;
  return (
    day: day,
    coins: roundCoins(def.coinsMult * miniGameRewardBase(state)),
    energy: def.energy,
    freeScout: def.freeScout,
    healOne: def.healOne,
    gems: def.gems,
  );
}

/// Where the player stands today.
typedef DailyRewardStatus = ({
  bool claimedToday,

  /// The day they would claim now — or did claim, when [claimedToday].
  int day,
  int streak,

  /// Missed a day or more with a streak running, so a repair is possible.
  bool broken,

  /// [trainedBonusMult] applies to the coin component.
  bool trainedBonus,

  /// A preview of what is claimable, or null once today is claimed.
  DailyRewardPreview? reward,
});

DailyRewardStatus getDailyRewardStatus(Map<String, dynamic> state, [int? ts]) {
  final at = ts ?? now();
  final dr = _dr(state);
  final today = _dayKey(at);
  final yesterday = _prevDayKey(at);
  final lastClaim = dr['lastClaimDayKey'];
  final cycleDay = _num(dr['cycleDay'])?.toInt() ?? 0;
  final streak = _num(dr['streak'])?.toInt() ?? 0;

  if (lastClaim == today) {
    return (
      claimedToday: true,
      day: cycleDay,
      streak: streak,
      broken: false,
      trainedBonus: false,
      reward: null,
    );
  }

  final continues = lastClaim == yesterday;
  final broken = !continues && lastClaim != null && streak > 0;
  final day = continues ? (cycleDay % cycleDays) + 1 : 1;

  return (
    claimedToday: false,
    day: day,
    streak: streak,
    broken: broken,
    trainedBonus: _trainedRecently(state, at),
    reward: getDailyRewardPreview(state, day),
  );
}

/// True when a broken streak is worth offering an ad-repair for.
bool canRepairStreak(Map<String, dynamic> state, [int? ts]) {
  final status = getDailyRewardStatus(state, ts);
  final cycleDay = _num(_map(state['dailyReward'])?['cycleDay'])?.toInt() ?? 0;
  return status.broken && cycleDay >= 1;
}

/// Repair a broken streak, after a completed rewarded ad.
///
/// Pretends yesterday was claimed, so the next claim continues the cycle where
/// it left off with the streak intact. A no-op unless the streak is actually
/// broken.
({bool ok, int? streak, String? reason}) repairStreak(
  Map<String, dynamic> state, [
  int? ts,
]) {
  final at = ts ?? now();
  if (!canRepairStreak(state, at)) {
    return (ok: false, streak: null, reason: 'not_broken');
  }
  final dr = _dr(state);
  dr['lastClaimDayKey'] = _prevDayKey(at);
  final streak = _num(dr['streak'])?.toInt() ?? 0;
  logAppEvent('daily_streak_repaired', {
    'streak': streak,
    'cycle_day': _num(dr['cycleDay'])?.toInt() ?? 0,
  });
  return (ok: true, streak: streak, reason: null);
}

/// What a claim did.
typedef DailyClaim = ({
  bool ok,
  String? reason,
  int day,
  int streak,
  int coins,
  int energy,
  double teamEnergyPct,
  int gems,
  bool freeScout,
  bool healOne,
  int healedCount,
  bool doubled,
  bool trainedBonus,
});

const DailyClaim _alreadyClaimed = (
  ok: false,
  reason: 'already_claimed',
  day: 0,
  streak: 0,
  coins: 0,
  energy: 0,
  teamEnergyPct: 0,
  gems: 0,
  freeScout: false,
  healOne: false,
  healedCount: 0,
  doubled: false,
  trainedBonus: false,
);

/// Claim today's reward and apply it.
///
/// [doubled] is the rewarded-ad double: twice the coins and twice the energy.
DailyClaim claimDailyReward(
  Map<String, dynamic> state, {
  bool doubled = false,
  int? ts,
}) {
  final at = ts ?? now();
  final status = getDailyRewardStatus(state, at);
  if (status.claimedToday) return _alreadyClaimed;

  final dr = _dr(state);
  final def = dailyRewards[status.day]!;
  final mult = doubled ? 2 : 1;

  // Coins — division-scaled, with the trained-recently bonus on top.
  var rawCoins = def.coinsMult * miniGameRewardBase(state);
  if (status.trainedBonus) rawCoins *= trainedBonusMult;
  final coins = roundCoins(rawCoins * mult);
  if (coins > 0) {
    final resources = _branch(state, 'resources');
    resources['fanCoins'] = (_num(resources['fanCoins']) ?? 0) + coins;
  }

  // Energy — pips in Casual, where they stack over the regen cap the same way a
  // streak milestone does; a squad-fitness top-up in Pro.
  final energy = def.energy * mult;
  final hardMode = _map(state['settings'])?['hardMode'] == true;
  var teamEnergyPct = 0.0;
  if (energy > 0) {
    if (hardMode) {
      teamEnergyPct = energy * _fitnessPctPerPip;
      topUpAllEnergy(state, at, teamEnergyPct);
    } else {
      var pool = _map(state['energy']);
      if (pool == null) {
        pool = <String, dynamic>{'current': 0, 'lastRegenAt': at};
        state['energy'] = pool;
      }
      pool['current'] = (_num(pool['current']) ?? 0) + energy;
    }
  }

  if (def.freeScout) {
    _branch(state, 'shop')['freeScoutReady'] = true;
  }

  // Gems are deliberately NOT multiplied by [doubled]. Everything else here
  // scales with the rewarded-ad double, but a video that mints hard currency
  // turns the ad shelf into a gem faucet — the one thing the gem engine's design
  // notes rule out.
  if (def.gems > 0) addGems(state, def.gems, 'daily_streak');

  // The Quick Sponge heals one injured player, two if doubled — distinct from
  // the shop's Magic Sponge, which heals every injured player at once.
  var healedCount = 0;
  if (def.healOne) {
    final cells = _map(state['grid'])?['cells'];
    if (cells is List) {
      for (final raw in cells) {
        if (healedCount >= mult) break;
        final card = _map(raw);
        if (card == null || card['injured'] != true) continue;
        card['injured'] = false;
        card['injuredAt'] = null;
        card['injuryDurationMs'] = null;
        healedCount++;
      }
    }
    // Back in contention for the slot the injury left open.
    if (healedCount > 0) refillLineupFromBench(state);
  }

  // Advance the streak. A broken streak that was not repaired restarts at 1.
  final continues = dr['lastClaimDayKey'] == _prevDayKey(at);
  final streak = continues ? (_num(dr['streak'])?.toInt() ?? 0) + 1 : 1;
  dr['streak'] = streak;
  dr['longestStreak'] = math.max(
    _num(dr['longestStreak'])?.toInt() ?? 0,
    streak,
  );
  dr['cycleDay'] = status.day;
  dr['lastClaimDayKey'] = _dayKey(at);
  dr['totalClaims'] = (_num(dr['totalClaims'])?.toInt() ?? 0) + 1;

  if (coins > 0) {
    emit('coins:updated', _map(state['resources'])?['fanCoins']);
  }
  if (energy > 0 && !hardMode) {
    emit('energy:updated', _map(state['energy'])?['current']);
  }

  final result = (
    ok: true,
    reason: null,
    day: status.day,
    streak: streak,
    coins: coins,
    energy: energy,
    teamEnergyPct: teamEnergyPct,
    gems: def.gems,
    freeScout: def.freeScout,
    healOne: def.healOne,
    healedCount: healedCount,
    doubled: doubled,
    trainedBonus: status.trainedBonus,
  );
  emit('dailyreward:claimed', result);

  logAppEvent('daily_reward_claimed', {
    'day': status.day,
    'streak': streak,
    'doubled': doubled ? 1 : 0,
    'trained_bonus': status.trainedBonus ? 1 : 0,
    'division': _map(state['progression'])?['currentDivision'] ?? 'unknown',
  });

  return result;
}

/// The current consecutive-day streak, for the HUD chip.
int getDailyStreak(Map<String, dynamic>? state) =>
    _num(_map(state?['dailyReward'])?['streak'])?.toInt() ?? 0;

/// Whether the once-a-day auto-popup should fire now, marking it as shown.
///
/// A manual open — tapping the HUD chip — bypasses this entirely.
bool shouldAutoShowPopup(Map<String, dynamic> state, [int? ts]) {
  final at = ts ?? now();
  final dr = _dr(state);
  final today = _dayKey(at);
  if (dr['lastAutoPopupDayKey'] == today) return false;
  if (getDailyRewardStatus(state, at).claimedToday) return false;
  dr['lastAutoPopupDayKey'] = today;
  return true;
}
