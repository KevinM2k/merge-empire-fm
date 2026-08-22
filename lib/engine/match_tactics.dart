/// Match constants, formation splits and the tactic system, ported from the
/// first third of `../merge-empire-fc/src/engine/matchEngine.js`.
///
/// Split out because matchEngine is 2,700 lines: this half holds the numbers
/// and the pure functions over them, and the simulation reads from it.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;

const int minSquadPlayers = 3;

/// An 8-team league (7 AI opponents plus the player) played as a round-robin
/// with home and away legs.
const int opponentsPerSeason = 7;
const int matchesPerSeason = opponentsPerSeason * 2;

/// Legacy flat home bonus, still used for AI-vs-AI background fixtures.
/// Player-facing matches use [homeAdvantageFor], which scales with the Fan Zone
/// — a Sunday League touchline with three mates and a dog is not the Kop.
const int homeAdvantage = 2;
const int homeAdvantageDisplay = homeAdvantage * 2;

/// Home advantage scaled by Fan Zone tier: +1 with no Fan Zone, +4 at max.
///
/// This is the number on the "Home +N" pill, added in full to BOTH ATK and DEF.
/// Because team star is the FIFA blend of ATK/DEF — translation-invariant —
/// adding +N to both raises the star by exactly +N too, so the pill, the
/// ATK/DEF rows and the star all move by the same amount.
int homeAdvantageDisplayFor([int fanTier = 0]) =>
    ((1 + (3 * math.max(0, math.min(8, fanTier))) / 8) + 0.5).floor();

/// The per-stat bonus — identical to the pill value, kept as a separate name
/// for call sites that read "per-stat".
int homeAdvantageFor([int fanTier = 0]) => homeAdvantageDisplayFor(fanTier);

/// Relegation-zone resilience: the bottom two get a tiny boost so they are not
/// total pushovers. Deliberately modest — they are bad teams.
const double relegationBoost = 1.0;

/// The Lucky Boot's bite, as a PROPORTION of the opponent's rating.
///
/// It was a flat -10, which cannot work across a 20-to-100 scale: ten points is
/// a tenth off a Champions League side and nearly half off a Sunday League one.
/// A fifth off lands the same way at every level, which is what "plays far
/// below their level" has to mean in a game with seven divisions.
const double luckyBootPct = 0.20;

/// Retained for copy that quotes a number. Derived, so it cannot drift.
final int luckyBootReduction = (luckyBootPct * 100 + 0.5).floor();

/// How far the Lucky Boot floors an opponent. TEN, not twenty.
///
/// Every call site used to clamp at 20 — and 20 is the BOTTOM of the rating
/// scale, so a "far below their level" item took a 22-rated side to 20, i.e.
/// did nothing, in the division where a new player is most likely to buy it.
const int luckyBootFloor = 1;

/// Weakens an opponent's rating.
///
/// One helper, used by the league sim, the cup sim and every screen that
/// displays an opponent — a display and a simulation disagreeing about what a
/// team is rated is precisely the bug this replaced.
///
/// The min is the invariant, not a nicety: every call site used to clamp with
/// `max(20, rating - 10)`, so a 12-rated opponent came out at TWENTY. The
/// weakest teams got STRONGER when you spent on making them worse. A weakening
/// effect must never raise a number.
int applyLuckyBoot(num rating) => math.min(
  rating.round(),
  math.max(luckyBootFloor, (rating * (1 - luckyBootPct) + 0.5).floor()),
);

/// Each slot position contributes differently to attacking versus defensive
/// rating. Normalised by their own sums so both stay on the same 0-100 scale.
const Map<String, double> attackWeights = {
  'GK': 0.00,
  'DEF': 0.15,
  'MID': 0.50,
  'FWD': 0.85,
};

const Map<String, double> defenceWeights = {
  'GK': 1.00,
  'DEF': 0.85,
  'MID': 0.50,
  'FWD': 0.15,
};

/// Personality bias scale: plus or minus 12 rating points at maximum bias.
const double biasScale = 12;

/// Default ATK share for a balanced opponent.
const double oppBaseAtkShare = 0.45;

/// Legacy, used only when converting old saves that stored attackBias.
const double oppBiasShare = 0.17;

