/// What a save write rebuilds while all five tabs are mounted.
///
/// Idle income moves the save once a second, and every tab is alive in the
/// `IndexedStack`. The grid used to re-derive all 38 slots on each tick — 469
/// widgets, ~15ms on a phone, two dropped frames a second on the home page.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/shell/app_shell.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';
import 'package:merge_empire_fc/util/time.dart';

void main() {
  tearDown(() {
    debugOnRebuildDirtyWidget = null;
    resetPopupQueue();
  });

  testWidgets('a coin tick does not rebuild the grid', (tester) async {
    final s = createDefaultState();
    s['dailyReward'] = <String, dynamic>{
      'cycleDay': 1,
      'lastClaimDayKey': dateString(),
      'streak': 1,
      'longestStreak': 1,
      'totalClaims': 1,
      'lastAutoPopupDayKey': dateString(),
    };
    final container = ProviderContainer(
      overrides: [
        saveStoreProvider.overrideWithValue(
          MemorySaveStore({saveKeyPrimary: jsonEncode(s)}),
        ),
      ],
    );
    addTearDown(container.dispose);
    final game = container.read(gameProvider)..load();
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
            home: const AppShell(),
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final rebuilt = <String>[];
    debugOnRebuildDirtyWidget = (e, _) =>
        rebuilt.add(e.widget.runtimeType.toString());
    // The loop credits the resources branch directly and notifies.
    final resources = game.state!['resources'] as Map<String, dynamic>;
    resources['fanCoins'] = (resources['fanCoins'] as num) + 7;
    game.notifyChanged();
    await tester.pump(const Duration(milliseconds: 16));
    debugOnRebuildDirtyWidget = null;

    expect(rebuilt.where((n) => n == '_Slot'), isEmpty, reason: 'a grid slot rebuilt for a coin');
    expect(rebuilt.length, lessThan(200), reason: rebuilt.join(', '));
  });
}
