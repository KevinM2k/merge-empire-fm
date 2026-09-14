import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/match_traits.dart';
import 'package:merge_empire_fc/engine/match_trait_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

MatchContext _ctx({
  bool isHome = false,
  bool isCup = false,
  bool isDerby = false,
  bool inRelegationZone = false,
  bool oppStronger = false,
  bool tenMen = false,
  int minute = 40,
  Set<String> subbedOnLate = const {},
  Set<String> cautioned = const {},
}) => (
  isHome: isHome,
  isCup: isCup,
  isDerby: isDerby,
  inRelegationZone: inRelegationZone,
  oppStronger: oppStronger,
  tenMen: tenMen,
  minute: minute,
  fullTime: 90,
  subbedOnLate: subbedOnLate,
  cautioned: cautioned,
);

/// A real definition id, so [traitRollCost] can price the roll.
const _def = 'player_t1_fwd';

Map<String, dynamic> _card(String id, {String? trait, int level = 3}) => {
  'instanceId': id,
  'definitionId': _def,
  if (trait != null) 'matchSlot': true,
  if (trait != null) 'matchTrait': {'id': trait, 'level': level},
};

List<CardInstance?> _cells(List<Map<String, dynamic>> raw) => [
  for (final r in raw) CardInstance.from(r),
];

List<Map<String, dynamic>> _lineup(List<String> ids) => [
  for (final id in ids) {'cardInstanceId': id, 'slotPosition': 'MID'},
];

Map<String, dynamic> _state(List<Map<String, dynamic>> cells, {int gems = 3}) =>
    {
      'resources': {'gems': gems, 'fanCoins': 999999},
      'grid': {'cells': cells},
    };