/// Player positions' typical attack share — the ratio-range midpoints.
const Map<String, double> _posRatio = {
  'GK': 0.025,
  'DEF': 0.20,
  'MID': 0.50,
  'FWD': 0.80,
};

/// AI formations as position lists.
///
/// The AI fields a real shape, and its team ATK/DEF are the average of eleven
/// per-position FIFA splits at the team's rating — the SAME maths the player's
/// squad runs. So an AI team and a player squad of equal rating and shape read
/// identical ATK/DEF.
const Map<String, List<String>> aiFormationPositions = {
  '3-4-3': ['GK', 'DEF', 'DEF', 'DEF', 'MID', 'MID', 'MID', 'MID', 'FWD', 'FWD', 'FWD'],
  '4-3-3': ['GK', 'DEF', 'DEF', 'DEF', 'DEF', 'MID', 'MID', 'MID', 'FWD', 'FWD', 'FWD'],
  '4-4-2': ['GK', 'DEF', 'DEF', 'DEF', 'DEF', 'MID', 'MID', 'MID', 'MID', 'FWD', 'FWD'],
  '5-3-2': ['GK', 'DEF', 'DEF', 'DEF', 'DEF', 'DEF', 'MID', 'MID', 'MID', 'FWD', 'FWD'],
  '5-4-1': ['GK', 'DEF', 'DEF', 'DEF', 'DEF', 'DEF', 'MID', 'MID', 'MID', 'MID', 'FWD'],
};

/// Maps a bare attack share onto the closest real formation. Thresholds are the
/// midpoints between the formations' own average shares.
String formationForShare(double share) {
  if (share >= 0.444) return '3-4-3';
  if (share >= 0.416) return '4-3-3';
  if (share >= 0.389) return '4-4-2';
  if (share >= 0.362) return '5-3-2';
  return '5-4-1';
}

/// A team's ATK and DEF.
typedef TeamSplit = ({int attack, int defence});

/// Team ATK/DEF for an AI side of [rating] playing [formationId].
TeamSplit teamSplitForFormation(num rating, String? formationId) {
  final positions =
      aiFormationPositions[formationId] ?? aiFormationPositions['4-4-2']!;

  var aNum = 0.0;
  var aDen = 0.0;
  var dNum = 0.0;
  var dDen = 0.0;

  for (final pos in positions) {
    final s = getCardAtkDefSplit(_posRatio[pos], rating);
    final aw = attackWeights[pos] ?? 0.5;
    final dw = defenceWeights[pos] ?? 0.5;
    aNum += s.attack * aw;
    aDen += aw;
    dNum += s.defence * dw;
    dDen += dw;
  }

  return (
    attack: (aNum / aDen + 0.5).floor(),
    defence: (dNum / dDen + 0.5).floor(),
  );
}

/// Opponent ATK/DEF from an overall rating and a formation id.
///
/// These are the FIFA-style team numbers the sim runs on — they do not sum to
/// the rating, they sit around it.
TeamSplit opponentAtkDef(num rating, [String formation = '4-4-2']) {
  final formationId = aiFormationPositions.containsKey(formation)
      ? formation
      : formationForShare(oppBaseAtkShare);
  return teamSplitForFormation(rating, formationId);
}

/// Opponent ATK/DEF from a legacy bare attack share.
TeamSplit opponentAtkDefFromShare(num rating, double share) =>
    teamSplitForFormation(rating, formationForShare(share));

/// A tactic on the dial.
///
/// `atkMult` and `defMult` are MULTIPLIERS on YOUR attack and defence
/// independently. The opponent's ratings are never changed by your tactic — if
/// their attack is 70 and you park the bus, YOUR defence goes up, so they score
/// less.
///
/// Multipliers rather than flat points so the swing scales with squad quality:
/// a Champions League side going all out shifts ~16 rating points, a Sunday
/// League side only ~4 — a weak team simply lacks the tactical ceiling.
///
/// Tactics are ZERO-SUM on composite rating: `atkMult + defMult == 2` for every
/// tactic, High Press included, and a test pins it. A tactic redistributes
/// strength, it does not create it.
class Strategy {
  const Strategy({
    required this.id,
    required this.name,
    required this.shortName,
    required this.icon,
    required this.atkMult,
    required this.defMult,
    required this.injMod,
    required this.possession,
    required this.variance,
    required this.swing,
    this.commitmentGain = 0,
    required this.hint,
  });

