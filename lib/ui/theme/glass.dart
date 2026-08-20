/// Glass. Ported from `styles/glass.css`.
///
/// One recipe for every panel that floats over the Play diorama: the HUD's
/// resource chips and the next-match card.
///
/// **IT FOLLOWS THE THEME NOW, AND THAT IS THE WHOLE CHANGE.** It used to be
/// dark in both, because the sky was one fixed dusk-blue on a ten-minute
/// day→night clock and a panel that followed the theme was white-on-white the
/// moment light mode was on. The sky follows the theme instead — light mode is
/// daylight, dark mode is a floodlit night (`theme/sky.dart`) — so the backdrop
/// is KNOWN, and a light panel over a daylit sky is exactly what it always
/// should have been. Two consequences fell out of it: the panel no longer has to
/// flip its own ink, because the app's ink is already right for the surface it is
/// on, and `glassThemeProvider` — which existed only to hand a dark subtree the
/// dark build of the kit — is gone.
///
/// **THE TINT CARRIES LEGIBILITY, THE BLUR DOES NOT.** The blur is layered on
/// top as a bonus; every value here is set so the panel still reads with it
/// removed. The JS makes the same rule because `backdrop-filter` silently
/// no-ops on the Android WebViews it ships to — the reason survives the port
/// intact, because a blur is a backdrop snapshot and a blur pass per panel per
/// frame over a diorama that is already animating, and that is the first thing
/// to drop on a phone that cannot afford it.
///
/// **The light recipe is DENSER than the dark one, not a mirror of it.** A dark
/// panel hides a busy backdrop by swallowing it; a light one has to out-shine
/// it, and what is behind these panels is a bright sky with a crowd, hoardings
/// and mown stripes in it. Same reason the sheen and the rim invert rather than
/// keep their colours: a white hairline is the edge of dark glass and is
/// invisible on light, so light glass is edged in its own shadow instead.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/theme/sky.dart';

/// **LIQUID GLASS: THE BLUR DOES THE WORK, NOT THE TINT.**
///
/// This went the wrong way twice and it is worth writing down. A pane over a
/// bright sky at 78% read as a smear, so the next attempt pushed it most of the
/// way to opaque — which made it legible and made it a white BLOCK sitting on
/// the scene. Both were trying to solve it with the tint.
///
/// The tint is not what makes a pane readable over a busy backdrop. The BLUR is:
/// at a big enough sigma the crowd, the hoardings and the mown stripes stop
/// being detail and become one smooth wash, and ink only ever has to
/// out-contrast an average. So the tint comes right back down — half the sky
/// shows through — the sigma goes up nearly three times, and the pane gets the
/// two things that actually say glass: a SATURATION lift on what is behind it,
/// and a bright specular hairline along its top edge.
///
/// The arithmetic that has to hold: a 52% white pane over a sky at 0.58 luma
/// composites to about 0.80, and the app's own ink is 0.11 — 5.3:1, comfortably
/// past the 4.5:1 small text needs. That is the floor these values are set from,
/// and it is why they cannot go much lower without the blur becoming
/// load-bearing for legibility rather than for looks.
const Color _darkA = Color(0x8A141E2C);
const Color _darkB = Color(0x66090F18);

/// A touch denser, for a panel big enough that the sky behind it varies across
/// its own height.
const Color _darkDeepA = Color(0x9E141E2C);
const Color _darkDeepB = Color(0x7A090F18);

/// The same two stops in daylight.
const Color _lightA = Color(0x85FCFEFF);
const Color _lightB = Color(0x6BE4EFF8);

const Color _lightDeepA = Color(0x9EFCFEFF);
const Color _lightDeepB = Color(0x82DCEAF5);

/// How much the backdrop's colour is pushed under the pane.
///
/// Glass concentrates what is behind it. Without this a low-opacity pane just
/// looks like a dirty window — the lift is what makes the sky under it read as
/// something seen THROUGH glass rather than something the pane failed to cover.
const double _saturation = 1.4;

/// A saturation matrix at the standard luma weights, as a colour filter to run
/// INSIDE the backdrop blur.
ColorFilter _saturate(double s) {
  const lr = 0.213, lg = 0.715, lb = 0.072;
  final ir = (1 - s) * lr, ig = (1 - s) * lg, ib = (1 - s) * lb;
  return ColorFilter.matrix(<double>[
    ir + s, ig, ib, 0, 0, //
    ir, ig + s, ib, 0, 0, //
    ir, ig, ib + s, 0, 0, //
    0, 0, 0, 1, 0,
  ]);
}

