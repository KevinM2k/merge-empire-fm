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
import 'package:merge_empire_fc/ui/hud/hud.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/screens/shop/purchase_flow.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_providers.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_section.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_tiles.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
import 'package:merge_empire_fc/util/format.dart';

/// Whether a refusal is just about MONEY.
///
/// The money ones never reach the tile: a row the balance will not cover stays
/// live and ends at the coin or gem packs instead — see `purchase_flow.dart`. A
/// player who wants the thing needs a way to afford it, not a sentence telling
/// them they cannot.
bool isAffordabilityBlock(String? reason) =>
    reason == 'insufficient_gems' ||
    reason == 'insufficientGems' ||
    reason == 'insufficient_coins';

/// Why a row is dead, said in copy that already exists — or null when the only
/// thing in the way is the balance.
///
/// Deliberately mapped onto shipped keys rather than adding ten new ones to ten
/// catalogues: every reason here has an existing sentence that says the same
/// thing, and a translated string beats a freshly invented one.
String? blockedCopy(String? reason) => switch (reason) {
  null => null,
  _ when isAffordabilityBlock(reason) => null,
  'already_owned' => t('shop.owned'),
  'already_held' ||
  'alreadyHeld' ||
  'already_active' => t('shop.already_active'),
  'no_injured' => t('shop.toast.no_injured'),
  _ => t('settings.comingSoon'),
};

/// The app's own line art for each coin-priced consumable, and for the gem
/// items — the JS's emoji, in the icon set the rest of the app is drawn in.
const Map<String, String> consumableIcons = {
  'magic_sponge': 'bandage',
  'kit_sponsor': 'handshake',
  'match_rev': 'tv',
};

const Map<String, String> gemItemIcons = {
  'scout_voucher_gem': 'ticket',
  'energy_refill': 'bolt',
  'trophy_polish_gem': 'trophy',
};

Widget _icon(String name, Color colour) =>
    GameIcon(name, size: 32, color: colour);

class BoostsSection extends ConsumerWidget {
  const BoostsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(consumableTilesProvider);
    final gems = ref.watch(gemItemTilesProvider);
    final game = ref.read(gameProvider);

    return ShopSectionFrame(
      id: ShopSectionId.boosts,
      child: ShopGrid(
        children: [
          for (final row in coins)
            ShopTile(
              tileKey: 'coin-${row.id}',
              title: t(row.nameKey),
              subtitle: t(row.descKey),
              glyph: _icon(consumableIcons[row.id] ?? 'coin', hudCoinInk),
              price: formatCoins(row.cost),
              tone: StoreTone.coin,
              disabledReason: blockedCopy(row.blocked),
              onBuy: blockedCopy(row.blocked) != null
                  ? null
                  : () => offerToBuy(context, ref, (
                      key: 'coin-${row.id}',
                      title: t(row.nameKey),
                      subtitle: t(row.descKey),
                      glyph: consumableIcons[row.id] ?? 'coin',
                      currency: SpendCurrency.coins,
                      cost: row.cost,
                      buy: () =>
                          game.update((s) => buyConsumable(s, row.id)).reason,
                    )),
            ),
          for (final tile in gems)
            ShopTile(
              tileKey: 'gem-${tile.item.id}',
              title: t('gem.${tile.item.id}.name'),
              subtitle: t('gem.${tile.item.id}.desc'),
              glyph: _icon(gemItemIcons[tile.item.id] ?? 'gem', hudGemInk),
              price: formatCoins(tile.item.cost),
              tone: StoreTone.gem,
              disabledReason: blockedCopy(tile.blocked),
              onBuy: blockedCopy(tile.blocked) != null
                  ? null
                  : () => offerToBuy(context, ref, (
                      key: 'gem-${tile.item.id}',
                      title: t('gem.${tile.item.id}.name'),
                      subtitle: t('gem.${tile.item.id}.desc'),
                      glyph: gemItemIcons[tile.item.id] ?? 'gem',
                      currency: SpendCurrency.gems,
                      cost: tile.item.cost,
                      buy: () => game
                          .update((s) => buyGemItem(s, tile.item.id))
                          .reason,
                    )),
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
      child: ShopGrid(
        children: [
          for (final tile in tiles)
            ShopTile(
              tileKey: 'voucher-${tile.floor}',
              title: '${t('shop.section.vouchers')} ${tile.floor}',
              glyph: _icon('ticket', hudGemInk),
              price: '${tile.cost ?? 0}',
              tone: StoreTone.gem,
              disabledReason: blockedCopy(tile.blocked?.name),
              onBuy: blockedCopy(tile.blocked?.name) != null
                  ? null
                  : () => offerToBuy(context, ref, (
                      key: 'voucher-${tile.floor}',
                      title: '${t('shop.section.vouchers')} ${tile.floor}',
                      subtitle: t('shop.voucher.one_at_a_time'),
                      glyph: 'ticket',
                      currency: SpendCurrency.gems,
                      cost: tile.cost ?? 0,
                      buy: () => game
                          .update((s) => buyScoutVoucher(s, tile.floor))
                          .reason
                          ?.name,
                    )),
            ),
        ],
      ),
    );
  }
}
