/// The celebration a merge lands with.
///
/// Merging is the game's core action and it landed in silence: two cards
/// became one with no acknowledgement at all.
///
/// The JS flies a ghost of the source card into the target, bursts particles
/// and flashes the cell. The FLY is not ported here — the drag has already
/// carried the card there under the player's own finger, and `merge_grid.dart`
/// owns the flight for the case that needs one. What is ported is the payoff.
///
/// **All four layers of it, because a merge is the loop's payoff.** The port had
/// the shape of the burst and none of its weight: twenty-odd theme-coloured dots
/// on fixed spokes, a half-second sine swell, and nothing else. The JS is a
/// set-piece and says so in its own comment — *"merging is the game's tentpole
/// moment, it should feel like a win, not a UI transition"*. Four things make it
/// one, and the port had one and a half of them:
///
/// 1. **The pop**, which is a squash into a stretch into an elastic settle over
///    a full second, pivoted on the card's bottom edge — `anim/gsapMerge.js`.
///    A symmetric swell is a card breathing; this is a card landing.
/// 2. **The flash** — `brightness(3) saturate(2)` decaying over 350ms, so the
///    cell itself blows out white for an instant.
/// 3. **The rings**: one shockwave, two from tier four, three from tier seven,
///    each delayed behind the last so it reads as a wave expanding rather than
///    as a flash.
/// 4. **The particles**, in the TIER's colours rather than the kit's, with the
///    JS's own spread of size, speed, spin and gravity, and its counts —
///    eighteen, twenty-six at a star, thirty-eight at a legend.
///
/// Every piece is derived from a stable per-burst hash rather than from
/// `Random`, and that is not tidiness: a painter that rolls dice inside `paint`
/// re-rolls them on every frame, so the pieces would flicker to new positions
/// sixty times a second instead of flying. The seed changes per burst, so two
/// merges do not land in the same shape.
library;

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/screens/grid/smoke_puff.dart';

/// The whole set-piece: the JS's GSAP timeline end to end — a 90ms squash, a
/// 150ms stretch, and an 850ms elastic settle.
const Duration mergeBurstDuration = Duration(milliseconds: 1090);

const Duration _squash = Duration(milliseconds: 90);
const Duration _stretch = Duration(milliseconds: 150);

/// The blow-out on the cell itself.
const Duration _flash = Duration(milliseconds: 350);

/// Particles per burst, by tier — the JS's 18 / 26 / 38. It had been `6 + tier
/// * 2`, which tops out at 24 for a Legend: fewer pieces for the rarest merge in
/// the game than the JS spends on a bronze one.
int particlesForTier(int tier) => tier >= 7
    ? 38
    : tier >= 5
    ? 26
    : 18;

/// Shockwaves: one, two from tier four, three from tier seven.
int ringsForTier(int tier) => tier >= 7
    ? 3
    : tier >= 4
    ? 2
    : 1;

/// How hard the card pops. The JS: a legendary merge should feel heaviest.
double peakForTier(int tier) => tier >= 7
    ? 1.34
    : tier >= 5
    ? 1.26
    : 1.18;

/// The JS's `TIER_PARTICLES` — bronze, then silver, then gold, then the purple
/// of a legend, and a tier eight that throws everything at once.
///
/// A tier the table does not name falls back to gold, exactly as the JS's `??`
/// does, so a merge past the end of the ladder still celebrates.
const Map<int, List<Color>> _tierColours = {
  1: [Color(0xFFCD7F32), Color(0xFFA05A2C), Color(0xFFE8A060)],
  2: [Color(0xFFCD7F32), Color(0xFFE8C080), Color(0xFFFFD580)],
  3: [Color(0xFFC0C0C0), Color(0xFFE8E8E8), Color(0xFFA0A0A0)],
  4: [Color(0xFFC0C0C0), Color(0xFF90A4AE), Color(0xFFFFFFFF)],
  5: [Color(0xFFFFD700), Color(0xFFFFE066), Color(0xFFFFB300)],
  6: [Color(0xFFFFD700), Color(0xFFFF8F00), Color(0xFFFFE082)],
  7: [Color(0xFFB06AFF), Color(0xFFE040FB), Color(0xFFCE93D8)],
  8: [
    Color(0xFFFFD700),
    Color(0xFFB06AFF),
    Color(0xFFFFFFFF),
    Color(0xFFFF4081),
  ],
};

