/// The two orbs on the home screen. Ported from `_sceneOverlayHtml` in
/// `ui/screens/LeagueScreen.js`.
///
/// Ten orbs used to run up both sides of the diorama and the scene was carrying
/// more furniture than scene. Nine of them moved into the quick-nav menu, and
/// what is left out here is what INTERRUPTS:
///
/// - **Coach Colin, bottom left.** He keeps his own orb rather than moving into
///   the menu because he is the one thing here that TALKS TO YOU, and a tip you
///   have to go looking for is not advice, it is a screen.
/// - **The burger, bottom right**, with Prestige above it when it is available.
///   Prestige leads the column: a gold star with a dot, rather than the
///   full-width call to action that used to sit under the match card. See
///   `ui/popups/prestige_card.dart` for what it opens — the engine behind it
///   had no caller in `lib/` at all until that landed.
///
/// The burger's dot is the OR of every tile's inside it, so nothing that used
/// to nag from the scene goes quiet just because it moved one tap deeper.
library;


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart' show energyMaxProvider;
import 'package:merge_empire_fc/ui/popups/coach_card.dart'
    show CoachAlertBadge, CoachFace, coachAlertDotInset;
import 'package:merge_empire_fc/ui/popups/prestige_card.dart';
import 'package:merge_empire_fc/ui/popups/quick_nav_menu.dart';
import 'package:merge_empire_fc/ui/screens/home/coach_bubble.dart';
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart'
    show managerLookProvider;
import 'package:merge_empire_fc/ui/screens/home/manager_customiser.dart';
import 'package:merge_empire_fc/ui/shell/shell_quick_nav.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart' show cssColor;

