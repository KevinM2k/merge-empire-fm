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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/engine/look_pack_engine.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/shop/purchase_flow.dart';
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
      child: Container(
        key: const ValueKey('shop-vault-case'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: vaultOwned
                ? kit.accent.withValues(alpha: 0.55)
                : ShopSectionId.looks.ink.withValues(alpha: 0.45),
            width: 1.5,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ShopSectionId.looks.ink.withValues(alpha: 0.10),
              kit.surface,
            ],
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (vault != null)
              _VaultHero(
                vault: vault,
                ownedPacks: owned,
                totalPacks: tiles.length,
                isOwned: vaultOwned,
              ),
            // The lid: what the case holds, and how much of it is already open.
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t('shop.looks.case_label', {'total': tiles.length}),
                      key: const ValueKey('shop-vault-case-label'),
                      style: TextStyle(
                        color: kit.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  if (!vaultOwned)
                    Text(
                      t('shop.vault.progress', {
                        'n': owned,
                        'total': tiles.length,
                      }),
                      style: TextStyle(color: kit.textMuted, fontSize: 11),
                    ),
                ],
              ),
            ),
            ShopGrid(
              columns: 3,
              children: [
                for (final tile in tiles)
                  _LookTile(
                    packId: tile.packId,
                    tile: tile.tile,
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
                            subtitle: t('customise.pack.count', {
                              'n': tile.tile.total,
                            }),
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
      ),
    );
  }
}

/// The Vault itself: a row rather than a tile, because it is the lid of the case
/// under it and not one of the things inside.
class _VaultHero extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Row(
      key: ValueKey('shop-tile-${vault.product.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: ShopSectionId.looks.ink.withValues(alpha: 0.18),
          ),
          // The app's own line art, not the catalogue's emoji — that one is for
          // the toast, which renders it as text.
          child: GameIcon('bank', size: 24, color: ShopSectionId.looks.ink),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vault.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                isOwned ? t('shop.looks.vault_owned') : vault.desc,
                style: TextStyle(
                  color: kit.textMuted,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
              if (!isOwned) ...[
                const SizedBox(height: 3),
                Text(
                  paidDisabledReason(),
                  style: TextStyle(color: kit.textMuted, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        isOwned
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  t('shop.owned'),
                  style: TextStyle(
                    color: kit.accentBright,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            // The CASE is Looks purple and the button is priced green: the
            // frame says what this is, the button says what it costs. See
            // [StoreButton].
            : StoreButton(
                key: ValueKey('shop-buy-${vault.product.id}'),
                tone: StoreTone.cash,
                label: vault.product.price,
                stretch: false,
                onTap: null,
              ),
      ],
    );
  }
}

/// One pack, inside the case: its own colour, what it holds, and what it costs.
class _LookTile extends StatelessWidget {
  const _LookTile({required this.packId, required this.tile, this.onBuy});

  final String packId;
  final LookTile tile;

  /// Null for a pack there is nothing left to buy — owned outright, or covered
  /// by the Vault.
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final pack = getLookPack(packId);
    final tint = pack == null ? kit.accent : lookPackTint(pack.tint);
    final owned = tile.status == 'owned';

    return GestureDetector(
      onTap: onBuy,
      child: Container(
        key: ValueKey('shop-tile-pack-$packId'),
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: tint.withValues(alpha: owned ? 0.20 : 0.10),
          border: Border.all(color: tint.withValues(alpha: owned ? 0.7 : 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              pack?.icon ?? '🎽',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, height: 1.2),
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
            _PackPill(cost: tile.cost, owned: owned),
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
  const _PackPill({required this.cost, required this.owned});

  final int cost;
  final bool owned;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    // **A BLUE BUTTON WITH A WHITE GEM.** It was a near-black pill with a blue
    // gem and blue digits inside it — the gem's own colour on the darkest thing
    // on the tile, at 11px, which reads as a disabled chip rather than as the
    // control that buys the pack. The price is the button, so it wears the
    // gem's colour as a FILL and everything on it is white.
    return Container(
      key: ValueKey(owned ? 'pack-pill-owned' : 'pack-pill-buy'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: owned
            ? kit.accent.withValues(alpha: 0.22)
            : ShopSectionId.gems.ink,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (owned)
            Icon(Icons.check, size: 12, color: kit.accentBright)
          else
            const Icon(Icons.diamond, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            owned ? t('shop.owned') : '$cost',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: owned ? kit.accentBright : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
