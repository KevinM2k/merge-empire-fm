/// A picture for each gem pack, drawn: a pocketful, a casket and a hoard.
///
/// **One gem, whatever you were buying.** Every bundle on the gems shelf wore
/// the same 34px `GameIcon('gem')` — so Pocket of Gems, Casket of Gems and
/// Hoard of Gems were three prices under three identical pictures, and the
/// tile said nothing about which of them was the big one.
///
/// **The names are the brief**, the same way they were for the coin packs next
/// to them: a pocket, a casket and a hoard are three different objects, not one
/// object at three sizes. The coin shelf solved this problem first and this is
/// that solution applied — four compositions of two primitives, a cut gem and a
/// container, written against a 100×100 box and scaled. Nothing is bundled for
/// these and nothing needs to be: they scale to any tile, they theme with
/// nothing, and they cost one painter.
///
/// **CHECKED AGAINST `assets/gemArt.js`, and it is deliberately a different
/// answer.** The JS draws FIVE tiers of the same stone in escalating PILES —
/// two loose, a handful, a heap, a three-row pyramid — and only the top tier is
/// a container, a chest, "because the jump from a lot to a container full is
/// what sells the best-value tile". Its own note says the stone SIZE stays
/// constant and the FOOTPRINT grows, because packing more stones into the same
/// area reads as denser rather than bigger.
///
/// This shelf has THREE bundles, not five, and they are NAMED — Pocket, Casket,
/// Hoard — so the container is the brief rather than a top-tier flourish, and
/// the piles the JS escalates through have nowhere to go. What is worth taking
/// from it and IS taken: the stone is faceted rather than flat (a table and a
/// lit crown, which is what makes it read as a cut gem at 34px), and the hoard
/// grows its footprint rather than its stones.
///
/// So: not a port of the spec's pictures, checked against them, and different
/// on purpose. The one thing to re-read if a fourth bundle is ever added is
/// that footprint note — it is the part of the JS's reasoning that survives
/// whatever the containers do.
library;

import 'package:flutter/material.dart';

/// Which picture a bundle gets, by product id. Falls back to the pocket, which
/// is the one that reads as "some gems" with no other information.
GemPackArt gemPackArtFor(String productId) => switch (productId) {
  'gems_5' => GemPackArt.pocket,
  'gems_15' => GemPackArt.casket,
  'gems_35' => GemPackArt.hoard,
  _ => GemPackArt.pocket,
};

enum GemPackArt {
  /// Pocket of Gems — three, spilling out of a small pouch.
  pocket,

  /// Casket of Gems — a lidded box, open, with gems showing over the rim.
  casket,

  /// Hoard of Gems — a heap of them, no container at all.
  hoard,
}

/// The gem's own colours. Deliberately NOT the kit's: like the coins, these are
/// pictures of a currency, and a currency is the same colour in every club's
/// colours. `0xFF7FD4FF` is the ink every gem figure in the game is printed in.
const Color gemInk = Color(0xFF7FD4FF);
const Color _gemLight = Color(0xFFD6F1FF);
const Color _gemDeep = Color(0xFF2E93C9);
const Color _gemEdge = Color(0xFF12496B);

/// The container metal, matching the coin packs' own.
const Color _leather = Color(0xFF6B4A2F);
const Color _leatherDark = Color(0xFF4A3220);
const Color _wood = Color(0xFF7A5330);
const Color _woodDark = Color(0xFF4E351E);

class GemPackPicture extends StatelessWidget {
  const GemPackPicture({super.key, required this.art, this.size = 52});

  final GemPackArt art;

  /// The box the picture is composed in. It fills it.
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: ValueKey('gem-pack-art-${art.name}'),
    size: Size.square(size),
    painter: _GemPackPainter(art: art),
  );
}

class _GemPackPainter extends CustomPainter {
  const _GemPackPainter({required this.art});

