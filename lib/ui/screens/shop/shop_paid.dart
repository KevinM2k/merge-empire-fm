/// The real-money shelves: Offers, Gems and Coins, plus Restore Purchases.
///
/// **THE TILES BUY NOW.** They were dead behind `paidDisabledReason()` while
/// there was no bridge, and `services/iap_purchase.dart` is that bridge — which
/// is also why `purchaseProduct` is STILL not called anywhere in this file. It
/// is the GRANT step, what runs once a store has confirmed a payment, so a
/// button wired straight to it hands out paid goods for free; `initiatePurchase`
/// is what asks the store first and calls it after.
///
/// Every tile shows its real price whatever the state of billing — a shelf that
/// hides its prices stops being a shop.
library;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/iap_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_copy.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_owned.dart';
import 'package:merge_empire_fc/ui/screens/shop/coin_pack_art.dart';
import 'package:merge_empire_fc/ui/screens/shop/gem_pack_art.dart';
import 'package:merge_empire_fc/ui/screens/shop/pack_contents.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_art.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_providers.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_section.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_tiles.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
import 'package:merge_empire_fc/engine/iap_billing_policy.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/services/iap_billing.dart';
import 'package:merge_empire_fc/services/iap_purchase.dart';
import 'package:merge_empire_fc/ui/popups/age_gate_sheet.dart';
import 'package:merge_empire_fc/ui/screens/shop/purchase_flow.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/util/time.dart';

/// Said on every real-money control, so a player is told the feature is coming
/// rather than left with a button that does nothing.
/// Null once the thing behind the button exists.
///
/// **Nullable so a tile can tell a true badge from a lie.** The free shelf was
/// printing "Already ready" AND "Coming soon" on the same tile: the first is
/// the ad GATE reporting itself open, the second is there being no ad SDK, and
/// both were true statements that contradict each other to a player.
String? paidDisabledReason() =>
    billingReady || simulatePurchases ? null : t('settings.comingSoon');

/// **What a refusal is called on screen, and the JS's own branch order.**
/// Every string here is shipped copy keyed to `iapEngine`'s wire reasons.
///
/// Two of the branches are decisions rather than mappings:
///
/// - **`cancelled` says nothing.** The player pressed Back, which is an answer
///   rather than a fault, and a toast for it is the app arguing with them.
/// - **"Try again" is the one thing NOT to say to a SKU the store does not
///   know.** A product missing or inactive in the console never fixes itself,
///   so a player told to retry would tap forever. The JS spends a paragraph on
///   this and gives all four of those reasons one calmer line.
String? purchaseRefusalCopy(String? reason) => switch (reason) {
  null || 'cancelled' || 'parental_consent_required' => null,
  'already_purchased' => t('shop.toast.already_purchased'),
  'vip_already_active' => t('toast.vip_already_active'),
  'product_not_found' ||
  'no_offer' ||
  'billing_unavailable' ||
  'not_initialized' => t('shop.toast.unavailable'),
  _ => t('shop.toast.purchase_failed'),
};

/// Tap Buy on a real-money tile.
///
/// **The confirm card comes first, on every real-money tap** — the JS's own
/// comment on the line that binds these tiles — and the store's payment sheet
/// after it. See `confirmRealMoneyPurchase` for why two are not one too many.
Future<void> buyProduct(
  BuildContext context,
  WidgetRef ref,
  IapProduct product,
  String name,
  String price,
) async {
  final game = ref.read(gameProvider);
  final state = game.state;
  if (state == null) return;
  final ok = await confirmRealMoneyPurchase(
    context,
    productId: product.id,
    icon: product.icon,
    name: name,
    description: productDesc(product, state: state, hardMode: hardModeOf(state)),
    price: price,
    android: defaultTargetPlatform == TargetPlatform.android,
  );
  if (!ok || !context.mounted) return;

  final result = await initiatePurchase(
    state,
    product.id,
    (apply) => game.update(apply),
  );
  if (result.ok) {
    emit('toast:success', t('shop.toast.purchased', {
      'icon': product.icon,
      'name': name,
    }));
    return;
  }
  // A verified minor with no consent on file gets the notice, not a refusal —
  // the whole point of the gate is that it is answerable.
  if (result.reason == 'parental_consent_required') {
    if (!context.mounted) return;
    if (await showAgeGateSheet(context)) {
      emit('toast:success', t('shop.toast.purchases_unlocked'));
    }
    return;
  }
  if (purchaseRefusalCopy(result.reason) case final line?) {
    emit('toast:error', line);
  }
}

