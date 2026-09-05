/// The park's trees breathe — see `ParkSway` in `pitch_scene.dart`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/home/pitch_scene.dart';

void main() {
  ParkSway tree(int seed) => ParkSway(
    clock: ValueNotifier<double>(0),
    seed: seed,
    child: const SizedBox(),
  );

  test('a breeze, not a gale: never more than the amplitude', () {
    for (var seed = 1; seed <= 10; seed++) {
      final t = tree(seed);
      for (var s = 0.0; s < 60; s += 0.05) {
        expect(t.angleAt(s).abs(), lessThanOrEqualTo(t.amplitude + 1e-9));
      }
    }
  });

  test('and it MOVES — a tree that holds still is a still', () {
    final t = tree(1);
    final peak = List.generate(200, (i) => t.angleAt(i * 0.05).abs())
        .reduce(math.max);
    expect(peak, greaterThan(t.amplitude * 0.5));
  });

  test('two trees do not nod in step', () {
    final a = tree(1);
    final b = tree(2);
    var agree = 0;
    for (var s = 0.0; s < 20; s += 0.1) {
      if ((a.angleAt(s) - b.angleAt(s)).abs() < 0.002) agree++;
    }
    expect(agree, lessThan(60), reason: 'in step most of the time');
  });

  testWidgets('the rotation is about the FOOT, so the trunk stays planted', (
    tester,
  ) async {
    final clock = ValueNotifier<double>(0);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ParkSway(
            clock: clock,
            seed: 3,
            child: const SizedBox(key: ValueKey('tree'), width: 20, height: 80),
          ),
        ),
      ),
    );
    final rotate = tester.widget<Transform>(
      find.ancestor(
        of: find.byKey(const ValueKey('tree')),
        matching: find.byType(Transform),
      ),
    );
    expect(rotate.alignment, Alignment.bottomCenter);
    clock.value = 1.1;
    await tester.pump();
    final moved = tester.widget<Transform>(
      find.ancestor(
        of: find.byKey(const ValueKey('tree')),
        matching: find.byType(Transform),
      ),
    );
    expect(moved.transform, isNot(rotate.transform), reason: 'the clock moved it');
  });
}