/// A dock orb: a 54px disc with its label riding up over the bottom edge.
class DockButton extends StatelessWidget {
  const DockButton({
    required this.label,
    required this.onTap,
    required this.child,
    this.dot = false,
    this.dotKey,
    this.anchorKey,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  /// Something inside wants attention.
  final bool dot;

  /// Names the dot, so a test can ask whether this particular orb is nagging.
  final Key? dotKey;

  /// A handle on the orb's own box, for anything that has to sit beside it —
  /// Colin's bubble measures this rather than guessing at a corner offset.
  final GlobalKey? anchorKey;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          key: anchorKey,
          width: dockOrbSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: dockOrbSize,
                    height: dockOrbSize,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      // **A CIRCLE, like the floating coach's head.** These were
                      // rounded squares while the same coach on every other
                      // screen was a ringed disc — one control, two shapes,
                      // depending which tab you were on.
                      //
                      // A LIGHT rim rather than the theme's border, and rather
                      // than the accent the floating head can afford: these sit
                      // ON the diorama. In dark mode `border` is a near-black
                      // ring, which round Colin's portrait — art of a face on
                      // white — read as a black frame stuck to him.
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.32),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    // **The glyph is LIGHT, whatever the theme.** The disc is
                    // deliberately dark glass on the diorama — same reasoning as
                    // the rim above it — and the child was inheriting the app's
                    // own icon colour, which in dark mode is dark. The burger
                    // drew three black lines on a black orb.
                    child: Center(
                      child: IconTheme(
                        data: const IconThemeData(
                          color: Colors.white,
                          size: 24,
                        ),
                        child: DefaultTextStyle.merge(
                          style: const TextStyle(color: Colors.white),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                  // UNDER the disc, clear of it. It used to ride up over the
                  // bottom edge, which put the word across the picture it is
                  // labelling — and on a 54px orb that is most of the picture.
                  // On a DARK CAPSULE of its own. It was
                  // muted ink with a 2px shadow, which is a caption on a
                  // surface — and this one is not on a surface, it is over a
                  // lit green pitch that scrolls underneath it. Nothing that
                  // sits on moving ground can be read off contrast with the
                  // ground; it needs its own.
                  const SizedBox(height: 3),
                  Container(
                    // **A FIXED HEIGHT, so a scaled caption cannot move the
                    // orb.** The docks are bottom-aligned in their slots — see
                    // `home_screen.dart`'s rail — so the caption's height is
                    // what decides how high the disc above it sits, and
                    // `scaleDown` shrinks BOTH axes: "Coach" is wider than the
                    // 54 orb and came out 11.6 tall where "Menu" fits at 14.5,
                    // which dropped Colin three points below the burger. They
                    // were only ever level by every label happening to have the
                    // same line metrics; this makes it structural.
                    height: dockCaptionHeight,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    // **THE WORD GIVES, IT DOES NOT GET CUT OFF.** The orb is
                    // 54 and "Prestige" at 12/w800 is wider than that once the
                    // capsule's padding is paid for, so the caption came out as
                    // an ellipsis on the home page. Reported from the couch.
                    // `scaleDown` rather than a smaller font for every orb:
                    // "Menu" and "Coach" fit at 12 and keep it, and it is the
                    // page's own answer to a tight caption already — the
                    // fixture line and the next-match card both use it.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (dot)
                Positioned(
                  // On the orb's rim, not off its corner — see
                  // [coachAlertDotInset].
                  right: coachAlertDotInset(dockOrbSize),
                  top: coachAlertDotInset(dockOrbSize),
                  // Plain: a dot, not an exclamation mark. These orbs are on
                  // the page the player is already looking at — see
                  // [CoachAlertBadge.plain].
                  child: CoachAlertBadge(dotKey: dotKey, plain: true),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Coach Colin, bottom left.
class CoachDock extends ConsumerWidget {
  const CoachDock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(coachHasUnreadProvider);
    return DockButton(
      key: const ValueKey('dock-coach'),
      // The bubble measures this box to sit beside him.
      anchorKey: coachDockKey,
      dotKey: const ValueKey('coach-dot'),
      label: t('scene.dock.coach'),
      dot: unread,
      onTap: () => showCoachBubble(context, ref),
      // **IT IS A HEAD SHOT, and it is round** — and it is the same head shot
      // the floating coach on every other tab wears, which is what [CoachFace]
      // is for. This orb zoomed to his face and that one did not, so Colin was
      // a different man depending which tab you were on.
      child: const CoachFace(fallbackSize: 26),
    );
  }
}

/// Prestige, directly above the burger and only when it is available.
///
/// **A gold star with a dot, not a full-width call to action.** The JS used to
/// put "Start New Adventure" across the scene under the match card, which is a
/// banner for a thing that happens at most once a career and can be taken at
/// any time from then on — and it competed with the one button on this screen
/// that the player is here to press. As an orb it leads the right-hand column
/// and nags exactly as much as the burger does.
///
/// **It appears at all only after the Champions League is won**, which is what
/// `canPrestige` reads; on every save before that this builds nothing and the
/// column is the burger alone.
class PrestigeDock extends ConsumerWidget {
  const PrestigeDock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canPrestigeProvider)) return const SizedBox.shrink();
    return DockButton(
      key: const ValueKey('dock-prestige'),
      dotKey: const ValueKey('prestige-dot'),
      label: t('scene.dock.prestige'),
      // Always nagging while it is up: an unclaimed new adventure is the only
      // thing on this screen with nothing else to remind you of it, and the orb
      // goes the moment it is taken.
      dot: true,
      onTap: () => showPrestigeOffer(context, ref),
      // Gold rather than the kit's accent, and this is the one orb where that
      // is right: prestige is the only control on the dock that is not about
      // the club the palette is derived FROM.
      child: const Icon(Icons.star_rounded, size: 26, color: Color(0xFFFFC93C)),
    );
  }
}

/// The orb's diameter. The dot is placed off it — see [coachAlertDotInset].
const double dockOrbSize = 54;

/// The caption capsule's height — see the note in [DockButton].
///
/// The 12/w800 label lays out 14.5 tall and the capsule carried a point of
/// padding either side of it, so this is what the pill already measured, named
/// and rounded up a half so a descender has somewhere to go.
const double dockCaptionHeight = 17;

/// The burger, bottom right.
class MenuDock extends ConsumerWidget {
  const MenuDock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DockButton(
      key: const ValueKey('dock-menu'),
      dotKey: const ValueKey('quick-nav-badge'),
      label: t('scene.dock.menu'),
      dot: ref.watch(quickNavNeedsAttentionProvider),
      onTap: () {
        final state = ref.read(gameProvider).state;
        // The hand holding it is the manager's: his skin off his look.
        final look = ref.read(managerLookProvider) ?? const {};
        final skin = '${look['skin'] ?? ''}';
        showQuickNavMenu(
          context,
          // **The MENU's own `ref`, not this one.** The tiles are rebuilt
          // inside the route so a dot that goes out while the phone is open
          // goes out on screen — the sheets open over it and the phone is
          // still there when they close. `context` stays this one: the doors
          // are opened from the screen the phone was opened from.
          groups: (menuRef) => quickNavGroups(context, menuRef),
          // **The battery is the game's energy**, and read from the route for
          // the same reason the tiles are: a pip spent behind the phone left
          // it charged. `energyMaxProvider` rather than a second call to
          // `getEnergyMax` — the HUD's bolt reads the cap from that one.
          battery: (menuRef) {
            final max = menuRef.watch(energyMaxProvider);
            return max <= 0 ? 1 : menuRef.watch(energyProvider) / max;
          },
          clubName: '${state?['clubName'] ?? ''}',
          skin: skin.isEmpty ? null : cssColor(skin),
        );
      },
      // A handset, because that is what the button opens now — see
      // `quick_nav_menu.dart`. The label stays "Menu": it says what it is FOR.
      child: const Icon(Icons.smartphone, size: 24),
    );
  }
}

/// The CUSTOMISE pill, between the two orbs.
///
/// It is the manager's own control, so it sits under him rather than in the
/// burger — and it shares the dock's rail so the three read as ONE ROW of
/// controls. The JS makes a point of that: the docks and the badge both hang
/// off the footer's top edge at the same 12px lift, having once been anchored
/// two different ways and drifted apart the day the Deadline Day strip arrived.
///
/// [anchorKey] is how the walker finds it. He stands 12px above this pill, and
/// the home screen MEASURES that rather than restating the footer's arithmetic
/// a second time.
class CustomiseDock extends ConsumerWidget {
  const CustomiseDock({this.anchorKey, super.key});

  final GlobalKey? anchorKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: t('league.customise_avatar'),
      child: GestureDetector(
        key: const ValueKey('dock-customise'),
        onTap: () => showManagerCustomiser(context),
        child: Container(
          key: anchorKey,
          padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A shirt, then the word. The mark this replaced in the JS was a
              // pair of scissors, which read as "cut" rather than "dress him".
              Icon(
                Icons.checkroom,
                size: 12,
                color: Colors.white.withValues(alpha: 0.72),
              ),
              const SizedBox(width: 5),
              // Flexible: the pill is now inside a `Flexible` on the dock rail
              // — see `home_screen.dart` — so on a 320pt phone in German the
              // word gives rather than the row reporting an overflow.
              Flexible(
                child: Text(
                  t('league.customise_label'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    height: 1,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
