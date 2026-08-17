/// What the coach recommends, and what it costs. Ported from the tactic-scoring
/// block of `../merge-empire-fc/src/engine/matchEngine.js`.
///
/// Split from `match_tactics.dart` by what it reads: that file is the tactic
/// TABLE and the pure multiplier arithmetic every screen shares, this one scores
/// those tactics against a matchup and a squad, so it reaches for the goal model,
/// the trait engine and the save. Keeping the table free of that lets the ATK/DEF
/// readouts import it without dragging the whole engine graph in behind them.
///
/// Nothing here draws a random number. The coach's claim is that it and the
/// simulation cannot disagree, and it earns that by computing expected points
/// EXACTLY from the two independent Poissons the sim samples — no Monte Carlo,
/// so there is nothing for the two to be inconsistent about.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/goal_model.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/player_rating.dart';
import 'package:merge_empire_fc/engine/sponsor_engine.dart';
import 'package:merge_empire_fc/engine/squad_rating.dart';
import 'package:merge_empire_fc/engine/trait_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/sorting.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// Descending by value, the way JS `sort((a, b) => b - a)` orders.
///
/// Written as a sign test rather than `compareTo` on purpose: Dart's
/// `compareTo` separates `0.0` from `-0.0`, which would reorder tactics that
/// actually score identically and lose the stable ordering the reference has.
int _byDescending(double a, double b) => a == b ? 0 : (b > a ? 1 : -1);

/// Expected league points from one match under [strat], computed exactly from
/// the two independent Poissons the simulation samples.
///
/// The ratings passed in are PRE-tactic and already carry home advantage,
/// stagnation and the relegation boost, exactly as the simulation assembles
/// them; the tactic's multipliers and the same floor of 1 are applied here.
///
/// A tactic's swing is a mean-preserving 50/50 lottery over the whole match, so
/// it is scored as the average of its hot and cold branches rather than at its
/// mean — averaging first would price Counter Attack as if its gamble never
/// happened, which is the entire identity of the tactic.
///
/// League semantics: a draw scores 1. A cup tie, where a draw goes to
/// penalties, is a different objective and this is not it.
double tacticExpectedPoints(
  num ourAtk,
  num ourDef,
  num oppAtk,
  num oppDef,
  Strategy? strat, {
  double fraction = 1,
  int margin = 0,
  double? oppAttackRatio,
}) {
  final a = math.max(1.0, applyTacticAtk(ourAtk, strat, oppAttackRatio));
  final d = math.max(1.0, applyTacticDef(ourDef, strat, oppAttackRatio));
  final f = math.max(0.0, fraction);
  final baseUs = goalRateLambda(a, oppDef) * f;
  final baseThem = goalRateLambda(oppAtk, d) * f;

  final s = strat?.swing ?? 0;
  final branches = s != 0 ? <double>[1 - s, 1 + s] : const <double>[1];

  var pts = 0.0;
  for (final swing in branches) {
    final v = (strat?.variance ?? 1) * swing;
    final us = poissonPmf(baseUs * v);
    final them = poissonPmf(baseThem * v);
    // The final margin is the goals already on the board plus what is still to
    // come, which is what makes this work mid-match as well as before kickoff.
    var win = 0.0;
    var draw = 0.0;
    for (var i = 0; i < scoreTail; i++) {
      for (var j = 0; j < scoreTail; j++) {
        final finalMargin = margin + i - j;
        if (finalMargin > 0) {
          win += us[i] * them[j];
        } else if (finalMargin == 0) {
          draw += us[i] * them[j];
        }
      }
    }
    pts += (3 * win + draw) / branches.length;
  }
  return pts;
}

/// Bench depth a risky tactic demands before the coach will offer it.
///
/// A veto over the ranking rather than a term inside it: this is a squad-depth
/// judgement, not a match-odds one.
const Map<String, int> tacticMinBenchCover = {'highPress': 2, 'allOutAttack': 1};

