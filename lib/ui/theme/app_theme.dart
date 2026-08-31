/// Turns a kit id into a `ThemeData`. The only place a palette string becomes a
/// `Color` — the derivation itself stays Flutter-free in `util/kit_theme.dart`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
import 'package:merge_empire_fc/data/card_theme.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/theme/stripe_painter.dart';
import 'package:merge_empire_fc/util/kit_theme.dart';

export 'package:merge_empire_fc/ui/theme/stripe_painter.dart';

/// A tier's card body, as a Flutter gradient.
///
/// CSS measures its angle clockwise from "to top" and Flutter takes two points.
/// 160deg and 135deg are the only two the catalogue uses and both read as a
/// top-left to bottom-right sweep, so one alignment pair covers it. Shared
/// because the merge grid's card and the Player Index's draw the same body and
/// a second copy is a second thing to get wrong.
LinearGradient tierBodyGradient(TierGradient g) => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [for (final stop in g.stops) cssColor(stop.$1)],
  stops: [for (final stop in g.stops) stop.$2 / 100],
);

final RegExp _hsl = RegExp(r'^hsl\(\s*(-?\d+)\s*,\s*(\d+)%\s*,\s*(\d+)%\s*\)$');

/// Parse the three forms the palette emits: `#rgb`, `#rrggbb` and `hsl()`.
///
/// Never throws. The value traces back to the save, and a theme that throws is a
/// white screen on launch.
Color cssColor(String value) {
  final v = value.trim();
  if (v.startsWith('#')) {
    final digits = v.substring(1);
    final full = digits.length == 3
        ? digits.split('').map((c) => '$c$c').join()
        : digits;
    final parsed = int.tryParse(full, radix: 16);
    if (parsed != null && full.length == 6) return Color(0xFF000000 | parsed);
    return const Color(0xFF000000);
  }
  final m = _hsl.firstMatch(v);
  if (m != null) {
    return cssColor(
      hslToHex(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      ),
    );
  }
  return const Color(0xFF000000);
}

/// The two striped kits' PAGE background — `TURF_BACKGROUND` and
/// `HUMBUG_BACKGROUND` in `kitTheme.js`, as a band pair and a band width.
///
/// **This is NOT the shirt's pair, and the port was using the shirt's.**
/// `kitPatterns` carries humbug as `#111111` / `#f0f0f0` and says in its own
/// comment why: "the app CHROME cannot use true black and white — white body
/// text sits directly on it, which is why the theme pairs near-black with a mid
/// slate — but a shirt carries no text, so the kit itself gets the real
/// humbug". This function reached for that pair anyway, so every screen in the
/// game stood on fourteen bands of true black and true white with body copy
/// over them. Reported as too many stripes, too hard to see and needing to be
/// softer, which is three readings of the one fault.
///
/// The WIDTHS were already the spec's and stay: at `#0e0e0e` against `#3a3a3a`
/// the count stops being something the eye has to fight, so widening the bands
/// as well would be treating the symptom twice.
const Map<String, ({String a, String b, double width})> _stripesDark = {
  'turf': (a: '#1f4f21', b: '#2a6d2d', width: 24),
  'humbug': (a: '#0e0e0e', b: '#3a3a3a', width: 28),
};

/// `TURF_BACKGROUND_LIGHT` / `HUMBUG_BACKGROUND_LIGHT` — the same geometry
/// paled up so the texture still reads on a light page.
///
/// **The port had no light variant at all**, so a light-mode humbug drew dark
/// body text over true-black bands and a light-mode turf drew it over forest
/// green. Both are one lookup, and both were unreadable.
const Map<String, ({String a, String b, double width})> _stripesLight = {
  'turf': (a: '#9fcda1', b: '#b6dfb8', width: 24),
  'humbug': (a: '#e4e4e4', b: '#b4b4b4', width: 28),
};

Decoration _backgroundFor(String kitId, KitSurfaces s, bool light) {
  // Only two of the six kits are stripes; the rest are smooth gradients.
  //
  // Turf's second layer — a 45° hatch of `rgba(255,255,255,0.03)` every 8px,
  // the mow lines — is NOT ported. `StripeDecoration` paints one axis, and at
  // 3% on a dark green it is below what the screenshots resolve; it is here as
  // a known gap rather than a forgotten one.
  final stripes = (light ? _stripesLight : _stripesDark)[kitId];
  if (stripes != null) {
    return StripeDecoration(
      dark: cssColor(stripes.a),
      light: cssColor(stripes.b),
      darkWidth: stripes.width,
      lightWidth: stripes.width,
    );
  }
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [cssColor(s.bg), cssColor(s.surface), cssColor(s.bg)],
    ),
  );
}