  final String id;
  final String name;
  final String shortName;
  final String icon;
  final double atkMult;
  final double defMult;
  final double injMod;

  /// Cosmetic display percentage in the live stats bar.
  final int possession;

  /// Tempo: multiplies goal RATES both ways. Above 1 is an open game with more
  /// goals for AND against; below 1 strangles it.
  final double variance;

  /// A mean-preserving lottery: the whole match runs hot or cold at 50/50, so
  /// average goals stay the same but outcomes spread.
  final double swing;

  /// Counter Attack's read on how committed forward the opponent is.
  final double commitmentGain;

  final String hint;
}

/// The five tactics.
///
/// The two attacking options are split by WHICH KIND of risk they buy. High
/// Press is the biggest attacking shift at ordinary tempo, priced in bodies
/// (1.55x injuries, 1.6x fatigue) — for a squad with a bench deep enough to
/// absorb a knock. All Out Attack is a smaller shift at the highest tempo,
/// buying CHAOS rather than strength, which is what you want when behind and
/// needing the game stretched, and it costs far less in injuries.
const Map<String, Strategy> strategies = {
  'balanced': Strategy(
    id: 'balanced', name: 'Balanced', shortName: 'Balanced', icon: '⚖️',
    atkMult: 1.00, defMult: 1.00, injMod: 1.00, possession: 50,
    variance: 1.0, swing: 0, hint: 'Standard formation',
  ),
  'allOutAttack': Strategy(
    id: 'allOutAttack', name: 'All Out Attack', shortName: 'Attack', icon: '⚔️',
    atkMult: 1.18, defMult: 0.82, injMod: 1.20, possession: 62,
    variance: 1.15, swing: 0,
    hint: 'Throw everyone forward — far more chances, but wide open at the back',
  ),
  'parkTheBus': Strategy(
    id: 'parkTheBus', name: 'Defence', shortName: 'Defence', icon: '🛡️',
    atkMult: 0.86, defMult: 1.14, injMod: 0.85, possession: 38,
    variance: 0.88, swing: 0,
    hint: 'Defend deep — hard to break down, little threat going forward',
  ),
  'counterAttack': Strategy(
    id: 'counterAttack', name: 'Counter Attack', shortName: 'Counter', icon: '🎯',
    atkMult: 0.92, defMult: 1.08, injMod: 0.80, possession: 30,
    variance: 1.0, swing: 0.5, commitmentGain: 0.18,
    hint: 'Sit deep, burst on the break — deadly against a side that commits '
        'forward, toothless against a deep block',
  ),
  'highPress': Strategy(
    id: 'highPress', name: 'High Press', shortName: 'Press', icon: '🔥',
    atkMult: 1.22, defMult: 0.78, injMod: 1.55, possession: 57,
    variance: 1.00, swing: 0,
    hint: 'Win the ball high — biggest attacking shift, high injury risk',
  ),
};

const String defaultStrategy = 'balanced';

/// Plain-English descriptions shown in the pause panel.
///
/// **THEY HAVE TO MATCH THE MULTIPLIERS ABOVE THEM, and two did not.**
///
/// Counter Attack's said "ATK and DEF swap as play flows". Nothing swaps: its
/// base is DEFENSIVE (`0.92 / 1.08`) and what moves is the attack multiplier,
/// lifted by `commitmentGain × commitmentRead(...)` against a side that commits
/// forward and cut against a deep block — with `swing` widening the result
/// either way. A player reading "swap" would pick it expecting a shape that
/// turns into an attacking one, which is the opposite of what it does.
///
/// High Press's "strongest boost" was true — `1.22` is the biggest attacking
/// shift of the five — but it left out the price, which is not the injuries: at
/// `0.78` it is the most OPEN tactic in the game, below All Out Attack's `0.82`.
/// Tactics are zero-sum on composite rating, so the biggest shift forward is by
/// definition the biggest hole at the back, and a description that names only
/// the boost is selling half of it.
///
/// Mirrors `strategy.*.desc` in the catalogue, which is what the picker shows.
/// Changed in `../merge-empire-fc/src/i18n/locales/en.js` and regenerated — the
/// nine other locales still carry the old line, which is ordinary translation
/// lag rather than a second source of truth.
const Map<String, String> strategyDescriptions = {
  'balanced': 'Solid shape at both ends. Good default.',
  'allOutAttack':
      'Everyone forward — more chances, exposed at the back. Use when chasing.',
  'parkTheBus': 'Hard to break down, little threat forward. Protect a lead.',
  'counterAttack':
      'Sits deep and reads the opponent: your attack climbs against a side that '
      'commits forward and drops against a deep block. Widest spread of '
      'results. Underdog pick.',
  'highPress':
      'Win the ball high. The biggest attacking shift of the five, and the most '
      'open at the back — players tire fast and injuries spike.',
};

