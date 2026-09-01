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
/// is loaded, shown once and disposed. So the cache holds at most one preloaded
/// ad and the show path always clears it — a second tap that re-showed the same
/// object would be an SDK error rather than a second video.
///
/// **And there is ONE slot for the whole app, not one per placement.** Every
/// rewarded placement serves from the same unit now, so the ad warmed on the
/// training screen is the ad the shop's lucky boot shows. That is the point of
/// the global unit: with eleven slots the warm ad was almost never the one that
/// got tapped, and the player waited on a load anyway. See
/// `globalRewardedUnitAndroid` in `data/ad_units.dart`.
///
/// **A warm ad goes off.** AdMob expires one about an hour after it loads and
/// says nothing — it fails at the tap, arriving as a dismissal the player never
/// made. [adFreshness] is checked whenever something is about to want an ad,
/// and on app resume via [RewardedAds.refresh]. No timer: an app in the
/// background must not be spending ad requests.
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

/// How long a warmed ad is worth showing.
///
/// **AdMob expires a loaded rewarded ad about an hour after it loads**, and an
/// expired one does not announce itself: it fails at the moment of the tap and
/// arrives as a dismissal the player never made. Ten minutes short of the hour,
/// because the check happens when something is about to want an ad rather than
/// on a timer — the load it triggers has to fit inside the margin too.
const Duration adFreshness = Duration(minutes: 50);

/// A warm ad and the moment it loaded. The pair is the whole point: a handle on
/// its own cannot say whether it is still good.
class _Warm {
  _Warm(this.handle, this.loadedAt);

  final RewardedHandle handle;
  final DateTime loadedAt;
}

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
    DateTime Function()? clock,
  }) : _loader = loader ?? const _PluginLoader(),
       _platform = platform ?? adPlatform(),
       _permitted = permitted ?? (() => adsPermitted),
       _clock = clock ?? DateTime.now;

  final RewardedAdLoader _loader;
  final String _platform;

  /// **Re-read on every show, not captured at construction.** Consent can be
  /// REVOKED from Settings mid-session, and an adapter built while it was
  /// granted would carry on serving afterwards.
  final bool Function() _permitted;

  /// The clock, as a seam. A stale ad is an age, and an age needs a now.
  final DateTime Function() _clock;

  /// **ONE warm ad for the whole app, not one per placement.** Every placement
  /// serves from the same unit now, so the ad warmed for the training screen is
  /// the ad the shop's lucky boot shows — which is the point: eleven separate
  /// slots meant the one that was warm was almost never the one that was
  /// tapped. See [globalRewardedUnitAndroid].
  _Warm? _warm;

  /// The in-flight load, so a prepare followed by a show does not load twice.
  Future<RewardedHandle?>? _loading;

  /// The placement a warm ad was loaded FOR, which is not necessarily where it
  /// gets shown. Reported on the outcome so the hop is visible rather than
  /// looking like a placement that loads ads it never uses.
  String? _warmedFor;

  /// **A show that is already running.** Re-entrancy is guarded in the UI by
  /// `adBusyProvider`, and guarded again here because the adapter must not
  /// depend on every caller having behaved: one ad object is one showing, and a
  /// second `show` racing the first would take the same handle twice.
  bool _showing = false;

  @override
  void prepare(String placement) {
    _dropIfStale();
    if (_warm != null || _loading != null) return;
    // Never awaited: a prefetch that fails must not hold up the thing that
    // asked for it.
    unawaited(_load(placement));
  }

  @override
  void refresh() {
    // A fresh slot is left exactly as it is, so a resume costs nothing when
    // nothing has expired.
    if (!_dropIfStale()) return;
    // `'resume'` is not a placement and is not pretending to be one: it is what
    // `warmed_for` will say about the ad this loads, which is the truth — no
    // screen asked for it, a resume did.
    if (_loading == null) unawaited(_load('resume'));
  }

  /// Throw away a warm ad past [adFreshness]. True when one was thrown away.
  ///
  /// **The SDK will not tell us.** An expired rewarded ad fails at the moment
  /// it is shown, which lands as a dismissal the player never made — so the age
  /// is tracked here rather than discovered there.
  bool _dropIfStale() {
    final warm = _warm;
    if (warm == null) return false;
    if (_clock().difference(warm.loadedAt) < adFreshness) return false;
    warm.handle.dispose();
    _warm = null;
    _warmedFor = null;
    return true;
  }

  Future<RewardedHandle?> _load(String placement) {
    final unit = rewardedUnitFor(_platform, placement);
    if (unit == null) return Future.value(null);
    final future = _loader.load(unit).then((handle) {
      _loading = null;
      if (handle != null) {
        _warm = _Warm(handle, _clock());
        _warmedFor = placement;
      }
      return handle;
    });
    _loading = future;
    return future;
  }

  @override
  Future<AdOutcome> show(String placement) async {
    // **Consent first, and a refusal is `unavailable` rather than an error.**
    // Serving without it in the EEA is the thing the gate exists to stop.
    if (!_permitted()) {
      return _report(placement, AdOutcome.unavailable, reason: 'consent');
    }
    // A double tap that got past the UI's flag pays nothing and says nothing.
    if (_showing) return AdOutcome.dismissed;

    _showing = true;
    try {
      _dropIfStale();
      final warmedFor = _warmedFor;
      var handle = _take();
      handle ??= await (_loading ?? _load(placement));
      // A load that resolved into the slot while we awaited it is the same
      // object — take it out so nothing shows it twice.
      _take();
      if (handle == null) {
        // **NOTHING IS WARMED UP AFTER A NO-FILL.** The load that just failed
        // is the evidence there is no inventory, and lining another one up on
        // the spot spends a second request to be told so again — two per tap,
        // each with `adLoadTimeout` behind it. The next `prepare` is a screen
        // saying an offer is coming, which is a better moment to ask.
        return _report(placement, AdOutcome.unavailable, reason: 'no_fill');
      }

      final earned = await handle.show();
      // And line up the next one while the player is still on the screen that
      // asked for this one.
      prepare(placement);
      return _report(
        placement,
        earned ? AdOutcome.rewarded : AdOutcome.dismissed,
        warmedFor: warmedFor,
      );
    } finally {
      _showing = false;
    }
  }

  /// Take the warm ad out of the slot, if there is one.
  RewardedHandle? _take() {
    final warm = _warm;
    _warm = null;
    _warmedFor = null;
    return warm?.handle;
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
  AdOutcome _report(
    String placement,
    AdOutcome outcome, {
    String? reason,
    String? warmedFor,
  }) {
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
      // choice the player made and the other is inventory. It mattered less
      // when a placement had its own unit and AdMob's own fill rate could be
      // read next to it; with one unit for everything, this is the only place
      // the split exists.
      'reason': ?reason,
      // **Where the ad was WARMED, when that is not where it was shown.** One
      // warm ad for the whole app is the point of the global unit, and the
      // consequence is that the training screen loads ads the shop spends. A
      // load count per placement that ignored this would read as the training
      // screen wasting inventory.
      if (warmedFor != null && warmedFor != placement) 'warmed_for': warmedFor,
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
