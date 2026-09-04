/// The Play Games bridge's session: a custom-token sign-in answers with tokens
/// and no uid, so the uid is read off the ID token.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/auth_session.dart';

String jwt(Map<String, Object?> payload) {
  final body = base64Url.encode(utf8.encode(jsonEncode(payload)));
  return 'eyJhbGciOiJSUzI1NiJ9.${body.replaceAll('=', '')}.sig';
}

void main() {
  final t0 = DateTime.utc(2026, 9, 4, 12);

  test('the uid is the token\'s sub, unpadded base64url and all', () {
    expect(uidFromIdToken(jwt({'sub': 'pgs_123', 'aud': 'merge-empire-fc'})), 'pgs_123');
    expect(uidFromIdToken(jwt({'user_id': 'u9'})), 'u9');
    expect(uidFromIdToken('not.a.jwt'), isNull);
    expect(uidFromIdToken('nodots'), isNull);
  });

  test('a session out of the custom-token body', () {
    final s = sessionFromCustomToken(
      {'idToken': jwt({'sub': 'pgs_1'}), 'refreshToken': 'r', 'expiresIn': '3600'},
      now: t0,
      provider: 'play_games',
    )!;
    expect(s.uid, 'pgs_1');
    expect(s.provider, 'play_games');
    expect(s.isAnonymous, isFalse);
    expect(s.expiresAt, t0.add(const Duration(hours: 1)));
  });

  test('no tokens, or a token with no uid in it, is no session', () {
    expect(sessionFromCustomToken({'refreshToken': 'r'}, now: t0, provider: 'play_games'), isNull);
    expect(
      sessionFromCustomToken({'idToken': 'x.y.z', 'refreshToken': 'r'}, now: t0, provider: 'play_games'),
      isNull,
    );
  });
}
