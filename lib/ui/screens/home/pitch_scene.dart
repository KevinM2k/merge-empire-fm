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
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart'
    show
        walkerAnkle,
        walkerBootSoleY,
        walkerFootOffset,
        walkerHeight,
        walkerHipRise,
        walkerStrideArtUnits,
        walkerWidth;
import 'package:merge_empire_fc/ui/screens/home/pitch_ball.dart';
import 'package:merge_empire_fc/ui/screens/home/pitch_weather.dart';
import 'package:merge_empire_fc/ui/screens/home/walk_ramp.dart';
import 'package:merge_empire_fc/ui/theme/sky.dart';

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

/// How many depth bands the tufts are spread across.
const int _tuftBands = 3;

/// The middle of one band's slice of the tuft range, as a fraction up the pitch
/// box — the same placement `_TuftPainter` scatters within.
double tuftBandFraction(int band) =>
    tuftFMin + (tuftFMax - tuftFMin) * (band + 0.5) / _tuftBands;

/// How far below the mowing fan's apex a row [fraction] of the way up the pitch
/// box sits, in pixels. A ray's speed is proportional to this, which is the whole
/// of the perspective.
double _rowDepth(double fraction, double turfHeight) =>
    _mowApex.abs() * turfHeight + (1 - fraction) * turfHeight;

/// The depth of the row HIS BOOTS are on — the one row whose speed is pinned. See
/// [groundSpeedPxPerSec].
double _contactDepth(double turfHeight, double contactBelowHorizon) =>
    _mowApex.abs() * turfHeight + contactBelowHorizon;

/// How long a [segmentWidth] strip takes to cross a row [fraction] up the pitch
/// box, at the speed the mowing fan sweeps THAT row.
///
/// **THIS IS WHAT STOPS THE TUFTS MOONWALKING, AND THEY WERE.** The bands carried
/// ratios measured against BAND 0, which is not the row the ground's speed is
/// defined at — that is his contact line, lower down the box and so further below
/// the apex. The difference is not small: the whole tuft layer ran 17.7% slower
/// than the mown stripes it grows in, at every band, on every screen. A tuft is a
/// clump of the same grass the stripes are mown into, and if it slides against
/// them at all both layers stop being ground and become wallpaper — which reads
/// instantly even when neither speed is wrong on its own.
///
/// So the solve is against HIS row, exactly as [mowDuration]'s is, and every layer
/// on the turf now takes its speed from the same one place.
Duration turfScroll({
  required double segmentWidth,
  required double fraction,
  required double turfHeight,
  required double contactBelowHorizon,
  required Mood mood,
}) {
  final speed =
      groundSpeedPxPerSec(mood) *
      _rowDepth(fraction, turfHeight) /
      _contactDepth(turfHeight, contactBelowHorizon);
  if (speed <= 0) return const Duration(seconds: 1);
  return Duration(microseconds: (segmentWidth / speed * 1e6).round());
}

/// The JS's `SEG_GROUND` and `SEG_FAR`. One segment per loop wraps seamlessly,
/// so these are the periods everything on their strip is drawn against — and
/// they are FIXED rather than viewport-derived, which is what keeps the seeded
/// arrangement identical on every screen size.
const double groundSegmentWidth = 420;
const double farSegmentWidth = 480;

/// How far above his boots the horizon sits, in walker heights.
///
/// **DERIVED FROM HIM rather than from a percentage of the page**, which is what
/// makes it a horizon instead of a number: the next-match card grew to five bands
/// and the footer to three, and 46% of the page could land BELOW the man standing
/// on it.
///
/// A whole walker's height put the stand in a strip along the top of the frame
/// with a page of empty sky over it — the stadium was on screen and nobody could
/// see it. 0.72 brought it down; **0.55 brings it down again**, and the terrace
/// with it, so the stand sits in the middle of the picture where it can be looked
/// at. He overlaps more of it at this height, which is correct — he is on the
/// pitch, in front of the crowd.
///
/// **It costs nothing in scale.** His size is [walkerScale] about his own contact
/// line, so where the horizon sits cannot change how big he is; what it changes is
/// how much turf there is between him and the boards. That shorter run is paid for
/// by [_mowApex], which recedes harder to match.
const double _horizonAboveBoots = 0.55;

/// The ad boards on the horizon.
const double hoardingHeight = 13;

/// One hoarding loop. Its own width, because the panels are drawn to a rhythm
/// that has nothing to do with the turf's segment.
const double hoardingSegmentWidth = 240;

/// The mowing fan — the mown stripes, in PERSPECTIVE.
///
/// The port had them as flat parallel lanes on a scrolling strip, and both
/// halves of that were wrong. They had no convergence, so the pitch read as a
/// wall of green bands rather than as ground going away from you; and the strip
/// translated ONE 84px segment per `grassDuration` where the JS translates its
/// whole 420px period, so the surface crawled at a fifth of his stride and he
/// moonwalked over it.
///
/// **THE TRICK, and it is the JS's**: paint the fan on a box a THIRD of the
/// pitch's width and stretch it back out. Two problems solve each other. Stripe
/// width here is ANGULAR, and equal angles subtend more pixels the further they
/// sit from the axis, so a full-width fan visibly fattens its lanes at the left
/// and right edges — a third-width box only ever uses the middle ~10° of the
/// fan, where that is under 1%. And stretching horizontally multiplies every
/// ray's horizontal run without touching its vertical one, so the convergence
/// comes out about 3× stronger than the same apex would give at full width.
/// The stretch and the apex are independent dials after that: the stretch for
/// how hard the lanes lean, the apex for the shape of the fall-off.
const double _mowStretch = 2.941;

/// Where the fan converges, in pitch-box heights above the box's top edge.
///
/// **THE STRENGTH OF THE PERSPECTIVE, and the reason the stand can come down.** A
/// ray's horizontal travel per radian is its distance below the apex, so pulling
/// the apex CLOSER to the pitch shortens every one of those distances and widens
/// the gap between them: near grass speeds up relative to far grass, and the
/// surface recedes harder. At -0.95 the near row ran 1.38x the far one; at -0.58
/// it is 1.60x.
///
/// That is what buys the horizon. A shorter run of turf can only read as ground
/// going away from you if it recedes faster — so strengthening this is what lets
/// [_horizonAboveBoots] come down without the pitch flattening into a green band.
///
/// Nothing else needs touching when it moves: [mowDuration] solves the sweep
/// against it, and [turfScroll] solves every strip on the turf against it. Those
/// used to be a constant each, with a comment asking whoever changed one to check
/// the others.
const double _mowApex = -0.58;

