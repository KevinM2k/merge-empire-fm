/// The Shop's three coin-priced consumables.
///
/// Ported from `ui/screens/ShopScreen.js`, which is where their pricing and
/// their effects both lived — unlike every other purchase on that screen, they
/// had no engine. That is why this file exists rather than being a translation:
/// the logic is being lifted OUT of a view, not moved across from one.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/engine/lineup_engine.dart';
import 'package:merge_empire_fc/util/format.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

Map<String, dynamic> _branch(Map<String, dynamic> owner, String key) {
  final existing = owner[key];
  if (existing is Map<String, dynamic>) return existing;
  final fresh = <String, dynamic>{};
  owner[key] = fresh;
  return fresh;
}

String? _divisionId(Map<String, dynamic>? state) =>
    _map(state?['progression'])?['currentDivision'] as String?;

/// A price scaled by division — always about five to eight match wins' worth.
///
/// Rounded to a tidy tens number so the shelf reads like a real price list.
int scaledCoinCost(Map<String, dynamic>? state, int base) {
  // getDivision falls back to the bottom of the ladder for an unknown id, which
  // is the honest price for a save whose division we cannot place.
  final division = getDivision(_divisionId(state) ?? divisions.first.id);
  return roundCoins(base * (division.matchRevenueBase / 100));
}

/// How many times the sponge has been used this run.
int spongeUses(Map<String, dynamic>? state) =>
    (_num(_map(state?['shop'])?['spongeUses']) ?? 0).toInt();

/// The sponge's escalating price, capped at three times its base.
///
/// The cap is the point. The old ramp was `2^uses` and unbounded, which made the
/// third heal cost sixty matches' worth of coins at every division — a price
/// that effectively forced an IAP rather than offering one.
int spongeCost(Map<String, dynamic>? state) {
  final multiplier = math.min(3.0, 1 + spongeUses(state) * 0.5);
  return roundCoins(scaledCoinCost(state, 1500) * multiplier);
}

int kitSponsorCost(Map<String, dynamic>? state) => scaledCoinCost(state, 5000);

int tvDealCost(Map<String, dynamic>? state) => scaledCoinCost(state, 3500);

/// The season a boost was bought for. A boost is live only for its own season.
int _season(Map<String, dynamic>? state) =>
    (_num(_map(state?['progression'])?['seasonCount']) ?? 1).toInt();

bool isKitSponsorActive(Map<String, dynamic>? state) =>
    _num(_map(state?['boosts'])?['kitSponsorSeason'])?.toInt() ==
    _season(state);

bool isTvDealActive(Map<String, dynamic>? state) =>
    _num(_map(state?['boosts'])?['matchRevBoostSeason'])?.toInt() ==
    _season(state);

List<Map<String, dynamic>> _injuredCards(Map<String, dynamic>? state) {
  final cells = _map(state?['grid'])?['cells'];
  if (cells is! List) return const [];
  return [
    for (final cell in cells)
      if (cell is Map<String, dynamic> && cell['injured'] == true) cell,
  ];
}

int injuredCount(Map<String, dynamic>? state) => _injuredCards(state).length;

/// Heal every injured player and put the XI back to eleven. Returns how many.
///
/// **One heal, two buyers.** The Magic Sponge pays coins for it and the Squad
/// bench's rewarded video gets it free three times a day — see the note in
/// [buyConsumable] on why they have to be the same effect. Lifted out of the
/// sponge's own case rather than copied: two heals that could drift apart is
/// exactly the pairing that comment exists to hold together.
int healAllInjured(Map<String, dynamic> state) {
  final injured = _injuredCards(state);
  for (final card in injured) {
    card['injured'] = false;
    card['injuredAt'] = null;
    card['injuryDurationMs'] = null;
  }
  // Back in contention for the slot their injury left open.
  refillLineupFromBench(state);
  return injured.length;
}

/// Why a consumable cannot be bought, or null when it can.
///
/// Split out for the same reason `gemItemBlocked` was: the Shop greys a row and
/// says why, rather than failing on a tap.
/// One of: `unknown_item`, `no_injured`, `already_active`, `insufficient_coins`.
String? consumableBlocked(Map<String, dynamic>? state, String id) {
  final coins = _num(_map(state?['resources'])?['fanCoins']) ?? 0;
  switch (id) {
    case 'magic_sponge':
      if (injuredCount(state) == 0) return 'no_injured';
      if (coins < spongeCost(state)) return 'insufficient_coins';
      return null;
    case 'kit_sponsor':
      if (isKitSponsorActive(state)) return 'already_active';
      if (coins < kitSponsorCost(state)) return 'insufficient_coins';
      return null;
    case 'match_rev':
      if (isTvDealActive(state)) return 'already_active';
      if (coins < tvDealCost(state)) return 'insufficient_coins';
      return null;
    default:
      return 'unknown_item';
  }
}

int consumableCost(Map<String, dynamic>? state, String id) => switch (id) {
  'magic_sponge' => spongeCost(state),
  'kit_sponsor' => kitSponsorCost(state),
  'match_rev' => tvDealCost(state),
  _ => 0,
};

/// What a purchase did.
typedef ConsumablePurchase = ({
  bool ok,
  String? reason,
  String? id,
  int cost,
  int healed,
});

ConsumablePurchase _fail(String reason) =>
    (ok: false, reason: reason, id: null, cost: 0, healed: 0);

/// Buy one, debiting the wallet and applying the effect.
///
/// Every failure path leaves the balance exactly where it found it — the gate is
/// asked before a coin moves, never after.
ConsumablePurchase buyConsumable(Map<String, dynamic> state, String id) {
  final blocked = consumableBlocked(state, id);
  if (blocked != null) return _fail(blocked);

  final cost = consumableCost(state, id);
  final resources = _branch(state, 'resources');
  // Plain subtraction, as the JS does. roundCoins is a PRICE formatter — it
  // rounds to a tidy figure, so running a balance through it hands the player
  // the difference.
  resources['fanCoins'] = ((_num(resources['fanCoins']) ?? 0) - cost).toInt();

  switch (id) {
    case 'magic_sponge':
      // Heals EVERY injured player, not the worst one. Healing exactly one made
      // it strictly worse than the free rewarded video on the Squad bench, which
      // heals the whole squad three times a day — and a coin item nobody should
      // rationally buy is worse than no coin item at all. Matching the ad's
      // effect turns the price into the cost of NOT watching.
      final healed = healAllInjured(state);
      final shop = _branch(state, 'shop');
      shop['spongeUses'] = spongeUses(state) + 1;
      return (ok: true, reason: null, id: id, cost: cost, healed: healed);

    case 'kit_sponsor':
      _branch(state, 'boosts')['kitSponsorSeason'] = _season(state);
      return (ok: true, reason: null, id: id, cost: cost, healed: 0);

    case 'match_rev':
      _branch(state, 'boosts')['matchRevBoostSeason'] = _season(state);
      return (ok: true, reason: null, id: id, cost: cost, healed: 0);
  }
  return _fail('unknown_item');
}
