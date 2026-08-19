/// The diorama the manager walks on. Ported from `components/PitchScene.js` and
/// `styles/league-scene.css`.
///
/// The port had him standing on a flat two-stop gradient, which is what made him
/// read as a paper doll pinned to a wall: **a walk cycle with nothing moving
/// under it is not walking**, it is a man treading air.
///
/// **THE GRASS IS TIMED OFF HIS STRIDE, not off a number.** It used to be a flat
/// 5s in the JS too, "matched to the walk cycle" — but the stride swings 1.45s to
/// 2.3s with his mood, so one fixed ground speed could only plant his feet in one
/// of five moods: in the others he skated, forwards when cheerful and backwards
/// when fed up. [grassDuration] is the stride times [_grassRatio], and every
/// other speed on the surface is a fixed RATIO of that.
///
/// **The tufts travel at the speed of the turf they stand in.** Not
/// approximately: a tuft is a clump of the same grass the stripes are mown into,
/// and if it slides against them at all both layers stop being ground and become
/// wallpaper. That reads instantly even when neither speed is wrong on its own.
/// The three bands are the fan's own proportions at three depths.
///
/// **Every surface here is PAINTED, not laid out.** That is not a style
/// preference, it is the fix for the bug that had no pitch on the screen at all:
/// a scrolling segment is handed its height by the strip above it, and any
/// widget in the chain that passes LOOSE constraints to a childless box collapses
/// that box to nothing. It happened twice — once at the scroller's own `Row`,
/// and again inside the mown segment, where two `Expanded` `ColoredBox`es came
/// out 42×0 under the default centre alignment and the whole pitch painted as
/// sky. A `CustomPaint` has no children to hand constraints to, so it cannot
/// lose them; every segment also names `double.infinity` for its height, which
/// fills the strip whether the incoming constraint is tight or loose.
///
/// **The backdrop deliberately does NOT scale with him.** The stand and the
/// crowd are parallax strips sized to the viewport; scaling them would crop the
/// stand out of the top of the frame. He reads as a longer lens on the same
/// scene rather than a step closer.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart'
    show walkerHeight, walkerWidth;

/// One stride, by mood. The JS's `--walk-dur` per `data-mood`.
Duration walkDurationFor(Mood mood) => switch (mood) {
  Mood.elated => const Duration(milliseconds: 1450),
  Mood.pleased => const Duration(milliseconds: 1620),
  Mood.neutral => const Duration(milliseconds: 1800),
  Mood.glum => const Duration(milliseconds: 2050),
  Mood.crushed => const Duration(milliseconds: 2300),
};

/// `5s / 1.8s`. The only free number on the grass: it lands the neutral mood on
/// exactly the 84px/s this scene was drawn and tuned around, and everything else
/// is a ratio of it.
const double _grassRatio = 2.7778;

Duration grassDuration(Mood mood) => Duration(
  microseconds: (walkDurationFor(mood).inMicroseconds * _grassRatio).round(),
);

/// The three depth bands, each matched to the mowing fan's sweep at the middle
/// of its own band. Band 0 is the grass he is standing in, so it runs at exactly
/// his speed; the other two keep the fan's proportions against it.
const List<double> tuftBandRatios = [1.0, 1.1515, 1.3737];

/// The JS's `SEG_GROUND` and `SEG_FAR`. One segment per loop wraps seamlessly,
/// so these are the periods everything on their strip is drawn against — and
/// they are FIXED rather than viewport-derived, which is what keeps the seeded
/// arrangement identical on every screen size.
const double groundSegmentWidth = 420;
const double farSegmentWidth = 480;

/// The ad boards on the horizon.
const double hoardingHeight = 13;

/// Two lanes to a segment: 42px each, and 42 divides 420 ten times.
const double mownSegmentWidth = 84;

/// Where the tufts live, as a fraction of the way up the pitch box. Not pixels:
/// they used to be `[0, 30, 62]px` off the bottom edge, which crammed all three
/// depth bands into the nearest 60px and left the whole middle of the pitch
/// bare — the JS scatters them from 34% to 96% and lets each band own a third
/// of that range.
const double tuftFMin = 0.34;
const double tuftFMax = 0.96;

