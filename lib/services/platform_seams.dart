/// The three platform seams the JS reaches through Capacitor for.
///
/// Ported from `utils/openUrl.js`, `utils/wakeLock.js` and `utils/network.js`.
/// One file rather than three because they are the same shape and the same size
/// — a plugin call each, wrapped so that **every failure is a no-op rather than
/// an error**. That is the JS's arrangement in all three: a link that will not
/// open, a lock the OS refuses and a connectivity query that throws all leave
/// the game playing exactly as it did.
///
/// **Nothing else in the app imports the plugins.** Keeping them behind this
/// file is what lets a test replace the seam instead of the platform, and it is
/// why [WakeLock] and [Network] are classes with a swappable instance rather
/// than three top-level functions.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Open a URL in the SYSTEM browser, not in the app.
///
/// The JS's own note is about a WebView — a `target="_blank"` navigation is
/// dropped inside the Capacitor WKWebView, so links silently failed. There is no
/// WebView here, but the destination is the same one: `LaunchMode.externalApplication`
/// is `SFSafariViewController` on iOS and a Custom Tab on Android, which is what
/// `@capacitor/browser` opens.
///
/// Returns whether it opened. **A false is not worth surfacing** — every caller
/// is a Rate Us or a terms link, and a toast saying a browser would not start is
/// less use than the button appearing to do nothing.
Future<bool> openExternalUrl(String? url) async {
  if (url == null || url.isEmpty) return false;
  final uri = Uri.tryParse(url);
  // **Only http(s).** `launchUrl` will happily fire a `tel:`, a `mailto:` or an
  // app scheme, and every URL this game has is a store page or a policy — so an
  // unexpected scheme arriving here is a bug rather than a feature to support.
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return false;
  }
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Keep the screen awake, REFCOUNTED.
///
/// **Only the live match asks for one**, and that is the JS's reasoning rather
/// than a limit of this class: it is the one screen the player watches without
/// touching, so the phone's own sleep timer can black out mid-match. Everything
/// else in the game takes taps every few seconds.
///
/// The count is what makes it safe to ask twice — a match popup reopening over
/// one that has not finished tearing down would otherwise release a lock the
/// second one is still holding.
class WakeLock {
  WakeLock();

  int _holds = 0;

  /// In flight, so two [acquire] calls in one frame cannot both request.
  Future<void>? _pending;

  /// How many holders there are. For tests.
  int get holds => _holds;

  /// Whether the platform is holding one. For tests.
  bool get held => _held;
  bool _held = false;

  Future<void> acquire() async {
    _holds += 1;
    if (_holds != 1) return;
    await (_pending = _sync());
  }

  Future<void> release() async {
    _holds = _holds > 0 ? _holds - 1 : 0;
    if (_holds != 0) return;
    await (_pending = _sync());
  }

  /// Put the platform where the count says it should be.
  ///
  /// **The await is a gap**, which the JS learned the hard way: the match may
  /// have been closed inside it, in which case nobody is holding this any more
  /// and it goes straight back. Re-reading the count after the call rather than
  /// before is the whole of the fix.
  Future<void> _sync() async {
    final earlier = _pending;
    if (earlier != null) {
      try {
        await earlier;
      } catch (_) {
        // A refusal is not an error — see below.
      }
    }
    final want = _holds > 0;
    if (want == _held) return;
    try {
      await enable(want);
      _held = want;
    } catch (_) {
      // **Refused is a no-op, not an error.** Battery saver and OS policy both
      // decline, and the game plays exactly as it did before.
    }
  }

  /// The platform call, overridable in a test.
  Future<void> enable(bool on) => WakelockPlus.toggle(enable: on);
}

/// Whether the device thinks it has a network.
///
/// **Best effort, and true when it cannot tell** — the JS's `navigator.onLine`
/// is the same shape: it answers "is there an interface" and never "will this
/// request succeed". A captive portal reads as online in both.
///
/// The one live caller in the port is the weather reader, which treats every
/// failure as "carry on with the seasonal model" anyway; this saves it the
/// request rather than deciding anything.
class Network {
  Network();

  /// The last reading, so a caller on a hot path is not awaiting the platform.
  bool _online = true;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool get isOnline => _online;

  /// Start listening. Safe to call twice.
  Future<void> start() async {
    if (_sub != null) return;
    try {
      // **`onError` is not belt and braces.** The channel raises when there is
      // no binding under it — a plain widget test, a headless build — and a
      // stream error with no handler is an unhandled zone error rather than
      // something the try below can catch.
      _sub = Connectivity().onConnectivityChanged.listen(
        _apply,
        onError: (_) => _online = true,
        cancelOnError: false,
      );
      _apply(await Connectivity().checkConnectivity());
    } catch (_) {
      // No platform channel — a plain `dart test`, or a desktop build without
      // the plugin. Online is the safe answer: it only ever costs a request
      // that was going to fail harmlessly.
      _online = true;
    }
  }

  void _apply(List<ConnectivityResult> results) {
    _online =
        results.isEmpty || results.any((r) => r != ConnectivityResult.none);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}

/// The app's own, swapped in tests.
WakeLock wakeLock = WakeLock();
Network network = Network();
