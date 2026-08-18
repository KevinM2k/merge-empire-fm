/// Differential test: the Dart event cup against the JS it was ported from.
///
/// Two things make this one worth pinning over whole tournaments rather than
/// function by function. The draw shuffles a 49-nation pool, so a single extra
/// number taken anywhere puts the player in a different bracket. And the other
/// fifteen nations are simulated IN ARREARS — seven ties the moment the player
/// wins the R16, three after the quarter-final, one after the semi — so a port
/// that advances the bracket a beat early or late produces a tournament that
/// looks entirely plausible and shares not one result with the original.
///
/// See `tool/dump_event_cup_reference.mjs`.
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

/// The save the reference was generated against, so both runtimes start from
/// byte-identical input.
Map<String, dynamic> _state() =>
    jsonDecode(jsonEncode(_ref['state'])) as Map<String, dynamic>;

/// Wall-clock stamps are the one thing the two runtimes cannot agree on, so
/// they are blanked on both sides rather than compared.
const _timeKeys = {
  'startedAt',
  'activatedAt',
  'lastMatchAt',
  'wonAt',
  'scoredAt',
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

Map<String, dynamic> _section(String key) => _ref[key] as Map<String, dynamic>;

Map<String, dynamic> _progressOf(Map<String, dynamic> state) =>
    ((state['events'] as Map<String, dynamic>)['progress']
            as Map<String, dynamic>)['wc2026']
        as Map<String, dynamic>;

void _expectPrepared(
  PreparedEventCupRound got,
  Map<String, dynamic> want, {
  required String reason,
}) {
  expect(got.eventId, want['eventId'], reason: '$reason eventId');
  expect(got.round, want['round'], reason: '$reason round');
  expect(got.roundName, want['roundName'], reason: '$reason roundName');
  expect(
    got.opponentName,
    want['opponentName'],
    reason: '$reason opponentName',
  );
  expect(got.won, want['won'], reason: '$reason won');
  expect(got.homeGoals, want['homeGoals'], reason: '$reason homeGoals');
  expect(got.awayGoals, want['awayGoals'], reason: '$reason awayGoals');
  expect(got.earned, want['earned'], reason: '$reason earned');
  expect(got.squadRating, want['squadRating'], reason: '$reason squadRating');
  expect(
    got.opponentRating,
    want['opponentRating'],
    reason: '$reason opponentRating',
  );
  expect(got.isFinal, want['isFinal'], reason: '$reason isFinal');
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

  group('parity — the draw', () {
    for (final entry in _section('draws').entries) {
      final want = entry.value as Map<String, dynamic>;
      test(
        'draws the same sixteen nations in the same order — ${entry.key}',
        () {
          seeded.setSeed(want['seed'] as int);
          final state = _state();
          final cup = startEventCup(state, 'wc2026', want['nation'] as String?);
          expect(_stripTimes(cup), want['cup']);
          expect(lastPickedNation(state, 'wc2026'), want['lastPickedNation']);
        },
      );
    }

    test('a second call on a live run hands back the same object', () {
      // Not merely equal — the SAME run. A redraw would move the player to a
      // different bracket mid-tournament.
      seeded.setSeed(1234);
      final state = _state();
      final a = startEventCup(state, 'wc2026', 'Argentina');
      final b = startEventCup(state, 'wc2026', 'Brazil');
      final want = _section('idempotentDraw');
      expect(identical(a, b), want['same']);
      expect(b?['playerNation'], want['playerNation']);
    });
  });

  group('parity — a whole tournament', () {
    for (final entry in _section('runs').entries) {
      final want = entry.value as Map<String, dynamic>;
      test('plays out identically, round for round — ${entry.key}', () {
        seeded.setSeed(want['seed'] as int);
        final state = _state();
        startEventCup(state, 'wc2026', want['nation'] as String?);

        final wantRounds = want['rounds'] as List;
        for (var i = 0; i < 5; i++) {
          final prepared = prepareEventCupRound(state, 'wc2026');
          if (prepared == null) break;
          final result = commitEventCupRound(
            state,
            'wc2026',
            prepared.won,
            prepared,
          );
          expect(
            i,
            lessThan(wantRounds.length),
            reason: 'the JS run was ${wantRounds.length} rounds long',
          );
          final wantRound = wantRounds[i] as Map<String, dynamic>;
          _expectPrepared(
            prepared,
            wantRound['prepared'] as Map<String, dynamic>,
            reason: 'round $i',
          );
          expect(result, wantRound['result'], reason: 'round $i result');
          expect(
            ((state['resources'] as Map)['fanCoins']),
            wantRound['coins'],
            reason: 'round $i coins',
          );
          expect(
            _stripTimes(activeEventCup(state, 'wc2026')),
            wantRound['cup'],
            reason: 'round $i cup',
          );
          final cup = activeEventCup(state, 'wc2026')!;
          if (cup['eliminated'] == true || cup['won'] == true) break;
        }

        expect(_stripTimes(_progressOf(state)), want['progress']);
        expect((state['resources'] as Map)['fanCoins'], want['coins']);
        expect(
          (state['progression'] as Map)['leagueTrophies'],
          want['leagueTrophies'],
        );
      });
    }
  });

  test('parity — a second trophy pays nothing but still scores', () {
    // The conditional challenge actions fire BEFORE the already-won gate, so a
    // count-based challenge keeps accruing on a repeat win while the money
    // does not.
    seeded.setSeed(1);
    final state = _state();
    (state['progression'] as Map)['leagueTrophies'] = <dynamic>[
      <String, dynamic>{
        'name': 'International Cup 2026',
        'cup': true,
        'event': true,
        'eventId': 'wc2026',
      },
    ];
    startEventCup(state, 'wc2026', 'Argentina');

    final want = _section('repeatWin');
    final rounds = <Map<String, dynamic>>[];
    for (var i = 0; i < 5; i++) {
      final r = playEventCupRound(state, 'wc2026');
      if (r == null) break;
      rounds.add(r);
      final cup = activeEventCup(state, 'wc2026')!;
      if (cup['eliminated'] == true || cup['won'] == true) break;
    }
    expect(rounds, want['rounds']);
    expect((state['resources'] as Map)['fanCoins'], want['coins']);
    expect(_stripTimes(_progressOf(state)), want['progress']);
  });

  test('parity — the committed result wins, not the prepared one', () {
    // A strategy swap mid-tie can flip the outcome, so the scoreline stays as
    // drawn while the win flag comes from the caller.
    seeded.setSeed(6);
    final state = _state();
    startEventCup(state, 'wc2026', 'Argentina');
    final prepared = prepareEventCupRound(state, 'wc2026')!;
    final result = commitEventCupRound(
      state,
      'wc2026',
      !prepared.won,
      prepared,
    );

    final want = _section('flipped');
    _expectPrepared(
      prepared,
      want['prepared'] as Map<String, dynamic>,
      reason: 'flipped',
    );
    expect(result, want['result']);
    expect(_stripTimes(activeEventCup(state, 'wc2026')), want['cup']);
  });

  group('parity — restarting', () {
    const nations = {
      'remembered': LastNation(),
      'picked': PickedNation('Brazil'),
      'picker': ShowNationPicker(),
    };
    for (final entry in _section('restarts').entries) {
      final want = entry.value as Map<String, dynamic>;
      test('takes the right nation into the next run — ${entry.key}', () {
        seeded.setSeed(6);
        final state = _state();
        startEventCup(state, 'wc2026', 'Argentina');
        playEventCupRound(state, 'wc2026'); // seed 6 goes out in the R16
        expect(
          activeEventCup(state, 'wc2026')!['eliminated'],
          want['eliminated'],
        );

        final next = restartEventCup(state, 'wc2026', nations[entry.key]!);
        expect(_stripTimes(next), want['next']);
        expect(
          (_progressOf(state)['cupHistory'] as List? ?? const []).length,
          want['historyLength'],
        );
        expect(lastPickedNation(state, 'wc2026'), want['lastPickedNation']);
        expect(_stripTimes(activeEventCup(state, 'wc2026')), want['cupAfter']);
      });
    }

    test('a run still going cannot be restarted', () {
      seeded.setSeed(6);
      final state = _state();
      final before = startEventCup(state, 'wc2026', 'Argentina');
      final next = restartEventCup(state, 'wc2026');
      final want = _section('restartMidRun');
      expect(next, want['next']);
      expect(
        identical(activeEventCup(state, 'wc2026'), before),
        want['unchanged'],
      );
    });

    test('starting over a WON run redraws in place', () {
      // Only an unfinished run is protected, so a fresh start after lifting the
      // trophy is a redraw rather than a refusal — and it does NOT push the old
      // run into the history, which only [restartEventCup] does.
      seeded.setSeed(1);
      final state = _state();
      startEventCup(state, 'wc2026', 'Argentina');
      for (var i = 0; i < 5; i++) {
        if (playEventCupRound(state, 'wc2026') == null) break;
        if (activeEventCup(state, 'wc2026')!['won'] == true) break;
      }
      final redrawn = startEventCup(state, 'wc2026', 'Brazil')!;
      final want = _section('startOverWonRun');
      expect(redrawn['playerNation'], want['playerNation']);
      expect(redrawn['round'], want['round']);
      expect((redrawn['results'] as List).length, want['results']);
      expect(
        (_progressOf(state)['cupHistory'] as List? ?? const []).length,
        want['historyLength'],
      );
    });
  });

  test('parity — the guards all refuse the same way', () {
    final want = _section('guards');

    final idle = _state();
    (idle['events'] as Map)['active'] = <dynamic>[];
    final noCupEvent = _state();
    (noCupEvent['events'] as Map)['active'] = <dynamic>['deadline_day'];

    final started = _state();
    startEventCup(started, 'wc2026', 'Argentina');
    final elim = _state();
    startEventCup(elim, 'wc2026', 'Argentina');
    activeEventCup(elim, 'wc2026')!['eliminated'] = true;

    expect(startEventCup(idle, 'wc2026', 'Argentina'), want['startInactive']);
    expect(
      startEventCup(_state(), 'nope', 'Argentina'),
      want['startUnknownEvent'],
    );
    expect(
      startEventCup(noCupEvent, 'deadline_day'),
      want['startEventWithoutCup'],
    );
    expect(prepareEventCupRound(idle, 'wc2026'), want['prepareInactive']);
    expect(prepareEventCupRound(_state(), 'wc2026'), want['prepareNoCup']);
    expect(prepareEventCupRound(elim, 'wc2026'), want['prepareEliminated']);
    expect(playEventCupRound(_state(), 'wc2026'), want['playNoCup']);
    expect(playEventCupRound(elim, 'wc2026'), want['playEliminated']);
    expect(
      commitEventCupRound(started, 'wc2026', true, null),
      want['commitNoPrepared'],
    );
    expect(restartEventCup(idle, 'wc2026'), want['restartInactive']);
    expect(
      activeEventCup(<String, dynamic>{}, 'wc2026'),
      want['activeOnEmptyState'],
    );
    expect(
      lastPickedNation(<String, dynamic>{}, 'wc2026'),
      want['lastPickedOnEmptyState'],
    );

    final noNation = _state();
    startEventCup(noNation, 'wc2026');
    expect(
      lastPickedNation(noNation, 'wc2026'),
      want['lastPickedAfterNoNation'],
    );
  });
}
