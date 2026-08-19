/// The shipped artwork, with the hand-drawn SVG behind it.
///
/// Every `<img>` in the JS carries the same `onerror` line: swap in the
/// generated SVG and stop. That is not defensive noise — the art is generated
/// per (category, tier) and a newly added asset can legitimately have none yet,
/// in which case the JS shows the drawing rather than a hole. `errorBuilder` is
/// that line, and it is the reason this widget exists rather than a bare
/// `Image.asset` at each call site.
///
/// [dimmed] is the CSS `grayscale(1) brightness(0.4)` the locked trophy tiles
/// and the unbuilt club tiles both use. A saturation matrix is the same
/// operation; doing it here keeps the one magic number in one place.
library;

import 'package:flutter/material.dart';

/// Luminance weights — the same ones CSS `grayscale()` is defined against, so a
/// dimmed tile here and a dimmed tile in the JS are the same grey.
const double _lumR = 0.2126;
const double _lumG = 0.7152;
const double _lumB = 0.0722;

/// How far a locked tile is knocked back. The trophy grid's own value; the
/// club tiles use a hair more (0.45) and pass it in.
const double _dimBrightness = 0.4;

ColorFilter _greyscale(double brightness) {
  final r = _lumR * brightness;
  final g = _lumG * brightness;
  final b = _lumB * brightness;
  return ColorFilter.matrix(<double>[
    r, g, b, 0, 0, //
    r, g, b, 0, 0, //
    r, g, b, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);
}

class ArtImage extends StatelessWidget {
  const ArtImage({
    required this.path,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.dimmed = false,
    this.dimBrightness = _dimBrightness,
    super.key,
  });

  /// An asset path from `lib/data/art_paths.dart`.
  final String path;

  /// What to show when that asset is not in the bundle. Never null: a tile with
  /// nothing in it renders shorter than its neighbours, which is the specific
  /// thing the JS's fallback was written to avoid.
  final Widget fallback;

  final BoxFit fit;
  final double? width;
  final double? height;

  /// Greyscaled and knocked back — a locked achievement, or a facility the club
  /// has not built yet.
  final bool dimmed;

  /// How far [dimmed] knocks it back, where the two call sites disagree.
  final double dimBrightness;

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      path,
      fit: fit,
      width: width,
      height: height,
      // Decoding a 512px trophy at 110px costs the same memory as showing it at
      // 512 unless the cache is told the size it will actually be drawn at.
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) =>
          SizedBox(width: width, height: height, child: fallback),
    );

    if (dimmed) {
      image = ColorFiltered(
        colorFilter: _greyscale(dimBrightness),
        child: image,
      );
    }
    return image;
  }
}
