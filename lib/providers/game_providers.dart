/// The bridge between the save — one big mutable map — and the widget tree.
///
/// Riverpod stops at this file in one direction: nothing under `lib/engine`,
/// `lib/data`, `lib/state` or `lib/util` knows it exists, and the architecture
/// test enforces that. What those layers offer instead is [GameState.changes],
/// a bare "something moved" signal, because a single mutable map gives a
/// reactive layer nothing to diff.
///
/// So the shape here is: one revision counter fed by that signal, and a
/// derived provider per thing a widget cares about. Each derived provider
/// recomputes on every change but only NOTIFIES when its own value differs, so
/// a coin landing rebuilds the coin label and nothing else. That is the whole
/// trick — do not have widgets watch the save map directly, because the map is
/// the same instance every time and `==` will never fire.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/state/game_runner.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/game_tick.dart';
import 'package:merge_empire_fc/state/save_store.dart';

/// Where the save is kept. Overridden at boot with the platform-backed store;
/// a test overrides it with a [MemorySaveStore].
///
/// It has no default on purpose: silently falling back to memory would mean a
/// build that looks fine and loses every player's progress on exit.
final saveStoreProvider = Provider<SaveStore>((ref) {
  throw UnimplementedError('override saveStoreProvider at boot');
});

/// The save itself.
final gameProvider = Provider<GameState>((ref) {
  final game = GameState(store: ref.watch(saveStoreProvider));
  ref.onDispose(game.dispose);
  return game;
});

/// What the screen is currently doing, which decides what a tick may start.
/// Screens that take over — the match, a mini-game, a transfer sheet — set this
/// while they are up.
final tickGatesProvider = StateProvider<TickGates>((ref) => clearScreen);

/// The app is in the background. Set by the lifecycle observer.
final appHiddenProvider = StateProvider<bool>((ref) => false);

/// The loop, the listeners and the timer.
final gameRunnerProvider = Provider<GameRunner>((ref) {
  final runner = GameRunner(
    game: ref.watch(gameProvider),
    gates: () => ref.read(tickGatesProvider),
    hidden: () => ref.read(appHiddenProvider),
  );
  ref.onDispose(() {
    runner.stop();
    runner.wiring.detach();
  });
  return runner;
});

/// Bumped once per change to the save.
///
/// Every derived provider below hangs off this. It is deliberately the only
/// thing subscribed to the raw signal: a hundred widgets each holding their own
/// stream subscription to the same broadcast controller is a hundred
/// subscriptions to tear down on every navigation.
final saveRevisionProvider = NotifierProvider<SaveRevision, int>(
  SaveRevision.new,
);

class SaveRevision extends Notifier<int> {
  @override
  int build() {
    final sub = ref.watch(gameProvider).changes.listen((_) => state++);
    ref.onDispose(sub.cancel);
    return 0;
  }
}

/// Define a provider for one thing a widget cares about.
///
/// [pick] runs on every change and its result is compared with the last one, so
/// the widgets watching it rebuild only when THAT value moved. Keep the picks
/// cheap and keep them returning values with a useful `==` — a fresh list or
/// map every time defeats the whole arrangement.
Provider<T> savePick<T>(T Function(Map<String, dynamic> save) pick) {
  return Provider<T>((ref) {
    ref.watch(saveRevisionProvider);
    final state = ref.watch(gameProvider).state;
    return pick(state ?? const <String, dynamic>{});
  });
}

Map<String, dynamic> _map(Object? v) =>
    v is Map<String, dynamic> ? v : const <String, dynamic>{};
num _num(Object? v) => v is num ? v : 0;

/// The handful the shell needs. Screens add their own next to these rather than
/// reading the save map directly.
final coinsProvider = savePick<num>(
  (s) => _num(_map(s['resources'])['fanCoins']),
);
final gemsProvider = savePick<num>((s) => _num(_map(s['resources'])['gems']));
final energyProvider = savePick<num>((s) => _num(_map(s['energy'])['current']));
final trophiesProvider = savePick<num>(
  (s) => _num(_map(s['resources'])['trophies']),
);
final clubNameProvider = savePick<String>(
  (s) => s['clubName'] is String ? s['clubName'] as String : '',
);
final currentDivisionProvider = savePick<String>((s) {
  final id = _map(s['progression'])['currentDivision'];
  return id is String ? id : '';
});
final hardModeProvider = savePick<bool>(
  (s) => _map(s['settings'])['hardMode'] == true,
);
