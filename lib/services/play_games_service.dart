/// Play Games Services — `../merge-empire-fc/src/services/playGamesService.js`.
///
/// **Android only, as the JS.** On boot: a silent sign-in, the player id kept
/// in the save, and — when nobody is signed in — the identity bridged into
/// Firebase through the `pgsAutoSignIn` function so the leaderboard knows the
/// player without a button pressed. That is what the Play Games bar on the
/// loading screen is. Achievements: `achievement:unlocked` → the Console id in
/// `data/pgs_achievements.dart`, and an unmapped one is silently skipped.
///
/// Every platform call is behind a seam, so a test replaces the seam rather
/// than the platform — the same split `auth_service.dart` took.
library;

import 'dart:async';
import 'dart:io';

import 'package:games_services/games_services.dart';
import 'package:merge_empire_fc/data/firebase_config.dart';
import 'package:merge_empire_fc/data/pgs_achievements.dart';
import 'package:merge_empire_fc/engine/auth_policy.dart';
import 'package:merge_empire_fc/services/auth_service.dart';
import 'package:merge_empire_fc/services/leaderboard_service.dart'
    show leaderboardPost;
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

/// What a sign-in hands back.
typedef PgsPlayer = ({String id, String? name});

/// The plugin seam, replaced wholesale in tests.
class PlayGamesSeams {
  bool Function() isAndroid = () => Platform.isAndroid;

  /// Null when Play Games has no player for this device; throws on refusal.
  Future<PgsPlayer?> Function() signIn = _realSignIn;
  Future<void> Function(String id) unlock = _realUnlock;
}

Future<PgsPlayer?> _realSignIn() async {
  await GamesServices.signIn();
  final id = await GamesServices.getPlayerID();
  if (id == null || id.isEmpty) return null;
  return (id: id, name: await GamesServices.getPlayerName());
}

Future<void> _realUnlock(String id) =>
    GamesServices.unlock(achievement: Achievement(androidID: id));

/// The deployed function that mints the bridge token.
final Uri pgsAutoSignInUrl = Uri.https(
  'us-central1-$firebaseProjectId.cloudfunctions.net',
  '/pgsAutoSignIn',
);

/// The token out of a callable's `{result: {token}}` — null for anything else.
String? pgsTokenFrom(Object? body) {
  final result = body is Map ? body['result'] : null;
  final token = result is Map ? result['token'] : null;
  return token is String && token.isNotEmpty ? token : null;
}

class PlayGamesService {
  PlayGamesService({PlayGamesSeams? seams}) : seams = seams ?? PlayGamesSeams();

  /// The app's. A field so a test can stand a fresh one up.
  static PlayGamesService instance = PlayGamesService();

  final PlayGamesSeams seams;
  Future<String?>? _init;

  /// Sign in and bridge, once per launch. Answers the player id, or null.
  Future<String?> init(GameState game) => _init ??= _initOnce(game);

  Future<String?> _initOnce(GameState game) async {
    if (!seams.isAndroid()) return null;
    final PgsPlayer? player;
    try {
      player = await seams.signIn();
    } catch (_) {
      return null;
    }
    final state = game.state;
    if (player == null || state == null) return null;
    recordPgsIdentity(state, playerId: player.id, playerName: player.name);
    game.scheduleSave();
    // A session already restored is the account to keep — the JS skips the
    // bridge for a live one, and re-bridging would sign the player into the
    // `pgs_<id>` account over the Google or Apple one they chose.
    if (AuthService.instance.signedIn) return player.id;
    try {
      final response = await leaderboardPost(pgsAutoSignInUrl, const {}, {
        'data': {'pgsPlayerId': player.id, 'pgsPlayerName': player.name},
      });
      final token = pgsTokenFrom(response.data);
      if (response.status < 200 || response.status >= 300 || token == null) {
        return player.id;
      }
      final session = await AuthService.instance.signInWithCustomToken(
        state,
        token,
      );
      if (session != null) {
        // `applyAuthUser` has just cleared the name; the Play Games one stands.
        recordPgsIdentity(state, playerId: player.id, playerName: player.name);
        game.scheduleSave();
      }
    } catch (_) {
      // Play Games is on; the leaderboard is not. The JS's own outcome.
    }
    return player.id;
  }

  /// Unlock the Console achievement mapped to [localId], if there is one.
  void unlock(String? localId) {
    if (!seams.isAndroid()) return;
    final id = pgsAchievementIds[localId];
    if (id == null) return;
    unawaited(seams.unlock(id).catchError((Object _) {}));
  }

  void attach() => on('achievement:unlocked', _onUnlocked);
  void detach() => off('achievement:unlocked', _onUnlocked);

  void _onUnlocked(Object? args) {
    final id = args is Map ? args['id'] : null;
    if (id is String) unlock(id);
  }
}
