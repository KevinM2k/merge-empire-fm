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

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/ui/screens/home/kenney_art.dart';
import 'package:merge_empire_fc/ui/widgets/modular_figure.dart';
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
import 'package:merge_empire_fc/ui/screens/home/scene_clock.dart';
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
/// Six, not three: every tuft in a band travels at the band's ONE row speed,
/// so a band's tufts must sit on that row — the spread within a wide band was
/// tufts sliding against the grass they stood on.
const int _tuftBands = 6;

/// The middle of one band's slice of the tuft range, as a fraction up the pitch
/// box — the same placement `_TuftPainter` scatters within.
double tuftBandFraction(int band) =>
    tuftFMin + (tuftFMax - tuftFMin) * (band + 0.5) / _tuftBands;

/// How far below the mowing fan's apex a row [fraction] of the way up the pitch
/// box sits, in pixels. A ray's speed is proportional to this, which is the whole
/// of the perspective.
double _rowDepth(double fraction, double turfHeight) =>
    mowApex.abs() * turfHeight + (1 - fraction) * turfHeight;

/// The depth of the row HIS BOOTS are on — the one row whose speed is pinned. See
/// [groundSpeedPxPerSec].
double _contactDepth(double turfHeight, double contactBelowHorizon) =>
    mowApex.abs() * turfHeight + contactBelowHorizon;

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

/// How much slower the PYLONS run than the stand they light.
///
/// They are genuinely further away — the towers stand behind the terrace — so
/// they are the one layer that should lag it. A factor rather than a period,
/// because the stand's own speed is solved from the viewport now and a second
/// fixed number would drift from it the moment the first one moved.
const double pylonDepth = 1.35;

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
/// by [mowApex], which recedes harder to match.
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
///
/// **-0.48, and the reason is the SIZE OF THE MANAGER.** Asked for from the
/// couch: a bit more perspective, so the crowd and the stand read as further
/// away without anything being moved. He is drawn at [walkerScale] and that is
/// the yardstick the eye uses for the whole diorama — a stand that is only a
/// little way behind a man that big is a small stand, however far up the frame
/// it sits. Recession is the cue, not position.
///
/// Two things move together when this tightens, and both push the same way.
/// The near grass is PINNED at his contact line — [groundSpeedPxPerSec] — so
/// the far rows slow instead: the stand and the boards drop from 47.9 px/s to
/// 44.2 on a 400-point scene, while the turf at his boots stays at 79. That
/// takes the near-to-far ratio from 1.65 to 1.79. And the mown lanes converge
/// harder, which is the same statement made in the geometry.
///
/// **It does not undo the far strip's speed-up**, which is worth stating
/// because the two arrived one after the other: the stand was on a fixed
/// 16.5s and 29.1 px/s before [farPeriod] solved it against the ground, so it
/// is still half again quicker than it was, just no longer running at the
/// speed of grass that is nearer than it.
/// **Public because the TESTS have to solve against it, not against a copy of
/// it.** `pitch_scene_test` had `0.58` written out three times, so moving the
/// apex broke a test whose subject is the invariant that every layer on the
/// turf travels at the fan's speed for its own row — which was still true. A
/// duplicated constant turns a scene decision into a test failure.
const double mowApex = -0.48;

/// One lane pair, in radians. The sweep must travel exactly one full period or
/// the loop jumps.
///
/// **Ten and a half degrees, not seven and not 5.2.** The lanes are ANGULAR, so
/// widening the period widens every one of them — and the narrow ones read as a
/// texture on the grass rather than as mown bands. Half again wider than the
/// seven this had settled on, asked for from the couch once the stripes were
/// carrying the tier: a mower cuts a wide band, and at seven degrees the top of
/// the pyramid had a pinstripe. [mowDuration] solves the sweep against this, so
/// the grass at his boots keeps its speed whatever the lanes are doing.
final double _mowPeriod = 10.5 * math.pi / 180;

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

/// **HOW MUCH OF THE GROUND'S SPEED IS THE PLANTED FOOT'S, and how much is a
/// steady walk.** At 0 the turf follows the supporting boot exactly and never
/// skates; at 1 it runs at one speed across the whole stride. It sat at 0.3,
/// and the turf visibly pulsed — a lurch every step, which is not how walking
/// looks: a walker's pace is level and the foot does the varying. Reported from
/// the couch as the background easing on every step. So it is 1 now, the JS's
/// own arrangement, and the residual skate is the accepted price — see
/// `manager_walker_test`, where it is measured.
const double groundEaseFloor = 1.0;

/// The slowest the SOLVED rate may run, as a fraction of its mean, before the
/// floor above is blended in.
///
/// **The floor alone still stalled.** Measured in sixteenths of a half-stride
/// the rate ran 0.54, 0.46, **0.34**, then 0.70 and up to 1.47 — a fourfold
/// swing whose dip lands exactly on the front foot's strike, which is where it
/// was reported: "he freezes, background and all, on every step". Raising the
/// floor to fix it costs slip everywhere (0.65 measured 83 units a cycle,
/// against a guard of 55); this clamps only the three samples in the hole and
/// leaves the rest of the stance the foot's own. The clamped curve is
/// renormalised so a half-stride still covers the same ground.
const double groundEaseMinRate = 0.6;

final ({List<double> table, double distance}) _groundEase = () {
  const steps = 256;
  double sole(double t, bool near) =>
      walkerBootSoleY(t, near: near) - walkerHipRise(t);
  final steps_ = <double>[];
  for (var i = 0; i < steps; i++) {
    final t = i / steps * 0.5;
    final t2 = (i + 1) / steps * 0.5;
    final near = sole(t, true) >= sole(t, false);
    steps_.add(
      math.max(0, walkerAnkle(t, near: near).x - walkerAnkle(t2, near: near).x),
    );
  }
  // The hand-over hole, filled — see [groundEaseMinRate].
  final travelled = steps_.fold(0.0, (a, b) => a + b);
  final mean = travelled / steps;
  final out = <double>[0];
  var sum = 0.0;
  for (final d in steps_) {
    sum += math.max(d, mean * groundEaseMinRate);
    out.add(sum);
  }
  // Normalised, then blended toward a constant rate — see [groundEaseFloor].
  return (
    table: [
      for (var i = 0; i < out.length; i++)
        (1 - groundEaseFloor) * (out[i] / sum) +
            groundEaseFloor * (i / (out.length - 1)),
    ],
    // The foot's own distance, not the clamped curve's: the table is
    // normalised, so the clamp reshapes a half-stride without lengthening it.
    distance: travelled,
  );
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

/// A last nudge on the ground's speed.
///
/// **1.22, because the ground runs level again.** (1.12 was still read as a
/// shade slow from the couch.) With the turf at one speed
/// the planted foot outruns it by half at mid-stance, and the eye reads that
/// as the grass being too slow even when the average is exact — reported from
/// the couch in as many words the moment the per-step ease came out. Pushing
/// the mean up a shade is the honest correction: the fastest part of the
/// stance is what the eye locks onto, and this closes most of that gap without
/// making the swing phase visibly quick. It was 1 while [groundEase] tracked
/// the foot outright and there was nothing to trim.
const double groundSpeedTrim = 1.22;

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
  final depth = mowApex.abs() * turfHeight + contactBelowHorizon;
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

/// How many tufts there are across a whole 420px segment, **AT THIS TIER**.
///
/// **The port drew the same kept pitch at every rank.** The spec scales it hard
/// and says why: nobody mows a Sunday League pitch, so the bottom of the pyramid
/// gets a lot more clumps, bigger and longer in the blade, and a top-flight
/// ground gets almost none. `_tuftBands` in `PitchScene.js`: sixteen at tier 0,
/// eleven at tier 1, then `7 - tier` and nothing at all from Continental up.
int tuftsTotal(int tier) => switch (tier) {
  <= 0 => 11,
  1 => 9,
  2 => 4,
  3 => 2,
  _ => 0,
};

/// How many of those fall in one band.
///
/// **Round-robin, as the JS's `i % TUFT_BANDS` is**, rather than the total
/// divided by the bands and rounded up: six bands and a ceiling could only
/// count in sixes, so a scruffy tier 2 and a nearly-kept tier 3 came out with
/// the identical one-per-band and the step between them disappeared.
int tuftsInBand(int band, int tier) =>
    (tuftsTotal(tier) - band + _tuftBands - 1) ~/ _tuftBands;

/// How much bigger and longer the blades are down the bottom. The spec's
/// `sizeBoost` and `lengthBoost`: a rough pitch is rough in the grass first.
double tuftSizeBoost(int tier) => switch (tier) {
  <= 0 => 2.0,
  1 => 1.5,
  2 => 1.15,
  _ => 1.0,
};

/// One tuft: where it stands across the segment, its row, its size.
typedef TuftPlacement = ({
  double x,
  double f,
  double depth,
  double w,
  double tall,
  double lean,
});

/// Where a band's tufts are — one list the blades and the sprites both read,
/// so a field is the same field either way. [x] is a fraction of the width;
/// the row is the band's own, with a jitter of a quarter of the band.
List<TuftPlacement> tuftPlacements(int band, int tier) {
  final rng = math.Random(31 + band);
  final span = (tuftFMax - tuftFMin) / _tuftBands;
  final count = tuftsInBand(band, tier);
  final sizeBoost = tuftSizeBoost(tier);
  final lengthBoost = tuftLengthBoost(tier);
  return [
    for (var i = 0; i < count; i++)
      () {
        final f =
            tuftBandFraction(band) + (rng.nextDouble() - 0.5) * span * 0.25;
        final depth = (f - tuftFMin) / (tuftFMax - tuftFMin);
        final w = math.max(
          4.0,
          (9 + rng.nextDouble() * 7) * (1 - depth * 0.55) * sizeBoost,
        );
        return (
          x: rng.nextDouble(),
          f: f,
          depth: depth,
          w: w,
          tall: w * lengthBoost,
          lean: rng.nextDouble() * 8 - 4,
        );
      }(),
  ];
}
double tuftLengthBoost(int tier) => switch (tier) {
  <= 0 => 1.25,
  1 => 1.15,
  2 => 0.95,
  _ => 0.85,
};

/// **THE TIER THE PITCH STOPS HOLDING WATER.** Below this there are puddles on
/// it; at and above it the groundsman has at least dug the drainage in.
///
/// Two: the locked ground and tier 1 are the field, and tier 2 is a plain pitch
/// — the couch's own reading of the Club tab's photographs, after a middle pass
/// had put water on tier 2 as well.
const int firstKeptPitchTier = 2;

/// **HOW BATTERED THE SURFACE IS**, 1 for a field and 0 for a kept pitch.
///
/// One dial the whole ground reads — the colour of the grass, how much bare
/// earth is showing through it, whether there is water lying on it and how
/// scuffed the chalk is. **The Club tab's tier photographs are the brief**, and
/// they are a stronger progression than the port was drawing: tier 1 is a
/// puddled quagmire with more mud than grass in it, tier 2 is plain green and
/// scruffy, and by tier 3 the groundsman has been. The port had one smudge and
/// one puddle on an otherwise perfect table at tier 1 and the identical surface
/// at every tier above it.
///
/// **THE LOCKED GROUND AND TIER 1 ARE THE BAD ONES**, and that is the couch's
/// own reading of the photographs — a middle pass had tier 2 nearly as rough and
/// it was called back: tier 2 is a plain green pitch that nobody has striped
/// hard, not a field. So the fall is steep rather than long, and what is left at
/// 2 and 3 is a scuff or two rather than mud.
double pitchWear(int tier) => switch (tier) {
  <= 1 => 1.0,
  2 => 0.25,
  3 => 0.08,
  _ => 0.0,
};

/// How hard the stripes have been cut in, as a multiplier on the mowing fan's
/// own contrast.
///
/// **Nobody stripes a Sunday League pitch**, and the port striped all eight the
/// same — a bold mown fan on a muddy park field, which is the one thing on the
/// surface that says "this ground is looked after". A whisper at the bottom so
/// the turf is not a flat wash, a plain cut by tier 2, and past a full one at
/// the top, where the photograph is a show pitch under lights.
double mowStrength(int tier) => (0.10 + (tier - 1) * 0.24).clamp(0.10, 1.35);

/// How big he renders. 1.2 → 1.5 → 1.35 → 1.22 → 1.34: at 1.2 he was a detail in
/// a wide shot and the gestures, kit and look packs did not read; 1.5 read but
/// crowded the frame on a notched phone.
///
/// It went down to 1.22 when the stadium became worth looking at — with the
/// horizon down and the stand in the middle of the picture, a 1.35 manager was
/// competing with it. **And that turned out to be a step too far**: asked for
/// from the couch as about ten per cent bigger, which lands almost exactly back
/// on the middle the earlier rounds had settled on. The stand has since gained
/// its own depth layers and its own haze, so it holds its place in the frame
/// without the figure having to give ground for it.
///
/// The ground speed follows him — [groundSpeedPxPerSec] multiplies his stride by
/// this — so a bigger man takes bigger steps and the grass speeds up to match.
const double walkerScale = 1.34;

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
    required this.walkerBuilder,
    this.tier = 1,
    this.kitColor = const Color(0xFF4CAF50),
    this.walkerBottom = 150 + walkerBottomClearance,
    this.condition = 'clear',
    this.onThunder,
    this.frozen = false,
    this.onBallCue,
    this.onBallStrike,
    this.onBallFlick,
    this.onBallWatch,
    this.ballWind = 0,
    this.onTapWalker,
    this.celebration,
  });

  final Mood mood;

  /// The figure. Passed in rather than built here so the scene stays about the
  /// GROUND and the rig stays about the body.
  /// Him, built around the ball. The scene owns the ball's geometry — it is
  /// measured off the scene's width — and he owns its DEPTH, so the two have to
  /// meet somewhere and this is it.
  final Widget Function(Widget ball) walkerBuilder;

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

  /// He is about to play the stray ball back — see [PitchBall.onStrike].
  final VoidCallback? onBallStrike;

  /// He is about to flick the ball up into his hands — see [PitchBall.onFlick].
  final VoidCallback? onBallFlick;

  /// There is a ball worth looking at, or there no longer is — see
  /// [PitchBall.onWatch].
  final void Function(bool watching)? onBallWatch;

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

    // Kenney's sprites, decoded before any strip that snapshots them is built.
    return SpriteGate(
      paths: [...kenneySceneSprites(tier), ...parkSpectatorAssets(tier)],
      builder: (context, sprites) => LayoutBuilder(
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

        // **THE FAR STRIP WAS THE LAST THING STILL RUNNING ON A FIXED CLOCK,
        // and it was the slowest thing on the screen by a factor of two.** The
        // stand and the pylons were pinned at the JS's 16.5s against a 480px
        // segment — 29.1 px/s, whatever the viewport — while the ad boards
        // PLANTED AT THE STAND'S FEET are solved against the grass and run at
        // 48 to 57. The stand's foot is the back of the board, so those two are
        // at the same depth and were moving at half each other's speed;
        // reported from the couch as the background not keeping pace with the
        // ground at tiers 1 and 2, which is where the stand and the park
        // backdrop live.
        //
        // Fixed number to fixed number would only move the argument, so this is
        // the same solve the boards already use — [turfScroll] at the horizon's
        // own row — and the two can now only ever agree. It also tracks the
        // viewport, which the fixed period never did: at h=320 the boards run
        // 18% quicker than at h=400 and the stand behind them did not move at
        // all.
        final farPeriod = turfScroll(
          segmentWidth: farSegmentWidth,
          fraction: 1,
          turfHeight: h - horizon,
          contactBelowHorizon: feet - horizon,
          mood: mood,
        );

        // The far strip: the stand and its crowd, at the speed of the
        // ground it is planted in — see [farPeriod]. Its height is the TERRACE's
        // own, not a fraction of the page: at `h * 0.24` it was a 200px bank
        // of seats with a hundred 1px dots in it, which is the shape of a
        // crowd without being one.
        //
        // Built here and placed in one of two slots below: a stand goes UNDER
        // the turf, behind its boards; a park goes OVER it, because its
        // spectators stand on the grass — see [parkFansDrop].
        final park = tier < firstStandTier;
        final stand = Positioned(
          left: 0,
          right: 0,
          // ON the ad boards, not behind them: the stand's foot is the
          // back of the board, which is what puts the perimeter in front
          // of the front row instead of across its knees.
          //
          // **AND THE LIFT IS THE BOARDS' OWN HEIGHT, so when there are
          // no boards there is no lift.** Below `firstHoardingTier`
          // nothing is drawn in that band and the strip was still being
          // raised out of it, which left a `hoardingHeight` ribbon of
          // bare SKY between the park's fence and the top of the grass
          // — reported as the backdrop being cut off and the grass not
          // meeting the fence. The park's foot is the horizon, and the
          // horizon is where the turf starts, so there is now nowhere
          // for a gap to be.
          top:
              horizon -
              standHeightFor(tier) -
              (tier >= firstHoardingTier ? hoardingHeight : 0),
          // A park's strip runs on below the horizon for its spectators to
          // stand on; its houses and trees keep their feet on the line.
          height: standHeightFor(tier) + (park ? parkFansDrop : 0),
          // Tapping the terrace gets the crowd up — the JS's own
          // interaction, and the one thing on this screen that answers a
          // tap with a crowd rather than with a menu.
          child: _Crowd(
            celebration: celebration,
            // **ONE clock for every tile of the park**, above the row that
            // repeats it — see `scene_clock.dart` for the jump it stops.
            builder: (beat, excitement) => SceneClock(
              active: park && sprites,
              builder: (context, clock) => _GroundDrive(
                builder: (worldX) => _Scroller(
                  key: const ValueKey('pitch-stand'),
                  // A park's fans idle every frame, and so do a stand's
                  // front rows — see [_liveRows]; the rest is a picture.
                  // when it is up.
                  live: park ? sprites : true,
                  stillKey: (kitColor, haze, tier, sprites, night),
                  offsetPx: parallaxOffset(
                    worldX,
                    segmentWidth: farSegmentWidth,
                    period: farPeriod,
                    mood: mood,
                  ),
                  segmentWidth: farSegmentWidth,
                  liveChild: park
                      ? (sprites
                            ? _ParkFans(tier: tier, night: night, clock: clock)
                            : null)
                      : _StandSegment(
                          front: true,
                          kitColor: kitColor,
                          haze: haze,
                          beat: beat,
                          excitement: excitement,
                          tier: tier,
                        ),
                  // The stand at rest, which is nearly all of it and
                  // which never leaves the picture — see [_liveRows].
                  child: _StandSegment(
                    kitColor: kitColor,
                    haze: haze,
                    beat: 0,
                    excitement: 0,
                    tier: tier,
                    sprites: sprites,
                    night: night,
                  ),
                ),
              ),
            ),
          ),
        );

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
                // **THE COUNTRY BEHIND THE GROUND.** Kenney's hills, faded into
                // the haze by day and a black cut-out by night, crawling at a
                // sixth of the stand's pace. Their feet are on the stand's own
                // foot line, so a taller ground hides more of them — by design.
                // **ALWAYS A CHILD HERE, empty until the sprites land.** The
                // siblings carry no keys, so a child that came and went shifted
                // them all and rebuilt the crowd, the weather and the walker.
                Positioned(
                  left: 0,
                  right: 0,
                  top:
                      horizon -
                      (tier >= firstHoardingTier ? hoardingHeight : 0) -
                      _hillsSegmentWidth / kenneyHillsAspect(tier),
                  height: _hillsSegmentWidth / kenneyHillsAspect(tier),
                  child: !sprites
                      ? const SizedBox.shrink()
                      : _GroundDrive(
                          builder: (worldX) => _Scroller(
                            key: const ValueKey('pitch-hills'),
                            stillKey: (night, tier),
                            offsetPx: parallaxOffset(
                              worldX,
                              segmentWidth: _hillsSegmentWidth,
                              period: farPeriod * 6,
                              mood: mood,
                            ),
                            segmentWidth: _hillsSegmentWidth,
                            child: _HillsSegment(
                              tier: tier,
                              night: night,
                              haze: haze,
                            ),
                          ),
                        ),
                ),
                // **THE HEDGEROW BETWEEN THE PARK AND THE COUNTRY.** Asked
                // for from the couch: bushes behind the ground's own trees and
                // hut but in front of the hills, moving slower than the near
                // layer and faster than the far one, and NOT washed out to the
                // same degree.
                //
                // That middle speed is the whole point of it. Two layers give
                // you a near one and a far one and no sense of the distance
                // between them; a third at a rate in between is what turns two
                // pictures into depth — and the haze is the other half of the
                // same statement, so this takes a third of what the hills take
                // rather than all of it.
                //
                // **AND IT GROWS TO CLEAR A SMALL STAND.** From
                // `firstStandTier` the terrace covers this line — but a
                // non-league ground has trees behind it, and asked for from the
                // couch: at tier 2 you should still see the tops of them over
                // the roof. So the strip is as tall as the stand plus a crown's
                // worth at 2 and 3, and stops there: by 4 the ground is big
                // enough that what is behind it is the hills.
                if (tier <= lastTreelineTier)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: horizon - hedgeHeightFor(tier),
                    height: hedgeHeightFor(tier),
                    child: _GroundDrive(
                      builder: (worldX) => _Scroller(
                        key: const ValueKey('pitch-hedgerow'),
                        stillKey: (night, haze),
                        offsetPx: parallaxOffset(
                          worldX,
                          segmentWidth: _hedgeSegmentWidth,
                          period: farPeriod * _hedgeDepth,
                          mood: mood,
                        ),
                        segmentWidth: _hedgeSegmentWidth,
                        child: RepaintBoundary(
                          child: CustomPaint(
                            size: Size(
                              _hedgeSegmentWidth,
                              hedgeHeightFor(tier),
                            ),
                            painter: _HedgePainter(haze: haze, night: night),
                          ),
                        ),
                      ),
                    ),
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
                      standHeightFor(tier) * _pylonStands,
                      math.max(0, (horizon - hoardingHeight) * 0.92),
                    ),
                    child: _GroundDrive(
                      builder: (worldX) => _Scroller(
                        key: const ValueKey('pitch-floodlights'),
                        stillKey: (pylons, night),
                        offsetPx: parallaxOffset(
                          worldX,
                          segmentWidth: farSegmentWidth,
                          period: farPeriod * pylonDepth,
                          mood: mood,
                        ),
                        segmentWidth: farSegmentWidth,
                        child: _FloodlightSegment(count: pylons, lit: night),
                      ),
                    ),
                  ),
                // The stand, behind the boards and under the turf — see
                // [stand] for the park, which is drawn OVER the turf instead.
                if (tier >= firstStandTier) stand,
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
                // **NO ADVERTISING AT A PARK.** Nobody sells perimeter space at
                // a ground with no stand — the fence is the boundary down
                // there. Same tier the stand arrives at, so the two come
                // together and tier 2 reads as the first real GROUND.
                if (tier >= firstHoardingTier)
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
                        stillKey: kitColor,
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
                    tier: tier,
                    sprites: sprites,
                  ),
                ),
                // **THE PARK STANDS ON THE GRASS, so it goes over it.** Its
                // spectators are [parkFansDrop] below the horizon, in front of
                // the houses and trees whose feet are ON it — which is the
                // depth the strip had none of with everything on one line. Under
                // the turf that band of them was turf.
                if (tier < firstStandTier) stand,
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
                  // His own layer: his tick repainted the whole scene with him.
                  child: RepaintBoundary(
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
                          // **THE BALL GOES INSIDE HIM NOW, not over him.** It
                          // still draws above every part of the figure — that has
                          // not changed and is right — but being one of his own
                          // layers is what lets the near arm be drawn ONE MORE
                          // TIME on top of it while he is carrying, so the ball is
                          // closed round rather than balanced on. See
                          // `ManagerWalker.ballLayer`, and the JS's `.ps-hold-arm`,
                          // which exists to solve the same thing the hard way.
                          child: walkerBuilder(
                            Positioned.fill(
                              key: const ValueKey('pitch-ball'),
                              child: PitchBall(
                                mood: mood,
                                wind: ballWind,
                                frozen: frozen,
                                onCue: onBallCue ?? (_) {},
                                onStrike: onBallStrike,
                                onFlick: onBallFlick,
                                onWatch: onBallWatch,
                                sceneWidth: w,
                                walkerLeft: w * 0.45 - 57,
                              ),
                            ),
                          ),
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
      ),
    );
  }
}

