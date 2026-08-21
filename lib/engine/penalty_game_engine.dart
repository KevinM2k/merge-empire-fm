/// Taking a penalty in the arcade mini-game.
///
/// The shot resolution lived in `ui/components/PenaltyGame.js`; the ramp it
/// uses, `penaltyKeeperSmartChance`, was already ported with the data. This is
/// the rest, lifted out so the outcome of a shot is testable without a widget.
///
/// Never a cup-tie shootout: that is the match engine's, and it touches
/// different counters entirely.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/mini_games.dart';

/// The four corners a penalty can be aimed at.
enum PenaltyCorner { topLeft, topRight, bottomLeft, bottomRight }

/// What one shot did.
typedef PenaltyShot = ({
  bool scored,
  PenaltyCorner aimed,
  PenaltyCorner keeper,

  /// The keeper READ it, rather than guessing and happening to be right. Worth
  /// separating: one is the division getting harder, the other is luck.
  bool keeperRead,
});

math.Random _rng = math.Random();

void setPenaltyRandom(math.Random rng) => _rng = rng;

void resetPenaltyRandom() => _rng = math.Random();

/// How often the keeper reads the shot at this save's division.
///
/// Five per cent at Sunday League, thirty at Champions Cup — which is why the
/// quest bank counts penalties SCORED rather than perfect rounds: a clean sweep
/// is a lottery that lengthens the higher you climb.
double keeperSmartChanceFor(Map<String, dynamic>? state) =>
    penaltyKeeperSmartChance(keeperDivisionIndex(state));

/// Which division's keeper the player is facing.
///
/// Shared, because his READ chance and his REACH are two ramps off the same
/// index and two ways of resolving it would be two ways of disagreeing.
int keeperDivisionIndex(Map<String, dynamic>? state) {
  final progression = state?['progression'];
  final id = progression is Map<String, dynamic>
      ? progression['currentDivision']
      : null;
  return math.max(0, divisions.indexWhere((d) => d.id == id));
}

/// Take one penalty at [aimed].
PenaltyShot takePenalty(Map<String, dynamic>? state, PenaltyCorner aimed) {
  final read = _rng.nextDouble() < keeperSmartChanceFor(state);
  // A read shot is a guaranteed save; otherwise the keeper picks a corner and
  // the shot beats them unless they happen to have picked the same one.
  final keeper = read
      ? aimed
      : PenaltyCorner.values[_rng.nextInt(PenaltyCorner.values.length)];
  return (
    scored: keeper != aimed,
    aimed: aimed,
    keeper: keeper,
    keeperRead: read,
  );
}
