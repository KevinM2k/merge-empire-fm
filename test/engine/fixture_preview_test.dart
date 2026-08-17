import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/fixture_preview.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';

final Map<String, dynamic> _ref = jsonDecode(
  File('test/fixtures/fixture_preview_reference.json').readAsStringSync(),
) as Map<String, dynamic>;

/// The same realistic save the quest fixture ships.
Map<String, dynamic> _state() =>
    jsonDecode(
          File('test/fixtures/quest_engine_reference.json').readAsStringSync(),
        )['state']
        as Map<String, dynamic>;

Map<String, dynamic> _prog(Map<String, dynamic> s) =>
    s['progression'] as Map<String, dynamic>;

/// The scenario mutations, mirrored from the node script.
final Map<String, Map<String, dynamic> Function(Map<String, dynamic>)> _scenarios = {
  'plain': (s) => s,
  'awayLeg': (s) {
    _prog(s)['seasonMatchesPlayed'] = 9;
    return s;
  },
  'unrolledOpponent': (s) {
    _prog(s)['seasonOpponentRatings'] = <String, dynamic>{};
    return s;
  },
  'luckyBoot': (s) {
    (s['shop'] as Map<String, dynamic>)['luckyBootReady'] = true;
    return s;
  },
  'grudge': (s) {
    (s['transferMarket'] as Map<String, dynamic>)['grudges'] = {
      'regional_league_4': {'boost': 3},
    };
    return s;
  },
  'stagnation': (s) {
    _prog(s)['stagnationBuffs'] = {'regional_league': 5};
    return s;
  },
  'bothRelegationZones': (s) {
    _prog(s)['seasonMatchesPlayed'] = 9;
    _prog(s)['playerTablePosition'] = 8;
    _prog(s)['opponentTablePositions'] = {'regional_league_2': 8};
    return s;
  },
  'championsCup': (s) {
    _prog(s)['currentDivision'] = 'champions_cup';
    _prog(s)['stagnationBuffs'] = {'champions_cup': 9};
    return s;
  },
  'proMode': (s) {
    (s['settings'] as Map<String, dynamic>)['hardMode'] = true;
    return s;
  },
  'noLineup': (s) {
    (s['squad'] as Map<String, dynamic>)['lineup'] = <dynamic>[];
    return s;
  },
  'emptySquad': (s) {
    (s['grid'] as Map<String, dynamic>)['cells'] = <dynamic>[];
    return s;
  },
};

