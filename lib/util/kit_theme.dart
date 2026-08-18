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
