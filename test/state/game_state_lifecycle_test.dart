/// Booting, saving and restoring: the half of the game state that talks to the
/// world rather than to the save's contents.
///
/// The resets are compared against the JS in `game_state_test.dart`. This is the
/// plumbing around them — which stored copy boot trusts, when a change is
/// actually written, what a cloud restore is allowed to overwrite, and what
/// happens when the native bridge simply never answers.
library;

import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/util/time.dart';

const int _now = 1700000000000;

/// A save this build can read, tagged so a test can tell which copy won.
String _save(String label, {int version = 7}) => jsonEncode({
  ...createDefaultState(),
  'version': version,
  'clubName': label,
});

GameState _game(
  MemorySaveStore store, {
  Future<String?> Function()? readNativeMirror,
  void Function(String json)? writeNativeMirror,
  Future<void> Function(Map<String, dynamic>)? uploadCloudSave,
}) => GameState(
  store: store,
  readNativeMirror: readNativeMirror,
  writeNativeMirror: writeNativeMirror,
  uploadCloudSave: uploadCloudSave,
);

void main() {
  setUp(() => setClock(() => _now));
  tearDown(resetClock);

  group('boot', () {
    test('the primary save wins when it loads', () {
      final store = MemorySaveStore({
        saveKeyPrimary: _save('primary'),
        saveKeyLastGood: _save('mirror'),
      });
      final game = _game(store);
      expect(game.load()['clubName'], 'primary');
      expect(game.bootedOnDefault, isFalse);
    });

    test('a truncated primary falls through to the mirror, and sticks', () {
      // Sticks: the recovered save is written straight back, so boot stops
      // retrying the ladder on every launch.
      final store = MemorySaveStore({
        saveKeyPrimary: '{"version":7,"clubName":"prim',
        saveKeyLastGood: _save('mirror'),
      });
      final game = _game(store);
      expect(game.load()['clubName'], 'mirror');
      expect(
        jsonDecode(store.values[saveKeyPrimary]!),
        containsPair('clubName', 'mirror'),
      );
    });

    test('an unreadable save is stashed before anything overwrites it', () {
      final fromTheFuture = _save('future', version: 99);
      final store = MemorySaveStore({saveKeyPrimary: fromTheFuture});
      final game = _game(store);
      game.load();
      expect(game.bootedOnDefault, isTrue);
      expect(store.values[saveKeyBackup], fromTheFuture);
    });

    test('the stash is one-time — a second bad boot does not overwrite it', () {
      // The first unreadable save is the one worth keeping; a later one is
      // whatever this build wrote over it.
      final store = MemorySaveStore({
        saveKeyPrimary: _save('second', version: 99),
        saveKeyBackup: _save('first', version: 99),
      });
      _game(store).load();
      expect(
        jsonDecode(store.values[saveKeyBackup]!),
        containsPair('clubName', 'first'),
      );
    });

    test('a backup this build can now read is recovered and cleared', () {
      final store = MemorySaveStore({
        saveKeyPrimary: 'not json at all',
        saveKeyBackup: _save('stashed'),
      });
      final game = _game(store);
      expect(game.load()['clubName'], 'stashed');
      expect(store.values.containsKey(saveKeyBackup), isFalse);
    });

    test('nothing stored is a fresh default, and says so', () {
      final game = _game(MemorySaveStore());
      final state = game.load();
      expect(state['version'], isNotNull);
      expect(game.bootedOnDefault, isTrue);
    });
  });

  group('the native mirror', () {
    test('recovers a save when boot found nothing', () {
      final store = MemorySaveStore();
      final game = _game(
        store,
        readNativeMirror: () async => _save('fromTheMirror'),
      );
      final state = game.load();
      expect(game.bootedOnDefault, isTrue);

      return expectLater(
        game.recoverFromNativeMirror(),
        completion(isTrue),
      ).then((_) {
        // The SAME map: every screen already holding it must see the recovery.
        expect(identical(game.state, state), isTrue);
        expect(state['clubName'], 'fromTheMirror');
        expect(game.bootedOnDefault, isFalse);
        expect(
          jsonDecode(store.values[saveKeyPrimary]!),
          containsPair('clubName', 'fromTheMirror'),
        );
      });
    });

    test('leaves a player who has a save alone', () async {
      var reads = 0;
      final game = _game(
        MemorySaveStore({saveKeyPrimary: _save('theirs')}),
        readNativeMirror: () async {
          reads++;
          return _save('older');
        },
      );
      game.load();
      expect(await game.recoverFromNativeMirror(), isFalse);
      expect(reads, 0);
      expect(game.state!['clubName'], 'theirs');
    });

    test('gives up rather than trapping boot on the splash', () async {
      // A native bridge that never answers must cost three seconds, not the
      // session.
      final game = _game(
        MemorySaveStore(),
        readNativeMirror: () => Completer<String?>().future,
      );
      game.load();
      expect(
        await game.recoverFromNativeMirror(
          timeout: const Duration(milliseconds: 10),
        ),
        isFalse,
      );
      expect(game.bootedOnDefault, isTrue);
    });

    test('a bridge that throws is not a crash', () async {
      final game = _game(
        MemorySaveStore(),
        readNativeMirror: () async => throw StateError('no channel'),
      );
      game.load();
      expect(await game.recoverFromNativeMirror(), isFalse);
    });

    test('is written at most once a minute, and always on demand', () {
      final writes = <String>[];
      fakeAsync((async) {
        var at = _now;
        setClock(() => at);
        final game = _game(MemorySaveStore(), writeNativeMirror: writes.add);
        game.load();

        game.update((s) => s['clubName'] = 'one');
        async.elapse(const Duration(seconds: 3));
        expect(writes, hasLength(1));

        // A second save inside the window does not churn the platform store.
        at += 5000;
        game.update((s) => s['clubName'] = 'two');
        async.elapse(const Duration(seconds: 3));
        expect(writes, hasLength(1));

        // The forced flush is what guarantees it is fresh in the window where
        // an eviction actually happens.
        game.flushNativeMirror();
        expect(writes, hasLength(2));

        at += nativeMirrorThrottleMs + 1;
        game.update((s) => s['clubName'] = 'three');
        async.elapse(const Duration(seconds: 3));
        expect(writes, hasLength(3));
      });
    });
  });

  group('saving', () {
    test('a change is written once the debounce lapses', () {
      fakeAsync((async) {
        final store = MemorySaveStore();
        final game = _game(store)..load();
        game.update((s) => s['clubName'] = 'Rovers');
        expect(game.savePending, isTrue);
        expect(store.values.containsKey(saveKeyPrimary), isFalse);

        async.elapse(const Duration(milliseconds: saveDebounceMs));
        expect(game.savePending, isFalse);
        expect(
          jsonDecode(store.values[saveKeyPrimary]!),
          containsPair('clubName', 'Rovers'),
        );
        // And the mirror slot, written separately so a truncated primary cannot
        // take it down too.
        expect(store.values[saveKeyLastGood], store.values[saveKeyPrimary]);
      });
    });

    test('a spree is one write, not thirty', () {
      fakeAsync((async) {
        final store = MemorySaveStore();
        final game = _game(store)..load();
        for (var i = 0; i < 30; i++) {
          game.update((s) => s['clubName'] = 'merge $i');
          async.elapse(const Duration(milliseconds: 100));
        }
        expect(store.values.containsKey(saveKeyPrimary), isFalse);
        async.elapse(const Duration(milliseconds: saveDebounceMs));
        expect(
          jsonDecode(store.values[saveKeyPrimary]!),
          containsPair('clubName', 'merge 29'),
        );
      });
    });

    test('the cloud flag is sticky across passive saves', () {
      // Idle income resets the shared timer with `syncCloud: false`, and it must
      // not cancel an upload a real event already asked for.
      fakeAsync((async) {
        final uploads = <Map<String, dynamic>>[];
        final game = _game(
          MemorySaveStore(),
          uploadCloudSave: (s) async => uploads.add(s),
        )..load();
        game.state!['leaderboard'] = <String, dynamic>{'authUid': 'uid'};

        game.update((s) => s['clubName'] = 'real event');
        async.elapse(const Duration(milliseconds: 500));
        game.update((s) => s['lastSeen'] = 1, syncCloud: false);
        async.elapse(const Duration(milliseconds: saveDebounceMs));
        expect(uploads, hasLength(1));

        // And a purely passive change on its own never uploads.
        game.update((s) => s['lastSeen'] = 2, syncCloud: false);
        async.elapse(const Duration(milliseconds: saveDebounceMs));
        expect(uploads, hasLength(1));
      });
    });

    test('a signed-out player never uploads', () {
      fakeAsync((async) {
        final uploads = <Map<String, dynamic>>[];
        final game = _game(
          MemorySaveStore(),
          uploadCloudSave: (s) async => uploads.add(s),
        )..load();
        game.update((s) => s['clubName'] = 'anon');
        async.elapse(const Duration(milliseconds: saveDebounceMs));
        expect(uploads, isEmpty);
      });
    });

    test('a failed upload is not an unhandled rejection', () {
      fakeAsync((async) {
        final game = _game(
          MemorySaveStore(),
          uploadCloudSave: (_) async => throw StateError('offline'),
        )..load();
        game.state!['leaderboard'] = <String, dynamic>{'authUid': 'uid'};
        game.update((s) => s['clubName'] = 'x');
        expect(
          () => async.elapse(const Duration(milliseconds: saveDebounceMs)),
          returnsNormally,
        );
      });
    });

    test('a frozen state writes nothing more', () {
      final store = MemorySaveStore();
      final game = _game(store)..load();
      game.commitAndFreeze();
      final written = store.values[saveKeyPrimary];
      game.state!['clubName'] = 'after the freeze';
      game.saveNow();
      expect(store.values[saveKeyPrimary], written);
    });

    test('committing stamps the save so a reload owes no offline earnings', () {
      final store = MemorySaveStore();
      final game = _game(store)..load();
      game.state!['lastSeen'] = 0;
      game.commitAndFreeze();
      expect(game.state!['lastSeen'], _now);
      expect(game.frozen, isTrue);
      expect(game.savePending, isFalse);
    });

    test('a save that will not serialise leaves the good one alone', () {
      // Should be impossible — but writing garbage over a working save is the
      // one outcome worse than not writing at all.
      final store = MemorySaveStore();
      final game = _game(store)..load();
      game.saveNow();
      final good = store.values[saveKeyPrimary];
      game.state!['bad'] = Object();
      game.saveNow();
      expect(store.values[saveKeyPrimary], good);
    });
  });

  group('the cloud', () {
    test('a restore replaces the contents, not the map', () {
      final store = MemorySaveStore();
      final game = _game(store)..load();
      final held = game.state!;
      final cloud = jsonDecode(_save('fromTheCloud')) as Map<String, dynamic>;

      expect(game.applyCloudSave(cloud, 'uid-1'), isTrue);
      expect(identical(game.state, held), isTrue);
      expect(held['clubName'], 'fromTheCloud');
      expect(
        jsonDecode(store.values[saveKeyPrimary]!),
        containsPair('clubName', 'fromTheCloud'),
      );
    });

    test('the local identity survives the restore', () {
      final game = _game(MemorySaveStore())..load();
      game.state!['leaderboard'] = <String, dynamic>{'playerId': 'mine'};
      final cloud = jsonDecode(_save('theirs')) as Map<String, dynamic>;
      cloud['leaderboard'] = <String, dynamic>{'playerId': 'theirs'};

      game.applyCloudSave(cloud, 'uid-1');
      final board = game.state!['leaderboard'] as Map;
      expect(board['playerId'], 'mine');
      expect(board['authUid'], 'uid-1');
      // Both re-run against this device's identity rather than the restored
      // save's.
      expect(board['careerSeeded'], isFalse);
      expect(board['anonymousLinked'], isFalse);
    });

    test('a save with no identity at all gets one', () {
      final game = _game(MemorySaveStore())..load();
      game.state!.remove('leaderboard');
      final cloud = jsonDecode(_save('theirs')) as Map<String, dynamic>;
      cloud.remove('leaderboard');
      game.applyCloudSave(cloud, 'uid-1');
      final id = (game.state!['leaderboard'] as Map)['playerId'] as String;
      // A v4 UUID, not a timestamp: two devices signing in within the same
      // millisecond must not share a leaderboard row.
      expect(
        id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
            r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('a corrupt cloud document keeps the local save', () {
      // A tampered or half-written document must not crash the restore, and
      // must not take the local save with it. A document with no version is not
      // a save at all — the migration is what decides that, and it says no.
      final game = _game(MemorySaveStore())..load();
      game.state!['clubName'] = 'local';
      expect(game.applyCloudSave(null, 'uid-1'), isFalse);
      expect(game.applyCloudSave(<String, dynamic>{}, 'uid-1'), isFalse);
      expect(
        game.applyCloudSave(<String, dynamic>{'version': 99}, 'uid-1'),
        isFalse,
      );
      expect(game.state!['clubName'], 'local');
    });

    test('nothing happens before boot', () {
      final game = _game(MemorySaveStore());
      expect(game.applyCloudSave(<String, dynamic>{}, 'uid'), isFalse);
      expect(game.state, isNull);
    });
  });

  test('every fresh identity is different', () {
    final ids = {for (var i = 0; i < 200; i++) newPlayerId()};
    expect(ids, hasLength(200));
  });
}
