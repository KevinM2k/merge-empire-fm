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
    ShopSectionId.gems => const GemPacksSection(),
    ShopSectionId.coins => const CoinPacksSection(),
    ShopSectionId.boosts => const BoostsSection(),
    ShopSectionId.income => const IncomeSection(),
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
        //
        // **SQUARE ACROSS THE TOP, and that is the rest of the same fix.** The
        // panel wore a 14-point radius on its top corners while the tabs above
        // it are square-shouldered, so at each end of the strip the tab's corner
        // overhung the curve and the join came apart at exactly the two points
        // it most needed to hold. Reported from the couch: they do not match up.
        // A tab and the panel it opens into share one edge, and a shared edge
        // cannot be rounded on one side only.
        Expanded(
          child: Padding(
            // **AND IT STOPS SHORT OF THE DOCK.** The case ran to the bottom
            // of the screen, so its framed edge met the nav bar's top edge
            // with nothing between them and the two read as one thick rule.
            // Asked for from the couch: about twelve points of air.
            padding: const EdgeInsets.fromLTRB(
              shopPanelInset,
              0,
              shopPanelInset,
              12,
            ),
            child: DecoratedBox(
              // **THE SAME FILL AS THE TAB THAT OPENED IT.** The selected tab
              // is a 16% wash of its own colour over [shopPanelInk] and the
              // panel was the undiluted ink, so the two met at a colour
              // change — and this file's whole argument for the square
              // shoulders and the broken baseline is that a tab and the panel
              // it opens into SHARE an edge. A shared edge between two
              // different fills is still a seam. Asked from the couch as a
              // question; it is the same [shopTabFill] on both sides now, so
              // the join is only where the frame says it is.
              key: const ValueKey('shop-panel'),
              decoration: BoxDecoration(
                color: shopTabFill(kit, shown.ink),
                // **AND THE BOTTOM CORNERS TURN.** The case was square at the
                // foot while every tile in it and every tab above it is
                // rounded; asked for from the couch. The TOP two stay square —
                // that edge is shared with the tabs, and a shared edge cannot
                // be rounded on one side only.
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(_tabRadius),
                ),
              ),
              child: _PanelFrame(
                ink: shown.ink,
                // **AND THE CASE IS FRAMED IN THE TAB'S OWN COLOUR.** Asked for
                // from the couch, naming all four: yellow for Special Offers,
                // then the blue, the green and the purple. The tab strip has
                // carried these since it was built and the panel under it was
                // neutral, so the one thing telling a player which shelf they
                // are looking at was the tab they had already stopped looking
                // at. `shown` is the selected tab, so the frame changes with it.
                //
                // **IN FRONT OF THE SCROLL, not behind it.** A `DecoratedBox`
                // paints its decoration BEHIND the child by default, so the
                // bottom edge ran under the list and a pack tile scrolled over
                // the top of it — reported from the couch with a shot of two
                // cards sitting on the purple. A frame is in front of what it
                // frames.
                //
                // **NO TOP EDGE**, for the same reason the top corners are
                // square: the tabs and the panel share that edge, and a line
                // drawn along it is the join coming apart — see above.
                child: SingleChildScrollView(
                  key: const ValueKey('shop-scroll'),
                  clipBehavior: Clip.hardEdge,
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
        ),
      ],
    );
  }
}

/// The frame round the case, in the selected tab's colour.
///
/// **In FRONT of the shelf, which is the whole reason it is a widget.** As a
/// `BoxDecoration` on the panel it painted BEHIND the scroll view — a
/// `DecoratedBox` does, by default — so the bottom edge ran under the list and
/// a pack tile scrolled straight over the top of it. Reported from the couch
/// with a shot of two cards sitting on the purple.
///
/// No top edge: the tabs and the panel share that one, and a line along it is
/// the join coming apart — see the note at the call site.
class _PanelFrame extends StatelessWidget {
  const _PanelFrame({required this.ink, required this.child});

  final Color ink;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final edge = BorderSide(
      color: shopFrameInk(Theme.of(context).extension<KitTheme>()!, ink),
      width: shopFrameWidth,
    );
    const corners = BorderRadius.vertical(
      bottom: Radius.circular(_tabRadius),
    );
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: corners,
        border: Border(left: edge, right: edge, bottom: edge),
      ),
      // Clipped to the same corners, or a tile scrolling past the foot squares
      // off the two the case just grew.
      child: ClipRRect(borderRadius: corners, child: child),
    );
  }
}

/// The tab's top corners, and the weight of the accent along its top edge.
const double _tabRadius = 12;
const double _tabAccent = 3;

/// One tab's face: fill, accent and edge, all cut by the SAME shape.
///
/// A `BoxDecoration` cannot draw this. It rounds only the top corners, which it
/// can; but its border is `Border.all` or nothing once there is a radius, so the
/// bottom edge — the one that has to be OPEN into the panel — is drawn too, and
/// anything laid on top of it has to be clipped by a second `ClipRRect` whose
/// box is its own rather than the tab's. Both of those were faults on screen;
/// see the note at the call site.
/// **PUBLIC so a test can read the face it paints.** The tab used to be a
/// `DecoratedBox` and three tests reach for one inside the strip; a
/// `BoxDecoration` cannot draw this shape — see the note below — so what they
/// have to ask instead is the painter what colours it was given.
class ShopTabFace extends CustomPainter {
  const ShopTabFace({
    required this.fill,
    required this.edge,
    required this.accent,
    required this.radius,
    required this.raised,
  });

