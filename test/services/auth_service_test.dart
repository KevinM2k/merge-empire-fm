/// Signing in, over the seams.
///
/// Nothing here opens a socket or touches a plugin: the two OAuth flows, the
/// HTTPS post, the clock and the stored refresh token are all replaced. What is
/// under test is the sequence — which call happens before which, and what each
/// one leaves in the save.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/auth_policy.dart';
import 'package:merge_empire_fc/services/auth_service.dart';
import 'package:merge_empire_fc/services/firestore_rest.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

final DateTime t0 = DateTime.utc(2026, 3, 1, 12);

late List<({Uri url, Object body})> posted;
late List<String?> refreshWrites;
late AuthService auth;
late DateTime clock;

/// Answer every post with [replies], in order; the last one repeats.
void serve(List<AuthResponse> replies) {
  auth.seams.post = (url, body) async {
    posted.add((url: url, body: body));
    return replies[posted.length <= replies.length ? posted.length - 1 : replies.length - 1];
  };
}

AuthResponse ok(Map<String, dynamic> data) => (status: 200, data: data);

Map<String, dynamic> idp({String uid = 'uid-1', String? email}) =>
    <String, dynamic>{
      'localId': uid,
      'idToken': 'id-$uid',
      'refreshToken': 'refresh-$uid',
      'expiresIn': '3600',
      'email': ?email,
    };

Map<String, dynamic> save() => <String, dynamic>{
  'leaderboard': <String, dynamic>{'careerSeeded': true, 'anonymousLinked': true},
};

