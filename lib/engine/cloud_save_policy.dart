/// Who wins when the phone and the cloud disagree — the pure half of
/// `../merge-empire-fc/src/services/cloudSaveService.js`.
///
/// **Every hard decision in cloud save is arithmetic over two summaries**, and
/// all of it is here: whether a save is more than a fresh install, whether two
/// saves are the same lineage, and which of upload / restore / ask the player
/// a boot should take. The transport, the debounce and the modal are in
/// `services/cloud_save_service.dart`; this file opens no socket and so is
/// testable to the edges, which matters more here than almost anywhere else in
/// the port — the failure mode is a player losing a season.
///
/// **The rules that are not obvious, and why they exist**, taken from the JS's
/// own comments rather than invented:
///
/// - A stale precondition must NOT silently drop the write. Doing that froze
///   full saves for days while the leaderboard — which writes with no
///   precondition — kept advancing, and only a reinstall re-baselined the token
///   to unstick it. [reconcileStaleUpload] is the answer: same lineage, or this
///   device at least as recent, means retry rather than conflict.
/// - Identical fingerprints are never a conflict. A token lost to an OS process
///   kill looks exactly like another device having written, and alarming a
///   player about their own save is worse than a silent re-sync.
/// - A cloud copy that has not moved since THIS device last synced it is not a
///   conflict either — local is simply ahead, which is what a tab closing
///   before a debounced upload flushed looks like.
library;

/// What the two sides look like, in the terms the conflict card shows.
typedef SaveSummary = ({
  String clubName,
  String divisionId,
  int matchesPlayed,
  int seasonCount,
  int lastSeen,
});

/// What a boot should do about the cloud.
enum CloudSaveAction {
  /// Nothing to do — same save on both sides.
  none,

  /// Local is authoritative; push it.
  upload,

  /// Cloud is authoritative; pull it.
  restore,

  /// They diverge and neither is obviously right. Ask.
  choose,
}

/// The outcome of a boot evaluation.
typedef CloudSaveVerdict = ({
  CloudSaveAction action,

  /// Non-zero when the saves match but the cloud has seen the player more
  /// recently — the local `lastSeen` is bumped rather than the whole save being
  /// replaced, which is what stops a boot loop on two devices playing the same
  /// save.
  int bumpLastSeen,
});

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

int _int(Object? v) => v is num ? v.toInt() : 0;

/// The default division id, matching the JS's fallback.
const String _openingDivision = 'sunday_league';

/// A summary of a live save.
///
/// [fallbackClubName] is `t('common.your_club')` at the call site: this file is
/// pure and does not reach the catalogues, which also means a test does not need
/// them initialised.
SaveSummary saveSummaryFromState(
  Map<String, dynamic>? state, {
  required String fallbackClubName,
}) {
  final progression = _map(state?['progression']);
  final name = '${state?['clubName'] ?? ''}'.trim();
  return (
    clubName: name.isEmpty ? fallbackClubName : name,
    divisionId: '${progression?['currentDivision'] ?? _openingDivision}',
    matchesPlayed: _int(progression?['matchesPlayed']),
    // Season ONE, not zero: a fresh save has played its first season.
    seasonCount: progression?['seasonCount'] is num
        ? _int(progression?['seasonCount'])
        : 1,
    lastSeen: _int(state?['lastSeen']),
  );
}

/// **Two saves are the same LINEAGE when these four agree.**
///
/// Not the whole save and not a hash of it: a fingerprint has to survive the
/// same save being played a few seconds further on one device, or every
/// background upload would read as a conflict. Club, division, matches and
/// seasons are the four fields a player would use to tell two saves apart on a
/// card, which is exactly the question being asked.
String saveFingerprint(SaveSummary s) =>
    '${s.clubName}|${s.divisionId}|${s.matchesPlayed}|${s.seasonCount}';

/// Whether this save is more than a fresh install.
///
/// **Deliberately generous.** Any one of these is enough, because the cost of a
/// false negative is overwriting somebody's game and the cost of a false
/// positive is one extra prompt.
bool localSaveHasProgress(Map<String, dynamic>? state) {
  if (state == null) return false;
  final progression = _map(state['progression']) ?? const {};
  if (_int(progression['matchesPlayed']) > 0) return true;
  if (progression['seasonCount'] is num && _int(progression['seasonCount']) > 1) {
    return true;
  }
  if ('${progression['currentDivision'] ?? _openingDivision}' !=
      _openingDivision) {
    return true;
  }
  if (_int(_map(state['prestige'])?['level']) > 0) return true;
  final cells = _map(state['grid'])?['cells'];
  if (cells is List && cells.any((c) => c != null)) return true;
  final assets = _map(state['clubAssets']) ?? const {};
  if (assets.values.any((a) => a is Map && a['owned'] == true)) return true;
  if (_int(_map(state['stats'])?['merges']) > 0) return true;
  if ('${state['clubName'] ?? ''}'.trim().isNotEmpty) return true;
  return false;
}

