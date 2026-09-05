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
import 'package:merge_empire_fc/engine/guide_engine.dart';
import 'package:merge_empire_fc/providers/bus_providers.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/energy_sheet.dart';
import 'package:merge_empire_fc/ui/hud/coin_flight.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart';
import 'package:merge_empire_fc/ui/screens/club/club_screen.dart';
import 'package:merge_empire_fc/ui/screens/grid/merge_grid.dart';
import 'package:merge_empire_fc/ui/screens/home/home_screen.dart';
import 'package:merge_empire_fc/ui/screens/settings_screen.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_screen.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_screen.dart';
import 'package:merge_empire_fc/ui/screens/transfers/transfer_offer_card.dart'
    show TransferPill;
import 'package:merge_empire_fc/ui/shell/screen_covered.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/shell/shell_routes.dart';
import 'package:merge_empire_fc/ui/shell/tab_bar.dart';
import 'package:merge_empire_fc/ui/shell/coach_floating.dart';
import 'package:merge_empire_fc/ui/shell/coach_tip_host.dart';
import 'package:merge_empire_fc/ui/shell/guide.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/entrance.dart';

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
class AppShellState extends ConsumerState<AppShell> {
  ShellTab _active = defaultTab;

  /// How many times each tab has been brought to the front. Handed down as
  /// [TabEntrance], so a page can replay its arrival on every open rather
  /// than once per process — `IndexedStack` never remounts it.
  final Map<ShellTab, int> _opened = {defaultTab: 1};
  final Map<ShellTab, DateTime> _openedAt = {defaultTab: DateTime.now()};

  /// The card-reveal overlay dims the whole screen and sits UNDER the HUD, so
  /// an unhidden HUD punches through its dim. The JS flags the body element for
  /// the same reason.
  bool _revealActive = false;

  @override
  void initState() {
    super.initState();
    // The engines emit navigation onto the bus; this is the only thing that
    // listens for it.
    attachShellBusListeners(ref.read(shellControllerProvider.notifier));
  }

  @override
  void dispose() {
    detachShellBusListeners();
    super.dispose();
  }

  /// Every route into the shell goes through the controller, so there is one
  /// answer to "which tab" rather than two racing.
  ///
  /// **BUT THE TAP APPLIES ON THE TAP.** It used to only write the controller
  /// and wait for the `ref.listen` in `build` to hand it back, which is a whole
  /// frame in the best case: Riverpod's listener fires DURING the rebuild that
  /// observes the change and `_applyTab` calls `setState` from inside that
  /// build. Applying first and telling the controller second is not two
  /// answers racing: the listener's call is a no-op by the time it arrives,
  /// because `_applyTab` returns early on the tab it is already on.
  ///
  /// [noSlide] is the controller's own flag and means nothing here now: no tab
  /// slides. See `_applyTab`.
  void goTab(ShellTab tab, {bool noSlide = false}) {
    _applyTab(tab);
    ref.read(shellControllerProvider.notifier).goTab(tab, noSlide: noSlide);
  }

