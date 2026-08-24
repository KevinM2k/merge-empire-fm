/// What navigation MEANS, in one place.
///
/// The engines emit onto the event bus and may not import Flutter, so the bus
/// stays the transport. What this adds is a typed front door: a screen calls
/// `goTab` or `deepLinkShop` rather than hand-rolling an event name, and the bus
/// listeners here are the only code that has to know the strings.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';
import 'package:merge_empire_fc/util/analytics.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

/// The three screens that present over a tab rather than replacing it.
enum ShellSheet {
  trophies(0.75),
  playerIndex(0.92),
  leaderboard(0.92);

  const ShellSheet(this.heightFraction);

  /// Fraction of the screen height. The JS writes these as `75vh` / `92vh`.
  final double heightFraction;
}

/// Where a shop deep link lands.
enum ShopSection { coins, gems }

class ShellState {
  const ShellState({
    required this.tab,
    this.noSlide = false,
    this.pendingShopSection,
  });

  final ShellTab tab;

  /// True when this move came from a deep link, which also scrolls the incoming
  /// screen to a section — so it must arrive without a transition.
  final bool noSlide;

  /// Consumed once by the Shop screen when it opens.
  final ShopSection? pendingShopSection;

  ShellState copyWith({
    ShellTab? tab,
    bool? noSlide,
    ShopSection? pendingShopSection,
    bool clearPending = false,
  }) {
    return ShellState(
      tab: tab ?? this.tab,
      noSlide: noSlide ?? this.noSlide,
      pendingShopSection: clearPending
          ? null
          : (pendingShopSection ?? this.pendingShopSection),
    );
  }
}

final shellControllerProvider = NotifierProvider<ShellController, ShellState>(
  ShellController.new,
);

class ShellController extends Notifier<ShellState> {
  @override
  ShellState build() => const ShellState(tab: defaultTab);

  /// [noSlide] is for a move that should arrive already in place — a deep link,
  /// or anything that scrolls the incoming screen the moment it opens.
  void goTab(ShellTab tab, {bool noSlide = false}) {
    // **THE SCREEN DIMENSION IS SENT BY HAND, or it is empty.** A Flutter app
    // is one Activity, so the automatic screen name is `(not set)` for every
    // session — and that dimension is the one that says where people are when
    // they stop playing. The JS says the same thing about its WebView.
    if (state.tab != tab) logScreen(tab.name);
    state = ShellState(tab: tab, noSlide: noSlide);
  }

  /// The HUD's coin `+` and gem chip. Arrives with no slide, carrying the
  /// section the Shop should scroll to.
  void deepLinkShop(ShopSection section) {
    state = ShellState(
      tab: ShellTab.shop,
      noSlide: true,
      pendingShopSection: section,
    );
  }

  /// Called by the Shop once it has scrolled, so a later rebuild does not
  /// scroll again.
  void consumePendingShopSection() {
    if (state.pendingShopSection == null) return;
    state = state.copyWith(clearPending: true);
  }
}

/// The bus events the JS navigates with. Grep the engines before adding one.
Map<String, BusHandler>? _attached;

void attachShellBusListeners(ShellController controller) {
  detachShellBusListeners();
  final handlers = <String, BusHandler>{
    'nav:tab-squad': (_) => controller.goTab(ShellTab.squad),
    'nav:shop-coins': (_) => controller.deepLinkShop(ShopSection.coins),
    'nav:shop-gems': (_) => controller.deepLinkShop(ShopSection.gems),
  };
  handlers.forEach(on);
  _attached = handlers;
}

void detachShellBusListeners() {
  _attached?.forEach(off);
  _attached = null;
}
