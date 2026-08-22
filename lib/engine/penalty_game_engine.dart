/// How hard the keeper is in the penalty mini-game.
///
/// **The SHOT is not here, and that is the point.** This library used to carry a
/// four-corner `takePenalty` in which a read was an automatic save — the arcade
/// model ported from `ui/components/PenaltyGame.js` — and the scene rebuild
/// replaced it wholesale with a simulated kick: `engine/penalty_physics.dart`
/// flies the ball at regulation numbers and `planKeeper` gives the keeper a dive
/// he still has to REACH, which is what makes aim worth anything. Two models of
/// one shot is two answers to "did that go in", so the arcade one is gone rather
/// than left where a future screen could pick the wrong one.
///
/// What survives is the pair the physics asks for: how often he goes the right
/// way, and off which division. They were always shared and are now all this
/// library is.
///
/// Never a cup-tie shootout: that is the match engine's, and it touches
/// different counters entirely.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/mini_games.dart';

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
