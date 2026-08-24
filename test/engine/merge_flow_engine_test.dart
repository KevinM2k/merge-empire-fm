/// A merge as the player performs it — the bookkeeping around `attemptMerge`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/player_art.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/quests.dart';
import 'package:merge_empire_fc/engine/merge_engine.dart';
import 'package:merge_empire_fc/engine/merge_flow_engine.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/format.dart';

/// The lowest-tier player, so a pair of them makes a predictable third.
String get _baseDefId => players.firstWhere((p) => p.tier == 1).id;

int get _maleVariant => List.generate(
  playerVariants,
  (i) => i,
).firstWhere((i) => !isVariantFemale(i));

/// A stored card. The variant is explicit and matched across a pair on purpose:
/// the engine refuses two players of different genders, so a fixture that omits
/// it makes a merge test pass about one run in three.
Map<String, dynamic> _card(String id, String instanceId) => {
  'definitionId': id,
  'instanceId': instanceId,
  'variant': _maleVariant,
};

Map<String, dynamic> _state({
  int coins = 100000,
  String division = 'regional_league',
  List<dynamic>? cells,
}) {
  final s = createDefaultState();
  (s['resources'] as Map<String, dynamic>)['fanCoins'] = coins;
  (s['progression'] as Map<String, dynamic>)['currentDivision'] = division;
  if (cells != null) {
    final grid = (s['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
    for (var i = 0; i < cells.length; i++) {
      grid[i] = cells[i];
    }
  }
  return s;
}

List<dynamic> _cells(Map<String, dynamic> s) =>
    (s['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;

int _filled(Map<String, dynamic> s) => _cells(s).where((c) => c != null).length;

int _coins(Map<String, dynamic> s) =>
    ((s['resources'] as Map<String, dynamic>)['fanCoins'] as num).toInt();

Map<String, dynamic> _tally(Map<String, dynamic> s) =>
    (s['quests'] as Map<String, dynamic>)['seasonTally']
        as Map<String, dynamic>;

/// A pair sitting in the first two slots.
Map<String, dynamic> _pairState({int coins = 100000}) => _state(
  coins: coins,
  cells: [_card(_baseDefId, 'a'), _card(_baseDefId, 'b')],
);

void main() {
  tearDown(clearBus);

  group('a merge the player dragged', () {
    test('counts toward the career total, which survives a prestige', () {
      final s = _pairState();
      final result = performMerge(s, 0, 1);
      expect(result.ok, isTrue);
      expect(result.action, MergeAction.merge);
      expect(
        (s['careerStats'] as Map<String, dynamic>)['totalMerges'],
        1,
        reason: 'the ledger the achievements read first',
      );
    });

    test('counts in stats too, which is what carries the highest tier', () {
      // `attemptMerge` only counts when it is handed a stats map, and the grid
      // was not handing it one.
      final s = _pairState();
      performMerge(s, 0, 1);
      final stats = s['stats'] as Map<String, dynamic>;
      expect(stats['totalMerges'], 1);
      expect(stats['highestTier'], 2);
    });

    test('advances the season merge tally', () {
      final s = _pairState();
      performMerge(s, 0, 1);
      expect(_tally(s)[QuestAction.mergeCount], 1);
    });

    test('reports the tier ladder once it is worth reporting', () {
      // A MAX action, and the quests start at three — so a tier-two merge has
      // nothing to say and does not call the funnel at all.
      final s = _pairState();
      performMerge(s, 0, 1);
      expect(_tally(s)[QuestAction.reachTier], isNull);

      final t2 = getDefinition(_baseDefId)!.mergesInto!;
      final higher = _state(cells: [_card(t2, 'c'), _card(t2, 'd')]);
      performMerge(higher, 0, 1);
      expect(_tally(higher)[QuestAction.reachTier], 3);
    });

    test('announces itself, so the achievement sweep hears it', () {
      final s = _pairState();
      final heard = <Object?>[];
      void listener(Object? args) => heard.add(args);
      on('merge:happened', listener);
      addTearDown(() => off('merge:happened', listener));

      performMerge(s, 0, 1);
      expect(heard.length, 1);
    });

    test('cancels a bid for either parent, and names the club', () {
      // Both parents are consumed, so a club that bid for one of them is left
      // waiting on a player who no longer exists.
      final s = _pairState();
      (s['transferMarket'] as Map<String, dynamic>)['pendingOffer'] = {
        'cardInstanceId': 'b',
        'fromTeam': 'Real Somewhere',
        'cash': 500,
      };

      final result = performMerge(s, 0, 1);
      expect(result.grudgeTeam, 'Real Somewhere');
      expect(
        (s['transferMarket'] as Map<String, dynamic>)['pendingOffer'],
        isNull,
      );
    });

    test('a move counts nothing at all', () {
      final s = _state(cells: [_card(_baseDefId, 'a')]);
      final result = performMerge(s, 0, 5);
      expect(result.ok, isTrue);
      expect(result.action, MergeAction.move);
      expect((s['careerStats'] as Map<String, dynamic>)['totalMerges'], 0);
      expect(_tally(s)[QuestAction.mergeCount], isNull);
    });

    test('a division ceiling refuses, and says which tier would clear it', () {
      // Sunday League tops out at two, so a pair of tier twos has nowhere to go.
      final t2 = getDefinition(_baseDefId)!.mergesInto!;
      final s = _state(
        division: 'sunday_league',
        cells: [_card(t2, 'c'), _card(t2, 'd')],
      );
      final heard = <Object?>[];
      void listener(Object? args) => heard.add(args);
      on('merge:refused', listener);
      addTearDown(() => off('merge:refused', listener));

      final result = performMerge(s, 0, 1, maxTier: 2);
      expect(result.ok, isFalse);
      expect(result.reason, 'division_locked');
      expect((heard.single as Map)['reason'], 'division_locked');
      expect((heard.single as Map)['tier'], 3);
      expect(_filled(s), 2, reason: 'both cards still there');
    });
  });

  group('Merge All', () {
    test('costs half a scout at this division, and says so', () {
      final s = _state(division: 'regional_league');
      final base = Scout.baseCostByDiv['regional_league']!;
      expect(mergeAllCost(s), roundCoins(base * 0.5));
    });

    test('the Academy does not discount it', () {
      // The Academy's one stat is the SIGNING price. Pricing the sweep off the
      // discounted rate would give it a second effect nothing documents.
      final s = _state();
      final before = mergeAllCost(s);
      (s['clubAssets'] as Map<String, dynamic>)['academy'] = {
        'owned': true,
        'tier': 8,
        'invested': 0,
        'tapCount': 0,
      };
      expect(mergeAllCost(s), before);
    });

    test('sweeps the grid and charges once', () {
      final s = _pairState();
      final cost = mergeAllCost(s);
      final coinsBefore = _coins(s);

      final run = runMergeAll(s);
      expect(run.ok, isTrue);
      expect(run.merges, 1);
      expect(_filled(s), 1);
      expect(_coins(s), coinsBefore - cost, reason: 'once, not once per pair');
    });

    test('counts every pair it merged, not one for the sweep', () {
      final s = _state(
        cells: [
          _card(_baseDefId, 'a'),
          _card(_baseDefId, 'b'),
          _card(_baseDefId, 'c'),
          _card(_baseDefId, 'd'),
        ],
      );
      final run = runMergeAll(s);
      expect(run.merges, greaterThan(1));
      expect(
        (s['careerStats'] as Map<String, dynamic>)['totalMerges'],
        run.merges,
      );
      expect(_tally(s)[QuestAction.mergeCount], run.merges);
    });

    test('a club that cannot pay keeps its coins AND its pairs', () {
      final s = _pairState(coins: 0);
      final run = runMergeAll(s);
      expect(run.ok, isFalse);
      expect(run.reason, 'insufficient_coins');
      expect(_filled(s), 2);
      expect(_coins(s), 0);
    });

    test('and is told what it would have cost', () {
      final s = _pairState(coins: 0);
      final heard = <Object?>[];
      void listener(Object? args) => heard.add(args);
      on('merge:refused', listener);
      addTearDown(() => off('merge:refused', listener));

      runMergeAll(s);
      expect((heard.single as Map)['reason'], 'insufficient_coins');
      expect((heard.single as Map)['coins'], mergeAllCost(s));
    });

    test('a grid with no pairs is free, and refuses before it charges', () {
      final s = _state(cells: [_card(_baseDefId, 'a')]);
      final coinsBefore = _coins(s);
      final run = runMergeAll(s);
      expect(run.ok, isFalse);
      expect(run.reason, 'no_pairs');
      expect(_coins(s), coinsBefore);
    });

    test('counting the pairs does not merge them', () {
      // The button carries the number, so the question gets asked on every
      // rebuild — against a copy, or the grid would sweep itself.
      final s = _pairState();
      expect(mergeablePairs(s), 1);
      expect(mergeablePairs(s), 1);
      expect(_filled(s), 2);
    });

    test('announces once for the whole sweep', () {
      final s = _state(
        cells: [
          _card(_baseDefId, 'a'),
          _card(_baseDefId, 'b'),
          _card(_baseDefId, 'c'),
          _card(_baseDefId, 'd'),
        ],
      );
      final heard = <Object?>[];
      void listener(Object? args) => heard.add(args);
      on('merge:happened', listener);
      addTearDown(() => off('merge:happened', listener));

      final run = runMergeAll(s);
      expect(run.merges, greaterThan(1));
      expect(heard.length, 1, reason: 'one action the player took');
    });

    test('coins stay whole numbers', () {
      final s = _pairState();
      runMergeAll(s);
      expect((s['resources'] as Map)['fanCoins'], isA<int>());
    });
  });

  group('a first-ever sighting', () {
    test('is false with nobody counting, which is the deal', () {
      final s = _pairState();
      expect(performMerge(s, 0, 1).isNewDiscovery, isFalse);
    });

    test('is true once the discovery listener has counted the card', () {
      // The app's listener, in miniature: `merge:complete` fires inside the
      // merge and what it writes is what the flow reads back.
      final s = _pairState();
      void handler(Object? args) {
        final card = (args as Map)['newCard'];
        final counts =
            (s['progression'] as Map<String, dynamic>)['playerFoundCounts']
                as Map<String, dynamic>;
        final key = '${card.definitionId}:m';
        counts[key] = ((counts[key] as num?) ?? 0) + 1;
      }

      on('merge:complete', handler);
      addTearDown(() => off('merge:complete', handler));

      expect(performMerge(s, 0, 1).isNewDiscovery, isTrue);
    });
  });

  group('the hole a merge leaves', () {
    test('is closed up, and the flow says where the card ended up', () {
      // The player merges into slot 4 and the card appears in slot 2, because
      // the two slots ahead of it were empty.
      final state = _state(
        cells: [
          null,
          null,
          null,
          _card(_baseDefId, 'a'),
          _card(_baseDefId, 'b'),
        ],
      );
      final flow = performMerge(state, 3, 4);
      expect(flow.action, MergeAction.merge);
      expect(flow.landedAt, 0, reason: 'it slid up past both holes');
      final cells = (state['grid'] as Map<String, dynamic>)['cells'] as List;
      expect(cells[0], isNotNull);
      expect(cells.skip(1).every((c) => c == null), isTrue);
    });

    test('but the merged card KEEPS the cell it was dropped on', () {
      // Three in a row, the first dragged onto the second. The celebration is
      // at cell 1 and it has to stay there; the third card fills the hole.
      final state = _state(
        cells: [
          _card(_baseDefId, 'a'),
          _card(_baseDefId, 'b'),
          _card(_baseDefId, 'c'),
          null,
        ],
      );
      final flow = performMerge(state, 0, 1);
      expect(flow.landedAt, 1);
      final cells = (state['grid'] as Map<String, dynamic>)['cells'] as List;
      expect(cells[0]['instanceId'], 'c', reason: 'it dropped into the hole');
      expect(cells[1]['definitionId'], isNot(_baseDefId));
      expect(cells[2], isNull);
    });

    test('but a MOVE leaves the card where the player put it', () {
      // The grid has to stay arrangeable: closing up after a move would slide
      // every card straight back to the front.
      final state = _state(cells: [_card(_baseDefId, 'a'), null, null, null]);
      final flow = performMerge(state, 0, 3);
      expect(flow.action, MergeAction.move);
      final cells = (state['grid'] as Map<String, dynamic>)['cells'] as List;
      expect(cells[0], isNull);
      expect(cells[3], isNotNull, reason: 'it was dragged there on purpose');
    });
  });
  group('A SWEEP SAYS WHERE IT LANDED', () {
    // **Merge All used to arrive at its answer** — the grid simply changed: no
    // burst, no slide, nothing to say which pairs had gone. One drag has had
    // the full set-piece since it was ported and twelve at once had none of it.

    test('it names a square for every card it made', () {
      final s = _state(
        cells: [
          for (var i = 0; i < 3; i++) ...[
            _card(_baseDefId, 'a$i'),
            _card(_baseDefId, 'b$i'),
          ],
        ],
      );
      final run = runMergeAll(s);
      expect(run.ok, isTrue);
      expect(run.landedAt, isNotEmpty);
      // **At most one per merge, and often fewer** — a survivor can merge
      // AGAIN on a later pass, and when it does the card it was is gone. What
      // `landedAt` names is what is still on the grid to celebrate, which is
      // the only thing a burst can go off over.
      expect(run.landedAt.length, lessThanOrEqualTo(run.merges));
    });

    test('AND THE SQUARES ARE THE ONES THE CARDS ARE IN, after the gaps close',
        () {
      // The indices could not be taken from `mergeAll` directly: closing the
      // holes moves every card after them, so an index recorded during the
      // sweep names a different square by the time anything can use it. Ids
      // come out instead and the squares are read at the end.
      final s = _state(
        cells: [
          for (var i = 0; i < 3; i++) ...[
            _card(_baseDefId, 'a$i'),
            _card(_baseDefId, 'b$i'),
          ],
        ],
      );
      final run = runMergeAll(s);
      final cells = _cells(s);
      for (final i in run.landedAt) {
        expect(cells[i], isNotNull, reason: 'square $i is empty');
      }
      // And they are contiguous from the top, because the gaps closed.
      expect(run.landedAt, run.landedAt.toList()..sort());
    });

    test('a refused sweep names nothing', () {
      final s = _state(cells: [_card(_baseDefId, 'lonely')]);
      final run = runMergeAll(s);
      expect(run.ok, isFalse);
      expect(run.landedAt, isEmpty);
    });
  });

  group('AND THE SWEEP CLOSES THE HOLES BEHIND IT', () {
    test('a dozen merges do not leave a dozen gaps', () {
      // Every merge empties the source's cell, so a sweep left the grid a
      // scatter of cards with holes between them and the next scout landed in
      // the first hole rather than after the cards the player can see. A DRAG
      // merge has closed them since `closeGridGaps` was written; the sweep
      // never called it.
      final s = createDefaultState();
      final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
      for (var i = 0; i < 12; i++) {
        cells[i] = <String, dynamic>{
          'definitionId': 'player_t1_fwd',
          'instanceId': 'c$i',
          'variant': 0,
        };
      }
      (s['resources'] as Map<String, dynamic>)['fanCoins'] = 1000000;

      final run = runMergeAll(s, maxTier: 9);
      expect(run.ok, isTrue);
      expect(run.merges, greaterThan(1));

      final after = (s['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
      final firstHole = after.indexWhere((c) => c == null);
      final lastCard = after.lastIndexWhere((c) => c != null);
      expect(
        firstHole,
        greaterThan(lastCard),
        reason: 'a gap was left in front of a card',
      );
    });
  });


  group('counting the pairs', () {
    test('ASKING THE QUESTION DOES NOT ANSWER IT — on the bus either', () {
      // The copy was there from the start and protected the grid; what it did
      // not protect was the BUS. Every probe merge fired `merge:complete`,
      // whose listener re-syncs the lineup and writes to the save — so counting
      // the pairs behind a "Merge All (3)" button announced three merges that
      // never happened, on every rebuild of the button.
      //
      // It surfaced as a crash rather than as drift, which is the only lucky
      // part: the count is read by a PROVIDER, so the write bumped the save
      // revision from inside another provider's build and Riverpod refused.
      final heard = <Object?>[];
      void listener(Object? args) => heard.add(args);
      on('merge:complete', listener);
      addTearDown(() => off('merge:complete', listener));

      final state = createDefaultState();
      final cells = (state['grid'] as Map<String, dynamic>)['cells'] as List;
      for (var i = 0; i < 4; i++) {
        cells[i] = <String, dynamic>{
          'definitionId': 'player_t1_mid',
          'instanceId': 'c$i',
          'variant': 0,
        };
      }

      final pairs = mergeablePairs(state);
      expect(pairs, greaterThan(0), reason: 'nothing to count');
      expect(heard, isEmpty, reason: 'the count announced a merge');
      // And the grid is untouched, which is what the copy was always for.
      expect(cells.where((c) => c != null), hasLength(4));
    });

    test('a REAL sweep still announces every merge it makes', () {
      final heard = <Object?>[];
      void listener(Object? args) => heard.add(args);
      on('merge:complete', listener);
      addTearDown(() => off('merge:complete', listener));

      final cells = <dynamic>[
        for (var i = 0; i < 2; i++)
          <String, dynamic>{
            'definitionId': 'player_t1_mid',
            'instanceId': 'c$i',
            'variant': 0,
          },
      ];
      expect(mergeAll(cells, maxTier: 9), 1);
      expect(heard, hasLength(1));
    });
  });
}
