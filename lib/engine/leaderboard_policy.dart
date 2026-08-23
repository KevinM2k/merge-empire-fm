/// The leaderboard's own shape: what a board IS, where its rows live, and which
/// of them count — the pure half of
/// `../merge-empire-fc/src/services/leaderboardService.js`.
///
/// **The schema is the interesting part, and it is v2.** One row per player per
/// PERIOD at `lb/{periodKey}/rows/{playerId}`, carrying every metric as a field.
/// The scope — which division, which region — is a field FILTER on the query
/// rather than a dimension of the path. That is what makes a finished match
/// cost four document writes instead of forty-eight: four periods, and the
/// four boards a player appears on are the same four rows read back with
/// different `where` clauses.
///
/// **And the rows on the server are the shipped app's.** A board written by the
/// JS has to be readable by this one and the other way round, which is why
/// every key, field name and path here is the JS's rather than a tidier one.
///
/// Deliberately Flutter-free: all of it runs under plain `dart test`, and the
/// transport sits on `services/firestore_rest.dart`.
library;

/// Which population a board ranks.
enum LeaderboardTier {
  /// Just this division.
  division,

  /// Everybody.
  all,
}

/// How far it reaches.
enum LeaderboardReach { regional, global }

/// One board view, as the JS's composite `tier_reach` id.
typedef LeaderboardScope = ({LeaderboardTier tier, LeaderboardReach reach});

/// The four views, in the JS's own order.
const List<String> leaderboardViewScopes = [
  'division_regional',
  'division_global',
  'all_regional',
  'all_global',
];

/// What a board can be ranked BY. All four descend — there is no metric here
/// where less is better.
const List<String> leaderboardMetrics = [
  'points',
  'wins',
  'goals_for',
  'prestige',
];

/// The four windows.
const List<String> leaderboardPeriods = ['1d', '7d', '30d', 'alltime'];

/// **Metric id to the FIELD it is stored under**, and `prestige` is the one
/// that differs: it rides on the row's meta level field rather than a score of
/// its own. Anything unrecognised falls back to points, which is a board rather
/// than an error.
const Map<String, String> leaderboardMetricFields = {
  'points': 'points',
  'wins': 'wins',
  'goals_for': 'goals_for',
  'prestige': 'prestigeLevel',
};

String leaderboardMetricField(String metric) =>
    leaderboardMetricFields[metric] ?? 'points';

/// Rows fetched per view. Firestore reads are the bill; this is the cap.
const int leaderboardFetchLimit = 50;

/// **A player with no match in this long is not on the board.**
///
/// It is filtered CLIENT-side, because the query is already ordered by score
/// and Firestore will not take a second range — which is why the fetch pulls
/// extra pages: see [leaderboardBackfillBatches].
const int leaderboardInactiveDays = 30;
const Duration leaderboardInactiveAfter = Duration(
  days: leaderboardInactiveDays,
);

/// Extra score-ordered pages to scan while dropping inactive rows.
const int leaderboardBackfillBatches = 5;

String _pad(int n) => n < 10 ? '0$n' : '$n';

/// The Firestore key for one period at [at], in the DEVICE's own timezone.
///
/// Local rather than UTC, and the JS is the same: a daily board that rolls at
/// midnight UTC rolls in the middle of the evening for half the world.
///
/// **The weekly key is the ISO week**, which is not "the seventh of the year
/// divided by seven": a week belongs to the year its THURSDAY falls in, so the
/// first days of January can be week 52 of the year before. Getting that wrong
/// puts two different weeks in one bucket once a year.
String leaderboardPeriodKey(String period, DateTime at) {
  switch (period) {
    case '1d':
      return 'day_${at.year}-${_pad(at.month)}-${_pad(at.day)}';
    case '7d':
      // Monday is 1 and Sunday is 7, which is what makes the offset arithmetic
      // below land on this week's Thursday.
      final thursday = DateTime(
        at.year,
        at.month,
        at.day + 4 - at.weekday,
      );
      final yearStart = DateTime(thursday.year, 1, 1);
      // **MILLISECONDS, divided — not `inDays`.** The JS computes
      // `(thursday - yearStart) / 86400000` and keeps the fraction, and the
      // fraction is not always zero: the clocks going forward makes the
      // interval a day short of an hour, so `inDays` truncates to 90 where the
      // JS has 90.958. That is a whole week's difference at the ceiling —
      // 30 March 2026 is W14 in the shipped app and came out W13 here. Caught
      // by the node fixture, which is the only reason it was caught at all.
      final days =
          thursday.difference(yearStart).inMilliseconds /
          Duration.millisecondsPerDay;
      final week = ((days + 1) / 7).ceil();
      return 'week_${thursday.year}-W${_pad(week)}';
    case '30d':
      return 'month_${at.year}-${_pad(at.month)}';
    default:
      return 'alltime';
  }
}

/// Where one player's row for a period lives.
///
/// Schema v2: the scope is a field on the row, not a folder in the path.
String leaderboardRowPath(String periodKey, String playerId) =>
    'lb/$periodKey/rows/$playerId';

/// Read a scope id, composite or legacy.
///
/// **The three legacy ids are still in saves**, which is why they are still
/// here: `division` meant division-global, `regional` and `global` both meant
/// every division. Anything unrecognised is division-global, which is the
/// board the JS opens on.
LeaderboardScope parseLeaderboardScope(String? scope) => switch (scope) {
  'division' => (tier: LeaderboardTier.division, reach: LeaderboardReach.global),
  'regional' => (tier: LeaderboardTier.all, reach: LeaderboardReach.regional),
  'global' => (tier: LeaderboardTier.all, reach: LeaderboardReach.global),
  'division_regional' => (
    tier: LeaderboardTier.division,
    reach: LeaderboardReach.regional,
  ),
  'division_global' => (
    tier: LeaderboardTier.division,
    reach: LeaderboardReach.global,
  ),
  'all_regional' => (
    tier: LeaderboardTier.all,
    reach: LeaderboardReach.regional,
  ),
  'all_global' => (tier: LeaderboardTier.all, reach: LeaderboardReach.global),
  _ => (tier: LeaderboardTier.division, reach: LeaderboardReach.global),
};

String buildLeaderboardScope(LeaderboardTier tier, LeaderboardReach reach) =>
    '${tier.name}_${reach.name}';

/// The equality filters that implement a view.
///
/// **A default per filter, not a refusal.** A save with no division or no
/// region still gets a board — the opening division and `GB`, which are the
/// JS's own fallbacks — because an empty leaderboard reads as broken where a
/// slightly wrong one reads as a leaderboard.
List<(String field, String value)> leaderboardScopeFilters(
  String? scope, {
  String? divisionId,
  String? regionCode,
}) {
  final view = parseLeaderboardScope(scope);
  return [
    if (view.tier == LeaderboardTier.division)
      ('division', divisionId ?? 'sunday_league'),
    if (view.reach == LeaderboardReach.regional) ('region', regionCode ?? 'GB'),
  ];
}

/// Does this row belong on the board the filters describe?
bool leaderboardRowMatches(
  Map<String, dynamic>? row,
  List<(String, String)> filters,
) => filters.every((f) => row?[f.$1] == f.$2);

/// Has this row played recently enough to be ranked?
///
/// [lastMatchAtMs] null is a row that has never played, which is not a row.
bool leaderboardRowIsActive(Object? lastMatchAtMs, {required int nowMs}) {
  if (lastMatchAtMs is! num) return false;
  final age = nowMs - lastMatchAtMs.toInt();
  return age >= 0 && age < leaderboardInactiveAfter.inMilliseconds;
}
