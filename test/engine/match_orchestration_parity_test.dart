/// Whole simulated matches against the Dart-owned golden — result, feed and
/// save — plus the pieces the JS is still the reference for.
///
/// Almost all of this function's risk is ORDERING. It draws the opponent's
/// rating, two injury rolls, the tactic's swing, the AI rotation plan, then
/// every positional attack and shot, then the entire event feed off one shared
/// stream, and a change that gets every formula right still comes out
/// different if it draws them in a different sequence. Comparing a whole match
/// is the only thing that catches that.
///
/// **Two references, deliberately.** The scoreline is decided by the
/// positional sim (see the header of `engine/match_orchestration.dart`), which
/// the JS does not have, so a simulated match is compared against
/// `positional_golden.json` — written by `tool/dump_positional_golden.dart`
/// from the same scenario set in `test/support/positional_scenarios.dart`. A
/// golden catches regressions, not correctness; `positional_balance_test` is
/// the other half. `bestFormationForFixture` and the cooldowns never simulate
/// a match, so they still stand against the node dump in
/// `match_orchestration_reference.json`, which now carries only those.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/match_events.dart';
import 'package:merge_empire_fc/engine/match_orchestration.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

import '../support/js_math_random.dart';
import '../support/positional_scenarios.dart';

final Map<String, dynamic> golden =
    jsonDecode(File(positionalGoldenPath).readAsStringSync())
        as Map<String, dynamic>;

