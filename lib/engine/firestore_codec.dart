/// Firestore's REST wire format, encoded and decoded — the pure half of
/// `../merge-empire-fc/src/services/firestoreRest.js`.
///
/// **The REST API is used instead of a Firestore SDK, and that is the JS's
/// decision rather than a shortcut.** Its own comment says why: the SDK's
/// WebChannel streams fail inside the native WebView, so every read and write
/// goes over plain HTTPS with hand-built typed values. The port keeps that
/// arrangement because the SAVE FORMAT on the server is the JS's — a document
/// written by the shipped app has to be readable by this one and vice versa, and
/// a different client library would have to agree with these encodings anyway.
///
/// **Split out of the transport on purpose.** Everything here is a pure
/// function over maps, so it runs under plain `dart test` and is where the
/// encoding bugs actually live; `services/firestore_rest.dart` is the thin part
/// that knows about sockets. `test/architecture_test.dart` enforces the split.
library;

/// Firestore's typed scalar, decoded.
///
/// **Only the scalars the game writes.** A `mapValue`, an `arrayValue` or a
/// reference comes back null rather than half-decoded — the JS does exactly the
/// same, and its own note explains it: nested objects are stored as JSON
/// STRINGS, so a real map arriving here means the document was written by
/// something that is not this game.
Object? decodeFirestoreValue(Object? value) {
  if (value is! Map) return null;
  if (value.containsKey('stringValue')) return value['stringValue'];
  // **Integers arrive as STRINGS**, which is the wire format rather than a
  // quirk of ours: Firestore's JSON mapping stringifies int64 so a 64-bit value
  // survives a JavaScript number. Parsed here so a caller never has to know.
  if (value.containsKey('integerValue')) {
    final raw = value['integerValue'];
    return raw is num ? raw.toInt() : int.tryParse('$raw');
  }
  if (value.containsKey('doubleValue')) {
    final raw = value['doubleValue'];
    return raw is num ? raw.toDouble() : double.tryParse('$raw');
  }
  if (value.containsKey('booleanValue')) return value['booleanValue'];
  if (value.containsKey('nullValue')) return null;
  if (value.containsKey('timestampValue')) return value['timestampValue'];
  return null;
}

/// A decoded document: the id off the end of its path, and its fields.
typedef FirestoreDoc = ({String id, Map<String, dynamic> data, String? updateTime});

/// Decode one document out of a REST response. Null when there is not one.
///
/// **`updatedAt` becomes an int, not a wrapper.** The JS hands back
/// `{ toMillis: () => ms }` because its callers were written against the SDK's
/// `Timestamp` and it was cheaper to fake the one method they used than to
/// change them. Dart has no such legacy: the field is milliseconds since epoch,
/// which is what every timestamp in this port already is.
FirestoreDoc? decodeFirestoreDocument(Object? doc) {
  if (doc is! Map) return null;
  final name = doc['name'];
  if (name is! String || name.isEmpty) return null;
  final id = name.split('/').last;

  final data = <String, dynamic>{};
  final fields = doc['fields'];
  if (fields is Map) {
    for (final entry in fields.entries) {
      final key = '${entry.key}';
      final raw = entry.value;
      if (key == 'updatedAt' && raw is Map && raw['timestampValue'] is String) {
        data['updatedAt'] =
            DateTime.tryParse(raw['timestampValue'] as String)
                ?.millisecondsSinceEpoch ??
            0;
        continue;
      }
      data[key] = decodeFirestoreValue(raw);
    }
  }
  final updateTime = doc['updateTime'];
  return (
    id: id,
    data: data,
    updateTime: updateTime is String ? updateTime : null,
  );
}

