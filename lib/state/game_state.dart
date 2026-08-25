/// The live save, and everything that happens to it. Ported from
/// `../merge-empire-fc/src/state/gameState.js`.
///
/// One map, held for the life of the process, mutated in place. Mutating in
/// place is not laziness: every screen and every engine holds the same map, and
/// a cloud restore or a reset REPLACES ITS CONTENTS rather than the reference,
/// so nothing is left pointing at a save that is no longer the game.
///
/// The two resets are the load-bearing part of this file, and the JS comments
/// they are ported from read like a list of things that went wrong: a full reset
/// that took the player's gems, a soft reset that zeroed the lifetime counters
/// and let the next boot overwrite a real leaderboard standing with them, a
/// preserved gem ledger that re-armed every one-time faucet so resetting became
/// the farm. Every one of those is a paying player losing something they paid
/// for, which is why the preservation rules are spelled out here and pinned
/// against the JS rather than reasoned about again.
///
/// A handful of branches here guard against a save with no `leaderboard`, no
/// `boosts` or no `managerAvatar`. The migration creates all three, so none of
/// them is reachable in practice — they are the JS's guards, kept because the
/// alternative is a null dereference on the one save that proves the migration
/// missed a case.
///
/// Deliberately Flutter-free so it runs under plain `dart test`. The store, the
/// clock and the debounce are injected; Riverpod sits on top of this rather than
/// inside it.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/auto_tier_engine.dart';
import 'package:merge_empire_fc/engine/gem_engine.dart';
import 'package:merge_empire_fc/state/migration.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;
List<dynamic>? _list(Object? v) => v is List ? v : null;

/// How long a change waits before it is written.
///
/// Long enough that a merge spree is one write rather than thirty, short enough
/// that a player who kills the app straight after a match keeps it.
const int saveDebounceMs = 2000;

/// The durable native mirror is written at most this often, so the frequent
/// debounced idle saves do not churn a platform store. The forced flush on
/// app-hide is what guarantees it is fresh in the window where eviction happens.
const int nativeMirrorThrottleMs = 60 * 1000;

/// The IAP entitlements that survive BOTH resets.
///
/// - `vip_pass` — a time-based subscription, which keeps ticking.
/// - `starter_pack` — re-grants its coins and energy at the start of each run.
/// - `energy_director` — a permanent cap and regen upgrade.
/// - `style_vault` — every look pack, present and future.
const List<String> persistentIaps = [
  'vip_pass',
  'starter_pack',
  'energy_director',
  'style_vault',
];

/// Which reset this is.
enum ResetKind {
  /// New team: the career, the prestige and the achievements carry forward.
  soft,

  /// Everything goes, including the player's global leaderboard rows.
  full,
}

