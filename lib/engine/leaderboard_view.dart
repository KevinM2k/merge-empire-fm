/// One board, as it comes back — the shape half of `fetchLeaderboard` in
/// `../merge-empire-fc/src/services/leaderboardService.js`.
///
/// **The board is built by a Cloud Function, not by the client.** That is the
/// JS's own primary path and it is why this file is small: ranking needs a
/// `count()` over the whole collection, which is one server call and would
/// otherwise be a hundred document reads on a phone. The client sends who it
/// is, which period, which metric and which filters, and gets back a finished
/// view — the top rows, the player's own row, its rank, and the two neighbours
/// either side of it when they are outside the window.
///
/// **THREE FIELDS ARE OVERWRITTEN LOCALLY ON THE PLAYER'S OWN ROW**, and each
/// has a reason the function cannot know:
///
/// - **The club name**, because a rename is instant here and only reaches the
///   server on the next match write.
/// - **The badge**, same, and with a sharper edge the JS spells out: the
///   override is skipped when this device has never made a badge CHOICE, so a
///   second device with an unsynced save shows the stored badge rather than
///   stomping it back to default.
/// - **The platform**, which is a fact about this device rather than about the
///   row.
///
/// Deliberately Flutter-free and socket-free: the parsing is arithmetic over a
/// decoded JSON body, so all of it runs under plain `dart test`.
library;

/// The badge a row with no choice on it wears. The JS's own default.
const String defaultLeaderboardBadge = 'default';

/// Where a row was played. Anything unrecognised is `web`, which is the JS's
/// own fallback and covers a row written by a build this one has never met.
const Set<String> leaderboardPlatforms = {'ios', 'android', 'web'};

String normaliseLeaderboardPlatform(Object? platform) =>
    platform is String && leaderboardPlatforms.contains(platform)
    ? platform
    : 'web';

/// One row on a board.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.playerId,
    required this.clubName,
    required this.score,
    required this.division,
    required this.prestigeLevel,
    required this.badgeId,
    required this.platform,
    required this.isPlayer,
    this.rank,
  });

  final String playerId;
  final String clubName;
  final num score;
  final String division;
  final int prestigeLevel;
  final String badgeId;
  final String platform;

  /// This device's own row, which is drawn differently and gets the three
  /// local overrides.
  final bool isPlayer;

  /// One-based, or null for a row the server did not rank.
  final int? rank;

  LeaderboardEntry copyWith({
    String? clubName,
    String? badgeId,
    String? platform,
    int? rank,
  }) => LeaderboardEntry(
    playerId: playerId,
    clubName: clubName ?? this.clubName,
    score: score,
    division: division,
    prestigeLevel: prestigeLevel,
    badgeId: badgeId ?? this.badgeId,
    platform: platform ?? this.platform,
    isPlayer: isPlayer,
    rank: rank ?? this.rank,
  );
}

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// One row out of the function's JSON, or null when it carries no score.
///
/// **A row with no usable score is not a row.** The JS drops it rather than
/// ranking it at zero, because a zero is a real score somebody could hold and
/// a missing field is a document written by something else.
LeaderboardEntry? leaderboardEntryFrom(Object? raw, {String? selfId}) {
  final row = _map(raw);
  if (row == null) return null;
  final id = row['playerId'];
  if (id is! String || id.isEmpty) return null;
  final rawScore = row['score'];
  final score = rawScore is num ? rawScore : num.tryParse('$rawScore');
  if (score == null || !score.isFinite) return null;
  final rank = row['rank'];
  return LeaderboardEntry(
    playerId: id,
    clubName: row['clubName'] is String && (row['clubName'] as String).isNotEmpty
        ? row['clubName'] as String
        : 'Unknown FC',
    score: score,
    division: row['division'] is String ? row['division'] as String : '',
    prestigeLevel: row['prestigeLevel'] is num
        ? (row['prestigeLevel'] as num).round()
        : 0,
    badgeId: row['badgeId'] is String && (row['badgeId'] as String).isNotEmpty
        ? row['badgeId'] as String
        : defaultLeaderboardBadge,
    platform: normaliseLeaderboardPlatform(row['platform']),
    isPlayer: selfId != null && selfId == id,
    rank: rank is num ? rank.toInt() : null,
  );
}

