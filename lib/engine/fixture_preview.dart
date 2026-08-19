/// A non-mutating look at the NEXT league fixture: who, where, and how the two
/// sides compare before a ball is kicked. Ported from the `previewFixture`
/// block of `../merge-empire-fc/src/engine/matchEngine.js`.
///
/// This exists for the match quest track. Quests are rolled BEFORE kickoff, and
/// a handful of them ask for a shape of result a given fixture simply cannot
/// produce — "win away from home" in a home game, "beat a better-rated side"
/// against a team you outrate by twenty. The quest engine gates those on this
/// preview so an impossible quest is never handed out.
///
/// It lives in its own file rather than beside the simulation, which is a
/// deliberate improvement on the JS: there the quest engine and the match
/// engine import each other, and the cycle only works because ES modules
/// tolerate it. Splitting the preview out breaks it properly.
///
/// Every number is derived the same way the simulation derives it, and a test
/// pins the two together — if the sim's ratings block changes and this doesn't,
/// that test fails rather than the quests quietly going wrong.
///
/// Two deliberate differences from the simulation:
///   • Nothing is written to the save. The opponent's rating is READ, never
///     seeded, so a fixture whose rating hasn't been rolled yet reports null
///     for it and for everything derived from it. Callers must treat null as
///     "unknown", never as zero.
///   • The Lucky Boot is applied but not consumed, and the grudge boost is read
///     rather than spent. A preview must never eat a one-shot buff.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/squad_rating.dart';
import 'package:merge_empire_fc/state/card_instance.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

/// Which leg of the season a fixture index is, and therefore where it is
/// played.
///
/// Seeded per opponent per season, with the second leg reversing the first —
/// one copy of the rule, because three places used to hold their own.
bool fixtureIsHome(int season, int oppIdx, int matchNum) {
  final firstLeg = matchNum < opponentsPerSeason;
  final seed = ((oppIdx + 1) * 37 + season * 13) % 10;
  return firstLeg ? seed >= 5 : seed < 5;
}

/// A club's attack share, looked up by name across the whole pyramid.
///
/// Falls back to the base share for an unknown club, and folds a legacy
/// `attackBias` onto the same scale for a save written before shares existed.
double getOpponentAttackRatio(
  Map<String, dynamic>? state,
  String opponentName,
) {
  final pyramid = _map(_map(state?['progression'])?['leaguePyramid']);
  if (pyramid == null) return oppBaseAtkShare;

  for (final teams in pyramid.values) {
    if (teams is! List) continue;
    for (final raw in teams) {
      final team = _map(raw);
      if (team == null || team['name'] != opponentName) continue;
      final ratio = _num(team['attackRatio']);
      if (ratio != null) return ratio.toDouble();
      final bias = _num(team['attackBias']) ?? 0;
      return math.max(
        0.12,
        math.min(0.88, oppBaseAtkShare + bias * oppBiasShare),
      );
    }
  }
  return oppBaseAtkShare;
}

/// What the next fixture looks like from here.
///
/// Every `opp`-prefixed field is null together: a season nobody has played has
/// no opponent rating to read, and reporting zero would say "they're terrible".
class FixturePreview {
  const FixturePreview({
    this.ourHomeAdv = 0,
    this.theirHomeAdv = 0,
    this.playerInRelegationZone = false,
    this.oppInRelegationZone = false,
    this.bootApplied = false,
    required this.oppIdx,
    required this.opponentName,
    required this.isHome,
    required this.squadRating,
    required this.ourAttackRating,
    required this.ourDefenceRating,
    required this.effAttack,
    required this.effDefence,
    required this.effectiveSquadRating,
    this.opponentRating,
    this.effectiveOppRating,
    this.effOppAttackRating,
    this.effOppDefenceRating,
    this.oppAttackRatio,
    this.grudgeBoost = 0,
  });

  final int oppIdx;
  final String opponentName;
  final bool isHome;

  /// The squad's star before the fixture's own modifiers.
  final int squadRating;
  final int ourAttackRating;
  final int ourDefenceRating;

