import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/match_events.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;

List<ScorerCandidate> _xi() => [
  const ScorerCandidate(name: 'Keeper', position: 'GK', instanceId: 'gk'),
  for (var i = 0; i < 4; i++)
    ScorerCandidate(name: 'Def $i', position: 'DEF', instanceId: 'd$i'),
  for (var i = 0; i < 3; i++)
    ScorerCandidate(name: 'Mid $i', position: 'MID', instanceId: 'm$i'),
  for (var i = 0; i < 3; i++)
    ScorerCandidate(name: 'Fwd $i', position: 'FWD', instanceId: 'f$i'),
];

void main() {
  setUp(() {
    resetEventRandom();
    seeded.setSeed(12345);
  });

  group('pickWeightedScorer', () {
    test('returns null with nobody on the pitch', () {
      expect(pickWeightedScorer([]), isNull);
    });

    test('always returns someone from the XI', () {
      final xi = _xi();
      final ids = xi.map((p) => p.instanceId).toSet();
      for (var i = 0; i < 200; i++) {
        expect(ids, contains(pickWeightedScorer(xi)!.instanceId));
      }
    });

    test('forwards score most, keepers almost never', () {
      // Real keepers score about once in 5,000 matches.
      final xi = _xi();
      final counts = <String, int>{};
      for (var i = 0; i < 20000; i++) {
        final p = pickWeightedScorer(xi)!;
        counts[p.position] = (counts[p.position] ?? 0) + 1;
      }
      final total = counts.values.reduce((a, b) => a + b);
      expect(counts['FWD']! / total, greaterThan(0.5));
      expect(counts['MID']! / total, closeTo(0.27, 0.05));
      expect((counts['GK'] ?? 0) / total, lessThan(0.01));
    });

    test('a keeper CAN score — the freak header stays possible', () {
      var scored = false;
      for (var i = 0; i < 40000 && !scored; i++) {
        if (pickWeightedScorer(_xi())!.position == 'GK') scored = true;
      }
      expect(scored, isTrue);
    });

    test('scorer odds follow the SLOT, not the card position', () {
      // A keeper fielded up front must be able to score like a forward.
      final pushedUp = [
        const ScorerCandidate(name: 'Keeper', position: 'FWD', instanceId: 'gk'),
      ];
      expect(pickWeightedScorer(pushedUp)!.instanceId, 'gk');
    });

    test('an unknown position gets a middling weight rather than zero', () {
      final odd = [
        const ScorerCandidate(name: 'X', position: 'SWEEPER', instanceId: 'x'),
      ];
      expect(pickWeightedScorer(odd)!.instanceId, 'x');
    });

    test('is deterministic for a given seed', () {
      final xi = _xi();
      seeded.setSeed(7);
      final a = List.generate(20, (_) => pickWeightedScorer(xi)!.instanceId);
      seeded.setSeed(7);
      final b = List.generate(20, (_) => pickWeightedScorer(xi)!.instanceId);
      expect(a, b);
    });
  });

  group('generateMatchEvents — structure', () {
    test('emits a goal event per goal, attributed to the right side', () {
      final events = generateMatchEvents(
        homeGoals: 2,
        awayGoals: 1,
        playerData: _xi(),
      );
      final goals = events.where((e) => e.type == 'goal').toList();
      expect(goals.length, 3);
      expect(goals.where((g) => g.team == 'home').length, 2);
      expect(goals.where((g) => g.team == 'away').length, 1);
    });

    test('only home goals carry a scorer — we hold no cards for the away side', () {
      final events = generateMatchEvents(
        homeGoals: 2,
        awayGoals: 2,
        playerData: _xi(),
      );
      for (final g in events.where((e) => e.type == 'goal')) {
        if (g.team == 'home') {
          expect(g.scorer, isNotNull);
          expect(g.scorerInstanceId, isNotNull);
        } else {
          expect(g.scorer, isNull);
        }
      }
    });

    test('a home goal with no squad data has no scorer', () {
      final events = generateMatchEvents(homeGoals: 1, awayGoals: 0);
      expect(events.firstWhere((e) => e.type == 'goal').scorer, isNull);
    });

    test('is sorted by minute', () {
      final events = generateMatchEvents(
        homeGoals: 3,
        awayGoals: 2,
        playerData: _xi(),
      );
      for (var i = 1; i < events.length; i++) {
        expect(events[i].minute, greaterThanOrEqualTo(events[i - 1].minute));
      }
    });

    test('half time and full time bracket the match', () {
      final events = generateMatchEvents(homeGoals: 0, awayGoals: 0);
      final half = events.where((e) => e.type == 'halftime');
      final full = events.where((e) => e.type == 'fulltime');
      expect(half.length, 1);
      expect(half.single.minute, 45);
      expect(full.length, 1);
      expect(full.single.minute, greaterThanOrEqualTo(91));
    });

    test('full time is the LAST event', () {
      // A stranded full-time marker mid-array was a real bug.
      for (var i = 0; i < 40; i++) {
        final events = generateMatchEvents(
          homeGoals: 3,
          awayGoals: 3,
          playerData: _xi(),
        );
        expect(events.last.type, 'fulltime', reason: 'run $i');
      }
    });

    test('added time is between one and five minutes', () {
      for (var i = 0; i < 40; i++) {
        final events = generateMatchEvents(homeGoals: 0, awayGoals: 0);
        final ft = events.firstWhere((e) => e.type == 'fulltime');
        expect(ft.addedTime, inInclusiveRange(1, 5));
      }
    });

    test('an explicit added time is honoured', () {
      final events = generateMatchEvents(
        homeGoals: 0,
        awayGoals: 0,
        addedTime: 3,
      );
      final ft = events.firstWhere((e) => e.type == 'fulltime');
      expect(ft.addedTime, 3);
      expect(ft.minute, 93);
    });

    test('no goal lands on the full-time whistle', () {
      for (var i = 0; i < 40; i++) {
        final events = generateMatchEvents(
          homeGoals: 4,
          awayGoals: 4,
          playerData: _xi(),
        );
        final ftMinute = events.firstWhere((e) => e.type == 'fulltime').minute;
        for (final g in events.where((e) => e.type == 'goal')) {
          expect(g.minute, lessThan(ftMinute));
        }
      }
    });

    test('emits chances and corners', () {
      final events = generateMatchEvents(homeGoals: 1, awayGoals: 1);
      expect(events.where((e) => e.type == 'chance').length, greaterThan(5));
      expect(events.where((e) => e.type == 'corner').length, greaterThanOrEqualTo(2));
    });

    test('every chance carries a plausible xG and shot result', () {
      final events = generateMatchEvents(homeGoals: 1, awayGoals: 1);
      for (final c in events.where((e) => e.type == 'chance')) {
        expect(c.xg, inInclusiveRange(0.08, 0.30));
        expect(['on_target', 'off'], contains(c.shotResult));
        expect(c.big, c.xg! >= 0.22);
      }
    });

    test('commentary keys resolve to the documented buckets', () {
      final events = generateMatchEvents(homeGoals: 0, awayGoals: 0);
      for (final c in events.where((e) => e.type == 'commentary')) {
        expect(c.textKey, startsWith('commentary.flow.'));
      }
    });
  });

  group('goal minutes', () {
    test('are back-loaded like real football', () {
      // Roughly 45% in the first half, 55% in the second with a late spike.
      seeded.setSeed(4242);
      var first = 0;
      var second = 0;
      for (var i = 0; i < 600; i++) {
        final events = generateMatchEvents(
          homeGoals: 2,
          awayGoals: 2,
          playerData: _xi(),
        );
        for (final g in events.where((e) => e.type == 'goal')) {
          if (g.minute <= 45) {
            first++;
          } else {
            second++;
          }
        }
      }
      expect(second, greaterThan(first));
      expect(first / (first + second), closeTo(0.45, 0.08));
    });

    test('never land on the half-time whistle', () {
      for (var i = 0; i < 60; i++) {
        final events = generateMatchEvents(
          homeGoals: 4,
          awayGoals: 4,
          playerData: _xi(),
        );
        for (final g in events.where((e) => e.type == 'goal')) {
          expect(g.minute, isNot(45));
        }
      }
    });
  });

  group('partial windows', () {
    test('a second-half window emits no half-time marker', () {
      final events = generateMatchEvents(
        homeGoals: 1,
        awayGoals: 0,
        minMin: 60,
        maxMin: 90,
      );
      expect(events.where((e) => e.type == 'halftime'), isEmpty);
    });

    test('a partial window gets no added time', () {
      final events = generateMatchEvents(
        homeGoals: 1,
        awayGoals: 0,
        minMin: 20,
        maxMin: 60,
      );
      expect(events.where((e) => e.type == 'fulltime'), isEmpty);
      for (final e in events) {
        expect(e.minute, lessThanOrEqualTo(60));
      }
    });

    test('survives a window starting in stoppage time', () {
      // A tactics change during added time can hand a minMin past the last
      // playable minute; the clamp is what stops duplicates stacking on the
      // full-time marker.
      final events = generateMatchEvents(
        homeGoals: 1,
        awayGoals: 1,
        playerData: _xi(),
        minMin: 93,
        addedTime: 2,
      );
      expect(events.last.type, 'fulltime');
      expect(events.where((e) => e.type == 'goal').length, 2);
    });

    test('only commentary pools overlapping the window fire', () {
      final events = generateMatchEvents(
        homeGoals: 0,
        awayGoals: 0,
        minMin: 76,
        maxMin: 88,
      );
      for (final c in events.where((e) => e.type == 'commentary')) {
        expect(c.textKey, contains('closing'));
      }
    });
  });

  group('injuries', () {
    test('places an injury at its pre-decided minute', () {
      final events = generateMatchEvents(
        homeGoals: 0,
        awayGoals: 0,
        injuries: [(name: 'Rodrigo', minute: 37)],
      );
      final inj = events.firstWhere((e) => e.type == 'injury');
      expect(inj.minute, 37);
      expect(inj.player, 'Rodrigo');
    });

    test('places an undated injury inside the playable window', () {
      for (var i = 0; i < 40; i++) {
        final events = generateMatchEvents(
          homeGoals: 0,
          awayGoals: 0,
          injuries: [(name: 'Rodrigo', minute: null)],
        );
        final inj = events.firstWhere((e) => e.type == 'injury');
        expect(inj.minute, inInclusiveRange(20, 85));
      }
    });

    test('handles several injuries in one match', () {
      final events = generateMatchEvents(
        homeGoals: 0,
        awayGoals: 0,
        injuries: [(name: 'A', minute: 20), (name: 'B', minute: 70)],
      );
      expect(events.where((e) => e.type == 'injury').length, 2);
    });

    test('no injuries means no injury events', () {
      final events = generateMatchEvents(homeGoals: 0, awayGoals: 0);
      expect(events.where((e) => e.type == 'injury'), isEmpty);
    });
  });

  group('the RNG split', () {
    test('minutes are reproducible from the seed', () {
      // The seeded half: goal minutes and the scorer.
      List<int> run() {
        seeded.setSeed(999);
        setEventRandom(math.Random(1));
        return generateMatchEvents(
          homeGoals: 3,
          awayGoals: 2,
          playerData: _xi(),
          addedTime: 3,
        ).where((e) => e.type == 'goal').map((e) => e.minute).toList();
      }

      expect(run(), run());
    });

    test('scorers are reproducible from the seed', () {
      List<String?> run() {
        seeded.setSeed(555);
        setEventRandom(math.Random(1));
        return generateMatchEvents(
          homeGoals: 3,
          awayGoals: 0,
          playerData: _xi(),
          addedTime: 2,
        ).where((e) => e.type == 'goal').map((e) => e.scorerInstanceId).toList();
      }

      expect(run(), run());
    });

    test('chance xG comes from the UNSEEDED generator', () {
      // Deliberate: unifying the two would silently shift every seeded draw
      // and break parity with the JS.
      List<double?> run(int eventSeed) {
        seeded.setSeed(1);
        setEventRandom(math.Random(eventSeed));
        return generateMatchEvents(homeGoals: 1, awayGoals: 1, addedTime: 2)
            .where((e) => e.type == 'chance')
            .map((e) => e.xg)
            .toList();
      }

      expect(run(1), run(1));
      expect(run(1), isNot(run(2)));
    });

    test('team attribution is NOT reproducible from the seed alone', () {
      // The documented consequence of the split.
      List<String?> run(int eventSeed) {
        seeded.setSeed(1);
        setEventRandom(math.Random(eventSeed));
        return generateMatchEvents(homeGoals: 1, awayGoals: 1, addedTime: 2)
            .where((e) => e.type == 'chance')
            .map((e) => e.team)
            .toList();
      }

      expect(run(11), isNot(run(22)));
    });
  });

  group('chance weighting', () {
    test('a dominant side gets most of the chances', () {
      setEventRandom(math.Random(3));
      var home = 0;
      var away = 0;
      for (var i = 0; i < 60; i++) {
        final events = generateMatchEvents(
          homeGoals: 0,
          awayGoals: 0,
          chanceWeights: (home: 9, away: 1),
          addedTime: 2,
        );
        for (final c in events.where((e) => e.type == 'chance')) {
          if (c.team == 'home') {
            home++;
          } else {
            away++;
          }
        }
      }
      expect(home, greaterThan(away * 4));
    });

    test('falls back to the scoreline when no weights are given', () {
      setEventRandom(math.Random(5));
      var home = 0;
      var away = 0;
      for (var i = 0; i < 60; i++) {
        final events = generateMatchEvents(
          homeGoals: 5,
          awayGoals: 0,
          playerData: _xi(),
          addedTime: 2,
        );
        for (final c in events.where((e) => e.type == 'chance')) {
          if (c.team == 'home') {
            home++;
          } else {
            away++;
          }
        }
      }
      expect(home, greaterThan(away));
    });
  });

  group('toMap', () {
    test('carries minute and type for an event with nothing else', () {
      expect(const MatchEvent(minute: 45, type: 'halftime').toMap(), {
        'minute': 45,
        'type': 'halftime',
      });
    });

    test('keeps a goal scorer even when nobody is credited', () {
      // An away goal has no scorer, and the KEYS still have to be there: the
      // match screen reads them positionally against our own goals.
      expect(
        const MatchEvent(minute: 12, type: 'goal', team: 'away').toMap(),
        {
          'minute': 12,
          'type': 'goal',
          'team': 'away',
          'scorer': null,
          'scorerInstanceId': null,
        },
      );
    });

    test('omits a field nothing set, rather than writing a null', () {
      final map = const MatchEvent(
        minute: 30,
        type: 'chance',
        team: 'home',
        xg: 0.2,
        shotResult: 'on_target',
        big: false,
      ).toMap();
      expect(map.keys, isNot(contains('player')));
      expect(map, {
        'minute': 30,
        'type': 'chance',
        'team': 'home',
        'xg': 0.2,
        'shotResult': 'on_target',
        'big': false,
      });
    });

    test('carries the added time a fulltime marker was built with', () {
      expect(
        const MatchEvent(minute: 93, type: 'fulltime', addedTime: 3).toMap(),
        {'minute': 93, 'type': 'fulltime', 'addedTime': 3},
      );
    });
  });
}
