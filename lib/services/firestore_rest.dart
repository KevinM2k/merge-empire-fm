/// Firestore over plain HTTPS, ported from
/// `../merge-empire-fc/src/services/firestoreRest.js` and
/// `firestoreRestAuth.js`.
///
/// **Why REST and not a Firestore SDK** is the JS's own note: the SDK's
/// WebChannel streams fail inside the native WebView, so every read and write is
/// a hand-built request. The port keeps it because the documents on the server
/// are the shipped app's — a save or a leaderboard row written by one client has
/// to be readable by the other — and because it needs no plugin, which is what
/// lets this whole file exist before any native work is done.
///
/// **The encoding lives in `engine/firestore_codec.dart`**, which is pure and
/// tested. What is here is sockets, URLs and the retry-free error handling: the
/// half that cannot be tested without a network, kept as thin as it can be for
/// exactly that reason.
///
/// **Two seams, both variables.** [firestoreSend] is the transport, so a test
/// drives every path in this file without opening a socket; [firestoreAuthToken]
/// is the bearer token, which comes from the Firebase auth session and is
/// therefore null until `authService` is ported. **A null token is not an
/// error** — the JS's own comment says leaderboard reads are public (`rules:
/// read if true`), so an unauthenticated read is the normal case rather than a
/// failure.
library;

import 'dart:convert';
import 'dart:io';

import 'package:merge_empire_fc/data/firebase_config.dart';
import 'package:merge_empire_fc/engine/firestore_codec.dart';

/// Ten seconds, connect and read alike. The JS's `REST_TIMEOUT_MS`.
const Duration firestoreTimeout = Duration(seconds: 10);

/// The project the documents live in, from `data/firebase_config.dart`.
const String firestoreProjectId = firebaseProjectId;

/// **THE KEY FOR THE PLATFORM THIS IS RUNNING ON.**
///
/// Firebase issues one per registered app and the JS picks between three,
/// because the iOS and Android keys are restricted to their bundle id and the
/// browser key is restricted by referrer — so a device sending the browser key
/// is a 403. This used to be the web key with a note saying the platform pair
/// would arrive with the Firebase port; it has.
///
/// A variable rather than a constant so a test can pin it, and resolved once:
/// `Platform` is a syscall and this is read on every request.
final String firestoreApiKey = firebaseConfigFor(_thisApp).apiKey;

FirebaseApp get _thisApp {
  if (Platform.isIOS) return FirebaseApp.ios;
  if (Platform.isAndroid) return FirebaseApp.android;
  // Desktop and the test host are neither, and the browser key is the one that
  // is not bundle-restricted — which is exactly the fallback the JS takes.
  return FirebaseApp.web;
}

/// Sent so an app-restricted key is accepted. The Firebase SDKs add these
/// automatically; a raw REST call has to, or the key comes back 403.
const String firestoreBundleId = 'com.mergeempirefc.app';

/// One HTTP response, reduced to what any caller here needs.
typedef FirestoreResponse = ({int status, Object? data, String? rawText});

/// The transport seam. Replaced wholesale in tests.
typedef FirestoreSend =
    Future<FirestoreResponse> Function(
      String method,
      Uri url,
      Map<String, String> headers,
      Object? body,
    );

/// The bearer token seam.
///
/// Null until the auth service exists — and null is fine: public reads work
/// without one, and a write that needs it fails with a 403 the caller already
/// handles.
Future<String?> Function() firestoreAuthToken = _noToken;

Future<String?> _noToken() async => null;

/// Put both seams back. For tests.
void resetFirestoreSeams() {
  firestoreAuthToken = _noToken;
  firestoreSend = _realSend;
}

FirestoreSend firestoreSend = _realSend;

Future<FirestoreResponse> _realSend(
  String method,
  Uri url,
  Map<String, String> headers,
  Object? body,
) async {
  final client = HttpClient()..connectionTimeout = firestoreTimeout;
  try {
    final request = await client.openUrl(method, url).timeout(firestoreTimeout);
    headers.forEach(request.headers.set);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close().timeout(firestoreTimeout);
    final rawText = await response
        .transform(utf8.decoder)
        .join()
        .timeout(firestoreTimeout);
    Object? data;
    try {
      data = rawText.isEmpty ? null : jsonDecode(rawText);
    } catch (_) {
      // Not JSON. The JS keeps the text as the body for exactly this case, and
      // it is usually a proxy or a captive portal rather than Firestore.
      data = rawText;
    }
    return (status: response.statusCode, data: data, rawText: rawText);
  } finally {
    client.close(force: true);
  }
}