/// Per band, per 420px segment. Sparse on purpose: this is a kept pitch, and the
/// port drew 7 clumps per 96px in every band, which read as moss.
const int _tuftsPerBand = 3;

/// How big he renders. 1.2 → 1.5 → 1.35: at 1.2 he was a detail in a wide shot
/// and the gestures, kit and look packs did not read; 1.5 read but crowded the
/// frame on a notched phone. 1.35 is the settled middle, and it is the size the
/// figure was TUNED at — so it is a ceiling, not a target.
const double walkerScale = 1.35;

/// How far up he stands, measured from the footer rather than off a percentage of
/// the page, so the bottom of the screen reads as one group however tall the
/// footer gets.
///
/// The JS stacks this up rather than picking it, and the stack is worth keeping
/// in front of you: the footer floats 10px up, the CUSTOMISE pill sits 12px
/// above that, the pill is ~23px tall, and he stands 12px clear of it. Anything
/// that moves one of those has to move this, which is why [PitchScene] takes the
/// contact line itself — the home screen MEASURES the pill and passes the
/// answer, rather than two places agreeing on paper and disagreeing on screen.
const double walkerBottomClearance = 57;

class PitchScene extends StatelessWidget {
  const PitchScene({
    super.key,
    required this.mood,
    required this.walker,
    this.kitColor = const Color(0xFF4CAF50),
    this.walkerBottom = 150 + walkerBottomClearance,
  });

  final Mood mood;

  /// The figure. Passed in rather than built here so the scene stays about the
  /// GROUND and the rig stays about the body.
  final Widget walker;

  /// The club's colour. Some of the crowd wear it — support that grows with you
  /// is the one thing the stand can say about the season.
  final Color kitColor;

  /// His contact line, above the scene's bottom edge. MEASURED by the caller:
  /// the pill he stands over moves with the footer, and a constant would be
  /// wrong the first frame an event strip appeared.
  final double walkerBottom;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        // Where the grass meets the stand: everything above is backdrop,
        // everything below is ground.
        //
        // Placed above HIS FEET rather than at a flat 46% of the page. The
        // fraction was fine until the next-match card grew to five bands and the
        // footer to three: between them the visible strip of grass closed up, and
        // 46% of the page could land BELOW the man standing on it. The horizon
        // now sits a walker's height above his contact line, which is what makes
        // it a horizon rather than a number — and it can never crowd him out,
        // because it is derived from where he is.
        final feet = h - walkerBottom;
        final horizon = (feet - walkerHeight * walkerScale).clamp(
          h * 0.16,
          h * 0.62,
        );

