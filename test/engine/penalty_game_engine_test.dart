/// How hard the keeper is in the penalty mini-game.
///
/// The four-corner `takePenalty` that used to live here — and the tests that
/// pinned it — went with the scene rebuild: a read is no longer an automatic
/// save, the shot is simulated in `engine/penalty_physics.dart`, and two models
/// of one kick is two answers to whether it went in. What is left is the pair
/// the physics asks for, and the claim that they come off ONE division index.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/mini_games.dart';
import 'package:merge_empire_fc/engine/penalty_game_engine.dart';
import 'package:merge_empire_fc/engine/penalty_physics.dart';
import 'package:merge_empire_fc/state/state_schema.dart';

Map<String, dynamic> stateIn(String divisionId) {
  final s = createDefaultState();
  (s['progression'] as Map<String, dynamic>)['currentDivision'] = divisionId;
  return s;
}

void main() {
  group('the keeper', () {
    test('reads more shots the higher you climb', () {
      // Five per cent at Sunday League, thirty at the top.
      final bottom = keeperSmartChanceFor(stateIn(divisions.first.id));
      final top = keeperSmartChanceFor(stateIn(divisions.last.id));
      expect(bottom, Penalty.keeperSmartBase);
      expect(top, Penalty.keeperSmartMax);
      expect(top, greaterThan(bottom));
    });

    test('an unknown division is treated as the bottom one', () {
      // The id comes off the save.
      expect(
        keeperSmartChanceFor(stateIn('no-such-division')),
        Penalty.keeperSmartBase,
      );
      expect(keeperSmartChanceFor(null), Penalty.keeperSmartBase);
      expect(keeperDivisionIndex(null), 0);
      expect(keeperDivisionIndex(stateIn('no-such-division')), 0);
    });

    test('the index is the ladder, and it is the one both ramps read', () {
      // His READ chance and his REACH are two ramps off the same number, and two
      // ways of resolving which division he keeps for would be two ways of
      // disagreeing — a keeper who reads like the top flight and dives like
      // Sunday League.
      for (var i = 0; i < divisions.length; i++) {
        final state = stateIn(divisions[i].id);
        expect(keeperDivisionIndex(state), i, reason: divisions[i].id);
        expect(
          keeperSmartChanceFor(state),
          penaltyKeeperSmartChance(keeperDivisionIndex(state)),
          reason: divisions[i].id,
        );
      }
      // Both ramps climb, so the ladder is felt in the save AND in the reach.
      expect(
        keeperReachFor(divisions.length - 1),
        greaterThan(keeperReachFor(0)),
      );
    });
  });
}
