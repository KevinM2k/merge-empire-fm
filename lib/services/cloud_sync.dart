/// Cloud save, actually wired up — the boot sync and the upload hook.
///
/// **`services/cloud_save_service.dart` had no caller.** Every piece of it was
/// ported and tested and none of it ran: the transport was waiting on a uid,
/// and there was no way to sign in. There is now, so this is the file that
/// connects the two — and it is the same class of gap `tool/unreached.sh`
/// exists to find.
///
/// **THE FALLBACK IS THE PLAYER'S OWN DEVICE, always.** Every failure here —
/// offline, an unreadable cloud, a document that will not migrate — leaves the
/// local save exactly as it was and plays on. The one thing this must never do
/// is lose a season to a network error.
///
/// **The conflict CARD is not here.** `evaluateCloudSave` answers
/// [CloudSaveAction.choose] and stops, because putting a decision on screen is
/// the UI layer's job and this file has no business drawing; [conflictPrompt]
/// is the seam the UI fills, and with nobody filling it a conflict keeps the
/// device's save rather than guessing at the cloud's.
library;

import 'dart:async';

import 'package:merge_empire_fc/engine/auth_policy.dart';
import 'package:merge_empire_fc/engine/cloud_save_policy.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/services/cloud_save_service.dart';
import 'package:merge_empire_fc/services/platform_seams.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/migration.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

/// Ask the player which save to keep. Returns what they chose.
///
/// **A null prompt means KEEP THE DEVICE'S**, which is the safe direction: the
/// save in front of the player is the one they have been playing, and replacing
/// it without asking is the only irreversible move available here.
typedef CloudConflictPrompt =
    Future<CloudSaveAction> Function(SaveSummary cloud, SaveSummary local);

/// Filled by the UI layer at boot. See `ui/popups/cloud_conflict_card.dart`.
CloudConflictPrompt? conflictPrompt;

/// Whether the device can reach anything. A seam so a test need not be online.
Future<bool> Function() cloudOnline = () async => network.isOnline;

/// Put both back. For tests.
void resetCloudSyncSeams() {
  conflictPrompt = null;
  cloudOnline = () async => network.isOnline;
}

String get _fallbackClub => t('common.your_club');

/// What one boot sync came to. For tests, and for the toast.
enum CloudSyncOutcome {
  /// Nothing to do, or nothing reachable.
  none,

  /// The device's save went up.
  uploaded,

  /// The cloud's came down and replaced it.
  restored,

  /// They diverged, the player was asked, and they kept this device.
  keptLocal,
}

/// Reconcile this device with the cloud, once, at boot or just after sign-in.
///
/// **The cloud is read BEFORE the leaderboard is seeded**, which is the JS's
/// own ordering and the reason it says so twice: on a delete-and-reinstall the
/// fresh local save has no progress, and a seed that ran first would write zero
/// career totals over a real all-time row.
Future<CloudSyncOutcome> runCloudBootSync(GameState game) async {
  final state = game.state;
  final uid = sessionUid(state);
  if (state == null || uid == null) return CloudSyncOutcome.none;
  if (!await cloudOnline()) return CloudSyncOutcome.none;

  final CloudSaveEvaluation evaluation;
  try {
    evaluation = await evaluateCloudSave(
      state,
      uid,
      migrateCloud: migrate,
      fallbackClubName: _fallbackClub,
      online: true,
    );
  } catch (_) {
    return CloudSyncOutcome.none;
  }

  switch (evaluation.action) {
    case CloudSaveAction.none:
      // The saves match. A cloud that has seen the player more recently bumps
      // the local stamp rather than replacing the whole save — which is what
      // stops two devices on one account booting each other in a loop.
      if (evaluation.bumpLastSeen > 0) {
        game.update((s) => s['lastSeen'] = evaluation.bumpLastSeen);
      }
      return CloudSyncOutcome.none;

    case CloudSaveAction.upload:
      return await _push(game, state, uid, force: false)
          ? CloudSyncOutcome.uploaded
          : CloudSyncOutcome.none;

    case CloudSaveAction.restore:
      return _pull(game, evaluation, uid);

    case CloudSaveAction.choose:
      final ask = conflictPrompt;
      // Nobody to ask: keep what the player is looking at.
      if (ask == null || evaluation.cloud == null || evaluation.local == null) {
        return CloudSyncOutcome.keptLocal;
      }
      final choice = await ask(evaluation.cloud!, evaluation.local!);
      if (choice == CloudSaveAction.restore) {
        return _pull(game, evaluation, uid);
      }
      // **Keeping the device FORCES the write.** The precondition token belongs
      // to the cloud copy the player just rejected, so an ordinary upload would
      // be refused as stale and the choice would silently not stick.
      emit('toast:info', t('cloud.conflict_kept_local'));
      await _push(game, state, uid, force: true);
      return CloudSyncOutcome.keptLocal;
  }
}

Future<bool> _push(
  GameState game,
  Map<String, dynamic> state,
  String uid, {
  required bool force,
}) async {
  try {
    final result = await uploadCloudSave(
      state,
      uid,
      force: force,
      migrateCloud: migrate,
      fallbackClubName: _fallbackClub,
    );
    return result.ok;
  } catch (_) {
    return false;
  }
}

CloudSyncOutcome _pull(
  GameState game,
  CloudSaveEvaluation evaluation,
  String uid,
) {
  // **A cloud document that will not migrate keeps the local save.** It is a
  // tampered or corrupt blob, and crashing a restore on one is how a player
  // loses everything to somebody else's bad write.
  if (!game.applyCloudSave(evaluation.cloudData, uid)) {
    return CloudSyncOutcome.none;
  }
  markCloudSynced(game.state!, evaluation.cloudUpdateTime);
  game.saveNow();
  game.notifyChanged();
  return CloudSyncOutcome.restored;
}

/// The hook `GameState` calls when a real event has changed the save.
///
/// **It is the DEBOUNCED one**, not the immediate write: `scheduleSave` already
/// waits, and a merge spree that wrote to Firestore per merge would be hundreds
/// of documents a minute. The two debounces stack deliberately.
Future<void> uploadSaveToCloud(Map<String, dynamic> save) async {
  final uid = sessionUid(save);
  if (uid == null) return;
  scheduleCloudUpload(
    save,
    uid,
    migrateCloud: migrate,
    fallbackClubName: _fallbackClub,
    online: network.isOnline,
    // A write refused because another device moved on is surfaced NOW rather
    // than left for the next resume — it is the one upload failure the player
    // can do something about.
    onStale: () => emit('cloud:conflict'),
  );
}

/// Push whatever is pending, immediately.
///
/// For the app going to the background, where a debounce is lost to the OS
/// suspending the process — which is exactly when a save most needs to have
/// landed.
Future<void> flushSaveToCloud(Map<String, dynamic>? save) async {
  final uid = sessionUid(save);
  if (save == null || uid == null) return;
  await flushCloudUpload(
    save,
    uid,
    migrateCloud: migrate,
    fallbackClubName: _fallbackClub,
    online: network.isOnline,
  );
}
