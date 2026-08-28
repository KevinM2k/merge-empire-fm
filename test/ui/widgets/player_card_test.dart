/// The player card — the most-repeated widget in the game.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/card_theme.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';

const CardView _view = (
  name: 'Bobby Charlton',
  tier: 5,
  rating: 72,
  position: 'FWD',
  injured: false,
  onLoan: false,
  variant: 0,
  fitness: null,
  incomePerSec: null,
  maxed: false,
  atCap: false,
  trait: null,
);

Future<void> pumpCard(
  WidgetTester tester,
  CardView view, {
  bool light = false,
  VoidCallback? onTap,
  bool selected = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildAppTheme(kitId: '#4caf50', light: light),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 90,
          height: 120,
          child: PlayerCard(
            view: view,
            light: light,
            onTap: onTap,
            selected: selected,
          ),
        ),
      ),
    ),
  ),
);

BoxDecoration decorationOf(WidgetTester tester) =>
    tester
            .widget<Container>(
              find
                  .descendant(
                    of: find.byType(PlayerCard),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

void main() {
  testWidgets('shows the rating, the position label and the name', (
    tester,
  ) async {
    await pumpCard(tester, _view);
    expect(find.text('72'), findsOneWidget);
    // The data says FWD; the card says ATK.
    expect(find.text('ATK'), findsOneWidget);
    expect(find.text('Bobby Charlton'), findsOneWidget);
  });

  testWidgets('every card gets its own RepaintBoundary', (tester) async {
    // One card animating must not repaint the grid around it. This is the
    // frame-budget rule the M0 probe was built to measure.
    await pumpCard(tester, _view);
    expect(
      find.descendant(
        of: find.byType(PlayerCard),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
  });

  testWidgets('the body paints its tier gradient', (tester) async {
    await pumpCard(tester, _view);
    final gradient = decorationOf(tester).gradient! as LinearGradient;
    final expected = tierThemes[5]!.bg;
    expect(gradient.colors.length, expected.stops.length);
    expect(gradient.colors.first, cssColor(expected.stops.first.$1));
    expect(gradient.stops!.first, 0);
    expect(gradient.stops!.last, 1);
  });

  testWidgets('light mode swaps the body', (tester) async {
    await pumpCard(tester, _view, light: true);
    final gradient = decorationOf(tester).gradient! as LinearGradient;
    expect(
      gradient.colors.first,
      cssColor(tierThemes[5]!.bgLight.stops.first.$1),
    );
    expect(find.text('72'), findsOneWidget);
  });

  group('AND THE CHIPS SWAP WITH IT', () {
    // **They did not, and that is what a light-mode card kept reading as dark
    // at the foot of.** The scrim under the caption was fixed a pass earlier
    // and the report came back, which was the tell: the band is white and the
    // TIER CHIP sitting on it was `#3d2000`.
    Color chipFillFor(WidgetTester tester, String label) {
      final box = tester.widget<Container>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Container))
            .first,
      );
      return (box.decoration! as BoxDecoration).color!;
    }

    Color chipInkFor(WidgetTester tester, String label) =>
        tester.widget<Text>(find.text(label)).style!.color!;

    testWidgets('dark mode is untouched — pale ink on the label ground', (
      tester,
    ) async {
      await pumpCard(tester, _view);
      expect(chipFillFor(tester, '72'), cssColor(tierThemes[5]!.labelBg));
      expect(chipInkFor(tester, '72'), cssColor(tierThemes[5]!.accentLight));
    });

    testWidgets('LIGHT MODE INVERTS THE JOB OF THE TWO, not their values', (
      tester,
    ) async {
      // Swapping ground and ink does not work: four of the nine accents are
      // `#ffaa00`, `#00c8ff` and friends and none of them carries on white. So
      // the contrast comes from near-black INK and the tier is carried by a
      // pale TINT of its own colour.
      await pumpCard(tester, _view, light: true);
      final fill = chipFillFor(tester, '72');
      expect(fill, isNot(cssColor(tierThemes[5]!.labelBg)));
      expect(
        fill.computeLuminance(),
        greaterThan(0.5),
        reason: 'a light-mode chip is a pale ground, not a dark one',
      );
      expect(chipInkFor(tester, '72').computeLuminance(), lessThan(0.1));
    });

    testWidgets('and the tier chip at the FOOT gets it too', (tester) async {
      // The one the report was actually about — top-left is the rating, and
      // this is the band under the name.
      await pumpCard(tester, _view, light: true);
      final label = tierLabel[5]!;
      expect(
        chipFillFor(tester, label).computeLuminance(),
        greaterThan(0.5),
      );
      expect(chipInkFor(tester, label).computeLuminance(), lessThan(0.1));
    });

    testWidgets('EVERY TIER CLEARS ITS OWN INK in light mode', (tester) async {
      // A pale tint is only pale for tiers whose accent is; this is the check
      // that no tier tints itself back into a dark chip.
      for (final tier in tierThemes.keys) {
        await pumpCard(tester, (
          name: 'X',
          tier: tier,
          rating: 50,
          position: 'MID',
          injured: false,
          onLoan: false,
          variant: 0,
          fitness: null,
          incomePerSec: null,
          maxed: false,
          atCap: false,
          trait: null,
        ), light: true);
        expect(
          chipFillFor(tester, '50').computeLuminance(),
          greaterThan(0.45),
          reason: 'tier $tier',
        );
      }
    });
  });

  testWidgets('each tier paints its own accent border', (tester) async {
    for (final tier in tierThemes.keys) {
      await pumpCard(tester, (
        name: 'X',
        tier: tier,
        rating: 50,
        position: 'MID',
        injured: false,
        onLoan: false,
        variant: 0,
        fitness: null,
        incomePerSec: null,
        maxed: false,
        atCap: false,
        trait: null,
      ));
      final border = decorationOf(tester).border! as Border;
      expect(
        border.top.color,
        cssColor(tierThemes[tier]!.accent),
        reason: 'tier $tier',
      );
    }
  });

  testWidgets('an unknown tier falls back rather than throwing', (
    tester,
  ) async {
    // The tier comes off the save, so a card from a future build must not
    // white-screen the grid.
    await pumpCard(tester, (
      name: 'X',
      tier: 99,
      rating: 50,
      position: 'MID',
      injured: false,
      onLoan: false,
      variant: 0,
      fitness: null,
      incomePerSec: null,
      maxed: false,
      atCap: false,
      trait: null,
    ));
    expect(find.text('X'), findsOneWidget);
  });

  testWidgets('selection thickens the border and brightens it', (tester) async {
    await pumpCard(tester, _view);
    final plain = decorationOf(tester).border! as Border;
    await pumpCard(tester, _view, selected: true);
    final picked = decorationOf(tester).border! as Border;
    expect(picked.top.width, greaterThan(plain.top.width));
    expect(picked.top.color, cssColor(tierThemes[5]!.accentLight));
  });

  testWidgets('an injury and a loan each show a marker', (tester) async {
    await pumpCard(tester, (
      name: 'X',
      tier: 3,
      rating: 40,
      position: 'DEF',
      injured: true,
      onLoan: true,
      variant: 0,
      fitness: null,
      incomePerSec: null,
      maxed: false,
      atCap: false,
      trait: null,
    ));
    expect(find.byIcon(Icons.healing), findsOneWidget);
    expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
  });

  testWidgets('a fit card shows no markers', (tester) async {
    await pumpCard(tester, _view);
    expect(find.byIcon(Icons.healing), findsNothing);
    expect(find.byIcon(Icons.swap_horiz), findsNothing);
  });

  testWidgets('a tap is reported', (tester) async {
    var taps = 0;
    await pumpCard(tester, _view, onTap: () => taps++);
    await tester.tap(find.byType(PlayerCard));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('a long name is truncated rather than overflowing', (
    tester,
  ) async {
    await pumpCard(tester, (
      name: 'Wojciech Szczesny-Lewandowski III',
      tier: 5,
      rating: 72,
      position: 'GK',
      injured: false,
      onLoan: false,
      variant: 0,
      fitness: null,
      incomePerSec: null,
      maxed: false,
      atCap: false,
      trait: null,
    ));
    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(find.textContaining('Wojciech'));
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.maxLines, 1);
  });

  group('fitness', () {
    testWidgets('is not drawn at all in casual mode', (tester) async {
      // Per-player fitness is a Pro-mode idea; casual play has team energy pips.
      // A bar pinned at 100% for every casual player is a number that never
      // moves, which is worse than no bar.
      await pumpCard(tester, _view);
      expect(find.byKey(const ValueKey('card-fitness')), findsNothing);
    });

    testWidgets('is drawn when the save is in Pro mode', (tester) async {
      await pumpCard(tester, (
        name: 'X',
        tier: 5,
        rating: 70,
        position: 'MID',
        injured: false,
        onLoan: false,
        variant: 0,
        fitness: 0.5,
        incomePerSec: null,
        maxed: false,
        atCap: false,
        trait: null,
      ));
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('card-fitness')),
      );
      expect(bar.value, 0.5);
    });

    testWidgets('a spent player is flagged red', (tester) async {
      await pumpCard(tester, (
        name: 'X',
        tier: 5,
        rating: 70,
        position: 'MID',
        injured: false,
        onLoan: false,
        variant: 0,
        fitness: 0.1,
        incomePerSec: null,
        maxed: false,
        atCap: false,
        trait: null,
      ));
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('card-fitness')),
      );
      expect(bar.valueColor!.value, Colors.redAccent);
    });

    testWidgets('an out-of-range value is clamped rather than thrown at', (
      tester,
    ) async {
      for (final value in [-0.5, 1.5]) {
        await pumpCard(tester, (
          name: 'X',
          tier: 5,
          rating: 70,
          position: 'MID',
          injured: false,
          onLoan: false,
          variant: 0,
          fitness: value,
          incomePerSec: null,
          maxed: false,
          atCap: false,
          trait: null,
        ));
        expect(tester.takeException(), isNull, reason: '$value');
      }
    });
  });
  group('THE PICTURE SITS IN A WELL, not across the whole card', () {
    testWidgets('inset from the border, under the strip, above the footer', (
      tester,
    ) async {
      // `.card-artwrap` is `flex: 1; margin: 2px 3px 0` under a 4px
      // `.card-strip`, with `.card-footer` below it. The port had the portrait
      // as a `Positioned.fill` across the whole card with everything floating
      // over it, so the drawing ran under the border and under the rating chip.
      await pumpCard(tester, _view);
      final card = tester.getRect(find.byType(PlayerCard));
      final art = tester.getRect(find.byType(ArtImage));

      expect(art.left, greaterThan(card.left));
      expect(art.right, lessThan(card.right));
      // The 2pt border, the 4pt strip and the 2pt margin.
      expect(art.top, greaterThanOrEqualTo(card.top + 8));
      // And it stops at the footer rather than running behind it.
      expect(
        art.bottom,
        lessThanOrEqualTo(tester.getRect(find.text(_view.name)).top),
      );
    });

    testWidgets('and the WHOLE figure fits — contain, not a crop', (
      tester,
    ) async {
      // `object-fit: contain`. The port used `fitWidth`, which scales a square
      // drawing to the card's full width and pins it to the top: bigger than
      // the well the spec gives it, and cropped. A pass before that had tried
      // `contain` across the whole CARD and backed it out for the band of
      // nothing it left above his head — that is a 3:4 box, and the well is
      // near enough square.
      await pumpCard(tester, _view);
      expect(
        tester.widget<ArtImage>(find.byType(ArtImage)).fit,
        BoxFit.contain,
      );
    });
  });

  group('THE TRAIT IS ON THE CARD', () {
    // It was visible only on the sheet a tap opens, so picking an eleven — or
    // choosing who comes on — was done blind to half of what a player is
    // worth, on the one attribute the game asks him to roll for.
    testWidgets('the glyph and the level, on the art', (tester) async {
      await pumpCard(tester, (
        name: 'Bobby Charlton',
        tier: 5,
        rating: 72,
        position: 'FWD',
        injured: false,
        onLoan: false,
        variant: 0,
        fitness: null,
        incomePerSec: null,
        maxed: false,
        atCap: false,
        trait: (icon: '⚽', level: 'III', title: '⚽ Finisher III'),
      ));
      expect(find.byKey(const ValueKey('card-trait')), findsOneWidget);
      expect(find.text('⚽ III'), findsOneWidget);
      // What anything that READS rather than looks is given: the emoji and a
      // roman numeral are not a sentence.
      expect(
        tester
            .widget<Semantics>(
              find
                  .ancestor(
                    of: find.byKey(const ValueKey('card-trait')),
                    matching: find.byType(Semantics),
                  )
                  .first,
            )
            .properties
            .label,
        '⚽ Finisher III',
      );
    });

    testWidgets('and a card with none draws none', (tester) async {
      await pumpCard(tester, _view);
      expect(find.byKey(const ValueKey('card-trait')), findsNothing);
    });
  });
}
