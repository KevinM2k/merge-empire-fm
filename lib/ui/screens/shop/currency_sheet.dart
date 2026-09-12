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

/// Open the packs for [which] directly, over whatever screen asked.
Future<void> showCurrencySheet(
  BuildContext context,
  ShopSection which,
) => showBottomSheetPopup<void>(
  context,
  // A CEILING. Four coin packs is four coin packs tall; taking two thirds of
  // the screen to show them read as a screen that had failed to load.
  heightFraction: 0.8,
  child: CurrencySheet(which: which),
);

class CurrencySheet extends ConsumerStatefulWidget {
  const CurrencySheet({super.key, required this.which});

  final ShopSection which;

  @override
  ConsumerState<CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends ConsumerState<CurrencySheet> {
  @override
  void initState() {
    super.initState();
    // **THIS IS HOW MOST PLAYERS REACH THE PACKS.** The HUD's coin and gem
    // chips open this sheet directly, so a session whose boot never heard from
    // Play priced every tile here in sterling and had nothing to ask again —
    // the Shop tab's own re-ask does not run, because the tab is never built.
    // Reported from Italy as the store quoting GBP.
    askStoreAgainIfItNeverAnswered(ref, stillThere: () => mounted);
  }

  @override
  Widget build(BuildContext context) {
    final shelf = currencyShelves[widget.which]!;

    return Column(
      key: ValueKey('currency-sheet-${widget.which.name}'),
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
        // **NO SHOP LINK.** This sheet IS the shelf — every pack on the tab is
        // already on it — so a button labelled "Shop" under them offered to
        // take the player somewhere to see what they were looking at. Asked to
        // go; a tap outside and the handle both close it.
      ],
    );
  }
}
