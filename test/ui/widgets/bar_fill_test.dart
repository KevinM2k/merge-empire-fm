/// Every progress bar in the game.
///
/// The one thing worth asserting is that a fill has HEIGHT. It has been the same
/// bug four times — the ATK/DEF tracks, the Play button's cooldown, Deadline
/// Day's fuse, the player card's income — and each time the widget was in the
/// tree, drawn, and zero pixels tall, so a test that only asked "is it there"
/// passed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/widgets/bar_fill.dart';

Future<void> pumpTrack(
  WidgetTester tester, {
  required double fraction,
  AlignmentGeometry alignment = Alignment.centerLeft,
}) => tester.pumpWidget(
  MaterialApp(
    home: Center(
      child: SizedBox(
        width: 200,
        // The trap needs BOTH halves: a loose height constraint, and a fill with
        // no child of its own.
        child: SizedBox(
          height: 6,
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: Colors.grey.shade300)),
              BarFill(
                key: const ValueKey('fill'),
                fraction: fraction,
                alignment: alignment,
                child: const ColoredBox(color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

Size fillSize(WidgetTester tester) => tester
    .renderObject<RenderBox>(
      find.descendant(
        of: find.byKey(const ValueKey('fill')),
        matching: find.byType(ColoredBox),
      ),
    )
    .size;

void main() {
  testWidgets('fills the track\'s full height, not zero', (tester) async {
    await pumpTrack(tester, fraction: 0.5);
    expect(fillSize(tester), const Size(100, 6));
  });

  testWidgets('and its width is the fraction', (tester) async {
    await pumpTrack(tester, fraction: 0.25);
    expect(fillSize(tester).width, 50);
    await pumpTrack(tester, fraction: 1);
    expect(fillSize(tester).width, 200);
  });

  testWidgets('a fraction off either end clamps rather than overflowing', (
    tester,
  ) async {
    // A fraction derived from a clock can run a hair past 1 on the first frame.
    await pumpTrack(tester, fraction: 1.4);
    expect(fillSize(tester).width, 200);
    await pumpTrack(tester, fraction: -0.2);
    expect(fillSize(tester).width, 0);
    expect(fillSize(tester).height, 6);
  });

  testWidgets('and it grows from the end it is aligned to', (tester) async {
    await pumpTrack(tester, fraction: 0.5);
    final left = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('fill')),
        matching: find.byType(ColoredBox),
      ),
    );
    await pumpTrack(tester, fraction: 0.5, alignment: Alignment.centerRight);
    final right = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('fill')),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(right.left, greaterThan(left.left));
    expect(left.left, right.left - 100);
  });
}
