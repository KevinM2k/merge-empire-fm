import 'dart:convert';

/// Decodes and encodes the save JSON.
///
/// Cloud saves store the entire state as a JSON string, so a decode followed by
/// an encode must not lose a single field — including fields written by a newer
/// build than this one.
class SaveCodec {
  const SaveCodec._();

  /// Returns the save map, or null when [raw] is not a JSON object.
  static Map<String, dynamic>? decode(String raw) {
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static String encode(Map<String, dynamic> save) => jsonEncode(save);

  /// True when decoding then encoding [raw] preserves every value.
  static bool isLossless(String raw) {
    final decoded = decode(raw);
    if (decoded == null) return false;
    return _deepEquals(decoded, decode(encode(decoded)));
  }

  static bool _deepEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key)) return false;
        if (!_deepEquals(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}
