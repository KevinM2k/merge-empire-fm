/// The listeners that turn an engine's announcement into a change to the save.
/// Ported from the bus wiring in `../merge-empire-fc/src/main.js`.
///
/// This is not a formality. Several engines deliberately do NOT apply their own
/// reward: the achievement engine says so in as many words — "the coin grant is
/// applied by the listener, which has the mutation wrapper needed to trigger a
/// save". Without that listener every achievement in the game unlocks, announces
/// itself, and pays nothing.
///
/// Only the listeners that change the SAVE live here. The ones that show a
/// toast, play a sound or log an analytics event belong to the layer that has a
/// screen and a speaker, and they subscribe to the same bus.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/engine/achievement_engine.dart';
import 'package:merge_empire_fc/engine/badge_engine.dart';
import 'package:merge_empire_fc/engine/lineup_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

/// The card on a bus payload, however it was put there.
///
/// The engines emit a `CardInstance`; a test — and any future emitter reading
/// straight off the save — has the raw map. Both are the same card, and a
/// listener that accepted only one would silently ignore half the traffic,
/// which is invisible until the Index stays empty.
CardInstance? _cardIn(Object? value) =>
    value is CardInstance ? value : CardInstance.from(value);

/// Record that the player has now SEEN this card.
///
/// The count goes up every time; the discovery list is a set, so only the first
/// one announces. Both live under `progression` and both are written to the
/// save, so the whole thing runs inside one `update`.
void _recordDiscovery(Map<String, dynamic> state, CardInstance card) {
  final prog = _map(state['progression']);
  if (prog == null) return;
  if (prog['discoveredPlayers'] is! List) {
    prog['discoveredPlayers'] = <dynamic>[];
  }
  if (prog['playerFoundCounts'] is! Map<String, dynamic>) {
    prog['playerFoundCounts'] = <String, dynamic>{};
  }
  final discovered = prog['discoveredPlayers'] as List<dynamic>;
  final counts = prog['playerFoundCounts'] as Map<String, dynamic>;
  final key = card.discoveryKey;

  counts[key] = (_num(counts[key]) ?? 0).toInt() + 1;
  if (!discovered.contains(key)) {
    discovered.add(key);
    emit('playerindex:discovered', key);
  }
}

/// Subscriptions that can be undone, so a test — or a reset — can start again.
class GameWiring {
  GameWiring(this._game);

  final GameState _game;
  final List<({String event, BusHandler handler})> _handlers = [];

  void _listen(String event, BusHandler handler) {
    on(event, handler);
    _handlers.add((event: event, handler: handler));
  }

  /// Register every listener that writes to the save.
  void attach() {
    // The achievement engine announces an unlock and grants nothing. This is
    // the half that pays.
    _listen('achievement:unlocked', (args) {
      final def = _map(args);
      final coins = _num(def?['coinsRewarded']) ?? 0;
      if (coins > 0) {
        _game.update((s) {
          final resources = _map(s['resources']);
          if (resources == null) return;
          resources['fanCoins'] = (_num(resources['fanCoins']) ?? 0) + coins;
        });
        emit('coins:updated', _map(_game.state?['resources'])?['fanCoins']);
      }
      // Move the auto-tracked badge to this newest achievement. A no-op once
      // the player has chosen one by hand.
      _game.update((s) => autoEquipLatestBadge(s));
    });

    // The lifetime high-water mark for coins, so the "earn N coins"
    // achievements still fire for a player who spent back below the threshold.
    _listen('coins:updated', (args) {
      final coins = _num(args);
      if (coins == null) return;
      final state = _game.state;
      if (state == null) return;
      final stats = _map(state['stats']);
      if (stats == null) return;
      if (coins > (_num(stats['maxCoinsReached']) ?? 0)) {
        stats['maxCoinsReached'] = coins;
      }
    });

    // The Player Index's only writer.
    //
    // `main.js` records a discovery on the two events that put a card in front
    // of the player — scouting one and merging one — and the port had neither.
    // Without it `discoveredPlayers` never grows: the Index would read 0 of 66
    // forever, and the season quest that counts discoveries could never
    // advance. Both engines already announce; this is the half that writes.
    for (final event in const ['card:placed', 'merge:complete']) {
      _listen(event, (args) {
        final payload = _map(args);
        // `card:placed` carries `card`, `merge:complete` carries `newCard`.
        final card = _cardIn(payload?['card'] ?? payload?['newCard']);
        if (card == null || card.definitionId.isEmpty) return;
        _game.update((s) => _recordDiscovery(s, card));
      });
    }

    // Keep the stored eleven in step with the grid.
    //
    // Every screen fills the lineup on the way OUT, so a fresh save showed a
    // full side while `squad.lineup` was empty — and `canPlayMatch` counts the
    // stored slots, so a player with eleven scouted men was told their squad
    // was too small by the screen that had just drawn them.
    for (final event in const [
      'card:placed',
      'merge:complete',
      'player:sold',
      'transfer:accepted',
    ]) {
      _listen(event, (_) => _game.update(syncLineupWithGrid));
    }

    // The achievement sweep, after every announcement that could unlock
    // something. It is a sweep rather than a subscription precisely so this
    // list can be short and dumb.
    for (final event in const [
      'match:complete',
      'season:ended',
      'merge:happened',
      'scout:placed',
      'player:sold',
      'transfer:accepted',
      'transfer:declined',
      'sponsor:declined',
      'coins:updated',
      'cup:won',
      // **Three achievements could never unlock**, because nothing swept after
      // a reset: `prestige_level_1`, `prestige_level_3` and
      // `reset_after_prestige` are all read off the level `performPrestige`
      // has just written. It clears `achievementIdsThisRun` on its way out and
      // emits last, so a sweep on this event sees the new adventure rather
      // than the finished one.
      'prestige:complete',
    ]) {
      _listen(event, (args) {
        final state = _game.state;
        if (state == null) return;
        checkAchievements(state, (type: event, data: _map(args)));
      });
    }
  }

  /// The boot sweep, and the badge that goes with it.
  ///
  /// Run here as well as in the unlock listener so a save whose achievements
  /// were unlocked by an older build still gets its badge set on load.
  void bootSweep() {
    final state = _game.state;
    if (state == null) return;
    checkAchievements(state);
    autoEquipLatestBadge(state);
  }

  /// Drop every listener this registered, and nothing else. A second [attach]
  /// on a live bus would double every grant.
  void detach() {
    for (final h in _handlers) {
      off(h.event, h.handler);
    }
    _handlers.clear();
  }
}
