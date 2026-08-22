/// The unread mark, and there is one of it now.
///
/// **There were two and only one moved.** The home dock's badge has bounced
/// since it was written; the floating coach's — the same eighteen pixels, the
/// same white ring, the same drop shadow, on every other tab — was a still copy
/// of it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';

Future<void> pumpBadge(WidgetTester tester, {bool reduceMotion = false}) =>
    tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: CoachAlertBadge()),
        ),
      ),
    );

Offset offsetOf(WidgetTester tester) =>
    tester.getTopLeft(find.text('!'));

void main() {
  testWidgets('IT IS A RED EXCLAMATION and it MOVES', (tester) async {
    await pumpBadge(tester);
    expect(find.text('!'), findsOneWidget);

    // Two hops and a rest over 900ms, rather than a sine that never settles: a
    // badge bobbing continuously reads as a loading spinner. So the assertion
    // is that it is not in the same place across the hop, not that it is at any
    // particular height.
    final seen = <double>{};
    for (var i = 0; i < 9; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      seen.add(offsetOf(tester).dy);
    }
    expect(seen.length, greaterThan(1), reason: 'it never moved');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('and reduced motion holds it still, WITHOUT hiding it', (
    tester,
  ) async {
    // Red on its own still reads. A badge that vanishes under reduce-motion
    // takes away the only sign that something is waiting.
    await pumpBadge(tester, reduceMotion: true);
    expect(find.text('!'), findsOneWidget);
    final first = offsetOf(tester);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(offsetOf(tester).dy, first.dy);
    }
  });
}
