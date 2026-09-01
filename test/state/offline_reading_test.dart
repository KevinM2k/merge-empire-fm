/// The offline window, taken at the one instant it means anything.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/state/game_runner.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';

Map<String, dynamic> _awayFor(Duration away) {
  final save = createDefaultState();
  save['tutorial'] = <String, dynamic>{'done': true, 'step': 0};
  save['lastSeen'] =
      DateTime.now().millisecondsSinceEpoch - away.inMilliseconds;
  final cells = (save['grid'] as Map<String, dynamic>)['cells'] as List;
  for (var i = 0; i < 4 && i < cells.length; i++) {
    cells[i] = <String, dynamic>{
      'instanceId': 'card-$i',
      'definitionId': 'player_t1_gk',
    };
  }
  return save;
}

GameRunner _runnerOver(Map<String, dynamic> save) => GameRunner(
  game: GameState(
    store: MemorySaveStore({saveKeyPrimary: jsonEncode(save)}),
  ),
);

void main() {
  test('AN HOUR AWAY SURVIVES THE STAMP THAT FOLLOWS IT', () {
    // **This is the whole bug, in one assertion.** `processOfflineEarnings`
    // measures `now() - lastSeen`, and `lastSeen` is rewritten by every
    // `saveNow` — the age-signal sweep boot fires and forgets, the two-second
    // save debounce, the cloud restore. It used to be computed later, in the
    // popup host's first post-frame callback, where it was racing all three.
    // On a device it lost: an hour away reached the card as a window of about
    // a millisecond, so the card paid a couple of coins and said "0s".
    //
    // The reading is taken inside `boot`, off the save as loaded. A stamp
    // afterwards — which is what the sweeps do — must not be able to touch it.
    final runner = _runnerOver(_awayFor(const Duration(hours: 1)));
    runner.boot();
    final atBoot = runner.pendingOffline;

    // Exactly what the sweeps do, and what used to erase the window.
    runner.game.saveNow();

    expect(atBoot, isNotNull, reason: 'boot took no reading at all');
    expect(
      atBoot!.offlineMs,
      greaterThan(const Duration(minutes: 55).inMilliseconds),
      reason: 'the hour was measured wrong',
    );
    expect(
      runner.pendingOffline!.offlineMs,
      atBoot.offlineMs,
      reason: 'a later stamp rewrote the reading — this is the "0s" bug',
    );
    expect(atBoot.earned, greaterThan(0));
  });

  test('and a save put down a moment ago is owed nothing', () {
    final runner = _runnerOver(_awayFor(Duration.zero));
    runner.boot();
    expect(runner.pendingOffline!.earned, 0);
  });
}
