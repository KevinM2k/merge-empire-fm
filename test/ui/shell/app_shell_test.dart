/// The tab shell.
///
/// The ticker test is the load-bearing one. The whole design assumes
/// `TickerMode` replaces `screenFreeze.js` — the JS's `.screen-frozen *` rule,
/// `freezeWhenSettled` and its `requestIdleCallback` scheduling — so it is
/// asserted rather than believed.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/placeholder_screen.dart';
import 'package:merge_empire_fc/ui/shell/app_shell.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/shell/shell_routes.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

Future<ProviderContainer> pumpShell(WidgetTester tester) async {
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
          // The home screen's walker loops forever, so `pumpAndSettle` would
          // never settle. He honours reduce-motion; declaring it here is what a
          // device with that setting on would do.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),

          home: AppShell(
            // Placeholders for all five: these tests are about the stack, the
            // tickers and the transitions, not about any screen.
            screenFor: (tab) => PlaceholderScreen(
              key: ValueKey('screen-${tab.name}'),
              label: tab.name,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 32));
  return container;
}

/// pumpAndSettle is unusable here: a live screen animates forever, so there is
/// no frame at which nothing is scheduled.
Future<void> settle(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 32));

ShellTab activeTabOf(WidgetTester tester) {
  final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
  return tabOrder[stack.index!];
}

/// skipOffstage: false — an IndexedStack keeps its inactive children in the
/// tree, unpainted, and those are exactly the ones worth asserting about.
PlaceholderScreenState screenState(WidgetTester tester, ShellTab tab) =>
    tester.state<PlaceholderScreenState>(
      find.byKey(ValueKey('screen-${tab.name}'), skipOffstage: false),
    );

