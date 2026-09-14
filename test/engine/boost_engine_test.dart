import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/boost_engine.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

void main() {
  setUp(resetBus);
  tearDown(resetBus);

  group('the boost inventory', () {
    test('DOES NOT USE THE SEASON BOOST KEY', () {
      final s = <String, dynamic>{
        'boosts': {'trophyPolishUntil': 123},
      };
      grantBoost(s, 'crowd_roar', 1);
      // The season flags are untouched; the inventory is its own branch.
      expect((s['boosts'] as Map)['trophyPolishUntil'], 123);
      expect(s['matchBoosts'], {'crowd_roar': 1});
    });

    test('reads zero from an empty or absent inventory', () {
      expect(boostCount(null, 'crowd_roar'), 0);
      expect(boostCount(<String, dynamic>{}, 'crowd_roar'), 0);
      expect(boostCount({'matchBoosts': {'var_review': 2}}, 'crowd_roar'), 0);
    });

    test('grants accumulate', () {
      final s = <String, dynamic>{};
      grantBoost(s, 'crowd_roar', 1);
      grantBoost(s, 'crowd_roar', 2);
      expect(boostCount(s, 'crowd_roar'), 3);
    });

    test('a grant of nothing, or of an unknown boost, writes nothing', () {
      final s = <String, dynamic>{};
      grantBoost(s, 'crowd_roar', 0);
      grantBoost(s, 'nope', 3);
      expect(s.containsKey('matchBoosts'), isFalse);
    });

    test('spending decrements, and refuses at zero without going negative', () {
      final s = <String, dynamic>{};
      grantBoost(s, 'crowd_roar', 1);
      expect(spendBoost(s, 'crowd_roar'), isTrue);
      expect(spendBoost(s, 'crowd_roar'), isFalse);
      expect(boostCount(s, 'crowd_roar'), 0);
    });

    test('announces a grant and a spend', () {
      var heard = 0;
      on('boosts:changed', (_) => heard++);
      final s = <String, dynamic>{};
      grantBoost(s, 'crowd_roar', 1);
      spendBoost(s, 'crowd_roar');
      spendBoost(s, 'crowd_roar'); // refused: nothing to announce
      expect(heard, 2);
    });
  });

  group('buyBoostPack', () {
    test('costs its gems and delivers its three', () {
      final s = <String, dynamic>{
        'resources': {'gems': 5},
      };
      final r = buyBoostPack(s, 'crowd_roar');
      expect(r.ok, isTrue);
      expect(r.reason, isNull);
      expect((s['resources'] as Map)['gems'], 3);
      expect(boostCount(s, 'crowd_roar'), 3);
    });

    test('REFUSES WITHOUT THE GEMS AND DELIVERS NOTHING', () {
      final s = <String, dynamic>{
        'resources': {'gems': 1},
      };
      expect(buyBoostPack(s, 'crowd_roar').reason, 'insufficient_gems');
      expect((s['resources'] as Map)['gems'], 1);
      expect(boostCount(s, 'crowd_roar'), 0);
    });

    test('refuses an unknown boost before touching the gems', () {
      final s = <String, dynamic>{
        'resources': {'gems': 5},
      };
      expect(buyBoostPack(s, 'nope').reason, 'unknown_boost');
      expect((s['resources'] as Map)['gems'], 5);
    });

    test('blocked reason matches what a purchase would refuse on', () {
      expect(boostPackBlocked({'resources': {'gems': 1}}, 'crowd_roar'),
          'insufficient_gems');
      expect(boostPackBlocked({'resources': {'gems': 2}}, 'crowd_roar'), isNull);
      expect(boostPackBlocked({'resources': {'gems': 9}}, 'nope'),
          'unknown_boost');
    });
  });
}
