/// Manager Customisations — the Style Vault and the packs it contains, as ONE
/// object on screen.
///
/// **A case with a lid.** The port had a Vault tile and six pack tiles side by
/// side in the same grid, which reads as seven separate things for sale — and
/// the one relationship a player needs (this one buys those six) was asserted by
/// a caption above the lot. The JS's own note on the same mistake is the brief:
/// the tiles sit INSIDE the Vault's border, under a label that counts them, so
/// "included" is a shape rather than a claim.
///
/// Each pack keeps its own tint (`data/manager_looks.dart`) on its chip and as a
/// wash behind it: six identically grey tiles read as a spreadsheet of
/// cosmetics, and the point of a look pack is that it has a look.
///
/// **The pill is a price, not a button.** The Vault is an `IapProduct` and
/// therefore M4; a pack's own price is five gems, and what spends them is the
/// offer sheet the manager customiser opens — a screen the port does not have
/// yet. So a pack tile answers "what does this cost" and nothing more, which is
/// exactly what `look_pack_engine.dart` says a tile is for.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart'
    show managerLookProvider;
import 'package:merge_empire_fc/ui/screens/home/manager_customiser.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart'
    show defaultManagerLook;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/engine/look_pack_engine.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/shop/purchase_flow.dart';
import 'package:merge_empire_fc/engine/iap_billing_policy.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_paid.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_providers.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_section.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';

/// A pack's tint, as a colour. Stored as a CSS hex because the catalogue is
/// generated from the JS's own data.
Color lookPackTint(String tint) =>
    Color(int.parse(tint.replaceFirst('#', 'ff'), radix: 16));

class LooksSection extends ConsumerWidget {
  const LooksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final tiles = ref.watch(lookTilesProvider);
    final vault = ref
        .watch(paidTilesProvider)
        .where((t) => t.product.styleVault)
        .firstOrNull;
    final owned = tiles.where((t) => t.tile.status == 'owned').length;
    final vaultOwned = ref.watch(styleVaultOwnedProvider);

