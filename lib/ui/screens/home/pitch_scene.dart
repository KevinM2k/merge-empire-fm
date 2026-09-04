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
/// **1.12, because the ground runs level again.** With the turf at one speed
/// the planted foot outruns it by half at mid-stance, and the eye reads that
/// as the grass being too slow even when the average is exact — reported from
/// the couch in as many words the moment the per-step ease came out. Pushing
/// the mean up a shade is the honest correction: the fastest part of the
/// stance is what the eye locks onto, and this closes most of that gap without
/// making the swing phase visibly quick. It was 1 while [groundEase] tracked
/// the foot outright and there was nothing to trim.
const double groundSpeedTrim = 1.12;

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

/// Per band, per 420px segment, **AT THIS TIER**.
///
/// **The port drew the same kept pitch at every rank.** The spec scales it hard
/// and says why: nobody mows a Sunday League pitch, so the bottom of the pyramid
/// gets a lot more clumps, bigger and longer in the blade, and a top-flight
/// ground gets almost none. `_tuftBands` in `PitchScene.js`: sixteen at tier 0,
/// eleven at tier 1, then `7 - tier` and nothing at all from Continental up.
int tuftsPerBand(int tier) {
  final total = tier == 0
      ? 16
      : tier == 1
      ? 11
      : math.max(0, 7 - tier);
  return (total / _tuftBands).ceil();
}

/// How much bigger and longer the blades are down the bottom. The spec's
/// `sizeBoost` and `lengthBoost`: a rough pitch is rough in the grass first.
double tuftSizeBoost(int tier) => tier == 0 ? 2.1 : (tier == 1 ? 1.5 : 1.0);
double tuftLengthBoost(int tier) =>
    tier == 0 ? 1.25 : (tier == 1 ? 1.05 : 0.85);