/// One lane pair, in radians. The sweep must travel exactly one full period or
/// the loop jumps.
///
/// **Seven degrees, not 5.2.** The lanes are ANGULAR, so widening the period
/// widens every one of them — and the narrow ones read as a texture on the grass
/// rather than as mown bands. [mowDuration] solves the sweep against this, so the
/// grass at his boots keeps its speed whatever the lanes are doing.
final double _mowPeriod = 7 * math.pi / 180;

/// **THE GROUND'S SPEED, DERIVED FROM HIS LEGS.**
///
/// Not a tuned constant and not a ratio of one: his planted foot travels
/// [walkerStrideArtUnits] in half a stride, scaled up by [walkerScale] to reach
/// the screen, so the world has to move exactly that far under him in that time
/// or he skates. The JS carries 84px/s as a hand-checked contract and notes that
/// it goes out of true whenever the pitch's height changes with the viewport;
/// here it falls out of the rig, so it cannot.
double groundSpeedPxPerSec(Mood mood) =>
    groundSpeedTrim *
    walkerStrideArtUnits *
    walkerScale /
    (walkDurationFor(mood).inMicroseconds / 2e6);

/// **HOW FAR THE WORLD HAS TRAVELLED, as a fraction of one half-stride, [u] of
/// the way through it.**
///
/// A constant ground speed cannot match this walk and no trim can rescue it. The
/// JS's tracks are linear in ANGLE, so the supporting ankle's horizontal rate
/// swings from -17 to +173 art units per cycle across one stance while a constant
/// ground sat at 119. That is the foot outrunning the grass by 45% at mid-stance
/// and briefly creeping the wrong way at heel strike — the slip that kept being
/// reported, and it is in the poses, not in the speed.
///
/// So the ground moves at the foot's OWN rate: this is the integral of the
/// supporting boot's horizontal velocity, normalised. A strip driven by it is
/// stationary under the planted foot at every instant, which is what "planted"
/// means — the one property a solved rig gets for free and a played one has to be
/// handed.
///
/// **Whichever boot is lower is carrying him**, and that changes hands twice a
/// cycle, so the velocity has period half a cycle — which is why this is per
/// half-stride.
///
/// Negative velocity is CLAMPED OUT. The support foot really does creep forward
/// for a few per cent either side of each hand-over, and following that exactly
/// would judder the whole world backwards; the JS's own note calls it "the judder
/// as he puts his foot down". A world that never reverses, with a hair of slip in
/// that window, is the better of the two.
final ({List<double> table, double distance}) _groundEase = () {
  const steps = 256;
  double sole(double t, bool near) =>
      walkerBootSoleY(t, near: near) - walkerHipRise(t);
  final out = <double>[0];
  var sum = 0.0;
  for (var i = 0; i < steps; i++) {
    final t = i / steps * 0.5;
    final t2 = (i + 1) / steps * 0.5;
    final near = sole(t, true) >= sole(t, false);
    sum += math.max(
      0,
      walkerAnkle(t, near: near).x - walkerAnkle(t2, near: near).x,
    );
    out.add(sum);
  }
  return (table: [for (final v in out) v / sum], distance: sum);
}();

/// How far the SUPPORTING boot carries the world in one half-stride, in art
/// units.
///
/// **Not [walkerStrideArtUnits], and the difference is the point.** That is the
/// NEAR ankle's displacement across its own nominal stance — 53.05 — while the
/// foot actually carrying him changes hands part way through, and integrating
/// whichever boot is lower gives 51.83. Scaling the ground by the first while
/// warping it by the second is a 2.3% error smeared across every step, which is
/// exactly the kind of thing that reads as a slip and cannot be found by looking.
double get groundHalfStrideArtUnits => _groundEase.distance;

/// [_groundEaseTable], interpolated. 0 at the start of a half-stride, 1 at its end.
double groundEase(double u) {
  final table = _groundEase.table;
  final x = u.clamp(0.0, 1.0) * (table.length - 1);
  final i = x.floor().clamp(0, table.length - 2);
  return table[i] + (table[i + 1] - table[i]) * (x - i);
}

/// How far the world travels in one half-stride, in pixels at his row.
double halfStridePx() =>
    groundSpeedTrim * groundHalfStrideArtUnits * walkerScale;

/// A parallax strip's travel, off the WALK's clock instead of its own.
///
/// **Everything behind the horizon moves because HE is moving**, and none of it
/// used to know that. The stand, the pylons and the advertising each ran an
/// `AnimationController.repeat()` — which is all a fixed speed needs and the
/// wrong thing entirely once the world can stop, because a controller has no
/// rate to vary. So he planted his feet, his legs and the turf eased down, and
/// the whole background kept sliding past a man standing still.
///
/// Given the [period] the strip used to loop on, this is the SAME SPEED restated
/// as a distance: the picture is unchanged while he walks, and it comes to rest
/// with him. Their periods stay their own — a terrace is further away than the
/// grass and moves slower for it — so this converts rather than flattening.
double parallaxOffset(
  double worldX, {
  required double segmentWidth,
  required Duration period,
  required Mood mood,
}) {
  final halfStrideSeconds = walkDurationFor(mood).inMicroseconds / 2e6;
  final contact = halfStridePx() / halfStrideSeconds;
  final seconds = period.inMicroseconds / 1e6;
  if (contact <= 0 || seconds <= 0) return 0;
  return worldX * (segmentWidth / seconds) / contact;
}

/// One clock for everything that is GROUND, handing out how far the world has
/// travelled, in pixels at his row.
///
/// **Every ground layer has to read ONE position rather than run its own clock.**
/// A per-layer clock is fine for a constant speed and impossible for a varying
/// one: the moment the world follows the foot they all have to be warped by the
/// same curve at the same instant, and a `% segmentWidth` taken from a clock that
/// repeats on its own period jumps every time it does.
///
/// The distance only ever grows: a layer takes `worldX x itsRowRatio`, mods it by
/// its own segment width, and stays continuous forever because it never resets.
///
/// **And the clock it reads is the WALKER's**, off [WalkBeat] — see
/// `walk_ramp.dart`. The ground used to own a ticker of its own, kept in step
/// with his legs only by the two starting in the same frame and every stop
/// restarting both from zero. An eased stop restarts nothing, so there is one
/// clock now and this converts it rather than keeping up with it.
class _GroundDrive extends StatelessWidget {
  const _GroundDrive({required this.builder});

