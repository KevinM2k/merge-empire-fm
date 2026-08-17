/// Differential test: the Dart match orchestration against the JS it was ported
/// from — whole simulated matches, not functions.
///
/// Almost all of this function's risk is ORDERING. It draws the opponent's
/// rating, two injury rolls, the tactic's swing, the AI rotation plan, the
/// segment goals and then the entire event feed off one shared stream, and a
/// port that gets every formula right still comes out wrong if it draws them in
/// a different sequence. Comparing a whole match — result, feed and save — is
/// the only thing that catches that.
///
/// BOTH generators are pinned. The engine mixes the seeded gameplay stream with
/// bare `Math.random` and the split is load-bearing (see the header of
/// `engine/match_events.dart`), so the node dump replaces `Math.random` with a
/// second mulberry32 and the same stream is injected here. One instance feeds
/// both `match_events` and `match_orchestration`, because in the JS there is
/// only one `Math.random`.
///
/// See `tool/dump_match_orchestration_reference.mjs`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/match_events.dart';
import 'package:merge_empire_fc/engine/match_orchestration.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

import '../support/js_math_random.dart';

final Map<String, dynamic> ref = jsonDecode(
  File('test/fixtures/match_orchestration_reference.json').readAsStringSync(),
) as Map<String, dynamic>;

final Map<String, dynamic> refSave = jsonDecode(
  File('test/fixtures/quest_engine_reference.json').readAsStringSync(),
) as Map<String, dynamic>;

final int fixedNow = ref['fixedNow'] as int;

Map<String, dynamic> _scenario(String name) => ref[name] as Map<String, dynamic>;

/// Dart values through a JSON round trip, so ints, doubles and nested maps line
/// up with what the node dump wrote.
Object? _json(Object? v) => jsonDecode(jsonEncode(v));

Map<String, dynamic> _cloneMap(Object? v) =>
    jsonDecode(jsonEncode(v)) as Map<String, dynamic>;

/// The fields a match can move on a card. Mirrors the dump script's own list.
const _cardKeys = [
  'injured',
  'injuredAt',
  'injuryDurationMs',
  'form',
  'energy',
  'energyUpdatedAt',
  'stats',
];

/// The same slice of the save the dump script records — the pyramid and the
/// discovered-player log are the bulk of it and a match touches neither.
Map<String, dynamic> _digest(Map<String, dynamic> s) {
  final cells = (s['grid'] as Map)['cells'] as List;
  return {
    'cells': {
      for (final c in cells.whereType<Map<String, dynamic>>())
        '${c['instanceId']}': {
          for (final k in _cardKeys)
            if (c.containsKey(k)) k: c[k],
        },
    },
    'lineup': (s['squad'] as Map)['lineup'],
    'progression': {
      for (final e in (s['progression'] as Map).entries)
        if (e.key != 'leaguePyramid' && e.key != 'discoveredPlayers')
          '${e.key}': e.value,
    },
    'resources': s['resources'],
    'careerStats': s['careerStats'],
    'shop': s['shop'],
    'grudges': (s['transferMarket'] as Map)['grudges'],
  };
}

/// How a scenario's save differs from the reference one.
class Setup {
  const Setup({
    this.hardMode = false,
    this.aged = false,
    this.progression = const {},
    this.squad = const {},
    this.shop = const {},
    this.boosts = const {},
    this.grudges = const {},
  });

  final bool hardMode;

  /// A squad old enough that injuries actually land, in the most physical
  /// league — applied AFTER the overrides, exactly as the dump script wraps it.
  final bool aged;

  final Map<String, dynamic> progression;
  final Map<String, dynamic> squad;
  final Map<String, dynamic> shop;
  final Map<String, dynamic> boosts;
  final Map<String, dynamic> grudges;

  String get divisionId => aged ? 'champions_cup' : 'regional_league';
}

