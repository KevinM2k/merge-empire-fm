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
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
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

  group('how much room it takes', () {
    testWidgets('THE CLEARANCE IS THE BAR, MEASURED', (tester) async {
      // The queue asked whether 56 on top of the notch is too deep. Answered by
      // measuring rather than by eye — and it turns the number from an opinion
      // somebody has to re-form every time the bar changes into a contract the
      // build keeps. A clearance SHORTER than the glass slides the page under
      // it; much longer is a band of wasted screen at the top of every tab.
      await pumpHud(tester, (_) {}, topPadding: 44, tab: ShellTab.grid);
      final glass = tester.getRect(find.byKey(const ValueKey('hud-glass')));
      // The notch is inside the glass — that is what lets the blur run to the
      // top of the screen instead of starting under it.
      expect(glass.top, 0);
      expect(
        glass.height,
        closeTo(44 + hudClearance - hudBottomMargin, 1.5),
        reason:
            'the glass is ${glass.height.toStringAsFixed(1)}px against a '
            'clearance of ${(44 + hudClearance).toStringAsFixed(1)} — a page '
            'either slides under the bar or starts a long way below it',
      );
    });

    testWidgets('and the chips sit inside it, clear of the notch', (
      tester,
    ) async {
      await pumpHud(tester, (_) {}, topPadding: 44, tab: ShellTab.grid);
      final glass = tester.getRect(find.byKey(const ValueKey('hud-glass')));
      final coins = tester.getRect(find.byKey(const ValueKey('hud-coins')));
      expect(coins.top, greaterThanOrEqualTo(44));
      expect(coins.bottom, lessThanOrEqualTo(glass.bottom + 0.5));
    });
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

  /// **AND THERE IS NO "SHOP" BUTTON UNDER THE PACKS.** The sheet IS the
  /// shelf — every pack on the tab is already on it — so a control offering to
  /// take the player somewhere to see what they were looking at was asked to go.
  testWidgets('and the sheet does not offer to take you to the shop', (
    tester,
  ) async {
    final container = await pumpHud(tester, (_) {});
    await tester.tap(find.byKey(const ValueKey('hud-coins-plus')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('currency-sheet-shop')), findsNothing);
    expect(container.read(shellControllerProvider).tab, isNot(ShellTab.shop));
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

  group('the resource colours', () {
    test('are three colours a player can actually tell apart', () {
      // Energy was `#57BCFF` and gems `#7FD4FF` — twenty degrees apart, both
      // pale, both blue. Coding that cannot be told apart is not coding.
      double hue(Color c) => HSLColor.fromColor(c).hue;
      final hues = [hudCoinInk, hudEnergyInk, hudGemInk].map(hue).toList();
      for (var i = 0; i < hues.length; i++) {
        for (var j = i + 1; j < hues.length; j++) {
          final apart = (hues[i] - hues[j]).abs();
          expect(
            apart > 45 && apart < 315,
            isTrue,
            reason: 'hues ${hues[i]} and ${hues[j]} are the same colour',
          );
        }
      }
    });

    test('and all three are vivid enough to read on the club\'s chrome', () {
      for (final c in [hudCoinInk, hudEnergyInk, hudGemInk]) {
        expect(
          HSLColor.fromColor(c).saturation,
          greaterThan(0.6),
          reason: '$c',
        );
      }
    });
  });

  group('the chrome', () {
    testWidgets('both bars wear the CLUB\'s colour, not a grey surface', (
      tester,
    ) async {
      // The JS's own decision: light mode is a neutral page, and the kit hue is
      // used for accents "AND for the HUD top bar + bottom tab bar, which are
      // solid accent-coloured chrome". Both bars were `surface`, so a player who
      // picked claret and blue got a grey app with a green tint in the buttons.
      await pumpHud(tester, (_) {}, tab: ShellTab.shop);
      final context = tester.element(find.byType(Hud));
      final kit = Theme.of(context).extension<KitTheme>()!;
      final gradients = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byKey(const ValueKey('hud-glass')),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((b) => b.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.gradient)
          .whereType<LinearGradient>();
      // The middle stop IS the accent in light mode.
      expect(
        gradients.any((g) => g.colors.contains(kit.accent)),
        isTrue,
        reason: 'the band is not wearing the kit',
      );
    });

    testWidgets('and it is a dark TINT of the same hue in dark mode', (
      tester,
    ) async {
      // A saturated bar on a near-black page is a stripe of daylight across it.
      await pumpHud(
        tester,
        (s) => (s['settings'] as Map<String, dynamic>)['lightMode'] = false,
        tab: ShellTab.shop,
      );
      final context = tester.element(find.byType(Hud));
      final kit = Theme.of(context).extension<KitTheme>()!;
      final chrome = hudChrome(kit, context);
      for (final c in chrome.colors) {
        final luma = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
        expect(luma, lessThan(0.12), reason: 'too bright for a dark page: $c');
        // Still the hue — a bar that has gone to pure black says nothing about
        // whose club it is.
        expect(c.g, greaterThan(c.r));
      }
    });

    testWidgets('the cluster is ONE glass pane, on every tab', (tester) async {
      // It was four panes on Play and four themed pills everywhere else: one
      // instrument reading as two, and the glass version reading as embossed
      // buttons.
      for (final tab in [ShellTab.home, ShellTab.shop]) {
        await pumpHud(tester, (_) {}, tab: tab);
        expect(
          find.byKey(const ValueKey('hud-cluster')),
          findsOne,
          reason: tab.name,
        );
      }
    });
  });

  group('where it sits', () {
    testWidgets('the resources are a group on the RIGHT', (tester) async {
      // `.hud-chips { margin-left: auto }`. They had been packed against the
      // crest with the empty half of the bar on the right.
      await pumpHud(tester, (_) {});
      final badge = tester.getRect(find.byKey(const ValueKey('hud-badge')));
      final cluster = tester.getRect(find.byKey(const ValueKey('hud-cluster')));
      final bar = tester.getRect(find.byType(Hud));

      expect(badge.left - bar.left, lessThan(28), reason: 'crest on the left');
      expect(
        cluster.left - badge.right,
        greaterThan(24),
        reason: 'and the gap is BEFORE the resources, not after them',
      );
      expect(bar.right - cluster.right, lessThan(28));
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

  /// **THE MULTIPLIER WAS ON THE BOOKS AND THE COUNT WAS NOWHERE.** The income
  /// breakdown names the level in its own row, so a player could read `×1.2`
  /// with no way to see they had prestiged twice. `.hud-prestige` in
  /// `hud.css` is a star, a `×` and the figure beside the crest, and
  /// `:empty { display: none }` is why a save that has never prestiged shows
  /// nothing at all.
  group('the prestige count', () {
    testWidgets('is beside the crest once there is one', (tester) async {
      await pumpHud(tester, (s) {
        (s['prestige'] as Map<String, dynamic>)['level'] = 2;
      });
      expect(find.byKey(const ValueKey('hud-prestige')), findsOneWidget);
      expect(find.text('×2'), findsOneWidget);
    });

    testWidgets('and is not drawn at all on a save that has never '
        'prestiged', (tester) async {
      await pumpHud(tester, (_) {});
      expect(find.byKey(const ValueKey('hud-prestige')), findsNothing);
    });

    testWidgets('it reads the SAVE, so it holds on every tab', (tester) async {
      await pumpHud(tester, (s) {
        (s['prestige'] as Map<String, dynamic>)['level'] = 7;
      }, tab: ShellTab.shop);
      expect(find.text('×7'), findsOneWidget);
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
