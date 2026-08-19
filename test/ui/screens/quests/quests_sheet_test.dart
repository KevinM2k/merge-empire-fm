/// The quests sheet, and the menu that reaches it.
///
/// The toast said "claim it in Quests!" and there was no Quests: shipped copy
/// pointing at nothing, and a completed quest nobody could claim.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/quests.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/quests/quests_sheet.dart';
import 'package:merge_empire_fc/ui/shell/app_shell.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';
import 'package:merge_empire_fc/util/time.dart';

/// A real SEASON quest. The bank's first entry is a MATCH one, and putting that
/// in the season track had the same id keyed twice once the match track started
/// rolling — which is the shape of save no real game can produce.
String get _questId => questBank.firstWhere((q) => q.scope == 'season').id;

Map<String, dynamic> saveWithQuests({
  bool completed = false,
  bool claimed = false,
  bool none = false,
}) {
  final s = createDefaultState();
  // No boot popup competing for the screen.
  s['dailyReward'] = <String, dynamic>{
    'cycleDay': 1,
    'lastClaimDayKey': dateString(),
    'streak': 1,
    'longestStreak': 1,
    'totalClaims': 1,
    'lastAutoPopupDayKey': dateString(),
  };
  s['quests'] = <String, dynamic>{
    'season': none
        ? <dynamic>[]
        : [
            <String, dynamic>{
              'id': _questId,
              'target': 10,
              'progress': completed ? 10 : 3,
              'completed': completed,
              'claimedAt': claimed ? 1 : null,
            },
          ],
    'match': <String, dynamic>{'fixtureKey': null, 'active': <dynamic>[]},
  };
  return s;
}

Future<ProviderContainer> pumpShell(
  WidgetTester tester,
  Map<String, dynamic> state,
) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
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
          // The home screen's walker loops forever, so `pumpAndSettle` would
          // never settle. He honours reduce-motion; declaring it here is what a
          // device with that setting on would do.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),

          home: const AppShell(),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 32));
  return container;
}

Future<void> settleSave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: saveDebounceMs + 100));

