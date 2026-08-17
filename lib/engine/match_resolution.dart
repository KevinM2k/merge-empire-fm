/// The core of a match: turning two squads' ATK/DEF into a scoreline.
///
/// Extracted from `simulateMatch` in
/// `../merge-empire-fc/src/engine/matchEngine.js`. The full orchestration also
/// consumes grudges, settles loans and resolves quests; this is the arithmetic
/// underneath, split out because it is the piece the differential harness
/// compares and the piece every other match path reuses.
///
/// The shape is symmetric and deliberately so:
///
///     our goals   = f(our ATK,   their DEF)
///     their goals = f(their ATK, our DEF)
///
/// Both directions are sampled independently at their own rate, with home
/// advantage, stagnation, relegation resilience and the tactic multipliers
/// folded into the ratings BEFORE they reach the goal model.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/engine/goal_model.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';

/// A finished scoreline. `home` is ALWAYS the player's goals and `away` always
/// the opponent's — being home or away affects the advantage bonus and the
/// display order, never which variable holds whose goals.
typedef Scoreline = ({int home, int away});

/// The two sides' ratings once every modifier has been applied.
typedef MatchRatings = ({
  double ourAttack,
  double ourDefence,
  double oppAttack,
  double oppDefence,
});

/// Folds the pre-kickoff modifiers into a squad's ATK/DEF.
///
/// Home advantage is added BEFORE the 100 cap and the stagnation and
/// relegation bonuses after it, matching the JS — so a maxed side at home can
/// still be lifted past 100 by the buffs it has earned, while the crowd alone
/// cannot.
({double attack, double defence}) applySquadModifiers({
  required num baseAttack,
  required num baseDefence,
  int homeAdv = 0,
  double stagnation = 0,
  bool relegationZone = false,
}) {
  final releg = relegationZone ? relegationBoost : 0;
  return (
    attack: math.min(baseAttack + homeAdv, 100) + stagnation + releg,
    defence: math.min(baseDefence + homeAdv, 100) + stagnation + releg,
  );
}

/// Folds the opponent's modifiers in.
///
/// Their defence carries a floor of 10 that ours does not: a side with no
/// defence at all would hand the player an unbounded rate through the lambda
/// curve.
({double attack, double defence}) applyOpponentModifiers({
  required num baseAttack,
  required num baseDefence,
  int homeAdv = 0,
  bool relegationZone = false,
  double grudgeBoost = 0,
}) {
  var attack = math.min(100, baseAttack + homeAdv).toDouble();
  var defence = math.max(10, math.min(100, baseDefence + homeAdv)).toDouble();

  if (relegationZone) {
    attack += relegationBoost;
    defence += relegationBoost;
  }
  if (grudgeBoost > 0) {
    attack += grudgeBoost;
    defence += grudgeBoost;
  }
  return (attack: attack, defence: defence);
}

/// Applies the chosen tactic to our own ratings, flooring at 1.
///
/// The opponent's ratings are never touched by our tactic: parking the bus
/// raises OUR defence against their unchanged attack, which is what makes them
/// score less.
({double attack, double defence}) applyTactic({
  required num attack,
  required num defence,
  required Strategy? strategy,
  double? oppAttackRatio,
}) => (
  attack: math.max(1, applyTacticAtk(attack, strategy, oppAttackRatio)),
  defence: math.max(1, applyTacticDef(defence, strategy, oppAttackRatio)),
);

/// The match variance actually used: the tactic's tempo times its hot/cold
/// swing, rolled once per simulation.
double rollMatchVariance(Strategy? strategy) =>
    (strategy?.variance ?? 1.0) * rollSwingFactor(strategy);

/// Resolves a full match from both sides' adjusted ratings.
///
/// Two independent samples, in this order — which matters, because they draw
/// from the shared seeded stream in sequence.
Scoreline resolveScoreline(MatchRatings r, {double variance = 1.0}) {
  final home = simulateGoals(r.ourAttack, r.oppDefence, variance);
  final away = simulateGoals(r.oppAttack, r.ourDefence, variance);
  return (home: home, away: away);
}

/// One window of a match, for the segmented paths.
typedef MatchWindow = ({double upToMinute, MatchRatings ratings});

/// Resolves a match in segments, re-rating between them.
///
/// This is the Casual-mode injury path: play a full-strength window up to the
/// injury minute, apply it — the victim leaves a hole in the XI — recompute,
/// and continue. It mirrors the Pro-mode man-down segments, so a skipped match
/// costs the same as a watched one.
///
/// Each window is sampled at its OWN rate rather than by scaling a full-match
/// count, which is what keeps a late burst rare-but-possible.
Scoreline resolveSegmented(
  List<MatchWindow> windows, {
  double variance = 1.0,
  double fullMatchMinutes = 90,
}) {
  var home = 0;
  var away = 0;
  var prevMin = 0.0;

  for (final w in windows) {
    final frac = math.max(0.0, (w.upToMinute - prevMin) / fullMatchMinutes);
    home += poissonGoals(
      goalRateLambda(w.ratings.ourAttack, w.ratings.oppDefence) * frac * variance,
    );
    away += poissonGoals(
      goalRateLambda(w.ratings.oppAttack, w.ratings.ourDefence) * frac * variance,
    );
    prevMin = w.upToMinute;
  }

  return (home: home, away: away);
}

/// How a finished match reads.
typedef MatchOutcome = ({bool won, bool drawn, bool lost});

MatchOutcome outcomeOf(Scoreline score) => (
  won: score.home > score.away,
  drawn: score.home == score.away,
  lost: score.home < score.away,
);

/// The tutorial's guaranteed first win, applied BEFORE events are generated so
/// commentary and player stats stay consistent with the final score.
Scoreline forceWin(Scoreline score) =>
    score.home > score.away ? score : (home: score.away + 1, away: score.away);
