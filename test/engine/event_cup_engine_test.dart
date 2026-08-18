/// The event cup's own behaviour: what it announces, what it writes into the
/// save, and the corners the parity fixture cannot reach because the JS cannot
/// reach them either from a normal run.
///
/// The round-for-round arithmetic lives in `event_cup_parity_test.dart`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/event_cup_engine.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

final Map<String, dynamic> _ref =
    jsonDecode(
          File('test/fixtures/event_cup_reference.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

Map<String, dynamic> _state() =>
    jsonDecode(jsonEncode(_ref['state'])) as Map<String, dynamic>;

Map<String, dynamic> _progressOf(Map<String, dynamic> state) =>
    ((state['events'] as Map<String, dynamic>)['progress']
            as Map<String, dynamic>)['wc2026']
        as Map<String, dynamic>;

/// Play until the run is over, however it ends.
List<Map<String, dynamic>> _playOut(Map<String, dynamic> state) {
  final rounds = <Map<String, dynamic>>[];
  for (var i = 0; i < 5; i++) {
    final r = playEventCupRound(state, 'wc2026');
    if (r == null) break;
    rounds.add(r);
    final cup = activeEventCup(state, 'wc2026')!;
    if (cup['eliminated'] == true || cup['won'] == true) break;
  }
  return rounds;
}

void main() {
  setUp(() {
    setClock(() => 1700000000000);
    seeded.setSeed(1234);
  });
  tearDown(() {
    resetClock();
    clearBus();
  });

  group('the draw', () {
    test('seats the player at slot 0 and reveals only the first tie', () {
      final cup = startEventCup(_state(), 'wc2026', 'Argentina')!;
      expect((cup['bracket'] as List).length, 16);
      expect((cup['bracket'] as List).first, 'Argentina');
      expect((cup['opponents'] as List).length, 1);
      expect(cup['opponents'], [(cup['bracket'] as List)[1]]);
      expect(cup['bracketRounds'], isEmpty);
      expect(cup['round'], 0);
      expect(cup['results'], isEmpty);
    });

    test('never draws the player against themselves', () {
      // The pool is filtered on the player's nation, so the one thing the draw
      // must not produce is Argentina in one of the other fifteen slots.
      for (var seed = 1; seed <= 40; seed++) {
        seeded.setSeed(seed);
        final cup = startEventCup(_state(), 'wc2026', 'Argentina')!;
        final others = (cup['bracket'] as List).skip(1);
        expect(others, isNot(contains('Argentina')), reason: 'seed $seed');
      }
    });

    test('creates the progress branch on a save that has none', () {
      final state = <String, dynamic>{
        'events': <String, dynamic>{
          'active': <dynamic>['wc2026'],
        },
      };
      expect(startEventCup(state, 'wc2026', 'Brazil'), isNotNull);
      final progress = _progressOf(state);
      expect(progress['score'], 0);
      expect(progress['claimedTiers'], isEmpty);
      expect(progress['activatedAt'], now());
    });

    test('an empty nation is not remembered as a pick', () {
      // The JS tests truthiness, so `''` is a nation-less run — and the picker
      // must surface again next time rather than reopening on nothing.
      final state = _state();
      startEventCup(state, 'wc2026', '');
      expect(lastPickedNation(state, 'wc2026'), isNull);
    });

    test('announces the draw', () {
      Object? announced;
      on('event:cup-started', (v) => announced = v);
      final cup = startEventCup(_state(), 'wc2026', 'Brazil')!;
      expect(announced, {
        'eventId': 'wc2026',
        'opponents': cup['opponents'],
        'playerNation': 'Brazil',
      });
    });
  });

  group('a round', () {
    test('announces the result and the new balance', () {
      final events = <String, Object?>{};
      for (final name in [
        'event:cup-round-complete',
        'coins:updated',
        'event:cup-eliminated',
      ]) {
        on(name, (v) => events[name] = v);
      }
      seeded.setSeed(6); // out in the R16
      final state = _state();
      startEventCup(state, 'wc2026', 'Argentina');
      final result = playEventCupRound(state, 'wc2026');

      expect(events['event:cup-round-complete'], {
        'eventId': 'wc2026',
        'result': result,
      });
      expect(events['coins:updated'], (state['resources'] as Map)['fanCoins']);
      expect(events['event:cup-eliminated'], {'eventId': 'wc2026', 'round': 0});
    });

    test('announces the trophy with the bounty', () {
      Object? announced;
      on('event:cup-won', (v) => announced = v);
      seeded.setSeed(1); // Argentina go all the way
      final state = _state();
      startEventCup(state, 'wc2026', 'Argentina');
      final rounds = _playOut(state);

      expect(announced, {
        'eventId': 'wc2026',
        'name': 'International Cup 2026',
        'playerNation': 'Argentina',
        'bounty': rounds.last['earned'],
        'firstWin': true,
      });
      // 30× the Champions Cup match revenue base.
      expect(rounds.last['earned'], 3600000);
    });

    test('stamps the match clock', () {
      seeded.setSeed(6);
      final state = _state();
      startEventCup(state, 'wc2026', 'Argentina');
      playEventCupRound(state, 'wc2026');
      expect((state['progression'] as Map)['lastMatchAt'], now());
    });

    test('pins the nation of the first win, and leaves it alone after', () {
      seeded.setSeed(1);
      final state = _state();
      startEventCup(state, 'wc2026', 'Argentina');
      _playOut(state);
      expect(_progressOf(state)['firstWin'], {
        'playerNation': 'Argentina',
        'wonAt': now(),
      });

      // Win again with somebody else: the headline stays as it was.
      seeded.setSeed(1);
      restartEventCup(state, 'wc2026', const PickedNation('Brazil'));
      _playOut(state);
      expect(
        (_progressOf(state)['firstWin'] as Map)['playerNation'],
        'Argentina',
      );
    });

    test('a run past its last round has nothing to prepare', () {
      // Unreachable from a normal run — the round counter hitting the end is
      // what sets `won` — but the guard is what stops a hand-edited or
      // part-migrated save walking off the end of the round names.
      final state = _state();
      final cup = startEventCup(state, 'wc2026', 'Argentina')!;
      cup['round'] = 4;
      expect(prepareEventCupRound(state, 'wc2026'), isNull);
    });

    test('commits nothing once the run is over', () {
      seeded.setSeed(6);
      final state = _state();
      startEventCup(state, 'wc2026', 'Argentina');
      final prepared = prepareEventCupRound(state, 'wc2026')!;
      commitEventCupRound(state, 'wc2026', false, prepared);
      // The same prepared round, replayed against an eliminated run.
      expect(commitEventCupRound(state, 'wc2026', true, prepared), isNull);
      expect((activeEventCup(state, 'wc2026')!['results'] as List).length, 1);
    });

    test('commits nothing for an event that has no cup', () {
      final state = _state();
      (state['events'] as Map)['active'] = <dynamic>['wc2026', 'deadline_day'];
      final prepared = prepareEventCupRound(state, 'wc2026');
      expect(prepared, isNull);
      startEventCup(state, 'wc2026', 'Argentina');
      final real = prepareEventCupRound(state, 'wc2026')!;
      expect(commitEventCupRound(state, 'deadline_day', true, real), isNull);
    });
  });

  group('the bracket', () {
    test('reveals one opponent per round and no more', () {
      seeded.setSeed(1);
      final state = _state();
      startEventCup(state, 'wc2026', 'Argentina');
      final seen = <int>[];
      for (var i = 0; i < 4; i++) {
        final cup = activeEventCup(state, 'wc2026')!;
        seen.add((cup['opponents'] as List).length);
        if (playEventCupRound(state, 'wc2026') == null) break;
        if (cup['eliminated'] == true) break;
      }
      // One known at the draw, one more revealed by each win — and the Final
      // reveals nobody, because there is nobody left.
      expect(seen, [1, 2, 3, 4]);
      final cup = activeEventCup(state, 'wc2026')!;
      expect((cup['opponents'] as List).length, 4);
      expect((cup['bracketRounds'] as List).map((r) => (r as List).length), [
        7,
        3,
        1,
      ]);
    });

    test('an eliminated player never learns the other results', () {
      // The rest of the round is simulated in arrears, so going out means it is
      // never played at all.
      seeded.setSeed(6);
      final state = _state();
      startEventCup(state, 'wc2026', 'Argentina');
      playEventCupRound(state, 'wc2026');
      expect(activeEventCup(state, 'wc2026')!['bracketRounds'], isEmpty);
    });

    test('a short bracket leaves holes rather than throwing', () {
      // Nothing in the app produces one — the pool is 49 nations — but the JS
      // read past the end of the array and got `undefined`, which fell to the
      // default rating, and a port that throws where the original shrugged
      // turns a cosmetic problem into a crash on somebody's save.
      final state = _state();
      final cup = startEventCup(state, 'wc2026', 'Argentina')!;
      final drawnFirst = (cup['opponents'] as List).first;
      cup['bracket'] = <dynamic>['Argentina', 'Brazil'];
      final prepared = prepareEventCupRound(state, 'wc2026')!;
      commitEventCupRound(state, 'wc2026', true, prepared);

      final r16 = (cup['bracketRounds'] as List).first as List;
      expect(r16.length, 7);
      expect((r16.first as Map)['t1'], isNull);
      expect(cup['opponents'], [drawnFirst, null]);
    });

    test('a bracket of the wrong SHAPE degrades to holes too', () {
      // Same argument as the short bracket, one level up: the JS read these
      // straight off the run and would have got `undefined` back. Every round
      // of the advance has its own fallback, so all three are walked here.
      final state = _state();
      final cup = startEventCup(state, 'wc2026', 'Argentina')!;
      final drawnFirst = (cup['opponents'] as List).first;

      cup['bracket'] = 'nonsense';
      for (final corrupt in <Object?>[
        null,
        <dynamic>['nonsense'],
        <dynamic>['nonsense', 'nonsense'],
      ]) {
        if (corrupt != null) cup['bracketRounds'] = corrupt;
        final prepared = prepareEventCupRound(state, 'wc2026')!;
        commitEventCupRound(state, 'wc2026', true, prepared);
      }

      expect(cup['round'], 3);
      expect(cup['opponents'], [drawnFirst, null, null, null]);
    });
  });

  group('restarting', () {
    test('keeps the finished run and remembers the nation', () {
      seeded.setSeed(6);
      final state = _state();
      startEventCup(state, 'wc2026', 'Argentina');
      playEventCupRound(state, 'wc2026');

      Object? announced;
      on('event:cup-restart', (v) => announced = v);
      final next = restartEventCup(state, 'wc2026')!;

      expect(announced, {'eventId': 'wc2026'});
      expect((_progressOf(state)['cupHistory'] as List).length, 1);
      expect(next['playerNation'], 'Argentina');
      expect(next['results'], isEmpty);
    });

    test('the picker clears the run without starting another', () {
      seeded.setSeed(6);
      final state = _state();
      startEventCup(state, 'wc2026', 'Argentina');
      playEventCupRound(state, 'wc2026');
      expect(
        restartEventCup(state, 'wc2026', const ShowNationPicker()),
        isNull,
      );
      expect(activeEventCup(state, 'wc2026'), isNull);
      // Still remembered, so the picker can preselect it.
      expect(lastPickedNation(state, 'wc2026'), 'Argentina');
    });

    test('falls back to the remembered nation when the old run had none', () {
      seeded.setSeed(6);
      final state = _state();
      startEventCup(state, 'wc2026', 'Argentina');
      playEventCupRound(state, 'wc2026');
      restartEventCup(state, 'wc2026', const ShowNationPicker());
      // No run at all now, so only `lastPickedNation` can answer.
      expect(restartEventCup(state, 'wc2026')?['playerNation'], 'Argentina');
    });

    test('an explicitly nation-less restart is not the remembered one', () {
      seeded.setSeed(6);
      final state = _state();
      startEventCup(state, 'wc2026', 'Argentina');
      playEventCupRound(state, 'wc2026');
      final next = restartEventCup(state, 'wc2026', const PickedNation(null))!;
      expect(next['playerNation'], isNull);
    });

    test('survives a cupHistory that is not a list', () {
      seeded.setSeed(6);
      final state = _state();
      startEventCup(state, 'wc2026', 'Argentina');
      playEventCupRound(state, 'wc2026');
      _progressOf(state)['cupHistory'] = 'nonsense';
      expect(restartEventCup(state, 'wc2026'), isNotNull);
      expect((_progressOf(state)['cupHistory'] as List).length, 1);
    });
  });

  group('what lands in the save', () {
    test('a whole tournament serialises', () {
      // Every result, every simulated bracket tie and the run itself go into
      // the save, so anything held as a record — or as a double where the JS
      // writes a whole number — would throw or drift on the first write.
      seeded.setSeed(1);
      final state = _state();
      startEventCup(state, 'wc2026', 'Argentina');
      _playOut(state);
      expect(() => jsonEncode(state), returnsNormally);
    });

    test('the bounty is a whole number of coins', () {
      seeded.setSeed(1);
      final state = _state();
      startEventCup(state, 'wc2026', 'Argentina');
      final rounds = _playOut(state);
      expect(rounds.last['earned'], isA<int>());
      expect((state['resources'] as Map)['fanCoins'], isA<int>());
    });

    test('a run with no coin branch still pays', () {
      final state = _state();
      state.remove('resources');
      seeded.setSeed(1);
      startEventCup(state, 'wc2026', 'Argentina');
      _playOut(state);
      expect((state['resources'] as Map)['fanCoins'], 3600000);
    });
  });
}
