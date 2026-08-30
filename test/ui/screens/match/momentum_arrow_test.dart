/// Which way the game is going, on the pitch it is going on.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  group('AND WHERE IT SITS IS THE OTHER HALF OF THE READING', () {
    // **"The location of the arrow should show the dominance — closer to them
    // if I'm dominating."** The sign of the bias had a test and the POSITION
    // never did, which is why the row sat waiting on a screenshot: the one
    // thing it asks about was the one thing nothing checked. Measured off the
    // painted pixels rather than off the painter's fields, so what is asserted
    // is what a player actually sees.
    const boxWidth = 200.0;

    /// The centre of mass of everything the arrow paints, in logical pixels.
    Future<double> paintedCentre(
      WidgetTester tester, {
      required double bias,
      required bool attackingRight,
    }) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: boxWidth,
                height: 120,
                child: MomentumArrow(
                  bias: bias,
                  attackingRight: attackingRight,
                  ours: const Color(0xFF4ADE80),
                  theirs: const Color(0xFFE07A5F),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      late double centre;
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final bytes = data!.buffer.asUint8List();
        var weight = 0.0;
        var moment = 0.0;
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            final alpha = bytes[(y * image.width + x) * 4 + 3] / 255;
            weight += alpha;
            moment += alpha * x;
          }
        }
        expect(weight, greaterThan(0), reason: 'the arrow painted nothing');
        centre = moment / weight / image.width * boxWidth;
      });
      return centre;
    }

    testWidgets('OUR spell puts it in THEIR half of the strip', (tester) async {
      // Attacking right, our goal is on the left and theirs on the right.
      final ours = await paintedCentre(
        tester,
        bias: 0.9,
        attackingRight: true,
      );
      expect(ours, greaterThan(boxWidth / 2 + 5));

      // And away, where the ends are swapped, it goes the other way for the
      // same spell — the arrow follows the GOAL, not the screen.
      final away = await paintedCentre(
        tester,
        bias: 0.9,
        attackingRight: false,
      );
      expect(away, lessThan(boxWidth / 2 - 5));
    });

    testWidgets('and THEIR spell puts it in OURS', (tester) async {
      expect(
        await paintedCentre(tester, bias: -0.9, attackingRight: true),
        lessThan(boxWidth / 2 - 5),
      );
    });

    testWidgets('THE HARDER THE SPELL, THE FURTHER IT GOES', (tester) async {
      // The whole of "the location shows the dominance": it is a slider, not a
      // switch. Monotone all the way out.
      var last = double.negativeInfinity;
      for (final bias in const [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final at = await paintedCentre(
          tester,
          bias: bias,
          attackingRight: true,
        );
        expect(at, greaterThan(last), reason: 'at bias $bias');
        last = at;
      }
    });

    testWidgets('and a level game leaves it in the middle', (tester) async {
      expect(
        await paintedCentre(tester, bias: 0, attackingRight: true),
        closeTo(boxWidth / 2, 2),
      );
    });
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
