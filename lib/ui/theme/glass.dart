/// Dark glass. Ported from `styles/glass.css`.
///
/// One recipe for every panel that floats over the Play diorama: the HUD's
/// resource chips and the next-match card.
///
/// **DARK IN BOTH THEMES, and that is the whole point of the file.** These
/// panels sit on a sky that runs daylight-blue to near-black, so a surface that
/// followed the app's theme was a pale card on a pale sky the moment anyone
/// turned light mode on — which is exactly what happened here: the chips were
/// `surface` at 85% and the card `surface` at 74%, and in light mode both went
/// white-on-white and disappeared. Fixed rgba, deliberately not theme tokens.
///
/// **THE TINT CARRIES LEGIBILITY, THE BLUR DOES NOT.** The blur is layered on
/// top as a bonus; every value here is set so the panel still reads with it
/// removed. The JS makes the same rule because `backdrop-filter` silently
/// no-ops on the Android WebViews it ships to — the reason survives the port
/// intact, because a blur is a backdrop snapshot and a blur pass per panel per
/// frame over a diorama that is already animating, and that is the first thing
/// to drop on a phone that cannot afford it.
///
/// **Going dark means the INK has to flip with it.** A panel is not just a
/// background — everything inside it is written for the surface it is on. So
/// the panel hands its subtree the DARK build of the player's own kit, and the
/// text, the muted captions and the accent inside come out of that rather than
/// out of the light theme the rest of the screen is using. Nothing inside needs
/// to know it is on glass.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

/// The dark build of whatever kit the player is wearing.
///
/// Watched rather than derived at each call site so a kit change repaints every
/// panel at once, and so the whole thing is one object to compare.
final glassThemeProvider = Provider<ThemeData>(
  (ref) => buildAppTheme(kitId: ref.watch(kitIdProvider), light: false),
);

/// The two tint stops. As thin as white 800-weight text survives with the blur
/// removed — the floor, not a starting point.
const Color _tintA = Color(0x8A141E2C);
const Color _tintB = Color(0x5C090F18);

/// A touch denser, for a panel big enough that the sky behind it varies across
/// its own height.
const Color _tintDeepA = Color(0xA3141E2C);
const Color _tintDeepB = Color(0x7A090F18);

/// Top-lit sheen: a bright band across the top third falling away to nothing,
/// plus a whisper of light caught on the bottom edge. This is what separates
/// glass from a translucent rectangle — it implies a light source and a
/// thickness.
const LinearGradient _sheen = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0x2EFFFFFF),
    Color(0x10FFFFFF),
    Color(0x00FFFFFF),
    Color(0x0DFFFFFF),
  ],
  stops: [0, 0.3, 0.58, 1],
);

/// CSS blur radius is about twice the Gaussian sigma, so the JS's 14px is 7
/// here.
const double _sigma = 7;

class GlassPanel extends ConsumerWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 16,
    this.padding = EdgeInsets.zero,
    this.deep = false,
    this.blur = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// A denser tint, for a panel tall enough to cross the sky's own gradient.
  final bool deep;

  /// Off for anything small or numerous — the tint stands alone by design.
  final bool blur;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shape = BorderRadius.circular(radius);
    final theme = ref.watch(glassThemeProvider);

    Widget panel = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          // The JS's 168deg: down the panel and a little across it.
          begin: const Alignment(-0.4, -1),
          end: const Alignment(0.4, 1),
          colors: deep
              ? const [_tintDeepA, _tintDeepB]
              : const [_tintA, _tintB],
        ),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: _sheen),
        child: Padding(
          padding: padding,
          // A `Theme` alone is NOT enough, and this is the trap: the ink most
          // text actually uses is `DefaultTextStyle`, which `Material` publishes
          // once from the theme in force where IT sits. Pushing a dark theme in
          // further down does not touch it — so every `Text` with no colour of
          // its own kept the light theme's near-black and came out black on dark
          // glass. The same goes for `IconTheme`.
          child: DefaultTextStyle.merge(
            style: TextStyle(color: theme.colorScheme.onSurface),
            child: IconTheme.merge(
              data: IconThemeData(color: theme.colorScheme.onSurface),
              child: child,
            ),
          ),
        ),
      ),
    );

    if (blur) {
      panel = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: _sigma, sigmaY: _sigma),
        child: panel,
      );
    }

    return Theme(
      data: theme,
      child: DecoratedBox(
        // OUTSIDE the clip, because a drop shadow is cast by the panel rather
        // than drawn on it.
        decoration: BoxDecoration(
          borderRadius: shape,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: deep ? 26 : 18,
              offset: Offset(0, deep ? 10 : 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: shape,
          child: Stack(
            children: [
              panel,
              // The edge and the two inner hairlines, over everything: they are
              // the thickness of the glass, so nothing inside may sit on top of
              // them.
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _GlassEdge(radius: radius)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The rim: one hairline round the whole edge, a brighter one catching the top
/// and a dark one under the bottom.
class _GlassEdge extends CustomPainter {
  const _GlassEdge({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.drawRRect(
      rect.deflate(0.5),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.save();
    canvas.clipRRect(rect);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 1),
      Paint()..color = Colors.white.withValues(alpha: 0.24),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 1, size.width, 1),
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassEdge old) => old.radius != radius;
}
