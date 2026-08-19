/// Turns a kit id into a `ThemeData`. The only place a palette string becomes a
/// `Color` — the derivation itself stays Flutter-free in `util/kit_theme.dart`.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/data/card_theme.dart';
import 'package:merge_empire_fc/data/kit_palette.dart';
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

Decoration _backgroundFor(String kitId, KitSurfaces s) {
  // Only two of the six kits are stripes; the rest are smooth gradients.
  final stripes = kitPatterns[kitId]?.stripes;
  if (stripes != null) {
    final width = kitId == 'humbug' ? 28.0 : 24.0;
    return StripeDecoration(
      dark: cssColor(stripes.$1),
      light: cssColor(stripes.$2),
      darkWidth: width,
      lightWidth: width,
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

ThemeData buildAppTheme({required String kitId, required bool light}) {
  final s = buildKitSurfaces(kitId: kitId, light: light);
  final kit = KitTheme(
    bg: cssColor(s.bg),
    surface: cssColor(s.surface),
    surface2: cssColor(s.surface2),
    border: cssColor(s.border),
    textMuted: cssColor(s.textMuted),
    accent: cssColor(s.accent),
    accentBright: cssColor(s.accentBright),
    accentBrightInk: cssColor(s.accentBrightInk),
    accentInk: cssColor(s.accentInk),
    background: _backgroundFor(kitId, s),
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
  );
}
