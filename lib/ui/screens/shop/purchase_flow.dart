/// Buying something with coins or gems: ask, then spend — or show the player
/// where the money is.
///
/// **"Not enough gems" is never said.** A dead tile with a refusal printed under
/// it is a dead end: the player wanted the thing, and the answer to wanting it
/// is a way to afford it, not a sentence explaining that they cannot. So every
/// priced row stays tappable, and a purchase the balance will not cover ends at
/// the coin or gem packs rather than at a greyed-out button.
///
/// Three beats, and the middle one is the whole point:
///
/// 1. **Ask.** A centred card with the item, what it does and what it costs —
///    the JS's `_showPurchaseConfirm` shape. Spending a currency the player
///    bought with real money should take a deliberate tap.
/// 2. **Short?** The bottom sheet for the currency they are short of, so the
///    next thing on screen is the thing that fixes it.
/// 3. **Paid?** A receipt, so a purchase is an event rather than a number
///    quietly changing.
///
/// A refusal that is NOT about money — already owned, already active, nobody
/// injured to heal — is a different thing and is still said on the tile: those
/// are answers, not obstacles.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/shop/currency_sheet.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';

/// Which balance a row spends from.
enum SpendCurrency {
  coins(ShopSection.coins, 'coin'),
  gems(ShopSection.gems, 'gem');

  const SpendCurrency(this.section, this.icon);

  /// The sheet to open when the balance will not cover it.
  final ShopSection section;

  /// Its icon in `game_icon.dart`.
  final String icon;
}

/// What one priced row is offering.
typedef SpendOffer = ({
  String key,
  String title,
  String? subtitle,

  /// An icon NAME from `game_icon.dart` — the app's own line art, not an emoji.
  String glyph,
  SpendCurrency currency,
  int cost,

  /// Anything the offer wants to SHOW rather than say.
  ///
  /// A subtitle can only summarise — "two Headwear, one Accessory" is a count
  /// of things the player cannot see, and the tile with the picture on it is
  /// behind this card. A look pack puts its actual contents here, one row per
  /// item with a tick against the ones already owned, which is what "it should
  /// list all of the items that come in it" asks for.
  Widget? body,

  /// Runs the engine. Returns null when it went through, or a reason when the
  /// engine refused for something other than money.
  String? Function() buy,
});

/// The balance a currency is held in.
int balanceOf(WidgetRef ref, SpendCurrency currency) => switch (currency) {
  SpendCurrency.coins => ref.read(coinsProvider).toInt(),
  SpendCurrency.gems => ref.read(gemsProvider).toInt(),
};

/// Run the three beats. Completes once the player is done with it.
Future<void> offerToBuy(
  BuildContext context,
  WidgetRef ref,
  SpendOffer offer,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => _ConfirmCard(offer: offer),
  );
  if (confirmed != true || !context.mounted) return;

  // Checked HERE rather than on the tile, because the balance can move while the
  // card is open — an idle tick pays out every second.
  if (balanceOf(ref, offer.currency) < offer.cost) {
    await showCurrencySheet(context, offer.currency.section);
    return;
  }

  final refused = offer.buy();
  if (!context.mounted) return;
  if (refused != null) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _ReceiptCard(offer: offer),
  );
}

class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard({required this.offer});

  final SpendOffer offer;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return AlertDialog(
      key: ValueKey('spend-confirm-${offer.key}'),
      backgroundColor: kit.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: kit.border),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameIcon(offer.glyph, size: 40, color: kit.accentBright),
          const SizedBox(height: 8),
          Text(
            offer.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          if (offer.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              offer.subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(color: kit.textMuted, fontSize: 13, height: 1.5),
            ),
          ],
          if (offer.body case final body?) ...[
            const SizedBox(height: 12),
            body,
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GameIcon(
                offer.currency.icon,
                size: 22,
                color: const Color(0xFFFFD700),
              ),
              const SizedBox(width: 6),
              Text(
                formatCoins(offer.cost),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFD700),
                ),
              ),
            ],
          ),
        ],
      ),
      // In a LINE, both the same width: the two answers to one question should
      // not be different sizes.
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: ValueKey('spend-cancel-${offer.key}'),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(t('common.cancel')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              // Coloured for the WALLET it is about to take from, so the
              // confirmation and the tile it came from agree — see
              // [StoreButton].
              child: StoreButton(
                key: ValueKey('spend-confirm-yes-${offer.key}'),
                tone: offer.currency == SpendCurrency.gems
                    ? StoreTone.gem
                    : StoreTone.coin,
                label: t('shop.buy_now'),
                onTap: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.offer});

  final SpendOffer offer;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return AlertDialog(
      key: ValueKey('spend-receipt-${offer.key}'),
      backgroundColor: kit.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: kit.accent.withValues(alpha: 0.5)),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameIcon(offer.glyph, size: 40, color: kit.accentBright),
          const SizedBox(height: 10),
          Text(
            // The shipped line, which already names the thing and the glyph.
            t('shop.toast.purchased', {'icon': '', 'name': offer.title}).trim(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: kit.accentBright,
            ),
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          // Not a price, so it takes the club's accent rather than borrowing a
          // currency's colour.
          child: StoreButton(
            key: ValueKey('spend-receipt-ok-${offer.key}'),
            tone: StoreTone.neutral,
            label: t('common.got_it'),
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
      ],
    );
  }
}
