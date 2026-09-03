/// League standings — the player's own table, the tables for leagues they
/// aren't in, and the promotion/relegation badges a club carries into the new
/// campaign.
///
/// Ported from the standings half of
/// `../merge-empire-fc/src/engine/progressionEngine.js`.
///
/// Rows are built for display and never saved, so unlike the pyramid entries
/// they get a proper type rather than a raw map.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/engine/league_pyramid.dart';
import 'package:merge_empire_fc/engine/season_fixtures.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/sorting.dart';

/// One row of a league table.
class LeagueRow {
  LeagueRow({
    required this.name,
    required this.isPlayer,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.pts,
    required this.gd,
    this.rating,
    this.formation,
    this.attackRatio,
    this.form = const [],
  });

  final String name;
  final bool isPlayer;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int pts;
  final int gd;

  /// Populated only by [buildPyramidTable] — the player's own table reads its
  /// opponents' ratings out of `seasonOpponentRatings`, not off the row.
  final int? rating;
  final String? formation;
  final double? attackRatio;

  /// The last five results, newest last. Pyramid tables only.
  final List<String> form;

  /// Where this club stood at the end of the previous round, or null when
  /// there is nothing honest to compare against.
  int? prevPos;

  /// Positive means climbed — a smaller position number is a better one.
  int? posDelta;

  /// Value equality so a table rebuilt on a tick that did not move anybody hands
  /// `savePick` back the SAME rows and nothing redraws. `listEquals` would want
  /// Flutter, which this half of the tree may not import.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LeagueRow) return false;
    if (form.length != other.form.length) return false;
    for (var i = 0; i < form.length; i++) {
      if (form[i] != other.form[i]) return false;
    }
    return name == other.name &&
        isPlayer == other.isPlayer &&
        played == other.played &&
        won == other.won &&
        drawn == other.drawn &&
        lost == other.lost &&
        pts == other.pts &&
        gd == other.gd &&
        rating == other.rating &&
        formation == other.formation &&
        attackRatio == other.attackRatio &&
        prevPos == other.prevPos &&
        posDelta == other.posDelta;
  }

  @override
  int get hashCode => Object.hash(
    name,
    isPlayer,
    played,
    won,
    drawn,
    lost,
    pts,
    gd,
    rating,
    formation,
    attackRatio,
    prevPos,
    posDelta,
    Object.hashAll(form),
  );
}

/// League order: points, then goal difference, then wins — then NAME, which is
/// what settles a table nobody has played in yet.
///
/// Without the name the opening round came out in whatever order the clubs
/// happened to sit in the pyramid, which reads as random; A–Z reads as "no
/// games played". It stays a tiebreak all season, so two identical records
/// don't swap places between renders.
int byLeaguePosition(LeagueRow a, LeagueRow b) {
  if (b.pts != a.pts) return b.pts - a.pts;
  if (b.gd != a.gd) return b.gd - a.gd;
  if (b.won != a.won) return b.won - a.won;
  return compareTeamNames(a.name, b.name);
}

/// The JS settles the name tiebreak with `localeCompare`, which orders by
/// collation rather than by code unit. Across the whole generated name space
/// the two agree except on the accented Pro prefixes, where code-unit order
/// puts `Atlético` after every unaccented name instead of beside `Athletic`.
/// Folding the accents before comparing is what makes the two orders identical
/// — a test pins that against node over every name the banks can produce.
int compareTeamNames(String a, String b) {
  final fa = _foldAccents(a);
  final fb = _foldAccents(b);
  final primary = fa.toLowerCase().compareTo(fb.toLowerCase());
  if (primary != 0) return primary;
  return fa.compareTo(fb);
}