/// How much match must be LEFT before protecting a lead stops being football
/// and starts being an exploit.
///
/// Expected points alone will happily park the bus from the first minute: once
/// you are ahead every remaining minute is pure downside, so the maths says kill
/// the game for eighty-nine of them. That is exactly the degenerate the tactic
/// table was designed to remove, and no manager alive would say it out loud. The
/// objective is not wrong, it just does not know what a football match looks
/// like — so the SHAPE of the advice is constrained here rather than by bending
/// the goal model.
const double leadProtectFraction = 1 / 3;

/// Tactics whose whole point is killing the game off.
bool _isShutUpShop(String id) => (strategies[id]?.defMult ?? 1) > 1;

/// How many further matches a knock is felt in, beyond the one it happens in.
///
/// Injuries heal on a ten-to-sixty minute real-time clock, so a knock typically
/// costs part of the next game and no more. The whole injury term scales
/// linearly with this.
const double injuryFutureMatches = 1.0;

/// What one injury costs THIS squad, in expected league points.
///
/// The point of computing it rather than assuming it: the cost of losing a
/// player is almost entirely a question of who replaces him. A deep bench makes
/// a knock nearly free and a high-risk tactic worth its price; eleven players
/// and nothing behind them makes the same knock ruinous. That is the difference
/// the coach is supposed to be weighing, and a fixed number cannot express it.
///
/// Two parts, because an injury is felt twice: the rest of THIS match with a
/// hole in the XI (there is no auto-sub, so the slot really is empty unless the
/// manager acts), and the matches after it with the best cover the bench can
/// offer — which is where squad depth actually shows up.
///
/// Averaged over which starter goes off, since that is a coin toss at roll time,
/// and scored under Balanced so the cost of an injury does not depend on the
/// tactic being priced by it.
double injuryCostPoints(
  Map<String, dynamic>? state,
  num oppAtk,
  num oppDef, {
  double fraction = 1,
  int margin = 0,
}) {
  final rawLineup = _map(state?['squad'])?['lineup'];
  if (rawLineup is! List || rawLineup.length != 11) return 0;
  final lineup = [
    for (final s in rawLineup)
      if (s is Map<String, dynamic>) s,
  ];
  if (lineup.length != 11) return 0;

  final cells = _cells(state);
  final ratios = _map(state?['definitionRatios']) ?? const {};
  final ref = strategies['balanced'];

  double pts(TeamSplit split, double frac, int marg) => tacticExpectedPoints(
    split.attack,
    split.defence,
    oppAtk,
    oppDef,
    ref,
    fraction: frac,
    margin: marg,
  );

  TeamSplit split(List<Map<String, dynamic>> xi) =>
      computeSquadRatings(cells, lineup: xi, definitionRatios: ratios);

  final ptsRest = pts(split(lineup), fraction, margin);
  final ptsNext = pts(split(lineup), 1, 0);

  final inXI = {
    for (final s in lineup)
      if (s['cardInstanceId'] != null) s['cardInstanceId'],
  };
  final bench = [
    for (final c in cells)
      if (c != null &&
          !c.injured &&
          !c.isUnavailable &&
          !inXI.contains(c.instanceId))
        c,
  ];

  var total = 0.0;
  var counted = 0;
  for (var i = 0; i < lineup.length; i++) {
    if (lineup[i]['cardInstanceId'] == null) continue;

    // The rest of this match: the slot is simply vacant.
    final vacated = [
      for (var j = 0; j < lineup.length; j++)
        if (j == i) {...lineup[j], 'cardInstanceId': null} else lineup[j],
    ];
    final nowCost = ptsRest - pts(split(vacated), fraction, margin);

    // Afterwards: whoever on the bench fits that slot best steps in. An empty
    // string for a slot with no position reads the same way the JS `undefined`
    // does — never equal to a real position, and never the keeper's.
    final slotPos = lineup[i]['slotPosition'] as String? ?? '';
    CardInstance? best;
    var bestVal = -1.0;
    for (final b in bench) {
      final def = getPlayerDef(b.definitionId);
      if (def == null) continue;
      final v = getEffectiveRating(b) *
          (1 - computePositionPenalty(def.position, slotPos));
      if (v > bestVal) {
        bestVal = v;
        best = b;
      }
    }
    final covered = [
      for (var j = 0; j < lineup.length; j++)
        if (j == i)
          {...lineup[j], 'cardInstanceId': best?.instanceId}
        else
          lineup[j],
    ];
    final laterCost = ptsNext - pts(split(covered), 1, 0);

    total +=
        math.max(0.0, nowCost) + math.max(0.0, laterCost) * injuryFutureMatches;
    counted++;
  }
  return counted > 0 ? total / counted : 0;
}

