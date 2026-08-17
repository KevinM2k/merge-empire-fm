import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/config.dart';

/// Values pinned against node output from
/// `../merge-empire-fc/src/data/clubAssets.js`, floating-point artifacts
/// included — the port uses the same arithmetic, so it reproduces the same
/// IEEE754 results and can assert them exactly.
Map<String, dynamic> _assets(String category, {required int tier, bool owned = true}) => {
  category: {'owned': owned, 'tier': tier, 'invested': 0, 'tapCount': 0},
};

void main() {
  group('categories', () {
    test('there are seven, in canonical order', () {
      expect(AssetCategory.all, [
        'TRAINING',
        'MERCH',
        'STADIUM',
        'MEDIA',
        'SPONSOR',
        'ACADEMY',
        'FANZONE',
      ]);
    });

    test('every category has display metadata', () {
      for (final cat in AssetCategory.all) {
        expect(assetMeta[cat], isNotNull, reason: cat);
        expect(assetMeta[cat]!.name, isNotEmpty, reason: cat);
        expect(assetMeta[cat]!.hint, isNotEmpty, reason: cat);
        expect(assetMeta[cat]!.icon, isNotEmpty, reason: cat);
      }
    });

    test('metadata has no extra categories', () {
      expect(assetMeta.keys.toSet(), AssetCategory.all.toSet());
    });

    test('the grid can hold every asset', () {
      expect(ClubGrid.maxAssets, greaterThanOrEqualTo(AssetCategory.all.length));
    });
  });

  group('defaultClubAssets', () {
    test('includes every category, unowned at tier zero', () {
      final d = defaultClubAssets();
      expect(d.keys, AssetCategory.all);
      for (final cat in AssetCategory.all) {
        expect(d[cat], {
          'owned': false,
          'tier': 0,
          'invested': 0,
          'tapCount': 0,
        }, reason: cat);
      }
    });

    test('returns a fresh map each call', () {
      final a = defaultClubAssets();
      final b = defaultClubAssets();
      (a['TRAINING'] as Map)['tier'] = 5;
      expect((b['TRAINING'] as Map)['tier'], 0);
    });
  });

  group('tap economics', () {
    test('taps per tier', () {
      expect(
        List.generate(9, tapsForTier),
        [0, 10, 15, 20, 25, 30, 35, 40, 0],
      );
    });

    test('tier totals are derived, not tabulated', () {
      expect(tierCosts, [0, 1200, 5400, 21000, 75000, 270000, 945000, 3300000]);
    });

    test('tierThreshold reads the totals and is safe out of range', () {
      expect(tierThreshold(1), 1200);
      expect(tierThreshold(7), 3300000);
      expect(tierThreshold(99), 0);
      expect(tierThreshold(-1), 0);
    });

    test('tier 1 tap costs ramp first to last', () {
      expect(
        List.generate(10, (i) => tapCost(1, i)),
        [80, 89, 98, 107, 116, 124, 133, 142, 151, 160],
      );
    });

    test('tier 3 tap costs ramp first to last', () {
      expect(
        List.generate(20, (i) => tapCost(3, i)),
        [
          700, 737, 774, 811, 847, 884, 921, 958, 995, 1032,
          1068, 1105, 1142, 1179, 1216, 1253, 1289, 1326, 1363, 1400,
        ],
      );
    });

    test('the last tap of a tier is twice the first', () {
      for (var tier = 1; tier <= 7; tier++) {
        final first = tapCost(tier, 0);
        final last = tapCost(tier, tapsForTier(tier) - 1);
        expect(last, first * 2, reason: 'tier $tier');
      }
    });

    test("the next tier's opening tap always costs more than this tier's last", () {
      for (var tier = 1; tier < 7; tier++) {
        expect(
          tapCost(tier + 1, 0),
          greaterThan(tapCost(tier, tapsForTier(tier) - 1)),
          reason: 'tier $tier to ${tier + 1}',
        );
      }
    });

    test('costs rise monotonically within a tier', () {
      for (var tier = 1; tier <= 7; tier++) {
        for (var i = 1; i < tapsForTier(tier); i++) {
          expect(
            tapCost(tier, i),
            greaterThanOrEqualTo(tapCost(tier, i - 1)),
            reason: 'tier $tier tap $i',
          );
        }
      }
    });

    test('the summed taps equal the tier total', () {
      for (var tier = 1; tier <= 7; tier++) {
        final summed = List.generate(
          tapsForTier(tier),
          (i) => tapCost(tier, i),
        ).fold<int>(0, (a, b) => a + b);
        expect(summed, tierThreshold(tier), reason: 'tier $tier');
      }
    });

    test('build cost is flat', () {
      expect(buildCost, 500);
    });

    test('the tier ceiling matches the top division cap', () {
      expect(maxAssetTier, 8);
    });
  });

  group('effect curves', () {
    test('training cooldown multiplier', () {
      expect(
        List.generate(9, trainingCooldownMult),
        [1, 0.95, 0.9, 0.85, 0.8, 0.75, 0.7, 0.6499999999999999, 0.6],
      );
    });

    test('training cooldown caps at -40%', () {
      expect(trainingCooldownMult(8), 0.6);
      expect(trainingCooldownMult(20), 0.6);
    });

    test('media payout multiplier', () {
      expect(
        List.generate(9, mediaPayoutMult),
        [1, 1.19, 1.38, 1.57, 1.76, 1.95, 2.14, 2.33, 2.52],
      );
    });

    test('a maxed Training plus Media pair lands at the documented ceiling', () {
      // The +19% rate exists so this equals the old stacked pair's x2.52.
      expect(mediaPayoutMult(8), closeTo(2.52, 1e-9));
    });

    test('academy scout discount', () {
      expect(
        List.generate(9, academyScoutDiscount),
        [
          0, 0.025, 0.05, 0.07500000000000001, 0.1,
          0.125, 0.15000000000000002, 0.17500000000000002, 0.2,
        ],
      );
    });

    test('academy discount caps at 20%', () {
      expect(academyScoutDiscount(8), 0.2);
      expect(academyScoutDiscount(50), 0.2);
    });

    test('sponsor stamina multiplier', () {
      expect(
        [
          for (var t = 0; t <= 8; t++)
            sponsorStaminaMult(_assets(AssetCategory.sponsor, tier: t)),
        ],
        [1, 0.96, 0.92, 0.88, 0.84, 0.8, 0.76, 0.72, 0.7],
      );
    });

    test('sponsor stamina caps at -30% drain', () {
      expect(sponsorStaminaMult(_assets(AssetCategory.sponsor, tier: 8)), 0.7);
      expect(sponsorStaminaMult(_assets(AssetCategory.sponsor, tier: 20)), 0.7);
    });

    test('an unowned sponsor counts as tier zero', () {
      expect(
        sponsorStaminaMult(_assets(AssetCategory.sponsor, tier: 8, owned: false)),
        1,
      );
    });

    test('missing or malformed clubAssets is treated as tier zero', () {
      expect(sponsorStaminaMult(null), 1);
      expect(sponsorStaminaMult({}), 1);
      expect(sponsorStaminaMult({'SPONSOR': 'nonsense'}), 1);
    });
  });

  group('fanZoneTier', () {
    test('reads an owned tier', () {
      expect(fanZoneTier(_assets(AssetCategory.fanzone, tier: 4)), 4);
    });

    test('an unowned Fan Zone is tier zero', () {
      expect(
        fanZoneTier(_assets(AssetCategory.fanzone, tier: 4, owned: false)),
        0,
      );
    });

    test('a missing Fan Zone is tier zero', () {
      expect(fanZoneTier(null), 0);
      expect(fanZoneTier({}), 0);
    });
  });

  group('getUnlockedMinigames', () {
    test('the ladder adds exactly one game a rung, 0 through 6', () {
      const expected = [
        ['penalty'],
        ['penalty', 'training'],
        ['penalty', 'training', 'keepy_uppys'],
        ['penalty', 'training', 'keepy_uppys', 'through_ball'],
        ['penalty', 'training', 'keepy_uppys', 'through_ball', 'whack'],
        ['penalty', 'training', 'keepy_uppys', 'through_ball', 'whack', 'pairs'],
        [
          'penalty', 'training', 'keepy_uppys', 'through_ball',
          'whack', 'pairs', 'boot_room',
        ],
      ];
      for (var tier = 0; tier <= 6; tier++) {
        expect(
          getUnlockedMinigames(_assets(AssetCategory.training, tier: tier)),
          expected[tier],
          reason: 'tier $tier',
        );
      }
    });

    test('no dead tier — every rung 1..6 adds a game', () {
      for (var tier = 1; tier <= 6; tier++) {
        expect(
          getUnlockedMinigames(_assets(AssetCategory.training, tier: tier)).length,
          getUnlockedMinigames(_assets(AssetCategory.training, tier: tier - 1)).length + 1,
          reason: 'tier $tier',
        );
      }
    });

    test('tiers past 6 add nothing further', () {
      final at6 = getUnlockedMinigames(_assets(AssetCategory.training, tier: 6));
      expect(getUnlockedMinigames(_assets(AssetCategory.training, tier: 8)), at6);
    });

    test('penalty training is free from the start', () {
      // A save with no Training Ground still needs somewhere to tap — that is
      // what teaches the panel exists at all.
      expect(getUnlockedMinigames(null), ['penalty']);
      expect(
        getUnlockedMinigames(_assets(AssetCategory.training, tier: 5, owned: false)),
        ['penalty'],
      );
    });
  });

  group('getUnlockedColours', () {
    test('stacks every tier up to the current one', () {
      expect(getUnlockedColours(8), [
        '#33691e', '#0d47a1', '#006064', '#d35400',
        '#880e4f', '#e91e63',
        '#795548', '#37474f',
        'sunset', 'midnight',
        'empire', 'void',
      ]);
    });

    test('an intermediate tier stops at the last unlocked band', () {
      expect(getUnlockedColours(4), [
        '#33691e', '#0d47a1', '#006064', '#d35400',
        '#880e4f', '#e91e63',
      ]);
    });

    test('tier zero unlocks nothing', () {
      expect(getUnlockedColours(0), isEmpty);
    });

    test('the set only grows with tier', () {
      for (var tier = 1; tier <= 8; tier++) {
        final prev = getUnlockedColours(tier - 1);
        final now = getUnlockedColours(tier);
        expect(now.length, greaterThanOrEqualTo(prev.length), reason: 'tier $tier');
        expect(now.take(prev.length), prev, reason: 'tier $tier prefix');
      }
    });

    test('no colour is unlocked twice', () {
      final all = getUnlockedColours(8);
      expect(all.toSet().length, all.length);
    });

    test('the retired hues are gone', () {
      // #00acc1, #7f8c8d, #bdc3c7 and #e8e8e8 were retired; saves migrate to
      // the nearest kept hue.
      final all = getUnlockedColours(8);
      for (final retired in ['#00acc1', '#7f8c8d', '#bdc3c7', '#e8e8e8']) {
        expect(all, isNot(contains(retired)), reason: retired);
      }
    });
  });
}