/// Pro mode changes what a pack DOES, so the confirm card's description has to
/// know which mode it is describing.
bool hardModeOf(Map<String, dynamic> state) {
  final settings = state['settings'];
  return settings is Map<String, dynamic> && settings['hardMode'] == true;
}

/// What the store has told us about, or null when billing is not running.
///
/// **Null shows every tile and empty hides them all**, which is the rule
/// `iapClient.js` argues for at length — see [StoreCatalogue]. It is null today
/// because there is no plugin, so the shop is unchanged; what this buys is that
/// the day one lands, a SKU created but not Active stops rendering a tile that
/// can never complete.
final storeCatalogueProvider = FutureProvider<StoreCatalogue>(
  (ref) => storeCatalogue(),
);

/// The tiles for one paid category, without a shelf around them — the currency
/// sheet draws its own frame around the same tiles the tab shows.
List<Widget> paidTilesFor(
  WidgetRef ref,
  Set<String> categories, {
  bool featured = false,
}) {
  // **A SKU THE STORE CANNOT SELL DOES NOT GET A TILE.** A product created in
  // the console but not Active comes back with no purchasable offer and every
  // `buy` fails `no_offer` forever, so a tile at the catalogue's fallback price
  // is one that can never complete — the state a partial rollout leaves you in,
  // because SKUs go live one at a time. Null is "nobody to ask", which offers
  // everything; see [canOffer].
  final known = ref.watch(storeCatalogueProvider).valueOrNull;
  // **What the save already owns.** Watched rather than read: buying one of
  // these changes it, and a tile that kept saying "Buy" after a purchase is how
  // a player is invited into a refusal.
  final save = ref.watch(gameProvider).state;
  final nowMs = now();
  return [
  for (final tile
      in ref
          .watch(paidTilesProvider)
          .where((t) => categories.contains(t.product.category)))
    if (canOffer(tile.product.sku, known))
    if (ownedStateFor(tile.product, save, nowMs: nowMs) case final owned)
    ShopTile(
      tileKey: tile.product.id,
      title: tile.name,
      subtitle: tile.desc,
      // The shelf's own art, which nothing had ever passed — so every shelf in
      // the shop was text with a price under it.
      glyph: shopProductGlyph(tile.product),
      // The STORE's price when it has one: the catalogue's is a fallback in
      // one currency, and a player in Japan being shown a pound sign is the
      // whole reason the store is asked.
      // Owned, the button carries the STATE rather than the price: a price on
      // something you already have is an offer to buy it twice.
      price: owned.buttonKey != null
          ? t(owned.buttonKey!)
          : priceFor(tile.product.sku, tile.product.price, known),
      // Real money, and the only tone that leaves the game to be paid.
      tone: StoreTone.cash,
      // **A CORNER FLASH ON A HERO, a line of text on a small tile.** The
      // popular tag was a grey sentence in the middle of the card wherever it
      // appeared — which on the shelf the shop OPENS on is the one place it is
      // worth shouting. See [ShopTile.corner]; the hero's price is on its own
      // line at the bottom now, so the corner is free for it.
      badge: tile.product.popular && !featured ? t('shop.most_popular') : null,
      corner: tile.product.popular && featured
          ? t('shop.most_popular')
          : null,
      disabledReason: owned.noteKey != null
          ? t(owned.noteKey!, {'days': owned.days})
          : paidDisabledReason(),
      onBuy: owned.owned
          ? null
          : () => buyProduct(
              ref.context,
              ref,
              tile.product,
              tile.name,
              priceFor(tile.product.sku, tile.product.price, known),
            ),
      featured: featured,
      // The spec's `.shop-hero__ribbon`: the product's own bonus line, or the
      // one-time badge for the two that are bought once and kept. It was a
      // line of grey text under the description, which is the same words in
      // the quietest place on the card.
      // A lapsed VIP's ribbon REPLACES the bonus line — "REACTIVATE" is the one
      // thing worth saying to somebody who has paid for this before — and an
      // active one has no ribbon at all.
      ribbon: owned.ribbonKey != null
          ? t(owned.ribbonKey!)
          : owned.owned
          ? null
          : productBonus(tile.product) ??
                (_oneTime.contains(tile.product.id)
                    ? t('product.starter_pack.badge_onetime')
                    : null),
      // **WHAT IS IN THE BOX, on the offers shelf only.** See
      // `pack_contents.dart` — the three heroes stated their contents in prose
      // and nowhere else, and a grid tile has no room for a strip. An owned
      // tile drops it: the question a strip answers is what the money buys, and
      // that is not the question in front of somebody who has already paid.
      contents: featured && !owned.owned
          ? PackContentsRow(
              tileKey: tile.product.id,
              items: packContents(tile.product, save),
            )
          : null,
      accent: _offerInk[tile.product.id],
      skin: featured
          ? offerSkinFor(
              tile.product.id,
              Theme.of(ref.context).extension<KitTheme>()!,
            )
          : null,
    ),
  ];
}

