/// Play Games, over the seams.
///
/// The bridge is the part worth asserting: the id lands in the save either way,
/// the leaderboard identity only when nobody is signed in, and a bridge that
/// fails leaves a player signed into Play Games and nothing else broken.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/auth_policy.dart';
import 'package:merge_empire_fc/services/auth_service.dart';
import 'package:merge_empire_fc/services/leaderboard_service.dart';
import 'package:merge_empire_fc/services/play_games_service.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

String fakeIdToken(String uid) {
  final payload = base64Url.encode(utf8.encode(jsonEncode({'sub': uid})));
  return 'h.${payload.replaceAll('=', '')}.s';
}

GameState gameFor(Map<String, dynamic> state) {
  final game = GameState(
    store: MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
  );
  addTearDown(game.dispose);
  game.load();
  return game;
}

Map<String, dynamic> board(GameState game) =>
    game.state!['leaderboard'] as Map<String, dynamic>;

void main() {
  late PlayGamesService pgs;
  late List<Uri> posted;
  late List<Uri> identityPosts;
  late List<String> unlocked;

  setUp(() {
    posted = [];
    identityPosts = [];
    unlocked = [];
    pgs = PlayGamesService();
    pgs.seams.isAndroid = () => true;
    pgs.seams.signIn = () async => (id: 'p1', name: 'Kev the Gaffer');
    pgs.seams.unlock = (id) async => unlocked.add(id);
    leaderboardPost = (url, headers, body) async {
      posted.add(url);
      return (status: 200, data: {'result': {'token': 'custom-1'}});
    };
    final auth = AuthService();
    auth.seams.readRefresh = () async => null;
    auth.seams.writeRefresh = (_) async {};
    auth.seams.post = (url, body) async {
      identityPosts.add(url);
      return (
        status: 200,
        data: {
          'idToken': fakeIdToken('pgs_p1'),
          'refreshToken': 'r1',
          'expiresIn': '3600',
        },
      );
    };
    AuthService.instance = auth;
  });
  tearDown(() {
    resetLeaderboardSeams();
    AuthService.instance = AuthService();
  });

  test('not Android: nothing happens at all', () async {
    pgs.seams.isAndroid = () => false;
    final game = gameFor(createDefaultState());
    expect(await pgs.init(game), isNull);
    expect(posted, isEmpty);
    expect(board(game)['pgsPlayerId'], isNull);
    pgs.unlock('reach_amateur');
    expect(unlocked, isEmpty);
  });

  test('signed into nothing: the id is kept and the identity is bridged', () async {
    final game = gameFor(createDefaultState());
    expect(await pgs.init(game), 'p1');
    expect(board(game)['pgsPlayerId'], 'p1');
    expect(posted.single.path, '/pgsAutoSignIn');
    expect(identityPosts.single.path, '/v1/accounts:signInWithCustomToken');
    expect(sessionUid(game.state), 'pgs_p1');
    expect(authProviderOf(game.state), 'play_games');
    expect(
      board(game)['accountName'],
      'Kev the Gaffer',
      reason: 'a Play Games account has no email; the display name stands in',
    );
    expect(AuthService.instance.signedIn, isTrue);
  });

  test('a Google session already restored is left alone', () async {
    final state = createDefaultState();
    (state['leaderboard'] as Map<String, dynamic>)
      ..['authUid'] = 'google-1'
      ..['authProvider'] = 'google'
      ..['accountName'] = 'kev';
    AuthService.instance.seams.readRefresh = () async => 'refresh-1';
    AuthService.instance.seams.post = (url, body) async => (
      status: 200,
      data: {'id_token': 'id', 'refresh_token': 'refresh-1', 'expires_in': '3600'},
    );
    await AuthService.instance.restore(state);
    final game = gameFor(state);
    expect(await pgs.init(game), 'p1');
    expect(board(game)['pgsPlayerId'], 'p1');
    expect(posted, isEmpty, reason: 'no bridge over a live session');
    expect(sessionUid(game.state), 'google-1');
    expect(board(game)['accountName'], 'kev');
  });

  test('a refused sign-in is quiet', () async {
    pgs.seams.signIn = () async => throw StateError('no play games');
    final game = gameFor(createDefaultState());
    expect(await pgs.init(game), isNull);
    expect(posted, isEmpty);
  });

  test('a bridge the function refuses leaves Play Games on and nothing else', () async {
    leaderboardPost = (url, headers, body) async {
      posted.add(url);
      return (status: 500, data: {'error': 'boom'});
    };
    final game = gameFor(createDefaultState());
    expect(await pgs.init(game), 'p1');
    expect(board(game)['pgsPlayerId'], 'p1');
    expect(identityPosts, isEmpty);
    expect(sessionUid(game.state), isNull);
  });

  test('init runs once per launch', () async {
    final game = gameFor(createDefaultState());
    await pgs.init(game);
    await pgs.init(game);
    expect(posted, hasLength(1));
  });

  group('achievements', () {
    test('a mapped one reaches the Console id; an unmapped one is skipped', () {
      pgs.unlock('reach_amateur');
      pgs.unlock('first_merge');
      pgs.unlock('no-such-achievement');
      expect(unlocked, ['CgkIq9aYo8oOEAIQAA']);
    });

    test('the bus event is what fires it', () {
      pgs.attach();
      addTearDown(pgs.detach);
      emit('achievement:unlocked', {'id': 'reach_regional', 'coinsRewarded': 0});
      expect(unlocked, ['CgkIq9aYo8oOEAIQAQ']);
    });

    test('a refusal from the plugin is swallowed', () async {
      pgs.seams.unlock = (id) async => throw StateError('not signed in');
      pgs.unlock('reach_amateur');
      await Future<void>.delayed(Duration.zero);
    });
  });

  test('the token is read out of a callable result and nothing else', () {
    expect(pgsTokenFrom({'result': {'token': 't'}}), 't');
    expect(pgsTokenFrom({'result': {'token': ''}}), isNull);
    expect(pgsTokenFrom({'error': 'x'}), isNull);
    expect(pgsTokenFrom('nonsense'), isNull);
  });
}
