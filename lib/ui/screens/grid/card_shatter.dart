/// A card breaking into pieces of itself. Ported from `burstAway` in
/// `ui/components/MergeAnimation.js`.
///
/// For a card that was never going to stay — an auto-sold scout result. Flying
/// it into a grid slot it does not occupy, only to have the slot turn up empty,
/// reads as a bug; breaking it apart reads as the sale it actually was.
///
/// **The port had the coins and not the break.** The cash-in faded the card to
/// nothing over a quarter of a second behind a coin burst, which is a card
/// being deleted with sparks over it — reported as the auto-sold animation
/// being poor next to the JS's. What the JS spends its effort on is the
/// SHARDS: twelve clipped clones of the card's own face, flung out from the
/// middle, spinning, sagging under gravity, so it is visibly THAT player coming
/// apart rather than a generic puff.
///
/// **The pieces are the card as it WAS.** The child is captured on the frame the
/// break begins and never rebuilt — the JS clones the face for the same reason,
/// and here it also means twelve card subtrees are built once rather than once
/// per frame for half a second.
///
/// The shard count is fixed where the JS halves it on a weak phone: each of its
/// pieces is a fresh DOM clone, so the count IS the cost there, and every one of
/// them lands in a single frame. A [RepaintBoundary] per shard makes these
/// twelve cached rasters that only move, which is the thing that reduction was
/// buying.
///
/// A caller must hold whatever backdrop it has up for [cardShatterDuration]: a
/// card exploding over the live UI reads as a glitch rather than as a sale.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/screens/grid/merge_burst.dart'
    show burstHash;

/// How long the break takes. The JS's `VANISH_MS`.
const Duration cardShatterDuration = Duration(milliseconds: 520);

/// The longest a single piece can run past the others, so the break frays out
/// rather than stopping on one frame. The JS's `+ Math.random() * 150`.
const int cardShatterFrayMs = 150;

/// Pieces across and down. The JS's non-low-end 3×4.
const int shatterCols = 3;
const int shatterRows = 4;

/// How many coin pieces the burst behind the break throws. Flat, whatever the
/// card was, which is what `MergeBurst`'s own `particles` override is for.
const int cardShatterParticles = 22;

/// `cubic-bezier(0.12, 0.62, 0.3, 1)` — the shards' own easing: away hard, then
/// a long tail while they fade.
const Curve _thrown = Cubic(0.12, 0.62, 0.3, 1);

class CardShatter extends StatefulWidget {
  const CardShatter({
    super.key,
    required this.progress,
    required this.seed,
    required this.child,
  });

  /// 0 while the card is whole, 1 when the last piece has gone.
  final double progress;

  /// Which break this is, so two sales do not come apart in the same shape
  /// while each one stays stable across its own frames.
  final int seed;

  final Widget child;

  @override
  State<CardShatter> createState() => _CardShatterState();
}

class _CardShatterState extends State<CardShatter> {
  /// The face, as it was when it broke. See the note at the top of the file.
  Widget? _face;

  @override
  Widget build(BuildContext context) {
    if (widget.progress <= 0) {
      _face = null;
      return widget.child;
    }
    // Reduce-motion keeps the sale and drops the break: the card goes, and the
    // caption and the coins say what happened to it.
    if (MediaQuery.disableAnimationsOf(context)) {
      return Opacity(
        opacity: (1 - widget.progress).clamp(0.0, 1.0),
        child: widget.child,
      );
    }
    final face = _face ??= widget.child;
    return Stack(
      key: const ValueKey('card-shatter'),
      clipBehavior: Clip.none,
      children: [
        for (var row = 0; row < shatterRows; row++)
          for (var col = 0; col < shatterCols; col++)
            _Shard(
              progress: widget.progress,
              seed: widget.seed,
              col: col,
              row: row,
              child: face,
            ),
      ],
    );
  }
}

/// One piece: the whole card, clipped to its own cell, thrown away from the
/// middle.
///
/// The clip is in the card's own space and the throw is outside it, which is
/// what makes the piece carry its share of the drawing with it. Rotation is
/// about the CARD's centre rather than the piece's — the JS rotates a
/// card-sized node with a `clip-path` on it, and pivoting each piece on itself
/// instead makes the break read as twelve independent spinning tiles.
class _Shard extends StatelessWidget {
  const _Shard({
    required this.progress,
    required this.seed,
    required this.col,
    required this.row,
    required this.child,
  });

  final double progress;
  final int seed;
  final int col;
  final int row;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final i = row * shatterCols + col;
    final spread = 150 + burstHash(seed, i, 0) * 110;
    final spin = (burstHash(seed, i, 1) - 0.5) * 150;
    final fray = burstHash(seed, i, 2) * cardShatterFrayMs;

    final p =
        (progress /
                (1 + fray / cardShatterDuration.inMilliseconds))
            .clamp(0.0, 1.0);
    final e = _thrown.transform(p);

    // Out from the card's middle, which is what makes it a break rather than a
    // drift, with the whole lot sagging as it goes.
    final ox = (col + 0.5) / shatterCols - 0.5;
    final oy = (row + 0.5) / shatterRows - 0.5;

    // Whole for the first 40%, so the shape of the card is readable for a beat
    // after it has come apart, then gone.
    final fade = p <= 0.4
        ? 1.0
        : 1 - _thrown.transform(((p - 0.4) / 0.6).clamp(0.0, 1.0));

    return Transform.translate(
      offset: Offset(ox * spread * 2 * e, (oy * spread * 2 + 70) * e),
      child: Transform.rotate(
        angle: spin * e * math.pi / 180,
        child: Opacity(
          opacity: fade.clamp(0.0, 1.0),
          child: RepaintBoundary(
            child: ClipRect(
              clipper: _ShardCell(col, row),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShardCell extends CustomClipper<Rect> {
  const _ShardCell(this.col, this.row);

  final int col;
  final int row;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(
    size.width * col / shatterCols,
    size.height * row / shatterRows,
    size.width / shatterCols,
    size.height / shatterRows,
  );

  @override
  bool shouldReclip(_ShardCell old) => old.col != col || old.row != row;
}
