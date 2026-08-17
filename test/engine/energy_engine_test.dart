import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/engine/energy_engine.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/time.dart';

int _clock = 1000000000;

Map<String, dynamic> _state({
  int current = 0,
  int? lastRegenAt,
  bool upgraded = false,
  bool hardMode = false,
}) => {
  'energy': <String, dynamic>{
    'current': current,
    'lastRegenAt': lastRegenAt ?? _clock,
  },
  'shop': <String, dynamic>{if (upgraded) 'energyUpgraded': true},
  'settings': <String, dynamic>{'hardMode': hardMode},
  'boosts': <String, dynamic>{},
};

void main() {
  setUp(() {
    _clock = 1000000000;
    setClock(() => _clock);
  });
  tearDown(() {
    resetClock();
    clearBus();
  });

  group('the cap and the rate', () {
    test('default to ten pips every ten minutes', () {
      final state = _state();
      expect(getEnergyMax(state), 10);
      expect(getEnergyRegenMs(state), 10 * 60 * 1000);
    });

    test('the Energy Director raises the cap and shortens the wait', () {
      final state = _state(upgraded: true);
      expect(getEnergyMax(state), 15);
      expect(getEnergyRegenMs(state), 450000);
      expect(getEnergyRegenMs(state), lessThan(Energy.regenMs));
    });

    test('a save with no shop block takes the defaults', () {
      expect(getEnergyMax(<String, dynamic>{}), Energy.max);
      expect(getEnergyRegenMs(null), Energy.regenMs);
    });
  });

  group('processEnergyRegen', () {
    test('grants nothing before a full interval has passed', () {
      final state = _state(current: 3);
      _clock += Energy.regenMs - 1;
      expect(processEnergyRegen(state), 0);
      expect(state['energy']['current'], 3);
    });

    test('grants one pip per elapsed interval', () {
      final state = _state(current: 2);
      _clock += Energy.regenMs * 3;
      expect(processEnergyRegen(state), 3);
      expect(state['energy']['current'], 5);
    });

    test('keeps the part-served interval rather than resetting the clock', () {
      // Checking the app often used to restart the countdown each time, so a
      // pip never arrived for anyone who kept looking.
      final state = _state(current: 0);
      final start = state['energy']['lastRegenAt'] as int;
      _clock += Energy.regenMs + 60000;
      processEnergyRegen(state);
      expect(state['energy']['lastRegenAt'], start + Energy.regenMs);
      // The leftover minute counts toward the next pip.
      expect(msUntilNextPip(state), Energy.regenMs - 60000);
    });

    test('never overfills the tank', () {
      final state = _state(current: 8);
      _clock += Energy.regenMs * 50;
      expect(processEnergyRegen(state), 50);
      expect(state['energy']['current'], 10);
    });

    test('a full tank just restamps the clock', () {
      final state = _state(current: 10);
      _clock += Energy.regenMs * 4;
      expect(processEnergyRegen(state), 0);
      expect(state['energy']['current'], 10);
      expect(state['energy']['lastRegenAt'], _clock);
    });

    test('the upgraded tank fills to fifteen on the shorter interval', () {
      final state = _state(current: 0, upgraded: true);
      _clock += Energy.regenMsUpgraded * 20;
      processEnergyRegen(state);
      expect(state['energy']['current'], 15);
    });

    test('builds the energy branch on a save that has none', () {
      final state = <String, dynamic>{};
      expect(processEnergyRegen(state), 0);
      expect(state['energy'], isA<Map<String, dynamic>>());
    });
  });

  group('msUntilNextPip', () {
    test('is a full interval immediately after a pip lands', () {
      final state = _state(current: 1);
      expect(msUntilNextPip(state), Energy.regenMs);
    });

    test('counts down as time passes', () {
      final state = _state(current: 1);
      _clock += 4 * 60 * 1000;
      expect(msUntilNextPip(state), Energy.regenMs - 4 * 60 * 1000);
    });

    test('is zero when the tank is full — there is nothing to wait for', () {
      expect(msUntilNextPip(_state(current: 10)), 0);
    });

    test('wraps within the interval rather than going negative', () {
      final state = _state(current: 1);
      _clock += Energy.regenMs * 2 + 30000;
      expect(msUntilNextPip(state), Energy.regenMs - 30000);
    });
  });

  group('spendEnergy', () {
    test('debits and announces', () {
      final state = _state(current: 5);
      Object? announced;
      on('energy:updated', (v) => announced = v);
      expect(spendEnergy(state, 2).ok, isTrue);
      expect(state['energy']['current'], 3);
      expect(announced, 3);
    });

    test('refuses and changes nothing when the tank is short', () {
      final state = _state(current: 1);
      final result = spendEnergy(state, 2);
      expect(result.ok, isFalse);
      expect(result.reason, 'not_enough_energy');
      expect(state['energy']['current'], 1);
    });

    test('spending exactly what is left is allowed', () {
      final state = _state(current: 2);
      expect(spendEnergy(state, 2).ok, isTrue);
      expect(state['energy']['current'], 0);
    });

    test('a match costs one pip', () {
      final state = _state(current: 10);
      spendEnergy(state, Energy.matchCost);
      expect(state['energy']['current'], 9);
    });
  });

  group('onWatchAdComplete', () {
    test('an energy video pays three pips', () {
      final state = _state(current: 2);
      onWatchAdComplete(state, 'energy');
      expect(state['energy']['current'], 2 + Energy.adReward);
    });

    test('and never past the cap', () {
      final state = _state(current: 9);
      onWatchAdComplete(state, 'energy');
      expect(state['energy']['current'], 10);
    });

    test('the upgraded cap lets the same video pay more of itself', () {
      final state = _state(current: 13, upgraded: true);
      onWatchAdComplete(state, 'energy');
      expect(state['energy']['current'], 15);
    });

    test('a boost video starts a timed income boost', () {
      final state = _state();
      Object? announced;
      on('boost:started', (v) => announced = v);
      onWatchAdComplete(state, 'boost');
      expect(state['boosts']['incomeBoostActive'], isTrue);
      expect(state['boosts']['incomeBoostEndsAt'], _clock + Idle.boostDurationMs);
      expect(announced, _clock + Idle.boostDurationMs);
    });

    test('an unknown reward type does nothing', () {
      final state = _state(current: 4);
      onWatchAdComplete(state, 'mystery');
      expect(state['energy']['current'], 4);
      expect(state['boosts'], isEmpty);
    });
  });

  group('shouldPrefetchEnergyAd', () {
    test('yes when the tank is low', () {
      expect(shouldPrefetchEnergyAd(_state(current: 0)), isTrue);
      expect(shouldPrefetchEnergyAd(_state(current: Energy.adPrefetchMax)), isTrue);
    });

    test('no when the player has plenty — the slot is worth more elsewhere', () {
      // AdMob caches exactly one rewarded ad, so an untapped prefetch evicts
      // the placement the player was actually about to use.
      expect(
        shouldPrefetchEnergyAd(_state(current: Energy.adPrefetchMax + 1)),
        isFalse,
      );
    });

    test('no when the tank is full', () {
      expect(shouldPrefetchEnergyAd(_state(current: 10)), isFalse);
    });

    test('always yes in Pro mode', () {
      // Pips aren't spent there, so the pip count says nothing about whether
      // the ad is wanted — and guessing wrong leaves the player on a cold ad.
      expect(
        shouldPrefetchEnergyAd(_state(current: 10, hardMode: true)),
        isTrue,
      );
    });

    test('a bare save is treated as empty', () {
      expect(shouldPrefetchEnergyAd(<String, dynamic>{}), isTrue);
      expect(shouldPrefetchEnergyAd(null), isTrue);
    });
  });

  group('shouldPrefetchDoubleMatchAd', () {
    test('warms up after a win or a draw', () {
      expect(shouldPrefetchDoubleMatchAd({'won': true}), isTrue);
      expect(shouldPrefetchDoubleMatchAd({'drawn': true}), isTrue);
    });

    test('not after a defeat — that screen is being dismissed, not watched', () {
      expect(
        shouldPrefetchDoubleMatchAd({'won': false, 'drawn': false}),
        isFalse,
      );
    });

    test('a missing result is not worth a slot', () {
      expect(shouldPrefetchDoubleMatchAd(null), isFalse);
      expect(shouldPrefetchDoubleMatchAd(<String, dynamic>{}), isFalse);
    });
  });

  test('the ad safety timeout clears the longest rewarded ad', () {
    // Rewarded ads run to about thirty seconds; the timeout only exists to
    // unblock the UI when the SDK drops its Dismissed event entirely.
    expect(adSafetyTimeoutMs, greaterThanOrEqualTo(45000));
  });
}
