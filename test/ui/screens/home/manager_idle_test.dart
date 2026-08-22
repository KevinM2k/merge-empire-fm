/// The manager, alive between gestures.
///
/// **There were two managers and only one of them was breathing.** The dugout
/// cam built a complete idle — four out-of-phase loops driving breath, a weight
/// rock, arm sway and a slow scan — and the one on the HOME screen, who is the
/// manager most players look at most, had none of it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_idle.dart';

Future<List<({double lift, double tilt})>> samples(
  WidgetTester tester, {
  Mood mood = Mood.neutral,
  bool reduceMotion = false,
  int frames = 8,
}) async {
  final seen = <({double lift, double tilt})>[];
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ManagerIdle(
          mood: mood,
          builder: (context, idle) {
            seen.add((lift: idle.pose.bodyLift ?? 0, tilt: idle.tilt));
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 220));
  }
  await tester.pumpWidget(const SizedBox.shrink());
  return seen;
}

void main() {
  testWidgets('HE BREATHES, and shifts his weight', (tester) async {
    final seen = await samples(tester);
    expect(seen.map((s) => s.lift).toSet().length, greaterThan(1));
    expect(seen.map((s) => s.tilt).toSet().length, greaterThan(1));
  });

  testWidgets('THE FOUR CLOCKS DO NOT RE-ALIGN, so it never repeats', (
    tester,
  ) async {
    // Four separate loops rather than one with four phases read off it: one
    // clock would re-align at every wrap, which is exactly the repeat this
    // avoids.
    final seen = await samples(tester, frames: 40);
    final pairs = seen.map((s) => '${s.lift}|${s.tilt}').toList();
    expect(
      pairs.toSet().length,
      greaterThan(pairs.length ~/ 2),
      reason: 'the combination is repeating',
    );
  });

  testWidgets('AND THE TEMPO IS THE MOOD\'S', (tester) async {
    // A man who has just won cannot keep still; a beaten one is slow.
    expect(
      camIdle[Mood.elated]!.breath,
      lessThan(camIdle[Mood.crushed]!.breath),
    );
    expect(
      camIdle[Mood.elated]!.swayDegrees,
      greaterThan(camIdle[Mood.crushed]!.swayDegrees),
    );
    // Head down on a bad night, chest out on a good one.
    expect(camIdle[Mood.elated]!.lean, lessThan(camIdle[Mood.crushed]!.lean));
  });

  testWidgets('reduced motion holds him still, and still DRAWS him', (
    tester,
  ) async {
    final seen = await samples(tester, reduceMotion: true);
    expect(seen, isNotEmpty);
    expect(seen.map((s) => s.lift).toSet().length, 1);
  });
}
