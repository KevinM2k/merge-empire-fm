/// Differential test: the Dart league layer against the JS it was ported from.
///
/// Every expectation in here was produced by running the real
/// `progressionEngine.js` under node — see `tool/dump_progression_reference.mjs`.
/// Each scenario resets the shared seed first, so these pin the RNG draw ORDER
/// as well as the arithmetic. A port can get every formula right and still be
/// wrong if it draws its numbers in a different order, and nothing written by
/// hand catches that.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/engine/league_pyramid.dart';
import 'package:merge_empire_fc/engine/league_table.dart';
import 'package:merge_empire_fc/engine/season_fixtures.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;

final Map<String, dynamic> ref = jsonDecode(
  File('test/fixtures/progression_reference.json').readAsStringSync(),
) as Map<String, dynamic>;

Map<String, dynamic> _baseState([Map<String, dynamic> over = const {}]) => {
  'clubName': 'Test Town',
  'progression': <String, dynamic>{
    'currentDivision': 'regional_league',
    'seasonCount': 1,
    'seasonMatchesPlayed': 0,
    'seasonAwardedPlayed': 0,
    'seasonWins': 0,
    'seasonDraws': 0,
    'seasonLosses': 0,
    'leaguePyramid': null,
    'seasonOpponents': <dynamic>[],
    'seasonOpponentRatings': <String, dynamic>{},
    'seasonFixtures': null,
    'fixtureResults': <String, dynamic>{},
    ...over,
  },
};

