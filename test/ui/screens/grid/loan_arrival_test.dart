/// The loan stars dropping into the grid, one at a time.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/grid/loan_arrival.dart';

Future<void> pumpArrival(
  WidgetTester tester,
  Duration? delay, {
  bool reduceMotion = false,
}) => tester.pumpWidget(
  MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: LoanArrival(
          delay: delay,
          child: const SizedBox(
            key: ValueKey('card'),
            width: 90,
            height: 120,
            child: ColoredBox(color: Color(0xFF00FF00)),
          ),
        ),
      ),
    ),
  ),
);

double _opacity(WidgetTester tester) =>
    tester.widget<Opacity>(find.byType(Opacity)).opacity;

void main() {
  testWidgets('A CARD THAT IS NOT ARRIVING IS JUST THERE', (tester) async {
    await pumpArrival(tester, null);
    expect(find.byType(Opacity), findsNothing);
    expect(tester.getSize(find.byKey(const ValueKey('card'))).width, 90);
  });

  testWidgets('AN ARRIVING ONE WAITS OUT ITS DELAY UNSEEN', (tester) async {
    // CSS `animation-fill-mode: both`, and it is what makes the stagger a
    // stagger: without it every card appears at once and then re-animates in
    // order.
    await pumpArrival(tester, loanArrivalStagger * 2);
    expect(_opacity(tester), 0);
    await tester.pump(loanArrivalStagger);
    expect(_opacity(tester), 0, reason: 'not its turn yet');
    await tester.pump(loanArrivalStagger + const Duration(milliseconds: 16));
    // The timer fires the controller; the first tick is the frame after.
    await tester.pump(const Duration(milliseconds: 100));
    expect(_opacity(tester), greaterThan(0), reason: 'on its way');
    await tester.pump(loanArrivalDuration);
  });

  testWidgets('and lands whole', (tester) async {
    await pumpArrival(tester, Duration.zero);
    await tester.pump(loanArrivalDuration);
    expect(_opacity(tester), 1);
    final scale = tester.widget<Transform>(
      find.byType(Transform).last,
    );
    // Back to its own size: the overshoot has settled out.
    expect(scale.transform.getMaxScaleOnAxis(), closeTo(1, 0.001));
  });

  testWidgets('IT FALLS FROM ABOVE the square it lands in', (tester) async {
    await pumpArrival(tester, Duration.zero);
    await tester.pump(const Duration(milliseconds: 16));
    final falling = tester.getCenter(find.byKey(const ValueKey('card')));
    await tester.pump(loanArrivalDuration);
    final landed = tester.getCenter(find.byKey(const ValueKey('card')));
    expect(falling.dy, lessThan(landed.dy));
  });

  testWidgets('reduce-motion keeps the loan and drops the drop', (
    tester,
  ) async {
    await pumpArrival(tester, Duration.zero, reduceMotion: true);
    expect(find.byType(Opacity), findsNothing);
  });

  group('the window a caller has to wait', () {
    test('is nothing at all when nobody was lent', () {
      expect(loanArrivalWindow(0), Duration.zero);
    });

    test('and grows by the stagger with every player', () {
      expect(
        loanArrivalWindow(8) - loanArrivalWindow(7),
        loanArrivalStagger,
      );
      // Long enough for the LAST card to have landed, which is the whole point
      // of the caller waiting at all.
      expect(
        loanArrivalWindow(8),
        greaterThan(loanArrivalStagger * 7 + loanArrivalDuration),
      );
    });
  });
}
