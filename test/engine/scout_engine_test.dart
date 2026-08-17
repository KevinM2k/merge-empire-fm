import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/merge_engine.dart';
import 'package:merge_empire_fc/engine/scout_engine.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;

Map<String, dynamic> _card(String id, String defId) => {
  'instanceId': id,
  'definitionId': defId,
  'seasonsPlayed': 0,
};

/// The first definition at a position and tier.
String _defId(String position, int tier) => players
    .firstWhere((p) => p.position == position && p.tier == tier)
    .id;

Map<String, dynamic> _state({
  String division = 'regional_league',
  List<dynamic>? cells,
  Map<String, dynamic>? clubAssets,
  List<dynamic>? discovered,
}) => {
  'progression': <String, dynamic>{
    'currentDivision': division,
    'discoveredPlayers': discovered ?? <dynamic>[],
  },
  'grid': <String, dynamic>{'cells': cells ?? <dynamic>[]},
  'clubAssets': clubAssets ?? defaultClubAssets(),
};

/// A squad that already meets every position target, so nothing is biased.
List<dynamic> _balancedSquad() => [
  for (var i = 0; i < 1; i++) _card('gk$i', _defId('GK', 2)),
  for (var i = 0; i < 4; i++) _card('def$i', _defId('DEF', 2)),
  for (var i = 0; i < 5; i++) _card('mid$i', _defId('MID', 2)),
  for (var i = 0; i < 2; i++) _card('fwd$i', _defId('FWD', 2)),
];