/// A whole board.
class LeaderboardView {
  const LeaderboardView({
    this.entries = const [],
    this.bottomEntries = const [],
    this.playerEntry,
    this.playerRank,
    this.contextAbove,
    this.contextBelow,
    this.playerBeyondTop = false,
    this.showGap = false,
    this.showGapBeforeBottom = false,
    this.error,
    this.optedOut = false,
  });

  /// The top of the board, in order.
  final List<LeaderboardEntry> entries;

  /// The last three, shown under a gap when the player is a long way down.
  final List<LeaderboardEntry> bottomEntries;

  final LeaderboardEntry? playerEntry;
  final int? playerRank;

  /// The rows either side of the player when they are outside the window.
  final LeaderboardEntry? contextAbove;
  final LeaderboardEntry? contextBelow;

  final bool playerBeyondTop;
  final bool showGap;
  final bool showGapBeforeBottom;

  /// `offline`, `fetch_failed`, or null. A STRING because these are the JS's
  /// own and the screen's copy is keyed to them.
  final String? error;

  /// The player asked not to be listed. The board still loads — they can look
  /// at it, they are simply not on it.
  final bool optedOut;

  bool get isEmpty => entries.isEmpty && playerEntry == null;
}

/// Every row the view carries, in one list. For the local overrides.
List<LeaderboardEntry> allViewRows(LeaderboardView view) => [
  ...view.entries,
  ?view.contextAbove,
  ?view.playerEntry,
  ?view.contextBelow,
  ...view.bottomEntries,
];

/// The finished view out of the function's response body.
LeaderboardView leaderboardViewFrom(
  Object? body, {
  String? selfId,
  bool optedOut = false,
}) {
  final view = _map(body);
  List<LeaderboardEntry> list(Object? raw) => [
    if (raw is List)
      for (final row in raw) ?leaderboardEntryFrom(row, selfId: selfId),
  ];
  return LeaderboardView(
    entries: list(view?['entries']),
    bottomEntries: list(view?['bottomEntries']),
    playerEntry: leaderboardEntryFrom(view?['playerEntry'], selfId: selfId),
    playerRank: view?['playerRank'] is num
        ? (view!['playerRank'] as num).toInt()
        : null,
    contextAbove: leaderboardEntryFrom(view?['contextAbove'], selfId: selfId),
    contextBelow: leaderboardEntryFrom(view?['contextBelow'], selfId: selfId),
    playerBeyondTop: view?['playerBeyondTop'] == true,
    showGap: view?['showGap'] == true,
    showGapBeforeBottom: view?['showGapBeforeBottom'] == true,
    optedOut: optedOut,
  );
}

/// Put this device's own club name, badge and platform on the player's row.
///
/// See the file header for why each one. [badgeId] null is a device that has
/// never made a badge choice, and skipping the override there is what stops a
/// second device stomping the stored badge back to default.
LeaderboardView withLocalOverrides(
  LeaderboardView view, {
  String? clubName,
  String? badgeId,
  required String platform,
}) {
  final name = clubName?.trim();
  LeaderboardEntry? fix(LeaderboardEntry? entry) {
    if (entry == null || !entry.isPlayer) return entry;
    return entry.copyWith(
      clubName: name == null || name.isEmpty
          ? null
          : (name.length <= 40 ? name : name.substring(0, 40)),
      badgeId: badgeId,
      platform: platform,
    );
  }

  return LeaderboardView(
    entries: [for (final e in view.entries) fix(e)!],
    bottomEntries: [for (final e in view.bottomEntries) fix(e)!],
    playerEntry: fix(view.playerEntry),
    playerRank: view.playerRank,
    contextAbove: fix(view.contextAbove),
    contextBelow: fix(view.contextBelow),
    playerBeyondTop: view.playerBeyondTop,
    showGap: view.showGap,
    showGapBeforeBottom: view.showGapBeforeBottom,
    error: view.error,
    optedOut: view.optedOut,
  );
}
