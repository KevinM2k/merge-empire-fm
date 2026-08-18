/// The save, on the device. The real implementation of [SaveStore].
///
/// The JS wrote to `localStorage`: always present, always synchronous. Neither
/// holds here — the store is a plugin behind a platform channel — but the
/// [SaveStore] contract is synchronous on purpose, because the debounced save
/// fires from a timer and the reset path writes three keys expecting each to
/// have landed.
///
/// So the whole thing is read into memory ONCE at boot and written through
/// afterwards. Reads answer from the cache; writes update the cache and fire the
/// plugin call off without waiting. A write that fails is swallowed: the game
/// runs from memory, and throwing here would take down whatever was mid-save.
library;

import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The keys this store keeps in memory. Everything the save layer writes, and
/// nothing else — the preferences file also holds whatever the platform put
/// there, and hoovering all of it up would grow with every plugin added.
const List<String> saveStoreKeys = [
  saveKeyPrimary,
  saveKeyLastGood,
  saveKeyBackup,
  resetPendingKey,
];

class PrefsSaveStore extends SaveStore {
  PrefsSaveStore._(this._prefs, this._cache);

  /// Open the store and read every save key into memory.
  ///
  /// A platform with no preferences plugin at all — a unit test, a headless
  /// host — gets a [MemorySaveStore] instead of an exception. A game that
  /// cannot save is worth more than a game that will not start.
  static Future<SaveStore> open() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return PrefsSaveStore._(prefs, {
        for (final key in saveStoreKeys)
          if (prefs.getString(key) case final String value) key: value,
      });
    } catch (_) {
      return MemorySaveStore();
    }
  }

  final SharedPreferences _prefs;
  final Map<String, String> _cache;

  @override
  String? read(String key) => _cache[key];

  @override
  void write(String key, String value) {
    _cache[key] = value;
    // Unawaited on purpose: see the note at the top.
    _prefs.setString(key, value).catchError((_) => false);
  }

  @override
  void remove(String key) {
    _cache.remove(key);
    _prefs.remove(key).catchError((_) => false);
  }
}