String _docName(String path) =>
    'projects/$firestoreProjectId/databases/(default)/documents/$path';

Future<Map<String, String>> _headers() async {
  final headers = <String, String>{
    // Platform attestation. Both are sent rather than one per platform: the
    // key in use is the web key, which cares about neither, and sending the
    // pair means the native keys work the moment one is swapped in.
    'X-Ios-Bundle-Identifier': firestoreBundleId,
    'X-Android-Package': firestoreBundleId,
  };
  String? token;
  try {
    token = await firestoreAuthToken();
  } catch (_) {
    // A token that will not come is the same as not having one.
    token = null;
  }
  if (token != null && token.isNotEmpty) {
    headers['Authorization'] = 'Bearer $token';
  }
  return headers;
}

bool _ok(int status) => status >= 200 && status < 300;

/// Everything in this file throws this and nothing else, so a caller has one
/// `catch` rather than one per transport failure.
class FirestoreRestException implements Exception {
  FirestoreRestException(this.operation, this.status, this.detail);

  final String operation;
  final int status;
  final String detail;

  @override
  String toString() =>
      'Firestore REST $operation $status${detail.isEmpty ? '' : ': $detail'}';
}

Uri _uri(String path, [Map<String, String> extra = const {}]) => Uri.https(
  'firestore.googleapis.com',
  '/v1/$path',
  <String, String>{'key': firestoreApiKey, ...extra},
);

/// GET one document. **Null for a 404** — a missing document is an answer, not
/// a failure, and every caller in the JS treats it that way.
Future<FirestoreDoc?> restGetDocument(String docPath) async {
  final res = await firestoreSend('GET', _uri(_docName(docPath)), await _headers(), null);
  if (res.status == 404) return null;
  if (!_ok(res.status)) {
    throw FirestoreRestException(
      'GET',
      res.status,
      firestoreErrorBody(res.data, res.rawText),
    );
  }
  return decodeFirestoreDocument(res.data);
}

/// List a collection, ordered, one page at a time.
///
/// **`documents.list`, not `:runQuery`**, and the JS's comment is the reason:
/// runQuery returns zero rows for the nested subcollections this database uses
/// while list returns them correctly. The cost is that there is no `where` —
/// ordering only — which is why the leaderboard pages rather than filters.
Future<({List<FirestoreDoc> docs, String? nextPageToken})> restListDocuments(
  String collectionPath, {
  String? orderBy,
  int pageSize = 100,
  String? pageToken,
}) async {
  final res = await firestoreSend(
    'GET',
    _uri(_docName(collectionPath), {
      'pageSize': '$pageSize',
      'orderBy': ?orderBy,
      'pageToken': ?pageToken,
    }),
    await _headers(),
    null,
  );
  if (res.status == 404) return (docs: const <FirestoreDoc>[], nextPageToken: null);
  if (!_ok(res.status)) {
    throw FirestoreRestException(
      'list',
      res.status,
      firestoreErrorBody(res.data, res.rawText),
    );
  }
  final data = res.data;
  final rows = data is Map ? data['documents'] : null;
  return (
    docs: <FirestoreDoc>[
      if (rows is List)
        for (final row in rows) ?decodeFirestoreDocument(row),
    ],
    nextPageToken: data is Map && data['nextPageToken'] is String
        ? data['nextPageToken'] as String
        : null,
  );
}

