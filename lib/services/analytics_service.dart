/// The analytics and crash-reporting backend — the half of
/// `../merge-empire-fc/src/utils/analytics.js` that talks to Firebase.
///
/// **This is the ONE place the port takes the Firebase SDK**, and it is worth
/// saying why given that `data/firebase_config.dart` argues at length for not
/// taking it anywhere else. Firestore and Auth go over plain HTTPS because the
/// SDK's transport is the thing that fails in the environment the JS ships in,
/// and REST is strictly simpler. Neither of these two has that option:
///
/// - **A crash reporter has to be native.** Its whole job is to survive the
///   process dying — an out-of-memory kill, a renderer crash — and record what
///   happened. Nothing written in Dart can report its own SIGKILL.
/// - **Analytics has no REST route from here.** The Measurement Protocol needs
///   an api_secret generated in the console, which is not in either repo, and
///   inventing one is not a thing a port can do.
///
/// **Dev builds send NOTHING**, which is the JS's own first line: production
/// dashboards stay clean, and a developer running the game for an afternoon
/// does not look like a very engaged player.
///
/// **Every failure here is silent and total.** Analytics that will not start
/// must not stop a game booting, so each step is guarded on its own and a
/// missing plugin leaves the default sink — which drops everything — exactly
/// where it was.
library;

import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:merge_empire_fc/util/analytics.dart';

/// Whether this build reports at all. A variable so a test can turn it on.
bool analyticsEnabled = kReleaseMode;

/// Bring the backend up and point [logAppEvent] at it.
///
/// Safe to call twice: `Firebase.initializeApp` is idempotent and the sink is
/// simply replaced with an equivalent one.
Future<void> startAnalytics() async {
  if (!analyticsEnabled) return;
  try {
    // The native config — `google-services.json` and `GoogleService-Info.plist`
    // — is what this reads. Both are the shipped app's own, copied across.
    await Firebase.initializeApp();
  } catch (_) {
    // No Firebase, no analytics. The game is unaffected.
    return;
  }

  try {
    final analytics = FirebaseAnalytics.instance;
    await analytics.setAnalyticsCollectionEnabled(true);
    setAnalyticsSink((name, params) {
      // **Fire and forget, and never awaited.** An event is a side note; a
      // game action must not wait on a network library to acknowledge one.
      unawaited(
        analytics
            .logEvent(name: name, parameters: _parameters(params))
            .catchError((_) {}),
      );
    });
  } catch (_) {
    // Leave the default sink, which drops.
  }

  try {
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(true);
    setCrashSink((message, fatal) {
      unawaited(
        crashlytics
            .recordError(message, null, fatal: fatal)
            .catchError((_) {}),
      );
    });
    _catchEverything(crashlytics);
  } catch (_) {
    // Crash reporting is best-effort: a missing pod or an older native build
    // must not take analytics down with it. The JS says the same.
  }
}

/// **The two handlers that catch what nothing else does.**
///
/// `FlutterError.onError` is a fault inside the framework — a bad build, a
/// layout that overflowed into an exception — and `PlatformDispatcher.onError`
/// is an unhandled error from anywhere else, including an async gap that no
/// `try` surrounds. Between them they are the errors nobody wrote a `catch`
/// for, which is exactly the set worth reporting.
void _catchEverything(FirebaseCrashlytics crashlytics) {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    crashlytics.recordFlutterFatalError(details);
    // Still printed to the console: a report going somewhere else is no reason
    // for a developer to stop seeing it.
    previous?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };
}

/// Firebase takes only strings and numbers, which is what
/// [sanitiseAnalyticsParams] has already reduced these to — this is the cast.
Map<String, Object> _parameters(Map<String, Object?> params) => {
  for (final entry in params.entries)
    if (entry.value case final Object value) entry.key: value,
};