/// How wide one tile of hills is. Wider than the stand's segment so the strip
/// stands taller than a park and shows above it.
const double _hillsSegmentWidth = 720;

/// Where the far village stands, per hill family: x across the tile, the foot
/// as a fraction of the height (just under the ridge line measured off the
/// sprite at that x), and how tall.
typedef _Villager = ({String path, double x, double up, double height});

List<_Villager> _villageFor(int tier) => tier < 2
    ? _hillsVillage
    : tier < 4
    ? _hillsLargeVillage
    : _peaksVillage;

// **`up` IS READ OFF THE RIDGE**, not tuned by eye: the LOWEST ridge row
// under the villager's whole footprint — one column was enough for a tree on
// a slope to hang its downhill side over the fall — eight pixels down so the
// base sits in the slope, over the cropped 240. Heights are fractions of a strip
// 1.9× taller than the old one, hence the small numbers.
const List<_Villager> _hillsVillage = [
  (path: 'assets/bg/kenney/treeSmall_green1.png', x: 0.035, up: 0.90, height: 0.083),
  (path: 'assets/bg/kenney/treeSmall_green3.png', x: 0.055, up: 0.91, height: 0.066),
  (path: 'assets/bg/kenney/treeSmall_green2.png', x: 0.070, up: 0.91, height: 0.088),
  (path: 'assets/bg/kenney/treeSmall_green1.png', x: 0.125, up: 0.85, height: 0.061),
  (path: 'assets/bg/kenney/houseSmall1.png', x: 0.205, up: 0.64, height: 0.066),
  (path: 'assets/bg/kenney/houseSmall2.png', x: 0.235, up: 0.59, height: 0.055),
  (path: 'assets/bg/kenney/treeSmall_green3.png', x: 0.255, up: 0.56, height: 0.055),
  (path: 'assets/bg/kenney/treeSmall_green2.png', x: 0.335, up: 0.48, height: 0.072),
  (path: 'assets/bg/kenney/treeSmall_green1.png', x: 0.415, up: 0.53, height: 0.055),
  (path: 'assets/bg/kenney/treeSmall_green1.png', x: 0.465, up: 0.65, height: 0.077),
  (path: 'assets/bg/kenney/treeSmall_green3.png', x: 0.485, up: 0.72, height: 0.061),
  (path: 'assets/bg/kenney/houseSmall2.png', x: 0.545, up: 0.87, height: 0.066),
  (path: 'assets/bg/kenney/treeSmall_green2.png', x: 0.575, up: 0.92, height: 0.072),
  (path: 'assets/bg/kenney/treeSmall_green1.png', x: 0.610, up: 0.96, height: 0.061),
  (path: 'assets/bg/kenney/treeSmall_green3.png', x: 0.630, up: 0.97, height: 0.072),
  (path: 'assets/bg/kenney/treeSmall_green2.png', x: 0.720, up: 0.84, height: 0.083),
  (path: 'assets/bg/kenney/treeSmall_green1.png', x: 0.790, up: 0.68, height: 0.061),
  (path: 'assets/bg/kenney/houseSmall1.png', x: 0.845, up: 0.55, height: 0.061),
  (path: 'assets/bg/kenney/treeSmall_green3.png', x: 0.865, up: 0.55, height: 0.072),
  (path: 'assets/bg/kenney/treeSmall_green2.png', x: 0.935, up: 0.66, height: 0.066),
];

const List<_Villager> _hillsLargeVillage = [
  (path: 'assets/bg/kenney/treeSmall_green1.png', x: 0.035, up: 0.67, height: 0.083),
  (path: 'assets/bg/kenney/treeSmall_green3.png', x: 0.055, up: 0.72, height: 0.066),
  (path: 'assets/bg/kenney/treeSmall_green2.png', x: 0.070, up: 0.75, height: 0.088),
  (path: 'assets/bg/kenney/treeSmall_green1.png', x: 0.125, up: 0.76, height: 0.061),
  (path: 'assets/bg/kenney/houseSmall1.png', x: 0.205, up: 0.60, height: 0.066),
  (path: 'assets/bg/kenney/houseSmall2.png', x: 0.235, up: 0.55, height: 0.055),
  (path: 'assets/bg/kenney/treeSmall_green3.png', x: 0.255, up: 0.51, height: 0.055),
  (path: 'assets/bg/kenney/treeSmall_green2.png', x: 0.335, up: 0.39, height: 0.072),
  (path: 'assets/bg/kenney/treeSmall_green1.png', x: 0.415, up: 0.45, height: 0.055),
  (path: 'assets/bg/kenney/treeSmall_green1.png', x: 0.465, up: 0.64, height: 0.077),
  (path: 'assets/bg/kenney/treeSmall_green3.png', x: 0.485, up: 0.72, height: 0.061),
  (path: 'assets/bg/kenney/houseSmall2.png', x: 0.545, up: 0.90, height: 0.066),
  (path: 'assets/bg/kenney/treeSmall_green2.png', x: 0.575, up: 0.95, height: 0.072),
  (path: 'assets/bg/kenney/treeSmall_green1.png', x: 0.610, up: 0.96, height: 0.061),
  (path: 'assets/bg/kenney/treeSmall_green3.png', x: 0.630, up: 0.95, height: 0.072),
  (path: 'assets/bg/kenney/treeSmall_green2.png', x: 0.720, up: 0.65, height: 0.083),
  (path: 'assets/bg/kenney/treeSmall_green1.png', x: 0.790, up: 0.22, height: 0.061),
  (path: 'assets/bg/kenney/houseSmall1.png', x: 0.845, up: 0.05, height: 0.061),
  (path: 'assets/bg/kenney/treeSmall_green3.png', x: 0.865, up: 0.05, height: 0.072),
  (path: 'assets/bg/kenney/treeSmall_green2.png', x: 0.935, up: 0.15, height: 0.066),
];

const List<_Villager> _peaksVillage = [
  (path: 'assets/bg/kenney/treeSmall_green1.png', x: 0.030, up: 0.30, height: 0.066),
  (path: 'assets/bg/kenney/treeSmall_green3.png', x: 0.090, up: 0.44, height: 0.061),
  (path: 'assets/bg/kenney/houseSmall1.png', x: 0.150, up: 0.23, height: 0.055),
  (path: 'assets/bg/kenney/treeSmall_green2.png', x: 0.220, up: 0.23, height: 0.066),
  (path: 'assets/bg/kenney/treeSmall_green1.png', x: 0.350, up: 0.85, height: 0.061),
  (path: 'assets/bg/kenney/treeSmall_green3.png', x: 0.420, up: 0.77, height: 0.066),
  (path: 'assets/bg/kenney/houseSmall2.png', x: 0.480, up: 0.46, height: 0.055),
  (path: 'assets/bg/kenney/treeSmall_green2.png', x: 0.620, up: 0.65, height: 0.066),
  (path: 'assets/bg/kenney/treeSmall_green1.png', x: 0.690, up: 0.52, height: 0.061),
  (path: 'assets/bg/kenney/treeSmall_green3.png', x: 0.750, up: 0.53, height: 0.066),
  (path: 'assets/bg/kenney/houseSmall1.png', x: 0.820, up: 0.30, height: 0.055),
  (path: 'assets/bg/kenney/treeSmall_green2.png', x: 0.890, up: 0.34, height: 0.066),
];

/// One tile of Kenney's hills. The sprite is a near-white silhouette, so by
/// day it is MULTIPLIED by a hill green — it read as cloud when only faded —
/// and by night it is a black cut-out.
/// How tall the hedgerow strip is, and how wide one tile of it is. Its own
/// width rather than the park's, so the two never repeat in step — a middle
/// layer that comes round with the layer in front of it is the layer in front
/// of it, drawn twice.
const double _hedgeHeight = 30;
const double _hedgeSegmentWidth = 560;

/// The last tier with a treeline behind the ground. Past it the stand is tall
/// enough that the country behind it is the hills' job.
const int lastTreelineTier = 3;

/// How much of the trees clears the roof of a small stand.
///
/// **Twice what it was, and then some.** Sixteen points of crown over a
/// non-league roof read as a mistake rather than as a wood — reported from the
/// couch twice, the second time asking for bigger again. A tree behind a stand
/// is a TREE: most of what you see of it is above the roof, not a green thumbnail
/// poking over the fascia.
const double _treetopRise = 27;

/// How tall the strip is at this tier: a hedgerow at a park, and enough to show
/// the crowns over a non-league roof at 2 and 3.
///
/// **THE BOARDS COUNT.** A stand from [firstHoardingTier] is raised by
/// [hoardingHeight] as well as being [standHeightFor] tall, so a strip that
/// only cleared the stand cleared nothing — the first cut of this put two
/// points of crown above the roof, which is to say none.
double hedgeHeightFor(int tier) => tier < firstStandTier
    ? _hedgeHeight
    : standHeightFor(tier) +
          (tier >= firstHoardingTier ? hoardingHeight : 0) +
          _treetopRise;

/// How much slower than the ground's own backdrop it runs. Between the park
/// (1) and the hills (6) — see the strip for why the middle is the point.
const double _hedgeDepth = 2.6;

/// **THE HEDGEROW.** A run of clipped bushes with a few small trees standing
/// out of it, lit along the top and dark underneath, on a bank of its own.
///
/// Painted rather than sprited: it is a silhouette at this distance, it has to
/// tile seamlessly at a width no sprite in the pack is, and a strip that draws
/// itself cannot be caught half-decoded.
class _HedgePainter extends CustomPainter {
  const _HedgePainter({required this.haze, required this.night});