void main() {
  setUp(() => seeded.setSeed(1234));

  group('the position targets', () {
    test('add up to a first XI', () {
      expect(posTargets.values.reduce((a, b) => a + b), 12);
      expect(posTargets['GK'], 1);
    });
  });

  group('countPositions', () {
    test('counts what is in the grid', () {
      final counts = countPositions([
        _card('a', _defId('GK', 1)),
        _card('b', _defId('DEF', 1)),
        _card('c', _defId('DEF', 2)),
        null,
      ]);
      expect(counts, {'GK': 1, 'DEF': 2, 'MID': 0, 'FWD': 0});
    });

    test('ignores an unknown definition', () {
      final counts = countPositions([
        <String, dynamic>{'instanceId': 'x', 'definitionId': 'club_asset_x'},
      ]);
      expect(counts.values.every((n) => n == 0), isTrue);
    });

    test('an empty or missing grid is all zeroes', () {
      expect(countPositions(null).values.every((n) => n == 0), isTrue);
      expect(countPositions(const []).values.every((n) => n == 0), isTrue);
    });
  });

  group('buildScoutDrawPool', () {
    test('draws from the division pool', () {
      final pool = buildScoutDrawPool(_state(cells: _balancedSquad()));
      expect(pool, isNotEmpty);
      final tiers = pool.map((e) => getDefinition(e.item)!.tier).toSet();
      expect(tiers, isNotEmpty);
    });

    test('a higher division reaches higher tiers', () {
      int best(String division) => buildScoutDrawPool(
        _state(division: division, cells: _balancedSquad()),
      ).map((e) => getDefinition(e.item)!.tier).reduce((a, b) => a > b ? a : b);

      expect(best('champions_cup'), greaterThan(best('sunday_league')));
    });

    test('biases toward the positions the squad is short on', () {
      // One keeper and nothing else — the draw should be the positions under
      // target, and GK is already met.
      final pool = buildScoutDrawPool(
        _state(cells: [_card('gk', _defId('GK', 1))]),
      );
      final positions = pool.map((e) => getDefinition(e.item)!.position).toSet();
      expect(positions, isNot(contains('GK')));
      expect(positions, isNotEmpty);
    });

    test('and drops the bias rather than the pool', () {
      // A squad short only on a position the division cannot produce must still
      // have something to draw from.
      final pool = buildScoutDrawPool(_state(cells: _balancedSquad()));
      expect(pool, isNotEmpty);
    });

    test('a voucher floor never draws below itself', () {
      final pool = buildScoutDrawPool(
        _state(division: 'champions_cup', cells: _balancedSquad()),
        minTier: 5,
      );
      expect(pool, isNotEmpty);
      for (final e in pool) {
        expect(getDefinition(e.item)!.tier, greaterThanOrEqualTo(5));
      }
    });

    test('and never reaches the chase card', () {
      // Tier 9 is the one uncraftable, globally unique card; a tier-8 floor
      // would otherwise have made a voucher the cheapest route to it.
      for (var floor = 2; floor <= 8; floor++) {
        final pool = buildScoutDrawPool(
          _state(division: 'champions_cup', cells: _balancedSquad()),
          minTier: floor,
        );
        for (final e in pool) {
          expect(getDefinition(e.item)!.tier, isNot(9), reason: 'floor $floor');
        }
      }
    });

    test('a floor the division cannot reach empties the pool', () {
      final pool = buildScoutDrawPool(
        _state(division: 'sunday_league', cells: _balancedSquad()),
        minTier: 8,
      );
      expect(pool, isEmpty);
    });

    test('the floor is applied FIRST and never traded away by the bias', () {
      // Every filter below it may only narrow what is left.
      final pool = buildScoutDrawPool(
        _state(division: 'champions_cup', cells: [_card('gk', _defId('GK', 1))]),
        minTier: 6,
      );
      for (final e in pool) {
        expect(getDefinition(e.item)!.tier, greaterThanOrEqualTo(6));
      }
    });

    test('owning the chase card takes it out of the pool', () {
      final t9 = players.firstWhere((p) => p.tier == 9);
      final with9 = buildScoutDrawPool(
        _state(
          division: 'champions_cup',
          cells: [..._balancedSquad(), _card('icon', t9.id)],
        ),
      );
      expect(with9.map((e) => getDefinition(e.item)!.tier), isNot(contains(9)));

      final without = buildScoutDrawPool(
        _state(division: 'champions_cup', cells: _balancedSquad()),
      );
      expect(without.map((e) => getDefinition(e.item)!.tier), contains(9));
    });
  });

  group('pickScoutDefinition', () {
    test('returns a definition the pool holds', () {
      final state = _state(cells: _balancedSquad());
      final pool = buildScoutDrawPool(state).map((e) => e.item).toSet();
      final picked = pickScoutDefinition(state);
      expect(pool, contains(picked));
    });

    test('an empty pool picks nothing rather than throwing', () {
      expect(
        pickScoutDefinition(_state(division: 'sunday_league'), minTier: 9),
        isNull,
      );
    });

    test('honours the voucher floor', () {
      for (var i = 0; i < 40; i++) {
        final picked = pickScoutDefinition(
          _state(division: 'champions_cup', cells: _balancedSquad()),
          minTier: 4,
        );
        expect(getDefinition(picked)!.tier, greaterThanOrEqualTo(4));
      }
    });

    test('is deterministic for a given seed', () {
      seeded.setSeed(9);
      final a = [
        for (var i = 0; i < 10; i++)
          pickScoutDefinition(_state(cells: _balancedSquad())),
      ];
      seeded.setSeed(9);
      final b = [
        for (var i = 0; i < 10; i++)
          pickScoutDefinition(_state(cells: _balancedSquad())),
      ];
      expect(a, b);
    });
  });

  group('reachablePlayerDefIds', () {
    test('a division reaches only a slice of the index', () {
      // Counting the whole book is what let "discover 4 new players" land on a
      // save that had already met every face it could reach.
      final sunday = reachablePlayerDefIds(_state(division: 'sunday_league'));
      final champions = reachablePlayerDefIds(_state(division: 'champions_cup'));
      expect(sunday.length, lessThan(champions.length));
      expect(champions, containsAll(sunday));
    });

    test('everything merging can build is reachable', () {
      for (final div in divisions) {
        final ids = reachablePlayerDefIds(_state(division: div.id));
        for (final p in players.where((p) => p.tier <= div.maxPlayerTier)) {
          expect(ids, contains(p.id), reason: '${div.id} ${p.id}');
        }
      }
    });

    test('an unlocked coin sink widens it', () {
      // The Youth Academy draws ABOVE the merge cap, so leaving it out would
      // withhold a quest that is winnable.
      final locked = reachablePlayerDefIds(_state(division: 'sunday_league'));
      final unlocked = reachablePlayerDefIds(_state(division: 'amateur_cup'));
      expect(unlocked.length, greaterThan(locked.length));
    });

    test('every id is a real definition', () {
      for (final div in divisions) {
        for (final id in reachablePlayerDefIds(_state(division: div.id))) {
          expect(getDefinition(id), isNotNull, reason: '${div.id} $id');
        }
      }
    });

    test('a bare save still answers', () {
      expect(reachablePlayerDefIds(<String, dynamic>{}), isNotEmpty);
      expect(reachablePlayerDefIds(null), isNotEmpty);
    });

    test('an unknown division falls back to the bottom of the ladder', () {
      expect(
        reachablePlayerDefIds(_state(division: 'retired_league')),
        isNotEmpty,
      );
    });
  });
}
