/// The rewarded-ad frequency gate. Ported from
/// `../merge-empire-fc/src/engine/adGateEngine.js`.
///
/// AdMob frequency-caps the cosmetics rewarded unit at three videos per five
/// minutes. That cap is enforced on AdMob's side, and when it bites the SDK
/// simply fails to serve — from the player's seat, a button that does nothing.
/// This mirrors the cap locally so the UI can say "next video in 2:41" instead,
/// and offer the Style Vault to anyone who does not want to wait.
///
/// Mirroring is not enforcement: AdMob remains the authority, and this can drift
/// — a no-fill is not a cap hit, and the SDK's window may not start where ours
/// does. It is deliberately CONSERVATIVE about the direction of the error: a
/// timestamp is only recorded when a video actually paid out, so the local count
/// can lag the real one but never run ahead of it. The failure mode is offering
/// a video AdMob then declines, which the caller already handles; the
/// alternative — a countdown blocking a video the player could have watched —
/// would be inventing a restriction that is not there.
///
/// The cap is PER AD UNIT, so cosmetic unlocks have their own budget and cannot
/// eat into the energy or double-match placements. A player who burns three
/// videos on hats can still double their next match reward.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/util/time.dart';

/// Videos allowed per window on the cosmetics unit. Matches the AdMob setting.
const int adPackLimit = 3;

/// The rolling window the limit applies over.
const int adPackWindowMs = 5 * 60 * 1000;

/// Timestamps of pack-unlock videos inside the current window, oldest first.
/// Anything older has aged out and is dropped.
List<int> recentPackAds(Map<String, dynamic>? state, [int? nowMs]) {
  final at = nowMs ?? now();
  final stamps = (state?['ads'] as Map<String, dynamic>?)?['packUnlocks'];
  if (stamps is! List) return const [];
  final live = [
    for (final ts in stamps)
      if (ts is num && ts.isFinite && at - ts < adPackWindowMs) ts.toInt(),
  ];
  live.sort();
  return live;
}

/// How many more videos the window allows right now.
int packAdsRemaining(Map<String, dynamic>? state, [int? nowMs]) =>
    math.max(0, adPackLimit - recentPackAds(state, nowMs).length);

/// Can the player watch a pack-unlock video right now?
bool canWatchPackAd(Map<String, dynamic>? state, [int? nowMs]) =>
    packAdsRemaining(state, nowMs) > 0;

/// Milliseconds until the next video is allowed, and zero when one is available.
///
/// With the window full, the wait is until the OLDEST timestamp in it ages out,
/// since that is the slot that frees up first.
int msUntilPackAd(Map<String, dynamic>? state, [int? nowMs]) {
  final at = nowMs ?? now();
  final recent = recentPackAds(state, at);
  if (recent.length < adPackLimit) return 0;
  return math.max(0, recent.first + adPackWindowMs - at);
}

/// Record a pack-unlock video that actually paid out.
///
/// Only ever called from the reward callback, never from "we asked for an ad": a
/// video that failed to serve did not consume anything on AdMob's side either,
/// and counting it would lock the player out over a network blip.
void recordPackAd(Map<String, dynamic>? state, [int? nowMs]) {
  if (state == null) return;
  final at = nowMs ?? now();
  var ads = state['ads'] is Map<String, dynamic>
      ? state['ads'] as Map<String, dynamic>
      : null;
  if (ads == null) {
    ads = <String, dynamic>{};
    state['ads'] = ads;
  }
  // Pruned on write as well as on read, so the array cannot grow without bound
  // in a save that sits untouched for months.
  ads['packUnlocks'] = [...recentPackAds(state, at), at];
}

/// "2:41" or "0:09" for the cap countdown.
///
/// Rounds UP, so the label never reads 0:00 while the gate is still shut.
String formatAdWait(num ms) {
  final total = (math.max(0, ms) / 1000).ceil();
  final mins = total ~/ 60;
  return '$mins:${(total - mins * 60).toString().padLeft(2, '0')}';
}