/// The save a scenario kicked off from.
///
/// The XI comes out of the fixture rather than through this port's own lineup
/// builder: that is a separate port with its own tests, and letting it feed
/// this one would confound two things at once.
Map<String, dynamic> _stateFor(String name, Setup setup) {
  final s = _cloneMap(refSave['state']);
  final prog = s['progression'] as Map<String, dynamic>;
  prog['matchesPlayed'] = 12;
  prog['matchesWon'] = 5;
  prog['matchesDrawn'] = 3;
  prog['seasonWins'] = 2;
  prog['seasonDraws'] = 1;
  prog['seasonLosses'] = 1;
  prog['seasonAwardedPlayed'] = 4;
  prog['trophiesTotal'] = 0;
  prog['lastMatchAt'] = fixedNow - 600000;
  prog['careerWins'] = 5;
  prog['careerDraws'] = 3;
  prog['careerGoalsFor'] = 14;
  s['careerStats'] = {
    'leagueWins': 0,
    'cupWins': 0,
    'matchesWon': 5,
    'totalMerges': 0,
  };

  final squad = s['squad'] as Map<String, dynamic>;
  squad['formation'] = '4-4-2';
  squad['lineup'] = _json(_scenario(name)['lineupBefore']);
  squad['strategyId'] = 'balanced';

  if (setup.hardMode) (s['settings'] as Map)['hardMode'] = true;
  prog.addAll(_cloneMap(_json(setup.progression)));
  squad.addAll(_cloneMap(_json(setup.squad)));
  (s['shop'] as Map).addAll(setup.shop);
  (s['boosts'] as Map).addAll(setup.boosts);
  ((s['transferMarket'] as Map)['grudges'] as Map)
      .addAll(_cloneMap(_json(setup.grudges)));

  if (setup.aged) {
    for (final c in (s['grid'] as Map)['cells'] as List) {
      if (c is Map) c['seasonsPlayed'] = 14;
    }
    prog['currentDivision'] = 'champions_cup';
  }
  return s;
}

/// Seed both streams the way the dump script did, then hand back the save.
Map<String, dynamic> _begin(String name, Setup setup) {
  final scenario = _scenario(name);
  final rng = JsMathRandom(scenario['mathSeed'] as int);
  // ONE instance for both, because the JS has one Math.random.
  setEventRandom(rng);
  setMatchRandom(rng);
  seeded.setSeed(scenario['seed'] as int);
  return _stateFor(name, setup);
}

void _expectResult(String name, Map<String, dynamic> got) {
  expect(_json(got), _scenario(name)['result'], reason: '$name — result');
}

void _expectState(String name, Map<String, dynamic> state) {
  final want = _scenario(name)['state'] as Map<String, dynamic>;
  expect(_json(_digest(state)), want, reason: '$name — save');
  // Key ORDER too: a save is compared byte for byte after a cloud round trip,
  // so a field first written in a different place is a real difference.
  expect(
    (_digest(state)['progression'] as Map).keys.toList(),
    (want['progression'] as Map).keys.toList(),
    reason: '$name — progression key order',
  );
}

/// Every scenario that is one plain call to [simulateMatch].
const _simScenarios = <String, Setup>{
  'easy_s1': Setup(),
  'easy_s7': Setup(),
  'easy_s12345': Setup(),
  'easy_s987654': Setup(),
  'hard_s1': Setup(hardMode: true),
  'hard_s7': Setup(hardMode: true),
  'hard_s12345': Setup(hardMode: true),
  'hard_s987654': Setup(hardMode: true),
  'luckyBoot': Setup(shop: {'luckyBootReady': true}),
  'grudge': Setup(
    grudges: {
      'regional_league_4': {'boost': 6, 'matches': 2},
    },
  ),
  'relegationZone': Setup(
    progression: {
      'seasonMatchesPlayed': 9,
      'playerTablePosition': 8,
      'opponentTablePositions': {'regional_league_2': 7},
      'stagnationBuffs': {'regional_league': 3},
    },
  ),
  'unrolledOpponent': Setup(
    progression: {'seasonCount': 9, 'seasonOpponentRatings': <String, int>{}},
  ),
  'noLineup': Setup(squad: {'lineup': <Object?>[]}),
  'noLineupHard': Setup(hardMode: true, squad: {'lineup': <Object?>[]}),
  'injuryEasy_s3': Setup(aged: true),
  'injuryEasy_s11': Setup(aged: true),
  'injuryEasy_s29': Setup(aged: true),
  'injuryEasy_s64': Setup(aged: true),
  'injuryHard_s3': Setup(aged: true, hardMode: true),
  'injuryHard_s11': Setup(aged: true, hardMode: true),
  'injuryHard_s29': Setup(aged: true, hardMode: true),
  'injuryHard_s64': Setup(aged: true, hardMode: true),
  'seasonCloses': Setup(progression: {'seasonMatchesPlayed': 13}),
};

/// Scenarios that simulate then settle, calling both entry points twice to
/// prove they are idempotent.
const _settleScenarios = <String, Setup>{
  'settleEasy_s2': Setup(),
  'settleEasy_s19': Setup(),
  'settleHard_s2': Setup(hardMode: true),
  'settleHard_s19': Setup(hardMode: true),
};