/// Top-lit sheen: a bright band across the top third falling away to nothing,
/// plus a whisper of light caught on the bottom edge. This is what separates
/// glass from a translucent rectangle — it implies a light source and a
/// thickness.
const LinearGradient _darkSheen = LinearGradient(
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

/// On light glass the same white band is invisible, and pushed hard enough to
/// show it bleaches the pane. A breath of light on the top edge and almost
/// nothing else: at a low tint the thickness reads off the RIM, and a gradient
/// laid over a half-transparent pane only ever makes it muddier.
const LinearGradient _lightSheen = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0x30FFFFFF),
    Color(0x00FFFFFF),
    Color(0x00000000),
    Color(0x0A0F2A44),
  ],
  stops: [0, 0.3, 0.7, 1],
);

/// The blur, and it is deliberately far past the JS's.
///
/// The JS uses a 14px CSS radius — about sigma 7 — because `backdrop-filter`
/// silently no-ops on the Android WebViews it ships to, so it could never lean
/// on it. A Flutter `BackdropFilter` always works, so the blur can be the thing
/// that carries the pane and the tint can come down. At sigma 7 a half-opacity
/// pane shows the crowd as recognisable dots through the card; at 20 it is a
/// wash.
const double _sigma = 20;

/// The ink a pane's own FURNITURE is drawn in — the rules between bands, the
/// chip fills, the hairlines inside it.
///
/// Not white. On dark glass white at 6–15% is the whole vocabulary for
/// separating one band from the next; on a near-white pane it is nothing at all,
/// so every rule and every chip outline inside the card disappeared the moment
/// the pane followed the theme. Same alphas, inverted ink.
Color glassInk(BuildContext context) =>
    nightSceneOf(context) ? Colors.white : const Color(0xFF0F2A44);

class GlassPanel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    final night = nightSceneOf(context);
    final tints = night
        ? (deep ? const [_darkDeepA, _darkDeepB] : const [_darkA, _darkB])
        : (deep ? const [_lightDeepA, _lightDeepB] : const [_lightA, _lightB]);

    Widget panel = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          // The JS's 168deg: down the panel and a little across it.
          begin: const Alignment(-0.4, -1),
          end: const Alignment(0.4, 1),
          colors: tints,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: night ? _darkSheen : _lightSheen),
        child: Padding(padding: padding, child: child),
      ),
    );

    if (blur) {
      panel = BackdropFilter(
        // Saturate FIRST, then blur — the lift is meant to apply to the
        // backdrop's own colours, and doing it after would just tint a grey wash.
        filter: ui.ImageFilter.compose(
          outer: ui.ImageFilter.blur(sigmaX: _sigma, sigmaY: _sigma),
          inner: _saturate(_saturation),
        ),
        child: panel,
      );
    }

    return DecoratedBox(
      // OUTSIDE the clip, because a drop shadow is cast by the panel rather
      // than drawn on it.
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            // Heavier in daylight than the dark theme's, which sounds backwards
            // and is not: on a night sky the pane is darker than its backdrop
            // and its own edge separates it, while in daylight the pane is
            // BRIGHTER than the sky and the shadow is the only thing that lifts
            // it off. A light card with no shadow is a hole in the sky.
            color: Colors.black.withValues(alpha: night ? 0.3 : 0.26),
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
                child: CustomPaint(
                  painter: _GlassEdge(radius: radius, night: night),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The rim: one hairline round the whole edge, a brighter one catching the top
/// and a dark one under the bottom.
///
/// It inverts with the theme. On dark glass the rim is the light caught along
/// the edge; on light glass there is no light to catch, so the rim is the
/// shadow the pane's own thickness casts.
class _GlassEdge extends CustomPainter {
  const _GlassEdge({required this.radius, required this.night});

  final double radius;
  final bool night;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.drawRRect(
      rect.deflate(0.5),
      Paint()
        ..color = night
            ? Colors.white.withValues(alpha: 0.18)
            // Firmer than the dark rim: it is the edge of a bright pane against
            // a bright sky, and at the dark theme's 0.18 it vanished.
            : const Color(0xFF0F2A44).withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.save();
    canvas.clipRRect(rect);
    // The SPECULAR line: the one hard highlight on the pane, and at a low tint it
    // is most of what says the surface is glass rather than a hole in the scene.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 1.2),
      Paint()..color = Colors.white.withValues(alpha: night ? 0.34 : 0.72),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 1, size.width, 1),
      Paint()
        ..color = night
            ? Colors.black.withValues(alpha: 0.3)
            : const Color(0xFF0F2A44).withValues(alpha: 0.26),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassEdge old) =>
      old.radius != radius || old.night != night;
}
