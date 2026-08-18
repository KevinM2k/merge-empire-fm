/// Manager Customisations — the Style Vault over the packs it contains.
///
/// Nothing in this section is bought with gems, which is not obvious from its
/// name. The Vault is an `IapProduct` carrying `styleVault: true`, so real money
/// and therefore M4; the pack tiles below it are pure PROGRESS. An individual
/// pack is unlocked one rewarded video at a time in the customiser, not here.
/// The tiles sit under the Vault so its value is visible rather than asserted.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_paid.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_providers.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_section.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_tiles.dart';

class LooksSection extends ConsumerWidget {
  const LooksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = ref.watch(lookTilesProvider);
    final vault = ref
        .watch(shopProductsProvider)
        .where((p) => p.styleVault)
        .firstOrNull;
    final owned = tiles.where((t) => t.tile.status == 'owned').length;

    return ShopSectionFrame(
      id: ShopSectionId.looks,
      note: t('shop.vault.progress', {'n': owned, 'total': tiles.length}),
      child: Column(
        children: [
          if (vault != null)
            ShopTile(
              tileKey: vault.id,
              title: vault.name,
              subtitle: vault.desc,
              price: vault.price,
              disabledReason: paidDisabledReason(),
            ),
          for (final tile in tiles)
            ShopProgressTile(
              tileKey: 'pack-${tile.packId}',
              // A pack's display name is a catalogue key, not a field on the
              // record — the record carries only what paints the tile.
              title: t('customise.pack.${tile.packId}'),
              owned: tile.tile.owned,
              total: tile.tile.total,
            ),
        ],
      ),
    );
  }
}
