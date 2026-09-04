/// Signing in — the transport half of
/// `../merge-empire-fc/src/services/authService.js`.
///
/// **What DECIDES anything is in `engine/auth_policy.dart` and
/// `engine/auth_session.dart`**, both pure and both already tested; this file
/// is the two plugins, the REST exchange and the one place a token is kept.
/// That is the same split cloud save took, and for the same reason: the failure
/// mode here is a player losing an account.
///
/// **The Firebase session is minted over REST rather than by the Firebase
/// SDK.** The port has no `firebase_core`, deliberately — `data/firebase_config.dart`
/// explains why the JS's own transport workarounds are a cure for an illness
/// this build does not have — so the shape is: a plugin does the OAuth dance
/// with Google or Apple and hands back an `id_token`, and Identity Toolkit
/// exchanges that for a Firebase uid and an ID token. The plugins are the only
/// part that has to be native, and each is behind a seam here so a test
/// replaces the seam instead of the platform.
///
/// **The refresh token is kept OUT of the save**, in a preference of its own.
/// The save goes to the cloud, and `cloud_save_service.dart` already strips
/// `authUid` on the way up because it belongs to the device that wrote it — a
/// refresh token is the same thing with the account attached, and restoring one
/// onto a second device would hand it the first one's session.
///
/// **An anonymous session is not a signed-in player.** `firestoreRestAuth.js`
/// signs in anonymously purely so leaderboard reads carry a bearer token; it
/// never becomes an account, and [AuthService.signedIn] says so.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:merge_empire_fc/data/firebase_config.dart';
import 'package:merge_empire_fc/engine/auth_policy.dart';
import 'package:merge_empire_fc/engine/auth_session.dart';
import 'package:merge_empire_fc/services/firestore_rest.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Where the refresh token lives. Named like every other key the app keeps.
const String authRefreshKey = 'mergeEmpireFC_authRefresh';

/// The same ten seconds Firestore's own calls take.
const Duration authTimeout = firestoreTimeout;

/// What a plugin hands back: an OAuth `id_token`, and whatever else came with it.
///
/// [rawNonce] is Apple's and only Apple's. Firebase verifies that the hash
/// baked into the identity token matches the nonce sent beside it, so the two
/// have to travel together — which is why the seam returns the nonce rather
/// than the caller inventing one.
typedef OAuthCredential = ({String idToken, String? email, String? rawNonce});

/// The plugin seam. One per provider, replaced wholesale in tests.
typedef OAuthSignIn = Future<OAuthCredential> Function();

/// One HTTPS POST, reduced to what this file needs.
typedef AuthResponse = ({int status, Object? data});

/// The transport seam.
typedef AuthPost = Future<AuthResponse> Function(Uri url, Object body);

/// Every failure out of this file, carrying the code the copy map is written
/// against.
///
/// **`toString` is the bare code** because `authErrorKey` interpolates whatever
/// it is given — so an exception that printed anything friendlier would fall
/// through every branch and land on the generic line.
class AuthException implements Exception {
  AuthException(this.code);

  final String code;

  @override
  String toString() => code;
}

/// Google, Apple, the network and the clock — the four things a test replaces.
class AuthSeams {
  AuthSeams();

  /// Google's OAuth flow. **`serverClientId` is what makes it useful**: without
  /// one the plugin returns an access token and no `id_token`, and an access
  /// token cannot be exchanged for a Firebase session.
  OAuthSignIn google = _realGoogle;

  /// Apple's. iOS and macOS only — the button is not offered elsewhere, which
  /// is the JS's own `showAppleSignInButton`.
  OAuthSignIn apple = _realApple;

  AuthPost post = _realPost;

  DateTime Function() now = DateTime.now;

  /// The refresh token across launches.
  Future<String?> Function() readRefresh = _realReadRefresh;
  Future<void> Function(String?) writeRefresh = _realWriteRefresh;
}

bool _googleReady = false;

