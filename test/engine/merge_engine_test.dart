import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/player_art.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/merge_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/time.dart';

/// A minimal card map — enough for the merge rules, which only read
/// definitionId, variant and the loan markers.
Map<String, dynamic> _card(
  String definitionId, {
  int variant = 0,
  String? instanceId,
  int? loanMatchesLeft,
  String? loanedOut,
}) => {
  'definitionId': definitionId,
  'instanceId': instanceId ?? '$definitionId-$variant',
  'variant': variant,
  'loanMatchesLeft': ?loanMatchesLeft,
  'loanedOut': ?loanedOut,
};

void main() {
  setUp(() {
    resetMergeRandom();
    resetInstanceCounter();
    resetClock();
    resetBus();
  });

  group('createInstance', () {
    test('builds a complete player card', () {
      final card = createInstance('player_t3_mid');
      expect(card.definitionId, 'player_t3_mid');
      expect(card.instanceId, isNotEmpty);
      expect(card.seasonsPlayed, 0);
      expect(card.form, 0);
      expect(card.raw['variant'], inInclusiveRange(0, playerVariants - 1));
      expect(card.raw['stats'], {
        'goals': 0,
        'assists': 0,
        'tackles': 0,
        'saves': 0,
        'matchesPlayed': 0,
      });
    });

    test('rating bonus spreads cards of the same definition', () {
      setMergeRandom(math.Random(1));
      final bonuses = {
        for (var i = 0; i < 60; i++) createInstance('player_t3_mid').ratingBonus,
      };
      expect(bonuses.length, greaterThan(1));
      for (final b in bonuses) {
        expect(b, inInclusiveRange(-2, 2));
      }
    });

    test('T9 gets no rating bonus — it is always exactly 100', () {
      setMergeRandom(math.Random(1));
      for (var i = 0; i < 30; i++) {
        expect(createInstance('player_t9_fwd').ratingBonus, 0);
      }
    });

    test('attack ratio falls inside the position band', () {
      setMergeRandom(math.Random(2));
      for (var i = 0; i < 50; i++) {
        final card = createInstance('player_t3_gk');
        final (lo, hi) = ratioRange['GK']!;
        expect(card.attackRatio, inInclusiveRange(lo, hi));
      }
    });

    test('starts with a full energy bar matching its rating', () {
      final card = createInstance('player_t5_fwd');
      final def = getPlayerDef('player_t5_fwd')!;
      expect(card.energy, getCardRating(def, ratingBonus: card.ratingBonus));
      expect(card.raw['energyUpdatedAt'], isNotNull);
    });

    test('a non-player definition gets no energy fields', () {
      final card = createInstance('some_club_asset_t1');
      expect(card.raw.containsKey('energy'), isFalse);
      expect(card.raw.containsKey('displayName'), isFalse);
    });

    test('display name matches the rolled variant gender', () {
      setMergeRandom(math.Random(3));
      for (var i = 0; i < 40; i++) {
        final card = createInstance('player_t1_fwd');
        final variant = card.raw['variant'] as int;
        final expected = pickDisplayName(
          'FWD',
          0,
          female: isVariantFemale(variant),
        );
        expect(card.displayName, expected);
      }
    });

    test('a preferred gender pins the variant', () {
      setMergeRandom(math.Random(4));
      for (var i = 0; i < 40; i++) {
        final female = createInstance('player_t1_fwd', preferredFemale: true);
        final male = createInstance('player_t1_fwd', preferredFemale: false);
        expect(isVariantFemale(female.raw['variant'] as int), isTrue);
        expect(isVariantFemale(male.raw['variant'] as int), isFalse);
      }
    });

    test('instance ids are unique', () {
      setClock(() => 1000);
      final ids = {for (var i = 0; i < 100; i++) createInstance('player_t1_fwd').instanceId};
      expect(ids.length, 100);
    });
  });

  group('attemptMerge — moves and swaps', () {
    test('moves a card into an empty slot', () {
      final cells = <dynamic>[_card('player_t1_fwd'), null];
      final r = attemptMerge(0, 1, cells);

      expect(r.ok, isTrue);
      expect(r.action, MergeAction.move);
      expect(cells[0], isNull);
      expect(cells[1], isNotNull);
    });

    test('swaps two different cards', () {
      final cells = <dynamic>[_card('player_t1_fwd'), _card('player_t1_mid')];
      final r = attemptMerge(0, 1, cells);

      expect(r.action, MergeAction.swap);
      expect((cells[0] as Map)['definitionId'], 'player_t1_mid');
      expect((cells[1] as Map)['definitionId'], 'player_t1_fwd');
    });

    test('refuses a drag onto itself', () {
      final cells = <dynamic>[_card('player_t1_fwd')];
      final r = attemptMerge(0, 0, cells);
      expect(r.ok, isFalse);
      expect(r.reason, 'same_cell');
    });

    test('refuses a drag from an empty slot', () {
      final cells = <dynamic>[null, _card('player_t1_fwd')];
      final r = attemptMerge(0, 1, cells);
      expect(r.ok, isFalse);
      expect(r.reason, 'empty_source');
    });

    test('swaps rather than merges when genders differ', () {
      // variant 0 is male, variant 2 is female.
      final cells = <dynamic>[
        _card('player_t1_fwd', variant: 0),
        _card('player_t1_fwd', variant: 2),
      ];
      final r = attemptMerge(0, 1, cells);
      expect(r.action, MergeAction.swap);
      expect(cells[0], isNotNull);
      expect(cells[1], isNotNull);
    });

    test('swaps a pair already at the merge ceiling', () {
      final cells = <dynamic>[
        _card('player_t8_fwd', instanceId: 'a'),
        _card('player_t8_fwd', instanceId: 'b'),
      ];
      final r = attemptMerge(0, 1, cells);
      expect(r.action, MergeAction.swap);
      expect((cells[0] as Map)['instanceId'], 'b');
    });

    test('an unknown definition refuses outright', () {
      final cells = <dynamic>[_card('nonsense'), _card('nonsense')];
      final r = attemptMerge(0, 1, cells);
      expect(r.ok, isFalse);
      expect(r.reason, 'unknown_definition');
    });
  });

  group('attemptMerge — loan blocks', () {
    test('a borrowed player swaps rather than merging', () {
      // A loanee is not ours to consume.
      final cells = <dynamic>[
        _card('player_t1_fwd', instanceId: 'a', loanMatchesLeft: 5),
        _card('player_t1_fwd', instanceId: 'b'),
      ];
      final r = attemptMerge(0, 1, cells);

      expect(r.action, MergeAction.swap);
      expect(r.blocked, 'loan');
      expect(cells[0], isNotNull);
      expect(cells[1], isNotNull);
    });

    test('a player lent out swaps rather than merging', () {
      // Consuming them would destroy a card we are contractually due back.
      final cells = <dynamic>[
        _card('player_t1_fwd', instanceId: 'a'),
        _card('player_t1_fwd', instanceId: 'b', loanedOut: 'rival'),
      ];
      final r = attemptMerge(0, 1, cells);

      expect(r.action, MergeAction.swap);
      expect(r.blocked, 'loan_out');
    });

    test('the block names which side caused it', () {
      final borrowed = _card('player_t1_fwd', loanMatchesLeft: 3);
      final lent = _card('player_t1_fwd', loanedOut: 'rival');
      expect(loanBlock(CardInstance(borrowed)), 'loan');
      expect(loanBlock(CardInstance(lent)), 'loan_out');
      expect(loanBlock(CardInstance(_card('player_t1_fwd'))), isNull);
    });
  });

  group('attemptMerge — merging', () {
    test('two matching cards become one of the next tier', () {
      final cells = <dynamic>[
        _card('player_t1_fwd', instanceId: 'a'),
        _card('player_t1_fwd', instanceId: 'b'),
      ];
      final r = attemptMerge(0, 1, cells);

      expect(r.action, MergeAction.merge);
      expect(cells[0], isNull);
      expect((cells[1] as Map)['definitionId'], 'player_t2_fwd');
      expect(r.result!.definitionId, 'player_t2_fwd');
    });

    test('the merged card inherits its parents gender', () {
      setMergeRandom(math.Random(9));
      final cells = <dynamic>[
        _card('player_t1_fwd', variant: 2, instanceId: 'a'),
        _card('player_t1_fwd', variant: 5, instanceId: 'b'),
      ];
      attemptMerge(0, 1, cells);
      expect(isVariantFemale((cells[1] as Map)['variant'] as int), isTrue);
    });

    test('respects the division tier cap', () {
      final cells = <dynamic>[
        _card('player_t2_fwd', instanceId: 'a'),
        _card('player_t2_fwd', instanceId: 'b'),
      ];
      final r = attemptMerge(0, 1, cells, maxTier: 2);

      expect(r.ok, isFalse);
      expect(r.reason, 'division_locked');
      expect(r.requiredTier, 3);
      expect(cells[0], isNotNull);
      expect(cells[1], isNotNull);
    });

    test('allows a merge up to the cap', () {
      final cells = <dynamic>[
        _card('player_t1_fwd', instanceId: 'a'),
        _card('player_t1_fwd', instanceId: 'b'),
      ];
      expect(attemptMerge(0, 1, cells, maxTier: 2).action, MergeAction.merge);
    });

    test('updates the merge and highest-tier stats', () {
      final stats = <String, dynamic>{};
      final cells = <dynamic>[
        _card('player_t1_fwd', instanceId: 'a'),
        _card('player_t1_fwd', instanceId: 'b'),
      ];
      attemptMerge(0, 1, cells, stats: stats);

      expect(stats['totalMerges'], 1);
      expect(stats['highestTier'], 2);
    });

    test('never lowers the highest tier already reached', () {
      final stats = <String, dynamic>{'highestTier': 7};
      final cells = <dynamic>[
        _card('player_t1_fwd', instanceId: 'a'),
        _card('player_t1_fwd', instanceId: 'b'),
      ];
      attemptMerge(0, 1, cells, stats: stats);
      expect(stats['highestTier'], 7);
    });

    test('announces the merge', () {
      Object? seen;
      on('merge:complete', (args) => seen = args);

      final cells = <dynamic>[
        _card('player_t1_fwd', instanceId: 'a'),
        _card('player_t1_fwd', instanceId: 'b'),
      ];
      attemptMerge(0, 1, cells);

      expect(seen, isNotNull);
      expect((seen! as Map)['newDef'], isNotNull);
    });
  });

  group('findFirstEmpty / placeCard', () {
    test('finds the first null slot', () {
      expect(findFirstEmpty(<dynamic>[_card('player_t1_fwd'), null, null]), 1);
    });

    test('returns -1 when full', () {
      expect(findFirstEmpty(<dynamic>[_card('player_t1_fwd')]), -1);
    });

    test('places a card in the first gap', () {
      final cells = <dynamic>[_card('player_t1_fwd'), null];
      final r = placeCard('player_t3_mid', cells);

      expect(r.ok, isTrue);
      expect(r.idx, 1);
      expect((cells[1] as Map)['definitionId'], 'player_t3_mid');
    });

    test('refuses when the grid is full', () {
      final cells = <dynamic>[_card('player_t1_fwd')];
      final r = placeCard('player_t3_mid', cells);
      expect(r.ok, isFalse);
      expect(r.reason, 'grid_full');
    });

    test('announces the placement', () {
      var fired = false;
      on('card:placed', (_) => fired = true);
      placeCard('player_t1_fwd', <dynamic>[null]);
      expect(fired, isTrue);
    });
  });

  group('mergeAll', () {
    test('merges every available pair', () {
      final cells = <dynamic>[
        for (var i = 0; i < 4; i++) _card('player_t1_fwd', instanceId: 'a$i'),
        null,
      ];
      final merges = mergeAll(cells);

      // Four T1s become two T2s, which become one T3.
      expect(merges, 3);
      final remaining = cells.whereType<Map<String, dynamic>>().toList();
      expect(remaining.length, 1);
      expect(remaining.single['definitionId'], 'player_t3_fwd');
    });

    test('leaves an odd card behind', () {
      final cells = <dynamic>[
        for (var i = 0; i < 3; i++) _card('player_t1_fwd', instanceId: 'a$i'),
      ];
      mergeAll(cells);
      final remaining = cells.whereType<Map<String, dynamic>>().toList();
      expect(remaining.length, 2);
    });

    test('respects the tier cap', () {
      final cells = <dynamic>[
        for (var i = 0; i < 4; i++) _card('player_t1_fwd', instanceId: 'a$i'),
      ];
      final merges = mergeAll(cells, maxTier: 2);
      expect(merges, 2);
      expect(
        cells.whereType<Map<String, dynamic>>().every((c) => c['definitionId'] == 'player_t2_fwd'),
        isTrue,
      );
    });

    test('never shuffles loanees around instead of merging', () {
      // attemptMerge would swap them, which is not progress — the pair would
      // be moved about on every Merge All with nothing to show for it.
      final cells = <dynamic>[
        _card('player_t1_fwd', instanceId: 'a', loanMatchesLeft: 3),
        _card('player_t1_fwd', instanceId: 'b', loanMatchesLeft: 3),
      ];
      final before = List<dynamic>.from(cells);
      expect(mergeAll(cells), 0);
      expect(cells, before);
    });

    test('skips mismatched genders without stalling', () {
      final cells = <dynamic>[
        _card('player_t1_fwd', variant: 0, instanceId: 'm'),
        _card('player_t1_fwd', variant: 2, instanceId: 'f'),
      ];
      expect(mergeAll(cells), 0);
      expect(cells.whereType<Map<String, dynamic>>().length, 2);
    });

    test('merges same-gender pairs across different variants', () {
      // Variants 0 and 1 are both male; art differences must not block a merge.
      final cells = <dynamic>[
        _card('player_t1_fwd', variant: 0, instanceId: 'a'),
        _card('player_t1_fwd', variant: 1, instanceId: 'b'),
      ];
      expect(mergeAll(cells), 1);
    });

    test('an empty grid merges nothing', () {
      final cells = <dynamic>[null, null];
      expect(mergeAll(cells), 0);
    });

    test('accumulates stats across the sweep', () {
      final stats = <String, dynamic>{};
      final cells = <dynamic>[
        for (var i = 0; i < 4; i++) _card('player_t1_fwd', instanceId: 'a$i'),
      ];
      mergeAll(cells, stats: stats);
      expect(stats['totalMerges'], 3);
      expect(stats['highestTier'], 3);
    });
  });
}