        return ClipRect(
          child: Stack(
            children: [
              const Positioned.fill(child: _Sky()),
              // The far strip: the stand and its crowd, at 16.5s — slow, because
              // distance is speed on a parallax scene. Its height is the TERRACE's
              // own, not a fraction of the page: at `h * 0.24` it was a 200px bank
              // of seats with a hundred 1px dots in it, which is the shape of a
              // crowd without being one.
              Positioned(
                left: 0,
                right: 0,
                // ON the ad boards, not behind them: the stand's foot is the
                // back of the board, which is what puts the perimeter in front
                // of the front row instead of across its knees.
                top: horizon - standHeight - hoardingHeight,
                height: standHeight,
                child: _Scroller(
                  key: const ValueKey('pitch-stand'),
                  duration: const Duration(milliseconds: 16500),
                  segmentWidth: farSegmentWidth,
                  child: _StandSegment(kitColor: kitColor),
                ),
              ),
              // The hoardings run at ~40px/s, which is the turf just short of the
              // horizon — they sit on it, so they have to travel with it.
              Positioned(
                left: 0,
                right: 0,
                top: horizon - hoardingHeight,
                height: hoardingHeight,
                child: _Scroller(
                  duration: Duration(
                    microseconds: (grassDuration(mood).inMicroseconds * 2.1)
                        .round(),
                  ),
                  segmentWidth: 240,
                  child: _HoardingSegment(kitColor: kitColor),
                ),
              ),
              Positioned(
                key: const ValueKey('pitch-turf'),
                left: 0,
                right: 0,
                top: horizon,
                bottom: 0,
                child: _Turf(mood: mood),
              ),
              // He stands LEFT of centre, on the grass under the horizon, and the
              // scale is about his FEET so he stays planted however big he gets.
              Positioned(
                left: w * 0.45 - 57,
                bottom: walkerBottom,
                // His OWN box, at his own size — not whatever is left of the
                // screen. He is 120×170 and scaled 1.35 about his feet, which is
                // ~162×230 on screen; handed the column's remaining height he
                // filled it, which is what made him tower over the pitch. The
                // box also has to be bounded: the rig is an `AspectRatio` and an
                // unbounded one cannot lay itself out at all.
                child: SizedBox(
                  width: walkerWidth,
                  height: walkerHeight,
                  child: Transform.scale(
                    scale: walkerScale,
                    alignment: Alignment.bottomCenter,
                    child: walker,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Sky extends StatelessWidget {
  const _Sky();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1B3A57), Color(0xFF2E5A74), Color(0xFF6E8FA0)],
        stops: [0, 0.55, 1],
      ),
    ),
  );
}

// ── The stand ───────────────────────────────────────────────────────────────
// The terrace and the people in it, at the JS's own proportions.
//
// The port had the crowd as banded speckle — a 1.3px dot per fan, seeded so it
// would not reshuffle. Seeded was right and a dot was not: at this distance a
// supporter is still a HEAD over a pair of shoulders, and it is the head that
// makes a row of them read as people rather than as noise. Each fan here is the
// JS's three shapes — torso, head, sleeve bar — all sized off one number, their
// shoulder width, exactly as `.ps-fan` sizes itself off `--fan`.

/// The JS's `CROWD_SCALE`.
const double _crowdScale = 1.12;

/// Rows in the terrace, back to front.
const int _crowdRows = 6;

/// Seat-row spacing and the dead terrace under the front row, before scale. 6
/// rather than the 14 it started at: at 14 there was an empty band along the
/// bottom of the deck that read as an unsold front row.
const double _rowPitch = 9;
const double _deckPad = 6;

/// The fascia over the back row. Static in the JS on purpose — a uniform beam
/// shows no motion, and the crowd scrolls underneath it.
const double _roofHeight = 9;

/// How many fans across one 480px segment. Row pitch and fan size scale
/// together or the rows drift out of the stand.
const int _fansPerRow = 26;

double get _deckHeight =>
    ((_deckPad + _crowdRows * _rowPitch) * _crowdScale).roundToDouble();

/// The whole silhouette, roof included. Exported because the horizon is where
/// the stand's FOOT goes, so the caller has to know how tall it is.
double get standHeight => _deckHeight + _roofHeight;

/// The JS's `FAN_COLORS`. Bright and few: a crowd is mostly replica shirts.
const List<Color> _fanColours = [
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFFFDD835),
  Color(0xFFF5F5F5),
  Color(0xFF8E24AA),
  Color(0xFFFB8C00),
  Color(0xFF26C6DA),
  Color(0xFFCFD8DC),
];

/// Skin variety, which the JS gets out of `nth-child` selectors for nothing.
const List<Color> _fanSkins = [
  Color(0xFFD8A982),
  Color(0xFFB9825A),
  Color(0xFF8A5A37),
  Color(0xFFF0C9A5),
  Color(0xFF5F3A22),
];

class _StandSegment extends StatelessWidget {
  const _StandSegment({required this.kitColor});

  final Color kitColor;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('pitch-stand-segment'),
    width: farSegmentWidth,
    height: double.infinity,
    child: CustomPaint(painter: _StandPainter(kitColor: kitColor)),
  );
}