Future<OAuthCredential> _realGoogle() async {
  final signIn = GoogleSignIn.instance;
  try {
    if (!_googleReady) {
      await signIn.initialize(
        // iOS reads its own client from the plist when one is bundled; passing
        // it means the value is the same on a build that has no plist yet.
        clientId: Platform.isIOS ? googleIosClientId : null,
        serverClientId: googleServerClientId,
      );
      _googleReady = true;
    }
    final account = await signIn.authenticate();
    final token = account.authentication.idToken;
    if (token == null || token.isEmpty) {
      throw AuthException('auth/invalid-credential');
    }
    return (idToken: token, email: account.email, rawNonce: null);
  } on GoogleSignInException catch (e) {
    throw AuthException(switch (e.code) {
      GoogleSignInExceptionCode.canceled => 'auth/user-cancelled',
      // The plugin is present and the app is not registered for it — the JS
      // gives this its own line because it is a SETUP problem rather than
      // something the player did.
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        'native_auth_unavailable',
      _ => 'auth/unavailable',
    });
  } on MissingPluginException catch (_) {
    throw AuthException('native_auth_unavailable');
  }
}

/// A one-off nonce, and its SHA-256 for Apple to bake into the token.
String _rawNonce([Random? random]) {
  const alphabet =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
  final rng = random ?? Random.secure();
  return List.generate(32, (_) => alphabet[rng.nextInt(alphabet.length)]).join();
}

Future<OAuthCredential> _realApple() async {
  final raw = _rawNonce();
  try {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: sha256.convert(utf8.encode(raw)).toString(),
    );
    final token = credential.identityToken;
    if (token == null || token.isEmpty) {
      throw AuthException('auth/invalid-credential');
    }
    return (idToken: token, email: credential.email, rawNonce: raw);
  } on SignInWithAppleAuthorizationException catch (e) {
    throw AuthException(
      e.code == AuthorizationErrorCode.canceled
          ? 'auth/user-cancelled'
          : 'auth/unavailable',
    );
  } on SignInWithAppleNotSupportedException catch (_) {
    throw AuthException('native_auth_unavailable');
  } on MissingPluginException catch (_) {
    throw AuthException('native_auth_unavailable');
  }
}

Future<AuthResponse> _realPost(Uri url, Object body) async {
  final client = HttpClient()..connectionTimeout = authTimeout;
  try {
    final request = await client.postUrl(url).timeout(authTimeout);
    request.headers.contentType = ContentType.json;
    // The same attestation Firestore's own calls carry, and for the same
    // reason: an app-restricted key is refused without it.
    request.headers.set('X-Ios-Bundle-Identifier', firestoreBundleId);
    request.headers.set('X-Android-Package', firestoreBundleId);
    request.write(jsonEncode(body));
    final response = await request.close().timeout(authTimeout);
    final text = await response
        .transform(utf8.decoder)
        .join()
        .timeout(authTimeout);
    Object? data;
    try {
      data = text.isEmpty ? null : jsonDecode(text);
    } catch (_) {
      data = text;
    }
    return (status: response.statusCode, data: data);
  } finally {
    client.close(force: true);
  }
}

Future<String?> _realReadRefresh() async {
  try {
    return (await SharedPreferences.getInstance()).getString(authRefreshKey);
  } catch (_) {
    return null;
  }
}

Future<void> _realWriteRefresh(String? token) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(authRefreshKey);
    } else {
      await prefs.setString(authRefreshKey, token);
    }
  } catch (_) {
    // A preference that will not write is a session that does not survive the
    // next launch, which is worth nobody's error dialog.
  }
}

/// The one signed-in session, and the calls that change it.
class AuthService {
  AuthService({AuthSeams? seams}) : seams = seams ?? AuthSeams();

  /// The app's. A field rather than a getter so a test can stand a fresh one up
  /// without the previous test's session in it.
  static AuthService instance = AuthService();

  final AuthSeams seams;

  AuthSession? _session;

  /// In flight, so two callers on one frame do not mint two anonymous sessions.
  Future<AuthSession?>? _pending;

