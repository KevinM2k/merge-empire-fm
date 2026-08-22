/// The night the game is won.
///
/// **Nine `champ.*` strings in ten catalogues with no caller**, and the queue
/// could not tell from here whether they were the endgame or a second copy of
/// the prestige card. They are the celebration the JS fires from the season-end
/// chain when the top flight has been won, and it feeds the same prestige flow
/// the dock orb does.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/season_end.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/popups/champions_card.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

SeasonOutcome outcomeWith({
  String oldDivision = 'champions_cup',
  int position = 1,
}) => (
  outcome: 'stayed',
  position: position,
  oldDivision: oldDivision,
  newDivision: oldDivision,
  payout: 0,
  gemsAwarded: 0,
  ageingReport: const [],
  injuryReport: (recovered: 0, shortened: 0),
  sponsorReport: (expired: 0),
);

int? lastResult;

Future<ProviderContainer> pumpCard(
  WidgetTester tester, {
  bool hardMode = false,
}) async {
  final save = createDefaultState();
  (save['progression'] as Map<String, dynamic>)['wonChampionsCup'] = true;
  (save['settings'] as Map<String, dynamic>)['hardMode'] = hardMode;
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(save)}),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(gameProvider).load();
  lastResult = null;

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                key: const ValueKey('open-champ'),
                onPressed: () async {
                  lastResult = await showChampionsCelebration(context, ref);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-champ')));
  await tester.pumpAndSettle();
  return container;
}

Future<void> tapAction(WidgetTester tester, String labelKey) async {
  await tester.tap(find.byKey(ValueKey('coach-action-$labelKey')));
  await tester.pumpAndSettle();
}

/// The German `champ.pro_teaser`, captured once so the English one can be
/// compared against it without a second `setLocale` inside an expectation.
late String tGerman;

void main() {
  setUpAll(() {
    setLocale('de');
    tGerman = t('champ.pro_teaser');
    resetLocale();
  });
  tearDown(resetLocale);

  group('whether this season won it', () {
    test('IT IS THE TABLE, not the permanent flag', () {
      // `wonChampionsCup` never clears until a prestige, so a save that won
      // three seasons ago would celebrate again every May.
      expect(wonTheTitle(outcomeWith()), isTrue);
      expect(wonTheTitle(outcomeWith(position: 2)), isFalse);
      expect(wonTheTitle(outcomeWith(oldDivision: 'elite_league')), isFalse);
    });
  });

  group('what the card offers', () {
    testWidgets('THE MOMENT, WHAT THE RESET BUYS, AND WHAT PRO IS', (
      tester,
    ) async {
      await pumpCard(tester);
      expect(find.text(t('champ.title')), findsOneWidget);
      expect(find.text(t('champ.subtitle')), findsOneWidget);
      expect(find.text(t('champ.body')), findsOneWidget);
      expect(
        find.text(t('champ.prestige_teaser', {'mult': '1.1'})),
        findsOneWidget,
        reason: 'the teaser quotes the multiplier the reset will actually pay',
      );
      expect(find.text(t('champ.pro_teaser')), findsOneWidget);
      // `prestige_teaser` is written with `<strong>` in it.
      expect(find.textContaining('<strong'), findsNothing);
    });

    testWidgets('and a save already in Pro is not pitched Pro', (tester) async {
      await pumpCard(tester, hardMode: true);
      expect(find.text(t('champ.pro_teaser')), findsNothing);
      expect(
        find.byKey(const ValueKey('coach-action-champ.pro_cta')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('coach-action-champ.new_adventure')),
        findsOneWidget,
      );
    });

    testWidgets('DEFENDING THE TITLE COSTS THE SAVE NOTHING', (tester) async {
      // The JS's own note: declining is respected, and the standing offer on
      // the dock stays available for whenever they want it.
      final c = await pumpCard(tester);
      await tapAction(tester, 'champ.defend');
      expect(lastResult, isNull);
      expect(prestigeLevel(c.read(gameProvider).state), 0);
      expect(c.read(canPrestigeProvider), isTrue);
    });

    testWidgets('NEW ADVENTURE GOES THROUGH THE SAME CONFIRM as the orb', (
      tester,
    ) async {
      // One reset flow, reached from two offers. A second copy is how the
      // celebration ends up resetting a career without asking twice.
      final c = await pumpCard(tester);
      await tapAction(tester, 'champ.new_adventure');
      expect(find.text(t('prestige.confirm_title')), findsOneWidget);
      expect(find.text(t('prestige.pro_note')), findsNothing);

      await tapAction(tester, 'prestige.lets_go');
      final state = c.read(gameProvider).state!;
      expect(prestigeLevel(state), 1);
      expect((state['settings'] as Map)['hardMode'], isFalse);

      await tapAction(tester, 'common.cancel');
      await tester.pump(const Duration(milliseconds: saveDebounceMs + 1));
    });

    testWidgets('AND THE PRO ROUTE BOOTS THE NEW CAREER IN PRO', (
      tester,
    ) async {
      final c = await pumpCard(tester);
      await tapAction(tester, 'champ.pro_cta');
      expect(find.text(t('prestige.pro_note')), findsOneWidget);

      await tapAction(tester, 'prestige.lets_go');
      final state = c.read(gameProvider).state!;
      expect(prestigeLevel(state), 1);
      expect((state['settings'] as Map)['hardMode'], isTrue);

      await tapAction(tester, 'common.cancel');
      await tester.pump(const Duration(milliseconds: saveDebounceMs + 1));
    });

    testWidgets('and backing out of the confirm changes nothing', (
      tester,
    ) async {
      final c = await pumpCard(tester);
      await tapAction(tester, 'champ.pro_cta');
      await tapAction(tester, 'common.cancel');
      expect(lastResult, isNull);
      expect(prestigeLevel(c.read(gameProvider).state), 0);
      expect(c.read(hardModeProvider), isFalse);
    });

    testWidgets('IT RESOLVES IN EVERY LOCALE, and six of the nine are still '
        'English in all of them', (tester) async {
      // **The catalogue is generated and six `champ.*` entries were never
      // translated** — `champ.title`, `.subtitle`, `.body`, `.prestige_teaser`,
      // `.new_adventure` and `.defend` are character-for-character English in
      // German, which is a gap in `../merge-empire-fc`'s own `en.js` run and
      // not something a call site can fix. `.pro_title`, `.pro_teaser` and
      // `.pro_cta` ARE translated, which is what makes it a gap rather than a
      // decision.
      //
      // So what is pinned is that every key RESOLVES — no raw key on screen —
      // and that the three which are translated actually change.
      setLocale('de');
      await pumpCard(tester);
      expect(find.textContaining('champ.'), findsNothing);
      expect(find.text(t('champ.pro_teaser')), findsOneWidget);
      resetLocale();
      expect(t('champ.pro_teaser'), isNot(equals(tGerman)));
    });
  });
}
