/// The league, derived from the save.
///
/// The table and the schedule are both the engines' own — `buildLeagueTable`
/// and the stored `seasonFixtures` — so nothing here computes a standing or a
/// result.
library;

import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/engine/league_table.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
int _int(Object? v, [int fallback = 0]) =>
    v is num ? v.toInt() : fallback;

/// One line of the schedule.
typedef FixtureRow = ({
  int round,
  String homeTeam,
  String awayTeam,
  int? homeGoals,
  int? awayGoals,
  bool involvesPlayer,
  bool played,
});

final leagueTableProvider = savePick<List<LeagueRow>>((s) {
  // buildLeagueTable writes back into the save (it tracks movement between
  // renders), so it is given the live map exactly as the JS gives it.
  return buildLeagueTable(s);
});

final divisionNameProvider = savePick<String>((s) {
  final id = _map(s['progression'])?['currentDivision'] as String?;
  return getDivision(id ?? divisions.first.id).name;
});

final seasonNumberProvider = savePick<int>(
  (s) => _int(_map(s['progression'])?['seasonCount'], 1),
);

final fixturesProvider = savePick<List<FixtureRow>>((s) {
  final prog = _map(s['progression']);
  final raw = prog?['seasonFixtures'];
  final clubName = s['clubName'] is String ? s['clubName'] as String : '';
  if (raw is! List) return const [];

  return [
    for (final row in raw)
      if (row is Map<String, dynamic>)
        () {
          final home = row['homeTeam'] as String? ?? '';
          final away = row['awayTeam'] as String? ?? '';
          final hg = row['homeGoals'];
          final ag = row['awayGoals'];
          return (
            round: _int(row['round']),
            homeTeam: home,
            awayTeam: away,
            homeGoals: hg is num ? hg.toInt() : null,
            awayGoals: ag is num ? ag.toInt() : null,
            involvesPlayer: home == clubName || away == clubName,
            played: hg is num && ag is num,
          );
        }(),
  ]..sort((a, b) => a.round.compareTo(b.round));
});
