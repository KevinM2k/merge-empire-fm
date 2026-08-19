/// A pile of coins, DRAWN. Ported from `coinCluster` in `ui/icons.js`.
///
/// This is the artwork the coin shelf was missing. All four bundles share the
/// same 💰 in the catalogue — deliberately, because `icon` is plain text that
/// the toast renders and every bundle should say "coins" rather than pick an
/// unrelated container. The JS's own note says where the tiers get told apart:
/// on the shop tile, by drawing one, two, three and five actual coins. A bag, a
/// chest, a vault and a mountain are four sizes of one idea, and the size is the
/// thing the tile has to show.
///
/// **A solid coin, not the HUD's.** The icon set's coin is `fill="none"` like
/// every other glyph in it, which is right beside a number and wrong the moment
/// two overlap: hollow rings let the coin behind show straight through and the
/// pile turns to wireframe. So the disc is filled, rimmed in translucent black
/// so touching coins still read as separate, and carries the ¢ on top in the
/// same ink.
///
/// **Gold literal, not the kit's.** The kit's gold is deliberately a dark bronze
/// in light mode, because bright gold TEXT is illegible on a white page. These
/// are not text: the rim carries the contrast, so the fill is free to be actual
/// gold on both themes. Following the theme made them look like pennies.
library;

import 'package:flutter/material.dart';

/// The coin the whole app draws money in.
const Color coinGold = Color(0xFFFFD700);

/// How many coins each bundle draws, cheapest first — the JS's
/// `COIN_TILE_COUNTS`. A bundle past the end of the ladder draws the biggest
/// pile rather than none.
const List<int> coinTileCounts = [1, 2, 3, 5];

int coinsDrawnFor(int rank) =>
    coinTileCounts[rank.clamp(0, coinTileCounts.length - 1)];

/// `[dx, dy, scale]` per coin, at the 30px box the offsets are written against.
const Map<int, List<(double, double, double)>> _layouts = {
  1: [(0, 0, 1)],
  2: [(-5, 3, 0.88), (5, -3, 1)],
  3: [(-7, 5, 0.8), (7, 5, 0.8), (0, -4, 1)],
  5: [
    (-10, 7, 0.66),
    (0, 8, 0.7),
    (10, 7, 0.66),
    (-5, -1, 0.86),
    (6, -4, 0.94),
  ],
};

/// The ¢ on the face, in the coin's own 24×24 space — the icon set's path, as
/// six relative cubics and two ticks.
final Path _cent = Path()
  ..moveTo(14.5, 9)
  ..relativeCubicTo(-.5, -1, -1.5, -1.5, -2.5, -1.5)
  ..relativeCubicTo(-1.5, 0, -3, .8, -3, 2.2)
  ..relativeCubicTo(0, 1.3, 1.3, 1.7, 2.7, 2)
  ..relativeCubicTo(1.5, .35, 3, .75, 3, 2.3)
  ..relativeCubicTo(0, 1.4, -1.5, 2.2, -3, 2.2)
  ..relativeCubicTo(-1.3, 0, -2.3, -.5, -2.8, -1.5)
  ..moveTo(12, 6.2)
  ..relativeLineTo(0, 1.3)
  ..moveTo(12, 16.5)
  ..lineTo(12, 17.8);

class CoinCluster extends StatelessWidget {
  const CoinCluster({super.key, required this.count, this.size = 30});

  /// How many coins to draw. A count with no layout draws one.
  final int count;

  /// The box the layout is measured against. The pile SPILLS OUT of it, exactly
  /// as the JS's absolutely-positioned spans do — five coins reach about a third
  /// again beyond the box, so give it room rather than clipping it.
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: ValueKey('coin-cluster-$count'),
    size: Size.square(size),
    painter: _ClusterPainter(count: count),
  );
}

class _ClusterPainter extends CustomPainter {
  const _ClusterPainter({required this.count});

  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final centre = size.center(Offset.zero);
    // The offsets are written against a 30px box, so they scale with it.
    final unit = size.shortestSide / 30;
    for (final (dx, dy, scale) in _layouts[count] ?? _layouts[1]!) {
      _coin(
        canvas,
        centre + Offset(dx * unit, dy * unit),
        size.shortestSide * scale,
      );
    }
  }

  void _coin(Canvas canvas, Offset at, double box) {
    final k = box / 24;
    canvas.drawCircle(at, 9 * k, Paint()..color = coinGold);
    canvas.drawCircle(
      at,
      9 * k,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3 * k
        ..color = Colors.black.withValues(alpha: 0.30),
    );
    canvas.drawPath(
      _cent.transform(
        (Matrix4.identity()
              ..translateByDouble(at.dx - 12 * k, at.dy - 12 * k, 0, 1)
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

  @override
  bool shouldRepaint(_ClusterPainter old) => old.count != count;
}
