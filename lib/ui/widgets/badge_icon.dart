/// The circular badge, ported from `ui/badgeIcon.js`.
///
/// One widget rather than three, for the reason the JS gives: the HUD, the
/// Trophy Room and the Leaderboard all draw a badge id, and a badge that
/// rendered differently depending on which screen you were looking at would
/// read as a different badge.
///
/// The default badge has no artwork at all and is drawn from a ball emoji — it
/// is not an achievement, so there is no tile to reuse.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/data/achievements.dart';
import 'package:merge_empire_fc/data/art_paths.dart';
import 'package:merge_empire_fc/engine/badge_engine.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';

class BadgeIcon extends StatelessWidget {
  const BadgeIcon({required this.badgeId, this.size = 22, super.key});

  final String? badgeId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final id = badgeId;
    final emojiSize = size * 0.55;

    final Widget inner;
    if (id == null || id.isEmpty || id == defaultBadgeId) {
      inner = Center(
        child: Text('⚽', style: TextStyle(fontSize: emojiSize, height: 1)),
      );
    } else {
      inner = ArtImage(
        path: achievementArtPath(id),
        // **CONTAIN, not cover.** The artwork is square and the badge is a
        // circle, so covering crops every corner — which on a trophy is its
        // handles, its plinth and the top of the cup. It read as an icon
        // slightly clipped on all four sides, because it was.
        fit: BoxFit.contain,
        fallback: Center(
          child: Text(
            getAchievementDef(id)?.icon ?? '🏅',
            style: TextStyle(fontSize: emojiSize, height: 1),
          ),
        ),
      );
    }

    return Container(
      key: ValueKey('badge-icon-${id ?? defaultBadgeId}'),
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: kit.surface2,
        shape: BoxShape.circle,
        border: Border.all(color: kit.border),
      ),
      // Inset, so the art sits INSIDE the rim rather than under it. Without it
      // a contained square touches the circle at four points and the border
      // reads as broken there.
      child: Padding(padding: EdgeInsets.all(size * 0.08), child: inner),
    );
  }
}