  /// What the distance fades TO — the sky at the horizon. Taken at a THIRD of
  /// the hills' strength: this row is nearer, and the couch's note was that it
  /// should not be as washed out as the background.
  final Color haze;
  final bool night;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    if (h <= 0 || w <= 0) return;
    final rng = math.Random(53);
    final base = h;
    // Deeper than the park's own hedge and cooler with it, which is the colour
    // half of standing further back.
    final body = night ? const Color(0xFF425B49) : const Color(0xFF2C6438);
    final lit = night ? const Color(0xFF486851) : const Color(0xFF3E8248);

    // The bank the row stands on, so the hedge has ground under it rather than
    // hanging in the sky.
    canvas.drawRect(
      Rect.fromLTWH(0, base - h * 0.16, w, h * 0.16 + 1),
      Paint()..color = night ? const Color(0xFF405146) : const Color(0xFF2A5B31),
    );

    // **THE RUN CLOSES ACROSS THE SEAM.** Bushes are placed on a fixed pitch
    // from zero, so the last one before the edge and the first of the next tile
    // meet as one continuous hedge instead of leaving a notch every loop.
    const pitch = 26.0;
    for (var x = -pitch; x < w + pitch; x += pitch) {
      final bh = h * (0.42 + rng.nextDouble() * 0.3);
      final bw = pitch * (1.5 + rng.nextDouble() * 0.4);
      final box = Rect.fromLTWH(x, base - bh, bw, bh * 2);
      canvas.drawOval(box, Paint()..color = body);
      canvas.drawOval(
        Rect.fromLTWH(x + bw * 0.16, base - bh + 1, bw * 0.5, bh * 0.5),
        Paint()
          ..color = lit
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    // **THE TREES, AND NO TWO OF THEM ALIKE.** Four evenly spaced ovals of one
    // size is a row of green bumps — reported from the couch twice, the second
    // time asking outright whether they read as trees at all. They did not, and
    // the reason is that an ellipse has no tree in it: what says tree at a
    // hundred yards is the OUTLINE, either a spire or a lumpy mass of clumps,
    // and either of those against a sky nothing else is that shape.
    //
    // So: two species, a conifer drawn as four narrowing skirts to a point and
    // a broadleaf built out of five overlapping clumps, at heights running from
    // half the strip to all of it, on a spacing that is nobody's rhythm.
    // Seeded off the same stream as the hedge, so the wood is the same wood on
    // every frame and on every phone.
    const spots = [0.03, 0.13, 0.21, 0.34, 0.44, 0.52, 0.66, 0.73, 0.86, 0.95];
    for (var i = 0; i < spots.length; i++) {
      final cx = w * spots[i] + (rng.nextDouble() - 0.5) * 22;
      // **AND NOTHING REACHES THE TOP OF THE BOX.** A crown is drawn about a
      // centre with a radius on top of it, so a tree as tall as its own strip
      // has its head cut off flat along the edge of the frame — reported from
      // the couch. The tallest here comes out at about nine tenths of the
      // strip, crown and all.
      final th = h * (0.45 + rng.nextDouble() * 0.4);
      final pine = rng.nextDouble() < 0.45;
      final trunkW = th * (pine ? 0.05 : 0.07);
      canvas.drawRect(
        Rect.fromLTWH(cx - trunkW / 2, base - th * 0.55, trunkW, th * 0.55),
        Paint()..color = night ? const Color(0xFF414A46) : const Color(0xFF4A3626),
      );
      if (pine) {
        // Four skirts to a point, each wider than the one above it.
        final spread = th * (0.19 + rng.nextDouble() * 0.07);
        for (var k = 3; k >= 0; k--) {
          final top = base - th * (1 - k * 0.17);
          final halfW = spread * (0.42 + k * 0.2);
          canvas.drawPath(
            Path()
              ..moveTo(cx, top)
              ..lineTo(cx + halfW, top + th * 0.3)
              ..lineTo(cx + halfW * 0.55, top + th * 0.3)
              ..lineTo(cx - halfW * 0.55, top + th * 0.3)
              ..lineTo(cx - halfW, top + th * 0.3)
              ..close(),
            Paint()..color = k == 0 ? lit : body,
          );
        }
      } else {
        // A crown of clumps, not an oval: five discs round a centre, each its
        // own size, so the silhouette comes out lumpy the way a canopy is.
        final crownR = th * (0.24 + rng.nextDouble() * 0.1);
        final cy = base - th * 0.72;
        final crown = Path();
        for (var k = 0; k < 5; k++) {
          final a = k / 5 * 2 * math.pi + rng.nextDouble() * 0.5;
          final rr = crownR * (0.52 + rng.nextDouble() * 0.34);
          crown.addOval(
            Rect.fromCircle(
              center: Offset(
                cx + math.cos(a) * crownR * 0.62,
                cy + math.sin(a) * crownR * 0.44,
              ),
              radius: rr,
            ),
          );
        }
        crown.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: crownR * 0.8));
        canvas.drawPath(crown, Paint()..color = body);
        // The light on top of it, clipped to the clumps so it takes their edge.
        canvas.save();
        canvas.clipPath(crown);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx - crownR * 0.3, cy - crownR * 0.5),
            width: crownR * 1.3,
            height: crownR * 0.9,
          ),
          Paint()
            ..color = lit
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
        );
        canvas.restore();
      }
    }

    // The air in front of it — a third of what the hills take, so it sits
    // between the park and the country rather than joining either.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = haze.withValues(alpha: 0.12)
        ..blendMode = BlendMode.srcATop,
    );
  }

  @override
  bool shouldRepaint(_HedgePainter old) =>
      old.haze != haze || old.night != night;
}

class _HillsSegment extends StatelessWidget {
  const _HillsSegment({
    required this.tier,
    required this.night,
    required this.haze,
  });

  final int tier;
  final bool night;
  final Color haze;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _hillsSegmentWidth,
    height: double.infinity,
    // The remastered sprite's edge columns are opaque and its ridge meets
    // itself across the tile, so it is drawn at exactly its slot. (The
    // originals' half-transparent edges needed cutting two columns in.)
    child: ClipRect(
      child: OverflowBox(
      minWidth: _hillsSegmentWidth,
      maxWidth: _hillsSegmentWidth,
      child: ColorFiltered(
        // The night cut-out takes the village with it; the day green does not.
        // Night: a solid black cut-out, village and all. At 85% the green
        // showed through and the hills read dark green rather than black.
        colorFilter: night
            // Not quite black any more — see [_turfNight] for the lift.
            ? const ColorFilter.mode(Color(0xFF2D3138), BlendMode.srcATop)
            : const ColorFilter.mode(Colors.transparent, BlendMode.srcATop),
        child: LayoutBuilder(
          builder: (context, box) {
            final h = box.maxHeight;
            final w = box.maxWidth;
            // A far village along the slopes and ridges: the same trees and
            // houses, a tenth of the size, each standing just under the hill
            // line at its x — see [_villageFor] — washed into the haze rather
            // than tinted, so a house stays a house and not a green one.
            Widget far(String path, double x, double up, double height) =>
                Positioned(
                  left: w * x,
                  bottom: h * up,
                  child: Opacity(
                    opacity: 0.5,
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        haze.withValues(alpha: 0.35),
                        BlendMode.srcATop,
                      ),
                      child: Image.asset(
                        path,
                        height: h * height,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                );
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.8,
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF8FBF7E),
                        BlendMode.modulate,
                      ),
                      child: Image.asset(
                        kenneyHillsFor(tier),
                        fit: BoxFit.fill,
                        alignment: Alignment.bottomCenter,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ),
                for (final v in _villageFor(tier))
                  far(v.path, v.x, v.up, v.height),
                // **AND THE VILLAGE HAS ITS LIGHTS ON.** A speck of warm each,
                // over the cut-out rather than in it: the night filter above
                // takes the whole strip to near-black, houses and all, so a
                // window drawn inside it would be black too. At this size the
                // light IS the house — which is what a village on a hill looks
                // like after dark. Asked for from the couch with the park's.
                if (night)
                  for (final v in _villageFor(tier))
                    if (v.path.contains('house'))
                      Positioned(
                        // Centred on the wall, not hung off its corner: the
                        // glow is drawn round the speck now, so the box is five
                        // times the size it was.
                        left:
                            w * v.x +
                            h * v.height * 0.32 -
                            h * v.height * 0.55,
                        bottom:
                            h * v.up +
                            h * v.height * 0.28 -
                            h * v.height * 0.55,
                        child: _VillageLight(size: h * v.height * 0.22),
                      ),
              ],
            );
          },
        ),
      ),
    ),
    ),
  );
}

/// Who is watching from the park fence: a couple, and from the first stand
/// up the terrace has them.
///
/// **TIER 1 IS THE FLOOR.** `stadiumTierProvider` clamps to 1, so a tier-0
/// park is never on the home screen — the "couple at the first ground, small
/// crowd at the second" split put fourteen people at the only park a player
/// sees. Asked for as one or two: a park is a park.
/// **AND A CLUB WITH A GROUND DRAWS MORE THAN ONE WITHOUT.** Both park tiers
/// stood the same two people on the touchline, which makes the first thing a
/// player ever buys change nothing about who turned up — asked about from the
/// couch in those words. One at the locked ground, four at tier 1, and from
/// [firstStandTier] the terrace has them instead.
List<int> parkSpectatorSeeds(int tier) => [
  for (
    var i = 0;
    i < (tier >= firstStandTier ? 0 : (tier <= 0 ? 1 : 4));
    i++
  )
    700 + i,
];

/// Every file the park's spectators draw, for the scene's gate.
List<String> parkSpectatorAssets(int tier) => [
  for (final seed in parkSpectatorSeeds(tier))
    ...spectatorAssets(spectatorLook(seed)),
];

/// Across the segment, per head-count: a pair stands together, a small crowd
/// is a knot of three, a couple and two on their own. Keyed by count rather
/// than indexed, so a count with no entry is a missing key and not the wrong
/// row.
const Map<int, List<double>> _spectatorSpots = {
  0: [],
  1: [0.62],
  2: [0.58, 0.64],
  3: [0.12, 0.60, 0.66],
  4: [0.08, 0.14, 0.60, 0.84],
  5: [0.06, 0.24, 0.29, 0.63, 0.89],
  6: [0.05, 0.19, 0.24, 0.52, 0.67, 0.86],
  7: [0.04, 0.17, 0.22, 0.27, 0.58, 0.63, 0.91],
};

/// The fans, drawn LIVE over the still park so they can shift their weight —
/// **and the trees and bushes, so they can sway.**
///
/// Seven small paper dolls a frame is cheap; a still strip could not move
/// them at all. Each idles at its own phase of ONE clock, so the knot of three
/// never sways as one, and reduced motion stops the clock and leaves them
/// standing.
///
/// **The clock is handed in, not owned.** This segment is tiled across the
/// strip, and a ticker per copy put a late tile out of step with the rest —
/// see `scene_clock.dart`.
///
/// The trees moved up here from [_ParkSegment] when the couch asked for the
/// background to breathe the way a reference game's did: its canopies rock a
/// degree or two about the trunk on slow, unequal clocks. Ten sprites more a
/// frame on a layer that already redraws is nothing; the houses stay in the
/// still, because a house does not move. Drawn BEHIND the fans, which is where
/// the still had them.
class _ParkFans extends StatelessWidget {
  const _ParkFans({
    required this.tier,
    required this.night,
    required this.clock,
  });

  final int tier;
  final bool night;

  /// Seconds, shared by every tile of the strip.
  final ValueListenable<double> clock;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final h = box.maxHeight;
      const w = farSegmentWidth;
      final seeds = parkSpectatorSeeds(tier);
      // The houses are [parkPropsDrop] below the horizon and the spectators
      // [parkFansDrop] below it — the lines the still is padded to. A tree or a
      // bush stands on its OWN one; see [parkTreeDrops].
      final ph = h - parkFansDrop + parkPropsDrop;
      Widget sway(
        String path,
        double x,
        double height, {
        required int seed,
        double amplitude = 0.022,
        double drop = parkPropsDrop,
      }) => Positioned(
        left: x,
        bottom: parkFansDrop - drop,
        child: ParkSway(
          clock: clock,
          seed: seed,
          amplitude: amplitude,
          child: Image.asset(
            path,
            // Further forward is nearer, so it is bigger: a stagger in depth
            // with no change of size is a row of cut-outs shuffled up and down.
            height: height * (1 + (drop - parkPropsDrop) * 0.012),
            filterQuality: FilterQuality.medium,
          ),
        ),
      );
      // Its own size, as every segment: a row of strips cannot size this.
      final fans = Stack(
          clipBehavior: Clip.none,
          children: [
            // The same trees, each on its own line — see [parkTreeDrops].
            sway(kenneyTrees[0], w * 0.03, ph, seed: 1, drop: parkTreeDrops[0]),
            sway(kenneyTrees[1], w * 0.30, ph * 0.96, seed: 2, drop: parkTreeDrops[1]),
            sway(kenneyTreesSmall[1], w * 0.42, ph * 0.55, seed: 3, drop: parkTreeDrops[2]),
            sway(kenneyTrees[2], w * 0.50, ph, seed: 4, drop: parkTreeDrops[3]),
            sway(kenneyTrees[0], w * 0.71, ph * 0.9, seed: 5, drop: parkTreeDrops[4]),
            sway(kenneyTreesSmall[2], w * 0.90, ph * 0.5, seed: 6, drop: parkTreeDrops[5]),
            // A bush is low and stiff: half the lean.
            sway(kenneyBushes[0], w * 0.15, ph * 0.24, seed: 7, amplitude: 0.022, drop: parkBushDrops[0]),
            sway(kenneyBushes[2], w * 0.38, ph * 0.22, seed: 8, amplitude: 0.022, drop: parkBushDrops[1]),
            sway(kenneyBushes[1], w * 0.64, ph * 0.26, seed: 9, amplitude: 0.022, drop: parkBushDrops[2]),
            sway(kenneyBushes[3], w * 0.95, ph * 0.22, seed: 10, amplitude: 0.022, drop: parkBushDrops[3]),
            for (final (i, seed) in seeds.indexed)
              Positioned(
                left: w * _spectatorSpots[seeds.length]![i],
                bottom: 0,
                // **THE FIGURE IS BUILT ONCE and only a transform moves.** Its
                // fourteen images rebuilt every frame, times the tiles the
                // strip draws, was the whole home page going slow.
                child: _Shuffle(
                  clock: clock,
                  seed: seed,
                  child: ModularFigure(
                    look: spectatorLook(seed),
                    height: h * (0.50 + (seed % 3) * 0.04),
                  ),
                ),
              ),
          ],
        );
      // The park's own night tint: a live layer misses the still strip's.
      return SizedBox(
        width: w,
        height: h,
        child: night
            ? ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  // Lifted with the rest of the night — see [_turfNight].
                  Color(0x6E141C2E),
                  BlendMode.srcATop,
                ),
                child: fans,
              )
            : fans,
      );
    },
  );
}

/// A tree in a breeze: a slow rock about its own foot, on a clock of its own.
///
/// **Public for the test that pins it to a breeze rather than a gale.** The
/// reference canopy moves a degree or two and never more; [amplitude] is in
/// radians and the default is about 2.6°.
///
/// **It was 1.3° and nobody could see it.** Reported from the couch as the
/// background not moving at all — which it was, by about a pixel at the top of
/// a tree. Doubled, plus a bob of its own: a canopy in a breeze rises and falls
/// as well as leaning, and the vertical is what the eye actually catches. Periods differ by [seed] so a row of
/// trees never nods in step, which is what would make it read as one sprite.
class ParkSway extends StatelessWidget {
  const ParkSway({
    required this.clock,
    required this.seed,
    required this.child,
    this.amplitude = 0.045,
    super.key,
  });

  final ValueListenable<double> clock;
  final int seed;
  final double amplitude;
  final Widget child;

  /// Where one tree is in its sway at [seconds], as an angle.
  double angleAt(double seconds) {
    final period = 3.6 + (seed % 4) * 0.7;
    final phase = (seconds / period + seed * 0.29) % 1;
    // A breeze is not a metronome: a second, slower wave rides on the first
    // so the lean pauses and gusts rather than ticking.
    final gust = math.sin((seconds / (period * 2.7) + seed * 0.11) * 2 * math.pi);
    return amplitude * math.sin(phase * 2 * math.pi) * (0.7 + 0.3 * gust);
  }

  /// And how far it rises, in points.
  double bobAt(double seconds) {
    final period = 2.3 + (seed % 5) * 0.6;
    return 0.7 * math.sin((seconds / period + seed * 0.41) * 2 * math.pi).abs();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: clock,
    child: child,
    builder: (context, tree) => Transform.translate(
      // Half a point of rise on twice the lean's period, so it never beats in
      // time with the sway and read as one motion.
      offset: Offset(0, -bobAt(clock.value)),
      child: Transform.rotate(
        angle: angleAt(clock.value),
        alignment: Alignment.bottomCenter,
        child: tree!,
      ),
    ),
  );
}

