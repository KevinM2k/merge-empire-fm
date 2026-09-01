/// The colour maths behind the kit theme. Ported from the pure half of
/// `../merge-empire-fc/src/utils/kitTheme.js`.
///
/// The other half of that file is a table of CSS custom properties written onto
/// `<html>` and `<body>` — six pattern kits and a derived palette for any hex
/// colour. It belongs to the theming layer here, not to a utility: Flutter has a
/// `ThemeData`, not custom properties, and deciding how a gradient background
/// becomes a widget is an M3 decision rather than a translation. What stays is
/// the arithmetic every one of those tables is built out of, which is also the
/// part with a bug history worth keeping.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/kit_palette.dart';

/// A colour as hue (0-360), saturation and lightness (both 0-100), rounded the
/// way the CSS the theme emits needs them.
typedef Hsl = ({int h, int s, int l});

int _channel(String hex, int start) =>
    int.parse(hex.substring(start, start + 2), radix: 16);

/// `#rrggbb` to HSL.
Hsl hexToHsl(String hex) {
  final r = _channel(hex, 1) / 255;
  final g = _channel(hex, 3) / 255;
  final b = _channel(hex, 5) / 255;
  final max = math.max(r, math.max(g, b));
  final min = math.min(r, math.min(g, b));
  var h = 0.0;
  var s = 0.0;
  final l = (max + min) / 2;
  if (max != min) {
    final d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    if (max == r) {
      h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
    } else if (max == g) {
      h = ((b - r) / d + 2) / 6;
    } else {
      h = ((r - g) / d + 4) / 6;
    }
  }
  return (h: (h * 360).round(), s: (s * 100).round(), l: (l * 100).round());
}

/// HSL back to `#rrggbb`.
String hslToHex(num h, num s, num l) {
  final sat = s / 100;
  final lig = l / 100;
  final a = sat * math.min(lig, 1 - lig);
  String f(int n) {
    final k = (n + h / 30) % 12;
    final colour = lig - a * math.max(math.min(k - 3, math.min(9 - k, 1)), -1);
    return (255 * colour).round().toRadixString(16).padLeft(2, '0');
  }

  return '#${f(0)}${f(8)}${f(4)}';
}

