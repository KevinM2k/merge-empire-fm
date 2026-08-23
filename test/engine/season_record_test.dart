/// The season's own record, read before it is settled.
///
/// `endSeason` resets the win, draw and loss counters for the new campaign as
/// part of its work — so a summary that reads them afterwards is a summary of
/// nothing, and this is what the overview page is made of.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/season_end.dart';

Map<String, dynamic> save({
  int season = 1,
  int wins = 0,
  int draws = 0,
  int losses = 0,
  Map<String, dynamic>? results,
}) => <String, dynamic>{
  'progression': <String, dynamic>{
    'seasonCount': season,
    'seasonWins': wins,
    'seasonDraws': draws,
    'seasonLosses': losses,
    'fixtureResults': results ?? <String, dynamic>{},
  },
};

void main() {
  test('an empty save is a season with nothing in it', () {
    final r = seasonRecordOf(<String, dynamic>{});
    expect(r.wins, 0);
    expect(r.goalsFor, 0);
    expect(seasonPoints(r), 0);
  });

  test('POINTS ARE COUNTED THE WAY A TABLE COUNTS THEM', () {
    expect(seasonPoints((
      wins: 7,
      draws: 3,
      losses: 4,
      goalsFor: 0,
      goalsAgainst: 0,
    )), 24);
  });

  test('the goals come off THIS season\'s fixtures, not every season\'s', () {
    // Keyed `s{season}_m{n}`, and a save carries every season it has played.
    final r = seasonRecordOf(
      save(
        season: 2,
        results: {
          's1_m0': {'homeGoals': 9, 'awayGoals': 9},
          's2_m0': {'homeGoals': 3, 'awayGoals': 1},
          's2_m1': {'homeGoals': 0, 'awayGoals': 2},
        },
      ),
    );
    expect(r.goalsFor, 3);
    expect(r.goalsAgainst, 3);
  });

  test('AND `homeGoals` IS ALWAYS OURS, whatever the venue was', () {
    // The match engine's own convention — the same one `league_table.dart` has
    // to undo when it works out somebody else's result. Reading it as the home
    // side's would report an away win as a defeat.
    final r = seasonRecordOf(
      save(results: {
        's1_m0': {'homeGoals': 4, 'awayGoals': 0},
      }),
    );
    expect(r.goalsFor, 4);
    expect(r.goalsAgainst, 0);
  });

  test('a fixture with no result is not a nil-nil', () {
    final r = seasonRecordOf(
      save(results: {'s1_m0': 'not a map'}),
    );
    expect(r.goalsFor, 0);
    expect(r.goalsAgainst, 0);
  });

  test('and the record is the save\'s own counters', () {
    final r = seasonRecordOf(save(wins: 6, draws: 2, losses: 6));
    expect((r.wins, r.draws, r.losses), (6, 2, 6));
  });
}