/// One fan's idle: a shift of weight on their own slow clock — a point or two
/// of translation and a hair of lean over a figure that never rebuilds.
class _Shuffle extends StatelessWidget {
  const _Shuffle({required this.clock, required this.seed, required this.child});

  final ValueListenable<double> clock;
  final int seed;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: clock,
    child: child,
    builder: (context, figure) {
      // **BIG ENOUGH TO SEE.** A point of drift and half a point of rise is a
      // figure standing still as far as anybody watching is concerned —
      // reported from the couch as the background not moving at all. Twice
      // that, on a quicker clock, and it reads as somebody shifting their
      // weight on a cold touchline.
      final phase = (clock.value / (2.2 + (seed % 5) * 0.4) + seed * 0.37) % 1;
      final wave = math.sin(phase * 2 * math.pi);
      return Transform.translate(
        offset: Offset(wave * 1.4, -wave.abs() * 1.5),
        child: Transform.rotate(
          angle: wave * 0.04,
          alignment: Alignment.bottomCenter,
          child: figure!,
        ),
      );
    },
  );
}

/// A park out of Kenney's pieces: houses into the haze. Stands in for
/// [ParkPainter] once the sprites have decoded; the painter is what draws until
/// then.
///
/// **The trees and bushes are not here.** They are in [_ParkFans], the live
/// layer over this one, so they can sway; this is the snapshot, and a snapshot
/// cannot. The houses stay, being the one thing in a park that holds still.
class _ParkSegment extends StatelessWidget {
  const _ParkSegment({
    required this.haze,
    required this.night,
    required this.tier,
  });

  final Color haze;
  final bool night;
  final int tier;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final h = box.maxHeight;
      const w = farSegmentWidth;
      Widget at(String path, double x, double height, {double fade = 0}) {
        final image = Image.asset(
          path,
          height: height,
          filterQuality: FilterQuality.medium,
        );
        final Widget hazed = fade == 0
            ? image
            : ColorFiltered(
                colorFilter: ColorFilter.mode(
                  haze.withValues(alpha: fade),
                  BlendMode.srcATop,
                ),
                child: image,
              );
        return Positioned(
          left: x,
          bottom: 0,
          // **SOMEBODY IS IN.** Asked for from the couch: at night the houses
          // behind the ground should have their lights on. Two warm windows and
          // the bloom around them, laid OVER the sprite and outside the park's
          // night tint — a lit window that takes the same blue wash as the wall
          // it is in is a pale rectangle, not a light. See [_LitWindows].
          child: night
              ? Stack(
                  // The glow is BIGGER THAN THE HOUSE — that is what makes it a
                  // light rather than a bright wall — so nothing may clip it.
                  clipBehavior: Clip.none,
                  children: [
                    hazed,
                    Positioned.fill(child: _LitWindows(size: height * 0.12)),
                  ],
                )
              : hazed,
        );
      }
      final park = Stack(
        clipBehavior: Clip.none,
        children: [
          at(kenneyHouses[2], w * 0.10, h * 0.78, fade: 0.35),
          at(kenneyHouses[0], w * 0.58, h * 0.92, fade: 0.35),
          at(kenneyHouses[3], w * 0.80, h * 0.74, fade: 0.35),
          // The trees and bushes are live — see [_ParkFans].
          // No fence. Kenney's 104px piece has a post at each end, so tiled
          // along the foot it read as a row of fences; the boundary is the
          // touchline on the turf now — see [touchlineBelowHorizon].
        ],
      );
      return SizedBox(
        width: w,
        height: h,
        child: night
            ? ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Color(0x99060A14),
                  BlendMode.srcATop,
                ),
                child: park,
              )
            : park,
      );
    },
  );
}

/// **A HOUSE WITH THE LIGHTS ON, THROWING LIGHT.** Asked for from the couch
/// several times over, and the last two are what shaped it: the windows should
/// EMIT a glow, and the glow has to be **concentrated where the light is and at
/// nothing by the edge of its box**.
///
/// Both notes are the same fault. The first pass hung `BoxShadow`s off the
/// panes and a wide soft ball over the whole house: a box shadow is a blurred
/// RECTANGLE, so it reads as a bright smear with corners, and a ball that broad
/// is fog on the roof rather than light out of a window. This is a radial
/// gradient per WINDOW instead — hottest on the pane, most of it spent inside a
/// third of the radius, and exactly zero at the rim, so nothing has an edge to
/// see. The only wide thing left is the pool on the grass outside the door,
/// which is what the light lands ON.
class _LitWindows extends StatelessWidget {
  const _LitWindows({required this.size});

  /// One window's height. Off the house, so a cottage does not get the big
  /// house's window.
  final double size;

  /// Light out of one opening: hot at the middle, gone at the rim.
  static const RadialGradient _lamp = RadialGradient(
    colors: [
      Color(0xF2FFE9B8),
      Color(0xA6FFCE7A),
      Color(0x3DFFC168),
      Color(0x00FFC168),
    ],
    stops: [0, 0.16, 0.42, 1],
  );

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        final halo = size * 5.2;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // What the light lands on outside the door. Flattened, because the
            // ground is not a wall and a circle of light on it is a balloon.
            Positioned(
              left: -w * 0.25,
              width: w * 1.5,
              bottom: -h * 0.12,
              height: h * 0.4,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Color(0x66FFC873),
                      Color(0x1FFFC168),
                      Color(0x00FFC168),
                    ],
                    stops: [0, 0.45, 1],
                  ),
                ),
              ),
            ),
            for (final x in const [-0.45, 0.42]) ...[
              Align(
                alignment: Alignment(x, 0.35),
                child: SizedBox(
                  width: halo,
                  height: halo,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _lamp,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment(x, 0.35),
                child: Container(
                  width: size * 0.85,
                  height: size,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6DF),
                    borderRadius: BorderRadius.circular(size * 0.12),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}

/// One lit window on a hillside, a mile off: a hot speck inside a glow that is
/// gone by the edge of its own box. Any bigger and the hills stop being far
/// away — see [_LitWindows] for why this is a gradient and not a box shadow.
class _VillageLight extends StatelessWidget {
  const _VillageLight({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final core = math.max(1.2, size);
    final halo = core * 5;
    return IgnorePointer(
      child: SizedBox(
        width: halo,
        height: halo,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0xF2FFE9B8),
                    Color(0x99FFCE7A),
                    Color(0x33FFC168),
                    Color(0x00FFC168),
                  ],
                  stops: [0, 0.18, 0.45, 1],
                ),
              ),
            ),
            Container(
              width: core,
              height: core,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6DF),
                borderRadius: BorderRadius.circular(core * 0.3),
              ),
            ),
          ],
        ),
      ),
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
  /// **THE CLOCK RUNS, and only the front rows pay for it.** Every fan in every
  /// deck bouncing was half the UI thread on a flagship phone, so the crowd
  /// was stopped dead at rest — and a still stand from tier 3 up was asked
  /// about from the couch, against a park whose few fans never stop. The split
  /// at [_liveRows] is what makes a resting bounce affordable: the keenest
  /// fifth of two rows move, the rest is one picture.
  void _sync() {
    final run = !MediaQuery.of(context).disableAnimations;
    if (run && !_c.isAnimating) {
      _last = Duration.zero;
      _c.repeat();
    } else if (!run && _c.isAnimating) {
      _c.stop();
    }
  }

  void _surge() {
    setState(() => _excitement = 1);
    _sync();
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
    if (_excitement <= 0) _sync();
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
      _surge();
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const ValueKey('pitch-stand-tap'),
    // Opaque, so the terrace answers a tap that lands on a gap between two
    // supporters rather than only on a head.
    behavior: HitTestBehavior.opaque,
    onTap: _surge,
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

/// **HOW THE STAND IS PUT TOGETHER AT A GIVEN TIER.** Ported from `_deckPlan`
/// in `../merge-empire-fc/src/ui/components/PitchScene.js`, and the port had
/// none of it: six rows in one deck at every tier, so a Sunday League pitch and
/// an empire mega-stadium were the same ground with a different sky.
///
/// **Stands only start at tier 2.** Tiers 0 and 1 are a PARK — trees, a hedge,
/// a low white fence and, at tier 1, one or two people loitering on the
/// touchline. That is the whole of the art brief for the bottom of the pyramid
/// and it is why [standRows] floors at one only from tier 2 up.
///
/// They grow hard from there: one shallow row at tier 2 to seven packed rows at
/// the top, and past tier 6 the rows are split into stacked DECKS with a facade
/// wall between them. One long terrace reads as a non-league bank of seats
/// however many rows you give it; a second and third deck is what makes it read
/// as a stadium.
///
/// Shared by the segment, the floodlight height and the horizon, so there is one
/// answer to "how tall is the stand" rather than three guesses.
typedef DeckPlan = ({
  int rows,
  int decks,
  List<int> perDeck,
  List<double> deckHs,

  /// How far away each deck is, as a scale on everything drawn in it. See
  /// [deckDepth].
  List<double> deckScales,
  double standH,
});

/// **THE TIER THE CROWD BRINGS BANNERS.** Below it the support is a stand full
/// of replica shirts; at the top of the pyramid it is an END — scarves held up
/// over the heads and big two-pole flags waving above them.
///
/// Asked for from the couch, naming 7 and 8. It is a real difference in kind
/// rather than more of the same: the crowd already grew from twelve a row to
/// thirty-three and got taller decks with it, and none of that says "this is a
/// club with a following" the way one banner does.
const int firstFlagTier = 7;

/// How many of the crowd hold a scarf up, at this tier.
double scarfShare(int tier) => tier < firstFlagTier
    ? 0
    : (tier == firstFlagTier ? 0.10 : 0.16);

/// How many hold a flag. Rare on purpose: a flag is drawn over the fans around
/// it, and a terrace where every tenth seat has a banner in front of it is a
/// bunting line rather than a crowd.
double flagShare(int tier) => tier < firstFlagTier
    ? 0
    : (tier == firstFlagTier ? 0.012 : 0.02);

/// The lowest tier that has a stand at all.
const int firstStandTier = 2;

/// **HOW MUCH SMALLER EACH DECK BEHIND THE FRONT ONE IS DRAWN.**
///
/// The stand used to be three decks at ONE size stacked vertically with a
/// balcony wall between them, and what that reads as is a single very tall bank
/// of seats rather than a ground with tiers in it. Asked for from the couch in
/// as many words: the closest is layer one, layer two is a little smaller and
/// further away, and the same again for layer three.
///
/// So a deck is a DEPTH now, and one number carries it: the fans, the row
/// pitch and the deck's own height all take the same scale, because a deck
/// where only the people shrank would be small fans in a full-size stand.
///
/// 0.84 per step, which puts a three-decker's back tier at 0.71 — plainly
/// further off without the top of the ground turning into a hairline. It was
/// 0.88 and the decks still read as one wall; asked for again from the couch:
/// stadiums go BACK as they go up. The rows
/// WITHIN a deck already narrow toward the back; this is the same idea one
/// level up, and the two compound the way they do in a real ground.
const double _deckDepth = 0.84;

/// The scale for deck [index] of [decks], nearest first at 1.0.
///
/// **Index 0 is the FURTHEST deck**, which is the order `_StandPainter` draws
/// in — highest up the screen, painted first so the deck in front of it
/// overlaps it — so the exponent counts back from the last entry.
double deckDepth(int decks, int index) =>
    math.pow(_deckDepth, decks - 1 - index).toDouble();

DeckPlan deckPlan(int tier) {
  final rows = math.max(1, math.min(7, tier - 1));
  final decks = tier >= 8
      ? 3
      : tier >= 6
      ? 2
      : 1;
  final perDeck = <int>[];
  var left = rows;
  for (var d = 0; d < decks; d++) {
    // The FRONT deck is the deepest, which is what a real ground looks like
    // from the halfway line.
    final n = math.max(1, (left / (decks - d)).ceil());
    perDeck.add(n);
    left -= n;
  }
  final deckScales = [for (var d = 0; d < decks; d++) deckDepth(decks, d)];
  final deckHs = [
    for (var d = 0; d < decks; d++)
      ((_deckPad + perDeck[d] * _rowPitch) * _crowdScale * deckScales[d])
          .roundToDouble(),
  ];
  final standH =
      deckHs.fold<double>(0, (a, b) => a + b) + (decks - 1) * _facadeHeight;
  return (
    rows: rows,
    decks: decks,
    perDeck: perDeck,
    deckHs: deckHs,
    deckScales: deckScales,
    standH: standH,
  );
}

/// The balcony wall between two decks. The JS's `FACADE_H`.
const double _facadeHeight = 8;

/// Fans across one segment, at this tier. The JS's `9 + tier * 3` against its
/// own segment width — support that grows with you.
int fansPerRow(int tier) => 9 + tier * 3;

/// Seat-row spacing and the dead terrace under the front row, before scale. 6
/// rather than the 14 it started at: at 14 there was an empty band along the
/// bottom of the deck that read as an unsold front row.
const double _rowPitch = 9;
const double _deckPad = 6;

/// The fascia over the back row. Static in the JS on purpose — a uniform beam
/// shows no motion, and the crowd scrolls underneath it.
const double _roofHeight = 9;

/// The whole silhouette, roof included. Exported because the horizon is where
/// the stand's FOOT goes, so the caller has to know how tall it is.
///
/// **A PARK HAS NO STAND**, so tiers 0 and 1 answer with the height of the tree
/// line instead — the strip is still there and still scrolls, it is just not
/// made of seats.
double standHeightFor(int tier) =>
    tier < firstStandTier ? parkHeight : deckPlan(tier).standH + _roofHeight;

/// How tall the park's own horizon strip is: a tree, its crown and its trunk.
const double parkHeight = 46 * _crowdScale;

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

/// Hair over the crowd's heads. Dark, mostly, with a few fair and a few grey.
const List<Color> _fanHair = [
  Color(0xFF2A1B12),
  Color(0xFF1A1A1A),
  Color(0xFF5B3A22),
  Color(0xFF2A1B12),
  Color(0xFFB88A4A),
  Color(0xFF8A8A8A),
  Color(0xFF3B2A1E),
];

/// Skin variety, which the JS gets out of `nth-child` selectors for nothing.
const List<Color> _fanSkins = [
  Color(0xFFD8A982),
  Color(0xFFB9825A),
  Color(0xFF8A5A37),
  Color(0xFFF0C9A5),
  Color(0xFF5F3A22),
];

/// **HOW MUCH OF THE CROWD KEEPS MOVING THROUGH A SURGE.**
///
/// The stand is one snapshot at rest, and a surge used to drop it: every fan in
/// every deck redrawn each frame for the 2.4s a celebration lasts, and the idle
/// gesture rota fires those with nobody touching the screen. So the strip splits
/// at a row — everything behind these front rows holds its resting pose and
/// stays inside the picture, and only these are drawn live over the top.
///
/// The front rows are the ones worth spending it on: they are the biggest, the
/// least hazed and the nearest the eye.
const int _liveRows = 2;

class _StandSegment extends StatelessWidget {
  const _StandSegment({
    required this.kitColor,
    required this.haze,
    required this.beat,
    required this.excitement,
    required this.tier,
    this.front = false,
    this.sprites = false,
    this.night = false,
  });

  final Color kitColor;
  final Color haze;

  /// Kenney's pieces have decoded, so a park is built from them.
  final bool sprites;
  final bool night;

  /// True for the LIVE layer — the front rows and the washes over them. See
  /// [_liveRows].
  final bool front;

  /// How grand the ground is — see [deckPlan]. Below [firstStandTier] this
  /// segment is a PARK and not a stand at all.
  final int tier;

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
    child: tier < firstStandTier
        // **THE PARK DRAWS ITSELF; there is no photographic plate behind it.**
        //
        // A Kenney backdrop was tried here through five reports and every one of
        // them was the same fault in a new place: a daylit square drawing does
        // not belong behind a scene that has its own sky and its own light. It
        // was scaled by the wrong axis, then cropped to its treeline, then had
        // its sky knocked out in `tool/gen_park_backdrop.py`, then dimmed by
        // 45% for the dark theme — and it still read as a pasted rectangle in
        // both themes, because the thing that was wrong with it was never the
        // crop. Reported last as not working in either mode.
        //
        // [ParkPainter] was always drawing the park IN FRONT of it — three
        // trees, a hedge, a spectator or two and the white fence — off the kit
        // scale and against the scene's own sky. That is the whole horizon, and
        // it cannot come apart from the pitch: every element stands on
        // `size.height`, which is the horizon by construction. So the plate is
        // gone and nothing has replaced it.
        ? Padding(
            // The strip runs on below the horizon for the spectators; the
            // park's own feet stay on it — see [parkFansDrop].
            padding: const EdgeInsets.only(
              bottom: parkFansDrop - parkPropsDrop,
            ),
            child: sprites
                ? _ParkSegment(haze: haze, night: night, tier: tier)
                : CustomPaint(
                    painter: ParkPainter(
                      haze: haze,
                      tier: tier,
                      night: night,
                    ),
                  ),
          )
        : CustomPaint(
            painter: _StandPainter(
              kitColor: kitColor,
              haze: haze,
              beat: beat,
              excitement: excitement,
              tier: tier,
              front: front,
            ),
          ),
  );
}