/// Bought once and kept, so the ribbon says so. The spec badges both.
const Set<String> _oneTime = {'starter_pack', 'energy_director'};

/// **A COLOUR PER OFFER.** The spec gives each hero its own — VIP purple, the
/// Energy Director blue — so three offers in a column read as three things
/// rather than one card repeated. Anything not named here keeps the shelf's
/// gold.
const Map<String, Color> _offerInk = {
  'vip_pass': Color(0xFFB77BFF),
  'energy_director': Color(0xFF64B5F6),
};

/// `.premium-vip`, `.premium-starter`, `.premium-director` — the background and
/// rim each hero wears in the spec, at 135deg, which is a top-left to
/// bottom-right sweep.
///
/// A null border takes the club's accent, which is what `.premium-starter`
/// asks for (`var(--color-accent)`).
const Map<String, ({List<Color> colors, Color? border, double width})>
_offerSkin = {
  'vip_pass': (
    colors: [Color(0xFF1A0050), Color(0xFF2A1200), Color(0xFF000000)],
    border: Color(0xFFFFD700),
    width: 2,
  ),
  'starter_pack': (
    colors: [Color(0xFF0A2A1A), Color(0xFF1A0A2A)],
    border: null,
    width: 1.5,
  ),
  'energy_director': (
    colors: [Color(0xFF0A1A2A), Color(0xFF001A0A)],
    border: Color(0xFFFFD54A),
    width: 1.5,
  ),
};

/// The hero's skin as the tile takes it, or null for a shelf item.
({Gradient gradient, Color border, double width})? offerSkinFor(
  String productId,
  KitTheme kit,
) {
  final skin = _offerSkin[productId];
  if (skin == null) return null;
  return (
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: skin.colors,
      // VIP is a three-stop with the middle at 60%; the other two are even.
      stops: skin.colors.length == 3 ? const [0, 0.6, 1] : null,
    ),
    border: skin.border ?? kit.accent,
    width: skin.width,
  );
}

class _PaidShelf extends ConsumerWidget {
  const _PaidShelf({
    required this.id,
    required this.categories,
    this.columns = 2,
    this.featured = false,
  });

  final ShopSectionId id;
  final Set<String> categories;

  /// How many tiles to a row. One is a shelf whose items are each worth the
  /// whole width.
  final int columns;

  /// The offers shelf, and only that one. See [ShopTile.featured].
  final bool featured;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ShopSectionFrame(
    id: id,
    child: ShopGrid(
      columns: columns,
      children: paidTilesFor(ref, categories, featured: featured),
    ),
  );
}

/// The line art a product wears on its tile.
///
/// The catalogue's `icon` is an emoji and stays one — the toast renders it as
/// text. A tile is not text: it gets the app's own icon set, and the coin
/// bundles get a drawn picture of the thing they are named after.
const Map<String, String> _productIcons = {
  'starter_pack': 'gift',
  'vip_pass': 'crown',
  'energy_director': 'bolt',
  'style_vault': 'bank',
};

/// **EVERY PICTURE IN THE SHOP GOES THROUGH [ShopArt].** It draws a bundled
/// illustration when the manifest has one for this product and the painter
/// below when it does not, which is every product today — so the shop looks
/// exactly as it did, and rendered art lands later without this function
/// changing. See `shop_art.dart`.
Widget shopProductGlyph(IapProduct product) => ShopArt(
  id: product.id,
  size: product.category == 'coins' || product.category == 'gems' ? 44 : 34,
  fallback: _drawnProductGlyph(product),
);

