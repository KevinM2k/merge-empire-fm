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
/// **AND THE TINT CAN GO MUCH LOWER THAN IT LOOKS LIKE IT CAN**, which is the
/// part that kept being got wrong by eye. Worked out properly rather than
/// guessed: contrast is a ratio of RELATIVE LUMINANCE, not of the linear grey
/// values it is tempting to compare. The app's light ink `#191d17` has a relative
/// luminance of 0.012, so anything it sits on needs 0.23 to clear 4.5:1 — which
/// is a mid-grey. The daylit sky is already past that on its own. The pane's tint
/// is therefore doing nothing for legibility at all in light mode, and it is free
/// to be as thin as it looks best at.
///
/// So these are set by EYE, with the arithmetic only as a floor, and the things
/// that make a quarter-opacity pane read as glass are the four below it: the
/// blur, the saturation lift, the specular rim and the drop shadow.
/// How much pane a surface gets.
///
/// **A SMALL PANE NEEDS MORE TINT THAN A BIG ONE, and that is not a contradiction
/// of the note above.** The floor is set by what has to be READ on it: a card
/// carrying 14px near-black ink clears 4.5:1 on the bare sky, so it can be a
/// quarter opacity and look like glass. A HUD chip carries a 13px figure in the
/// kit's accent — a mid-tone green, not near-black — at maybe forty pixels wide,
/// and on the same pane that is under 2:1. It was unreadable on the Play tab and
/// fine everywhere else, because everywhere else the chip is a near-opaque pill.
/// So a chip gets a denser pane. It covers so little of the scene that the cost
/// is nothing, and the alternative is a status bar you cannot read.
enum GlassDensity {
  /// Small, numerous, and carrying accent-coloured figures.
  chip,

  /// The default.
  panel,

  /// Tall enough to cross the sky's own gradient.
  deep,
}

const Color _darkA = Color(0x59141E2C);
const Color _darkB = Color(0x42090F18);

const Color _darkChipA = Color(0xAD141E2C);
const Color _darkChipB = Color(0x8F090F18);

const Color _darkDeepA = Color(0x6E141E2C);
const Color _darkDeepB = Color(0x54090F18);

/// The same stops in daylight.
const Color _lightA = Color(0x45FCFEFF);
const Color _lightB = Color(0x33E4EFF8);

const Color _lightChipA = Color(0xC4FCFEFF);
const Color _lightChipB = Color(0xADE4EFF8);

const Color _lightDeepA = Color(0x57FCFEFF);
const Color _lightDeepB = Color(0x42DCEAF5);

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
    this.density = GlassDensity.panel,
    this.blur = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// How much pane this surface gets — see [GlassDensity].
  final GlassDensity density;

  /// Off for anything small or numerous — the tint stands alone by design.
  final bool blur;

  bool get _deep => density == GlassDensity.deep;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    final night = nightSceneOf(context);
    final tints = switch ((night, density)) {
      (true, GlassDensity.chip) => const [_darkChipA, _darkChipB],
      (true, GlassDensity.panel) => const [_darkA, _darkB],
      (true, GlassDensity.deep) => const [_darkDeepA, _darkDeepB],
      (false, GlassDensity.chip) => const [_lightChipA, _lightChipB],
      (false, GlassDensity.panel) => const [_lightA, _lightB],
      (false, GlassDensity.deep) => const [_lightDeepA, _lightDeepB],
    };

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
            // At a quarter opacity the shadow is not decoration — it is the only
            // thing telling you the pane is IN FRONT of the scene rather than a
            // patch of it. Heavier in daylight, which sounds backwards and is
            // not: on a night sky the pane is darker than its backdrop and its
            // own edge separates it; in daylight it is brighter, and the shadow
            // is what lifts it off.
            color: Colors.black.withValues(alpha: night ? 0.34 : 0.30),
            blurRadius: _deep ? 26 : 18,
            offset: Offset(0, _deep ? 10 : 6),
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
