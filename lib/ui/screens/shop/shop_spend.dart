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
import 'package:merge_empire_fc/data/boosts.dart';
import 'package:merge_empire_fc/engine/coin_sink_engine.dart' show trophyPolishLeftMs;
import 'package:merge_empire_fc/engine/boost_engine.dart';
import 'package:merge_empire_fc/engine/shop_consumables_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/screens/shop/purchase_flow.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_copy.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_match_day.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_providers.dart';
import 'package:merge_empire_fc/ui/screens/match/boost_bar_paint.dart' show flameDeep, liveBoostColour;
import 'package:merge_empire_fc/ui/screens/shop/shop_section.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_tiles.dart';
import 'package:merge_empire_fc/util/event_bus.dart' show emit;
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

bool _held(String? blocked) =>
    blocked == 'already_active' || blocked == 'already_held';

/// The badge on a held item: the polish says how long it has left.
String _activeLabel(String id, Map<String, dynamic>? state) {
  if (id != 'trophy_polish_gem') return t('shop.already_active');
  final mins = (trophyPolishLeftMs(state) / 60000).ceil();
  return t('shop.active_mins_left', {'mins': mins < 1 ? 1 : mins});
}

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

/// The items on this tab that multiply what the club EARNS, rather than fixing
/// or freshening the squad.
///
/// **ONE SET, read by both shelves.** The split is a partition — a tile is in
/// exactly one of them — so a single membership test is what guarantees that
/// nothing is drawn twice and nothing falls between them. Adding a consumable
/// or a gem item without touching this set puts it on the Boosts shelf, which
/// is the safer default: a boost on the wrong shelf is misfiled, and an income
/// item on the wrong shelf is a claim about what it does.
///
/// `kit_sponsor` is ×1.25 income for a season, `match_rev` is the TV deal, and
/// `trophy_polish_gem` is "doubles EVERYTHING you earn — idle and matchday".
/// The Magic Sponge heals and the Energy Refill refills; neither pays anything.
const Set<String> incomeShelfIds = {
  'kit_sponsor',
  'match_rev',
  'trophy_polish_gem',
};

/// The two shelves the old Boosts shelf became.
///
/// **A Magic Sponge and a Kit Sponsor answer different questions**, and one
/// heading over both of them answered neither: a player looking for income
/// scanned past a bandage, and a player with three injured men scanned past a
/// TV deal. Asked for from the couch: split the boosts from the income. The
/// tiles, the prices and the buy flow are identical on both — what differs is
/// which side of [incomeShelfIds] a row falls on, so there is one widget and a
/// flag rather than two shelves to keep in step.
class BoostsSection extends ConsumerWidget {
  const BoostsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const _SpendShelf(income: false);
}

class IncomeSection extends ConsumerWidget {
  const IncomeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const _SpendShelf(income: true);
}

class _SpendShelf extends ConsumerWidget {
  const _SpendShelf({required this.income});

  /// Which side of [incomeShelfIds] this shelf draws.
  final bool income;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref
        .watch(consumableTilesProvider)
        .where((row) => incomeShelfIds.contains(row.id) == income);
    final gems = ref
        .watch(gemItemTilesProvider)
        .where((tile) => incomeShelfIds.contains(tile.item.id) == income);
    final game = ref.read(gameProvider);
    final settings = game.state?['settings'];
    final hardMode =
        settings is Map<String, dynamic> && settings['hardMode'] == true;

