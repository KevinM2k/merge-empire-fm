import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/engine/league_pyramid.dart';
import 'package:merge_empire_fc/engine/league_table.dart';
import 'package:merge_empire_fc/engine/season_fixtures.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/sorting.dart';

Map<String, dynamic> _state({
  String clubName = 'Test Town',
  String division = 'regional_league',
  int seasonCount = 1,
  int played = 0,
  int wins = 0,
  int draws = 0,
  int matchesPlayed = 0,
  Map<String, dynamic>? pyramid,
  List<dynamic>? seasonOpponents,
  Map<String, dynamic>? seasonOpponentRatings,
  List<dynamic>? seasonFixtures,
  Map<String, dynamic>? fixtureResults,
  Map<String, dynamic>? lastSeasonStatus,
}) => {
  'clubName': clubName,
  'progression': <String, dynamic>{
    'currentDivision': division,
    'seasonCount': seasonCount,
    'seasonAwardedPlayed': played,
    'seasonMatchesPlayed': matchesPlayed,
    'seasonWins': wins,
    'seasonDraws': draws,
    'leaguePyramid': pyramid,
    'seasonOpponents': ?seasonOpponents,
    'seasonOpponentRatings': ?seasonOpponentRatings,
    'seasonFixtures': seasonFixtures,
    'fixtureResults': ?fixtureResults,
    'lastSeasonStatus': ?lastSeasonStatus,
  },
};

