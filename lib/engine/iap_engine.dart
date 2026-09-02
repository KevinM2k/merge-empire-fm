/// In-app purchases: the catalogue, and applying what a purchase grants. Ported
/// from `../merge-empire-fc/src/engine/iapEngine.js`.
///
/// THE PURE HALF ONLY, the same split `energy_engine` took for its AdMob side.
/// `initiatePurchase` — the "user tapped Buy" flow — needs native billing and the
/// parental-consent gate, both of which are M4 services. What lives here is the
/// catalogue and [purchaseProduct], the reward-application step that runs once a
/// payment has completed (and directly, with no payment, on a dev build).
///
/// THE CATALOGUE IS A CONTRACT. Every `sku` is a live product id in App Store
/// Connect and Play Console, so a typo is a SKU nobody can buy. They keep the
/// `com.mergeempirefc.` prefix even though the game is now called Merge Empire
/// Football Manager — a store product id cannot be renamed any more than a bundle
/// id can.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/engine/gem_engine.dart';
import 'package:merge_empire_fc/engine/player_energy_engine.dart';
import 'package:merge_empire_fc/util/analytics.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;
bool _flag(Object? v) => v == true;

/// JS `Math.round` — halves go up, not to even.
int _jsRound(num v) => (v + 0.5).floor();

/// The far-future sentinel a prestige-linked pass uses instead of a wall clock,
/// so the ordinary `expiresAt > now` checks keep working. JS
/// `Number.MAX_SAFE_INTEGER`.
const int maxSafeInteger = 9007199254740991;

/// One thing on the shelf.
class IapProduct {
  const IapProduct({
    required this.id,
    required this.sku,
    required this.type,
    required this.category,
    required this.name,
    required this.icon,
    required this.price,
    required this.priceValue,
    this.desc,
    this.descHard,
    this.coins,
    this.coinsScaleWithDivision = false,
    this.energyAdd,
    this.energy,
    this.energyDirector = false,
    this.gems,
    this.vipCoinsPerWin,
    this.vipDays,
    this.vipPrestigeLinked = false,
    this.styleVault = false,
    this.oneTime = false,
    this.popular = false,
    this.bonus,
    this.eventGated,
  });

  final String id;

  /// The store's product id. Never rename one: it is the key the App Store and
  /// Play Console hold the product under.
  final String sku;

  /// `consumable` or `non_consumable`, matching the store's own notion.
  final String type;
  final String category;
  final String name;

  /// Plain TEXT, not markup — the toast renders it as text.
  final String icon;
  final String price;
  final double priceValue;

  /// `{coins}` and `{gems}` are substituted at render time. [descHard] replaces
  /// it in Pro mode, where energy is per-player fitness rather than team pips.
  final String? desc;
  final String? descHard;

  final int? coins;
  final bool coinsScaleWithDivision;
  final int? energyAdd;
  final int? energy;
  final bool energyDirector;
  final int? gems;
  final int? vipCoinsPerWin;
  final int? vipDays;
  final bool vipPrestigeLinked;
  final bool styleVault;
  final bool oneTime;
  final bool popular;
  final String? bonus;
  final String? eventGated;
}