/// Scenarios that simulate then change tactic. Value is (setup, fromMinute,
/// strategyId).
const _resimScenarios = <String, (Setup, int, String)>{
  'resimEasy_s5_m45_allOutAttack': (Setup(), 45, 'allOutAttack'),
  'resimEasy_s5_m20_parkTheBus': (Setup(), 20, 'parkTheBus'),
  'resimEasy_s5_m80_counterAttack': (Setup(), 80, 'counterAttack'),
  'resimEasy_s13_m45_highPress': (Setup(), 45, 'highPress'),
  'resimEasy_s13_m89_balanced': (Setup(), 89, 'balanced'),
  'resimHard_s5_m45_allOutAttack': (Setup(hardMode: true), 45, 'allOutAttack'),
  'resimHard_s5_m20_parkTheBus': (Setup(hardMode: true), 20, 'parkTheBus'),
  'resimHard_s5_m80_counterAttack': (Setup(hardMode: true), 80, 'counterAttack'),
  'resimHard_s13_m45_highPress': (Setup(hardMode: true), 45, 'highPress'),
  'resimHard_s13_m89_balanced': (Setup(hardMode: true), 89, 'balanced'),
  'resimCancelsInjury_s3': (Setup(aged: true), 10, 'parkTheBus'),
  'resimCancelsInjury_s11': (Setup(aged: true), 10, 'parkTheBus'),
  'resimCancelsInjury_s29': (Setup(aged: true), 10, 'parkTheBus'),
};

