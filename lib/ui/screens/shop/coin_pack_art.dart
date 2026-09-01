/// A picture for each coin pack, drawn: a pocketful, a pile, a vault and a
/// mountain.
///
/// **The names are the brief.** All four bundles share one 💰 in the catalogue
/// and the JS tells them apart with a cluster of one, two, three and five coins —
/// which is a quantity, not a picture, and does not make sense of "Coin Vault"
/// or "Coin Mountain". Nothing is bundled for these and nothing needs to be:
/// they are four compositions of the same two primitives — a filled coin and a
/// container — so they scale to any tile, theme with nothing, and cost one
/// painter each.
///
/// The coin itself is [CoinCluster]'s: a gold disc with a translucent black rim
/// so overlapping coins still read as separate, and the ¢ on top in the same
/// ink. Everything here is built from it so the four pictures are visibly the
/// same currency at four different scales.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/screens/shop/coin_cluster.dart';

/// Which picture a bundle gets, by product id. Falls back to the pile, which is
/// the one that reads as "coins" with no other information.
CoinPackArt coinPackArtFor(String productId) => switch (productId) {
  'coins_small' => CoinPackArt.pocket,
  'coins_medium' => CoinPackArt.pile,
  'coins_large' => CoinPackArt.vault,
  'coins_mega' => CoinPackArt.mountain,
  _ => CoinPackArt.pile,
};

enum CoinPackArt {
  /// Pocket Change — a few coins spilling out of a small pouch.
  pocket,

  /// Coin Pile — a heap, three rows deep.
  pile,

  /// Coin Vault — a strongbox with its lid up and coins showing.
  vault,

  /// Coin Mountain — a peak of coins with a couple tumbling off it.
  mountain,
}

/// The metal the containers are drawn in. Deliberately NOT the kit's: these are
/// pictures of money, and money is the same colour in every club's colours.
/// The lit face and the shaded one, either side of [coinGold].
///
/// Two members of the same gold rather than white and black: a highlight that
/// goes to white is a plastic bead, and a shadow that goes to grey takes the
/// metal out of it.
const Color _coinLit = Color(0xFFFFF3B0);
const Color _coinDeep = Color(0xFFB8860B);

const Color _leather = Color(0xFF6B4A2F);
const Color _leatherDark = Color(0xFF4A3220);
const Color _steel = Color(0xFF5A6472);
const Color _steelLight = Color(0xFF8A96A6);
const Color _steelDark = Color(0xFF39404A);

class CoinPackPicture extends StatelessWidget {
  const CoinPackPicture({super.key, required this.art, this.size = 52});

  final CoinPackArt art;

  /// The box the picture is composed in. It fills it.
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: ValueKey('coin-pack-art-${art.name}'),
    size: Size.square(size),
    painter: _PackPainter(art: art),
  );
}

class _PackPainter extends CustomPainter {
  const _PackPainter({required this.art});

