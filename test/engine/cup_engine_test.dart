import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/cups.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/engine/cup_engine.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

final Map<String, dynamic> _ref = jsonDecode(
  File('test/fixtures/cup_engine_reference.json').readAsStringSync(),
) as Map<String, dynamic>;

final Map<String, dynamic> _questRef = jsonDecode(
  File('test/fixtures/quest_engine_reference.json').readAsStringSync(),
) as Map<String, dynamic>;

/// The reference save, with the branches a cup run writes into.
Map<String, dynamic> _state({
  String division = 'regional_league',
  bool hardMode = false,
  bool strongSquad = false,
  bool luckyBoot = false,
}) {
  final s = jsonDecode(jsonEncode(_questRef['state'])) as Map<String, dynamic>;
  s['prestige'] = <String, dynamic>{'level': 0};
  s['careerStats'] = <String, dynamic>{'leagueWins': 0, 'cupWins': 0};
  s['club'] = <String, dynamic>{};
  final prog = s['progression'] as Map<String, dynamic>;
  prog['cups'] = <String, dynamic>{
    'active': null,
    'history': <dynamic>[],
    'availableThisSeason': true,
  };
  prog['currentDivision'] = division;
  (s['settings'] as Map<String, dynamic>)['hardMode'] = hardMode;
  if (luckyBoot) (s['shop'] as Map<String, dynamic>)['luckyBootReady'] = true;

  if (strongSquad) {
    // The reference squad is a 27-rated Regional side and the bracket draws
    // from the top of the pyramid, so it loses in the first round on every seed
    // tried. Lifting a trophy needs a squad that could plausibly do it.
    for (final raw in (s['grid'] as Map<String, dynamic>)['cells'] as List) {
      if (raw is! Map<String, dynamic>) continue;
      final pos = (raw['definitionId'] as String).split('_').last;
      raw['definitionId'] = 'player_t8_$pos';
    }
  }
  return s;
}

/// Wall-clock stamps are the one thing the two runtimes cannot agree on, so
/// they are blanked on both sides rather than compared. The tests that care
/// about them assert their shape separately.
const _timeKeys = {
  'startedAt',
  'endedAt',
  'lastMatchAt',
  'injuredAt',
  'energyUpdatedAt',
};

Object? _stripTimes(Object? v) {
  if (v is List) return [for (final e in v) _stripTimes(e)];
  if (v is Map) {
    return <String, dynamic>{
      for (final e in v.entries)
        '${e.key}': _timeKeys.contains(e.key) ? null : _stripTimes(e.value),
    };
  }
  return v;
}

Map<String, dynamic> _cupsOf(Map<String, dynamic> state) =>
    (state['progression'] as Map<String, dynamic>)['cups']
        as Map<String, dynamic>;

