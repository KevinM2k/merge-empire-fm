/// The leaderboard's transport half — the fetch, the match write and the
/// opt-out sweep from
/// `../merge-empire-fc/src/services/leaderboardService.js`.
///
/// **The schema is in `engine/leaderboard_policy.dart` and the shapes are in
/// `engine/leaderboard_view.dart`**, both pure and both tested; what is here is
/// what talks. The split matters because the rows on the server are the SHIPPED
/// app's, so the schema half had to agree with it exactly and this half is free
/// to use whatever transport suits the port.
///
/// **THE BOARD IS BUILT BY A CLOUD FUNCTION.** That is the JS's own primary
/// path, and the reason it exists is that a rank is a `count()` over the whole
/// collection: one server call, or a hundred document reads on a phone. The
/// client sends who it is, which period, which metric and which filters, and
/// gets a finished view back.
///
/// **What is NOT ported: the direct-read fallback.** The JS drops to a
/// multi-query Firestore path when the function call fails — top rows,
/// neighbours, two counts and a backfill sweep, several hundred lines of it —
/// and a board that fails to load is a board that says so rather than a save
/// that is at risk. Recorded in `docs/REMAINING.md` rather than half-built.
///
/// **A FINISHED MATCH IS FOUR WRITES, NOT FORTY-EIGHT.** Schema v2 puts one row
/// per player per PERIOD and makes the scope a `where` filter rather than a
/// folder in the path, so a match touches `1d`, `7d`, `30d` and `alltime` and
/// nothing else. They go in ONE atomic commit, which is also what makes the
/// retry safe: a failure wrote nothing, so the whole batch can be replayed.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:merge_empire_fc/data/firebase_config.dart';
import 'package:merge_empire_fc/engine/auth_policy.dart';
import 'package:merge_empire_fc/engine/leaderboard_policy.dart';
import 'package:merge_empire_fc/engine/leaderboard_view.dart';
import 'package:merge_empire_fc/services/firestore_rest.dart';
import 'package:merge_empire_fc/util/region.dart';
import 'package:merge_empire_fc/util/time.dart';

/// The deployed function that builds a board.
final Uri leaderboardViewUrl = Uri.https(
  'us-central1-$firebaseProjectId.cloudfunctions.net',
  '/getLeaderboardView',
);

/// The JS's own fifteen seconds. Longer than a Firestore read because the
/// function is doing the counting.
const Duration leaderboardTimeout = Duration(seconds: 15);

/// How long a fetched board is reused. The JS's sixty seconds: a board view
/// reads a hundred documents server-side and a tab flip re-requests the same
/// one within a second or two.
const Duration leaderboardCacheFor = Duration(seconds: 60);

/// The transport seam. Replaced wholesale in tests.
typedef LeaderboardPost =
    Future<({int status, Object? data})> Function(
      Uri url,
      Map<String, String> headers,
      Object body,
    );

LeaderboardPost leaderboardPost = _realPost;

/// Put it back, and empty the cache with it. For tests.
void resetLeaderboardSeams() {
  leaderboardPost = _realPost;
  clearLeaderboardCache();
}

Future<({int status, Object? data})> _realPost(
  Uri url,
  Map<String, String> headers,
  Object body,
) async {
  final client = HttpClient()..connectionTimeout = leaderboardTimeout;
  try {
    final request = await client.postUrl(url).timeout(leaderboardTimeout);
    request.headers.contentType = ContentType.json;
    headers.forEach(request.headers.set);
    request.write(jsonEncode(body));
    final response = await request.close().timeout(leaderboardTimeout);
    final text = await response
        .transform(utf8.decoder)
        .join()
        .timeout(leaderboardTimeout);
    Object? data;
    try {
      data = text.isEmpty ? null : jsonDecode(text);
    } catch (_) {
      data = text;
    }
    return (status: response.statusCode, data: data);
  } finally {
    client.close(force: true);
  }
}

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// Which platform a row was written from. A fact about this device.
String get _platform {
  if (Platform.isIOS) return 'ios';
  if (Platform.isAndroid) return 'android';
  return 'web';
}

