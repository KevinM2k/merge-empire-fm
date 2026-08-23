/// The real-money shelves: Offers, Gems and Coins, plus Restore Purchases.
///
/// Every control here is DEAD until M4 lands the billing bridge, and every tile
/// still shows its real price — a shelf that hides its prices stops being a
/// shop. `purchaseProduct` is deliberately not called anywhere in this file: it
/// is the GRANT step, what runs once a store has confirmed a payment, so a
/// button wired to it would hand out paid goods for free.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/iap_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_copy.dart';
import 'package:merge_empire_fc/ui/screens/shop/coin_cluster.dart';
import 'package:merge_empire_fc/ui/screens/shop/coin_pack_art.dart';
import 'package:merge_empire_fc/ui/screens/shop/gem_pack_art.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_providers.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_section.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_tiles.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
import 'package:merge_empire_fc/util/format.dart';

/// Said on every real-money control, so a player is told the feature is coming
/// rather than left with a button that does nothing.
/// Null once the thing behind the button exists.
///
/// **Nullable so a tile can tell a true badge from a lie.** The free shelf was
/// printing "Already ready" AND "Coming soon" on the same tile: the first is
/// the ad GATE reporting itself open, the second is there being no ad SDK, and
/// both were true statements that contradict each other to a player.
String? paidDisabledReason() => t('settings.comingSoon');

/// The tiles for one paid category, without a shelf around them — the currency
/// sheet draws its own frame around the same tiles the tab shows.
List<Widget> paidTilesFor(
  WidgetRef ref,
  Set<String> categories, {
  bool featured = false,
}) => [
  for (final tile
      in ref
          .watch(paidTilesProvider)
          .where((t) => categories.contains(t.product.category)))
    ShopTile(
      tileKey: tile.product.id,
      title: tile.name,
      subtitle: tile.desc,
      // The shelf's own art, which nothing had ever passed — so every shelf in
      // the shop was text with a price under it.
      glyph: shopProductGlyph(tile.product),
      price: tile.product.price,
      // Real money, and the only tone that leaves the game to be paid.
      tone: StoreTone.cash,
      badge: tile.product.popular ? t('shop.most_popular') : null,
      disabledReason: paidDisabledReason(),
      featured: featured,
      // The spec's `.shop-hero__ribbon`: the product's own bonus line, or the
      // one-time badge for the two that are bought once and kept. It was a
      // line of grey text under the description, which is the same words in
      // the quietest place on the card.
      ribbon:
          productBonus(tile.product) ??
          (_oneTime.contains(tile.product.id)
              ? t('product.starter_pack.badge_onetime')
              : null),
      accent: _offerInk[tile.product.id],
    ),
];

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

Widget shopProductGlyph(IapProduct product) {
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
class GemPackTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final art = GemPackPicture(
      art: gemPackArtFor(tile.product.id),
      size: hero ? 96 : 74,
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
        // Dead until the billing bridge lands, like every other real-money
        // control on this screen.
        onTap: null,
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
          child: Stack(
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
              if (tile.bonus case final bonus?)
                Positioned(
                  top: -13,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(9, 4, 9, 4),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFD257), Color(0xFFF0A91B)],
                      ),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(13),
                        bottomLeft: Radius.circular(10),
                      ),
                    ),
                    child: Text(
                      bonus,
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                        color: Color(0xFF4A2C00),
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
class CoinPackTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final ink = _coinTierInk[rank.clamp(0, _coinTierInk.length - 1)];
    final badge = _badge;
    final coins = (product.coins ?? 0) * coinMult;

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
                      child: CoinPackPicture(
                        art: coinPackArtFor(product.id),
                        size: 52,
                      ),
                    ),
                  ),
                  if (product.popular)
                    const Positioned(
                      top: 0,
                      right: 0,
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
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: coinGold,
                  height: 1.3,
                ),
              ),
              const Spacer(),
              const SizedBox(height: 10),
              ElevatedButton(
                key: ValueKey('shop-buy-${product.id}'),
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  product.price,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (paidDisabledReason() case final why?)
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
        Positioned(
          top: -9,
          child: badge == null
              ? const SizedBox.shrink()
              : Container(
                  key: ValueKey('shop-badge-${product.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: badge.popular
                        ? kit.accentBright
                        : const Color(0xFFFF9800),
                  ),
                  child: Text(
                    badge.text,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: badge.popular
                          ? kit.accentBrightInk
                          : const Color(0xFF171717),
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
class RestoreRow extends StatelessWidget {
  const RestoreRow({super.key});

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
          onTap: null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.restore, size: 17, color: kit.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t('shop.restore_purchases'),
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