/// A card being cashed in rather than kept. The JS's note is the whole reason
/// it is a separate palette: the burst should read as money, not as the tier the
/// card happened to be.
const List<Color> _coinColours = [
  Color(0xFFFFD45E),
  Color(0xFFFFB300),
  Color(0xFFFFF3C4),
];

List<Color> mergeBurstColours(int tier, {bool coins = false}) =>
    coins ? _coinColours : (_tierColours[tier] ?? _tierColours[5]!);

class MergeBurst extends StatefulWidget {
  const MergeBurst({
    super.key,
    required this.child,
    required this.tier,
    required this.playing,
    this.onDone,
    this.duration = mergeBurstDuration,
    this.coins = false,
    this.pop = true,
    this.particles,
  });

  final Widget child;
  final int tier;

  /// Flipped true for one merge; the burst runs once and reports back.
  final bool playing;
  final VoidCallback? onDone;

  /// Overridable for the scout reveal's cash-in, which holds its backdrop up for
  /// its own window and must not be left waiting on a settle it never shows.
  final Duration duration;

  /// Money rather than tier: a card being sold, not merged.
  final bool coins;

  /// The squash-stretch-settle on the card itself. Off for a card that is coming
  /// apart — popping something on its way out is two stories at once.
  final bool pop;

  /// How many pieces, where the tier's own count is the wrong answer. Null takes
  /// [particlesForTier].
  ///
  /// The cash-in is the case: the JS spends a flat twenty-two on it whatever the
  /// card was, because the burst is about the MONEY and a legend being sold
  /// should not throw more coins than a bronze one fetched.
  final int? particles;

  @override
  State<MergeBurst> createState() => MergeBurstState();
}