/// The chance this match produces an injury, BEFORE the tactic's multiplier.
///
/// Averaged over the XI, since the simulation rolls on a randomly-picked healthy
/// player. Squad-wide trait reduction and per-card sponsor penalties are folded
/// in, so a squad built to stay fit is correctly cheaper to gamble with.
double baselineInjuryRisk(Map<String, dynamic>? state, [String? divisionId]) {
  final cells = _cells(state);
  final prog = _map(state?['progression']);
  final rawLineup = _map(state?['squad'])?['lineup'];
  final lineup = [
    if (rawLineup is List)
      for (final s in rawLineup)
        if (s is Map<String, dynamic>) s,
  ];

  final div = getDivision('${divisionId ?? prog?['currentDivision']}');
  final divIdx = math.max(0, divisions.indexWhere((d) => d.id == div.id));

  final inXI = {
    for (final s in lineup)
      if (s['cardInstanceId'] != null) s['cardInstanceId'],
  };
  final pool = [
    for (final c in cells)
      if (c != null &&
          !c.injured &&
          (inXI.isEmpty || inXI.contains(c.instanceId)))
        c,
  ];
  if (pool.isEmpty) return 0;

  final squadRed = computeSquadTraitTotals(cells, lineup).teamInjuryReduction;
  var sum = 0.0;
  for (final c in pool) {
    var chance = getInjuryChance(c.seasonsPlayed, divIdx);
    chance += sponsorDrawback(_map(c.sponsor)).injuryPenalty;
    chance -= getTraitBonus(c, getPlayerDef(c.definitionId)?.position)
        .injuryReduction;
    chance -= squadRed;
    sum += math.max(0.0, chance);
  }
  return sum / pool.length;
}

/// One tactic's score in a ranking.
class RankedTactic {
  const RankedTactic({
    required this.id,
    required this.points,
    required this.injuryPenalty,
    required this.expectedPoints,
  });

  final String id;

  /// Expected league points on match odds alone.
  final double points;

  /// What this tactic's injury exposure is worth to this squad, in points.
  final double injuryPenalty;

  /// [points] net of [injuryPenalty] — what the ranking actually sorts on.
  final double expectedPoints;
}

/// What the coach would do, and whether the squad talked it out of it.
class TacticSuggestion {
  const TacticSuggestion({
    required this.id,
    required this.expectedPoints,
    required this.ranked,
    required this.thinSquad,
    required this.heldOffSittingBack,
  });

  final String id;
  final double expectedPoints;

  /// Every tactic, best first.
  final List<RankedTactic> ranked;

  /// "We'd go after them, but we can't afford a knock" — true when the injury
  /// economics, or the hard depth floor, moved the pick off what the odds alone
  /// wanted.
  final bool thinSquad;

  /// The advice would have been to kill the game off, and it is too early for
  /// that to be football.
  final bool heldOffSittingBack;
}

