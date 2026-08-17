/// Casual-mode energy — the pip pool that paces matches. Ported from the pure
/// half of `../merge-empire-fc/src/engine/energyEngine.js`.
///
/// The other half of that file is AdMob plumbing (prepare / show / listener
/// wiring). It belongs to the services layer here, not to the logic core, and
/// the ad-unit tables it needs are data in `lib/data/ad_units.dart`. What stays
/// is the arithmetic: regeneration, spending, and the two prefetch decisions —
/// which are pure judgements about the save, and the parts worth testing.
///
/// Pro mode has no pip pool at all; it runs per-player fatigue through
/// `player_energy_engine.dart` instead.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

/// The pip cap, which the Energy Director upgrade raises.
int getEnergyMax(Map<String, dynamic>? state) =>
    _map(state?['shop'])?['energyUpgraded'] == true
    ? Energy.maxUpgraded
    : Energy.max;

/// How long one pip takes to come back, which the same upgrade shortens.
int getEnergyRegenMs(Map<String, dynamic>? state) =>
    _map(state?['shop'])?['energyUpgraded'] == true
    ? Energy.regenMsUpgraded
    : Energy.regenMs;

Map<String, dynamic> _energy(Map<String, dynamic> state) =>
    _map(state['energy']) ??
    (state['energy'] = <String, dynamic>{'current': 0, 'lastRegenAt': now()});

/// Credit whatever has regenerated since the last check, and return how many
/// pips that was.
///
/// The timestamp advances by exactly the pips granted rather than jumping to
/// now, so the fraction of an interval already served is kept — otherwise
/// checking the app often would reset the countdown every time and a pip would
/// never arrive.
int processEnergyRegen(Map<String, dynamic> state) {
  final energy = _energy(state);
  final max = getEnergyMax(state);
  final regenMs = getEnergyRegenMs(state);
  final current = _num(energy['current'])?.toInt() ?? 0;

  if (current >= max) {
    energy['lastRegenAt'] = now();
    return 0;
  }

  final lastRegenAt = _num(energy['lastRegenAt'])?.toInt() ?? now();
  final elapsed = now() - lastRegenAt;
  final earned = elapsed ~/ regenMs;
  if (earned <= 0) return 0;

  energy['current'] = math.min(current + earned, max);
  energy['lastRegenAt'] = lastRegenAt + earned * regenMs;
  return earned;
}

/// Milliseconds until the next pip, or 0 when the tank is full.
int msUntilNextPip(Map<String, dynamic> state) {
  final energy = _energy(state);
  final max = getEnergyMax(state);
  final regenMs = getEnergyRegenMs(state);
  if ((_num(energy['current'])?.toInt() ?? 0) >= max) return 0;
  final lastRegenAt = _num(energy['lastRegenAt'])?.toInt() ?? now();
  return regenMs - ((now() - lastRegenAt) % regenMs);
}

/// The outcome of trying to spend pips.
typedef SpendResult = ({bool ok, String? reason});

/// Debit [amount] pips, or refuse and change nothing.
///
/// The check and the debit are one step, so there is no window between them for
/// a second tap to slip through.
SpendResult spendEnergy(Map<String, dynamic> state, int amount) {
  final energy = _energy(state);
  final current = _num(energy['current'])?.toInt() ?? 0;
  if (current < amount) return (ok: false, reason: 'not_enough_energy');
  energy['current'] = current - amount;
  emit('energy:updated', energy['current']);
  return (ok: true, reason: null);
}

/// Pay out a watched rewarded video.
void onWatchAdComplete(Map<String, dynamic> state, String rewardType) {
  if (rewardType == 'energy') {
    final energy = _energy(state);
    final current = _num(energy['current'])?.toInt() ?? 0;
    energy['current'] = math.min(current + Energy.adReward, getEnergyMax(state));
    emit('energy:updated', energy['current']);
    return;
  }
  if (rewardType == 'boost') {
    final boosts = _map(state['boosts']) ?? (state['boosts'] = <String, dynamic>{});
    boosts['incomeBoostActive'] = true;
    boosts['incomeBoostEndsAt'] = now() + Idle.boostDurationMs;
    emit('boost:started', boosts['incomeBoostEndsAt']);
  }
}

/// Is the energy rewarded ad worth preloading right now?
///
/// Preloading is not free — the plugin holds one rewarded ad at a time, so an
/// unwanted prefetch costs a request AND evicts whatever the player was
/// actually about to tap. Somebody sitting on plenty of pips is not about to
/// buy more.
///
/// Pro mode deliberately answers yes: pips aren't spent there — the popup
/// offers the ad against squad fitness instead — so the pip count says nothing
/// about whether the ad is wanted, and guessing wrong leaves a Pro player
/// waiting on a cold ad.
bool shouldPrefetchEnergyAd(Map<String, dynamic>? state) {
  if (_map(state?['settings'])?['hardMode'] == true) return true;
  final current = _num(_map(state?['energy'])?['current'])?.toInt() ?? 0;
  if (current >= getEnergyMax(state)) return false;
  return current <= Energy.adPrefetchMax;
}

/// Is the 2× match-reward ad worth preloading for this result?
///
/// Somebody who has just lost is dismissing the result screen, not watching
/// thirty seconds of video to double a consolation payout — the tap rate
/// doesn't justify spending the one cached slot. Wins and draws get the warm-up
/// so the button is instant where it is used; a loser who does tap just pays
/// the usual cold prepare.
bool shouldPrefetchDoubleMatchAd(Map<String, dynamic>? result) =>
    result?['won'] == true || result?['drawn'] == true;

/// Rewarded ads can run to about thirty seconds, so a minute is a generous
/// margin before the UI is unblocked and silence treated as a failure. On iOS
/// the SDK sometimes drops the Dismissed event outright, which without this
/// leaves the button stuck on "Loading…" forever.
const int adSafetyTimeoutMs = 60000;