void main() {
  setUp(() => setClock(() => fixedNow));
  tearDown(() {
    resetClock();
    resetEventRandom();
    resetMatchRandom();
  });

  group('simulateMatch', () {
    for (final entry in _simScenarios.entries) {
      test('${entry.key} matches the JS match, feed and save', () {
        final state = _begin(entry.key, entry.value);
        final result = simulateMatch(state, entry.value.divisionId);
        _expectResult(entry.key, result);
        _expectState(entry.key, state);
      });
    }

    test('forceWin matches the JS', () {
      const setup = Setup();
      final state = _begin('forceWin', setup);
      final result = simulateMatch(state, setup.divisionId, forceWin: true);
      _expectResult('forceWin', result);
      _expectState('forceWin', state);
    });
  });

  group('settlement', () {
    for (final entry in _settleScenarios.entries) {
      test('${entry.key} settles the same way, twice over', () {
        final state = _begin(entry.key, entry.value);
        final result = simulateMatch(state, entry.value.divisionId);
        finalizeMatchOutcome(state, result);
        // The second call has to be a no-op — full time reaches it from the
        // match screen AND from applyMatchRewards.
        finalizeMatchOutcome(state, result);
        applyMatchRewards(state, result);
        applyMatchRewards(state, result);
        _expectResult(entry.key, result);
        _expectState(entry.key, state);
      });
    }

    test('settleWin credits a win the JS way', () {
      const setup = Setup();
      final state = _begin('settleWin', setup);
      final result = simulateMatch(state, setup.divisionId, forceWin: true);
      applyMatchRewards(state, result);
      _expectResult('settleWin', result);
      _expectState('settleWin', state);
    });

    test('applyMatchRewards on its own settles everything', () {
      const setup = Setup();
      final state = _begin('rewardsOnly', setup);
      final result = simulateMatch(state, setup.divisionId);
      applyMatchRewards(state, result);
      _expectResult('rewardsOnly', result);
      _expectState('rewardsOnly', state);
    });
  });

  group('reSimulateRemainder', () {
    for (final entry in _resimScenarios.entries) {
      final (setup, fromMinute, strategyId) = entry.value;
      test('${entry.key} rewrites the match the JS way', () {
        final state = _begin(entry.key, setup);
        final result = simulateMatch(state, setup.divisionId);

        // What the kickoff sim produced, before the tactic change rewrote it.
        final want = _scenario(entry.key)['before'] as Map<String, dynamic>;
        expect(_json(result['homeGoals']), want['homeGoals']);
        expect(_json(result['awayGoals']), want['awayGoals']);
        expect(_json(result['injuryCount']), want['injuryCount']);
        expect(_json(result['injuryLog']), want['injuryLog']);

        final newEvents = reSimulateRemainder(
          result,
          fromMinute,
          strategyId,
          (result['homeGoals'] as num).toInt(),
          (result['awayGoals'] as num).toInt(),
          state,
        );
        expect(
          _json(newEvents),
          _scenario(entry.key)['newEvents'],
          reason: '${entry.key} — new events',
        );
        _expectResult(entry.key, result);
        _expectState(entry.key, state);
      });
    }

    for (final strategyId in ['balanced', 'allOutAttack', 'parkTheBus']) {
      test('an event cup runs off its fixed rating — $strategyId', () {
        final name = 'resimFixedRating_$strategyId';
        final state = _begin(name, const Setup());
        // Strength is the chosen nation's rating, never the club squad's, and no
        // goal is credited to a club player.
        final result = <String, dynamic>{
          'divisionId': 'regional_league',
          'isCup': true,
          'fixedRating': true,
          'anonymousPlayers': true,
          'squadRating': 74,
          'isHome': true,
          'effOppAttackRating': 70,
          'effOppDefenceRating': 71,
          'opponentRating': 70,
          'addedTime': 3,
          'homeGoals': 0,
          'awayGoals': 0,
          'events': <Object?>[],
          'injuryLog': <Object?>[],
        };
        final newEvents =
            reSimulateRemainder(result, 0, strategyId, 0, 0, state);
        expect(_json(newEvents), _scenario(name)['newEvents']);
        _expectResult(name, result);
      });
    }

    test('a level cup tie goes to penalties', () {
      const name = 'resimCupShootout';
      final state = _begin(name, const Setup());
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
        'oppAttackRatio': 0.45,
      };
      // Past the final whistle, so nothing more is scored and the tie is still
      // level — the only way to reach the shootout branch.
      final newEvents = reSimulateRemainder(result, 92, 'balanced', 1, 1, state);
      expect(_json(newEvents), _scenario(name)['newEvents']);
      _expectResult(name, result);
    });
  });

  group('hardLiveRatings', () {
    test('matches the JS at every minute, and rebuilds minutes played', () {
      const name = 'hardLive';
      const setup = Setup(aged: true, hardMode: true);
      final state = _begin(name, setup);
      final result = simulateMatch(state, setup.divisionId);
      final at = _scenario(name)['at'] as Map<String, dynamic>;
      for (final minute in [0, 20, 45, 70, 90]) {
        final live = hardLiveRatings(result, minute, state, 'balanced');
        expect(
          {'attack': live.attack, 'defence': live.defence},
          at['$minute'],
          reason: 'live ratings at $minute',
        );
        expect(
          _json(((result['hardSim'] as Map)['minutesPlayed'])),
          at['minutesPlayed_$minute'],
          reason: 'minutes played after reading $minute',
        );
      }
      _expectResult(name, result);
    });
  });

  group('bestFormationForFixture', () {
    /// The squads the reference ranked, by the label it used.
    Map<String, dynamic> squadFor(String label) {
      switch (label) {
        case 'refSave':
          return _stateForBest(label, const Setup());
        case 'refSaveHome':
          return _stateForBest(
            label,
            const Setup(progression: {'seasonMatchesPlayed': 5}),
          );
        case 'unrolled':
          return _stateForBest(
            label,
            const Setup(
              progression: {
                'seasonCount': 9,
                'seasonOpponentRatings': <String, int>{},
              },
            ),
          );
        case 'attackTactic':
          return _stateForBest(
            label,
            const Setup(squad: {'strategyId': 'allOutAttack'}),
          );
        case 'bareEleven':
          return _tierSquad(4, 11);
        case 'strong':
          return _tierSquad(8, 15);
      }
      throw ArgumentError(label);
    }

    for (final row in ref['bestFormation'] as List) {
      final r = row as Map<String, dynamic>;
      test('picks the same shape and XI for ${r['label']}', () {
        seeded.setSeed(1);
        final rng = JsMathRandom(1);
        setEventRandom(rng);
        setMatchRandom(rng);
        final best = bestFormationForFixture(
          squadFor('${r['label']}'),
          divisionId: 'regional_league',
        );
        expect(best.formationId, r['formationId']);
        expect(best.points, closeTo(r['points'] as num, 1e-12));
        expect(
          [
            for (final s in best.lineup)
              {
                'slotId': s.slotId,
                'slotPosition': s.slotPosition,
                'cardInstanceId': s.cardInstanceId,
              },
          ],
          r['lineup'],
        );
      });
    }
  });

  group('cooldowns', () {
    Map<String, dynamic> stateFor(String label) {
      switch (label) {
        case 'ready':
          return _stateForBest(label, const Setup());
        case 'justPlayed':
          return _stateForBest(
            label,
            Setup(progression: {'lastMatchAt': fixedNow}),
          );
        case 'vip':
          return _stateForBest(
            label,
            Setup(
              progression: {'lastMatchAt': fixedNow},
              boosts: {'vipActive': true, 'vipExpiresAt': fixedNow + 60000},
            ),
          );
        case 'vipExpired':
          return _stateForBest(
            label,
            Setup(
              progression: {'lastMatchAt': fixedNow},
              boosts: {'vipActive': true, 'vipExpiresAt': fixedNow - 1},
            ),
          );
        case 'freeWindow':
          return _stateForBest(
            label,
            Setup(
              progression: {'lastMatchAt': fixedNow},
              boosts: {'matchCooldownFreeUntil': fixedNow + 60000},
            ),
          );
        case 'seasonComplete':
          return _stateForBest(
            label,
            const Setup(progression: {'seasonComplete': true}),
          );
        case 'thinLineup':
          return _stateForBest(
            label,
            const Setup(
              squad: {
                'lineup': [
                  {
                    'slotId': 'gk',
                    'slotPosition': 'GK',
                    'cardInstanceId': 'c0',
                  },
                  {
                    'slotId': 'rb',
                    'slotPosition': 'DEF',
                    'cardInstanceId': null,
                  },
                ],
              },
            ),
          );
        case 'championsCup':
          return _stateForBest(
            label,
            Setup(
              progression: {
                'currentDivision': 'champions_cup',
                'lastMatchAt': fixedNow,
              },
            ),
          );
      }
      throw ArgumentError(label);
    }

    for (final row in ref['cooldowns'] as List) {
      final r = row as Map<String, dynamic>;
      test('${r['label']} gates the Play button the JS way', () {
        final state = stateFor('${r['label']}');
        expect(effectiveCooldownMs(state), r['effectiveCooldownMs']);
        expect(canPlayMatch(state), r['canPlayMatch']);
        expect(matchCooldownRemaining(state), r['matchCooldownRemaining']);
        startMatchCooldown(state);
        final after = r['afterStart'] as Map<String, dynamic>;
        expect(
          (state['progression'] as Map)['lastMatchAt'],
          after['lastMatchAt'],
        );
        expect(canPlayMatch(state), after['canPlayMatch']);
      });
    }

    test('startMatchCooldown only ever pushes the clock later', () {
      final state = _stateForBest(
        'cooldownFloor',
        Setup(progression: {'lastMatchAt': fixedNow + 999999}),
      );
      startMatchCooldown(state);
      expect(
        (state['progression'] as Map)['lastMatchAt'],
        (ref['cooldownFloor'] as Map)['lastMatchAt'],
      );
    });

    test('survives a state with no progression at all', () {
      expect(() => startMatchCooldown(<String, dynamic>{}), returnsNormally);
    });
  });
}

