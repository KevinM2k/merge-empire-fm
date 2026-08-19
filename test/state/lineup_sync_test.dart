/// The stored eleven keeps up with the grid.
///
/// The bug this exists for: every screen runs the lineup through
/// `cleanAndFillLineup` on the way OUT, so a fresh save could DISPLAY a full
/// side while `squad.lineup` was still empty — and `canPlayMatch` counts the
/// stored slots. A player who had just scouted a squad was told it was too
/// small, by the screen that had drawn them all.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/match_orchestration.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/lineup_engine.dart';
import 'package:merge_empire_fc/engine/merge_engine.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/game_wiring.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

const String _defId = 'player_t1_fwd';

({GameState game, GameWiring wiring}) _boot({bool emptyLineup = true}) {
  final state = createDefaultState();
  if (emptyLineup) {
    (state['squad'] as Map<String, dynamic>)['lineup'] = <dynamic>[];
  }
  final game = GameState(
    store: MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
  );
  game.load();
  final wiring = GameWiring(game)..attach();
  addTearDown(wiring.detach);
  return (game: game, wiring: wiring);
}

List<dynamic> _lineup(GameState game) =>
    (game.state!['squad'] as Map<String, dynamic>)['lineup'] as List<dynamic>;

int _filled(GameState game) =>
    _lineup(game).where((s) => (s as Map)['cardInstanceId'] != null).length;

List<dynamic> _cells(GameState game) =>
    (game.state!['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;

void main() {
  tearDown(resetBus);

  test('a scouted squad fills the stored lineup', () {
    final boot = _boot();
    expect(_filled(boot.game), 0, reason: 'nothing signed yet');

    for (var i = 0; i < 11; i++) {
      boot.game.update((_) => placeCard(_defId, _cells(boot.game)));
    }

    expect(_filled(boot.game), 11);
  });

  test('and the Play button stops refusing once it is filled', () {
    // The reported bug, end to end: eleven players in the grid and the match
    // still refused.
    final boot = _boot();
    for (var i = 0; i < 11; i++) {
      boot.game.update((_) => placeCard(_defId, _cells(boot.game)));
    }
    // A fresh save has never played, so the cooldown is long past.
    expect(canPlayMatch(boot.game.state!), isTrue);
  });

  test('a squad below the minimum is still correctly refused', () {
    // The gate has to keep working — the fix is that it counts the real squad,
    // not that it stops counting. `minSquadPlayers` is 3, not 11: you can field
    // a side long before the eleven is full.
    final boot = _boot();
    for (var i = 0; i < minSquadPlayers - 1; i++) {
      boot.game.update((_) => placeCard(_defId, _cells(boot.game)));
    }
    expect(_filled(boot.game), minSquadPlayers - 1);
    expect(canPlayMatch(boot.game.state!), isFalse);

    boot.game.update((_) => placeCard(_defId, _cells(boot.game)));
    expect(canPlayMatch(boot.game.state!), isTrue);
  });

  test('selling a starter does not leave a hole', () {
    final boot = _boot();
    for (var i = 0; i < 12; i++) {
      boot.game.update((_) => placeCard(_defId, _cells(boot.game)));
    }
    expect(_filled(boot.game), 11);

    // Take one out of the grid and announce it, the way the sell engines do.
    final sold = (_cells(boot.game)[0] as Map)['instanceId'];
    boot.game.update((s) {
      final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List;
      cells[0] = null;
    });
    emit('player:sold', {'instanceId': sold});

    expect(_filled(boot.game), 11, reason: 'the twelfth man steps up');
    expect(
      _lineup(boot.game).any((s) => (s as Map)['cardInstanceId'] == sold),
      isFalse,
      reason: 'the sold player is out of the eleven',
    );
  });

  test('a no-op change does not rewrite the lineup', () {
    // This runs on every placement and every merge; a pointless write would
    // mark the save dirty for nothing.
    final boot = _boot();
    for (var i = 0; i < 11; i++) {
      boot.game.update((_) => placeCard(_defId, _cells(boot.game)));
    }
    final before = _lineup(boot.game);
    expect(syncLineupWithGrid(boot.game.state!), isFalse);
    expect(identical(_lineup(boot.game), before), isTrue);
  });
}
