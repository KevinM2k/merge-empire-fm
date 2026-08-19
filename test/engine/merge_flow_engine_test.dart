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
}
