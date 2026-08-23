import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/auth_policy.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';

Map<String, dynamic> save({
  String? uid,
  String? provider,
  bool careerSeeded = true,
  bool anonymousLinked = true,
}) => <String, dynamic>{
  'leaderboard': <String, dynamic>{
    'authUid': ?uid,
    'authProvider': ?provider,
    'careerSeeded': careerSeeded,
    'anonymousLinked': anonymousLinked,
  },
};

void main() {
  group('the public name', () {
    test('IS THE EMAIL\'S LOCAL PART, not the display name', () {
      // A Google account's display name is the person's real one, and this goes
      // on a global leaderboard.
      expect(accountNameFromEmail('kevin.matthews@example.com'), 'kevin.matthews');
    });

    test('and it is capped at forty', () {
      final long = 'a' * 60;
      expect(accountNameFromEmail('$long@example.com'), 'a' * 40);
    });

    test('AN APPLE SIGN-IN THAT HID ITS EMAIL HAS NO NAME', () {
      expect(accountNameFromEmail(null), isNull);
      expect(accountNameFromEmail(''), isNull);
      expect(accountNameFromEmail('@example.com'), isNull);
      expect(accountNameFromEmail('   @example.com'), isNull);
    });
  });

  group('who is signed in', () {
    test('comes off the SAVE, with no round trip', () {
      // The settings screen needs it on the frame it opens.
      expect(isSignedInLocal(save(uid: 'u1')), isTrue);
      expect(isSignedInLocal(save()), isFalse);
      expect(isSignedInLocal(null), isFalse);
      expect(isSignedInLocal(<String, dynamic>{}), isFalse);
    });

    test('and an empty uid is nobody', () {
      expect(sessionUid(save(uid: '')), isNull);
    });

    test('A PROVIDER WITHOUT A UID IS A STALE WRITE, not a session', () {
      expect(authProviderOf(save(provider: 'google')), isNull);
      expect(authProviderOf(save(uid: 'u1', provider: 'google')), 'google');
    });
  });

  group('writing a sign-in', () {
    test('A DIFFERENT UID RESETS THE LEADERBOARD FLAGS', () {
      // Otherwise the new account inherits the last one's and the seeding never
      // runs again.
      final state = save(uid: 'old');
      expect(
        applyAuthUser(state, uid: 'new', email: 'x@y.com', provider: 'google'),
        isTrue,
      );
      final board = state['leaderboard'] as Map<String, dynamic>;
      expect(board['careerSeeded'], isFalse);
      expect(board['anonymousLinked'], isFalse);
      expect(board['authUid'], 'new');
      expect(board['accountName'], 'x');
      expect(board['authProvider'], 'google');
    });

    test('BUT THE SAME UID DOES NOT — that is a re-auth', () {
      // Clearing here would re-seed a career on every token refresh.
      final state = save(uid: 'same');
      expect(
        applyAuthUser(state, uid: 'same', email: 'x@y.com', provider: 'google'),
        isFalse,
      );
      final board = state['leaderboard'] as Map<String, dynamic>;
      expect(board['careerSeeded'], isTrue);
      expect(board['anonymousLinked'], isTrue);
    });

    test('a sign-OUT clears the uid and the provider with it', () {
      final state = save(uid: 'u1', provider: 'google');
      expect(applyAuthUser(state, uid: null), isTrue);
      final board = state['leaderboard'] as Map<String, dynamic>;
      expect(board['authUid'], isNull);
      expect(board['authProvider'], isNull);
      expect(board['accountName'], isNull);
      // And it does NOT reset the flags: signing out is not a new career.
      expect(board['careerSeeded'], isTrue);
    });

    test('and a save with no leaderboard branch gets one', () {
      final state = <String, dynamic>{};
      applyAuthUser(state, uid: 'u1', email: 'a@b.com', provider: 'apple');
      expect(sessionUid(state), 'u1');
      expect(authProviderOf(state), 'apple');
    });
  });

  group('what a failure says', () {
    test('EVERY BRANCH IS THE JS\'S, and every key ships', () {
      const cases = {
        'offline': 'auth.no_connection',
        'auth/popup-blocked': 'auth.error_popup_blocked',
        'auth/cancelled-popup-request': 'auth.error_popup_blocked',
        'auth/unauthorized-domain': 'auth.error_unauthorized_domain',
        'auth/operation-not-allowed': 'auth.error_not_enabled',
        'auth/user-cancelled': 'auth.error_cancelled',
        'auth/popup-closed-by-user': 'auth.error_cancelled',
        'native_auth_unavailable': 'auth.error_native_setup',
        'UNIMPLEMENTED': 'auth.error_native_setup',
        'something else entirely': 'auth.sign_in_failed',
      };
      for (final entry in cases.entries) {
        expect(authErrorKey(entry.key), entry.value, reason: entry.key);
        // A key with no catalogue entry answers itself, which would put the key
        // on screen.
        expect(t(entry.value), isNot(entry.value), reason: entry.value);
      }
    });

    test('AND A WEBVIEW REFUSAL IS ITS OWN LINE', () {
      // Google will not render its consent screen inside a WebView, and that is
      // a SETUP problem rather than something the player did.
      expect(
        authErrorKey('Error: disallowed_useragent for this request'),
        'auth.error_webview_blocked',
      );
    });
  });
}