double _srgbToLinear(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

/// The WCAG relative luminance of a `#rrggbb` colour, 0 for black to 1 for
/// white.
double relLuminance(String hex) {
  final r = _srgbToLinear(_channel(hex, 1) / 255);
  final g = _srgbToLinear(_channel(hex, 3) / 255);
  final b = _srgbToLinear(_channel(hex, 5) / 255);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrastRatio(double a, double b) {
  final hi = a > b ? a : b;
  final lo = a > b ? b : a;
  return (hi + 0.05) / (lo + 0.05);
}

const String inkDark = '#111111';
const String inkLight = '#ffffff';

/// Below this white-on-accent contrast ratio, white stops being readable and the
/// ink flips to dark.
///
/// NOT a straight "whichever contrasts more" test. Dark ink wins that comparison
/// on most mid-tone accents — the default green scores 6.8 against black but
/// only 2.8 against white — which would repaint every filled button, the HUD bar
/// and the tab bar in black text and throw away the white-on-accent look the
/// game is built around. White is the house style; the job here is only to catch
/// the kits where it genuinely disappears.
///
/// 2.2 sits in the clear space between the two cases: green lands at 2.78 and
/// keeps white, yellow at 1.40 and flips to black. Orange, at about 2.16, also
/// flips, which is right — white on orange is the same mush as white on yellow.
const double whiteInkMinContrast = 2.2;

/// The ink to print on [hex]: white, unless white is genuinely unreadable.
///
/// This used to be `lightness > 62 ? black : white`, which is wrong in a way
/// that only shows up on some hues. HSL lightness is not perceived brightness:
/// pure yellow sits at 50% L — the same as a mid green — but reflects far more
/// light. The old test gave it WHITE ink, so a yellow kit rendered white text on
/// a yellow button and a yellow HUD bar, which is to say invisible.
String inkFor(String hex) {
  final white = contrastRatio(relLuminance(hex), relLuminance(inkLight));
  return white >= whiteInkMinContrast ? inkLight : inkDark;
}

/// The saturation the surface ramp is built from: the kit's own, held inside a
/// band so a grey kit still has some colour in its chrome and a neon one does
/// not glow through every panel.
int kitSaturation(int s) => math.max(20, math.min(s, 80));

/// The hue rotation applied to the art, in degrees.
///
/// Measured from the default green's hue, wrapped to the shortest way round, so
/// a kit two hues away never rotates the long way.
int kitHueRotate(int h) => ((h - 123) % 360 + 540) % 360 - 180;

/// The fixed rotation each pattern kit uses instead of a derived one.
const Map<String, int> patternHueRotate = {
  'turf': 0,
  'humbug': 180,
  'sunset': 30,
  'midnight': -90,
  'empire': -120,
  'void': 150,
};

/// One kit's derived surfaces, as CSS colour strings.
///
/// Values are kept in the form the JS emits them — `#rrggbb`, `#rgb`, or
/// `hsl(h,s%,l%)` — rather than normalised, so the fixture comparison is
/// byte-exact and no conversion sits between the two runtimes. Turning these
/// into `Color`s is `lib/ui/theme/`'s job and nowhere else's.
class KitSurfaces {
  const KitSurfaces({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.textMuted,
    required this.accent,
    required this.accentBright,
    required this.accentBrightInk,
    required this.accentInk,
    required this.hueRotate,
  });

  final String bg;
  final String surface;
  final String surface2;
  final String border;
  final String textMuted;
  final String accent;
  final String accentBright;
  final String accentBrightInk;
  final String accentInk;

  /// Degrees the kit art is rotated by.
  final int hueRotate;
}

/// The accent each pattern kit paints its LIGHT theme from. Dark is a separate
/// story — five of the six are fixed tables, and only turf derives.
const Map<String, String> _patternLightAccent = {
  'turf': '#2e7d32',
  'humbug': '#d32f2f',
  'sunset': '#e64a19',
  'midnight': '#3355ee',
  'empire': '#0099cc',
  'void': '#7733cc',
};

/// **Light mode takes the kit too, the same way dark mode does.**
///
/// It was one neutral card stack for every club — white page, grey boxes — with
/// only the accent moving, while the dark theme has always leaned the club's
/// way. So a light-mode Everton and a light-mode Liverpool were the same screen
/// with a different button on it. Asked for in exactly those terms: the inverse
/// of what dark mode does.
///
/// It IS [_darkFrom]'s ramp read from the other end. The lightnesses are the
/// neutrals they replace — 100, 94.7, 90.4, 83.7, and 39 for muted text — so
/// nothing tuned against a light grey shifts underfoot; what is new is the hue,
/// on the same saturation ladder. A tint at 95% lightness is a whisper, which is
/// the point: the page reads as the club's rather than as coloured.
const String _lightTextMuted = '#5b616b';

KitSurfaces _lightFrom(String accentHex, int hueRotate) {
  final hsl = hexToHsl(accentHex);
  final h = hsl.h;
  final sat = kitSaturation(hsl.s);
  return KitSurfaces(
    bg: 'hsl($h,$sat%,99%)',
    surface: 'hsl($h,${(sat * 0.75).round()}%,95%)',
    surface2: 'hsl($h,${(sat * 0.65).round()}%,90%)',
    border: 'hsl($h,${(sat * 0.55).round()}%,84%)',
    // **The muted ink stays NEUTRAL, and it is the one value that has to.** Hue
    // is not free at a fixed lightness: green weighs 0.7152 of the luminance
    // sum, so a green-tinted grey at the same 39% is measurably brighter than
    // this and lands under 3:1 on the pale panels — which is what
    // `light_mode_contrast_test` caught on the match screen and the full-time
    // report. The boxes take the club; the small grey text does not.
    textMuted: _lightTextMuted,
    accent: accentHex,
    accentBright: 'hsl(${hsl.h},60%,36%)',
    accentBrightInk: inkFor(hslToHex(hsl.h, 60, 36)),
    accentInk: inkFor(accentHex),
    hueRotate: hueRotate,
  );
}

/// The dark theme for a derived kit — turf, and any club colour.
///
/// Turf differs from a club colour in two places, both because it sits on a
/// green stripe texture rather than a flat near-black: its muted text is paler
/// and less saturated, and its ink is fixed rather than measured.
///
/// For a club colour the CHOICE of `accentInk` goes through [inkFor], where the
/// JS kept an older `lightness > 55` test that hands white ink to a yellow or a
/// cyan accent — invisible text on the button. The JS's own light path already
/// calls [inkFor] and its comment says why. See "Fixed in the port rather than
/// carried" in docs/REMAINING.md.
///
/// The two INKS stay the JS's own, so a kit it already got right does not shift
/// shade. Only which of the two is picked changes.
KitSurfaces _darkFrom(
  String accentHex,
  int hueRotate, {
  double mutedSat = 0.4,
  int mutedLightness = 55,
  String? ink,
}) {
  final hsl = hexToHsl(accentHex);
  final h = hsl.h;
  final sat = kitSaturation(hsl.s);
  return KitSurfaces(
    bg: 'hsl($h,$sat%,7%)',
    surface: 'hsl($h,${(sat * 0.75).round()}%,12%)',
    surface2: 'hsl($h,${(sat * 0.65).round()}%,16%)',
    border: 'hsl($h,${(sat * 0.55).round()}%,22%)',
    textMuted: 'hsl($h,${(sat * mutedSat).round()}%,$mutedLightness%)',
    accent: accentHex,
    accentBright: 'hsl($h,90%,70%)',
    accentBrightInk: '#0d0d0d',
    accentInk: ink ?? (inkFor(accentHex) == inkDark ? darkModeInkDark : inkLight),
    hueRotate: hueRotate,
  );
}

/// The near-black this branch of the JS prints on a pale accent. Not [inkDark] —
/// the two differ by three values and only this one belongs to the dark theme.
const String darkModeInkDark = '#0d0d0d';

/// The five pattern kits whose dark theme is a hand-picked table rather than a
/// derivation. Transcribed from the branches of `applyKitColor`.
const Map<String, KitSurfaces> _patternDark = {
  'humbug': KitSurfaces(
    bg: '#111',
    surface: '#1a1a1a',
    surface2: '#222',
    border: '#3a3a3a',
    textMuted: '#d0d0d0',
    accent: '#d32f2f',
    accentBright: '#ff5c5c',
    accentBrightInk: '#0d0d0d',
    accentInk: '#ffffff',
    hueRotate: 180,
  ),
  'sunset': KitSurfaces(
    bg: '#1a0800',
    surface: '#2a1008',
    surface2: '#3a1a0c',
    border: '#5a2a14',
    textMuted: '#d4956a',
    accent: '#ff6b35',
    accentBright: '#ffb347',
    accentBrightInk: '#0d0d0d',
    accentInk: '#0d0d0d',
    hueRotate: 30,
  ),
  'midnight': KitSurfaces(
    bg: '#03030f',
    surface: '#08081e',
    surface2: '#0e0e2c',
    border: '#1a1a44',
    textMuted: '#7070b0',
    accent: '#4466ff',
    accentBright: '#88aaff',
    accentBrightInk: '#0d0d0d',
    accentInk: '#ffffff',
    hueRotate: -90,
  ),
  'empire': KitSurfaces(
    bg: '#001418',
    surface: '#001e24',
    surface2: '#002830',
    border: '#00404e',
    textMuted: '#4aa8c0',
    accent: '#00c8ff',
    accentBright: '#7ee8fa',
    accentBrightInk: '#0d0d0d',
    accentInk: '#001418',
    hueRotate: -120,
  ),
  'void': KitSurfaces(
    bg: '#030006',
    surface: '#09000f',
    surface2: '#100018',
    border: '#220030',
    textMuted: '#7a50a0',
    accent: '#9933ff',
    accentBright: '#cc88ff',
    accentBrightInk: '#0d0d0d',
    accentInk: '#ffffff',
    hueRotate: 150,
  ),
};

/// Turf is the one pattern kit whose dark theme derives rather than tabulates.
const String _turfGreen = '#2e7d32';

/// The palette for a kit id — one of the six pattern names, or a `#rrggbb`.
///
/// Anything unrecognised lands on the default green rather than throwing: the id
/// comes off the save, so a future build's kit must not brick an older one.
KitSurfaces buildKitSurfaces({required String kitId, required bool light}) {
  final patternAccent = _patternLightAccent[kitId];
  final known = patternAccent != null || kitId.startsWith('#');
  final hueRotate = patternHueRotate[kitId];

  if (light) {
    final accent = patternAccent ?? (known ? kitId : defaultKitColor);
    return _lightFrom(accent, hueRotate ?? kitHueRotate(hexToHsl(accent).h));
  }

  final table = _patternDark[kitId];
  if (table != null) return table;
  if (kitId == 'turf') {
    return _darkFrom(
      _turfGreen,
      hueRotate ?? 0,
      mutedSat: 0.3,
      mutedLightness: 82,
      ink: inkLight,
    );
  }
  final accent = known ? kitId : defaultKitColor;
  return _darkFrom(accent, kitHueRotate(hexToHsl(accent).h));
}
