/// Taking a penalty in the arcade mini-game.
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/mini_games.dart';
import 'package:merge_empire_fc/engine/penalty_game_engine.dart';
import 'package:merge_empire_fc/state/state_schema.dart';

Map<String, dynamic> stateIn(String divisionId) {
  final s = createDefaultState();
  (s['progression'] as Map<String, dynamic>)['currentDivision'] = divisionId;
  return s;
}

void main() {
  tearDown(resetPenaltyRandom);

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
    });
  });

  group('a shot', () {
    test('is saved outright when the keeper reads it', () {
      // rng always 0, so the read check always passes.
      setPenaltyRandom(_FixedRandom(0));
      final shot = takePenalty(stateIn(divisions.first.id), PenaltyCorner.topLeft);
      expect(shot.keeperRead, isTrue);
      expect(shot.keeper, shot.aimed);
      expect(shot.scored, isFalse);
    });

    test('beats a keeper who guessed elsewhere', () {
      // Never reads; dives to the first corner. Aim anywhere else.
      setPenaltyRandom(_FixedRandom(0.99, intValue: 0));
      final shot = takePenalty(
        stateIn(divisions.first.id),
        PenaltyCorner.bottomRight,
      );
      expect(shot.keeperRead, isFalse);
      expect(shot.keeper, PenaltyCorner.topLeft);
      expect(shot.scored, isTrue);
    });

    test('is saved when the keeper guesses right by luck', () {
      // A guess and a read are different things, and only one is the division
      // getting harder.
      setPenaltyRandom(_FixedRandom(0.99, intValue: 0));
      final shot = takePenalty(stateIn(divisions.first.id), PenaltyCorner.topLeft);
      expect(shot.keeperRead, isFalse, reason: 'luck, not skill');
      expect(shot.scored, isFalse);
    });

    test('every corner is aimable', () {
      setPenaltyRandom(math.Random(7));
      for (final corner in PenaltyCorner.values) {
        expect(takePenalty(stateIn(divisions.first.id), corner).aimed, corner);
      }
    });

    test('the bottom division is beatable more often than the top', () {
      int scoreIn(String division) {
        setPenaltyRandom(math.Random(11));
        var scored = 0;
        for (var i = 0; i < 600; i++) {
          if (takePenalty(stateIn(division), PenaltyCorner.topLeft).scored) {
            scored++;
          }
        }
        return scored;
      }

      expect(scoreIn(divisions.first.id), greaterThan(scoreIn(divisions.last.id)));
    });
  });
}

/// Returns the same doubles every time, so a branch can be pinned.
class _FixedRandom implements math.Random {
  _FixedRandom(this.value, {this.intValue = 0});

  final double value;
  final int intValue;

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => intValue % max;

  @override
  bool nextBool() => false;
}
