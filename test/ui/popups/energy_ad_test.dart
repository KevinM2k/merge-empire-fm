/// What the energy sheet's video grants, and what it grants in PRO.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/engine/player_energy_engine.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/popups/energy_sheet.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/util/time.dart';

class _Ads implements RewardedAds {
  _Ads(this.outcome);

  final AdOutcome outcome;
  final List<String> shown = [];

  @override
  Future<AdOutcome> show(String placement) async {
    shown.add(placement);
    return outcome;
  }

  @override
  void prepare(String placement) {}


  @override

  void refresh() {}
}

/// A container with a save and a stand-in SDK, and a `ref` to reach them by.
Future<(ProviderContainer, WidgetRef)> _wire(
  WidgetTester tester,
  _Ads ads, {
  void Function(Map<String, dynamic>)? mutate,
}) async {
  final state = createDefaultState();
  mutate?.call(state);
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
      ),
      rewardedAdsProvider.overrideWithValue(ads),
    ],
  );
  addTearDown(container.dispose);
  container.read(gameProvider).load();

  late WidgetRef captured;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) {
          captured = ref;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return (container, captured);
}

void main() {
  tearDown(clearBus);

  testWidgets('a watched video adds pips, and says how many', (tester) async {
    final ads = _Ads(AdOutcome.rewarded);
    final (c, ref) = await _wire(
      tester,
      ads,
      mutate: (s) => (s['energy'] as Map<String, dynamic>)['current'] = 1,
    );
    final toasts = <Object?>[];
    on('toast:success', toasts.add);

    await watchEnergyAd(ref);

    expect(ads.shown, [energyPlacement]);
    expect(
      (c.read(gameProvider).state!['energy'] as Map)['current'],
      1 + Energy.adReward,
    );
    expect(toasts, hasLength(1));
    // Every write arms the 2s debounced save; pump past it or the binding
    // rightly complains about a pending timer.
    await tester.pump(const Duration(milliseconds: saveDebounceMs + 100));
  });

  testWidgets('PRO MODE REFILLS FITNESS, because there are no pips there', (
    tester,
  ) async {
    // The squad's match fitness is the gate in Pro, so the same video buys a
    // quarter of everyone's back rather than three of a currency that does not
    // exist. The JS branches on exactly this.
    final ads = _Ads(AdOutcome.rewarded);
    final (c, ref) = await _wire(
      tester,
      ads,
      mutate: (s) {
        (s['settings'] as Map<String, dynamic>)['hardMode'] = true;
        // The RAW map: `mutate` runs before the save is encoded, and a
        // `CardInstance` is not JSON.
        (s['grid'] as Map<String, dynamic>)['cells'] = <dynamic>[
          <String, dynamic>{
            'instanceId': 'c1',
            'definitionId': 'player_t5_fwd',
            'energy': 1,
            'energyUpdatedAt': now(),
          },
        ];
      },
    );

    await watchEnergyAd(ref);

    // **The BRANCH is what this test is about**, not the arithmetic — how much
    // a top-up is worth belongs to `player_energy_engine` and is tested there.
    final card = CardInstance.from(
      (c.read(gameProvider).state!['grid'] as Map)['cells'][0],
    )!;
    expect(
      (card.raw['energy'] as num).toDouble(),
      greaterThan(1),
      reason: 'the squad was not topped up',
    );
    expect(
      (card.raw['energy'] as num).toDouble(),
      lessThanOrEqualTo(getMaxEnergy(card).toDouble()),
      reason: 'a rewarded video overfilled, which only a PAID pack may do',
    );
    // And the pips are untouched: they are not what Pro spends.
    expect((c.read(gameProvider).state!['energy'] as Map)['current'], 10);
    await tester.pump(const Duration(milliseconds: saveDebounceMs + 100));
  });

  testWidgets('A CLOSED VIDEO GRANTS NOTHING and says nothing', (tester) async {
    final (c, ref) = await _wire(
      tester,
      _Ads(AdOutcome.dismissed),
      mutate: (s) => (s['energy'] as Map<String, dynamic>)['current'] = 1,
    );
    final toasts = <Object?>[];
    on('toast:info', toasts.add);
    on('toast:success', toasts.add);

    await watchEnergyAd(ref);

    expect((c.read(gameProvider).state!['energy'] as Map)['current'], 1);
    expect(toasts, isEmpty, reason: 'they closed it; they know');
  });

  testWidgets('but NO FILL says so — that one is not their doing', (
    tester,
  ) async {
    final (c, ref) = await _wire(
      tester,
      _Ads(AdOutcome.unavailable),
      mutate: (s) => (s['energy'] as Map<String, dynamic>)['current'] = 1,
    );
    final toasts = <Object?>[];
    on('toast:info', toasts.add);

    await watchEnergyAd(ref);

    expect((c.read(gameProvider).state!['energy'] as Map)['current'], 1);
    expect(toasts, hasLength(1));
  });
}
