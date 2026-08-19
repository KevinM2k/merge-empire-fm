/// The energy sheet, and the button that opens it.
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
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';
import 'package:merge_empire_fc/util/time.dart';

Future<ProviderContainer> pumpShell(
  WidgetTester tester, {
  int energy = 4,
  bool upgraded = false,
}) async {
  final state = createDefaultState();
  (state['energy'] as Map<String, dynamic>)['current'] = energy;
  (state['shop'] as Map<String, dynamic>)['energyUpgraded'] = upgraded;
  // Today's reward already claimed, so no boot popup competes for the screen.
  state['dailyReward'] = <String, dynamic>{
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

void main() {
  tearDown(() {
    resetPopupQueue();
    resetLocale();
    clearBus();
  });

  testWidgets('the HUD energy + opens the sheet', (tester) async {
    // It emitted nav:energy and nothing listened — a button that did nothing.
    await pumpShell(tester);
    expect(find.byKey(const ValueKey('energy-sheet')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('hud-energy-plus')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('energy-sheet')), findsOneWidget);
  });

  testWidgets('it reports where the player stands', (tester) async {
    await pumpShell(tester, energy: 4);
    await tester.tap(find.byKey(const ValueKey('hud-energy-plus')));
    await tester.pumpAndSettle();
    // By key: the HUD chip behind the sheet shows the same figure.
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('energy-count'))).data,
      '4/10',
    );
  });

  testWidgets('and the upgraded cap when it is owned', (tester) async {
    await pumpShell(tester, energy: 12, upgraded: true);
    await tester.tap(find.byKey(const ValueKey('hud-energy-plus')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('energy-count'))).data,
      '12/15',
    );
  });

  testWidgets('a full tank counts down to nothing', (tester) async {
    // A countdown to a pip that is never coming is worse than no countdown.
    await pumpShell(tester, energy: 10);
    await tester.tap(find.byKey(const ValueKey('hud-energy-plus')));
    await tester.pumpAndSettle();
    expect(find.text(t('shop.already_ready')), findsOneWidget);
  });

  testWidgets('the ad route is named and dead, like every other M4 control', (
    tester,
  ) async {
    await pumpShell(tester);
    await tester.tap(find.byKey(const ValueKey('hud-energy-plus')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const ValueKey('energy-watch-ad')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('the Shop route works today', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byKey(const ValueKey('hud-energy-plus')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('energy-to-shop')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('energy-sheet')), findsNothing);
    expect(find.byKey(const ValueKey('shop-scroll')), findsOneWidget);
  });
}