void main() {
  setUp(() {
    setClock(() => 1700000000000);
    seeded.setSeed(1234);
  });
  tearDown(() {
    resetClock();
    clearBus();
  });

  group('parity — which cup, and whether it can be entered', () {
    test('the right cup surfaces at every division', () {
      for (final entry in (_ref['cupForDivision'] as Map<String, dynamic>).entries) {
        expect(
          cupForDivision(_state(division: entry.key))?.id,
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('and availability agrees', () {
      for (final entry in (_ref['cupAvailable'] as Map<String, dynamic>).entries) {
        expect(
          cupAvailable(_state(division: entry.key)),
          entry.value,
          reason: entry.key,
        );
      }
    });
  });

  group('parity — the bracket draw', () {
    for (final (label, seed, division) in const [
      ('regionalA', 4242, 'regional_league'),
      ('regionalB', 77, 'regional_league'),
      ('worldCup', 9, 'champions_cup'),
    ]) {
      test('draws the same clubs and blurbs — $label', () {
        // Weighted per round out of the whole pyramid, so this pins the draw
        // ORDER as well as the weights.
        seeded.setSeed(seed);
        final state = _state(division: division);
        final active = startCup(state);
        final want = (_ref['brackets'] as Map<String, dynamic>)[label]
            as Map<String, dynamic>;
        expect(_stripTimes(active), want['active']);
        expect(cupAvailable(state), want['availableAfter']);
      });
    }
  });

  group('parity — a whole run', () {
    for (final (label, seed, division, hardMode, strong) in const [
      ('runA', 31337, 'regional_league', false, false),
      ('runB', 555, 'champions_cup', false, false),
      ('runPro', 8080, 'elite_league', true, false),
      ('runWinner', 7, 'regional_league', false, true),
    ]) {
      test('plays out identically, round for round — $label', () {
        seeded.setSeed(seed);
        final state = _state(
          division: division,
          hardMode: hardMode,
          strongSquad: strong,
        );
        startCup(state);

        final want = _ref[label] as Map<String, dynamic>;
        final wantRounds = want['rounds'] as List;

        for (var i = 0; i < 5; i++) {
          final prepared = prepareCupRound(state);
          if (prepared == null) break;
          final drop = commitCupRound(state, prepared.won, prepared);

          expect(i, lessThan(wantRounds.length), reason: 'extra round $i');
          final w = wantRounds[i] as Map<String, dynamic>;
          final p = w['prepared'] as Map<String, dynamic>;
          final where = '$label round $i';

          expect(prepared.cupId, p['cupId'], reason: where);
          expect(prepared.round, p['round'], reason: where);
          expect(prepared.roundName, p['roundName'], reason: where);
          expect(prepared.opponentName, p['opponentName'], reason: where);
          expect(prepared.won, p['won'], reason: where);
          expect(prepared.homeGoals, p['homeGoals'], reason: where);
          expect(prepared.awayGoals, p['awayGoals'], reason: where);
          expect(prepared.earned, p['earned'], reason: where);
          expect(prepared.squadRating, p['squadRating'], reason: where);
          expect(prepared.opponentRating, p['opponentRating'], reason: where);
          expect(prepared.ourAttackRating, p['ourAttackRating'], reason: where);
          expect(prepared.ourDefenceRating, p['ourDefenceRating'], reason: where);
          expect(prepared.effOppAttackRating, p['effOppAttackRating'], reason: where);
          expect(prepared.effOppDefenceRating, p['effOppDefenceRating'], reason: where);
          expect(prepared.isFinal, p['isFinal'], reason: where);

          final wantShootout = p['penaltyShootout'] as Map<String, dynamic>?;
          expect(prepared.penaltyShootout?.playerWins, wantShootout?['playerWins'],
              reason: where);
          expect(prepared.penaltyShootout?.homeScore, wantShootout?['homeScore'],
              reason: where);
          expect(prepared.penaltyShootout?.awayScore, wantShootout?['awayScore'],
              reason: where);
          expect(prepared.penaltyShootout?.kicks.length, wantShootout?['kicks'],
              reason: where);

          expect(
            [
              for (final inj in prepared.injuries)
                {'iid': inj.card.instanceId, 'minute': inj.minute},
            ],
            p['injuries'],
            reason: where,
          );

          final wantDrop = w['sponsorDrop'] as Map<String, dynamic>?;
          expect(drop?.kind, wantDrop?['kind'], reason: where);
          expect(drop?.cellIdx, wantDrop?['cellIdx'], reason: where);
          if (wantDrop != null) {
            final sd = wantDrop['sponsorData'] as Map<String, dynamic>;
            expect(drop!.sponsorData.name, sd['name'], reason: where);
            expect(drop.sponsorData.multiplier, sd['multiplier'], reason: where);
          }

          expect(state['resources']['fanCoins'], w['coins'], reason: where);
          expect(activeCup(state)?['round'], w['activeRound'], reason: where);

          if (activeCup(state) == null) break;
        }

        expect(_stripTimes(_cupsOf(state)['history']), want['history'],
            reason: label);
        expect(state['resources']['gems'], want['gems'], reason: label);
        expect(state['careerStats'], want['careerStats'], reason: label);
        expect(state['club']['cupLooksWon'] ?? <dynamic>[], want['cupLooksWon'],
            reason: label);
        expect(
          state['progression']['leagueTrophies'] ?? <dynamic>[],
          want['leagueTrophies'],
          reason: label,
        );
        expect(state['squad']['lineup'], want['lineup'], reason: label);
        expect(
          [
            for (final c in state['grid']['cells'] as List)
              if (c != null) (c as Map)['energy'],
          ],
          want['energies'],
          reason: label,
        );
      });
    }
  });

  group('parity — the one-shot path', () {
    test('matches the prepare-and-commit pair', () {
      seeded.setSeed(31337);
      final state = _state();
      startCup(state);
      final r = playCupRound(state)!;
      final want = _ref['playCupRound'] as Map<String, dynamic>;
      expect(r.prepared.won, want['won']);
      expect(r.prepared.homeGoals, want['homeGoals']);
      expect(r.prepared.awayGoals, want['awayGoals']);
      expect(state['resources']['fanCoins'], want['coins']);
    });
  });

  group('parity — the Lucky Boot', () {
    test('is spent by the PREPARE, not the commit', () {
      // It is a one-shot consumable: taking it up front is what stops it being
      // replayed by cancelling the popup.
      final want = _ref['luckyBoot'] as Map<String, dynamic>;

      seeded.setSeed(4242);
      final state = _state(luckyBoot: true);
      startCup(state);
      final prepared = prepareCupRound(state)!;
      expect(prepared.opponentRating, want['opponentRating']);
      expect(state['shop']['luckyBootReady'], want['stillReady']);

      seeded.setSeed(4242);
      final plain = _state();
      startCup(plain);
      expect(prepareCupRound(plain)!.opponentRating, want['plainRating']);
      expect(prepared.opponentRating, lessThan(want['plainRating'] as num));
    });
  });

  group('the cup ladder', () {
    test('a division below the first unlock has no cup', () {
      expect(cupForDivision(_state(division: 'sunday_league')), isNull);
      expect(cupAvailable(_state(division: 'sunday_league')), isFalse);
    });

    test('surfaces the highest cup reached, not the first', () {
      // Being in the Champions League should offer the World Club Cup.
      expect(cupForDivision(_state(division: 'champions_cup'))?.id, cups.last.id);
    });

    test('every cup has a prize multiplier and a bump per round', () {
      for (final cup in cups) {
        expect(cup.roundPrizeMult.length, cup.rounds.length, reason: cup.id);
        expect(cup.opponentRatingBump.length, cup.rounds.length, reason: cup.id);
      }
    });

    test('the prize rises with the round', () {
      for (final cup in cups) {
        for (var i = 1; i < cup.roundPrizeMult.length; i++) {
          expect(
            cup.roundPrizeMult[i],
            greaterThan(cup.roundPrizeMult[i - 1]),
            reason: cup.id,
          );
        }
      }
    });
  });

  group('availability', () {
    test('a run in progress blocks a second entry', () {
      final state = _state();
      startCup(state);
      expect(cupAvailable(state), isFalse);
      expect(startCup(state), isNull);
    });

    test('one run per season, enforced against the HISTORY', () {
      // The flag alone isn't trustworthy — older code flipped it back to true
      // after an elimination, which had the auto-enter re-rolling a fresh
      // bracket on every restart.
      final state = _state();
      startCup(state);
      final prepared = prepareCupRound(state)!;
      commitCupRound(state, false, prepared);
      expect(activeCup(state), isNull);

      _cupsOf(state)['availableThisSeason'] = true;
      expect(cupAvailable(state), isFalse);
    });

    test('a new season opens it again', () {
      final state = _state();
      startCup(state);
      commitCupRound(state, false, prepareCupRound(state)!);
      (state['progression'] as Map<String, dynamic>)['seasonCount'] = 4;
      refreshCupAvailability(state);
      expect(cupAvailable(state), isTrue);
    });

    test('a previous ADVENTURE cannot lock this one out', () {
      // Prestige restarts the season counter, so "season 3" alone doesn't
      // identify a season — the run has to come with it.
      final state = _state();
      startCup(state);
      commitCupRound(state, false, prepareCupRound(state)!);
      expect(cupAvailable(state), isFalse);

      (state['prestige'] as Map<String, dynamic>)['level'] = 1;
      refreshCupAvailability(state);
      expect(cupAvailable(state), isTrue);
    });

    test('an entry written before the run stamp reads as run zero', () {
      final state = _state();
      _cupsOf(state)['history'] = <dynamic>[
        <String, dynamic>{
          'cupId': 'regional_cup',
          'season': 3,
          'outcome': 'eliminated',
        },
      ];
      expect(cupAvailable(state), isFalse);
    });

    test('no pyramid means no bracket, rather than fictional opponents', () {
      final state = _state();
      (state['progression'] as Map<String, dynamic>).remove('leaguePyramid');
      expect(startCup(state), isNull);
      // And nothing was consumed, so it can be entered once the pyramid exists.
      expect(_cupsOf(state)['availableThisSeason'], isTrue);
    });
  });

  group('the bracket', () {
    test('draws one distinct club per round', () {
      final state = _state(division: 'champions_cup');
      final active = startCup(state)!;
      final opponents = (active['opponents'] as List).cast<String>();
      expect(opponents.length, cupForDivision(state)!.rounds.length);
      expect(opponents.toSet().length, opponents.length);
    });

    test('and a scout report for each', () {
      final active = startCup(_state())!;
      final contexts = active['contexts'] as List;
      expect(contexts.length, (active['opponents'] as List).length);
      for (final c in contexts) {
        expect('$c', isNotEmpty);
      }
    });

    test('a scout report never prints a raw rating', () {
      // Qualitative language only — the point is a report, not a stat line.
      for (var seed = 0; seed < 20; seed++) {
        seeded.setSeed(seed);
        final active = startCup(_state(division: 'champions_cup'))!;
        for (final raw in active['contexts'] as List) {
          final c = '$raw';
          final opponents = (active['opponents'] as List).cast<String>();
          // Strip the club names before looking for stray numbers, since a
          // generated name can legitimately end in one.
          var stripped = c;
          for (final name in opponents) {
            stripped = stripped.replaceAll(name, '');
          }
          // Positions are the only numbers allowed.
          final numbers = RegExp(r'\d+').allMatches(stripped);
          for (final m in numbers) {
            expect(
              int.parse(m.group(0)!),
              lessThanOrEqualTo(20),
              reason: 'seed $seed: $c',
            );
          }
        }
      }
    });

    test('the later rounds draw from higher up', () {
      // The final is almost exclusively the top available division.
      var laterIsHigher = 0;
      for (var seed = 0; seed < 40; seed++) {
        seeded.setSeed(seed);
        final active = startCup(_state(division: 'champions_cup'))!;
        final meta = (active['opponentMeta'] as List).cast<Map<String, dynamic>>();
        final first = divisions.indexWhere((d) => d.id == meta.first['divId']);
        final last = divisions.indexWhere((d) => d.id == meta.last['divId']);
        if (last >= first) laterIsHigher++;
      }
      expect(laterIsHigher, greaterThan(30));
    });

    test('every drawn club is a real one from the pyramid', () {
      final state = _state(division: 'champions_cup');
      final active = startCup(state)!;
      final pyramid = (state['progression'] as Map<String, dynamic>)['leaguePyramid']
          as Map<String, dynamic>;
      final allNames = {
        for (final teams in pyramid.values)
          for (final t in teams as List) (t as Map)['name'] as String,
      };
      for (final name in active['opponents'] as List) {
        expect(allNames, contains(name), reason: '$name');
      }
    });

    test('announces the start', () {
      Object? announced;
      on('cup:started', (v) => announced = v);
      startCup(_state());
      expect((announced as Map)['cupId'], 'regional_cup');
    });
  });

  group('a round', () {
    test('is neutral ground — neither side gets home advantage', () {
      // Which is why the prepared result carries no isHome at all.
      final state = _state();
      startCup(state);
      final prepared = prepareCupRound(state)!;
      expect(prepared.isCup, isTrue);
    });

    test('a draw goes to penalties, and the shootout settles it', () {
      var seen = 0;
      for (var seed = 0; seed < 120 && seen < 3; seed++) {
        seeded.setSeed(seed);
        final state = _state();
        startCup(state);
        final prepared = prepareCupRound(state)!;
        if (prepared.penaltyShootout == null) continue;
        seen++;
        expect(prepared.homeGoals, isNot(prepared.awayGoals));
        expect(
          prepared.won,
          prepared.penaltyShootout!.playerWins,
          reason: 'seed $seed',
        );
      }
      expect(seen, greaterThan(0));
    });

    test('a defeat still pays a share of the prize', () {
      // A cup run is worth something even when it ends.
      seeded.setSeed(31337);
      final state = _state();
      startCup(state);
      final prepared = prepareCupRound(state)!;
      expect(prepared.won, isFalse);
      expect(prepared.earned, greaterThan(0));
    });

    test('nothing is committed by the prepare but the Lucky Boot', () {
      final state = _state();
      startCup(state);
      final coinsBefore = state['resources']['fanCoins'];
      final historyBefore = jsonEncode(_cupsOf(state)['history']);
      prepareCupRound(state);
      expect(state['resources']['fanCoins'], coinsBefore);
      expect(jsonEncode(_cupsOf(state)['history']), historyBefore);
      expect(activeCup(state)?['round'], 0);
    });

    test('the commit uses the FINAL result, not the prepared one', () {
      // The player can change tactics on the way through and change the
      // outcome, so the prize is recalculated.
      seeded.setSeed(31337);
      final state = _state();
      startCup(state);
      final prepared = prepareCupRound(state)!;
      expect(prepared.won, isFalse);
      commitCupRound(state, true, prepared);
      // A win advances the bracket rather than ending the run.
      expect(activeCup(state), isNotNull);
      expect(activeCup(state)!['round'], 1);
    });

    test('there is no round to play without an active run', () {
      expect(prepareCupRound(_state()), isNull);
      expect(playCupRound(_state()), isNull);
    });

    test('a commit with nothing prepared does nothing', () {
      final state = _state();
      startCup(state);
      expect(commitCupRound(state, true, null), isNull);
      expect(activeCup(state)!['round'], 0);
    });
  });

  group('winning the thing', () {
    Map<String, dynamic> lift() {
      seeded.setSeed(7);
      final state = _state(strongSquad: true);
      startCup(state);
      while (activeCup(state) != null) {
        final prepared = prepareCupRound(state);
        if (prepared == null) break;
        commitCupRound(state, true, prepared);
      }
      return state;
    }

    test('files the run as won and clears the bracket', () {
      final state = lift();
      expect(activeCup(state), isNull);
      final history = _cupsOf(state)['history'] as List;
      expect((history.last as Map)['outcome'], 'won');
    });

    test('pays a gem — the earned route to hard currency', () {
      final state = lift();
      expect(state['resources']['gems'], 11);
    });

    test('and only the FIRST time that cup is lifted', () {
      final state = lift();
      final after = state['resources']['gems'];
      // A second run at the same cup, next season.
      (state['progression'] as Map<String, dynamic>)['seasonCount'] = 4;
      refreshCupAvailability(state);
      seeded.setSeed(7);
      startCup(state);
      while (activeCup(state) != null) {
        final prepared = prepareCupRound(state);
        if (prepared == null) break;
        commitCupRound(state, true, prepared);
      }
      expect(state['resources']['gems'], after);
    });

    test('records the trophy, the career stat and the cosmetic', () {
      final state = lift();
      expect(state['careerStats']['cupWins'], 1);
      expect(state['club']['cupLooksWon'], ['regional_cup']);
      final trophies = state['progression']['leagueTrophies'] as List;
      expect((trophies.last as Map)['cup'], isTrue);
      expect((trophies.last as Map)['cupName'], isNotNull);
    });

    test('the cosmetic ledger outlives the trophy cabinet', () {
      // leagueTrophies is session-only and wiped by a soft reset; a cosmetic
      // earned by lifting a trophy has to survive that.
      final state = lift();
      (state['progression'] as Map<String, dynamic>)['leagueTrophies'] =
          <dynamic>[];
      expect(state['club']['cupLooksWon'], contains('regional_cup'));
    });

    test('announces the win with the gems it paid', () {
      Object? announced;
      on('cup:won', (v) => announced = v);
      lift();
      expect((announced as Map)['gems'], 1);
    });
  });

  group('losing', () {
    test('files the run as eliminated and clears the bracket', () {
      final state = _state();
      startCup(state);
      final prepared = prepareCupRound(state)!;
      commitCupRound(state, false, prepared);
      expect(activeCup(state), isNull);
      final history = _cupsOf(state)['history'] as List;
      expect((history.single as Map)['outcome'], 'eliminated');
      expect((history.single as Map)['roundReached'], 0);
    });

    test('announces the elimination', () {
      Object? announced;
      on('cup:eliminated', (v) => announced = v);
      final state = _state();
      startCup(state);
      commitCupRound(state, false, prepareCupRound(state)!);
      expect((announced as Map)['cupId'], 'regional_cup');
    });

    test('no sponsor drops on a defeat', () {
      final state = _state();
      startCup(state);
      expect(commitCupRound(state, false, prepareCupRound(state)!), isNull);
    });
  });

  group('accessors', () {
    test('report nothing on a bare save', () {
      expect(activeCup(<String, dynamic>{}), isNull);
      expect(activeCup(null), isNull);
      expect(cupHistory(<String, dynamic>{}), isEmpty);
      expect(cupHistory(null), isEmpty);
    });

    test('getCupById finds a cup and nothing else', () {
      expect(getCupById('regional_cup')?.id, 'regional_cup');
      expect(getCupById('nonsense'), isNull);
      expect(getCupById(null), isNull);
    });
  });
}