final Map<String, dynamic> jsRef =
    jsonDecode(
          File(
            'test/fixtures/match_orchestration_reference.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

final int fixedNow = jsRef['fixedNow'] as int;

Map<String, dynamic> _want(String name) =>
    (golden['matches'] as Map)[name] as Map<String, dynamic>;

/// Runs a scenario and compares every recorded key on its own, so a failure
/// says WHICH of the result, the feed or the save moved.
void _expectScenario(String name) {
  final sc = matchScenario(name);
  final got = runMatchScenario(sc);
  final want = _want(name);
  expect(got.keys.toSet(), want.keys.toSet(), reason: '$name — record shape');
  for (final key in want.keys) {
    if (key == 'state') continue;
    expect(got[key], want[key], reason: '$name — $key');
  }
  expect(got['state'], want['state'], reason: '$name — save');
  // Key ORDER too: a save is compared byte for byte after a cloud round trip,
  // so a field first written in a different place is a real difference.
  expect(
    ((got['state'] as Map)['progression'] as Map).keys.toList(),
    ((want['state'] as Map)['progression'] as Map).keys.toList(),
    reason: '$name — progression key order',
  );
}

void main() {
  setUp(() => setClock(() => fixedNow));
  tearDown(() {
    resetClock();
    resetEventRandom();
    resetMatchRandom();
  });

  test('the golden was written for this scenario set', () {
    expect(
      (golden['matches'] as Map).keys.toSet(),
      matchScenarios.map((s) => s.name).toSet(),
      reason:
          'scenario set and golden disagree — '
          'dart run tool/dump_positional_golden.dart',
    );
    expect(golden['fixedNow'], positionalFixedNow);
  });

  test("this port's default XI is the one the JS built", () {
    // The scenarios build their 4-4-2 with `buildDefaultLineup`; the node dump
    // shipped its own. They have to agree or every golden kicks off from a
    // different eleven than the JS parity fixtures that survive do.
    final state = matchState(const Setup());
    expect(
      jsonRoundTrip((state['squad'] as Map)['lineup']),
      jsRef['baseLineup'],
    );
  });

  group('simulateMatch', () {
    for (final sc in matchScenarios) {
      if (!sc.name.startsWith(
        RegExp(
          'easy|hard|forceWin|luckyBoot|grudge|'
          'relegationZone|unrolledOpponent|noLineup|injury|seasonCloses',
        ),
      )) {
        continue;
      }
      test('${sc.name} matches the golden match, feed and save', () {
        _expectScenario(sc.name);
      });
    }
  });

  group('settlement', () {
    for (final sc in matchScenarios) {
      if (!sc.name.startsWith(RegExp('settle|rewardsOnly'))) continue;
      test('${sc.name} settles the same way, twice over', () {
        _expectScenario(sc.name);
      });
    }
  });

  group('reSimulateRemainder', () {
    for (final sc in matchScenarios) {
      if (!sc.name.startsWith('resim')) continue;
      test('${sc.name} rewrites the match the same way', () {
        _expectScenario(sc.name);
      });
    }

    test('a re-simulated remainder keeps the minutes already played', () {
      final got = runMatchScenario(
        matchScenario('resimEasy_s5_m45_allOutAttack'),
      );
      final positional = (got['result'] as Map)['positional'] as Map;
      final minutes = [
        for (final e in positional['ev'] as List) (e as Map)['m'] as int,
      ];
      expect(minutes.any((m) => m <= 45), isTrue);
      expect(minutes.any((m) => m > 45), isTrue);
    });
  });

  group('hardLiveRatings', () {
    test('matches the golden at every minute, and rebuilds minutes played', () {
      _expectScenario('hardLive');
    });
  });

  group('bestFormationForFixture', () {
    /// The squads the reference ranked, by the label it used.
    Map<String, dynamic> squadFor(String label) {
      switch (label) {
        case 'refSave':
          return matchState(const Setup());
        case 'refSaveHome':
          return matchState(
            const Setup(progression: {'seasonMatchesPlayed': 5}),
          );
        case 'unrolled':
          return matchState(
            const Setup(
              progression: {
                'seasonCount': 9,
                'seasonOpponentRatings': <String, int>{},
              },
            ),
          );
        case 'attackTactic':
          return matchState(const Setup(squad: {'strategyId': 'allOutAttack'}));
        case 'bareEleven':
          return tierSquadState(4, 11);
        case 'strong':
          return tierSquadState(8, 15);
      }
      throw ArgumentError(label);
    }

    for (final row in jsRef['bestFormation'] as List) {
      final r = row as Map<String, dynamic>;
      test('picks the same shape and XI as the JS for ${r['label']}', () {
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
        expect([
          for (final s in best.lineup)
            {
              'slotId': s.slotId,
              'slotPosition': s.slotPosition,
              'cardInstanceId': s.cardInstanceId,
            },
        ], r['lineup']);
      });
    }
  });

  group('cooldowns', () {
    Map<String, dynamic> stateFor(String label) {
      switch (label) {
        case 'ready':
          return matchState(const Setup());
        case 'justPlayed':
          return matchState(Setup(progression: {'lastMatchAt': fixedNow}));
        case 'vip':
          return matchState(
            Setup(
              progression: {'lastMatchAt': fixedNow},
              boosts: {'vipActive': true, 'vipExpiresAt': fixedNow + 60000},
            ),
          );
        case 'vipExpired':
          return matchState(
            Setup(
              progression: {'lastMatchAt': fixedNow},
              boosts: {'vipActive': true, 'vipExpiresAt': fixedNow - 1},
            ),
          );
        case 'freeWindow':
          return matchState(
            Setup(
              progression: {'lastMatchAt': fixedNow},
              boosts: {'matchCooldownFreeUntil': fixedNow + 60000},
            ),
          );
        case 'seasonComplete':
          return matchState(const Setup(progression: {'seasonComplete': true}));
        case 'thinLineup':
          return matchState(
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
          return matchState(
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

    for (final row in jsRef['cooldowns'] as List) {
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
      final state = matchState(
        Setup(progression: {'lastMatchAt': fixedNow + 999999}),
      );
      startMatchCooldown(state);
      expect(
        (state['progression'] as Map)['lastMatchAt'],
        (jsRef['cooldownFloor'] as Map)['lastMatchAt'],
      );
    });

    test('survives a state with no progression at all', () {
      expect(() => startMatchCooldown(<String, dynamic>{}), returnsNormally);
    });
  });
}