/// How far two Firestore update times may drift and still count as the same
/// version.
///
/// A commit's `updateTime` and the `updateTime` a later read reports are not
/// bit-identical — server clock and write-vs-read timing — so an exact
/// comparison would call every second boot a conflict.
const int cloudSyncSlackMs = 1500;

/// Firestore timestamps come back as RFC 3339 strings.
int cloudTimestampMs(String? timestamp) {
  if (timestamp == null || timestamp.isEmpty) return 0;
  return DateTime.tryParse(timestamp)?.millisecondsSinceEpoch ?? 0;
}

/// Whether a rejected write was rejected by its PRECONDITION rather than by
/// anything else.
///
/// Matched on the message because that is all the REST API gives back, and on
/// four spellings because the API has used more than one. A false negative here
/// re-throws to the caller, which is the safe direction: it surfaces rather than
/// silently retrying.
bool isPreconditionFailure(Object? error) {
  final message = '$error'.toLowerCase();
  return message.contains('failed_precondition') ||
      message.contains('precondition') ||
      message.contains('does not match the required base version') ||
      message.contains('stored version');
}

/// What to do about a rejected precondition.
enum StaleUploadVerdict {
  /// The token had merely drifted. Re-baseline and write again.
  retry,

  /// The cloud holds a genuinely newer, divergent save. Do not clobber it.
  conflict,
}

/// **A stale precondition is usually NOT a conflict**, and treating it as one
/// is the bug this function exists to have fixed: it froze full saves for days
/// while the leaderboard kept advancing.
///
/// [cloudSummary] null means the cloud document is missing or will not decode,
/// which is safe to overwrite.
StaleUploadVerdict reconcileStaleUpload({
  required SaveSummary local,
  required SaveSummary? cloudSummary,
  required int cloudLastSeen,
}) {
  if (cloudSummary == null) return StaleUploadVerdict.retry;
  final sameLineage = saveFingerprint(local) == saveFingerprint(cloudSummary);
  // Overwriting is correct when this device has been active at least as
  // recently: the only alternative — the old behaviour — dropped the write
  // forever.
  final localAtLeastAsRecent = local.lastSeen >= cloudLastSeen;
  return sameLineage || localAtLeastAsRecent
      ? StaleUploadVerdict.retry
      : StaleUploadVerdict.conflict;
}

/// The boot decision, given both sides.
///
/// [cloudSummary] null means there is no usable cloud save — missing, or a
/// document this build cannot migrate.
///
/// [priorToken] is the cloud version THIS device last synced, captured before
/// the evaluation re-baselines it. It is what separates "local is ahead of a
/// cloud nobody else has touched" (upload, no prompt) from "another device
/// wrote" (a real conflict).
CloudSaveVerdict decideCloudSaveAction({
  required Map<String, dynamic>? localState,
  required SaveSummary local,
  required SaveSummary? cloudSummary,
  required Map<String, dynamic>? cloudState,
  required String? priorToken,
  required String? cloudUpdateTime,
}) {
  const none = (action: CloudSaveAction.none, bumpLastSeen: 0);
  if (cloudSummary == null || cloudState == null) {
    return (action: CloudSaveAction.upload, bumpLastSeen: 0);
  }

  final cloudProgress = localSaveHasProgress(cloudState);
  if (!cloudProgress) return (action: CloudSaveAction.upload, bumpLastSeen: 0);

  if (!localSaveHasProgress(localState)) {
    return (action: CloudSaveAction.restore, bumpLastSeen: 0);
  }

  if (saveFingerprint(local) == saveFingerprint(cloudSummary)) {
    // Same progress snapshot. No restore — that is a reload loop on boot — but
    // the later `lastSeen` is worth taking, because it is the one thing the
    // other device knows that this one does not.
    return (
      action: CloudSaveAction.none,
      bumpLastSeen: cloudSummary.lastSeen > local.lastSeen
          ? cloudSummary.lastSeen
          : 0,
    );
  }

  // Fingerprints differ. If the cloud has not moved since this device last
  // synced it, local is simply ahead — the tab closed before the debounced
  // upload flushed. Only a cloud changed on ANOTHER device is a real conflict.
  if (priorToken != null && cloudUpdateTime != null) {
    final drift =
        (cloudTimestampMs(cloudUpdateTime) - cloudTimestampMs(priorToken)).abs();
    if (drift <= cloudSyncSlackMs) {
      return (action: CloudSaveAction.upload, bumpLastSeen: 0);
    }
  }

  return (action: CloudSaveAction.choose, bumpLastSeen: none.bumpLastSeen);
}

/// Whether a cloud document seen on resume was written by ANOTHER device.
///
/// The slack is the same as everywhere else: a write this device made comes back
/// with an `updateTime` a few hundred milliseconds off the token it recorded,
/// and that is not somebody else playing.
bool cloudChangedElsewhere({required int cloudMs, required int syncedMs}) =>
    cloudMs > syncedMs + cloudSyncSlackMs;
