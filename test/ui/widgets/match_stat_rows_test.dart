/// The mirrored ATK/DEF block, on the next-match card and the match page.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';

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

/// The colour of the GLYPH in the badge that carries [label]. `at` picks
/// between two badges printing the same figure — one on each side.
Color glyphInk(WidgetTester tester, String label, {int at = 0}) => tester
    .widgetList<GameIcon>(
      find.descendant(
        // The INNERMOST row around this particular figure — `at` indexes the
        // figure, not the row, because two badges can print the same number.
        of: find
            .ancestor(of: find.text(label).at(at), matching: find.byType(Row))
            .first,
        matching: find.byType(GameIcon),
      ),
    )
    .first
    .color!;

/// **A MODIFIER'S COLOUR IS ITS INK, on a neutral recess.**
///
/// Three rounds, and the middle one is why this helper exists: it was the hue
/// on a 13% wash of itself (unreadable), then WHITE on a solid plate of the
/// hue (readable, and three blocks of colour on a card whose loudest thing is
/// meant to be the ratings), and now the deep member of the pair as ink on the
/// recess every panel in the app recesses with. So the tone is back on the
/// figure, and [plateOfFigure] is what checks the recess is NOT carrying it.
Color plateOfFigure(WidgetTester tester, String label) {
  final box = tester.widget<Container>(
    find
        .ancestor(of: find.text(label), matching: find.byType(Container))
        .first,
  );
  return (box.decoration! as BoxDecoration).color!;
}

