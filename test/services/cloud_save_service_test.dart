/// Cloud save, over the transport seam.
///
/// The policy — who wins when the phone and the cloud disagree — is pure and
/// lives in `engine/cloud_save_policy.dart` with its own tests. What is here is
/// the half that talks: what gets written, what a refused precondition does,
/// and what the debounce is for. Nothing opens a socket: `firestoreSend` is
/// replaced wholesale.
library;

import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/cloud_save_policy.dart';
import 'package:merge_empire_fc/services/cloud_save_service.dart';
import 'package:merge_empire_fc/services/firestore_rest.dart';

late List<({String method, Uri url, Object? body})> sent;

/// Answer every request with [replies], in order; the last one repeats.
void serve(List<({int status, Object? data})> replies) {
  var i = 0;
  firestoreSend = (method, url, headers, body) async {
    sent.add((method: method, url: url, body: body));
    final reply = replies[i < replies.length - 1 ? i++ : replies.length - 1];
    return (status: reply.status, data: reply.data, rawText: null);
  };
}

Map<String, dynamic> save({
  String club = 'Borough United',
  int matches = 4,
  int lastSeen = 1000,
  String? token,
  int syncedMs = 0,
}) => <String, dynamic>{
  'version': 7,
  'clubName': club,
  'lastSeen': lastSeen,
  'progression': <String, dynamic>{
    'currentDivision': 'sunday_league',
    'matchesPlayed': matches,
    'seasonCount': 1,
  },
  'leaderboard': <String, dynamic>{
    'authUid': 'u1',
    'cloudSyncToken': ?token,
    'cloudSyncMs': syncedMs,
  },
};

/// A Firestore document as the REST API hands one back.
({int status, Object? data}) doc(
  Map<String, dynamic> state, {
  String updateTime = '2026-08-23T10:00:00.000Z',
  int lastSeen = 1000,
}) => (
  status: 200,
  data: {
    'name': 'projects/p/databases/(default)/documents/saves/u1',
    'updateTime': updateTime,
    'fields': {
      'lastSeen': {'integerValue': '$lastSeen'},
      'data': {'stringValue': jsonEncode(state)},
    },
  },
);

Map<String, dynamic>? passThrough(Map<String, dynamic>? s) => s;