  /// **NO SLIDE.** The page opens on the tap. The 220ms slide drew the diorama
  /// at a fractional offset and Impeller rastered every frame of it at 40-50ms.
  void _applyTab(ShellTab tab) {
    // The home screen used to have sub-tabs, so tapping Home had to reset it to
    // Overview — "take me home", and last week's table is not home. It has no
    // sub-tabs now: the table and the fixtures are quick-nav sheets and close
    // over the screen rather than replacing it, so there is nothing left to
    // reset and the rule holds by construction.
    if (tab == _active) return;
    setState(() {
      _active = tab;
      _opened[tab] = (_opened[tab] ?? 0) + 1;
      _openedAt[tab] = DateTime.now();
    });
    // **Opening a tab is knowing where it is.** The tour's "head to the Players
    // tab" is spent the moment the Players tab is in front — see
    // `guide_engine.dart`. After the frame: this can be reached from a
    // listener firing mid-build, and the update moves the save revision.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final game = ref.read(gameProvider);
      if (!guideActive(game.state)) return;
      game.update((s) => guideTabOpened(s, guideTabOf(tab)));
    });
  }

  @override
  Widget build(BuildContext context) {
    // Navigation that came from anywhere but the tab bar — a deep link, a bus
    // event — arrives here.
    ref.listen(shellControllerProvider, (_, next) {
      _applyTab(next.tab);
    });
    final covered = ref.watch(screenIsCoveredProvider);
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
    // The tour's "tap Scout to sign somebody": a card landing on the grid is
    // the player having done it. Spent for good.
    ref.listen(busEventProvider('card:placed'), (_, _) {
      final game = ref.read(gameProvider);
      if (!guideActive(game.state)) return;
      game.update((s) => markGuideDone(s, 'scout'));
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
        // **ON PLAY, THE DIORAMA RUNS UNDER THE TAB BAR.** Everywhere else the
        // bar is a surface with content scrolling up to it; on Play the page is
        // a pitch, and a band of chrome across the foot of it was reported as
        // jarringly bright against the grass. `extendBody` plus a bar with no
        // decoration of its own is the same answer the top HUD has always given
        // — see `Hud.build` and `ShellTabBar.build`. The body's own
        // `MediaQuery` carries the bar's height, so the footer's `SafeArea`
        // clears it without anything here being told how tall it is.
        // Constant: flipping it per tab re-laid out all five tabs on every switch.
        extendBody: true,
        body: Stack(
          children: [
            // FULL BLEED. The ground and anything a screen paints over it run to
            // the top of the glass; the notch is cleared by the CONTENT (see
            // `hudClearanceOf`) rather than by a SafeArea around the lot. Wrapped,
            // the home screen's diorama stopped at the notch and left a bar of
            // page colour above it.
            Container(
              // **PLAY GETS A FLAT GROUND, not the kit's pattern.** The diorama
              // covers the page there, so the backdrop is only ever seen for the
              // length of a swipe — and on a pattern kit that meant the turf
              // stripes ran to the top of the screen for half a second and then
              // vanished as the pitch landed on them, while sliding to Squad
              // showed no such thing. Reported directly: there is no turf to be
              // seen on Play, so it should not be there at all.
              decoration: _active == ShellTab.home
                  ? BoxDecoration(color: kit.bg)
                  : kit.background,
              // **NO SWIPE BETWEEN TABS.** A horizontal drag anywhere on the
              // page changed tab, and every tab in this game is something you
              // drag on — a card across the grid, a player onto the pitch, a
              // filter strip sideways. So an intercepted or slightly diagonal
              // drag threw the player onto a different screen. Reported from
              // the couch: it happens by accident, and the five buttons in the
              // bar are what people use anyway. And no slide either — see
              // `_applyTab`.
              child: SizedBox.expand(
                    // **ONE LAYER FOR THE BODY.** The coach's pulse ring and
                    // the HUD live in the same Stack; without this every beat
                    // of the ring repainted the whole tab under it.
                    child: RepaintBoundary(
                      child: IndexedStack(
                        index: tabOrder.indexOf(_active),
                        children: [
                          for (final tab in tabOrder)
                            TickerMode(
                              // **AND OFF WHILE SOMETHING OPAQUE IS OVER IT.** An
                              // offscreen tab has never been given frames; the
                              // COVERED one was, because a modal bottom sheet is
                              // a `PopupRoute` and nothing tells the route beneath
                              // it that it has stopped being looked at. On the
                              // home tab that is a pitch scene, weather, a ball
                              // and a walking manager, all animating behind a
                              // sheet nobody can see through — which is the
                              // "second animated screen" the customiser's lag was
                              // reported as. See `screen_covered.dart`.
                              enabled: tab == _active && !covered,
                              // **"You have just opened this" — see
                              // `entrance.dart`.** The pieces of the page under
                              // it drop into place every time the number moves.
                              child: TabEntrance(
                                generation: _opened[tab] ?? 0,
                                openedAt: _openedAt[tab],
                                // The inset `extendBody` used to give them, per tab.
                                child: SafeArea(
                                top: false,
                                left: false,
                                right: false,
                                bottom: tab != ShellTab.home,
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
                              ),
                            ),
                        ],
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
                child: RepaintBoundary(child: CoachFloating(tab: _active)),
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
            // **THE WAY BACK TO A PARKED BID.** Above the tab bar so it
            // follows the player across every tab — the offer is about the
            // squad, and the squad is three tabs from wherever it was parked.
            // Under the coin flight, which is the layer nothing shares.
            const Positioned(
              key: ValueKey('transfer-pill-layer'),
              left: 0,
              right: 0,
              bottom: 0,
              child: TransferPill(),
            ),
            // **ABOVE THE GLASS.** A coin flying to the counter that passes
            // UNDER the HUD disappears a third of the way through the throw,
            // which reads as the animation being broken rather than as money
            // arriving.
            //
            // **AND ITS CLOCK IS ITS OWN, which is why nothing is needed here.**
            // A Navigator mutes `TickerMode` for everything under the topmost
            // route, so a reward paid from inside a mini-game or a shop sheet
            // used to put a sprite up in the middle of the screen and leave it
            // there, frozen at the start of its arc, until the route was
            // popped. `CoinFlight` provides its own unmuted tickers — a
            // `TickerMode` wrapped round this mounting would NOT have worked,
            // because `TickerMode` composes with its ancestors. See its note.
            const Positioned.fill(
              key: ValueKey('coin-flight-layer'),
              child: CoinFlight(),
            ),
          ],
        ),
        bottomNavigationBar: ShellTabBar(
          active: _active,
          onTap: (tab) => goTab(tab),
          // The tour's finger on the bar: the tab its current step is sending
          // the player to. Off the moment they get there.
          highlight: ref.watch(guideHighlightProvider),
        ),
      ),
    );
  }
}
