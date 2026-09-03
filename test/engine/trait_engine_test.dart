import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/traits.dart';
import 'package:merge_empire_fc/engine/trait_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

CardInstance _card(
  String id, {
  String? traitId,
  int level = 1,
  bool injured = false,
  String definitionId = 'player_t5_fwd',
}) => CardInstance({
  'instanceId': id,
  'definitionId': definitionId,
  if (injured) 'injured': true,
  if (traitId != null) 'trait': {'id': traitId, 'level': level},
});

List<Map<String, dynamic>> _lineup(List<String?> ids) => [
  for (var i = 0; i < 11; i++)
    {
      'slotId': 's$i',
      'slotPosition': 'MID',
      'cardInstanceId': ids.length > i ? ids[i] : null,
    },
];

void main() {
  setUp(resetTraitRandom);

  group('traitRollCost', () {
    test('scales with tier', () {
      expect(traitRollCost(getPlayerDef('player_t1_fwd')), 50);
      expect(traitRollCost(getPlayerDef('player_t3_mid')), 200);
      expect(traitRollCost(getPlayerDef('player_t5_fwd')), 2000);
      expect(traitRollCost(getPlayerDef('player_t8_gk')), 150000);
      expect(traitRollCost(getPlayerDef('player_t9_fwd')), 400000);
    });

    test('falls back to the base cost for an unknown def', () {
      expect(traitRollCost(null), traitRollBaseCost);
    });

    test('never falls as tier rises', () {
      num prev = 0;
      for (var tier = 1; tier <= 9; tier++) {
        final def = players.firstWhere((p) => p.tier == tier);
        final cost = traitRollCost(def);
        expect(cost, greaterThanOrEqualTo(prev), reason: 'tier $tier');
        prev = cost;
      }
    });
  });

  group('rollTrait', () {
    test('always returns a trait from the position pool', () {
      setTraitRandom(math.Random(7));
      final allowed = getTraitPoolForPosition('FWD').map((t) => t.id).toSet();
      for (var i = 0; i < 200; i++) {
        expect(allowed, contains(rollTrait('FWD').id));
      }
    });

    test('never rolls a stamina trait outside Pro mode', () {
      setTraitRandom(math.Random(3));
      for (var i = 0; i < 300; i++) {
        expect(rollTrait('MID').id, isNot('iron_lungs'));
      }
    });

    test('can roll a stamina trait in Pro mode', () {
      setTraitRandom(math.Random(3));
      var seen = false;
      for (var i = 0; i < 500 && !seen; i++) {
        if (rollTrait('MID', hardMode: true).id == 'iron_lungs') seen = true;
      }
      expect(seen, isTrue);
    });

    test('always returns a level between 1 and 3', () {
      setTraitRandom(math.Random(11));
      for (var i = 0; i < 300; i++) {
        expect(rollTrait('DEF').level, inInclusiveRange(1, 3));
      }
    });

    test('level I is by far the commonest and III is rare', () {
      // Authored weights: 70 / 26.2 / 3.8.
      setTraitRandom(math.Random(99));
      final counts = <int, int>{1: 0, 2: 0, 3: 0};
      for (var i = 0; i < 5000; i++) {
        final level = rollTrait('GK').level;
        counts[level] = counts[level]! + 1;
      }
      final total = counts.values.reduce((a, b) => a + b);
      expect(counts[1]! / total, closeTo(0.70, 0.05));
      expect(counts[3]! / total, closeTo(0.038, 0.02));
    });

    test('is deterministic for a given seed', () {
      setTraitRandom(math.Random(42));
      final first = List.generate(10, (_) => rollTrait('FWD'));
      setTraitRandom(math.Random(42));
      final second = List.generate(10, (_) => rollTrait('FWD'));
      expect(first, second);
    });

    test('a null position draws from the whole usable list', () {
      setTraitRandom(math.Random(5));
      final allowed = getTraitPoolForPosition(null).map((t) => t.id).toSet();
      for (var i = 0; i < 100; i++) {
        expect(allowed, contains(rollTrait(null).id));
      }
    });
  });

  group('getTraitBonus', () {
    test('a card with no trait gets nothing', () {
      final b = getTraitBonus(_card('a'), 'FWD');
      expect(b.atkBonus, 0);
      expect(b.staminaMult, 1);
    });

    test('an unknown trait id gets nothing', () {
      expect(getTraitBonus(_card('a', traitId: 'nonesuch'), 'FWD').atkBonus, 0);
    });

    test('an out-of-range level gets nothing', () {
      expect(
        getTraitBonus(
          _card('a', traitId: 'finisher', level: 9),
          'FWD',
        ).atkBonus,
        0,
      );
    });

    test('directional bonuses arrive pre-scaled', () {
      // Finisher III authors +13; what a card receives is 13 * traitStatScale.
      final b = getTraitBonus(_card('a', traitId: 'finisher', level: 3), 'FWD');
      expect(b.atkBonus, closeTo(13 * traitStatScale, 1e-9));
    });

    test('directional bonuses are left fractional, not rounded', () {
      // The ATK/DEF split rounds once at the end, so rounding here would lose
      // a point to double rounding.
      final b = getTraitBonus(_card('a', traitId: 'finisher', level: 3), 'FWD');
      expect(b.atkBonus, isNot(b.atkBonus.roundToDouble()));
    });

    test('a position-locked trait gives no directional bonus off-position', () {
      final b = getTraitBonus(_card('a', traitId: 'finisher', level: 3), 'DEF');
      expect(b.atkBonus, 0);
      expect(b.defBonus, 0);
    });

    test('economy and injury axes apply regardless of position', () {
      // Poacher is FWD-locked but its matchday cut is squad-wide.
      final b = getTraitBonus(_card('a', traitId: 'poacher', level: 3), 'GK');
      expect(b.atkBonus, 0);
      expect(b.matchRevBonus, 0.10);
    });

    test('aging, recovery and injury axes are unscaled', () {
      final b = getTraitBonus(_card('a', traitId: 'veteran', level: 3), 'MID');
      expect(b.agingReduction, 6);
      expect(b.recoveryBonus, 0.25);
    });

    test('a universal trait applies to every position', () {
      for (final pos in ['FWD', 'MID', 'DEF', 'GK']) {
        final b = getTraitBonus(
          _card('a', traitId: 'allrounder', level: 2),
          pos,
        );
        expect(b.atkBonus, closeTo(6 * traitStatScale, 1e-9), reason: pos);
      }
    });

    test('stamina is never position-gated', () {
      final b = getTraitBonus(
        _card('a', traitId: 'iron_lungs', level: 3),
        'GK',
      );
      expect(b.staminaMult, 0.60);
    });

    test('a trait with no stamina effect reports a neutral multiplier', () {
      expect(
        getTraitBonus(_card('a', traitId: 'finisher'), 'FWD').staminaMult,
        1,
      );
    });
  });

  group('hasTrait', () {
    test('true for a real trait', () {
      expect(hasTrait(_card('a', traitId: 'finisher')), isTrue);
    });

    test('false for none — that is the empty slot, not a trait', () {
      expect(hasTrait(_card('a', traitId: 'none')), isFalse);
    });

    test('false for no trait at all', () {
      expect(hasTrait(_card('a')), isFalse);
      expect(hasTrait(null), isFalse);
    });
  });

  group('traitCoverage', () {
    test('measures the fielded eleven, not the whole grid', () {
      // The nudge used to count the bench and kept telling managers with a
      // fully-kitted XI to roll more traits.
      final grid = <CardInstance?>[
        for (var i = 0; i < 11; i++) _card('x$i', traitId: 'allrounder'),
        for (var i = 0; i < 8; i++) _card('bench$i'),
      ];
      final lineup = _lineup([for (var i = 0; i < 11; i++) 'x$i']);

      final cov = traitCoverage(grid, lineup);
      expect(cov.counted, 11);
      expect(cov.withTrait, 11);
      expect(cov.ratio, 1.0);
    });

    test('falls back to the healthy top of the grid with no lineup', () {
      final grid = <CardInstance?>[
        _card('a', traitId: 'allrounder'),
        _card('b'),
        _card('c', injured: true, traitId: 'allrounder'),
      ];
      final cov = traitCoverage(grid);
      expect(cov.counted, 2);
      expect(cov.withTrait, 1);
      expect(cov.ratio, 0.5);
    });

    test('an empty grid reports a zero ratio rather than dividing by zero', () {
      final cov = traitCoverage([]);
      expect(cov.counted, 0);
      expect(cov.ratio, 0);
    });

    test('caps at eleven even with a big grid', () {
      final grid = <CardInstance?>[for (var i = 0; i < 30; i++) _card('x$i')];
      expect(traitCoverage(grid).counted, 11);
    });
  });

  group('computeSquadTraitTotals', () {
    test('sums matchday bonuses across the fielded XI', () {
      final grid = <CardInstance?>[
        for (var i = 0; i < 3; i++) _card('x$i', traitId: 'poacher', level: 3),
      ];
      final totals = computeSquadTraitTotals(grid);
      expect(totals.matchRevBonus, closeTo(0.30, 1e-9));
    });

    test('a benched trait sells no tickets', () {
      // Only the starting XI counts.
      final grid = <CardInstance?>[
        _card('starter'),
        _card('benched', traitId: 'commanding', level: 3),
      ];
      final lineup = _lineup(['starter']);
      expect(computeSquadTraitTotals(grid, lineup).matchRevBonus, 0);
    });

    test('an injured starter contributes nothing', () {
      final grid = <CardInstance?>[
        _card('hurt', injured: true, traitId: 'commanding', level: 3),
      ];
      final lineup = _lineup(['hurt']);
      expect(computeSquadTraitTotals(grid, lineup).matchRevBonus, 0);
    });

    test('a position-locked trait still resolves squad-wide', () {
      // Commanding is GK-locked; its matchday cut must not be zeroed just
      // because the aggregator has no slot position to hand.
      final grid = <CardInstance?>[
        _card('gk', traitId: 'commanding', level: 3),
      ];
      expect(computeSquadTraitTotals(grid).matchRevBonus, 0.20);
    });

    test('match revenue is capped', () {
      final grid = <CardInstance?>[
        for (var i = 0; i < 11; i++)
          _card('x$i', traitId: 'commanding', level: 3),
      ];
      expect(
        computeSquadTraitTotals(grid).matchRevBonus,
        maxSquadMatchRevBonus,
      );
    });

    test('team injury reduction is capped', () {
      final grid = <CardInstance?>[
        for (var i = 0; i < 11; i++) _card('x$i', traitId: 'sweeper', level: 3),
      ];
      expect(
        computeSquadTraitTotals(grid).teamInjuryReduction,
        maxSquadInjuryReduction,
      );
    });

    test('an empty grid totals zero', () {
      final totals = computeSquadTraitTotals([]);
      expect(totals.matchRevBonus, 0);
      expect(totals.teamInjuryReduction, 0);
    });
  });

  group('labels', () {
    test('the label leads with the icon', () {
      expect(traitLabel({'id': 'finisher', 'level': 3}), '⚽ Finisher III');
    });

    test('none has no level label', () {
      expect(traitLabel({'id': 'none', 'level': 1}), '✕ None');
    });

    test('an unknown trait or null yields an empty label', () {
      expect(traitLabel(null), '');
      expect(traitLabel({'id': 'nope', 'level': 1}), '');
    });
  });

  group('applyTrait', () {
    test('assigns a trait and reports no overwrite the first time', () {
      final card = _card('a');
      expect(applyTrait(card, (id: 'finisher', level: 2)), isFalse);
      expect(card.raw['trait'], {'id': 'finisher', 'level': 2});
    });

    test('reports an overwrite when one was already there', () {
      final card = _card('a', traitId: 'anchor');
      expect(applyTrait(card, (id: 'finisher', level: 1)), isTrue);
    });

    test('none normalises to level 1', () {
      final card = _card('a');
      applyTrait(card, (id: 'none', level: 3));
      expect(card.raw['trait'], {'id': 'none', 'level': 1});
    });

    test('the assignment reads back through getTraitBonus', () {
      final card = _card('a');
      applyTrait(card, (id: 'finisher', level: 3));
      expect(
        getTraitBonus(card, 'FWD').atkBonus,
        closeTo(13 * traitStatScale, 1e-9),
      );
    });
  });

  group('a paid roll', () {
    /// A save holding one card, with money.
    Map<String, dynamic> stateWith({
      num coins = 100000,
      String? traitId,
      bool loanedOut = false,
      int? loanMatchesLeft,
    }) => {
      'resources': <String, dynamic>{'fanCoins': coins},
      'settings': <String, dynamic>{'hardMode': false},
      'grid': <String, dynamic>{
        'cells': <dynamic>[
          <String, dynamic>{
            'instanceId': 'a',
            'definitionId': 'player_t5_fwd',
            if (traitId != null) 'trait': {'id': traitId, 'level': 1},
            if (loanedOut) 'loanedOut': {'toTeam': 'Elsewhere'},
            'loanMatchesLeft': ?loanMatchesLeft,
          },
        ],
      },
    };

    num coinsOf(Map<String, dynamic> s) =>
        (s['resources'] as Map<String, dynamic>)['fanCoins'] as num;

    test('charges the tier price and lands a trait', () {
      final s = stateWith();
      final before = coinsOf(s);
      final result = rollTraitForCard(s, 'a');

      expect(result.ok, isTrue);
      expect(result.roll, isNotNull);
      expect(result.cost, traitRollCost(getPlayerDef('player_t5_fwd')));
      expect(coinsOf(s), before - result.cost);
      final card = ((s['grid'] as Map<String, dynamic>)['cells'] as List).first;
      expect((card as Map<String, dynamic>)['trait'], isNotNull);
    });

    test('and the coins stay whole numbers', () {
      final s = stateWith();
      rollTraitForCard(s, 'a');
      expect(coinsOf(s), isA<int>());
    });

    test('says when it overwrote something', () {
      // A roll is a gamble on a card that may already carry something good.
      final s = stateWith(traitId: 'anchor');
      expect(rollTraitForCard(s, 'a').replaced, isTrue);
      expect(rollTraitForCard(stateWith(), 'a').replaced, isFalse);
    });

    test('a club that cannot pay is refused, and keeps its coins', () {
      final s = stateWith(coins: 1);
      final result = rollTraitForCard(s, 'a');
      expect(result.ok, isFalse);
      expect(result.reason, 'insufficient_coins');
      expect(result.cost, greaterThan(0), reason: 'so the UI can quote it');
      expect(coinsOf(s), 1);
    });

    test('a player out on loan cannot be improved', () {
      // They cannot take the field, so the coins would buy nothing this season.
      final s = stateWith(loanedOut: true);
      final result = rollTraitForCard(s, 'a');
      expect(result.reason, 'unavailable');
      expect(coinsOf(s), 100000);
    });

    test('nor can a loanee we have borrowed', () {
      // The trait would go back with them.
      final s = stateWith(loanMatchesLeft: 3);
      expect(rollTraitForCard(s, 'a').reason, 'unavailable');
    });

    test('a card that has gone is refused rather than crashed on', () {
      expect(rollTraitForCard(stateWith(), 'nobody').reason, 'unknown_card');
    });

    test('it announces the roll, so a screen can react to it', () {
      final s = stateWith();
      final heard = <Object?>[];
      void listener(Object? args) => heard.add(args);
      on('trait:rolled', listener);
      addTearDown(() => off('trait:rolled', listener));

      rollTraitForCard(s, 'a');
      expect(heard, hasLength(1));
      expect((heard.single as Map)['instanceId'], 'a');
    });
  });
}