const Map<int, String> _accentFolds = {
  0xE1: 'a', 0xE9: 'e', 0xED: 'i', 0xF3: 'o', 0xFA: 'u', // á é í ó ú
  0xE0: 'a', 0xE8: 'e', 0xEC: 'i', 0xF2: 'o', 0xF9: 'u', // à è ì ò ù
  0xE2: 'a', 0xEA: 'e', 0xEE: 'i', 0xF4: 'o', 0xFB: 'u', // â ê î ô û
  0xE4: 'a', 0xEB: 'e', 0xEF: 'i', 0xF6: 'o', 0xFC: 'u', // ä ë ï ö ü
  0xE3: 'a', 0xF1: 'n', 0xF5: 'o', 0xE7: 'c', // ã ñ õ ç
  0xC1: 'A', 0xC9: 'E', 0xCD: 'I', 0xD3: 'O', 0xDA: 'U',
  0xC0: 'A', 0xC8: 'E', 0xCC: 'I', 0xD2: 'O', 0xD9: 'U',
  0xC2: 'A', 0xCA: 'E', 0xCE: 'I', 0xD4: 'O', 0xDB: 'U',
  0xC4: 'A', 0xCB: 'E', 0xCF: 'I', 0xD6: 'O', 0xDC: 'U',
  0xC3: 'A', 0xD1: 'N', 0xD5: 'O', 0xC7: 'C',
};

String _foldAccents(String s) {
  if (s.codeUnits.every((c) => c < 0x80)) return s;
  final out = StringBuffer();
  for (final rune in s.runes) {
    out.write(_accentFolds[rune] ?? String.fromCharCode(rune));
  }
  return out.toString();
}

Map<String, dynamic> _progression(Map<String, dynamic> state) =>
    (state['progression'] as Map<String, dynamic>?) ??
    (state['progression'] = <String, dynamic>{});

int _int(Object? v, [int fallback = 0]) => (v as num?)?.toInt() ?? fallback;

/// The player's own division table.
///
/// Also caches every club's position back onto the save, because the match
/// engine reads them for form and the relegation-zone boost.
List<LeagueRow> buildLeagueTable(Map<String, dynamic> state) {
  final prog = _progression(state);
  final divId = '${prog['currentDivision']}';
  final season = _int(prog['seasonCount'], 1);

  // `seasonAwardedPlayed` rather than `seasonMatchesPlayed`, so the table
  // doesn't shift mid-match while the sim is still running.
  final played = _int(prog['seasonAwardedPlayed']);
  final won = math.min(played, _int(prog['seasonWins']));
  final drawn = math.min(played - won, _int(prog['seasonDraws']));
  // Losses are derived from the played counter rather than trusted from the
  // save — pre-fix saves accumulated them across seasons, which showed as
  // totals that didn't add up to the games played.
  final lost = math.max(0, played - won - drawn);

  final clubName = state['clubName'];
  final player = LeagueRow(
    name: (clubName is String && clubName.isNotEmpty) ? clubName : 'Your Club',
    isPlayer: true,
    played: played,
    won: won,
    drawn: drawn,
    lost: lost,
    pts: won * 3 + drawn,
    gd: won * 2 - lost,
  );

  final opponentNames = getSeasonOpponents(divId, season, state);
  final fixtures = prog['seasonFixtures'];

  // Standings come from the pre-simulated fixtures when there are any. Saves
  // predating the schedule fall back to the old rating-based fabrication.
  final opponents = (fixtures is List && fixtures.isNotEmpty)
      ? _rowsFromFixtures(state, fixtures, opponentNames, played, season)
      : _rowsFabricated(state, divId, season, played, opponentNames);

  final sorted = stableSorted([player, ...opponents], byLeaguePosition);

  // The branch is created BEFORE the loop, which is the JS's order and
  // therefore the save's: `playerTablePosition` is written from inside the loop,
  // so filling a local map and assigning it afterwards put the two keys in the
  // progression branch the other way round. The differential harness is what
  // caught it — every value agreed and the bytes did not.
  final tablePositions = <String, dynamic>{};
  prog['opponentTablePositions'] = tablePositions;
  final positions = <String, int>{};
  for (var i = 0; i < sorted.length; i++) {
    final team = sorted[i];
    if (team.isPlayer) {
      prog['playerTablePosition'] = i + 1;
    } else {
      tablePositions[team.name] = i + 1;
    }
    positions[_tableKey(team)] = i + 1;
  }

  _trackTableMovement(state, season, played, positions);
  final prev = _prevPositions(prog);
  for (final team in sorted) {
    final was = prev?[_tableKey(team)];
    team.prevPos = (was as num?)?.toInt();
    team.posDelta = team.prevPos == null
        ? null
        : team.prevPos! - positions[_tableKey(team)]!;
  }

  return sorted;
}

/// AI clubs are keyed by name; the player is keyed apart because their club can
/// be renamed mid-season, which would otherwise read as one side leaving the
/// division and another arriving.
String _tableKey(LeagueRow team) => team.isPlayer ? '__player' : team.name;

