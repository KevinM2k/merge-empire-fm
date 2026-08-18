/// Where a save is kept, as an interface.
///
/// The JS reaches straight for `localStorage`, which is always there and never
/// asynchronous. Neither is true here — the store is a plugin, and a plugin is
/// a platform channel — so the game state takes one of these instead and stays
/// testable without a widget binding.
///
/// The methods are deliberately SYNCHRONOUS. The debounced save runs on a timer
/// and the reset path writes three keys in a row expecting each to have landed;
/// making those await would spread `async` through every caller for a store
/// whose real implementation caches in memory anyway. The plugin-backed store
/// loads once at boot and writes through.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

abstract class SaveStore {
  const SaveStore();

  /// The raw bytes under [key], or null when there are none.
  String? read(String key);

  /// Write [value] under [key]. A store that is full or otherwise unwilling
  /// must fail SILENTLY: the game runs from memory, and an exception here would
  /// take down whatever was mid-save.
  void write(String key, String value);

  void remove(String key);
}

/// A store that keeps everything in memory. The tests' store, and the fallback
/// when a platform has no persistence at all — a game that cannot save is worth
/// more than a game that will not start.
class MemorySaveStore extends SaveStore {
  MemorySaveStore([Map<String, String>? initial]) : _values = {...?initial};

  final Map<String, String> _values;

  /// What is currently stored, for a test to assert against.
  Map<String, String> get values => Map.unmodifiable(_values);

  @override
  String? read(String key) => _values[key];

  @override
  void write(String key, String value) => _values[key] = value;

  @override
  void remove(String key) => _values.remove(key);
}
