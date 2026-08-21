/// The sell sheet, opened by tapping a card.
///
/// Until this the grid was one-way: cards came in and never left, and tapping
/// one did nothing at all.
///
/// The market multiplier is rolled ONCE, when the sheet opens, and the sale
/// takes that same number. Rolling again on confirm would pay out something
/// other than the figure the player just agreed to.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/sell_card_engine.dart';
import 'package:merge_empire_fc/engine/sell_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/popups/sheet_header.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';
import 'package:merge_empire_fc/util/format.dart';

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

  // Rolled here, once. The sheet quotes it and the sale takes it.
  final card = CardInstance.from(
    (state?['grid'] as Map<String, dynamic>?)?['cells'] is List
        ? ((state!['grid'] as Map<String, dynamic>)['cells'] as List)
              .firstWhere(
                (c) =>
                    c is Map<String, dynamic> && c['instanceId'] == instanceId,
                orElse: () => null,
              )
        : null,
  );
  final mult = rollMarketMult(card);
  final price = sellPriceAt(state, instanceId, mult);
  final tier = marketTierFor(mult);

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
                height: 200,
                dimmed: view.injured,
              ),
            ),
            const SizedBox(height: 14),
            if (blocked == null) ...[
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
                decoration: BoxDecoration(
                  color: kit.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kit.border),
                ),
                child: Column(
                  children: [
                    Text(
                      t(tier.labelKey).toUpperCase(),
                      key: const ValueKey('sell-tier'),
                      style: TextStyle(
                        color: kit.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CoinIcon(size: 20, solid: true),
                        const SizedBox(width: 6),
                        Text(
                          formatCoins(price),
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
                      style: TextStyle(color: kit.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                key: const ValueKey('sell-confirm'),
                onPressed: () {
                  game.update((s) => sellCard(s, instanceId, mult));
                  Navigator.of(sheetContext).pop();
                },
                child: Text(t('common.sell')),
              ),
            ] else
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
        );
      },
    ),
  );
}