/// What share of a side's strength sits in attack.
double attackingCommitment(num? oppAtk, num? oppDef) {
  final total = (oppAtk ?? 0) + (oppDef ?? 0);
  return total > 0 ? (oppAtk ?? 0) / total : 0.5;
}

/// The five shapes' commitments, computed UNROUNDED.
///
/// [teamSplitForFormation] rounds to integers, and at a rating of 50 that
/// rounding moves the ratio enough to shift the read by a quarter of its range.
/// A load-bearing number cannot wobble with the opponent's rating.
double _shapeCommitment(String formationId) {
  final positions =
      aiFormationPositions[formationId] ?? aiFormationPositions['4-4-2']!;

  var aNum = 0.0;
  var aDen = 0.0;
  var dNum = 0.0;
  var dDen = 0.0;

  for (final pos in positions) {
    // The split maths at unit rating, inlined rather than called: the helper
    // rounds AND clamps to 100, and both destroy the signal here — at a high
    // rating every stat clamps flat, at a low one the rounding is a quarter of
    // the read.
    final ratio = _posRatio[pos]!;
    final spec = math.min(1.0, (ratio - 0.5).abs() * 2);
    final strong = 1 + spec * peakLift;
    final weak = 1 - spec * offStatDrop;
    final atk = ratio >= 0.5 ? strong : weak;
    final dfn = ratio >= 0.5 ? weak : strong;
    final aw = attackWeights[pos] ?? 0.5;
    final dw = defenceWeights[pos] ?? 0.5;
    aNum += atk * aw;
    aDen += aw;
    dNum += dfn * dw;
    dDen += dw;
  }

  return attackingCommitment(aNum / aDen, dNum / dDen);
}

final Map<String, double> _shapeCommitments = {
  for (final id in aiFormationPositions.keys) id: _shapeCommitment(id),
};

/// Centred on the mean shape, so the modal opponent is worth about nothing and
/// the read is a wash across the shapes the AI actually fields. Derived rather
/// than written down: add an AI formation and the centre moves with it.
final double commitmentNeutral =
    _shapeCommitments.values.reduce((a, b) => a + b) / _shapeCommitments.length;

final double _commitmentScale = _shapeCommitments.values
    .map((c) => (c - commitmentNeutral).abs())
    .reduce(math.max);

/// How committed forward the opponent is, from -1 (deepest block) to +1 (most
/// open).
///
/// Takes the opponent's stored ATTACK RATIO — the thing that actually
/// determines their shape — not their ATK/DEF. That was the first attempt and
/// it cannot work: team ATK and DEF both sit near the rating, so a 3-4-3 and a
/// 4-3-3 differ by less than one integer point in the numbers that reach us.
/// The shape is simply not recoverable from the split, at any rating.
double commitmentRead(double? oppAttackRatio) {
  if (_commitmentScale <= 0 || oppAttackRatio == null) return 0;
  final c = _shapeCommitments[formationForShare(oppAttackRatio)] ??
      _shapeCommitments['4-4-2'];
  if (c == null) return 0;
  return math.max(-1, math.min(1, (c - commitmentNeutral) / _commitmentScale));
}

