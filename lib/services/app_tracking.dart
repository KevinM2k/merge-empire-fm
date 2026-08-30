/// Apple's App Tracking Transparency prompt — the iOS half of the ad stack.
///
/// **UMP is not this, and having one is not having the other.** `ad_consent.dart`
/// asks Google's consent question, which is the EEA's; this asks Apple's, which
/// is every iOS device's regardless of region. They are separate prompts with
/// separate APIs, separate answers and separate consequences, and
/// `google_mobile_ads` exposes only the first — so a build with UMP wired and
/// nothing here has `NSUserTrackingUsageDescription` sitting in `Info.plist`
/// being read by nobody.
///
/// **What it costs to skip, which is why this exists.** Without an authorised
/// ATT status the IDFA is unavailable, so on iOS:
///
/// - every ad served is CONTEXTUAL rather than personalised, which is the
///   difference between a filled impression and a well-paid one;
/// - the fifty `SKAdNetworkItems` already in `Info.plist` still attribute the
///   install, but nothing links a player to the campaign that brought them;
/// - Firebase can measure the session and not where it came from.
///
/// None of that fails loudly. The ads keep serving, the dashboards keep
/// filling, and the number that moves is eCPM — which is why it went unnoticed
/// until someone went looking.
///
/// **ORDER, and it is Google's own.** UMP first, then ATT, then the first ad
/// request: the SDK reads the tracking status when it initialises, so a prompt
/// answered afterwards does not apply until the next launch. [startAds] calls
/// these in that order.
///
/// **Nothing here throws and nothing here blocks a boot.** No plugin, an
/// Android device, an iOS 14-or-below device, a managed device that forbids the
/// prompt: all the same outcome, which is [TrackingStatus.notSupported] and an
/// ad stack that carries on serving contextually.
library;

import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:merge_empire_fc/util/analytics.dart';

/// How long the prompt is given to be answered before the ad stack gives up
/// waiting on it.
///
/// **A player who walks away mid-prompt must not strand the ad SDK.** The
/// system dialog is modal and its future does not complete until it is
/// dismissed; the same reasoning that keeps the UMP form off the launch splash
/// applies here, one layer down. On a timeout the status is simply whatever it
/// was, which is the honest answer — the prompt is still on screen and iOS will
/// remember the eventual reply for the next launch.
const Duration trackingPromptTimeout = Duration(seconds: 30);

/// The last status this process saw. `notSupported` until something asks.
TrackingStatus _status = TrackingStatus.notSupported;

/// What Apple last said. Cached so a caller can read it synchronously.
TrackingStatus get trackingStatus => _status;

/// Whether the IDFA is available, and so whether an ad can be personalised.
bool get trackingAuthorised => _status == TrackingStatus.authorized;

/// The seam a test replaces — the plugin's two statics, as an object.
abstract class TrackingPrompt {
  Future<TrackingStatus> status();

  Future<TrackingStatus> request();
}

class _PluginPrompt implements TrackingPrompt {
  const _PluginPrompt();

  @override
  Future<TrackingStatus> status() =>
      AppTrackingTransparency.trackingAuthorizationStatus;

  @override
  Future<TrackingStatus> request() =>
      AppTrackingTransparency.requestTrackingAuthorization();
}

/// Ask once, and only when there is something to ask.
///
/// **`notDetermined` is the ONLY state that prompts.** Apple shows the dialog
/// once per install and returns the standing answer forever after, so a
/// re-request on a `denied` device is a round trip that changes nothing — and
/// on a `restricted` one there is no dialog to show at all. Reading the status
/// first is also what makes this safe to call on every boot.
///
/// Returns the status the ad SDK should initialise against.
Future<TrackingStatus> requestTrackingIfNeeded({TrackingPrompt? prompt}) async {
  final att = prompt ?? const _PluginPrompt();
  try {
    _status = await att.status();
    if (_status == TrackingStatus.notDetermined) {
      _status = await att
          .request()
          .timeout(trackingPromptTimeout, onTimeout: () => _status);
    }
  } catch (_) {
    // No plugin, or a platform without the prompt. Contextual ads, honestly.
    _status = TrackingStatus.notSupported;
  }
  // **The answer is worth a dimension of its own.** Opt-in rate is the number
  // that explains an iOS eCPM, and it is not derivable from anything else the
  // app reports.
  logAppEvent('att_status', {'status': _status.name});
  return _status;
}
