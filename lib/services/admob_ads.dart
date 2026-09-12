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
/// whether an SDK is present or not. The saying-why is now one line in
/// [watchRewardedAd] rather than eight screens each remembering to.
///
/// **NOTHING IS PRELOADED.** There was one warm ad for the whole app, primed by
/// six screens and topped up on every resume, and it is gone: a single global
/// slot meant a request spent on whichever offer the player happened to walk
/// past, sitting there going off — AdMob expires a loaded rewarded ad about an
/// hour after it loads and says nothing about it, so a tap on a stale slot
/// failed at the moment of the tap and arrived as a dismissal nobody made. The
/// staleness clock, the resume refresh and the per-screen priming all existed
/// to manage that one slot. Now the load happens on the tap that wants it, the
/// button says so while it runs, and there is no window in which anything can
/// go off.
///
/// **One ad object is ONE SHOWING.** The SDK's rewarded ad is not reusable: it
/// is loaded, shown once and disposed — which is now the only life it has.
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
  /// Show it.
  ///
  /// **[onShown] fires when the video is PRESENTED**, which is the signal the
  /// tapped button is waiting on — the future below is the dismissal, seconds
  /// later, and a spinner held until then would still be turning under a video
  /// that is already playing.
  ///
  /// Resolves to [AdOutcome.rewarded] when the reward was earned,
  /// [AdOutcome.dismissed] when the player backed out, and
  /// [AdOutcome.unavailable] when the SDK could not present it at all — which
  /// is a failure the player should be told about rather than a choice they
  /// made, and was being reported as the latter.
  Future<AdOutcome> show({void Function()? onShown});

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
  Future<AdOutcome> show({void Function()? onShown}) async {
    final closed = Completer<AdOutcome>();
    var earned = false;
    _ad.fullScreenContentCallback = FullScreenContentCallback(
      // The moment the video covers the app. See [RewardedHandle.show].
      onAdShowedFullScreenContent: (_) => onShown?.call(),
      onAdDismissedFullScreenContent: (ad) {
        unawaited(ad.dispose());
        if (!closed.isCompleted) {
          closed.complete(earned ? AdOutcome.rewarded : AdOutcome.dismissed);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        unawaited(ad.dispose());
        if (!closed.isCompleted) closed.complete(AdOutcome.unavailable);
      },
    );
    try {
      // Not awaited: `show` resolves when the ad is PRESENTED, and what this
      // wants is the dismissal — which arrives on the callback above.
      unawaited(_ad.show(onUserEarnedReward: (_, _) => earned = true));
    } catch (_) {
      unawaited(_ad.dispose());
      if (!closed.isCompleted) closed.complete(AdOutcome.unavailable);
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

  /// **A show that is already running.** Re-entrancy is guarded in the UI by
  /// `adBusyProvider`, and guarded again here because the adapter must not
  /// depend on every caller having behaved: one ad object is one showing, and a
  /// second `show` racing the first would take the same handle twice.
  bool _showing = false;

  @override
  Future<AdOutcome> show(String placement, {void Function()? onShown}) async {
    // **Consent first, and a refusal is `unavailable` rather than an error.**
    // Serving without it in the EEA is the thing the gate exists to stop.
    if (!_permitted()) {
      return _report(placement, AdOutcome.unavailable, reason: 'consent');
    }
    // A double tap that got past the UI's flag pays nothing and says nothing.
    if (_showing) return AdOutcome.dismissed;

    _showing = true;
    try {
      final unit = rewardedUnitFor(_platform, placement);
      if (unit == null) {
        return _report(placement, AdOutcome.unavailable, reason: 'no_unit');
      }
      // **LOADED HERE, on the tap that wants it, and nowhere else.** The warm
      // slot is gone — see this file's header — so this is the whole life of an
      // ad object: loaded, shown once, disposed. `adLoadTimeout` is what stops
      // it being an indefinite wait, and the player is watching a spinner on
      // the button they pressed for the length of it.
      final handle = await _loader.load(unit);
      if (handle == null) {
        return _report(placement, AdOutcome.unavailable, reason: 'no_fill');
      }

      // **A PRESENT THAT FAILS IS A FAILURE, not a dismissal.** It used to
      // resolve `false` alongside a player who closed the video early, so a
      // broken showing paid nothing AND said nothing — the one outcome that
      // most needs the toast, filed as the one that deliberately has none.
      final outcome = await handle.show(onShown: onShown);
      return _report(
        placement,
        outcome,
        reason: outcome == AdOutcome.unavailable ? 'show_failed' : null,
      );
    } finally {
      _showing = false;
    }
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
  AdOutcome _report(String placement, AdOutcome outcome, {String? reason}) {
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
      // **`reason` splits the one outcome that was two problems.** Consent and
      // no-fill both answer `unavailable` and want opposite responses: one is a
      // choice the player made and the other is inventory — and `show_failed`
      // is a third, which is the SDK holding an ad it could not put on screen.
      // It mattered less when a placement had its own unit and AdMob's own fill
      // rate could be read next to it; with one unit for everything, this is
      // the only place the split exists.
      'reason': ?reason,
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