Map<String, dynamic> _cellOf(Map<String, dynamic> s, String id) =>
    ((s['grid'] as Map)['cells'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((c) => c['instanceId'] == id);

void main() {
  setUp(resetBus);
  tearDown(resetBus);

  group('matchTraitMultipliers', () {
    test('A DARK CONDITION PAYS NOTHING', () {
      final cells = _cells([_card('a', trait: 'fortress')]);
      final out = matchTraitMultipliers(
        cells,
        _lineup(['a']),
        _ctx(isHome: false),
      );
      expect(out, isEmpty);
    });

    test('a lit condition pays its level', () {
      final cells = _cells([_card('a', trait: 'fortress', level: 2)]);
      final out = matchTraitMultipliers(
        cells,
        _lineup(['a']),
        _ctx(isHome: true),
      );
      expect(out['a'], closeTo(1.07, 1e-9));
    });

    test('a locked slot pays nothing even with a trait in the map', () {
      final raw = _card('a', trait: 'fortress')..remove('matchSlot');
      final out = matchTraitMultipliers(
        _cells([raw]),
        _lineup(['a']),
        _ctx(isHome: true),
      );
      expect(out, isEmpty);
    });

    // **ONLY THE ELEVEN.** A Cup Fighter sat on the bench does not fight.
    test('a man not in the lineup pays nothing', () {
      final cells = _cells([
        _card('a', trait: 'cup_fighter'),
        _card('b', trait: 'cup_fighter'),
      ]);
      final out = matchTraitMultipliers(cells, _lineup(['a']), _ctx(isCup: true));
      expect(out.keys, ['a']);
    });

    test('an injured man in the lineup pays nothing', () {
      final raw = _card('a', trait: 'cup_fighter')..['injured'] = true;
      final out = matchTraitMultipliers(
        _cells([raw]),
        _lineup(['a']),
        _ctx(isCup: true),
      );
      expect(out, isEmpty);
    });

    test('each kickoff condition maps to its own flag', () {
      double? lit(String trait, MatchContext ctx) => matchTraitMultipliers(
        _cells([_card('a', trait: trait)]),
        _lineup(['a']),
        ctx,
      )['a'];
      expect(lit('away_day', _ctx(isHome: false)), closeTo(1.11, 1e-9));
      expect(lit('away_day', _ctx(isHome: true)), isNull);
      expect(lit('big_game', _ctx(oppStronger: true)), closeTo(1.14, 1e-9));
      expect(lit('big_game', _ctx()), isNull);
      expect(lit('derby_devil', _ctx(isDerby: true)), closeTo(1.28, 1e-9));
      expect(lit('derby_devil', _ctx()), isNull);
      expect(
        lit('relegation_scrapper', _ctx(inRelegationZone: true)),
        closeTo(1.20, 1e-9),
      );
      expect(lit('relegation_scrapper', _ctx()), isNull);
    });

    test('Super Sub pays only the men who came on late', () {
      final cells = _cells([
        _card('a', trait: 'super_sub'),
        _card('b', trait: 'super_sub'),
      ]);
      final out = matchTraitMultipliers(
        cells,
        _lineup(['a', 'b']),
        _ctx(subbedOnLate: {'b'}),
      );
      expect(out.keys, ['b']);
      expect(out['b'], closeTo(1.30, 1e-9));
    });

    test('Fast Starter is lit through minute 20 and dark after', () {
      final cells = _cells([_card('a', trait: 'fast_starter')]);
      expect(
        matchTraitMultipliers(cells, _lineup(['a']), _ctx(minute: 0))['a'],
        closeTo(1.20, 1e-9),
      );
      expect(
        matchTraitMultipliers(cells, _lineup(['a']), _ctx(minute: 20))['a'],
        closeTo(1.20, 1e-9),
      );
      expect(
        matchTraitMultipliers(cells, _lineup(['a']), _ctx(minute: 21)),
        isEmpty,
      );
    });

    test('Last Gasp is lit from 76 to the whistle', () {
      final cells = _cells([_card('a', trait: 'last_gasp')]);
      expect(
        matchTraitMultipliers(cells, _lineup(['a']), _ctx(minute: 75)),
        isEmpty,
      );
      expect(
        matchTraitMultipliers(cells, _lineup(['a']), _ctx(minute: 76))['a'],
        closeTo(1.23, 1e-9),
      );
      expect(
        matchTraitMultipliers(cells, _lineup(['a']), _ctx(minute: 93))['a'],
        closeTo(1.23, 1e-9),
      );
    });

    // **SQUAD-WIDE, AND CAPPED.** Two carriers must not be twice as good.
    test('TEN MAN WALL LIFTS EVERY MAN AND IS CAPPED', () {
      final cells = _cells([
        _card('a', trait: 'ten_man_wall'),
        _card('b', trait: 'ten_man_wall'),
        _card('c'),
      ]);
      final out = matchTraitMultipliers(
        cells,
        _lineup(['a', 'b', 'c']),
        _ctx(tenMen: true),
      );
      expect(out.keys.toSet(), {'a', 'b', 'c'});
      // 0.08 + 0.08 = 0.16, over the 0.12 cap.
      expect(out['c'], closeTo(1.12, 1e-9));
    });

    test('Ten Man Wall pays nothing at eleven men', () {
      final cells = _cells([_card('a', trait: 'ten_man_wall')]);
      expect(
        matchTraitMultipliers(cells, _lineup(['a']), _ctx(tenMen: false)),
        isEmpty,
      );
    });

    test('a Fortress who is also one of the ten keeps both', () {
      final cells = _cells([
        _card('a', trait: 'fortress'),
        _card('b', trait: 'ten_man_wall', level: 1),
      ]);
      final out = matchTraitMultipliers(
        cells,
        _lineup(['a', 'b']),
        _ctx(isHome: true, tenMen: true),
      );
      expect(out['a'], closeTo(1.11 * 1.03, 1e-9));
    });

    // Ice Veins REPLACES the caution penalty, so it only exists for a booked
    // man and its value is the multiplier the booking map should end up with.
    test('ICE VEINS REPLACES THE CAUTION PENALTY, NOT THE RATING', () {
      final cells = _cells([_card('a', trait: 'ice_veins')]);
      expect(matchTraitMultipliers(cells, _lineup(['a']), _ctx()), isEmpty);
      final booked = matchTraitMultipliers(
        cells,
        _lineup(['a']),
        _ctx(cautioned: {'a'}),
      );
      expect(booked['a'], closeTo(1.00, 1e-9));
    });

    test('Warrior is not a rating and never appears in the map', () {
      final cells = _cells([_card('a', trait: 'warrior')]);
      expect(
        matchTraitMultipliers(cells, _lineup(['a']), _ctx(isHome: true)),
        isEmpty,
      );
    });

    test('an unknown trait id or level is ignored', () {
      final raw = _card('a')..['matchSlot'] = true;
      raw['matchTrait'] = {'id': 'nope', 'level': 1};
      final bad = _card('b')..['matchSlot'] = true;
      bad['matchTrait'] = {'id': 'fortress', 'level': 9};
      final out = matchTraitMultipliers(
        _cells([raw, bad]),
        _lineup(['a', 'b']),
        _ctx(isHome: true),
      );
      expect(out, isEmpty);
    });
  });

  group('isMatchTraitLit', () {
    test('answers the same question for one man', () {
      final cells = _cells([_card('a', trait: 'fortress')]);
      expect(isMatchTraitLit(cells, _lineup(['a']), _ctx(isHome: true), 'a'),
          isTrue);
      expect(isMatchTraitLit(cells, _lineup(['a']), _ctx(isHome: false), 'a'),
          isFalse);
    });
  });

  group('warriorShrugChance', () {
    test('is zero without the trait and its level with it', () {
      expect(warriorShrugChance(CardInstance.from(_card('a'))), 0);
      expect(
        warriorShrugChance(
          CardInstance.from(_card('a', trait: 'warrior', level: 2)),
        ),
        closeTo(0.45, 1e-9),
      );
      expect(warriorShrugChance(null), 0);
    });

    test('is zero for a locked slot', () {
      final raw = _card('a', trait: 'warrior')..remove('matchSlot');
      expect(warriorShrugChance(CardInstance.from(raw)), 0);
    });
  });

  group('unlockMatchSlot', () {
    test('DEBITS EXACTLY ONE GEM AND OPENS THE SLOT', () {
      final s = _state([_card('a')]);
      final r = unlockMatchSlot(s, 'a');
      expect(r.ok, isTrue);
      expect(r.reason, isNull);
      expect((s['resources'] as Map)['gems'], 2);
      expect(_cellOf(s, 'a')['matchSlot'], isTrue);
      expect(hasMatchSlot(CardInstance.from(_cellOf(s, 'a'))), isTrue);
    });

    test('refuses without the gem, and takes nothing', () {
      final s = _state([_card('a')], gems: 0);
      expect(unlockMatchSlot(s, 'a').reason, 'insufficient_gems');
      expect(_cellOf(s, 'a')['matchSlot'], isNull);
    });

    test('refuses a second unlock rather than charging twice', () {
      final s = _state([_card('a')]);
      unlockMatchSlot(s, 'a');
      expect(unlockMatchSlot(s, 'a').reason, 'already_unlocked');
      expect((s['resources'] as Map)['gems'], 2);
    });

    test('refuses an unknown card', () {
      expect(unlockMatchSlot(_state([_card('a')]), 'nope').reason,
          'unknown_card');
      expect(unlockMatchSlot(_state([_card('a')]), null).reason,
          'unknown_card');
    });

    // A loanee is not ours to improve — the same rule the first slot applies.
    test('refuses a card that is not ours', () {
      final s = _state([_card('a')..['loanMatchesLeft'] = 3]);
      expect(unlockMatchSlot(s, 'a').reason, 'unavailable');
      expect((s['resources'] as Map)['gems'], 3);
    });

    test('announces the unlock', () {
      Object? got;
      on('match_trait:unlocked', (a) => got = a);
      unlockMatchSlot(_state([_card('a')]), 'a');
      expect(got, {'instanceId': 'a'});
    });
  });

  group('rollMatchTrait', () {
    test('draws from the whole pool at a real level', () {
      setMatchTraitRandom(math.Random(42));
      addTearDown(resetMatchTraitRandom);
      final seen = <String>{};
      for (var i = 0; i < 300; i++) {
        final r = rollMatchTrait();
        expect(matchTraits.containsKey(r.id), isTrue);
        expect(r.level, inInclusiveRange(1, 3));
        seen.add(r.id);
      }
      // No position gating, so every trait is reachable from any card.
      expect(seen, matchTraits.keys.toSet());
    });
  });

  group('rollMatchTraitForCard', () {
    test('REFUSES A LOCKED SLOT AND CHARGES NOTHING', () {
      final s = _state([_card('a')]);
      final r = rollMatchTraitForCard(s, 'a');
      expect(r.ok, isFalse);
      expect(r.reason, 'locked');
      expect((s['resources'] as Map)['fanCoins'], 999999);
    });

    test('rolls into an unlocked slot and debits coins', () {
      setMatchTraitRandom(math.Random(1));
      addTearDown(resetMatchTraitRandom);
      final s = _state([_card('a')..['matchSlot'] = true]);
      final r = rollMatchTraitForCard(s, 'a');
      expect(r.ok, isTrue);
      expect(matchTraits.containsKey(r.roll!.id), isTrue);
      expect(r.replaced, isFalse);
      expect(r.cost, greaterThan(0));
      expect((s['resources'] as Map)['fanCoins'], 999999 - r.cost);
      final written = _cellOf(s, 'a')['matchTrait'] as Map;
      expect(written['id'], r.roll!.id);
      expect(written['level'], r.roll!.level);
    });

    test('a second roll reports that it replaced the first', () {
      setMatchTraitRandom(math.Random(1));
      addTearDown(resetMatchTraitRandom);
      final s = _state([_card('a')..['matchSlot'] = true]);
      rollMatchTraitForCard(s, 'a');
      expect(rollMatchTraitForCard(s, 'a').replaced, isTrue);
    });

    test('refuses without the coins and writes nothing', () {
      final s = _state([_card('a')..['matchSlot'] = true]);
      (s['resources'] as Map)['fanCoins'] = 0;
      final r = rollMatchTraitForCard(s, 'a');
      expect(r.reason, 'insufficient_coins');
      expect(r.cost, greaterThan(0));
      expect(_cellOf(s, 'a')['matchTrait'], isNull);
    });

    test('announces the roll and the new coin balance', () {
      setMatchTraitRandom(math.Random(1));
      addTearDown(resetMatchTraitRandom);
      Object? rolled;
      Object? coins;
      on('match_trait:rolled', (a) => rolled = a);
      on('coins:updated', (a) => coins = a);
      final s = _state([_card('a')..['matchSlot'] = true]);
      final r = rollMatchTraitForCard(s, 'a');
      expect(rolled, {
        'instanceId': 'a',
        'id': r.roll!.id,
        'level': r.roll!.level,
        'replaced': false,
      });
      expect(coins, 999999 - r.cost);
    });
  });
}
