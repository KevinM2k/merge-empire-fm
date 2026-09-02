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

    test('breaks a tie by grid order, then slot order', () {
      // Eleven identical players means the pair scores tie in whole blocks, and
      // which of two equal cards takes which slot is then decided purely by the
      // ORDER the pairs were built in — player-major, slot-minor. The JS relies
      // on Array.sort being stable for exactly this; Dart's List.sort is not, so
      // an unstable sort here quietly produces a different XI from the same
      // squad. The assignment below is the JS answer, pinned.
      final lineup = buildDefaultLineup('4-4-2', [
        for (var i = 0; i < 11; i++)
          _card('c$i', definitionId: 'player_t3_mid'),
      ]);
      expect(
        {for (final s in lineup) s.slotId: s.cardInstanceId},
        // The four midfield slots go first — no position penalty — and take the
        // first four cards. The defenders and forwards share the next tier, and
        // the keeper's slot is the worst fit for a midfielder, so it goes last.
        {
          'gk': 'c10',
          'rb': 'c4',
          'rcb': 'c5',
          'lcb': 'c6',
          'lb': 'c7',
          'rm': 'c0',
          'rcm': 'c1',
          'lcm': 'c2',
          'lm': 'c3',
          'rs': 'c8',
          'ls': 'c9',
        },
      );
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

    test('breaks a tie by grid order, then slot order', () {
      // Same stability requirement as buildDefaultLineup, and the same reason:
      // the comparator returns 0 for equal in-slot value, so the pair build
      // order is the only thing deciding between identical players.
      final filled = fillLineupGaps(
        [
          for (final s in getFormation('4-4-2').slots)
            LineupSlot(
              slotId: s.slotId,
              slotPosition: s.slotPosition,
              cardInstanceId: null,
            ),
        ],
        '4-4-2',
        [
          for (var i = 0; i < 11; i++)
            _card('c$i', definitionId: 'player_t3_mid'),
        ],
      );
      expect({for (final s in filled) s.slotId: s.cardInstanceId}, {
        'gk': 'c10',
        'rb': 'c4',
        'rcb': 'c5',
        'lcb': 'c6',
        'lb': 'c7',
        'rm': 'c0',
        'rcm': 'c1',
        'lcm': 'c2',
        'lm': 'c3',
        'rs': 'c8',
        'ls': 'c9',
      });
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
      'grid': <String, dynamic>{'cells': <dynamic>[for (final c in grid) c?.raw]},
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
      expect(refillLineupFromBench({'squad': {'lineup': <dynamic>[]}}), isFalse);
      expect(refillLineupFromBench({}), isFalse);
    });

    test('only ever fills empty slots — it never benches anyone', () {
      final state = stateWith(['starter'], [_card('starter'), _card('better', definitionId: 'player_t8_mid')]);
      refillLineupFromBench(state);

      final lineup = (state['squad'] as Map)['lineup'] as List;
      expect((lineup.first as Map)['cardInstanceId'], 'starter');
    });
  });

  group('restoreKickoffLineup', () {
    // A FULL eleven, so the only holes in play are the ones a test makes. With
    // spare slots open, `refillLineupFromBench` quite correctly puts every
    // available body somewhere and the assertion is about the refill rather
    // than about the restore.
    const midSlot = 5;

    Map<String, dynamic> stateWith({
      required List<CardInstance?> grid,
      required List<String?> lineupIds,
    }) => {
      'squad': {
        'formation': '4-3-3',
        'lineup': [
          for (var i = 0; i < 11; i++)
            {
              'slotId': getFormation('4-3-3').slots[i].slotId,
              'slotPosition': getFormation('4-3-3').slots[i].slotPosition,
              'cardInstanceId': lineupIds[i],
            },
        ],
      },
      'grid': <String, dynamic>{
        'cells': <dynamic>[for (final c in grid) c?.raw],
      },
    };

    String slot(int i) => getFormation('4-3-3').slots[i].slotId;

    /// The eleven that started, as the screen snapshots it.
    Map<String, String?> kickoffOf(List<String?> ids) => {
      for (var i = 0; i < 11; i++) slot(i): ids[i],
    };

    List<String?> idsOf(Map<String, dynamic> state) => [
      for (final s in (state['squad'] as Map)['lineup'] as List)
        (s as Map)['cardInstanceId'] as String?,
    ];

    test('an ordinary swap goes back: the kickoff man returns', () {
      // "If we only subbed and not injured then you should keep the original
      // team." A substitution is a change for THIS match.
      final started = <String?>[for (var i = 0; i < 11; i++) 'p$i'];
      final now = [...started]..[midSlot] = 'sub';
      final state = stateWith(
        grid: [..._squad(), _card('sub')],
        lineupIds: now,
      );
      expect(restoreKickoffLineup(state, kickoffOf(started)), isTrue);
      expect(idsOf(state)[midSlot], 'p$midSlot');
      expect(idsOf(state), isNot(contains('sub')), reason: 'still on the pitch');
    });

    test('BUT AN INJURY HOLE KEEPS THE COVER THE MANAGER PICKED', () {
      // "An injured player should be replaced with the sub player." The slot
      // was EMPTY at kickoff — the sim vacated it before the screen opened —
      // so there is no original to go back to, and reverting it threw away the
      // one decision the subs panel exists to make.
      final started = <String?>[for (var i = 0; i < 11; i++) 'p$i']
        ..[midSlot] = null;
      final now = [...started]..[midSlot] = 'cover';
      final squad = _squad();
      squad[midSlot] = _card('p$midSlot', injured: true);
      final state = stateWith(
        grid: [...squad, _card('cover')],
        lineupIds: now,
      );
      expect(restoreKickoffLineup(state, kickoffOf(started)), isFalse);
      expect(idsOf(state)[midSlot], 'cover');
      expect(idsOf(state), isNot(contains('p$midSlot')));
    });

    test('and nobody comes back INJURED', () {
      // A tactic change re-rolls the remainder's injuries, so a man can be hurt
      // AFTER the kickoff snapshot was taken. `cleanLineup` keeps an injured
      // card in its slot on purpose — at full time that is exactly wrong.
      final started = <String?>[for (var i = 0; i < 11; i++) 'p$i'];
      final squad = _squad();
      squad[midSlot] = _card('p$midSlot', injured: true);
      final state = stateWith(
        grid: [...squad, _card('spare')],
        lineupIds: [...started],
      );
      expect(restoreKickoffLineup(state, kickoffOf(started)), isTrue);
      expect(idsOf(state)[midSlot], 'spare', reason: 'the casualty kept his place');
    });

    test('nor does anyone who has left the club', () {
      final started = <String?>[for (var i = 0; i < 11; i++) 'p$i'];
      final squad = _squad();
      squad[midSlot] = _card('p$midSlot', loanedOut: 'Ayton');
      final state = stateWith(
        grid: [...squad, _card('spare')],
        lineupIds: [...started],
      );
      restoreKickoffLineup(state, kickoffOf(started));
      expect(idsOf(state)[midSlot], 'spare');
    });

    test('a hole nobody covered is filled from the bench', () {
      // The half the old guard skipped: a manager who saw the casualty and made
      // no change left the side a man light for the next fixture.
      final started = <String?>[for (var i = 0; i < 11; i++) 'p$i']
        ..[midSlot] = null;
      final squad = _squad();
      squad[midSlot] = _card('p$midSlot', injured: true);
      final state = stateWith(
        grid: [...squad, _card('spare')],
        lineupIds: [...started],
      );
      expect(restoreKickoffLineup(state, kickoffOf(started)), isTrue);
      expect(idsOf(state)[midSlot], 'spare');
    });

    test('a match nobody changed reports no change at all', () {
      final started = <String?>[for (var i = 0; i < 11; i++) 'p$i'];
      final state = stateWith(grid: _squad(), lineupIds: [...started]);
      expect(
        restoreKickoffLineup(state, kickoffOf(started)),
        isFalse,
        reason: 'a write for nothing at the end of every match',
      );
    });

    test('a slot the formation no longer has is left alone', () {
      final started = <String?>[for (var i = 0; i < 11; i++) 'p$i'];
      final state = stateWith(grid: _squad(), lineupIds: [...started]);
      expect(restoreKickoffLineup(state, const {'not-a-slot': 'x'}), isFalse);
      expect(idsOf(state)[0], 'p0');
    });

    test('refuses a malformed save', () {
      expect(restoreKickoffLineup({}, const {}), isFalse);
      expect(
        restoreKickoffLineup({'squad': {'lineup': null}}, const {}),
        isFalse,
      );
    });
  });
}