  /// The current session, or null. For tests and for the settings row.
  AuthSession? get session => _session;

  /// **An anonymous session does not count.** It exists so a read carries a
  /// token; nobody is signed IN under one.
  bool get signedIn => _session != null && !_session!.isAnonymous;

  /// Whether Apple's button is offered. The JS hides it on Android and nowhere
  /// else, which is Apple's own rule rather than a product decision.
  static bool get appleAvailable => Platform.isIOS || Platform.isMacOS;

  Uri _identityUri(String method) => Uri.https(
    'identitytoolkit.googleapis.com',
    '/v1/accounts:$method',
    {'key': firestoreApiKey},
  );

  /// Sign in with [provider] — `google` or `apple` — and write it into [state].
  ///
  /// **The save is written before anything else happens.** `applyAuthUser`
  /// clears the leaderboard's seeding flags when the uid CHANGES, and the sync
  /// that reads them runs after; doing it the other way round seeds the new
  /// account off the old one's counters.
  Future<AuthSession> signIn(
    Map<String, dynamic> state, {
    required String provider,
  }) async {
    final credential = await switch (provider) {
      'google' => seams.google(),
      'apple' => seams.apple(),
      _ => throw AuthException('auth/unavailable'),
    };
    final providerId = provider == 'apple' ? 'apple.com' : 'google.com';
    final postBody = <String>[
      'id_token=${credential.idToken}',
      'providerId=$providerId',
      if (credential.rawNonce != null) 'nonce=${credential.rawNonce}',
    ].join('&');

    final response = await seams.post(_identityUri('signInWithIdp'), {
      'postBody': postBody,
      'requestUri': 'https://$firebaseProjectId.firebaseapp.com',
      'returnSecureToken': true,
      'returnIdpCredential': true,
    });
    final session = sessionFromSignIn(
      response.data,
      now: seams.now(),
      provider: provider,
    );
    if (session == null) {
      throw AuthException(
        authErrorCodeFromRest(restErrorCode(response.data)),
      );
    }

    _session = session;
    await seams.writeRefresh(session.refreshToken);
    applyAuthUser(
      state,
      uid: session.uid,
      // **Apple only sends the address once**, on the very first authorisation,
      // so a re-sign-in has none and the stored name is the one that stands.
      email: session.email,
      provider: provider,
    );
    emit('auth:changed', {'uid': session.uid});
    return session;
  }

  /// Play Games' bridge: a custom token minted by the `pgsAutoSignIn`
  /// function, exchanged for a session of this device's own.
  ///
  /// **Null, never a throw.** This runs on the boot path with nothing pressed,
  /// and a bridge that fails leaves the player in Play Games and out of the
  /// leaderboard — which is the JS's own answer.
  Future<AuthSession?> signInWithCustomToken(
    Map<String, dynamic> state,
    String token,
  ) async {
    final AuthResponse response;
    try {
      response = await seams.post(_identityUri('signInWithCustomToken'), {
        'token': token,
        'returnSecureToken': true,
      });
    } catch (_) {
      return null;
    }
    final session = sessionFromCustomToken(
      response.data,
      now: seams.now(),
      provider: 'play_games',
    );
    if (session == null) return null;
    _session = session;
    await seams.writeRefresh(session.refreshToken);
    applyAuthUser(state, uid: session.uid, provider: 'play_games');
    emit('auth:changed', {'uid': session.uid});
    return session;
  }

  /// Sign out — the plugin session, the token and the save's own uid.
  ///
  /// **The anonymous session is dropped with it** rather than kept for reads: a
  /// player who has just signed out and whose next request still carries the
  /// old bearer is the one case where a stale token is worse than none.
  /// **IT RETURNS NOTHING TO WAIT ON, deliberately.** Signing out is the one
  /// call here that must not depend on anything answering: the save is the
  /// record of who is signed in, and a preferences write that hangs would
  /// otherwise leave a player who asked to disconnect still connected until it
  /// came back. The token it clears is useless the moment the uid beside it is
  /// gone, so clearing it is housekeeping rather than part of the act.
  void signOut(Map<String, dynamic> state) {
    _session = null;
    _pending = null;
    applyAuthUser(state, uid: null);
    emit('auth:changed', {'uid': null});
    unawaited(seams.writeRefresh(null));
  }

