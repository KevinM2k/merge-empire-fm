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
/// **`screen_class` rides along with it.** GA4's screen reports group by the
/// class and fall back to the name, so a build that sends only the name leaves
/// half of every screen report empty. The JS sends both — `screenClassOverride`
/// on native, the two reserved params on web — for exactly that reason.
///
/// The name is also kept for [currentScreen], because the one dimension
/// `app_backgrounded` needs is where the player was when they left.
void logScreen(String? screen) {
  if (screen == null || screen.isEmpty) return;
  _currentScreen = screen;
  logAppEvent('screen_view', {
    'screen_name': screen,
    'screen_class': screen,
  });
}

String? _currentScreen;

/// The last screen [logScreen] was told about, or null before the first one.
///
/// Read by the session events rather than tracked a second time beside them:
/// the JS keeps its own `_activeTab` off a bus event, which is a second copy of
/// a fact this function already has and a second place for it to go stale.
String? get currentScreen => _currentScreen;

/// Forget the current screen. For tests, which must not leak one into the next.
void resetCurrentScreen() => _currentScreen = null;

/// Where a user-scoped dimension goes. Null drops them, which is what a test
/// wants.
void Function(String key, Object? value)? _props;

/// Where the stable player id goes. Null drops it.
void Function(String id)? _userId;

/// A user id set before the backend was ready, applied once it is.
///
/// The JS caches one for the same reason: `setAnalyticsUserId` is called from
/// the boot path with the save in hand, and `initAnalytics` is a network-shaped
/// future that has usually not resolved yet. Without the cache the id was set
/// on a sink that dropped it, and every session started anonymous.
String? _pendingUserId;

/// Send user properties to [sink]. Returns the one being replaced.
void Function(String, Object?)? setUserPropsSink(
  void Function(String, Object?)? sink,
) {
  final previous = _props;
  _props = sink;
  return previous;
}

/// Send the user id to [sink]. Returns the one being replaced.
///
/// Installing a sink flushes any id cached before it arrived.
void Function(String)? setUserIdSink(void Function(String)? sink) {
  final previous = _userId;
  _userId = sink;
  if (sink != null && _pendingUserId != null) {
    final id = _pendingUserId!;
    _pendingUserId = null;
    try {
      sink(id);
    } catch (_) {
      // Best-effort, as everywhere else here.
    }
  }
  return previous;
}

/// **The dimensions every event in the session is sliced BY.**
///
/// An event says what happened; a user property says who it happened to, and
/// without them a funnel cannot answer the only question anyone asks of one —
/// whether the players dropping out are the new ones or the established ones.
/// Firebase caps a property at 24 per project, so this is a small fixed set:
/// `current_division`, `total_seasons`, `is_vip`, `prestige_level`,
/// `game_mode`, `signed_in`. The JS's own six.
///
/// **`game_mode` sends `standard` for Casual**, not `casual`. The mode was
/// renamed in the UI and the event value deliberately was not, so the funnel
/// stays comparable with everything recorded before the rename — the same rule
/// the `difficulty_switch` event follows. See the JS's `CLAUDE.md`.
void setUserProps(Map<String, Object?> props) {
  final sink = _props;
  if (sink == null) return;
  for (final entry in props.entries) {
    try {
      sink(entry.key, _sanitise(entry.value));
    } catch (_) {
      // Deliberately swallowed — a broken sink must not fail a game action.
    }
  }
}

/// **The retention identity, which survives what the automatic one does not.**
///
/// Pass the stable per-player id (`state.leaderboard.playerId` — a UUID minted
/// on first boot and cloud-synced), NOT the auth uid: `playerId` exists for
/// every player from the first session including those who never sign in, so
/// cohorts stitch across app-instance-id resets, updates, reinstalls and
/// platforms. Requires GA4 Reporting Identity = Blended.
///
/// Safe to call before the backend is up — see [_pendingUserId].
void setAnalyticsUserId(Object? userId) {
  final id = '${userId ?? ''}';
  if (id.isEmpty) return;
  final trimmed = id.length <= 256 ? id : id.substring(0, 256);
  final sink = _userId;
  if (sink == null) {
    _pendingUserId = trimmed;
    return;
  }
  try {
    sink(trimmed);
  } catch (_) {
    // Best-effort.
  }
}
