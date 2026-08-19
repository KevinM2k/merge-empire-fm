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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/popups/quick_nav_menu.dart';
import 'package:merge_empire_fc/ui/screens/home/coach_bubble.dart';
import 'package:merge_empire_fc/ui/shell/shell_quick_nav.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';

/// A dock orb: a 54px disc with its label riding up over the bottom edge.
class DockButton extends StatelessWidget {
  const DockButton({
    required this.label,
    required this.onTap,
    required this.child,
    this.dot = false,
    this.dotKey,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  /// Something inside wants attention.
  final bool dot;

  /// Names the dot, so a test can ask whether this particular orb is nagging.
  final Key? dotKey;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
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
                      color: kit.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kit.border),
                    ),
                    child: Center(child: child),
                  ),
                  // Rides UP over the disc's bottom edge, which is why the dock
                  // spaces its buttons more generously than a caption would
                  // need.
                  Transform.translate(
                    offset: const Offset(0, -6),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kit.textMuted,
                        shadows: const [
                          Shadow(blurRadius: 2, color: Colors.black87),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (dot)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    key: dotKey,
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: kit.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: kit.bg, width: 2),
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

/// Coach Colin, bottom left.
class CoachDock extends ConsumerWidget {
  const CoachDock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(coachHasUnreadProvider);
    return DockButton(
      key: const ValueKey('dock-coach'),
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
