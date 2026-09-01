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
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            shopPanelInset,
            hudClearanceOf(context),
            shopPanelInset,
            0,
          ),
          child: _ShopTabs(
            selected: _tab,
            onPick: (i) {
              setState(() => _tab = i);
              if (_scroll.hasClients) _scroll.jumpTo(0);
            },
          ),
        ),
        // **THE PANEL THE TABS OPEN INTO.** Asked for from the couch against a
        // shelf of reference shots, and it is the half of "make them look like
        // tabs" that was missing: the strip already broke its baseline under
        // the selected tab, which is the join — but there was nothing on the
        // other side of it to join TO, so the gap opened onto the club backdrop
        // and the tabs went back to reading as a row of links.
        //
        // The fill is [shopPanelInk], which is the DEEPEST tone in the kit
        // rather than another surface: the tiles are `surface2 → surface` with a
        // border, so a panel in a surface tone is a panel they disappear into.
        // A shop is a case with things in it, and a case is a recess.
        //
        // Opaque, and it covers the backdrop from the tabs down. That is the
        // point rather than a cost — the club backdrops put turf and
        // black-and-white stripes behind this screen, which is what made the top
        // of the Shop unreadable in the first place, and the strip above the
        // tabs still shows them.
        // **AND IT LINES UP WITH THE TABS.** The strip is inset 12 either side
        // and the panel ran to both edges of the phone, so the thing the tabs
        // are supposed to be sitting ON was wider than they were — reported
        // from the couch. Same margin, so the join is a join.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: shopPanelInset),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: shopPanelInk(kit),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              child: SingleChildScrollView(
                key: const ValueKey('shop-scroll'),
                controller: _scroll,
                // The Shop had NO padding at all: its first tile ran under the
                // floating HUD and its last under the tab bar. The strip above
                // carries the HUD's clearance now; this is the tab bar's own.
                //
                // Narrower down the sides than it was, because the panel itself
                // now carries [shopPanelInset]: 12 inside 12 would be 24 of air
                // beside every tile.
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                child: Column(
                  children: [
                    for (final id in shown.sections) _shelf(id),
                    // **Only on the shelves that sell for MONEY.** Restore is
                    // about purchases, and a Restore button under the kit colours
                    // is a control answering a question nobody asked there.
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
          ),
        ),
      ],
    );
  }
}

/// The shop's own ground, and the fill the selected tab is continuous with.
///
/// `kit.bg` rather than a surface, for the reason above: the shelves' tiles are
/// built out of the surface tones, so they need something behind them that is
/// not one. It is also the one token that behaves in both themes — the deepest
/// in dark, near-white in light — which is exactly the relationship a tab strip
/// wants with the tabs sitting on it.
Color shopPanelInk(KitTheme kit) => kit.bg;

/// The margin the tab strip and the panel under it BOTH keep.
///
/// One number, because the whole point of the panel is that the selected tab
/// opens into it — and a panel wider than the tabs standing on it is not a
/// panel they belong to.
const double shopPanelInset = 12;

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
      height: 68,
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
                // **AN UNSELECTED TAB STANDS SHORTER, and that is what makes
                // the strip a stack rather than a row.** Four tabs of one
                // height differing only in fill is a segmented control; a tab
                // that is behind the others is physically further back, and
                // the six points it gives up at the top are the whole of that
                // reading. Reference shots from the couch, where the gap is
                // wider still.
                //
                // The hit target keeps the full height — the `GestureDetector`
                // is outside this padding — so a short tab is not a smaller
                // thing to press.
                child: Padding(
                  padding: EdgeInsets.only(top: i == selected ? 0 : 6),
                  child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // The tab itself: filled, edged, and rounded at the TOP
                    // only. A uniform border is a hard requirement of
                    // `BoxDecoration` once there is a radius, so the top
                    // accent and the baseline are drawn as their own strips
                    // over it rather than as sides of this one.
                    //
                    // **AND EVERY TAB IS OPAQUE.** The unselected ones were
                    // `Colors.transparent` with a muted label on them, which is
                    // fine over a plain page and unreadable over the ones this
                    // game actually draws: the club backdrops put turf and
                    // black-and-white stripes directly behind the strip, and the
                    // top of the Shop was reported as impossible to read on
                    // them. The tint the selected tab carries is now BLENDED
                    // onto that fill rather than laid over the page, so its
                    // colour is the same colour it was.
                    //
                    // **AND THE SELECTED ONE IS THE PANEL'S OWN FILL**, tinted.
                    // It was blended onto `kit.surface`, which is the tile
                    // colour — so the tab that is supposed to be the mouth of
                    // the panel was a different colour from the panel, and the
                    // broken baseline underneath it opened onto a seam. Blended
                    // onto [shopPanelInk] the join has nothing to show, which
                    // is the only way a tab reads as continuous with what it
                    // opens into.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        color: i == selected
                            ? Color.alphaBlend(
                                tab.ink.withValues(alpha: 0.16),
                                shopPanelInk(kit),
                              )
                            : kit.surface,
                        border: Border.all(
                          color: i == selected
                              ? tab.ink.withValues(alpha: 0.45)
                              : Colors.transparent,
                        ),
                        boxShadow: i == selected
                            ? [
                                // The selected tab stands proud of the two
                                // beside it, so it casts on them.
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.28),
                                  blurRadius: 8,
                                  offset: const Offset(0, -1),
                                ),
                              ]
                            : null,
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
                        // **The glyph carries the tab, so it is drawn at a
                        // size that can.** The reference shops put a piece of
                        // ART on each tab and a word under it; the label here
                        // is 9.5pt of two-line translated copy, which cannot be
                        // the thing you aim at. Bigger icon, and it keeps the
                        // shelf's colour even unselected — at a third of the
                        // alpha, so the strip is four colours knocked back
                        // rather than four greys.
                        Icon(
                          tab.icon,
                          size: 23,
                          color: i == selected
                              ? tab.ink
                              : Color.alphaBlend(
                                  tab.ink.withValues(alpha: 0.45),
                                  kit.textMuted,
                                ),
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
            ),
        ],
      ),
    );
  }
}
