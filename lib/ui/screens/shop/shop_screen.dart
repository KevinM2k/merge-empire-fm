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
    // Both land on the same tab now — it holds both shelves, and the gem rows
    // lead it, so a coin link still arrives with its packs one flick away.
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
/// **THEY HAVE TO LOOK LIKE TABS.** What was here was an icon, a label and a
/// short underline — a row of LINKS, which says which one is highlighted and
/// never says that the thing below belongs to it. A tab is a container: it has
/// an edge, it is filled, and its bottom edge is OPEN into the panel, which is
/// the one detail that does all the work.
///
/// So the baseline is drawn per segment rather than across the strip — an
/// unselected tab draws it, the selected one does not — and the gap it leaves
/// is the join. The fill and the top accent are the shelf's own colour, which
/// is why the sections have one: four tabs in the club's accent would be the
/// same undifferentiated list the colours were introduced to break up.
class _ShopTabs extends StatelessWidget {
  const _ShopTabs({required this.selected, required this.onPick});

  final int selected;
  final void Function(int) onPick;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final rule = kit.textMuted.withValues(alpha: 0.35);
    const radius = BorderRadius.vertical(top: Radius.circular(12));
    return SizedBox(
      // Two lines of label, because one of them needs two — see below.
      height: 64,
      child: Row(
        key: const ValueKey('shop-tabs'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, tab) in shopTabs.indexed)
            Expanded(
              child: GestureDetector(
                key: ValueKey('shop-tab-${shopTabSlug(tab)}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onPick(i),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // The tab itself: filled, edged, and rounded at the TOP
                    // only. A uniform border is a hard requirement of
                    // `BoxDecoration` once there is a radius, so the top
                    // accent and the baseline are drawn as their own strips
                    // over it rather than as sides of this one.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        color: i == selected
                            ? tab.ink.withValues(alpha: 0.16)
                            : Colors.transparent,
                        border: Border.all(
                          color: i == selected
                              ? tab.ink.withValues(alpha: 0.45)
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    if (i == selected)
                      // The accent is the tab's own top edge, at the weight a
                      // frame would be — not a stripe floating under a label.
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: ClipRRect(
                          borderRadius: radius,
                          child: Container(height: 3, color: tab.ink),
                        ),
                      ),
                    // **THE BASELINE BREAKS UNDER THE SELECTED TAB.** That gap
                    // is what makes the panel below read as this tab's
                    // contents rather than as the next thing down the page,
                    // and it is the whole difference between a tab and a link.
                    if (i != selected)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(height: 1, color: rule),
                      ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tab.icon,
                          size: 19,
                          color: i == selected ? tab.ink : kit.textMuted,
                        ),
                        const SizedBox(height: 3),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          // **IT WRAPS RATHER THAN ELLIPSISING.** "Manager
                          // Customisations" is a quarter of the strip's width
                          // and came out as "Manager Custo…" — reported, and a
                          // cut-off label on a tab is worse than a shorter one.
                          // Shorter copy is not available: the catalogues are
                          // generated from the JS and no `t()` key can be added
                          // from this repo. So the room comes from the strip.
                          child: Text(
                            t(tab.titleKey),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9.5,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              color: i == selected
                                  ? Theme.of(context).colorScheme.onSurface
                                  : kit.textMuted,
                            ),
                          ),
                        ),
                      ],
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
