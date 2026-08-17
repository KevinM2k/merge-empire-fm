import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/engine/lineup_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';

CardInstance _card(
  String id, {
  String definitionId = 'player_t5_mid',
  bool injured = false,
  bool listed = false,
  String? loanedOut,
  num? energy,
}) => CardInstance({
  'instanceId': id,
  'definitionId': definitionId,
  if (injured) 'injured': true,
  if (listed) 'listed': true,
  'loanedOut': ?loanedOut,
  'energy': ?energy,
});

/// A full squad of eleven, one per slot position of 4-3-3.
List<CardInstance?> _squad() {
  const defs = [
    'player_t5_gk',
    'player_t5_def', 'player_t5_def', 'player_t5_def', 'player_t5_def',
    'player_t5_mid', 'player_t5_mid', 'player_t5_mid',
    'player_t5_fwd', 'player_t5_fwd', 'player_t5_fwd',
  ];
  return [
    for (var i = 0; i < defs.length; i++) _card('p$i', definitionId: defs[i]),
  ];
}

void main() {
  group('positionPenalty', () {
    test('a player in his own position loses nothing', () {
      expect(positionPenalty('FWD', 'FWD'), 0);
    });

    test('a keeper anywhere else is the worst case', () {
      expect(positionPenalty('GK', 'FWD'), 0.5);
      expect(positionPenalty('FWD', 'GK'), 0.5);
    });

    test('a forward at the back is nearly as bad', () {
      expect(positionPenalty('FWD', 'DEF'), 0.35);
      expect(positionPenalty('DEF', 'FWD'), 0.35);
    });

    test('anything else is a mild adjustment', () {
      expect(positionPenalty('MID', 'FWD'), 0.2);
      expect(positionPenalty('DEF', 'MID'), 0.2);
    });
  });

  group('buildDefaultLineup', () {
    test('produces one entry per formation slot', () {
      final lineup = buildDefaultLineup('4-3-3', _squad());
      expect(lineup.length, 11);
      expect(
        lineup.map((s) => s.slotId),
        getFormation('4-3-3').slots.map((s) => s.slotId),
      );
    });

    test('puts every player in his own position when the squad fits', () {
      final lineup = buildDefaultLineup('4-3-3', _squad());
      for (final slot in lineup) {
        final id = slot.cardInstanceId;
        expect(id, isNotNull, reason: slot.slotId);
      }
      // The keeper must be in goal.
      final gk = lineup.firstWhere((s) => s.slotPosition == 'GK');
      expect(gk.cardInstanceId, 'p0');
    });

    test('never picks the same player twice', () {
      final lineup = buildDefaultLineup('4-3-3', _squad());
      final ids = lineup.map((s) => s.cardInstanceId).whereType<String>().toList();
      expect(ids.toSet().length, ids.length);
    });

    test('leaves slots empty when the squad is short', () {
      final lineup = buildDefaultLineup('4-3-3', [_card('a'), _card('b')]);
      final filled = lineup.where((s) => s.cardInstanceId != null);
      expect(filled.length, 2);
    });

    test('skips injured players', () {
      final lineup = buildDefaultLineup('4-3-3', [
        _card('fit'),
        _card('hurt', injured: true),
      ]);
      final ids = lineup.map((s) => s.cardInstanceId).whereType<String>();
      expect(ids, ['fit']);
    });

    test('skips listed and loaned-out players', () {
      // They are at another club or advertised for sale — the match engine
      // rates them zero, so auto-picking one leaves a hole in the side.
      final lineup = buildDefaultLineup('4-3-3', [
        _card('ours'),
        _card('sold', listed: true),
        _card('away', loanedOut: 'rival'),
      ]);
      final ids = lineup.map((s) => s.cardInstanceId).whereType<String>();
      expect(ids, ['ours']);
    });

    test('prefers the better player for a slot', () {
      final lineup = buildDefaultLineup('4-3-3', [
        _card('weak', definitionId: 'player_t1_mid'),
        _card('strong', definitionId: 'player_t8_mid'),
      ]);
      final ids = lineup.map((s) => s.cardInstanceId).whereType<String>().toList();
      expect(ids.first, 'strong');
    });

    test('an unknown formation falls back to the default', () {
      final lineup = buildDefaultLineup('9-0-1', _squad());
      expect(
        lineup.map((s) => s.slotId),
        getFormation(defaultFormation).slots.map((s) => s.slotId),
      );
    });

    test('an empty grid yields an empty lineup of the right shape', () {
      final lineup = buildDefaultLineup('4-3-3', []);
      expect(lineup.length, 11);
      expect(lineup.every((s) => s.cardInstanceId == null), isTrue);
    });

    test('ignores unknown definitions', () {
      final lineup = buildDefaultLineup('4-3-3', [
        CardInstance({'instanceId': 'ghost', 'definitionId': 'nope'}),
      ]);
      expect(lineup.every((s) => s.cardInstanceId == null), isTrue);
    });
  });

  group('buildDefaultLineup with fatigue', () {
    test('a fitter player wins a tie on in-slot value', () {
      final lineup = buildDefaultLineup(
        '4-3-3',
        [
          _card('tired', energy: 10),
          _card('fresh'),
        ],
        fatigue: true,
      );
      final ids = lineup.map((s) => s.cardInstanceId).whereType<String>().toList();
      expect(ids.first, 'fresh');
    });

    test('a tired specialist still beats a fresh player out of position', () {
      // Fitness only decides between players of equal in-slot value.
      final lineup = buildDefaultLineup(
        '4-3-3',
        [
          _card('tiredKeeper', definitionId: 'player_t8_gk', energy: 60),
          _card('freshStriker', definitionId: 'player_t8_fwd'),
        ],
        fatigue: true,
      );
      final gk = lineup.firstWhere((s) => s.slotPosition == 'GK');
      expect(gk.cardInstanceId, 'tiredKeeper');
    });

    test('fitness is ignored when fatigue is off', () {
      final lineup = buildDefaultLineup('4-3-3', [
        _card('tired', definitionId: 'player_t8_mid', energy: 1),
        _card('fresh', definitionId: 'player_t1_mid'),
      ]);
      final ids = lineup.map((s) => s.cardInstanceId).whereType<String>().toList();
      expect(ids.first, 'tired');
    });
  });

  group('fillLineupGaps', () {
    List<LineupSlot> emptyLineup() => [
      for (final s in getFormation('4-3-3').slots)
        LineupSlot(slotId: s.slotId, slotPosition: s.slotPosition, cardInstanceId: null),
    ];

    test('fills empty slots', () {
      final filled = fillLineupGaps(emptyLineup(), '4-3-3', [_card('a')]);
      expect(filled.where((s) => s.cardInstanceId != null).length, 1);
    });

    test('leaves placed players undisturbed', () {
      final lineup = emptyLineup();
      final withOne = [
        lineup.first.copyWith(cardInstanceId: 'keeper'),
        ...lineup.skip(1),
      ];
      final filled = fillLineupGaps(withOne, '4-3-3', [
        _card('keeper', definitionId: 'player_t5_gk'),
        _card('other'),
      ]);
      expect(filled.first.cardInstanceId, 'keeper');
    });

    test('never places someone already in the lineup', () {
      final lineup = emptyLineup();
      final withOne = [
        lineup.first.copyWith(cardInstanceId: 'a'),
        ...lineup.skip(1),
      ];
      final filled = fillLineupGaps(withOne, '4-3-3', [_card('a')]);
      final ids = filled.map((s) => s.cardInstanceId).whereType<String>().toList();
      expect(ids, ['a']);
    });

    test('a full lineup is returned untouched', () {
      final full = [
        for (final s in getFormation('4-3-3').slots)
          LineupSlot(slotId: s.slotId, slotPosition: s.slotPosition, cardInstanceId: 'x'),
      ];
      expect(fillLineupGaps(full, '4-3-3', [_card('spare')]), full);
    });

    test('no available players leaves the lineup alone', () {
      final lineup = emptyLineup();
      expect(fillLineupGaps(lineup, '4-3-3', []), lineup);
    });

    test('skips unavailable players', () {
      final filled = fillLineupGaps(emptyLineup(), '4-3-3', [
        _card('away', loanedOut: 'rival'),
      ]);
      expect(filled.every((s) => s.cardInstanceId == null), isTrue);
    });
  });

  group('cleanAndFillLineup', () {
    test('drops a card that has left the grid and refills the slot', () {
      final lineup = [
        for (final s in getFormation('4-3-3').slots)
          LineupSlot(slotId: s.slotId, slotPosition: s.slotPosition, cardInstanceId: 'gone'),
      ];
      final cleaned = cleanAndFillLineup(lineup, '4-3-3', [_card('here')]);
      final ids = cleaned.map((s) => s.cardInstanceId).whereType<String>().toList();
      expect(ids, ['here']);
    });

    test('drops a card still in the grid that can no longer be picked', () {
      // A loaned-out player is at another club; the match engine rates them 0.
      final lineup = [
        for (final s in getFormation('4-3-3').slots)
          LineupSlot(slotId: s.slotId, slotPosition: s.slotPosition, cardInstanceId: null),
      ];
      final withLoanee = [
        lineup.first.copyWith(cardInstanceId: 'away'),
        ...lineup.skip(1),
      ];
      final cleaned = cleanAndFillLineup(withLoanee, '4-3-3', [
        _card('away', loanedOut: 'rival'),
        _card('here'),
      ]);
      final ids = cleaned.map((s) => s.cardInstanceId).whereType<String>().toList();
      expect(ids, ['here']);
    });

    test('keeps an injured player in the grid out of the XI', () {
      final lineup = [
        for (final s in getFormation('4-3-3').slots)
          LineupSlot(slotId: s.slotId, slotPosition: s.slotPosition, cardInstanceId: null),
      ];
      final cleaned = cleanAndFillLineup(lineup, '4-3-3', [
        _card('hurt', injured: true),
      ]);
      expect(cleaned.every((s) => s.cardInstanceId == null), isTrue);
    });
  });

  group('refillLineupFromBench', () {
    Map<String, dynamic> stateWith(List<String?> lineupIds, List<CardInstance?> grid) => {
      'squad': {
        'formation': '4-3-3',
        'lineup': [
          for (var i = 0; i < 11; i++)
            {
              'slotId': getFormation('4-3-3').slots[i].slotId,
              'slotPosition': getFormation('4-3-3').slots[i].slotPosition,
              'cardInstanceId': i < lineupIds.length ? lineupIds[i] : null,
            },
        ],
      },
      'grid': {'cells': [for (final c in grid) c?.raw]},
    };

    test('fills a hole left by an injury that has healed', () {
      // An injury vacates its slot and nothing ever put anyone back: once
      // healed, the player sat on the bench while the XI played a man short.
      final state = stateWith([null], [_card('healed')]);
      expect(refillLineupFromBench(state), isTrue);

      final lineup = (state['squad'] as Map)['lineup'] as List;
      final ids = [for (final s in lineup) (s as Map)['cardInstanceId']]
          .whereType<String>()
          .toList();
      expect(ids, ['healed']);
    });

    test('reports no change when nothing needed filling', () {
      final state = stateWith(List.filled(11, null), []);
      expect(refillLineupFromBench(state), isFalse);
    });

    test('refuses a malformed lineup', () {
      expect(refillLineupFromBench({'squad': {'lineup': null}}), isFalse);
      expect(refillLineupFromBench({'squad': {'lineup': []}}), isFalse);
      expect(refillLineupFromBench({}), isFalse);
    });

    test('only ever fills empty slots — it never benches anyone', () {
      final state = stateWith(['starter'], [_card('starter'), _card('better', definitionId: 'player_t8_mid')]);
      refillLineupFromBench(state);

      final lineup = (state['squad'] as Map)['lineup'] as List;
      expect((lineup.first as Map)['cardInstanceId'], 'starter');
    });
  });
}
