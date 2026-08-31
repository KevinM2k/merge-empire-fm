/// **THE SEAM RENDERED ART DROPS INTO, and the drawn art that stands in until
/// it does.**
///
/// The shop's pictures are `CustomPainter` vector art — `coin_pack_art.dart`,
/// `gem_pack_art.dart` — and against the reference shops they are the biggest
/// remaining gap: those packs are rendered 3D illustrations and these are very
/// good vector drawings of the same objects. Generating replacements is blocked
/// in a cloud session (see the artwork row in `docs/REMAINING.md`: every image
/// host is refused at the proxy), so the decision taken was "do the art later,
/// build the fallbacks now" — which is this file.
///
/// **What it buys is that the art arrives without touching a tile.** Every
/// picture in the shop goes through [ShopArt]; when an id has no entry in
/// [shopArtManifest] it draws whatever the caller passes as [ShopArt.fallback],
/// which is the painter that is there today. Landing real art is then three
/// mechanical steps and no logic: put the file in `assets/shop/`, list it in
/// `pubspec.yaml`, add the row here. The tiles never learn about it.
///
/// **It is a MANIFEST rather than a probe**, deliberately. Asking the bundle at
/// runtime whether a file exists is asynchronous, gives every tile a frame of
/// nothing before it resolves, and turns a missing asset into console noise
/// instead of a fact. A declared map is checkable — `shop_art_test` holds every
/// path in it against `pubspec.yaml`, so a half-landed art drop fails the build
/// rather than shipping a broken image box.
library;

import 'package:flutter/material.dart';

/// Product id → the bundled illustration for it.
///
/// **EMPTY ON PURPOSE.** There is no rendered shop art yet; every id below the
/// line falls through to its painter. The keys, when they come, are
/// `IapProduct.id` — `coins_small`, `gems_35`, `vip_pass` — so the tile can ask
/// with the thing it already holds.
///
/// Paths go under `assets/shop/`. Square, and drawn to fill the box: the tiles
/// hand [ShopArt] one side length and the picture is fitted inside it, so a
/// rectangular illustration letterboxes rather than crops.
const Map<String, String> shopArtManifest = {};

/// The bundled illustration for [id], or null when there is not one yet.
String? shopArtAsset(String id) => shopArtManifest[id];

/// A shop picture: the illustration if there is one, the drawing if there is not.
class ShopArt extends StatelessWidget {
  const ShopArt({
    super.key,
    required this.id,
    required this.size,
    required this.fallback,
  });

  /// The product's own id, which is what [shopArtManifest] is keyed by.
  final String id;

  /// The side of the square the picture is composed in.
  final double size;

  /// What to draw while there is no illustration. **Not nullable**: a shop tile
  /// with no picture at all is worse than either answer, and making the caller
  /// pass one is what guarantees this widget can always draw something.
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final asset = shopArtAsset(id);
    if (asset == null) return fallback;
    return Image.asset(
      asset,
      key: ValueKey('shop-art-$id'),
      width: size,
      height: size,
      // Fitted rather than cropped: an illustration that does not match the box
      // should show all of itself with air round it, not lose its edges.
      fit: BoxFit.contain,
      // These are big pictures in small boxes — a coin pack renders at 44 on a
      // grid tile — and nearest-neighbour downscaling of a rendered illustration
      // is the one thing that would make it look worse than the drawing it
      // replaced.
      filterQuality: FilterQuality.medium,
      // **Belt and braces against a half-landed drop.** The test holds the
      // manifest against `pubspec.yaml`, so this should be unreachable; if it
      // ever is not, a tile draws its old picture rather than a broken box.
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