/// A structured query. [parentDocPath] empty queries from the database root,
/// which is the only form that returns rows for a collection-group query here.
Future<List<FirestoreDoc>> restRunQuery(
  String parentDocPath,
  Map<String, Object?> structuredQuery,
) async {
  final res = await firestoreSend(
    'POST',
    _uri(
      'projects/$firestoreProjectId/databases/(default)/documents:runQuery',
    ),
    await _headers(),
    {
      'parent': parentDocPath.isEmpty
          ? 'projects/$firestoreProjectId/databases/(default)/documents'
          : _docName(parentDocPath),
      'structuredQuery': structuredQuery,
    },
  );
  if (!_ok(res.status)) {
    final detail = firestoreErrorBody(res.data, res.rawText);
    throw FirestoreRestException(
      'query',
      res.status,
      detail.isEmpty ? 'permission denied' : detail,
    );
  }
  final rows = res.data;
  if (rows is! List) return const [];
  // **A 200 CAN STILL BE AN ERROR.** runQuery streams its failure back as a
  // one-element array with the status intact, which is the trap this branch
  // exists for.
  if (rows.isNotEmpty && rows.first is Map && (rows.first as Map)['error'] != null) {
    throw FirestoreRestException(
      'query',
      res.status,
      firestoreErrorBody(rows, res.rawText),
    );
  }
  return <FirestoreDoc>[
    for (final row in rows)
      if (row is Map) ?decodeFirestoreDocument(row['document']),
  ];
}

Uri _commitUri() =>
    _uri('projects/$firestoreProjectId/databases/(default)/documents:commit');

/// Write one document. See [buildFirestoreWrite] for what the options mean.
Future<void> restCommitWrite(
  String docPath, {
  Map<String, Object?> set = const {},
  Map<String, num> increment = const {},
  List<String> serverTimestamps = const [],
  bool merge = true,
  bool mustNotExist = false,
  String? ifUpdateTime,
}) => restCommitWrites([
  (
    docPath: docPath,
    set: set,
    increment: increment,
    serverTimestamps: serverTimestamps,
    merge: merge,
    mustNotExist: mustNotExist,
    ifUpdateTime: ifUpdateTime,
  ),
]);

/// One write in a batch.
typedef FirestoreWriteSpec = ({
  String docPath,
  Map<String, Object?> set,
  Map<String, num> increment,
  List<String> serverTimestamps,
  bool merge,
  bool mustNotExist,
  String? ifUpdateTime,
});

/// Commit many writes atomically, in batches of [firestoreCommitBatch].
///
/// One round trip a batch, which the JS's comment argues for directly: it is far
/// more reliable than N sequential writes on a flaky connection, and a phone
/// finishing a season on a train is the case it was written for.
Future<void> restCommitWrites(List<FirestoreWriteSpec> specs) async {
  for (var i = 0; i < specs.length; i += firestoreCommitBatch) {
    final slice = specs.skip(i).take(firestoreCommitBatch);
    final res = await firestoreSend(
      'POST',
      _commitUri(),
      await _headers(),
      {
        'writes': [
          for (final s in slice)
            buildFirestoreWrite(
              _docName(s.docPath),
              set: s.set,
              increment: s.increment,
              serverTimestamps: s.serverTimestamps,
              merge: s.merge,
              mustNotExist: s.mustNotExist,
              ifUpdateTime: s.ifUpdateTime,
            ),
        ],
      },
    );
    if (!_ok(res.status)) {
      throw FirestoreRestException(
        'commit',
        res.status,
        firestoreErrorBody(res.data, res.rawText),
      );
    }
  }
}

/// Delete one document. **A 404 is a success** — deleting something that is not
/// there is the outcome asked for.
Future<void> restDeleteDocument(String docPath) async {
  final res = await firestoreSend(
    'DELETE',
    _uri(_docName(docPath)),
    await _headers(),
    null,
  );
  if (!_ok(res.status) && res.status != 404) {
    throw FirestoreRestException(
      'delete',
      res.status,
      firestoreErrorBody(res.data, res.rawText),
    );
  }
}

/// Delete many, in batches.
Future<void> restCommitDeletes(List<String> docPaths) async {
  for (var i = 0; i < docPaths.length; i += firestoreCommitBatch) {
    final slice = docPaths.skip(i).take(firestoreCommitBatch);
    final res = await firestoreSend('POST', _commitUri(), await _headers(), {
      'writes': [
        for (final path in slice) {'delete': _docName(path)},
      ],
    });
    if (!_ok(res.status)) {
      throw FirestoreRestException(
        'delete-commit',
        res.status,
        firestoreErrorBody(res.data, res.rawText),
      );
    }
  }
}
