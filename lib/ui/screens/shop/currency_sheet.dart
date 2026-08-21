/// The coin and gem packs, as a sheet you can open from the HUD.
///
/// **A player who taps the coin counter wants to buy coins.** The HUD's `+` used
/// to send them to the Shop tab with a pending section, and the Shop scrolled to
/// that section's heading — into the top of the viewport, which is where the
/// floating HUD is. So the heading the whole journey was aimed at was the one
/// thing off the screen, and the answer to "how do I get coins" was a tab switch
/// followed by a scroll that landed under the glass.
///
/// The tab still deep-links, and `shop_screen.dart` now clears the HUD when it
/// does — the bus events an engine can fire (`nav:shop-coins`, `nav:shop-gems`)
/// are a jump to a shelf, and this is the chip beside the number.
///
/// It sells nothing that the tab does not, and draws it with the same tiles for
/// exactly that reason: two implementations of one shelf is the thing that
/// drifts. `Shop` at the bottom is the way through to the rest of it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/popups/sheet_header.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_paid.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_section.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// Open the packs for [which] directly, over whatever screen asked.
Future<void> showCurrencySheet(
  BuildContext context,
  ShopSection which,
) => showBottomSheetPopup<void>(
  context,
  // A CEILING. Four coin packs is four coin packs tall; taking two thirds of
  // the screen to show them read as a screen that had failed to load.
  heightFraction: 0.8,
  fitContent: true,
  child: CurrencySheet(which: which),
);

class CurrencySheet extends ConsumerWidget {
  const CurrencySheet({super.key, required this.which});

  final ShopSection which;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final shelf = currencyShelves[which]!;

    return Column(
      key: ValueKey('currency-sheet-${which.name}'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The SHEET's title, not the shop section's. Inside the tab the shelf
        // heading is one of several on a scrolling page and reads as a divider;
        // opened on its own it is the only thing on screen, and a sheet is the
        // game talking. See `sheet_header.dart`.
        SheetHeader(title: t(shelf.id.titleKey)),
        // Flexible, not Expanded: it takes the room it needs and scrolls only if
        // the ceiling is reached.
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: ShopGrid(children: paidTilesFor(ref, shelf.categories)),
          ),
        ),
        Divider(height: 1, color: kit.border),
        // The rest of the shop is one tap away, and the deep link still points
        // at the shelf this sheet is showing — so backing out of here into the
        // tab lands in the same place rather than at the top.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: TextButton(
            key: const ValueKey('currency-sheet-shop'),
            onPressed: () {
              Navigator.of(context).maybePop();
              ref.read(shellControllerProvider.notifier).deepLinkShop(which);
            },
            child: Text(t('nav.shop')),
          ),
        ),
      ],
    );
  }
}