    return ShopSectionFrame(
      id: ShopSectionId.looks,
      child: Column(
        key: const ValueKey('shop-vault-case'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // **THE CASE ROUND ALL OF THIS IS GONE, because the TAB is the case
          // now.** Grouping the wardrobe inside a bordered container made sense
          // on a page that held seven shelves at once and had to say where one
          // ended; on a tab of its own it is a frame drawn round the only thing
          // on the page, and it cost the vault the width it needed to make its
          // one argument.
          //
          // What replaced it is the argument itself, drawn: the Vault, then the
          // sentence that it holds every pack, then an arrow into the packs, and
          // a Vault mark on each one of them. Asked for directly — the money SKU
          // unlocks all ten gem packs and nothing on the shelf said so.
          if (vault != null)
            _VaultHero(
              vault: vault,
              ownedPacks: owned,
              totalPacks: tiles.length,
              isOwned: vaultOwned,
            ),
          if (vault != null)
            // The spine. A hairline down out of the Vault into the grid, with
            // the count on it — so the tiles below are read as its contents
            // rather than as the alternative to it.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const SizedBox(width: 22),
                  Icon(
                    Icons.subdirectory_arrow_right,
                    size: 16,
                    color: ShopSectionId.looks.ink,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      // The count, never the headline — the hero says
                      // "all customisations unlocked" and saying it twice on
                      // one shelf is the repetition the tab strip was just
                      // relieved of.
                      t('shop.vault.progress', {
                        'n': vaultOwned ? tiles.length : owned,
                        'total': tiles.length,
                      }),
                      key: const ValueKey('shop-vault-case-label'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: kit.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ShopGrid(
            // **TWO TO A ROW, not three.** Asked for directly: a pack is a
            // face with a name under it, and at a third of the width the face
            // is a thumbnail and the name ellipsises.
            columns: 2,
            children: [
              for (final tile in tiles)
                _LookTile(
                  packId: tile.packId,
                  tile: tile.tile,
                  // **EVERY TILE WEARS THE VAULT'S MARK.** That is the whole
                  // point of the restyle: a player looking at ten gem prices
                  // has no way of knowing the one cash price above covers all
                  // of them, and the shelf never said it.
                  inVault: vault != null,
                  vaultOwned: vaultOwned,
                  // **EVERY PACK IS TAPPABLE.** The tile answered "what does
                  // this cost" and stopped there, because what spent the gems
                  // was a sheet the port did not have — so the price on ten
                  // tiles was a figure the player could read and not act on.
                  // The Shop's own three beats do the rest: ask, and if the
                  // balance will not cover it, the gem packs rather than a
                  // sentence explaining that they cannot.
                  onBuy: tile.tile.status == 'owned' || vaultOwned
                      ? null
                      : () => offerToBuy(context, ref, (
                          key: 'pack-${tile.packId}',
                          title: t('customise.pack.${tile.packId}'),
                          // **WHAT IT UNLOCKS, not how many.** "4 items" over
                          // a confirm is a count of things the player cannot
                          // see — the tile behind the sheet has the picture
                          // and the sheet covers it. The pack's own contents
                          // are `axis:id` pairs and every axis already has a
                          // catalogue label (`customise.tab.*`), so the
                          // summary needs no new copy: two Headwear, one
                          // Accessory, one Celebration.
                          subtitle: _packContents(tile.packId),
                          // **AND THE ITEMS THEMSELVES, one row each, with a
                          // TICK against what is already owned.** The
                          // subtitle can only summarise — "two Headwear, one
                          // Accessory" is a count of things the player cannot
                          // see, and the tile with the picture on it is
                          // behind this card. Asked for directly.
                          body: _PackContents(packId: tile.packId),
                          glyph: 'shirt',
                          currency: SpendCurrency.gems,
                          cost: tile.tile.cost,
                          buy: () => ref
                              .read(gameProvider)
                              .update((s) => buyLookPack(s, tile.packId))
                              .reason,
                        )),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The pack's contents, item by item, with what is already owned ticked.
///
/// **Named from the catalogue, not from the id.** Every wardrobe item has a
/// `customise.<axis>.<id>` entry — `customise.hat.sunhat` is "Sun Hat" in all
/// ten languages — so the list needs no new copy, which is just as well: the
/// catalogues are generated and no new key can be added from this repo.
///
/// The GLYPH is the axis's own line-art icon rather than a drawing of the item.
/// Drawing one means a `ManagerWalker` rig per row, and the customiser's own
/// note measures twenty of those at 60ms against 18ms for an empty grid — this
/// card slides up over a shop, and a confirm that lands twelve frames late is
/// the "customise comes up laggy" defect wearing a different hat.
class _PackContents extends ConsumerWidget {
  const _PackContents({required this.packId});

  final String packId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final pack = getLookPack(packId);
    if (pack == null) return const SizedBox.shrink();
    final state = ref.watch(gameProvider).state;
    final owned = ownedLookItems(state);
    final all = hasStyleVault(state);

    // **ACROSS, NOT DOWN — the shape the customiser already uses.** The items
    // were a COLUMN: one 54pt picture per row with its name beside it and the
    // rest of the card empty to the right, so a four-item pack was four short
    // lines down a wide sheet and the pictures — the whole reason this list was
    // drawn rather than written — were the smallest thing on it. The customiser
    // lays the same choices out as a grid of chips with the name UNDER each
    // one, which is what a player has already learned to read, and it is what
    // was asked for from the couch.
    return Wrap(
      key: ValueKey('pack-contents-$packId'),
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in pack.items)
          () {
            final axis = item.split(':').first;
            final id = item.split(':').last;
            final has = all || owned.contains(item);
            return SizedBox(
              width: _chipWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // **A PICTURE OF IT, not a glyph for its category.** The
                  // row used to be a shirt icon and a word — "Bucket",
                  // "Viking", "Party" — which tells a player nothing about
                  // what they are buying, and the customiser has been drawing
                  // the real thing all along. Reported as wanting to see each
                  // item before unlocking it. Same [LookPreview], on the
                  // player's OWN figure with this one choice swapped in, so a
                  // hat is previewed over their hair in their colours.
                  Stack(
                    children: [
                      Container(
                        width: _chipWidth,
                        height: _chipWidth,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: kit.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: has ? kit.accentBright : kit.border,
                            width: has ? 2 : 1,
                          ),
                        ),
                        child: _previewOf(axis, id, ref) ??
                            GameIcon(
                              lookAxisIcon[axis] ?? 'shirt',
                              size: 22,
                              color: has ? kit.accentBright : kit.textMuted,
                            ),
                      ),
                      // **A TICK, not a lock.** What the player is deciding is
                      // what this pack still has to give them, so the ones they
                      // have are the marked ones — a padlock on the rest would
                      // read as the pack being unavailable. In the corner now
                      // rather than at the end of a row, because there is no
                      // row any more.
                      if (has)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Icon(
                            Icons.check_circle,
                            size: 15,
                            color: kit.accentBright,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    // The catalogue's key scheme is not one scheme — see
                    // [lookItemLabel]. Asking for `customise.<axis>.<id>` and
                    // tidying the id when it missed meant "Sunhat" where the
                    // catalogue says "Sun Hat", in English and in nothing
                    // else.
                    lookItemLabel(axis, id),
                    textAlign: TextAlign.center,
                    // Two lines, because these are translated names under a
                    // 64pt chip: "Sun Hat" fits on one and its German is not
                    // going to.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.15,
                      fontWeight: has ? FontWeight.w800 : FontWeight.w600,
                      color: has ? kit.accentBright : kit.textMuted,
                    ),
                  ),
                ],
              ),
            );
          }(),
      ],
    );
  }
}

/// One contents chip's side, matching the customiser's own grid.
const double _chipWidth = 64;

/// The line-art glyph for each wardrobe axis, for [_PackContents].
const Map<String, String> lookAxisIcon = {
  'hat': 'shirt',
  'face': 'star',
  'color': 'star',
  'emote': 'megaphone',
  'outfit': 'shirt',
  'beard': 'star',
  'style': 'shirt',
};

/// What a look pack actually contains, by part.
///
/// Grouped by AXIS rather than listed item by item: the ids inside a pack are
/// `hat:sunhat` and `face:aviators`, and there is no catalogue entry naming
/// either — but `customise.tab.hat` is "Headwear" in all ten languages and has
/// been since the customiser was built. Order follows the pack's own, so the
/// summary reads the way the case is laid out.
String _packContents(String packId) {
  final pack = getLookPack(packId);
  if (pack == null) return '';
  final counts = <String, int>{};
  for (final item in pack.items) {
    final axis = item.split(':').first;
    counts[axis] = (counts[axis] ?? 0) + 1;
  }
  return [
    for (final entry in counts.entries)
      entry.value > 1
          ? '${t('customise.tab.${entry.key}')} ×${entry.value}'
          : t('customise.tab.${entry.key}'),
  ].join(' · ');
}

/// **THE VAULT'S ONE JOB IS TO SAY THAT IT HOLDS EVERYTHING BELOW IT.**
///
/// It was a row — a glyph, a name and a price button, sat on the lid of a case
/// whose label carried the actual pitch two lines further down in muted 11pt.
/// So the shelf showed a cash price and then ten gem prices and never once said
/// that the first one covers the other ten, which is the entire proposition of
/// the SKU. Reported exactly that way.
///
/// `shop.looks.case_label` — "Includes all {total} packs" — is the sentence,
/// and it is shipped in ten languages, so this needed no new copy at all. It is
/// now the headline under the name, at the weight it earns, and the price is a
/// full-width button under it rather than a chip fighting the title for room.
class _VaultHero extends ConsumerWidget {
  const _VaultHero({
    required this.vault,
    required this.ownedPacks,
    required this.totalPacks,
    required this.isOwned,
  });

  final PaidTile vault;
  final int ownedPacks;
  final int totalPacks;
  final bool isOwned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final ink = ShopSectionId.looks.ink;
    return Container(
      key: ValueKey('shop-tile-${vault.product.id}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOwned ? kit.accent.withValues(alpha: 0.55) : ink,
          width: 1.5,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ink.withValues(alpha: 0.22), kit.surface],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: ink.withValues(alpha: 0.22),
                ),
                // The app's own line art, not the catalogue's emoji — that one
                // is for the toast, which renders it as text.
                child: GameIcon('bank', size: 24, color: ink),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vault.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // **THE PITCH, at the weight of a pitch.** Not the muted
                    // caption it was.
                    Text(
                      isOwned
                          ? t('shop.looks.vault_owned')
                          : t('shop.looks.case_label', {'total': totalPacks}),
                      style: TextStyle(
                        color: isOwned ? kit.accentBright : ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                    if (!isOwned) ...[
                      const SizedBox(height: 3),
                      Text(
                        vault.desc,
                        style: TextStyle(
                          color: kit.textMuted,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                      if (paidDisabledReason() case final why?) ...[
                        const SizedBox(height: 3),
                        Text(
                          why,
                          style: TextStyle(color: kit.textMuted, fontSize: 11),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              if (isOwned)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 8),
                  child: Text(
                    t('shop.owned'),
                    style: TextStyle(
                      color: kit.accentBright,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          if (!isOwned) ...[
            const SizedBox(height: 10),
            // The CASE is Looks purple and the button is priced green: the
            // frame says what this is, the button says what it costs. See
            // [StoreButton].
            StoreButton(
              key: ValueKey('shop-buy-${vault.product.id}'),
              tone: StoreTone.cash,
              label: priceFor(
                vault.product.sku,
                vault.product.price,
                ref.watch(storeCatalogueProvider).valueOrNull,
              ),
              // The Vault is the other tile the JS names as having charged
              // straight off itself before the confirm went in.
              onTap: () => buyProduct(
                context,
                ref,
                vault.product,
                vault.name,
                priceFor(
                  vault.product.sku,
                  vault.product.price,
                  ref.read(storeCatalogueProvider).valueOrNull,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One pack, inside the case: its own colour, what it holds, and what it costs.
class _LookTile extends StatelessWidget {
  const _LookTile({
    required this.packId,
    required this.tile,
    this.inVault = false,
    this.vaultOwned = false,
    this.onBuy,
  });

  final String packId;
  final LookTile tile;

  /// Whether the Vault SKU covers this pack — which it does for all of them,
  /// and which is the fact the shelf was never stating. The mark is small
  /// deliberately: it is a footnote on ten tiles that adds up to the argument
  /// the hero above makes once.
  final bool inVault;

  /// Whether that SKU has already been bought, in which case the mark is the
  /// REASON this tile is owned rather than a pitch for buying it.
  final bool vaultOwned;

  /// Null for a pack there is nothing left to buy — owned outright, or covered
  /// by the Vault.
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final pack = getLookPack(packId);
    final tint = pack == null ? kit.accent : lookPackTint(pack.tint);
    final owned = tile.status == 'owned';

    final vaultInk = ShopSectionId.looks.ink;
    return GestureDetector(
      onTap: onBuy,
      child: Container(
        key: ValueKey('shop-tile-pack-$packId'),
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 9),
        // **A SURFACE UNDER THE TINT, which is what the tile never had.** The
        // pane was the pack's colour at 10% alpha and nothing else, so on the
        // turf and humbug backgrounds the page showed straight through ten
        // tiles — reported as the customisation buttons being see-through and
        // not looking like they sit on top of the screen. `.look-tile` in the
        // spec is TWO stacked gradients: the faint tint wash over an opaque
        // `surface-2 → surface`, the same base every other tile in the shop is
        // built on. One `BoxDecoration` takes one gradient, so the wash is
        // composited onto the surface here instead — same result, and the tint
        // stays faint on purpose, because ten saturated tiles is a fruit
        // machine.
        //
        // The drop shadow is the other half of "on top of the screen": it is in
        // the spec (`0 2px 6px`) and was the one thing lifting these off the
        // page.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            // 160deg — down, leaning right.
            begin: const Alignment(-0.35, -1),
            end: const Alignment(0.35, 1),
            colors: [
              Color.alphaBlend(
                tint.withValues(alpha: owned ? 0.28 : 0.16),
                kit.surface2,
              ),
              Color.lerp(kit.surface2, kit.surface, 0.65)!,
              kit.surface,
            ],
            stops: const [0, 0.65, 1],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x38000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
          border: Border.all(
            // A pack the Vault has already opened is edged in the VAULT's
            // colour rather than its own, so the ten tiles read as one purchase
            // instead of ten.
            color: vaultOwned
                ? vaultInk.withValues(alpha: 0.7)
                : tint.withValues(alpha: owned ? 0.7 : 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The Vault mark rides in the glyph's own row so it costs the
            // tile no height — there is none to give on a three-across shelf.
            Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  pack?.icon ?? '🎽',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, height: 1.2),
                ),
                if (inVault)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GameIcon(
                      'bank',
                      size: 11,
                      color: vaultInk.withValues(alpha: vaultOwned ? 1 : 0.6),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              t('customise.pack.$packId'),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              // Partial progress is the normal state — a video buys one item — so
              // a part-owned pack counts, and an untouched one says its size.
              tile.owned > 0 && tile.owned < tile.total
                  ? t('customise.pack.progress', {
                      'n': tile.owned,
                      'total': tile.total,
                    })
                  : t('customise.pack.count', {'n': tile.total}),
              textAlign: TextAlign.center,
              style: TextStyle(color: kit.textMuted, fontSize: 10),
            ),
            const Spacer(),
            const SizedBox(height: 6),
            _PackPill(
              cost: tile.cost,
              owned: owned || vaultOwned,
              onBuy: onBuy,
            ),
          ],
        ),
      ),
    );
  }
}

/// Owned, or the pack's gem price — the JS's two states and no others. The '▶
/// FREE' pill and the countdown went with the tile's old ad-first ordering; see
/// `look_pack_engine.dart` for what they were promising.
class _PackPill extends StatelessWidget {
  const _PackPill({required this.cost, required this.owned, this.onBuy});

  final int cost;
  final bool owned;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    // **IT IS THE SHOP'S OWN GEM BUTTON NOW, not a pill that looks like one.**
    // A pass ago this became "a blue button with a white gem" and picked its
    // own blue — `ShopSectionId.gems.ink`, the SECTION's tint — so the ten
    // controls that buy a look pack were the only buy buttons in the shop that
    // were not `StoreButton`: different face, different edge, different radius,
    // no press. `StoreTone.gem` is the same blue every other gem price in the
    // shop wears, and the glyph comes with it.
    if (owned) {
      return Center(
        child: Container(
          key: const ValueKey('pack-pill-owned'),
          padding: const EdgeInsets.fromLTRB(11, 6, 11, 7),
          decoration: BoxDecoration(
            // The buy button's radius, not a 999 lozenge — the spec's two pills
            // are one shape saying two things, and a capsule beside a moulded
            // 10pt button reads as a different kind of control.
            borderRadius: BorderRadius.circular(10),
            color: kit.accent.withValues(alpha: 0.22),
            border: Border.all(color: kit.accentBright.withValues(alpha: 0.55)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check, size: 13, color: kit.accentBright),
              const SizedBox(width: 4),
              Text(
                t('shop.owned'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: kit.accentBright,
                ),
              ),
            ],
          ),
        ),
      );
    }
    // **FULL SIZE, and sized to the price rather than to the tile.** It was the
    // `--sm` variant — 11pt type in a 9pt radius — which is the ROW button, for
    // a list line; every other buy control in the shop is the full one, and on
    // a tile as wide as this one the small variant read as a caption. Asked for
    // directly: the same size as the rest of the buttons.
    //
    // `stretch` off with it, or the extra size arrives as a bar across the
    // bottom of the tile: the spec's own note is that a full-width pill reads
    // as the tile's footer instead of as a button, and "5" in a 150pt button is
    // mostly empty.
    return Center(
      child: StoreButton(
        key: const ValueKey('pack-pill-buy'),
        tone: StoreTone.gem,
        stretch: false,
        label: '$cost',
        leading: const GameIcon('gem', size: 14),
        onTap: onBuy,
      ),
    );
  }
}


/// The drawn preview for one pack item, or null for an axis with no figure to
/// draw — a skin tone IS a colour, and no pack contains one anyway.
///
/// **A HAIR COLOUR GETS A HEAD.** It was excluded alongside skin, on the
/// customiser's reasoning that a colour is better looked at as a colour — but
/// the customiser then draws a SWATCH, and the shop had no swatch branch, so
/// what a player buying a colour pack actually saw was `GameIcon('star')`, four
/// times over, one per colour. A star is not a worse look at a colour; it is no
/// look at one. Reported from the couch. The head crop is already what
/// `_regionFor('color')` returns, so this is the customiser's own picture.
///
/// **And the hat comes off for it**, which the customiser never has to think
/// about because its swatch shows the colour whatever he is wearing. A manager
/// in a bucket hat previewing four hair colours would be four identical hats,
/// which is the sixteen-identical-managers defect the emote poses exist to fix.
Widget? _previewOf(String axisKind, String id, WidgetRef ref) {
  final axis = lookAxes.where((a) => a.kind == axisKind).firstOrNull;
  if (axis == null || axisKind == 'skin') return null;
  final look = ref.read(managerLookProvider) ?? defaultManagerLook;
  return LookPreview(
    axis: axis,
    look: <String, dynamic>{
      ...look,
      if (axisKind == 'color') 'hat': 'none',
      axis.field: axisKind == 'color' ? hairColorValue(id) : id,
    },
  );
}