  final CoinPackArt art;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Everything is written against a 100×100 box and scaled, so one set of
    // numbers draws the picture at any tile size.
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    switch (art) {
      case CoinPackArt.pocket:
        _pocket(canvas);
      case CoinPackArt.pile:
        _pile(canvas);
      case CoinPackArt.vault:
        _vault(canvas);
      case CoinPackArt.mountain:
        _mountain(canvas);
    }
    canvas.restore();
  }

  /// A coin, face on, in the 100-box's units.
  ///
  /// **METAL, not a yellow disc.** It was one flat fill of [coinGold] under a
  /// black rim, four pictures' worth of it, and a flat circle is what reads as
  /// generated — reported from the couch about this shelf's artwork. A struck
  /// coin is a raised disc: light off the top-left, the face falling away to a
  /// deeper gold at the bottom-right, and a bright arc along the lit rim where
  /// the milling catches. Three paints, and it is the same light source every
  /// moulded control in this game is lit by.
  void _coin(Canvas canvas, double cx, double cy, double r) {
    final at = Offset(cx, cy);
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.45, -0.5),
          radius: 1.1,
          colors: [_coinLit, coinGold, _coinDeep],
          stops: [0, 0.52, 1],
        ).createShader(Rect.fromCircle(center: at, radius: r)),
    );
    // The milled edge, caught on the lit side only — a rim that is bright all
    // the way round is a ring rather than a light.
    canvas.drawArc(
      Rect.fromCircle(center: at, radius: r * 0.92),
      math.pi * 1.05,
      math.pi * 0.8,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.11
        ..strokeCap = StrokeCap.round
        ..color = _coinLit.withValues(alpha: 0.75),
    );
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.14
        ..color = Colors.black.withValues(alpha: 0.30),
    );
    // The ¢, only once a coin is big enough to carry it — below about six units
    // it is a smudge and reads worse than a clean disc.
    if (r < 6) return;
    final k = r / 9;
    canvas.drawPath(
      centGlyph.transform(
        (Matrix4.identity()
              ..translateByDouble(cx - 12 * k, cy - 12 * k, 0, 1)
              ..scaleByDouble(k, k, 1, 1))
            .storage,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7 * k
        ..strokeCap = StrokeCap.round
        ..color = Colors.black.withValues(alpha: 0.42),
    );
  }

  /// A coin seen edge-on — an ellipse with a rim under it. What a stack is made
  /// of, and what makes a heap read as a heap rather than as a bag of discs.
  void _edge(Canvas canvas, double cx, double cy, double rx) {
    final ry = rx * 0.34;
    final box = Rect.fromCenter(
      center: Offset(cx, cy),
      width: rx * 2,
      height: ry * 2,
    );
    // Lit along the top of the rim and shaded under it, so a stack of these has
    // thickness rather than being a run of identical yellow ellipses.
    canvas.drawOval(
      box,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_coinLit, coinGold, _coinDeep],
          stops: [0, 0.45, 1],
        ).createShader(box),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rx * 0.1
        ..color = Colors.black.withValues(alpha: 0.28),
    );
  }

  // ── Pocket Change ─────────────────────────────────────────────────────────
  //
  // A small drawstring pouch with three coins out of it. The pouch is what makes
  // "pocket" the picture rather than "three coins".

  void _pocket(Canvas canvas) {
    final body = Path()
      ..moveTo(30, 58)
      ..cubicTo(24, 74, 34, 90, 52, 90)
      ..cubicTo(70, 90, 80, 74, 74, 58)
      ..cubicTo(66, 52, 38, 52, 30, 58)
      ..close();
    canvas.drawPath(body, Paint()..color = _leather);
    // A gusset down the middle, so the pouch has a front and a side.
    canvas.drawPath(
      Path()
        ..moveTo(56, 55)
        ..cubicTo(78, 58, 84, 76, 70, 87)
        ..cubicTo(78, 80, 82, 66, 74, 58)
        ..close(),
      Paint()..color = _leatherDark,
    );
    // The tie, pinched at the neck.
    canvas.drawRect(
      const Rect.fromLTWH(38, 50, 34, 8),
      Paint()..color = _leatherDark,
    );

    _coin(canvas, 24, 40, 12);
    _coin(canvas, 46, 30, 14);
    _coin(canvas, 68, 42, 11);
  }

  // ── Coin Pile ─────────────────────────────────────────────────────────────
  //
  // A heap: edge-on coins stacked into a triangle with face-on coins leaning on
  // the front of it, which is how a pile of coins actually looks.

  void _pile(Canvas canvas) {
    // Back rows, edge-on, widest at the bottom.
    for (final row in [
      (y: 84.0, xs: [22.0, 40.0, 58.0, 78.0], rx: 12.0),
      (y: 70.0, xs: [31.0, 50.0, 69.0], rx: 12.0),
      (y: 56.0, xs: [40.0, 60.0], rx: 12.0),
      (y: 42.0, xs: [50.0], rx: 12.0),
    ]) {
      for (final x in row.xs) {
        _edge(canvas, x, row.y, row.rx);
      }
    }
    // Two face-on, leaning against the front — the ones that carry the ¢.
    _coin(canvas, 33, 76, 13);
    _coin(canvas, 64, 78, 11);
  }

  // ── Coin Vault ────────────────────────────────────────────────────────────
  //
  // A strongbox with the lid up. The dial is what says "vault" at 52 pixels;
  // without it a box of coins is a box of coins.

  void _vault(Canvas canvas) {
    // The lid, thrown back.
    canvas.drawPath(
      Path()
        ..moveTo(16, 46)
        ..cubicTo(18, 22, 82, 22, 84, 46)
        ..lineTo(84, 52)
        ..lineTo(16, 52)
        ..close(),
      Paint()..color = _steelDark,
    );
    canvas.drawPath(
      Path()
        ..moveTo(22, 46)
        ..cubicTo(24, 30, 76, 30, 78, 46)
        ..close(),
      Paint()..color = _steel,
    );

    // Coins showing over the rim, drawn before the front so the box holds them.
    _coin(canvas, 36, 56, 11);
    _coin(canvas, 58, 54, 12);
    _coin(canvas, 74, 58, 9);

    // The body.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        const Rect.fromLTWH(16, 58, 68, 32),
        bottomLeft: const Radius.circular(6),
        bottomRight: const Radius.circular(6),
      ),
      Paint()..color = _steel,
    );
    canvas.drawRect(
      const Rect.fromLTWH(16, 58, 68, 5),
      Paint()..color = _steelLight,
    );

    // The dial.
    canvas.drawCircle(const Offset(50, 75), 10, Paint()..color = _steelDark);
    canvas.drawCircle(
      const Offset(50, 75),
      10,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _steelLight,
    );
    // Spokes, so it reads as something that turns.
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 4 + math.pi / 8;
      canvas.drawLine(
        Offset(50 + math.cos(a) * 8, 75 + math.sin(a) * 8),
        Offset(50 - math.cos(a) * 8, 75 - math.sin(a) * 8),
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = _steelLight,
      );
    }
  }

  // ── Coin Mountain ─────────────────────────────────────────────────────────
  //
  // A peak, tall enough to read as terrain rather than as a bigger pile, with
  // two coins tumbling off the side to say it will not all stay up there.

  void _mountain(Canvas canvas) {
    // The mass, as one silhouette so the rows below sit ON something.
    canvas.drawPath(
      Path()
        ..moveTo(8, 92)
        ..lineTo(50, 14)
        ..lineTo(92, 92)
        ..close(),
      Paint()..color = const Color(0xFFB8860B),
    );
    // A lit face down the left of the peak.
    canvas.drawPath(
      Path()
        ..moveTo(50, 14)
        ..lineTo(50, 92)
        ..lineTo(8, 92)
        ..close(),
      Paint()..color = const Color(0xFFDAA520),
    );

    // Coins across it, thinning toward the summit, so the terrain is visibly
    // MADE of them.
    for (final row in [
      (y: 88.0, xs: [16.0, 34.0, 52.0, 70.0, 86.0]),
      (y: 74.0, xs: [24.0, 42.0, 60.0, 78.0]),
      (y: 60.0, xs: [32.0, 50.0, 68.0]),
      (y: 46.0, xs: [40.0, 58.0]),
      (y: 32.0, xs: [49.0]),
    ]) {
      for (final x in row.xs) {
        _edge(canvas, x, row.y, 11);
      }
    }
    // The summit, face on: the one coin the eye lands on.
    _coin(canvas, 50, 20, 9);
    // And two coming off the slope.
    _coin(canvas, 86, 60, 8);
    _coin(canvas, 14, 66, 7);
  }

  @override
  bool shouldRepaint(_PackPainter old) => old.art != art;
}