  /// Pick the stored session back up on boot, without a plugin round trip.
  ///
  /// **The SAVE says who was signed in and the preference says how to prove
  /// it**, and both are needed: a refresh token with no uid in the save is a
  /// session for an account this device has been signed out of, and a uid with
  /// no refresh token is a row that would say "connected" and then fail every
  /// write. Either one alone is cleared rather than trusted.
  Future<AuthSession?> restore(Map<String, dynamic>? state) async {
    final uid = sessionUid(state);
    final refresh = await seams.readRefresh();
    if (uid == null || refresh == null) {
      if (refresh != null) await seams.writeRefresh(null);
      return null;
    }
    final stale = AuthSession(
      uid: uid,
      idToken: '',
      refreshToken: refresh,
      // Already expired, so the first token asked for is a fresh one.
      expiresAt: seams.now(),
      provider: authProviderOf(state) ?? 'google',
    );
    _session = stale;
    return (await _refresh(stale)).session;
  }

  /// The bearer token for a REST call, minting or refreshing as needed.
  ///
  /// **Null is a normal answer.** Leaderboard reads are public — the JS's own
  /// Firestore rule is `read: if true` — so a failure here costs a player
  /// nothing they can see, and a caller that needs the token will get its own
  /// 403 to report.
  Future<String?> bearerToken() async {
    final current = _session;
    if (current != null && !current.stale(seams.now())) return current.idToken;
    final resolved = await (_pending ??= _renew(current).whenComplete(() {
      _pending = null;
    }));
    return resolved?.idToken;
  }

  Future<AuthSession?> _renew(AuthSession? current) async {
    if (current != null) {
      final attempt = await _refresh(current);
      if (attempt.session != null) return attempt.session;
      // **UNREACHABLE IS NOT REVOKED, and telling them apart is the whole
      // reason [_refresh] answers with two fields.** A refusal means the token
      // is gone — revoked, or the account deleted — and asking again on every
      // request turns one failure into a loop, so it is a sign-out. A socket
      // that would not open means the player is on a train, and signing them
      // out for it would be the port inventing a logout the JS never has.
      if (!attempt.refused) return null;
      if (!current.isAnonymous) {
        _session = null;
        await seams.writeRefresh(null);
        emit('auth:changed', {'uid': null});
      }
    }
    return _anonymous();
  }

  /// New tokens, and whether the refusal was Firebase's or the network's.
  Future<({AuthSession? session, bool refused})> _refresh(
    AuthSession current,
  ) async {
    final AuthResponse response;
    try {
      response = await seams.post(
        Uri.https('securetoken.googleapis.com', '/v1/token', {
          'key': firestoreApiKey,
        }),
        {'grant_type': 'refresh_token', 'refresh_token': current.refreshToken},
      );
    } catch (_) {
      return (session: null, refused: false);
    }
    final next = refreshedSession(current, response.data, now: seams.now());
    if (next == null) return (session: null, refused: true);
    _session = next;
    if (!next.isAnonymous) await seams.writeRefresh(next.refreshToken);
    return (session: next, refused: false);
  }

  /// The token-carrying session a reader who has never signed in gets.
  Future<AuthSession?> _anonymous() async {
    final AuthResponse response;
    try {
      response = await seams.post(_identityUri('signUp'), {
        'returnSecureToken': true,
      });
    } catch (_) {
      return null;
    }
    final session = sessionFromSignIn(response.data, now: seams.now());
    if (session != null) _session = session;
    return session;
  }
}

/// Hand Firestore's bearer seam to the auth service.
///
/// Called once at boot. Separate from the service so that nothing about the
/// leaderboard's transport is decided by importing this file.
void wireAuthToFirestore() {
  firestoreAuthToken = () => AuthService.instance.bearerToken();
}
