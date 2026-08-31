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
    this.alignment = Alignment.center,
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

  /// Where the art sits when the fit leaves room. Top-centre for a portrait
  /// that is wider than its frame: the head is at the top of the drawing, so
  /// centring the slack puts a gap above it and crops his boots twice over.
  final Alignment alignment;
  final double? width;
  final double? height;

  /// Greyscaled and knocked back — a locked achievement, or a facility the club
  /// has not built yet.
  final bool dimmed;

  /// How far [dimmed] knocks it back, where the two call sites disagree.
  final double dimBrightness;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, box) => _image(context, box));

  Widget _image(BuildContext context, BoxConstraints box) {
    // **THE DECODE WAS FULL SIZE, and the comment here has said so for months
    // without the code doing anything about it.** Every one of these is a
    // 512×512 PNG and most are drawn at 90 or less; `Image.asset` with no
    // `cacheWidth` decodes at the file's own size, so the first time a portrait
    // is shown the raster thread does thirty-two times the work it needs to.
    //
    // On the grid that is invisible — the cards are already up. It is the
    // REVEAL that shows it: a merge and an Add Player both put a portrait on
    // screen that has never been decoded, on the frame the card animates in,
    // and the animation stutters on its first frame. Reported as a slight
    // slowdown on both.
    //
    // Sized from the box it is actually being laid out in, times the device's
    // pixel ratio so a 3× phone still gets a sharp one, and clamped to the
    // asset's own size so this can never ask for an UPSCALE.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final want = width ?? (box.hasBoundedWidth ? box.maxWidth : null);
    final tall = height ?? (box.hasBoundedHeight ? box.maxHeight : null);
    Widget image = Image.asset(
      path,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      cacheWidth: want == null ? null : (want * dpr).round().clamp(1, 2048),
      cacheHeight: want != null || tall == null
          ? null
          : (tall * dpr).round().clamp(1, 2048),
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