/// The shelf, in display order.
const List<IapProduct> products = [
  // ── Coin bundles ──────────────────────────────────────────────────────────
  // All four share the same icon. The tiers are distinguished on the shop tiles
  // by drawing 1/2/3/5 actual coins, and every bundle says "coins" rather than
  // naming an unrelated container: this used to run bag / gem / bank / crown,
  // which told the player nothing about the amount and put the GEM currency's
  // glyph on a coin pack.
  IapProduct(
    id: 'coins_small',
    sku: 'com.mergeempirefc.coins_small',
    type: 'consumable',
    category: 'coins',
    name: 'Bag of Coins',
    icon: '💰',
    desc: '{coins} coins + 5 energy',
    price: '£0.99',
    priceValue: 0.99,
    coins: 5000,
    energyAdd: 5,
  ),
  IapProduct(
    id: 'coins_medium',
    sku: 'com.mergeempirefc.coins_medium',
    type: 'consumable',
    category: 'coins',
    name: 'Chest of Coins',
    icon: '💰',
    desc: '{coins} coins + 15 energy',
    price: '£2.49',
    priceValue: 2.49,
    coins: 15000,
    energyAdd: 15,
    popular: true,
  ),
  IapProduct(
    id: 'coins_large',
    sku: 'com.mergeempirefc.coins_large',
    type: 'consumable',
    category: 'coins',
    name: 'Vault of Coins',
    icon: '💰',
    desc: '{coins} coins + 30 energy',
    price: '£5.99',
    priceValue: 5.99,
    coins: 50000,
    energyAdd: 30,
  ),
  IapProduct(
    id: 'coins_mega',
    sku: 'com.mergeempirefc.coins_mega',
    type: 'consumable',
    category: 'coins',
    name: 'Coin Mountain',
    icon: '💰',
    desc: '{coins} coins + 60 energy',
    price: '£12.99',
    priceValue: 12.99,
    coins: 150000,
    energyAdd: 60,
    bonus: 'BEST VALUE',
  ),

  // **EVERY COIN PACK CARRIES ENERGY, and the reference set is why.** Asked for
  // directly — "coin packs should have other things in them" — with every pack
  // in the shots holding four or five items and the coin count only the
  // headline.
  //
  // **Energy is the one that can be given twice.** A coin bundle is a
  // CONSUMABLE, bought as often as the player likes, and the two obvious
  // sweeteners are not: the scout voucher is one-at-a-time by design
  // (`anyVoucherArmed` blocks a second across the whole ladder), and both coin
  // boosts are per-season FLAGS compared against the current season rather than
  // stacking timers — buy either pack twice in a season and the second pays
  // nothing. Energy is additive, has a Pro-mode branch already written, and is
  // what the reference set actually bundles.
  //
  // **And not gems**, which is the other thing the shots suggest: every gem
  // price in this game is quoted against one rate, so a coin bundle handing out
  // gems discounts the whole catalogue and squeezes the Style Vault's ceiling
  // with it.
  //
  // The screen half needed nothing: `PackContentsRow` draws whatever
  // `packContents` returns and that function has read `energyAdd` all along.

  // The coin component scales with division on grant, so the pack keeps its
  // value late-game — at Champions Cup it pays 10M instead of 10k. Energy is a
  // fixed ten-pip top-up.
  IapProduct(
    id: 'starter_pack',
    sku: 'com.mergeempirefc.starter_pack',
    type: 'non_consumable',
    category: 'bundle',
    name: 'Starter Pack',
    icon: '🎁',
    desc: '{coins} coins + 10 Energy — re-granted every reset!',
    descHard:
        '{coins} coins + fully refresh squad fitness — re-granted every reset!',
    price: '£1.99',
    priceValue: 1.99,
    coins: 10000,
    coinsScaleWithDivision: true,
    energyAdd: 10,
    oneTime: true,
  ),

  IapProduct(
    id: 'vip_pass',
    sku: 'com.mergeempirefc.vip_pass',
    type: 'non_consumable',
    category: 'vip',
    name: 'VIP Manager Pass',
    icon: '🌟',
    desc: '×2 income + bonus coins (scales with division) + 10s match cooldown '
        '· 30 days',
    price: '£4.99',
    priceValue: 4.99,
    vipCoinsPerWin: 200,
    vipDays: 30,
    popular: true,
    bonus: 'PREMIUM',
  ),

  // A permanent energy upgrade that survives a reset.
  IapProduct(
    id: 'energy_director',
    sku: 'com.mergeempirefc.energy_director',
    type: 'non_consumable',
    category: 'bundle',
    name: 'Energy Director',
    icon: '⚡',
    desc: 'Never wait on energy again — +50 now · bigger 15-cap tank · refills '
        '33% faster · permanent, even after resets!',
    descHard: 'Full squad fitness refresh right now, plus ~33% faster recovery '
        'forever — even after resets!',
    price: '£7.99',
    priceValue: 7.99,
    energyAdd: 50,
    energyDirector: true,
    oneTime: true,
    bonus: 'PERMANENT',
  ),

  // ── Gem bundles ───────────────────────────────────────────────────────────
  // The ONLY way to buy gems. There is deliberately no coin-to-gem exchange: the
  // moment coins can become gems, gems inherit the run's inflation and stop
  // being hard currency.
  //
  // Anchored at about 20p a gem for the entry bundle, improving with size. Every
  // rung must be a real step up, or the rational move is to buy the cheapest one
  // forever and the ladder is decoration.
  //
  // THE CEILING ON STEEPNESS, which is the easy thing to get wrong: a coin ladder
  // can discount as hard as it likes, because coins do not price a catalogue. A
  // GEM ladder cannot. Every gem price in the game is quoted against one rate,
  // and the rate a player actually pays is whichever rung they buy — so a steeper
  // ladder quietly sells the whole catalogue at a discount and squeezes the Style
  // Vault's ceiling down with it.
  IapProduct(
    id: 'gems_5',
    sku: 'com.mergeempirefc.gems_5',
    type: 'consumable',
    category: 'gems',
    name: 'Pocket of Gems',
    icon: '💎',
    desc: '{gems} gems',
    price: '£0.99',
    priceValue: 0.99,
    gems: 5,
  ),
  IapProduct(
    id: 'gems_15',
    sku: 'com.mergeempirefc.gems_15',
    type: 'consumable',
    category: 'gems',
    name: 'Casket of Gems',
    icon: '💎',
    desc: '{gems} gems',
    price: '£1.99',
    priceValue: 1.99,
    gems: 15,
  ),
  IapProduct(
    id: 'gems_35',
    sku: 'com.mergeempirefc.gems_35',
    type: 'consumable',
    category: 'gems',
    name: 'Hoard of Gems',
    icon: '💎',
    desc: '{gems} gems',
    price: '£3.99',
    priceValue: 3.99,
    gems: 35,
    bonus: 'BEST VALUE',
  ),

  // Every manager look pack at once, instead of a rewarded video per pack.
  //
  // The price is DERIVED: the best gem rate times the gems in the full set, minus
  // a margin. So it moves only when a pack price, the pack count or the bundle
  // ladder moves — and a test holds the line that the Vault still undercuts every
  // other way of buying the same packs. It has to: it is the SKU we most want
  // sold, and one that loses to a cheaper bundle reads as a trap.
  //
  // The forward promise — "and everything we add later" — is worth more than the
  // current contents and is free to keep, because ownership of the Vault is
  // checked before pack ownership.
  IapProduct(
    id: 'style_vault',
    sku: 'com.mergeempirefc.style_vault',
    type: 'non_consumable',
    category: 'cosmetic',
    name: 'Style Vault',
    icon: '🎩',
    desc: 'Unlock every manager look pack — and every one we add later',
    price: '£4.49',
    priceValue: 4.49,
    oneTime: true,
    styleVault: true,
  ),
];

