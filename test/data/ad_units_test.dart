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

  /// **RECORDED BEFORE THE SCREEN THAT SHOWS THEM.** There is no News screen
  /// yet and nothing in `lib/` reads this table — the ids are here so they live
  /// with the other twenty-eight rather than in a message, and this is what
  /// stops one of them being quietly mistyped in the meantime.
  group('the native table', () {
    test('both platforms carry the news banner, and neither borrows the '
        "other's id", () {
      expect(nativeByPlacementIos.keys.toSet(), nativeByPlacementAndroid.keys.toSet());
      expect(nativeUnitFor('android', 'news'), isNotNull);
      expect(nativeUnitFor('ios', 'news'), isNotNull);
      expect(nativeUnitFor('ios', 'news'), isNot(nativeUnitFor('android', 'news')));
      // The web build takes the Android ids, as everything else here does.
      expect(nativeUnitFor('web', 'news'), nativeUnitFor('android', 'news'));
    });

    test('the ids are ours, and are not any other placement\'s', () {
      final native = {
        for (final table in [nativeByPlacementAndroid, nativeByPlacementIos])
          for (final v in table.values) ?v,
      };
      expect(native, hasLength(2));
      for (final id in native) {
        expect(id, startsWith('ca-app-pub-0386196346828968/'));
      }
      final other = {
        for (final table in [
          rewardedByPlacementAndroid,
          rewardedByPlacementIos,
          interstitialByDivisionAndroid,
          interstitialByDivisionIos,
        ])
          for (final v in table.values) ?v,
      };
      expect(native.intersection(other), isEmpty);
    });

    /// **NO FALLBACK, and that is the point of a separate function.** The
    /// rewarded and interstitial tables fall back so a tap still pays out; a
    /// native banner has nothing to pay out and a rewarded unit rendered as a
    /// banner is a policy problem rather than a mislabelled revenue line.
    test('an unknown native placement gets nothing, not a borrowed unit', () {
      expect(nativeUnitFor('android', 'match_feed'), isNull);
      expect(nativeUnitFor('ios', 'match_feed'), isNull);
    });
  });

    test('a platform never borrows the other one\'s ids', () {
      // AdMob rejects cross-platform traffic outright.
      final android = {for (final v in rewardedByPlacementAndroid.values) ?v};
      final ios = {for (final v in rewardedByPlacementIos.values) ?v};
      expect(android.intersection(ios), isEmpty);
    });

    test('THE COSMETICS PLACEMENT HAS ITS OWN UNIT NOW, on both platforms', () {
      // It fell back to `energy_pip` for as long as these were null, which
      // served ads and filed the revenue under the wrong placement — and shared
      // `energy_pip`'s frequency cap, so a look unlocked ate into the energy
      // budget. Not sharing that cap is the whole point of a separate unit.
      expect(rewardedByPlacementAndroid['cosmetic_pack'], isNotNull);
      expect(rewardedByPlacementIos['cosmetic_pack'], isNotNull);
      expect(
        rewardedByPlacementAndroid['cosmetic_pack'],
        isNot(rewardedByPlacementIos['cosmetic_pack']),
      );
    });

  });

  /// **THE TABLES ABOVE ARE THE SPEC'S RECORD; THIS IS WHAT SERVES.** Every
  /// rewarded placement resolves to one unit per platform so that a warmed ad
  /// can be shown wherever the player taps first — see the head of
  /// `data/ad_units.dart`. The per-placement ids stay because
  /// `ad_units_parity_test` pins them against the JS fixture, and because a
  /// console that still holds them is a decision that can be reversed.
  group('THE GLOBAL REWARDED UNIT', () {
    test('every placement resolves to it, on both platforms', () {
      for (final placement in rewardedByPlacementAndroid.keys) {
        expect(
          rewardedUnitFor('android', placement),
          globalRewardedUnitAndroid,
          reason: placement,
        );
        expect(
          rewardedUnitFor('ios', placement),
          globalRewardedUnitIos,
          reason: placement,
        );
      }
    });

    test('and so does a placement nobody has heard of', () {
      // There is no fallback left to get wrong: an unknown placement is the
      // same unit as a known one, and only the analytics differ.
      expect(rewardedUnitFor('android', 'not_a_placement'), globalRewardedUnitAndroid);
      expect(rewardedUnitFor('ios', 'not_a_placement'), globalRewardedUnitIos);
    });

    test('the two platforms do not share it', () {
      // AdMob rejects cross-platform traffic outright, and the mistake looks
      // exactly like an ad network having no inventory.
      expect(globalRewardedUnitAndroid, isNot(globalRewardedUnitIos));
      expect(globalRewardedUnit('web'), globalRewardedUnitAndroid);
    });

    test('it is ours, and it is a UNIT id rather than an APP id', () {
      for (final id in [globalRewardedUnitAndroid, globalRewardedUnitIos]) {
        expect(id, startsWith('ca-app-pub-0386196346828968/'));
        expect(id, isNot(contains('~')), reason: 'that is an APP id');
      }
    });

    test('AND IT IS NOT ONE OF THE PER-PLACEMENT UNITS', () {
      // A global unit that is secretly `energy_pip`'s would put every
      // placement's impressions on one historical revenue line and read as
      // energy suddenly earning elevenfold.
      final perPlacement = {
        for (final table in [rewardedByPlacementAndroid, rewardedByPlacementIos])
          for (final v in table.values) ?v,
      };
      expect(perPlacement, isNot(contains(globalRewardedUnitAndroid)));
      expect(perPlacement, isNot(contains(globalRewardedUnitIos)));
    });

    test('and it is not an interstitial or a native unit either', () {
      // Format is not a label: a rewarded unit rendered as a banner is a policy
      // problem rather than a mislabelled revenue line.
      final other = {
        for (final table in [
          interstitialByDivisionAndroid,
          interstitialByDivisionIos,
          nativeByPlacementAndroid,
          nativeByPlacementIos,
        ])
          for (final v in table.values) ?v,
      };
      expect(other, isNot(contains(globalRewardedUnitAndroid)));
      expect(other, isNot(contains(globalRewardedUnitIos)));
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

    test('a known placement no longer resolves to its OWN unit', () {
      // The per-placement id is still on record and is no longer what serves —
      // see the global unit group above.
      expect(
        rewardedUnitFor('android', 'lucky_boot'),
        isNot(rewardedByPlacementAndroid['lucky_boot']),
      );
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
