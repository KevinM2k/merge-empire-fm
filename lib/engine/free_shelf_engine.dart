/// What a rewarded video on the free shelf actually grants. Ported from
/// `_renderLuckyBoot` and `_renderMatchCooldownAd` in
/// `../merge-empire-fc/src/ui/screens/ShopScreen.js`.
///
/// **Both mechanics already existed in the port and neither could be reached.**
/// `luckyBootReady` is read by the match and the cup and by the fixture preview;
/// `matchCooldownFreeUntil` is read by the cooldown. What was missing was the
/// only thing that sets them, which is a video — so the two tiles on the free
/// shelf sat behind the IAP's own "coming soon".
///
/// The grants live here rather than in the tile so the caps, the day boundary
/// and the "already held" states are testable without a screen — and so the
/// screen cannot decide the cap for itself.
///
/// Deliberately Flutter-free.
library;

import 'package:merge_empire_fc/engine/shop_consumables_engine.dart'
    show healAllInjured;
import 'package:merge_empire_fc/util/time.dart';

/// Videos a day for the cooldown skip. The JS's `MATCH_COOLDOWN_AD_CAP_PER_DAY`.
const int matchCooldownAdCapPerDay = 3;

/// How long one buys. Five minutes with no thirty-second wait between matches.
const int matchCooldownFreeMs = 5 * 60 * 1000;

Map<String, dynamic> _sub(Map<String, dynamic> state, String key) {
  final existing = state[key];
  if (existing is Map<String, dynamic>) return existing;
  final made = <String, dynamic>{};
  state[key] = made;
  return made;
}

int _int(Object? v) => v is num ? v.toInt() : 0;

/// How many cooldown-skip videos have been watched TODAY.
///
/// **A different day is a fresh count, and the day is the DEVICE's own.** The
/// JS stamps `toDateString()`, so this is the same wall-clock day rather than a
/// rolling 24 hours — which is what makes the cap read as "three a day".
int matchCooldownAdsUsed(Map<String, dynamic>? state, [int? nowMs]) {
  final shop = state?['shop'];
  if (shop is! Map<String, dynamic>) return 0;
  return shop['matchCooldownAdDay'] == dateString(nowMs ?? now())
      ? _int(shop['matchCooldownAdCount'])
      : 0;
}

/// Whether the boost is running right now.
bool matchCooldownFree(Map<String, dynamic>? state, [int? nowMs]) {
  final boosts = state?['boosts'];
  if (boosts is! Map<String, dynamic>) return false;
  return _int(boosts['matchCooldownFreeUntil']) > (nowMs ?? now());
}

/// Whole minutes left on it, rounded UP — a boost with forty seconds left is
/// still a minute to a player watching a countdown.
int matchCooldownFreeMinsLeft(Map<String, dynamic>? state, [int? nowMs]) {
  final boosts = state?['boosts'];
  if (boosts is! Map<String, dynamic>) return 0;
  final left = _int(boosts['matchCooldownFreeUntil']) - (nowMs ?? now());
  return left <= 0 ? 0 : (left + 59999) ~/ 60000;
}

bool canWatchMatchCooldownAd(Map<String, dynamic>? state, [int? nowMs]) =>
    !matchCooldownFree(state, nowMs) &&
    matchCooldownAdsUsed(state, nowMs) < matchCooldownAdCapPerDay;

/// Pay out a watched cooldown-skip video.
///
/// **The day is re-read here, not captured by the caller.** A video started at
/// 23:59 and finished at 00:01 belongs to the day it FINISHED — the JS captures
/// it before the ad instead, which spends yesterday's budget on a boost the
/// player is holding today.
void grantMatchCooldownAd(Map<String, dynamic> state, [int? nowMs]) {
  final at = nowMs ?? now();
  _sub(state, 'boosts')['matchCooldownFreeUntil'] = at + matchCooldownFreeMs;
  final shop = _sub(state, 'shop');
  final today = dateString(at);
  if (shop['matchCooldownAdDay'] != today) {
    shop['matchCooldownAdDay'] = today;
    shop['matchCooldownAdCount'] = 0;
  }
  shop['matchCooldownAdCount'] = _int(shop['matchCooldownAdCount']) + 1;
}

/// Videos a day for the free heal-all.
///
/// Three, and the number is not a guess: `shop_consumables_engine`'s own
/// comment on the Magic Sponge names "the free rewarded video on the Squad
/// bench, which heals the whole squad three times a day" as the thing the coin
/// item has to be priced against. The video was the half of that pairing the
/// port never built.
const int healAllAdCapPerDay = 3;

/// How many heal-all videos have been watched TODAY. Same day boundary as
/// [matchCooldownAdsUsed] — the device's own wall-clock day.
int healAllAdsUsed(Map<String, dynamic>? state, [int? nowMs]) {
  final shop = state?['shop'];
  if (shop is! Map<String, dynamic>) return 0;
  return shop['healAllAdDay'] == dateString(nowMs ?? now())
      ? _int(shop['healAllAdCount'])
      : 0;
}

/// Heal every injured player, and count the video against the day's cap.
///
/// **The same effect the Magic Sponge buys**, because that is what makes the
/// coin item's price the cost of not watching — see the note in
/// `buyConsumable`. Returns how many were healed, so the toast can say.
///
/// **The cap is checked HERE, inside the grant**, for the reason
/// `grantMatchCooldownAd`'s caller spells out: a button painted before the
/// third video must not pay out a fourth.
int grantHealAllAd(Map<String, dynamic> state, [int? nowMs]) {
  final at = nowMs ?? now();
  if (healAllAdsUsed(state, at) >= healAllAdCapPerDay) return 0;

  final healed = healAllInjured(state);

  final shop = _sub(state, 'shop');
  final today = dateString(at);
  if (shop['healAllAdDay'] != today) {
    shop['healAllAdDay'] = today;
    shop['healAllAdCount'] = 0;
  }
  shop['healAllAdCount'] = _int(shop['healAllAdCount']) + 1;
  return healed;
}

/// Whether a lucky boot is already waiting to be used.
bool luckyBootHeld(Map<String, dynamic>? state) {
  final shop = state?['shop'];
  return shop is Map<String, dynamic> && shop['luckyBootReady'] == true;
}

/// Pay out a watched lucky-boot video.
///
/// **Deliberately does NOT touch `luckyBootUses`.** That counter is what pushes
/// the COIN price of the next boot up, and a free one must not make the paid one
/// dearer — the JS says so in its own comment and it is the kind of thing that
/// looks like an oversight when it is a decision.
void grantLuckyBootAd(Map<String, dynamic> state) {
  _sub(state, 'shop')['luckyBootReady'] = true;
}