/// **THE BOTTOM TWO TIERS HAVE NO GROUND**, which is the art brief and which
/// the port had dropped: a hedge line, three trees, a low white fence — and at
/// tier 1, one or two people loitering on the touchline. No stand, just a
/// couple of people. Ported from `_parkSegment`.
/// The park at the horizon: three trees, a hedge, a spectator or two and the
/// low white fence, on the strip whose bottom edge IS the horizon.
///
/// **Public so a test can read its pixels back.** The invariant that kept
/// regressing is that the strip is TRANSPARENT above the treeline — the aerial
/// haze used to be a `drawRect` over the whole of it, which put a hard-edged
/// rectangle of lighter sky across the diorama and was reported nine times as
/// the backdrop being cropped. Nothing about that is visible from the outside
/// except the pixels, so the pixels are what `pitch_scene_test` checks.
class ParkPainter extends CustomPainter {
  const ParkPainter({required this.haze, required this.tier, this.night = false});

  final Color haze;
  final int tier;

  /// Whether the lights are on in the changing rooms — see [_LitWindows] for
  /// the sprite park's own.
  final bool night;

  @override
  void paint(Canvas canvas, Size size) {
    // Seeded like the crowd is, so the tree line does not reshuffle per frame.
    final rng = math.Random(11);
    final scale = _crowdScale;
    final unit = size.width / 480;
    final h = size.height;
    final base = h;
    // The strip runs on below this for the spectators — see [parkFansDrop].
    final fanLine = base + (parkFansDrop - parkPropsDrop);

    // This IS the horizon at these tiers — there is no plate behind it. See
    // the segment for the five reports that established that.
    //
    // **THE HAZE GOES ON THE THINGS AT THE HORIZON, NOT ON THE AIR ABOVE THEM,
    // and that rectangle is the line this strip has been reported for.** The
    // `srcATop` wash at the foot of this method tints only what this painter
    // put down; the sky keeps its own colour. Everything above six tenths of
    // the strip has to leave most of its row clear for the same reason, and
    // `pitch_scene_test` counts the pixels.
    canvas.saveLayer(Offset.zero & size, Paint());

    // **A FAR TREELINE, in the bottom two fifths.** Three trees on a bare
    // horizon is a field; a soft, hazed line of distant woodland behind them
    // is a place, and it is what gives the near trees something to be in
    // front of. Kept below the sixty-per-cent line so it is depth rather than
    // a wash across the sky.
    final farTop = h * 0.64;
    final far = Path()..moveTo(0, h);
    var fx = -8.0;
    var i = 0;
    while (fx < size.width + 20) {
      final r = (7 + (i % 3) * 2.2 + ((i * 7) % 5) * 0.8) * unit;
      final cy = farTop + r + 1;
      far.addOval(Rect.fromCircle(center: Offset(fx, cy), radius: r));
      fx += r * 1.15;
      i++;
    }
    far.addRect(Rect.fromLTRB(0, farTop + 6, size.width, h));
    canvas.drawPath(
      far,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, farTop), Offset(0, h), [
          const Color(0xFF5C9A78),
          const Color(0xFF3F7A5B),
        ]),
    );

    // A near tree: a trunk, a crown built of three blobs, lit up-left and
    // shaded underneath, and a shadow on the grass at its foot. The old one
    // was a disc on a stick.
    void tree(double x, double size_, {bool tall = false, double dy = 0}) {
      // Its own line, [dy] in front of the props' one.
      final foot = base + dy;
      final s = math.min(size_, h / (49 * scale));
      final w = (tall ? 22 : 34) * scale * s;
      final crownH = (tall ? 40 : 30) * scale * s;
      final trunkH = (tall ? 12 : 15) * scale * s;
      final trunkW = (tall ? 4 : 6) * scale * s;
      final cx = x + w / 2;
      // Shadow on the ground, so it stands on the grass rather than on the
      // horizon line.
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + w * 0.15, foot - 1), width: w * 1.1, height: 4 * scale),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
      // Trunk, tapered, with a branch or two into the crown.
      canvas.drawPath(
        Path()
          ..moveTo(cx - trunkW * 0.7, foot + 1)
          ..lineTo(cx + trunkW * 0.7, foot + 1)
          ..lineTo(cx + trunkW * 0.35, foot - trunkH - crownH * 0.35)
          ..lineTo(cx - trunkW * 0.35, foot - trunkH - crownH * 0.35)
          ..close(),
        Paint()..color = const Color(0xFF5E4130),
      );
      canvas.drawLine(
        Offset(cx, foot - trunkH - crownH * 0.2),
        Offset(cx + w * 0.22, foot - trunkH - crownH * 0.5),
        Paint()
          ..color = const Color(0xFF5E4130)
          ..strokeWidth = trunkW * 0.35,
      );
      final crownTop = foot - trunkH - crownH;
      final crown = Path();
      if (tall) {
        crown.addOval(Rect.fromLTWH(cx - w / 2, crownTop, w, crownH));
      } else {
        crown.addOval(Rect.fromLTWH(cx - w * 0.5, crownTop + crownH * 0.18, w, crownH * 0.82));
        crown.addOval(Rect.fromLTWH(cx - w * 0.32, crownTop, w * 0.62, crownH * 0.62));
        crown.addOval(Rect.fromLTWH(cx - w * 0.05, crownTop + crownH * 0.1, w * 0.55, crownH * 0.6));
      }
      final cb = crown.getBounds();
      canvas.drawPath(
        crown,
        Paint()
          ..shader = ui.Gradient.linear(cb.topLeft, cb.bottomRight, [
            const Color(0xFF6DB760),
            const Color(0xFF3E8A42),
            const Color(0xFF265C2C),
          ], const [0, 0.5, 1]),
      );
      canvas.save();
      canvas.clipPath(crown);
      // Leaf clumps: a lit one high on the left, shade low on the right.
      canvas.drawOval(
        Rect.fromLTWH(cb.left + cb.width * 0.12, cb.top + cb.height * 0.1, cb.width * 0.4, cb.height * 0.32),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawOval(
        Rect.fromLTWH(cb.left + cb.width * 0.3, cb.top + cb.height * 0.55, cb.width * 0.75, cb.height * 0.5),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
      );
      canvas.restore();
    }

    // A park bench: two slats, a back rest, two legs, in weathered wood.
    void bench(double x) {
      final w = 22 * unit;
      final seatY = base - 7 * scale;
      final wood = Paint()..color = const Color(0xFF8A5A36);
      final light = Paint()..color = const Color(0xFFA97347);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x + w / 2, base - 0.5), width: w * 1.05, height: 3 * scale),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );
      // Legs.
      canvas.drawRect(Rect.fromLTWH(x + 2 * unit, seatY, 1.6 * unit, base - seatY + 1), Paint()..color = const Color(0xFF3A3A3A));
      canvas.drawRect(Rect.fromLTWH(x + w - 3.6 * unit, seatY, 1.6 * unit, base - seatY + 1), Paint()..color = const Color(0xFF3A3A3A));
      // Seat slats.
      canvas.drawRect(Rect.fromLTWH(x, seatY, w, 1.4 * scale), light);
      canvas.drawRect(Rect.fromLTWH(x, seatY + 1.6 * scale, w, 1.2 * scale), wood);
      // Back rest, leaning back a touch.
      canvas.drawRect(Rect.fromLTWH(x + 1 * unit, seatY - 5.2 * scale, w - 2 * unit, 1.3 * scale), light);
      canvas.drawRect(Rect.fromLTWH(x + 1 * unit, seatY - 3.4 * scale, w - 2 * unit, 1.1 * scale), wood);
      canvas.drawRect(Rect.fromLTWH(x + 3 * unit, seatY - 5.6 * scale, 1.2 * unit, 5.6 * scale), Paint()..color = const Color(0xFF3A3A3A));
      canvas.drawRect(Rect.fromLTWH(x + w - 4.2 * unit, seatY - 5.6 * scale, 1.2 * unit, 5.6 * scale), Paint()..color = const Color(0xFF3A3A3A));
    }

    // A person: legs, a shirt with two ARMS, a head with HAIR. The one who
    // used to loiter here was a rounded rect with a disc on it.
    void person(double x, Color shirt, Color hair, {bool sitting = false, bool waving = false, double seatY = 0, double? foot}) {
      // **THE WATCHERS STAND WHERE THE SPRITE LAYER'S DO**, which is
      // [parkFansDrop] down the picture rather than on the props' line — and
      // still above the chalk. A fallback that stands its people somewhere else
      // is a different park. Anyone on a BENCH is the exception, and passes the
      // line the bench is standing on: a sitter whose feet are eight points in
      // front of the seat is not sitting on it.
      final base = foot ?? fanLine;
      final skin = _fanSkins[rng.nextInt(_fanSkins.length)];
      final legH = sitting ? 5 * scale : 7 * scale;
      final torsoH = 7 * scale;
      final feet = sitting ? base : base;
      final hip = sitting ? seatY : feet - legH;
      final trousers = Paint()..color = const Color(0xFF34404A);
      if (sitting) {
        // Thighs forward along the seat, shins down to the ground.
        canvas.drawRect(Rect.fromLTWH(x, hip - 1.5 * scale, 6 * unit, 2.6 * scale), trousers);
        canvas.drawRect(Rect.fromLTWH(x + 4.5 * unit, hip, 2 * unit, feet - hip + 1), trousers);
        canvas.drawRect(Rect.fromLTWH(x + 1.5 * unit, hip, 2 * unit, feet - hip + 1), trousers);
      } else {
        canvas.drawRect(Rect.fromLTWH(x + 1 * unit, hip, 2.4 * unit, legH + 1), trousers);
        canvas.drawRect(Rect.fromLTWH(x + 4.2 * unit, hip, 2.4 * unit, legH + 1), trousers);
      }
      final torsoTop = hip - torsoH + (sitting ? 1.5 * scale : 0);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, torsoTop, 7.6 * unit, torsoH + 0.5),
          topLeft: const Radius.circular(2.5),
          topRight: const Radius.circular(2.5),
        ),
        Paint()..color = shirt,
      );
      // Arms: one hanging, one hanging or raised.
      final arm = Paint()
        ..color = shirt
        ..strokeWidth = 1.7 * unit
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x + 0.8 * unit, torsoTop + 1.5 * scale), Offset(x - 0.6 * unit, torsoTop + 6 * scale), arm);
      if (waving) {
        canvas.drawLine(Offset(x + 6.8 * unit, torsoTop + 1.5 * scale), Offset(x + 9.5 * unit, torsoTop - 4 * scale), arm);
        canvas.drawCircle(Offset(x + 9.6 * unit, torsoTop - 4.6 * scale), 1.1 * unit, Paint()..color = skin);
      } else if (sitting) {
        canvas.drawLine(Offset(x + 6.8 * unit, torsoTop + 1.5 * scale), Offset(x + 7.5 * unit, torsoTop + 6 * scale), arm);
      } else {
        canvas.drawLine(Offset(x + 6.8 * unit, torsoTop + 1.5 * scale), Offset(x + 8.2 * unit, torsoTop + 6 * scale), arm);
      }
      // Head, and hair over the top of it.
      final headC = Offset(x + 3.8 * unit, torsoTop - 3 * scale);
      canvas.drawCircle(headC, 3.1 * unit, Paint()..color = skin);
      canvas.drawPath(
        Path()
          ..addArc(Rect.fromCircle(center: headC, radius: 3.25 * unit), math.pi * 0.95, math.pi * 1.1)
          ..close(),
        Paint()..color = hair,
      );
    }

    const hairs = [Color(0xFF2A1B12), Color(0xFF5B3A22), Color(0xFFB88A4A), Color(0xFF8A8A8A), Color(0xFF1A1A1A)];

    // Trees, two species, and **NOT IN A LINE** — each on its own depth, as the
    // live layer plants them (see [parkTreeDrops]). Five trunks with their feet
    // on one row is a fence with leaves on.
    tree((22 + rng.nextDouble() * 20) * unit, 0.9 + rng.nextDouble() * 0.3, dy: 0);
    tree((120 + rng.nextDouble() * 20) * unit, 1.0 + rng.nextDouble() * 0.25, tall: true, dy: 3);
    tree((205 + rng.nextDouble() * 30) * unit, 0.75 + rng.nextDouble() * 0.3, dy: 1);
    tree((340 + rng.nextDouble() * 30) * unit, 0.9 + rng.nextDouble() * 0.3, dy: 5);
    tree((430 + rng.nextDouble() * 20) * unit, 0.8, tall: true, dy: 2);

    // The hedge: a run of clipped bushes along the boundary, lit on top.
    final hedgeX0 = (150 + rng.nextDouble() * 40) * unit;
    for (var b = 0; b < 6; b++) {
      final bx = hedgeX0 + b * 15 * unit;
      final bh = (9 + (b % 2) * 2.5) * scale;
      final box = Rect.fromLTWH(bx, base - bh, 18 * unit, bh + 1);
      canvas.drawOval(box, Paint()..color = const Color(0xFF2F6E37));
      canvas.drawOval(
        Rect.fromLTWH(bx + 2 * unit, base - bh + 0.6, 10 * unit, bh * 0.45),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.13)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );
    }

    // **A PARK HAS BENCHES.** Two, either side of the pitch, and at Sunday
    // League somebody is sitting on one.
    final bench1 = 78 * unit;
    final bench2 = 318 * unit;
    bench(bench1);
    bench(bench2);

    if (tier >= 1) {
      // The changing rooms: a hut with a pitched roof, a door and a window.
      final hx = 385 * unit;
      final hw = 34 * unit;
      final hh = 13 * scale;
      final wall = Rect.fromLTWH(hx, base - hh, hw, hh + 1);
      canvas.drawRect(wall, Paint()..color = const Color(0xFFD9CBB0));
      canvas.drawRect(Rect.fromLTWH(hx, base - hh, hw * 0.3, hh + 1), Paint()..color = Colors.black.withValues(alpha: 0.1));
      canvas.drawPath(
        Path()
          ..moveTo(hx - 3 * unit, base - hh + 0.5)
          ..lineTo(hx + hw / 2, base - hh - 7 * scale)
          ..lineTo(hx + hw + 3 * unit, base - hh + 0.5)
          ..close(),
        Paint()..color = const Color(0xFF6E3F36),
      );
      canvas.drawRect(Rect.fromLTWH(hx + 6 * unit, base - 8 * scale, 5 * unit, 8 * scale + 1), Paint()..color = night ? const Color(0xFF6A5A44) : const Color(0xFF4A5B6A));
      final pane = Rect.fromLTWH(hx + 18 * unit, base - 10 * scale, 7 * unit, 5 * scale);
      // **THE LIGHTS ARE ON IN THERE.** Asked for from the couch: at night the
      // buildings behind the ground should be lit. The bloom around the pane is
      // most of it — a warm rectangle on its own is a sticker, and the light
      // spilling onto the wall is what says somebody is inside.
      if (night) {
        canvas.drawRect(
          pane.inflate(5 * scale),
          Paint()
            ..color = const Color(0x8FFFB85A)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.5 * scale),
        );
        canvas.drawRect(
          pane.inflate(1.6 * scale),
          Paint()
            ..color = const Color(0xE6FFCE7A)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.6 * scale),
        );
        // And it falls on the ground outside the door.
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(hx + 8.5 * unit, base),
            width: 16 * unit,
            height: 4 * scale,
          ),
          Paint()
            ..color = const Color(0x59FFC46B)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * scale),
        );
      }
      canvas.drawRect(pane, Paint()..color = night ? const Color(0xFFFFEFC2) : const Color(0xFFBFDCEC));
      canvas.drawRect(Rect.fromLTWH(hx + 21.2 * unit, base - 10 * scale, 0.7 * unit, 5 * scale), Paint()..color = const Color(0xFF7A6A55));
      canvas.drawRect(Rect.fromLTWH(hx + 18 * unit, base - 7.8 * scale, 7 * unit, 0.7 * scale), Paint()..color = const Color(0xFF7A6A55));

      // A lamp post and a bin, because somebody looks after this park.
      final lx = 262 * unit;
      canvas.drawRect(Rect.fromLTWH(lx, base - 24 * scale, 1.4 * unit, 24 * scale + 1), Paint()..color = const Color(0xFF4B5560));
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(lx - 2.2 * unit, base - 26.5 * scale, 5.8 * unit, 3 * scale), const Radius.circular(1)),
        Paint()..color = const Color(0xFF5E6975),
      );
      final binX = 236 * unit;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(binX, base - 7 * scale, 5.5 * unit, 7 * scale + 1), const Radius.circular(1.2)),
        Paint()..color = const Color(0xFF3F4A44),
      );
      canvas.drawRect(Rect.fromLTWH(binX - 0.5 * unit, base - 7.6 * scale, 6.5 * unit, 1.2 * scale), Paint()..color = const Color(0xFF2B332F));

      // **SUNDAY LEAGUE GETS SPECTATORS; the park below it gets nobody.** One
      // sat on the bench, one standing with a wave, and a dog.
      person(bench1 + 6 * unit, _fanColours[rng.nextInt(_fanColours.length)], hairs[rng.nextInt(hairs.length)], sitting: true, seatY: base - 7 * scale, foot: base);
      // **AND SOMEBODY ON THE OTHER ONE.** Asked for from the couch, who liked
      // the sitter: two benches with one in use read as a bench somebody had
      // been put on rather than a park people come to. A pair on the far one,
      // shoulder to shoulder.
      person(bench2 + 3 * unit, _fanColours[rng.nextInt(_fanColours.length)], hairs[rng.nextInt(hairs.length)], sitting: true, seatY: base - 7 * scale, foot: base);
      person(bench2 + 12 * unit, _fanColours[rng.nextInt(_fanColours.length)], hairs[rng.nextInt(hairs.length)], sitting: true, seatY: base - 7 * scale, foot: base);
      final px = (170 + rng.nextDouble() * 40) * unit;
      person(px, _fanColours[rng.nextInt(_fanColours.length)], hairs[rng.nextInt(hairs.length)], waving: rng.nextDouble() < 0.6);
      // The dog: a body, a head, four legs and a tail up.
      final dx = px + 14 * unit;
      final dog = Paint()..color = const Color(0xFF7A5A3A);
      canvas.drawOval(Rect.fromLTWH(dx, fanLine - 5 * scale, 7 * unit, 3.2 * scale), dog);
      canvas.drawCircle(Offset(dx + 7.4 * unit, fanLine - 4.6 * scale), 1.7 * unit, dog);
      for (final lx2 in [dx + 1 * unit, dx + 2.6 * unit, dx + 4.6 * unit, dx + 6 * unit]) {
        canvas.drawRect(Rect.fromLTWH(lx2, fanLine - 2.2 * scale, 0.9 * unit, 2.2 * scale + 1), dog);
      }
      canvas.drawLine(Offset(dx + 0.3 * unit, fanLine - 4.4 * scale), Offset(dx - 1.6 * unit, fanLine - 7 * scale), Paint()..color = const Color(0xFF7A5A3A)..strokeWidth = 0.9 * unit..strokeCap = StrokeCap.round);
    }

    // No fence here either, so the sprites do not take one away when they
    // land: the boundary is the touchline on the turf.

    // The same aerial haze the terrace takes, so the two horizons sit at the
    // same distance — but ONLY where this painter drew something. See the
    // `saveLayer` above.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = haze.withValues(alpha: 0.2)
        ..blendMode = BlendMode.srcATop,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(ParkPainter old) =>
      old.haze != haze || old.tier != tier || old.night != night;
}

