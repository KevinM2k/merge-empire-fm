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
///   full-width call to action that used to sit under the match card.
///
/// The burger's dot is the OR of every tile's inside it, so nothing that used
/// to nag from the scene goes quiet just because it moved one tap deeper.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart' show coachAlert;
import 'package:merge_empire_fc/ui/popups/quick_nav_menu.dart';
import 'package:merge_empire_fc/ui/screens/home/coach_bubble.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_customiser.dart';
import 'package:merge_empire_fc/ui/shell/shell_quick_nav.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';

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
          width: 54,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 54,
                    height: 54,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              if (dot)
                Positioned(right: -3, top: -4, child: _Nag(dotKey: dotKey)),
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
      child: const ArtImage(
        path: 'assets/ui/manager_hint.png',
        fallback: Center(child: Text('🧢', style: TextStyle(fontSize: 26))),
      ),
    );
  }
}

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
      onTap: () =>
          showQuickNavMenu(context, groups: quickNavGroups(context, ref)),
      child: const Icon(Icons.menu, size: 24),
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
              Text(
                t('league.customise_label'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  height: 1,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Something in here wants attention.
///
/// A RED EXCLAMATION, and it bounces. It was a flat accent-coloured dot, which
/// on a green kit is a green pip on a green pitch — the one mark on this screen
/// whose entire job is to be noticed, in the one colour that cannot be. Red is
/// not the club's to choose, and a mark that moves is seen without being looked
/// for.
class _Nag extends StatefulWidget {
  const _Nag({this.dotKey});

  final Key? dotKey;

  @override
  State<_Nag> createState() => _NagState();
}

class _NagState extends State<_Nag> with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  void _sync() {
    // A badge that never stops moving is exactly what reduce-motion is asking
    // us not to run. It stays — red on its own still reads — it just holds
    // still.
    if (MediaQuery.of(context).disableAnimations) {
      if (_bounce.isAnimating) _bounce.stop();
      return;
    }
    if (!_bounce.isAnimating) _bounce.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bounce,
      builder: (context, child) {
        // Two hops and a rest, rather than a sine that never settles: a badge
        // bobbing continuously reads as a loading spinner.
        final phase = (_bounce.value * 2).clamp(0.0, 1.0);
        final hop = math.sin(phase * math.pi * 2).clamp(0.0, 1.0) * 4;
        return Transform.translate(offset: Offset(0, -hop), child: child);
      },
      child: Container(
        key: widget.dotKey,
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: coachAlert,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          '!',
          style: TextStyle(
            fontSize: 12,
            height: 1,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