/// A fresh leaderboard identity.
///
/// A v4 UUID from the secure generator. The JS reaches for `crypto.randomUUID`
/// and falls back to a timestamp where there is none — but a timestamp is not an
/// identity: two devices first signing in within the same millisecond would
/// share a leaderboard row. There is no platform here without a secure
/// generator, so there is no reason to keep the weaker branch.
String newPlayerId() {
  final rng = math.Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
  String hex(int from, int to) => [
    for (var i = from; i < to; i++) bytes[i].toRadixString(16).padLeft(2, '0'),
  ].join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

/// The live game state.
class GameState {
  GameState({
    required SaveStore store,
    Future<String?> Function()? readNativeMirror,
    void Function(String json)? writeNativeMirror,
    Future<void> Function(Map<String, dynamic> save)? uploadCloudSave,
  }) : _store = store,
       _readNativeMirror = readNativeMirror,
       _writeNativeMirror = writeNativeMirror,
       _uploadCloudSave = uploadCloudSave;

  final SaveStore _store;
  final Future<String?> Function()? _readNativeMirror;
  final void Function(String json)? _writeNativeMirror;
  final Future<void> Function(Map<String, dynamic> save)? _uploadCloudSave;

  Map<String, dynamic>? _state;
  Timer? _saveTimer;

  /// Fires after every change that went through [update], and after a reset or
  /// a cloud restore replaced the contents.
  ///
  /// The save is ONE mutable map, so nothing downstream can diff it — a
  /// reactive layer has to be told. Synchronous, because a widget rebuilding a
  /// frame late after a coin lands is a visible stutter.
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );

  Stream<void> get changes => _changes.stream;

  /// A real event — not passive idle income — is waiting on a cloud upload.
  bool _cloudDirty = false;

  /// Set during a reset, so a debounced save from before it cannot land on top.
  bool _frozen = false;

  bool _bootedOnDefault = false;
  int _lastNativeMirrorAt = 0;

  /// The save. Null until [load] has run.
  Map<String, dynamic>? get state => _state;

  /// True when boot fell back to a fresh default because nothing loaded — a
  /// genuinely new player, OR one whose storage was evicted. The native mirror
  /// is what tells the two apart.
  bool get bootedOnDefault => _bootedOnDefault;

  /// True while saves are frozen.
  ///
  /// Set for the length of a reset — see [_finalizeReset], which clears it — and
  /// by [commitAndFreeze], which is the app going away and stays frozen because
  /// there is nothing after it.
  bool get frozen => _frozen;

  /// A save is waiting on the debounce.
  bool get savePending => _saveTimer != null;

  // ── Boot ──────────────────────────────────────────────────────────────────

  /// Load the save, trying each stored copy in order of trust.
  ///
  /// The ladder itself is [recoverSave]; this is the half that talks to the
  /// store and acts on the plan it hands back.
  Map<String, dynamic> load() {
    final primary = _store.read(saveKeyPrimary);
    final plan = recoverSave(
      primary: primary,
      lastGood: _store.read(saveKeyLastGood),
      backup: _store.read(saveKeyBackup),
      parse: _parseAndMigrate,
    );

    // Before anything overwrites them, preserve the exact bytes of a save that
    // could not be loaded — and only if nothing is stashed already, since the
    // stash is one-time and an unreadable save is worth more than a second copy
    // of one.
    final stash = plan.stashBackup;
    if (stash != null && _store.read(saveKeyBackup) == null) {
      _store.write(saveKeyBackup, stash);
    }

    _state = plan.save ?? createDefaultState();
    // Whichever way the save arrived — loaded, recovered or freshly made — it is
    // not waiting on a tutorial this app cannot run. See `settleTutorial`.
    settleTutorial(_state);
    _bootedOnDefault = plan.bootedOnDefault;

    // Rebuilt from a fallback: write it straight back to the primary slot so the
    // recovery sticks and boot stops retrying it, and drop the backup it came
    // from.
    if (plan.recovered) {
      _writeSave();
      _store.remove(saveKeyBackup);
    }
    return _state!;
  }

  /// Parse raw bytes and migrate them; null when either fails.
  ///
  /// A structurally corrupt save must never brick boot with a blank screen.
  Map<String, dynamic>? _parseAndMigrate(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return migrate(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Last-resort recovery from the durable native store, which survives an
  /// eviction that wipes the ordinary one.
  ///
  /// Only acts when [load] found nothing usable, so a genuinely new player keeps
  /// their fresh default while a player whose storage was cleared gets their
  /// progress back in place.
  Future<bool> recoverFromNativeMirror({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final read = _readNativeMirror;
    if (!_bootedOnDefault || _state == null || read == null) return false;
    String? raw;
    try {
      // A hard timeout: the native bridge must never trap boot on the splash.
      //
      // A race rather than `Future.timeout`, and deliberately: `timeout` takes
      // its `onTimeout` against the future's RUNTIME type, so a reader declared
      // to return a non-nullable `Future<String>` — which any sensible bridge
      // is — makes `() => null` a type error thrown on the spot. The recovery
      // then fails instantly and silently, on exactly the boot it exists for.
      raw = await Future.any<String?>([
        read(),
        Future<String?>.delayed(timeout, () => null),
      ]);
    } catch (_) {
      return false;
    }
    if (raw == null) return false;
    final migrated = _parseAndMigrate(raw);
    if (migrated == null) return false;

    _replaceContents(migrated);
    _writeSave();
    _bootedOnDefault = false;
    notifyChanged();
    return true;
  }

  // ── Saving ────────────────────────────────────────────────────────────────

  /// Stamp the save and write it now.
  ///
  /// Drops any debounced write still armed: it would write the same bytes a
  /// moment later, and after a pause that is a write racing the process going
  /// away. A pending CLOUD sync is not lost with it — `_cloudDirty` is sticky,
  /// so the next real event uploads.
  void saveNow() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (_state == null || _frozen) return;
    _state!['lastSeen'] = now();
    _writeSave();
  }

  /// Persist after a short debounce.
  ///
  /// [syncCloud] false is for passive, high-frequency changes — idle income,
  /// energy regeneration — so the cloud only moves on real events. Passive
  /// income recomputes from `lastSeen` on load, so it need not churn the cloud.
  ///
  /// The flag is STICKY: once a real event has asked for a sync, a later passive
  /// save resetting the shared timer must not cancel it.
  void scheduleSave({bool syncCloud = true}) {
    if (syncCloud) _cloudDirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: saveDebounceMs), () {
      _saveTimer = null;
      saveNow();
      _mirrorNative();
      final upload = _uploadCloudSave;
      final signedIn = _map(_state?['leaderboard'])?['authUid'] != null;
      if (_cloudDirty && signedIn && upload != null) {
        _cloudDirty = false;
        // Fire and forget: a failed upload must never surface as an unhandled
        // rejection, and the next real event will try again.
        upload(_state!).catchError((_) {});
      }
    });
  }

  /// Run [mutator] against the save and schedule a write.
  ///
  /// Every change goes through here, which is what makes "did anything need
  /// saving" a question nobody has to remember to ask.
  T update<T>(
    T Function(Map<String, dynamic> state) mutator, {
    bool syncCloud = true,
  }) {
    final result = mutator(_state!);
    scheduleSave(syncCloud: syncCloud);
    notifyChanged();
    return result;
  }

  /// Announce that the save moved.
  ///
  /// [update] does this for you. It is public for the paths that mutate the map
  /// directly and still have to wake the UI — the game loop credits idle income
  /// straight onto the resources branch every second, and going through
  /// [update] there would schedule a save on every tick.
  void notifyChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Drop the change stream. Only a test that builds several of these needs it;
  /// the app's one lives as long as the process.
  ///
  /// A debounced write still armed is FLUSHED rather than dropped: the timer
  /// would otherwise outlive the object that armed it and fire into a disposed
  /// state, and the bytes it holds are a real change somebody made.
  void dispose() {
    if (_saveTimer != null) saveNow();
    _changes.close();
  }

  /// Freeze pending saves, stamp the save, and flush — so a reload sees a clean
  /// state rather than a stale one with offline earnings still owed.
  void commitAndFreeze() {
    _frozen = true;
    _saveTimer?.cancel();
    _saveTimer = null;
    if (_state == null) return;
    _state!['lastSeen'] = now();
    _writeSave();
    _mirrorNative(force: true);
  }

  /// Force-write the durable native mirror. Call on pause or app-hide.
  void flushNativeMirror() => _mirrorNative(force: true);

  void _writeSave() {
    final state = _state;
    if (state == null) return;
    final String json;
    try {
      json = jsonEncode(state);
    } catch (_) {
      // Non-serialisable state should be impossible, and if it happens the save
      // on disk is worth more than whatever this would have written over it.
      return;
    }
    _store.write(saveKeyPrimary, json);
    // The mirror is a separate write so a truncated primary cannot take it down
    // too. It is the whole reason a killed process does not cost a save.
    _store.write(saveKeyLastGood, json);
  }

  void _mirrorNative({bool force = false}) {
    final write = _writeNativeMirror;
    final state = _state;
    if (write == null || state == null) return;
    final at = now();
    if (!force && at - _lastNativeMirrorAt < nativeMirrorThrottleMs) return;
    _lastNativeMirrorAt = at;
    try {
      write(jsonEncode(state));
    } catch (_) {
      // Best-effort, and off-platform it does nothing at all.
    }
  }

  /// Swap the save's CONTENTS, keeping the map itself.
  ///
  /// Every screen and engine holds this map. Replacing the reference would leave
  /// half the app looking at a save that is no longer the game.
  void _replaceContents(Map<String, dynamic> next) {
    final state = _state!;
    state.clear();
    state.addAll(next);
  }

  // ── The cloud ─────────────────────────────────────────────────────────────

  /// Replace the in-memory save from a cloud snapshot.
  ///
  /// Returns false and keeps the local save when the snapshot will not migrate:
  /// a tampered or corrupt cloud document must not crash the restore.
  bool applyCloudSave(Map<String, dynamic>? cloudData, String? authUid) {
    if (_state == null) return false;
    Map<String, dynamic>? migrated;
    try {
      migrated = migrate(cloudData);
    } catch (_) {
      return false;
    }
    if (migrated == null) return false;

    final playerId =
        _map(_state!['leaderboard'])?['playerId'] ??
        _map(migrated['leaderboard'])?['playerId'];

    _replaceContents(migrated);

    var leaderboard = _map(_state!['leaderboard']);
    if (leaderboard == null) {
      leaderboard = <String, dynamic>{
        'playerId': null,
        'authUid': null,
        'lastSubmittedAt': 0,
        'careerSeeded': false,
        'anonymousLinked': false,
      };
      _state!['leaderboard'] = leaderboard;
    }
    leaderboard['authUid'] = authUid;
    // The restored save's standing belongs to whatever it was before; both flags
    // re-run against this device's identity.
    leaderboard['careerSeeded'] = false;
    leaderboard['anonymousLinked'] = false;
    leaderboard['playerId'] =
        playerId ?? leaderboard['playerId'] ?? newPlayerId();

    _writeSave();
    // Keep the durable mirror in step with the restore, or an eviction recovery
    // could resurrect the save the cloud just replaced.
    _mirrorNative(force: true);
    notifyChanged();
    return true;
  }

  // ── Resets ────────────────────────────────────────────────────────────────

  /// New team: wipe the run, keep the career.
  Map<String, dynamic> resetState({bool replayTutorial = false}) {
    final prev = _state;
    final carry = _carryStats(prev);
    final settings = _map(prev?['settings']);
    final preservedSettings = settings == null
        ? null
        : <String, dynamic>{...settings};
    final achievements = [
      for (final a
          in _list(_map(prev?['progression'])?['achievements']) ?? const [])
        if (_map(a) case final entry?) <String, dynamic>{...entry},
    ];
    final careerStats = _map(prev?['careerStats']);
    final discovered = [
      ...?_list(_map(prev?['progression'])?['discoveredPlayers']),
    ];
    final foundCounts = _map(_map(prev?['progression'])?['playerFoundCounts']);
    final maxCoins = _num(_map(prev?['stats'])?['maxCoinsReached']) ?? 0;
    final permanent = _preservePermanent(prev);
    final prestige = _map(prev?['prestige']);
    // Manager cosmetics survive a soft reset the way achievements and prestige
    // do. Taking a new job does not change your face, and a look earned by
    // lifting a cup must never be revoked — the trophies ARE wiped here, so cup
    // unlocks would otherwise vanish with the cabinet.
    final club = _map(prev?['club']);
    final preservedLooks = club == null
        ? null
        : <String, dynamic>{
            'lookPacks': persistentLookPacks(prev),
            'lookItems': persistentLookItems(prev),
            'cupLooksWon': [...?_list(club['cupLooksWon'])],
            'managerAvatar': _map(club['managerAvatar']) == null
                ? null
                : <String, dynamic>{..._map(club['managerAvatar'])!},
          };
    final entitlements = _preserveEntitlements(prev);
    final leaderboard = _map(prev?['leaderboard']);
    final preservedLeaderboard = leaderboard == null
        ? null
        : <String, dynamic>{
            'playerId': leaderboard['playerId'],
            'authUid': leaderboard['authUid'],
            'accountName': leaderboard['accountName'],
            'lastSubmittedAt': leaderboard['lastSubmittedAt'] ?? 0,
            'careerSeeded': leaderboard['careerSeeded'] ?? false,
            'anonymousLinked': leaderboard['anonymousLinked'] ?? false,
            'rankingsVisible': leaderboard['rankingsVisible'] != false,
            'optOutApplied': leaderboard['optOutApplied'] == true,
            'metaClubName': leaderboard['metaClubName'],
            // Not preserving this let a post-reset boot re-run the one-time
            // all-time repair while the career counters below were still zeroed,
            // overwriting a real all-time total with near-zero.
            'allTimeRepairDone': leaderboard['allTimeRepairDone'] == true,
          };
    // The lifetime leaderboard counters, which must survive a soft reset the way
    // they survive prestige. A soft reset replaces the whole progression branch
    // with a fresh default, which zeroed them — and the next signed-in boot then
    // reseeded the all-time row from the zeros, wiping a global standing.
    final progression = _map(prev?['progression']);
    final preservedCareer = progression == null
        ? null
        : <String, dynamic>{
            'careerWins': progression['careerWins'] ?? 0,
            'careerDraws': progression['careerDraws'] ?? 0,
            'careerGoalsFor': progression['careerGoalsFor'] ?? 0,
            'careerBackfillDone': progression['careerBackfillDone'] ?? true,
          };

    _beginFreshState();
    final state = _state!;

    if (preservedSettings != null) state['settings'] = preservedSettings;
    // ...except the auto-sell rules, which are a judgement about a squad that no
    // longer exists. A new team starts in Sunday League, where every draw is the
    // bronze a late-game rule was set to bin.
    clearTierActions(state);

    final prog = _map(state['progression'])!;
    prog['achievements'] = achievements;
    prog['discoveredPlayers'] = discovered;
    prog['playerFoundCounts'] = foundCounts == null
        ? <String, dynamic>{}
        : <String, dynamic>{...foundCounts};
    if (preservedCareer != null) prog.addAll(preservedCareer);
    _map(state['stats'])!['maxCoinsReached'] = maxCoins;
    _restorePermanent(permanent);
    if (carry != null) _map(state['stats'])!.addAll(carry);

    _restoreEntitlements(entitlements);

    // Prestige is earned by completing the game, so it crosses every reset.
    if (prestige != null) {
      state['prestige'] = <String, dynamic>{...prestige};
    }

    if (preservedLooks != null) {
      state['club'] = <String, dynamic>{
        ...?_map(state['club']),
        ...preservedLooks,
      };
      // Against the FRESH state: the Fan Zone is gone and the packs are
      // re-locked, so the manager drops back to the free defaults on any axis he
      // can no longer justify. Cup looks are kept above and so survive this.
      final avatar = _map(state['club'])!['managerAvatar'];
      if (avatar != null) {
        _map(state['club'])!['managerAvatar'] = sanitizeAvatar(state, avatar);
      }
    }

    // Career totals ACCUMULATE across every reset rather than being replaced.
    if (careerStats != null) {
      final fresh = _map(state['careerStats']) ?? <String, dynamic>{};
      state['careerStats'] = <String, dynamic>{
        ...fresh,
        for (final key in const [
          'leagueWins',
          'cupWins',
          'matchesWon',
          'totalMerges',
          'hardModeWins',
        ])
          key: (_num(fresh[key]) ?? 0) + (_num(careerStats[key]) ?? 0),
      };
    }

    if (preservedLeaderboard != null) {
      state['leaderboard'] = <String, dynamic>{
        ...?_map(state['leaderboard']),
        ...preservedLeaderboard,
      };
    }

    // Skipping the tutorial is the default — a repeat player knows the ropes —
    // and the reset dialog is where they ask to see it again.
    _finalizeReset(ResetKind.soft, replayTutorial);
    return state;
  }

  /// Give it all up: wipe the save, keep the receipts.
  Map<String, dynamic> fullResetState({bool replayTutorial = true}) {
    final prev = _state;
    // The signed-in identity stays so the cloud overwrite on the next boot
    // targets the right document. The progress flags reset, so the leaderboard
    // re-seeds from the fresh save.
    final leaderboard = _map(prev?['leaderboard']);
    final preservedLeaderboard = leaderboard == null
        ? null
        : <String, dynamic>{
            'playerId': leaderboard['playerId'],
            'authUid': leaderboard['authUid'],
            'authProvider': leaderboard['authProvider'],
            'accountName': leaderboard['accountName'],
            'cloudSyncToken': leaderboard['cloudSyncToken'],
            'cloudSyncMs': leaderboard['cloudSyncMs'] ?? 0,
            'rankingsVisible': leaderboard['rankingsVisible'] != false,
            'optOutApplied': leaderboard['optOutApplied'] == true,
          };
    final entitlements = _preserveEntitlements(prev);
    // A full reset wipes the SAVE, not the RECEIPTS. Anything bought with real
    // money survives, and so does anything bought with gems — gems are real
    // money one step removed, so revoking what they bought revokes a purchase.
    //
    // This path used to keep none of it: a full reset took the gem balance,
    // every look pack gems had paid for, and the whole gem ledger — which
    // re-armed every one-time faucet on the way out, making a full reset a gem
    // farm as well as a gem confiscation.
    final permanent = _preservePermanent(prev);
    // Look packs only. Cup looks are NOT here: they are won by lifting a trophy,
    // and a full reset takes the cabinet with everything else.
    final club = _map(prev?['club']);
    final preservedLooks = club == null
        ? null
        : <String, dynamic>{
            'lookPacks': persistentLookPacks(prev),
            'lookItems': persistentLookItems(prev),
          };

    _beginFreshState();
    final state = _state!;
    _restoreEntitlements(entitlements);
    _restorePermanent(permanent);

    if (preservedLooks != null) {
      state['club'] = <String, dynamic>{
        ...?_map(state['club']),
        ...preservedLooks,
      };
      final avatar = _map(state['club'])!['managerAvatar'];
      if (avatar != null) {
        _map(state['club'])!['managerAvatar'] = sanitizeAvatar(state, avatar);
      }
    }

    if (preservedLeaderboard != null) {
      state['leaderboard'] = <String, dynamic>{
        ...?_map(state['leaderboard']),
        ...preservedLeaderboard,
      };
    }

    _finalizeReset(ResetKind.full, replayTutorial);
    return state;
  }

  /// The lifetime and reset-related stats that cross a reset.
  ///
  /// Read BEFORE the wipe: the incoming save is the one about to be discarded,
  /// and the result is merged into the fresh state's stats. It is also the
  /// unlock trigger for the reset achievements.
  Map<String, dynamic>? _carryStats(Map<String, dynamic>? prev) {
    if (prev == null) return null;
    final prevStats = _map(prev['stats']) ?? const {};

    final hadLegendary = (_list(_map(prev['grid'])?['cells']) ?? const []).any((
      c,
    ) {
      final def = getPlayerDef(_map(c)?['definitionId'] as String?);
      return def != null && def.tier >= 7;
    });
    final seasons = _num(_map(prev['progression'])?['seasonCount']) ?? 1;
    final atTop =
        _map(prev['progression'])?['currentDivision'] == 'champions_cup';
    final prestigeLevel = _num(_map(prev['prestige'])?['level']) ?? 0;

    return <String, dynamic>{
      'resetCount': (_num(prevStats['resetCount']) ?? 0) + 1,
      'everHadLegendaryAtReset':
          prevStats['everHadLegendaryAtReset'] == true || hadLegendary,
      'maxSeasonsAtReset': math.max(
        _num(prevStats['maxSeasonsAtReset']) ?? 0,
        seasons,
      ),
      'everResetFromTopDivision':
          prevStats['everResetFromTopDivision'] == true || atTop,
      'maxPrestigeLevelAtReset': math.max(
        _num(prevStats['maxPrestigeLevelAtReset']) ?? 0,
        prestigeLevel,
      ),
    };
  }

  /// The paid entitlements that must survive a reset.
  ({Map<String, dynamic>? shop, bool hadStarterPack, bool hadEnergyDirector})
  _preserveEntitlements(Map<String, dynamic>? prev) {
    final shop = _map(prev?['shop']);
    final purchased = _list(shop?['purchasedIds']);
    return (
      shop: shop == null
          ? null
          : <String, dynamic>{
              'purchasedIds': [
                for (final id in purchased ?? const [])
                  if (persistentIaps.contains(id)) id,
              ],
              'vipExpiresAt': shop['vipExpiresAt'] ?? 0,
              'totalSpent': shop['totalSpent'] ?? 0,
              'energyUpgraded': shop['energyUpgraded'] ?? false,
            },
      hadStarterPack: purchased?.contains('starter_pack') ?? false,
      hadEnergyDirector: shop?['energyUpgraded'] == true,
    );
  }

  /// The things NO reset may take away, soft or full.
  ///
  /// Gems are hard currency — bought with real money, or earned once from a
  /// faucet that never re-arms. Wiping them revokes something that was paid for,
  /// and wiping the ledger with them is worse than it looks: every one-time
  /// faucet re-arms, so the reset itself becomes the farm. The login streak is
  /// here for the same reason, since day 7 is the only recurring gem faucet in
  /// the game and losing your place in the cycle is losing gems.
  ///
  /// Shared by both resets deliberately: the two drifted apart once, and the
  /// difference was invisible until a player lost a gem balance.
  ({
    int gems,
    List<dynamic> gemUnlocks,
    Map<String, dynamic>? gemGrants,
    Map<String, dynamic>? dailyReward,
  })
  _preservePermanent(Map<String, dynamic>? prev) {
    final grants = _map(prev?['gemGrants']);
    final daily = _map(prev?['dailyReward']);
    return (
      gems: getGems(prev),
      gemUnlocks: [...?_list(prev?['gemUnlocks'])],
      gemGrants: grants == null
          ? null
          : <String, dynamic>{
              'tutorialGranted': grants['tutorialGranted'] == true,
              // Must ride along, or a reset drops the flag and the next boot
              // re-runs the one-time retro-pay — which, on a save whose gems
              // have since been spent, pays it a second time.
              'tutorialBackfilled': grants['tutorialBackfilled'] == true,
              'divisionFirsts': [...?_list(grants['divisionFirsts'])],
              'cupFirsts': [...?_list(grants['cupFirsts'])],
              'firstPrestigeDone': grants['firstPrestigeDone'] == true,
              // The one per-run flag, dropped so the new run can win its own
              // league title.
              'chlTitleThisRun': false,
            },
      dailyReward: daily == null ? null : <String, dynamic>{...daily},
    );
  }

  void _restorePermanent(
    ({
      int gems,
      List<dynamic> gemUnlocks,
      Map<String, dynamic>? gemGrants,
      Map<String, dynamic>? dailyReward,
    })
    permanent,
  ) {
    final state = _state!;
    _map(state['resources'])!['gems'] = permanent.gems;
    state['gemUnlocks'] = permanent.gemUnlocks;
    if (permanent.gemGrants != null) state['gemGrants'] = permanent.gemGrants;
    if (permanent.dailyReward != null) {
      state['dailyReward'] = permanent.dailyReward;
    }
  }

  /// Freeze saves and swap in a fresh default — the shared reset preamble.
  void _beginFreshState() {
    _frozen = true;
    _saveTimer?.cancel();
    _saveTimer = null;
    _store.remove(saveKeyPrimary);
    // The mirror goes too, so a recovery cannot undo the reset by pulling the
    // pre-reset state back out of it.
    _store.remove(saveKeyLastGood);
    _state = createDefaultState();
  }

  void _restoreEntitlements(
    ({Map<String, dynamic>? shop, bool hadStarterPack, bool hadEnergyDirector})
    entitlements,
  ) {
    final state = _state!;
    final shop = entitlements.shop;
    if (shop != null) {
      // Merged INTO the default shop, so fields added since the previous save
      // still get their defaults.
      state['shop'] = <String, dynamic>{...?_map(state['shop']), ...shop};
      // Re-hydrate the derived VIP flag so the income multiplier is live
      // immediately rather than waiting for the next tick.
      if ((_num(shop['vipExpiresAt']) ?? 0) > now()) {
        var boosts = _map(state['boosts']);
        if (boosts == null) {
          boosts = <String, dynamic>{};
          state['boosts'] = boosts;
        }
        boosts['vipActive'] = true;
        boosts['vipExpiresAt'] = shop['vipExpiresAt'];
      }
    }
    // The starter pack re-grants on every new team, so a returning player gets
    // the head start they paid for each run.
    final energy = _map(state['energy'])!;
    if (entitlements.hadStarterPack) {
      final resources = _map(state['resources'])!;
      resources['fanCoins'] = (_num(resources['fanCoins']) ?? 0) + 10000;
      energy['current'] = math.min((_num(energy['current']) ?? 0) + 10, 20);
    }
    if (entitlements.hadEnergyDirector) {
      energy['current'] = math.min((_num(energy['current']) ?? 0) + 50, 65);
    }
  }

  /// The shared reset epilogue: the tutorial, the offline-earnings guard, the
  /// cloud-overwrite flag, and the flush.
  /// Run over a save that was just MADE — a reset — before it is written.
  /// The runner hangs its boot-time sweep here; see `GameRunner.prepareSave`.
  void Function(Map<String, dynamic> state)? onFreshState;

  void _finalizeReset(ResetKind kind, bool replayTutorial) {
    final state = _state!;
    state['tutorial'] = <String, dynamic>{'done': !replayTutorial, 'step': 0};
    onFreshState?.call(state);
    // Prevents offline earnings on the reload that follows.
    state['lastSeen'] = now();
    // The cloud still holds the OLD save. Without this flag the next signed-in
    // boot sees a no-progress local against a has-progress cloud and RESTORES
    // the old save straight back over the reset.
    _store.write(
      resetPendingKey,
      resetModeName(kind == ResetKind.soft ? ResetMode.soft : ResetMode.full),
    );
    _writeSave();
    // Overwrite the durable mirror with the post-reset state, so a later
    // eviction recovery cannot resurrect the pre-reset game.
    _mirrorNative(force: true);
    // **AND UNFREEZE.** The freeze exists for one reason — a save scheduled
    // BEFORE the reset must not land on top of it — and by here that danger has
    // passed: `_beginFreshState` cancelled the timer, and the fresh state is
    // written to both the slot and the mirror. The JS could leave it frozen
    // because a reset there is followed by `location.reload()`; this app has no
    // reload, so staying frozen means the game silently never saves again.
    _frozen = false;
    notifyChanged();
  }

  /// Read the reset flag without clearing it.
  ///
  /// A peek rather than a consume, so every concurrent boot-sync path sees it
  /// and all of them force-upload. Only [clearResetPending] clears it, and only
  /// once the cloud has actually been overwritten.
  ResetMode? peekResetPending() =>
      parseResetPending(_store.read(resetPendingKey));

  void clearResetPending() => _store.remove(resetPendingKey);
}
