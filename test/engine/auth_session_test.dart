/// The Firebase session's own arithmetic: what a sign-in body means, when a
/// token is stale, and what a refusal is called.
///
/// Nothing here touches a plugin or a socket — the whole exchange reduces to
/// two JSON bodies, which is why it lives in `lib/engine` at all.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/auth_policy.dart';
import 'package:merge_empire_fc/engine/auth_session.dart';

final DateTime t0 = DateTime.utc(2026, 3, 1, 12);

Map<String, dynamic> idpBody({
  String uid = 'uid-1',
  String? email = 'kevin.matthews@example.com',
  Object? expiresIn = '3600',
}) => <String, dynamic>{
  'localId': uid,
  'idToken': 'id-token',
  'refreshToken': 'refresh-token',
  'expiresIn': expiresIn,
  'email': ?email,
};

void main() {
  group('a session out of a sign-in body', () {
    test('carries the uid, both tokens and the provider', () {
      final session = sessionFromSignIn(
        idpBody(),
        now: t0,
        provider: 'google',
      )!;
      expect(session.uid, 'uid-1');
      expect(session.idToken, 'id-token');
      expect(session.refreshToken, 'refresh-token');
      expect(session.provider, 'google');
      expect(session.isAnonymous, isFalse);
      expect(session.expiresAt, t0.add(const Duration(hours: 1)));
    });

    test('with no provider is the anonymous one the reads run on', () {
      final session = sessionFromSignIn(idpBody(email: null), now: t0)!;
      expect(session.isAnonymous, isTrue);
      expect(session.email, isNull);
    });

    test('AN EMPTY EMAIL IS NULL, not an address', () {
      // Apple sends `''` for a sign-in that chose to hide the address, and
      // `accountNameFromEmail` should never be handed one to defend against.
      final session = sessionFromSignIn(
        idpBody(email: ''),
        now: t0,
        provider: 'apple',
      )!;
      expect(session.email, isNull);
      expect(accountNameFromEmail(session.email), isNull);
    });

    test('an hour when the lifetime is missing or nonsense', () {
      for (final value in <Object?>[null, '0', '-5', 'soon']) {
        final session = sessionFromSignIn(idpBody(expiresIn: value), now: t0)!;
        expect(session.expiresAt, t0.add(const Duration(hours: 1)));
      }
    });

    test('a lifetime that arrives as a NUMBER is read too', () {
      final session = sessionFromSignIn(idpBody(expiresIn: 900), now: t0)!;
      expect(session.expiresAt, t0.add(const Duration(minutes: 15)));
    });

    test('is null for an error body, without checking the status twice', () {
      const error = {
        'error': {'code': 400, 'message': 'OPERATION_NOT_ALLOWED'},
      };
      expect(sessionFromSignIn(error, now: t0), isNull);
      expect(sessionFromSignIn(null, now: t0), isNull);
      expect(sessionFromSignIn('<html>a captive portal</html>', now: t0), isNull);
    });

    test('is null when a token is missing, not a session with an empty one', () {
      final half = idpBody()..remove('refreshToken');
      expect(sessionFromSignIn(half, now: t0), isNull);
    });
  });

  group('staleness', () {
    test('is a minute EARLY, so a request in flight cannot expire', () {
      final session = sessionFromSignIn(idpBody(), now: t0)!;
      expect(session.stale(t0), isFalse);
      expect(session.stale(t0.add(const Duration(minutes: 58))), isFalse);
      expect(session.stale(t0.add(const Duration(minutes: 59))), isTrue);
      expect(session.stale(t0.add(const Duration(hours: 2))), isTrue);
    });
  });

  group('a refresh', () {
    test('reads snake_case and keeps the uid, email and provider', () {
      final session = sessionFromSignIn(
        idpBody(),
        now: t0,
        provider: 'apple',
      )!;
      final next = refreshedSession(session, const {
        'id_token': 'fresh',
        'refresh_token': 'refresh-2',
        'expires_in': '3600',
      }, now: t0.add(const Duration(hours: 1)))!;
      expect(next.idToken, 'fresh');
      expect(next.refreshToken, 'refresh-2');
      expect(next.uid, session.uid);
      expect(next.email, session.email);
      expect(next.provider, 'apple');
      expect(next.expiresAt, t0.add(const Duration(hours: 2)));
    });

    test('is null when the token was revoked', () {
      final session = sessionFromSignIn(idpBody(), now: t0)!;
      expect(
        refreshedSession(session, const {
          'error': {'message': 'TOKEN_EXPIRED'},
        }, now: t0),
        isNull,
      );
    });
  });

  group('what a refusal is called', () {
    test('the code is the part before the colon', () {
      expect(
        restErrorCode(const {
          'error': {'message': 'WEAK_PASSWORD : Password should be longer'},
        }),
        'WEAK_PASSWORD',
      );
      expect(
        restErrorCode(const {
          'error': {'message': 'OPERATION_NOT_ALLOWED'},
        }),
        'OPERATION_NOT_ALLOWED',
      );
      expect(restErrorCode(const {'localId': 'x'}), isNull);
      expect(restErrorCode(null), isNull);
    });

    test('REST codes reach the JS COPY MAP, which is the only one', () {
      // The point of the translation: `authErrorKey` stays written against the
      // Firebase JS SDK's strings, because those are the JS's.
      expect(
        authErrorKey(authErrorCodeFromRest('OPERATION_NOT_ALLOWED')),
        'auth.error_not_enabled',
      );
      expect(
        authErrorKey(authErrorCodeFromRest(null)),
        'auth.sign_in_failed',
      );
      // Anything unrecognised passes straight through to the generic line,
      // which is what the JS does with a code it has never seen.
      expect(
        authErrorKey(authErrorCodeFromRest('SOMETHING_NEW')),
        'auth.sign_in_failed',
      );
    });

    test('the two SETUP failures keep their own lines', () {
      expect(authErrorKey('native_auth_unavailable'), 'auth.error_native_setup');
      expect(authErrorKey('auth/user-cancelled'), 'auth.error_cancelled');
    });
  });
}
