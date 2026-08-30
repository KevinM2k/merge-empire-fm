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
import 'package:merge_empire_fc/services/app_tracking.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';
import 'package:merge_empire_fc/util/analytics.dart';

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
    if (!_permitted()) return _report(placement, AdOutcome.unavailable);

    var handle = _ready.remove(placement);
    handle ??= await (_loading[placement] ?? _load(placement));
    // A load that resolved into the cache while we awaited it is the same
    // object — take it out so nothing shows it twice.
    _ready.remove(placement);
    if (handle == null) return _report(placement, AdOutcome.unavailable);

    final earned = await handle.show();
    // And line up the next one while the player is still on the screen that
    // asked for this one.
    prepare(placement);
    return _report(
      placement,
      earned ? AdOutcome.rewarded : AdOutcome.dismissed,
    );
  }

  /// **Every ask, answered on the record.** The three outcomes are three
  /// different problems and the dashboard cannot tell them apart without this:
  /// `rewarded` is the funnel working, `dismissed` is a player choosing to walk
  /// away from a reward, and `unavailable` is inventory or consent failing them
  /// — which reads to the player as a broken button and to AdMob as nothing at
  /// all. The placement is the dimension the ad units were split up FOR.
  ///
  /// `personalised` rides along because it is the other half of an eCPM: on iOS
  /// a fill rate is not comparable between an ATT-authorised device and a
  /// contextual one. See `services/app_tracking.dart`.
  AdOutcome _report(String placement, AdOutcome outcome) {
    // **THREE NAMES, which are the JS's three.** One event with an `outcome`
    // param is the tidier shape and it is the wrong one here: FC has been
    // sending `ad_watched`, `ad_dismissed` and `ad_failed` into this same
    // Firebase project for the life of the app, and the port ships as an
    // UPDATE to it. A single renamed event would leave all three historical
    // series flat from the update onwards — see the head of
    // `services/analytics_wiring.dart`.
    //
    // `type` is the JS's too, and it is load-bearing: a rewarded ad the player
    // chose to watch and an interstitial they were shown are different funnels
    // that would otherwise be summed into one impression count.
    //
    // `ad_platform` and `personalised` have no JS counterpart and stay. They
    // are additions to the event rather than a rename of it, and the second is
    // half of an eCPM — on iOS a fill rate is not comparable between an
    // ATT-authorised device and a contextual one.
    const names = {
      AdOutcome.rewarded: 'ad_watched',
      AdOutcome.dismissed: 'ad_dismissed',
      AdOutcome.unavailable: 'ad_failed',
    };
    logAppEvent(names[outcome] ?? 'ad_failed', {
      'placement': placement,
      'type': 'rewarded',
      'outcome': outcome.name,
      'ad_platform': _platform,
      'personalised': trackingAuthorised,
    });
    return outcome;
  }
}

/// Start the SDK, once, after consent has been resolved.
///
/// Order is not a preference: `MobileAds.initialize` may request an ad before
/// the consent answer exists if it goes first.
Future<RewardedAds> startAds({
  ({bool tagForChildDirectedTreatment, bool tagForUnderAgeOfConsent})? ageFlags,
}) async {
  try {
    await initAdConsent();
    if (!adsPermitted) {
      logAppEvent('ad_stack_blocked', {'reason': 'consent'});
      return const NoRewardedAds();
    }
    // **ATT AFTER UMP AND BEFORE THE FIRST REQUEST**, which is Google's own
    // order and is not a preference either: the SDK reads the tracking status
    // when it initialises, so a prompt answered after `initialize` does not
    // apply until the next launch. Without this the IDFA is never available and
    // every iOS impression is contextual. See `services/app_tracking.dart`.
    await requestTrackingIfNeeded();
    // **THE AGE FLAGS GO ON BEFORE THE FIRST REQUEST, not after.** They are a
    // property of the SDK's request configuration rather than of an ad, so a
    // request made before they are set is served untagged — and for a player
    // Google Play has identified as a child that is the one request that must
    // not happen. See `engine/age_verification.dart`; on every device with no
    // signal both flags are false and this is the default configuration.
    if (ageFlags != null) await applyAgeFlagsToAds(ageFlags);
    await MobileAds.instance.initialize();
    return AdMobRewardedAds();
  } catch (_) {
    // No SDK on this platform. Every placement answers `unavailable`, honestly.
    logAppEvent('ad_stack_blocked', {'reason': 'unavailable'});
    return const NoRewardedAds();
  }
}

/// Tag the SDK for a child or a teen.
///
/// **Separate from [startAds] because the answer arrives LATER than the SDK
/// does.** The signal is a query against the save, and the save is not loaded
/// until the game host boots — which is after `main` has already started the
/// ads. So the flags are applied twice over an app's life: whatever the last
/// boot knew, at start-up, and the fresh answer as soon as there is one.
///
/// Both false is the default configuration and is what every device with no
/// signal gets, which is every device outside Texas.
Future<void> applyAgeFlagsToAds(
  ({bool tagForChildDirectedTreatment, bool tagForUnderAgeOfConsent}) flags,
) async {
  try {
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        tagForChildDirectedTreatment: flags.tagForChildDirectedTreatment
            ? TagForChildDirectedTreatment.yes
            : TagForChildDirectedTreatment.unspecified,
        tagForUnderAgeOfConsent: flags.tagForUnderAgeOfConsent
            ? TagForUnderAgeOfConsent.yes
            : TagForUnderAgeOfConsent.unspecified,
      ),
    );
  } catch (_) {
    // No SDK on this platform. Nothing to tag, and nothing to report.
  }
}
