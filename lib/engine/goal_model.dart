/// The goal model and injury curves, ported from
/// `../merge-empire-fc/src/engine/matchEngine.js`.
///
/// This is the arithmetic that decides matches, so it is the first target for
/// the differential harness: identical seeded inputs must produce identical
/// scorelines in Dart and node.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/squad_rating.dart' show winProbExponent;
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;

// ── Injuries ────────────────────────────────────────────────────────────────

/// Base injury chance per match, rolled against ONE randomly-picked healthy
/// player.
///
/// At 12% a fresh Sunday League squad picks up a knock roughly every 8 matches,
/// rising with age and division. Real clubs see one every 2-3 games; this sits
/// deliberately below that — injuries are friction, not the game — but high
/// enough that squads feel mortal. Merging resets seasons played, so most top
/// cards sit near the low end of the curve for a long time and the base has to
/// carry the load.
const double baseInjuryChance = 0.12;

/// Higher leagues are more physical, so the same card picks up knocks more
/// often at Champions Cup than at Sunday League. Linear from 1.0 to 1.7.
double divisionInjuryMultiplier([int divIdx = 0]) {
  final clamped = math.max(0, math.min(6, divIdx));
  return 1.0 + (1.7 - 1.0) * (clamped / 6);
}

/// Injury probability from seasons at the club times divisional intensity.
///
/// Linear rise to the peak at season 10, then a quadratic ramp after it:
/// Sunday League runs 12% fresh, ~20% at peak and ~36% by season 14; Champions
/// Cup runs ~20% fresh and caps at 55%.
double getInjuryChance([int seasonsPlayed = 0, int divIdx = 0]) {
  final prePeak = math.min(10, seasonsPlayed);
  final postPeak = math.max(0, seasonsPlayed - 10);
  final base = baseInjuryChance + 0.008 * prePeak + 0.010 * postPeak * postPeak;
  return math.min(0.55, base * divisionInjuryMultiplier(divIdx));
}

/// Injury duration in milliseconds, scaling with age and capped at an hour.
int getInjuryDuration([int seasonsPlayed = 0]) {
  const baseMs = 10 * 60 * 1000; // fresh players
  const perSeason = 5 * 60 * 1000;
  return math.min(60 * 60 * 1000, baseMs + seasonsPlayed * perSeason);
}

/// Deprecated in the JS, kept so any future caller does not silently break.
double retirementMultiplier(int seasonsPlayed) {
  final penalty = agingPenalty(seasonsPlayed);
  if (penalty == 0) return 1.0;
  return math.max(0.5, 1.0 - penalty / 100);
}

/// A side can field a match while it has this many healthy players.
bool hasEnoughPlayers(List<CardInstance?> gridCells) =>
    gridCells.where((c) => c != null && !c.injured).length >= minSquadPlayers;

// ── The goal model ──────────────────────────────────────────────────────────

/// Attack-versus-defence probability of two evenly-matched teams.
///
/// Both sides are built the same FIFA way, position-weighted so a team's ATK
/// and DEF both sit near its rating. So an even match pits ATK near rating
/// against DEF near rating, giving this anchor, which maps to
/// [evenMatchLambda]. Symmetric: both teams get the same even-match rate.
const double evenAttackProb = 0.47;

/// Expected goals per side for two evenly-matched teams over a full 90 —
/// about 2.7 total goals and ~25% draws, which are real-football averages.
const double evenMatchLambda = 1.35;

/// Curve above and below the even match.
///
/// The rate previously grew with a convex amplifier stacked on top of the
/// already-convex rating^4 term, so a small attack boost exploded into goals: a
/// weak side that shifted weight into attack more than DOUBLED its goals for a
/// modest defensive cost, making "throw everyone forward" a dominant underdog
/// exploit — the reverse of real football. At 1.0 the rate responds
/// PROPORTIONALLY to the attack/defence edge, so tactics redistribute strength
/// without manufacturing wins, and rating decides matches.
const double lambdaCurveExp = 1.0;

/// Blowout compression: above the even-match rate, lambda saturates smoothly
/// toward this cap, so a crushing edge means a clear 3-0 rather than uncapped
/// cricket scores. Still strictly increasing, so win-probability ordering is
/// untouched.
const double lambdaSoftCap = 2.8;

/// Keeps a hopeless underdog's rate from collapsing to nothing — real
/// relegation sides away at champions still average 0.3 to 0.5 goals — while
/// keeping mismatches one-sided.
const double lambdaFloor = 0.12;

/// The most volatile the dial can be made, derived from the tactics rather than
/// written down so a new tactic cannot quietly invalidate it.
final double maxMatchVariance = strategies.values.fold<double>(
  1,
  (m, s) => math.max(m, s.variance * (1 + s.swing)),
);

/// The most goals a match can be EXPECTED to produce for one side.
///
/// NOT a hard ceiling on any single scoreline — the sampler is Poisson and its
/// tail is unbounded. It IS the right yardstick over several matches, which is
/// what the quest engine uses it for: "could a season quest asking for N more
/// goals still be finished in the fixtures left" is answered by the best rate
/// the sim can be made to run at, not by one lucky afternoon.
final double maxGoalRate = lambdaSoftCap * maxMatchVariance;

/// Expected goals for an attacker rating against a defender rating, over a full
/// 90 minutes.
///
/// A Bradley-Terry attack probability drives the rate, normalised so two evenly
/// matched teams yield [evenMatchLambda], with growth above that softly capped
/// so mismatches win by realistic margins.
double goalRateLambda(num attackerRating, num defenderRating) {
  final a = math.pow(math.max(1, attackerRating), winProbExponent);
  final b = math.pow(math.max(1, defenderRating), winProbExponent);
  final attackProb = a / (a + b);

  final raw =
      evenMatchLambda *
      math.pow(attackProb / evenAttackProb, lambdaCurveExp).toDouble();

  if (raw <= evenMatchLambda) return math.max(lambdaFloor, raw);

  const span = lambdaSoftCap - evenMatchLambda;
  return evenMatchLambda +
      span * (1 - math.exp(-(raw - evenMatchLambda) / span));
}