class _StandPainter extends CustomPainter {
  const _StandPainter({
    required this.kitColor,
    required this.haze,
    required this.beat,
    required this.excitement,
    required this.tier,
    required this.front,
  });

  /// How grand the ground is: [deckPlan] turns it into rows and decks, and
  /// [fansPerRow] into how many are in each.
  final int tier;

  /// Which half of the split this is drawing — see [_liveRows]. The two halves
  /// walk the identical seeded stream and each skips what the other draws, so
  /// the pair paints exactly the picture one painter did.
  final bool front;

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
    final plan = deckPlan(tier);
    final perRow = fansPerRow(tier);
    final deckTop = _roofHeight;
    final deckRect = Rect.fromLTRB(0, deckTop, size.width, size.height);

    // The rows that keep moving: the front deck's frontmost, and never more of
    // it than it has.
    final liveFrom = plan.perDeck.last - math.min(_liveRows, plan.perDeck.last);

    if (!front) {
      // The terrace: a dark bank, STEPPED. Each row is a tread caught by the
      // light with a riser falling into shade under it — the old hairlines on
      // a flat gradient read as a wall with a crowd glued to it, and the
      // steps are what say the rows climb away from the pitch.
      canvas.drawRect(
        deckRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF39424E), Color(0xFF2A323C)],
          ).createShader(deckRect),
      );
      var stepY = deckTop;
      for (var d = 0; d < plan.decks; d++) {
        if (d > 0) stepY += _facadeHeight;
        final depth = plan.deckScales[d];
        final pitch = _rowPitch * _crowdScale * depth;
        final deckH = plan.deckHs[d];
        for (var row = 0; row < plan.perDeck[d]; row++) {
          final y = stepY + (_deckPad + 4 + row * _rowPitch) * _crowdScale * depth;
          if (y > stepY + deckH) break;
          final riser = Rect.fromLTWH(0, y, size.width, math.min(pitch * 0.55, stepY + deckH - y));
          canvas.drawRect(
            riser,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.22), Colors.black.withValues(alpha: 0.02)],
              ).createShader(riser),
          );
          canvas.drawRect(Rect.fromLTWH(0, y - 1, size.width, 1), Paint()..color = const Color(0x2EFFFFFF));
        }
        // Aisles: a stair up the deck every so often, lighter than the seats,
        // with its steps marked. Sections, which is what a stand is made of.
        final aisleGap = 96.0 * depth + 24;
        for (var ax = 30.0 * depth; ax < size.width; ax += aisleGap) {
          final aisle = Rect.fromLTWH(ax, stepY, 4 * depth + 1, deckH);
          canvas.drawRect(aisle, Paint()..color = const Color(0xFF55606D));
          for (var sy = stepY + 2; sy < stepY + deckH; sy += 3) {
            canvas.drawRect(Rect.fromLTWH(ax, sy, aisle.width, 1), Paint()..color = const Color(0x40000000));
          }
        }
        stepY += deckH;
      }
    }

    // The people. Seeded, so a re-render reproduces the identical crowd — a
    // stand that reshuffles between frames reads as static rather than as
    // people. Rows run BACK to front: row 0 is highest and smallest, and
    // because it is painted first the row in front of it overlaps it, which is
    // the whole reason the rows read as depth.
    final rng = math.Random(7);
    // **DECK BY DECK, back to front.** Past tier 6 the rows are split into
    // stacked decks with a facade wall between them — one long terrace reads as
    // a non-league bank of seats however many rows you give it. The first deck
    // in the list is the BACK one, and it is drawn first so the deck in front
    // overlaps it.
    var deckY = deckTop;
    // The banners in the deck being walked, held back until its rows are done.
    final flags =
        <({double x, double top, double shoulder, Color colour, double phase})>[];
    for (var d = 0; d < plan.decks; d++) {
      final rows = plan.perDeck[d];
      final deckH = plan.deckHs[d];
      // **HOW FAR BACK THIS DECK IS** — see [deckDepth]. Everything drawn in it
      // takes the same number, which is what makes it a layer rather than a
      // band of smaller people.
      final depth = plan.deckScales[d];
      // Further away is MORE of them across the same width, which is the other
      // half of what says "further": a distant terrace is denser, not just
      // smaller.
      final deckPerRow = (perRow / depth).round();
      if (d > 0) {
        // The balcony wall between two decks — and the SHADOW it throws on the
        // deck below, which is what says the upper deck stands back and above
        // rather than being stacked flat on top.
        if (!front) {
          final facade = Rect.fromLTWH(0, deckY, size.width, _facadeHeight);
          canvas.drawRect(
            facade,
            Paint()
              ..shader = const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF5A6572), Color(0xFF3A434E), Color(0xFF232A33)],
                stops: [0, 0.55, 1],
              ).createShader(facade),
          );
          canvas.drawRect(Rect.fromLTWH(0, deckY, size.width, 1), Paint()..color = const Color(0x55FFFFFF));
          final drop = Rect.fromLTWH(0, deckY + _facadeHeight, size.width, 7);
          canvas.drawRect(
            drop,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.4), Colors.black.withValues(alpha: 0)],
              ).createShader(drop),
          );
        }
        deckY += _facadeHeight;
      }
      for (var row = 0; row < rows; row++) {
      // The JS's `y`, measured down from the deck's own top edge, at this
      // deck's own depth — the rows have to close up as the deck shrinks or
      // they would run out of the bottom of it.
      final y =
          deckY - deckTop + (_deckPad - 1 + row * _rowPitch) * _crowdScale * depth;
      // The back rows are further away, so they are smaller — and so is the
      // whole deck, which is the layer this row is in.
      final shoulder =
          (7 - math.min(2.5, (rows - 1 - row) * 0.5)) * _crowdScale * depth;
      if (y + shoulder > deckY - deckTop + deckH) continue;
      // Whose row this is. The other layer walks it too — the stream has to
      // reach the next fan with the same numbers either way.
      final mine = (d == plan.decks - 1 && row >= liveFrom) == front;
      for (var i = 0; i < deckPerRow; i++) {
        final x =
            (i + 0.1 + rng.nextDouble() * 0.8) * (size.width / deckPerRow);
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
        // At rest about a third are up; excitement brings the rest. It was a
        // fifth, and a stand that still reads as a photograph from the couch is
        // the whole reason the bounce exists.
        final up = keen < 0.32 + excitement * 0.68;
        final lift = up
            ? math.max(0.0, math.sin((beat + phase) * 2 * math.pi)) *
                  (1.1 + excitement * 2.4) *
                  // A fan two hundred feet further back does not bounce as far
                  // ON SCREEN, and a lift that ignored the deck's scale would
                  // pop the back tier's heads out through the facade above it.
                  depth
            : 0.0;
        final skin = _fanSkins[rng.nextInt(_fanSkins.length)];
        // Drawn from the stream on BOTH halves so the two stay in step.
        final hair = _fanHair[rng.nextInt(_fanHair.length)];
        // **WHAT THEY BROUGHT WITH THEM.** Drawn from the stream on BOTH
        // halves, like the hair, so the two stay in step — see [firstFlagTier].
        final prop = rng.nextDouble();
        final scarf = prop < scarfShare(tier);
        // A flag is only ever in the FRONT deck: one waving out of the back
        // tier of a three-decker is a banner hung in the roof.
        final flag =
            d == plan.decks - 1 && prop > 1 - flagShare(tier);
        final armsUp = up && (keen < 0.1 || excitement > 0.5);
        if (mine) {
          _paintFan(
            canvas,
            x: x,
            top: deckTop + y - lift,
            shoulder: shoulder,
            shirt: shirt,
            skin: skin,
            hair: hair,
            // A scarf is held up in two hands, so the arms go with it.
            armsUp: armsUp || scarf,
          );
          if (scarf) {
            _paintScarf(
              canvas,
              x: x,
              top: deckTop + y - lift,
              shoulder: shoulder,
              colour: shirt == kitColor ? kitColor : shirt,
              phase: phase,
            );
          }
          if (flag) {
            flags.add((
              x: x,
              top: deckTop + y - lift,
              shoulder: shoulder,
              colour: kitColor,
              phase: phase,
            ));
          }
        }
      }
      }
      // **THE FLAGS GO OVER THE DECK THEY ARE IN**, and no further. Painted
      // inside the row loop a banner was cut in half by the next fan along and
      // by every row in front of it; held back to here it stands over its own
      // deck's crowd and still passes behind the one in front, which is what
      // keeps it in the stand rather than on top of the picture.
      for (final f in flags) {
        _paintFlag(
          canvas,
          x: f.x,
          top: f.top,
          shoulder: f.shoulder,
          colour: f.colour,
          phase: f.phase,
        );
      }
      flags.clear();
      // **AND THE AIR IN FRONT OF IT.** Size alone is a small stand rather than
      // a distant one; what actually sits a tier back is the haze between the
      // viewer and it. One pass per deck, over that deck's own band only, so
      // the three layers separate — the whole-terrace wash below is still there
      // and does a different job, which is sitting the BAND under the sky.
      if (depth < 1 && !front) {
        canvas.drawRect(
          Rect.fromLTWH(0, deckY, size.width, deckH),
          Paint()..color = haze.withValues(alpha: (1 - depth) * 1.4),
        );
      }
      deckY += deckH;
    }

    // The washes go OVER the live rows, so they belong to the layer that draws
    // them — a front row painted on top of the haze reads brighter than the
    // rest of the stand for as long as a surge lasts.
    if (!front) return;

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
    // And the shade it throws down the back rows, which is what puts the roof
    // OVER the stand rather than along its top edge.
    final eave = Rect.fromLTWH(0, _roofHeight, size.width, 9);
    canvas.drawRect(
      eave,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.5), Colors.black.withValues(alpha: 0)],
        ).createShader(eave),
    );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 1.2), Paint()..color = const Color(0xFFE6ECF2));
  }

  /// One supporter, at `.ps-fan`'s geometry. Everything is a multiple of
  /// [shoulder] — the torso box, the head that overlaps its top edge by a hair
  /// so there is no neck gap at 5px, and the sleeve bar across the shoulders.
  /// **A SCARF HELD UP**, which is the cheapest thing on a terrace that says
  /// this is a support rather than an audience: a bar of club colour stretched
  /// between two raised hands, with a stripe through it and a lick of movement
  /// so a hundred of them are not one shape repeated.
  void _paintScarf(
    Canvas canvas, {
    required double x,
    required double top,
    required double shoulder,
    required Color colour,
    required double phase,
  }) {
    // Between the hands the raised arms end at, and a touch above them.
    final w = shoulder * 1.72;
    final h = math.max(1.4, shoulder * 0.3);
    final y = top - shoulder * 0.72;
    canvas.save();
    canvas.translate(x + shoulder * 0.5, y);
    // Held at a slight angle, its own per fan, so a row of them is not a fence.
    canvas.rotate((phase - 0.5) * 0.34);
    final box = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(h * 0.35)),
      Paint()..color = colour,
    );
    // The bar across the middle every club scarf has.
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: w, height: h * 0.34),
      Paint()..color = Colors.white.withValues(alpha: 0.65),
    );
    canvas.restore();
  }

  /// **A BIG FLAG.** A pole out of the crowd and a cloth two heads wide,
  /// rippling on the same beat the terrace bounces to.
  ///
  /// The cloth is drawn as a run of columns whose top and bottom edges ride one
  /// sine — a flag whose OUTLINE waves but whose face is flat reads as a sheet
  /// of card, so the shading rides the same wave and the folds move with it.
  void _paintFlag(
    Canvas canvas, {
    required double x,
    required double top,
    required double shoulder,
    required Color colour,
    required double phase,
  }) {
    // **IT STOPS UNDER THE FASCIA.** The pole is nearly five shoulders long and
    // the top rows sit close to the roof, so a fixed length put the cloth off
    // the top of the strip and the flag arrived as a stripe with no top edge.
    final poleH = math.min(
      shoulder * 4.6,
      math.max(shoulder * 2.0, top - _roofHeight - 2),
    );
    final poleX = x + shoulder * 0.2;
    final poleTop = top - poleH;
    canvas.drawLine(
      Offset(poleX, top + shoulder * 0.2),
      Offset(poleX, poleTop),
      Paint()
        ..color = const Color(0xFF3A3A3A)
        ..strokeWidth = math.max(1, shoulder * 0.12),
    );
    final w = shoulder * 3.6;
    final h = math.min(shoulder * 2.4, poleH * 0.55);
    final wave = (phase + beat) * 2 * math.pi;
    final top_ = poleTop + shoulder * 0.15;
    // The cloth, column by column: each one hung off the same travelling wave,
    // so the whole sheet ripples away from the pole rather than swinging as a
    // board.
    const steps = 10;
    final path = Path()..moveTo(poleX, top_);
    double lift(double t) => math.sin(wave - t * 3.4) * h * 0.13 * t;
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      path.lineTo(poleX + w * t, top_ + lift(t));
    }
    for (var i = steps; i >= 0; i--) {
      final t = i / steps;
      path.lineTo(poleX + w * t, top_ + h + lift(t));
    }
    path.close();
    canvas.drawPath(path, Paint()..color = colour);
    // A white band across it, and the fold shading — both clipped to the cloth
    // so they travel with the wave rather than sitting over it.
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Rect.fromLTWH(poleX, top_ + h * 0.42, w, h * 0.2),
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
    for (var i = 0; i < 3; i++) {
      final t = 0.25 + i * 0.25;
      final fold = poleX + w * t + math.sin(wave - t * 3.4) * w * 0.05;
      canvas.drawRect(
        Rect.fromLTWH(fold, top_ - h * 0.2, w * 0.09, h * 1.5),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    canvas.restore();
  }

  void _paintFan(
    Canvas canvas, {
    required double x,
    required double top,
    required double shoulder,
    required Color shirt,
    required Color skin,
    required Color hair,
    bool armsUp = false,
  }) {
    final body = Paint()..color = shirt;
    // **ARMS.** Down at the sides at rest, and thrown up when a fan is on
    // their feet and bothered — a crowd with no arms is a row of bottles.
    final arm = Paint()
      ..color = shirt
      ..strokeWidth = shoulder * 0.24
      ..strokeCap = StrokeCap.round;
    if (armsUp) {
      canvas.drawLine(Offset(x + shoulder * 0.05, top + shoulder * 0.25), Offset(x - shoulder * 0.3, top - shoulder * 0.55), arm);
      canvas.drawLine(Offset(x + shoulder * 0.95, top + shoulder * 0.25), Offset(x + shoulder * 1.3, top - shoulder * 0.55), arm);
    } else {
      canvas.drawLine(Offset(x + shoulder * 0.05, top + shoulder * 0.3), Offset(x - shoulder * 0.1, top + shoulder * 0.85), arm);
      canvas.drawLine(Offset(x + shoulder * 0.95, top + shoulder * 0.3), Offset(x + shoulder * 1.1, top + shoulder * 0.85), arm);
    }
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
    final head = Offset(x + shoulder * 0.5, top - shoulder * 0.21);
    canvas.drawCircle(head, shoulder * 0.31, Paint()..color = skin);
    // **HAIR**, as a cap over the top of the head. One arc, but it is the
    // difference between a peach and a person at this size.
    canvas.drawPath(
      Path()
        ..addArc(Rect.fromCircle(center: head, radius: shoulder * 0.33), math.pi * 0.92, math.pi * 1.16)
        ..close(),
      Paint()..color = hair,
    );
  }

  @override
  bool shouldRepaint(_StandPainter old) =>
      old.front != front ||
      old.tier != tier ||
      old.kitColor != kitColor ||
      old.haze != haze ||
      old.beat != beat ||
      old.excitement != excitement;
}

