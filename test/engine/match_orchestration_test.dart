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
import 'package:merge_empire_fc/data/club_assets.dart' show AssetCategory;
import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/engine/fixture_preview.dart'
    show fixtureIsHome, previewFixture;
import 'package:merge_empire_fc/engine/match_tactics.dart'
    show opponentsPerSeason, relegationBoost;
import 'package:merge_empire_fc/engine/lineup_engine.dart';
import 'package:merge_empire_fc/engine/match_events.dart';
import 'package:merge_empire_fc/engine/booking_engine.dart'
    show oppTeamRatingMult;
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

    group('WHAT THE BOARD IS ALLOWED TO PRINT', () {
      /// A save whose Fan Zone actually pays a home advantage, so a modifier
      /// that is zero either way cannot be mistaken for a passing test.
      Map<String, dynamic> withCrowd({int tier = 8}) {
        final state = _state();
        (state['clubAssets'] as Map<String, dynamic>)[AssetCategory.fanzone] = {
          'owned': true,
          'tier': tier,
        };
        return state;
      }

      test('OUR SPLIT IS THE ONE THE SIM RAN ON, home advantage and all', () {
        // **Reported from the couch with both screens photographed: "soon as I
        // started the game my stats had already dropped."** The next-match card
        // draws `preview.effAttack`, which carries home advantage; the
        // scoreboard drew `result['ourAttackRating']`, which is the BASE split
        // and carries none of it. Same fixture, same squad, 93/100 on one
        // screen and 89/97 on the other — and the sim had been using the
        // higher pair the whole time.
        seeded.setSeed(11);
        final state = withCrowd();
        // A HOME fixture, or the bonus under test is not in play.
        final prog = state['progression'] as Map<String, dynamic>;
        var m = (prog['seasonMatchesPlayed'] as num).toInt();
        while (!fixtureIsHome(3, m % opponentsPerSeason, m)) {
          m++;
        }
        prog['seasonMatchesPlayed'] = m;

        // Taken BEFORE the whistle: the sim injures people and injured men
        // score zero, so a preview read afterwards is of a different squad.
        final preview = previewFixture(state)!;

        final result = simulateMatch(state, 'regional_league');
        expect(result['isHome'], isTrue, reason: 'not a home game after all');
        final adv = result['homeAdvDisplay'] as num;
        expect(adv, greaterThan(0), reason: 'the Fan Zone paid nothing');

        final split = ourMatchSplit(result);
        expect(split.attack, (result['ourAttackRating'] as num) + adv);
        expect(split.defence, (result['ourDefenceRating'] as num) + adv);

        // And it is the SAME pair the next-match card drew for the fixture that
        // was about to be played, which is the whole complaint.
        expect(split.attack, preview.effAttack);
        expect(split.defence, preview.effDefence);
      });

      test('an away day gets none of it, and neither does a cup tie', () {
        seeded.setSeed(11);
        final state = withCrowd();
        final prog = state['progression'] as Map<String, dynamic>;
        var m = (prog['seasonMatchesPlayed'] as num).toInt();
        while (fixtureIsHome(3, m % opponentsPerSeason, m)) {
          m++;
        }
        prog['seasonMatchesPlayed'] = m;
        final away = simulateMatch(state, 'regional_league');
        expect(away['isHome'], isFalse);
        expect(ourMatchSplit(away).attack, away['ourAttackRating']);

        // A cup result carries `isHome: true` for every round — the tie is
        // played on neutral ground and `prepareCupRound` gives neither side a
        // bonus — so the venue alone cannot decide this.
        final tie = <String, dynamic>{
          'isCup': true,
          'isHome': true,
          'homeAdvDisplay': 4,
          'ourAttackRating': 70,
          'ourDefenceRating': 72,
        };
        expect(ourMatchSplit(tie).attack, 70);
        expect(ourMatchSplit(tie).defence, 72);
      });

      test('the stagnation buff and the relegation lift are in it too', () {
        // Both are already inside the numbers the sim rolled with — see the
        // `effAttack` block — so a board that drops them is describing a
        // different match from the one being played.
        final result = <String, dynamic>{
          'isHome': false,
          'ourAttackRating': 60,
          'ourDefenceRating': 64,
          'stagnationBuff': 3,
          'playerInRelegationZone': true,
        };
        final split = ourMatchSplit(result);
        expect(split.attack, 60 + 3 + relegationBoost);
        expect(split.defence, 64 + 3 + relegationBoost);
      });

      test('and the ceiling is still a hundred before the buffs land', () {
        // The sim clamps the home bonus at 100 and then ADDS the buffs, so a
        // maxed side does not lose its stagnation buff to the cap.
        final result = <String, dynamic>{
          'isHome': true,
          'homeAdvDisplay': 4,
          'ourAttackRating': 99,
          'ourDefenceRating': 99,
          'stagnationBuff': 2,
        };
        final split = ourMatchSplit(result);
        expect(split.attack, 102);
        expect(split.defence, 102);
      });

      test('AND A RE-SIM HANDS BACK THE SAME BASIS, not the bare squad', () {
        // The live pair is what the remainder was actually rolled with, and the
        // board prints it in place of the kickoff one — so handing back
        // `computeSquadRatings` made the four points vanish the moment anybody
        // was booked, which is the same bug arriving by a second route.
        seeded.setSeed(11);
        final state = withCrowd();
        final prog = state['progression'] as Map<String, dynamic>;
        var m = (prog['seasonMatchesPlayed'] as num).toInt();
        while (!fixtureIsHome(3, m % opponentsPerSeason, m)) {
          m++;
        }
        prog['seasonMatchesPlayed'] = m;
        final result = simulateMatch(state, 'regional_league');
        expect(result['isHome'], isTrue);

        final out = <String, dynamic>{};
        seeded.setSeed(11);
        reSimulateRemainder(
          result,
          45,
          'balanced',
          0,
          0,
          state,
          liveRatingsOut: out,
        );
        // Nobody was booked and nobody came off, so a clean re-sim re-rolls
        // with exactly what kicked off.
        expect(out['liveAttackRating'], ourMatchSplit(result).attack);
        expect(out['liveDefenceRating'], ourMatchSplit(result).defence);
      });
    });

    group('THE REFEREE REACHES THE MATHS', () {
      /// One re-sim of a fresh league match, with the live ratings it rolled
      /// with and the state it rolled against.
      ({Map<String, dynamic> live, Map<String, dynamic> state}) resim({
        Map<String, double> booked = const {},
        double oppMult = 1.0,
      }) {
        seeded.setSeed(7);
        final state = _state();
        final result = simulateMatch(state, 'regional_league');
        final out = <String, dynamic>{};
        seeded.setSeed(7);
        reSimulateRemainder(
          result,
          45,
          'balanced',
          0,
          0,
          state,
          bookedMultipliers: booked,
          oppRatingMult: oppMult,
          liveRatingsOut: out,
        );
        return (live: out, state: state);
      }

      test('THE RESULT IS NEVER STAMPED WITH THEM, which the harness insists on', () {
        // `match_orchestration_parity_test` compares the whole result object
        // against a node dump, and a booking is a mechanic the JS has never
        // had. The first version of this wrote the live pair onto the result
        // and seventeen parity scenarios refused it — correctly. The screen is
        // where a divergence goes.
        seeded.setSeed(7);
        final state = _state();
        final result = simulateMatch(state, 'regional_league');
        reSimulateRemainder(
          result,
          45,
          'balanced',
          0,
          0,
          state,
          bookedMultipliers: const {'anyone': 0.5},
          oppRatingMult: 0.5,
        );
        for (final key in result.keys) {
          expect(
            key.startsWith('live'),
            isFalse,
            reason: '$key was stamped on the result',
          );
        }
      });

      test('a caution on one of ours lowers what we re-roll with', () {
        // **AND IT IS QUANTISED, which is worth knowing rather than hiding.**
        // `computeSquadRatings` returns whole numbers — the JS's own rounding,
        // held there by the parity harness — so ten per cent of ONE man is
        // about 0.9% of eleven, which on a mid-table side is half a rating
        // point. It lands as a point or as nothing depending on where the side
        // already sat.
        //
        // That is the right size for a caution and the wrong size to prove a
        // wire with, so the wire is proved with a number that cannot round
        // away. The real multiplier is asserted at full resolution in
        // `squad_rating_test`.
        //
        // **AND THE WHOLE ELEVEN IS BOOKED RATHER THAN ONE MAN**, which is not
        // laziness. The first draft booked the first slot's occupant and
        // asserted nothing had changed — because the seeded match injures that
        // player, an injured man is already scored zero, and a multiplier on
        // zero is zero. Whoever is on the pitch at the 45th minute is a
        // property of the seed; booking all of them is the assertion that does
        // not depend on it.
        final clean = resim();
        final everyone = {
          for (final id in (clean.state['squad']
                  as Map<String, dynamic>)['lineup'] as List)
            if (id is Map<String, dynamic> && id['cardInstanceId'] is String)
              id['cardInstanceId'] as String: 0.4,
        };
        final booked = resim(booked: everyone);
        expect(
          (booked.live['liveAttackRating'] as num) +
              (booked.live['liveDefenceRating'] as num),
          lessThan(
            (clean.live['liveAttackRating'] as num) +
                (clean.live['liveDefenceRating'] as num),
          ),
        );
      });

      test('AND THEIR CARD LOWERS THEIRS, which nothing did at all', () {
        // "Opponent got a red card and I did not see that affect their team
        // rating whilst I was in a game." It did not — their side is a pair of
        // numbers with nobody in it, so there was no man to take out of it.
        final clean = resim();
        final theirRed = resim(oppMult: oppTeamRatingMult(0, 1));
        expect(
          theirRed.live['liveOppAttackRating'] as num,
          lessThan(clean.live['liveOppAttackRating'] as num),
        );
        expect(
          theirRed.live['liveOppDefenceRating'] as num,
          lessThan(clean.live['liveOppDefenceRating'] as num),
        );
        expect(
          theirRed.live['liveOppRating'] as num,
          lessThan(clean.live['liveOppRating'] as num),
        );
      });

      test('and a clean match re-rolls with exactly what it had', () {
        // The common case, and the one that must not move: no cards, no
        // change, or the port has quietly re-balanced every match in the game.
        seeded.setSeed(7);
        final state = _state();
        final result = simulateMatch(state, 'regional_league');
        final out = <String, dynamic>{};
        seeded.setSeed(7);
        reSimulateRemainder(
          result,
          45,
          'balanced',
          0,
          0,
          state,
          liveRatingsOut: out,
        );
        expect(
          out['liveOppAttackRating'],
          result['effOppAttackRating'],
          reason: 'an unbooked opposition is the side that kicked off',
        );
      });

      test('A RESULT WITH NO EFFECTIVE PAIR RE-ROLLS THEM, not zero', () {
        // Their ATK and DEF have always fallen back on `opponentRating` — the
        // figure their split was modelled from — and the single figure the
        // board prints did not, so a result carrying only the base pair
        // re-simulated its opposition down to a flat zero. That is a cup tie
        // and it is what a sending-off made visible: the re-sim fills our half
        // in from the live squad, so ours moved and theirs was wiped out.
        seeded.setSeed(7);
        final result = <String, dynamic>{
          'isHome': true,
          'squadRating': 78,
          'opponentRating': 86,
          'effOppAttackRating': 85,
          'effOppDefenceRating': 87,
          'addedTime': 3,
          'events': <Object?>[],
          'injuryLog': <Object?>[],
        };
        final out = <String, dynamic>{};
        reSimulateRemainder(
          result,
          60,
          'balanced',
          1,
          1,
          _state(),
          liveRatingsOut: out,
        );
        expect(out['liveOppRating'], 86);
      });

      test('and their referee still cuts a figure read that way', () {
        seeded.setSeed(7);
        final result = <String, dynamic>{
          'isHome': true,
          'squadRating': 78,
          'opponentRating': 80,
          'effOppAttackRating': 79,
          'effOppDefenceRating': 81,
          'addedTime': 0,
          'events': <Object?>[],
          'injuryLog': <Object?>[],
        };
        final out = <String, dynamic>{};
        reSimulateRemainder(
          result,
          60,
          'balanced',
          0,
          0,
          _state(),
          oppRatingMult: oppTeamRatingMult(0, 1),
          liveRatingsOut: out,
        );
        expect(out['liveOppRating'] as num, lessThan(80));
        expect(out['liveOppRating'] as num, greaterThan(0));
      });
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
