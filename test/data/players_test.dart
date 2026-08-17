import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/util/random.dart';

/// The full generated table, captured from the JS
/// (`../merge-empire-fc/src/data/players.js`) via node. Ratings and idle income
/// are computed from position variance and rounding, so every value is pinned
/// rather than eyeballed — a rounding difference here silently re-balances the
/// whole game.
///
/// Columns: id, tier, position, rating, maxRating, idleIncomePerSec,
///          mergesInto, sellValue, attackRatio, name, art
const _expected = <List<Object?>>[
  ['player_t1_fwd', 1, 'FWD', 18, 26, 0.05, 'player_t2_fwd', 10, 0.75, 'Rodrigo Flash', 'cards/fwd_t1'],
  ['player_t2_fwd', 2, 'FWD', 28, 35, 0.15, 'player_t3_fwd', 25, 0.88, 'Hiro Blitz', 'cards/fwd_t2'],
  ['player_t3_fwd', 3, 'FWD', 37, 44, 0.41, 'player_t4_fwd', 60, 0.80, 'Lucas Rocket', 'cards/fwd_t3'],
  ['player_t4_fwd', 4, 'FWD', 46, 54, 1.02, 'player_t5_fwd', 150, 0.92, 'Emeka Turbo', 'cards/fwd_t4'],
  ['player_t5_fwd', 5, 'FWD', 56, 64, 2.56, 'player_t6_fwd', 400, 0.72, 'Antoine Swift', 'cards/fwd_t5'],
  ['player_t6_fwd', 6, 'FWD', 67, 75, 6.15, 'player_t7_fwd', 1000, 0.90, 'Kofi Bolt', 'cards/fwd_t6'],
  ['player_t7_fwd', 7, 'FWD', 78, 85, 15.37, 'player_t8_fwd', 3000, 0.85, 'Diego Ace', 'cards/fwd_t7'],
  ['player_t8_fwd', 8, 'FWD', 88, 95, 41.0, null, 8000, 0.95, 'Ivan Strike', 'cards/fwd_t8'],
  ['player_t9_fwd', 9, 'FWD', 100, 100, 123.0, null, 100000, 0.90, 'Piotr Dash', 'cards/fwd_t9'],
  ['player_t1_mid', 1, 'MID', 18, 26, 0.05, 'player_t2_mid', 10, 0.30, 'Sung-ho Vision', 'cards/mid_t1'],
  ['player_t2_mid', 2, 'MID', 27, 35, 0.15, 'player_t3_mid', 25, 0.65, 'Mateo Thread', 'cards/mid_t2'],
  ['player_t3_mid', 3, 'MID', 36, 44, 0.40, 'player_t4_mid', 60, 0.35, 'Giacomo Maestro', 'cards/mid_t3'],
  ['player_t4_mid', 4, 'MID', 45, 54, 1.00, 'player_t5_mid', 150, 0.60, 'Kenji Dynamo', 'cards/mid_t4'],
  ['player_t5_mid', 5, 'MID', 55, 64, 2.50, 'player_t6_mid', 400, 0.28, 'Lars Pulse', 'cards/mid_t5'],
  ['player_t6_mid', 6, 'MID', 65, 75, 6.00, 'player_t7_mid', 1000, 0.70, 'Chidi Engine', 'cards/mid_t6'],
  ['player_t7_mid', 7, 'MID', 76, 85, 15.00, 'player_t8_mid', 3000, 0.45, 'Klaus Ticker', 'cards/mid_t7'],
  ['player_t8_mid', 8, 'MID', 86, 95, 40.0, null, 8000, 0.55, 'Paulo Link', 'cards/mid_t8'],
  ['player_t1_def', 1, 'DEF', 18, 26, 0.05, 'player_t2_def', 10, 0.10, 'Imran Iron', 'cards/def_t1'],
  ['player_t2_def', 2, 'DEF', 27, 35, 0.15, 'player_t3_def', 25, 0.20, 'Hans Stone', 'cards/def_t2'],
  ['player_t3_def', 3, 'DEF', 36, 44, 0.40, 'player_t4_def', 60, 0.12, 'Obinna Fortress', 'cards/def_t3'],
  ['player_t4_def', 4, 'DEF', 45, 54, 0.99, 'player_t5_def', 150, 0.22, 'Dmitri Shield', 'cards/def_t4'],
  ['player_t5_def', 5, 'DEF', 54, 64, 2.48, 'player_t6_def', 400, 0.14, 'Rafael Bulwark', 'cards/def_t5'],
  ['player_t6_def', 6, 'DEF', 64, 75, 5.94, 'player_t7_def', 1000, 0.18, 'Erik Rock', 'cards/def_t6'],
  ['player_t7_def', 7, 'DEF', 75, 85, 14.85, 'player_t8_def', 3000, 0.20, 'Tunde Titan', 'cards/def_t7'],
  ['player_t8_def', 8, 'DEF', 85, 95, 39.6, null, 8000, 0.15, 'Pierre Bastion', 'cards/def_t8'],
  ['player_t1_gk', 1, 'GK', 18, 26, 0.05, 'player_t2_gk', 10, 0.00, 'Miguel Hands', 'cards/gk_t1'],
  ['player_t2_gk', 2, 'GK', 26, 35, 0.15, 'player_t3_gk', 25, 0.00, 'Peter Vault', 'cards/gk_t2'],
  ['player_t3_gk', 3, 'GK', 35, 44, 0.39, 'player_t4_gk', 60, 0.00, 'Laurent Safe', 'cards/gk_t3'],
  ['player_t4_gk', 4, 'GK', 44, 54, 0.98, 'player_t5_gk', 150, 0.00, 'Diego Block', 'cards/gk_t4'],
  ['player_t5_gk', 5, 'GK', 54, 64, 2.44, 'player_t6_gk', 400, 0.00, 'Akio Cat', 'cards/gk_t5'],
  ['player_t6_gk', 6, 'GK', 63, 75, 5.85, 'player_t7_gk', 1000, 0.00, 'Emeka Glove', 'cards/gk_t6'],
  ['player_t7_gk', 7, 'GK', 74, 85, 14.63, 'player_t8_gk', 3000, 0.00, 'Novak Wall', 'cards/gk_t7'],
  ['player_t8_gk', 8, 'GK', 84, 95, 39.0, null, 8000, 0.00, 'Anders Reach', 'cards/gk_t8'],
];