/// The ad boards on the horizon: panels in the division's colour alternating
/// with white, under a sheen that catches the light along their top edge.
/// **What a perimeter board says, and why it is not a `t()` key.**
///
/// It is the game's own DISPLAY NAME — the one in `android:label` and the
/// window title — so it is a brand mark on a prop, the
/// same class of thing as a badge, and not copy that a locale would translate.
/// Which is just as well: the catalogues are generated from the JS and no new
/// key can be added from this repo.
const String hoardingText = 'MERGE EMPIRE FOOTBALL MANAGER';

/// **SMALL, and that is the point — it is in the DISTANCE.** Big enough to read
/// as lettering on a board, too small to read as a sentence, which is exactly
/// how advertising behind a pitch looks from the touchline.
const double hoardingFontSize = 5.5;

/// **The lowest tier with advertising.** A park has a fence and a hedge; nobody
/// sells perimeter space at a ground with no stand. Same boundary as
/// [firstStandTier] and deliberately so — the two arrive together, which is what
/// makes tier 2 read as the first real GROUND.
const int firstHoardingTier = firstStandTier;

/// The cap band, as a fraction of the font size. Every letter on a board is a
/// capital, so this IS the ink: there is nothing below the baseline and nothing
/// above the cap line.
const double _hoardingCap = 0.72;

/// Where the lettering's top edge goes on a board [height] tall, given the
/// paragraph's [baseline].
///
/// **The LINE BOX was being centred, and the ink is not the line box.** A box
/// reserves room under the baseline for descenders that a line of capitals
/// never uses, so centring it hangs the lettering high on the board — reported
/// as the text needing to move down slightly to be vertically centred. This
/// centres the cap band instead, which is the part anyone can see.
/// [fontSize] defaults to [hoardingFontSize] and is passed explicitly by the
/// painter, because the mark is not always set at that size: it shrinks rather
/// than wrap — see [hoardingLettering] — and a cap band computed for 5.5 on a
/// mark set at 3.7 puts back most of the offset this is removing.
double hoardingTextTop(double height, double baseline, {double? fontSize}) =>
    height / 2 + (fontSize ?? hoardingFontSize) * _hoardingCap / 2 - baseline;

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

final Map<double, ui.Paragraph> _hoardingCache = {};

ui.Paragraph _buildHoardingText(double fontSize) => (ui.ParagraphBuilder(
  ui.ParagraphStyle(
    textAlign: TextAlign.center,
    fontSize: fontSize,
    fontWeight: FontWeight.w900,
    // **ONE LINE, ALWAYS** — see [hoardingLettering].
    maxLines: 1,
  ),
)
      ..pushStyle(
        ui.TextStyle(
          color: Colors.black.withValues(alpha: 0.55),
          // Kept proportional, so a mark that has to shrink to fit does not
          // shrink its letters and keep its gaps.
          letterSpacing: fontSize * (0.7 / hoardingFontSize),
          height: 1,
        ),
      )
      ..addText(hoardingText))
    .build();

/// **AND IT WAS WRAPPING.** Measured rather than assumed: the mark is 29
/// characters and the pale half of a 240 panel is 120 wide, which is not enough
/// at 5.5 in every face the platform might resolve — the test binding's own
/// fallback wants 179.8 and breaks it over TWO lines, six units each, stacked
/// inside a board 13 tall. Whether it wraps at all depended on which font the
/// device handed back, which is the kind of thing that is fine until it is not.
///
/// So it measures what the mark wants unconstrained and scales the type down if
/// the panel cannot take it. A brand mark on a hoarding is one line by
/// definition; a smaller one is still the mark, and two lines of it is not.
/// Public because it is the whole of what a test can ask about a strip that is
/// otherwise a painter inside a scrolling clip.
///
/// Laid out once per panel width and reused: a `TextPainter` per repaint, on a
/// band that repaints with the scroll, is the one cost this strip cannot take.
ui.Paragraph hoardingLettering(double width) =>
    _hoardingCache.putIfAbsent(width, () {
  final wanted = (_buildHoardingText(hoardingFontSize)
        ..layout(const ui.ParagraphConstraints(width: double.infinity)))
      .maxIntrinsicWidth;
  final size = wanted <= width || wanted <= 0
      ? hoardingFontSize
      : hoardingFontSize * width / wanted;
  return _buildHoardingText(size)
    ..layout(ui.ParagraphConstraints(width: width));
});

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

    // The advert, on the PALE panel only. On the club-coloured one it would be
    // a second thing competing with the colour that is the point of that board.
    final mark = hoardingLettering(size.width - half);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(half, 0, size.width - half, size.height));
    // The cap band follows the size the mark was actually SET at, which is not
    // always [hoardingFontSize] — see [hoardingLettering], which shrinks it
    // rather than let it wrap. With `height: 1` on one line the paragraph's
    // height IS that size.
    canvas.drawParagraph(
      mark,
      Offset(
        half,
        hoardingTextTop(
          size.height,
          mark.alphabeticBaseline,
          fontSize: mark.height,
        ),
      ),
    );
    canvas.restore();
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
///
/// **THE NIGHT SIDE IS LIFTED TWICE, about a tenth each time**, here and in
/// `theme/sky.dart`, the hills, the hedgerow and the park's own tint. Asked for
/// from the couch: dark mode on the home page was too dark across the board,
/// and still too dark once the houses had their lights on — a window only reads
/// as lit against something it can be brighter THAN. The fix is one consistent
/// lift rather than a brighter pitch under the same black sky.
const List<Color> _turfNight = [
  Color(0xFF436852),
  Color(0xFF497E5B),
  Color(0xFF529263),
];

/// **A FIELD'S COLOUR**: the same three stops with the good taken out of them —
/// yellowed toward olive and knocked down, which is what a winter of studs and
/// no groundsman leaves. Lerped in by [pitchWear], because a battered pitch is
/// not fresh green grass with stains laid over it; the whole surface has gone
/// off, and the mud patches sit in THAT.
///
/// **Yellowed, not greyed.** The first pass took the green most of the way out
/// and the field came back a flat olive table — which is a dead pitch rather
/// than a rough one. The photograph's grass is still GRASS; it is the mud
/// through it that does the talking, so this only warms and dulls it.
const List<Color> _turfWornDay = [
  Color(0xFF4A6B2E),
  Color(0xFF5E8438),
  Color(0xFF6E9440),
];
const List<Color> _turfWornNight = [
  Color(0xFF51634C),
  Color(0xFF5B7353),
  Color(0xFF648058),
];

/// The turf at this tier, at this hour.
List<Color> turfColours({required bool night, required int tier}) {
  final wear = pitchWear(tier);
  final kept = night ? _turfNight : _turfDay;
  if (wear <= 0) return kept;
  final worn = night ? _turfWornNight : _turfWornDay;
  return [
    for (var i = 0; i < kept.length; i++) Color.lerp(kept[i], worn[i], wear)!,
  ];
}

/// The ground: the turf, the mowing fan over it, the tuft bands, and the haze
/// that puts the far end of it in the distance.
/// **THE PARK IS FOUR LINES DEEP, and it used to be one.** Everything from the
/// hedgerow to the crowd stood on the horizon, which is a painted backdrop
/// rather than a place — asked for from the couch a piece at a time as each one
/// came off that line.
///
/// Down the picture: the hedgerow on the horizon itself, the houses and the hut
/// [parkPropsDrop] under it, the trees scattered between and in front of them
/// ([parkTreeDrops]), the spectators at this depth, and the touchline on the
/// grass below all of it. The one hard rule is that the people stay ABOVE the
/// chalk — they are watching from the touchline, not standing on the pitch.
///
/// How far below the horizon a park's spectators stand, in points.
const double parkFansDrop = 11;

/// How far below the horizon the park's OWN props stand — the trees, the hut,
/// the benches.
///
/// **They came off the horizon when the hedgerow arrived.** With a row of
/// bushes on the skyline behind them, a hut whose feet were on that same line
/// was standing IN the hedge; two things at two distances need two lines, or
/// the middle layer is a pattern on the far one. A third of the spectators'
/// drop, so the order down the picture reads country, hedgerow, ground, crowd.
/// Asked for from the couch, on the first frame the hedgerow was in.
const double parkPropsDrop = 4;

/// **AND THE TREES ARE NOT IN A ROW EITHER.** Their own depth each, some level
/// with the houses and some well in front of them — a line of trunks all on one
/// line is a fence with leaves on. Asked for in those terms. Indexed by the
/// order [_ParkFans] plants them.
const List<double> parkTreeDrops = [4, 7, 5, 9, 6, 8];

/// The bushes among them.
///
/// **NONE OF THESE MAY STAND BEHIND THE HOUSES**, and that is a rule about the
/// LAYERS rather than about bushes: the houses are in the still snapshot and
/// the trees and bushes are in the live one over it, so anything here is drawn
/// in front of a house whatever depth it claims. A bush on the horizon crossing
/// a house four points down the picture is the contradiction that produces —
/// reported from the couch as exactly that. So every drop here is at or past
/// [parkPropsDrop] and the painting order tells the truth.
const List<double> parkBushDrops = [5, 8, 6, 9];

/// How far below the horizon the far touchline is chalked, in points — the same
/// depth at every tier, because the pitch is the same pitch whatever is
/// standing round it.
///
/// **Its own number rather than the spectators' plus ten.** It was derived from
/// [parkFansDrop], so taking the park's crowd further down the picture dragged
/// the chalk of all eight grounds with it. The two are related by a rule
/// instead: the people watch from ABOVE the line.
const double touchlineBelowHorizon = 16;

/// How thick the chalk is at that depth. Under two points: it is the far line.
const double touchlineWidth = 1.5;

class _Turf extends StatelessWidget {
  const _Turf({
    required this.mood,
    required this.contactBelowHorizon,
    required this.condition,
    required this.tier,
    this.sprites = false,
  });

  final Mood mood;

  /// Kenney's grass has decoded, so a field's tufts are sprites.
  final bool sprites;

  /// How well kept the pitch is — see [pitchWear] and [tuftsTotal].
  final int tier;

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
                // **AND HOW WELL KEPT IT IS.** Green at the top of the pyramid,
                // olive and gone-off at the bottom — see [pitchWear].
                colors: turfColours(night: night, tier: tier),
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
                      strength: mowStrength(tier),
                    ),
                    // Each band a FULL-HEIGHT strip whose tufts sit at their own
                    // depth inside it, offset by what the world has done at that
                    // depth.
                    // **MUD, RUTS AND STANDING WATER, under the grass.** The
                    // bottom of the pyramid is a field rather than a pitch, and
                    // this is most of what says so — the spec scatters them
                    // from 6% to 80% up the pitch and rides them on the ground
                    // at their own depth, exactly as the tufts do. How much of
                    // it there is, and whether any of it is water, is
                    // [pitchWear]'s: it fades out over three tiers rather than
                    // switching off at 2, so the climb out of the park is a
                    // visible one more than once.
                    if (pitchWear(tier) > 0)
                      for (var band = 0; band < _decoBands; band++)
                        Positioned.fill(
                          child: _Scroller(
                            offsetPx: atRow(decoBandFraction(band)),
                            segmentWidth: groundSegmentWidth,
                            stillKey: (band, tier, night),
                            child: _DecoSegment(
                              band: band,
                              tier: tier,
                              night: night,
                            ),
                          ),
                        ),
                    for (var band = 0; band < _tuftBands; band++)
                      Positioned.fill(
                        child: _Scroller(
                          offsetPx: atRow(tuftBandFraction(band)),
                          segmentWidth: groundSegmentWidth,
                          stillKey: (band, tier, sprites),
                          child: _TuftSegment(
                            band: band,
                            tier: tier,
                            sprites: sprites,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          // **THE FAR TOUCHLINE.** Chalked a few points onto the grass from the
          // foot of whatever stands on the horizon — the park's spectators, or
          // the ad boards.
          //
          // **AT EVERY TIER, which is the whole of the report.** It was drawn
          // for the park only, on the reasoning that from [firstHoardingTier]
          // the boards are the boundary — and the boards are the boundary of
          // the GROUND, not of the pitch. Six of the eight tiers were a
          // football pitch with no line on it. Reported from the couch as the
          // touchlines missing on all of them.
          //
          // **ONE UNBROKEN RUN, FADED RATHER THAN BROKEN.** A worn pitch had it
          // in dashes for a while, which was truer to a park in February and
          // wrong in two ways at once: it read as a dotted line rather than as
          // old paint, and a gap is a FEATURE — it had to be hung off the
          // ground drive at its own row's speed or it sat still while the grass
          // ran under it. Faded, it has nothing to give away, so it holds still
          // and costs nothing. Both calls came from the couch, in that order.
          //
          // A perpendicular mark still cannot join it: the halfway line and the
          // boxes would come round with the segment every few seconds and read
          // as running past the same spot, which is why `PitchScene.js` dropped
          // them.
          Positioned(
            key: const ValueKey('pitch-touchline'),
            left: 0,
            right: 0,
            top: touchlineBelowHorizon,
            height: touchlineWidth,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.lerp(
                    chalkInk(night: night),
                    chalkWorn(night: night),
                    pitchWear(tier),
                  ),
                ),
              ),
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
    required this.strength,
  });

  final double worldX;
  final double turfHeight;
  final double contactBelowHorizon;

  /// How hard the cut is at this tier — see [mowStrength].
  final double strength;

  @override
  Widget build(BuildContext context) {
    final perRadian =
        _mowStretch * _contactDepth(turfHeight, contactBelowHorizon);
    final angle = perRadian <= 0 ? 0.0 : worldX / perRadian;
    // Named rather than inherited: a loose height constraint anywhere above this
    // is what once collapsed the surface to nothing and painted the pitch as sky.
    return CustomPaint(
      size: Size.infinite,
      painter: _MowPainter(phase: (angle / _mowPeriod) % 1, strength: strength),
    );
  }
}

/// The colour of fresh chalk, at this hour.
///
/// **NOT WHITE AT NIGHT — BUT STILL THERE.** Reported from the couch twice, one
/// each way: a paper-white line under a floodlit sky is the brightest thing in
/// the frame, brighter than the lamps throwing the light; and the first
/// correction took it so far down that the line had gone. Dimmer AND cooler,
/// which is the same move the turf makes — what a lamp gives back off wet paint
/// is a pale blue-grey, and it reads against grass that has been lifted twice
/// since the first pass.
Color chalkInk({required bool night}) =>
    night ? const Color(0xDCBACCCC) : const Color(0xF2F6F6F0);

/// And the colour of the chalk that has been trodden into the mud: the same
/// line, half taken back into the grass.
Color chalkWorn({required bool night}) =>
    night ? const Color(0xA5899C9C) : const Color(0x99D8D4C2);

/// The mow lanes at rest, and the size they were cut for.
class _MowLanes {
  const _MowLanes({
    required this.apexY,
    required this.half,
    required this.reach,
    required this.light,
    required this.dark,
  });

  final double apexY;
  final double half;
  final double reach;
  final Path light;
  final Path dark;
}

class _MowPainter extends CustomPainter {
  const _MowPainter({required this.phase, required this.strength});

  /// How far through one lane pair the sweep is, 0 to 1.
  final double phase;

  /// The tier's cut, as a multiplier on the lanes' contrast.
  final double strength;

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

    final apexY = mowApex * h;
    // Enough of the fan to cover the box's far corners, plus a lane either side
    // so the sweep never uncovers an edge.
    final half = math.atan2(inner / 2, -apexY) + _mowPeriod * 2;
    final reach = (h - apexY) * 1.6;
    final light = Paint()
      ..color = Colors.white.withValues(alpha: 0.055 * strength);
    final dark = Paint()
      ..color = Colors.black.withValues(alpha: 0.051 * strength);

