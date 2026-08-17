import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/ad_units.dart';
import 'package:merge_empire_fc/data/divisions.dart';

void main() {
  group('the placement tables', () {
    test('the two platforms cover exactly the same placements', () {
      // A placement wired on one platform and not the other serves no ads to
      // half the players, silently.
      expect(
        rewardedByPlacementIos.keys.toSet(),
        rewardedByPlacementAndroid.keys.toSet(),
      );
    });

    test('every unit id belongs to our AdMob account', () {
      for (final table in [rewardedByPlacementAndroid, rewardedByPlacementIos]) {
        for (final entry in table.entries) {
          final id = entry.value;
          if (id == null) continue;
          expect(id, startsWith('ca-app-pub-0386196346828968/'), reason: entry.key);
        }
      }
    });

    test('no unit id is shared between two placements', () {
      // Separate units are the whole point — a shared one merges two revenue
      // lines AND makes the two placements share a frequency cap.
      for (final table in [rewardedByPlacementAndroid, rewardedByPlacementIos]) {
        final ids = [for (final v in table.values) ?v];
        expect(ids.toSet().length, ids.length);
      }
    });

    test('a platform never borrows the other one\'s ids', () {
      // AdMob rejects cross-platform traffic outright.
      final android = {for (final v in rewardedByPlacementAndroid.values) ?v};
      final ios = {for (final v in rewardedByPlacementIos.values) ?v};
      expect(android.intersection(ios), isEmpty);
    });

    test('the cosmetics placement is still unwired on both platforms', () {
      // Deliberate, and it has a cost: it falls back to energy_pip, which
      // serves ads but files the revenue under the wrong placement and shares
      // energy_pip's frequency cap — so cosmetic unlocks WOULD eat into the
      // energy budget. Delete this test when the real ids land.
      expect(rewardedByPlacementAndroid['cosmetic_pack'], isNull);
      expect(rewardedByPlacementIos['cosmetic_pack'], isNull);
    });
  });

  group('the interstitial tables', () {
    test('every division has its own unit, on both platforms', () {
      for (final div in divisions) {
        expect(interstitialByDivisionAndroid[div.id], isNotNull, reason: div.id);
        expect(interstitialByDivisionIos[div.id], isNotNull, reason: div.id);
      }
    });

    test('and no division borrows another\'s', () {
      // Per-division units are what turn season-end drop-off into a churn
      // signal with a league attached to it.
      for (final table in [interstitialByDivisionAndroid, interstitialByDivisionIos]) {
        expect(table.values.toSet().length, table.length);
      }
    });

    test('the tables hold the live ladder and nothing else', () {
      expect(
        interstitialByDivisionAndroid.keys.toSet(),
        divisions.map((d) => d.id).toSet(),
      );
    });
  });

  group('lookups', () {
    test('pick the platform table', () {
      expect(rewardedByPlacement('ios'), same(rewardedByPlacementIos));
      expect(rewardedByPlacement('android'), same(rewardedByPlacementAndroid));
    });

    test('anything that is not iOS takes the Android ids', () {
      // Matching the JS. The web build has no ad inventory either way.
      expect(rewardedByPlacement('web'), same(rewardedByPlacementAndroid));
      expect(interstitialByDivision('web'), same(interstitialByDivisionAndroid));
    });

    test('a known placement resolves to its own unit', () {
      expect(
        rewardedUnitFor('android', 'lucky_boot'),
        rewardedByPlacementAndroid['lucky_boot'],
      );
    });

    test('an unknown or unwired placement falls back to the longest-lived unit', () {
      expect(rewardedUnitFor('ios', 'not_a_placement'), fallbackRewardedUnit('ios'));
      expect(rewardedUnitFor('ios', 'cosmetic_pack'), fallbackRewardedUnit('ios'));
      expect(fallbackRewardedUnit('ios'), rewardedByPlacementIos['energy_pip']);
    });

    test('a known division resolves to its own interstitial', () {
      expect(
        interstitialUnitFor('android', 'elite_league'),
        interstitialByDivisionAndroid['elite_league'],
      );
    });

    test('an unknown or missing division falls back to the top flight unit', () {
      expect(
        interstitialUnitFor('android', 'retired_league'),
        fallbackInterstitialUnit('android'),
      );
      expect(interstitialUnitFor('android', null), fallbackInterstitialUnit('android'));
      expect(
        fallbackInterstitialUnit('android'),
        interstitialByDivisionAndroid['champions_cup'],
      );
    });
  });
}