/// Samples a goal count from a Poisson distribution with mean [lambda], using
/// Knuth's algorithm.
///
/// Used for partial-window re-simulation where the rate has already been scaled
/// to the remaining minutes — sampling at the window's own rate keeps a late
/// burst rare-but-possible, instead of sampling a full-match count and flooring
/// it, which made two goals in twenty minutes impossible.
///
/// Draws from the SEEDED stream: this is the core gameplay randomness the
/// differential harness compares.
int poissonGoals(double lambda) {
  final l = math.exp(-math.max(0, lambda));
  var k = 0;
  var p = 1.0;
  do {
    k++;
    p *= seeded.random();
  } while (p > l);
  return k - 1;
}

/// Goals scored in a FRACTION of a match, sampled at the window's own rate.
///
/// Shared by the Casual-mode injury split, remainder re-simulation and cup ties
/// so every partial window uses identical maths.
int sampleWindowGoals(
  num attackerRating,
  num defenderRating,
  double fraction, [
  double variance = 1.0,
]) => poissonGoals(
  goalRateLambda(attackerRating, defenderRating) *
      math.max(0, fraction) *
      variance,
);

/// Independently simulates goals for an attacker against a defender over a full
/// match. Called twice per match: once for goals scored, once for conceded.
///
/// Sampled straight from the Poisson. The old discrete-bucket ladder overshot
/// its own lambda bands — the 1.6-2.0 bucket averaged 2.16 goals — inflating
/// scorelines and amplifying the underdog attack exploit. Poisson is exact by
/// construction and matches the partial-window sampler used everywhere else.
int simulateGoals(
  num attackerRating,
  num defenderRating, [
  double variance = 1.0,
]) => poissonGoals(goalRateLambda(attackerRating, defenderRating) * variance);

/// Anything past this many goals is negligible at the soft cap — the tail is
/// below 1e-4 at the highest rate the sim can run — so truncating costs nothing
/// and keeps the scorer allocation-free enough to run on every render.
const int scoreTail = 11;

/// Poisson probability mass for mean [lambda], from zero to [scoreTail] - 1.
List<double> poissonPmf(double lambda) {
  final l = math.max(0.0, lambda);
  final out = List<double>.filled(scoreTail, 0);
  var p = math.exp(-l);
  out[0] = p;
  for (var k = 1; k < scoreTail; k++) {
    p = p * l / k;
    out[k] = p;
  }
  return out;
}

/// One kick in a shootout.
typedef PenaltyKick = ({
  String team,
  bool scored,
  int homeTotal,
  int awayTotal,
  bool suddenDeath,
});

/// How a shootout finished.
typedef Shootout = ({
  bool playerWins,
  List<PenaltyKick> kicks,
  int homeScore,
  int awayScore,
});

/// A penalty shootout, kick by kick.
///
/// About a 75% conversion rate for evenly matched sides, scaling with the
/// attack-against-defence mismatch. Every input is floored at one so sudden
/// death can never loop for ever on a zeroed rating.
Shootout simulatePenaltyShootout(
  num ourAttack,
  num ourDefence,
  num oppAttack,
  num oppDefence,
) {
  final oa = math.max(1, ourAttack);
  final od = math.max(1, oppDefence);
  final pa = math.max(1, oppAttack);
  final pd = math.max(1, ourDefence);
  final ourProb = 0.55 + 0.4 * (oa / (oa + od));
  final oppProb = 0.55 + 0.4 * (pa / (pa + pd));

  var homeScore = 0;
  var awayScore = 0;
  final kicks = <PenaltyKick>[];

  for (var round = 0; round < 5; round++) {
    final homeScored = seeded.random() < ourProb;
    if (homeScored) homeScore++;
    kicks.add((
      team: 'home',
      scored: homeScored,
      homeTotal: homeScore,
      awayTotal: awayScore,
      suddenDeath: false,
    ));

    // The away side has (5 - round) kicks left at this point; the home side has
    // (4 - round). Either total being out of reach ends it here.
    if (homeScore > awayScore + (5 - round)) break;
    if (awayScore > homeScore + (4 - round)) break;

    final awayScored = seeded.random() < oppProb;
    if (awayScored) awayScore++;
    kicks.add((
      team: 'away',
      scored: awayScored,
      homeTotal: homeScore,
      awayTotal: awayScore,
      suddenDeath: false,
    ));

    if (homeScore > awayScore + (4 - round)) break;
    if (awayScore > homeScore + (4 - round)) break;
  }

  // Sudden death: BOTH sides kick every round. The tie is only settled once the
  // away team has answered — breaking early on a home goal would hand them the
  // win without the away side getting their go.
  while (homeScore == awayScore) {
    final homeScored = seeded.random() < ourProb;
    if (homeScored) homeScore++;
    kicks.add((
      team: 'home',
      scored: homeScored,
      homeTotal: homeScore,
      awayTotal: awayScore,
      suddenDeath: true,
    ));

    final awayScored = seeded.random() < oppProb;
    if (awayScored) awayScore++;
    kicks.add((
      team: 'away',
      scored: awayScored,
      homeTotal: homeScore,
      awayTotal: awayScore,
      suddenDeath: true,
    ));
  }

  return (
    playerWins: homeScore > awayScore,
    kicks: kicks,
    homeScore: homeScore,
    awayScore: awayScore,
  );
}
