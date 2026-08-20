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

/// √2 — what it takes for a square image's own inscribed circle to cover the
/// badge's circle rather than the other way round.
const double _fillCircle = 1.4143;

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
      // **THE CIRCLE GOVERNS THE IMAGE, so the image has to be SCALED UP.**
      //
      // The artwork is a 512×512 painting with an opaque grey background and the
      // subject inside its own soft glow disc. Contained in a circular badge that
      // leaves the four grey corners showing through — which is exactly what "a
      // square in a circle" looks like, and no amount of insetting fixes it,
      // because the inset makes the trophy smaller and leaves MORE grey.
      //
      // Scaling by √2 maps the badge's circle onto the image's own inscribed
      // circle, so the corners are cropped away entirely and what is left is the
      // glow disc filling the badge. It costs the outer 15% of each edge, which
      // on every one of these paintings is background.
      inner = Transform.scale(
        scale: _fillCircle,
        child: ArtImage(
          path: achievementArtPath(id),
          fit: BoxFit.cover,
          fallback: Center(
            child: Text(
              getAchievementDef(id)?.icon ?? '🏅',
              style: TextStyle(fontSize: emojiSize, height: 1),
            ),
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
      child: inner,
    );
  }
}