void main() {
  group('the generated definition table', () {
    test('has 33 definitions — 8 tiers x 4 positions, plus the unique T9', () {
      expect(players.length, 33);
      expect(players.length, 8 * 4 + 1);
    });

    test('matches the JS table row for row', () {
      expect(players.length, _expected.length);
      for (var i = 0; i < _expected.length; i++) {
        final row = _expected[i];
        final p = players[i];
        final where = 'row $i (${row[0]})';

        expect(p.id, row[0], reason: where);
        expect(p.tier, row[1], reason: where);
        expect(p.position, row[2], reason: where);
        expect(p.rating, row[3], reason: '$where rating');
        expect(p.maxRating, row[4], reason: '$where maxRating');
        expect(
          p.idleIncomePerSec,
          closeTo(row[5]! as double, 1e-9),
          reason: '$where idleIncomePerSec',
        );
        expect(p.mergesInto, row[6], reason: '$where mergesInto');
        expect(p.sellValue, row[7], reason: '$where sellValue');
        expect(
          p.attackRatio,
          closeTo(row[8]! as double, 1e-9),
          reason: '$where attackRatio',
        );
        expect(p.name, row[9], reason: '$where name');
        expect(p.art, row[10], reason: '$where art');
      }
    });

    test('ids are unique', () {
      expect(players.map((p) => p.id).toSet().length, players.length);
    });

    test('every definition carries 8 flavour texts (position x gender)', () {
      for (final p in players) {
        expect(p.flavourTexts.length, 8, reason: p.id);
        for (final f in p.flavourTexts) {
          expect(f, isNotEmpty, reason: p.id);
        }
      }
    });
  });

  group('tier structure', () {
    test('T9 exists only as a forward — it is globally unique', () {
      final t9 = players.where((p) => p.tier == 9).toList();
      expect(t9.length, 1);
      expect(t9.single.id, 'player_t9_fwd');
      expect(t9.single.position, 'FWD');
    });

    test('T9 is exactly 100 regardless of position variance', () {
      final t9 = players.firstWhere((p) => p.tier == 9);
      expect(t9.rating, 100);
      expect(t9.maxRating, 100);
    });

    test('T9 cannot be merged into and merges into nothing', () {
      expect(players.any((p) => p.mergesInto == 'player_t9_fwd'), isFalse);
      expect(players.firstWhere((p) => p.tier == 9).mergesInto, isNull);
    });

    test('T8 is the merge ceiling', () {
      for (final p in players.where((p) => p.tier == 8)) {
        expect(p.mergesInto, isNull, reason: p.id);
      }
    });

    test('every non-top tier merges into the same position one tier up', () {
      for (final p in players.where((p) => p.tier < 8)) {
        expect(p.mergesInto, isNotNull, reason: p.id);
        final target = getPlayerDef(p.mergesInto!);
        expect(target, isNotNull, reason: '${p.id} merges into a real card');
        expect(target!.tier, p.tier + 1, reason: p.id);
        expect(target.position, p.position, reason: p.id);
      }
    });

    test('rating never exceeds its tier ceiling', () {
      for (final p in players) {
        expect(p.rating, lessThanOrEqualTo(p.maxRating), reason: p.id);
      }
    });

    test('within a position, every tier beats the one below', () {
      for (final pos in ['FWD', 'MID', 'DEF', 'GK']) {
        final byTier = players.where((p) => p.position == pos).toList()
          ..sort((a, b) => a.tier.compareTo(b.tier));
        for (var i = 1; i < byTier.length; i++) {
          expect(
            byTier[i].rating,
            greaterThan(byTier[i - 1].rating),
            reason: '$pos T${byTier[i].tier} vs T${byTier[i - 1].tier}',
          );
          expect(
            byTier[i].idleIncomePerSec,
            greaterThan(byTier[i - 1].idleIncomePerSec),
            reason: '$pos T${byTier[i].tier} income',
          );
        }
      }
    });

    test('the GK-to-FWD spread stays within 5 points at every tier', () {
      // players.js: "Tight spread so GK->FWD gap stays <= 5 points".
      for (var tier = 1; tier <= 8; tier++) {
        final atTier = players.where((p) => p.tier == tier).toList();
        final ratings = atTier.map((p) => p.rating).toList();
        final spread =
            ratings.reduce((a, b) => a > b ? a : b) -
            ratings.reduce((a, b) => a < b ? a : b);
        expect(spread, lessThanOrEqualTo(5), reason: 'tier $tier');
      }
    });
  });

  group('getPlayerDef', () {
    test('returns the definition for a known id', () {
      expect(getPlayerDef('player_t5_mid')?.tierName, 'Gold Elite');
    });

    test('returns null for an unknown id', () {
      expect(getPlayerDef('nope'), isNull);
    });
  });

  group('getPlayersByTier', () {
    test('returns the four positions at a normal tier', () {
      expect(getPlayersByTier(3).length, 4);
      expect(
        getPlayersByTier(3).map((p) => p.position).toSet(),
        {'FWD', 'MID', 'DEF', 'GK'},
      );
    });

    test('returns the single card at T9', () {
      expect(getPlayersByTier(9).length, 1);
    });

    test('returns empty for a tier that does not exist', () {
      expect(getPlayersByTier(99), isEmpty);
    });
  });

  group('pickDisplayName', () {
    test('picks from the male pool by default', () {
      expect(pickDisplayName('FWD', 0, female: false), 'Rodrigo Flash');
      expect(pickDisplayName('GK', 0, female: false), 'Miguel Hands');
    });

    test('picks from the female pool when asked', () {
      expect(pickDisplayName('FWD', 0, female: true), 'Sofia Lightning');
      expect(pickDisplayName('GK', 0, female: true), 'Isabela Catlike');
    });

    test('wraps around the pool', () {
      expect(pickDisplayName('FWD', 10, female: false), 'Rodrigo Flash');
      expect(pickDisplayName('MID', 11, female: false), 'Mateo Thread');
    });

    test('falls back to the forward pool for an unknown position', () {
      expect(pickDisplayName('STRIKER', 0, female: false), 'Rodrigo Flash');
    });

    test('every pool holds 10 names', () {
      for (final pos in ['FWD', 'MID', 'DEF', 'GK']) {
        final male = {for (var i = 0; i < 10; i++) pickDisplayName(pos, i, female: false)};
        final female = {for (var i = 0; i < 10; i++) pickDisplayName(pos, i, female: true)};
        expect(male.length, 10, reason: '$pos male');
        expect(female.length, 10, reason: '$pos female');
        expect(male.intersection(female), isEmpty, reason: '$pos overlap');
      }
    });
  });

  group('getCardRating', () {
    test('applies a positive rating bonus', () {
      final def = getPlayerDef('player_t3_mid')!;
      expect(getCardRating(def, ratingBonus: 3), 39);
    });

    test('clamps to the tier ceiling', () {
      final def = getPlayerDef('player_t3_mid')!;
      expect(getCardRating(def, ratingBonus: 999), 44);
    });

    test('never drops below 1', () {
      final def = getPlayerDef('player_t3_mid')!;
      expect(getCardRating(def, ratingBonus: -999), 1);
    });

    test('T9 is always 100 whatever the bonus', () {
      final def = getPlayerDef('player_t9_fwd')!;
      expect(getCardRating(def, ratingBonus: -50), 100);
      expect(getCardRating(def, ratingBonus: 50), 100);
    });

    test('a null definition rates 0', () {
      expect(getCardRating(null), 0);
    });
  });

  group('agingPenalty', () {
    test('is free for the first ten seasons', () {
      for (var s = 0; s <= 10; s++) {
        expect(agingPenalty(s), 0, reason: 'season $s');
      }
    });

    test('costs 10 rating points per season beyond ten', () {
      expect(agingPenalty(11), 10);
      expect(agingPenalty(13), 30);
      expect(agingPenalty(20), 100);
    });
  });

  group('getCardAtkDefSplit', () {
    test('a balanced player reads at their rating on both stats', () {
      final split = getCardAtkDefSplit(0.5, 70);
      expect(split.attack, 70);
      expect(split.defence, 70);
    });

    test('a striker leads on attack and drops well below on defence', () {
      final split = getCardAtkDefSplit(0.8, 76);
      expect(split.attack, greaterThan(76));
      expect(split.defence, lessThan(45));
    });

    test('a keeper is the mirror of a striker', () {
      final striker = getCardAtkDefSplit(0.9, 70);
      final keeper = getCardAtkDefSplit(0.1, 70);
      expect(keeper.attack, striker.defence);
      expect(keeper.defence, striker.attack);
    });

    test('the headline floats up to PEAK_LIFT above the rating', () {
      final split = getCardAtkDefSplit(1.0, 100);
      expect(split.attack, (100 * (1 + peakLift)).round().clamp(0, 100));
    });

    test('both stats stay within 0..100', () {
      for (final ratio in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        for (final rating in [0, 1, 50, 100, 200]) {
          final split = getCardAtkDefSplit(ratio, rating);
          expect(split.attack, inInclusiveRange(0, 100));
          expect(split.defence, inInclusiveRange(0, 100));
        }
      }
    });

    test('bonuses are applied directionally', () {
      final base = getCardAtkDefSplit(0.5, 50);
      final boosted = getCardAtkDefSplit(0.5, 50, atkBonus: 5, defBonus: 3);
      expect(boosted.attack, base.attack + 5);
      expect(boosted.defence, base.defence + 3);
    });

    test('a null ratio is treated as balanced', () {
      final split = getCardAtkDefSplit(null, 60);
      expect(split.attack, 60);
      expect(split.defence, 60);
    });

    test('a negative rating floors at zero', () {
      final split = getCardAtkDefSplit(0.8, -10);
      expect(split.attack, 0);
      expect(split.defence, 0);
    });
  });

  group('scout odds', () {
    test('every division has an odds table', () {
      expect(divisionScoutOdds.keys.toSet(), {
        'sunday_league',
        'amateur_cup',
        'regional_league',
        'national_league',
        'elite_league',
        'continental',
        'champions_cup',
      });
    });

    test('each table sums to 100', () {
      divisionScoutOdds.forEach((div, odds) {
        final total = odds.fold<double>(0, (sum, e) => sum + e.$2);
        expect(total, closeTo(100, 1e-9), reason: div);
      });
    });

    test('each division adds exactly one scoutable tier', () {
      // scoutVoucherEngine depends on this 1:1 mapping — it is what stops the
      // voucher ladder growing two rungs on one promotion.
      const ladder = [
        'sunday_league',
        'amateur_cup',
        'regional_league',
        'national_league',
        'elite_league',
        'continental',
        'champions_cup',
      ];
      for (var i = 1; i < ladder.length - 1; i++) {
        expect(
          divisionScoutOdds[ladder[i]]!.length,
          divisionScoutOdds[ladder[i - 1]]!.length + 1,
          reason: ladder[i],
        );
      }
    });

    test('T9 is scoutable only in the top division, at 1%', () {
      divisionScoutOdds.forEach((div, odds) {
        final t9 = odds.where((e) => e.$1 == 9);
        if (div == 'champions_cup') {
          expect(t9.single.$2, 1);
        } else {
          expect(t9, isEmpty, reason: div);
        }
      });
    });

    test('bronze weight falls steadily up the ladder', () {
      const ladder = [
        'sunday_league',
        'amateur_cup',
        'regional_league',
        'national_league',
        'elite_league',
        'continental',
        'champions_cup',
      ];
      final t1 = ladder
          .map((d) => divisionScoutOdds[d]!.firstWhere((e) => e.$1 == 1).$2)
          .toList();
      for (var i = 1; i < t1.length; i++) {
        expect(t1[i], lessThan(t1[i - 1]), reason: ladder[i]);
      }
    });
  });

  group('buildScoutPool', () {
    test('expands each tier weight across that tier’s definitions', () {
      final pool = buildScoutPool('sunday_league');
      // T1 has 4 positions, T2 has 4.
      expect(pool.length, 8);
      expect(
        pool.where((e) => e.item.startsWith('player_t1_')).every((e) => e.weight == 85),
        isTrue,
      );
    });

    test('falls back to sunday_league for an unknown division', () {
      expect(
        buildScoutPool('nope').map((e) => e.item),
        buildScoutPool('sunday_league').map((e) => e.item),
      );
    });

    test('the champions pool can draw the unique T9', () {
      expect(
        buildScoutPool('champions_cup').any((e) => e.item == 'player_t9_fwd'),
        isTrue,
      );
    });

    test('every pooled id resolves to a real definition', () {
      for (final div in divisionScoutOdds.keys) {
        for (final entry in buildScoutPool(div)) {
          expect(getPlayerDef(entry.item), isNotNull, reason: '$div ${entry.item}');
        }
      }
    });
  });

  group('named pools', () {
    test('bronze pool is every T1 card at equal weight', () {
      expect(bronzePool.length, 4);
      expect(bronzePool.every((e) => e.weight == 10), isTrue);
      expect(
        bronzePool.every((e) => getPlayerDef(e.item)!.tier == 1),
        isTrue,
      );
    });

    test('silver pool is every T3 card at equal weight', () {
      expect(silverPool.length, 4);
      expect(silverPool.every((e) => e.weight == 10), isTrue);
      expect(
        silverPool.every((e) => getPlayerDef(e.item)!.tier == 3),
        isTrue,
      );
    });
  });

  group('ratio ranges', () {
    test('cover all four positions and do not overlap across roles', () {
      expect(ratioRange.keys.toSet(), {'GK', 'DEF', 'MID', 'FWD'});
      expect(ratioRange['GK']!.$2, lessThanOrEqualTo(ratioRange['DEF']!.$1));
      expect(ratioRange['DEF']!.$2, lessThanOrEqualTo(ratioRange['MID']!.$1));
      expect(ratioRange['MID']!.$2, lessThanOrEqualTo(ratioRange['FWD']!.$1));
    });

    test('every range is low-to-high inside 0..1', () {
      ratioRange.forEach((pos, range) {
        expect(range.$1, lessThan(range.$2), reason: pos);
        expect(range.$1, greaterThanOrEqualTo(0), reason: pos);
        expect(range.$2, lessThanOrEqualTo(1), reason: pos);
      });
    });
  });

  group('generateDefinitionRatios', () {
    test('produces one ratio per definition, inside that position’s range', () {
      final ratios = generateDefinitionRatios();
      expect(ratios.length, players.length);
      for (final p in players) {
        final range = ratioRange[p.position]!;
        expect(ratios[p.id], isNotNull, reason: p.id);
        expect(ratios[p.id], greaterThanOrEqualTo(range.$1), reason: p.id);
        expect(ratios[p.id], lessThanOrEqualTo(range.$2), reason: p.id);
      }
    });

    test('rounds to two decimals', () {
      final ratios = generateDefinitionRatios();
      for (final value in ratios.values) {
        expect((value * 100 - (value * 100).round()).abs(), lessThan(1e-9));
      }
    });

    test('is seedable for deterministic tests', () {
      expect(generateDefinitionRatios(seed: 7), generateDefinitionRatios(seed: 7));
    });

    test('does not disturb the shared gameplay PRNG stream', () {
      // It uses its own generator on purpose: consuming the seeded stream here
      // would shift every subsequent gameplay draw and break JS parity.
      setSeed(12345);
      final before = random();

      setSeed(12345);
      generateDefinitionRatios();
      final after = random();

      expect(after, before);
    });
  });
}