Map<String, dynamic>? _prevPositions(Map<String, dynamic> prog) {
  final tp = prog['tablePos'];
  if (tp is! Map<String, dynamic>) return null;
  final prev = tp['prevPositions'];
  return prev is Map<String, dynamic> ? prev : null;
}

/// Remember where every club stood at the END OF THE PREVIOUS ROUND, so the
/// next-match card can show whether a side climbed into its position or fell
/// into it.
///
/// The table is rebuilt on every League render, so this has to be idempotent:
/// the snapshot only rolls over when the round actually changes. The previous
/// positions are cleared unless the stored snapshot is the round IMMEDIATELY
/// before this one in the SAME season — a rollover resets every club to zero
/// points, and comparing round 1 against last season's final table would report
/// a climb that never happened.
void _trackTableMovement(
  Map<String, dynamic> state,
  int season,
  int played,
  Map<String, int> positions,
) {
  final prog = _progression(state);
  var tp = prog['tablePos'];
  if (tp is! Map<String, dynamic>) {
    tp = <String, dynamic>{
      'season': null,
      'round': null,
      'positions': null,
      'prevPositions': null,
    };
    prog['tablePos'] = tp;
  }
  final snapshot = tp;

  if (snapshot['season'] != season || snapshot['round'] != played) {
    final contiguous =
        snapshot['season'] == season && snapshot['round'] == played - 1;
    snapshot['prevPositions'] = contiguous ? snapshot['positions'] : null;
    snapshot['season'] = season;
    snapshot['round'] = played;
  }
  snapshot['positions'] = <String, dynamic>{...positions};
}

/// AI rows accumulated from the pre-simulated fixtures. The player's own
/// results are read back out of `fixtureResults`, and only rounds up to the
/// current one are counted — one round per player match played.
List<LeagueRow> _rowsFromFixtures(
  Map<String, dynamic> state,
  List<dynamic> fixtures,
  List<String> opponentNames,
  int currentRound,
  int season,
) {
  final stats = <String, ({int played, int won, int drawn, int lost, int gd})>{
    for (final name in opponentNames)
      name: (played: 0, won: 0, drawn: 0, lost: 0, gd: 0),
  };

  final results =
      (_progression(state)['fixtureResults'] as Map<String, dynamic>?) ??
      const {};

  for (final raw in fixtures) {
    if (raw is! Map<String, dynamic>) continue;
    if (_int(raw['round']) > currentRound) continue;

    final int homeGoals;
    final int awayGoals;
    final playerMatchNum = raw['playerMatchNum'];

    if (playerMatchNum != null) {
      final res = results['s${season}_m${_int(playerMatchNum)}'];
      // Not played yet, or a save predating fixtureResults.
      if (res is! Map<String, dynamic>) continue;
      // The match engine stores `homeGoals` as the PLAYER's goals, whatever the
      // venue. When the player was physically away the fixture names the
      // opponent as the home club, so swap to get the real home/away split.
      if (raw['homeTeam'] == null) {
        homeGoals = _int(res['homeGoals']);
        awayGoals = _int(res['awayGoals']);
      } else {
        homeGoals = _int(res['awayGoals']);
        awayGoals = _int(res['homeGoals']);
      }
    } else {
      if (raw['homeGoals'] == null) continue;
      homeGoals = _int(raw['homeGoals']);
      awayGoals = _int(raw['awayGoals']);
    }

    for (final side in [
      (name: raw['homeTeam'], gf: homeGoals, ga: awayGoals),
      (name: raw['awayTeam'], gf: awayGoals, ga: homeGoals),
    ]) {
      // A null name is the player's slot.
      final name = side.name;
      if (name is! String) continue;
      final s = stats[name];
      if (s == null) continue;
      stats[name] = (
        played: s.played + 1,
        won: s.won + (side.gf > side.ga ? 1 : 0),
        drawn: s.drawn + (side.gf == side.ga ? 1 : 0),
        lost: s.lost + (side.gf < side.ga ? 1 : 0),
        gd: s.gd + side.gf - side.ga,
      );
    }
  }

  return [
    for (final name in opponentNames)
      () {
        final s = stats[name] ?? (played: 0, won: 0, drawn: 0, lost: 0, gd: 0);
        return LeagueRow(
          name: name,
          isPlayer: false,
          played: s.played,
          won: s.won,
          drawn: s.drawn,
          lost: s.lost,
          pts: s.won * 3 + s.drawn,
          gd: s.gd,
        );
      }(),
  ];
}

