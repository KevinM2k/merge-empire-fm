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
import 'package:merge_empire_fc/ui/screens/settings_screen.dart';
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

  /// What the notch takes, for the tests that are about clearing it.
  double topPadding = 0,

  /// The HUD is written for dark glass on the Play tab and for the app's own
  /// surface everywhere else, so the tab decides which build is under test.
  ShellTab tab = ShellTab.home,
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
  container.read(shellControllerProvider.notifier).goTab(tab);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(400, 800),
              padding: EdgeInsets.only(top: topPadding),
            ),
            child: Scaffold(body: Hud(onSettings: onSettings)),
          ),
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

  testWidgets('the coin + opens the coin packs, where they are', (
    tester,
  ) async {
    // NOT a tab switch. It used to deep-link the Shop, which scrolled the coin
    // heading to the top of the viewport — under the HUD that had just been
    // tapped. A player who taps the coin counter wants to buy coins.
    final container = await pumpHud(tester, (_) {});
    await tester.tap(find.byKey(const ValueKey('hud-coins-plus')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('currency-sheet-coins')), findsOneWidget);
    expect(
      container.read(shellControllerProvider).tab,
      isNot(ShellTab.shop),
      reason: 'nothing was navigated to',
    );
  });

  testWidgets('and the whole gem chip opens the gem packs', (tester) async {
    await pumpHud(tester, (_) {});
    await tester.tap(find.byKey(const ValueKey('hud-gems')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('currency-sheet-gems')), findsOneWidget);
  });

  testWidgets('and the rest of the shop is one tap from the sheet', (
    tester,
  ) async {
    final container = await pumpHud(tester, (_) {});
    await tester.tap(find.byKey(const ValueKey('hud-coins-plus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('currency-sheet-shop')));
    await tester.pumpAndSettle();
    final shell = container.read(shellControllerProvider);
    expect(shell.tab, ShellTab.shop);
    expect(
      shell.pendingShopSection,
      ShopSection.coins,
      reason: 'and it lands on the shelf the sheet was showing',
    );
    expect(shell.noSlide, isTrue);
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

  testWidgets('the cog opens the real Settings screen', (tester) async {
    // It opened a stub for three modules — reachable in a test, dead in the
    // running app.
    await pumpShellWithHud(tester);
    await tester.tap(find.byKey(const ValueKey('hud-cog')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
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

  group('where it sits', () {
    testWidgets('the resources are a group on the RIGHT', (tester) async {
      // `.hud-chips { margin-left: auto }`. They had been packed against the
      // crest with the empty half of the bar on the right.
      await pumpHud(tester, (_) {});
      final badge = tester.getRect(find.byKey(const ValueKey('hud-badge')));
      final coins = tester.getRect(find.byKey(const ValueKey('hud-coins')));
      final cog = tester.getRect(find.byKey(const ValueKey('hud-cog')));
      final bar = tester.getRect(find.byType(Hud));

      expect(badge.left - bar.left, lessThan(28), reason: 'crest on the left');
      expect(
        coins.left - badge.right,
        greaterThan(24),
        reason: 'and the gap is BEFORE the resources, not after them',
      );
      expect(bar.right - cog.right, lessThan(28));
    });

    testWidgets('and its glass covers the notch, not just the bar', (
      tester,
    ) async {
      // A `SafeArea` around the whole HUD pushed the frosted band below the
      // notch and left the raw page showing above it — a white strip across the
      // top of the Shop in light mode.
      await pumpHud(tester, (_) {}, topPadding: 47, tab: ShellTab.shop);
      final glass = tester.getRect(find.byKey(const ValueKey('hud-glass')));
      expect(
        glass.top,
        moreOrLessEquals(tester.getRect(find.byType(Hud)).top, epsilon: 0.5),
        reason: 'the blur starts where the HUD does, notch included',
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('hud-coins'))).top,
        greaterThanOrEqualTo(47),
        reason: 'and the chips still clear it',
      );
    });
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

bool hudVisible(WidgetTester tester) =>
    tester.widget<Visibility>(find.byKey(const ValueKey('hud-layer'))).visible;

/// Any kit will do; the HUD only reads colours off the extension.
ThemeData buildTestTheme() => buildAppTheme(kitId: '#4caf50', light: false);
