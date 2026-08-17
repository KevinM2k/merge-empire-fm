/// The analytics call the engines make, with the backend left out.
///
/// In the JS this is `../merge-empire-fc/src/utils/analytics.js`, which reaches
/// straight for Firebase. Engines can't do that here: `lib/engine/` has to stay
/// Flutter-free so it runs under plain `dart test`, and a hard Firebase import
/// would take the whole logic core with it.
///
/// So the engines call [logAppEvent] and something else decides what that
/// means. The default sink drops everything, which is what a test wants and
/// what a build with analytics disabled wants; the services layer installs a
/// real one at boot.
library;

/// Somewhere for an app event to go.
typedef AnalyticsSink = void Function(String name, Map<String, Object?> params);

void _drop(String name, Map<String, Object?> params) {}

AnalyticsSink _sink = _drop;

/// Send app events to [sink]. Pass null to go back to dropping them.
///
/// Returns the sink being replaced, so a caller can put it back — which is how
/// a test installs a recorder for one case without leaking it into the next.
AnalyticsSink setAnalyticsSink(AnalyticsSink? sink) {
  final previous = _sink;
  _sink = sink ?? _drop;
  return previous;
}

/// Record a named event. Never throws: a broken sink must not be able to fail a
/// game action that merely happened to be worth counting.
void logAppEvent(String name, [Map<String, Object?> params = const {}]) {
  try {
    _sink(name, params);
  } catch (_) {
    // Deliberately swallowed — see above.
  }
}
