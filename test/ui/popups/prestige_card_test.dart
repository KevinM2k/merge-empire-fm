/// Prestige — the New Adventure.
///
/// **Nothing in the port could reach any of it.** `canPrestige` and
/// `performPrestige` (`engine/season_end.dart`) are ported and fixture-tested
/// with no caller in `lib/` at all; fourteen `prestige.*` strings sit generated
/// in all ten catalogues with nothing able to print one; and
/// `prestige_level_1`, `prestige_level_3` and `prestige_level_10` are read off
/// a level that could therefore never rise. A green fixture test is not a
/// caller.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/achievements.dart';
import 'package:merge_empire_fc/engine/season_end.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/popups/prestige_card.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

Map<String, dynamic> saveWith({
  bool wonChampionsCup = true,
  int level = 0,
  bool hardMode = false,
}) {
  final state = createDefaultState();
  final prog = state['progression'] as Map<String, dynamic>;
  prog['wonChampionsCup'] = wonChampionsCup;
  if (level > 0) {
    state['prestige'] = <String, dynamic>{
      'level': level,
      'incomeMultiplier': prestigeMultiplierFor(level),
      'totalTrophies': 0,
      'points': level,
    };
  }
  (state['settings'] as Map<String, dynamic>)['hardMode'] = hardMode;
  return state;
}

int? lastResult;

Future<ProviderContainer> pumpFlow(
  WidgetTester tester, {
  bool wonChampionsCup = true,
  int level = 0,
  bool hardMode = false,
}) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({
          saveKeyPrimary: jsonEncode(
            saveWith(
              wonChampionsCup: wonChampionsCup,
              level: level,
              hardMode: hardMode,
            ),
          ),
        }),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(gameProvider).load();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                key: const ValueKey('open-prestige'),
                onPressed: () async {
                  lastResult = await showPrestigeOffer(context, ref);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-prestige')));
  await tester.pumpAndSettle();
  return container;
}

Future<void> tapAction(WidgetTester tester, String labelKey) async {
  await tester.tap(find.byKey(ValueKey('coach-action-$labelKey')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => lastResult = null);
  tearDown(resetLocale);

  group('THE ENGINE HAD NO CALLER', () {
    test('and three achievements read the level it could never raise', () {
      final gated = achievements.where(
        (a) => a.id.startsWith('prestige_level_'),
      );
      expect(gated, isNotEmpty);
      // Every one of them is a threshold on the same number, so a prestige that
      // cannot happen is a whole category that cannot unlock.
      for (final a in gated) {
        expect(
          a.check(saveWith(level: 0), (type: "boot", data: null)),
          isFalse,
        );
        expect(
          a.check(saveWith(level: 10), (type: "boot", data: null)),
          isTrue,
        );
      }
    });
  });

  group('THE MULTIPLIER ON THE CARD IS THE ONE THE RESET PAYS', () {
    test('the offer names the NEXT level, not the current one', () {
      expect(nextPrestigeMultiplier(saveWith(level: 0)), closeTo(1.1, 1e-9));
      expect(nextPrestigeMultiplier(saveWith(level: 1)), closeTo(1.21, 1e-9));
      expect(nextPrestigeMultiplier(null), closeTo(1.1, 1e-9));
    });

    test('and a run deep enough to float is still readable', () {
      // `1.1 ^ 7` is 1.9487171000000004, and a bare interpolation would have
      // put every digit of that on the card.
      expect(formatPrestigeMultiplier(prestigeMultiplierFor(7)), '1.95');
      expect(formatPrestigeMultiplier(1.1), '1.1');
      expect(formatPrestigeMultiplier(2), '2');
      expect(formatPrestigeMultiplier(1.21), '1.21');
    });
  });

  group('THE FLOW', () {
    testWidgets('the offer says what the new adventure pays', (tester) async {
      await pumpFlow(tester);
      expect(find.text(t('prestige.title')), findsOneWidget);
      expect(
        find.text(t('prestige.body', {'mult': '1.1'})),
        findsOneWidget,
        reason: 'the headline is the multiplier the reset will actually pay',
      );
      // No markup on screen — `prestige.body` is written for a DOM.
      expect(find.textContaining('<strong'), findsNothing);
    });

    testWidgets('CANCELLING THE OFFER COSTS THE SAVE NOTHING', (tester) async {
      final c = await pumpFlow(tester);
      final before = c.read(gameProvider).state!['progression'];
      await tapAction(tester, 'common.cancel');
      expect(lastResult, isNull);
      expect((before as Map)['wonChampionsCup'], isTrue);
      expect(prestigeLevel(c.read(gameProvider).state), 0);
    });

    testWidgets('AND SO DOES CANCELLING THE CONFIRM — nothing is written '
        'until the last button', (tester) async {
      final c = await pumpFlow(tester);
      await tapAction(tester, 'prestige.button');
      expect(find.text(t('prestige.confirm_title')), findsOneWidget);
      await tapAction(tester, 'common.cancel');
      expect(lastResult, isNull);
      expect(prestigeLevel(c.read(gameProvider).state), 0);
      expect(c.read(canPrestigeProvider), isTrue);
    });

    testWidgets('LET\'S GO RESETS THE CAREER and asks the new club its name', (
      tester,
    ) async {
      final c = await pumpFlow(tester);
      await tapAction(tester, 'prestige.button');
      await tapAction(tester, 'prestige.lets_go');

      final state = c.read(gameProvider).state!;
      expect(prestigeLevel(state), 1);
      expect(
        (state['prestige'] as Map)['incomeMultiplier'],
        closeTo(1.1, 1e-9),
      );
      expect((state['progression'] as Map)['currentDivision'], 'sunday_league');
      // Re-gated, so the orb takes itself away rather than offering a second
      // reset for free.
      expect((state['progression'] as Map)['wonChampionsCup'], isFalse);

      // The name card, in prestige's own words.
      expect(find.text(t('prestige.name_prompt')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('coach-action-prestige.kick_off')),
        findsOneWidget,
      );

      // The reset wrote the save, and the write is debounced — leaving the
      // tree here fails the binding's own pending-timer check rather than the
      // assertions above.
      await tapAction(tester, 'common.cancel');
      await tester.pump(const Duration(milliseconds: saveDebounceMs + 1));
    });

    testWidgets('a save that has not won it is never offered one', (
      tester,
    ) async {
      await pumpFlow(tester, wonChampionsCup: false);
      expect(find.text(t('prestige.title')), findsNothing);
      expect(lastResult, isNull);
    });
  });

  group('THE PRO LINE CHANGES WITH THE SAVE', () {
    testWidgets('a casual save is INVITED into Pro mode', (tester) async {
      await pumpFlow(tester);
      expect(find.text(t('prestige.body_pro_hint')), findsOneWidget);
      expect(find.text(t('prestige.pro_note')), findsNothing);
    });

    testWidgets('and one already in it is told what it is starting', (
      tester,
    ) async {
      // An invitation to somewhere the player is standing is not an
      // invitation.
      await pumpFlow(tester, hardMode: true);
      expect(find.text(t('prestige.pro_note')), findsOneWidget);
      expect(find.text(t('prestige.body_pro_hint')), findsNothing);
    });
  });
}