final Map<String, IapProduct> _byId = {for (final p in products) p.id: p};

/// A product by id, or null.
IapProduct? getProduct(String? id) => id == null ? null : _byId[id];

/// Coin bundle amounts scale with division so they stay meaningful at every
/// level.
const Map<String, int> divisionCoinMult = {
  'sunday_league': 1,
  'amateur_cup': 3,
  'regional_league': 10,
  'national_league': 30,
  'elite_league': 100,
  'continental': 400,
  'champions_cup': 1000,
};

int getDivisionCoinMult(Map<String, dynamic>? state) =>
    divisionCoinMult['${_map(state?['progression'])?['currentDivision']}'] ?? 1;

/// A coin bundle's real coins-per-pound, as a percentage improvement over the
/// cheapest bundle.
///
/// Computed from the actual price and coins so the shop's "+X%" badges can never
/// drift out of sync with the numbers again — they used to be hand-typed and were
/// wrong by two to three times.
int getCoinBundleValuePct(IapProduct product) {
  final bundles = [
    for (final p in products)
      if (p.category == 'coins') p,
  ];
  final cheapest = bundles.reduce((a, b) => a.priceValue < b.priceValue ? a : b);
  final baseRate = cheapest.coins! / cheapest.priceValue;
  final rate = product.coins! / product.priceValue;
  return _jsRound((rate / baseRate - 1) * 100);
}

