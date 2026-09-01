/// The shelves' ambient light — see [TileShine].
///
/// The interesting property is not what it draws; it is that it can be turned
/// OFF, because an animation that repeats for as long as it is on screen is an
/// animation `pumpAndSettle` never gets past. Every other test in this package
/// depends on that switch being thrown, so it gets a test of its own.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_shine.dart';

Future<void> pumpShine(
  WidgetTester tester, {
  bool reducedMotion = false,
  int sparkles = 4,
}) => tester.pumpWidget(
  MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
      child: child!,
    ),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 160,
          height: 120,
          child: TileShine(radius: 14, sparkles: sparkles, seed: 3),
        ),
      ),
    ),
  ),
);

void main() {
  // `flutter_test_config.dart` clears this for the whole package, so a test
  // that wants the live animation has to ask for it back — and put it back.
  setUp(() => shopShineEnabled = true);
  tearDown(() => shopShineEnabled = false);

  testWidgets('IT RUNS, and never lets the tree settle', (tester) async {
    await pumpShine(tester);
    // A repeating controller is what a shopfront sheen IS, and it is also
    // exactly why the package-wide switch has to exist.
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('REDUCED MOTION stops it dead, on one still frame', (
    tester,
  ) async {
    // A player who has asked their phone for less movement gets a tile that
    // does not move — and still gets a tile, not a hole.
    await pumpShine(tester, reducedMotion: true);
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.byType(CustomPaint), findsWidgets);
    // And `pumpAndSettle` returns, which is the whole point of the branch.
    await tester.pumpAndSettle();
  });

  testWidgets('AND THE PACKAGE SWITCH DOES THE SAME', (tester) async {
    // What `flutter_test_config.dart` throws for every other test in the
    // suite. Without it, a shop tile in any harness hangs the run.
    shopShineEnabled = false;
    await pumpShine(tester);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('it takes no pointer, whatever it is drawing over', (
    tester,
  ) async {
    var taps = 0;
    shopShineEnabled = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              height: 120,
              child: Stack(
                children: [
                  GestureDetector(
                    key: const ValueKey('under'),
                    onTap: () => taps++,
                    child: const ColoredBox(
                      color: Colors.blue,
                      child: SizedBox.expand(),
                    ),
                  ),
                  const Positioned.fill(
                    child: TileShine(radius: 14, sparkles: 4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('under')));
    expect(taps, 1, reason: 'the sheen is over the tile a player taps');
  });
}
