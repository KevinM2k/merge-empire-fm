import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/engine/league_pyramid.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/season_fixtures.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;

Map<String, dynamic> _state({
  String division = 'regional_league',
  int seasonCount = 1,
  Map<String, dynamic>? pyramid,
  List<dynamic>? seasonOpponents,
  Map<String, dynamic>? seasonOpponentRatings,
  List<dynamic>? seasonFixtures,
}) => {
  'progression': <String, dynamic>{
    'currentDivision': division,
    'seasonCount': seasonCount,
    'leaguePyramid': pyramid,
    'seasonOpponents': ?seasonOpponents,
    'seasonOpponentRatings': ?seasonOpponentRatings,
    'seasonFixtures': seasonFixtures,
  },
};

Map<String, dynamic> _fullPyramid({
  String? tweakDiv,
  List<Map<String, dynamic>>? tweakTeams,
}) {
  final out = <String, dynamic>{};
  for (final div in divisions) {
    if (div.id == tweakDiv && tweakTeams != null) {
      out[div.id] = tweakTeams;
      continue;
    }
    final mid = (div.opponentRatingRange.$1 + div.opponentRatingRange.$2) ~/ 2;
    out[div.id] = [
      for (var i = 0; i < teamsPerLeague; i++)
        <String, dynamic>{
          'name': '${div.id}_$i',
          'rating': mid + i,
          'formation': '4-4-2',
          'attackRatio': 0.402,
        },
    ];
  }
  return out;
}

List<Map<String, dynamic>> _fixtures(Map<String, dynamic> state) => [
  for (final f in state['progression']['seasonFixtures'] as List)
    f as Map<String, dynamic>,
];

