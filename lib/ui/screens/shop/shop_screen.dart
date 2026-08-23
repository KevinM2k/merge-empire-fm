/// The Shop — seven shelves in a deliberate order.
///
/// The order is not arbitrary and was arrived at by fixing a mess: offers and
/// passes first (the highest-converting slot), then the free shelf — the reason
/// a non-payer opens the shop at all — then hard currency before soft, then the
/// things those currencies buy, then cosmetics.
///
/// The Gems section stays on screen even once the Style Vault is owned: a
/// section that deletes itself takes the player's balance off screen with it.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_free.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_looks.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_paid.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_section.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_spend.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => ShopScreenState();
}

class ShopScreenState extends ConsumerState<ShopScreen> {
  final ScrollController _scroll = ScrollController();

  /// Which tab is open. For tests.
  int get tab => _tab;
  int _tab = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // The tab may be built by the very frame that set the deep link, so the
    // first jump happens here rather than only on a later change.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPending());
  }

  /// **A DEEP LINK SELECTS A TAB now, rather than scrolling to a heading.**
  ///
  /// It used to `ensureVisible` a section anchor and then back the scroll off by
  /// the HUD's clearance, because `ensureVisible` puts its target at the top of
  /// the VIEWPORT and the top of the viewport is under the floating HUD — so
  /// the one thing a deep link was aimed at was the one thing behind the glass.
  /// A tab has no such problem: the shelf is the only thing on the page.
  void _openPending() {
    if (!mounted) return;
    final pending = ref.read(shellControllerProvider).pendingShopSection;
    if (pending == null) return;
    final id = switch (pending) {
      ShopSection.coins => ShopSectionId.coins,
      ShopSection.gems => ShopSectionId.gems,
    };
    final index = shopTabOf(id);
    if (index >= 0) {
      setState(() => _tab = index);
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
    // Consumed immediately, so a later rebuild does not jump again.
    ref.read(shellControllerProvider.notifier).consumePendingShopSection();
  }

  Widget _shelf(ShopSectionId id) => switch (id) {
    ShopSectionId.offers => const OffersSection(),
    ShopSectionId.free => const FreeShelfSection(),
    ShopSectionId.gems => const GemPacksSection(),
    ShopSectionId.coins => const CoinPacksSection(),
    ShopSectionId.boosts => const BoostsSection(),
    ShopSectionId.vouchers => const VouchersSection(),
    ShopSectionId.looks => const LooksSection(),
  };

  @override
  Widget build(BuildContext context) {
    ref.listen(shellControllerProvider, (_, next) {
      if (next.pendingShopSection != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _openPending());
      }
    });

    final shown = shopTabs[_tab];
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(12, hudClearanceOf(context), 12, 0),
          child: _ShopTabs(
            selected: _tab,
            onPick: (i) {
              setState(() => _tab = i);
              if (_scroll.hasClients) _scroll.jumpTo(0);
            },
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('shop-scroll'),
            controller: _scroll,
            // The Shop had NO padding at all: its first tile ran under the
            // floating HUD and its last under the tab bar. The strip above
            // carries the HUD's clearance now; this is the tab bar's own.
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              children: [
                for (final id in shown.sections) _shelf(id),
                // **Only on the shelves that sell for MONEY.** Restore is about
                // purchases, and a Restore button under the kit colours is a
                // control answering a question nobody asked there.
                if (shown.sections.any(
                  (id) =>
                      id == ShopSectionId.offers ||
                      id == ShopSectionId.gems ||
                      id == ShopSectionId.coins,
                ))
                  const RestoreRow(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The strip that picks a shelf.
///
/// **Each tab keeps its section's own colour**, which is the whole reason the
/// sections have one: painting seven shelves in the club's accent turns the
/// shop into one undifferentiated list, and a tab strip in one colour does
/// exactly the same thing to the tabs.
class _ShopTabs extends StatelessWidget {
  const _ShopTabs({required this.selected, required this.onPick});

  final int selected;
  final void Function(int) onPick;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return SizedBox(
      height: 54,
      child: Row(
        key: const ValueKey('shop-tabs'),
        children: [
          for (final (i, tab) in shopTabs.indexed)
            Expanded(
              child: GestureDetector(
                key: ValueKey('shop-tab-${tab.label.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onPick(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab.label.icon,
                      size: 18,
                      color: i == selected ? tab.label.ink : kit.textMuted,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      t(tab.label.titleKey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: i == selected ? tab.label.ink : kit.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // The underline is the selection, in the shelf's own colour.
                    Container(
                      height: 2,
                      width: 22,
                      decoration: BoxDecoration(
                        color: i == selected
                            ? tab.label.ink
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
