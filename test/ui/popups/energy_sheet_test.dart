/// The energy sheet, and the button that opens it.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_copy.dart' show gemItemDesc;
import 'package:merge_empire_fc/ui/shell/app_shell.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';
import 'package:merge_empire_fc/util/time.dart';

/// An SDK that always pays out, so the wiring is what is under test.
class PayingAds implements RewardedAds {
  final List<String> shown = [];

  @override
  Future<AdOutcome> show(String placement) async {
    shown.add(placement);
    // **It takes TIME, which is the whole point.** A video that resolves on the
    // next microtask lands while the sheet's route is still being torn down and
    // hides the defect this file's last test is about.
    await Future<void>.delayed(const Duration(seconds: 2));
    return AdOutcome.rewarded;
  }

  @override
  void prepare(String placement) {}
}

Future<ProviderContainer> pumpShell(
  WidgetTester tester, {
  int energy = 4,
  bool upgraded = false,
  RewardedAds? ads,
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
      if (ads != null) rewardedAdsProvider.overrideWithValue(ads),
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
    // By key: the ad row says the same thing when the tank is full, and for the
    // same reason — there is nothing to add.
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('energy-next'))).data,
      t('hud.energy_full'),
    );
  });

  /// The ad row's own tap target.
  InkWell adRow(WidgetTester tester) => tester.widget<InkWell>(
    find.descendant(
      of: find.byKey(const ValueKey('energy-watch-ad')),
      matching: find.byType(InkWell),
    ),
  );

  testWidgets('THE AD ROUTE CAN BE TAKEN NOW', (tester) async {
    // **Inverted, and the inversion is the news.** It said this route was named
    // and dead, like every other M4 control — `services/admob_ads.dart` is the
    // AdMob it was waiting for.
    await pumpShell(tester);
    await tester.tap(find.byKey(const ValueKey('hud-energy-plus')));
    await tester.pumpAndSettle();
    expect(adRow(tester).onTap, isNotNull);
  });

  testWidgets('and a full tank is what stops it', (tester) async {
    // Nothing to add to. The SDK's own answers — no fill, closed early — are
    // its business and are handled where the video is asked for.
    await pumpShell(tester, energy: 10);
    await tester.tap(find.byKey(const ValueKey('hud-energy-plus')));
    await tester.pumpAndSettle();
    expect(adRow(tester).onTap, isNull);
  });

  testWidgets('the Shop route works today', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byKey(const ValueKey('hud-energy-plus')));
    await tester.pumpAndSettle();

    // The gem option carries its description now, so the sheet is taller than
    // an 800x600 test viewport — it is a `ListView` and scrolls.
    await tester.ensureVisible(find.byKey(const ValueKey('energy-to-shop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('energy-to-shop')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('energy-sheet')), findsNothing);
    expect(find.byKey(const ValueKey('shop-scroll')), findsOneWidget);
  });

  /// **THE GEM ROUTE SAYS WHAT IT GIVES YOU.** The video option has always said
  /// so in its own title — "up to N energy" — and the gem one said "Energy
  /// Refill" and a price, so the only route a player PAYS for was the one that
  /// would not tell them what they were buying. Reported from the couch.
  testWidgets('the gem refill says what it gives, not just what it costs', (
    tester,
  ) async {
    final container = await pumpShell(tester, energy: 1);
    await tester.tap(find.byKey(const ValueKey('hud-energy-plus')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('energy-buy-refill')),
        // `{n}` comes from the tank the player actually HAS — an Energy
        // Director owner gets fifteen, so a literal would be a lie to them.
        matching: find.text(
          gemItemDesc(
            'energy_refill',
            state: container.read(gameProvider).state,
          ),
        ),
      ),
      findsOneWidget,
    );
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
  testWidgets('AND THE VIDEO STILL PAYS OUT AFTER THE SHEET CLOSES', (
    tester,
  ) async {
    // **The bug this was written for.** The tap popped the sheet and then
    // awaited the video on `sheetRef` — a `Consumer`'s ref inside the route
    // being popped — so the grant read the game through a disposed element and
    // did nothing. From the couch that is "I watched the ad and got no energy",
    // which is how it was reported.
    final ads = PayingAds();
    final container = await pumpShell(tester, energy: 1, ads: ads);
    await tester.tap(find.byKey(const ValueKey('hud-energy-plus')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('energy-watch-ad-btn')));
    // The sheet is gone well before the video ends.
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('energy-sheet')), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(ads.shown, isNotEmpty, reason: 'no video was even asked for');
    expect(
      (container.read(gameProvider).state!['energy'] as Map)['current'],
      1 + Energy.adReward,
    );
    await tester.pump(const Duration(milliseconds: saveDebounceMs + 100));
  });

}