class _StandPainter extends CustomPainter {
  const _StandPainter({required this.kitColor});

  final Color kitColor;

  @override
  void paint(Canvas canvas, Size size) {
    final deckTop = _roofHeight;
    final deckRect = Rect.fromLTRB(0, deckTop, size.width, size.height);

    // The terrace: a dark bank, with the seat rows as hairlines in it.
    canvas.drawRect(
      deckRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF39424E), Color(0xFF262E38)],
        ).createShader(deckRect),
    );
    final seatLine = Paint()..color = const Color(0x0FFFFFFF);
    for (var y = deckTop; y < size.height; y += 7) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), seatLine);
    }

    // The people. Seeded, so a re-render reproduces the identical crowd — a
    // stand that reshuffles between frames reads as static rather than as
    // people. Rows run BACK to front: row 0 is highest and smallest, and
    // because it is painted first the row in front of it overlaps it, which is
    // the whole reason the rows read as depth.
    final rng = math.Random(7);
    final deckH = size.height - deckTop;
    for (var row = 0; row < _crowdRows; row++) {
      // The JS's `y`, measured down from the deck's own top edge.
      final y = (_deckPad - 1 + row * _rowPitch) * _crowdScale;
      // The back rows are further away, so they are smaller.
      final shoulder =
          (7 - math.min(2.5, (_crowdRows - 1 - row) * 0.5)) * _crowdScale;
      if (y + shoulder > deckH) continue;
      for (var i = 0; i < _fansPerRow; i++) {
        final x =
            (i + 0.1 + rng.nextDouble() * 0.8) * (size.width / _fansPerRow);
        // Your own colours get commoner as the support grows; the rest of the
        // stand is replica shirts in whatever they turned up in.
        final shirt = rng.nextDouble() < 0.22
            ? kitColor
            : _fanColours[rng.nextInt(_fanColours.length)];
        _paintFan(
          canvas,
          x: x,
          top: deckTop + y,
          shoulder: shoulder,
          shirt: shirt,
          skin: _fanSkins[rng.nextInt(_fanSkins.length)],
        );
      }
    }

    // Aerial haze over the terrace, heaviest at the BACK. Eight replica-shirt
    // colours at full strength is a crowd the size of confetti and twice as
    // loud as the pitch in front of it; the JS keeps the same palette and sits
    // the whole band back under one overlay rather than dulling the individuals
    // — per-fan shading on a few hundred of them is the one cost this scene
    // cannot afford.
    canvas.drawRect(
      deckRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1B3A57).withValues(alpha: 0.42),
            const Color(0xFF1B3A57).withValues(alpha: 0.16),
          ],
        ).createShader(deckRect),
    );

    // The deck falls into shadow at its foot, which is what sits the front row
    // behind a kerb rather than on the grass.
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 6, size.width, 6),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.45)],
        ).createShader(Rect.fromLTWH(0, size.height - 6, size.width, 6)),
    );

    // The fascia over the back row.
    final roof = Rect.fromLTWH(0, 0, size.width, _roofHeight);
    canvas.drawRect(
      roof,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC2CCD6), Color(0xFF828E9A)],
        ).createShader(roof),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, _roofHeight, size.width, 3),
      Paint()..color = Colors.black.withValues(alpha: 0.4),
    );
  }

  /// One supporter, at `.ps-fan`'s geometry. Everything is a multiple of
  /// [shoulder] — the torso box, the head that overlaps its top edge by a hair
  /// so there is no neck gap at 5px, and the sleeve bar across the shoulders.
  void _paintFan(
    Canvas canvas, {
    required double x,
    required double top,
    required double shoulder,
    required Color shirt,
    required Color skin,
  }) {
    final body = Paint()..color = shirt;
    // Sloped shoulders, squarer at the seat.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(x, top, shoulder, shoulder * 0.92),
        topLeft: Radius.circular(shoulder * 0.46),
        topRight: Radius.circular(shoulder * 0.46),
        bottomLeft: Radius.circular(shoulder * 0.2),
        bottomRight: Radius.circular(shoulder * 0.2),
      ),
      body,
    );
    // The sleeves: a bar across the shoulders in the same shirt.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x - shoulder * 0.22,
          top + shoulder * 0.16,
          shoulder * 1.44,
          shoulder * 0.27,
        ),
        Radius.circular(shoulder * 0.14),
      ),
      body,
    );
    canvas.drawCircle(
      Offset(x + shoulder * 0.5, top - shoulder * 0.21),
      shoulder * 0.31,
      Paint()..color = skin,
    );
  }

  @override
  bool shouldRepaint(_StandPainter old) => old.kitColor != kitColor;
}

