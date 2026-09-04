/// Coins flying to the counter, and the one thing that must never make them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'dart:convert';

import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/hud/coin_counter.dart';
import 'package:merge_empire_fc/ui/hud/coin_flight.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

/// Where a widget sits in the order the frame is painted in. The overlay is one
/// list, so "above the sheet" is "later in it".
int _paintOrder(WidgetTester tester, Finder of) {
  final target = tester.element(of);
  var seen = 0;
  var found = -1;
  void walk(Element e) {
    if (e == target) found = seen;
    seen++;
    e.visitChildren(walk);
  }

  walk(tester.binding.rootElement!);
  return found;
}

/// A scope with a save behind it: the layer reads the balance it starts from,
/// because `coins:updated` fires on a SPEND too and it has to know which way the
/// figure went.
ProviderContainer scope(WidgetTester tester) {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(createDefaultState())}),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(gameProvider).load();
  return container;
}

Future<CoinFlightState> pumpFlight(WidgetTester tester) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: scope(tester),
      child: MaterialApp(
        home: Stack(
          children: [
            // Something for the coins to fly TO. Without it there is nowhere to
            // aim and the launch is a no-op, which is also the honest behaviour
            // on a screen with no HUD.
            Positioned(
              top: 10,
              right: 10,
              child: CoinCounter(key: coinChipKey, value: 100),
            ),
            // The other two wallets have chips of their own now — see
            // `flightWallets`. A chip that is not on screen has no target and
            // the launch is a no-op, so a test that wants gems to fly has to
            // give them somewhere to land, the same as coins.
            Positioned(top: 10, right: 90, child: Text('0', key: gemChipKey)),
            Positioned(
              top: 10,
              right: 160,
              child: Text('0', key: energyChipKey),
            ),
            const Positioned.fill(child: CoinFlight()),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  return tester.state<CoinFlightState>(find.byType(CoinFlight));
}

/// Wait out the stagger.
///
/// **A SPRITE IS ONLY PUT UP ON THE FRAME IT STARTS MOVING** — see
/// `coin_flight.dart`'s header — so the whole handful is in the air a beat
/// after the reward rather than on the frame of it. Anything asking "how many
/// flew" has to wait for the last one to be thrown.
Future<void> pumpStagger(WidgetTester tester) => tester.pump(
  const Duration(milliseconds: coinFlightStaggerMs * coinFlightSprites),
);

void main() {
  tearDown(clearBus);

  testWidgets('a reward throws a handful of coins at the counter', (
    tester,
  ) async {
    // Money that arrives out of nowhere is money nobody notices: every reward
    // moved the figure in the HUD and nothing joined the two.
    final state = await pumpFlight(tester);
    expect(state.flying, 0);

    emit('coins:updated', 90000);
    await tester.pump();
    await pumpStagger(tester);
    expect(state.flying, coinFlightSprites);
    expect(find.byKey(const ValueKey('coin-flight')), findsOneWidget);

    // They stagger out and they all land.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(state.flying, 0);
  });

  testWidgets('AND SO DO GEMS AND ENERGY, at their own chips', (tester) async {
    // It was written for coins and the other two chips sat there while gems and
    // energy landed silently. Reported from the couch.
    final state = await pumpFlight(tester);

    // **AND THE FIRST GRANT OF THE SESSION FLIES.** All three balances are
    // seeded from the SAVE now — a default one starts on no gems — so a gem
    // payout no longer has to be the second one of the run to be animated.
    // Coins and energy were only ever seeded by accident, by the loop
    // announcing them within a second of boot; gems do not move at all until
    // something hands some over.
    emit('gems:updated', 5);
    await tester.pump();
    await pumpStagger(tester);
    expect(state.flying, greaterThan(0));
    final gemSprites = state.flying;
    await tester.pumpAndSettle();
    expect(state.flying, 0);

    emit('energy:updated', 999);
    await tester.pump();
    await pumpStagger(tester);
    expect(state.flying, greaterThan(0));
    await tester.pumpAndSettle();
    expect(state.flying, 0);

    // Fewer than a handful of change: seven gems reads as a jackpot and a gem
    // reward is usually one or two.
    expect(gemSprites, lessThan(coinFlightSprites));
  });

  testWidgets('and SPENDING throws nothing, in any wallet', (tester) async {
    // Money flying INTO the counter as it goes down is the animation telling
    // the opposite of the truth.
    final state = await pumpFlight(tester);
    for (final event in ['gems:updated', 'energy:updated']) {
      emit(event, 10);
      await tester.pump();
      await tester.pumpAndSettle();
      emit(event, 4);
      await tester.pump();
      expect(state.flying, 0, reason: event);
    }
  });

  testWidgets('AND ENERGY REGEN THROWS NOTHING EITHER', (tester) async {
    // The loop hands a pip back on its own, and a flight for every one of them
    // is the fault `coins:idle` exists to prevent. `game_runner` emits
    // `energy:idle` immediately before the update, the same way.
    final state = await pumpFlight(tester);
    emit('energy:updated', 3);
    await tester.pump();
    await tester.pumpAndSettle();

    emit('energy:idle', 1);
    emit('energy:updated', 4);
    await tester.pump();
    expect(state.flying, 0);

    // And the flag is spent: the next real one still flies.
    emit('energy:updated', 5);
    await tester.pump();
    await pumpStagger(tester);
    expect(state.flying, greaterThan(0));
    await tester.pumpAndSettle();
  });

  testWidgets('THE IDLE TRICKLE THROWS NOTHING', (tester) async {
    // It lands every second. A counter that swells every second is furniture
    // rather than a reward, so the loop says so itself before it announces the
    // balance — see `coins:idle` in `game_runner.dart`.
    final state = await pumpFlight(tester);
    emit('coins:idle', 3);
    emit('coins:updated', 90003);
    await tester.pump();
    expect(state.flying, 0);
  });

  testWidgets('and it only excuses the ONE update it came with', (
    tester,
  ) async {
    // The pair is emitted inside the same throttle in the loop, so a skipped
    // update can never leave the flag set and swallow a real reward.
    final state = await pumpFlight(tester);
    emit('coins:idle', 3);
    emit('coins:updated', 90003);
    await tester.pump();
    expect(state.flying, 0);

    emit('coins:updated', 91000);
    await tester.pump();
    await pumpStagger(tester);
    expect(state.flying, coinFlightSprites);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('SPENDING throws nothing at all', (tester) async {
    // `coins:updated` fires on a spend as well — a signing, a trait roll, an
    // upgrade — and coins flying INTO the counter as it goes down is the
    // animation telling the opposite of the truth.
    final state = await pumpFlight(tester);
    emit('coins:updated', 91000);
    await tester.pump();
    await pumpStagger(tester);
    expect(state.flying, coinFlightSprites);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    emit('coins:updated', 40);
    await tester.pump();
    expect(state.flying, 0);
  });

  testWidgets('AND THEY FLY OVER THE SHEET THAT HANDED THE MONEY OVER', (
    tester,
  ) async {
    // The layer used to draw in the shell's own `Stack`, which is under every
    // modal route in the game — so the rewards most worth animating were the
    // ones that could never be seen: the daily reward sheet, the welcome-back
    // card, a shop purchase, an ad payout. All of them pay out from inside a
    // route.
    final state = await pumpFlight(tester);
    final context = tester.element(find.byType(CoinFlight));
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => const SizedBox(height: 300, child: Text('a sheet')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('a sheet'), findsOneWidget);

    emit('coins:updated', 90000);
    await tester.pump();
    await pumpStagger(tester);
    expect(state.flying, coinFlightSprites);

    // Painted after the route, which is what puts them on top of it.
    final sprites = find.byKey(const ValueKey('coin-flight'));
    expect(sprites, findsOneWidget);
    expect(
      _paintOrder(tester, sprites),
      greaterThan(_paintOrder(tester, find.text('a sheet'))),
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  group('A SPRITE IS NEVER ON SCREEN WITHOUT MOVING', () {
    testWidgets('AND A FULL-SCREEN ROUTE DOES NOT FREEZE THE THROW', (
      tester,
    ) async {
      // **The reported fault, and it is a `TickerMode` one.** The sprites draw
      // in the ROOT overlay so they are over the route — but the LAYER is
      // mounted in the shell, and a Navigator mutes `TickerMode` for
      // everything under the topmost route. So a reward paid from inside a
      // mini-game or a shop sheet put the handful up in the middle of the
      // screen and left it there, frozen at the start of its arc, until the
      // route was popped. Reported from the couch: a yellow dot in the middle
      // of the screen that nobody could identify, which flew to the HUD on the
      // way home.
      //
      // The existing sheet test does not catch it — a modal bottom sheet is
      // not opaque, so what is underneath keeps its clock. A pushed page is.
      final state = await pumpFlight(tester);
      final navigator = Navigator.of(tester.element(find.byType(CoinFlight)));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('a whole screen')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('a whole screen'), findsOneWidget);

      emit('coins:updated', 90000);
      await tester.pump();
      await pumpStagger(tester);
      expect(state.flying, coinFlightSprites);

      // The clock is the point: a muted layer reads as every sprite stuck on
      // zero, which is what the dot in the middle of the screen WAS.
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        state.progress,
        everyElement(greaterThan(0.0)),
        reason: 'the throw is frozen under the route',
      );
      expect(state.progress, isNotEmpty);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(state.flying, 0, reason: 'a sprite never arrived');
    });

    testWidgets('and a HEALTHY throw never reaches the backstop', (
      tester,
    ) async {
      // Frame by frame, the way a device runs it: the last sprite is thrown at
      // `coinFlightStaggerMs * (coinFlightSprites - 1)` and lands
      // `coinFlightMs` later, well inside `coinFlightLifetime`. The backstop
      // must not be culling throws that were going to land.
      final state = await pumpFlight(tester);
      emit('coins:updated', 90000);
      for (
        var t = 0;
        t < coinFlightLifetime.inMilliseconds + 200;
        t += 16
      ) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(state.flying, 0);
      expect(state.swept, 0, reason: 'the backstop swept a healthy throw');
    });

    testWidgets('AND A STALLED THROW IS SWEPT, wherever it stalled', (
      tester,
    ) async {
      // The backstop, not the fix. **A sprite that is not moving is not an
      // animation, it is litter** — asked for flat: the dot must never just
      // sit there, no matter where it is. So whatever stalls a throw next, the
      // sprites come down rather than parking. Simulated by taking the frames
      // away, which is what a muted clock did.
      final state = await pumpFlight(tester);
      emit('coins:updated', 90000);
      await tester.pump();
      await pumpStagger(tester);
      expect(state.flying, coinFlightSprites);

      // **ONE pump across the whole lifetime, which is the stall.** The test
      // binding elapses the fake clock — firing `Timer`s — and only THEN draws
      // a single frame, so at the moment the backstop's timer goes off the
      // controllers are still sitting wherever the last frame left them. That
      // is a layer getting no frames, which is what the muted clock was.
      await tester.pump(coinFlightLifetime + const Duration(milliseconds: 50));
      expect(state.swept, 1, reason: 'the backstop never fired');
      expect(
        state.flying,
        0,
        reason: 'a sprite outlived its own flight and stayed on screen',
      );
      expect(find.byKey(const ValueKey('coin-flight')), findsNothing);
    });

    testWidgets('and the sweep still pays the swell it was announcing', (
      tester,
    ) async {
      // The money was never in the flight — it is already in the save — so a
      // sweep costs the animation and nothing else.
      final state = await pumpFlight(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CoinFlight)),
      );
      final before = container.read(coinRewardProvider);
      emit('coins:updated', 90000);
      await tester.pump();
      await pumpStagger(tester);
      await tester.pump(coinFlightLifetime + const Duration(milliseconds: 50));
      expect(state.swept, 1);
      expect(state.flying, 0);
      expect(container.read(coinRewardProvider), greaterThan(before));
    });

    testWidgets('and none of them WAITS at the throw point', (tester) async {
      // The stagger is what makes a handful of change out of one thick coin,
      // and every sprite used to be drawn at the throw point for the length of
      // its own delay — so the last of seven sat in the middle of the screen
      // for a quarter of a second before it went anywhere. Asked for in one
      // sentence: as soon as they appear they fly up, otherwise they should
      // not be there.
      final state = await pumpFlight(tester);
      emit('coins:updated', 90000);
      // Walked frame by frame across the whole stagger: at no point is there a
      // sprite on screen that has not started moving.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        // At most the one just thrown, which has not had a tick yet. Before
        // the fix all seven sat here on the first frame and the last of them
        // for a quarter of a second.
        expect(
          state.progress.where((p) => p == 0).length,
          lessThanOrEqualTo(1),
          reason: 'sprites were parked at the throw point on frame $i',
        );
      }
      expect(state.flying, coinFlightSprites);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('reduced motion takes the reward without the throw', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope(tester),
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Stack(
              children: [
                Positioned(
                  top: 10,
                  right: 10,
                  child: CoinCounter(key: coinChipKey, value: 100),
                ),
                const Positioned.fill(child: CoinFlight()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final state = tester.state<CoinFlightState>(find.byType(CoinFlight));
    emit('coins:updated', 90000);
    await tester.pump();
    expect(state.flying, 0);
  });
}