  final Color fill;
  final Color edge;

  /// The band along the top, or null on a tab that is not open.
  final Color? accent;
  final double radius;
  final bool raised;

  Path _shape(Size size) => Path()
    ..addRRect(
      RRect.fromRectAndCorners(
        Offset.zero & size,
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
      ),
    );

  @override
  void paint(Canvas canvas, Size size) {
    final shape = _shape(size);
    if (raised) {
      canvas.drawPath(
        shape.shift(const Offset(0, -1)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    canvas.drawPath(shape, Paint()..color = fill);
    if (accent case final band?) {
      canvas.save();
      canvas.clipPath(shape);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, _tabAccent),
        Paint()..color = band,
      );
      canvas.restore();
    }
    // Up one side, over the top, down the other. The half-pixel keeps a
    // one-point stroke inside the shape rather than straddling it.
    final w = size.width;
    final h = size.height;
    final r = radius;
    canvas.drawPath(
      Path()
        ..moveTo(0.5, h)
        ..lineTo(0.5, r)
        ..arcToPoint(Offset(r, 0.5), radius: Radius.circular(r - 0.5))
        ..lineTo(w - r, 0.5)
        ..arcToPoint(Offset(w - 0.5, r), radius: Radius.circular(r - 0.5))
        ..lineTo(w - 0.5, h),
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(ShopTabFace old) =>
      old.fill != fill ||
      old.edge != edge ||
      old.accent != accent ||
      old.radius != radius ||
      old.raised != raised;
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
/// How thick the case is framed, in the selected tab's colour.
///
/// One point, not two: at phone scale two reads as a slab round the shelf
/// rather than as a frame on it. Shared with the tab strip's baseline, which
/// is the same line carried across the tabs that are shut.
const double shopFrameWidth = 1;

/// The open tab's face, and the case's ground — one colour, because they are
/// one surface. See the note at the panel.
Color shopTabFill(KitTheme kit, Color ink) =>
    Color.alphaBlend(ink.withValues(alpha: 0.16), shopPanelInk(kit));

/// **ONE LINE ALL THE WAY ROUND.** The case's frame was full-strength ink while
/// the tab's own edge and the baseline under the shut ones were the same ink at
/// 55%, so the border changed shade exactly where the tabs meet the panel —
/// the join those alphas exist to hide.
///
/// **AND THE ALPHA WAS THE SECOND HALF OF IT.** 55% of one colour over three
/// different grounds is three colours: the tab's edge sits on the page, the
/// baseline on the strip, the frame on the case. Reported from the couch twice,
/// the second time after the first fix — the sides and the bottom still not
/// matching the top. Blended ONCE here, so every call site gets an OPAQUE
/// colour that cannot pick up what is behind it.
Color shopFrameInk(KitTheme kit, Color ink) =>
    Color.alphaBlend(ink.withValues(alpha: 0.55), shopPanelInk(kit));

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
    // **THE BASELINE UNDER THE SHUT TABS IS THE FRAME'S OWN LINE.** It was a
    // muted grey while the case below it is framed in the tab's colour, so the
    // frame stopped dead at the two ends of the strip. Asked for from the
    // couch: the tab bar's bottom border keeps that same colour. Knocked back,
    // because a shut tab is not the open one — same line, quieter.
    final rule = shopFrameInk(kit, shopTabs[selected].ink);
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
                    // **ONE PATH DRAWS THE WHOLE TAB, and that is what fixes
                    // the two things a `BoxDecoration` could not.**
                    //
                    // The accent was a 3pt bar in its own `ClipRRect` at the
                    // tab's radius — but an `RRect` scales radii down to fit
                    // the box it is given, and that box is three points tall,
                    // so the bar's corners came out at 3 against the tab's 12
                    // and its square ends stood proud of the rounded corner
                    // underneath. Reported from the couch as the top border not
                    // respecting the radius of the tab below it.
                    //
                    // And `Border.all` is the only border a rounded
                    // `BoxDecoration` can have, so the selected tab's edge was
                    // drawn along its BOTTOM as well — a hairline straight
                    // across the mouth of the panel, which is the one thing the
                    // broken baseline exists to avoid. The stroke here is an
                    // open path: up one side, over the top, down the other, and
                    // it stops.
                    CustomPaint(
                      painter: ShopTabFace(
                        fill: i == selected
                            ? shopTabFill(kit, tab.ink)
                            : kit.surface,
                        // An unselected tab is a container too. It had a
                        // TRANSPARENT border, so the three that are not open
                        // were flat blocks of surface with no edge on them.
                        edge: i == selected
                            ? shopFrameInk(kit, tab.ink)
                            : kit.border,
                        accent: i == selected ? tab.ink : null,
                        radius: _tabRadius,
                        // The selected tab stands proud of the two beside it,
                        // so it casts on them.
                        raised: i == selected,
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
                              fontSize: 12,
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
