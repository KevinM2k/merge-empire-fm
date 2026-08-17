/// The season schedule — who the player faces, and every AI-vs-AI result that
/// fills the rest of the table.
///
/// Ported from the fixture half of
/// `../merge-empire-fc/src/engine/progressionEngine.js`.
///
/// AI games are simulated the moment the schedule is drawn, through the same
/// ATK-vs-DEF sampler player matches run on, so the standings reflect real club
/// styles rather than a rating ladder. The player's own slots are left blank
/// and filled in later from `progression.fixtureResults`.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/engine/goal_model.dart';
import 'package:merge_empire_fc/engine/league_pyramid.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/team_names.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;

/// A Berger-table round robin for the seven AI clubs.
///
/// `aiSchedule[r]` holds the three inter-AI pairings for first-half round `r`,
/// where the player faces `seasonOpponents[r]` and that club has the bye.
/// Indices are into `seasonOpponents`; every pair meets exactly once across
/// rounds 0–6, which is what makes this a valid single round robin.
const List<List<List<int>>> aiSchedule = [
  [[1, 6], [2, 5], [3, 4]],
  [[0, 4], [5, 3], [6, 2]],
  [[0, 1], [3, 6], [4, 5]],
  [[0, 5], [6, 4], [1, 2]],
  [[0, 2], [3, 1], [5, 6]],
  [[0, 6], [1, 4], [2, 3]],
  [[0, 3], [4, 2], [5, 1]],
];

/// One AI-vs-AI result, through the same dual ATK-vs-DEF simulation player
/// matches use. Home advantage is added to the home side's attack and to the
/// home side's defence — that second one reads oddly as `homeDef +
/// HOME_ADVANTAGE` inside the away sampler, but it is the same bonus applied
/// once to each of the home club's two numbers.
({int homeGoals, int awayGoals}) simulateAiFixture(
  num homeAtk,
  num homeDef,
  num awayAtk,
  num awayDef,
) {
  final homeGoals = simulateGoals(homeAtk + homeAdvantage, awayDef);
  final awayGoals = simulateGoals(awayAtk, homeDef + homeAdvantage);
  return (homeGoals: homeGoals, awayGoals: awayGoals);
}

Map<String, dynamic> _progression(Map<String, dynamic> state) =>
    (state['progression'] as Map<String, dynamic>?) ??
    (state['progression'] = <String, dynamic>{});

List<String> _opponentNames(Object? raw) {
  if (raw is! List) return [];
  return [for (final n in raw) '$n'];
}

/// Generate and store all 56 fixtures for the season (14 rounds × 4 games).
///
/// Only called when `seasonFixtures` is null — a loaded save keeps the schedule
/// it was playing, results and all.
void generateSeasonFixtures(Map<String, dynamic> state) {
  final prog = _progression(state);
  final opponents = _opponentNames(prog['seasonOpponents']);
  final season = (prog['seasonCount'] as num?)?.toInt() ?? 1;
  final div = getDivision('${prog['currentDivision']}');
  final (lo, hi) = div.opponentRatingRange;
  final ratingMid = ((lo + hi) / 2).round();

  final storedRatings =
      (prog['seasonOpponentRatings'] as Map<String, dynamic>?) ?? const {};
  final ratings = [
    for (var i = 0; i < opponents.length; i++)
      (storedRatings['s${season}_o$i'] as num?)?.toInt() ?? ratingMid,
  ];

  // Each opponent's ATK/DEF comes off its pyramid entry, so the table and the
  // match engine describe the same club.
  final pyramid = prog['leaguePyramid'];
  final divTeams = (pyramid is Map<String, dynamic>)
      ? pyramid['${prog['currentDivision']}']
      : null;
  final splits = [
    for (var i = 0; i < opponents.length; i++)
      splitForTeam(ratings[i], _findTeam(divTeams, opponents[i])),
  ];

  final fixtures = <Map<String, dynamic>>[];

  for (var r = 0; r < 7; r++) {
    final oppName = r < opponents.length ? opponents[r] : null;

    // The same seeded home/away formula the match engine uses, so the schedule
    // and the fixture the player is handed can never disagree.
    final seed = ((r + 1) * 37 + season * 13) % 10;
    final playerIsHome = seed >= 5;

    fixtures.add({
      'round': r + 1,
      'homeTeam': playerIsHome ? null : oppName,
      'awayTeam': playerIsHome ? oppName : null,
      'homeGoals': null,
      'awayGoals': null,
      'playerMatchNum': r,
    });

    for (final pair in aiSchedule[r]) {
      final ai = pair[0];
      final aj = pair[1];
      final nameA = ai < opponents.length ? opponents[ai] : null;
      final nameB = aj < opponents.length ? opponents[aj] : null;
      if (nameA == null || nameB == null) continue;
      final homeFirst = (ai * 31 + aj * 17 + season * 7) % 2 == 0;
      final result = simulateAiFixture(
        homeFirst ? splits[ai].attack : splits[aj].attack,
        homeFirst ? splits[ai].defence : splits[aj].defence,
        homeFirst ? splits[aj].attack : splits[ai].attack,
        homeFirst ? splits[aj].defence : splits[ai].defence,
      );
      fixtures.add({
        'round': r + 1,
        'homeTeam': homeFirst ? nameA : nameB,
        'awayTeam': homeFirst ? nameB : nameA,
        'homeGoals': result.homeGoals,
        'awayGoals': result.awayGoals,
      });
    }

    // The second leg reverses the venue.
    fixtures.add({
      'round': r + 8,
      'homeTeam': playerIsHome ? oppName : null,
      'awayTeam': playerIsHome ? null : oppName,
      'homeGoals': null,
      'awayGoals': null,
      'playerMatchNum': r + 7,
    });

    for (final pair in aiSchedule[r]) {
      final ai = pair[0];
      final aj = pair[1];
      final nameA = ai < opponents.length ? opponents[ai] : null;
      final nameB = aj < opponents.length ? opponents[aj] : null;
      if (nameA == null || nameB == null) continue;
      final homeFirst = (ai * 31 + aj * 17 + season * 7) % 2 == 0;
      final result = simulateAiFixture(
        homeFirst ? splits[aj].attack : splits[ai].attack,
        homeFirst ? splits[aj].defence : splits[ai].defence,
        homeFirst ? splits[ai].attack : splits[aj].attack,
        homeFirst ? splits[ai].defence : splits[aj].defence,
      );
      fixtures.add({
        'round': r + 8,
        'homeTeam': homeFirst ? nameB : nameA,
        'awayTeam': homeFirst ? nameA : nameB,
        'homeGoals': result.homeGoals,
        'awayGoals': result.awayGoals,
      });
    }
  }

  prog['seasonFixtures'] = fixtures;
}