/// A save built the same way as [_stateFor] but with the XI from this port's own
/// builder, for the cases the reference did not simulate a match for.
Map<String, dynamic> _stateForBest(String label, Setup setup) {
  final s = _cloneMap(refSave['state']);
  final prog = s['progression'] as Map<String, dynamic>;
  prog['matchesPlayed'] = 12;
  prog['matchesWon'] = 5;
  prog['matchesDrawn'] = 3;
  prog['seasonWins'] = 2;
  prog['seasonDraws'] = 1;
  prog['seasonLosses'] = 1;
  prog['seasonAwardedPlayed'] = 4;
  prog['trophiesTotal'] = 0;
  prog['lastMatchAt'] = fixedNow - 600000;
  prog['careerWins'] = 5;
  prog['careerDraws'] = 3;
  prog['careerGoalsFor'] = 14;
  s['careerStats'] = {
    'leagueWins': 0,
    'cupWins': 0,
    'matchesWon': 5,
    'totalMerges': 0,
  };
  final squad = s['squad'] as Map<String, dynamic>;
  squad['formation'] = '4-4-2';
  squad['strategyId'] = 'balanced';
  squad['lineup'] = _json(_baseLineup);
  if (setup.hardMode) (s['settings'] as Map)['hardMode'] = true;
  prog.addAll(_cloneMap(_json(setup.progression)));
  squad.addAll(_cloneMap(_json(setup.squad)));
  (s['boosts'] as Map).addAll(setup.boosts);
  return s;
}

/// The 4-4-2 XI every un-simulated scenario starts from — taken from a scenario
/// that shipped it, so it is still the JS builder's answer.
final Object? _baseLineup = _scenario('easy_s1')['lineupBefore'];

/// A squad of `count` cards all at `tier`, matching the dump script's own.
Map<String, dynamic> _tierSquad(int tier, int count) {
  final s = _stateForBest('tier', const Setup());
  final cells = (s['grid'] as Map)['cells'] as List;
  for (var i = 0; i < cells.length; i++) {
    final c = cells[i];
    if (c == null || i >= count) {
      cells[i] = null;
      continue;
    }
    final pos = '${(c as Map)['definitionId']}'.split('_').last;
    c['definitionId'] = 'player_t${tier}_$pos';
  }
  return s;
}
