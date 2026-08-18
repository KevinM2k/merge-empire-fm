/// The save-slot policy: which stored copy to trust, in what order, and what to
/// do about the one that failed. Ported from the slot half of
/// `../merge-empire-fc/src/utils/storage.js` and the recovery ladder in
/// `loadState`.
///
/// `migrate()` — the bulk of that file — is already ported in `migration.dart`,
/// and the JSON round trip is `save_codec.dart`. What was left is this: three
/// keys, a mirror, a one-time stash, and the reset flag. It is load-bearing
/// rather than incidental — the mirror exists because a WebView process killed
/// mid-write leaves a truncated primary save, and without it boot falls back to
/// a fresh default and wipes the player's progress.
///
/// Nothing here touches storage. [recoverSave] takes the three raw strings and
/// hands back a PLAN — which save to use, and which side effects to apply — so
/// M2's game state wires it to real persistence and does not have to re-decide
/// any of it.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

/// The live save.
const String saveKeyPrimary = 'mergeEmpireFC_save';

/// A redundant copy written alongside every successful save.
///
/// If the primary key is later found truncated or corrupt — the WebView process
/// killed mid-write, which frequent crashes make far more likely — boot recovers
/// the previous good state from here instead of falling back to a fresh default.
const String saveKeyLastGood = 'mergeEmpireFC_save_lastgood';

/// A one-time stash of the exact bytes of a save that could not be loaded:
/// corrupt JSON, or a save written by a NEWER build than this one.
///
/// Preserved so a later build can recover it, and so nothing is ever silently
/// discarded.
const String saveKeyBackup = 'mergeEmpireFC_save_backup';

/// Survives the state wipe and the reload: it tells boot the local save was just
/// reset, so cloud sync must FORCE-OVERWRITE the cloud with the fresh local save
/// rather than restoring the now-stale cloud save back over it.
const String resetPendingKey = 'mergeEmpireFC_resetPending';

/// What kind of reset just happened.
enum ResetMode {
  /// New team: the career and the prestige carry forward.
  soft,

  /// Wipe everything, the player's global leaderboard rows included.
  full,
}

String resetModeName(ResetMode mode) => mode.name;

/// The stored reset flag, or null when there is not one.
///
/// Anything that is not one of the two known words reads as no flag at all: a
/// half-written value must not send a boot down the force-overwrite path.
ResetMode? parseResetPending(String? stored) => switch (stored) {
  'soft' => ResetMode.soft,
  'full' => ResetMode.full,
  _ => null,
};

/// What boot should do with the three stored copies.
typedef SaveRecovery = ({
  /// The save to run on, or null when none of the three was usable.
  Map<String, dynamic>? save,

  /// True when the save came from a fallback slot rather than the primary one.
  ///
  /// The caller writes it straight back to the primary slot so the recovery
  /// sticks and boot stops retrying it, and clears the one-time backup.
  bool recovered,

  /// True when nothing was usable, so the caller is about to run on a fresh
  /// default. The native mirror is what tells a genuinely new player apart from
  /// one whose storage was evicted.
  bool bootedOnDefault,

  /// The exact bytes to stash in the backup slot before anything overwrites
  /// them, or null when there is nothing to preserve.
  String? stashBackup,
});

/// Try each persisted source in order of trust.
///
/// The first that BOTH parses and migrates wins, so a corrupt or truncated
/// newest write can never silently wipe a good earlier one:
///
/// 1. the primary — the live save;
/// 2. the last-good mirror — which survives a truncated primary write;
/// 3. the backup — a one-time stash of a save this build could not load before,
///    which becomes recoverable once the build catches up to its version.
///
/// [parse] is the parse-and-migrate step, returning null for anything
/// structurally corrupt: a bad save must never brick boot with a blank screen.
/// A fallback slot holding the identical bytes to the primary is skipped rather
/// than re-parsed, since it can only fail the same way.
SaveRecovery recoverSave({
  required String? primary,
  required String? lastGood,
  required String? backup,
  required Map<String, dynamic>? Function(String raw) parse,
}) {
  Map<String, dynamic>? migrated = primary == null ? null : parse(primary);
  var recovered = false;

  if (migrated == null && lastGood != null && lastGood != primary) {
    final m = parse(lastGood);
    if (m != null) {
      migrated = m;
      recovered = true;
    }
  }

  // Before anything overwrites it, preserve the exact bytes of a primary save
  // that could not be loaded — which covers BOTH corrupt JSON and a save from a
  // newer build.
  final stash = migrated == null ? primary : null;

  if (migrated == null && backup != null && backup != primary) {
    final m = parse(backup);
    if (m != null) {
      migrated = m;
      recovered = true;
    }
  }

  return (
    save: migrated,
    recovered: recovered,
    bootedOnDefault: migrated == null,
    stashBackup: stash,
  );
}
