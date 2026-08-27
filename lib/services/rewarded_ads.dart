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
}

/// The one that ships today. Every placement is unavailable, honestly.
class NoRewardedAds implements RewardedAds {
  const NoRewardedAds();

  @override
  Future<AdOutcome> show(String placement) async => AdOutcome.unavailable;

  @override
  void prepare(String placement) {}
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
}

final rewardedAdsProvider = Provider<RewardedAds>(
  (ref) => const NoRewardedAds(),
);
