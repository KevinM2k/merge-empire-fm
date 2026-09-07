/// The park strip is one picture tiled: every tile has to read ONE clock.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/ui/screens/home/pitch_scene.dart';

void main() {
  Future<void> pumpScene(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Theme(
        data: ThemeData(brightness: Brightness.light),
        child: Scaffold(
          body: PitchScene(
            mood: Mood.neutral,
            tier: 0,
            walkerBottom: 150 + walkerBottomClearance,
            walkerBuilder: (ball) =>
                Stack(children: [const SizedBox(width: 120, height: 170), ball]),
          ),
        ),
      ),
    ),
  );

  testWidgets('a tile added later sways in step with the tiles already there', (
    tester,
  ) async {
    // Narrow first, so widening it adds tiles to a strip already running.
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpScene(tester);
    // The decode is real I/O, so it needs the real event loop.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();
    // In frames: the clock is clamped per frame, so one long pump is one step.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    final stand = find.byKey(const ValueKey('pitch-stand'));
    final before = tester
        .widgetList<ParkSway>(find.descendant(of: stand, matching: find.byType(ParkSway)))
        .length;
    expect(before, greaterThan(0), reason: 'no trees on the park strip');

    await tester.binding.setSurfaceSize(const Size(1000, 800));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final trees = tester
        .widgetList<ParkSway>(find.descendant(of: stand, matching: find.byType(ParkSway)))
        .toList();
    expect(trees.length, greaterThan(before), reason: 'widening added no tiles');
    final clocks = {for (final t in trees) t.clock};
    expect(clocks.length, 1, reason: 'the tiles are on ${clocks.length} clocks');
    expect(clocks.single.value, greaterThan(0.9), reason: 'the clock is not running');
  });
}