void main() {
  group('parity with the JS', () {
    test('every scenario matches, field for field', () {
      // Pure rating arithmetic — home advantage, stagnation, the relegation
      // boost, the Lucky Boot and a grudge, layered in a particular order —
      // which is exactly what drifts a point or two between two languages and
      // quietly changes which quests get handed out.
      final want = _ref['scenarios'] as Map<String, dynamic>;
      expect(_scenarios.keys.toSet(), want.keys.toSet());

      for (final entry in _scenarios.entries) {
        final p = previewFixture(entry.value(_state()));
        final w = want[entry.key] as Map<String, dynamic>?;
        if (w == null) {
          expect(p, isNull, reason: entry.key);
          continue;
        }
        expect(p, isNotNull, reason: entry.key);
        final reason = entry.key;
        expect(p!.oppIdx, w['oppIdx'], reason: reason);
        expect(p.opponentName, w['opponentName'], reason: reason);
        expect(p.isHome, w['isHome'], reason: reason);
        expect(p.squadRating, w['squadRating'], reason: reason);
        expect(p.ourAttackRating, w['ourAttackRating'], reason: reason);
        expect(p.ourDefenceRating, w['ourDefenceRating'], reason: reason);
        expect(p.effAttack, closeTo((w['effAttack'] as num).toDouble(), 1e-9),
            reason: reason);
        expect(p.effDefence, closeTo((w['effDefence'] as num).toDouble(), 1e-9),
            reason: reason);
        expect(
          p.effectiveSquadRating,
          closeTo((w['effectiveSquadRating'] as num).toDouble(), 1e-9),
          reason: reason,
        );
        expect(p.opponentRating, w['opponentRating'], reason: reason);
        _closeOrNull(p.effectiveOppRating, w['effectiveOppRating'], reason);
        _closeOrNull(p.effOppAttackRating, w['effOppAttackRating'], reason);
        _closeOrNull(p.effOppDefenceRating, w['effOppDefenceRating'], reason);
        expect(p.oppAttackRatio, w['oppAttackRatio'], reason: reason);
        expect(p.grudgeBoost, w['grudgeBoost'] ?? 0, reason: reason);
      }
    });

    test('the home/away seed matches across three seasons of fixtures', () {
      for (final entry in (_ref['fixtureIsHome'] as Map<String, dynamic>).entries) {
        final parts = entry.key.split('|');
        final season = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        expect(
          fixtureIsHome(season, m % opponentsPerSeason, m),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('the attack-ratio lookup matches', () {
      final want = _ref['attackRatio'] as Map<String, dynamic>;
      expect(
        getOpponentAttackRatio(_state(), 'regional_league_3'),
        want['known'],
      );
      expect(getOpponentAttackRatio(_state(), 'Nobody FC'), want['unknown']);

      final legacy = _state();
      (_prog(legacy)['leaguePyramid'] as Map<String, dynamic>)['regional_league']
          [0] = <String, dynamic>{
        'name': 'Legacy FC',
        'rating': 50,
        'attackBias': 1.5,
      };
      expect(
        getOpponentAttackRatio(legacy, 'Legacy FC'),
        closeTo((want['legacyBias'] as num).toDouble(), 1e-12),
      );

      final noPyramid = _state();
      _prog(noPyramid).remove('leaguePyramid');
      expect(
        getOpponentAttackRatio(noPyramid, 'regional_league_3'),
        want['noPyramid'],
      );
    });
  });

  group('fixtureIsHome', () {
    test('the second leg reverses the first', () {
      for (var opp = 0; opp < opponentsPerSeason; opp++) {
        expect(
          fixtureIsHome(3, opp, opp + opponentsPerSeason),
          isNot(fixtureIsHome(3, opp, opp)),
          reason: 'opponent $opp',
        );
      }
    });

    test('a season plays as many at home as away', () {
      for (final season in [1, 2, 3, 9]) {
        final home = [
          for (var m = 0; m < matchesPerSeason; m++)
            if (fixtureIsHome(season, m % opponentsPerSeason, m)) m,
        ];
        expect(home.length, matchesPerSeason ~/ 2, reason: 'season $season');
      }
    });
  });

  group('the preview itself', () {
    test('nothing is written back to the save', () {
      // A preview must never eat a one-shot buff, and it must never seed a
      // rating either.
      final state = _state();
      (state['shop'] as Map<String, dynamic>)['luckyBootReady'] = true;
      (state['transferMarket'] as Map<String, dynamic>)['grudges'] = {
        'regional_league_4': {'boost': 3},
      };
      final before = jsonEncode(state);
      previewFixture(state);
      expect(jsonEncode(state), before);
    });

    test('an unrolled opponent reports null, never zero', () {
      // Saying zero would read as "they're terrible".
      final state = _state();
      _prog(state)['seasonOpponentRatings'] = <String, dynamic>{};
      final p = previewFixture(state)!;
      expect(p.opponentRating, isNull);
      expect(p.effectiveOppRating, isNull);
      expect(p.effOppAttackRating, isNull);
      expect(p.effOppDefenceRating, isNull);
      // Our own half is still known.
      expect(p.squadRating, greaterThan(0));
    });

    test('the Lucky Boot weakens them without being spent', () {
      final plain = previewFixture(_state())!;
      final state = _state();
      (state['shop'] as Map<String, dynamic>)['luckyBootReady'] = true;
      final boosted = previewFixture(state)!;
      expect(boosted.opponentRating!, lessThan(plain.opponentRating!));
      expect(state['shop']['luckyBootReady'], isTrue);
    });

    test('a grudge lifts every one of their numbers', () {
      final plain = previewFixture(_state())!;
      final state = _state();
      (state['transferMarket'] as Map<String, dynamic>)['grudges'] = {
        plain.opponentName: {'boost': 3},
      };
      final fired = previewFixture(state)!;
      expect(fired.grudgeBoost, 3);
      expect(fired.effectiveOppRating!, greaterThan(plain.effectiveOppRating!));
      expect(fired.effOppAttackRating!, greaterThan(plain.effOppAttackRating!));
      expect(fired.effOppDefenceRating!, greaterThan(plain.effOppDefenceRating!));
    });

    test('stagnation lifts ours', () {
      final plain = previewFixture(_state())!;
      final state = _state();
      _prog(state)['stagnationBuffs'] = {'regional_league': 5};
      final stuck = previewFixture(state)!;
      expect(stuck.effAttack, plain.effAttack + 5);
      expect(stuck.effDefence, plain.effDefence + 5);
      expect(stuck.effectiveSquadRating, plain.effectiveSquadRating + 5);
    });

    test('the top flight has no stagnation buff at all', () {
      // It has no promotion to escape by, so the buff would accumulate for
      // ever.
      final state = _state();
      _prog(state)['currentDivision'] = 'champions_cup';
      _prog(state)['stagnationBuffs'] = {'champions_cup': 9};
      final plainState = _state();
      _prog(plainState)['currentDivision'] = 'champions_cup';
      expect(
        previewFixture(state)!.effAttack,
        previewFixture(plainState)!.effAttack,
      );
    });

    test('home advantage only applies at home', () {
      final home = _state();
      _prog(home)['seasonMatchesPlayed'] = 0;
      final away = _state();
      _prog(away)['seasonMatchesPlayed'] = 7;
      final a = previewFixture(home)!;
      final b = previewFixture(away)!;
      expect(a.isHome, isNot(b.isHome));
      final atHome = a.isHome ? a : b;
      final awayDay = a.isHome ? b : a;
      expect(atHome.effAttack, greaterThan(awayDay.effAttack));
    });

    test("their defence has a floor ours does not", () {
      // A side with no defence at all would hand an unbounded rate through the
      // lambda curve.
      final state = _state();
      _prog(state)['seasonOpponentRatings'] = {'s3_o4': 1};
      expect(previewFixture(state)!.effOppDefenceRating, greaterThanOrEqualTo(10));
    });

    test('an empty squad still previews rather than crashing', () {
      final state = _state();
      (state['grid'] as Map<String, dynamic>)['cells'] = <dynamic>[];
      final p = previewFixture(state)!;
      expect(p.squadRating, 0);
      expect(p.opponentName, isNotEmpty);
    });

    test('a save with no progression has no fixture', () {
      expect(previewFixture(<String, dynamic>{}), isNull);
      expect(previewFixture(null), isNull);
    });

    test('a division can be asked for explicitly', () {
      final state = _state();
      final own = previewFixture(state)!;
      final top = previewFixture(state, 'champions_cup')!;
      // The opponent is the same club; what changes is the implied stadium
      // behind their home advantage.
      expect(top.opponentName, own.opponentName);
      expect(top.effOppAttackRating, greaterThan(own.effOppAttackRating!));
    });

    test('an opponent index past the list still names something', () {
      final state = _state();
      _prog(state)['seasonOpponents'] = <dynamic>[];
      expect(previewFixture(state)!.opponentName, 'Opponent');
    });
  });
}

void _closeOrNull(double? got, Object? want, String reason) {
  if (want == null) {
    expect(got, isNull, reason: reason);
  } else {
    expect(got, closeTo((want as num).toDouble(), 1e-9), reason: reason);
  }
}