/// Legacy fallback: fabricate AI standings from win-rate estimates. Used for
/// saves predating the fixture schedule, and by tests that build a table
/// without running [initSeasonOpponents] first.
List<LeagueRow> _rowsFabricated(
  Map<String, dynamic> state,
  String divId,
  int season,
  int played,
  List<String> opponentNames,
) {
  final div = getDivision(divId);
  final divIdx = divisions.indexWhere((d) => d.id == divId);
  final (lo, hi) = div.opponentRatingRange;
  final ratings =
      (_progression(state)['seasonOpponentRatings'] as Map<String, dynamic>?) ??
      const {};

  return [
    for (var i = 0; i < opponentNames.length; i++)
      () {
        final seed = divIdx * 7 + i + season + 1;
        final teamRating = ratings['s${season}_o$i'] as num?;
        final double str;
        if (teamRating != null) {
          final mid = (lo + hi) / 2;
          final norm = math.max(
            -1.0,
            math.min(1.0, (teamRating - mid) / math.max(1, (hi - lo) / 2)),
          );
          str = math.max(
            0.20,
            math.min(0.50, 0.38 + norm * 0.10 + (((seed * 13) % 14) - 7) / 100),
          );
        } else {
          str = math.max(0.22, math.min(0.50, 0.22 + ((seed * 13) % 28) / 100));
        }
        final oppPlayed = math.max(
          0,
          math.min(played, played + ((seed * 7) % 5 - 2)),
        );
        final oppWon = (oppPlayed * str).round();
        final oppDrawn = (oppPlayed * 0.10).round();
        final oppLost = math.max(0, oppPlayed - oppWon - oppDrawn);
        return LeagueRow(
          name: opponentNames[i],
          isPlayer: false,
          played: oppPlayed,
          won: oppWon,
          drawn: oppDrawn,
          lost: oppLost,
          pts: oppWon * 3 + oppDrawn,
          gd: oppWon * 2 - oppLost,
        );
      }(),
  ];
}

