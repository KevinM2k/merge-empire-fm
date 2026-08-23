/// Cloud save — the Firestore backup of a whole save, ported from
/// `../merge-empire-fc/src/services/cloudSaveService.js`.
///
/// **All of the deciding is in `engine/cloud_save_policy.dart`**, which is pure
/// and tested to the edges; this file is the sockets, the debounce and the
/// writes. That split matters more here than anywhere else in the port, because
/// the failure mode is a player losing a season.
///
/// **The save travels as a JSON STRING in one field.** The REST value encoder
/// handles scalars only and the save is deeply nested, so `data` is
/// `jsonEncode(save)` rather than a Firestore map — the JS's own arrangement,
/// and the reason a document written by the shipped app is readable here.
///
/// **`authUid` is stripped before upload.** It belongs to whichever device
/// wrote the copy, and restoring it over the top would hand this device another
/// account's identity.
///
/// What is NOT here: the conflict CARD. `evaluateCloudSave` returns
/// [CloudSaveAction.choose] and stops, because putting a decision on screen is
/// the UI layer's job and this file may not import Flutter — the shipped copy
/// for it (`cloud.conflict.*`, twelve keys with no caller) is waiting.
library;

import 'dart:async';
import 'dart:convert';

import 'package:merge_empire_fc/engine/cloud_save_policy.dart';
import 'package:merge_empire_fc/services/firestore_rest.dart';

/// How long a debounced upload waits. The JS's 2,500ms — long enough that a
/// merge spree is one write, short enough that closing the app loses nothing
/// the flush below would not catch.
const Duration cloudUploadDebounce = Duration(milliseconds: 2500);

/// Where a player's save lives.
String cloudSaveDocPath(String uid) => 'saves/$uid';

/// The result of an upload attempt.
///
/// [stale] means the write was refused because the cloud moved on another
/// device — NOT that it failed. The caller surfaces the conflict rather than
/// retrying, and the local save is untouched.
typedef CloudUploadResult = ({bool ok, bool stale});

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

int _int(Object? v) => v is num ? v.toInt() : 0;

/// A deep copy with the device's own identity removed.
Map<String, dynamic> packStateForCloud(Map<String, dynamic> state) {
  final copy = jsonDecode(jsonEncode(state)) as Map<String, dynamic>;
  final leaderboard = _map(copy['leaderboard']);
  if (leaderboard != null) leaderboard['authUid'] = null;
  return copy;
}

/// Record the exact cloud version this device last synced.
///
/// **Both halves matter.** The token is the optimistic-concurrency
/// precondition; the milliseconds are what the resume check compares against,
/// and it needs a number rather than a string.
void markCloudSynced(Map<String, dynamic> state, String? updateTime) {
  if (updateTime == null || updateTime.isEmpty) return;
  final leaderboard = _map(state['leaderboard']);
  if (leaderboard == null) return;
  leaderboard['cloudSyncToken'] = updateTime;
  leaderboard['cloudSyncMs'] = cloudTimestampMs(updateTime);
}

/// What a cloud document holds, decoded.
typedef CloudSnapshot = ({
  int lastSeen,
  String? updateTime,
  int updatedAtMs,
  Map<String, dynamic>? cloudData,
});

/// Read and parse the cloud document. Null when there is not one.
Future<CloudSnapshot?> fetchCloudSave(String uid) async {
  final doc = await restGetDocument(cloudSaveDocPath(uid));
  if (doc == null) return null;
  final raw = doc.data['data'];
  Map<String, dynamic>? cloudData;
  if (raw is String) {
    try {
      final decoded = jsonDecode(raw);
      cloudData = decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      cloudData = null;
    }
  } else if (raw is Map<String, dynamic>) {
    // Legacy nested-map saves, from before the string encoding.
    cloudData = raw;
  }
  return (
    lastSeen: _int(doc.data['lastSeen']),
    updateTime: doc.updateTime,
    updatedAtMs: cloudTimestampMs(doc.updateTime),
    cloudData: cloudData,
  );
}