/// Rank every tactic for a matchup and return the best.
///
/// This replaces a hand-written branch table that keyed off two booleans — can
/// we score on them, can they score on us — and recommended All Out Attack to
/// "exploit" the gap whenever the first was true and the second false. That
/// advice invalidated its own premise: the second was measured on the PRE-tactic
/// defence, which All Out Attack then multiplies by 0.82.
///
/// The deeper reason a table cannot work here is that [goalRateLambda] saturates
/// toward the soft cap above the even-match rate, so a favourite's attacking
/// upside is already capped while the defensive downside is not. Whether a
/// tactic pays therefore depends on where on that curve the matchup sits, which
/// is what scoring it directly answers and a threshold cannot.
///
/// [fraction] (how much match is left) and [margin] (our goals minus theirs so
/// far) make this work mid-match too. Chasing is NOT a special case bolted on
/// top: league points already encode it, because a draw is worth 1 and a defeat
/// 0. Two down with ten minutes left, throwing everyone forward maximises
/// expected points on its own — there is almost nothing left to lose — and the
/// same arithmetic shuts the game down when protecting a lead.
TacticSuggestion suggestTactic(
  num ourAtk,
  num ourDef,
  num oppAtk,
  num oppDef, {
  double benchCover = double.infinity,
  double fraction = 1,
  int margin = 0,
  double injuryRisk = 0,
  double injuryCost = 0,
  double? oppAttackRatio,
}) {
  // Expected points MINUS what the tactic's injury exposure is worth to this
  // squad. Both halves are real points, so they compare directly rather than
  // one of them being a veto bolted onto the other.
  final scored = [
    for (final s in strategies.values)
      () {
        final points = tacticExpectedPoints(
          ourAtk,
          ourDef,
          oppAtk,
          oppDef,
          s,
          fraction: fraction,
          margin: margin,
          oppAttackRatio: oppAttackRatio,
        );
        final risk = injuryRisk * s.injMod * math.max(0.0, fraction);
        final penalty = risk * injuryCost;
        return RankedTactic(
          id: s.id,
          points: points,
          injuryPenalty: penalty,
          expectedPoints: points - penalty,
        );
      }(),
  ];
  final ranked = stableSorted(
    scored,
    (a, b) => _byDescending(a.expectedPoints, b.expectedPoints),
  );

  // Ranking on match odds alone, so callers can see whether the injury
  // economics changed the answer — that is what "we can't risk it" means.
  final onOddsAlone =
      stableSorted(ranked, (a, b) => _byDescending(a.points, b.points)).first;

  // Hard floor for a squad that cannot absorb a knock at all. The cost term
  // above does the nuanced work; this only catches the genuinely desperate,
  // where losing anyone means finishing with ten.
  final affordable = [
    for (final e in ranked)
      if ((strategies[e.id]?.injMod ?? 1) <= 1 ||
          benchCover >= (tacticMinBenchCover[e.id] ?? 0))
        e,
  ];

  // Too early to be killing the game off. Lifted when they are actually
  // outgunning us — a side under the cosh defends because it has to, not
  // because it is ahead.
  final tooEarlyToSitBack =
      margin > 0 && fraction > leadProtectFraction && oppAtk <= ourDef;
  final allowed = tooEarlyToSitBack
      ? [
          for (final e in affordable)
            if (!_isShutUpShop(e.id)) e,
        ]
      : affordable;

  final best = allowed.isNotEmpty
      ? allowed.first
      : (affordable.isNotEmpty ? affordable.first : ranked.first);
  return TacticSuggestion(
    id: best.id,
    expectedPoints: best.expectedPoints,
    ranked: ranked,
    thinSquad: best.id != onOddsAlone.id &&
        (strategies[onOddsAlone.id]?.injMod ?? 1) > 1,
    heldOffSittingBack: tooEarlyToSitBack &&
        _isShutUpShop((affordable.isNotEmpty ? affordable.first : ranked.first).id),
  );
}

List<CardInstance?> _cells(Map<String, dynamic>? state) {
  final cells = _map(state?['grid'])?['cells'];
  if (cells is! List) return const [];
  return [for (final c in cells) CardInstance.from(c)];
}
