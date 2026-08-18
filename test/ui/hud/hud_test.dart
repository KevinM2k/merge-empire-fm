/// The floating resource bar.
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
import 'package:merge_empire_fc/ui/hud/coin_counter.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart';
import 'package:merge_empire_fc/ui/shell/app_shell.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

Future<ProviderContainer> pumpHud(
  WidgetTester tester,
  void Function(Map<String, dynamic> state) mutate, {
  VoidCallback? onSettings,
}) async {
  final state = createDefaultState();
  mutate(state);
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
          home: Scaffold(body: Hud(onSettings: onSettings)),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 800));
  return container;
}

void main() {
  tearDown(() {
    resetLocale();
    clearBus();
  });

  testWidgets('shows coins, gems and energy off the save', (tester) async {
    final container = await pumpHud(tester, (s) {
      (s['resources'] as Map<String, dynamic>)['fanCoins'] = 1234;
      (s['resources'] as Map<String, dynamic>)['gems'] = 7;
      (s['energy'] as Map<String, dynamic>)['current'] = 4;
    });
    expect(container.read(energyMaxProvider), 10);
    expect(find.text('4/10'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('energy shows the UPGRADED max when the upgrade is owned', (
    tester,
  ) async {
    // getEnergyMax reads shop.energyUpgraded. A HUD hardcoding 10 would show a
    // player holding 15 pips a bar that reads 15/10.
    final container = await pumpHud(tester, (s) {
      (s['shop'] as Map<String, dynamic>)['energyUpgraded'] = true;
      (s['energy'] as Map<String, dynamic>)['current'] = 15;
    });
    expect(container.read(energyMaxProvider), 15);
    expect(find.text('15/15'), findsOneWidget);
  });

  testWidgets('the coin + deep-links to the shop coin section', (tester) async {
    final container = await pumpHud(tester, (_) {});
    await tester.tap(find.byKey(const ValueKey('hud-coins-plus')));
    await tester.pump();
    final shell = container.read(shellControllerProvider);
    expect(shell.tab, ShellTab.shop);
    expect(shell.pendingShopSection, ShopSection.coins);
    expect(shell.noSlide, isTrue);
  });

  testWidgets('the whole gem chip deep-links to the gem section', (tester) async {
    final container = await pumpHud(tester, (_) {});
    await tester.tap(find.byKey(const ValueKey('hud-gems')));
    await tester.pump();
    expect(
      container.read(shellControllerProvider).pendingShopSection,
      ShopSection.gems,
    );
  });

  testWidgets('the energy + asks for the energy popup', (tester) async {
    await pumpHud(tester, (_) {});
    var asked = 0;
    on('nav:energy', (_) => asked++);
    await tester.tap(find.byKey(const ValueKey('hud-energy-plus')));
    await tester.pump();
    expect(asked, 1);
  });

  testWidgets('the cog runs its callback', (tester) async {
    var opened = 0;
    await pumpHud(tester, (_) {}, onSettings: () => opened++);
    await tester.tap(find.byKey(const ValueKey('hud-cog')));
    await tester.pump();
    expect(opened, 1);
  });

  group('the coin counter', () {
    testWidgets('counts up rather than snapping', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: const Scaffold(body: CoinCounter(value: 0)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: const Scaffold(body: CoinCounter(value: 1000)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<Text>(find.byType(Text)).data,
        isNot('1,000'),
        reason: 'it should still be counting up',
      );

      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.widget<Text>(find.byType(Text)).data, '1,000');
    });
  });

  testWidgets('the HUD gets out of the way of a card reveal', (tester) async {
    // The reveal overlay dims everything and sits under the HUD; an unhidden
    // HUD punches through its dim.
    await pumpShellWithHud(tester);
    expect(hudVisible(tester), isTrue);

    emit('reveal:start');
    await tester.pump(const Duration(milliseconds: 32));
    expect(hudVisible(tester), isFalse);

    emit('reveal:end');
    await tester.pump(const Duration(milliseconds: 32));
    expect(hudVisible(tester), isTrue);
  });
}

Future<void> pumpShellWithHud(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(createDefaultState())}),
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
}

bool hudVisible(WidgetTester tester) => tester
    .widget<Visibility>(find.byKey(const ValueKey('hud-layer')))
    .visible;

/// Any kit will do; the HUD only reads colours off the extension.
ThemeData buildTestTheme() => buildAppTheme(kitId: '#4caf50', light: false);