/// A pyramid with a full, predictable complement in every division — the same
/// one the node script builds.
Map<String, dynamic> _fullPyramid() {
  final out = <String, dynamic>{};
  for (final div in divisions) {
    final mid =
        (div.opponentRatingRange.$1 + div.opponentRatingRange.$2) ~/ 2;
    out[div.id] = [
      for (var i = 0; i < 8; i++)
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

/// A league row in the JS's own shape, so the two can be compared as JSON.
Map<String, dynamic> _rowJson(LeagueRow r, {bool pyramid = false}) => {
  'name': r.name,
  if (pyramid) 'rating': r.rating,
  if (pyramid) 'formation': r.formation,
  if (pyramid) 'attackRatio': r.attackRatio,
  'isPlayer': r.isPlayer,
  'played': r.played,
  'won': r.won,
  'drawn': r.drawn,
  'lost': r.lost,
  'pts': r.pts,
  'gd': r.gd,
  if (pyramid) 'form': r.form,
  if (!pyramid) 'prevPos': r.prevPos,
  if (!pyramid) 'posDelta': r.posDelta,
};

List<Map<String, dynamic>> _rowsJson(
  List<LeagueRow> rows, {
  bool pyramid = false,
}) => [for (final r in rows) _rowJson(r, pyramid: pyramid)];

void main() {
  group('ensureLeaguePyramid', () {
    test('builds the JS pyramid, club for club and rating for rating', () {
      seeded.setSeed(4242);
      final state = _baseState();
      expect(ensureLeaguePyramid(state), ref['freshPyramid']);
    });

    test('carries legacy rivals across exactly as the JS does', () {
      seeded.setSeed(909);
      final state = _baseState({
        'seasonOpponents': [for (var i = 0; i < 7; i++) 'Old Rival $i'],
        'seasonOpponentRatings': {'s1_o0': 61, 's1_o3': 55},
      });
      expect(ensureLeaguePyramid(state), ref['legacyCarryPyramid']);
    });
  });

  group('shufflePyramid', () {
    test('moves the same clubs the JS moves, with the same new ratings', () {
      seeded.setSeed(31337);
      final state = _baseState({'leaguePyramid': _fullPyramid()});
      final statuses = <String, dynamic>{};
      shufflePyramid(state, statuses: statuses);
      expect(state['progression']['leaguePyramid'], ref['shuffled']);
      expect(statuses, ref['shuffledStatuses']);
    });

    test('honours skipDivId and recentlyMoved identically', () {
      seeded.setSeed(31337);
      final state = _baseState({'leaguePyramid': _fullPyramid()});
      shufflePyramid(
        state,
        skipDivId: 'regional_league',
        recentlyMoved: {'regional_league_0'},
      );
      expect(
        state['progression']['leaguePyramid'],
        ref['shuffledSkippingPlayerDivision'],
      );
    });
  });

  group('initSeasonOpponents', () {
    test('picks the same seven clubs and seeds the same ratings', () {
      seeded.setSeed(777);
      final state = _baseState({'leaguePyramid': _fullPyramid()});
      initSeasonOpponents(state);
      expect(state['progression']['seasonOpponents'], ref['seasonOpponents']);
      expect(
        state['progression']['seasonOpponentRatings'],
        ref['seasonOpponentRatings'],
      );
    });

    test('generates all 56 fixtures with identical simulated scorelines', () {
      seeded.setSeed(777);
      final state = _baseState({'leaguePyramid': _fullPyramid()});
      initSeasonOpponents(state);
      expect(state['progression']['seasonFixtures'], ref['seasonFixtures']);
    });

    test('a later season flips the venues the same way', () {
      // The home/away seed folds seasonCount in, so this is the check that the
      // schedule reverses on the same fixtures the JS reverses.
      seeded.setSeed(777);
      final state = _baseState({
        'leaguePyramid': _fullPyramid(),
        'seasonCount': 4,
      });
      initSeasonOpponents(state);
      expect(
        state['progression']['seasonFixtures'],
        ref['seasonFixturesSeason4'],
      );
    });
  });

  group('buildLeagueTable', () {
    Map<String, dynamic> playedSixState() => _baseState({
      'leaguePyramid': _fullPyramid(),
    });

    void playSix(Map<String, dynamic> state) {
      final prog = state['progression'] as Map<String, dynamic>;
      prog['seasonAwardedPlayed'] = 6;
      prog['seasonMatchesPlayed'] = 6;
      prog['seasonWins'] = 4;
      prog['seasonDraws'] = 1;
      prog['fixtureResults'] = {
        's1_m0': {'homeGoals': 3, 'awayGoals': 1},
        's1_m1': {'homeGoals': 0, 'awayGoals': 2},
        's1_m2': {'homeGoals': 2, 'awayGoals': 2},
        's1_m3': {'homeGoals': 1, 'awayGoals': 0},
        's1_m4': {'homeGoals': 4, 'awayGoals': 2},
        's1_m5': {'homeGoals': 2, 'awayGoals': 0},
      };
    }

    test('produces the JS standings, in the JS order', () {
      seeded.setSeed(555);
      final state = playedSixState();
      initSeasonOpponents(state);
      playSix(state);
      expect(_rowsJson(buildLeagueTable(state)), ref['leagueTable']);
    });

    test('caches the same positions back onto the save', () {
      seeded.setSeed(555);
      final state = playedSixState();
      initSeasonOpponents(state);
      playSix(state);
      buildLeagueTable(state);
      final prog = state['progression'] as Map<String, dynamic>;
      expect(prog['opponentTablePositions'], ref['leagueTablePositions']);
      expect(prog['playerTablePosition'], ref['leagueTablePlayerPosition']);
      expect(prog['tablePos'], ref['leagueTableTablePos']);
    });

    test('the legacy fabricated table matches too', () {
      // Saves predating the fixture schedule still have to render, and the
      // fabrication is pure arithmetic off a seed — an easy thing to get subtly
      // wrong between two languages' rounding.
      seeded.setSeed(555);
      final state = _baseState({
        'leaguePyramid': _fullPyramid(),
        'seasonOpponents': [for (var i = 0; i < 7; i++) 'Rival $i'],
        'seasonOpponentRatings': {'s1_o0': 61, 's1_o2': 44, 's1_o5': 52},
        'seasonAwardedPlayed': 9,
        'seasonWins': 5,
        'seasonDraws': 2,
      });
      expect(_rowsJson(buildLeagueTable(state)), ref['fabricatedTable']);
    });
  });

  group('buildPyramidTable', () {
    Map<String, dynamic> peekState() => _baseState({
      'leaguePyramid': _fullPyramid(),
      'seasonMatchesPlayed': 9,
    });

    test('plays out a peeked league exactly as the JS does', () {
      seeded.setSeed(1010);
      final state = peekState();
      expect(
        _rowsJson(buildPyramidTable(state, 'elite_league'), pyramid: true),
        ref['pyramidTableElite'],
      );
    });

    test('and does the same for a division at the other end of the ladder', () {
      seeded.setSeed(1010);
      final state = peekState();
      buildPyramidTable(state, 'elite_league');
      expect(
        _rowsJson(buildPyramidTable(state, 'sunday_league'), pyramid: true),
        ref['pyramidTableSunday'],
      );
    });

    test('renders the same table on a second visit', () {
      seeded.setSeed(1010);
      final state = peekState();
      buildPyramidTable(state, 'elite_league');
      buildPyramidTable(state, 'sunday_league');
      expect(
        _rowsJson(buildPyramidTable(state, 'elite_league'), pyramid: true),
        ref['pyramidTableEliteAgain'],
      );
    });

    test('leaves the shared stream exactly where it found it', () {
      // A peeked table runs its own seeded island. If it spent draws off the
      // shared stream, walking through the league tabs would change the next
      // match — and the table would reshuffle every time you swiped back to it.
      seeded.setSeed(1010);
      final state = peekState();
      buildPyramidTable(state, 'elite_league');
      buildPyramidTable(state, 'sunday_league');
      buildPyramidTable(state, 'elite_league');
      expect(
        [for (var i = 0; i < 4; i++) seeded.random()],
        ref['streamAfterPyramidTables'],
      );
    });
  });
}