    return ShopSectionFrame(
      id: income ? ShopSectionId.income : ShopSectionId.boosts,
      child: ShopGrid(
        children: [
          // The two Match Day items, on the end of THIS shelf — they had a
          // heading of their own directly under this one and it was a
          // subdivision of a tab already named for this shelf. See
          // [matchDayTiles].
          if (!income) ...matchDayTiles(context, ref),
          for (final row in coins)
            ShopTile(
              tileKey: 'coin-${row.id}',
              title: t(row.nameKey),
              subtitle: t(row.descKey),
              glyph: _icon(consumableIcons[row.id] ?? 'coin', hudCoinInk),
              price: formatCoins(row.cost),
              tone: StoreTone.coin,
              disabledReason: row.blocked == 'already_active'
                  ? null
                  : blockedCopy(row.blocked),
              activeLabel: row.blocked == 'already_active'
                  ? t('shop.already_active')
                  : null,
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
                      // The tile's own ink, so the card and the tile agree.
                      glyphColor: hudCoinInk,
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
              // On the Income shelf the icon says what it EARNS, in the
              // coin gold its neighbours wear; the button still says gems.
              glyph: _icon(
                gemItemIcons[tile.item.id] ?? 'gem',
                income ? hudCoinInk : hudGemInk,
              ),
              price: formatCoins(tile.item.cost),
              tone: StoreTone.gem,
              // A held item is ACTIVE, in the green badge the TV deal wears
              // — and the polish's badge counts down. Reported from the couch.
              disabledReason: _held(tile.blocked)
                  ? null
                  : blockedCopy(tile.blocked),
              activeLabel: _held(tile.blocked)
                  ? _activeLabel(tile.item.id, game.state)
                  : null,
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
                      glyphColor: income ? hudCoinInk : hudGemInk,
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
    final tokens = voucherCount(game.state, anyCardVoucher);

    return ShopSectionFrame(
      id: ShopSectionId.vouchers,
      // **NO SECTION NOTE ANY MORE.** It used to carry
      // `shop.voucher.one_at_a_time`, said once up here rather than eight times
      // on eight tiles because the rule was about the SECTION and answered "why
      // can't I buy this one" for every rung at once. Vouchers are collectable
      // now, so that sentence is simply false and the question it answered
      // cannot be asked: nothing on this shelf blocks anything else on it.
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
              // **Buyable again and again now.** `already_held` was the
              // one-voucher rule and it can no longer fire — the flag it read
              // is drained by `migrate` and never written again — so what is
              // left to say is how many are in the bag.
              disabledReason: item.blocked == 'already_held'
                  ? null
                  : blockedCopy(item.blocked),
              activeLabel: tokens > 0 ? '×$tokens' : null,
              onBuy: blockedCopy(item.blocked) != null
                  ? null
                  : () => offerToBuy(context, ref, (
                      key: 'voucher-random',
                      title: t('shop.voucher.random'),
                      subtitle: t('shop.voucher.random_sub'),
                      body: null,
                      glyph: t('shop.voucher.random_icon'),
                      currency: SpendCurrency.gems,
                      glyphColor: hudGemInk,
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
              // **A COUNT, WHERE "ALREADY ACTIVE" USED TO BE.** The family
              // blocked as a family — one voucher at a time — so every rung on
              // the ladder claimed to be the live one, and the fix at the time
              // was to say the rule once at section level instead. Now nothing
              // blocks anything: a rung the player owns three of says ×3, and
              // the tile stays buyable.
              // A rung above this division is LOCKED, not "coming soon": the
              // JS puts a padlock on the button and lets the subtitle name
              // the division. `blockedCopy` has no line for it, and its
              // fallthrough printed the settings screen's "Coming soon" under
              // a tile whose own subtitle said when it unlocks.
              // The held rung wears the green chip; the rungs it blocks say
              // nothing — the rule is the section's note, once, above them.
              final reason = tile.blocked == VoucherBlock.notOffered
                  ? null
                  : blockedCopy(tile.blocked?.name);
              final dead = tile.blocked != null;
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
                locked: !tile.offered,
                disabledReason: reason,
                activeLabel: tile.owned > 0 ? '×${tile.owned}' : null,
                onBuy: dead
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
                        glyph: tierEmoji[tile.floor] ?? 'ticket',
                        currency: SpendCurrency.gems,
                        glyphColor: hudGemInk,
                        cost: tile.cost ?? 0,
                        // **[purchaseScoutVoucher], not `buyScoutVoucher`.**
                        // The latter arms the legacy scalar and exists only to
                        // answer the frozen JS fixture; this one banks the floor
                        // in the inventory, which is what the Scout button and
                        // the assignment sheet read.
                        buy: () {
                          final result = game.update(
                            (s) => purchaseScoutVoucher(s, tile.floor),
                          );
                          if (result.ok) {
                            // Shipped copy in ten languages that had never had
                            // a caller — exactly the tell CLAUDE.md describes.
                            // It is the right sentence for this moment and it
                            // needed no new translation.
                            emit(
                              'toast:success',
                              t('shop.voucher.toast', {'tier': name}),
                            );
                          }
                          return result.reason?.name;
                        },
                      )),
              );
            }(),
        ],
      ),
    );
  }
}

/// The four manager boosts, three across, on a shelf of their own — see
/// `ShopSectionId.matchBoosts`. One gem buys one; the badge is how many are
/// in the bag, so a second buy reads x2 where the first read x1.
class MatchBoostsSection extends ConsumerWidget {
  const MatchBoostsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The bag is a pick, so a buy redraws the badge; the gem balance is the
    // shelf's other input and already has its own.
    ref.watch(saveRevisionProvider);
    ref.watch(gemsProvider);
    final game = ref.read(gameProvider);
    return ShopSectionFrame(
      id: ShopSectionId.matchBoosts,
      child: ShopGrid(
        columns: 3,
        children: [
          for (final boost in boostList)
            // No description on the tile: three across, two clamped lines
            // read as "The ground erupts - the ..." and were cut off on every
            // one. The confirm card carries it. Reported from the couch.
            ShopTile(
              tileKey: 'boost-${boost.id}',
              title: t('boost.${boost.id}.name'),
              // The Roar's red, the same the daily calendar draws them in.
              glyph: _icon(boost.icon, flameDeep),
              badge: t('boost.shop.count', {
                'n': '${boostCount(game.state, boost.id)}',
              }),
              price: formatCoins(boost.gemCost),
              tone: StoreTone.gem,
              disabledReason: blockedCopy(boostPackBlocked(game.state, boost.id)),
              onBuy: blockedCopy(boostPackBlocked(game.state, boost.id)) != null
                  ? null
                  : () => offerToBuy(context, ref, (
                      key: 'boost-${boost.id}',
                      title: t('boost.${boost.id}.name'),
                      subtitle: t('boost.${boost.id}.desc'),
                      // The figure, for the three that have one: "+25% ATK"
                      // is what is being bought, and the prose alone did not
                      // say it. Reported from the couch.
                      body: boost.kind == BoostKind.proactive
                          ? Text(
                              t('boost.${boost.id}.effect'),
                              key: ValueKey('boost-effect-${boost.id}'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: liveBoostColour(boost.id),
                              ),
                            )
                          : null,
                      // Its own icon in the tile's red, not the gem: the
                      // gem is on the button.
                      glyph: boost.icon,
                      currency: SpendCurrency.gems,
                      glyphColor: flameDeep,
                      cost: boost.gemCost,
                      buy: () =>
                          game.update((s) => buyBoostPack(s, boost.id)).reason,
                    )),
            ),
        ],
      ),
    );
  }
}
