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
import 'package:merge_empire_fc/ui/screens/home/home_screen.dart';
import 'package:merge_empire_fc/ui/screens/settings_screen.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_screen.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_screen.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/shell/shell_routes.dart';
import 'package:merge_empire_fc/ui/shell/tab_bar.dart';
import 'package:merge_empire_fc/ui/shell/tab_transition.dart';
import 'package:merge_empire_fc/ui/shell/coach_floating.dart';
import 'package:merge_empire_fc/ui/shell/coach_tip_host.dart';
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
    // The home screen used to have sub-tabs, so tapping Home had to reset it to
    // Overview — "take me home", and last week's table is not home. It has no
    // sub-tabs now: the table and the fixtures are quick-nav sheets and close
    // over the screen rather than replacing it, so there is nothing left to
    // reset and the rule holds by construction.
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
    // **Colin's one-time tips**, watching for a milestone. It draws nothing —
    // when one lands it goes through `enqueuePopup` like every other popup, so a
    // lesson can never land on top of the welcome-back card's coins. Wrapped
    // around the whole shell rather than sat in the Stack because it needs the
    // tab and nothing else.
    return CoachTipHost(
      tab: _active,
      child: Scaffold(
        body: Stack(
          children: [
            // FULL BLEED. The ground and anything a screen paints over it run to
            // the top of the glass; the notch is cleared by the CONTENT (see
            // `hudClearanceOf`) rather than by a SafeArea around the lot. Wrapped,
            // the home screen's diorama stopped at the notch and left a bar of
            // page colour above it.
            Container(
              decoration: kit.background,
              child: SizedBox.expand(
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
                            child:
                                widget.screenFor?.call(tab) ??
                                switch (tab) {
                                  ShellTab.grid => const GridScreen(
                                    key: ValueKey('screen-grid'),
                                  ),
                                  ShellTab.squad => const SquadScreen(
                                    key: ValueKey('screen-squad'),
                                  ),
                                  ShellTab.home => const HomeScreen(
                                    key: ValueKey('screen-home'),
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
            // **Colin, on every tab.** Above the screens and below the HUD, inside
            // the body's `Stack` rather than in an overlay — which is what makes a
            // sheet or a dialog cover him by construction instead of by a
            // ref-counted "step aside" signal from every modal in the app. See
            // `coach_floating.dart`.
            Positioned.fill(
              key: const ValueKey('coach-layer'),
              child: Visibility(
                visible: !_revealActive,
                maintainState: true,
                child: CoachFloating(tab: _active),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              // NOT wrapped in a `SafeArea`: the HUD clears the notch itself, so
              // its glass can run to the top of the screen instead of starting
              // below it with the raw page showing above.
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
          ],
        ),
        bottomNavigationBar: ShellTabBar(
          active: _active,
          onTap: (tab) => goTab(tab),
        ),
      ),
    );
  }
}
