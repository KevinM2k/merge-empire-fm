/// The Firebase session itself — what a sign-in returns, when it goes stale and
/// what a refusal is called.
///
/// **The port mints its Firebase session over REST**, which is the same call
/// `services/firestore_rest.dart` already makes and for the same reason: the
/// JS's own transport note is that the Firebase SDK's network layer hangs in a
/// native WebView, so `firebase.js` is a lazy singleton wrapped in two
/// workarounds the port does not need. What the plugins on either side supply
/// is an OAuth `id_token` — Google's or Apple's — and Identity Toolkit turns
/// one of those into a Firebase uid and an ID token. That leaves the whole
/// exchange as arithmetic over two JSON bodies, which is why it is in here and
/// testable rather than behind a plugin.
///
/// **A refresh token outlives its ID token by a long way**, and mixing the two
/// up is the failure that looks like a random sign-out: the ID token is an hour
/// and the refresh token is until it is revoked. Only the first one expires in
/// normal play, so [AuthSession.stale] asks about that one.
///
/// Deliberately Flutter-free, and it takes `now` rather than reading the clock —
/// see the wall-clock note in `docs/REMAINING.md`, where two seeds in twenty-six
/// failed because a test read the real one.
library;

import 'dart:convert';

/// One signed-in Firebase session.
///
/// [provider] is `google`, `apple` or null for the anonymous session the
/// leaderboard's public reads run on — the JS's `signInAnonymously` in
/// `firestoreRestAuth.js`, which exists so a reader that has never signed in
/// still carries a bearer token.
class AuthSession {
  const AuthSession({
    required this.uid,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
    this.email,
    this.provider,
  });

  final String uid;
  final String idToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String? email;
  final String? provider;

  /// Anonymous sessions carry no provider, and nothing may be written to a
  /// player's cloud save under one.
  bool get isAnonymous => provider == null;

  /// **Stale a minute EARLY.** A token that expires while the request carrying
  /// it is in flight is a 401 the caller cannot tell from a permissions
  /// failure, so the margin is what keeps "signed out" meaning signed out.
  bool stale(DateTime now) =>
      !now.isBefore(expiresAt.subtract(const Duration(minutes: 1)));

  AuthSession withTokens({
    required String idToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) => AuthSession(
    uid: uid,
    idToken: idToken,
    refreshToken: refreshToken,
    expiresAt: expiresAt,
    email: email,
    provider: provider,
  );
}

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

/// `expiresIn` arrives as a STRING of seconds, in both shapes of response.
Duration _lifetime(Object? v) {
  final seconds = v is num ? v.toInt() : int.tryParse('$v');
  // An hour is Identity Toolkit's own figure, and a missing field is far more
  // likely to be a shape change than a token that never expires.
  return Duration(seconds: seconds == null || seconds <= 0 ? 3600 : seconds);
}

/// A session out of `accounts:signInWithIdp` or `accounts:signUp`.
///
/// Null when the body has no uid or no token — which is every error body, and
/// is why the caller does not have to check the status code twice.
AuthSession? sessionFromSignIn(
  Object? body, {
  required DateTime now,
  String? provider,
}) {
  final json = _map(body);
  final uid = _str(json?['localId']);
  final idToken = _str(json?['idToken']);
  final refresh = _str(json?['refreshToken']);
  if (uid == null || idToken == null || refresh == null) return null;
  return AuthSession(
    uid: uid,
    idToken: idToken,
    refreshToken: refresh,
    expiresAt: now.add(_lifetime(json?['expiresIn'])),
    // **Empty is null, not an email.** An Apple sign-in that chose to hide its
    // address sends `''`, and `accountNameFromEmail` would otherwise be handed
    // a string it has to defend itself against.
    email: _str(json?['email']),
    provider: provider,
  );
}

/// New tokens for an existing session, out of `securetoken.googleapis.com`.
///
/// **That endpoint answers in snake_case** while Identity Toolkit answers in
/// camelCase — the same two fields under different names, which is the shape
/// mistake this function exists to make once instead of at every call site.
AuthSession? refreshedSession(
  AuthSession current,
  Object? body, {
  required DateTime now,
}) {
  final json = _map(body);
  final idToken = _str(json?['id_token']);
  final refresh = _str(json?['refresh_token']);
  if (idToken == null || refresh == null) return null;
  return current.withTokens(
    idToken: idToken,
    refreshToken: refresh,
    expiresAt: now.add(_lifetime(json?['expires_in'])),
  );
}

/// The failure code out of an Identity Toolkit error body.
///
/// The message field carries the code and sometimes a colon and an explanation
/// after it — `WEAK_PASSWORD : Password should be...` — so the code is the part
/// before the colon.
String? restErrorCode(Object? body) {
  final message = _str(_map(_map(body)?['error'])?['message']);
  if (message == null) return null;
  final colon = message.indexOf(':');
  return (colon < 0 ? message : message.substring(0, colon)).trim();
}

/// An Identity Toolkit code as the code the JS's own error map is written in.
///
/// **`authErrorKey` in `auth_policy.dart` stays the one place a failure becomes
/// copy**, and it is written against the Firebase JS SDK's `auth/...` strings
/// because those are the JS's. Rather than teach it a second vocabulary — which
/// would leave two maps to keep in step — the REST code is translated into the
/// SDK's here. Anything unrecognised passes through and lands on the generic
/// `auth.sign_in_failed`, which is the same thing the JS does with a code it
/// has never seen.
String authErrorCodeFromRest(String? restCode) => switch (restCode) {
  'OPERATION_NOT_ALLOWED' => 'auth/operation-not-allowed',
  'INVALID_IDP_RESPONSE' || 'INVALID_ID_TOKEN' => 'auth/invalid-credential',
  'USER_DISABLED' => 'auth/user-disabled',
  'TOKEN_EXPIRED' || 'USER_NOT_FOUND' => 'auth/user-token-expired',
  null => 'auth/unavailable',
  _ => restCode,
};

/// The uid inside a Firebase ID token — its `sub`.
///
/// `accounts:signInWithCustomToken` answers with the tokens and no `localId`
/// beside them, so the uid has to be read off the token itself.
String? uidFromIdToken(String idToken) {
  final parts = idToken.split('.');
  if (parts.length < 2) return null;
  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final json = _map(jsonDecode(payload));
    return _str(json?['sub']) ?? _str(json?['user_id']);
  } catch (_) {
    return null;
  }
}

/// A session out of `accounts:signInWithCustomToken` — Play Games' bridge.
AuthSession? sessionFromCustomToken(
  Object? body, {
  required DateTime now,
  required String provider,
}) {
  final json = _map(body);
  final idToken = _str(json?['idToken']);
  final refresh = _str(json?['refreshToken']);
  if (idToken == null || refresh == null) return null;
  final uid = uidFromIdToken(idToken);
  if (uid == null) return null;
  return AuthSession(
    uid: uid,
    idToken: idToken,
    refreshToken: refresh,
    expiresAt: now.add(_lifetime(json?['expiresIn'])),
    provider: provider,
  );
}
