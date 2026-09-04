/// What signing in DOES to the save, and what a failure says — the pure half of
/// `../merge-empire-fc/src/services/authService.js`.
///
/// **The rest of that file is Firebase Auth's own lifecycle**, and the port has
/// no Firebase SDK: the leaderboard and cloud save reach Firestore over plain
/// HTTPS, and a sign-in will come through whatever plugin the native build
/// carries. What survives the change of transport is what the file DECIDES —
/// and every decision in it is arithmetic over the save or a mapping from an
/// error code to a line of copy.
///
/// Two of those decisions are not obvious and both are load-bearing:
///
/// - **A DIFFERENT uid is a different career.** Signing in as somebody else
///   must clear `careerSeeded` and `anonymousLinked`, or the new account
///   inherits the last one's leaderboard state and the seeding never runs
///   again. Signing in as the SAME uid must not — that is a re-auth, and
///   clearing there would re-seed a career on every token refresh.
/// - **The account name is the email's local part, capped.** Not the display
///   name: a Google account's display name is the person's real one and this
///   goes on a public leaderboard. Forty characters, which is the JS's own
///   slice.
///
/// Deliberately Flutter-free, so all of it runs under plain `dart test` with no
/// network and no plugin.
library;

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// The `leaderboard` branch, created if the save has none.
Map<String, dynamic> _leaderboard(Map<String, dynamic> state) {
  final existing = _map(state['leaderboard']);
  if (existing != null) return existing;
  final fresh = <String, dynamic>{};
  state['leaderboard'] = fresh;
  return fresh;
}

/// **The public name, off the email's local part.**
///
/// Not the display name, which on a Google account is the person's real one —
/// and this goes on a global leaderboard. Trimmed, and capped at the JS's own
/// forty characters. Null for a user with no email, which is every Apple
/// sign-in that chose to hide it.
String? accountNameFromEmail(String? email) {
  if (email == null) return null;
  final at = email.indexOf('@');
  final local = (at < 0 ? email : email.substring(0, at)).trim();
  if (local.isEmpty) return null;
  return local.length <= 40 ? local : local.substring(0, 40);
}

/// Who the save believes is signed in, or null.
String? sessionUid(Map<String, dynamic>? state) {
  final uid = _map(state?['leaderboard'])?['authUid'];
  return uid is String && uid.isNotEmpty ? uid : null;
}

/// **No round trip.** The save carries the uid, so "is anybody signed in" is
/// answerable before Firebase has said a word — which is what the settings
/// screen needs on the frame it opens.
bool isSignedInLocal(Map<String, dynamic>? state) => sessionUid(state) != null;

/// `google`, `apple`, or null.
///
/// Null when nobody is signed in, whatever the save happens to have left in the
/// field: a provider without a uid is a stale write, not a session.
String? authProviderOf(Map<String, dynamic>? state) {
  if (sessionUid(state) == null) return null;
  final p = _map(state?['leaderboard'])?['authProvider'];
  return p is String && p.isNotEmpty ? p : null;
}

/// Write a sign-in — or a sign-out, with [uid] null — into the save.
///
/// **A DIFFERENT uid resets the leaderboard's own flags.** Signing in as
/// somebody else must clear `careerSeeded` and `anonymousLinked` or the new
/// account inherits the last one's and the seeding never runs again; signing in
/// as the SAME uid must not, because that is a re-auth and clearing there
/// re-seeds a career on every token refresh.
///
/// Returns whether the uid actually changed, so a caller knows whether to run
/// the boot sync.
bool applyAuthUser(
  Map<String, dynamic> state, {
  required String? uid,
  String? email,
  String? provider,
}) {
  final board = _leaderboard(state);
  final previous = sessionUid(state);
  final next = uid != null && uid.isNotEmpty ? uid : null;
  final changed = next != previous;
  if (next != null && changed) {
    board['careerSeeded'] = false;
    board['anonymousLinked'] = false;
  }
  board['authUid'] = next;
  board['accountName'] = accountNameFromEmail(email);
  board['authProvider'] = next == null ? null : provider;
  return changed;
}

/// The copy key for a failed sign-in.
///
/// **Every branch is the JS's**, including the two that look like typos and are
/// not: `disallowed_useragent` is Google refusing to render its consent screen
/// inside a WebView, and `UNIMPLEMENTED` is the native plugin being present but
/// not configured. Both have their own line because both are a SETUP problem
/// rather than something the player did.
String authErrorKey(Object? error) {
  final code = '$error';
  if (code == 'offline') return 'auth.no_connection';
  if (code == 'auth/popup-blocked' ||
      code == 'auth/cancelled-popup-request') {
    return 'auth.error_popup_blocked';
  }
  if (code == 'auth/unauthorized-domain') {
    return 'auth.error_unauthorized_domain';
  }
  if (code == 'auth/operation-not-allowed') return 'auth.error_not_enabled';
  if (code == 'auth/user-cancelled' ||
      code == 'auth/popup-closed-by-user') {
    return 'auth.error_cancelled';
  }
  if (code.contains('disallowed_useragent')) {
    return 'auth.error_webview_blocked';
  }
  if (code == 'native_auth_unavailable' || code == 'UNIMPLEMENTED') {
    return 'auth.error_native_setup';
  }
  return 'auth.sign_in_failed';
}

/// Play Games' player, beside the Firebase uid — the JS's `pgsPlayerId`.
///
/// The display name stands in for the email a Play Games account never has,
/// and only when nothing is there already: a name the player typed stands.
void recordPgsIdentity(
  Map<String, dynamic> state, {
  required String playerId,
  String? playerName,
}) {
  final board = _leaderboard(state);
  board['pgsPlayerId'] = playerId;
  final current = board['accountName'];
  if (playerName == null || playerName.isEmpty) return;
  if (current is String && current.isNotEmpty) return;
  board['accountName'] = playerName.length > 40
      ? playerName.substring(0, 40)
      : playerName;
}
