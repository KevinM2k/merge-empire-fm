/// Which way the game is going, on the pitch it is going on.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/ui/screens/match/momentum_arrow.dart';

void main() {
  group('the reading', () {
    test('is OUR share, whichever ground we are on', () {
      // `possHome` is home-positive; the arrow is ours-positive, because we
      // always defend the left on this pitch whoever is at home.
      expect(momentumBias(dangerHome: 66, isHome: true), greaterThan(0));
      expect(momentumBias(dangerHome: 66, isHome: false), lessThan(0));
      expect(momentumBias(dangerHome: 34, isHome: false), greaterThan(0));
    });

    test('and a level game points nowhere in particular', () {
      expect(momentumBias(dangerHome: 50, isHome: true), 0);
      expect(momentumBias(dangerHome: 50, isHome: false), 0);
    });

    test('it never leaves the pitch', () {
      // The board clamps possession to 28–72, but the arrow must hold even if
      // that ever loosens.
      for (final poss in [0.0, 10.0, 28.0, 50.0, 72.0, 90.0, 100.0]) {
        for (final home in [true, false]) {
          final bias = momentumBias(dangerHome: poss, isHome: home);
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
  group('IT POINTS WHERE THE CHANCES ARE, not where the ball is', () {
    // **The arrow read POSSESSION and the engine attributes chances on the
    // RATINGS**, so a side set up to keep the ball moved the arrow and got no
    // more of the chances for it — which is what "the arrow doesn't mean
    // anything" is. Weighting the chances on possession instead broke
    // thirty-two rows of the parity harness, which compares the feed against
    // the JS's own: the arrow was the half that disagreed, and the arrow is the
    // port's, so the arrow is what moved.

    test('the better side takes most of them', () {
      final split = chanceWeightsFor(
        possHome: 66,
        counterHome: 0,
        counterAway: 0,
      );
      expect(split.home, greaterThan(split.away));
    });

    test('AND A COUNTER-ATTACKING SIDE IS STILL DANGEROUS', () {
      // The exception that makes it football: most possession most of the time
      // wins, and NOT always.
      final flat = chanceWeightsFor(
        possHome: 66,
        counterHome: 0,
        counterAway: 0,
      );
      final breaking = chanceWeightsFor(
        possHome: 66,
        counterHome: 0,
        counterAway: 1,
      );
      expect(breaking.away, greaterThan(flat.away));
      // Still not favourites, though — a counter is a share of the chances, not
      // the run of play.
      expect(breaking.away, lessThan(breaking.home));
    });

    test('and only the side WITHOUT the ball can counter', () {
      // That is what the word means.
      final a = chanceWeightsFor(possHome: 66, counterHome: 0, counterAway: 0);
      final b = chanceWeightsFor(possHome: 66, counterHome: 1, counterAway: 0);
      expect(b.home, a.home);
    });

    test('A TACTIC THAT SITS DEEP LEANS INTO THE BREAK', () {
      // Read off the tactic's own possession figure rather than named by id: a
      // side expecting 30% of the ball is playing for the moment it wins it
      // back, and one expecting 62% is not countering anything.
      expect(counterLeanFor('parkTheBus'), greaterThan(0));
      expect(counterLeanFor('counterAttack'), greaterThan(0));
      expect(counterLeanFor('allOutAttack'), 0);
      expect(counterLeanFor('balanced'), 0);
      expect(counterLeanFor(null), 0);
    });
  });

}
