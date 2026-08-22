/// Colin's milestone tips, reached the way a player reaches them.
///
/// **Which is the whole point of a second test file.** The engine's rules are
/// pinned next to the engine; this asks whether anybody ever sees one. That
/// distinction has caught four engines in this port — fully ported, fully
/// tested, never called — and `seenTips` was the fifth: a ledger in the schema,
/// written by the migration, read by nothing.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/util/time.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/popups/popup_host.dart';
import 'package:merge_empire_fc/ui/shell/app_shell.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';

Future<ProviderContainer> pumpShell(
  WidgetTester tester, {
  void Function(Map<String, dynamic> state)? mutate,
}) async {
  final state = createDefaultState();
  // **And the tutorial already finished.** `settleTutorial` used to mark every
  // save done on the way in, so this was true without being said; there is a
  // script now and it settles only a save with evidence of play. A tip that
  // fires on arriving at a tab is not a thing a brand new save should be shown
  // — it is nine steps into being told what the tabs are.
  (state['tutorial'] as Map<String, dynamic>)['done'] = true;
  // **Today's reward already claimed.** Boot queues it unconditionally, and a
  // sheet on screen is exactly what a tip is not allowed to open over — so a
  // shell that still owes one can never show a tip, correctly, and this test
  // would be measuring the queue rather than the tips.
  state['dailyReward'] = <String, dynamic>{
    'cycleDay': 1,
    'lastClaimDayKey': dateString(now()),
    'streak': 1,
    'longestStreak': 1,
    'totalClaims': 1,
    'lastAutoPopupDayKey': dateString(now()),
  };
  mutate?.call(state);

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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          // **`PopupHost` is what releases the queue's no-host blocker.**
          // Without it nothing may open at all — which is the mechanism that
          // stops a boot popup being dropped for want of somewhere to go, and
          // it means a shell built on its own can never show a tip.
          home: const PopupHost(child: AppShell()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// The save's own debounce, so a test that wrote to the save does not end with
/// its timer still pending.
Future<void> settleSave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: saveDebounceMs + 100));

void main() {
  tearDown(resetLocale);
  // **The queue is module state, so it outlives a test.** Without this the
  // entry one test left behind is still "work" for the next, and a tip that was
  // correctly refused reads as a tip that never fired.
  setUp(resetPopupQueue);

  testWidgets('ARRIVING ON THE CLUB TAB EXPLAINS THE CLUB TAB', (tester) async {
    final container = await pumpShell(tester);
    addTearDown(container.dispose);
    expect(
      find.byKey(const ValueKey('coach-card')),
      findsNothing,
      reason: 'a tip fired before the player had gone anywhere',
    );

    await tester.tap(find.byKey(const ValueKey('tab-club')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('coach-card')),
      findsOneWidget,
      reason: 'nothing explained the Club tab',
    );
    // With the milestone's own badge on it, which is what makes sixteen
    // one-off subjects tell themselves apart at a glance.
    expect(find.byKey(const ValueKey('coach-card-badge')), findsOneWidget);
    expect(find.text(t('coachtip.club_assets.title')), findsOneWidget);
    await settleSave(tester);
  });

  testWidgets('and it is SPENT — going back does not repeat it', (
    tester,
  ) async {
    final container = await pumpShell(tester);
    addTearDown(container.dispose);
    await tester.tap(find.byKey(const ValueKey('tab-club')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('coach-card')), findsOneWidget);

    // Dismissed, and the ledger has it.
    await tester.tap(find.text(t('coachtip.tap_dismiss')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('coach-card')), findsNothing);
    expect(
      container.read(gameProvider).state?['seenTips'],
      contains('club_assets'),
      reason: 'the ledger never recorded it',
    );

    await tester.tap(find.byKey(const ValueKey('tab-home')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tab-club')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('coach-card')),
      findsNothing,
      reason: 'the same lesson came back',
    );
    await settleSave(tester);
  });

  testWidgets('NEVER OVER ANOTHER POPUP, nor in the gap after one', (
    tester,
  ) async {
    // Colin talking over Colin is the worst version of this bug, and the gap
    // between one popup closing and the next opening is the part a bare
    // "is a dialog up" probe misses.
    final container = await pumpShell(tester);
    addTearDown(container.dispose);
    blockPopups('test');
    addTearDown(() => unblockPopups('test'));

    await tester.tap(find.byKey(const ValueKey('tab-club')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('coach-card')),
      findsNothing,
      reason: 'a tip opened while popups were blocked',
    );
    // And the id is NOT spent, so the lesson survives to be taught later.
    expect(
      container.read(gameProvider).state?['seenTips'] as List?,
      isNot(contains('club_assets')),
    );
    await settleSave(tester);
  });

  testWidgets('a tip with a button GOES somewhere', (tester) async {
    // The injury tip's CTA is the squad — a lesson that names a screen and then
    // leaves you to find it is half a lesson.
    final container = await pumpShell(
      tester,
      mutate: (s) {
        // Everything the Club tab would otherwise say first, already said.
        s['seenTips'] = ['club_assets', 'rename_player', 'traits', 'atk_def'];
        final prog = s['progression'] as Map<String, dynamic>;
        prog['divisionsUnlocked'] = ['elite_league'];
      },
    );
    addTearDown(container.dispose);

    await tester.tap(find.byKey(const ValueKey('tab-club')));
    await tester.pumpAndSettle();
    expect(find.text(t('coachtip.auto_sell.title')), findsOneWidget);
    expect(find.text(t('coachtip.auto_sell.cta')), findsOneWidget);
    await settleSave(tester);
  });
}