/// The standings for a league the player ISN'T in.
///
/// These used to be a rate rounded into a record, and at low match counts the
/// rounding collapsed every club onto the same line: at two games played, all
/// eight read 1W 0D 1L. Draws were worse — `round(played * 0.12)` is the same
/// number for everybody, so a whole division shared a draw count all season.
///
/// So every game is PLAYED instead, through the same sampler the player's own
/// league pre-simulates its fixtures with, each side using its own rating and
/// formation. Records come out of results, which means they add up to the games
/// played, draws land where the goals put them, and the form dots are the real
/// tail of the sequence rather than a shuffle of the totals.
///
/// Nothing is stored. Seeded off (season, division) so the same league renders
/// identically every time it is drawn while the shared stream is left alone — a
/// table that reshuffled itself on each visit would be worse than the rounding
/// ever was.
List<LeagueRow> buildPyramidTable(Map<String, dynamic> state, String divId) {
  final pyramid = ensureLeaguePyramid(state);
  final raw = pyramid[divId];
  final teams = <Map<String, dynamic>>[
    if (raw is List)
      for (final t in raw)
        if (t is Map<String, dynamic>) t,
  ];
  if (teams.isEmpty) return [];

  final prog = _progression(state);
  final season = _int(prog['seasonCount'], 1);
  // Both legs, exactly as long as the player's own campaign, so the two tables
  // are directly comparable.
  final rounds = math.max(0, (teams.length - 1) * 2);
  final played = math.min(rounds, _int(prog['seasonMatchesPlayed']));

  final splits = [for (final t in teams) splitForTeam(_int(t['rating']), t)];
  final won = List<int>.filled(teams.length, 0);
  final drawn = List<int>.filled(teams.length, 0);
  final lost = List<int>.filled(teams.length, 0);
  final goalsFor = List<int>.filled(teams.length, 0);
  final goalsAgainst = List<int>.filled(teams.length, 0);
  final form = [for (var i = 0; i < teams.length; i++) <String>[]];

  // Circle method: index 0 is the pivot and the rest rotate one place each
  // round, pairing across the circle. Each side meets every other exactly once
  // per turn of it, which is what makes the second leg a straight venue swap.
  final n = teams.length;
  final order = [for (var i = 0; i < n; i++) i];
  var divSeed = 0;
  for (final c in divId.codeUnits) {
    divSeed = (divSeed * 31 + c).toSigned(32);
  }

  seeded.withSeed((divSeed + season * 7919).abs(), () {
    for (var round = 0; round < played; round++) {
      final secondLeg =
          round >= n - 1; // reverse the venues after one full turn
      for (var m = 0; m < n / 2; m++) {
        final a = order[m];
        final b = order[n - 1 - m];
        final home = secondLeg ? b : a;
        final away = secondLeg ? a : b;
        final result = simulateAiFixture(
          splits[home].attack,
          splits[home].defence,
          splits[away].attack,
          splits[away].defence,
        );
        goalsFor[home] += result.homeGoals;
        goalsAgainst[home] += result.awayGoals;
        goalsFor[away] += result.awayGoals;
        goalsAgainst[away] += result.homeGoals;
        if (result.homeGoals > result.awayGoals) {
          won[home]++;
          lost[away]++;
          form[home].add('W');
          form[away].add('L');
        } else if (result.homeGoals < result.awayGoals) {
          won[away]++;
          lost[home]++;
          form[away].add('W');
          form[home].add('L');
        } else {
          drawn[home]++;
          drawn[away]++;
          form[home].add('D');
          form[away].add('D');
        }
      }
      order.insert(1, order.removeLast()); // rotate for the next round
    }
  });

  final rows = [
    for (var i = 0; i < teams.length; i++)
      LeagueRow(
        name: '${teams[i]['name']}',
        isPlayer: false,
        played: won[i] + drawn[i] + lost[i],
        won: won[i],
        drawn: drawn[i],
        lost: lost[i],
        pts: won[i] * 3 + drawn[i],
        gd: goalsFor[i] - goalsAgainst[i],
        rating: _int(teams[i]['rating']),
        formation: teams[i]['formation'] as String?,
        attackRatio: (teams[i]['attackRatio'] as num?)?.toDouble(),
        form: form[i].length <= 5
            ? List.unmodifiable(form[i])
            : List.unmodifiable(form[i].sublist(form[i].length - 5)),
      ),
  ];
  return stableSorted(rows, byLeaguePosition);
}

/// The badge a table row carries from LAST season: `champion` (won the top
/// flight), `promoted` / `relegated` (moved into the league it is sitting in
/// now), or null.
///
/// Keyed on the division the club is in NOW, so a badge can only ever light up
/// in the league the move landed in — never in the one the club left.
String? seasonStatusFor(
  Map<String, dynamic>? state,
  String divId,
  LeagueRow? row,
) {
  final rec =
      (state?['progression'] as Map<String, dynamic>?)?['lastSeasonStatus'];
  if (rec is! Map<String, dynamic> || row == null) return null;
  if (row.isPlayer) {
    return rec['playerDivision'] == divId ? rec['player'] as String? : null;
  }
  final teams = rec['teams'];
  final entry = teams is Map<String, dynamic> ? teams[row.name] : null;
  if (entry is! Map<String, dynamic>) return null;
  return entry['division'] == divId ? entry['status'] as String? : null;
}

/// Which band of the table a position sits in.
///
/// Ported from `_tableZone` in `ui/screens/LeagueScreen.js`, and the two edge
/// cases are the whole of it: the Champions Cup has nothing above it, so only
/// FIRST is a prize rather than the top two; and Sunday League has nothing below
/// it, so no position is a drop.
enum LeagueZone { champion, promotion, relegation, midtable }

LeagueZone leagueZoneFor(int pos, int rowCount, String divisionId) {
  final isTop = divisionId == 'champions_cup';
  final isBottom = divisionId == 'sunday_league';
  if (isTop && pos == 1) return LeagueZone.champion;
  if (!isTop && pos <= 2) return LeagueZone.promotion;
  // TWO rows wide, not one — a side one place off the bottom is in the fight,
  // and colouring only the last row said otherwise.
  if (!isBottom && pos >= rowCount - 1) return LeagueZone.relegation;
  return LeagueZone.midtable;
}