Map<String, dynamic> _fullPyramid() {
  final out = <String, dynamic>{};
  for (final div in divisions) {
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

LeagueRow _row(
  String name, {
  bool isPlayer = false,
  int pts = 0,
  int gd = 0,
  int won = 0,
}) => LeagueRow(
  name: name,
  isPlayer: isPlayer,
  played: 0,
  won: won,
  drawn: 0,
  lost: 0,
  pts: pts,
  gd: gd,
);

void main() {
  setUp(() => seeded.setSeed(1234));

  group('byLeaguePosition', () {
    test('points come first', () {
      final sorted = stableSorted([
        _row('B', pts: 3),
        _row('A', pts: 9),
      ], byLeaguePosition);
      expect(sorted.first.name, 'A');
    });

    test('goal difference splits equal points', () {
      final sorted = stableSorted([
        _row('A', pts: 9, gd: 1),
        _row('B', pts: 9, gd: 5),
      ], byLeaguePosition);
      expect(sorted.first.name, 'B');
    });

    test('wins split equal points and goal difference', () {
      final sorted = stableSorted([
        _row('A', pts: 9, gd: 2, won: 2),
        _row('B', pts: 9, gd: 2, won: 3),
      ], byLeaguePosition);
      expect(sorted.first.name, 'B');
    });

    test('a table nobody has played in comes out A-Z', () {
      // Without the name tiebreak a fresh season rendered in whatever order the
      // clubs happened to sit in the pyramid, which reads as random. A-Z reads
      // as "no games played".
      final sorted = stableSorted([
        _row('Zenith FC'),
        _row('Apex United'),
        _row('Meridian Town'),
      ], byLeaguePosition);
      expect(sorted.map((r) => r.name), [
        'Apex United',
        'Meridian Town',
        'Zenith FC',
      ]);
    });

    test('two identical records never swap places between renders', () {
      final rows = [_row('Beta', pts: 4), _row('Alpha', pts: 4)];
      final once = stableSorted(rows, byLeaguePosition).map((r) => r.name);
      final twice = stableSorted(
        rows.reversed.toList(),
        byLeaguePosition,
      ).map((r) => r.name);
      expect(once, twice);
    });
  });

  group('compareTeamNames', () {
    test('reproduces localeCompare across every name the banks can produce', () {
      // The JS settles the tiebreak with `localeCompare`, which Dart has no
      // equivalent for. This fixture is the whole generated name space sorted
      // by node; the port has to land on the same order or two clubs level on
      // points would sit in different places in the two versions.
      final data =
          jsonDecode(
                File('test/fixtures/team_name_order.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final expected = (data['sorted'] as List).cast<String>();
      final scrambled = expected.reversed.toList();
      expect(stableSorted(scrambled, compareTeamNames), expected);
    });

    test('an accented club sorts beside its unaccented neighbours', () {
      // Code-unit order would put every Atlético side after Zenith.
      final sorted = stableSorted([
        'Zenith Apex',
        'Atlético Apex',
        'Athletic Apex',
      ], compareTeamNames);
      expect(sorted, ['Athletic Apex', 'Atlético Apex', 'Zenith Apex']);
    });

    test('is a total order — no two distinct names compare equal', () {
      final data =
          jsonDecode(
                File('test/fixtures/team_name_order.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final names = (data['sorted'] as List).cast<String>();
      for (var i = 1; i < names.length; i++) {
        expect(
          compareTeamNames(names[i - 1], names[i]),
          lessThan(0),
          reason: '${names[i - 1]} vs ${names[i]}',
        );
      }
    });
  });

  group('buildLeagueTable — the player row', () {
    test('derives losses from the games played, not the stored counter', () {
      // Pre-fix saves accumulated losses across seasons, which showed as totals
      // that didn't add up to the games played.
      final state = _state(played: 6, wins: 4, draws: 1);
      state['progression']['seasonLosses'] = 99;
      final player = buildLeagueTable(state).firstWhere((r) => r.isPlayer);
      expect(player.lost, 1);
      expect(player.won + player.drawn + player.lost, player.played);
    });

    test('clamps wins and draws to the games actually played', () {
      final state = _state(played: 3, wins: 9, draws: 9);
      final player = buildLeagueTable(state).firstWhere((r) => r.isPlayer);
      expect(player.won, 3);
      expect(player.drawn, 0);
      expect(player.lost, 0);
    });

    test('scores three for a win and one for a draw', () {
      final state = _state(played: 5, wins: 3, draws: 1);
      final player = buildLeagueTable(state).firstWhere((r) => r.isPlayer);
      expect(player.pts, 10);
    });

    test('falls back to a placeholder name for an unnamed club', () {
      final state = _state(clubName: '');
      expect(buildLeagueTable(state).firstWhere((r) => r.isPlayer).name, 'Your Club');
    });

    test('reads seasonAwardedPlayed, so the table holds still mid-match', () {
      // seasonMatchesPlayed increments when the sim starts; the awarded counter
      // increments when the rewards land. Using the wrong one made the table
      // shift under the player while the match was on screen.
      final state = _state(played: 4, matchesPlayed: 5, wins: 4);
      expect(buildLeagueTable(state).firstWhere((r) => r.isPlayer).played, 4);
    });
  });

  group('buildLeagueTable — the standings', () {
    Map<String, dynamic> midSeason({int played = 6}) {
      final state = _state(pyramid: _fullPyramid());
      initSeasonOpponents(state);
      final prog = state['progression'] as Map<String, dynamic>;
      prog['seasonAwardedPlayed'] = played;
      prog['seasonMatchesPlayed'] = played;
      prog['seasonWins'] = 4;
      prog['seasonDraws'] = 1;
      prog['fixtureResults'] = {
        for (var i = 0; i < played; i++)
          's1_m$i': {'homeGoals': 2, 'awayGoals': 1},
      };
      return state;
    }

    test('is eight rows — the player plus seven opponents', () {
      expect(buildLeagueTable(midSeason()).length, teamsPerLeague);
    });

    test('every club has played the same number of games', () {
      for (final row in buildLeagueTable(midSeason())) {
        expect(row.played, 6, reason: row.name);
      }
    });

    test("each club's record adds up to its games played", () {
      for (final row in buildLeagueTable(midSeason())) {
        expect(row.won + row.drawn + row.lost, row.played, reason: row.name);
      }
    });

    test('points are consistent with the record', () {
      for (final row in buildLeagueTable(midSeason())) {
        expect(row.pts, row.won * 3 + row.drawn, reason: row.name);
      }
    });

    test('comes out in descending league order', () {
      final rows = buildLeagueTable(midSeason());
      for (var i = 1; i < rows.length; i++) {
        expect(byLeaguePosition(rows[i - 1], rows[i]), lessThanOrEqualTo(0));
      }
    });

    test('nothing is counted before the season starts', () {
      final state = _state(pyramid: _fullPyramid());
      initSeasonOpponents(state);
      for (final row in buildLeagueTable(state)) {
        expect(row.played, 0, reason: row.name);
        expect(row.pts, 0, reason: row.name);
      }
    });

    test('only rounds up to the current one are counted', () {
      final six = buildLeagueTable(midSeason(played: 6));
      final ten = buildLeagueTable(midSeason(played: 10));
      expect(six.first.played, 6);
      expect(ten.first.played, 10);
    });

    test('an unplayed player fixture is skipped rather than counted as a draw', () {
      final state = midSeason();
      (state['progression']['fixtureResults'] as Map).remove('s1_m3');
      final rows = buildLeagueTable(state);
      // The two clubs that met the player in that round have a game in hand.
      expect(rows.where((r) => !r.isPlayer && r.played == 5).length, 1);
    });

    test('the player is stored under their own key, not their club name', () {
      // A club can be renamed mid-season, which would otherwise read as one
      // side leaving the division and another arriving.
      final state = midSeason();
      buildLeagueTable(state);
      final positions =
          state['progression']['opponentTablePositions'] as Map<String, dynamic>;
      expect(positions.containsKey('Test Town'), isFalse);
      expect(state['progression']['playerTablePosition'], isA<int>());
    });

    test('caches every opponent position for the match engine to read', () {
      final state = midSeason();
      final rows = buildLeagueTable(state);
      final positions =
          state['progression']['opponentTablePositions'] as Map<String, dynamic>;
      expect(positions.length, teamsPerLeague - 1);
      for (var i = 0; i < rows.length; i++) {
        if (rows[i].isPlayer) continue;
        expect(positions[rows[i].name], i + 1);
      }
    });

    test('renaming the club keeps its position', () {
      final state = midSeason();
      final before = buildLeagueTable(state).indexWhere((r) => r.isPlayer);
      state['clubName'] = 'Renamed Rovers';
      final after = buildLeagueTable(state).indexWhere((r) => r.isPlayer);
      expect(after, before);
    });

    test('a physically away player result is folded in the right way round', () {
      // The match engine stores homeGoals as the PLAYER's goals whatever the
      // venue, so an away win has to be swapped before it reaches the table.
      final state = midSeason(played: 14);
      final fixtures = state['progression']['seasonFixtures'] as List;
      // Some rounds are home and some away; take the first away leg whatever
      // the schedule happened to draw.
      final away = fixtures
          .cast<Map<String, dynamic>>()
          .where((f) => f['playerMatchNum'] != null && f['homeTeam'] != null)
          .first;
      final num = away['playerMatchNum'] as int;
      final opponentName = away['homeTeam'] as String;

      LeagueRow rowFor(Map<String, dynamic> results) {
        state['progression']['fixtureResults'] = results;
        return buildLeagueTable(state).firstWhere((r) => r.name == opponentName);
      }

      // The opponent's other games are the same either way, so the delta is
      // this one result and nothing else.
      final without = rowFor(<String, dynamic>{});
      final with5 = rowFor({
        's1_m$num': {'homeGoals': 5, 'awayGoals': 0},
      });

      // The player won 5-0 AWAY, so the club listed at home lost by five.
      expect(with5.lost - without.lost, 1);
      expect(with5.gd - without.gd, -5);
      expect(with5.won, without.won);
    });
  });

  group('buildLeagueTable — position movement', () {
    Map<String, dynamic> movingState() {
      final state = _state(pyramid: _fullPyramid());
      initSeasonOpponents(state);
      return state;
    }

    void playTo(Map<String, dynamic> state, int round) {
      final prog = state['progression'] as Map<String, dynamic>;
      prog['seasonAwardedPlayed'] = round;
      prog['seasonWins'] = round;
      prog['fixtureResults'] = {
        for (var i = 0; i < round; i++)
          's1_m$i': {'homeGoals': 3, 'awayGoals': 0},
      };
    }

    test('the first table of a season has nothing to compare against', () {
      final state = movingState();
      for (final row in buildLeagueTable(state)) {
        expect(row.prevPos, isNull);
        expect(row.posDelta, isNull);
      }
    });

    test('is idempotent — rendering twice in a round changes nothing', () {
      final state = movingState();
      playTo(state, 1);
      buildLeagueTable(state);
      playTo(state, 2);
      final first = buildLeagueTable(state).map((r) => r.prevPos).toList();
      final second = buildLeagueTable(state).map((r) => r.prevPos).toList();
      expect(second, first);
    });

    test('a climb reads as a positive delta', () {
      final state = movingState();
      playTo(state, 1);
      buildLeagueTable(state);
      playTo(state, 2);
      final rows = buildLeagueTable(state);
      for (final row in rows) {
        if (row.prevPos == null) continue;
        final pos = rows.indexOf(row) + 1;
        expect(row.posDelta, row.prevPos! - pos, reason: row.name);
      }
    });

    test('a skipped round breaks the comparison rather than faking one', () {
      final state = movingState();
      playTo(state, 1);
      buildLeagueTable(state);
      playTo(state, 5);
      for (final row in buildLeagueTable(state)) {
        expect(row.prevPos, isNull, reason: row.name);
      }
    });

    test('a season rollover clears it — round 1 is not compared to last May', () {
      final state = movingState();
      playTo(state, 3);
      buildLeagueTable(state);
      state['progression']['seasonCount'] = 2;
      playTo(state, 0);
      for (final row in buildLeagueTable(state)) {
        expect(row.prevPos, isNull, reason: row.name);
      }
    });
  });

  group('buildPyramidTable', () {
    Map<String, dynamic> peeking({int matchesPlayed = 14}) =>
        _state(pyramid: _fullPyramid(), matchesPlayed: matchesPlayed);

    test('shows all eight clubs — the player is not in this league', () {
      final rows = buildPyramidTable(peeking(), 'elite_league');
      expect(rows.length, teamsPerLeague);
      expect(rows.every((r) => !r.isPlayer), isTrue);
    });

    test('records add up to games played', () {
      for (final row in buildPyramidTable(peeking(), 'elite_league')) {
        expect(row.won + row.drawn + row.lost, row.played, reason: row.name);
      }
    });

    test('a full campaign is 14 games, matching the player own season', () {
      for (final row in buildPyramidTable(peeking(), 'elite_league')) {
        expect(row.played, 14, reason: row.name);
      }
    });

    test('the league is zero-sum on goal difference', () {
      final rows = buildPyramidTable(peeking(), 'elite_league');
      expect(rows.fold<int>(0, (s, r) => s + r.gd), 0);
    });

    test('wins and losses balance across the division', () {
      final rows = buildPyramidTable(peeking(), 'elite_league');
      expect(
        rows.fold<int>(0, (s, r) => s + r.won),
        rows.fold<int>(0, (s, r) => s + r.lost),
      );
    });

    test('draws are always shared, so the total is even', () {
      final rows = buildPyramidTable(peeking(), 'elite_league');
      expect(rows.fold<int>(0, (s, r) => s + r.drawn) % 2, 0);
    });

    test('draws vary between clubs rather than collapsing onto one number', () {
      // The bug this replaced: `round(played * 0.12)` was the same number for
      // everybody, so a whole division shared a draw count all season.
      final drawCounts = buildPyramidTable(
        peeking(),
        'elite_league',
      ).map((r) => r.drawn).toSet();
      expect(drawCounts.length, greaterThan(1));
    });

    test('records differ between clubs at low match counts too', () {
      // At two games played the old rounding put all eight on 1W 0D 1L.
      final rows = buildPyramidTable(peeking(matchesPlayed: 2), 'elite_league');
      final records = rows.map((r) => '${r.won}/${r.drawn}/${r.lost}').toSet();
      expect(records.length, greaterThan(1));
    });

    test('form is the real tail of the sequence, capped at five', () {
      for (final row in buildPyramidTable(peeking(), 'elite_league')) {
        expect(row.form.length, 5, reason: row.name);
        expect(row.form.every((c) => 'WDL'.contains(c)), isTrue);
      }
    });

    test('form agrees with the record it came from', () {
      final rows = buildPyramidTable(peeking(matchesPlayed: 4), 'elite_league');
      for (final row in rows) {
        expect(row.form.where((c) => c == 'W').length, row.won, reason: row.name);
        expect(row.form.where((c) => c == 'D').length, row.drawn, reason: row.name);
      }
    });

    test('carries each club rating and shape through onto the row', () {
      for (final row in buildPyramidTable(peeking(), 'elite_league')) {
        expect(row.rating, isNotNull);
        expect(row.formation, '4-4-2');
        expect(row.attackRatio, 0.402);
      }
    });

    test('nothing has been played before the season starts', () {
      final rows = buildPyramidTable(peeking(matchesPlayed: 0), 'elite_league');
      expect(rows.every((r) => r.played == 0), isTrue);
      expect(rows.every((r) => r.form.isEmpty), isTrue);
    });

    test('a campaign cannot run past its own round robin', () {
      final rows = buildPyramidTable(peeking(matchesPlayed: 99), 'elite_league');
      expect(rows.every((r) => r.played == 14), isTrue);
    });

    test('an unknown division is an empty table, not a crash', () {
      expect(buildPyramidTable(peeking(), 'not_a_division'), isEmpty);
    });

    test('comes out in league order', () {
      final rows = buildPyramidTable(peeking(), 'elite_league');
      for (var i = 1; i < rows.length; i++) {
        expect(byLeaguePosition(rows[i - 1], rows[i]), lessThanOrEqualTo(0));
      }
    });

    test('the same league renders identically on every visit', () {
      final state = peeking();
      final once = buildPyramidTable(state, 'elite_league');
      buildPyramidTable(state, 'sunday_league');
      final twice = buildPyramidTable(state, 'elite_league');
      expect(
        twice.map((r) => '${r.name}:${r.pts}:${r.gd}'),
        once.map((r) => '${r.name}:${r.pts}:${r.gd}'),
      );
    });

    test('two different leagues get different tables', () {
      final state = peeking();
      final elite = buildPyramidTable(state, 'elite_league');
      final sunday = buildPyramidTable(state, 'sunday_league');
      expect(
        elite.map((r) => r.pts).toList(),
        isNot(sunday.map((r) => r.pts).toList()),
      );
    });

    test('a new season re-plays the league differently', () {
      final state = peeking();
      final first = buildPyramidTable(state, 'elite_league').map((r) => r.pts).toList();
      state['progression']['seasonCount'] = 2;
      final second = buildPyramidTable(state, 'elite_league').map((r) => r.pts).toList();
      expect(second, isNot(first));
    });

    test('nothing about the table is written back to the save', () {
      final state = peeking();
      final before = jsonEncode(state['progression']['leaguePyramid']);
      buildPyramidTable(state, 'elite_league');
      expect(jsonEncode(state['progression']['leaguePyramid']), before);
    });

    test('a stronger club tends to finish above a weaker one', () {
      final pyramid = _fullPyramid();
      pyramid['elite_league'] = [
        {'name': 'Titan', 'rating': 95, 'formation': '4-4-2', 'attackRatio': 0.402},
        for (var i = 1; i < teamsPerLeague; i++)
          {
            'name': 'Minnow $i',
            'rating': 40,
            'formation': '4-4-2',
            'attackRatio': 0.402,
          },
      ];
      final state = _state(pyramid: pyramid, matchesPlayed: 14);
      expect(buildPyramidTable(state, 'elite_league').first.name, 'Titan');
    });
  });

  group('seasonStatusFor', () {
    LeagueRow ai(String name) => _row(name);
    final player = _row('Test Town', isPlayer: true);

    Map<String, dynamic> withStatus() => _state(
      lastSeasonStatus: {
        'season': 3,
        'player': 'promoted',
        'playerDivision': 'national_league',
        'teams': {
          'Riser FC': {'status': 'promoted', 'division': 'national_league'},
          'Faller FC': {'status': 'relegated', 'division': 'amateur_cup'},
          'Winner FC': {'status': 'champion', 'division': 'champions_cup'},
        },
      },
    );

    test('badges a club in the league its move landed in', () {
      expect(
        seasonStatusFor(withStatus(), 'national_league', ai('Riser FC')),
        'promoted',
      );
    });

    test('never badges a club in the league it left', () {
      expect(
        seasonStatusFor(withStatus(), 'regional_league', ai('Riser FC')),
        isNull,
      );
    });

    test('the top flight keeps its champion', () {
      expect(
        seasonStatusFor(withStatus(), 'champions_cup', ai('Winner FC')),
        'champion',
      );
    });

    test('a relegated club is badged where it landed', () {
      expect(
        seasonStatusFor(withStatus(), 'amateur_cup', ai('Faller FC')),
        'relegated',
      );
    });

    test('the player badge is stored apart from the name map', () {
      // An unnamed save's "Your Club" would otherwise collide with an AI side.
      expect(
        seasonStatusFor(withStatus(), 'national_league', player),
        'promoted',
      );
      expect(
        seasonStatusFor(withStatus(), 'regional_league', player),
        isNull,
      );
    });

    test('an unknown club has no badge', () {
      expect(
        seasonStatusFor(withStatus(), 'national_league', ai('Nobody')),
        isNull,
      );
    });

    test('a save with no record badges nobody', () {
      expect(seasonStatusFor(_state(), 'national_league', ai('Riser FC')), isNull);
    });

    test('a null state and a null row are both safe', () {
      expect(seasonStatusFor(null, 'national_league', ai('Riser FC')), isNull);
      expect(seasonStatusFor(withStatus(), 'national_league', null), isNull);
    });
  });
}