/// The colour a modifier of this tone and amount is drawn in.
///
/// The vivid member in BOTH themes, because the badge is a dent in the same
/// dark recess the ATK/DEF ratings sit in — asked for from the couch in those
/// words: use the green we use for ATK/DEF.
Color toneInk(WidgetTester tester, String label, StatTone tone, int amount) =>
    tone == StatTone.warn
    ? vsAmberBright
    : amount < 0
    ? vsRedBright
    : vsGreenBright;

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
      // **THE FIGURE IS WHITE and the GLYPH carries the tone.** A shape reads
      // at any luminance; a number has to be legible. Asked for from the couch:
      // the text can be white, just not the whole thing.
      expect(inkOfFigure(tester, '+4'), vividWellInk);
      expect(inkOfFigure(tester, '+3'), vividWellInk);
      // Green, whichever side it is on.
      expect(glyphInk(tester, '+4'), toneInk(tester, '+4', StatTone.delta, 4));
      expect(glyphInk(tester, '+3'), glyphInk(tester, '+4'));
      // **THE GROUND CARRIES NONE OF IT.** Reported from the couch: three solid
      // blocks of colour stand out a lot on a card whose loudest thing is meant
      // to be the two ratings. It is the pane's own recess now, and the tone
      // lives on the rim and the figure.
      expect(plateOfFigure(tester, '+4'), plateOfFigure(tester, '+3'));
      expect(
        plateOfFigure(tester, '+4'),
        isNot(toneInk(tester, '+4', StatTone.delta, 4)),
      );
    });

    testWidgets('AND IT STILL HAS A CHASSIS IN LIGHT MODE', (tester) async {
      // Two rounds of this. A 5% wash of `glassInk` is WHITE on a light pane —
      // the badge had no ground at all and the figure floated, reported
      // immediately. A 16% wash of the hue put it back and failed the contrast
      // sweep at 2.70:1, because this card sits on glass over a pitch and a
      // green kit makes that pane green before any tint is added.
      for (final light in [false, true]) {
        await pumpRows(tester, leftMods: [mod(4)], light: light);
        await tester.pumpAndSettle();
        final plate = plateOfFigure(tester, '+4');
        // **THE SAME DARK RECESS IN BOTH THEMES.** Four rounds went looking for
        // a plate that would carry a bright figure and every one landed on
        // something opaque — an opaque `surface2`, a 7% hue wash over it, a 13%
        // wash — and every one came back as a white sticker on a pane built out
        // of blur, the last of them with a screenshot. Deepening the ink
        // instead bought the contrast and cost the colour, so it takes the
        // treatment the ATK/DEF block above it already has.
        expect(plate, vividWellFill, reason: 'light: $light');

        // And white on it measures, on a light pane as on a dark one.
        final ground = Color.alphaBlend(
          plate,
          Theme.of(
            tester.element(find.text('+4')),
          ).extension<KitTheme>()!.surface2,
        );
        final a = ground.computeLuminance();
        final b = inkOfFigure(tester, '+4').computeLuminance();
        final ratio = ((a > b ? a : b) + 0.05) / ((a < b ? a : b) + 0.05);
        expect(ratio, greaterThanOrEqualTo(4.5), reason: 'light: $light');
      }
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
      expect(glyphInk(tester, '-2'), isNot(glyphInk(tester, '+5')));
      expect(glyphInk(tester, '-2'), vsRedBright);
      // The recess is the same either way — it is the block's own, not the
      // hue's — so only the glyph and the rim carry the sign.
      expect(plateOfFigure(tester, '-2'), plateOfFigure(tester, '+5'));
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
      expect(glyphInk(tester, '+4', at: 0), vsAmberBright);
      expect(glyphInk(tester, '+4', at: 1), vsGreenBright);
    });

    testWidgets('THREE OF THEM STAY OUT OF THE ATK/DEF BLOCK', (tester) async {
      // **Reported from the couch: "the game modifiers overlay the ATK and DEF
      // ratings when there is more than one. I think we can have 3 so need to
      // cater for it."** An away grudge against a side in the drop zone is
      // three, and the row was `MainAxisSize.min` and centred inside a rating
      // column sitting in a `Clip.none` stack — so it grew straight over the
      // well between the two sides.
      await pumpRows(
        tester,
        leftMods: [mod(4), mod(3), mod(2)],
        rightMods: [mod(1)],
      );
      await tester.pumpAndSettle();

      final well = tester.getRect(find.byKey(const ValueKey('nm-stat-well')));
      for (final label in ['+4', '+3', '+2']) {
        final badge = tester.getRect(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(
          badge.right,
          lessThanOrEqualTo(well.left + 0.5),
          reason: '$label is painted over the ratings',
        );
      }
    });

    testWidgets('THE COLUMN HAS ONE CENTRE, whatever is in it', (tester) async {
      // Two goes at anchoring this. Outward, a lone badge sat hard against the
      // edge of the card with an inch of nothing between it and the rating it
      // belongs to. Inward, one sat tight against the well and two sat
      // somewhere else again — reported with a screenshot: one is slightly
      // misaligned, two have odd gaps, three would be worse. Both are the same
      // fault, which is that an anchored group MOVES as the count changes.
      Rect groupOf(String first, String last) {
        Rect badge(String label) => tester.getRect(
          find
              .ancestor(of: find.text(label), matching: find.byType(Container))
              .first,
        );
        final a = badge(first);
        final b = badge(last);
        return Rect.fromLTRB(
          a.left < b.left ? a.left : b.left,
          a.top,
          a.right > b.right ? a.right : b.right,
          b.bottom,
        );
      }

      await pumpRows(tester, leftMods: [mod(4)], rightMods: [mod(1)]);
      await tester.pumpAndSettle();
      final well = tester.getRect(find.byKey(const ValueKey('nm-stat-well')));
      // **THE INNER EDGE IS THE ANCHOR** — the one nearest the figure. A third
      // badge makes the column scale down, so the OUTER edge moves inward and
      // the inner one does not: that is the point of anchoring it there.
      final oneInner = groupOf('+4', '+4').right;
      final oneRight = groupOf('+1', '+1').left;

      // Two on each side, STACKED — and the column does not move sideways.
      await pumpRows(
        tester,
        leftMods: [mod(4), mod(2)],
        rightMods: [mod(1), mod(3)],
      );
      await tester.pumpAndSettle();
      expect(groupOf('+4', '+2').right, closeTo(oneInner, 2));
      expect(groupOf('+1', '+3').left, closeTo(oneRight, 2));
      // One above the other, which is the whole of the change.
      expect(
        tester.getRect(find.text('+2')).top,
        greaterThan(tester.getRect(find.text('+4')).top),
      );

      // Three, and the column still starts in the same place — and still clear
      // of the ratings, which is the constraint the margin exists for.
      await pumpRows(
        tester,
        leftMods: [mod(4), mod(2), mod(6)],
        rightMods: [mod(1)],
      );
      await tester.pumpAndSettle();
      final three = groupOf('+4', '+6');
      expect(three.right, closeTo(oneInner, 2));
      expect(three.right, lessThanOrEqualTo(well.left + 0.5));

      // **AND EACH STANDS AGAINST ITS OWN FIGURE**, not out at the card's edge
      // — reported from the couch as looking lost. `modInset` is half a figure
      // plus a gap, so a badge clears the number and nothing else, and the two
      // sides are reflections because both are measured the same way.
      await pumpRows(tester, leftMods: [mod(4)], rightMods: [mod(1)]);
      await tester.pumpAndSettle();
      final leftFigure = tester.getRect(
        find.byKey(const ValueKey('nm-figure-left')),
      );
      final rightFigure = tester.getRect(
        find.byKey(const ValueKey('nm-figure-right')),
      );
      final leftGap = leftFigure.left - groupOf('+4', '+4').right;
      final rightGap = groupOf('+1', '+1').left - rightFigure.right;
      expect(oneRight, isNotNaN);
      expect(leftGap, greaterThanOrEqualTo(0));
      expect(rightGap, greaterThanOrEqualTo(0));
      expect(leftGap, closeTo(rightGap, 2), reason: 'the sides do not mirror');
      expect(
        leftGap,
        lessThan(leftFigure.width),
        reason: 'the badge is nowhere near the number it annotates',
      );
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

    testWidgets('and the two sides are always the same height', (tester) async {
      // **THE PAIR DECIDES, not each side.** The modifiers stood in a reserved
      // band UNDER the figure for three rounds, and the reason the band was
      // reserved on both sides is the one that still applies: a side WITH a
      // modifier sitting higher than a side without is two ratings that stop
      // lining up.
      //
      // What has changed is that the block GROWS with the count rather than
      // scaling the badges into a fixed strip — because a scaled badge renders
      // its figure under the type floor, which is the one thing this app does
      // not do.
      await pumpRows(tester);
      await tester.pumpAndSettle();
      final bare = tester.getSize(find.byKey(const ValueKey('nm-rating-left')));

      double heightOf(String key) =>
          tester.getSize(find.byKey(ValueKey(key))).height;

      var last = bare.height;
      for (final mods in [
        [homeAdv],
        [homeAdv, mod(2)],
        [homeAdv, mod(2), mod(3)],
      ]) {
        await pumpRows(tester, leftMods: mods);
        await tester.pumpAndSettle();
        expect(
          heightOf('nm-rating-left'),
          heightOf('nm-rating-right'),
          reason: '${mods.length} on one side only, and the sides diverged',
        );
        expect(
          heightOf('nm-rating-left'),
          greaterThanOrEqualTo(last),
          reason: 'the block shrank as modifiers were added',
        );
        last = heightOf('nm-rating-left');
      }

      // And the figure inside every one of them is at full size — no badge is
      // ever scaled to fit, which is the whole reason the block grows.
      for (final label in ['+3', '+2']) {
        expect(
          tester.widget<Text>(find.text(label)).style!.fontSize,
          minFontSize,
        );
      }
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