/// The VIP pass's coin bonus — always worth `vipCoinsPerWin` league wins at the
/// current division.
int getVipCoins(Map<String, dynamic>? state) {
  final div = getDivision(
    '${_map(state?['progression'])?['currentDivision'] ?? 'sunday_league'}',
  );
  final product = getProduct('vip_pass');
  return _jsRound((product?.vipCoinsPerWin ?? 200) * div.matchRevenueBase);
}

/// The coins a product actually grants at the current division.
///
/// The single source of truth for shop copy, so a displayed figure always matches
/// what [purchaseProduct] pays out rather than a stale hardcoded base. Mirrors
/// the grant branches below exactly.
num getProductGrantCoins(Map<String, dynamic>? state, IapProduct? product) {
  if (product == null) return 0;
  if (product.vipCoinsPerWin != null) return getVipCoins(state);
  final coins = product.coins;
  if (coins == null) return 0;
  final scales = product.category == 'coins' || product.coinsScaleWithDivision;
  return coins * (scales ? getDivisionCoinMult(state) : 1);
}

/// Visible products for the main shop — hides event-gated bundles.
List<IapProduct> getShopProducts() => [
  for (final p in products)
    if (p.eventGated == null) p,
];

/// Products gated to a specific ACTIVE event.
List<IapProduct> getEventProducts(Map<String, dynamic>? state, String? eventId) {
  final active = _map(state?['events'])?['active'];
  final isActive = active is List && active.contains(eventId);
  return [
    for (final p in products)
      if (p.eventGated == eventId && isActive) p,
  ];
}

/// What a purchase did.
typedef PurchaseResult = ({bool ok, String? reason, IapProduct? product});

