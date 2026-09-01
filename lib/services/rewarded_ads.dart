/// Rewarded video, as one seam.
///
/// **There is no ad SDK in this project yet.** `lib/data/ad_units.dart` has held
/// the AdMob placement ids since M4 was written and nothing has ever been able
/// to show one — which is why the shop's free shelf, the double-or-nothing at
/// full time, the quick-fire matches and the lucky boot all say "coming soon".
///
/// This is the shape the SDK will plug into, and it is not a placeholder for the
/// UI: [AdOutcome.unavailable] is a real answer the flow has to handle anyway.
/// A video fails to fill more often than anyone expects, and the JS's own path
/// for it — toast, then take the single reward — is the path the screens follow
/// here whether the SDK is present or not. When AdMob lands, one override in
/// [rewardedAdsProvider] turns the whole chain on.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What came of asking for one.
enum AdOutcome {
  /// Watched to the end. The reward is owed.
  rewarded,

  /// Closed early, or the player backed out. Nothing is owed.
  dismissed,

  /// No fill, no network, or no SDK. Nothing is owed and the player is not at
  /// fault, so the copy says so.
  unavailable,
}

abstract class RewardedAds {
  /// Show one for [placement] — a key from `ad_units.dart`.
  Future<AdOutcome> show(String placement);

  /// Warm one up, when the screen can see the offer coming. Never awaited: a
  /// prefetch that fails must not hold up the thing that asked for it.
  void prepare(String placement);

  /// Throw away a warm ad that has gone stale and load a fresh one.
  ///
  /// **A loaded rewarded ad expires**, so the one warmed before the player put
  /// the phone down is not the one that will show an hour later — it fails at
  /// the moment of the tap, which reads as a broken button. Called on app
  /// resume; a slot that is still fresh is left alone, so this is free when it
  /// is not needed.
  void refresh();
}

/// The one that ships today. Every placement is unavailable, honestly.
class NoRewardedAds implements RewardedAds {
  const NoRewardedAds();

  @override
  Future<AdOutcome> show(String placement) async => AdOutcome.unavailable;

  @override
  void prepare(String placement) {}

  @override
  void refresh() {}
}

/// The adapter to hold while the SDK behind it is still starting.
///
/// **Boot must not wait on ads.** Starting them shows the UMP consent form, and
/// that future only completes when the player DISMISSES it — awaited before
/// `runApp`, it held the app on the launch splash for as long as the form was
/// up, which on a device where the form never rendered was forever.
///
/// A tap that lands first waits [settle] for the real adapter rather than being
/// told "coming soon"; a start that never answers is not cached, so the next
/// tap asks again.
class PendingRewardedAds implements RewardedAds {
  PendingRewardedAds(this._ready, {this.settle = const Duration(seconds: 8)});

  final Future<RewardedAds> _ready;
  final Duration settle;
  RewardedAds? _live;

  Future<RewardedAds> _adapter() async {
    final live = _live;
    if (live != null) return live;
    try {
      return _live = await _ready.timeout(settle);
    } catch (_) {
      return const NoRewardedAds();
    }
  }

  @override
  Future<AdOutcome> show(String placement) async =>
      (await _adapter()).show(placement);

  @override
  void prepare(String placement) =>
      unawaited(_adapter().then((ads) => ads.prepare(placement)));

  @override
  void refresh() => unawaited(_adapter().then((ads) => ads.refresh()));
}

final rewardedAdsProvider = Provider<RewardedAds>(
  (ref) => const NoRewardedAds(),
);

/// The video that is up, and whether it has been up long enough to say so.
///
/// `placement` is what disables the buttons; `slow` is what puts a spinner on
/// the one that was tapped. They are separate because they answer on different
/// schedules — see [watchRewardedAd].
typedef AdBusy = ({String placement, bool slow});

/// The rewarded ad currently in flight, anywhere in the app, or null.
///
/// **One flag for the whole app rather than one per screen.** Three of the six
/// offers had a busy field of their own and three had nothing, so the shop's
/// free shelf and the energy sheet could both be double-tapped into two videos
/// against one reward. It is app-wide rather than per-screen because the offers
/// are not independent: the daily sheet's own comment already says so — "the
/// sheet is one decision and two of them in flight is two claims against one
/// day" — and one warm ad cannot serve two taps anyway.
final adBusyProvider = StateProvider<AdBusy?>((ref) => null);

/// How long a tap may sit there before it earns a spinner.
///
/// **A warm ad opens on the tap**, and a spinner shown unconditionally is a
/// one-frame flicker on every single offer. Only a tap that is actually waiting
/// on a load — a cold slot, a stale one, a no-fill — reaches this.
const Duration adSpinnerDelay = Duration(milliseconds: 150);

/// Show a video for [placement], with the button held shut while it runs.
///
/// **The one entry point every offer goes through.** A second tap while one is
/// in flight is answered [AdOutcome.dismissed] without reaching the SDK — which
/// is the outcome that pays nothing and says nothing, and is what a double tap
/// should do. Nothing is logged for it either: a tap that never asked for an ad
/// is not an ad that failed.
Future<AdOutcome> watchRewardedAd(WidgetRef ref, String placement) async {
  final busy = ref.read(adBusyProvider.notifier);
  if (busy.state != null) return AdOutcome.dismissed;
  busy.state = (placement: placement, slow: false);
  final spinner = Timer(adSpinnerDelay, () {
    if (busy.mounted && busy.state?.placement == placement) {
      busy.state = (placement: placement, slow: true);
    }
  });
  try {
    return await ref.read(rewardedAdsProvider).show(placement);
  } finally {
    // **In a `finally`, because a stuck flag is a dead button.** The show path
    // catches its own failures, but a throw from anywhere above here would
    // otherwise leave every offer in the app disabled for the session. The
    // `mounted` guard is for the container going away under a video that is
    // still running, which a widget test does routinely.
    spinner.cancel();
    if (busy.mounted) busy.state = null;
  }
}
