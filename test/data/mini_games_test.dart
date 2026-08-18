/// The mini-game constants and difficulty curves, against the JS they were
/// ported from.
///
/// The constants are balance numbers rather than mechanics, which is exactly
/// why they are pinned: a retune on the JS side that never reaches the port is
/// a game paying different money on the two platforms, and nothing about the
/// port would look broken.
///
/// See `tool/dump_mini_games_reference.mjs`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/mini_games.dart';

final Map<String, dynamic> _ref =
    jsonDecode(
          File('test/fixtures/mini_games_reference.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

Map<String, dynamic> _constants(String game) =>
    (_ref['constants'] as Map<String, dynamic>)[game] as Map<String, dynamic>;

Map<String, dynamic> _curve(int divIdx) =>
    (_ref['curves'] as Map<String, dynamic>)['$divIdx'] as Map<String, dynamic>;

/// Every division index the reference covers, the two out-of-range ones
/// included — both ends clamp, and a port that interpolates past them hands a
/// Champions Cup player an impossible game.
const _divIdxs = [-1, 0, 1, 2, 3, 4, 5, 6, 7];

void main() {
  group('the constants match the JS', () {
    test('penalty', () {
      final want = _constants('penalty');
      expect(Penalty.cooldownMs, want['COOLDOWN_MS']);
      expect(Penalty.attempts, want['ATTEMPTS']);
      expect(Penalty.rewardPerGoalMult, want['REWARD_PER_GOAL_MULT']);
      expect(Penalty.keeperSmartBase, want['KEEPER_SMART_BASE']);
      expect(Penalty.keeperSmartMax, want['KEEPER_SMART_MAX']);
    });

    test('training', () {
      final want = _constants('training');
      expect(Training.cooldownMs, want['COOLDOWN_MS']);
      expect(Training.durationMs, want['DURATION_MS']);
      expect(Training.leadInMs, want['LEAD_IN_MS']);
      expect(Training.rewardBaseMult, want['REWARD_BASE_MULT']);
      expect(Training.drillsBase, want['DRILLS_BASE']);
      expect(Training.drillsMax, want['DRILLS_MAX']);
      expect(Training.drillWindowBaseMs, want['DRILL_WINDOW_BASE_MS']);
      expect(Training.drillWindowMinMs, want['DRILL_WINDOW_MIN_MS']);
      expect(Training.energyGrant, want['ENERGY_GRANT']);
    });

    test('through ball', () {
      final want = _constants('throughBall');
      expect(ThroughBall.cooldownMs, want['COOLDOWN_MS']);
      expect(ThroughBall.rounds, want['ROUNDS']);
      expect(ThroughBall.rewardPerRoundMult, want['REWARD_PER_ROUND_MULT']);
      expect(ThroughBall.zoneEasyPct, want['ZONE_EASY_PCT']);
      expect(ThroughBall.zoneHardPct, want['ZONE_HARD_PCT']);
      expect(ThroughBall.sweepEasyMs, want['SWEEP_EASY_MS']);
      expect(ThroughBall.sweepHardMs, want['SWEEP_HARD_MS']);
      expect(ThroughBall.zonePosMinPct, want['ZONE_POS_MIN_PCT']);
      expect(ThroughBall.zonePosMaxPct, want['ZONE_POS_MAX_PCT']);
    });

    test('keepy uppys', () {
      final want = _constants('keepyUppys');
      expect(KeepyUppys.cooldownMs, want['COOLDOWN_MS']);
      expect(KeepyUppys.rewardPerTapMult, want['REWARD_PER_TAP_MULT']);
    });

    test('pairs', () {
      final want = _constants('pairs');
      expect(Pairs.cooldownMs, want['COOLDOWN_MS']);
      expect(Pairs.lives, want['LIVES']);
      expect(Pairs.rewardPerPairMult, want['REWARD_PER_PAIR_MULT']);
      expect(Pairs.clearBonusMult, want['CLEAR_BONUS_MULT']);
      expect(Pairs.pairsBase, want['PAIRS_BASE']);
      expect(Pairs.pairsMax, want['PAIRS_MAX']);
      expect(Pairs.peekBaseMs, want['PEEK_BASE_MS']);
      expect(Pairs.peekMinMs, want['PEEK_MIN_MS']);
      expect(Pairs.mismatchHideMs, want['MISMATCH_HIDE_MS']);
    });

    test('pitch invaders', () {
      final want = _constants('whack');
      expect(Whack.cooldownMs, want['COOLDOWN_MS']);
      expect(Whack.holes, want['HOLES']);
      expect(Whack.durationMs, want['DURATION_MS']);
      expect(Whack.leadInMs, want['LEAD_IN_MS']);
      expect(Whack.rewardPerCatchMult, want['REWARD_PER_CATCH_MULT']);
      expect(Whack.dogValue, want['DOG_VALUE']);
      expect(Whack.foulCost, want['FOUL_COST']);
      expect(Whack.spawnBaseMs, want['SPAWN_BASE_MS']);
      expect(Whack.spawnMinMs, want['SPAWN_MIN_MS']);
      expect(Whack.upBaseMs, want['UP_BASE_MS']);
      expect(Whack.upMinMs, want['UP_MIN_MS']);
      expect(Whack.stewardBasePct, want['STEWARD_BASE_PCT']);
      expect(Whack.stewardMaxPct, want['STEWARD_MAX_PCT']);
      expect(Whack.dogPct, want['DOG_PCT']);
    });

    test('boot room', () {
      final want = _constants('bootRoom');
      expect(BootRoom.cooldownMs, want['COOLDOWN_MS']);
      expect(BootRoom.cols, want['COLS']);
      expect(BootRoom.rows, want['ROWS']);
      expect(BootRoom.rewardPerTileMult, want['REWARD_PER_TILE_MULT']);
      expect(BootRoom.targetBonusMult, want['TARGET_BONUS_MULT']);
      expect(BootRoom.movesBase, want['MOVES_BASE']);
      expect(BootRoom.movesMin, want['MOVES_MIN']);
      expect(BootRoom.typesBase, want['TYPES_BASE']);
      expect(BootRoom.typesMax, want['TYPES_MAX']);
      expect(BootRoom.yieldPerMove5, want['YIELD_PER_MOVE_5']);
      expect(BootRoom.yieldPerMove6, want['YIELD_PER_MOVE_6']);
    });
  });

  group('the difficulty curves match the JS', () {
    for (final divIdx in _divIdxs) {
      test('at division index $divIdx', () {
        final want = _curve(divIdx);

        expect(penaltyKeeperSmartChance(divIdx), want['keeperSmart']);

        final training = trainingDifficulty(divIdx);
        expect(training.drills, (want['training'] as Map)['drills']);
        expect(training.windowMs, (want['training'] as Map)['windowMs']);

        final throughBall = throughBallDifficulty(divIdx);
        expect(throughBall.zonePct, (want['throughBall'] as Map)['zonePct']);
        expect(throughBall.sweepMs, (want['throughBall'] as Map)['sweepMs']);

        final pairs = pairsDifficulty(divIdx);
        expect(pairs.pairs, (want['pairs'] as Map)['pairs']);
        expect(pairs.peekMs, (want['pairs'] as Map)['peekMs']);

        final whack = whackDifficulty(divIdx);
        expect(whack.spawnMs, (want['whack'] as Map)['spawnMs']);
        expect(whack.upMs, (want['whack'] as Map)['upMs']);
        expect(whack.stewardPct, (want['whack'] as Map)['stewardPct']);
        expect(whack.dogPct, (want['whack'] as Map)['dogPct']);
        expect(whackMaxCatches(divIdx), want['whackMaxCatches']);

        final bootRoom = bootRoomDifficulty(divIdx);
        expect(bootRoom.moves, (want['bootRoom'] as Map)['moves']);
        expect(bootRoom.types, (want['bootRoom'] as Map)['types']);
        expect(bootRoom.target, (want['bootRoom'] as Map)['target']);
      });
    }

    test('the defaults are the easiest rung', () {
      // Every curve defaults to Sunday League, so a caller that has no division
      // to hand describes the gentlest version of the game rather than the
      // hardest.
      expect(trainingDifficulty(), trainingDifficulty(0));
      expect(throughBallDifficulty(), throughBallDifficulty(0));
      expect(pairsDifficulty(), pairsDifficulty(0));
      expect(whackDifficulty(), whackDifficulty(0));
      expect(whackMaxCatches(), whackMaxCatches(0));
      expect(bootRoomDifficulty(), bootRoomDifficulty(0));
    });
  });

  group('the curves are monotone across the ladder', () {
    // The fixture pins the numbers; this pins the SHAPE, which is what a retune
    // is most likely to break — a curve that stops being harder as you climb
    // reads as a balance change nobody asked for.
    test('everything gets harder, and the boot room target falls', () {
      for (var i = 1; i <= 6; i++) {
        expect(
          penaltyKeeperSmartChance(i),
          greaterThan(penaltyKeeperSmartChance(i - 1)),
          reason: 'keeper at $i',
        );
        expect(
          throughBallDifficulty(i).zonePct,
          lessThan(throughBallDifficulty(i - 1).zonePct),
          reason: 'zone at $i',
        );
        expect(
          throughBallDifficulty(i).sweepMs,
          lessThan(throughBallDifficulty(i - 1).sweepMs),
          reason: 'sweep at $i',
        );
        expect(
          whackDifficulty(i).spawnMs,
          lessThanOrEqualTo(whackDifficulty(i - 1).spawnMs),
          reason: 'spawn at $i',
        );
        expect(
          bootRoomDifficulty(i).moves,
          lessThanOrEqualTo(bootRoomDifficulty(i - 1).moves),
          reason: 'moves at $i',
        );
        expect(
          bootRoomDifficulty(i).target,
          lessThanOrEqualTo(bootRoomDifficulty(i - 1).target),
          reason: 'target at $i',
        );
      }
    });

    test(
      'the sixth kit type arrives at National League, and kinks the target',
      () {
        // `types` is round(5 + divIdx/6), so the sixth type lands at index 3 —
        // halfway up, not at the top — and the measured yield steps down with it.
        // That is where the target drops 82 to 58: a cliff, not a ramp, which is
        // the whole reason the ask is derived from the yield rather than
        // interpolated. Worth pinning because it looks like an off-by-three.
        for (var i = 0; i <= 2; i++) {
          expect(bootRoomDifficulty(i).types, 5, reason: 'types at $i');
        }
        for (var i = 3; i <= 6; i++) {
          expect(bootRoomDifficulty(i).types, 6, reason: 'types at $i');
        }
        expect(bootRoomDifficulty(2).target, 82);
        expect(bootRoomDifficulty(3).target, 58);
      },
    );
  });
}
