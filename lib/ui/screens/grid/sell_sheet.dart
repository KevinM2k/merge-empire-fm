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
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
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
        ? ((state!['grid'] as Map<String, dynamic>)['cells'] as List).firstWhere(
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
    heightFraction: 0.62,
    child: Builder(
      builder: (sheetContext) {
        final kit = Theme.of(sheetContext).extension<KitTheme>()!;
        return ListView(
          key: const ValueKey('sell-sheet'),
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(
              height: 96,
              child: Center(
                child: SizedBox(width: 72, child: PlayerCard(view: view)),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                view.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (blocked == null) ...[
              Center(
                child: Text(
                  t(tier.labelKey),
                  key: const ValueKey('sell-tier'),
                  style: TextStyle(color: kit.textMuted, fontSize: 12),
                ),
              ),
              Center(
                child: Text(
                  formatCoins(price),
                  key: const ValueKey('sell-price'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: kit.accentBright,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  t('sell.market_note'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kit.textMuted, fontSize: 11),
                ),
              ),
              const SizedBox(height: 16),
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