  final GemPackArt art;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Everything is written against a 100×100 box and scaled, so one set of
    // numbers draws the picture at any tile size.
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    switch (art) {
      case GemPackArt.pocket:
        _pocket(canvas);
      case GemPackArt.casket:
        _casket(canvas);
      case GemPackArt.hoard:
        _hoard(canvas);
    }
    canvas.restore();
  }

  /// One cut gem, in the 100-box's units: a table, a crown and a point.
  ///
  /// Drawn rather than stroked as an icon, because a pile of outlines is a
  /// tangle — a filled stone with a lit table reads as a separate object even
  /// where three of them overlap.
  void _gem(Canvas canvas, double cx, double cy, double r) {
    final table = <Offset>[
      Offset(cx - r * 0.52, cy - r * 0.78),
      Offset(cx + r * 0.52, cy - r * 0.78),
      Offset(cx + r, cy - r * 0.18),
      Offset(cx, cy + r),
      Offset(cx - r, cy - r * 0.18),
    ];
    final body = Path()..addPolygon(table, true);
    canvas.drawPath(body, Paint()..color = gemInk);

    // The lit half: the table and the crown facet on the left, which is what
    // makes it read as CUT rather than as a coloured pentagon.
    canvas.drawPath(
      Path()..addPolygon([
        table[0],
        table[1],
        Offset(cx + r * 0.34, cy - r * 0.18),
        Offset(cx - r * 0.34, cy - r * 0.18),
      ], true),
      Paint()..color = _gemLight,
    );
    canvas.drawPath(
      Path()..addPolygon([
        Offset(cx + r * 0.34, cy - r * 0.18),
        table[2],
        table[3],
      ], true),
      Paint()..color = _gemDeep,
    );

    // Facet lines, and the outline. Below about five units they crowd the stone
    // and it reads better clean — the same call the coin's ¢ makes.
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.11
      ..color = _gemEdge.withValues(alpha: 0.55);
    canvas.drawPath(body, edge);
    if (r < 5) return;
    final facet = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08
      ..color = _gemEdge.withValues(alpha: 0.42);
    canvas.drawLine(table[4], Offset(cx - r * 0.34, cy - r * 0.18), facet);
    canvas.drawLine(
      Offset(cx - r * 0.34, cy - r * 0.18),
      Offset(cx + r * 0.34, cy - r * 0.18),
      facet,
    );
    canvas.drawLine(Offset(cx + r * 0.34, cy - r * 0.18), table[2], facet);
    canvas.drawLine(Offset(cx - r * 0.34, cy - r * 0.18), table[3], facet);
    canvas.drawLine(Offset(cx + r * 0.34, cy - r * 0.18), table[3], facet);
  }

  /// Pocket of Gems — a small pouch, three stones spilling from the neck.
  void _pocket(Canvas canvas) {
    final pouch = Path()
      ..moveTo(30, 52)
      ..cubicTo(18, 62, 18, 92, 50, 92)
      ..cubicTo(82, 92, 82, 62, 70, 52)
      ..close();
    canvas.drawPath(pouch, Paint()..color = _leather);
    // The tie, and the shadow under it — the pouch is a bag rather than a blob
    // because the mouth is drawn narrower than the belly.
    canvas.drawPath(
      Path()
        ..moveTo(30, 52)
        ..lineTo(70, 52)
        ..lineTo(66, 62)
        ..lineTo(34, 62)
        ..close(),
      Paint()..color = _leatherDark,
    );
    _gem(canvas, 38, 44, 12);
    _gem(canvas, 60, 40, 11);
    _gem(canvas, 50, 30, 13);
  }

  /// Casket of Gems — a lidded box, open, with the stones over the rim.
  void _casket(Canvas canvas) {
    // The lid, thrown back.
    canvas.drawPath(
      Path()
        ..moveTo(16, 42)
        ..lineTo(84, 42)
        ..lineTo(78, 24)
        ..lineTo(22, 24)
        ..close(),
      Paint()..color = _woodDark,
    );
    // The stones sit BETWEEN the lid and the box, which is what says the box is
    // open and full rather than shut with a picture on the front.
    _gem(canvas, 32, 52, 12);
    _gem(canvas, 68, 52, 12);
    _gem(canvas, 50, 46, 15);
    // The box.
    canvas.drawRect(
      const Rect.fromLTWH(16, 56, 68, 32),
      Paint()..color = _wood,
    );
    canvas.drawRect(
      const Rect.fromLTWH(16, 56, 68, 7),
      Paint()..color = _woodDark,
    );
    // A band and a clasp, so it is a casket and not a crate.
    canvas.drawRect(
      const Rect.fromLTWH(44, 56, 12, 32),
      Paint()..color = _leatherDark,
    );
    canvas.drawRect(
      const Rect.fromLTWH(42, 68, 16, 10),
      Paint()..color = _gemLight.withValues(alpha: 0.85),
    );
  }

  /// Hoard of Gems — no container at all, just a great many of them.
  ///
  /// The top of the shelf gets the picture with the most STONES in it rather
  /// than the biggest box: what is being bought is the gems, and a hoard is a
  /// quantity that has outgrown anything you would keep it in.
  void _hoard(Canvas canvas) {
    for (final row in [
      (y: 82.0, xs: [16.0, 38.0, 62.0, 84.0], r: 11.0),
      (y: 64.0, xs: [27.0, 50.0, 73.0], r: 12.0),
      (y: 46.0, xs: [38.0, 62.0], r: 12.0),
      (y: 28.0, xs: [50.0], r: 14.0),
    ]) {
      for (final x in row.xs) {
        _gem(canvas, x, row.y, row.r);
      }
    }
  }

  @override
  bool shouldRepaint(_GemPackPainter old) => old.art != art;
}
