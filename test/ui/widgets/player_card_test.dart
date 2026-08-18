/// The player card — the most-repeated widget in the game.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/card_theme.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';

const CardView _view = (
  name: 'Bobby Charlton',
  tier: 5,
  rating: 72,
  position: 'FWD',
  injured: false,
  onLoan: false,
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

  testWidgets('light mode swaps the body, not the chips', (tester) async {
    await pumpCard(tester, _view, light: true);
    final gradient = decorationOf(tester).gradient! as LinearGradient;
    expect(
      gradient.colors.first,
      cssColor(tierThemes[5]!.bgLight.stops.first.$1),
    );
    // The chips keep the dark label background so bright rarity text still
    // reads on top of them.
    expect(find.text('72'), findsOneWidget);
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
      ));
      final border = decorationOf(tester).border! as Border;
      expect(
        border.top.color,
        cssColor(tierThemes[tier]!.accent),
        reason: 'tier $tier',
      );
    }
  });

  testWidgets('an unknown tier falls back rather than throwing', (tester) async {
    // The tier comes off the save, so a card from a future build must not
    // white-screen the grid.
    await pumpCard(tester, (
      name: 'X',
      tier: 99,
      rating: 50,
      position: 'MID',
      injured: false,
      onLoan: false,
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
    ));
    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(find.textContaining('Wojciech'));
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.maxLines, 1);
  });
}