  final Widget Function(double worldX) builder;

  @override
  Widget build(BuildContext context) {
    final beat = WalkBeat.maybeOf(context);
    if (beat == null) return builder(0);
    return ValueListenableBuilder<double>(
      valueListenable: beat,
      builder: (context, halfStrides, _) {
        final whole = halfStrides.floor();
        return builder(
          (whole + groundEase(halfStrides - whole)) * halfStridePx(),
        );
      },
    );
  }
}

/// The scene's walk clock: it runs the ticker, eases the world to a stop when he
/// plants his feet, and publishes how many half-strides he has taken.
///
/// **Half-strides is the unit both halves want.** The ground is solved in them —
/// [groundEase] is one stance — and the figure takes the full cycle as
/// `halfStrides / 2`, which is exactly the relationship the two separate clocks
/// used to hold by both starting at zero.
class _WalkBeat extends StatefulWidget {
  const _WalkBeat({
    required this.mood,
    required this.frozen,
    required this.child,
  });

  final Mood mood;

  /// He has planted his feet. Not a switch: the world eases down over
  /// [haltRamp] and back up again after, because he does not brake.
  final bool frozen;

  final Widget child;

  @override
  State<_WalkBeat> createState() => _WalkBeatState();
}

class _WalkBeatState extends State<_WalkBeat>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _halfStrides = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(_onTick);

  /// The ease in progress, stated in the ticker's own elapsed seconds.
  WalkRamp _ramp = const WalkRamp.walking();

  /// The ticker's elapsed at the last frame, and the walking-seconds banked by
  /// then. The beat advances on the DIFFERENCE, so a mood that retimes his
  /// stride changes what a second is worth from here on without warping the
  /// strides he has already taken.
  double _now = 0;
  double _walked = 0;

  void _onTick(Duration elapsed) {
    _now = elapsed.inMicroseconds / 1e6;
    final walked = _ramp.walkedAt(_now);
    final halfStrideSeconds = walkDurationFor(widget.mood).inMicroseconds / 2e6;
    // **Clamped, the same way the ball clamps its own step.** A ticker MUTED by
    // `TickerMode` still counts the time it spent muted, so coming back to this
    // tab after a minute elsewhere hands the world a minute of travel in one
    // frame and the whole diorama leaps. It does not owe anybody the distance it
    // did not draw.
    final step = math.min(walked - _walked, 0.05);
    _halfStrides.value += step / halfStrideSeconds;
    _walked = walked;
    // The ease is over and the world has stopped: park the ticker rather than
    // spending a frame every frame on a diorama that is not moving.
    if (_ramp.target == 0 && _ramp.rateAt(_now) == 0) _ticker.stop();
  }

  void _sync() {
    // Reduced motion stops the diorama outright rather than easing it down: it
    // is perpetual movement on the screen the app opens on, which is exactly
    // what that setting exists to stop.
    if (MediaQuery.of(context).disableAnimations) {
      _ticker.stop();
      return;
    }
    final target = widget.frozen ? 0.0 : 1.0;
    // **`isActive`, not `isTicking`.** A ticker muted by `TickerMode` — every
    // tab that is not the one on screen — is active and not ticking, and
    // starting one that is already running throws.
    if (_ticker.isActive) {
      _ramp = _ramp.aim(target, _now);
      return;
    }
    // A stopped ticker restarts its elapsed at zero, so the ramp is restated
    // against the clock it is about to be read on — carrying the rate it had
    // reached, so a bow cut short by a tap winds back up from the speed he was
    // actually walking at.
    _ramp = WalkRamp(
      from: _ramp.rateAt(_now),
      target: target,
      since: 0,
      banked: _walked,
      ramp: haltRamp,
    );
    _now = 0;
    if (target != 0 || _ramp.from != 0) _ticker.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_WalkBeat old) {
    super.didUpdateWidget(old);
    if (old.frozen != widget.frozen) _sync();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _halfStrides.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      WalkBeat(notifier: _halfStrides, child: widget.child);
}

/// A last nudge on the ground's speed, if it is ever wanted.
///
/// **It is 1, and it should stay 1 unless something changes.** It was 1.12 for a
/// while and it was covering for the wrong thing: with a constant-speed ground the
/// foot outran the grass by 45% at mid-stance, and the eye reads that as "the
/// ground is too slow" even when the AVERAGE is right — so the average kept being
/// pushed up, which made the rest of the cycle too fast instead.
///
/// [groundEase] fixes it at source: the world now travels at the supporting foot's
/// own instantaneous rate, so there is nothing left to trim. Kept as a named knob
/// because it is the one honest place to put a correction if one is ever needed,
/// rather than having somebody reach into the stride for it.
const double groundSpeedTrim = 1;

/// How long one lane pair takes to sweep past, so that the grass AT HIS FEET
/// moves at [groundSpeedPxPerSec].
///
/// A ray's horizontal travel per radian is its distance below the apex, so one
/// period moves `stretch x period x depth` screen pixels at a row that deep.
/// Solve that for time and the fan is pinned to the one row the eye actually
/// checks — the row his boots are on — at every viewport, instead of being
/// right on the screen it was tuned against and slow everywhere else.
Duration mowDuration({
  required double turfHeight,
  required double contactBelowHorizon,
  required Mood mood,
}) {
  final depth = _mowApex.abs() * turfHeight + contactBelowHorizon;
  final travel = _mowStretch * _mowPeriod * depth;
  final seconds = travel / groundSpeedPxPerSec(mood);
  return Duration(microseconds: (seconds * 1e6).round());
}

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

