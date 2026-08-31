/// The mirrored ATK/DEF block, on the next-match card and the match page.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart';

Future<void> pumpRows(
  WidgetTester tester, {
  List<StatMod> leftMods = const [],
  List<StatMod> rightMods = const [],
  bool light = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildAppTheme(kitId: '#4caf50', light: light),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 340,
          child: MatchStatRows(
            left: (atk: 74, def: 61),
            right: (atk: 52, def: 80),
            leftRating: 68,
            rightRating: 66,
            leftMods: leftMods,
            rightMods: rightMods,
            leftBoot: false,
            rightBoot: false,
          ),
        ),
      ),
    ),
  ),
);

/// The block at a real phone width, through the real card's inset — 13 of page
/// padding and 8 of card padding a side. The bars' breakpoint is a MEDIA query,
/// so the viewport is the thing that has to be set, not the box.
Future<void> pumpAtViewport(
  WidgetTester tester,
  double viewport, {
  int value = 91,
}) async {
  tester.view.physicalSize = Size(viewport, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(kitId: '#4caf50', light: false),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 21),
            child: MatchStatRows(
              left: (atk: value, def: value),
              right: (atk: value, def: value),
              leftRating: value,
              rightRating: value,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// What the figure's own text needs, in whatever font the test is running in —
/// so the comparison against its box holds without a bundled font.
double intrinsicFigure(String text) => (TextPainter(
  text: TextSpan(
    text: text,
    style: const TextStyle(
      fontSize: 12,
      height: 1,
      fontWeight: FontWeight.w900,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
  ),
  textDirection: TextDirection.ltr,
)..layout()).width;

StatMod mod(int amount, {StatTone tone = StatTone.delta}) =>
    (icon: 'home', amount: amount, tone: tone, tip: 'why');

Color inkOfFigure(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style!.color!;

/// **A MODIFIER'S COLOUR IS ITS BADGE, not its ink.** It used to be the ink on
/// the bare pane; it is a filled chip printed in white now — reported as
/// needing to be white on green rather than green on green — so what carries
/// the tone is the plate behind it.
Color plateOfFigure(WidgetTester tester, String label) {
  final box = tester.widget<Container>(
    find
        .ancestor(of: find.text(label), matching: find.byType(Container))
        .first,
  );
  return (box.decoration! as BoxDecoration).color!;
}

void main() {
  tearDown(resetLocale);

  testWidgets('the bars are DRAWN, not zero pixels tall', (tester) async {
    // `FractionallySizedBox` with a `widthFactor` and no `heightFactor` passes
    // the incoming height through loose, and a `DecoratedBox` with no child
    // takes the smallest size it is allowed. Both tracks read as empty.
    await pumpRows(tester);
    await tester.pumpAndSettle();

    final fills = tester.widgetList<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(fills, isNotEmpty);
    for (final fill in fills) {
      expect(fill.heightFactor, 1, reason: 'or it draws at no height at all');
    }
    for (final box in find.byType(FractionallySizedBox).evaluate()) {
      expect(
        tester.getSize(find.byWidget(box.widget)).height,
        greaterThan(0),
      );
    }
  });

  testWidgets('and the stronger side gets the longer one', (tester) async {
    // ATK 74 against 52: the left track has to be visibly longer, which is the
    // whole reason the block is mirrored.
    await pumpRows(tester);
    await tester.pumpAndSettle();
    final widths = [
      for (final box in find.byType(FractionallySizedBox).evaluate())
        tester.getSize(find.byWidget(box.widget)).width,
    ];
    expect(widths.length, 4, reason: 'ATK and DEF, both sides');
    expect(widths[0], greaterThan(widths[1]), reason: 'our ATK beats theirs');
  });

  group('A MODIFIER IS COLOURED BY ITS SIGN, NOT BY WHOSE SIDE IT IS ON', () {
    // The tone used to mean "in our favour" / "against us", so the away side's
    // `+4` for home advantage came out RED while ours came out green — and both
    // of them are the same fact: four points added to the figure above. Reported
    // as "regardless if that's home or away, it's a plus so it should be green".
    testWidgets('the same plus is the same green on both sides', (tester) async {
      await pumpRows(tester, leftMods: [mod(4)], rightMods: [mod(3)]);
      await tester.pumpAndSettle();
      expect(plateOfFigure(tester, '+4'), plateOfFigure(tester, '+3'));
      expect(inkOfFigure(tester, '+4'), Colors.white);
      expect(
        plateOfFigure(tester, '+4'),
        semanticInk(
          tester.element(find.text('+4')),
          statToneColor(tester.element(find.text('+4')), StatTone.delta, 4),
          light: true,
        ),
      );
    });

    testWidgets('AND A MINUS IS RED, prints its own sign, and is not the green', (
      tester,
    ) async {
      // Nothing produces one yet — every modifier the card builds is an
      // addition — so what this pins is that the sign is read off the NUMBER.
      // It was a hardcoded `+`, which is why the colour had to come from
      // somewhere else in the first place.
      await pumpRows(tester, leftMods: [mod(-2), mod(5)]);
      await tester.pumpAndSettle();
      expect(find.text('-2'), findsOneWidget);
      expect(plateOfFigure(tester, '-2'), isNot(plateOfFigure(tester, '+5')));
    });

    testWidgets('and a relegation scrap is neither, on either side', (
      tester,
    ) async {
      // Amber is the one tone left, and it is left because a scrap lifts
      // whoever is in it — so it is not a verdict on the fixture and it reads
      // the same from both benches.
      await pumpRows(
        tester,
        leftMods: [mod(4, tone: StatTone.warn)],
        rightMods: [mod(4, tone: StatTone.delta)],
      );
      await tester.pumpAndSettle();
      final plates = tester
          .widgetList<Container>(
            find.ancestor(
              of: find.text('+4'),
              matching: find.byType(Container),
            ),
          )
          .map((c) => (c.decoration! as BoxDecoration).color)
          .toSet();
      expect(plates.length, 2, reason: 'warn is not the plus green');
    });

    testWidgets('and the tap tip is reachable without a long press', (
      tester,
    ) async {
      // `Tooltip`'s default trigger on a touch screen is a LONG PRESS, so the
      // sentence behind a `+1` was an explanation nobody could reach.
      await pumpRows(tester, leftMods: [mod(4)]);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Tooltip>(
              find.ancestor(
                of: find.text('+4'),
                matching: find.byType(Tooltip),
              ),
            )
            .triggerMode,
        TooltipTriggerMode.tap,
      );
    });
  });

  group('the stat figures', () {
    testWidgets('are not clipped by the bar beside them', (tester) async {
      // **The figure did not shrink in the spec; the bar did.**
      // `.nm-stat-val` is `flex: 0 0 auto; min-width: 19px` against a
      // `.nm-stat-bar` of `flex: 1`, and this had them the other way round —
      // the figure took a 2/7 proportional share of its side. A share is not a
      // leftover, so the 19 never applied: the box measured 9.3pt on a 340pt
      // card, narrower than ONE digit, and every two-figure stat was clipped to
      // its first digit at every width. 91 against 81 read as 9 against 8.
      await pumpAtViewport(tester, 390);
      final box = tester.getSize(find.byKey(const ValueKey('nm-stat-atk-l')));
      expect(
        box.width,
        greaterThanOrEqualTo(intrinsicFigure('91')),
        reason: 'the whole number, not its first digit',
      );
    });

    testWidgets('and keep the 19pt floor at every phone width', (tester) async {
      // The floor is what lines the four figures up with each other; it is also
      // the number that proves the figure is not back on a proportional share,
      // whatever the running font makes of two digits.
      for (final viewport in [320.0, 360.0, 375.0, 390.0, 430.0]) {
        await pumpAtViewport(tester, viewport);
        for (final key in ['atk-l', 'atk-r', 'def-l', 'def-r']) {
          expect(
            tester.getSize(find.byKey(ValueKey('nm-stat-$key'))).width,
            greaterThanOrEqualTo(19),
            reason: 'at $viewport, $key',
          );
        }
      }
    });
  });

  group('on a narrow phone the bars come off', () {
    // MEASURED in the spec rather than picked (`@media (max-width: 379px)`):
    // the bar width is derived from the card's, and at 375 and under every one
    // of them bottoms out on its 12pt floor whatever figure it is drawing —
    // four identical stubs claiming to compare four different numbers. The
    // figures stay; they are the data, and the bars were only the shape of it.
    testWidgets('at 375, and the four figures stay', (tester) async {
      await pumpAtViewport(tester, 375);
      expect(find.byType(FractionallySizedBox), findsNothing);
      for (final key in ['atk-l', 'atk-r', 'def-l', 'def-r']) {
        expect(find.byKey(ValueKey('nm-stat-$key')), findsOneWidget);
      }
    });

    testWidgets('and are back at 390', (tester) async {
      await pumpAtViewport(tester, 390);
      expect(find.byType(FractionallySizedBox), findsNWidgets(4));
    });
  });


  group('A MODIFIER IS A CONTROL, and it never once took a tap', () {
    // They were a `Positioned` hanging out of the bottom of a `Clip.none`
    // stack, which paints outside a box and hit-tests nothing outside it: the
    // glyphs drew where they were meant to and every tap fell through to the
    // card behind. The `Tooltip` that says what home advantage IS had been
    // unreachable since the day it was written.
    const homeAdv = (
      icon: 'home',
      amount: 4,
      tone: StatTone.delta,
      tip: 'Home advantage',
    );

    testWidgets('tapping one says what it is, and it goes again', (
      tester,
    ) async {
      await pumpRows(tester, leftMods: const [homeAdv]);
      await tester.pumpAndSettle();
      expect(find.text('Home advantage'), findsNothing);

      await tester.tap(find.byType(Tooltip));
      await tester.pumpAndSettle();
      expect(find.text('Home advantage'), findsOneWidget);

      // It is a popup, not a panel: nobody has to put it away.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Home advantage'), findsNothing);
    });

    testWidgets('and the glyph is inside its own side, not hanging off it', (
      tester,
    ) async {
      // The hit test walks the tree by BOX, so a mark drawn past the edge of
      // the rating it belongs to is a mark nothing can reach.
      await pumpRows(tester, leftMods: const [homeAdv]);
      await tester.pumpAndSettle();
      final mod = tester.getRect(find.byType(Tooltip));
      final side = tester.getRect(find.byKey(const ValueKey('nm-rating-left')));
      expect(side.contains(mod.topLeft), isTrue);
      expect(side.contains(mod.bottomRight - const Offset(0.5, 0.5)), isTrue);
    });

    testWidgets('on the narrowest phone too', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpRows(tester, rightMods: const [homeAdv]);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Tooltip));
      await tester.pumpAndSettle();
      expect(find.text('Home advantage'), findsOneWidget);
    });

    testWidgets('and a fixture with none pays nothing for the band', (
      tester,
    ) async {
      // The match page's own board never carries one, and a strip of reserved
      // air under the ratings on the one screen with no room to spare is a
      // cost for nothing.
      await pumpRows(tester);
      await tester.pumpAndSettle();
      final bare = tester.getSize(find.byKey(const ValueKey('nm-rating-left')));
      await pumpRows(tester, leftMods: const [homeAdv]);
      await tester.pumpAndSettle();
      final banded = tester.getSize(
        find.byKey(const ValueKey('nm-rating-left')),
      );
      expect(banded.height, greaterThan(bare.height));
    });

    testWidgets('AND THE TWO FIGURES STILL LINE UP', (tester) async {
      // The band is reserved on both sides whether there are modifiers in it
      // or not — in flow and only when present, the side WITH one sat higher
      // than the side without.
      await pumpRows(tester, leftMods: const [homeAdv]);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('nm-figure-left'))).top,
        closeTo(
          tester.getRect(find.byKey(const ValueKey('nm-figure-right'))).top,
          0.01,
        ),
      );
    });
  });

}
