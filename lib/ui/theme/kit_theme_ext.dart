/// The kit palette, carried through the widget tree.
///
/// `ThemeData` has no slot for "the border colour a card uses" or "the ink that
/// reads on a filled accent", so the derived palette rides along as an extension
/// and screens read it with `Theme.of(context).extension<KitTheme>()!`.
library;

import 'package:flutter/material.dart';

class KitTheme extends ThemeExtension<KitTheme> {
  const KitTheme({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.textMuted,
    required this.accent,
    required this.accentBright,
    required this.accentBrightInk,
    required this.accentInk,
    required this.background,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color textMuted;
  final Color accent;
  final Color accentBright;

  /// Reads on [accentBright].
  final Color accentBrightInk;

  /// Reads on a filled [accent] — measured, not guessed. See `inkFor`.
  final Color accentInk;

  /// The page behind everything: a gradient, or stripes for the two kits that
  /// are a texture rather than a colour.
  final Decoration background;

  @override
  KitTheme copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? border,
    Color? textMuted,
    Color? accent,
    Color? accentBright,
    Color? accentBrightInk,
    Color? accentInk,
    Decoration? background,
  }) {
    return KitTheme(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      border: border ?? this.border,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      accentBright: accentBright ?? this.accentBright,
      accentBrightInk: accentBrightInk ?? this.accentBrightInk,
      accentInk: accentInk ?? this.accentInk,
      background: background ?? this.background,
    );
  }

  @override
  KitTheme lerp(covariant KitTheme? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return KitTheme(
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      surface2: c(surface2, other.surface2),
      border: c(border, other.border),
      textMuted: c(textMuted, other.textMuted),
      accent: c(accent, other.accent),
      accentBright: c(accentBright, other.accentBright),
      accentBrightInk: c(accentBrightInk, other.accentBrightInk),
      accentInk: c(accentInk, other.accentInk),
      // Two decorations of different kinds cannot be interpolated, and a kit
      // change swaps stripes for a gradient often enough to matter. Snap.
      background: t < 0.5 ? background : other.background,
    );
  }
}
