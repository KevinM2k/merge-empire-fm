/// The cloud, actually reconciled — the boot sync that had no caller.
///
/// Every piece under this was ported and tested and none of it ran: the
/// transport was waiting on a uid and there was no way to sign in. What is
/// pinned here is the ORCHESTRATION — which branch acts how, and that every
/// failure leaves the device's own save alone.
///
/// No socket is opened: `firestoreSend` is replaced wholesale.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/auth_policy.dart';
import 'package:merge_empire_fc/engine/cloud_save_policy.dart';
import 'package:merge_empire_fc/services/cloud_save_service.dart';
import 'package:merge_empire_fc/services/cloud_sync.dart';
import 'package:merge_empire_fc/services/firestore_rest.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';

late List<({String method, Uri url, Object? body})> sent;

/// Answer every request with [replies], in order; the last one repeats.
void serve(List<({int status, Object? data})> replies) {
  firestoreSend = (method, url, headers, body) async {
    sent.add((method: method, url: url, body: body));
    final reply = replies[sent.length <= replies.length
        ? sent.length - 1
        : replies.length - 1];
    return (status: reply.status, data: reply.data, rawText: null);
  };
}

/// A cloud document, in the shape `firestore_rest` hands back.
({int status, Object? data}) cloudDoc({
  required Map<String, dynamic> save,
  int lastSeen = 5000,
  String updateTime = '2026-03-01T12:00:00.000000Z',
}) => (
  status: 200,
  data: {
    'name': 'projects/p/databases/(default)/documents/saves/u1',
    'updateTime': updateTime,
    'fields': {
      'version': {'integerValue': '${save['version']}'},
      'lastSeen': {'integerValue': '$lastSeen'},
      'data': {'stringValue': jsonEncode(save)},
    },
  },
);

const missingDoc = (status: 404, data: null);

/// A save with a club, a division and some football behind it.
Map<String, dynamic> saveWith({
  String club = 'Borough United',
  int matches = 12,
  int seasons = 2,
  int lastSeen = 1000,
}) {
  final state = createDefaultState();
  state['clubName'] = club;
  state['lastSeen'] = lastSeen;
  final progression = state['progression'] as Map<String, dynamic>;
  progression['matchesPlayed'] = matches;
  progression['seasonCount'] = seasons;
  final board = state['leaderboard'] as Map<String, dynamic>;
  board['authUid'] = 'u1';
  return state;
}

GameState gameFor(Map<String, dynamic> state) {
  final game = GameState(
    store: MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
  );
  addTearDown(game.dispose);
  game.load();
  return game;
}