    // **THE FAN IS BUILT ONCE AND TURNED**, not rebuilt every frame. The lanes
    // are identical and the pattern repeats every [_mowPeriod], so the sweep is
    // a rotation about the apex rather than two dozen fresh `Path`s a frame —
    // which is what it was, at 120Hz, for geometry that only moves when the
    // pitch is resized.
    //
    // MINUS the phase: increasing the angle sweeps a ray to the right, and the
    // world has to move right-to-left past a man walking on the spot. A canvas
    // turned by +θ renders a lane BUILT at `a` at `a - θ`, so the turn is the
    // phase itself.
    final fan = _fanFor(apexY, half, reach);
    canvas.translate(0, apexY);
    canvas.rotate(phase * _mowPeriod);
    canvas.translate(0, -apexY);
    canvas.drawPath(fan.light, light);
    canvas.drawPath(fan.dark, dark);
    canvas.restore();
  }

  /// The last fan built, kept while the pitch keeps its size.
  static _MowLanes? _fan;

  static _MowLanes _fanFor(double apexY, double half, double reach) {
    final held = _fan;
    if (held != null &&
        held.apexY == apexY &&
        held.half == half &&
        held.reach == reach) {
      return held;
    }
    final light = Path();
    final dark = Path();
    // A lane past each end, so a turn of up to one period never uncovers one.
    final first = -(half / _mowPeriod).ceil() * _mowPeriod - _mowPeriod;
    for (var a = first; a < half + _mowPeriod; a += _mowPeriod) {
      _wedge(light, apexY, a, a + _mowPeriod / 2, reach);
      _wedge(dark, apexY, a + _mowPeriod / 2, a + _mowPeriod, reach);
    }
    return _fan = _MowLanes(
      apexY: apexY,
      half: half,
      reach: reach,
      light: light,
      dark: dark,
    );
  }

  /// One lane, as the wedge between two rays out of the apex.
  static void _wedge(
    Path path,
    double apexY,
    double from,
    double to,
    double reach,
  ) {
    path
      ..moveTo(0, apexY)
      ..lineTo(reach * math.sin(from), apexY + reach * math.cos(from))
      ..lineTo(reach * math.sin(to), apexY + reach * math.cos(to))
      ..close();
  }

  @override
  bool shouldRepaint(_MowPainter old) =>
      old.phase != phase || old.strength != strength;
}

class _TuftSegment extends StatelessWidget {
  const _TuftSegment({
    required this.band,
    required this.tier,
    this.sprites = false,
  });

  final int band;
  final int tier;
  final bool sprites;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: groundSegmentWidth,
    height: double.infinity,
    // A FIELD's tufts are Kenney's scruffy grass; a kept pitch keeps its blades.
    child: sprites && tier < firstKeptPitchTier
        ? _GrassSprites(band: band, tier: tier)
        : CustomPaint(painter: _TuftPainter(band: band, tier: tier)),
  );
}

/// Kenney's grass at the tufts' own places — the same rolls the painter makes,
/// so a field reads the same whether it is blades or sprites.
class _GrassSprites extends StatelessWidget {
  const _GrassSprites({required this.band, required this.tier});

  final int band;
  final int tier;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final children = <Widget>[];
      var i = 0;
      for (final t in tuftPlacements(band, tier)) {
        final depth = t.depth;
        final x = t.x * box.maxWidth;
        final base = box.maxHeight * (1 - t.f);
        final sprite = kenneyGrass[i++ % kenneyGrass.length];
        final height = math.max(6.0, t.tall * 1.3);
        children.add(
          Positioned(
            left: x,
            top: base - height,
            // The sprite is a pale silhouette; multiplied into a lighter,
            // yellower green than the turf so it reads as a tuft ON the grass.
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Color.lerp(
                  const Color(0xFFA8DE72),
                  const Color(0xFF7CC062),
                  depth,
                )!,
                BlendMode.modulate,
              ),
              child: Image.asset(
                sprite,
                height: height,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        );
      }
      return Stack(clipBehavior: Clip.none, children: children);
    },
  );
}

/// **THE FIELD AT THE BOTTOM OF THE PYRAMID.** Mud patches, soft mounds and
/// standing water, ported from `_decoBands` in `PitchScene.js` — the half of
/// "a battered pitch" the port had left out entirely, so a Sunday League ground
/// was the same flat green table as a European final.
///
/// They ride the ground at their own depth, exactly as the tufts do: their depth
/// IS their speed, and a puddle that raced the stripes it sits in is the one
/// thing a parallax scene cannot forgive.
class _DecoSegment extends StatelessWidget {
  const _DecoSegment({
    required this.band,
    required this.tier,
    required this.night,
  });

  final int band;
  final int tier;

  /// Water takes the SKY, so it has to know what hour the sky is at — a puddle
  /// lit like an afternoon on a floodlit pitch is a hole cut in the ground.
  final bool night;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: groundSegmentWidth,
    height: double.infinity,
    child: CustomPaint(
      painter: _DecoPainter(band: band, tier: tier, night: night),
    ),
  );
}

/// The spec's own range: 6% to 80% up the pitch.
const double _decoFMin = 0.06;
const double _decoFMax = 0.80;

/// **The mud's own count of bands**, so doubling the tuft bands did not double
/// the mud.
///
/// Five rather than the three it was, and the reason is drift: a band's whole
/// strip travels at the speed of ONE row — its centre — so anything painted far
/// off that row slides against the grass under it. Narrower bands mean a patch
/// is never more than a fifth of the pitch from the row it is moving at, which
/// is the same bargain [tuftBandFraction] makes.
const int _decoBands = 5;

/// The row a deco band's strip travels at — the middle of its slice of the
/// DECO's range.
///
/// **It was riding on [tuftBandFraction], and that is a different pitch.** The
/// tufts live between 0.34 and 0.96 and the mud between 0.06 and 0.80, so band
/// 0's mud is drawn near the bottom touchline — the closest, fastest ground on
/// the screen — and was being offset at the speed of the tuft band a third of
/// the way up. Depth IS speed here, so a puddle given a slower row than the one
/// it is painted on drifts backwards against the stripes under it. Reported
/// from the couch: the mud and the water on the tier-1 pitch moving slightly
/// slower than the pitch behind them.
///
/// Public because the test measures the placements against it rather than
/// against a copy of it.
double decoBandFraction(int band) =>
    _decoFMin + (_decoFMax - _decoFMin) * (band + 0.5) / _decoBands;

/// One thing on a battered surface.
enum DecoKind {
  /// Bare earth showing through the grass.
  patch,

  /// A rut or a mound — uneven ground, lit along the top.
  bump,

  /// Standing water, taking the sky.
  puddle,
}

/// One of them: where it sits across the segment, its row, its size, and the
/// seed its outline is torn with — see [decoOutline].
typedef DecoPlacement = ({
  DecoKind kind,
  double x,
  double f,
  double depth,
  double w,
  int seed,
});

/// **What is on the ground in this band at this tier**, in the order it is laid
/// down: bare earth first, then the ruts, then the water on top of both.
///
/// A list rather than three loops inside the painter, exactly as
/// [tuftPlacements] is — it is what lets the test check that nothing is painted
/// far from the one row its strip travels at, which is the whole of whether the
/// mud rides the grass or slides over it.
List<DecoPlacement> decoPlacements(int band, int tier) {
  final wear = pitchWear(tier);
  if (wear <= 0) return const [];
  final rng = math.Random(97 + band);
  const span = (_decoFMax - _decoFMin) / _decoBands;
  // **AS MUCH BARE EARTH AS GRASS.** One patch a band drew a green table with a
  // smudge on it; the Club tab's tier-1 photograph is mud with grass in it, and
  // this is the half of "a battered pitch" that has to carry that.
  final counts = {
    DecoKind.patch: (wear * 4).ceil(),
    DecoKind.bump: (wear * 2).ceil(),
    // Water is what a drain fixes first, so it goes a tier before the mud does.
    DecoKind.puddle: tier < firstKeptPitchTier ? (wear * 1.6).ceil() : 0,
  };
  // The middle half of the band, as the tufts keep to, so nothing is painted
  // far from the row its strip is offset at.
  final out = <DecoPlacement>[];
  for (final MapEntry(key: kind, value: count) in counts.entries) {
    for (var i = 0; i < count; i++) {
      final f = _decoFMin + (band + 0.25 + rng.nextDouble() * 0.5) * span;
      final depth = (f - _decoFMin) / (_decoFMax - _decoFMin);
      // The perspective, on everything: the far end of the pitch draws the same
      // puddle smaller, exactly as it draws the same tuft smaller.
      final near = 1 - depth * 0.55;
      final w = switch (kind) {
        // Bigger as well as more of it, so the worst pitch in the game is not
        // the best one with more marks on it.
        DecoKind.patch =>
          (20 + rng.nextDouble() * 42) * (0.55 + wear * 0.85) * near,
        DecoKind.bump => (30 + rng.nextDouble() * 52) * near,
        DecoKind.puddle => (30 + rng.nextDouble() * 34) * near,
      };
      out.add((
        kind: kind,
        x: rng.nextDouble(),
        f: f,
        depth: depth,
        w: w,
        seed: rng.nextInt(1 << 30),
      ));
    }
  }
  return out;
}

/// **MUD HAS NO EDGE AN OVAL CAN DRAW.** Every patch was a blurred ellipse, and
/// a dozen of them on one pitch read as stains on a green table rather than as
/// bare ground — the eye finds the repeated shape before it finds the mud. A
/// ragged ring around the same box, softened by the blur the paint carries.
Path decoOutline(Rect box, int seed) {
  const points = 11;
  final rng = math.Random(seed);
  final path = Path();
  for (var i = 0; i < points; i++) {
    final a = i / points * 2 * math.pi;
    final r = 0.7 + rng.nextDouble() * 0.44;
    final p = Offset(
      box.center.dx + math.cos(a) * box.width / 2 * r,
      box.center.dy + math.sin(a) * box.height / 2 * r,
    );
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  return path..close();
}

class _DecoPainter extends CustomPainter {
  const _DecoPainter({
    required this.band,
    required this.tier,
    required this.night,
  });

  final int band;
  final int tier;
  final bool night;

  @override
  void paint(Canvas canvas, Size size) {
    final wear = pitchWear(tier);
    for (final deco in decoPlacements(band, tier)) {
      final box = Rect.fromCenter(
        center: Offset(deco.x * size.width, size.height * (1 - deco.f)),
        width: deco.w,
        height: deco.w * switch (deco.kind) {
          DecoKind.patch => 0.5,
          DecoKind.bump => 0.34,
          DecoKind.puddle => 0.38,
        },
      );
      // A rut is a soft change of level and keeps its ellipse; earth and water
      // have a torn edge.
      final shape = deco.kind == DecoKind.bump
          ? (Path()..addOval(box))
          : decoOutline(box, deco.seed);
      canvas.drawPath(shape, switch (deco.kind) {
        // Bare earth. Deeper as well as denser with the wear: a churned
        // goalmouth is nearly black, and one alpha at every tier had the worst
        // pitch in the game reading as a dry patch on a good one.
        DecoKind.patch =>
          Paint()
            ..color = Color.lerp(
              const Color(0xFF7A5A3C),
              const Color(0xFF56381F),
              wear,
            )!.withValues(alpha: 0.18 + wear * 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
        // **UNEVEN GROUND: lit along the top, shadowed underneath.** That
        // pairing is the whole trick — a mound drawn in one tone is a stain,
        // and a park pitch has to read as rutted rather than as a flat green
        // table with marks on it.
        DecoKind.bump =>
          Paint()
            ..shader = ui.Gradient.linear(box.topCenter, box.bottomCenter, [
              Colors.white.withValues(alpha: 0.10 * wear),
              Colors.black.withValues(alpha: 0.16 * wear),
            ])
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
        // Standing water: it takes the SKY, not the grass, which is what makes
        // it read as a reflection rather than as a pale patch of turf.
        DecoKind.puddle =>
          Paint()
            ..shader = ui.Gradient.linear(box.topCenter, box.bottomCenter, [
              night ? const Color(0x8C4E6A80) : const Color(0xB8A6CDE8),
              night ? const Color(0x8C1E2A28) : const Color(0x8C46584E),
            ])
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
      });
      // The churned lip water stands in. Only round the water: it is what
      // separates a puddle from a pale patch of grass at a glance.
      if (deco.kind == DecoKind.puddle) {
        canvas.drawPath(
          shape,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = const Color(0x66422C18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DecoPainter old) =>
      old.band != band || old.tier != tier || old.night != night;
}

class _TuftPainter extends CustomPainter {
  const _TuftPainter({required this.band, required this.tier});

  final int band;
  final int tier;

  @override
  void paint(Canvas canvas, Size size) {
    // Seeded per tuft's blades only; where a tuft stands is shared with the
    // sprites — see [tuftPlacements].
    final rng = math.Random(97 + band);
    for (final t in tuftPlacements(band, tier)) {
      final depth = t.depth;
      final w = t.w;
      final tall = t.tall;
      final x = t.x * size.width;
      final base = size.height * (1 - t.f);
      final lean = t.lean;

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
    this.live = false,
    this.liveChild,
    this.stillKey,
  });

  /// How far the world has travelled, in pixels at THIS strip's row.
  final double offsetPx;

  final double segmentWidth;
  final Widget child;

  /// The part of the segment that is allowed to move, tiled over [child] at the
  /// same offset. Only this one drops its picture while [live] — see
  /// [_liveRows].
  final Widget? liveChild;

  /// True while the segment itself is animating (a surging crowd), which is
  /// the one time it must be drawn rather than shown as a picture.
  final bool live;

  /// What the picture depends on. A change takes a new one — a snapshot never
  /// notices its child repainting.
  final Object? stillKey;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: LayoutBuilder(
      builder: (context, constraints) {
        // One spare segment so the leading edge is always covered.
        final count = (constraints.maxWidth / segmentWidth).ceil() + 2;
        // **WHOLE DEVICE PIXELS, or the picture wobbles.** The still strip is
        // a raster, and a raster drawn a fraction of a pixel along is
        // resampled at a new phase every frame: sharp on the pixel, soft
        // half-way between. At the hills' crawl that is a house's edge
        // pulsing every few frames — reported as the houses and trees moving
        // while the fans, who are drawn live, did not. Snapped here rather
        // than in the still, so the live layer over it takes the same shift.
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final shift = ((offsetPx % segmentWidth) * dpr).round() / dpr;
        final still = _tiled(count, shift, child, animating: false, id: 'still');
        final moving = liveChild;
        if (moving == null) return still;
        // One offset drives both, so the two halves cannot come apart.
        return Stack(
          fit: StackFit.expand,
          children: [
            still,
            _tiled(count, shift, moving, animating: live, id: 'live'),
          ],
        );
      },
    ),
  );

  Widget _tiled(
    int count,
    double shift,
    Widget segment, {
    required bool animating,
    required String id,
  }) => Transform.translate(
    // Right to left: the world moves past him, he walks in place.
    offset: Offset(-shift, 0),
    child: OverflowBox(
      alignment: Alignment.centerLeft,
      maxWidth: count * segmentWidth,
      // Its own layer. The translate above repaints every frame, and
      // without this every tiled painter (five stands, five hoardings…)
      // re-ran its paint each time — half the UI thread at idle.
      child: _StillStrip(
        key: ValueKey((id, stillKey)),
        live: animating,
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
          children: [for (var i = 0; i < count; i++) segment],
        ),
      ),
    ),
  );
}

/// The tiled row as ONE PICTURE. Impeller keeps no raster cache, so a
/// `RepaintBoundary` alone still re-rasterised five stands of ~300 fans every
/// frame under the translate; a snapshot is drawn once and moved.
class _StillStrip extends StatefulWidget {
  const _StillStrip({super.key, required this.live, required this.child});

  final bool live;
  final Widget child;

  @override
  State<_StillStrip> createState() => _StillStripState();
}

class _StillStripState extends State<_StillStrip> {
  late final SnapshotController _controller = SnapshotController(
    allowSnapshotting: !widget.live,
  );

  @override
  void didUpdateWidget(_StillStrip old) {
    super.didUpdateWidget(old);
    if (old.live != widget.live) {
      _controller.allowSnapshotting = !widget.live;
      if (!widget.live) _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  // At the DEVICE's ratio, not capped at 2x as the customiser's stills are.
  // Sharpness was never the point of the cap and is not what it cost: a 2x
  // raster on a 2.6x or 3x screen is scaled by a fraction, so one raster pixel
  // is one-and-a-bit device pixels and the strip cannot be moved by a whole
  // number of both — the snap in [_Scroller] only holds when a raster pixel
  // IS a device pixel.
  Widget build(BuildContext context) => SnapshotWidget(
    controller: _controller,
    mode: SnapshotMode.permissive,
    child: RepaintBoundary(child: widget.child),
  );
}