/// A tactic's effective multipliers against a specific opponent.
///
/// Every caller — the sim, the coach and every ATK/DEF readout — goes through
/// this, because a display and a simulation disagreeing about what a tactic
/// does is the exact bug this file keeps growing comments about.
///
/// Counter Attack's gain against the most attacking shape is paid for by an
/// equal loss against the most defensive one, so across the formations the AI
/// fields it averages to nothing. Tactics may not create strength, but they may
/// be right or wrong about who they are facing.
({double atk, double def}) tacticMultipliers(
  Strategy? strat, [
  double? oppAttackRatio,
]) {
  final def = strat?.defMult ?? 1;
  var atk = strat?.atkMult ?? 1;
  final gain = strat?.commitmentGain ?? 0;
  if (gain != 0 && oppAttackRatio != null) {
    atk *= 1 + gain * commitmentRead(oppAttackRatio);
  }
  return (atk: atk, def: def);
}

double applyTacticAtk(num v, Strategy? strat, [double? oppAttackRatio]) =>
    v * tacticMultipliers(strat, oppAttackRatio).atk;

double applyTacticDef(num v, Strategy? strat, [double? oppAttackRatio]) =>
    v * tacticMultipliers(strat, oppAttackRatio).def;

/// Possession bias in the legacy point scale, derived from the attack
/// multiplier so the live display is unchanged by the switch to multipliers.
double stratBiasPoints(Strategy? strat) => ((strat?.atkMult ?? 1) - 1) * 50;

/// Rolls a tactic's hot/cold swing once per simulation.
///
/// Mean-preserving: the expected factor is 1, so swing widens outcomes without
/// inflating total goals. Draws from the SEEDED stream — this is gameplay
/// randomness.
double rollSwingFactor(Strategy? strat) {
  final s = strat?.swing ?? 0;
  if (s == 0) return 1;
  return seeded.random() < 0.5 ? 1 - s : 1 + s;
}

/// Where the run of play sits before a ball is kicked, home-positive, 0..100.
///
/// **THE ARROW AND THE CHANCES WERE TWO DIFFERENT FORMULAS.** The momentum
/// arrow reads the stat board's possession — rating gap, tactic and the swing of
/// the goals so far — while `generateMatchEvents` weighted chance attribution on
/// the RATINGS alone. So the arrow could point hard one way, because of a tactic
/// or a swing it knew about, and the chances went on falling the other way. That
/// is exactly the thing a player calls "the arrow doesn't mean anything".
///
/// Unclamped: the caller clamps once, after adding whatever it knows that this
/// does not — the board adds the live swing, and the kickoff weighting has no
/// swing to add.
double restingPossessionHome({
  required double ratingDiffHome,
  required double possessionBiasHome,
}) => 50 + ratingDiffHome * 0.3 + possessionBiasHome * 0.5;

/// How much of the GAP a counter closes for the side without the ball.
///
/// A share of the gap rather than a share of the leader's play: at 0.5 of the
/// leader's figure a countering underdog overtook the side dominating the game,
/// which is not a counter attack, it is a different match.
const double counterLift = 0.5;

/// How the chances split between the two sides.
///
/// **The side with the run of play takes most of them — just not all of them**,
/// and the exception is the one that makes it read as football: a COUNTER
/// ATTACK. Only the side with LESS of the ball can counter, because that is
/// what the word means, and how much it is worth to them is how far they are
/// set up for it.
///
/// So: the team with most possession most of the time wins, and a side pinned
/// back and playing on the break is still dangerous — which is the whole shape
/// of the report this came from.
({double home, double away}) chanceWeightsFor({
  required double possHome,
  required double counterHome,
  required double counterAway,
}) {
  final home = possHome.clamp(0.0, 100.0);
  final away = 100 - home;
  final gap = (home - away).abs();
  double lift(double counter) => gap * counter.clamp(0.0, 1.0) * counterLift;
  return (
    home: math.max(0.1, home + (home < away ? lift(counterHome) : 0)),
    away: math.max(0.1, away + (away < home ? lift(counterAway) : 0)),
  );
}

/// How far a tactic is set up to play on the break, 0..1.
///
/// Read off the tactic's own possession figure rather than named by id: a side
/// that expects 30% of the ball is playing for the moment it wins it back, and
/// one expecting 62% is not countering anything.
double counterLeanFor(String? strategyId) {
  final strat = strategies[strategyId ?? defaultStrategy];
  if (strat == null) return 0;
  return ((50 - strat.possession) / 20).clamp(0.0, 1.0);
}