void main() {
  setUp(() {
    posted = [];
    refreshWrites = [];
    clock = t0;
    auth = AuthService();
    auth.seams.now = () => clock;
    auth.seams.google = () async =>
        (idToken: 'google-token', email: 'kevin@example.com', rawNonce: null);
    auth.seams.apple = () async =>
        (idToken: 'apple-token', email: null, rawNonce: 'nonce-1');
    auth.seams.readRefresh = () async => null;
    auth.seams.writeRefresh = (token) async => refreshWrites.add(token);
    serve([ok(idp(email: 'kevin@example.com'))]);
  });

  tearDown(resetFirestoreSeams);

  group('signing in', () {
    test('exchanges the OAuth token for a Firebase session', () async {
      final state = save();
      final session = await auth.signIn(state, provider: 'google');

      expect(posted.single.url.path, '/v1/accounts:signInWithIdp');
      final body = posted.single.body as Map<String, dynamic>;
      expect(body['postBody'], contains('id_token=google-token'));
      expect(body['postBody'], contains('providerId=google.com'));
      expect(body['returnSecureToken'], isTrue);
      expect(session.uid, 'uid-1');
      expect(auth.signedIn, isTrue);
    });

    test("APPLE'S NONCE TRAVELS WITH THE TOKEN", () async {
      // Firebase verifies the hash baked into the identity token against the
      // nonce beside it, so a sign-in that drops one is refused.
      await auth.signIn(save(), provider: 'apple');
      final body = posted.single.body as Map<String, dynamic>;
      expect(body['postBody'], contains('providerId=apple.com'));
      expect(body['postBody'], contains('nonce=nonce-1'));
    });

    test("Google's has no nonce to send", () async {
      await auth.signIn(save(), provider: 'google');
      expect((posted.single.body as Map)['postBody'], isNot(contains('nonce=')));
    });

    test('writes the uid, the name and the provider into the save', () async {
      final state = save();
      await auth.signIn(state, provider: 'google');
      final board = state['leaderboard'] as Map<String, dynamic>;
      expect(board['authUid'], 'uid-1');
      expect(board['authProvider'], 'google');
      // The email's local part, not the display name — see auth_policy.
      expect(board['accountName'], 'kevin');
    });

    test('A DIFFERENT ACCOUNT CLEARS THE SEEDING FLAGS', () async {
      final state = save();
      await auth.signIn(state, provider: 'google');
      final board = state['leaderboard'] as Map<String, dynamic>;
      expect(board['careerSeeded'], isFalse);
      expect(board['anonymousLinked'], isFalse);
    });

    test('keeps the refresh token OUT of the save', () async {
      final state = save();
      await auth.signIn(state, provider: 'google');
      expect(refreshWrites, ['refresh-uid-1']);
      // The save goes to the cloud; a refresh token in it is the account
      // travelling with it.
      expect(state.toString(), isNot(contains('refresh-uid-1')));
    });

    test('announces itself on the bus', () async {
      final seen = <Object?>[];
      void listener(Object? args) => seen.add(args);
      on('auth:changed', listener);
      await auth.signIn(save(), provider: 'google');
      off('auth:changed', listener);
      expect(seen, [
        {'uid': 'uid-1'},
      ]);
    });

    test('a refusal throws the code the copy map reads', () async {
      serve([
        (
          status: 400,
          data: const {
            'error': {'message': 'OPERATION_NOT_ALLOWED'},
          },
        ),
      ]);
      final state = save();
      await expectLater(
        auth.signIn(state, provider: 'google'),
        throwsA(
          isA<AuthException>().having(
            (e) => authErrorKey(e),
            'copy key',
            'auth.error_not_enabled',
          ),
        ),
      );
      // And it left nothing behind.
      expect(isSignedInLocal(state), isFalse);
      expect(refreshWrites, isEmpty);
    });

    test('a cancelled dialog never reaches the network', () async {
      auth.seams.google = () async => throw AuthException('auth/user-cancelled');
      await expectLater(
        auth.signIn(save(), provider: 'google'),
        throwsA(isA<AuthException>()),
      );
      expect(posted, isEmpty);
    });
  });

  group('the bearer token', () {
    test('mints an ANONYMOUS session when nobody has signed in', () async {
      serve([ok(idp(uid: 'anon'))]);
      expect(await auth.bearerToken(), 'id-anon');
      expect(posted.single.url.path, '/v1/accounts:signUp');
      // It carries a token; it is not an account.
      expect(auth.signedIn, isFalse);
      // And it is not persisted — only a real sign-in is.
      expect(refreshWrites, isEmpty);
    });

    test('is minted ONCE for two callers on the same frame', () async {
      serve([ok(idp(uid: 'anon'))]);
      final both = await Future.wait([auth.bearerToken(), auth.bearerToken()]);
      expect(both, ['id-anon', 'id-anon']);
      expect(posted, hasLength(1));
    });

    test('reuses a live token rather than asking again', () async {
      await auth.signIn(save(), provider: 'google');
      posted.clear();
      expect(await auth.bearerToken(), 'id-uid-1');
      expect(posted, isEmpty);
    });

    test('refreshes a stale one, in snake_case', () async {
      await auth.signIn(save(), provider: 'google');
      serve([
        ok(const {
          'id_token': 'fresh',
          'refresh_token': 'refresh-2',
          'expires_in': '3600',
        }),
      ]);
      posted.clear();
      clock = t0.add(const Duration(hours: 2));
      expect(await auth.bearerToken(), 'fresh');
      expect(posted.single.url.host, 'securetoken.googleapis.com');
      expect(refreshWrites.last, 'refresh-2');
    });

    test('OFFLINE KEEPS THE SESSION — unreachable is not revoked', () async {
      final state = save();
      await auth.signIn(state, provider: 'google');
      auth.seams.post = (url, body) async => throw const SocketFailure();
      clock = t0.add(const Duration(hours: 2));
      expect(await auth.bearerToken(), isNull);
      expect(auth.signedIn, isTrue);
      expect(refreshWrites, ['refresh-uid-1']);
    });

    test('A REFUSED REFRESH IS A SIGN-OUT, not a retry loop', () async {
      final state = save();
      await auth.signIn(state, provider: 'google');
      final seen = <Object?>[];
      void listener(Object? args) => seen.add(args);
      on('auth:changed', listener);
      serve([
        (
          status: 400,
          data: const {
            'error': {'message': 'TOKEN_EXPIRED'},
          },
        ),
        ok(idp(uid: 'anon')),
      ]);
      clock = t0.add(const Duration(hours: 2));
      // It falls back to an anonymous session so reads keep working.
      expect(await auth.bearerToken(), 'id-anon');
      off('auth:changed', listener);
      expect(auth.signedIn, isFalse);
      expect(refreshWrites.last, isNull);
      expect(seen, [
        {'uid': null},
      ]);
    });
  });

  group('signing out', () {
    test('clears the save, the token and the session', () async {
      final state = save();
      await auth.signIn(state, provider: 'google');
      auth.signOut(state);
      await pumpEventQueue();
      expect(isSignedInLocal(state), isFalse);
      expect(authProviderOf(state), isNull);
      expect(auth.signedIn, isFalse);
      expect(refreshWrites.last, isNull);
    });
  });

  group('restoring a session on boot', () {
    test('needs BOTH the save and the stored token', () async {
      // A refresh token with no uid is a session for an account this device has
      // been signed out of, and it is dropped rather than trusted.
      auth.seams.readRefresh = () async => 'refresh-uid-1';
      expect(await auth.restore(save()), isNull);
      expect(refreshWrites, [null]);
      expect(posted, isEmpty);
    });

    test('a uid with no stored token is not a session either', () async {
      final state = save();
      applyAuthUser(state, uid: 'uid-1', provider: 'google');
      expect(await auth.restore(state), isNull);
      expect(posted, isEmpty);
    });

    test('turns the stored token straight into a live one', () async {
      final state = save();
      applyAuthUser(
        state,
        uid: 'uid-1',
        email: 'kevin@example.com',
        provider: 'apple',
      );
      auth.seams.readRefresh = () async => 'refresh-uid-1';
      serve([
        ok(const {
          'id_token': 'fresh',
          'refresh_token': 'refresh-2',
          'expires_in': '3600',
        }),
      ]);
      final session = await auth.restore(state);
      expect(session!.idToken, 'fresh');
      expect(session.uid, 'uid-1');
      expect(session.provider, 'apple');
      expect(auth.signedIn, isTrue);
      expect(posted.single.url.host, 'securetoken.googleapis.com');
    });
  });

  group('the wiring', () {
    test('hands Firestore the bearer seam', () async {
      wireAuthToFirestore();
      AuthService.instance = auth;
      serve([ok(idp(uid: 'anon'))]);
      expect(await firestoreAuthToken(), 'id-anon');
    });
  });
}

/// A network that is not there. Any throw does; this one is named so the test
/// reads as the case it is.
class SocketFailure implements Exception {
  const SocketFailure();
}