void main() {
  setUp(() {
    sent = [];
    resetFirestoreSeams();
    cancelPendingCloudUpload();
  });

  tearDown(() {
    resetFirestoreSeams();
    cancelPendingCloudUpload();
  });

  group('what goes up', () {
    test('THE SAVE IS ONE BLOB, and it is not merged', () async {
      // Patching would leave the previous save's fields alongside the new
      // one's, which is a save nobody wrote.
      serve([(status: 200, data: <String, dynamic>{})]);
      final res = await uploadCloudSave(
        save(),
        'u1',
        migrateCloud: passThrough,
        fallbackClubName: 'Your Club',
      );
      expect(res.ok, isTrue);
      final write = ((sent.single.body as Map)['writes'] as List).single as Map;
      expect(
        (write['update'] as Map)['name'],
        endsWith('/documents/saves/u1'),
      );
      expect(write['updateMask'], isNull, reason: 'a mask IS a merge');
      final data =
          ((write['update'] as Map)['fields'] as Map)['data'] as Map;
      expect(
        jsonDecode(data['stringValue'] as String),
        isA<Map<String, dynamic>>(),
      );
    });

    test('and the auth uid is NOT carried into the blob', () async {
      // It is this device's identity, not the save's.
      final packed = packStateForCloud(save());
      expect((packed['leaderboard'] as Map)['authUid'], isNull);
      expect(packed['clubName'], 'Borough United');
    });

    test('a save with a token writes a PRECONDITION', () async {
      serve([(status: 200, data: <String, dynamic>{})]);
      await uploadCloudSave(
        save(token: '2026-08-23T09:00:00.000Z'),
        'u1',
        migrateCloud: passThrough,
        fallbackClubName: 'Your Club',
      );
      final write = ((sent.single.body as Map)['writes'] as List).single as Map;
      expect(
        (write['currentDocument'] as Map)['updateTime'],
        '2026-08-23T09:00:00.000Z',
      );
    });

    test('and `force` drops it', () async {
      serve([(status: 200, data: <String, dynamic>{})]);
      await uploadCloudSave(
        save(token: '2026-08-23T09:00:00.000Z'),
        'u1',
        force: true,
        migrateCloud: passThrough,
        fallbackClubName: 'Your Club',
      );
      final write = ((sent.single.body as Map)['writes'] as List).single as Map;
      expect(write['currentDocument'], isNull);
    });

    test('no uid is not an upload', () async {
      serve([(status: 200, data: <String, dynamic>{})]);
      final res = await uploadCloudSave(
        save(),
        null,
        migrateCloud: passThrough,
        fallbackClubName: 'Your Club',
      );
      expect(res.ok, isFalse);
      expect(sent, isEmpty);
    });
  });

  group('A REFUSED PRECONDITION IS RECONCILED, not dropped', () {
    // Dropping it froze full saves for days while the leaderboard — which
    // writes with no precondition — kept advancing, and only a reinstall
    // re-baselined the token to unstick it.
    test('the same lineage RETRIES, and the retry has no precondition', () async {
      serve([
        (status: 400, data: {'error': {'message': 'FAILED_PRECONDITION'}}),
        doc(save(), lastSeen: 9999),
        (status: 200, data: <String, dynamic>{}),
      ]);
      final res = await uploadCloudSave(
        save(token: '2026-08-23T09:00:00.000Z'),
        'u1',
        migrateCloud: passThrough,
        fallbackClubName: 'Your Club',
      );
      expect(res.ok, isTrue);
      expect(res.stale, isFalse);
      expect(sent, hasLength(3), reason: 'write, read, write');
      // The re-baselined token came off the read, so the second write carries
      // that one rather than the stale one.
      final retry =
          ((sent.last.body as Map)['writes'] as List).single as Map;
      expect(
        (retry['currentDocument'] as Map?)?['updateTime'],
        isNot('2026-08-23T09:00:00.000Z'),
      );
    });

    test('BUT A NEWER DIVERGENT CLOUD IS A CONFLICT, and stops', () async {
      serve([
        (status: 400, data: {'error': {'message': 'FAILED_PRECONDITION'}}),
        doc(
          save(club: 'Somebody Else', matches: 40),
          updateTime: '2026-08-23T12:00:00.000Z',
          lastSeen: 99999,
        ),
      ]);
      final res = await uploadCloudSave(
        save(token: '2026-08-23T09:00:00.000Z', lastSeen: 10),
        'u1',
        migrateCloud: passThrough,
        fallbackClubName: 'Your Club',
      );
      expect(res.ok, isFalse);
      expect(res.stale, isTrue);
      expect(sent, hasLength(2), reason: 'it must not write over them');
    });

    test('and anything that is NOT a precondition re-throws', () async {
      serve([
        (status: 403, data: {'error': {'message': 'PERMISSION_DENIED'}}),
      ]);
      await expectLater(
        uploadCloudSave(
          save(token: '2026-08-23T09:00:00.000Z'),
          'u1',
          migrateCloud: passThrough,
          fallbackClubName: 'Your Club',
        ),
        throwsA(isA<FirestoreRestException>()),
      );
    });
  });

  group('what comes down', () {
    test('a missing document is null, not a throw', () async {
      serve([(status: 404, data: null)]);
      expect(await fetchCloudSave('u1'), isNull);
    });

    test('THE BLOB IS A STRING, and a mapValue is not one', () async {
      // The save is stored as JSON text in one field, and the codec answers
      // null for a `mapValue` on purpose — the JS does the same, because a real
      // map arriving here means the document was written by something that is
      // not this game. A "legacy nested map" branch was written into
      // `fetchCloudSave` and could never have run.
      serve([
        (
          status: 200,
          data: {
            'name': 'projects/p/databases/(default)/documents/saves/u1',
            'updateTime': '2026-08-23T10:00:00.000Z',
            'fields': {
              'lastSeen': {'integerValue': '77'},
              'data': {
                'mapValue': {
                  'fields': {
                    'clubName': {'stringValue': 'Old Save'},
                  },
                },
              },
            },
          },
        ),
      ]);
      final snap = await fetchCloudSave('u1');
      expect(snap!.lastSeen, 77);
      expect(snap.cloudData, isNull);
      expect(snap.updatedAtMs, greaterThan(0));
    });

    test('but a STRING blob decodes, and carries the club', () async {
      serve([doc(save(club: 'Read Back'), lastSeen: 42)]);
      final snap = await fetchCloudSave('u1');
      expect(snap!.lastSeen, 42);
      expect(snap.cloudData!['clubName'], 'Read Back');
    });

    test('and a blob that will not parse is null DATA, not a null doc', () async {
      serve([
        (
          status: 200,
          data: {
            'name': 'projects/p/databases/(default)/documents/saves/u1',
            'updateTime': '2026-08-23T10:00:00.000Z',
            'fields': {
              'data': {'stringValue': 'not json'},
            },
          },
        ),
      ]);
      final snap = await fetchCloudSave('u1');
      expect(snap, isNotNull);
      expect(snap!.cloudData, isNull);
    });
  });

  group('the boot evaluation', () {
    test('offline decides nothing and asks nothing', () async {
      serve([(status: 200, data: <String, dynamic>{})]);
      final out = await evaluateCloudSave(
        save(),
        'u1',
        migrateCloud: passThrough,
        fallbackClubName: 'Your Club',
        online: false,
      );
      expect(out.action, CloudSaveAction.none);
      expect(sent, isEmpty);
    });

    test('A CLOUD WE CANNOT READ IS ONE WE LEAVE ALONE', () async {
      // Not an upload: a 500 is not evidence that the cloud is empty.
      serve([(status: 500, data: null)]);
      final out = await evaluateCloudSave(
        save(),
        'u1',
        migrateCloud: passThrough,
        fallbackClubName: 'Your Club',
        online: true,
      );
      expect(out.action, CloudSaveAction.none);
    });

    test('no cloud document at all is an UPLOAD', () async {
      serve([(status: 404, data: null)]);
      final out = await evaluateCloudSave(
        save(),
        'u1',
        migrateCloud: passThrough,
        fallbackClubName: 'Your Club',
        online: true,
      );
      expect(out.action, CloudSaveAction.upload);
    });

    test('a fresh local against a played cloud is a RESTORE', () async {
      serve([doc(save(club: 'Cloud Club', matches: 30))]);
      final out = await evaluateCloudSave(
        <String, dynamic>{'leaderboard': <String, dynamic>{'authUid': 'u1'}},
        'u1',
        migrateCloud: passThrough,
        fallbackClubName: 'Your Club',
        online: true,
      );
      expect(out.action, CloudSaveAction.restore);
      expect(out.cloud!.clubName, 'Cloud Club');
    });

    test('and a cloud this build cannot migrate is an upload', () async {
      serve([doc(save(club: 'Cloud Club', matches: 30))]);
      final out = await evaluateCloudSave(
        save(),
        'u1',
        migrateCloud: (_) => null,
        fallbackClubName: 'Your Club',
        online: true,
      );
      expect(out.action, CloudSaveAction.upload);
    });
  });

  group('a change seen on resume', () {
    test('IDENTICAL FINGERPRINTS RE-SYNC SILENTLY', () async {
      // A token lost to an OS process kill looks exactly like somebody else
      // having written, and alarming a player about their own save is worse
      // than a quiet re-baseline.
      final state = save(syncedMs: 0);
      serve([doc(save(), updateTime: '2026-08-23T10:00:00.000Z')]);
      final out = await checkRemoteCloudChange(
        state,
        'u1',
        migrateCloud: passThrough,
        fallbackClubName: 'Your Club',
        online: true,
      );
      expect(out, isNull);
      expect(
        (state['leaderboard'] as Map)['cloudSyncToken'],
        '2026-08-23T10:00:00.000Z',
        reason: 'the baseline was not re-written',
      );
    });

    test('but a DIVERGENT newer cloud is a choice', () async {
      serve([doc(save(club: 'Another Phone', matches: 40))]);
      final out = await checkRemoteCloudChange(
        save(),
        'u1',
        migrateCloud: passThrough,
        fallbackClubName: 'Your Club',
        online: true,
      );
      expect(out!.action, CloudSaveAction.choose);
      expect(out.cloud!.clubName, 'Another Phone');
    });

    test('and a cloud inside the slack is not somebody else', () async {
      final state = save(syncedMs: cloudTimestampMs('2026-08-23T10:00:00.000Z'));
      serve([
        doc(
          save(club: 'Another Phone', matches: 40),
          updateTime: '2026-08-23T10:00:01.000Z',
        ),
      ]);
      expect(
        await checkRemoteCloudChange(
          state,
          'u1',
          migrateCloud: passThrough,
          fallbackClubName: 'Your Club',
          online: true,
        ),
        isNull,
      );
    });
  });

  group('the debounce', () {
    test('a spree is ONE write, and the newest save wins', () {
      fakeAsync((async) {
        serve([(status: 200, data: <String, dynamic>{})]);
        for (var i = 0; i < 5; i++) {
          scheduleCloudUpload(
            save(matches: i),
            'u1',
            migrateCloud: passThrough,
            fallbackClubName: 'Your Club',
            online: true,
          );
          async.elapse(const Duration(milliseconds: 300));
        }
        expect(sent, isEmpty, reason: 'it fired mid-spree');
        async.elapse(cloudUploadDebounce);
        expect(sent, hasLength(1));
      });
    });

    test('and a flush cancels the pending one rather than doubling it', () {
      fakeAsync((async) {
        serve([(status: 200, data: <String, dynamic>{})]);
        scheduleCloudUpload(
          save(),
          'u1',
          migrateCloud: passThrough,
          fallbackClubName: 'Your Club',
          online: true,
        );
        unawaited(
          flushCloudUpload(
            save(),
            'u1',
            migrateCloud: passThrough,
            fallbackClubName: 'Your Club',
            online: true,
          ),
        );
        async.elapse(cloudUploadDebounce * 2);
        expect(sent, hasLength(1));
      });
    });

    test('offline schedules nothing at all', () {
      fakeAsync((async) {
        serve([(status: 200, data: <String, dynamic>{})]);
        scheduleCloudUpload(
          save(),
          'u1',
          migrateCloud: passThrough,
          fallbackClubName: 'Your Club',
          online: false,
        );
        async.elapse(cloudUploadDebounce * 2);
        expect(sent, isEmpty);
      });
    });
  });
}