/// A Dart scalar, encoded.
///
/// **Scalars only, and anything else is stringified.** The JS's last branch is
/// `String(v)`, and keeping it means a map that slips through is stored as its
/// `toString` rather than throwing on a background write — the same choice the
/// shipped app makes, and the reason nested objects are written as JSON strings
/// at the call site instead.
Map<String, Object?> encodeFirestoreValue(Object? v) {
  if (v == null) return const {'nullValue': null};
  if (v is bool) return {'booleanValue': v};
  if (v is int) return {'integerValue': '$v'};
  if (v is double) {
    // The JS branches on `Number.isInteger`, and a Dart `double` holding a whole
    // number has to take the same branch or the two clients disagree about the
    // TYPE of a field they both write.
    return v == v.roundToDouble() && v.isFinite
        ? {'integerValue': '${v.toInt()}'}
        : {'doubleValue': v};
  }
  if (v is String) return {'stringValue': v};
  return {'stringValue': '$v'};
}

Map<String, Object?> _numberValue(num n) => n is int || n == n.roundToDouble()
    ? {'integerValue': '${n.toInt()}'}
    : {'doubleValue': n};

/// One entry in a `:commit` body.
///
/// [set] are plain fields; [increment] are numeric transforms the server
/// applies atomically; [serverTimestamps] are fields stamped with REQUEST_TIME
/// so the clock is the server's rather than a phone's.
///
/// [merge] adds the `updateMask` that makes this a patch — without it a write
/// REPLACES the document, which for a leaderboard entry means one field's
/// update wiping the rest of the row.
///
/// [mustNotExist] and [ifUpdateTime] are the two preconditions: the first
/// claims a document nobody else has taken, the second is optimistic
/// concurrency — write only if it still looks the way it did when we read it.
/// They are mutually exclusive and `mustNotExist` wins, which is the JS's own
/// `else if`.
Map<String, Object?> buildFirestoreWrite(
  String docName, {
  Map<String, Object?> set = const {},
  Map<String, num> increment = const {},
  List<String> serverTimestamps = const [],
  bool merge = true,
  bool mustNotExist = false,
  String? ifUpdateTime,
}) {
  final fields = <String, Object?>{
    for (final e in set.entries) e.key: encodeFirestoreValue(e.value),
  };
  final write = <String, Object?>{
    'update': {'name': docName, 'fields': fields},
  };
  if (merge) {
    write['updateMask'] = {'fieldPaths': fields.keys.toList()};
  }

  final transforms = <Map<String, Object?>>[
    for (final f in serverTimestamps)
      {'fieldPath': f, 'setToServerValue': 'REQUEST_TIME'},
    for (final e in increment.entries)
      {'fieldPath': e.key, 'increment': _numberValue(e.value)},
  ];
  if (transforms.isNotEmpty) write['updateTransforms'] = transforms;

  if (mustNotExist) {
    write['currentDocument'] = {'exists': false};
  } else if (ifUpdateTime != null) {
    write['currentDocument'] = {'updateTime': ifUpdateTime};
  }
  return write;
}

/// The first 200 characters of whatever the server said went wrong.
///
/// **`runQuery` streams its error back as a one-element ARRAY**, which is the
/// shape nothing else uses and the reason this is a function rather than a
/// field read — a query that fails on permissions returns `[{error: {...}}]`
/// with a 200, so the array branch is the one that matters most.
String firestoreErrorBody(Object? data, [String? rawText]) {
  String clip(Object? s) {
    final text = '$s';
    return text.length > 200 ? text.substring(0, 200) : text;
  }

  if (data is String) return clip(data);
  if (data is List && data.isNotEmpty) {
    final first = data.first;
    if (first is Map && first['error'] is Map) {
      final message = (first['error'] as Map)['message'];
      if (message != null) return clip(message);
    }
  }
  if (data is Map && data['error'] is Map) {
    final message = (data['error'] as Map)['message'];
    if (message != null) return clip(message);
  }
  if (rawText != null && rawText.isNotEmpty) return clip(rawText);
  return '';
}

/// How many writes go in one `:commit`. Firestore's own limit.
const int firestoreCommitBatch = 500;
