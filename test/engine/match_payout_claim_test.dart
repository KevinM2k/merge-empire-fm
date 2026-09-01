/// **THE FIGURE ON THE SCREEN IS THE FIGURE IN THE WALLET.**
///
/// The summary's total is assembled from two sources paid at DIFFERENT times
/// by DIFFERENT code: a match quest pays itself at the whistle inside
/// `settleMatch`, and the fee is held back until the player dismisses the
/// screen so the rewarded video has something left to double. The screen adds
/// them and shows one number; nothing checked that the number it shows is the
/// number that lands.
///
/// Asked for from the couch in those terms — when it says ten coins, we should
/// actually get ten coins, and the same when it is doubled.
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/lineup_engine.dart';
import 'package:merge_empire_fc/engine/match_events.dart';
import 'package:merge_empire_fc/engine/match_orchestration.dart';
import 'package:merge_empire_fc/ui/screens/match/match_launcher.dart';
import 'package:merge_empire_fc/ui/screens/match/match_summary.dart'
    show questCoins;
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

const int _now = 1700000000000;

/// A save good enough to play a league match from.
Map<String, dynamic> _state({
  bool hardMode = false,
  int seasonsPlayed = 0,
  String division = 'regional_league',
  int cardCount = 13,
  int seasonMatchesPlayed = 4,
  bool setLineup = true,
  Map<String, dynamic> shop = const {},
  Map<String, dynamic> boosts = const {},
}) {
  const positions = [
    'gk', 'def', 'def', 'def', 'def', 'mid', 'mid', 'mid', 'mid', 'fwd', 'fwd',
    'mid', 'def', 'fwd', 'mid',
  ];
  final cells = <Map<String, dynamic>?>[
    for (var i = 0; i < 15; i++)
      if (i < cardCount)
        {
          'instanceId': 'c$i',
          'definitionId': 'player_t5_${positions[i]}',
          'seasonsPlayed': seasonsPlayed,
        }
      else
        null,
  ];
  final lineup = setLineup
      ? [
          for (final s in buildDefaultLineup(
            '4-4-2',
            [for (final c in cells) CardInstance.from(c)],
          ))
            {
              'slotId': s.slotId,
              'slotPosition': s.slotPosition,
              'cardInstanceId': s.cardInstanceId,
            },
        ]
      : <Map<String, dynamic>>[];

  return {
    'clubName': 'Test Town',
    'grid': {'cells': cells},
    'squad': {'lineup': lineup, 'formation': '4-4-2', 'strategyId': 'balanced'},
    'settings': {'hardMode': hardMode},
    'resources': {'fanCoins': 0, 'gems': 0, 'trophies': 0},
    'clubAssets': <String, dynamic>{},
    'shop': {...shop},
    'boosts': {...boosts},
    'definitionRatios': <String, dynamic>{},
    'transferMarket': {'grudges': <String, dynamic>{}},
    'progression': {
      'currentDivision': division,
      'seasonCount': 3,
      'seasonMatchesPlayed': seasonMatchesPlayed,
      'seasonOpponents': [for (var i = 0; i < 7; i++) '${division}_$i'],
      'seasonOpponentRatings': {
        for (var i = 0; i < 7; i++) 's3_o$i': 44 + i,
      },
      'leaguePyramid': <String, dynamic>{},
      'fixtureResults': <String, dynamic>{},
      'stagnationBuffs': <String, dynamic>{},
      'opponentTablePositions': <String, dynamic>{},
      'matchesPlayed': 12,
      'lastMatchAt': _now - 600000,
    },
  };
}

void main() {
  setUp(() {
    setClock(() => _now);
    seeded.setSeed(3);
    setEventRandom(math.Random(7));
    setMatchRandom(math.Random(7));
  });
  tearDown(() {
    resetClock();
    resetEventRandom();
    resetMatchRandom();
  });

  int wallet(Map<String, dynamic> state) =>
      ((state['resources'] as Map)['fanCoins'] as num).toInt();

  /// Full time, and the two halves of the claim measured the way the screen
  /// measures them.
  ({int before, int fee, int quests}) toFullTime(
    Map<String, dynamic> state,
    Map<String, dynamic> result,
  ) {
    final before = wallet(state);
    settleMatch(state, result);
    return (
      before: before,
      fee: (result['coinsEarned'] as num).toInt(),
      quests: questCoins(result),
    );
  }

  group('what the summary claims is what the player gets', () {
    // A spread of seeds, because the quest track is drawn at random: a match
    // where nothing came off is a different sum from one where all three did.
    test('DECLINED: the wallet moves by exactly the figure on the card', () {
      for (var seed = 0; seed < 20; seed++) {
        seeded.setSeed(seed);
        final state = _state();
        final result = simulateMatch(state, 'regional_league');
        final claim = toFullTime(state, result);
        // What `_Payout` prints: `_base + _quests`, both read before the offer
        // is answered.
        final shown = claim.fee + claim.quests;

        payMatch(state, result);

        expect(
          wallet(state) - claim.before,
          shown,
          reason: 'seed $seed claimed $shown',
        );
      }
    });

    test('DOUBLED: and by exactly twice it when the video is watched', () {
      for (var seed = 0; seed < 20; seed++) {
        seeded.setSeed(seed);
        final state = _state();
        final result = simulateMatch(state, 'regional_league');
        final claim = toFullTime(state, result);
        final shown = claim.fee + claim.quests;

        // What `_double` writes back. The quest money is already banked, so
        // the fee doubles and the quests' SECOND helping rides along on the
        // half still owed — see `MatchSummaryScreenState._double`.
        result['coinsEarned'] = claim.fee * 2 + claim.quests;
        payMatch(state, result);

        expect(
          wallet(state) - claim.before,
          shown * 2,
          reason: 'seed $seed claimed ${shown * 2}',
        );
      }
    });

    test('and the quest half really is in the wallet before the card shows', () {
      // The half that is NOT deferred. If this stopped being true the totals
      // above would still add up while the player waited for money they had
      // already been given.
      for (var seed = 0; seed < 20; seed++) {
        seeded.setSeed(seed);
        final state = _state();
        final result = simulateMatch(state, 'regional_league');
        final claim = toFullTime(state, result);
        expect(
          wallet(state) - claim.before,
          claim.quests,
          reason: 'seed $seed banked its quests at the whistle',
        );
      }
    });
  });
}