/// How big he renders. 1.2 → 1.5 → 1.35 → 1.22: at 1.2 he was a detail in a wide
/// shot and the gestures, kit and look packs did not read; 1.5 read but crowded
/// the frame on a notched phone.
///
/// **Back down to 1.22 now the stadium is worth looking at.** 1.35 was the settled
/// middle when the terrace was a strip along the top of the frame and he was the
/// only thing on the screen with any detail on it; with the horizon down and the
/// stand in the middle of the picture, he was competing with it. The figure is
/// also a better drawing than it was, so it survives being smaller.
///
/// The ground speed follows him — [groundSpeedPxPerSec] multiplies his stride by
/// this — so a smaller man takes smaller steps and the grass slows to match.
const double walkerScale = 1.22;

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
    this.tier = 1,
    this.kitColor = const Color(0xFF4CAF50),
    this.walkerBottom = 150 + walkerBottomClearance,
    this.condition = 'clear',
    this.onThunder,
    this.frozen = false,
    this.onBallCue,
    this.ballWind = 0,
    this.onTapWalker,
    this.celebration,
  });

  final Mood mood;

  /// The figure. Passed in rather than built here so the scene stays about the
  /// GROUND and the rig stays about the body.
  final Widget walker;

  /// The club's colour. Some of the crowd wear it — support that grows with you
  /// is the one thing the stand can say about the season.
  final Color kitColor;

  /// How grand the ground is. It buys the height of the terrace in the JS; here
  /// it also picks where along the sky's ramp we are and whether there are
  /// floodlight pylons behind the stand — see `theme/sky.dart` for why the TIER
  /// owns the grandeur and the THEME owns the hour.
  final int tier;

  /// His contact line, above the scene's bottom edge. MEASURED by the caller:
  /// the pill he stands over moves with the footer, and a constant would be
  /// wrong the first frame an event strip appeared.
  final double walkerBottom;

  /// The sky, as `weather_engine.dart` names it: one of `clear`, `sunny`,
  /// `cloudy`, `wind`, `fog`, `rain`, `storm`, `snow`.
  ///
  /// A string rather than an enum so it cannot drift from the engine that
  /// produces it — and `clear` by default, which is what every screen that does
  /// not care about the weather already gets.
  final String condition;

  /// Play the thunder. The scene has no speaker of its own: the sound service
  /// lives behind a provider and this widget deliberately does not read one, so
  /// a test can build the whole diorama without wiring audio.
  final void Function()? onThunder;

  /// **The world stops travelling past him.**
  ///
  /// He walks in place and the scene scrolls, so a gesture that plants his feet
  /// has to stop the scroll with it — otherwise the ground keeps sliding past a
  /// man standing still, which is the one thing that gives the whole trick away.
  /// The walker stops itself; this is every surface he is standing on.
  final bool frozen;

  /// A tap on the figure. The JS answers it with a mood-appropriate gesture,
  /// which is the one thing on this screen that replies with a person rather
  /// than a menu.
  final void Function()? onTapWalker;

  /// **THE CROWD ANSWERS A CELEBRATION.** A new identity here means he has just
  /// done something worth reacting to — a fist pump, a wave at the terrace — and
  /// the stand surges.
  ///
  /// Identity rather than a bool, so two fist pumps in a row are two surges. The
  /// crowd already had the mechanism and only a TAP on the terrace could trigger
  /// it, so the one thing on the screen most worth cheering could not.
  final Object? celebration;

  /// A stray ball has reached his hands, left them, or rolled past him
  /// untouched. `pitch_ball.dart` owns the ball; the screen above owns the man,
  /// so the two meet here rather than the sim reaching into the figure.
  final void Function(BallCue cue)? onBallCue;

  /// What the weather does to a ball in flight, from `windAccelFor`.
  ///
  /// **The last link in that chain.** The service fetches a reading, the engine
  /// turns it into a gust and `windAccelFor` turns that into an acceleration —
  /// and until the ball arrived nothing in the port had ever read the answer.
  final double ballWind;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final night = nightScene(brightness);
    final sky = skyGradient(brightness: brightness, tier: tier);
    final haze = skyHaze(brightness: brightness, tier: tier);
    final pylons = floodlightCount(tier);

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
        final horizon = (feet - walkerHeight * walkerScale * _horizonAboveBoots)
            .clamp(h * 0.16, h * 0.68);

        return ClipRect(
          // **ONE clock for the man and for the ground he is walking on**, so a
          // gesture that plants his feet eases both down together — see
          // `walk_ramp.dart`. Outside the Stack because the walker is handed in
          // from the screen above and reads the beat off the context.
          child: _WalkBeat(
            mood: mood,
            frozen: frozen,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(decoration: BoxDecoration(gradient: sky)),
                ),
                // The sun and the clouds paint WITH the sky, before anything the
                // ground carries. At one layer higher the sun sat in front of the
                // terrace and a tier-5 ground had it hanging over its floodlights.
                Positioned.fill(
                  key: const ValueKey('pitch-weather-sky'),
                  child: WeatherSky(condition: condition),
                ),
                // The pylons, on their OWN strip behind the stand and at the
                // stand's own speed and period — so however tall they get they
                // cannot drift against the terrace they are planted in. A tall
                // strip rather than a tall segment: a floodlight rises well clear
                // of the roof, and the stand's strip is only as tall as the stand.
                if (pylons > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: h - (horizon - hoardingHeight),
                    // **OFF THE TERRACE, NOT OFF THE VIEWPORT.** The JS gives the
                    // pylon 100% of a layer that is 46% of the scene, which on a
                    // phone puts the lamps up behind the next-match card — so all
                    // you see of a floodlight is two thin poles crossing the sky,
                    // which read as cables. A pylon is proportioned against the
                    // stand it lights (about two and a half terraces), so the head
                    // lands in the band of sky the diorama actually shows, and it
                    // stays there whatever the viewport does. Clamped to the sky
                    // above the horizon so a short scene cannot push it out of
                    // frame.
                    height: math.min(
                      standHeight * _pylonStands,
                      math.max(0, (horizon - hoardingHeight) * 0.92),
                    ),
                    child: _GroundDrive(
                      builder: (worldX) => _Scroller(
                        key: const ValueKey('pitch-floodlights'),
                        offsetPx: parallaxOffset(
                          worldX,
                          segmentWidth: farSegmentWidth,
                          period: const Duration(milliseconds: 16500),
                          mood: mood,
                        ),
                        segmentWidth: farSegmentWidth,
                        child: _FloodlightSegment(count: pylons, lit: night),
                      ),
                    ),
                  ),
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
                  // Tapping the terrace gets the crowd up — the JS's own
                  // interaction, and the one thing on this screen that answers a
                  // tap with a crowd rather than with a menu.
                  child: _Crowd(
                    celebration: celebration,
                    builder: (beat, excitement) => _GroundDrive(
                      builder: (worldX) => _Scroller(
                        key: const ValueKey('pitch-stand'),
                        offsetPx: parallaxOffset(
                          worldX,
                          segmentWidth: farSegmentWidth,
                          period: const Duration(milliseconds: 16500),
                          mood: mood,
                        ),
                        segmentWidth: farSegmentWidth,
                        child: _StandSegment(
                          kitColor: kitColor,
                          haze: haze,
                          beat: beat,
                          excitement: excitement,
                        ),
                      ),
                    ),
                  ),
                ),
                // **At the speed of the ground they STAND on.** They were pinned
                // to 2.1× the grass period against a 240px segment, which works
                // out at nearly four times slower than the turf at his feet and
                // two and a half times slower than the farthest tuft band — the
                // ground the boards are actually planted in. So the pitch swept
                // past and the advertising crawled, which is the one thing on a
                // parallax scene the eye cannot forgive.
                //
                // Derived the same way the tufts are — segment over speed, scaled
                // by the depth band — so the boards and the grass at their feet
                // can only ever agree.
                Positioned(
                  left: 0,
                  right: 0,
                  top: horizon - hoardingHeight,
                  height: hoardingHeight,
                  child: _GroundDrive(
                    builder: (worldX) {
                      // The boards are planted ON the horizon, so their row is the
                      // far edge of the pitch — fraction 1. Same solve as the
                      // tufts, so the advertising and the grass at its feet can
                      // only agree.
                      final period = turfScroll(
                        segmentWidth: hoardingSegmentWidth,
                        fraction: 1,
                        turfHeight: h - horizon,
                        contactBelowHorizon: feet - horizon,
                        mood: mood,
                      );
                      return _Scroller(
                        key: const ValueKey('pitch-hoardings'),
                        offsetPx: parallaxOffset(
                          worldX,
                          segmentWidth: hoardingSegmentWidth,
                          period: period,
                          mood: mood,
                        ),
                        segmentWidth: hoardingSegmentWidth,
                        child: _HoardingSegment(kitColor: kitColor),
                      );
                    },
                  ),
                ),
                Positioned(
                  key: const ValueKey('pitch-turf'),
                  left: 0,
                  right: 0,
                  top: horizon,
                  bottom: 0,
                  child: _Turf(
                    mood: mood,
                    contactBelowHorizon: feet - horizon,
                    condition: condition,
                  ),
                ),
                // His boot prints, pinned to HIS contact line rather than to the
                // pitch box — which is why they are out here and not inside the
                // turf with the snow they are pressed into. Above that snow,
                // below the figure.
                Positioned(
                  key: const ValueKey('pitch-weather-prints'),
                  left: 0,
                  right: 0,
                  // The shadow under his boots centres a shade above where he
                  // sits, hence the 6px off the shared baseline.
                  bottom: walkerBottom - 6,
                  height: 13,
                  child: WeatherPrints(
                    condition: condition,
                    // **The ground's own number, not one of its own.** A print
                    // that slides against the grass is the one mistake here the
                    // eye catches instantly, so it rides band 0's period — the
                    // grass at his boots.
                    scrollDuration: Duration(
                      microseconds:
                          (printSegmentWidth / groundSpeedPxPerSec(mood) * 1e6)
                              .round(),
                    ),
                    // Where his boot actually is: he stands at `w * 0.45 - 57`
                    // with his feet ~59 art units into the figure.
                    contactFraction: w == 0 ? 0.45 : (w * 0.45 - 57 + 59) / w,
                  ),
                ),
                // Overcast, rain, snow, fog and wind: above the pitch and BELOW
                // him. That is the CSS's z-order rather than an oversight — he is
                // the subject of the shot, so a shower is a curtain behind him.
                Positioned.fill(
                  key: const ValueKey('pitch-weather-air'),
                  child: WeatherAir(condition: condition),
                ),
                // He stands LEFT of centre, on the grass under the horizon, and the
                // scale is about his FEET so he stays planted however big he gets.
                Positioned(
                  key: const ValueKey('pitch-walker'),
                  left: w * 0.45 - 57,
                  // His BOOTS on the contact line, not the bottom of his box.
                  // There are 17.5 art units of empty picture under his soles, and
                  // scaled up that is two dozen pixels of him floating above the
                  // line everything else on this screen is measured from.
                  bottom: walkerBottom - walkerFootOffset * walkerScale,
                  // His OWN box, at his own size — not whatever is left of the
                  // screen. He is 120×170 and scaled 1.35 about his feet, which is
                  // ~162×230 on screen; handed the column's remaining height he
                  // filled it, which is what made him tower over the pitch. The
                  // box also has to be bounded: the rig is an `AspectRatio` and an
                  // unbounded one cannot lay itself out at all.
                  child: SizedBox(
                    width: walkerWidth,
                    height: walkerHeight,
                    child: GestureDetector(
                      // A tap on HIM, not on the scene: the diorama's own taps are
                      // the crowd's and the fireworks', and tapping the manager
                      // used to set off a rocket — which is what you noticed.
                      onTap: onTapWalker,
                      child: Transform.scale(
                        scale: walkerScale,
                        alignment: Alignment.bottomCenter,
                        // **The ball is in HIS box**, so it is scaled by the
                        // same number he is and a distance means the same thing
                        // to it as to his boot — which is the whole reason the
                        // JS parents `.ps-ball` to `.ps-walker`. Unclipped,
                        // because a pass has to travel most of the scene's
                        // width and his box is 120 units wide; the scene's own
                        // `ClipRect` is what stops it at the frame.
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(child: walker),
                            Positioned.fill(
                              key: const ValueKey('pitch-ball'),
                              child: PitchBall(
                                mood: mood,
                                wind: ballWind,
                                frozen: frozen,
                                onCue: onBallCue ?? (_) {},
                                sceneWidth: w,
                                walkerLeft: w * 0.45 - 57,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // The wash the pylons throw, OVER everything they light —
                // including him, because a man standing in a floodlit ground is
                // lit by it. The JS's `.ps-glow`: two soft pools off to either
                // side, which is what says the light comes from up there rather
                // than from the screen.
                if (night && pylons > 0)
                  const Positioned.fill(
                    key: ValueKey('pitch-floodlight-wash'),
                    child: IgnorePointer(
                      child: CustomPaint(painter: _FloodWash()),
                    ),
                  ),
                // The only weather layer that goes OVER him. A flash lights the
                // whole scene, and a man standing in it is part of the scene.
                Positioned.fill(
                  key: const ValueKey('pitch-weather-lightning'),
                  child: WeatherLightning(
                    condition: condition,
                    onThunder: onThunder,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The crowd's own clock, and how worked up it is.
///
/// **Its own controller rather than the scroller's**, because the two are
/// different speeds for different reasons: the stand SCROLLS at the speed of the
/// ground it stands on (16.5s a segment, parallax), and a crowd BOUNCES at about
/// the rate people bounce. Sharing one would tie the crowd's energy to how fast
/// the manager happens to be walking.
///
/// Excitement decays rather than switching off, so a tap is a surge that settles
/// instead of a state that ends.
class _Crowd extends StatefulWidget {
  const _Crowd({required this.builder, this.celebration});

  final Widget Function(double beat, double excitement) builder;

  /// A new identity is something worth getting up for. See
  /// [PitchScene.celebration].
  final Object? celebration;

  @override
  State<_Crowd> createState() => _CrowdState();
}

class _CrowdState extends State<_Crowd> with SingleTickerProviderStateMixin {
  static const Duration _bounce = Duration(milliseconds: 1150);

  /// How long a tap keeps them up.
  static const double _surgeSeconds = 2.4;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _bounce,
  );

  double _excitement = 0;
  Duration _last = Duration.zero;

  /// The same bargain the scrolling strips make — see `_ScrollerState._sync`.
  ///
  /// It does NOT take the scene's freeze, and that is the point of it being here
  /// rather than shared: the crowd bounces at the rate people bounce, not at the
  /// rate the ground travels. A stand that stopped dead because the manager
  /// paused to bow would be stranger than one that carried on.
  void _sync() {
    if (MediaQuery.of(context).disableAnimations) {
      if (_c.isAnimating) _c.stop();
      return;
    }
    if (!_c.isAnimating) _c.repeat();
  }

  @override
  void initState() {
    super.initState();
    _c.addListener(_decay);
  }

  void _decay() {
    if (_excitement <= 0) return;
    final now = _c.lastElapsedDuration ?? Duration.zero;
    // The controller repeats, so elapsed resets — a backwards step is a wrap and
    // is worth one frame rather than a negative one.
    final dt = now > _last ? (now - _last).inMicroseconds / 1e6 : 1 / 60;
    _last = now;
    setState(() {
      _excitement = math.max(0, _excitement - dt / _surgeSeconds);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_Crowd old) {
    super.didUpdateWidget(old);
    // Same surge a tap gives, and it decays the same way — a crowd that stayed up
    // would be a crowd that had stopped reacting.
    if (widget.celebration != null && widget.celebration != old.celebration) {
      setState(() => _excitement = 1);
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const ValueKey('pitch-stand-tap'),
    // Opaque, so the terrace answers a tap that lands on a gap between two
    // supporters rather than only on a head.
    behavior: HitTestBehavior.opaque,
    onTap: () => setState(() => _excitement = 1),
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => widget.builder(_c.value, _excitement),
    ),
  );
}

// ── Floodlights ─────────────────────────────────────────────────────────────
// A pylon is BUILT, not switched on: the tier decides whether one is standing
// there, the theme decides whether it is burning. So in light mode a top-tier
// ground still has its pylons, cold and grey against a daylit sky, which is the
// difference between a big club in the afternoon and the same club at night.
//
// All the geometry is the JS's `.ps-flood`, as fractions of the pylon's own
// height rather than of the layer it sits in: the strip's height is derived
// (46% of the scene, clamped by the sky above the horizon), so pinning the head
// to a percentage of the LAYER would slide it up and down the pole with the
// viewport.

/// How many terraces tall a pylon stands.
///
/// Tall enough to clear the roof and read as a floodlight, short enough that the
/// HEAD lands in the strip of sky the next-match card leaves — which on a phone
/// is a hundred-odd pixels between the card's foot and the stand's fascia. At
/// 2.6 the lamps sat behind the card on every screen size, which is the same
/// fault as the JS's viewport fraction, one step smaller.
const double _pylonStands = 2.0;

/// Where the pole and the head sit across the pylon's 30px box.
const double _poleWidth = 4;
const double _poleLeft = 13;
const double _headWidth = 28;
const double _headHeight = 10;

/// The pole stops short of the top; the head hangs just below where it stops.
const double _poleFraction = 0.86;
const double _headTopFraction = 0.09;

class _FloodlightSegment extends StatelessWidget {
  const _FloodlightSegment({required this.count, required this.lit});

  final int count;
  final bool lit;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('pitch-floodlight-segment'),
    width: farSegmentWidth,
    height: double.infinity,
    child: CustomPaint(
      painter: _FloodlightPainter(count: count, lit: lit),
    ),
  );
}

class _FloodlightPainter extends CustomPainter {
  const _FloodlightPainter({required this.count, required this.lit});

  final int count;
  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    // Seeded like the crowd, and for the same reason: a pylon that stood
    // somewhere else on every rebuild would read as the ground being rebuilt.
    final rng = math.Random(11);
    for (var i = 0; i < count; i++) {
      final left = 60 + rng.nextDouble() * 90 + i * 220;
      _paintPylon(canvas, size, left);
    }
  }

  void _paintPylon(Canvas canvas, Size size, double left) {
    final poleRect = Rect.fromLTWH(
      left + _poleLeft,
      size.height * (1 - _poleFraction),
      _poleWidth,
      size.height * _poleFraction,
    );
    canvas.drawRect(
      poleRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF667080), Color(0xFF3A424C)],
        ).createShader(poleRect),
    );

    final head = Rect.fromLTWH(
      left + 1,
      size.height * _headTopFraction,
      _headWidth,
      _headHeight,
    );
    final headShape = RRect.fromRectAndRadius(head, const Radius.circular(3));
    if (lit) {
      // The bloom BEFORE the lamps, so the glass sits inside its own halo
      // rather than under it. A blurred fill is the paint-side equivalent of
      // the JS's `box-shadow` spread, and it is the one thing that makes the
      // head read as a light rather than as a pale rectangle.
      canvas.drawRRect(
        headShape.inflate(5),
        Paint()
          ..color = const Color(0xFFFFFAD2).withValues(alpha: 0.55)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8),
      );
    }
    // The lamp bank: bright glass with the frame between each lamp showing.
    canvas.drawRRect(
      headShape,
      Paint()..color = lit ? const Color(0xFFFFFBE0) : const Color(0xFF9AA4B0),
    );
    final mullion = Paint()
      ..color = lit ? const Color(0xFFC9C49A) : const Color(0xFF6E7885);
    for (var x = head.left + 4; x < head.right; x += 6) {
      canvas.drawRect(
        Rect.fromLTWH(x, head.top, 2, head.height).intersect(head),
        mullion,
      );
    }
  }

  @override
  bool shouldRepaint(_FloodlightPainter old) =>
      old.count != count || old.lit != lit;
}

/// The wash the pylons throw over the ground: the JS's `.ps-glow`, two soft
/// pools to either side of the middle rather than one even lift, because an even
/// lift is a brightness slider and two pools are lamps.
class _FloodWash extends CustomPainter {
  const _FloodWash();

  static const Color _light = Color(0xFFFFFADC);

  @override
  void paint(Canvas canvas, Size size) {
    for (final cx in const [0.18, 0.82]) {
      final rect = Rect.fromCenter(
        center: Offset(size.width * cx, size.height * 0.4),
        width: size.width * 1.2,
        height: size.height * 0.9,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _light.withValues(alpha: 0.10),
              _light.withValues(alpha: 0),
            ],
            stops: const [0, 0.7],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_FloodWash old) => false;
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
  const _StandSegment({
    required this.kitColor,
    required this.haze,
    required this.beat,
    required this.excitement,
  });

  final Color kitColor;
  final Color haze;

  /// Where the crowd's own clock is, 0..1 through one bounce.
  final double beat;

  /// 0 is an ordinary crowd with a few people on their feet; 1 is the whole
  /// stand up.
  final double excitement;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('pitch-stand-segment'),
    width: farSegmentWidth,
    height: double.infinity,
    child: CustomPaint(
      painter: _StandPainter(
        kitColor: kitColor,
        haze: haze,
        beat: beat,
        excitement: excitement,
      ),
    ),
  );
}

class _StandPainter extends CustomPainter {
  const _StandPainter({
    required this.kitColor,
    required this.haze,
    required this.beat,
    required this.excitement,
  });

  /// **A CROWD IS NEVER COMPLETELY STILL.** Every fan was pinned to its seat,
  /// and a few hundred motionless heads read as a printed backdrop rather than
  /// as people — which is most of why the terrace looked like wallpaper next to
  /// a walking manager and a scrolling pitch.
  ///
  /// The cheap version of life is a BOUNCE on its own phase per fan, so at rest a
  /// scattering of them are up and down out of step with each other and nothing
  /// reads as synchronised. Tapping the stand raises [excitement], which brings
  /// the rest to their feet and lifts everyone higher — the JS's own interaction,
  /// and the reason the phase is per fan rather than per row: a stand that
  /// bounces in unison is a Mexican wave, which is a different thing and reads as
  /// one.
  final double beat;
  final double excitement;

  final Color kitColor;

  /// What the distance fades TO — the sky at the horizon, handed in rather than
  /// chosen here. See [skyHaze]: a fixed colour here was a twilight terrace
  /// under a daylight sky.
  final Color haze;

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
        // Its own phase and its own idea of whether it is bothered — both drawn
        // from the same seeded stream, so a fan bounces the same way every
        // repaint and the stand never reshuffles.
        final phase = rng.nextDouble();
        final keen = rng.nextDouble();
        // At rest only the keenest fifth are up; excitement brings the rest.
        final up = keen < 0.2 + excitement * 0.8;
        final lift = up
            ? math.max(0.0, math.sin((beat + phase) * 2 * math.pi)) *
                  (1.1 + excitement * 2.4)
            : 0.0;
        _paintFan(
          canvas,
          x: x,
          top: deckTop + y - lift,
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
          colors: [haze.withValues(alpha: 0.42), haze.withValues(alpha: 0.16)],
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
  bool shouldRepaint(_StandPainter old) =>
      old.kitColor != kitColor ||
      old.haze != haze ||
      old.beat != beat ||
      old.excitement != excitement;
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

/// The grass in the afternoon, and the same grass under the lamps.
const List<Color> _turfDay = [
  Color(0xFF2A7231),
  Color(0xFF3A9441),
  Color(0xFF48AD50),
];
const List<Color> _turfNight = [
  Color(0xFF17442A),
  Color(0xFF1F6035),
  Color(0xFF2A783F),
];

/// The ground: the turf, the mowing fan over it, the tuft bands, and the haze
/// that puts the far end of it in the distance.
class _Turf extends StatelessWidget {
  const _Turf({
    required this.mood,
    required this.contactBelowHorizon,
    required this.condition,
  });

  final Mood mood;

  /// The sky, because snow does not only fall — it settles, and grass under snow
  /// is white.
  final String condition;

  /// How far below the horizon his boots are, which is the depth the fan is
  /// pinned at.
  final double contactBelowHorizon;

  @override
  Widget build(BuildContext context) {
    // Every speed on this surface comes off one number — his stride — and every
    // layer reads it through [turfScroll], so nothing on the grass can slide
    // against the grass.
    // **LIT BY THE SAME DECISION AS THE SKY.** A sunlit pitch under a night sky
    // was the one thing that gave away that the two halves of the diorama were
    // deciding their own light independently, and it is the whole reason the
    // theme owns the hour rather than a clock: there is exactly one answer to
    // "is it night", so the grass and the sky can only agree.
    final night = nightSceneOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          // The turf. Brighter at his boots and darker toward the horizon, which
          // is the first half of reading as ground rather than as a green wall.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                // Floodlit grass is COOLER and darker rather than simply dimmer:
                // a lamp is a narrow band of light on a field that has no sun on
                // it, so the green loses its warmth and the pools the pylons
                // throw put it back in two places — see `_FloodWash`.
                colors: night ? _turfNight : _turfDay,
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
          // **THE STRIPES AND THE TUFTS OFF ONE POSITION.** They used to own a
          // clock each, which is the only arrangement a constant speed allows and
          // the wrong one the moment the world follows his foot — see
          // [groundEase]. Now the drive owns the distance and each layer scales it
          // by its own row's depth, so nothing on the surface can drift from
          // anything else on it, at any instant rather than on average.
          Positioned.fill(
            child: _GroundDrive(
              builder: (worldX) {
                final contact = _contactDepth(
                  constraints.maxHeight,
                  contactBelowHorizon,
                );
                double atRow(double fraction) =>
                    worldX *
                    _rowDepth(fraction, constraints.maxHeight) /
                    contact;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _MowFan(
                      key: const ValueKey('pitch-mown'),
                      worldX: worldX,
                      turfHeight: constraints.maxHeight,
                      contactBelowHorizon: contactBelowHorizon,
                    ),
                    // Each band a FULL-HEIGHT strip whose tufts sit at their own
                    // depth inside it, offset by what the world has done at that
                    // depth.
                    for (var band = 0; band < _tuftBands; band++)
                      Positioned.fill(
                        child: _Scroller(
                          offsetPx: atRow(tuftBandFraction(band)),
                          segmentWidth: groundSegmentWidth,
                          child: _TuftSegment(band: band),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          // Snow LYING on the grass, over the stripes and the tufts but UNDER
          // the distance shade — settled snow is the surface, so it takes the
          // same aerial perspective the turf does.
          Positioned.fill(
            key: const ValueKey('pitch-weather-ground'),
            child: WeatherGroundSnow(condition: condition),
          ),
          // Distance shade, OVER the fan and everything growing out of the turf.
          // It stops before it reaches him: the shading has to fall off short of
          // his boots or he ends up standing in a vignette.
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x57061A0C),
                      Color(0x29061A0C),
                      Color(0x0A061A0C),
                      Color(0x00061A0C),
                    ],
                    stops: [0, 0.3, 0.52, 0.68],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The mown stripes as a fan of rays converging on an apex above the pitch.
///
/// It SWEEPS rather than translating, and that is the whole point: a ray's
/// horizontal travel for a given rotation is proportional to its distance below
/// the apex, so the near grass moves fast and the far grass barely moves. A
/// translating strip gives every depth the same speed, which is a conveyor belt
/// rather than a pitch — and pinning that one speed anywhere but under his boots
/// is what has him skating.
/// The mown fan, swept to a WORLD POSITION rather than on a clock of its own.
///
/// A radian carries his row `stretch x depth` pixels, so the angle is simply the
/// distance travelled divided by that — and the stripes under his boots move
/// exactly as far as the world has, at every instant rather than on average.
class _MowFan extends StatelessWidget {
  const _MowFan({
    super.key,
    required this.worldX,
    required this.turfHeight,
    required this.contactBelowHorizon,
  });

  final double worldX;
  final double turfHeight;
  final double contactBelowHorizon;

  @override
  Widget build(BuildContext context) {
    final perRadian =
        _mowStretch * _contactDepth(turfHeight, contactBelowHorizon);
    final angle = perRadian <= 0 ? 0.0 : worldX / perRadian;
    // Named rather than inherited: a loose height constraint anywhere above this
    // is what once collapsed the surface to nothing and painted the pitch as sky.
    return CustomPaint(
      size: Size.infinite,
      painter: _MowPainter(phase: (angle / _mowPeriod) % 1),
    );
  }
}

class _MowPainter extends CustomPainter {
  const _MowPainter({required this.phase});

  /// How far through one lane pair the sweep is, 0 to 1.
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    if (h <= 0 || size.width <= 0) return;
    final inner = size.width / _mowStretch;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Into the third-width space the fan is drawn in, then stretched back out.
    canvas.translate(size.width / 2, 0);
    canvas.scale(_mowStretch, 1);

    final apexY = _mowApex * h;
    // Enough of the fan to cover the box's far corners, plus a lane either side
    // so the sweep never uncovers an edge.
    final half = math.atan2(inner / 2, -apexY) + _mowPeriod * 2;
    final reach = (h - apexY) * 1.6;
    final light = Paint()..color = const Color(0x0EFFFFFF);
    final dark = Paint()..color = const Color(0x0D000000);

    // MINUS the phase: increasing the angle sweeps a ray to the right, and the
    // world has to move right-to-left past a man walking on the spot.
    final first = -(half / _mowPeriod).ceil() * _mowPeriod - phase * _mowPeriod;
    for (var a = first; a < half; a += _mowPeriod) {
      _wedge(canvas, apexY, a, a + _mowPeriod / 2, reach, light);
      _wedge(canvas, apexY, a + _mowPeriod / 2, a + _mowPeriod, reach, dark);
    }
    canvas.restore();
  }

  /// One lane, as the wedge between two rays out of the apex.
  void _wedge(
    Canvas canvas,
    double apexY,
    double from,
    double to,
    double reach,
    Paint paint,
  ) {
    canvas.drawPath(
      Path()
        ..moveTo(0, apexY)
        ..lineTo(reach * math.sin(from), apexY + reach * math.cos(from))
        ..lineTo(reach * math.sin(to), apexY + reach * math.cos(to))
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(_MowPainter old) => old.phase != phase;
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
    final span = (tuftFMax - tuftFMin) / _tuftBands;

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
///
/// **It owns no clock.** Every strip on this scene is a window onto a position
/// somebody else holds — see [parallaxOffset] and `_GroundDrive` — because that
/// is the only way layers can share a rate that VARIES. Each used to run its own
/// `AnimationController.repeat()`, which is all a fixed speed needs and exactly
/// what left the background sliding past a man who had stopped walking: a
/// controller has no rate to vary. There is nothing to switch off here now, and
/// nothing to forget to switch off.
class _Scroller extends StatelessWidget {
  const _Scroller({
    super.key,
    required this.offsetPx,
    required this.segmentWidth,
    required this.child,
  });

  /// How far the world has travelled, in pixels at THIS strip's row.
  final double offsetPx;

  final double segmentWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: LayoutBuilder(
      builder: (context, constraints) {
        // One spare segment so the leading edge is always covered.
        final count = (constraints.maxWidth / segmentWidth).ceil() + 2;
        return Transform.translate(
          // Right to left: the world moves past him, he walks in place.
          offset: Offset(-(offsetPx % segmentWidth), 0),
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            maxWidth: count * segmentWidth,
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
              children: [for (var i = 0; i < count; i++) child],
            ),
          ),
        );
      },
    ),
  );
}
