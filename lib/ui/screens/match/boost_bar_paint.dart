/// What says a lift is LIVE: the bands on the progress bar, the glow round the
/// figures, and the one-at-a-time caption under them.
///
/// **The bar already means time**, so a window is a segment of it — the player
/// sees when it started and when it ends in the one control that already says
/// how far in the match is. Flame for Roar, a grey wash for Bus: the visual
/// opposite, for the boost that is the tactical opposite.
///
/// **Nothing here changes SIZE while animating.** A widget that grows every
/// frame relayouts past any `RepaintBoundary` to the route and repaints the
/// whole shell — the HUD coin count-up has already cost this once. The glow
/// moves opacity and colour inside a fixed box; the pill fades; the bands are
/// positioned once per minute, not per frame.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/engine/match_boost_state.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// The fire the Roar burns in. Not kit colours and deliberately not: a flame
/// is a flame whatever the club wears, the way the level metals on the trait
/// reel are bronze, silver and gold on every kit.
const Color flameHot = Color(0xFFFFE08A);
const Color flameMid = Color(0xFFFF8A3D);
const Color flameDeep = Color(0xFFD9481C);

/// The windows laid over the bar, each across its own minute range.
class BoostBands extends StatelessWidget {
  const BoostBands({
    super.key,
    required this.windows,
    required this.glow,
  });

  final List<LiveBoost> windows;

  /// The shared pulse, or null when nothing should move.
  final Animation<double>? glow;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        return Stack(
          children: [
            for (final b in windows)
              Positioned(
                // The bar is `minute / 90`, so the bands are too — stoppage
                // runs off the end the way the clock's own fill does.
                left: w * (b.fromMinute / 90).clamp(0.0, 1.0),
                width: w *
                    ((b.toMinute - b.fromMinute) / 90).clamp(
                      0.0,
                      1.0 - (b.fromMinute / 90).clamp(0.0, 1.0),
                    ),
                top: 0,
                bottom: 0,
                child: _Band(
                  key: ValueKey('match-boost-band-${b.id}'),
                  flame: b.id == 'crowd_roar',
                  glow: glow,
                  wash: kit.textMuted,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Band extends StatelessWidget {
  const _Band({
    super.key,
    required this.flame,
    required this.glow,
    required this.wash,
  });

  final bool flame;
  final Animation<double>? glow;
  final Color wash;

  @override
  Widget build(BuildContext context) {
    if (!flame) {
      return DecoratedBox(
        decoration: BoxDecoration(color: wash.withValues(alpha: 0.7)),
      );
    }
    final anim = glow;
    if (anim == null) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [flameDeep, flameMid, flameHot]),
        ),
      );
    }
    // The shimmer slides the gradient's stops, not the box: same size every
    // frame, only the paint moves.
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final t = anim.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: const [flameDeep, flameMid, flameHot, flameMid, flameDeep],
              stops: [0, 0.25 + 0.2 * t, 0.5 + 0.2 * t, 0.75 + 0.1 * t, 1],
            ),
          ),
        );
      },
    );
  }
}

/// A soft pulse round the figures while anything temporary lifts the side.
///
/// Opacity only. The box the child sits in does not change size, so the
/// scoreboard's layout is untouched by the pulse.
class LiveGlow extends StatelessWidget {
  const LiveGlow({
    super.key,
    required this.on,
    required this.glow,
    required this.child,
  });

  final bool on;
  final Animation<double>? glow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!on) return child;
    final kit = Theme.of(context).extension<KitTheme>()!;
    final anim = glow;
    Widget halo(double t) => DecoratedBox(
      key: const ValueKey('match-live-glow'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: kit.accentBright.withValues(alpha: 0.18 + 0.22 * t),
            blurRadius: 14 + 6 * t,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
    if (anim == null) return halo(0.5);
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => halo(anim.value),
    );
  }
}

/// The caption naming what just changed — `🔄 Super Sub`, `📣 Crowd Roar`.
///
/// **One, transient, and only on a CHANGE.** Five lifts can hold at once and
/// five captions is not a board; the glow carries the persistent state and
/// this explains the moment, then fades. The box reserves its height whether
/// or not a caption is up, so its arrival and departure move nothing.
class LiveSourcePill extends StatelessWidget {
  const LiveSourcePill({super.key, required this.text});

  /// Null when nothing has just changed.
  final String? text;

  static const double height = 18;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return SizedBox(
      height: height,
      child: AnimatedOpacity(
        opacity: text == null ? 0 : 1,
        duration: const Duration(milliseconds: 220),
        child: text == null
            ? const SizedBox.shrink()
            : Center(
                child: Container(
                  key: const ValueKey('match-live-source-pill'),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: kit.accent.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    text!,
                    key: const ValueKey('match-live-source-pill-text'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                      color: kit.accentBright,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