/// Upload, with an optimistic-concurrency precondition unless [force].
///
/// **A refused precondition is reconciled rather than dropped.** Dropping it —
/// which the JS used to do — froze full saves for days while the leaderboard,
/// which writes with no precondition, kept advancing; only a reinstall
/// re-baselined the token to unstick it. See [reconcileStaleUpload].
///
/// [migrateCloud] decides whether a cloud document is readable at all, and is
/// passed in because migration lives in the state layer, which this file is
/// below.
Future<CloudUploadResult> uploadCloudSave(
  Map<String, dynamic> state,
  String? uid, {
  bool force = false,
  required Map<String, dynamic>? Function(Map<String, dynamic>?) migrateCloud,
  required String fallbackClubName,
  bool retried = false,
}) async {
  if (uid == null || uid.isEmpty) return (ok: false, stale: false);

  final token = _map(state['leaderboard'])?['cloudSyncToken'];
  final ifUpdateTime = force || token is! String || token.isEmpty
      ? null
      : token;

  try {
    await restCommitWrite(
      cloudSaveDocPath(uid),
      set: <String, Object?>{
        'version': _int(state['version']),
        'lastSeen': _int(state['lastSeen']),
        'data': jsonEncode(packStateForCloud(state)),
      },
      serverTimestamps: const ['updatedAt'],
      // **NOT a merge.** The document is one blob; patching it would leave the
      // previous save's fields alongside the new one's.
      merge: false,
      ifUpdateTime: ifUpdateTime,
    );
    // The commit's own updateTime is not returned by `restCommitWrite`, so the
    // token is re-baselined by the next read rather than guessed at here. That
    // is a deliberate simplification of the JS, which reads it out of the
    // response: a token that lags is the DRIFT case, which reconciles to a
    // retry — the safe direction — while a wrong token would not.
    return (ok: true, stale: false);
  } catch (e) {
    if (ifUpdateTime == null || !isPreconditionFailure(e)) rethrow;
    if (retried) return (ok: false, stale: true);

    final verdict = await _reconcile(
      state,
      uid,
      migrateCloud: migrateCloud,
      fallbackClubName: fallbackClubName,
    );
    if (verdict == StaleUploadVerdict.conflict) {
      return (ok: false, stale: true);
    }
    return uploadCloudSave(
      state,
      uid,
      force: force,
      migrateCloud: migrateCloud,
      fallbackClubName: fallbackClubName,
      retried: true,
    );
  }
}

Future<StaleUploadVerdict> _reconcile(
  Map<String, dynamic> state,
  String uid, {
  required Map<String, dynamic>? Function(Map<String, dynamic>?) migrateCloud,
  required String fallbackClubName,
}) async {
  CloudSnapshot? snap;
  try {
    snap = await fetchCloudSave(uid);
  } catch (_) {
    // Cannot verify the live version — do not risk clobbering it.
    return StaleUploadVerdict.conflict;
  }

  final migrated = snap == null ? null : migrateCloud(snap.cloudData);
  if (migrated == null) {
    // No usable cloud document. Clear the stale token so the retry writes
    // unconditionally.
    final leaderboard = _map(state['leaderboard']);
    if (leaderboard != null) {
      leaderboard['cloudSyncToken'] = null;
      leaderboard['cloudSyncMs'] = 0;
    }
    return StaleUploadVerdict.retry;
  }

  final verdict = reconcileStaleUpload(
    local: saveSummaryFromState(state, fallbackClubName: fallbackClubName),
    cloudSummary: saveSummaryFromState(
      migrated,
      fallbackClubName: fallbackClubName,
    ),
    cloudLastSeen: snap!.lastSeen,
  );
  if (verdict == StaleUploadVerdict.retry) {
    markCloudSynced(state, snap.updateTime);
  }
  return verdict;
}

/// What a boot or a sign-in should do, and everything the conflict card needs
/// to draw itself.
typedef CloudSaveEvaluation = ({
  CloudSaveAction action,
  int bumpLastSeen,
  SaveSummary? cloud,
  SaveSummary? local,
  Map<String, dynamic>? cloudData,
  int cloudLastSeen,
  String? cloudUpdateTime,
});

const CloudSaveEvaluation _nothingToDo = (
  action: CloudSaveAction.none,
  bumpLastSeen: 0,
  cloud: null,
  local: null,
  cloudData: null,
  cloudLastSeen: 0,
  cloudUpdateTime: null,
);

/// Decide what to do about the cloud, without doing it.
///
/// **The prior token is captured BEFORE the baseline is written**, and that
/// ordering is the whole of how "local is ahead of a cloud nobody touched" is
/// told apart from "another device wrote". Getting it the other way round makes
/// every boot a conflict.
Future<CloudSaveEvaluation> evaluateCloudSave(
  Map<String, dynamic> state,
  String? uid, {
  required Map<String, dynamic>? Function(Map<String, dynamic>?) migrateCloud,
  required String fallbackClubName,
  required bool online,
}) async {
  if (uid == null || uid.isEmpty || !online) return _nothingToDo;

  final priorRaw = _map(state['leaderboard'])?['cloudSyncToken'];
  final priorToken = priorRaw is String && priorRaw.isNotEmpty
      ? priorRaw
      : null;

  final CloudSnapshot? snap;
  try {
    snap = await fetchCloudSave(uid);
  } catch (_) {
    // A cloud we cannot read is a cloud we leave alone.
    return _nothingToDo;
  }

  final local = saveSummaryFromState(
    state,
    fallbackClubName: fallbackClubName,
  );
  if (snap == null) {
    return (
      action: CloudSaveAction.upload,
      bumpLastSeen: 0,
      cloud: null,
      local: local,
      cloudData: null,
      cloudLastSeen: 0,
      cloudUpdateTime: null,
    );
  }

  // Baseline the synced version so the resume check does not false-fire.
  //
  // **This does not persist**, deliberately: saving here stamps `lastSeen` with
  // now, and offline earnings have not been processed yet — which would zero
  // out the player's overnight income. The token is in memory and the boot
  // sequence's own save flushes it.
  markCloudSynced(state, snap.updateTime);

  final migrated = migrateCloud(snap.cloudData);
  final cloud = migrated == null
      ? null
      : (
          clubName: saveSummaryFromState(
            migrated,
            fallbackClubName: fallbackClubName,
          ).clubName,
          divisionId: saveSummaryFromState(
            migrated,
            fallbackClubName: fallbackClubName,
          ).divisionId,
          matchesPlayed: saveSummaryFromState(
            migrated,
            fallbackClubName: fallbackClubName,
          ).matchesPlayed,
          seasonCount: saveSummaryFromState(
            migrated,
            fallbackClubName: fallbackClubName,
          ).seasonCount,
          // The CLOUD DOCUMENT's lastSeen, not the one inside the blob: the
          // field is written alongside the save and is what the card shows.
          lastSeen: snap.lastSeen,
        );

  final verdict = decideCloudSaveAction(
    localState: state,
    local: local,
    cloudSummary: cloud,
    cloudState: migrated,
    priorToken: priorToken,
    cloudUpdateTime: snap.updateTime,
  );

  return (
    action: verdict.action,
    bumpLastSeen: verdict.bumpLastSeen,
    cloud: cloud,
    local: local,
    cloudData: snap.cloudData,
    cloudLastSeen: snap.lastSeen,
    cloudUpdateTime: snap.updateTime,
  );
}

