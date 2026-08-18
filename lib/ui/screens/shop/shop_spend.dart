/// The two shelves a player can actually buy from today.
///
/// Boosts & Consumables mixes currencies deliberately: coin rows first, then gem
/// rows, and every row states its own price — which is the only reason one
/// section can hold two currencies and stay legible.
///
/// The coin rows go through `shop_consumables_engine`, which was extracted from
/// the JS `ShopScreen` for this screen to call; the gem rows go through
/// `buyGemItem`. Both engines own the debit AND the effect, so a row here can
/// only ask and never price or grant anything itself.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/gem_engine.dart';
import 'package:merge_empire_fc/engine/scout_voucher_engine.dart';
import 'package:merge_empire_fc/engine/shop_consumables_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_providers.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_section.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_tiles.dart';
import 'package:merge_empire_fc/util/format.dart';

/// Why a row is dead, said in copy that already exists.
///
/// Deliberately mapped onto shipped keys rather than adding ten new ones to ten
/// catalogues: every reason here has an existing sentence that says the same
/// thing, and a translated string beats a freshly invented one.
String blockedCopy(String reason) => switch (reason) {
  'insufficient_gems' || 'insufficientGems' => t('shop.toast.not_enough_gems'),
  'already_owned' => t('shop.owned'),
  'already_held' || 'alreadyHeld' || 'already_active' =>
    t('shop.already_active'),
  'insufficient_coins' => t('toast.not_enough_coins'),
  'no_injured' => t('shop.toast.no_injured'),
  _ => t('settings.comingSoon'),
};

class BoostsSection extends ConsumerWidget {
  const BoostsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(consumableTilesProvider);
    final gems = ref.watch(gemItemTilesProvider);
    final game = ref.read(gameProvider);

    return ShopSectionFrame(
      id: ShopSectionId.boosts,
      child: Column(
        children: [
          for (final row in coins)
            ShopTile(
              tileKey: 'coin-${row.id}',
              title: t(row.nameKey),
              subtitle: t(row.descKey),
              price: formatCoins(row.cost),
              disabledReason: row.blocked == null
                  ? null
                  : blockedCopy(row.blocked!),
              onBuy: row.blocked != null
                  ? null
                  : () => game.update((s) => buyConsumable(s, row.id)),
            ),
          for (final tile in gems)
            ShopTile(
              tileKey: 'gem-${tile.item.id}',
              title: t('gem.${tile.item.id}.name'),
              subtitle: t('gem.${tile.item.id}.desc'),
              price: formatCoins(tile.item.cost),
              disabledReason: tile.blocked == null
                  ? null
                  : blockedCopy(tile.blocked!),
              onBuy: tile.blocked != null
                  ? null
                  : () => game.update((s) => buyGemItem(s, tile.item.id)),
            ),
        ],
      ),
    );
  }
}

/// The whole voucher ladder, one tile a rung.
///
/// The one-at-a-time rule is stated once, at section level: it is the answer to
/// "why can't I buy this one" for all eight rungs at once, and saying it eight
/// times is worse rather than clearer.
class VouchersSection extends ConsumerWidget {
  const VouchersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = ref.watch(voucherTilesProvider);
    final game = ref.read(gameProvider);

    return ShopSectionFrame(
      id: ShopSectionId.vouchers,
      note: t('shop.voucher.one_at_a_time'),
      child: Column(
        children: [
          for (final tile in tiles)
            ShopTile(
              tileKey: 'voucher-${tile.floor}',
              title: '${t('shop.section.vouchers')} ${tile.floor}',
              price: '${tile.cost ?? 0}',
              disabledReason: tile.blocked == null
                  ? null
                  : blockedCopy(tile.blocked!.name),
              onBuy: tile.blocked != null
                  ? null
                  : () => game.update((s) => buyScoutVoucher(s, tile.floor)),
            ),
        ],
      ),
    );
  }
}
