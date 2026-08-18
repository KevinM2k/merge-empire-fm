/// What the game shows the moment it opens.
///
/// The queue and its guarantees were built and NOTHING ever queued into it, so
/// the welcome-back card and the daily reward were both unreachable. These are
/// the tests that would have caught that.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/popups/popup_host.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic> saveWith({
  bool claimedToday = false,
  bool withPlayers = false,
  int? lastSeen,
}) {
  final s = createDefaultState();
  s['dailyReward'] = <String, dynamic>{
    'cycleDay': claimedToday ? 1 : 0,
    'lastClaimDayKey': claimedToday ? dateString() : null,
    'streak': claimedToday ? 1 : 0,
    'longestStreak': 0,
    'totalClaims': claimedToday ? 1 : 0,
    'lastAutoPopupDayKey': null,
  };
  if (lastSeen != null) s['lastSeen'] = lastSeen;
  if (withPlayers) {
    final def = players.firstWhere((p) => p.tier == 1);
    final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
    for (var i = 0; i < 5; i++) {
      cells[i] = <String, dynamic>{
        'definitionId': def.id,
        'instanceId': 'c$i',
        'variant': 0,
      };
    }
  }
  return s;
}

Future<ProviderContainer> boot(
  WidgetTester tester,
  Map<String, dynamic> state, {
  bool load = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
      ),
    ],
  );
  addTearDown(container.dispose);
  if (load) container.read(gameProvider).load();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(kitId: '#4caf50', light: false),
        home: const PopupHost(child: Scaffold(body: SizedBox.expand())),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Every claim arms the 2s debounced save.
Future<void> settleSave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: saveDebounceMs + 100));

void main() {
  tearDown(() {
    resetPopupQueue();
    resetLocale();
  });

  testWidgets('an unclaimed daily reward is offered at boot', (tester) async {
    await boot(tester, saveWith());
    expect(find.byKey(const ValueKey('coach-card')), findsOneWidget);
    expect(find.text(t('daily.claim')), findsOneWidget);
  });

  testWidgets('claiming it pays, and it is not offered twice', (tester) async {
    final container = await boot(tester, saveWith());
    final before = container.read(coinsProvider);

    await tester.tap(find.text(t('daily.claim')));
    await tester.pumpAndSettle();

    await settleSave(tester);
    expect(container.read(coinsProvider), greaterThan(before));
    expect(find.byKey(const ValueKey('coach-card')), findsNothing);
    expect(hasPopupWork(), isFalse);
  });

  testWidgets('an already-claimed day offers nothing', (tester) async {
    await boot(tester, saveWith(claimedToday: true));
    expect(find.byKey(const ValueKey('coach-card')), findsNothing);
  });

  testWidgets('offline earnings are offered, and paid on Collect', (
    tester,
  ) async {
    // The card holds coins that exist NOWHERE else: boot stamps lastSeen, so if
    // the card never shows, those earnings are simply gone.
    final container = await boot(
      tester,
      saveWith(claimedToday: true, withPlayers: true, lastSeen: 1),
    );
    expect(find.byKey(const ValueKey('coach-card')), findsOneWidget);

    final before = container.read(coinsProvider);
    await tester.tap(find.text(t('common.collect')));
    await tester.pumpAndSettle();
    await settleSave(tester);
    expect(
      container.read(coinsProvider),
      greaterThan(before),
      reason: 'applied on Collect, so the HUD animates when asked',
    );
  });

  testWidgets('the coins come FIRST, the streak second', (tester) async {
    // The queue's own priority, and the reason it has one.
    await boot(tester, saveWith(withPlayers: true, lastSeen: 1));
    expect(activePopupId(), 'welcome-back');

    await tester.tap(find.text(t('common.collect')));
    await settleSave(tester);
    await tester.pumpAndSettle();
    expect(activePopupId(), 'daily-reward');
  });

  testWidgets('a club with no players is owed no offline earnings', (
    tester,
  ) async {
    // Nothing was earning while they were away.
    await boot(tester, saveWith(claimedToday: true, lastSeen: 1));
    expect(find.byKey(const ValueKey('coach-card')), findsNothing);
  });

  testWidgets('a boot with no save loaded offers nothing at all', (
    tester,
  ) async {
    // Treating an absent save as "unclaimed" would offer the reward twice.
    await boot(tester, saveWith(), load: false);
    expect(find.byKey(const ValueKey('coach-card')), findsNothing);
    expect(hasPopupWork(), isFalse);
  });
}