/// A cloud copy changed by ANOTHER device since this one last synced, or null.
///
/// **Identical fingerprints are re-synced silently rather than reported.** A
/// token lost to an OS process kill looks exactly like somebody else having
/// written, and alarming a player about their own save is worse than a quiet
/// re-baseline.
Future<CloudSaveEvaluation?> checkRemoteCloudChange(
  Map<String, dynamic> state,
  String? uid, {
  required Map<String, dynamic>? Function(Map<String, dynamic>?) migrateCloud,
  required String fallbackClubName,
  required bool online,
}) async {
  if (uid == null || uid.isEmpty || !online) return null;

  final CloudSnapshot? snap;
  try {
    snap = await fetchCloudSave(uid);
  } catch (_) {
    return null;
  }
  if (snap == null) return null;

  final migrated = migrateCloud(snap.cloudData);
  if (migrated == null) return null;

  if (!cloudChangedElsewhere(
    cloudMs: snap.updatedAtMs,
    syncedMs: _int(_map(state['leaderboard'])?['cloudSyncMs']),
  )) {
    return null;
  }

  final local = saveSummaryFromState(
    state,
    fallbackClubName: fallbackClubName,
  );
  final migratedSummary = saveSummaryFromState(
    migrated,
    fallbackClubName: fallbackClubName,
  );
  final cloud = (
    clubName: migratedSummary.clubName,
    divisionId: migratedSummary.divisionId,
    matchesPlayed: migratedSummary.matchesPlayed,
    seasonCount: migratedSummary.seasonCount,
    lastSeen: snap.lastSeen,
  );

  if (saveFingerprint(local) == saveFingerprint(cloud)) {
    markCloudSynced(state, snap.updateTime);
    return null;
  }

  return (
    action: CloudSaveAction.choose,
    bumpLastSeen: 0,
    cloud: cloud,
    local: local,
    cloudData: snap.cloudData,
    cloudLastSeen: snap.lastSeen,
    cloudUpdateTime: snap.updateTime,
  );
}

/// The debounced upload's timer. One at a time, and the newest wins.
Timer? _uploadTimer;

/// Piggybacks on the local save's debounce: a merge spree is one write.
void scheduleCloudUpload(
  Map<String, dynamic> state,
  String? uid, {
  required Map<String, dynamic>? Function(Map<String, dynamic>?) migrateCloud,
  required String fallbackClubName,
  required bool online,
  void Function()? onStale,
}) {
  if (uid == null || uid.isEmpty || !online) return;
  _uploadTimer?.cancel();
  _uploadTimer = Timer(cloudUploadDebounce, () {
    unawaited(
      uploadCloudSave(
        state,
        uid,
        migrateCloud: migrateCloud,
        fallbackClubName: fallbackClubName,
      ).then((res) {
        // Our change could not push because another device wrote newer. Surface
        // it now rather than waiting for the next resume.
        if (res.stale) onStale?.call();
      }).catchError((_) {
        // A failed background upload is not worth a toast: the next one will
        // carry the same save.
      }),
    );
  });
}

/// Immediate upload — on app background, where a debounce would be lost to the
/// OS suspending the process.
Future<void> flushCloudUpload(
  Map<String, dynamic> state,
  String? uid, {
  required Map<String, dynamic>? Function(Map<String, dynamic>?) migrateCloud,
  required String fallbackClubName,
  required bool online,
}) async {
  _uploadTimer?.cancel();
  _uploadTimer = null;
  if (uid == null || uid.isEmpty || !online) return;
  try {
    await uploadCloudSave(
      state,
      uid,
      migrateCloud: migrateCloud,
      fallbackClubName: fallbackClubName,
    );
  } catch (_) {
    // Backgrounding is not a moment to report an error into.
  }
}

/// Cancel a pending upload. For tests, and for a reset that is about to
/// force-write anyway.
void cancelPendingCloudUpload() {
  _uploadTimer?.cancel();
  _uploadTimer = null;
}
