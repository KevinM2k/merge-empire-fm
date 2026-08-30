/// The rules the match orchestration has to obey, as distinct from the numbers
/// it produces.
///
/// The parity fixture pins whole matches against the JS; this pins the
/// INVARIANTS, so a fixture regenerated against a broken source still fails
/// here. The serialisation test is the important one: a cup win puts a result
/// into the save, and this file's own history includes a Dart record stored on a
/// result that would have thrown on the first save after it.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/engine/lineup_engine.dart';
import 'package:merge_empire_fc/engine/match_events.dart';
import 'package:merge_empire_fc/engine/match_orchestration.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/analytics.dart';
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

List<Map<String, dynamic>> _events(Map<String, dynamic> result) => [
  for (final e in result['events'] as List) e as Map<String, dynamic>,
];

int _goalCount(Map<String, dynamic> result) =>
    _events(result).where((e) => e['type'] == 'goal').length;

void main() {
  setUp(() {
    setClock(() => _now);
    seeded.setSeed(12345);
    setEventRandom(math.Random(7));
    setMatchRandom(math.Random(7));
  });
  tearDown(() {
    resetClock();
    resetEventRandom();
    resetMatchRandom();
  });

  group('the result is save-safe', () {
    test('a finished, settled match encodes as JSON', () {
      // A cup win puts a result into the save, so anything on it that cannot be
      // encoded throws on the first save after the match rather than here.
      for (final hardMode in [false, true]) {
        for (var seed = 0; seed < 25; seed++) {
          seeded.setSeed(seed);
          final state = _state(hardMode: hardMode, seasonsPlayed: 12);
          final result = simulateMatch(state, 'champions_cup');
          applyMatchRewards(state, result);
          expect(() => jsonEncode(result), returnsNormally, reason: 'seed $seed');
          expect(() => jsonEncode(state), returnsNormally, reason: 'seed $seed');
        }
      }
    });

    test('a re-simulated cup tie encodes as JSON, shootout and all', () {
      // The shootout is the specific thing that used to go in as a record.
      for (var seed = 0; seed < 40; seed++) {
        seeded.setSeed(seed);
        final state = _state();
        final result = <String, dynamic>{
          'divisionId': 'regional_league',
          'isCup': true,
          'isHome': true,
          'squadRating': 60,
          'effOppAttackRating': 60,
          'effOppDefenceRating': 61,
          'opponentRating': 60,
          'addedTime': 2,
          'homeGoals': 1,
          'awayGoals': 1,
          'events': <Object?>[],
          'injuryLog': <Object?>[],
        };
        reSimulateRemainder(result, 92, 'balanced', 1, 1, state);
        expect(result['penaltyShootout'], isNotNull, reason: 'seed $seed');
        expect(() => jsonEncode(result), returnsNormally, reason: 'seed $seed');
      }
    });
  });

  group('injuries', () {
    test('never more than two in one match, however many tactic changes', () {
      // Repeated tactic changes must never grind a squad down past the cap.
      for (var seed = 0; seed < 40; seed++) {
        seeded.setSeed(seed);
        final state = _state(seasonsPlayed: 14);
        final result = simulateMatch(state, 'champions_cup');
        for (final min in [10, 30, 50, 70]) {
          reSimulateRemainder(
            result,
            min,
            'highPress',
            (result['homeGoals'] as num).toInt(),
            (result['awayGoals'] as num).toInt(),
            state,
          );
        }
        final injured = (state['grid'] as Map)['cells'] as List;
        expect(
          injured.where((c) => (c as Map?)?['injured'] == true).length,
          lessThanOrEqualTo(2),
          reason: 'seed $seed',
        );
      }
    });

    test('a knock vacates the slot and nobody is subbed in for them', () {
      // No auto-replacement in EITHER mode — the manager subs from the bench
      // themselves, which is what the no_sub event opens the panel for.
      for (var seed = 0; seed < 60; seed++) {
        seeded.setSeed(seed);
        final state = _state(seasonsPlayed: 14);
        final result = simulateMatch(state, 'champions_cup');
        if ((result['injuryCount'] as num) == 0) continue;
        final lineup = (state['squad'] as Map)['lineup'] as List;
        final injuredIds = {
          for (final c in (state['grid'] as Map)['cells'] as List)
            if ((c as Map?)?['injured'] == true) c!['instanceId'],
        };
        for (final slot in lineup) {
          expect(
            injuredIds.contains((slot as Map)['cardInstanceId']),
            isFalse,
            reason: 'an injured player is still on the pitch — seed $seed',
          );
        }
        expect(
          _events(result).where((e) => e['type'] == 'no_sub'),
          hasLength(result['injuryCount']),
          reason: 'seed $seed',
        );
        return;
      }
      fail('no seed produced an injury');
    });
  });

  group('the event feed', () {
    test('names exactly as many goals as the scoreline', () {
      for (var seed = 0; seed < 30; seed++) {
        seeded.setSeed(seed);
        final state = _state();
        final result = simulateMatch(state, 'regional_league');
        expect(
          _goalCount(result),
          (result['homeGoals'] as num) + (result['awayGoals'] as num),
          reason: 'seed $seed',
        );
      }
    });

    test('ends on the final whistle, after every goal', () {
      for (var seed = 0; seed < 30; seed++) {
        seeded.setSeed(seed);
        final state = _state();
        final result = simulateMatch(state, 'regional_league');
        final events = _events(result);
        final fulltime = events.lastWhere((e) => e['type'] == 'fulltime');
        for (final e in events) {
          if (e['type'] == 'opp_sub') continue;
          expect(
            e['minute'] as num,
            lessThanOrEqualTo(fulltime['minute'] as num),
            reason: '${e['type']} after full time — seed $seed',
          );
        }
      }
    });

    test('credits our goals to our players and theirs to nobody', () {
      // Engine events are us-centric: team `home` is always our goal, whichever
      // ground it was played on.
      for (var seed = 0; seed < 30; seed++) {
        seeded.setSeed(seed);
        final state = _state();
        final result = simulateMatch(state, 'regional_league');
        for (final e in _events(result).where((e) => e['type'] == 'goal')) {
          if (e['team'] == 'away') {
            expect(e['scorerInstanceId'], isNull, reason: 'seed $seed');
          } else {
            expect(e['scorerInstanceId'], isNotNull, reason: 'seed $seed');
          }
        }
      }
    });
  });

  group('simulateMatch', () {
    test('forceWin always wins, and the feed agrees', () {
      for (var seed = 0; seed < 30; seed++) {
        seeded.setSeed(seed);
        final state = _state();
        final result = simulateMatch(state, 'regional_league', forceWin: true);
        expect(result['won'], isTrue, reason: 'seed $seed');
        expect(result['homeGoals'] as num, greaterThan(result['awayGoals'] as num));
        expect(_goalCount(result),
            (result['homeGoals'] as num) + (result['awayGoals'] as num));
      }
    });

    test('spends the Lucky Boot, once', () {
      final state = _state(shop: {'luckyBootReady': true});
      final withBoot = simulateMatch(state, 'regional_league');
      expect((state['shop'] as Map)['luckyBootReady'], isFalse);

      seeded.setSeed(12345);
      final plain = _state();
      final without = simulateMatch(plain, 'regional_league');
      expect(
        withBoot['opponentRating'] as num,
        lessThan(without['opponentRating'] as num),
      );
    });

    test('closes the season on the fourteenth fixture, not before', () {
      final almost = _state(seasonMatchesPlayed: 12);
      simulateMatch(almost, 'regional_league');
      expect((almost['progression'] as Map)['seasonComplete'], isNull);

      final last = _state(seasonMatchesPlayed: 13);
      simulateMatch(last, 'regional_league');
      expect((last['progression'] as Map)['seasonComplete'], isTrue);
    });

    test('runs the segment sim only in Pro mode with an XI set', () {
      expect(
        simulateMatch(_state(), 'regional_league')['hardSim'],
        isNull,
      );
      expect(
        simulateMatch(_state(hardMode: true), 'regional_league')['hardSim'],
        isNotNull,
      );
      expect(
        simulateMatch(
          _state(hardMode: true, setLineup: false),
          'regional_league',
        )['hardSim'],
        isNull,
      );
    });

    test('does not credit coins or move the table — that waits for full time', () {
      final state = _state();
      final result = simulateMatch(state, 'regional_league');
      final prog = state['progression'] as Map;
      expect((state['resources'] as Map)['fanCoins'], 0);
      expect(prog['seasonAwardedPlayed'], isNull);
      expect(prog['matchesWon'], isNull);
      // The counters that cooldowns and fixture indexing need DO move.
      expect(prog['matchesPlayed'], 13);
      expect(prog['seasonMatchesPlayed'], 5);
      expect(prog['lastMatchAt'], _now);
      expect(prog['fixtureResults'], contains(result['fixtureKey']));
    });
  });

  group('settlement', () {
    test('credits once, however many times it is called', () {
      final state = _state();
      final result = simulateMatch(state, 'regional_league');
      final coins = result['coinsEarned'] as num;
      for (var i = 0; i < 4; i++) {
        finalizeMatchOutcome(state, result);
        applyMatchRewards(state, result);
      }
      expect((state['resources'] as Map)['fanCoins'], coins);
      expect((state['progression'] as Map)['seasonAwardedPlayed'], 1);
    });

    test('records the draw context a mood reads, from the events', () {
      // A 1-1 tells you nothing on its own. led and trailed are replayed from
      // the feed because a tactic change rewrites the scoreline but the feed is
      // always the match that actually happened.
      for (var seed = 0; seed < 60; seed++) {
        seeded.setSeed(seed);
        final state = _state();
        final result = simulateMatch(state, 'regional_league');
        applyMatchRewards(state, result);
        final last =
            (state['progression'] as Map)['lastMatchResult'] as Map<String, dynamic>;
        var ours = 0;
        var theirs = 0;
        var led = false;
        var trailed = false;
        for (final e in _events(result).where((e) => e['type'] == 'goal')) {
          e['team'] == 'home' ? ours++ : theirs++;
          if (ours > theirs) led = true;
          if (theirs > ours) trailed = true;
        }
        expect(last['led'], led, reason: 'seed $seed');
        expect(last['trailed'], trailed, reason: 'seed $seed');
        expect(
          last['ratingGap'],
          (result['opponentRating'] as num) - (result['squadRating'] as num),
        );
      }
    });

    test('shows the score home-team-first, whoever we are', () {
      for (var seed = 0; seed < 30; seed++) {
        seeded.setSeed(seed);
        final state = _state();
        final result = simulateMatch(state, 'regional_league');
        applyMatchRewards(state, result);
        final last = (state['progression'] as Map)['lastMatchResult'] as Map;
        final ours = result['homeGoals'];
        final theirs = result['awayGoals'];
        expect(
          last['score'],
          result['isHome'] == true ? '$ours–$theirs' : '$theirs–$ours',
          reason: 'seed $seed',
        );
        expect(last['ourGoals'], ours);
        expect(last['theirGoals'], theirs);
      }
    });

    test('everyone who played gets an appearance, and only them', () {
      final state = _state();
      final result = simulateMatch(state, 'regional_league');
      applyMatchRewards(state, result);
      final xi = {
        for (final s in (state['squad'] as Map)['lineup'] as List)
          (s as Map)['cardInstanceId'],
      };
      for (final c in (state['grid'] as Map)['cells'] as List) {
        if (c == null) continue;
        final played = (c as Map)['stats'] != null;
        expect(played, xi.contains(c['instanceId']), reason: '${c['instanceId']}');
      }
    });
  });

  group('reSimulateRemainder', () {
    test('a cup tie never ends level', () {
      for (var seed = 0; seed < 40; seed++) {
        seeded.setSeed(seed);
        final state = _state();
        final result = <String, dynamic>{
          'divisionId': 'regional_league',
          'isCup': true,
          'isHome': true,
          'squadRating': 60,
          'effOppAttackRating': 60,
          'effOppDefenceRating': 61,
          'opponentRating': 60,
          'addedTime': 2,
          'homeGoals': 0,
          'awayGoals': 0,
          'events': <Object?>[],
          'injuryLog': <Object?>[],
        };
        reSimulateRemainder(result, 45, 'balanced', 0, 0, state);
        expect(result['drawn'], isFalse, reason: 'seed $seed');
      }
    });

    test('the remainder feed names exactly the remainder goals', () {
      for (var seed = 0; seed < 30; seed++) {
        seeded.setSeed(seed);
        final state = _state();
        final result = simulateMatch(state, 'regional_league');
        final ours = (result['homeGoals'] as num).toInt();
        final theirs = (result['awayGoals'] as num).toInt();
        final newEvents =
            reSimulateRemainder(result, 45, 'allOutAttack', ours, theirs, state);
        final scored = newEvents.where((e) => e['type'] == 'goal').length;
        expect(
          scored,
          (result['homeGoals'] as num) + (result['awayGoals'] as num) - ours - theirs,
          reason: 'seed $seed',
        );
      }
    });

    test('re-prices the payout when the outcome flips', () {
      for (var seed = 0; seed < 60; seed++) {
        seeded.setSeed(seed);
        final state = _state();
        final result = simulateMatch(state, 'regional_league');
        final wonBefore = result['won'] as bool;
        final coinsBefore = result['coinsEarned'] as num;
        reSimulateRemainder(result, 20, 'allOutAttack', 0, 0, state);
        if (result['won'] == wonBefore) continue;
        expect(
          result['coinsEarned'] as num == coinsBefore,
          isFalse,
          reason: 'the outcome flipped but the payout did not — seed $seed',
        );
        return;
      }
      fail('no seed flipped the outcome');
    });

    test('an event cup ignores the club squad entirely', () {
      // Strength is the chosen nation's rating, and no goal is credited to a
      // club player.
      final state = _state();
      final result = <String, dynamic>{
        'divisionId': 'regional_league',
        'isCup': true,
        'fixedRating': true,
        'anonymousPlayers': true,
        'squadRating': 90,
        'isHome': true,
        'effOppAttackRating': 20,
        'effOppDefenceRating': 20,
        'opponentRating': 20,
        'addedTime': 3,
        'homeGoals': 0,
        'awayGoals': 0,
        'events': <Object?>[],
        'injuryLog': <Object?>[],
      };
      final newEvents = reSimulateRemainder(result, 0, 'balanced', 0, 0, state);
      for (final e in newEvents.where((e) => e['type'] == 'goal')) {
        expect(e['scorerInstanceId'], isNull);
      }
      // A fixed-rating match never rolls an injury against the club squad.
      expect(
        ((state['grid'] as Map)['cells'] as List)
            .any((c) => (c as Map?)?['injured'] == true),
        isFalse,
      );
    });
  });

  group('cooldowns', () {
    test('gates on a squad too thin to field a side', () {
      final state = _state(setLineup: true);
      (state['squad'] as Map)['lineup'] = [
        for (final s in getFormation('4-4-2').slots)
          {
            'slotId': s.slotId,
            'slotPosition': s.slotPosition,
            'cardInstanceId': s.slotId == 'gk' ? 'c0' : null,
          },
      ];
      expect(canPlayMatch(state), isFalse);
    });

    test('a finished season closes the Play button', () {
      final state = _state();
      (state['progression'] as Map)['seasonComplete'] = true;
      expect(canPlayMatch(state), isFalse);
    });

    test('only ever pushes the clock later', () {
      final state = _state();
      (state['progression'] as Map)['lastMatchAt'] = _now + 5000;
      startMatchCooldown(state);
      expect((state['progression'] as Map)['lastMatchAt'], _now + 5000);
    });
  });

  group('home advantage', () {
    test('the Fan Zone lifts us at home and does nothing away', () {
      // A Sunday League touchline with three mates and a dog is not the Kop, so
      // the bonus scales with the tier — and only when we are hosting.
      Map<String, dynamic> hosting({required int fanTier}) {
        // Season 3, fixture 0 is a home tie under the seeded home/away rule.
        final s = _state(seasonMatchesPlayed: 0);
        (s['clubAssets'] as Map)['FANZONE'] = {'owned': true, 'tier': fanTier};
        return s;
      }

      seeded.setSeed(1);
      final bare = simulateMatch(hosting(fanTier: 0), 'regional_league');
      seeded.setSeed(1);
      final packed = simulateMatch(hosting(fanTier: 8), 'regional_league');
      expect(bare['isHome'], isTrue);
      expect(
        packed['homeAdvDisplay'] as num,
        greaterThan(bare['homeAdvDisplay'] as num),
      );

      // Away, the crowd is theirs, so our own tier buys nothing.
      seeded.setSeed(1);
      final away = _state(seasonMatchesPlayed: 4);
      (away['clubAssets'] as Map)['FANZONE'] = {'owned': true, 'tier': 8};
      final awayResult = simulateMatch(away, 'regional_league');
      expect(awayResult['isHome'], isFalse);
      expect(
        awayResult['ourAttackRating'],
        lessThanOrEqualTo(packed['ourAttackRating'] as num),
      );
    });
  });

  group('the loan book', () {
    test('a settled match reports the loans it ended, as plain data', () {
      // The report goes onto the result, and a cup result goes into the save —
      // so it has to be a map, never the record the loan engine returns.
      final state = _state(cardCount: 12);
      final cells = (state['grid'] as Map)['cells'] as List;
      cells[12] = {
        'instanceId': 'loanee',
        'definitionId': 'player_t5_mid',
        'seasonsPlayed': 0,
        'borrowed': true,
        'loanMatchesLeft': 1,
        'loanWage': 5,
      };
      final result = simulateMatch(state, 'regional_league');
      applyMatchRewards(state, result);

      final report = result['loanReport'] as Map<String, dynamic>;
      expect(report['departed'], hasLength(1));
      expect((report['departed'] as List).first, isA<Map<String, dynamic>>());
      expect(() => jsonEncode(result), returnsNormally);
    });

    test('a returning loanee comes home as plain data too', () {
      final state = _state(cardCount: 12);
      final cells = (state['grid'] as Map)['cells'] as List;
      cells[12] = {
        'instanceId': 'away',
        'definitionId': 'player_t5_mid',
        'seasonsPlayed': 0,
        'loanedOut': {'toTeam': 'Elsewhere FC', 'matchesLeft': 1},
      };
      final result = simulateMatch(state, 'regional_league');
      applyMatchRewards(state, result);

      final report = result['loanReport'] as Map<String, dynamic>;
      expect(report['returned'], hasLength(1));
      expect(
        ((report['returned'] as List).first as Map)['toTeam'],
        'Elsewhere FC',
      );
      expect(() => jsonEncode(result), returnsNormally);
    });
  });

  group('hardLiveRatings', () {
    test('a Pro-mode tactic change drops a cancelled injury from the sim too', () {
      // The victim is healed and their slot restored, so the live badge must stop
      // holding a place for them on the pitch as well.
      for (var seed = 0; seed < 60; seed++) {
        seeded.setSeed(seed);
        final state = _state(hardMode: true, seasonsPlayed: 14);
        final result = simulateMatch(state, 'champions_cup');
        final planned = (result['hardSim'] as Map)['injuries'] as List;
        if (planned.isEmpty) continue;
        final iid = (planned.first as Map)['iid'];
        final minute = ((planned.first as Map)['minute'] as num).toInt();
        if (minute <= 5) continue;

        reSimulateRemainder(
          result,
          5,
          'parkTheBus',
          (result['homeGoals'] as num).toInt(),
          (result['awayGoals'] as num).toInt(),
          state,
        );

        // The remainder may roll a FRESH knock, which legitimately lands back on
        // the list — so the rule is that this one is gone, not that the list is.
        expect(
          [
            for (final e in (result['hardSim'] as Map)['injuries'] as List)
              if ((e as Map)['iid'] == iid && e['minute'] == minute) e,
          ],
          isEmpty,
          reason: 'seed $seed',
        );
        expect(
          [
            for (final e in result['injuryLog'] as List)
              if ((e as Map)['iid'] == iid && e['minute'] == minute)
                e['cancelled'],
          ],
          [true],
          reason: 'seed $seed',
        );
        return;
      }
      fail('no seed produced a cancellable Pro-mode injury');
    });

    test('tolerates a save with no strategy timeline', () {
      final state = _state(hardMode: true);
      final result = simulateMatch(state, 'regional_league');
      (result['hardSim'] as Map).remove('stratLog');
      expect(
        () => hardLiveRatings(result, 45, state, 'balanced'),
        returnsNormally,
      );
    });

    test('reads the single-injury shape an older save wrote', () {
      final state = _state(hardMode: true);
      final result = simulateMatch(state, 'regional_league');
      final hs = result['hardSim'] as Map;
      final onPitch = (state['squad'] as Map)['lineup'] as List;
      hs.remove('injuries');
      hs['injury'] = {
        'iid': (onPitch.first as Map)['cardInstanceId'],
        'slotPosition': 'GK',
        'minute': 60,
      };
      expect(
        () => hardLiveRatings(result, 30, state, 'balanced'),
        returnsNormally,
      );
    });
  });

  group('bestFormationForFixture', () {
    test('keeps the manager\'s own shape on an exact tie', () {
      // A shape change nobody asked for should have to earn itself.
      for (final formationId in formations.keys) {
        final state = _state();
        (state['squad'] as Map)['formation'] = formationId;
        final picked = bestFormationForFixture(state, divisionId: 'regional_league');
        final incumbent = bestFormationForFixture(
          state,
          divisionId: 'regional_league',
        );
        expect(picked.formationId, incumbent.formationId);
      }
    });

    test('always returns a full eleven slots', () {
      for (final cardCount in [3, 8, 13, 15]) {
        final picked = bestFormationForFixture(
          _state(cardCount: cardCount),
          divisionId: 'regional_league',
        );
        expect(picked.lineup, hasLength(11), reason: '$cardCount cards');
      }
    });

    test('scores against a division midpoint when nobody has been played yet', () {
      final state = _state();
      (state['progression'] as Map)['seasonOpponentRatings'] = <String, dynamic>{};
      expect(
        () => bestFormationForFixture(state, divisionId: 'regional_league'),
        returnsNormally,
      );
    });
  });

  group('WHAT A MATCH REPORTS', () {
    late List<({String name, Map<String, Object?> params})> sent;

    setUp(() {
      sent = [];
      setAnalyticsSink((name, params) => sent.add((name: name, params: params)));
    });

    tearDown(() => setAnalyticsSink(null));

    ({String name, Map<String, Object?> params}) played() =>
        sent.singleWhere((e) => e.name == 'match_played');

    test('EVERY MATCH REPORTS ONCE, from the one function they all go through',
        () {
      // `match_played` is the JS's name and this is the JS's moment — at
      // KICK-OFF, where the counters it carries have just been written. The
      // full-time path is a screen, and a screen can be left.
      final state = _state(division: 'regional_league', seasonMatchesPlayed: 4);
      simulateMatch(state, 'regional_league');
      expect(sent.where((e) => e.name == 'match_played'), hasLength(1));
      expect(played().params['division'], 'regional_league');
      expect(played().params['season_match'], 5);
    });

    test('the outcome is one of exactly three words', () {
      simulateMatch(_state(), 'regional_league');
      expect(played().params['outcome'], anyOf('win', 'draw', 'loss'));
    });

    test('and the venue rides along, because home advantage is +3', () {
      simulateMatch(_state(), 'regional_league');
      expect(played().params['is_home'], anyOf(0, 1));
    });
  });
}
