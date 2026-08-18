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
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

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
