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
    _sink(name, sanitiseAnalyticsParams(params));
  } catch (_) {
    // Deliberately swallowed — see above.
  }
}

/// **Firebase's own limits, applied at the boundary rather than at the call
/// sites.** A parameter value may be a number or a string of at most a hundred
/// characters; anything else is dropped on the floor by the SDK without saying
/// so, which is the worst way for an event to be wrong. Booleans become 1 and
/// 0 because that is what the JS sends and the dashboards are built on it.
Map<String, Object?> sanitiseAnalyticsParams(Map<String, Object?> params) => {
  for (final entry in params.entries) entry.key: _sanitise(entry.value),
};

Object _sanitise(Object? value) {
  if (value is num && value.isFinite) return value;
  if (value is bool) return value ? 1 : 0;
  final text = '${value ?? ''}';
  return text.length <= 100 ? text : text.substring(0, 100);
}

/// **Coins bucketed into bands, so a report does not explode with
/// cardinality.** The JS's own six, and its own reasoning: a raw figure is
/// useless as a dimension because almost every value is unique.
String bucketCoins(num n) {
  if (n < 100) return '<100';
  if (n < 1000) return '100-1k';
  if (n < 10000) return '1k-10k';
  if (n < 100000) return '10k-100k';
  if (n < 1000000) return '100k-1M';
  return '1M+';
}

/// Something went wrong. [fatal] is a crash rather than a handled fault.
///
/// **It is an EVENT as well as a crash report**, which is the JS's arrangement:
/// the crash reporter catches the process dying and the event is what shows up
/// beside the rest of the funnel, so a spike in errors is visible in the same
/// place as the behaviour that caused it.
///
/// **And for a long time NOTHING CALLED IT**, so the analytics half of that
/// arrangement did not exist: crashes reached Crashlytics through handlers that
/// recorded straight to the SDK, and `app_crash` never once appeared beside the
/// funnel it was meant to explain. `analytics_service.dart` routes both
/// handlers through here now, which is the only way the two halves stay in step.
///
/// [stack] is passed through to the crash sink and deliberately NOT to the
/// event: a stack trace is thousands of characters and Firebase's parameter
/// limit is a hundred, so an event carrying one would ship a truncated first
/// line and nothing useful. The symbolicated trace belongs in Crashlytics.
void logError(Object? message, {bool fatal = false, StackTrace? stack}) {
  logAppEvent(fatal ? 'app_crash' : 'app_error', {
    'description': '$message',
    'fatal': fatal,
  });
  _errors?.call(message, fatal, stack);
}

/// Where a crash report goes. Null drops them, which is what a test wants.
void Function(Object? message, bool fatal, StackTrace? stack)? _errors;

/// Send crash reports to [sink]. Returns the one being replaced.
void Function(Object?, bool, StackTrace?)? setCrashSink(
  void Function(Object?, bool, StackTrace?)? sink,
) {
  final previous = _errors;
  _errors = sink;
  return previous;
}

/// Which screen the player is on.
///
/// **Native builds report `(not set)` without this**, because the whole app is
/// one Activity — so the screen dimension, which is the one that says where
/// people are when they leave, is empty unless it is sent by hand.
void logScreen(String? screen) {
  if (screen == null || screen.isEmpty) return;
  logAppEvent('screen_view', {'screen_name': screen});
}