/// **THE TIER THE PITCH STOPS BEING A FIELD.** Below this it gets mud, ruts and
/// standing water; at and above it the groundsman has been.
const int firstKeptPitchTier = 2;

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
                // The far strip: the stand and its crowd, at the speed of the
                // ground it is planted in — see [farPeriod]. Its height is the TERRACE's
                // own, not a fraction of the page: at `h * 0.24` it was a 200px bank
                // of seats with a hundred 1px dots in it, which is the shape of a
                // crowd without being one.
                Positioned(
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
                  height: standHeightFor(tier),
                  // Tapping the terrace gets the crowd up — the JS's own
                  // interaction, and the one thing on this screen that answers a
                  // tap with a crowd rather than with a menu.
                  child: _Crowd(
                    celebration: celebration,
                    builder: (beat, excitement) => _GroundDrive(
                      builder: (worldX) => _Scroller(
                        key: const ValueKey('pitch-stand'),
                        live: excitement > 0,
                        stillKey: (kitColor, haze, tier),
                        offsetPx: parallaxOffset(
                          worldX,
                          segmentWidth: farSegmentWidth,
                          period: farPeriod,
                          mood: mood,
                        ),
                        segmentWidth: farSegmentWidth,
                        liveChild: tier < firstStandTier
                            ? null
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
                              sceneWidth: w,
                              walkerLeft: w * 0.45 - 57,
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
  /// **AT REST THE CROWD IS STILL.** The bounce ran every frame for the life
  /// of the screen and was half the UI thread on a flagship phone, for a
  /// movement nobody could see. The clock runs while a surge decays and stops.
  void _sync() {
    final run = _excitement > 0 && !MediaQuery.of(context).disableAnimations;
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
  });

  final Color kitColor;
  final Color haze;

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
        ? CustomPaint(painter: ParkPainter(haze: haze, tier: tier))
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
  const ParkPainter({required this.haze, required this.tier});

  final Color haze;
  final int tier;

  @override
  void paint(Canvas canvas, Size size) {
    // Seeded like the crowd is, so the tree line does not reshuffle per frame.
    final rng = math.Random(11);
    final scale = _crowdScale;
    final unit = size.width / 480;
    final h = size.height;
    final base = h;

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
    void tree(double x, double size_, {bool tall = false}) {
      final s = math.min(size_, h / (49 * scale));
      final w = (tall ? 22 : 34) * scale * s;
      final crownH = (tall ? 40 : 30) * scale * s;
      final trunkH = (tall ? 12 : 15) * scale * s;
      final trunkW = (tall ? 4 : 6) * scale * s;
      final cx = x + w / 2;
      // Shadow on the ground, so it stands on the grass rather than on the
      // horizon line.
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + w * 0.15, base - 1), width: w * 1.1, height: 4 * scale),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
      // Trunk, tapered, with a branch or two into the crown.
      canvas.drawPath(
        Path()
          ..moveTo(cx - trunkW * 0.7, base + 1)
          ..lineTo(cx + trunkW * 0.7, base + 1)
          ..lineTo(cx + trunkW * 0.35, base - trunkH - crownH * 0.35)
          ..lineTo(cx - trunkW * 0.35, base - trunkH - crownH * 0.35)
          ..close(),
        Paint()..color = const Color(0xFF5E4130),
      );
      canvas.drawLine(
        Offset(cx, base - trunkH - crownH * 0.2),
        Offset(cx + w * 0.22, base - trunkH - crownH * 0.5),
        Paint()
          ..color = const Color(0xFF5E4130)
          ..strokeWidth = trunkW * 0.35,
      );
      final crownTop = base - trunkH - crownH;
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
    void person(double x, Color shirt, Color hair, {bool sitting = false, bool waving = false, double seatY = 0}) {
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

    // Trees, two species, in a loose line.
    tree((22 + rng.nextDouble() * 20) * unit, 0.9 + rng.nextDouble() * 0.3);
    tree((120 + rng.nextDouble() * 20) * unit, 1.0 + rng.nextDouble() * 0.25, tall: true);
    tree((205 + rng.nextDouble() * 30) * unit, 0.75 + rng.nextDouble() * 0.3);
    tree((340 + rng.nextDouble() * 30) * unit, 0.9 + rng.nextDouble() * 0.3);
    tree((430 + rng.nextDouble() * 20) * unit, 0.8, tall: true);

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
      canvas.drawRect(Rect.fromLTWH(hx + 6 * unit, base - 8 * scale, 5 * unit, 8 * scale + 1), Paint()..color = const Color(0xFF4A5B6A));
      canvas.drawRect(Rect.fromLTWH(hx + 18 * unit, base - 10 * scale, 7 * unit, 5 * scale), Paint()..color = const Color(0xFFBFDCEC));
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
      person(bench1 + 6 * unit, _fanColours[rng.nextInt(_fanColours.length)], hairs[rng.nextInt(hairs.length)], sitting: true, seatY: base - 7 * scale);
      final px = (170 + rng.nextDouble() * 40) * unit;
      person(px, _fanColours[rng.nextInt(_fanColours.length)], hairs[rng.nextInt(hairs.length)], waving: rng.nextDouble() < 0.6);
      // The dog: a body, a head, four legs and a tail up.
      final dx = px + 14 * unit;
      final dog = Paint()..color = const Color(0xFF7A5A3A);
      canvas.drawOval(Rect.fromLTWH(dx, base - 5 * scale, 7 * unit, 3.2 * scale), dog);
      canvas.drawCircle(Offset(dx + 7.4 * unit, base - 4.6 * scale), 1.7 * unit, dog);
      for (final lx2 in [dx + 1 * unit, dx + 2.6 * unit, dx + 4.6 * unit, dx + 6 * unit]) {
        canvas.drawRect(Rect.fromLTWH(lx2, base - 2.2 * scale, 0.9 * unit, 2.2 * scale + 1), dog);
      }
      canvas.drawLine(Offset(dx + 0.3 * unit, base - 4.4 * scale), Offset(dx - 1.6 * unit, base - 7 * scale), Paint()..color = const Color(0xFF7A5A3A)..strokeWidth = 0.9 * unit..strokeCap = StrokeCap.round);
    }

    // The low white fence along the front, which is what says "park" rather
    // than "field": a rail, and posts every 24.
    //
    // **ITS FEET ARE ON THE PITCH.** This strip's bottom edge IS the horizon,
    // so a post that runs to `size.height` is a post standing on the turf.
    // Two units of overlap, because a hairline gap at a seam between two
    // layers is what a rounding error looks like on a real screen.
    final fenceTop = h - 17 * scale;
    final rail = Paint()..color = const Color(0xD9E2E2D8);
    final railShade = Paint()..color = const Color(0x66707068);
    canvas.drawRect(Rect.fromLTWH(0, fenceTop + 3 * scale, size.width, 2 * scale), rail);
    canvas.drawRect(Rect.fromLTWH(0, fenceTop + 5 * scale, size.width, 0.6 * scale), railShade);
    canvas.drawRect(Rect.fromLTWH(0, fenceTop + 9.5 * scale, size.width, 1.4 * scale), rail);
    for (var x = 0.0; x < size.width; x += 24 * unit) {
      canvas.drawRect(Rect.fromLTWH(x, fenceTop, 3 * unit, h - fenceTop + 2), rail);
      canvas.drawRect(Rect.fromLTWH(x + 2.2 * unit, fenceTop, 0.8 * unit, h - fenceTop + 2), railShade);
    }

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
      old.haze != haze || old.tier != tier;
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
        // At rest only the keenest fifth are up; excitement brings the rest.
        final up = keen < 0.2 + excitement * 0.8;
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
            armsUp: armsUp,
          );
        }
      }
      }
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
    required this.tier,
  });

  final Mood mood;

  /// How well kept the pitch is — see [tuftsPerBand] and [firstKeptPitchTier].
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
                    // **MUD, RUTS AND STANDING WATER, under the grass.** The
                    // bottom two tiers are a field rather than a pitch, and
                    // this is most of what says so — the spec scatters them
                    // from 6% to 80% up the pitch and rides them on the ground
                    // at their own depth, exactly as the tufts do.
                    if (tier < firstKeptPitchTier)
                      for (var band = 0; band < _tuftBands; band++)
                        Positioned.fill(
                          child: _Scroller(
                            offsetPx: atRow(_decoBandFraction(band)),
                            segmentWidth: groundSegmentWidth,
                            stillKey: (band, tier),
                            child: _DecoSegment(band: band, tier: tier),
                          ),
                        ),
                    for (var band = 0; band < _tuftBands; band++)
                      Positioned.fill(
                        child: _Scroller(
                          offsetPx: atRow(tuftBandFraction(band)),
                          segmentWidth: groundSegmentWidth,
                          stillKey: (band, tier),
                          child: _TuftSegment(band: band, tier: tier),
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

    final apexY = mowApex * h;
    // Enough of the fan to cover the box's far corners, plus a lane either side
    // so the sweep never uncovers an edge.
    final half = math.atan2(inner / 2, -apexY) + _mowPeriod * 2;
    final reach = (h - apexY) * 1.6;
    final light = Paint()..color = const Color(0x0EFFFFFF);
    final dark = Paint()..color = const Color(0x0D000000);

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
  bool shouldRepaint(_MowPainter old) => old.phase != phase;
}

class _TuftSegment extends StatelessWidget {
  const _TuftSegment({required this.band, required this.tier});

  final int band;
  final int tier;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: groundSegmentWidth,
    height: double.infinity,
    child: CustomPaint(painter: _TuftPainter(band: band, tier: tier)),
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
  const _DecoSegment({required this.band, required this.tier});

  final int band;
  final int tier;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: groundSegmentWidth,
    height: double.infinity,
    child: CustomPaint(painter: _DecoPainter(band: band, tier: tier)),
  );
}