/// Applies what a purchase grants.
///
/// This is the reward step, not the payment step: it runs synchronously once
/// native billing has completed, and directly with no payment on a dev build. The
/// payment half is M4.
PurchaseResult purchaseProduct(Map<String, dynamic> state, String? productId) {
  final product = getProduct(productId);
  if (product == null) {
    return (ok: false, reason: 'unknown_product', product: null);
  }

  // The shop branch is created UP FRONT rather than inside two of the grant
  // branches, which is what the JS does. There, a coin bundle bought against a
  // state with no `shop` throws on `state.shop.totalSpent` — unreachable in the
  // app because the schema always writes the branch, but a real latent crash, and
  // the JS's own `state.shop = state.shop ?? {}` in the other branches shows the
  // defensiveness was intended. Creating it here cannot change behaviour where
  // the branch already exists, which in a real save is always.
  final shop = _map(state['shop']) ?? (state['shop'] = <String, dynamic>{});
  final boosts = _map(state['boosts']) ?? (state['boosts'] = <String, dynamic>{});

  final purchasedIds = shop['purchasedIds'];
  if (product.oneTime &&
      purchasedIds is List &&
      purchasedIds.contains(productId)) {
    return (ok: false, reason: 'already_purchased', product: null);
  }

  if (product.id == 'vip_pass' && (_num(shop['vipExpiresAt']) ?? 0) > now()) {
    return (ok: false, reason: 'vip_already_active', product: null);
  }

  final resources = state['resources'] as Map<String, dynamic>;

  // Coin bundles, and anything marked as scaling, keep their value late-game.
  if (product.vipCoinsPerWin != null) {
    resources['fanCoins'] = (_num(resources['fanCoins']) ?? 0) + getVipCoins(state);
  } else if (product.coins != null) {
    final scales = product.category == 'coins' || product.coinsScaleWithDivision;
    final mult = scales ? getDivisionCoinMult(state) : 1;
    resources['fanCoins'] =
        (_num(resources['fanCoins']) ?? 0) + product.coins! * mult;
  }

  // Purchased energy. In PRO mode there is no team pip pool — energy is
  // per-player fitness — so an energy buy banks a FULL extra bar on top of
  // current fitness, up to the overfill buffer: a player at 100% goes to 200% and
  // stays at top rating until it drains back below 100%. That mirrors Casual,
  // where the pack stacks pips ON TOP of the current value and can exceed the
  // regen cap (regen itself still caps).
  if (product.energyAdd != null || product.energy != null) {
    if (_flag(_map(state['settings'])?['hardMode'])) {
      topUpAllEnergy(state, now(), 1, overfill: true);
    } else {
      final energy = _map(state['energy']) ??
          (state['energy'] = <String, dynamic>{'current': 0});
      if (product.energyAdd != null) {
        energy['current'] = (_num(energy['current']) ?? 0) + product.energyAdd!;
      }
      if (product.energy != null) {
        energy['current'] = math.max(_num(energy['current']) ?? 0, Energy.max);
      }
    }
  }

  // Gems go through addGems rather than a bare increment, so the balance is
  // sanitised, the HUD hears about it, and the purchase is logged with the same
  // shape as an earned one.
  if (product.gems != null) addGems(state, product.gems!, 'iap');

  if (product.energyDirector) shop['energyUpgraded'] = true;

  if (product.vipDays != null) {
    final ms = product.vipDays! * 24 * 60 * 60 * 1000;
    shop['vipExpiresAt'] = now() + ms;
    // VIP also doubles idle income, via a boost flag.
    boosts['vipActive'] = true;
    boosts['vipExpiresAt'] = now() + ms;
  }

  // NOTE: no product carries this flag today — `vip_pass` runs on `vipDays`, a
  // wall clock. The branch is kept because the comment above `vip_pass` in the JS
  // still describes a prestige-linked pass with no timer, so the two disagree and
  // this is the half that would be switched back on. See docs/REMAINING.md.
  if (product.vipPrestigeLinked) {
    // Active until the player's next prestige reset, stamped with the current
    // level so the prestige can detect and clear it. The far-future sentinel
    // keeps the ordinary `expiresAt > now` checks happy without a timer.
    final prestigeLevel = _num(_map(state['prestige'])?['level'])?.toInt() ?? 0;
    shop['vipPrestigeLevel'] = prestigeLevel;
    shop['vipExpiresAt'] = maxSafeInteger;
    boosts['vipActive'] = true;
    boosts['vipPrestigeLevel'] = prestigeLevel;
    boosts['vipExpiresAt'] = maxSafeInteger;
  }

  if (product.oneTime) {
    final ids = shop['purchasedIds'];
    if (ids is List) {
      ids.add(productId);
    } else {
      shop['purchasedIds'] = <Object?>[productId];
    }
  }

  shop['totalSpent'] = (_num(shop['totalSpent']) ?? 0) + product.priceValue;

  emit('coins:updated', resources['fanCoins']);
  if (product.energy != null || product.energyAdd != null) {
    emit('energy:updated', _map(state['energy'])?['current']);
  }
  emit('purchase:complete', {'product': product.id});

  logAppEvent('iap_purchase', {
    'product_id': productId,
    'price_value': product.priceValue,
    'currency': 'GBP',
    'one_time': product.oneTime,
    'division':
        _map(state['progression'])?['currentDivision'] ?? 'unknown',
  });

  return (ok: true, reason: null, product: product);
}

/// Is VIP currently live?
bool isVipActive(Map<String, dynamic>? state) =>
    (_num(_map(state?['shop'])?['vipExpiresAt']) ?? 0) > now();

/// Milliseconds of VIP left.
int vipTimeRemaining(Map<String, dynamic>? state) => math
    .max(0, (_num(_map(state?['shop'])?['vipExpiresAt']) ?? 0) - now())
    .toInt();
