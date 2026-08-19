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
/// **The backdrop deliberately does NOT scale with him.** The stand and the
/// crowd are parallax strips sized to the viewport; scaling them would crop the
/// stand out of the top of the frame. He reads as a longer lens on the same
/// scene rather than a step closer.
///
/// This is the information-carrying half of the JS's 6,777-line scene — the
/// depth, the speeds and their relationship to his stride. The ball simulation,
/// the mowing fan's true conic sweep, the crowd sprites and the six stadium tiers
/// are not here; what IS here is the arithmetic that has to hold, so anything
/// added later has a floor to build on rather than a number to guess.
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

/// How big he renders. 1.2 → 1.5 → 1.35: at 1.2 he was a detail in a wide shot
/// and the gestures, kit and look packs did not read; 1.5 read but crowded the
/// frame on a notched phone. 1.35 is the settled middle, and it is the size the
/// figure was TUNED at — so it is a ceiling, not a target.
const double walkerScale = 1.35;

/// How far up he stands, measured from the footer rather than off a percentage of
/// the page, so the bottom of the screen reads as one group however tall the
/// footer gets.
const double walkerBottomClearance = 58;

class PitchScene extends StatelessWidget {
  const PitchScene({
    super.key,
    required this.mood,
    required this.walker,
    this.footerHeight = 150,
  });

  final Mood mood;

  /// The figure. Passed in rather than built here so the scene stays about the
  /// GROUND and the rig stays about the body.
  final Widget walker;

  /// Measured, not assumed: the footer's height moves with the cup button, Pro
  /// mode and the event strip.
  final double footerHeight;

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
        final feet = h - (footerHeight + walkerBottomClearance);
        final horizon = (feet - walkerHeight * walkerScale).clamp(
          h * 0.16,
          h * 0.62,
        );

        return ClipRect(
          child: Stack(
            children: [
              const Positioned.fill(child: _Sky()),
              // The far strip: the stand and its crowd, at 16.5s — slow, because
              // distance is speed on a parallax scene.
              Positioned(
                left: 0,
                right: 0,
                top: horizon - h * 0.24,
                height: h * 0.24,
                child: _Scroller(
                  key: const ValueKey('pitch-stand'),
                  duration: const Duration(milliseconds: 16500),
                  segmentWidth: w,
                  child: _Stand(width: w, height: h * 0.24),
                ),
              ),
              // The hoardings run at ~40px/s, which is the turf just short of the
              // horizon — they sit on it, so they have to travel with it.
              Positioned(
                left: 0,
                right: 0,
                top: horizon - 14,
                height: 14,
                child: _Scroller(
                  duration: Duration(
                    microseconds:
                        (grassDuration(mood).inMicroseconds * 2.1).round(),
                  ),
                  segmentWidth: 120,
                  child: const _Hoarding(),
                ),
              ),
              Positioned(
                key: const ValueKey('pitch-turf'),
                left: 0,
                right: 0,
                top: horizon,
                bottom: 0,
                child: _Turf(mood: mood, width: w),
              ),
              // He stands LEFT of centre, on the grass under the horizon, and the
              // scale is about his FEET so he stays planted however big he gets.
              Positioned(
                left: w * 0.45 - 57,
                bottom: footerHeight + walkerBottomClearance,
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

/// A terrace of stands with a crowd in it. One segment, tiled by [_Scroller].
class _Stand extends StatelessWidget {
  const _Stand({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: const CustomPaint(painter: _StandPainter()),
  );
}

class _StandPainter extends CustomPainter {
  const _StandPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // The stand itself: a dark bank rising to a roof line.
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.35, size.width, size.height * 0.65),
      Paint()..color = const Color(0xFF243642),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.28, size.width, size.height * 0.09),
      Paint()..color = const Color(0xFF1A2731),
    );

    // The crowd, as banded speckle. Deterministic — a seeded generator, because
    // a crowd that reshuffles every frame reads as static rather than as people.
    final rng = math.Random(7);
    const crowdColours = [
      Color(0xFF8A94A3),
      Color(0xFFB9C2CE),
      Color(0xFF6D7889),
      Color(0xFFD6C9A8),
    ];
    final top = size.height * 0.4;
    final bottom = size.height * 0.94;
    for (var y = top; y < bottom; y += 4.5) {
      for (var x = 1.0; x < size.width; x += 5) {
        if (rng.nextDouble() < 0.55) continue;
        canvas.drawCircle(
          Offset(x + rng.nextDouble() * 2, y),
          1.3,
          Paint()..color = crowdColours[rng.nextInt(crowdColours.length)],
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StandPainter old) => false;
}

class _Hoarding extends StatelessWidget {
  const _Hoarding();

  @override
  Widget build(BuildContext context) => Container(
    width: 120,
    decoration: const BoxDecoration(
      color: Color(0xFF14202A),
      border: Border(
        top: BorderSide(color: Color(0xFF2B3E4C)),
        right: BorderSide(color: Color(0xFF0C141B)),
      ),
    ),
  );
}

/// The ground: mown stripes, then the three tuft bands over them.
class _Turf extends StatelessWidget {
  const _Turf({required this.mood, required this.width});

  final Mood mood;
  final double width;

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
          segmentWidth: 84,
          child: const _MownSegment(),
        ),
        // Aerial perspective: the turf DARKENS toward the horizon, so distance
        // reads as distance rather than as a paler green.
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99000000), Color(0x1A000000), Colors.transparent],
                stops: [0, 0.35, 1],
              ),
            ),
          ),
        ),
        // Each band sits at its own depth and travels at the fan's speed there.
        // Band 0 is his own grass and runs at exactly his stride.
        for (var band = 0; band < tuftBandRatios.length; band++)
          Positioned(
            left: 0,
            right: 0,
            // Band 2 is the far touchline, band 0 the grass at his boots.
            top: null,
            bottom: [0.0, 0.3, 0.62][band] * 100,
            height: 14,
            child: _Scroller(
              duration: Duration(
                microseconds:
                    (grass.inMicroseconds * tuftBandRatios[band]).round(),
              ),
              segmentWidth: 96,
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
    width: 84,
    child: Row(
      children: [
        Expanded(child: ColoredBox(color: Color(0xFF2E7D3A))),
        Expanded(child: ColoredBox(color: Color(0xFF276E33))),
      ],
    ),
  );
}

class _TuftSegment extends StatelessWidget {
  const _TuftSegment({required this.band});

  final int band;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 96,
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
    // Further away is smaller and flatter — the tuft is the same grass seen from
    // further up the pitch.
    final scale = 1 - band * 0.28;
    final paint = Paint()
      ..color = Color.lerp(
        const Color(0xFF48A055),
        const Color(0xFF2F6B39),
        band / 2,
      )!
      ..strokeWidth = 1.2 * scale
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < 7; i++) {
      final x = rng.nextDouble() * size.width;
      final base = size.height * (0.7 + rng.nextDouble() * 0.25);
      final tall = (3 + rng.nextDouble() * 4) * scale;
      for (var blade = -1; blade <= 1; blade++) {
        canvas.drawLine(
          Offset(x + blade * 1.4 * scale, base),
          Offset(x + blade * 2.6 * scale, base - tall),
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
                  children: [
                    for (var i = 0; i < count; i++) widget.child,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
