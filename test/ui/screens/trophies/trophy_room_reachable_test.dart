/// Can a player actually GET to the Trophy Room?
///
/// Separate from the screen's own tests on purpose. Those construct the sheet
/// and prove it works, which is exactly the kind of passing test that let three
/// finished screens sit unreachable — see the reachability note in
/// `docs/REMAINING.md`. This one starts at the shell, the way a player does.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/shell/app_shell.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';
import 'package:merge_empire_fc/util/time.dart';

/// A save with no boot popup queued, so nothing is covering the HUD.
Map<String, dynamic> _quietSave() {
  final s = createDefaultState();
  s['dailyReward'] = <String, dynamic>{
    'cycleDay': 1,
    'lastClaimDayKey': dateString(),
    'streak': 1,
    'longestStreak': 1,
    'totalClaims': 1,
    'lastAutoPopupDayKey': dateString(),
  };
  return s;
}

Future<void> _pumpShell(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(_quietSave())}),
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
}

void main() {
  tearDown(() {
    resetPopupQueue();
    resetLocale();
  });

  testWidgets('the quick-nav menu opens it', (tester) async {
    await _pumpShell(tester);
    await tester.tap(find.byKey(const ValueKey('dock-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('quick-nav-scene.dock.trophies')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trophy-room')), findsOneWidget);
  });

  testWidgets('so does the badge in the HUD', (tester) async {
    // The JS hangs this off the manager avatar. It is the second door, and it
    // is also the only place in the game that SHOWS the badge — without it
    // "Set as Badge" changes nothing a player can see.
    await _pumpShell(tester);
    expect(find.byKey(const ValueKey('hud-badge')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('hud-badge')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trophy-room')), findsOneWidget);
  });

  testWidgets('the menu names it in the player\'s language', (tester) async {
    await _pumpShell(tester);
    await tester.tap(find.byKey(const ValueKey('dock-menu')));
    await tester.pumpAndSettle();
    // Caps, like every other nav label — the words are still the catalogue's.
    expect(find.text(t('scene.dock.trophies').toUpperCase()), findsOneWidget);
  });
}
