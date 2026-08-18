/// Tiny pub/sub, ported from `../merge-empire-fc/src/utils/eventBus.js`.
///
/// Every cross-cutting signal in the app rides this bus: `coins:updated`,
/// `trophies:updated`, `match:complete`, `merge:happened`, `kit:changed`,
/// `season:ended` and the rest. Grep before inventing a new event.
///
/// The bus stays here, pure, rather than being replaced wholesale by Riverpod:
/// engines emit on it and engines may not import Flutter. The UI layer
/// subscribes and republishes into Riverpod providers, which is what gives
/// widgets narrow rebuilds without dragging a Flutter dependency into the
/// engines.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

typedef BusHandler = void Function(Object? args);
typedef BusErrorHandler =
    void Function(String event, Object error, StackTrace stackTrace);

final Map<String, List<BusHandler>> _listeners = {};

void _defaultErrorHandler(String event, Object error, StackTrace stackTrace) {
  // ignore: avoid_print
  print('[eventBus] "$event" handler failed: $error');
}

BusErrorHandler _onError = _defaultErrorHandler;

/// Route handler failures somewhere other than stdout — Crashlytics in the
/// app, an assertion in tests.
void setBusErrorHandler(BusErrorHandler handler) => _onError = handler;

/// Registers [handler] for [event]. Registering the same handler twice is a
/// no-op, matching the JS `Set` semantics.
void on(String event, BusHandler handler) {
  final handlers = _listeners.putIfAbsent(event, () => <BusHandler>[]);
  if (!handlers.contains(handler)) handlers.add(handler);
}

void off(String event, BusHandler handler) {
  _listeners[event]?.remove(handler);
}

/// Drop every registration.
///
/// The app never calls this — the bus lives as long as the process. It exists
/// for tests: a handler registered in one case would otherwise still be
/// listening in the next, and a closure that captures the previous case's state
/// firing against the current one is a failure that reads as a bug in the code
/// under test.
void clearBus() => _listeners.clear();

/// How many handlers are registered for [event].
///
/// Also for tests. A subscription that outlives the thing that made it is
/// invisible from the outside — the events still arrive, they just arrive twice
/// — so the only way to assert a teardown happened is to count.
int busListenerCount(String event) => _listeners[event]?.length ?? 0;

void emit(String event, [Object? args]) {
  final handlers = _listeners[event];
  if (handlers == null || handlers.isEmpty) return;

  // Iterate a snapshot. `once` unregisters itself from inside this loop, and
  // handlers may register more — mutating the live list mid-iteration throws
  // ConcurrentModificationError in Dart where the JS Set simply coped.
  for (final handler in List<BusHandler>.of(handlers)) {
    try {
      handler(args);
    } catch (error, stackTrace) {
      // A throwing listener must not starve the ones registered after it.
      _onError(event, error, stackTrace);
    }
  }
}

/// Fires [handler] at most once. Returns a cancel function, so a listener that
/// never fires can still be torn down.
void Function() once(String event, BusHandler handler) {
  late final BusHandler wrapper;
  wrapper = (args) {
    // Unregister BEFORE calling, so a throwing handler cannot leave itself
    // armed — in the JS original the throw skipped its own `off`.
    off(event, wrapper);
    handler(args);
  };
  on(event, wrapper);
  return () => off(event, wrapper);
}

/// Drops every listener and restores the default error hook. For tests —
/// leaving a hook installed leaks one test's expectations into the next.
void resetBus() {
  _listeners.clear();
  _onError = _defaultErrorHandler;
}