Future<void> openQuests(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('dock-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('quick-nav-quests.title')));
  await tester.pumpAndSettle();
  // Opening it rolls the track for the next match, which is a real write — so
  // there is a debounced save to let land.
  await settleSave(tester);
}

void main() {
  tearDown(() {
    resetPopupQueue();
    resetLocale();
  });

  testWidgets('the quick-nav menu now leads somewhere', (tester) async {
    // It was built with the other two shapes and nothing ever showed it.
    await pumpShell(tester, saveWithQuests());
    await tester.tap(find.byKey(const ValueKey('dock-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quick-nav')), findsOneWidget);
    expect(find.text(t('quests.title')), findsWidgets);
  });

  testWidgets('and Quests opens from it', (tester) async {
    await pumpShell(tester, saveWithQuests());
    await openQuests(tester);
    expect(find.byKey(const ValueKey('quests-sheet')), findsOneWidget);
    expect(find.byKey(ValueKey('quest-season-$_questId')), findsOneWidget);
  });

  testWidgets('an unfinished quest shows progress and cannot be claimed', (
    tester,
  ) async {
    await pumpShell(tester, saveWithQuests());
    await openQuests(tester);
    expect(find.text('3 / 10'), findsOneWidget);
    expect(find.byKey(ValueKey('quest-claim-season-$_questId')), findsNothing);
  });

  testWidgets('a finished one can be claimed, and pays', (tester) async {
    final container = await pumpShell(tester, saveWithQuests(completed: true));
    await openQuests(tester);

    final before = container.read(coinsProvider);
    await tester.tap(find.byKey(ValueKey('quest-claim-season-$_questId')));
    await tester.pumpAndSettle();
    await settleSave(tester);

    expect(container.read(coinsProvider), greaterThan(before));
    expect(container.read(claimableQuestsProvider), 0);
  });

  testWidgets('an already-claimed one offers nothing', (tester) async {
    await pumpShell(tester, saveWithQuests(completed: true, claimed: true));
    await openQuests(tester);
    expect(find.byKey(ValueKey('quest-claim-season-$_questId')), findsNothing);
    expect(find.byKey(ValueKey('quest-done-season-$_questId')), findsOneWidget);
  });

  testWidgets('an empty season track says so', (tester) async {
    await pumpShell(tester, saveWithQuests(none: true));
    await openQuests(tester);
    expect(find.byKey(const ValueKey('quests-none-season')), findsOneWidget);
  });

  group('the badge', () {
    // A dot on the burger rather than a count, which is what the JS shows: it
    // is the OR of every tile behind it, so a number would have to mean the sum
    // of several unrelated things.
    testWidgets('lights when something is waiting to be claimed', (
      tester,
    ) async {
      final container = await pumpShell(
        tester,
        saveWithQuests(completed: true),
      );
      expect(container.read(claimableQuestsProvider), 1);
      expect(find.byKey(const ValueKey('quick-nav-badge')), findsOneWidget);
    });

    testWidgets('and stays away when nothing is', (tester) async {
      await pumpShell(tester, saveWithQuests());
      expect(find.byKey(const ValueKey('quick-nav-badge')), findsNothing);
    });
  });

  group('the match track', () {
    testWidgets('is rolled when the sheet is opened', (tester) async {
      // `rollMatchQuests` had no caller, so the match track was empty for every
      // match ever played — three quests a fixture, none of them drawn.
      final container = await pumpShell(tester, saveWithQuests());
      final before =
          ((container.read(gameProvider).state!['quests']
                      as Map<String, dynamic>)['match']
                  as Map<String, dynamic>)['active']
              as List;
      expect(before, isEmpty);

      await openQuests(tester);
      final after =
          ((container.read(gameProvider).state!['quests']
                      as Map<String, dynamic>)['match']
                  as Map<String, dynamic>)['active']
              as List;
      expect(after.length, matchQuestCount);
      // The TRACK is rolled here; the sheet no longer SHOWS it. Match quests
      // read on the next-match card, where the fixture they belong to is — see
      // `MatchQuestsBlock`.
      expect(find.text(t('quests.match')), findsNothing);
    });

    testWidgets('and the sheet carries the SEASON track only', (tester) async {
      // A match quest pays itself at full time, so there was never anything to
      // claim on one — and reading it after choosing to open a menu is reading
      // it too late. It lives on the next-match card now.
      await pumpShell(tester, saveWithQuests());
      await openQuests(tester);
      expect(find.byKey(const ValueKey('quests-match-auto')), findsNothing);
      expect(find.text(t('quests.season')), findsOneWidget);
    });

    testWidgets('opening it twice does not redraw the set just read', (
      tester,
    ) async {
      final container = await pumpShell(tester, saveWithQuests());
      await openQuests(tester);
      List<String> ids() => [
        for (final q
            in (((container.read(gameProvider).state!['quests']
                            as Map<String, dynamic>)['match']
                        as Map<String, dynamic>)['active']
                    as List)
                .cast<Map<String, dynamic>>())
          '${q['id']}',
      ];
      final first = ids();

      // Tap the barrier above the sheet to dismiss it, then come back.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await openQuests(tester);
      expect(ids(), first);
    });
  });

  group('the reroll', () {
    testWidgets('offers the free swaps a season comes with', (tester) async {
      await pumpShell(tester, saveWithQuests());
      await openQuests(tester);
      expect(find.byKey(const ValueKey('quests-reroll')), findsOneWidget);
      expect(find.byKey(const ValueKey('quests-reroll-free')), findsOneWidget);
      expect(find.textContaining(t('quests.reroll_free')), findsWidgets);
    });

    testWidgets('swaps the unfinished quest for a different one', (
      tester,
    ) async {
      final container = await pumpShell(tester, saveWithQuests());
      await openQuests(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('quests-reroll')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quests-reroll')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      final ids = [
        for (final q
            in ((container.read(gameProvider).state!['quests']
                        as Map<String, dynamic>)['season']
                    as List)
                .cast<Map<String, dynamic>>())
          '${q['id']}',
      ];
      expect(ids, isNot(contains(_questId)));
      expect(ids, hasLength(1), reason: 'swapped, not added to');
    });

    testWidgets('refuses when there is nothing left to swap', (tester) async {
      // Charging for a reroll that could change nothing would be theft.
      await pumpShell(tester, saveWithQuests(completed: true, claimed: true));
      await openQuests(tester);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('quests-reroll')))
            .onPressed,
        isNull,
      );
    });
  });
}