/// The ad boards on the horizon: panels in the division's colour alternating
/// with white, under a sheen that catches the light along their top edge.
class _HoardingSegment extends StatelessWidget {
  const _HoardingSegment({required this.kitColor});

  final Color kitColor;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 240,
    height: double.infinity,
    child: CustomPaint(painter: _HoardingPainter(kitColor: kitColor)),
  );
}

class _HoardingPainter extends CustomPainter {
  const _HoardingPainter({required this.kitColor});

  final Color kitColor;

  @override
  void paint(Canvas canvas, Size size) {
    final half = size.width / 2;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, half, size.height),
      Paint()..color = kitColor,
    );
    canvas.drawRect(
      Rect.fromLTWH(half, 0, size.width - half, size.height),
      Paint()..color = const Color(0xFFE6E6E6),
    );
    final all = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      all,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.28),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(all),
    );
  }

  @override
  bool shouldRepaint(_HoardingPainter old) => old.kitColor != kitColor;
}

/// The ground: mown stripes, then the three tuft bands over them.
class _Turf extends StatelessWidget {
  const _Turf({required this.mood});

  final Mood mood;

  @override
  Widget build(BuildContext context) {
    final grass = grassDuration(mood);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Mown lanes travelling with the surface. One segment is two lanes, so
        // one segment per loop wraps seamlessly.
        _Scroller(
          key: const ValueKey('pitch-mown'),
          duration: grass,
          segmentWidth: mownSegmentWidth,
          child: const _MownSegment(),
        ),
        // Aerial perspective: the turf DARKENS toward the horizon, so distance
        // reads as distance rather than as a paler green.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.42),
                  Colors.black.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
                stops: const [0, 0.35, 1],
              ),
            ),
          ),
        ),
        // Each band is a FULL-HEIGHT strip whose tufts sit at their own depth
        // inside it, and travels at the mowing fan's speed there. Band 0 is his
        // own grass and runs at exactly his stride.
        for (var band = 0; band < tuftBandRatios.length; band++)
          Positioned.fill(
            child: _Scroller(
              duration: Duration(
                microseconds: (grass.inMicroseconds * tuftBandRatios[band])
                    .round(),
              ),
              segmentWidth: groundSegmentWidth,
              child: _TuftSegment(band: band),
            ),
          ),
      ],
    );
  }
}

class _MownSegment extends StatelessWidget {
  const _MownSegment();

  @override
  Widget build(BuildContext context) => const SizedBox(
    key: ValueKey('pitch-lane'),
    width: mownSegmentWidth,
    // Named rather than inherited: a loose height constraint anywhere above
    // this is what once collapsed the lanes to 42×0 and painted the pitch as
    // sky. `infinity` resolves to whatever the strip's own height is, tight or
    // loose.
    height: double.infinity,
    child: CustomPaint(painter: _MownPainter()),
  );
}

class _MownPainter extends CustomPainter {
  const _MownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final half = size.width / 2;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, half, size.height),
      Paint()..color = const Color(0xFF2E7D3A),
    );
    canvas.drawRect(
      Rect.fromLTWH(half, 0, size.width - half, size.height),
      Paint()..color = const Color(0xFF276E33),
    );
  }

  @override
  bool shouldRepaint(_MownPainter old) => false;
}

class _TuftSegment extends StatelessWidget {
  const _TuftSegment({required this.band});

