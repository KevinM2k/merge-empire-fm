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
    // A BOX now, not a full-width button with its refusal printed underneath —
    // the two routes to more energy are alternatives and sit side by side. The
    // thing that must still hold is that this one cannot be taken.
    expect(
      tester
          .widget<InkWell>(
            find.descendant(
              of: find.byKey(const ValueKey('energy-watch-ad')),
              matching: find.byType(InkWell),
            ),
          )
          .onTap,
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

  testWidgets('THE TANK IS PIPS, not a fraction on its own', (tester) async {
    // The one thing on an energy sheet that could be a picture was `3/6` beside
    // a bolt, which asks the player to do the arithmetic the picture does for
    // them. A row of bolts says how much is left AND how big the tank is.
    await pumpShell(tester, energy: 2);
    await tester.tap(find.byKey(const ValueKey('hud-energy-plus')));
    await tester.pumpAndSettle();
    // Scoped to the SHEET: the HUD's own energy chip wears a bolt too.
    final bolts = tester
        .widgetList<Icon>(
          find.descendant(
            of: find.byKey(const ValueKey('energy-sheet')),
            matching: find.byType(Icon),
          ),
        )
        .where((i) => i.icon == Icons.bolt || i.icon == Icons.bolt_outlined);
    expect(bolts.where((i) => i.icon == Icons.bolt).length, 2);
    expect(bolts.length, greaterThan(2), reason: 'the empty pips are missing');
    // And the figure is still there, as the caption rather than the headline.
    expect(find.byKey(const ValueKey('energy-count')), findsOneWidget);
  });

  testWidgets('and the two routes are BOXES SIDE BY SIDE', (tester) async {
    // Stacked full-width buttons with their refusals printed underneath read as
    // a column of things that do not work. They are alternatives — watch
    // something, or pay — so they sit beside each other, which is what makes the
    // dead one the other half of a choice instead of a broken control.
    await pumpShell(tester);
    await tester.tap(find.byKey(const ValueKey('hud-energy-plus')));
    await tester.pumpAndSettle();
    final ad = find.byKey(const ValueKey('energy-watch-ad'));
    final buy = find.byKey(const ValueKey('energy-buy-refill'));
    expect(ad, findsOneWidget);
    expect(buy, findsOneWidget);
    // Level with each other, and one to the left of the other.
    expect(tester.getTopLeft(ad).dy, closeTo(tester.getTopLeft(buy).dy, 0.5));
    expect(tester.getTopLeft(ad).dx, lessThan(tester.getTopLeft(buy).dx));
  });
}