/// The spec's own range: 6% to 80% up the pitch.
const double _decoFMin = 0.06;
const double _decoFMax = 0.80;

/// The middle of a deco band, over the DECO's range.
///
/// **It was riding on [tuftBandFraction], and that is a different pitch.** The
/// tufts live between 0.34 and 0.96 and the mud between 0.06 and 0.80, so band
/// 0's mud is drawn near the bottom touchline — the closest, fastest ground on
/// the screen — and was being offset at the speed of the tuft band a third of
/// the way up. Depth IS speed here, so a puddle given a slower row than the one
/// it is painted on drifts backwards against the stripes under it. Reported
/// from the couch: the mud and the water on the tier-1 pitch moving slightly
/// slower than the pitch behind them.
double _decoBandFraction(int band) =>
    _decoFMin + (_decoFMax - _decoFMin) * (band + 0.5) / _tuftBands;

class _DecoPainter extends CustomPainter {
  const _DecoPainter({required this.band, required this.tier});

  final int band;
  final int tier;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(97 + band);
    final span = (_decoFMax - _decoFMin) / _tuftBands;
    // A park pitch is worse than a Sunday League one, and the counts say so.
    final patches = tier == 0 ? 2 : 1;
    final bumps = tier == 0 ? 2 : 1;
    final puddles = tier == 0 ? 1 : 1;

