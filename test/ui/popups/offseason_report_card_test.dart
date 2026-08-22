/// The offseason report — what the break did to the squad.
///
/// **Eleven `offseason.*` strings in ten catalogues with no caller, and the
/// engine producing the data the whole time.** `endSeason` has returned an
/// injury, a sponsor and an ageing report since M1 and every reader of the
/// three was a test.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/season_end.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/popups/offseason_report_card.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

SeasonOutcome outcomeWith({
  int recovered = 0,
  int shortened = 0,
  int expired = 0,
  List<String> retired = const [],
  String oldDivision = 'sunday_league',
  int position = 4,
}) => (
  outcome: 'stayed',
  position: position,
  oldDivision: oldDivision,
  newDivision: oldDivision,
  payout: 0,
  gemsAwarded: 0,
  ageingReport: [
    for (final name in retired)
      <String, dynamic>{
        'playerName': name,
        'fromTier': 5,
        'fromTierName': 'Gold',
        'toTier': 0,
        'toTierName': 'Retired',
        'retired': true,
        'ageingPenalty': 0,
      },
  ],
  injuryReport: (recovered: recovered, shortened: shortened),
  sponsorReport: (expired: expired),
);

Future<void> pumpCard(WidgetTester tester, SeasonOutcome outcome) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(createDefaultState())}),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: OffseasonReportCard(outcome: outcome),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(resetLocale);

  group('whether there is anything to report', () {
    test('A QUIET BREAK IS NO CARD AT ALL', () {
      // A popup that opens to say nothing happened is worse than no popup, and
      // most seasons are quiet ones.
      expect(offseasonHasNews(outcomeWith()), isFalse);
    });

    test('and any one of the three is enough', () {
      expect(offseasonHasNews(outcomeWith(recovered: 1)), isTrue);
      expect(offseasonHasNews(outcomeWith(shortened: 1)), isTrue);
      expect(offseasonHasNews(outcomeWith(expired: 1)), isTrue);
      expect(offseasonHasNews(outcomeWith(retired: ['Old Boy'])), isTrue);
    });
  });

  group('what it says', () {
    testWidgets('ONE PLAYER AND TWO ARE DIFFERENT KEYS, not a plural rule', (
      tester,
    ) async {
      // Singular and plural are separate catalogue entries, which is how the
      // copy can be right in ten languages without the port knowing any of
      // their grammar.
      await pumpCard(tester, outcomeWith(recovered: 1));
      expect(
        find.text(t('offseason.injuries_recovered_one', {'n': 1})),
        findsOneWidget,
      );

      await pumpCard(tester, outcomeWith(recovered: 3));
      expect(
        find.text(t('offseason.injuries_recovered_n', {'n': 3})),
        findsOneWidget,
      );
    });

    testWidgets('a shortened recovery and an expired sponsor each get a row', (
      tester,
    ) async {
      await pumpCard(tester, outcomeWith(shortened: 2, expired: 1));
      expect(
        find.text(t('offseason.injuries_shortened_n', {'n': 2})),
        findsOneWidget,
      );
      expect(
        find.text(t('offseason.sponsors_expired_one', {'n': 1})),
        findsOneWidget,
      );
    });

    testWidgets('and a row nothing happened in is not drawn', (tester) async {
      await pumpCard(tester, outcomeWith(recovered: 1));
      expect(find.textContaining('sponsorship'), findsNothing);
      expect(find.textContaining('off recovery'), findsNothing);
    });

    testWidgets('THE VETERANS ARE NAMED, and the section counts them', (
      tester,
    ) async {
      await pumpCard(tester, outcomeWith(retired: ['Aled Grey']));
      expect(find.text('Aled Grey'), findsOneWidget);
      expect(find.text(t('offseason.retired')), findsOneWidget);
      expect(
        find.text(t('offseason.veterans_declining_one').toUpperCase()),
        findsOneWidget,
      );

      await pumpCard(tester, outcomeWith(retired: ['Aled Grey', 'Bo Nash']));
      expect(find.text(t('offseason.retired')), findsNWidgets(2));
      expect(
        find.text(t('offseason.veterans_declining_n').toUpperCase()),
        findsOneWidget,
      );
    });

    testWidgets('NO MARKUP REACHES THE SCREEN', (tester) async {
      // Seven of the eleven are built on `<b>{n}</b>`, and this card is one of
      // the nine strings the `t()` tag-stripping was widened for.
      await pumpCard(
        tester,
        outcomeWith(recovered: 2, shortened: 1, expired: 1, retired: ['X Y']),
      );
      expect(find.textContaining('<b>'), findsNothing);
      expect(find.textContaining('</b>'), findsNothing);
      expect(find.textContaining('<'), findsNothing);
    });

    testWidgets('and it is in the player\'s language', (tester) async {
      setLocale('de');
      await pumpCard(tester, outcomeWith(recovered: 2));
      expect(find.text(t('offseason.title')), findsOneWidget);
      expect(find.textContaining('offseason.'), findsNothing);
      expect(find.textContaining('fully recovered'), findsNothing);
    });

    testWidgets('one button, and it is Continue', (tester) async {
      await pumpCard(tester, outcomeWith(recovered: 1));
      expect(
        find.byKey(const ValueKey('coach-action-common.continue')),
        findsOneWidget,
      );
    });
  });
}
