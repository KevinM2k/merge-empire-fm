/// A card breaking into pieces of itself — the auto-sold cash-in.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/grid/card_shatter.dart';

/// The shatter around a plain marker, at a card's own size.
Future<void> pumpShatter(
  WidgetTester tester,
  double progress, {
  bool reduceMotion = false,
}) => tester.pumpWidget(
  MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: CardShatter(
          progress: progress,
          seed: 3,
          child: const SizedBox(
            key: ValueKey('face'),
            width: 120,
            height: 170,
            child: ColoredBox(color: Color(0xFF00FF00)),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('A WHOLE CARD IS ONE CARD', (tester) async {
    await pumpShatter(tester, 0);
    expect(find.byKey(const ValueKey('card-shatter')), findsNothing);
    expect(find.byKey(const ValueKey('face')), findsOneWidget);
  });

  testWidgets('and a breaking one is twelve pieces of itself', (tester) async {
    await pumpShatter(tester, 0.2);
    expect(find.byKey(const ValueKey('card-shatter')), findsOneWidget);
    // The pieces are clones of the card's own face, which is what makes it
    // visibly THAT player coming apart rather than a generic puff.
    expect(
      find.byKey(const ValueKey('face')),
      findsNWidgets(shatterCols * shatterRows),
    );
  });

  testWidgets('THE PIECES GO OUTWARD, not in a heap', (tester) async {
    await pumpShatter(tester, 0.5);
    final pieces = tester
        .widgetList<ClipRect>(find.byType(ClipRect))
        .length;
    expect(pieces, shatterCols * shatterRows);

    final drawn = [
      for (var i = 0; i < shatterCols * shatterRows; i++)
        tester.getCenter(find.byKey(const ValueKey('face')).at(i)),
    ];
    // Every piece is somewhere different, and the spread is wider than the card
    // it came from — a break, not a fade.
    expect(drawn.toSet(), hasLength(drawn.length));
    final xs = drawn.map((o) => o.dx);
    expect(xs.reduce((a, b) => a > b ? a : b) - xs.reduce((a, b) => a < b ? a : b),
        greaterThan(120));
  });

  testWidgets('AND THE LAST OF THEM RUNS PAST THE FIRST', (tester) async {
    // The pieces are not all the same length: the break frays out rather than
    // stopping on one frame, so a progress of exactly 1 still has stragglers.
    await pumpShatter(tester, 1);
    expect(find.byKey(const ValueKey('face')), findsNWidgets(12));
  });

  testWidgets('reduce-motion keeps the sale and drops the break', (
    tester,
  ) async {
    await pumpShatter(tester, 0.5, reduceMotion: true);
    expect(find.byKey(const ValueKey('card-shatter')), findsNothing);
    expect(find.byKey(const ValueKey('face')), findsOneWidget);
  });

  test('the break is the window a caller has to hold its backdrop for', () {
    // The JS's `VANISH_MS`, and the reason the reveal waits before clearing.
    expect(cardShatterDuration.inMilliseconds, 520);
  });
}