void main() {
  setUp(() => seeded.setSeed(1234));

  group('aiSchedule', () {
    test('is a valid single round robin among the seven AI clubs', () {
      final met = <String>{};
      for (final round in aiSchedule) {
        for (final pair in round) {
          final key = '${[...pair]..sort()}';
          expect(met.contains(key), isFalse, reason: 'repeat pairing $key');
          met.add(key);
        }
      }
      // 7 clubs pair up 21 ways; each round plays 3 and one club has the bye.
      expect(met.length, 21);
    });

    test('the club the player faces has the bye that round', () {
      for (var r = 0; r < aiSchedule.length; r++) {
        for (final pair in aiSchedule[r]) {
          expect(pair, isNot(contains(r)), reason: 'round $r');
        }
      }
    });

    test('every club plays exactly six inter-AI games across the seven rounds', () {
      final counts = List<int>.filled(7, 0);
      for (final round in aiSchedule) {
        for (final pair in round) {
          counts[pair[0]]++;
          counts[pair[1]]++;
        }
      }
      expect(counts, List.filled(7, 6));
    });
  });

  group('simulateAiFixture', () {
    test('gives the home side the advantage on both of its numbers', () {
      seeded.setSeed(7);
      var homeGoals = 0;
      var awayGoals = 0;
      for (var i = 0; i < 4000; i++) {
        final r = simulateAiFixture(60, 60, 60, 60);
        homeGoals += r.homeGoals;
        awayGoals += r.awayGoals;
      }
      expect(homeGoals, greaterThan(awayGoals));
    });

    test('a stronger attack against a weaker defence scores more', () {
      seeded.setSeed(9);
      var strong = 0;
      for (var i = 0; i < 2000; i++) {
        strong += simulateAiFixture(85, 60, 60, 40).homeGoals;
      }
      seeded.setSeed(9);
      var weak = 0;
      for (var i = 0; i < 2000; i++) {
        weak += simulateAiFixture(40, 60, 60, 85).homeGoals;
      }
      expect(strong, greaterThan(weak * 3));
    });

    test('is deterministic for a given seed', () {
      seeded.setSeed(3);
      final a = [for (var i = 0; i < 10; i++) simulateAiFixture(62, 58, 55, 60)];
      seeded.setSeed(3);
      final b = [for (var i = 0; i < 10; i++) simulateAiFixture(62, 58, 55, 60)];
      expect(a, b);
    });
  });

  group('generateSeasonFixtures', () {
    Map<String, dynamic> readyState() {
      final state = _state(pyramid: _fullPyramid());
      initSeasonOpponents(state);
      return state;
    }

    test('draws 56 fixtures — 14 rounds of four games', () {
      final fixtures = _fixtures(readyState());
      expect(fixtures.length, 56);
      final byRound = <int, int>{};
      for (final f in fixtures) {
        byRound[f['round'] as int] = (byRound[f['round'] as int] ?? 0) + 1;
      }
      expect(byRound.keys.toList()..sort(), [for (var r = 1; r <= 14; r++) r]);
      expect(byRound.values.toSet(), {4});
    });

    test('the player appears in exactly one fixture per round', () {
      final fixtures = _fixtures(readyState());
      final playerSlots = fixtures.where((f) => f['playerMatchNum'] != null);
      expect(playerSlots.length, matchesPerSeason);
      expect(
        playerSlots.map((f) => f['round']).toSet().length,
        matchesPerSeason,
      );
    });

    test('the player plays each opponent home and away', () {
      final state = readyState();
      final opponents = (state['progression']['seasonOpponents'] as List).cast<String>();
      for (final name in opponents) {
        final games = _fixtures(state).where(
          (f) =>
              f['playerMatchNum'] != null &&
              (f['homeTeam'] == name || f['awayTeam'] == name),
        );
        expect(games.length, 2, reason: name);
        // One leg each way — exactly one of the two has the player at home.
        expect(games.where((f) => f['homeTeam'] == null).length, 1, reason: name);
      }
    });

    test('the player slots are left blank for the match engine to fill', () {
      for (final f in _fixtures(readyState())) {
        if (f['playerMatchNum'] == null) continue;
        expect(f['homeGoals'], isNull);
        expect(f['awayGoals'], isNull);
      }
    });

    test('every AI game is pre-simulated', () {
      for (final f in _fixtures(readyState())) {
        if (f['playerMatchNum'] != null) continue;
        expect(f['homeGoals'], isA<int>());
        expect(f['awayGoals'], isA<int>());
        expect(f['homeTeam'], isNotNull);
        expect(f['awayTeam'], isNotNull);
      }
    });

    test('the second leg reverses the first leg venue, AI games included', () {
      final fixtures = _fixtures(readyState());
      for (var r = 1; r <= 7; r++) {
        final first = fixtures.where((f) => f['round'] == r).toList();
        final second = fixtures.where((f) => f['round'] == r + 7).toList();
        expect(first.length, second.length);
        for (var i = 0; i < first.length; i++) {
          expect(second[i]['homeTeam'], first[i]['awayTeam']);
          expect(second[i]['awayTeam'], first[i]['homeTeam']);
        }
      }
    });

    test('playerMatchNum runs 0..13 with no gaps', () {
      final nums = [
        for (final f in _fixtures(readyState()))
          if (f['playerMatchNum'] != null) f['playerMatchNum'] as int,
      ]..sort();
      expect(nums, [for (var i = 0; i < matchesPerSeason; i++) i]);
    });

    test('a stronger league produces a table of stronger clubs, not more goals', () {
      // ATK and DEF both rise with rating, so a top-flight round robin should
      // not run away with the scoring.
      seeded.setSeed(21);
      int totalGoals(String division) {
        final state = _state(division: division, pyramid: _fullPyramid());
        initSeasonOpponents(state);
        return _fixtures(state)
            .where((f) => f['playerMatchNum'] == null)
            .fold(0, (sum, f) => sum + (f['homeGoals'] as int) + (f['awayGoals'] as int));
      }

      final low = totalGoals('sunday_league');
      final high = totalGoals('champions_cup');
      expect(high, closeTo(low, low * 0.5));
    });

    test('an attacking league outscores a defensive one at the same rating', () {
      List<Map<String, dynamic>> shaped(String formation, double ratio) => [
        for (var i = 0; i < teamsPerLeague; i++)
          {
            'name': 'Club $i',
            'rating': 60,
            'formation': formation,
            'attackRatio': ratio,
          },
      ];

      int goalsFor(String formation, double ratio) {
        seeded.setSeed(64);
        final state = _state(
          pyramid: _fullPyramid(
            tweakDiv: 'regional_league',
            tweakTeams: shaped(formation, ratio),
          ),
        );
        initSeasonOpponents(state);
        return _fixtures(state)
            .where((f) => f['playerMatchNum'] == null)
            .fold(0, (s, f) => s + (f['homeGoals'] as int) + (f['awayGoals'] as int));
      }

      expect(goalsFor('3-4-3', 0.457), greaterThan(goalsFor('5-4-1', 0.348)));
    });

    test('is deterministic for a given seed', () {
      seeded.setSeed(404);
      final a = _state(pyramid: _fullPyramid());
      initSeasonOpponents(a);
      seeded.setSeed(404);
      final b = _state(pyramid: _fullPyramid());
      initSeasonOpponents(b);
      expect(_fixtures(a), _fixtures(b));
    });
  });

  group('initSeasonOpponents', () {
    test('takes the first seven clubs from the division', () {
      final state = _state(pyramid: _fullPyramid());
      initSeasonOpponents(state);
      expect(state['progression']['seasonOpponents'], [
        for (var i = 0; i < opponentsPerSeason; i++) 'regional_league_$i',
      ]);
    });

    test('seeds each opponent rating from its pyramid entry', () {
      final state = _state(pyramid: _fullPyramid());
      initSeasonOpponents(state);
      final ratings =
          state['progression']['seasonOpponentRatings'] as Map<String, dynamic>;
      final mid =
          (getDivision('regional_league').opponentRatingRange.$1 +
              getDivision('regional_league').opponentRatingRange.$2) ~/
          2;
      expect(ratings['s1_o0'], mid);
      expect(ratings['s1_o6'], mid + 6);
    });

    test('never overwrites a rating already banked for this season', () {
      final state = _state(
        pyramid: _fullPyramid(),
        seasonOpponentRatings: {'s1_o0': 99},
      );
      initSeasonOpponents(state);
      expect(state['progression']['seasonOpponentRatings']['s1_o0'], 99);
    });

    test('keys ratings by season, so a new campaign gets fresh ones', () {
      final state = _state(pyramid: _fullPyramid(), seasonCount: 3);
      initSeasonOpponents(state);
      final ratings =
          state['progression']['seasonOpponentRatings'] as Map<String, dynamic>;
      expect(ratings.keys.every((k) => k.startsWith('s3_')), isTrue);
    });

    test('pads a short division with invented clubs', () {
      final state = _state(
        pyramid: _fullPyramid(
          tweakDiv: 'regional_league',
          tweakTeams: [
            {
              'name': 'Alone',
              'rating': 45,
              'formation': '4-4-2',
              'attackRatio': 0.402,
            },
          ],
        ),
      );
      initSeasonOpponents(state);
      final names = (state['progression']['seasonOpponents'] as List).cast<String>();
      expect(names.length, opponentsPerSeason);
      // The top-up inside ensureLeaguePyramid fills the league first, so the
      // survivor is still the club the season opens against.
      expect(names.first, 'Alone');
      expect(names.toSet().length, opponentsPerSeason);
    });

    test('drops the legacy departed-teams marker', () {
      final state = _state(pyramid: _fullPyramid());
      state['progression']['_departedTeams'] = ['Someone'];
      initSeasonOpponents(state);
      expect(state['progression'].containsKey('_departedTeams'), isFalse);
    });

    test('keeps a schedule a save arrived with', () {
      // A loaded save is mid-season; regenerating would throw away every result
      // in the table.
      final existing = [
        {'round': 1, 'homeTeam': 'A', 'awayTeam': 'B', 'homeGoals': 2, 'awayGoals': 1},
      ];
      final state = _state(pyramid: _fullPyramid(), seasonFixtures: existing);
      initSeasonOpponents(state);
      expect(state['progression']['seasonFixtures'], existing);
    });

    test('a division that no longer exists still gets a playable season', () {
      // The pyramid has nothing under an unknown id, so the padding and the
      // rating fallback are the only things standing between a retired
      // division in an old save and a crash on the League tab.
      final state = _state(division: 'retired_league', pyramid: _fullPyramid());
      initSeasonOpponents(state);
      final names = (state['progression']['seasonOpponents'] as List).cast<String>();
      expect(names.length, opponentsPerSeason);
      expect(names.toSet().length, opponentsPerSeason);
      final ratings =
          state['progression']['seasonOpponentRatings'] as Map<String, dynamic>;
      expect(ratings.length, opponentsPerSeason);
      // getDivision falls back to the first division, so the invented ratings
      // land in Sunday League's band rather than nowhere.
      final (lo, hi) = divisions.first.opponentRatingRange;
      for (final r in ratings.values) {
        expect(r, inInclusiveRange(lo, hi));
      }
      expect((state['progression']['seasonFixtures'] as List).length, 56);
    });

    test('builds the pyramid when a save has none', () {
      final state = _state();
      initSeasonOpponents(state);
      expect(state['progression']['leaguePyramid'], isNotNull);
      expect(
        (state['progression']['seasonOpponents'] as List).length,
        opponentsPerSeason,
      );
    });
  });

  group('getSeasonOpponents', () {
    test('returns the stored opponents when there are any', () {
      final state = _state(
        seasonOpponents: [for (var i = 0; i < 9; i++) 'Rival $i'],
      );
      expect(getSeasonOpponents('regional_league', 1, state), [
        for (var i = 0; i < opponentsPerSeason; i++) 'Rival $i',
      ]);
    });

    test('invents a set when the save has none', () {
      final names = getSeasonOpponents('regional_league', 1, _state());
      expect(names.length, opponentsPerSeason);
      expect(names.toSet().length, opponentsPerSeason);
    });

    test('draws from the tier the division belongs to', () {
      seeded.setSeed(5);
      final pro = getSeasonOpponents('champions_cup', 1, null);
      // The Pro bank is `prefix noun` with no `FC`-style suffix bank behind it.
      expect(pro.every((n) => n.split(' ').length >= 2), isTrue);
    });

    test('tolerates a null state', () {
      expect(getSeasonOpponents('sunday_league', 1, null).length, opponentsPerSeason);
    });

    test('a tampered non-list opponents field is ignored', () {
      final state = _state();
      state['progression']['seasonOpponents'] = 'not a list';
      expect(
        getSeasonOpponents('regional_league', 1, state).length,
        opponentsPerSeason,
      );
    });
  });

  group('generateSeasonFixtures on a bare state', () {
    test('creates the progression branch rather than throwing', () {
      final state = <String, dynamic>{};
      generateSeasonFixtures(state);
      // No opponents means no games, but the save comes back well-formed.
      expect(state['progression'], isA<Map<String, dynamic>>());
      expect(state['progression']['seasonFixtures'], isA<List<dynamic>>());
    });
  });
}