Widget _drawnProductGlyph(IapProduct product) {
  if (product.category == 'coins') {
    return CoinPackPicture(art: coinPackArtFor(product.id), size: 44);
  }
  if (product.category == 'gems') {
    // **A PICTURE PER PACK, not one gem for all three.** Every bundle on the
    // gems shelf wore the same 34px icon, so Pocket, Casket and Hoard were
    // three prices under three identical images. See [GemPackPicture] — and
    // the note there about `gemArt.js`, which is in a repo a cloud session
    // cannot read.
    return GemPackPicture(art: gemPackArtFor(product.id), size: 44);
  }
  return GameIcon(
    _productIcons[product.id] ?? 'tag',
    size: 34,
    color: const Color(0xFFFFD54A),
  );
}

/// Which shelf each currency lives on, so the sheet and the tab agree.
const Map<ShopSection, ({ShopSectionId id, Set<String> categories})>
currencyShelves = {
  ShopSection.coins: (id: ShopSectionId.coins, categories: {'coins'}),
  ShopSection.gems: (id: ShopSectionId.gems, categories: {'gems'}),
};

/// One-time and time-limited real-money items — the highest-converting slot,
/// which is why it is first.
class OffersSection extends StatelessWidget {
  const OffersSection({super.key});

  @override
  Widget build(BuildContext context) => const _PaidShelf(
    id: ShopSectionId.offers,
    categories: {'bundle', 'vip'},
    // **ONE PER ROW.** There are three of them and they are the shelf the shop
    // opens on: two up made the highest-converting slot in the game the same
    // size as a consumable, with the third sitting alone in a half-width tile
    // beside a gap.
    columns: 1,
    // And they LOOK like offers now — width alone did not do it. See
    // [ShopTile.featured].
    featured: true,
  );
}

/// Hard currency, and the only way to buy it — there is deliberately no
/// coin-to-gem exchange.
///
/// **The spec's own tiles, copied.** They were the shop's generic pane with a
/// price under it; `ShopScreen.js` draws a blue three-dimensional tile with the
/// pile on it, the number big, and the price as a green button — and an ODD
/// count runs the biggest pack full width as a hero rather than leaving half a
/// tile of dead space on the last row. Asked for by name, with the shipped
/// version as the reference.
class GemPacksSection extends ConsumerWidget {
  const GemPacksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packs = [
      for (final tile in ref.watch(paidTilesProvider))
        if (tile.product.category == 'gems') tile,
    ];
    // The last one, when there is an odd number of them. The JS's own rule.
    final hero = packs.length.isOdd ? packs.last : null;
    final grid = hero == null ? packs : packs.sublist(0, packs.length - 1);
    return ShopSectionFrame(
      id: ShopSectionId.gems,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < grid.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: GemPackTile(tile: grid[i])),
                    const SizedBox(width: 10),
                    Expanded(
                      child: i + 1 < grid.length
                          ? GemPackTile(tile: grid[i + 1])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          if (hero != null) GemPackTile(tile: hero, hero: true),
        ],
      ),
    );
  }
}

/// One gem bundle, as `.gem-pack-tile` / `.store-3d--gem`.
///
/// Every number here is the stylesheet's. A three-dimensional tile is a face, a
/// mid, a deep and an EDGE — the flat bar under it is what makes it read as
/// something with thickness rather than a coloured rectangle — plus a sheen
/// across the top third for a light source.
class GemPackTile extends ConsumerWidget {
  const GemPackTile({super.key, required this.tile, this.hero = false});

  final PaidTile tile;

  /// Full width, laid out as a row. The chest needs the room, and an odd count
  /// would otherwise leave half a tile of nothing beside it.
  final bool hero;