/// Whether this player is listed publicly. Opted out is the only stored false.
bool leaderboardRankingsVisible(Map<String, dynamic>? state) =>
    _map(state?['leaderboard'])?['rankingsVisible'] != false;

// ---------------------------------------------------------------------------
// The fetch.
// ---------------------------------------------------------------------------

final Map<String, ({int at, LeaderboardView view})> _cache = {};

void clearLeaderboardCache() => _cache.clear();

/// **What the cached board is keyed on, and why each part is in it.**
///
/// The period, metric, limit and filters are the board itself. The other four
/// feed the row FLAGS and labels rather than the query — the player's own uid,
/// whether they are listed, their club name and their badge — and changing any
/// of them has to miss the cache rather than serve a view with the old one
/// stamped on the player's row.
String leaderboardCacheKey(
  Map<String, dynamic>? state, {
  required String periodKey,
  required String metric,
  required int limit,
  required List<(String, String)> filters,
}) {
  final board = _map(state?['leaderboard']);
  return [
    periodKey,
    metric,
    '$limit',
    [for (final f in filters) '${f.$1}=${f.$2}'].join(','),
    board?['authUid'] ?? '',
    '${leaderboardRankingsVisible(state)}',
    state?['clubName'] ?? '',
    _map(state?['progression'])?['equippedBadgeId'] ?? '',
  ].join('|');
}

/// One board.
///
/// **Prestige is always ALL-TIME.** It is not a score that accumulates in a
/// window — it is a level — so a "this week's prestige" board would be a board
/// of everybody who has prestiged this week rather than of who has prestiged
/// most. The JS forces the period and so does this.
Future<LeaderboardView> fetchLeaderboard(
  Map<String, dynamic>? state, {
  required String scope,
  required String period,
  required String metric,
  String? divisionId,
  int limit = leaderboardFetchLimit,
  bool force = false,
}) async {
  final effectivePeriod = metric == 'prestige' ? 'alltime' : period;
  final periodKey = leaderboardPeriodKey(effectivePeriod, DateTime.now());
  final filters = leaderboardScopeFilters(
    scope,
    divisionId:
        divisionId ?? _map(state?['progression'])?['currentDivision'] as String?,
    regionCode: getPlayerRegionCode(state),
  );
  final capped = limit.clamp(1, leaderboardFetchLimit);
  final key = leaderboardCacheKey(
    state,
    periodKey: periodKey,
    metric: metric,
    limit: capped,
    filters: filters,
  );
  if (!force) {
    final hit = _cache[key];
    if (hit != null && now() - hit.at < leaderboardCacheFor.inMilliseconds) {
      return hit.view;
    }
  }

  final optedOut = !leaderboardRankingsVisible(state);
  // **An opted-out player is not looked up.** They can read the board; they are
  // simply not on it, and asking for their row would put it there.
  final selfId = optedOut ? null : sessionUid(state);

  final LeaderboardView view;
  try {
    view = await _callViewFunction(
      selfId: selfId,
      periodKey: periodKey,
      metric: metric,
      filters: filters,
      limit: capped,
      optedOut: optedOut,
    );
  } catch (_) {
    // A board that will not load says so. Never cached: the next look should
    // try again rather than be told the same thing for a minute.
    return LeaderboardView(error: 'fetch_failed', optedOut: optedOut);
  }

  final stamped = withLocalOverrides(
    view,
    clubName: state?['clubName'] as String?,
    // RAW, so a device that has never chosen a badge overrides nothing.
    badgeId: optedOut
        ? null
        : _map(state?['progression'])?['equippedBadgeId'] as String?,
    platform: _platform,
  );
  _cache[key] = (at: now(), view: stamped);
  return stamped;
}

