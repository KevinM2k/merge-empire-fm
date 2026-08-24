/// The Kenney smoke, which was on disk and had no caller.
///
/// `assets/fx/puff_0..7.png` have shipped since the packs were imported and
/// nothing in `lib/` named one — the same class of finding as a translated
/// string nothing can print.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/grid/merge_burst.dart';
import 'package:merge_empire_fc/ui/screens/grid/smoke_puff.dart';

Future<void> pumpPuff(
  WidgetTester tester, {
  required bool playing,
  bool reduceMotion = false,
}) => tester.pumpWidget(
  MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: SmokePuff(playing: playing)),
    ),
  ),
);

void main() {
  group('which frame is on screen', () {
    test('every eighth of the run is one frame, and the last is HELD', () {
      // `t == 1` is the end of the eighth frame's slot, not the start of a
      // ninth that does not exist.
      expect(frameAt(0), 0);
      expect(frameAt(0.124), 0);
      expect(frameAt(0.125), 1);
      expect(frameAt(0.5), 4);
      expect(frameAt(0.99), 7);
      expect(frameAt(1), 7);
    });

    test('and it cannot be walked off either end', () {
      expect(frameAt(-1), 0);
      expect(frameAt(5), 7);
    });

    test('there are eight of them, and each names a real asset', () {
      expect(smokePuffAssets, hasLength(smokePuffFrames));
      expect(smokePuffAssets.first, 'assets/fx/puff_0.png');
      expect(smokePuffAssets.last, 'assets/fx/puff_7.png');
    });
  });

  group('on screen', () {
    testWidgets('nothing at all until it is played', (tester) async {
      await pumpPuff(tester, playing: false);
      expect(find.byKey(const ValueKey('smoke-puff')), findsNothing);
    });

    testWidgets('a frame while it runs, and nothing after', (tester) async {
      await pumpPuff(tester, playing: true);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('smoke-puff')), findsOneWidget);
      await tester.pump(smokePuffDuration);
      expect(
        find.byKey(const ValueKey('smoke-puff')),
        findsNothing,
        reason: 'the last frame was left on screen',
      );
    });

    testWidgets('REDUCE MOTION DROPS IT ENTIRELY', (tester) async {
      // A puff is decoration with no information in it, which is the one kind
      // of effect that should simply not happen rather than jump to its end.
      await pumpPuff(tester, playing: true, reduceMotion: true);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('smoke-puff')), findsNothing);
    });
  });

  group('under the merge burst', () {
    testWidgets('THE SPRITE IS AN ADDITION, NOT A REPLACEMENT', (tester) async {
      // The burst is procedural and draws in the tier's own colours, which a
      // sprite sheet cannot do — so the smoke sits beneath it rather than
      // instead of it, and it is colourless so it can.
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 80,
                height: 110,
                child: MergeBurst(
                  tier: 3,
                  playing: true,
                  child: ColoredBox(color: Color(0xFF203040)),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byType(SmokePuff), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // And the smoke is drawn UNDER the sparks: paint order is child order.
      final children = tester
          .widget<Stack>(
            find.ancestor(
              of: find.byType(SmokePuff),
              matching: find.byType(Stack),
            ).first,
          )
          .children;
      final smokeAt = children.indexWhere(
        (c) => c is Positioned && c.child is Center,
      );
      expect(smokeAt, isNonNegative);
      expect(smokeAt, lessThan(children.length - 1));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('and it spreads wider than the square it happened in', (
      tester,
    ) async {
      // Smoke that stops at the card's edge reads as a texture printed on the
      // card rather than as air being pushed out of the way.
      expect(mergeSmokeSpread, greaterThan(80));
    });
  });
}