/// **THE CLUB'S COLOUR, AS THE PLAYER PICKED IT.**
///
/// `KitSurfaces.accentBright` is the JS's own `hsl(h,60%,36%)` in light and
/// `hsl(h,90%,70%)` in dark — a hue re-derived at a fixed saturation and
/// lightness. It is what `kit_theme_reference.json` compares and it stays
/// exactly as it is; what changes is what the SCREEN reads, which is the
/// divergence this repo puts on the screen rather than in the harness.
///
/// The re-derivation is why a chosen `#4CAF50` printed as `#25932A`: two thirds
/// of a kit's identity is its saturation and its lightness, and both were being
/// thrown away and replaced with a constant. Reported directly — the accents
/// are darker, or just not quite the colour that was chosen.
///
/// So the answer is the accent ITSELF, moved only when it cannot be read on the
/// ground it stands on, and only as far as that takes. A kit that is already
/// legible is left completely alone, which is most of them.
String uiAccentBright(String accentHex, {required bool light}) {
  final hsl = hexToHsl(accentHex);
  final ground = light ? lightPaneHex : darkPaneHex;
  var l = hsl.l;
  // Sixteen steps of three points is the whole range, and it stops the moment
  // the colour clears the bar — a mid-tone moves a little, a bad pairing moves
  // a lot, and nothing moves that did not have to.
  for (var i = 0; i < 24; i++) {
    final ratio = contrastRatio(
      relLuminance(hslToHex(hsl.h, hsl.s, l)),
      relLuminance(ground),
    );
    if (ratio >= uiAccentMinContrast(light: light)) break;
    l = light ? math.max(0, l - 3) : math.min(100, l + 3);
  }
  return hslToHex(hsl.h, hsl.s, l);
}

/// What a club colour has to clear against the surface it is printed on.
///
/// **The small-text bar in daylight and the large-text one at night**, which is
/// not an inconsistency: an accent in light mode is nearly always INK — a club
/// name, a heading, a label — where 4.5 is the rule the whole app's light sweep
/// enforces, and `glassAccent` would only take it there anyway one ramp later.
/// In dark mode it is as often a FILL as an ink, the ground gives it far more
/// room, and holding it to 4.5 would bleach a club's colour toward white for no
/// legibility gained.
double uiAccentMinContrast({required bool light}) => light ? 4.5 : 3.0;

/// The two grounds an accent is printed on: the light theme's card stack and
/// the dark theme's. Measured against the surface rather than the page, because
/// an accent is nearly always on a panel.
const String lightPaneHex = '#eef0f3';
const String darkPaneHex = '#151a15';

ThemeData buildAppTheme({required String kitId, required bool light}) {
  final s = buildKitSurfaces(kitId: kitId, light: light);
  final kit = KitTheme(
    bg: cssColor(s.bg),
    surface: cssColor(s.surface),
    surface2: cssColor(s.surface2),
    border: cssColor(s.border),
    textMuted: cssColor(s.textMuted),
    accent: cssColor(s.accent),
    accentBright: cssColor(uiAccentBright(s.accent, light: light)),
    accentBrightInk: cssColor(
      inkFor(uiAccentBright(s.accent, light: light)),
    ),
    accentInk: cssColor(s.accentInk),
    background: _backgroundFor(kitId, s, light),
  );
  final brightness = light ? Brightness.light : Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: kit.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kit.accent,
      brightness: brightness,
    ),
    extensions: [kit],
    // **EVERY BUTTON WEARS THE SHOP'S FACE.** Reported as the shop's controls
    // being moulded and nothing else in the app being — see
    // [mouldedButtonStyle]. Set here so it reaches all eighty-odd Material
    // buttons without eighty-odd edits, and so a new one is moulded by
    // default rather than by remembering.
    //
    // `TextButton` is deliberately left alone: it is a text link — "Maybe
    // later", "Load", "Export" — and a moulded face on one would make the
    // cancel look like the action.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: mouldedButtonStyle(
        face: kit.accent,
        edge: Color.alphaBlend(Colors.black.withValues(alpha: 0.45), kit.accent),
        ink: kit.accentInk,
        dead: kit.surface2,
        deadInk: kit.textMuted,
        border: kit.border,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: mouldedButtonStyle(
        face: kit.accent,
        edge: Color.alphaBlend(Colors.black.withValues(alpha: 0.45), kit.accent),
        ink: kit.accentInk,
        dead: kit.surface2,
        deadInk: kit.textMuted,
        border: kit.border,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: mouldedButtonStyle(
        face: kit.accent,
        edge: kit.border,
        ink: kit.accent,
        dead: kit.surface2,
        deadInk: kit.textMuted,
        border: kit.border,
        outline: true,
      ),
    ),
  );
}
