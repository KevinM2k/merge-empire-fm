/// What a paid tile says once you already own the thing.
///
/// **Seven `shop.vip.*` keys shipped in ten languages with no caller**, plus
/// `shop.owned_check`, `shop.owned_regranted` and
/// `product.energy_director.active_note` — a whole state machine the JS draws on
/// three tiles and the port drew on none. Every one of them printed its price
/// and a live Buy button whatever the save said.
///
/// **It stopped being cosmetic the moment the tiles could actually buy.** A
/// player who owns the Starter Pack was being offered it again, and the
/// purchase now gets as far as `initiatePurchase` before being refused
/// `already_purchased` — a dead end reached by pressing the thing the shop was
/// pointing at.
///
/// **VIP has THREE states and the middle one is the interesting one.** Active is
/// obvious and owned is obvious; LAPSED — it ran and has run out — is the one
/// the JS gives its own ribbon and its own line, because a player who has paid
/// once is the one most likely to pay again and the tile is the only place that
/// can say so.
///
/// Deliberately Flutter-free: it is a reading of the save, and the tile decides
/// what to do with it.
library;

import 'package:merge_empire_fc/engine/iap_engine.dart';

/// Whether a product is already owned, and what the tile should say about it.
typedef OwnedState = ({
  /// It cannot be bought again right now.
  bool owned,

  /// The button's label — a price is the caller's fallback.
  String? buttonKey,

  /// A line under it, or null.
  String? noteKey,

  /// What to put in the note's `{days}`, when it takes one.
  int days,

  /// The ribbon, which REPLACES the product's own bonus line.
  String? ribbonKey,
});

const OwnedState _buyable = (
  owned: false,
  buttonKey: null,
  noteKey: null,
  days: 0,
  ribbonKey: null,
);

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// **How close to the end counts as expiring.** The JS's three days: long
/// enough to renew before it lapses, short enough that the warning means
/// something.
const int vipExpiringDays = 3;

/// Days left on VIP, rounded UP.
///
/// Up rather than down because a pass with two hours left is a pass with a day
/// on it as far as a player is concerned, and saying "0 days left" about
/// something still working is worse than being a few hours generous.
int vipDaysLeft(Map<String, dynamic>? state, {required int nowMs}) {
  final expires = _map(state?['shop'])?['vipExpiresAt'];
  if (expires is! num) return 0;
  final left = expires.toInt() - nowMs;
  if (left <= 0) return 0;
  return (left / 86400000).ceil();
}

/// Has VIP run and run OUT? The state the JS gives its own ribbon to.
bool vipLapsed(Map<String, dynamic>? state, {required int nowMs}) {
  final expires = _map(state?['shop'])?['vipExpiresAt'];
  return expires is num && expires > 0 && expires <= nowMs;
}

/// What [product]'s tile should say, given the save.
OwnedState ownedStateFor(
  IapProduct product,
  Map<String, dynamic>? state, {
  required int nowMs,
}) {
  final shop = _map(state?['shop']);

  if (product.id == 'vip_pass') {
    final days = vipDaysLeft(state, nowMs: nowMs);
    if (days > 0) {
      return (
        owned: true,
        buttonKey: 'shop.vip.active_btn',
        noteKey: days <= vipExpiringDays
            ? 'shop.vip.active_expiring'
            : 'shop.vip.active',
        days: days,
        // **No ribbon while it is running.** The bonus line is an inducement,
        // and inducing somebody to buy what they already have is the tile
        // arguing with itself.
        ribbonKey: null,
      );
    }
    if (vipLapsed(state, nowMs: nowMs)) {
      return (
        owned: false,
        buttonKey: null,
        noteKey: 'shop.vip.lapsed_note',
        days: 0,
        ribbonKey: 'shop.vip.reactivate_ribbon',
      );
    }
    return _buyable;
  }

  // **The Energy Director is owned by its EFFECT, not by a receipt.** It writes
  // `energyUpgraded`, and that flag is what every other reader checks — a
  // second source for "do they have it" is how a restore and a purchase come to
  // disagree.
  if (product.energyDirector) {
    return shop?['energyUpgraded'] == true
        ? (
            owned: true,
            buttonKey: 'shop.owned_check',
            noteKey: 'product.energy_director.active_note',
            days: 0,
            ribbonKey: null,
          )
        : _buyable;
  }

  if (product.oneTime) {
    final purchased = shop?['purchasedIds'];
    if (purchased is List && purchased.contains(product.id)) {
      return (
        owned: true,
        buttonKey: 'shop.owned_check',
        // **"Re-granted every reset" is the reason it stays on the shelf.** A
        // one-time purchase that vanished once bought would look like it had
        // been taken away at the next prestige.
        noteKey: 'shop.owned_regranted',
        days: 0,
        ribbonKey: null,
      );
    }
  }

  return _buyable;
}