class MergeBurstState extends State<MergeBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  /// Bumped per burst, so consecutive merges do not land in the same shape while
  /// each one stays stable across its own repaints.
  int _seed = 0;

  /// Test seam.
  bool get isPlaying => _controller.isAnimating;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone?.call();
    });
    if (widget.playing) _start();
  }

  @override
  void didUpdateWidget(MergeBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing && !oldWidget.playing) _start();
  }

  void _start() {
    _seed++;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduce-motion keeps the merge and drops the celebration. The burst is
    // decoration — what a merge DID is on the card and in the HUD, and the
    // timing is unchanged so nothing downstream waits a different length.
    final still = MediaQuery.disableAnimationsOf(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final v = _controller.value;
        if (v == 0 || v == 1 || still) return child!;
        final ms = v * widget.duration.inMilliseconds;

        Widget body = child!;
        if (widget.pop) {
          final at = _popAt(ms, widget.tier, widget.duration);
          body = Transform(
            // Pivoted on the bottom edge, as the JS sets `transform-origin`:
            // the card grows UP out of its square rather than swelling out of
            // its own middle, which is what makes it read as landing.
            alignment: Alignment.bottomCenter,
            transform: Matrix4.diagonal3Values(at.x, at.y, 1),
            child: body,
          );
          if (ms < _flash.inMilliseconds) {
            final t = Curves.easeOut.transform(ms / _flash.inMilliseconds);
            body = ColorFiltered(
              colorFilter: ColorFilter.matrix(
                _blowOut(lerpDouble(3, 1, t)!, lerpDouble(2, 1, t)!),
              ),
              child: body,
            );
          }
        }

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            body,
            // **THE SMOKE GOES UNDER THE BURST, and only under it.**
            // `docs/REMAINING.md` names the trap: the burst is procedural and
            // draws in whatever colour the tier calls for, which a sprite sheet
            // cannot do — so the sprite may not replace it. Smoke can sit
            // beneath it because smoke is COLOURLESS: it reads as displaced air
            // rather than as a second opinion about what tier the card was.
            //
            // Behind `body` in the stack would put it behind the card; here it
            // is over the card and under the sparks, which is where displaced
            // air belongs.
            Positioned.fill(
              child: Center(
                child: SmokePuff(
                  playing: widget.playing,
                  // Wider than the square it happens in, because smoke that
                  // stops at the card's edge reads as a texture on the card.
                  size: mergeSmokeSpread,
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _BurstPainter(
                    ms: ms,
                    tier: widget.tier,
                    seed: _seed,
                    colours: mergeBurstColours(
                      widget.tier,
                      coins: widget.coins,
                    ),
                    count: widget.particles ?? particlesForTier(widget.tier),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

/// How wide the merge's own puff is drawn.
///
/// Wider than a grid square on purpose: smoke that stops at the card's edge
/// reads as a texture printed on the card rather than as air being pushed out
/// of the way.
const double mergeSmokeSpread = 120;

/// Where the pop is at, in x and y — the JS's three tweens, back to back.
///
/// The settle overshoots past 1 and decays into it, which is the one thing a
/// keyframe list cannot say and the reason the JS reaches for GSAP at all.
({double x, double y}) _popAt(double ms, int tier, Duration whole) {
  final peak = peakForTier(tier);
  final squash = _squash.inMilliseconds.toDouble();
  final stretched = squash + _stretch.inMilliseconds;

  if (ms <= squash) {
    final t = Curves.easeOutQuad.transform((ms / squash).clamp(0.0, 1.0));
    return (x: lerpDouble(1, 1.16, t)!, y: lerpDouble(1, 0.84, t)!);
  }
  if (ms <= stretched) {
    final t = Curves.easeOutQuad.transform(
      ((ms - squash) / _stretch.inMilliseconds).clamp(0.0, 1.0),
    );
    return (
      x: lerpDouble(1.16, peak * 0.93, t)!,
      y: lerpDouble(0.84, peak, t)!,
    );
  }
  final settle = (whole.inMilliseconds - stretched).clamp(1.0, double.infinity);
  final t = const ElasticOutCurve(
    0.42,
  ).transform(((ms - stretched) / settle).clamp(0.0, 1.0));
  return (x: lerpDouble(peak * 0.93, 1, t)!, y: lerpDouble(peak, 1, t)!);
}

/// `brightness(k) saturate(s)`, multiplied out into the one matrix a
/// [ColorFilter] takes. The JS applies the two CSS filters together.
List<double> _blowOut(double k, double s) {
  const lr = 0.213, lg = 0.715, lb = 0.072;
  double m(double l, bool own) => k * (l + (own ? s * (1 - l) : -s * l));
  return <double>[
    m(lr, true), m(lg, false), m(lb, false), 0, 0, //
    m(lr, false), m(lg, true), m(lb, false), 0, 0, //
    m(lr, false), m(lg, false), m(lb, true), 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

/// `cubic-bezier(0, 0.9, 0.57, 1)` — off the mark instantly and a long tail,
/// which is what makes a piece read as thrown rather than as drifting.
const Curve _thrown = Cubic(0, 0.9, 0.57, 1);

/// A stable value in `[0, 1)` for piece [i] on stream [stream] of burst [seed].
/// A hash, not a die: see the note at the top of the file.
///
/// Shared, because the card shatter has the same problem and the same reason
/// for it — a piece whose flight is re-rolled every frame flickers instead of
/// flying.
double burstHash(int seed, int i, int stream) {
  var h =
      (seed * 0x27D4EB2D) ^ ((i + 1) * 0x9E3779B1) ^ ((stream + 1) * 0x85EBCA6B);
  h &= 0xFFFFFFFF;
  h ^= h >> 15;
  h = (h * 0x2545F491) & 0xFFFFFFFF;
  h ^= h >> 13;
  return (h & 0xFFFFFF) / 0x1000000;
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter({
    required this.ms,
    required this.tier,
    required this.seed,
    required this.colours,
    required this.count,
  });

  final double ms;
  final int tier;
  final int seed;
  final List<Color> colours;

  /// How many pieces. Off the tier unless the caller says otherwise.
  final int count;

  double _at(int i, int stream) => burstHash(seed, i, stream);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || ms <= 0) return;
    final centre = Offset(size.width / 2, size.height / 2);
    // Every JS distance is in pixels against a cell about 110 wide. Scaled off
    // the cell instead, so the burst is the same burst on a phone and a tablet.
    final unit = size.shortestSide / 110;

    _rings(canvas, centre, unit);
    _particles(canvas, centre, unit);
  }

  /// The shockwaves, each one starting behind the last.
  void _rings(Canvas canvas, Offset centre, double unit) {
    final rings = ringsForTier(tier);
    final born =
        (tier >= 7
            ? 80.0
            : tier >= 5
            ? 60.0
            : 44.0) *
        unit /
        2;
    for (var w = 0; w < rings; w++) {
      final t = ((ms - w * 120) / (550 + w * 150)).clamp(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;
      final e = Curves.easeOut.transform(t);
      canvas.drawCircle(
        centre,
        born * (3 + w * 0.8) * e,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * unit
          ..color = colours[w % colours.length].withValues(
            alpha: 0.85 * (1 - e),
          ),
      );
    }
  }

  void _particles(Canvas canvas, Offset centre, double unit) {
    for (var i = 0; i < count; i++) {
      final t = (ms / (800 + _at(i, 0) * 500)).clamp(0.0, 1.0);
      if (t >= 1) continue;
      final e = _thrown.transform(t);

      // Spokes with a little jitter on them: the shape is the game's own
      // punctuation, and a wholly random scatter reads as noise.
      final angle = i / count * math.pi * 2 + _at(i, 1) * 0.6;
      final speed = (60 + _at(i, 2) * 110) * unit;
      final piece =
          centre +
          Offset(
            math.cos(angle) * speed * e,
            // The `+ 30` is the JS's gravity: every piece sags as it flies.
            (math.sin(angle) * speed + 30 * unit) * e,
          );

      final half = (4 + _at(i, 3) * (tier >= 6 ? 8 : 5)) * unit / 2 * (1 - e);
      if (half <= 0) continue;
      final colour =
          colours[(_at(i, 4) * colours.length).floor() % colours.length];
      final fade = colour.withValues(alpha: 1 - e);

      // `box-shadow: 0 0 (size + 4)px`, drawn as a wider translucent copy
      // rather than a blur: a `MaskFilter` per piece is a saveLayer per piece,
      // and thirty-eight of them lands on exactly the frame the player is
      // waiting for.
      canvas.drawCircle(
        piece,
        half * 2.2,
        Paint()..color = colour.withValues(alpha: 0.22 * (1 - e)),
      );

      // Half of a star merge's pieces are squares on the turn, as the JS's
      // `isStarAt` makes them — it is the cheapest way for a rare merge to look
      // like a different event rather than a louder one.
      if (tier >= 5 && _at(i, 5) > 0.5) {
        canvas.save();
        canvas.translate(piece.dx, piece.dy);
        canvas.rotate(math.pi / 4 + (_at(i, 6) - 0.5) * 4 * math.pi * e);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: half * 2,
            height: half * 2,
          ),
          Paint()..color = fade,
        );
        canvas.restore();
      } else {
        canvas.drawCircle(piece, half, Paint()..color = fade);
      }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.ms != ms || old.tier != tier || old.seed != seed;
}
