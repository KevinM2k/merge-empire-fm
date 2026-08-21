/// Which way the game is going, on the pitch it is going on.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/match/momentum_arrow.dart';

void main() {
  group('the reading', () {
    test('is OUR share, whichever ground we are on', () {
      // `possHome` is home-positive; the arrow is ours-positive, because we
      // always defend the left on this pitch whoever is at home.
      expect(momentumBias(possHome: 66, isHome: true), greaterThan(0));
      expect(momentumBias(possHome: 66, isHome: false), lessThan(0));
      expect(momentumBias(possHome: 34, isHome: false), greaterThan(0));
    });

    test('and a level game points nowhere in particular', () {
      expect(momentumBias(possHome: 50, isHome: true), 0);
      expect(momentumBias(possHome: 50, isHome: false), 0);
    });

    test('it never leaves the pitch', () {
      // The board clamps possession to 28–72, but the arrow must hold even if
      // that ever loosens.
      for (final poss in [0, 10, 28, 50, 72, 90, 100]) {
        for (final home in [true, false]) {
          final bias = momentumBias(possHome: poss, isHome: home);
          expect(bias, inInclusiveRange(-1, 1));
        }
      }
    });
  });

  testWidgets('AWAY, our best spell points the other way', (tester) async {
    // At home we attack right and away we attack left — the same rule the 2D
    // pitch follows, so the arrow and the passage of play it turns into cannot
    // point opposite ways.
    Widget at({required bool attackingRight}) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: 200,
          height: 120,
          child: MomentumArrow(
            bias: 0.8,
            attackingRight: attackingRight,
            ours: const Color(0xFF4ADE80),
            theirs: const Color(0xFFE07A5F),
          ),
        ),
      ),
    );
    await tester.pumpWidget(at(attackingRight: true));
    await tester.pumpAndSettle();
    final home = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('match-momentum')),
    );
    await tester.pumpWidget(at(attackingRight: false));
    await tester.pumpAndSettle();
    final away = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('match-momentum')),
    );
    expect(
      away.painter,
      isNot(equals(home.painter)),
      reason: 'the same arrow at home and away',
    );
  });

  testWidgets('the arrow draws, and redraws when the game swings', (
    tester,
  ) async {
    Widget at(double bias) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: 200,
          height: 120,
          child: MomentumArrow(
            bias: bias,
            attackingRight: true,
            ours: const Color(0xFF4ADE80),
            theirs: const Color(0xFFE07A5F),
          ),
        ),
      ),
    );

    await tester.pumpWidget(at(0.5));
    expect(find.byKey(const ValueKey('match-momentum')), findsOneWidget);
    // It GLIDES rather than jumping: possession moves on every chance, and an
    // arrow that snaps reads as a bug rather than as a game swinging.
    await tester.pumpWidget(at(-0.5));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('match-momentum')), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
