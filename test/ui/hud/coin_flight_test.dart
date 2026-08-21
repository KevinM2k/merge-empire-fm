/// Coins flying to the counter, and the one thing that must never make them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/hud/coin_counter.dart';
import 'package:merge_empire_fc/ui/hud/coin_flight.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

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
            const Positioned.fill(child: CoinFlight()),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  return tester.state<CoinFlightState>(find.byType(CoinFlight));
}

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
    expect(state.flying, coinFlightSprites);
    expect(find.byKey(const ValueKey('coin-flight')), findsOneWidget);

    // They stagger out and they all land.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(state.flying, 0);
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
    expect(state.flying, coinFlightSprites);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    emit('coins:updated', 40);
    await tester.pump();
    expect(state.flying, 0);
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
