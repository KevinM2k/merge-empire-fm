import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/boosts.dart';

void main() {
  group('the boost catalogue', () {
    test('four boosts, two of each kind', () {
      expect(boostList.length, 4);
      expect(boosts.length, 4);
      expect(boostList.where((b) => b.kind == BoostKind.proactive).length, 2);
      expect(
        boostList.where((b) => b.kind == BoostKind.retrospective).length,
        2,
      );
    });

    test('every key matches its id, and every boost has an icon', () {
      boosts.forEach((key, b) {
        expect(b.id, key);
        expect(b.icon, isNotEmpty, reason: key);
      });
    });

    test('one gem buys one', () {
      for (final b in boostList) {
        expect(b.packSize, 1, reason: b.id);
        expect(b.gemCost, 1, reason: b.id);
      }
    });

    // A retrospective boost is taken at the bench in front of the consequence;
    // it has no window because the match is paused while it is offered.
    test('only the proactive pair carry a window', () {
      for (final b in boostList) {
        expect(b.windowMinutes > 0, b.kind == BoostKind.proactive, reason: b.id);
      }
    });

    test('the window is twenty-five in-game minutes', () {
      expect(boosts['crowd_roar']!.windowMinutes, 25);
      expect(boosts['park_the_bus']!.windowMinutes, 25);
    });

    test('the four are the four', () {
      expect(boosts.keys.toSet(), {
        'crowd_roar',
        'park_the_bus',
        'var_review',
        'physio_sponge',
      });
      expect(boosts['var_review']!.kind, BoostKind.retrospective);
      expect(boosts['physio_sponge']!.kind, BoostKind.retrospective);
    });

    test('lookups tolerate a null or unknown id', () {
      expect(getBoost(null), isNull);
      expect(getBoost('nope'), isNull);
      expect(getBoost('crowd_roar')?.id, 'crowd_roar');
    });
  });
}