  /// `.store-3d--gem`, and the hero's own face.
  static const Color _rim = Color(0xFF63B8EC);
  static const Color _face = Color(0xFF2F86CB);
  static const Color _mid = Color(0xFF1C62A4);
  static const Color _deep = Color(0xFF114B81);
  static const Color _edge = Color(0xFF0B3960);
  static const Color _heroRim = Color(0xFFFFD257);
  static const Color _heroFace = Color(0xFF3590D8);
  static const Color _heroMid = Color(0xFF1D66AA);
  static const Color _heroDeep = Color(0xFF0F4A82);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artSize = hero ? 96.0 : 74.0;
    final art = ShopArt(
      id: tile.product.id,
      size: artSize,
      fallback: GemPackPicture(
        art: gemPackArtFor(tile.product.id),
        size: artSize,
      ),
    );
    final words = Column(
      crossAxisAlignment: hero
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${tile.product.gems ?? 0}',
          style: TextStyle(
            fontSize: hero ? 30 : 23,
            fontWeight: FontWeight.w900,
            height: 1.05,
            color: Colors.white,
            shadows: const [
              Shadow(color: Color(0x61000000), offset: Offset(0, 2)),
            ],
          ),
        ),
        Text(
          t('shop.gems_label').toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: Color(0xB8FFFFFF),
          ),
        ),
        SizedBox(height: hero ? 6 : 8),
        // The price reads as a BUTTON, not a caption: it is what the tile is
        // selling.
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: hero ? 16 : 14,
            vertical: hero ? 6 : 5,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF4ECB59), Color(0xFF35A83F)],
            ),
            borderRadius: BorderRadius.all(Radius.circular(10)),
            boxShadow: [
              BoxShadow(color: Color(0xFF22702A), offset: Offset(0, 3)),
            ],
          ),
          child: Text(
            tile.product.price,
            style: TextStyle(
              fontSize: hero ? 15 : 13,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: const [
                Shadow(color: Color(0x47000000), offset: Offset(0, 1)),
              ],
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      label: '${tile.name} ${tile.product.price}',
      child: GestureDetector(
        key: ValueKey('shop-tile-${tile.product.id}'),
        // **THROUGH THE CONFIRM, like every other real-money tap.** The JS's
        // own comment on this line says gem bundles and the Vault used to
        // charge straight off the tile, so a mis-tap on a two-across grid was a
        // completed purchase with no interstitial.
        onTap: () => buyProduct(
          context,
          ref,
          tile.product,
          tile.name,
          priceFor(
            tile.product.sku,
            tile.product.price,
            ref.read(storeCatalogueProvider).valueOrNull,
          ),
        ),
        child: Container(
          padding: hero
              ? const EdgeInsets.fromLTRB(16, 12, 16, 12)
              : const EdgeInsets.fromLTRB(8, 13, 8, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: hero ? _heroRim : _rim, width: 2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: hero
                  ? const [_heroFace, _heroMid, _heroDeep]
                  : const [_face, _mid, _deep],
              stops: const [0, 0.55, 1],
            ),
            boxShadow: const [
              // The flat bar under the tile: this is the thickness.
              BoxShadow(color: _edge, offset: Offset(0, 4)),
              BoxShadow(
                color: Color(0x52000000),
                blurRadius: 14,
                offset: Offset(0, 7),
              ),
            ],
          ),
          // **CENTRED.** A `Stack`'s non-positioned children align to its
          // top-LEFT corner unless it is told otherwise, so the pile, the
          // number and the price all sat in the corner of the tile — reported
          // as the gem packs not being centred. The sheen and the ribbon are
          // `Positioned` and are unaffected.
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The sheen across the top third, so the card has a light source.
              const Positioned(
                top: -13,
                left: -16,
                right: -16,
                height: 62,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x29FFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
              if (hero)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [art, const SizedBox(width: 20), words],
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [art, const SizedBox(height: 2), words],
                ),
              // **A BANNER, not a rosette.** Both shelves wore a die-cut seal
              // stuck on the corner; asked for again from the couch, with the
              // banner named — a rosette is a sticker somebody slapped on, and
              // on a tile this small it sat over the pile it was recommending
              // and pushed the crown off its own corner. The corner flash is
              // the shop's own device, already on the offers hero, and it is
              // part of the tile rather than something on top of it.
              if (tile.bonus case final bonus?)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: CornerBanner(
                        key: ValueKey('shop-seal-${tile.product.id}'),
                        text: bonus,
                        ink: const Color(0xFFFFC02E),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft currency, and the one shelf with its own tile.
///
/// The HUD's coin chip opens these as a sheet (`currency_sheet.dart`), so this
/// shelf's position in the list does not govern how players reach it.
class CoinPacksSection extends ConsumerWidget {
  const CoinPacksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundles = [
      for (final t in ref.watch(paidTilesProvider))
        if (t.product.category == 'coins') t.product,
    ];
    final mult = ref.watch(coinMultProvider);
    return ShopSectionFrame(
      id: ShopSectionId.coins,
      child: ShopGrid(
        children: [
          for (var i = 0; i < bundles.length; i++)
            CoinPackTile(product: bundles[i], rank: i, coinMult: mult),
        ],
      ),
    );
  }
}

/// The four tiers of coin tile, bronze up to diamond — a `box-shadow: inset`
/// wash off the top edge in the JS, which Flutter cannot draw inward, so it is a
/// gradient over the tile's own.
const List<Color> _coinTierInk = [
  Color(0xFFCF8F4E),
  Color(0xFFCBD5DD),
  Color(0xFFFFD54A),
  Color(0xFF86D8FF),
];

/// One coin bundle: the pile, what it pays at THIS division, and its price.
///
/// Not a [ShopTile]. Four things a generic tile has no room for are exactly what
/// tells the bundles apart — the drawn pile, the tier wash, the crown on the
/// popular one, and a badge that is either the computed coins-per-pound
/// improvement or the "most popular" tag.
class CoinPackTile extends ConsumerWidget {
  const CoinPackTile({
    super.key,
    required this.product,
    required this.rank,
    required this.coinMult,
  });

  final IapProduct product;

  /// Cheapest first — it picks the pile and the tier.
  final int rank;
  final int coinMult;

  /// The ribbon over the tile, and whether it is the popular tag or a value
  /// claim. The JS's rules exactly, and the value figure is COMPUTED: the
  /// hand-typed ones were wrong by two to three times.
  ({String text, bool popular})? get _badge {
    if (product.id == 'coins_large') return null;
    if (product.id == 'coins_medium') {
      return (text: t('shop.most_popular'), popular: true);
    }
    final bonus = productBonus(product);
    if (bonus != null) return (text: bonus, popular: false);
    final pct = getCoinBundleValuePct(product);
    return pct > 0
        ? (text: t('shop.coin_value_badge', {'pct': pct}), popular: false)
        : null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final ink = _coinTierInk[rank.clamp(0, _coinTierInk.length - 1)];
    final badge = _badge;
    final coins = (product.coins ?? 0) * coinMult;
    final blocked = paidDisabledReason();
    final price = priceFor(
      product.sku,
      product.price,
      ref.watch(storeCatalogueProvider).valueOrNull,
    );

    return Stack(
      // The badge sits ON the tile's top edge, half outside it.
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          key: ValueKey('shop-tile-${product.id}'),
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: product.popular ? kit.accentBright : kit.border,
            ),
            gradient: LinearGradient(
              begin: const Alignment(-0.6, -1),
              end: const Alignment(0.6, 1),
              colors: [kit.surface2, kit.surface],
            ),
            boxShadow: [
              const BoxShadow(
                color: Color(0x38000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
              if (product.popular)
                BoxShadow(
                  color: kit.accent.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The tier's wash, over the tile's own surface but under the pile.
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            ink.withValues(alpha: 0.28),
                            ink.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 52,
                    // A PICTURE of the thing it is called, not a count of coins.
                    // All four bundles share one 💰 in the catalogue and the JS
                    // tells them apart with a cluster of 1/2/3/5 — which is a
                    // quantity and makes no sense of "Coin Vault".
                    child: Center(
                      child: ShopArt(
                        id: product.id,
                        size: 52,
                        fallback: CoinPackPicture(
                          art: coinPackArtFor(product.id),
                          size: 52,
                        ),
                      ),
                    ),
                  ),
                  // **The crown moved to the LEFT** when the value badge became
                  // a seal: the seal is stuck on the top-right corner, which is
                  // where a shopfront puts one, and the crown was sitting under
                  // it.
                  if (product.popular)
                    const Positioned(
                      top: 0,
                      left: 0,
                      child: Text('👑', style: TextStyle(fontSize: 15)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                productName(product),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                // What THIS save would be paid, which past Sunday League is not
                // the figure on the product at all.
                t('shop.coins_count', {'n': formatCoins(coins)}) +
                    (coinMult > 1
                        ? t('shop.division_mult', {'mult': coinMult})
                        : ''),
                textAlign: TextAlign.center,
                // **YELLOW ON WHITE, WHICH IS NOT A COLOUR.** This was the raw
                // `coinGold` — `#FFD700`, 1.1:1 on the near-white surface a
                // light-mode tile is built from, so the one line saying what the
                // bundle actually pays was invisible. Reported from the couch.
                // `coinFigureInk` is the pair the rest of the game answers this
                // with: money stays yellow and the SHADE moves, which is the
                // JS's own light-block `--color-gold`.
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: coinFigureInk(context),
                  height: 1.3,
                ),
              ),
              const Spacer(),
              const SizedBox(height: 10),
              // **IT BUYS.** `onPressed: null` on a plain `ElevatedButton` — the
              // one real-money control in this file the bridge landing never
              // reached, so the coin shelf was four dead grey buttons beside a
              // gem shelf that charges. The JS's own markup is
              // `store-btn store-btn--cash` wired to `_showPurchaseConfirm`,
              // which is `buyProduct` here: green, because green is real money.
              // Live even while `blocked` has something to say, which is what
              // every other real-money tile on this shelf does: the note
              // explains, the store gives the real refusal, and a pre-dead
              // button would take the price off the screen with it.
              StoreButton(
                key: ValueKey('shop-buy-${product.id}'),
                tone: StoreTone.cash,
                label: price,
                onTap: () => buyProduct(
                  context,
                  ref,
                  product,
                  productName(product),
                  price,
                ),
              ),
              if (blocked case final why?)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    why,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kit.textMuted, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
        // **A BANNER ACROSS THE CORNER — not a rosette stuck on it.** Asked for
        // from the couch, with the banner named: the seal is a sticker on top of
        // the tile, and on one this size it sat over the pile and shoved the
        // crown across to the other corner to make room. A corner flash is the
        // tile's own furniture, and it is what the offers hero already wears —
        // one device for a value claim in this shop rather than two.
        if (badge case final flash?)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Align(
                alignment: Alignment.topRight,
                child: CornerBanner(
                  key: ValueKey('shop-badge-${product.id}'),
                  text: flash.text,
                  ink: flash.popular
                      ? kit.accentBright
                      : const Color(0xFFFF9800),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Required by App Store guidelines, and correctly the LAST thing on the screen
/// rather than buried mid-shop.
class RestoreRow extends ConsumerStatefulWidget {
  const RestoreRow({super.key});

  @override
  ConsumerState<RestoreRow> createState() => _RestoreRowState();
}

class _RestoreRowState extends ConsumerState<RestoreRow> {
  bool _running = false;

  /// **Only NON-CONSUMABLES come back.** A coin pack is consumed the moment it
  /// is granted and the store lists it forever; re-granting one on every
  /// restore is a free coin button. `restorePurchases` is where that is
  /// decided, and it grants only what this save does not already own.
  Future<void> _restore() async {
    final game = ref.read(gameProvider);
    final state = game.state;
    if (state == null) return;
    setState(() => _running = true);
    final result = await restorePurchases(state, (apply) => game.update(apply));
    if (!mounted) return;
    setState(() => _running = false);
    // **Nothing owned and nothing reachable read the same from here**, which is
    // the JS's own conflation and the right one: neither is a failure the
    // player can act on, and both leave the save exactly as it was.
    emit(
      result.restored.isEmpty ? 'toast:info' : 'toast:success',
      t(
        result.restored.isEmpty
            ? 'shop.toast.restore_failed'
            : 'shop.toast.restore_success',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    // A quiet ROW rather than a stranded button with a caption under it. It is
    // the last thing on the screen and it is housekeeping — it belongs to the
    // shop's furniture, not to its shelves, and the "coming soon" underneath was
    // the fourth time that sentence appeared on one screen.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 32),
      child: Material(
        color: kit.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: const ValueKey('shop-restore'),
          borderRadius: BorderRadius.circular(10),
          // **Dead while it is running**, because a restore is several store
          // round trips and a second tap would grant the same non-consumables
          // twice — the JS disables its button and swaps the label for the
          // same reason.
          onTap: _running ? null : _restore,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.restore, size: 17, color: kit.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _running ? '…' : t('shop.restore_purchases'),
                    style: TextStyle(
                      color: kit.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: kit.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
