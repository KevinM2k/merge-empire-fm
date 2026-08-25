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
import 'package:merge_empire_fc/data/card_theme.dart';
import 'package:merge_empire_fc/engine/gem_engine.dart';
import 'package:merge_empire_fc/engine/scout_voucher_engine.dart';
import 'package:merge_empire_fc/engine/shop_consumables_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/screens/shop/purchase_flow.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_copy.dart';
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
/// Whether a refusal is a PRECONDITION the player can act on.
///
/// Owned and Active are states they are already in and read fine in grey; "No
/// injured players!" is the tile saying the Magic Sponge would heal nobody, and
/// it was the same muted grey as the description under it.
bool isPreconditionBlock(String? reason) => reason == 'no_injured';

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
    final settings = game.state?['settings'];
    final hardMode =
        settings is Map<String, dynamic> && settings['hardMode'] == true;

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
              warnReason: isPreconditionBlock(row.blocked),
              onBuy: blockedCopy(row.blocked) != null
                  ? null
                  : () => offerToBuy(context, ref, (
                      key: 'coin-${row.id}',
                      title: t(row.nameKey),
                      subtitle: t(row.descKey),
                      body: null,
                      glyph: consumableIcons[row.id] ?? 'coin',
                      currency: SpendCurrency.coins,
                      cost: row.cost,
                      buy: () =>
                          game.update((s) => buyConsumable(s, row.id)).reason,
                    )),
            ),
          // **NOT THE PLAIN SCOUT VOUCHER.** It is the bottom rung of the
          // voucher LADDER below and it was being drawn twice — once as a loose
          // gem item beside the TV broadcast deal, once in the section a player
          // looking for a scout actually goes to. `_renderGemItems` filters it
          // out for exactly this reason and says so; the port did not. Reported
          // as the same voucher appearing twice.
          for (final tile in gems)
            if (tile.item.id != _scoutVoucherGemId)
            ShopTile(
              tileKey: 'gem-${tile.item.id}',
              title: t('gem.${tile.item.id}.name'),
              subtitle: gemItemDesc(
                tile.item.id,
                state: game.state,
                hardMode: hardMode,
              ),
              glyph: _icon(gemItemIcons[tile.item.id] ?? 'gem', hudGemInk),
              price: formatCoins(tile.item.cost),
              tone: StoreTone.gem,
              disabledReason: blockedCopy(tile.blocked),
              onBuy: blockedCopy(tile.blocked) != null
                  ? null
                  : () => offerToBuy(context, ref, (
                      key: 'gem-${tile.item.id}',
                      title: t('gem.${tile.item.id}.name'),
                      subtitle: gemItemDesc(
                        tile.item.id,
                        state: game.state,
                        hardMode: hardMode,
                      ),
                      body: null,
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
/// The gamble rung of the ladder — the catalogue's own one-gem item, drawn in
/// the voucher section rather than among the gem items because that is where a
/// player looking for a scout goes.
const String _scoutVoucherGemId = 'scout_voucher_gem';

/// The voucher ladder.
///
/// **A voucher sets a FLOOR, and the tile has to say so.** "or better · normally
/// 4%" is load-bearing, not a footnote: a tile reading just "GOLD★" is the
/// exact-tier misreading the whole design was chosen to avoid. The port left it
/// off entirely, along with the odds it is argued against — so eight tiles all
/// read "Scout Vouchers 5", which spends the widest line on each of them saying
/// what the section heading has already said.
///
/// **Every rung is shown, locked or not.** The shelf listed only the tiers this
/// division can buy, so the top of the ladder simply was not there and
/// `shop.voucher.unlocks_in` had nothing able to reach it. A ladder with its top
/// hidden is a shelf, and it takes the reason to climb with it.
///
/// The 🎲 rung is the catalogue's own one-gem item rather than a tier: the
/// cheapest of them, and the only one that can hand over an Icon.
class VouchersSection extends ConsumerWidget {
  const VouchersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = ref.watch(voucherTilesProvider);
    final gamble = ref
        .watch(gemItemTilesProvider)
        .where((g) => g.item.id == _scoutVoucherGemId);
    final game = ref.read(gameProvider);

    return ShopSectionFrame(
      id: ShopSectionId.vouchers,
      // Said once, up here, rather than eight times on eight tiles: the rule is
      // about the SECTION, and it answers "why can't I buy this one" for every
      // rung at once.
      note: t('shop.voucher.one_at_a_time'),
      child: ShopGrid(
        children: [
          for (final item in gamble)
            ShopTile(
              tileKey: 'voucher-random',
              title: t('shop.voucher.random'),
              subtitle: t('shop.voucher.random_sub'),
              glyph: Text(
                t('shop.voucher.random_icon'),
                style: const TextStyle(fontSize: 22),
              ),
              price: '${item.item.cost}',
              tone: StoreTone.gem,
              // Never locked: every division can scout a random player.
              disabledReason: blockedCopy(item.blocked),
              onBuy: blockedCopy(item.blocked) != null
                  ? null
                  : () => offerToBuy(context, ref, (
                      key: 'voucher-random',
                      title: t('shop.voucher.random'),
                      subtitle: t('shop.voucher.random_sub'),
                      body: null,
                      glyph: 'ticket',
                      currency: SpendCurrency.gems,
                      cost: item.item.cost,
                      buy: () => game
                          .update((s) => buyGemItem(s, item.item.id))
                          .reason,
                    )),
            ),
          for (final tile in tiles)
            () {
              // The TIER is the name. The section heading already said "Scout
              // Vouchers".
              final name = tierLabel[tile.floor] ?? 'T${tile.floor}';
              final reason = tile.holding
                  ? t('shop.already_active')
                  : blockedCopy(tile.blocked?.name);
              return ShopTile(
                tileKey: 'voucher-${tile.floor}',
                title: name,
                subtitle: tile.offered
                    ? t('shop.voucher.sub', {
                        'pct': (tile.odds * 100).toStringAsFixed(
                          tile.odds * 100 < 10 ? 1 : 0,
                        ),
                      })
                    // A locked rung has no odds worth quoting yet, so it names
                    // the division instead.
                    : t('shop.voucher.unlocks_in', {
                        'division': tName('division', tile.unlocksIn),
                      }),
                glyph: Text(
                  tierEmoji[tile.floor] ?? '',
                  style: const TextStyle(fontSize: 22),
                ),
                price: '${tile.cost ?? 0}',
                tone: StoreTone.gem,
                disabledReason: reason,
                onBuy: reason != null
                    ? null
                    : () => offerToBuy(context, ref, (
                        key: 'voucher-${tile.floor}',
                        title: name,
                        subtitle: t('shop.voucher.sub', {
                          'pct': (tile.odds * 100).toStringAsFixed(
                            tile.odds * 100 < 10 ? 1 : 0,
                          ),
                        }),
                        body: null,
                        glyph: 'ticket',
                        currency: SpendCurrency.gems,
                        cost: tile.cost ?? 0,
                        buy: () => game
                            .update((s) => buyScoutVoucher(s, tile.floor))
                            .reason
                            ?.name,
                      )),
              );
            }(),
        ],
      ),
    );
  }
}
