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

/// **EVERY REAL-MONEY TAP GOES THROUGH THIS**, which is the JS's own sentence
/// and its own comment on the line that binds the tiles. It looks redundant
/// beside the store's own payment sheet and is not: the store's sheet says what
/// is being charged, and this one says what is being BOUGHT — a product name, a
/// description and the price, in the game's own words, before the platform
/// takes the screen.
///
/// It also carries `shop.payment_disclaimer`, which is shipped copy this port
/// had no caller for, and it is the JS that decides the wording per platform:
/// the string names the App Store and Google Play is substituted on Android.
Future<bool> confirmRealMoneyPurchase(
  BuildContext context, {
  required String productId,
  required String icon,
  required String name,
  required String? description,
  required String price,
  required bool android,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => _PaidConfirmCard(
      productId: productId,
      icon: icon,
      name: name,
      description: description,
      price: price,
      android: android,
    ),
  );
  return confirmed == true;
}

class _PaidConfirmCard extends StatelessWidget {
  const _PaidConfirmCard({
    required this.productId,
    required this.icon,
    required this.name,
    required this.description,
    required this.price,
    required this.android,
  });

  final String productId;
  final String icon;
  final String name;
  final String? description;
  final String price;
  final bool android;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return AlertDialog(
      key: ValueKey('paid-confirm-$productId'),
      backgroundColor: kit.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: kit.border),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The product's own glyph, which for the paid shelf is an emoji in
          // the catalogue rather than a name in `game_icon.dart`.
          Text(icon, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: TextStyle(color: kit.textMuted, fontSize: 13, height: 1.5),
            ),
          ],
          const SizedBox(height: 16),
          // **A REAL-MONEY PRICE IS NOT COIN GOLD.** It was a hardcoded
          // `0xFFFFD700` — the raw coin yellow, 1.1:1 on the near-white card
          // this dialog is drawn on, so the one figure the player has to read
          // before spending actual money was the least readable thing on it.
          // Reported from the couch with a shot of it.
          //
          // And gold is the wrong SIGN as well as the wrong shade: £0.99 buys
          // gems, it is not paid in coins. The page's own ink says the number
          // plainly, which is what a price on a confirmation should do.
          Text(
            price,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: ValueKey('paid-cancel-$productId'),
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(foregroundColor: dangerInk),
                child: Text(t('common.cancel')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              // Green: this is the one tone that leaves the game to be paid.
              child: StoreButton(
                key: ValueKey('paid-confirm-yes-$productId'),
                tone: StoreTone.cash,
                label: t('shop.buy_now'),
                onTap: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            android
                ? t('shop.payment_disclaimer').replaceAll(
                    'App Store',
                    'Google Play',
                  )
                : t('shop.payment_disclaimer'),
            textAlign: TextAlign.center,
            style: TextStyle(color: kit.textMuted, fontSize: 10, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard({required this.offer});

  final SpendOffer offer;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return _SpendDialog(
      dialogKey: ValueKey('spend-confirm-${offer.key}'),
      surface: kit.surface,
      edge: kit.border,
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
                style: OutlinedButton.styleFrom(foregroundColor: dangerInk),
                child: Text(t('common.cancel')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              // **THE PRICE IS ON THE BUTTON**, with its own currency's mark,
              // which is what every priced control in this shop already does.
              // It was a 24pt figure in COIN GOLD floating above the buttons —
              // gold for a gem price too — and the button under it said only
              // "Buy now". Reported as the gem and the number wanting to be on
              // the buy button.
              //
              // Coloured for the WALLET it is about to take from, so the
              // confirmation and the tile it came from agree — see
              // [StoreButton].
              child: StoreButton(
                key: ValueKey('spend-confirm-yes-${offer.key}'),
                tone: offer.currency == SpendCurrency.gems
                    ? StoreTone.gem
                    : StoreTone.coin,
                label: formatCoins(offer.cost),
                leading: GameIcon(offer.currency.icon, size: 14),
                onTap: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// **A DIALOG THAT DOES NOT MEASURE WHAT IT IS GIVEN.**
///
/// `AlertDialog` wraps its column in an `IntrinsicWidth`, which asks the whole
/// subtree for a DRY LAYOUT — and `LayoutBuilder` cannot answer one, by
/// design: working it out would mean running the build callback speculatively.
/// So an offer whose `body` contains one throws
/// `_RenderLayoutBuilder does not support dry layout` mid-layout, the subtree
/// never gets a size, and every ancestor then fails its own `hasSize` assert.
/// On a device that is a grey screen and a wall of `!semantics.parentDataDirty`
/// in the log; reported from the couch as a style pack going grey when tapped.
///
/// The pack sheet is exactly that case — `LookPreview` scales the rig off its
/// own box, so it must have a `LayoutBuilder` — and it reached the dry pass
/// through the `Wrap` the chips are laid out in. Nothing about it is wrong; the
/// dialog asking arbitrary caller-supplied content for its intrinsic width is.
///
/// So the width is a NUMBER here rather than a measurement, and no ancestor of
/// `offer.body` ever needs a dry layout. It also stops the next `body` from
/// having to know any of this.
class _SpendDialog extends StatelessWidget {
  const _SpendDialog({
    required this.dialogKey,
    required this.surface,
    required this.edge,
    required this.content,
    required this.actions,
  });

  final Key dialogKey;
  final Color surface;
  final Color edge;
  final Widget content;

  /// Laid out under the content in the same column, so the card is one box —
  /// `AlertDialog` kept them in separate padding regions and the two had to
  /// agree by hand.
  final List<Widget> actions;

  /// What `AlertDialog` would have measured its way to on every phone this
  /// game runs on, give or take the odd point.
  static const double _width = 300;

  @override
  Widget build(BuildContext context) => Dialog(
    key: dialogKey,
    backgroundColor: surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: edge),
    ),
    child: ConstrainedBox(
      // A phone narrower than the card still gets a card that fits, and the
      // `Dialog`'s own 40pt of inset is already off the top of this.
      constraints: const BoxConstraints(maxWidth: _width),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [content, const SizedBox(height: 20), ...actions],
          ),
        ),
      ),
    ),
  );
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
