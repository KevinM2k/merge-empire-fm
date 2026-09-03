/// Keepy Uppys' physics, against the JS's own frames.
///
/// Regenerate with:
///   node tool/dump_keepy_uppys_reference.mjs > test/fixtures/keepy_uppys.json
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/mini_games.dart';
import 'package:merge_empire_fc/ui/screens/minigames/keepy_uppys_sim.dart';

Map<String, dynamic> loadFixture() =>
    jsonDecode(File('test/fixtures/keepy_uppys.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final fixture = loadFixture();
  final arena = fixture['arena'] as Map<String, dynamic>;
  final reel = (fixture['reel'] as List).cast<num>();
  final taps = (fixture['taps'] as List).cast<Map<String, dynamic>>();
  final frames = (fixture['frames'] as List).cast<Map<String, dynamic>>();

  test('THE WHOLE RUN, FRAME BY FRAME, matches the JS', () {
    // Same numbers, in the same ORDER. The sim takes exactly one draw and it
    // takes it first; an extra draw anywhere would shift the opening drift and
    // every frame after it.
    var drawAt = 0;
    final sim = KeepyUppysSim(
      arenaW: (arena['w'] as num).toDouble(),
      arenaH: (arena['h'] as num).toDouble(),
      random: () => reel[drawAt++].toDouble(),
    );

    final tapAt = {for (final t in taps) t['frame'] as int: t};
    var landed = 0;

    for (var frame = 0; frame < frames.length; frame++) {
      final scripted = tapAt[frame];
      if (scripted != null) {
        final at = (scripted['at'] as List).cast<num>();
        final hit = sim.tap(at[0].toDouble(), at[1].toDouble());
        expect(
          hit,
          scripted['landed'],
          reason: 'frame $frame: the hit radius disagrees',
        );
        if (hit) landed++;
        expect(
          sim.vx,
          closeTo((scripted['vx'] as num).toDouble(), 1e-6),
          reason: 'frame $frame: the sideways kick',
        );
        expect(
          sim.vy,
          closeTo((scripted['vy'] as num).toDouble(), 1e-6),
          reason: 'frame $frame: the upward kick',
        );
      }

      final want = frames[frame];
      // The dt the JS's own loop used, not an assumed 1.0 — see the dump.
      sim.step((want['dt'] as num).toDouble());
      expect(
        sim.x,
        closeTo((want['x'] as num).toDouble(), 1e-6),
        reason: '$frame x',
      );
      expect(
        sim.y,
        closeTo((want['y'] as num).toDouble(), 1e-6),
        reason: '$frame y',
      );
      expect(
        sim.vx,
        closeTo((want['vx'] as num).toDouble(), 1e-6),
        reason: '$frame vx',
      );
      expect(
        sim.vy,
        closeTo((want['vy'] as num).toDouble(), 1e-6),
        reason: '$frame vy',
      );
      expect(
        sim.angle,
        closeTo((want['angle'] as num).toDouble(), 1e-6),
        reason: '$frame angle',
      );
      expect(sim.taps, want['taps'], reason: '$frame taps');
    }

    expect(sim.tapsByStage, (fixture['tapsByStage'] as List).cast<int>());
    expect(sim.weightedTaps, fixture['weightedTaps']);
    expect(sim.bonus, fixture['bonus']);
    expect(landed, greaterThan(0));
  });

  test('the run exercises ALL THREE BALLS and both outcomes of a tap', () {
    // A fixture that only ever hits a balloon pins one third of the physics.
    final byStage = (fixture['tapsByStage'] as List).cast<int>();
    expect(
      byStage.every((n) => n > 0),
      isTrue,
      reason: 'a stage went untested',
    );
    expect(taps.where((t) => t['landed'] == false), isNotEmpty);
    expect(taps.where((t) => t['landed'] == true), isNotEmpty);
    expect(fixture['bonus'], isTrue, reason: 'the full run was never made');
  });

  group('the stages', () {
    test('HARDEN, in every direction at once', () {
      for (var i = 1; i < keepyStages.length; i++) {
        final prev = keepyStages[i - 1];
        final next = keepyStages[i];
        expect(next.minTaps, greaterThan(prev.minTaps));
        expect(next.gravity, greaterThan(prev.gravity), reason: 'gravity $i');
        expect(next.hitRadius, lessThan(prev.hitRadius), reason: 'reach $i');
        expect(next.size, lessThan(prev.size), reason: 'size $i');
        expect(next.rewardMult, greaterThan(prev.rewardMult), reason: 'pay $i');
      }
    });

    test('and the ladder is what the bonus target is BUILT from', () {
      // 10 balloon + 15 football + 20 cannonball. If the thresholds ever move
      // and the target does not, "survive all three" stops meaning that.
      expect(keepyBonusTarget, greaterThan(keepyStages.last.minTaps));
      expect(stageFor(0), keepyStages[0]);
      expect(stageFor(9), keepyStages[0]);
      expect(stageFor(10), keepyStages[1]);
      expect(stageFor(24), keepyStages[1]);
      expect(stageFor(25), keepyStages[2]);
      expect(stageFor(keepyBonusTarget), keepyStages[2]);
    });
  });

  test('THE PAYOUT IS WEIGHTED, not counted', () {
    // Ten taps on the cannonball are worth two and a half times ten on the
    // balloon; banking `taps` would pay the same for both.
    final sim = KeepyUppysSim(arenaW: 320, arenaH: 280, random: () => 0.5);
    sim.tapsByStage.setAll(0, [10, 0, 0]);
    expect(sim.weightedTaps, 10);
    sim.tapsByStage.setAll(0, [0, 10, 0]);
    expect(sim.weightedTaps, 15);
    sim.tapsByStage.setAll(0, [0, 0, 10]);
    expect(sim.weightedTaps, 25);
    sim.tapsByStage.setAll(0, [10, 15, 20]);
    expect(sim.weightedTaps, 83);
  });

  test('and the FULL RUN doubles it', () {
    final sim = KeepyUppysSim(arenaW: 320, arenaH: 280, random: () => 0.5);
    sim.tapsByStage.setAll(0, [10, 15, 20]);
    expect(sim.bankedTaps, 83, reason: 'the bonus paid without being earned');
    sim.bonus = true;
    expect(sim.bankedTaps, 166);
  });

  test('AND THE LAUNCHER QUOTES EXACTLY THAT, from the other half of the tree', () {
    // The Training tab prints a ceiling for every drill and Keepy Uppys was
    // the one row with nothing on it — "taps are unbounded", which they are
    // not: the run ENDS the moment the full-run target is reached. So the
    // engine quotes a figure like the rest of them.
    //
    // The stage table is up here in the UI, where the physics is, and
    // `lib/engine` may not import it — see `architecture_test.dart` — so the
    // engine carries the number as a constant and this is what stops the two
    // drifting apart. A stage weight moved without the constant moving fails
    // HERE rather than on a launcher that quietly over-promises.
    final perfect = KeepyUppysSim(arenaW: 320, arenaH: 280, random: () => 0.5)
      ..tapsByStage.setAll(0, [
        for (var i = 0; i < keepyStages.length; i++)
          (i + 1 < keepyStages.length
              ? keepyStages[i + 1].minTaps
              : keepyBonusTarget) -
              keepyStages[i].minTaps,
      ])
      ..bonus = true;
    expect(
      perfect.bankedTaps,
      KeepyUppys.maxBankedTaps,
      reason: 'the launcher is quoting a figure a perfect run cannot bank',
    );
    // And the stage table really does add up to the target it is measured
    // against, or the run above is not a full one.
    expect(
      perfect.tapsByStage.fold<int>(0, (a, b) => a + b),
      keepyBonusTarget,
    );
  });

  test('a ball out at the bottom ENDS it, and nothing moves after', () {
    final sim = KeepyUppysSim(arenaW: 320, arenaH: 280, random: () => 0.5);
    for (var i = 0; i < 2000 && !sim.missed; i++) {
      sim.step(1);
    }
    expect(sim.missed, isTrue, reason: 'the balloon never came down');
    final restX = sim.x;
    final restY = sim.y;
    expect(sim.step(1), isFalse);
    expect(sim.x, restX);
    expect(sim.y, restY);
    expect(sim.tap(sim.x, sim.y), isFalse, reason: 'a dead ball was tappable');
  });

  test('the WALLS damp rather than reflect', () {
    // A wall that returned the same speed would make the arena a pinball
    // table; each bounce has to cost the ball something.
    final sim = KeepyUppysSim(arenaW: 320, arenaH: 280, random: () => 0.5)
      ..x = 10
      ..vx = -6
      ..vy = 0;
    sim.step(1);
    expect(sim.vx, greaterThan(0), reason: 'it went through the wall');
    expect(sim.vx.abs(), lessThan(6));
    expect(sim.x, greaterThanOrEqualTo(0));
  });
}
