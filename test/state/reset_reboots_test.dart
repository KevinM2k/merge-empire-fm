/// A reset goes through the same start-up as a load.
///
/// The JS reloads the page after one; the port swaps the save in place, so the
/// season's opponents and its schedule — rolled only at boot — were never
/// rolled: the next-match card read "Opponent" and the Fixtures sheet sat on
/// "loading" until the app was killed. Reported with a reset, twice.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart'
    show opponentsPerSeason;
import 'package:merge_empire_fc/state/game_runner.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

void main() {
  setUp(resetBus);

  GameRunner booted() {
    final store = MemorySaveStore({
      saveKeyPrimary: jsonEncode(createDefaultState()),
    });
    return GameRunner(game: GameState(store: store))..boot();
  }

  Map<String, dynamic> prog(GameRunner r) =>
      r.game.state!['progression'] as Map<String, dynamic>;

  test('A BOOTED SAVE HAS A NAME, its opponents and its schedule', () {
    final r = booted();
    expect(r.game.state!['clubName'], isNotEmpty,
        reason: 'the JS auto-names an unnamed club at boot');
    expect(prog(r)['seasonOpponents'], hasLength(opponentsPerSeason));
    expect(prog(r)['seasonFixtures'], isNotNull);
  });

  for (final full in [false, true]) {
    test('AND SO DOES A ${full ? 'FULL' : 'SOFT'} RESET, without a relaunch',
        () {
      final r = booted();
      final before = r.game.state!['clubName'];
      if (full) {
        r.game.fullResetState(replayTutorial: false);
      } else {
        r.game.resetState(replayTutorial: false);
      }
      final state = r.game.state!;
      expect(state['clubName'], isNotEmpty);
      expect(state['clubName'], isNot(before),
          reason: 'a new club gets a new random name');
      expect(prog(r)['seasonOpponents'], hasLength(opponentsPerSeason),
          reason: 'the next-match card would read "Opponent"');
      expect(prog(r)['seasonFixtures'], isNotNull,
          reason: 'the Fixtures sheet would say loading for good');
    });
  }
}