  final int band;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: groundSegmentWidth,
    height: double.infinity,
    child: CustomPaint(painter: _TuftPainter(band: band)),
  );
}

class _TuftPainter extends CustomPainter {
  const _TuftPainter({required this.band});

  final int band;

  @override
  void paint(Canvas canvas, Size size) {
    // Seeded per band so each depth has its own arrangement and none of them
    // reshuffle between frames.
    final rng = math.Random(31 + band);
    final span = (tuftFMax - tuftFMin) / tuftBandRatios.length;

    for (var i = 0; i < _tuftsPerBand; i++) {
      // How far up the pitch this clump sits. Its band owns a third of the
      // range, so a sparse pitch still spreads its tufts through the depth
      // instead of stacking them at one distance.
      final f = tuftFMin + (band + rng.nextDouble()) * span;
      final depth = (f - tuftFMin) / (tuftFMax - tuftFMin);
      // Fake perspective: the further up the pitch, the smaller.
      final w = math.max(4.0, (9 + rng.nextDouble() * 7) * (1 - depth * 0.55));
      final tall = w * 0.85;
      final x = rng.nextDouble() * size.width;
      final base = size.height * (1 - f);
      final lean = rng.nextDouble() * 8 - 4;

      final paint = Paint()
        ..color = Color.lerp(
          const Color(0xFF48A055),
          const Color(0xFF2F6B39),
          depth,
        )!
        ..strokeWidth = 1.4 * (1 - depth * 0.4)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      // The clump is a run of blades across its own width, which is what the
      // JS's 1.4px-in-3.4px mask over a gradient comes out as.
      for (var bx = 0.0; bx < w; bx += 3.4) {
        final h = tall * (0.65 + rng.nextDouble() * 0.35);
        canvas.drawLine(
          Offset(x + bx, base),
          Offset(x + bx + lean * 0.25, base - h),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TuftPainter old) => old.band != band;
}

/// Tiles [child] across the width and translates by exactly one segment per
/// loop, so the wrap is seamless.
class _Scroller extends StatefulWidget {
  const _Scroller({
    super.key,
    required this.duration,
    required this.segmentWidth,
    required this.child,
  });

  final Duration duration;
  final double segmentWidth;
  final Widget child;

  @override
  State<_Scroller> createState() => _ScrollerState();
}

class _ScrollerState extends State<_Scroller>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
  }

  /// Honours the platform's reduce-motion setting. The scene is decoration on
  /// the screen the app OPENS on, which is exactly the kind of perpetual
  /// movement that setting exists to stop — and it is also what lets a widget
  /// test settle, because a looping animation never does.
  void _sync() {
    final still = MediaQuery.of(context).disableAnimations;
    if (still) {
      if (_c.isAnimating) _c.stop();
      return;
    }
    if (!_c.isAnimating) _c.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Scroller old) {
    super.didUpdateWidget(old);
    // A mood change retimes the surface mid-walk, and it restarts from the top
    // for the same reason his stride does — see `ManagerWalker._sync`.
    if (old.duration != widget.duration) {
      final running = _c.isAnimating;
      _c.stop();
      _c.duration = widget.duration;
      if (running) _c.repeat();
    }
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // One spare segment so the leading edge is always covered.
          final count = (constraints.maxWidth / widget.segmentWidth).ceil() + 2;
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Transform.translate(
              // Right to left: the world moves past him, he walks in place.
              offset: Offset(-_c.value * widget.segmentWidth, 0),
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: count * widget.segmentWidth,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  // STRETCH, not the default centre. A centred child gets LOOSE
                  // height constraints, so a segment that does not name its own
                  // height collapses to nothing — which is exactly what happened
                  // to the turf. Every segment now names `double.infinity` as
                  // well, because this alignment being right was not enough on
                  // its own: the mown lanes had a `Row` of their own inside, and
                  // THAT one handed its `ColoredBox`es loose heights and
                  // collapsed them one level deeper than anyone was looking.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (var i = 0; i < count; i++) widget.child],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