void main() {
  setUp(() {
    sent = [];
    resetCloudSyncSeams();
    cloudOnline = () async => true;
  });

  tearDown(() {
    resetFirestoreSeams();
    resetCloudSyncSeams();
    cancelPendingCloudUpload();
  });

  test('nobody signed in is nothing to do, and no request', () async {
    final state = createDefaultState();
    expect(sessionUid(state), isNull);
    serve([missingDoc]);
    expect(await runCloudBootSync(gameFor(state)), CloudSyncOutcome.none);
    expect(sent, isEmpty);
  });

  test('OFFLINE IS NOTHING TO DO — never a restore from a cloud we cannot read',
      () async {
    cloudOnline = () async => false;
    serve([missingDoc]);
    expect(await runCloudBootSync(gameFor(saveWith())), CloudSyncOutcome.none);
    expect(sent, isEmpty);
  });

  test('an empty cloud gets this device pushed to it', () async {
    serve([missingDoc, (status: 200, data: const {})]);
    expect(
      await runCloudBootSync(gameFor(saveWith())),
      CloudSyncOutcome.uploaded,
    );
    expect(sent.last.method, 'POST');
  });

  test('A REINSTALL PULLS THE CAREER BACK DOWN', () async {
    // The case the whole feature is for: a fresh local save with no progress
    // and a cloud copy with a career in it. It is not a conflict, because
    // there is nothing on this device to lose.
    final ahead = saveWith(club: 'Cloud City', matches: 90, seasons: 6);
    final fresh = createDefaultState();
    (fresh['leaderboard'] as Map<String, dynamic>)['authUid'] = 'u1';
    final game = gameFor(fresh);
    serve([cloudDoc(save: ahead, lastSeen: 99999)]);

    expect(await runCloudBootSync(game), CloudSyncOutcome.restored);
    expect(game.state!['clubName'], 'Cloud City');
    // **The uid survives the replacement.** The cloud blob has its own stripped
    // out on the way up, and a restore that forgot to put this device's back
    // would sign the player out of the save they just restored.
    expect(sessionUid(game.state), 'u1');
  });

  test('an UNREADABLE cloud document is overwritten, not obeyed', () async {
    // A tampered or corrupt blob reads as no cloud save at all, so the device
    // pushes over it. What must never happen is the local save being replaced
    // by one that would not migrate — losing everything to somebody else's bad
    // write is the outcome this whole file exists to prevent.
    final game = gameFor(saveWith(club: 'Local Town'));
    serve([
      (
        status: 200,
        data: {
          'name': 'projects/p/databases/(default)/documents/saves/u1',
          'updateTime': '2026-03-01T12:00:00.000000Z',
          'fields': {
            'version': {'integerValue': '9999'},
            'lastSeen': {'integerValue': '99999'},
            'data': {'stringValue': 'not json at all'},
          },
        },
      ),
      (status: 200, data: const {}),
    ]);
    expect(await runCloudBootSync(game), CloudSyncOutcome.uploaded);
    expect(game.state!['clubName'], 'Local Town');
  });

  test('a cloud that will not answer leaves the save alone', () async {
    final game = gameFor(saveWith(club: 'Local Town'));
    firestoreSend = (method, url, headers, body) async =>
        throw Exception('no route to host');
    expect(await runCloudBootSync(game), CloudSyncOutcome.none);
    expect(game.state!['clubName'], 'Local Town');
  });

  group('a genuine conflict', () {
    /// Two saves with real football on both sides and no shared history.
    GameState diverged() {
      final game = gameFor(saveWith(club: 'Local Town', matches: 40));
      serve([
        cloudDoc(
          save: saveWith(club: 'Cloud City', matches: 55, seasons: 3),
          lastSeen: 99999,
        ),
        (status: 200, data: const {}),
      ]);
      return game;
    }

    test('WITH NOBODY TO ASK, THE DEVICE WINS', () async {
      // The save in front of the player is the one they have been playing, and
      // replacing it unasked is the only irreversible move here.
      final game = diverged();
      expect(await runCloudBootSync(game), CloudSyncOutcome.keptLocal);
      expect(game.state!['clubName'], 'Local Town');
    });

    test('asks, and takes the cloud when that is the answer', () async {
      final game = diverged();
      late SaveSummary offeredCloud;
      late SaveSummary offeredLocal;
      conflictPrompt = (cloud, local) async {
        offeredCloud = cloud;
        offeredLocal = local;
        return CloudSaveAction.restore;
      };
      expect(await runCloudBootSync(game), CloudSyncOutcome.restored);
      expect(game.state!['clubName'], 'Cloud City');
      // The card has to be able to tell them apart, which is what it shows.
      expect(offeredCloud.clubName, 'Cloud City');
      expect(offeredLocal.clubName, 'Local Town');
      expect(offeredCloud.matchesPlayed, 55);
      expect(offeredLocal.matchesPlayed, 40);
    });

    test('KEEPING THE DEVICE FORCES THE WRITE', () async {
      // The precondition token belongs to the cloud copy the player just
      // rejected, so an ordinary upload would be refused as stale and the
      // choice would silently not stick.
      final game = diverged();
      conflictPrompt = (cloud, local) async => CloudSaveAction.upload;
      expect(await runCloudBootSync(game), CloudSyncOutcome.keptLocal);
      expect(game.state!['clubName'], 'Local Town');
      final commit = sent.last;
      expect(commit.method, 'POST');
      // A forced write carries no `currentDocument` precondition.
      expect(jsonEncode(commit.body), isNot(contains('updateTime')));
    });
  });
}
