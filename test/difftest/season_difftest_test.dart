/// Whole SEASONS through the Dart engines, compared against the Dart-owned
/// season golden.
///
/// The per-module fixtures each pin one engine. This pins the whole thing at
/// once, and the difference matters: a per-module fixture proves a function
/// agrees on the inputs somebody thought to write down, and a season proves
/// the functions agree with EACH OTHER — that the pyramid the season boundary
/// shuffles is the one the next season's fixtures are drawn from, that the
/// ratings a match writes are the ones the table reads, and that thirty
/// thousand draws later the save is still on the same number.
///
/// It compared against the JS until the positional sim took over the
/// scoreline (see the header of `engine/match_orchestration.dart`); the JS
/// still draws two Poissons, so it stopped being a reference for a match. The
/// golden is written by `tool/dump_positional_golden.dart` from the runner in
/// `test/support/positional_scenarios.dart`, which this file also calls. A
/// golden catches regressions, not correctness — `positional_balance_test` is
/// the half that asks whether the numbers are right.
///
/// A mismatch reports the first match it happened on, because after that every
/// hash is wrong for the same reason and only the first one tells you anything.
///
/// See `tool/difftest/README.md`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/season_end.dart';
import 'package:merge_empire_fc/util/time.dart';

import '../support/canonical.dart';
import '../support/positional_scenarios.dart';

final Map<String, dynamic> _golden =
    jsonDecode(File(positionalSeasonGoldenPath).readAsStringSync())
        as Map<String, dynamic>;

Map<String, dynamic> _runs() => _golden['runs'] as Map<String, dynamic>;

void main() {
  setUp(() => setClock(() => _golden['fixedNow'] as int));
  tearDown(resetClock);

  test('the golden was written for these runs', () {
    expect(_runs().keys.toSet(), seasonRuns().keys.toSet());
    expect(_golden['seasons'], seasonsPerRun);
    for (final e in seasonRuns().entries) {
      final want = _runs()[e.key] as Map<String, dynamic>;
      expect(want['seed'], e.value['seed'], reason: e.key);
      expect(want['mathSeed'], e.value['mathSeed'], reason: e.key);
    }
  });

  for (final label in seasonRuns().keys) {
    test('$seasonsPerRun seasons match the golden byte for byte — $label', () {
      final want = _runs()[label] as Map<String, dynamic>;
      final steps = (want['steps'] as List).cast<Map<String, dynamic>>();
      final ends = (want['seasonEnds'] as List).cast<Map<String, dynamic>>();

      final got = runSeasonRun(
        label,
        onStep: (step, record) {
          expect(
            step,
            lessThan(steps.length),
            reason: 'the golden run was ${steps.length} matches long',
          );
          final w = steps[step];
          final where = 'season ${record['season']} match ${record['match']}';
          // The result first: when both are wrong it is the more legible of
          // the two, and when only the hash is wrong the divergence is in the
          // save rather than in the scoreline.
          expect(record['result'], w['result'], reason: '$where result');
          if (w['save'] != null) {
            expect(record['save'], w['save'], reason: '$where save');
          }
          expect(record['hash'], w['hash'], reason: '$where save');
        },
        onSeasonEnd: (season, record) {
          expect(
            record['ended'],
            ends[season]['ended'],
            reason: 'season $season outcome',
          );
          // The whole save, so a failure here says WHAT differs rather than
          // only that something does.
          expect(
            record['save'],
            ends[season]['save'],
            reason: 'season $season save',
          );
        },
      );

      expect(
        (got['steps'] as List).length,
        steps.length,
        reason: 'the run played every match',
      );
    });

    test('nothing whole is stored as a double — $label', () {
      // What the canonical form deliberately hides, so the hash tracks values
      // rather than types. It is a real risk: coins are the most-written field
      // in the save, and one landing as 75.0 where an int belongs is equal as
      // a number and different as JSON.
      setClock(() => positionalFixedNow);
      final state = beginSeasonRun(label);
      for (var season = 0; season < seasonsPerRun; season++) {
        final fixtures =
            (state['progression'] as Map)['seasonFixtures'] as List? ??
            const [];
        for (var i = 0; i < fixtures.length; i++) {
          playSeasonMatch(state);
        }
        endSeason(state);
      }
      expect(integralDoubles(state), isEmpty);
      // And the whole thing still serialises, which is the other half of the
      // same promise.
      expect(() => jsonEncode(state), returnsNormally);
    });
  }
}