Future<LeaderboardView> _callViewFunction({
  required String? selfId,
  required String periodKey,
  required String metric,
  required List<(String, String)> filters,
  required int limit,
  required bool optedOut,
}) async {
  final token = await firestoreAuthToken();
  final response = await leaderboardPost(
    leaderboardViewUrl,
    {if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token'},
    {
      // A callable function takes its payload wrapped, and answers wrapped.
      'data': {
        'playerId': selfId,
        'periodKey': periodKey,
        'metric': metric,
        'scopeFilters': [
          for (final f in filters) [f.$1, f.$2],
        ],
        'limit': limit,
      },
    },
  );
  if (response.status < 200 || response.status >= 300) {
    throw StateError('fn_http_${response.status}');
  }
  final body = _map(response.data);
  if (body?['error'] != null) throw StateError('fn_error');
  return leaderboardViewFrom(
    body?['result'] ?? body,
    selfId: selfId,
    optedOut: optedOut,
  );
}

// ---------------------------------------------------------------------------
// The write.
// ---------------------------------------------------------------------------

/// What one finished match adds to a row.
typedef MatchSubmission = ({
  int points,
  int wins,
  int goalsFor,
  String divisionId,
  int playedAt,
});

/// The three increments and the division, off a match result.
///
/// **`homeGoals` is always the PLAYER's goals** in an engine result — there is
/// no venue flip — which is the JS's own comment and the one thing about this
/// that looks wrong and is not.
MatchSubmission submissionFor(
  Map<String, dynamic>? state,
  Map<String, dynamic> result,
) {
  final won = result['won'] == true;
  final drawn = result['drawn'] == true;
  final goals = result['homeGoals'];
  return (
    points: won ? 3 : (drawn ? 1 : 0),
    wins: won ? 1 : 0,
    goalsFor: goals is num ? goals.round() : 0,
    divisionId:
        result['divisionId'] as String? ??
        _map(state?['progression'])?['currentDivision'] as String? ??
        'sunday_league',
    playedAt: result['playedAt'] is num
        ? (result['playedAt'] as num).toInt()
        : now(),
  );
}

/// The meta every write refreshes on the row.
///
/// **`accountName` is written as NULL rather than left out.** Email-derived
/// names are never published, and stating the null is what scrubs the field
/// from a row created by an older version.
///
/// **`badgeId` is left OUT when this device has never chosen one.** A merge
/// patch then leaves the stored badge alone, which is what stops a second
/// device with an unsynced save stomping it back to default.
Map<String, Object?> leaderboardRowMeta(
  Map<String, dynamic>? state, {
  required String divisionId,
}) {
  final club = '${state?['clubName'] ?? 'Unknown FC'}';
  final badge = _map(state?['progression'])?['equippedBadgeId'];
  return <String, Object?>{
    'clubName': club.length <= 40 ? club : club.substring(0, 40),
    'division': divisionId,
    'region': getPlayerRegionCode(state),
    'prestigeLevel': (_map(state?['prestige'])?['level'] as num?)?.round() ?? 0,
    // Opted-out players keep accruing scores — the rolling windows stay
    // correct — and simply stay off the public boards.
    'listed': leaderboardRankingsVisible(state),
    'accountName': null,
    'platform': _platform,
    if (badge is String && badge.isNotEmpty) 'badgeId': badge,
  };
}

/// Put a finished match on all four boards.
///
/// **Increment-by-zero is deliberate.** It creates the field at 0 without
/// resetting an existing score, so a drawn or lost match still puts the club on
/// every board rather than leaving it absent until it wins one.
///
/// Returns whether the commit landed. A false is not an error the player should
/// see: the JS queues the batch and replays it on reconnect, and a board that
/// is a match behind is not a save at risk.
Future<bool> submitMatchStats(
  Map<String, dynamic> state,
  Map<String, dynamic> result,
) async {
  final uid = sessionUid(state);
  if (uid == null) return false;
  final submission = submissionFor(state, result);
  final meta = leaderboardRowMeta(state, divisionId: submission.divisionId);
  final at = DateTime.fromMillisecondsSinceEpoch(submission.playedAt);

  try {
    await restCommitWrites([
      for (final period in leaderboardPeriods)
        (
          docPath: leaderboardRowPath(
            leaderboardPeriodKey(period, at),
            uid,
          ),
          set: <String, Object?>{
            ...meta,
            'period': leaderboardPeriodKey(period, at),
            'ownerId': uid,
          },
          increment: <String, num>{
            'points': submission.points,
            'wins': submission.wins,
            'goals_for': submission.goalsFor,
          },
          serverTimestamps: const ['updatedAt'],
          merge: true,
          mustNotExist: false,
          ifUpdateTime: null,
        ),
    ]);
  } catch (_) {
    return false;
  }

  final board = _map(state['leaderboard']);
  if (board != null) {
    board['prestigeSynced'] = <String, dynamic>{
      'level': meta['prestigeLevel'],
    };
    board['lastSubmittedAt'] = now();
  }
  // The board moved, so anything cached from before it is stale.
  clearLeaderboardCache();
  return true;
}

// ---------------------------------------------------------------------------
// Opting out.
// ---------------------------------------------------------------------------

/// Every period a row could exist in, for a sweep.
///
/// **Not "all of them" — the rolling windows the rows can still be in.** The
/// JS's own spans: thirty-five days, six weeks, three months, plus all-time.
/// A row older than that has aged off every board it could appear on.
List<String> leaderboardSweepPeriods([DateTime? at]) {
  final now = at ?? DateTime.now();
  final keys = <String>{'alltime'};
  for (var d = 0; d < 35; d++) {
    keys.add(leaderboardPeriodKey('1d', now.subtract(Duration(days: d))));
  }
  for (var w = 0; w < 6; w++) {
    keys.add(leaderboardPeriodKey('7d', now.subtract(Duration(days: w * 7))));
  }
  for (var m = 0; m < 3; m++) {
    keys.add(
      leaderboardPeriodKey(
        '30d',
        DateTime.utc(now.year, now.month - m, 1),
      ),
    );
  }
  return keys.toList();
}

/// Hide or re-list this player's rows.
///
/// **A row UPDATE is always permitted and a DELETE may not be**, which is why
/// opting out patches `listed` rather than removing anything: the scores vanish
/// from every public board whatever the rules say about deletes, and opting
/// back in simply re-lists them with nothing lost.
///
/// `merge: true` creates a score-less stub for a period the player has no row
/// in, which is harmless — a board orders by a score field, so a document
/// without one is not on it.
Future<bool> setLeaderboardListed(
  Map<String, dynamic> state, {
  required bool listed,
}) async {
  final uid = sessionUid(state);
  if (uid == null) return false;
  try {
    await restCommitWrites([
      for (final period in leaderboardSweepPeriods())
        (
          docPath: leaderboardRowPath(period, uid),
          set: <String, Object?>{'listed': listed},
          increment: const <String, num>{},
          serverTimestamps: const ['updatedAt'],
          merge: true,
          mustNotExist: false,
          ifUpdateTime: null,
        ),
    ]);
  } catch (_) {
    return false;
  }
  final board = _map(state['leaderboard']);
  if (board != null) board['optOutApplied'] = !listed;
  clearLeaderboardCache();
  return true;
}

/// Repair a visibility toggle that was interrupted — offline, or killed
/// mid-write.
///
/// **Idempotent, and run on every signed-in boot.** The player's stored
/// preference is the truth; `optOutApplied` records whether the server has been
/// told. A hide that never landed leaves somebody listed who asked not to be,
/// which is the direction that matters.
Future<void> ensureLeaderboardOptOutApplied(Map<String, dynamic> state) async {
  if (sessionUid(state) == null) return;
  final board = _map(state['leaderboard']);
  final applied = board?['optOutApplied'] == true;
  if (leaderboardRankingsVisible(state)) {
    if (applied) await setLeaderboardListed(state, listed: true);
    return;
  }
  if (!applied) await setLeaderboardListed(state, listed: false);
}
