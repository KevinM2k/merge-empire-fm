/// The sell sheet, opened by tapping a card.
///
/// Until this the grid was one-way: cards came in and never left, and tapping
/// one did nothing at all.
///
/// The market multiplier is a standing offer on a clock — see
/// `market_offer.dart`. It was rolled on every open, so closing and reopening
/// the sheet shopped for a better price. The sale takes the figure that was on
/// screen when Sell was pressed: the quote freezes at the tap, because a price
/// that moved between "Sell" and "Confirm" is a bait-and-switch.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/sell_card_engine.dart';
import 'package:merge_empire_fc/engine/sell_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/popups/sheet_header.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/market_offer.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';
import 'package:merge_empire_fc/util/format.dart';

/// The offer plate. Dark in BOTH themes, because the figure on it is gold and
/// gold has to sit on something.
const Color _plate = Color(0xFF14171B);

/// Its small print, at a readable weight on that plate.
const Color _plateInk = Color(0xFFB6BCC4);

/// Why a card cannot be sold, in copy that already ships.
String sellBlockedCopy(String reason) => switch (reason) {
  // 'A borrowed player is not yours to lend on.' — the same rule, and the
  // shipped sentence for it.
  'on_loan' || 'loaned_out' => t('event.deadline.blocked_loan_card'),
  'listed' => t('shop.already_active'),
  _ => t('settings.comingSoon'),
};

