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

String get _questId => questBank.first.id;

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
  await tester.tap(find.byKey(const ValueKey('quick-nav-open')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('quick-nav-quests.title')));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    resetPopupQueue();
    resetLocale();
  });

  testWidgets('the quick-nav menu now leads somewhere', (tester) async {
    // It was built with the other two shapes and nothing ever showed it.
    await pumpShell(tester, saveWithQuests());
    await tester.tap(find.byKey(const ValueKey('quick-nav-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quick-nav')), findsOneWidget);
    expect(find.text(t('quests.title')), findsWidgets);
  });

  testWidgets('and Quests opens from it', (tester) async {
    await pumpShell(tester, saveWithQuests());
    await openQuests(tester);
    expect(find.byKey(const ValueKey('quests-sheet')), findsOneWidget);
    expect(find.byKey(ValueKey('quest-$_questId')), findsOneWidget);
  });

  testWidgets('an unfinished quest shows progress and cannot be claimed', (
    tester,
  ) async {
    await pumpShell(tester, saveWithQuests());
    await openQuests(tester);
    expect(find.text('3 / 10'), findsOneWidget);
    expect(find.byKey(ValueKey('quest-claim-$_questId')), findsNothing);
  });

  testWidgets('a finished one can be claimed, and pays', (tester) async {
    final container = await pumpShell(tester, saveWithQuests(completed: true));
    await openQuests(tester);

    final before = container.read(coinsProvider);
    await tester.tap(find.byKey(ValueKey('quest-claim-$_questId')));
    await tester.pumpAndSettle();
    await settleSave(tester);

    expect(container.read(coinsProvider), greaterThan(before));
    expect(container.read(claimableQuestsProvider), 0);
  });

  testWidgets('an already-claimed one offers nothing', (tester) async {
    await pumpShell(tester, saveWithQuests(completed: true, claimed: true));
    await openQuests(tester);
    expect(find.byKey(ValueKey('quest-claim-$_questId')), findsNothing);
    expect(find.byKey(ValueKey('quest-done-$_questId')), findsOneWidget);
  });

  testWidgets('an empty season track says so', (tester) async {
    await pumpShell(tester, saveWithQuests(none: true));
    await openQuests(tester);
    expect(find.byKey(const ValueKey('quests-none-season')), findsOneWidget);
  });

  group('the badge', () {
    testWidgets('counts what is waiting to be claimed', (tester) async {
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
}
