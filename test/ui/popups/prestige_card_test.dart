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
import 'package:merge_empire_fc/ui/popups/coach_card.dart' show CoachStandee;
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
      // A TENTH ADDED, not compounded: the second adventure pays 1.2, not the
      // 1.21 the old power gave — and the fiftieth pays 6 rather than 117.
      expect(nextPrestigeMultiplier(saveWith(level: 1)), closeTo(1.2, 1e-9));
      expect(nextPrestigeMultiplier(saveWith(level: 49)), closeTo(6.0, 1e-9));
      expect(nextPrestigeMultiplier(null), closeTo(1.1, 1e-9));
    });

    test('and a run deep enough to float is still readable', () {
      // A tenth added seven times is 1.7000000000000002 in binary floating
      // point, and a bare interpolation would have put every digit of that on
      // the card — the same reason this formatter existed for `1.1 ^ 7`.
      expect(formatPrestigeMultiplier(prestigeMultiplierFor(7)), '1.7');
      expect(formatPrestigeMultiplier(1.9487171000000004), '1.95');
      expect(formatPrestigeMultiplier(1.1), '1.1');
      expect(formatPrestigeMultiplier(2), '2');
      expect(formatPrestigeMultiplier(1.21), '1.21');
    });
  });

  group('THE FLOW', () {
    testWidgets('the offer says what the new adventure pays', (tester) async {
      await pumpFlow(tester);
      // Through `withoutEmoji`: the coach card takes the pictograph off every
      // string it prints, so asserting the raw catalogue value here is
      // asserting the one place it does not appear. `coach_card_test` makes
      // the same call about its own title; this one was left behind.
      expect(find.text(withoutEmoji(t('prestige.title'))), findsOneWidget);
      // `textContaining`, because the pro line is part of the same body now —
      // he types both sentences rather than one appearing under the other. See
      // `showPrestigeOffer`.
      expect(
        find.textContaining(t('prestige.body', {'mult': '1.1'})),
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
      await tapAction(tester, 'prestige.button_standard');
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
      await tapAction(tester, 'prestige.button_standard');
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

  group('THE SECOND DOOR INTO PRO MODE', () {
    testWidgets('A CASUAL SAVE IS OFFERED BOTH, and a Pro save only one', (
      tester,
    ) async {
      // `prestige.button_standard` exists BECAUSE there are two buttons — a
      // card with one has no reason for a shorter label on it — and it had no
      // caller here for exactly as long as the Pro route was missing.
      await pumpFlow(tester);
      expect(
        find.byKey(const ValueKey('coach-action-prestige.button_standard')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('coach-action-champ.pro_cta')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('coach-action-prestige.button')),
        findsNothing,
      );
    });

    testWidgets('and a save already in Pro is offered one', (tester) async {
      await pumpFlow(tester, hardMode: true);
      expect(
        find.byKey(const ValueKey('coach-action-prestige.button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('coach-action-champ.pro_cta')),
        findsNothing,
      );
    });

    testWidgets('THE PRO ROUTE WARNS ON THE CONFIRM, not on the offer', (
      tester,
    ) async {
      // The JS appends `prestige.pro_note` to `_doPrestige(true)`'s confirm
      // body. Choosing the harder game and being told what it costs are two
      // beats, and the second is the last card before the career goes.
      await pumpFlow(tester);
      expect(find.text(t('prestige.pro_note')), findsNothing);
      await tapAction(tester, 'champ.pro_cta');
      expect(find.text(t('prestige.confirm_title')), findsOneWidget);
      expect(find.text(t('prestige.pro_note')), findsOneWidget);
    });

    testWidgets('and the standard route does NOT', (tester) async {
      await pumpFlow(tester);
      await tapAction(tester, 'prestige.button_standard');
      expect(find.text(t('prestige.pro_note')), findsNothing);
    });

    testWidgets('THE NEW CAREER BOOTS IN PRO, and only on that route', (
      tester,
    ) async {
      final c = await pumpFlow(tester);
      expect(c.read(hardModeProvider), isFalse);
      await tapAction(tester, 'champ.pro_cta');
      await tapAction(tester, 'prestige.lets_go');

      final state = c.read(gameProvider).state!;
      expect(prestigeLevel(state), 1);
      expect((state['settings'] as Map)['hardMode'], isTrue);

      await tapAction(tester, 'common.cancel');
      await tester.pump(const Duration(milliseconds: saveDebounceMs + 1));
    });

    testWidgets('a standard reset leaves the mode alone', (tester) async {
      final c = await pumpFlow(tester);
      await tapAction(tester, 'prestige.button_standard');
      await tapAction(tester, 'prestige.lets_go');

      final state = c.read(gameProvider).state!;
      expect(prestigeLevel(state), 1);
      expect((state['settings'] as Map)['hardMode'], isFalse);

      await tapAction(tester, 'common.cancel');
      await tester.pump(const Duration(milliseconds: saveDebounceMs + 1));
    });

    testWidgets('and backing out of the Pro confirm changes no mode either', (
      tester,
    ) async {
      final c = await pumpFlow(tester);
      await tapAction(tester, 'champ.pro_cta');
      await tapAction(tester, 'common.cancel');
      expect(lastResult, isNull);
      expect(prestigeLevel(c.read(gameProvider).state), 0);
      expect(c.read(hardModeProvider), isFalse);
    });
  });

  group('A TAP OFF THE CARD IS A CANCEL', () {
    // **THE DIALOG IS THE WHOLE SCREEN**, bottom-aligned and transparent with
    // Colin standing in the empty half of it — so the barrier only ever got the
    // strip outside the inset padding and a tap beside his shoulder did
    // nothing. Reported from the couch twice: that the card would not close,
    // and then precisely that tapping above him worked and beside him did not.
    // See `CoachStage.dismissible`.
    Finder title() => find.text(withoutEmoji(t('prestige.title')));

    testWidgets('beside him closes it, and nothing is written', (tester) async {
      final c = await pumpFlow(tester);
      expect(title(), findsOneWidget);

      final him = tester.getRect(find.byType(CoachStandee));
      await tester.tapAt(Offset(him.right + 20, him.center.dy));
      await tester.pumpAndSettle();

      expect(title(), findsNothing);
      expect(lastResult, isNull);
      expect(prestigeLevel(c.read(gameProvider).state), 0);
      expect(c.read(hardModeProvider), isFalse);
    });

    testWidgets('and so does above him, which always worked', (tester) async {
      await pumpFlow(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(title(), findsNothing);
      expect(lastResult, isNull);
    });

    testWidgets('but ON HIM does not — that is the card', (tester) async {
      await pumpFlow(tester);
      await tester.tapAt(tester.getCenter(find.byType(CoachStandee)));
      await tester.pumpAndSettle();
      expect(title(), findsOneWidget, reason: 'tapping the man closed it');
    });

    testWidgets('nor does the box he is saying it out of', (tester) async {
      await pumpFlow(tester);
      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('coach-card-body'))),
      );
      await tester.pumpAndSettle();
      expect(title(), findsOneWidget, reason: 'tapping the card closed it');
    });
  });

  group('THE PRO LINE CHANGES WITH THE SAVE', () {
    // **AND IT IS PART OF WHAT HE SAYS, not a row under it.** It was an
    // `extraLines` entry, so the second half of his line was on screen before
    // the typewriter had finished the first. `textContaining` is what asks the
    // question now: one body, both sentences, typed.
    //
    // Through `withoutEmoji`, for the reason the title is: the card takes the
    // pictograph off every string it TYPES, so the hint's 🔥 goes the way
    // `prestige.title`'s 🌟 already did. The `extraLines` row it left was the
    // one place on this card that kept one.
    testWidgets('a casual save is INVITED into Pro mode', (tester) async {
      await pumpFlow(tester);
      expect(
        find.textContaining(withoutEmoji(t('prestige.body_pro_hint'))),
        findsOneWidget,
      );
      expect(
        find.textContaining(withoutEmoji(t('prestige.pro_note'))),
        findsNothing,
      );
    });

    testWidgets('and one already in it is told what it is starting', (
      tester,
    ) async {
      // An invitation to somewhere the player is standing is not an
      // invitation.
      await pumpFlow(tester, hardMode: true);
      expect(
        find.textContaining(withoutEmoji(t('prestige.pro_note'))),
        findsOneWidget,
      );
      expect(
        find.textContaining(withoutEmoji(t('prestige.body_pro_hint'))),
        findsNothing,
      );
    });

    testWidgets('and there is no second Text under the body at all', (
      tester,
    ) async {
      await pumpFlow(tester);
      expect(
        find.byKey(const ValueKey('coach-line-prestige.body_pro_hint')),
        findsNothing,
      );
    });
  });
}