void main() {
  tearDown(resetLocale);

  test('the tab order is the one the JS ships', () {
    expect(tabOrder, [
      ShellTab.grid,
      ShellTab.squad,
      ShellTab.home,
      ShellTab.club,
      ShellTab.shop,
    ]);
  });

  testWidgets('opens on the Play tab', (tester) async {
    await pumpShell(tester);
    expect(activeTabOf(tester), ShellTab.home);
  });

  testWidgets('tapping a tab switches to it', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byKey(const ValueKey('tab-shop')));
    await tester.pump(const Duration(milliseconds: 32));
    expect(activeTabOf(tester), ShellTab.shop);
  });

  testWidgets('every tab is reachable from the bar', (tester) async {
    await pumpShell(tester);
    for (final tab in tabOrder) {
      await tester.tap(find.byKey(ValueKey('tab-${tab.name}')));
      await tester.pump(const Duration(milliseconds: 32));
      expect(activeTabOf(tester), tab);
    }
  });

  testWidgets('the raised Play tab is icon-only but still named', (
    tester,
  ) async {
    await pumpShell(tester);
    // The JS drops this one label deliberately: it was the only label in the bar
    // telling you nothing its icon didn't. The accessible name stays.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tab-home')),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tab-club')),
        matching: find.byType(Text),
      ),
      findsOneWidget,
      reason: 'the other four keep their labels',
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('tab-home'))).label,
      contains(t('nav.play')),
    );
  });

  testWidgets('an offscreen tab keeps its state', (tester) async {
    // The IndexedStack contract. A tab rebuilt from scratch on every visit loses
    // its scroll position and anything mid-animation.
    await pumpShell(tester);
    screenState(tester, ShellTab.grid).bump();

    await tester.tap(find.byKey(const ValueKey('tab-shop')));
    await tester.pump(const Duration(milliseconds: 32));
    await tester.tap(find.byKey(const ValueKey('tab-grid')));
    await tester.pump(const Duration(milliseconds: 32));

    expect(screenState(tester, ShellTab.grid).bumps, 1);
  });

  testWidgets('an offscreen tab stops ticking', (tester) async {
    // This is what replaces screenFreeze.js. If it does not hold, the frame
    // budget story needs redesigning rather than patching.
    await pumpShell(tester);

    expect(
      screenState(tester, ShellTab.grid).isTicking,
      isFalse,
      reason: 'grid starts offscreen',
    );
    expect(
      screenState(tester, ShellTab.home).isTicking,
      isTrue,
      reason: 'league is the opening tab',
    );

    await tester.tap(find.byKey(const ValueKey('tab-grid')));
    await tester.pump(const Duration(milliseconds: 32));

    expect(screenState(tester, ShellTab.grid).isTicking, isTrue);
    expect(screenState(tester, ShellTab.home).isTicking, isFalse);

    // And the flag is not just cosmetic: the muted screen is handed no frames.
    final leagueTicks = screenState(tester, ShellTab.home).ticks;
    final gridTicks = screenState(tester, ShellTab.grid).ticks;
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(screenState(tester, ShellTab.home).ticks, leagueTicks);
    expect(screenState(tester, ShellTab.grid).ticks, greaterThan(gridTicks));
  });

  testWidgets('A SIDEWAYS FLING CHANGES NOTHING', (tester) async {
    // **The swipe is gone, and this is the assertion that used to be its
    // opposite.** Every tab in this game is something you drag on — a card
    // across the grid, a player onto the pitch, a filter strip sideways — so an
    // intercepted or slightly diagonal drag threw the player onto a different
    // screen. Reported from the couch as happening by accident, with the note
    // that the five buttons in the bar are what people use anyway.
    await pumpShell(tester);
    final was = activeTabOf(tester);
    for (final dx in [-200.0, 200.0]) {
      await tester.fling(find.byType(IndexedStack), Offset(dx, 0), 1000);
      await settle(tester);
      expect(activeTabOf(tester), was, reason: 'a fling of $dx moved the tab');
    }
  });

  testWidgets('and the BUTTONS still do', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byKey(const ValueKey('tab-shop')));
    await settle(tester);
    expect(activeTabOf(tester), ShellTab.shop);
    await tester.tap(find.byKey(const ValueKey('tab-grid')));
    await settle(tester);
    expect(activeTabOf(tester), ShellTab.grid);
  });

  testWidgets('a tab tap slides, and a deep link does not', (tester) async {
    await pumpShell(tester);
    final shell = tester.state<AppShellState>(find.byType(AppShell));

    shell.goTab(ShellTab.shop);
    await tester.pump();
    // Mid-slide: the incoming screen is still off to one side.
    final mid = tester.widget<SlideTransition>(
      find.byKey(const ValueKey('tab-slide')),
    );
    expect(mid.position.value, isNot(Offset.zero));

    await tester.pump(const Duration(milliseconds: 300));
    shell.goTab(ShellTab.grid, noSlide: true);
    await tester.pump();
    final deep = tester.widget<SlideTransition>(
      find.byKey(const ValueKey('tab-slide')),
    );
    expect(
      deep.position.value,
      Offset.zero,
      reason: 'a deep link arrives already in place',
    );
  });

  testWidgets('the tab labels are translated, not hardcoded', (tester) async {
    await pumpShell(tester);
    expect(find.text(t('nav.shop')), findsOneWidget);
    setLocale('fr');
    await tester.pumpWidget(const SizedBox());
    await pumpShell(tester);
    expect(find.text(t('nav.shop')), findsOneWidget);
    expect(t('nav.shop'), isNot('Shop'), reason: 'fr should differ from en');
  });

  testWidgets('a sheet opens over the shell and closes on back', (
    tester,
  ) async {
    await pumpShell(tester);
    final context = tester.element(find.byType(IndexedStack));
    unawaited(
      openShellSheet(context, ShellSheet.trophies, const Text('sheet body')),
    );
    await settle(tester);
    await settle(tester);
    expect(find.text('sheet body'), findsOneWidget);

    // The Android back button, which the JS has to route through nav:back after
    // asking itself whether a sheet is open.
    await tester.binding.handlePopRoute();
    await settle(tester);
    await settle(tester);
    expect(find.text('sheet body'), findsNothing);
    expect(activeTabOf(tester), ShellTab.home);
  });

  testWidgets('the event route forces dark only for a themed event', (
    tester,
  ) async {
    final container = await pumpShell(tester);
    final context = tester.element(find.byType(IndexedStack));
    // ConsumerState exposes a WidgetRef, which is what the real caller has.
    final ref = tester.state<AppShellState>(find.byType(AppShell)).ref;
    expect(container.read(forcedDarkProvider), isFalse);

    // Deadline Day: no palette, so the player's light mode survives.
    unawaited(
      openEventRoute(
        context,
        ref,
        const Scaffold(body: Text('plain event')),
        hasPalette: false,
      ),
    );
    await settle(tester);
    await settle(tester);
    expect(container.read(forcedDarkProvider), isFalse);
    await tester.binding.handlePopRoute();
    await settle(tester);
    await settle(tester);

    // A themed event is a fixed dark showpiece for as long as it is up.
    unawaited(
      openEventRoute(
        context,
        ref,
        const Scaffold(body: Text('themed event')),
        hasPalette: true,
      ),
    );
    await settle(tester);
    await settle(tester);
    expect(container.read(forcedDarkProvider), isTrue);

    await tester.binding.handlePopRoute();
    await settle(tester);
    await settle(tester);
    expect(
      container.read(forcedDarkProvider),
      isFalse,
      reason: 'back restores it too',
    );
  });

  testWidgets('the home tab has no sub-tabs left to reset', (tester) async {
    // The JS rule was "tapping Play is take me home", which needed a reset
    // because Home had a sub-tab strip. It has none: the table and the fixtures
    // are quick-nav sheets that close over the screen rather than replacing it,
    // so the rule holds by construction and there is nothing to call.
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
    await settle(tester);

    expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);

    // Away and back leaves the same screen, not a remembered sub-tab.
    await tester.tap(find.byKey(const ValueKey('tab-shop')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('tab-home')));
    await settle(tester);
    expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);
  });
}
