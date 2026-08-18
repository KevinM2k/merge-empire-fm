/// The five-tab shell.
///
/// `IndexedStack` keeps every tab alive so a switch does not throw away scroll
/// position, and `TickerMode` on the offscreen children stops them animating.
/// That pair is the whole of what `screenFreeze.js` hand-builds in the JS —
/// there, a hidden screen keeps running its CSS animations and starves whatever
/// is on top of it, so the code adds a class that restyles ~1,150 elements and
/// schedules it through `requestIdleCallback` to hide the cost.
///
/// The swipe has no exclusion list either. The JS carries
/// `SWIPE_NAV_EXCLUDE_SELECTOR`, a `card-dragging` body class and
/// `preventDefault` calls to arbitrate between a tab swipe and a card drag;
/// Flutter's gesture arena is what all of that was hand-building, and a card's
/// own recogniser wins it without being told to.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/providers/bus_providers.dart';
import 'package:merge_empire_fc/ui/popups/energy_sheet.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart';
import 'package:merge_empire_fc/ui/screens/club/club_screen.dart';
import 'package:merge_empire_fc/ui/screens/grid/merge_grid.dart';
import 'package:merge_empire_fc/ui/screens/league/league_screen.dart';
import 'package:merge_empire_fc/ui/screens/settings_screen.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_screen.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_screen.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/shell/shell_routes.dart';
import 'package:merge_empire_fc/ui/shell/tab_bar.dart';
import 'package:merge_empire_fc/ui/shell/tab_transition.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, this.screenFor});

  /// Test seam: what to put in each tab.
  ///
  /// The shell's own tests are about the stack, the tickers and the
  /// transitions, not about any screen — and pinning them to whichever tab
  /// happened to still be a placeholder meant they broke every time a real
  /// screen landed. They pass placeholders for all five instead.
  final Widget Function(ShellTab tab)? screenFor;

  @override
  ConsumerState<AppShell> createState() => AppShellState();
}

/// Public so a test can drive [goTab] directly, the same seam Flutter's own
/// ScaffoldState exposes. Production navigation goes through
/// [shellControllerProvider], which this watches.
class AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  ShellTab _active = defaultTab;
  EnterMode _enter = EnterMode.none;

  /// Lets a tap on the Play tab reach the League screen's sub-tabs.
  final GlobalKey<LeagueScreenState> _leagueKey = GlobalKey();

  /// The card-reveal overlay dims the whole screen and sits UNDER the HUD, so
  /// an unhidden HUD punches through its dim. The JS flags the body element for
  /// the same reason.
  bool _revealActive = false;

  late final AnimationController _slide;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(vsync: this, duration: tabSlideDuration);
    // The engines emit navigation onto the bus; this is the only thing that
    // listens for it.
    attachShellBusListeners(ref.read(shellControllerProvider.notifier));
  }

  @override
  void dispose() {
    detachShellBusListeners();
    _slide.dispose();
    super.dispose();
  }

  /// Every route into the shell goes through the controller, so there is one
  /// answer to "which tab, and did it slide" rather than two racing.
  void goTab(ShellTab tab, {bool noSlide = false}) =>
      ref.read(shellControllerProvider.notifier).goTab(tab, noSlide: noSlide);

  void _applyTab(ShellTab tab, {required bool noSlide}) {
    // Tapping Play always lands on Overview, even when the player was last on
    // the table. Tapping Play is "take me home", and last week's table is not
    // home. Done even when Play is ALREADY the tab, which is the case the JS
    // rule is really about.
    if (tab == ShellTab.league) _leagueKey.currentState?.resetToOverview();
    if (tab == _active) return;
    final mode = enterModeFor(from: _active, to: tab, noSlide: noSlide);
    setState(() {
      _active = tab;
      _enter = mode;
    });
    if (mode == EnterMode.none) {
      _slide.value = 1;
    } else {
      _slide.forward(from: 0);
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity == 0) return;
    final idx = tabOrder.indexOf(_active);
    // No wrap at the ends: the bar has a first and a last tab, and a swipe past
    // either should do nothing rather than teleport across the app.
    final next = velocity < 0 ? idx + 1 : idx - 1;
    if (next < 0 || next >= tabOrder.length) return;
    goTab(tabOrder[next]);
  }

  Offset get _beginOffset => switch (_enter) {
    EnterMode.fromRight => const Offset(1, 0),
    EnterMode.fromLeft => const Offset(-1, 0),
    EnterMode.fromBelow => const Offset(0, 1),
    EnterMode.none => Offset.zero,
  };

  @override
  Widget build(BuildContext context) {
    // Navigation that came from anywhere but the tab bar — a deep link, a bus
    // event — arrives here.
    ref.listen(shellControllerProvider, (_, next) {
      _applyTab(next.tab, noSlide: next.noSlide);
    });
    // The HUD's energy + asks for this rather than opening it, so the button
    // stays a button and the shell owns what a route means.
    ref.listen(busEventProvider('nav:energy'), (_, _) {
      showEnergySheet(context, ref);
    });
    ref.listen(busEventProvider('reveal:start'), (_, _) {
      if (!_revealActive) setState(() => _revealActive = true);
    });
    ref.listen(busEventProvider('reveal:end'), (_, _) {
      if (_revealActive) setState(() => _revealActive = false);
    });
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: kit.background,
            child: SafeArea(
              bottom: false,
              child: GestureDetector(
                onHorizontalDragEnd: _onDragEnd,
                child: SlideTransition(
                  key: const ValueKey('tab-slide'),
                  position:
                      Tween<Offset>(
                        begin: _beginOffset,
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _slide,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                  child: IndexedStack(
                    index: tabOrder.indexOf(_active),
                    children: [
                      for (final tab in tabOrder)
                        TickerMode(
                          enabled: tab == _active,
                          // Exhaustive over ShellTab: every tab has a real
                          // screen now, so there is no fallback left to write.
                          child: widget.screenFor?.call(tab) ??
                              switch (tab) {
                                ShellTab.grid => const GridScreen(
                                  key: ValueKey('screen-grid'),
                                ),
                                ShellTab.squad => const SquadScreen(
                                  key: ValueKey('screen-squad'),
                                ),
                                ShellTab.league => LeagueScreen(
                                  key: _leagueKey,
                                ),
                                ShellTab.club => const ClubScreen(
                                  key: ValueKey('screen-club'),
                                ),
                                ShellTab.shop => const ShopScreen(
                                  key: ValueKey('screen-shop'),
                                ),
                              },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Visibility(
                key: const ValueKey('hud-layer'),
                visible: !_revealActive,
                maintainState: true,
                child: Hud(
                  onSettings: () =>
                      openRoute<void>(context, const SettingsScreen()),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: ShellTabBar(
        active: _active,
        onTap: (tab) => goTab(tab),
      ),
    );
  }
}