Map<String, dynamic>? _findTeam(Object? teams, String name) {
  if (teams is! List) return null;
  for (final t in teams) {
    if (t is Map<String, dynamic> && t['name'] == name) return t;
  }
  return null;
}

/// Set up the season's opponents, pulling them straight out of the pyramid for
/// the player's current division and seeding their ratings into the lookup key
/// the match engine already reads.
void initSeasonOpponents(Map<String, dynamic> state) {
  final pyramid = ensureLeaguePyramid(state);
  final prog = _progression(state);
  final divId = '${prog['currentDivision']}';
  final season = (prog['seasonCount'] as num?)?.toInt() ?? 1;

  final divTeams = pyramid[divId];
  final teams = <Map<String, dynamic>>[
    if (divTeams is List)
      for (final t in divTeams.take(opponentsPerSeason))
        if (t is Map<String, dynamic>) t,
  ];

  final names = <String>[for (final t in teams) '${t['name']}'];
  if (names.length < opponentsPerSeason) {
    final tier = divTier(divId);
    final used = names.toSet();
    while (names.length < opponentsPerSeason) {
      final name = generateTeamName(tier, used);
      used.add(name);
      names.add(name);
    }
  }
  prog['seasonOpponents'] = names;

  final ratings =
      (prog['seasonOpponentRatings'] as Map<String, dynamic>?) ??
      <String, dynamic>{};
  prog['seasonOpponentRatings'] = ratings;

  final div = getDivision(divId);
  for (var i = 0; i < names.length; i++) {
    final key = 's${season}_o$i';
    if (ratings[key] != null) continue;
    final team = _findTeam(teams, names[i]);
    final rating = (team?['rating'] as num?)?.toInt();
    ratings[key] = rating ??
        seeded.randomInt(
          div.opponentRatingRange.$1,
          div.opponentRatingRange.$2,
        );
  }

  prog.remove('_departedTeams');

  // Skipped on boot when a save already carries its schedule.
  if (prog['seasonFixtures'] == null) generateSeasonFixtures(state);
}

/// Legacy fallback — the stored opponents if there are any, otherwise a fresh
/// set of names. Used by saves predating the pyramid and by tests that build a
/// table without running [initSeasonOpponents] first.
List<String> getSeasonOpponents(
  String divisionId,
  int seasonCount,
  Map<String, dynamic>? state,
) {
  final stored = (state?['progression'] as Map<String, dynamic>?)?['seasonOpponents'];
  if (stored is List && stored.isNotEmpty) {
    return _opponentNames(stored).take(opponentsPerSeason).toList();
  }
  final tier = divTier(divisionId);
  final used = <String>{};
  final names = <String>[];
  while (names.length < opponentsPerSeason) {
    final name = generateTeamName(tier, used);
    used.add(name);
    names.add(name);
  }
  return names;
}
