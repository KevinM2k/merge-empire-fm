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
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => ShopScreenState();
}

class ShopScreenState extends ConsumerState<ShopScreen> {
  final Map<ShopSectionId, GlobalKey> _anchors = {
    for (final id in shopSectionOrder) id: GlobalKey(),
  };

  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // The tab may be built by the very frame that set the deep link, so the
    // first scroll happens here rather than only on a later change.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToPending());
  }

  void _scrollToPending() {
    if (!mounted) return;
    final pending = ref.read(shellControllerProvider).pendingShopSection;
    if (pending == null) return;
    final id = switch (pending) {
      ShopSection.coins => ShopSectionId.coins,
      ShopSection.gems => ShopSectionId.gems,
    };
    final context = _anchors[id]?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(context, duration: Duration.zero);
      // `ensureVisible` puts the heading at the top of the VIEWPORT, and the top
      // of the viewport is under the floating HUD — so the one thing a deep link
      // was aimed at was the one thing behind the glass. Back off by the same
      // clearance the screen's own padding uses, plus the JS's own 8px.
      if (_scroll.hasClients) {
        _scroll.jumpTo(
          (_scroll.offset - hudClearanceOf(this.context) - 8).clamp(
            0.0,
            _scroll.position.maxScrollExtent,
          ),
        );
      }
    }
    // Consumed immediately, so a later rebuild does not scroll again.
    ref.read(shellControllerProvider.notifier).consumePendingShopSection();
  }

  Widget _section(ShopSectionId id, Widget child) =>
      KeyedSubtree(key: _anchors[id], child: child);

  @override
  Widget build(BuildContext context) {
    ref.listen(shellControllerProvider, (_, next) {
      if (next.pendingShopSection != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToPending());
      }
    });

    // Eager rather than a lazy ListView, and the deep link is why: scrolling to
    // Coins or Gems needs that section's context to exist, and a lazily built
    // list has not created one for a section still off screen. Seven sections of
    // about twenty tiles is well within what one pass can afford.
    return SingleChildScrollView(
      key: const ValueKey('shop-scroll'),
      controller: _scroll,
      // The Shop had NO padding at all: its first tile ran under the floating
      // HUD and its last under the tab bar. `hudClearance` is the shared figure
      // every screen uses; the bottom inset is the tab bar's own.
      padding: EdgeInsets.fromLTRB(12, hudClearanceOf(context), 12, 12),
      child: Column(
        children: [
          _section(ShopSectionId.offers, const OffersSection()),
          _section(ShopSectionId.free, const FreeShelfSection()),
          _section(ShopSectionId.gems, const GemPacksSection()),
          _section(ShopSectionId.coins, const CoinPacksSection()),
          _section(ShopSectionId.boosts, const BoostsSection()),
          _section(ShopSectionId.vouchers, const VouchersSection()),
          _section(ShopSectionId.looks, const LooksSection()),
          const RestoreRow(),
        ],
      ),
    );
  }
}