  /// ATK and DEF with home advantage, stagnation and the relegation boost in.
  final double effAttack;
  final double effDefence;
  final double effectiveSquadRating;

  final num? opponentRating;
  final double? effectiveOppRating;
  final double? effOppAttackRating;
  final double? effOppDefenceRating;

  /// Their shape, exactly. Counter Attack's multiplier reads it, so every
  /// screen that prices a tactic needs it — and none of them can infer it from
  /// the split, where a 3-4-3 and a 4-3-3 differ by less than a rounding unit.
  final double? oppAttackRatio;

  final num grudgeBoost;

  /// The modifiers, separately, because the card NAMES them.
  ///
  /// Every one is a delta already inside the rating beside it, so the card hangs
  /// a glyph and a signed number under the figure it moved — the arithmetic
  /// behind the number rather than a second number to reconcile with it. Without
  /// these the card could print the total and not say where it came from.
  final int ourHomeAdv;
  final int theirHomeAdv;
  final bool playerInRelegationZone;
  final bool oppInRelegationZone;

  /// The Lucky Boot actually weakened this opponent — the card marks it with a
  /// 🍀 rather than silently quoting a lower number.
  final bool bootApplied;
}

/// The next league fixture, or null when the save has no progression at all.
FixturePreview? previewFixture(
  Map<String, dynamic>? state, [
  String? divisionId,
]) {
  final prog = _map(state?['progression']);
  if (state == null || prog == null) return null;
  final div = getDivision('${divisionId ?? prog['currentDivision']}');

  final matchNum = _num(prog['seasonMatchesPlayed'])?.toInt() ?? 0;
  final season = _num(prog['seasonCount'])?.toInt() ?? 1;
  final oppIdx = matchNum % opponentsPerSeason;
  final isHome = fixtureIsHome(season, oppIdx, matchNum);

  final opponents = prog['seasonOpponents'];
  final opponentName = (opponents is List && oppIdx < opponents.length)
      ? '${opponents[oppIdx]}'
      : 'Opponent';

  final squad = _map(state['squad']);
  final rawLineup = squad?['lineup'];
  final lineup = (rawLineup is List && rawLineup.length == 11)
      ? [
          for (final s in rawLineup)
            if (s is Map<String, dynamic>) s,
        ]
      : null;
  final cells = _cells(state);
  final ratios = _map(state['definitionRatios']) ?? const {};
  final fatigue = _map(state['settings'])?['hardMode'] == true;

  final baseRating = computeSquadRating(
    cells,
    lineup: lineup?.length == 11 ? lineup : null,
    definitionRatios: ratios,
    fatigue: fatigue,
  );
  final baseRatings = computeSquadRatings(
    cells,
    lineup: lineup?.length == 11 ? lineup : null,
    definitionRatios: ratios,
    fatigue: fatigue,
  );

  final currentDiv = '${prog['currentDivision']}';
  // The Champions League has no promotion to escape by, so the buff would
  // accumulate for ever — it is skipped there entirely.
  final stagnationBuff = currentDiv == 'champions_cup'
      ? 0
      : _num(_map(prog['stagnationBuffs'])?[currentDiv])?.toInt() ?? 0;

  final secondHalf = matchNum >= opponentsPerSeason;
  final tablePos = _num(_map(prog['opponentTablePositions'])?[opponentName]);
  final oppInRelegationZone = secondHalf && tablePos != null && tablePos >= 7;
  final playerTablePos = _num(prog['playerTablePosition']);
  // Sunday League has no division below it, so its drop zone is one place
  // deeper — there is nowhere for the seventh-placed side to go.
  final playerRelegThreshold = div.id == 'sunday_league' ? 8 : 7;
  final playerInRelegationZone = secondHalf &&
      playerTablePos != null &&
      playerTablePos >= playerRelegThreshold;

  final ourFanZoneTier = fanZoneTier(_map(state['clubAssets']));
  final ourHomeAdv = isHome ? homeAdvantageFor(ourFanZoneTier) : 0;
  // An AI side uses its division's max asset tier as an implied stadium, so a
  // lower-division away day is gentler and a top-flight one is a fortress.
  final theirHomeAdv = isHome ? 0 : homeAdvantageFor(div.maxAssetTier);

  final relegationLift = playerInRelegationZone ? relegationBoost : 0;
  final effAttack =
      math.min(baseRatings.attack + ourHomeAdv, 100) + stagnationBuff + relegationLift;
  final effDefence =
      math.min(baseRatings.defence + ourHomeAdv, 100) + stagnationBuff + relegationLift;

  final effectiveSquadRating = effectiveMatchRating(
        baseRating,
        isHome: isHome,
        relegationZone: playerInRelegationZone,
        homeAdvDisplay: homeAdvantageDisplayFor(ourFanZoneTier),
      ) +
      stagnationBuff;

  final stored = _num(_map(prog['seasonOpponentRatings'])?['s${season}_o$oppIdx']);
  if (stored == null) {
    return FixturePreview(
      oppIdx: oppIdx,
      opponentName: opponentName,
      isHome: isHome,
      squadRating: baseRating,
      ourAttackRating: baseRatings.attack,
      ourDefenceRating: baseRatings.defence,
      effAttack: effAttack.toDouble(),
      effDefence: effDefence.toDouble(),
      effectiveSquadRating: effectiveSquadRating,
      ourHomeAdv: ourHomeAdv,
      theirHomeAdv: theirHomeAdv,
      playerInRelegationZone: playerInRelegationZone,
      oppInRelegationZone: oppInRelegationZone,
    );
  }

  var opponentRating = math.min(100, stored);
  // Read-only: the boot is applied without clearing the flag, unlike the sim.
  var bootApplied = false;
  if (_map(state['shop'])?['luckyBootReady'] == true) {
    final weakened = applyLuckyBoot(opponentRating);
    bootApplied = weakened < opponentRating;
    opponentRating = weakened;
  }

  // Read the grudge rather than consuming it — the sim decrements it.
  final grudgeBoost =
      _num(_map(_map(_map(state['transferMarket'])?['grudges'])?[opponentName])?['boost']) ?? 0;

  var effectiveOppRating = effectiveMatchRating(
    opponentRating,
    isHome: !isHome,
    relegationZone: oppInRelegationZone,
    homeAdvDisplay: homeAdvantageDisplayFor(div.maxAssetTier),
  );
  if (grudgeBoost > 0) effectiveOppRating += grudgeBoost;

  final oppAttackRatio = getOpponentAttackRatio(state, opponentName);
  final oppBase = opponentAtkDefFromShare(opponentRating, oppAttackRatio);
  var effOppAttack = math.min(100, oppBase.attack + theirHomeAdv).toDouble();
  var effOppDefence =
      math.max(10, math.min(100, oppBase.defence + theirHomeAdv)).toDouble();
  if (oppInRelegationZone) {
    effOppAttack += relegationBoost;
    effOppDefence += relegationBoost;
  }
  if (grudgeBoost > 0) {
    effOppAttack += grudgeBoost;
    effOppDefence += grudgeBoost;
  }

  return FixturePreview(
    oppIdx: oppIdx,
    opponentName: opponentName,
    isHome: isHome,
    squadRating: baseRating,
    ourAttackRating: baseRatings.attack,
    ourDefenceRating: baseRatings.defence,
    effAttack: effAttack.toDouble(),
    effDefence: effDefence.toDouble(),
    effectiveSquadRating: effectiveSquadRating,
    opponentRating: opponentRating,
    effectiveOppRating: effectiveOppRating,
    effOppAttackRating: effOppAttack,
    effOppDefenceRating: effOppDefence,
    oppAttackRatio: oppAttackRatio,
    grudgeBoost: grudgeBoost,
    ourHomeAdv: ourHomeAdv,
    theirHomeAdv: theirHomeAdv,
    playerInRelegationZone: playerInRelegationZone,
    oppInRelegationZone: oppInRelegationZone,
    bootApplied: bootApplied,
  );
}

List<CardInstance?> _cells(Map<String, dynamic>? state) {
  final cells = _map(state?['grid'])?['cells'];
  if (cells is! List) return const [];
  return [for (final c in cells) CardInstance.from(c)];
}
