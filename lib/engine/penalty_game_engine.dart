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
/// What survives is the one thing the physics asks for: how often he goes the
/// right way. **Which division he is on is not this library's to answer** — it
/// had a `keeperDivisionIndex` that was a character-for-character copy of the
/// `divisionIndexOf` five other mini-games went through, and a rule about the
/// SAVE belongs beside the ladder it indexes. See `currentDivisionIndex` in
/// `data/divisions.dart`; its own doc carries what this one used to claim about
/// two ramps off one index.
///
/// Never a cup-tie shootout: that is the match engine's, and it touches
/// different counters entirely.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/mini_games.dart';

/// How often the keeper reads the shot at this save's division.
///
/// Five per cent at Sunday League, thirty at Champions Cup — which is why the
/// quest bank counts penalties SCORED rather than perfect rounds: a clean sweep
/// is a lottery that lengthens the higher you climb.
double keeperSmartChanceFor(Map<String, dynamic>? state) =>
    penaltyKeeperSmartChance(currentDivisionIndex(state));