    double bandF() => _decoFMin + (band + rng.nextDouble()) * span;

    // Bare earth, first: the grass and everything else sits on top of it.
    for (var i = 0; i < patches; i++) {
      final f = bandF();
      final w = 22 + rng.nextDouble() * 40;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(rng.nextDouble() * size.width, size.height * (1 - f)),
          width: w,
          height: w * 0.5,
        ),
        Paint()
          ..color = const Color(0x8C6B4A2E)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // **UNEVEN GROUND: lit along the top, shadowed underneath.** That pairing is
    // the whole trick — a mound drawn in one tone is a stain, and a park pitch
    // has to read as rutted rather than as a flat green table with marks on it.
    for (var i = 0; i < bumps; i++) {
      final f = bandF();
      final w = 30 + rng.nextDouble() * 52;
      final c = Offset(rng.nextDouble() * size.width, size.height * (1 - f));
      final box = Rect.fromCenter(center: c, width: w, height: w * 0.34);
      canvas.drawOval(
        box,
        Paint()
          ..shader = ui.Gradient.linear(box.topCenter, box.bottomCenter, [
            Colors.white.withValues(alpha: 0.10),
            Colors.black.withValues(alpha: 0.16),
          ])
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
    }

    // Standing water: it takes the SKY, not the grass, which is what makes it
    // read as a reflection rather than as a pale patch of turf.
    for (var i = 0; i < puddles; i++) {
      final f = _decoFMin + (band + rng.nextDouble()) * span * 0.7;
      final w = 30 + rng.nextDouble() * 34;
      final c = Offset(rng.nextDouble() * size.width, size.height * (1 - f));
      final box = Rect.fromCenter(center: c, width: w, height: w * 0.38);
      canvas.drawOval(
        box,
        Paint()
          ..shader = ui.Gradient.linear(box.topCenter, box.bottomCenter, [
            const Color(0x99A8C4D8),
            const Color(0x4D3E5A55),
          ])
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
      );
    }
  }

  @override
  bool shouldRepaint(_DecoPainter old) =>
      old.band != band || old.tier != tier;
}

class _TuftPainter extends CustomPainter {
  const _TuftPainter({required this.band, required this.tier});

  final int band;
  final int tier;

  @override
  void paint(Canvas canvas, Size size) {
    // Seeded per band so each depth has its own arrangement and none of them
    // reshuffle between frames.
    final rng = math.Random(31 + band);
    final span = (tuftFMax - tuftFMin) / _tuftBands;

    final count = tuftsPerBand(tier);
    final sizeBoost = tuftSizeBoost(tier);
    final lengthBoost = tuftLengthBoost(tier);
    for (var i = 0; i < count; i++) {
      // How far up the pitch this clump sits. Its band owns a third of the
      // range, so a sparse pitch still spreads its tufts through the depth
      // instead of stacking them at one distance.
      final f = tuftFMin + (band + rng.nextDouble()) * span;
      final depth = (f - tuftFMin) / (tuftFMax - tuftFMin);
      // Fake perspective: the further up the pitch, the smaller.
      final w = math.max(
        4.0,
        (9 + rng.nextDouble() * 7) * (1 - depth * 0.55) * sizeBoost,
      );
      final tall = w * lengthBoost;
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
        final still = _tiled(count, child, animating: false, id: 'still');
        final moving = liveChild;
        if (moving == null) return still;
        // One offset drives both, so the two halves cannot come apart.
        return Stack(
          fit: StackFit.expand,
          children: [
            still,
            _tiled(count, moving, animating: live, id: 'live'),
          ],
        );
      },
    ),
  );

  Widget _tiled(
    int count,
    Widget segment, {
    required bool animating,
    required String id,
  }) => Transform.translate(
    // Right to left: the world moves past him, he walks in place.
    offset: Offset(-(offsetPx % segmentWidth), 0),
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
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // 2x at most, as the customiser's stills: the eye gets nothing from 3x.
    return MediaQuery(
      data: media.copyWith(
        devicePixelRatio: math.min(media.devicePixelRatio, 2),
      ),
      child: SnapshotWidget(
        controller: _controller,
        mode: SnapshotMode.permissive,
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}