Future<void> showSellSheet(
  BuildContext context,
  WidgetRef ref, {
  required String instanceId,
  required CardView view,
}) {
  final game = ref.read(gameProvider);
  final state = game.state;
  final blocked = sellBlocked(state, instanceId);

  return showBottomSheetPopup<void>(
    context,
    // **Tall enough that the button is not below the fold.** It was 0.62 with a
    // 96px thumbnail; the full-length figure is worth the room, and a sell sheet
    // whose confirm has to be scrolled to is a sheet that looks broken.
    heightFraction: 0.88,
    child: Builder(
      builder: (sheetContext) {
        final kit = Theme.of(sheetContext).extension<KitTheme>()!;
        return ListView(
          key: const ValueKey('sell-sheet'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            // The PLAYER's name is the sheet's title — this sheet is about one
            // card and nothing else, so a separate "Sell" heading over his own
            // name would be a heading about the button. See `sheet_header.dart`.
            SheetHeader(
              title: view.name,
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
            ),
            // **THE PLAYER, not his merge card.** It was a 72px thumbnail in a
            // 96px box — the same man the squad sheet gives 260px of
            // full-length figure to, described here as an inventory item. What
            // is being decided is whether to sell a person, so it is the person
            // you look at. Same widget as the squad sheet, so the two cannot
            // drift.
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: PlayerHeroArt(
                key: const ValueKey('sell-hero'),
                position: view.position,
                tier: view.tier,
                variant: view.variant ?? 0,
                // More of HIM. The decision is about the player, so he gets the
                // room — the sheet is 88% tall and the offer under him is three
                // short lines.
                height: 300,
                dimmed: view.injured,
              ),
            ),
            const SizedBox(height: 14),
            if (blocked == null)
              // **THE QUOTE IS LIVE.** It stands for its window and then moves,
              // countdown and all — the panel and the button are both inside the
              // builder so the sale can only ever take the figure on screen.
              MarketOffer(
                instanceId: instanceId,
                builder: (context, offer) {
                  final tier = marketTierFor(offer.mult);
                  return Column(
                    children: [
                      // **THE OFFER AS A PANEL.** Three centred lines of text under a
                      // picture is a caption; the figure is the whole decision, so it
                      // gets a surface of its own with the market's own word over it and
                      // the small print under it.
                      Container(
                        key: const ValueKey('sell-offer'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        // **A DARK PLATE, in both themes, and no rule round it.**
                        // A ruled box reads as a form field, and a surface a
                        // shade off the sheet's own left the gold figure sitting
                        // on white — which is what the halo under the digits was
                        // invented to fix and what the bronze was invented to
                        // fix after that. The money keeps its yellow and the
                        // contrast comes from underneath it, the way a
                        // scoreboard does it.
                        decoration: BoxDecoration(
                          color: _plate,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  t(tier.labelKey).toUpperCase(),
                                  key: const ValueKey('sell-tier'),
                                  style: const TextStyle(
                                    color: _plateInk,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                // The clock the offer runs on, beside the word for it —
                                // where the JS's market block puts it.
                                Text(
                                  t('squad.refresh_in', {'n': offer.secsLeft}),
                                  key: const ValueKey('sell-refresh'),
                                  style: const TextStyle(
                                    color: _plateInk,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // The disc takes the FIGURE's ink, so the pair is one
                                // currency on a light page — see `coinFigureInk`.
                                CoinIcon(
                                  size: 20,
                                  solid: true,
                                  color: coinFigureInk(sheetContext),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  formatCoins(offer.price),
                                  key: const ValueKey('sell-price'),
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: coinFigureInk(sheetContext),
                                    shadows: coinFigureShadows(sheetContext),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              t('sell.market_note'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _plateInk,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // **SIDE BY SIDE, and coloured for what they do.** Stacked,
                      // the two full-width buttons read as two steps of the same
                      // flow; the choice is one decision with two answers, so it
                      // is one row — the way Colin's own card asks.
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              key: const ValueKey('sell-cancel'),
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: kit.textMuted,
                                side: BorderSide(color: kit.border),
                              ),
                              child: Text(t('common.cancel')),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              key: const ValueKey('sell-confirm'),
                              // **IT ASKS FIRST.** Selling is irreversible and the button sits
                              // under the thumb at the foot of a sheet, so a mis-tap costs a
                              // player. This confirmation used to guard the squad sheet's own
                              // Sell; that button has gone, and the guard belongs with the one
                              // that remains rather than with the one that left.
                              //
                              // And it asks as COLIN, on a screen whose premise is that there
                              // is a manager to talk to — the copy is already shipped and
                              // translated, including what the sale COSTS in its own right:
                              // the bonuses go with him, and burying that inside the offer is
                              // how somebody agrees to something they did not read.
                              onPressed: () async {
                                final confirmed = await showCoachCard<bool>(
                                  sheetContext,
                                  titleKey: 'sell.title',
                                  // `sell.title` is `Sell {name}?` and there was no way to
                                  // fill it, so the card asked with the braces showing.
                                  titleParams: {'name': view.name},
                                  bodyKey: 'sell.receive',
                                  // The figure gets a COIN beside it rather than sitting in
                                  // the middle of a sentence: money on a card should look
                                  // like money.
                                  coins: offer.price,
                                  // **WHAT THE SALE ACTUALLY COSTS, in the club's own terms.**
                                  // "You'll lose its bonuses permanently" names a category
                                  // rather than a consequence, and what a player weighing an
                                  // offer wants is the number they are giving up — the income
                                  // he pays every second. Null on a view with no rate to show,
                                  // and then the old line is the honest one.
                                  extraTexts: [
                                    if (view.incomePerSec != null)
                                      '${t('squad.detail.income')}: '
                                          '−${view.incomePerSec!.toStringAsFixed(2)}/s',
                                  ],
                                  extraLines: [
                                    if (view.incomePerSec == null)
                                      (
                                        key: 'sell.lose_bonuses',
                                        params: const {},
                                        strong: false,
                                      ),
                                  ],
                                  actions: [
                                    CoachAction(
                                      labelKey: 'common.cancel',
                                      tone: CoachTone.decline,
                                      onTap: () {},
                                    ),
                                    CoachAction(
                                      labelKey: 'common.sell',
                                      tone: CoachTone.confirm,
                                      onTap: () {},
                                      result: true,
                                    ),
                                  ],
                                );
                                if (confirmed != true ||
                                    !sheetContext.mounted) {
                                  return;
                                }
                                game.update(
                                  (s) => sellCard(s, instanceId, offer.mult),
                                );
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kit.accent,
                                foregroundColor: kit.accentInk,
                              ),
                              child: Text(t('common.sell')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              )
            else ...[
              Center(
                child: Text(
                  sellBlockedCopy(blocked),
                  key: const ValueKey('sell-blocked'),
                  style: TextStyle(color: kit.textMuted),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const ValueKey('sell-cancel'),
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(t('common.cancel')),
              ),
            ],
          ],
        );
      },
    ),
  );
}
