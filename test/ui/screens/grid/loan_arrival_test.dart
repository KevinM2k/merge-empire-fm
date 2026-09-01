/// The loan stars dropping into the grid, one at a time.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/grid/card_shatter.dart';
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

Future<void> pumpDeparture(
  WidgetTester tester,
  Duration? delay, {
  bool reduceMotion = false,
}) => tester.pumpWidget(
  MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: LoanDeparture(
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

/// How far through its break a departing card is.
double _breaking(WidgetTester tester) =>
    tester.widget<CardShatter>(find.byType(CardShatter)).progress;

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

  /// **The loan going home, which the port used to do by deleting it.**
  ///
  /// It flew off on `loan-card-exit` — up a little, then away and down — and
  /// the report from the couch was that it should POOF, or come apart the way
  /// the auto-sell does. It does the second: [CardShatter] is the game's own
  /// effect for a card leaving the grid, and a second one would have been two
  /// that drift.
  group('and the departure', () {
    testWidgets('leaves a card that is staying alone', (tester) async {
      await pumpDeparture(tester, null);
      expect(find.byType(CardShatter), findsNothing);
    });

    testWidgets('holds a card whole until its turn', (tester) async {
      await pumpDeparture(tester, loanDepartureStagger * 3);
      expect(_breaking(tester), 0);
      await tester.pump(loanDepartureStagger);
      expect(_breaking(tester), 0, reason: 'not its turn yet');
      // The timer fires the controller; the first tick is the frame after.
      await tester.pump(loanDepartureStagger * 3);
      await tester.pump(loanDepartureDuration);
      expect(_breaking(tester), greaterThanOrEqualTo(1));
    });

    testWidgets('and then comes apart into pieces of itself', (tester) async {
      await pumpDeparture(tester, Duration.zero);
      await tester.pump(loanDepartureDuration * 0.3);
      final part = _breaking(tester);
      expect(part, greaterThan(0));
      expect(part, lessThan(1), reason: 'still on its way apart');
      // **Past 1 by the end, deliberately.** The pieces run to slightly
      // different lengths, so a figure capped at 1 freezes the slow ones in
      // mid-air — see `cardShatterFrayMs`.
      await tester.pump(loanDepartureDuration);
      expect(_breaking(tester), greaterThan(1));
    });

    testWidgets('and answers no drag on the way out', (tester) async {
      await pumpDeparture(tester, Duration.zero);
      expect(find.byType(IgnorePointer), findsOneWidget);
      await tester.pump(loanDepartureDuration);
    });

    testWidgets('reduce-motion takes them without the flight', (tester) async {
      await pumpDeparture(tester, Duration.zero, reduceMotion: true);
      expect(find.byKey(const ValueKey('card')), findsNothing);
    });

    test('and the window is nothing when nothing was lent', () {
      expect(loanDepartureWindow(0), Duration.zero);
      expect(
        loanDepartureWindow(8) - loanDepartureWindow(7),
        loanDepartureStagger,
      );
      // Long enough for the LAST card to have gone.
      expect(
        loanDepartureWindow(8),
        greaterThanOrEqualTo(loanDepartureStagger * 7 + loanDepartureDuration),
      );
    });
  });
}
