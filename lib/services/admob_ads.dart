/// Rewarded video, for real. The adapter behind `services/rewarded_ads.dart`.
///
/// **The whole chain was waiting on one override.** `ad_units.dart` has held
/// the placement ids since M4 was written and `NoRewardedAds` answered
/// `unavailable` to every one of them, which is why the shop's free shelf, the
/// double-or-nothing at full time, the quick-fire matches and the lucky boot
/// all said "coming soon".
///
/// **`unavailable` is still a real answer and the flow still has to handle it.**
/// A video fails to fill far more often than anyone expects, and the JS's path
/// for it — take the single reward, say why — is the path the screens follow
/// whether an SDK is present or not. Nothing above this file changes.
///
/// **One ad object is ONE SHOWING.** The SDK's rewarded ad is not reusable: it
/// is loaded, shown once and disposed. So a cache holds at most one preloaded
/// ad per placement and the show path always clears it — a second tap that
/// re-showed the same object would be an SDK error rather than a second video.
///
/// **NOTHING IS VERIFIED ON A DEVICE.** `flutter analyze` and the suite are the
/// only evidence in this repo and neither can exercise an ad SDK; the seam is
/// tested, the SDK's own behaviour is not. See the device pass in M6.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:merge_empire_fc/data/ad_units.dart';
import 'package:merge_empire_fc/services/ad_consent.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';

/// How long a show waits for a load before giving up and answering honestly.
///
/// **A player is looking at a button that said "watch a video".** Ten seconds of
/// nothing is a broken button; the single reward is right there behind an
/// `unavailable`.
const Duration adLoadTimeout = Duration(seconds: 10);

String adPlatform() {
  try {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
  } catch (_) {
    // No platform to ask.
  }
  return 'web';
}

/// The SDK, as a seam a test can replace.
abstract class RewardedAdLoader {
  /// Load one, or null if it will not fill.
  Future<RewardedHandle?> load(String unitId);
}

/// One loaded ad, which can be shown exactly once.
abstract class RewardedHandle {
  /// Show it. Resolves to true when the reward was earned.
  Future<bool> show();

  void dispose();
}

class _PluginLoader implements RewardedAdLoader {
  const _PluginLoader();

  @override
  Future<RewardedHandle?> load(String unitId) async {
    final done = Completer<RewardedHandle?>();
    try {
      await RewardedAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (!done.isCompleted) done.complete(_PluginHandle(ad));
          },
          onAdFailedToLoad: (_) {
            if (!done.isCompleted) done.complete(null);
          },
        ),
      );
    } catch (_) {
      if (!done.isCompleted) done.complete(null);
    }
    return done.future.timeout(adLoadTimeout, onTimeout: () => null);
  }
}

class _PluginHandle implements RewardedHandle {
  _PluginHandle(this._ad);

  final RewardedAd _ad;

  @override
  Future<bool> show() async {
    final closed = Completer<bool>();
    var earned = false;
    _ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        unawaited(ad.dispose());
        if (!closed.isCompleted) closed.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        unawaited(ad.dispose());
        if (!closed.isCompleted) closed.complete(false);
      },
    );
    try {
      // Not awaited: `show` resolves when the ad is PRESENTED, and what this
      // wants is the dismissal — which arrives on the callback above.
      unawaited(_ad.show(onUserEarnedReward: (_, _) => earned = true));
    } catch (_) {
      unawaited(_ad.dispose());
      if (!closed.isCompleted) closed.complete(false);
    }
    return closed.future;
  }

  @override
  void dispose() => unawaited(_ad.dispose());
}

class AdMobRewardedAds implements RewardedAds {
  AdMobRewardedAds({
    RewardedAdLoader? loader,
    String? platform,
    bool Function()? permitted,
  }) : _loader = loader ?? const _PluginLoader(),
       _platform = platform ?? adPlatform(),
       _permitted = permitted ?? (() => adsPermitted);

  final RewardedAdLoader _loader;
  final String _platform;

  /// **Re-read on every show, not captured at construction.** Consent can be
  /// REVOKED from Settings mid-session, and an adapter built while it was
  /// granted would carry on serving afterwards.
  final bool Function() _permitted;

  /// At most one warmed ad per placement — see the note on single showings.
  final Map<String, RewardedHandle> _ready = {};

  /// In-flight loads, so a prepare followed by a show does not load twice.
  final Map<String, Future<RewardedHandle?>> _loading = {};

  @override
  void prepare(String placement) {
    if (_ready.containsKey(placement) || _loading.containsKey(placement)) return;
    // Never awaited: a prefetch that fails must not hold up the thing that
    // asked for it.
    unawaited(_load(placement));
  }

  Future<RewardedHandle?> _load(String placement) {
    final unit = rewardedUnitFor(_platform, placement);
    if (unit == null) return Future.value(null);
    final future = _loader.load(unit).then((handle) {
      _loading.remove(placement);
      if (handle != null) _ready[placement] = handle;
      return handle;
    });
    _loading[placement] = future;
    return future;
  }

  @override
  Future<AdOutcome> show(String placement) async {
    // **Consent first, and a refusal is `unavailable` rather than an error.**
    // Serving without it in the EEA is the thing the gate exists to stop.
    if (!_permitted()) return AdOutcome.unavailable;

    var handle = _ready.remove(placement);
    handle ??= await (_loading[placement] ?? _load(placement));
    // A load that resolved into the cache while we awaited it is the same
    // object — take it out so nothing shows it twice.
    _ready.remove(placement);
    if (handle == null) return AdOutcome.unavailable;

    final earned = await handle.show();
    // And line up the next one while the player is still on the screen that
    // asked for this one.
    prepare(placement);
    return earned ? AdOutcome.rewarded : AdOutcome.dismissed;
  }
}

/// Start the SDK, once, after consent has been resolved.
///
/// Order is not a preference: `MobileAds.initialize` may request an ad before
/// the consent answer exists if it goes first.
Future<RewardedAds> startAds() async {
  try {
    await initAdConsent();
    if (!adsPermitted) return const NoRewardedAds();
    await MobileAds.instance.initialize();
    return AdMobRewardedAds();
  } catch (_) {
    // No SDK on this platform. Every placement answers `unavailable`, honestly.
    return const NoRewardedAds();
  }
}
