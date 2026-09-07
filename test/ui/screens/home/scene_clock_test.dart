/// The shared layer clock — see `scene_clock.dart`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/home/scene_clock.dart';

void main() {
  Future<ValueListenable<double>> pumpClock(
    WidgetTester tester, {
    bool enabled = true,
    bool active = true,
    bool reduced = false,
  }) async {
    late ValueListenable<double> clock;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: TickerMode(
          enabled: enabled,
          child: SceneClock(
            active: active,
            builder: (context, c) {
              clock = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return clock;
  }

  testWidgets('counts seconds while it ticks', (tester) async {
    final clock = await pumpClock(tester);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    expect(clock.value, closeTo(1.0, 0.03));
  });

  testWidgets('a mute is not owed: one frame after it advances one step', (
    tester,
  ) async {
    final clock = await pumpClock(tester);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    final before = clock.value;
    await pumpClock(tester, enabled: false);
    await tester.pump(const Duration(seconds: 30));
    await pumpClock(tester, enabled: true);
    await tester.pump(const Duration(milliseconds: 16));
    expect(clock.value - before, lessThanOrEqualTo(sceneClockMaxStep + 1e-9));
    expect(clock.value, greaterThan(before));
  });

  testWidgets('and a stop holds where it froze, then carries on', (
    tester,
  ) async {
    final clock = await pumpClock(tester);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    final frozen = clock.value;
    await pumpClock(tester, active: false);
    await tester.pump(const Duration(seconds: 5));
    expect(clock.value, frozen);
    await pumpClock(tester, active: true);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 25));
    expect(clock.value, closeTo(frozen + 0.025, 0.03));
  });

  testWidgets('reduced motion never starts it', (tester) async {
    final clock = await pumpClock(tester, reduced: true);
    await tester.pump(const Duration(seconds: 2));
    expect(clock.value, 0);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
