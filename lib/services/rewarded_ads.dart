/// Rewarded video, as one seam.
///
/// **NOTHING IS PRELOADED.** Every ad is loaded on the tap that wants it, and
/// the button that was tapped says so while it happens. The warm slot this used
/// to keep is gone along with the six screens that primed it, the resume that
/// topped it up and the staleness clock that threw it away: one warm ad for the
/// whole app meant a request spent on whatever offer the player walked past,
/// expiring in their pocket, and a tap that hit a slot loaded fifty minutes ago
/// failed at the moment of the tap as a dismissal nobody made.
///
/// The cost of that is real — a cold load is a wait where there used to be
/// none — and it is paid in the UI rather than hidden: see [AdBusy], which is
/// what puts a spinner on the button and takes it off again.
///
/// [AdOutcome.unavailable] is a real answer the flow has to handle. A video
/// fails to fill more often than anyone expects, and the JS's own path for it —
/// toast, then take the single reward — is the path the screens follow here.
/// The toast is raised ONCE, by [watchRewardedAd], rather than by each of the
/// eight offers remembering to.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

/// What came of asking for one.
enum AdOutcome {
  /// Watched to the end. The reward is owed.
  rewarded,

  /// Closed early, or the player backed out. Nothing is owed.
  dismissed,

  /// No fill, no network, no SDK, or one that would not present. Nothing is
  /// owed and the player is not at fault, so the copy says so.
  unavailable,
}

abstract class RewardedAds {
  /// Show one for [placement] — a key from `ad_units.dart`.
  ///
  /// **[onShown] fires the moment the video is actually on screen**, which is
  /// several seconds before this future resolves: the future is the DISMISSAL,
  /// and the dismissal is far too late to be the thing that takes a button's
  /// spinner off. An implementation that cannot tell — no SDK, no fill — never
  /// calls it, and the failure resolves the future instead.
  Future<AdOutcome> show(String placement, {void Function()? onShown});
}

/// The one that ships when there is no SDK. Every placement is unavailable,
/// honestly.
class NoRewardedAds implements RewardedAds {
  const NoRewardedAds();

  @override
  Future<AdOutcome> show(String placement, {void Function()? onShown}) async =>
      AdOutcome.unavailable;
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
  Future<AdOutcome> show(String placement, {void Function()? onShown}) async =>
      (await _adapter()).show(placement, onShown: onShown);
}

final rewardedAdsProvider = Provider<RewardedAds>(
  (ref) => const NoRewardedAds(),
);

/// The rewarded ad in flight, and how far along it is.
///
/// Three fields answering three different questions, on three different
/// schedules:
///
/// - `placement` — non-null at all means an ad is in flight ANYWHERE in the
///   app, which is what shuts every offer's button. Up on the tap, down when
///   the whole thing is over.
/// - `showing` — the video is on screen. This is what takes the tapped
///   button's spinner off: the player is watching a video, so the control
///   behind it has nothing left to say and must be a button again by the time
///   they come back to it.
/// - `slow` — the ask has been sitting there long enough to deserve a scrim as
///   well. See [adSpinnerDelay].
typedef AdBusy = ({String placement, bool slow, bool showing});

/// The rewarded ad currently in flight, anywhere in the app, or null.
///
/// **One flag for the whole app rather than one per screen.** Three of the six
/// offers had a busy field of their own and three had nothing, so the shop's
/// free shelf and the energy sheet could both be double-tapped into two videos
/// against one reward. It is app-wide rather than per-screen because the offers
/// are not independent: the daily sheet's own comment already says so — "the
/// sheet is one decision and two of them in flight is two claims against one
/// day".
final adBusyProvider = StateProvider<AdBusy?>((ref) => null);

/// Whether [placement]'s own button should be wearing its loading state.
///
/// **True from the tap until the video is up or the ask has failed**, which is
/// the whole of what a button has to know. Only the placement that was TAPPED
/// answers true: every other offer in the app is shut by [adBusyProvider] being
/// non-null, and a second button spinning would read as two videos loading.
final adLoadingProvider = Provider.family<bool, String>((ref, placement) {
  final busy = ref.watch(adBusyProvider);
  return busy != null && busy.placement == placement && !busy.showing;
});

/// How long a tap may sit there before it earns a scrim as well.
///
/// **The BUTTON's spinner is immediate** — with nothing preloaded there is no
/// such thing as an ad that opens on the tap, so a tap with no answer is the
/// normal case and the control has to say so at once. This is the second,
/// heavier cue: the full-screen scrim, which would be a flicker on an ask that
/// resolves in a frame or two.
const Duration adSpinnerDelay = Duration(milliseconds: 150);

/// Show a video for [placement], with the button held shut while it loads.
///
/// **The one entry point every offer goes through**, and the one place the
/// failure is spoken aloud. A second tap while one is in flight is answered
/// [AdOutcome.dismissed] without reaching the SDK — which is the outcome that
/// pays nothing and says nothing, and is what a double tap should do. Nothing
/// is logged or toasted for it either: a tap that never asked for an ad is not
/// an ad that failed.
///
/// **The toast lives here rather than at the eight call sites.** Six of them
/// raised their own line, two raised nothing, and three different keys said the
/// same sentence — so an offer that failed told the player so only if whoever
/// wrote that screen had remembered. `toast.no_ad` and `customise.pack.ad_failed`
/// are left in the catalogues with no caller, which is deliberate here rather
/// than the dropped-feature tell it usually is.
///
/// [onShown] is the caller's share of the presented signal, for a screen with
/// something of its own to do at that moment — the energy sheet comes down when
/// the video goes up rather than on the tap, so the button the player pressed
/// is still there to spin. Never called when the ask fails.
Future<AdOutcome> watchRewardedAd(
  WidgetRef ref,
  String placement, {
  VoidCallback? onShown,
}) async {
  final busy = ref.read(adBusyProvider.notifier);
  if (busy.state != null) return AdOutcome.dismissed;
  busy.state = (placement: placement, slow: false, showing: false);

  /// Move the flag on, if it is still this ask's to move. The `mounted` guard
  /// is for the container going away under a video that is still running,
  /// which a widget test does routinely.
  void advance(AdBusy? next) {
    if (!busy.mounted) return;
    final now = busy.state;
    if (now == null || now.placement != placement || now.showing) return;
    busy.state = next;
  }

  final spinner = Timer(
    adSpinnerDelay,
    () => advance((placement: placement, slow: true, showing: false)),
  );
  try {
    final outcome = await ref
        .read(rewardedAdsProvider)
        .show(
          placement,
          onShown: () {
            // The video is up: the scrim comes down and so does the button's
            // spinner, so the control is a button again by the time the player
            // is looking at it.
            spinner.cancel();
            advance((placement: placement, slow: false, showing: true));
            onShown?.call();
          },
        );
    if (outcome == AdOutcome.unavailable) {
      emit('toast:error', t('toast.ad_unavailable'));
    }
    return outcome;
  } finally {
    // **In a `finally`, because a stuck flag is a dead button.** The show path
    // catches its own failures, but a throw from anywhere above here would
    // otherwise leave every offer in the app disabled for the session.
    spinner.cancel();
    if (busy.mounted) busy.state = null;
  }
}
