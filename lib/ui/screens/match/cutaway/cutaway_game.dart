/// The 2D cutaway, as a Flame game. Ported from
/// `ui/components/ChanceCutaway.js`.
///
/// This is the one screen in the game that genuinely wants a game loop rather
/// than a widget tree: twenty-two bodies steering toward moving targets, a ball
/// on a bezier with height, and a defensive line reacting on staggered clocks.
/// Everything else in the port is UI and stays widgets.
///
/// **Two layers of motion, and they are different on purpose.**
///
/// - The BALL is tweened along an eased, gently curved path. A lofted ball
///   additionally scales up mid-flight while its shadow drops away, because
///   height is otherwise invisible on a flat top-down pitch — and without it a
///   cross and a square ball look the same, so a header has nothing to be a
///   header off.
/// - Every PLAYER is a MOVER: a target, smoothed velocity, an arrival radius
///   and its own pace. They accelerate, decelerate and drift like individuals
///   rather than sliding along straight lines. A carrier detaches the ball from
///   the tween and knocks it along a step ahead of their feet.
///
/// **The sprites are Kenney's top-down sports pack** (CC0). There is no run
/// cycle in it and none is wanted: these are overhead figures, so heading is
/// rotation and movement reads from the movement itself. Ten skin and hair
/// variants per kit colour is what stops a team looking like eleven clones.
///
/// **And they face along +X.** The figure is a shirt oval with the head on top
/// and the FACE as a light crescent on the RIGHT of it, so the drawing looks
/// down the positive x axis — not up the pitch, which is what this file
/// believed. See [Mover.heading].
library;

import 'dart:math' as math;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_pitch.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_sequences.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_stage.dart'
    show shortName;
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

/// How a chance ended.
enum CutawayOutcome { goal, saved, post, wide, over, tackled }

/// Which kit a figure wears. Kenney ships Blue, Green, Red and White; green and
/// red are the two the JS uses for the teams, and white keeps the keepers
/// clearly apart from both.
enum Kit { green, red, white }

String _kitName(Kit kit) => switch (kit) {
  Kit.green => 'green',
  Kit.red => 'red',
  Kit.white => 'white',
};

/// The sprite files this game needs, in Flame's `assets/images/`-relative form.
///
/// Ten body variants per kit, plus the ball. Listed rather than globbed so a
/// missing file fails at load with a name rather than at draw with a blank.
List<String> cutawaySpritePaths() => [
  for (final kit in Kit.values)
    for (var i = 1; i <= 10; i++) '${_kitName(kit)}_$i.png',
  'ball.png',
];

/// ONE cache, for the whole match rather than for each chance.
///
/// A `FlameGame` owns its own `Images` by default, so every clip decoded all
/// thirty-one sprites again from scratch — and because `onLoad` is async, the
/// widget showed a bare green rectangle until it finished. Several times a
/// match. That is what the flash was.
final Images cutawayImages = Images(prefix: 'assets/pitch/');

/// Filled by the first chance and shared by every one after it.
///
/// It is deliberately NOT warmed at kickoff any more: an unawaited load fired
/// from `initState` outlives whatever started it, which is a stray future in
/// production and a flaky teardown in a test. The first chance pays for it
/// once, and the stage paints the markings underneath meanwhile — so what that
/// frame costs is the players arriving a beat late, not a green flash.
Future<void> preloadCutawaySprites() async {
  await cutawayImages.loadAll(cutawaySpritePaths());
}

double _easeOut(double t) => 1 - math.pow(1 - t, 3).toDouble();
double _linear(double t) => t;

/// One body on the pitch.
///
/// The steering is the whole character model: [target] is where it wants to be,
/// [_velocity] catches up to the direction of travel at [MoverTuning.accel] per
/// second, and inside [MoverTuning.arriveRadius] the desired speed falls away
/// so it settles rather than stopping dead.
class Mover extends PositionComponent {
  Mover({
    required this.sprite,
    required Vector2 start,
    required this.paceScale,
    this.label,
  }) : super(
         position: start.clone(),
         size: Vector2(5.2, 5.2),
         anchor: Anchor.center,
       );

  final Sprite sprite;

  /// Individual pace, so a back four does not move as one object.
  ///
  /// **Not final any more**: a receiver has to be able to run at whatever pace
  /// MEETS the ball. See [sprintTo], and `_basePace` for what it goes back to.
  double paceScale;

  late final double _basePace = paceScale;

  /// A surname or a shirt number. Null draws nothing.
  /// What is written under him: a name for our eleven, a shirt number for
  /// theirs, `GK` for the keeper — the JS's dots, on a figure. Mutable because
  /// the scorer's name moves onto whoever takes the shot.
  String? label;

  /// **A `TextPaint` INHERITS NOTHING**, so the family is named here or the
  /// names on the pitch are drawn in the platform's own font — the same escape
  /// the button styles were making.
  ///
  /// Sixteen rather than 12.8, which is four world units against a 5.2-unit
  /// figure: asked for from the couch as the names wanting to be a bit bigger.
  /// The size is quadrupled and the canvas scaled back down at the call — a
  /// 4-unit font rasterises as mush — so this number is four times what lands.
  static final TextPaint _labelPaint = TextPaint(
    style: const TextStyle(
      fontSize: 16,
      fontFamily: uiFontFamily,
      fontWeight: FontWeight.w800,
      color: Colors.white,
      shadows: [Shadow(offset: Offset(0.5, 0.5), color: Colors.black87)],
    ),
  );

  Vector2 target = Vector2.zero();
  final Vector2 _velocity = Vector2.zero();

  /// How fast he is going, and where to — what his facing has to agree with,
  /// and the seam `cutaway_facing_test` checks it against.
  double get speed => _velocity.length;
  double get travelAngle => math.atan2(_velocity.y, _velocity.x);

  /// Which way the figure is facing, in radians, clockwise from +X.
  ///
  /// **Zero points RIGHT, because that is where the art looks.** It was read as
  /// north — `atan2(x, -y)`, sprites "drawn facing up" — and Kenney's top-down
  /// footballer is not: the face is a pale crescent on the right of the head,
  /// so every figure on the pitch ran with its face a quarter turn off the way
  /// it was going. A man sprinting at the goal was looking at the far
  /// touchline. Reported from the couch; the sprite files are where it was
  /// settled, `green_1.png` in a pixel dump.
  double heading = 0;

  /// Where the ball is — [_lookAngle]'s other half. Null just means nobody has
  /// told him, and then he faces his run.
  Vector2 Function()? watching;

  /// Whether he has ever faced anywhere: the first frame SNAPS rather than
  /// turning, so a clip does not open on eleven men spinning round.
  bool _facedOnce = false;

  /// Brains off — a wall in a free kick, or anyone after the ball has gone in.
  bool frozen = false;

  /// How far into a stride, 0..1, advanced by DISTANCE COVERED rather than by
  /// time.
  ///
  /// **The run cycle is a WEIGHT SHIFT, not legs.** Kenney's top-down sports
  /// characters are a shirt oval, a head and two arm stubs — there are no legs in
  /// the pack to swap, and the modular-character pack's legs are side-on, so they
  /// would not work here either. What a top-down runner actually shows is the
  /// body rocking foot to foot: a small roll of the shoulders and a bob, in time
  /// with the stride. Driven off distance so a walking figure rocks slowly and a
  /// sprinting one fast, without a second speed to keep in step.
  double _stride = 0;

  /// Arms up. Set for the length of a celebration.
  bool celebrating = false;

  /// Run to [spot] fast enough to be there in [seconds].
  ///
  /// **THE BALL WAS ARRIVING AT NOBODY.** A receiver is a body steering toward
  /// a target at his own pace while the ball is a tween on a fixed duration —
  /// two clocks with nothing keeping them together — so a through ball outran
  /// its runner and landed on empty grass, and a `firstTime` finish then fired
  /// from a spot with no player on it. Watched from the couch that is "the ball
  /// goes to an invisible player who then scores".
  ///
  /// Never SLOWER than his own pace: a short square ball should not make him
  /// amble. Capped, because a runner who cannot make it in time is a script
  /// asking for a run nobody could make, and a figure crossing the pitch in a
  /// blink is worse than one arriving a beat late.
  void sprintTo(Vector2 spot, double seconds) {
    target = spot.clone();
    paceScale = meetPace(
      distance: position.distanceTo(spot),
      seconds: seconds,
      basePace: _basePace,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (frozen || dt <= 0) return;

    final toTarget = target - position;
    final distance = toTarget.length;
    if (distance > 0.01) {
      // Ease into the target rather than arriving at cruise and stopping.
      final approach = distance < MoverTuning.arriveRadius
          ? distance / MoverTuning.arriveRadius
          : 1.0;
      final desired = toTarget.normalized()
        ..scale(MoverTuning.baseSpeed * paceScale * approach);
      // Exponential smoothing — frame-rate independent, unlike a fixed lerp.
      final blend = 1 - math.exp(-MoverTuning.accel * dt);
      _velocity.setValues(
        _velocity.x + (desired.x - _velocity.x) * blend,
        _velocity.y + (desired.y - _velocity.y) * blend,
      );
    } else {
      _velocity.scale(math.max(0, 1 - 6 * dt));
      // Arrived, so he goes back to his own legs. Self-cleaning rather than
      // something every call site has to remember — a dribbler carrying a
      // sprint pace he was given for somebody else's pass is exactly the kind
      // of leak a manual reset produces.
      paceScale = _basePace;
    }

    final step = _velocity * dt;
    position.add(step);
    // **AND HE STAYS ON THE PITCH.** The camera shows exactly the 200x120, so
    // off the field is off the screen — and a run to the corner overshoots,
    // because the velocity eases in and out rather than stopping on the spot.
    // Men vanished into the surround on the way to a flag; reported from the
    // couch. Clamped rather than steered: the scripts want him AT the corner,
    // and a body that cannot cross the touchline is what a touchline is. His
    // own width, so the FIGURE stays in frame and not just his centre.
    position.setValues(
      position.x.clamp(size.x / 2, pitchWidth - size.x / 2),
      position.y.clamp(size.y / 2, pitchHeight - size.y / 2),
    );
    // One stride per ~4.2 units covered.
    _stride = (_stride + step.length / 4.2) % 1;

    final want = _lookAngle();
    if (!_facedOnce) {
      _facedOnce = true;
      heading = want;
    } else {
      final turn = shortestTurn(heading, want);
      final most = MoverTuning.turnRate * dt;
      // Kept inside a turn of zero, which is what `shortestTurn` from 0 is: a
      // heading that only ever accumulates ends up a number nobody can read.
      heading = shortestTurn(0, heading + turn.clamp(-most, most));
    }
  }

  /// Which way he WANTS to be facing: down the run, canted toward the ball.
  ///
  /// The share the ball takes falls off with speed — see
  /// [MoverTuning.watchAtRest] — so a standing player is square to it and a
  /// sprinter leads with his run. A ball at his own feet is not something to
  /// look at, and neither is a ball nobody has told him about.
  double _lookAngle() {
    final speed = _velocity.length;
    final running = speed > _walking;
    final run = running ? math.atan2(_velocity.y, _velocity.x) : heading;
    final ball = watching?.call();
    if (ball == null) return run;
    final toBall = ball - position;
    if (toBall.length < MoverTuning.ballAtFeet) return run;
    final at = math.atan2(toBall.y, toBall.x);
    if (!running) return at;
    final share =
        MoverTuning.watchAtRest +
        (MoverTuning.watchAtRun - MoverTuning.watchAtRest) *
            (speed / MoverTuning.baseSpeed).clamp(0.0, 1.0);
    final cant = shortestTurn(run, at) * share;
    return run +
        cant.clamp(-MoverTuning.watchMostOff, MoverTuning.watchMostOff);
  }

  /// Below this he is standing still as far as his eyeline is concerned.
  static const double _walking = 1;

  @override
  void render(Canvas canvas) {
    final rock = math.sin(_stride * 2 * math.pi);
    // Two strides per bob: the body rises on each footfall, not on each pair.
    final bob = math.sin(_stride * 4 * math.pi);
    // **A CONTACT SHADOW.** The pitch is in perspective and the men standing on
    // it were flat sprites with nothing underneath — reported as the players
    // looking flat. Drawn before the rotate, so it stays on the GROUND while he
    // turns, and it tightens as he rises on each footfall, which is the whole
    // of the depth in a running figure.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y * 0.88),
        width: size.x * (0.60 - bob * 0.06),
        height: size.y * (0.19 - bob * 0.03),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.30),
    );
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    // The roll leads the heading by a few degrees either way, which is what
    // makes the figure read as running rather than sliding.
    canvas.rotate(heading + rock * 0.09);
    final lift = 1 + bob * 0.035 + (celebrating ? 0.14 : 0);
    canvas.scale(lift);
    canvas.translate(-size.x / 2, -size.y / 2);
    sprite.render(canvas, size: size);
    canvas.restore();

    // Under his feet, upright whichever way he is running. Drawn at four times
    // the size and scaled down, because a 3-unit font rasterises as mush.
    final text = label;
    if (text != null && text.isNotEmpty) {
      canvas.save();
      canvas.translate(size.x / 2, size.y + 0.3);
      canvas.scale(0.25);
      _labelPaint.render(canvas, text, Vector2.zero(), anchor: Anchor.topCenter);
      canvas.restore();
    }
  }
}

/// The ball, and its shadow.
///
/// [loft] is 0 on the deck and 1 at the top of a lofted flight. The sprite
/// scales with it and the shadow slides away underneath, which is the only cue
/// for height on a flat pitch.
class Ball extends PositionComponent {
  Ball({required this.sprite, required Vector2 start})
    : super(
        position: start.clone(),
        size: Vector2(3.4, 3.4),
        anchor: Anchor.center,
      );

  final Sprite sprite;

  /// 0 on the deck, 1 at the top of a lofted flight.
  ///
  /// NOT called `height`: that is `PositionComponent`'s own, and it drives
  /// `size.y`. Shadowing it would make the ball's altitude silently resize it.
  double loft = 0;

  @override
  void render(Canvas canvas) {
    final lift = 1 + loft * 0.55;
    // The shadow stays on the ground and drifts as the ball rises, so the two
    // separating is what reads as height.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y / 2 + loft * 2.2),
        width: size.x * 0.9,
        height: size.y * 0.5,
      ),
      Paint()
        // **`loft`, NOT `height`.** `height` is `PositionComponent`'s own and
        // is the ball's SIZE — 3.4 — so this resolved to a negative alpha and
        // the ball had no shadow at all. The file's own note warns about
        // exactly this name and the shadow was the one place it bit.
        ..color = Colors.black.withValues(alpha: 0.30 * (1 - loft * 0.4)),
    );
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(lift);
    canvas.translate(-size.x / 2, -size.y / 2);
    sprite.render(canvas, size: size);
    canvas.restore();
  }
}

/// The pitch: turf, mown stripes and markings, in the 200×120 space every
/// script is written in.
class PitchBackdrop extends PositionComponent {
  PitchBackdrop() : super(size: Vector2(pitchWidth, pitchHeight));

  static const Color turf = Color(0xFF2D6A2D);

  /// What is OUTSIDE the touchlines.
  ///
  /// **The pitch and the not-pitch were the same green, which is what made most
  /// of the pitch look missing.** The stage backs its clip box with a flat fill
  /// and it was [turf] — the identical colour the pitch itself is painted in. So
  /// a tilted pitch is a trapezoid inside a rectangle, and the two triangles of
  /// dead space beside the far touchline were indistinguishable from the grass:
  /// what a player saw was a green rectangle with some faint white lines
  /// floating in the middle of it, nowhere near its edges.
  ///
  /// Measured rather than guessed — on a 375-point band the far touchline spans
  /// 249 points of it, so a third of the box's width at the top is outside the
  /// pitch. That space is not a bug in the fit (`fittedTilt` puts all four
  /// corners inside the band, three points in); it is what a camera behind the
  /// goal SEES, and it has to be a different colour or the tilt reads as a crop.
  static const Color surround = Color(0xFF14351B);

  @override
  void render(Canvas canvas) {
    renderTurf(canvas);
    renderLines(canvas);
  }

  /// The grass alone — split from the markings so the idle stage can lay the
  /// momentum shading between the two.
  void renderTurf(Canvas canvas) {
    canvas.save();
    canvas.clipRRect(_grass);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, pitchWidth, pitchHeight),
      Paint()..color = turf,
    );
    // Mown stripes. Ten bands, every other one lifted.
    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.035);
    for (var i = 0; i < 10; i += 2) {
      canvas.drawRect(Rect.fromLTWH(i * 20, 0, 20, pitchHeight), stripe);
    }
    canvas.restore();
  }

  /// **THE GRASS HAS ROUNDED CORNERS, to sit in a rounded box.**
  ///
  /// The stage clips its band to `stageRadius`, so the surround outside the
  /// touchlines is a rounded rectangle — and the pitch inside it was a hard
  /// rectangle with a hard right angle at each corner, three points in. Two
  /// corners of different shapes a few pixels apart, which is what was
  /// reported from the couch with a screenshot of the top-left one.
  ///
  /// **In PITCH space, so the perspective skews it.** A radius applied on the
  /// screen side would sit square against a quad that does not, which is the
  /// same mistake in the other direction; taking the tilt is what makes it read
  /// as a rounded pitch seen at an angle rather than as a rounded mask over
  /// one.
  static const double cornerRadius = 5;

  static final RRect _grass = RRect.fromRectAndRadius(
    const Rect.fromLTWH(0, 0, pitchWidth, pitchHeight),
    const Radius.circular(cornerRadius),
  );

  /// The markings alone.
  void renderLines(Canvas canvas) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    // The touchlines and the goal lines, rounded with the grass they are drawn
    // on — see [cornerRadius]. Inset three, so the radius comes in with them.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 3, pitchWidth - 6, pitchHeight - 6),
        const Radius.circular(cornerRadius - 1.5),
      ),
      line..strokeWidth = 0.7,
    );
    canvas.drawLine(
      const Offset(pitchWidth / 2, 3),
      const Offset(pitchWidth / 2, pitchHeight - 3),
      line..strokeWidth = 0.6,
    );
    canvas.drawCircle(const Offset(pitchWidth / 2, pitchHeight / 2), 13, line);
    canvas.drawCircle(
      const Offset(pitchWidth / 2, pitchHeight / 2),
      1,
      Paint()..color = Colors.white.withValues(alpha: 0.32),
    );

    const boxW = 26.0, boxH = 58.0, sixW = 10.0, sixH = 30.0, goalH = 22.0;
    for (final atLeft in [true, false]) {
      final boxX = atLeft ? 3.0 : pitchWidth - 3 - boxW;
      final sixX = atLeft ? 3.0 : pitchWidth - 3 - sixW;
      final goalX = atLeft ? 0.0 : pitchWidth - 3;
      canvas.drawRect(
        Rect.fromLTWH(boxX, (pitchHeight - boxH) / 2, boxW, boxH),
        line..strokeWidth = 0.6,
      );
      canvas.drawRect(
        Rect.fromLTWH(sixX, (pitchHeight - sixH) / 2, sixW, sixH),
        line..strokeWidth = 0.5,
      );
      final mouth = Rect.fromLTWH(goalX, (pitchHeight - goalH) / 2, 3, goalH);
      canvas.drawRect(
        mouth,
        Paint()..color = Colors.white.withValues(alpha: 0.08),
      );
      canvas.drawRect(mouth, line..strokeWidth = 0.7);
    }
  }
}

/// The pace a run needs to arrive with the ball, in `paceScale` units.
///
/// Pure, so the arithmetic can be pinned without a game loop. The margin pays
/// for the steering's own easing: `Mover` slows over the last `arriveRadius`
/// and accelerates into the first stride, so the straight-line average is below
/// the cruise it is set to.
double meetPace({
  required double distance,
  required double seconds,
  required double basePace,
}) {
  if (seconds <= 0 || distance <= 0) return basePace;
  const margin = 1.25;
  const maxPace = 2.6;
  final needed = distance / seconds / MoverTuning.baseSpeed * margin;
  return math.min(maxPace, math.max(basePace, needed));
}

/// A scripted chance, played out.
/// The cast a passage needs: where each attacker starts, and who receives each
/// ball.
///
/// **Pure, and public, because this is where the ball got passed to nobody.**
/// The two halves have to agree — a pass whose receiver has no body still gets
/// a receiver index, and the index lands on whoever happens to be nearest the
/// end of the list, which is very often the man doing the passing. He is then
/// told to run onto his own pass, and the ball arrives on empty grass ahead of
/// him. `tiki_box` was one man passing to himself three times.
typedef AttackCast = ({
  /// Where each attacker starts. Index 0 is the carrier.
  List<AttackPoint> starts,

  /// The receiver's index per beat index. -1 where the beat is not a pass.
  List<int> receiverAt,

  /// Which attacker has the ball at the Finish — the man who shoots.
  ///
  /// **Known before the passage starts, which is the point of it.** The carrier
  /// walks the same chain every run: he begins at 0 and becomes the receiver of
  /// each pass in turn, and both of those come off the script. So the figure
  /// who is going to shoot can be given the scorer's name at kick-off instead
  /// of being handed it at the moment he pulls the trigger. See
  /// [CutawayGame._shoot] for what that fixed.
  int finisher,
});

/// How far back a receiver stands from the ball he is about to be played.
///
/// **He has to run ONTO it**, which is the whole reason the scripts carry a
/// `run` field: a receiver already standing on the spot makes the ball arrive at
/// a statue. This is the fallback for a pass that names no run, and it is back
/// toward our own goal because that is the side a team-mate comes from.
const double _receiverLag = 0.11;

AttackCast castFor(CutawaySequence sequence) {
  final starts = <AttackPoint>[];
  final receiverAt = List<int>.filled(sequence.play.length, -1);

  for (var i = 0; i < sequence.play.length; i++) {
    final beat = sequence.play[i];
    if (beat is Start) {
      starts.add(beat.at);
      continue;
    }
    if (beat is! Pass) continue;
    // A one-two goes back to somebody who already has a body.
    if (beat.who != null) {
      receiverAt[i] = beat.who!;
      continue;
    }
    // **EVERY OTHER PASS GETS ITS OWN BODY.** It used to get one only if the
    // script named a `run`, while still being assigned a receiver — so a bare
    // pass was received by whoever was already nearest the end of the list.
    receiverAt[i] = starts.length;
    starts.add(
      beat.run ?? (p: (beat.to.p - _receiverLag).clamp(0.0, 1.0), q: beat.to.q),
    );
  }

  // A script that is nothing but a carrier still needs somebody to pass to.
  while (starts.length < 2) {
    starts.add((p: 0.5, q: starts.isEmpty ? 0.5 : 0.35));
  }

  // The carrier's chain, walked to the end: he starts on 0 and becomes each
  // pass's receiver in turn. Whoever holds it at the last beat takes the shot.
  var finisher = 0;
  for (var i = 0; i < receiverAt.length; i++) {
    if (receiverAt[i] >= 0) finisher = receiverAt[i];
  }
  return (starts: starts, receiverAt: receiverAt, finisher: finisher);
}

/// **`HasTimeScale` IS WHAT MAKES `2x` MEAN 2x.** The clock's period halved and
/// the pitch did not, so at double speed the passages ran at the same pace
/// against a match going twice as fast — reported as `2x` not speeding the 2D
/// pitch up. The mixin scales `dt` for the whole tree, so a run-up, the shot and
/// the ball's flight all halve together and the passage still fits its minute.
class CutawayGame extends FlameGame with HasTimeScale {
  CutawayGame({
    required this.sequence,
    required this.attackingRight,
    required this.outcome,
    required this.seed,
    this.ours = true,
    this.names = const [],
    this.scorerName,
    this.onDone,
  });

  /// Whether the attacking side is ours — the side that wears the names.
  final bool ours;

  /// Our eleven's names, lineup order, for the figures on our side.
  final List<String> names;

  /// The goalscorer, put on whoever takes the shot when it goes in.
  final String? scorerName;

  final CutawaySequence sequence;

  /// Which way the attacking side is shooting. The whole of the mirroring.
  final bool attackingRight;

  final CutawayOutcome outcome;
  final int seed;
  final void Function(CutawayOutcome outcome)? onDone;

  late final math.Random _rng = math.Random(seed);

  final List<Mover> attackers = [];
  final List<Mover> defenders = [];
  late final Mover keeper;
  late final Ball ball;

  /// Which attacker currently has it.
  int carrier = 0;

  /// A pass that has landed and not yet been collected: who is coming for it.
  int? _loose;

  /// Whether the ball is in the air or rolling from a kick.
  bool get inFlight => _flight != null;

  /// Whether the ball is lying where a pass landed, waiting to be collected.
  bool get isLoose => _loose != null;

  /// How close a receiver has to get to a loose ball to have it.
  static const double _collectRadius = 3.0;

  /// How far through the script we are.
  int beatIndex = 0;

  bool finished = false;

  /// A ball in flight, or null while it is at someone's feet.
  _Flight? _flight;

  Vector2 _at(AttackPoint point) {
    final p = toPitch(point, attackingRight: attackingRight);
    return Vector2(p.x, p.y);
  }

  /// TRANSPARENT, so the markings the stage paints underneath show through.
  ///
  /// Opaque turf here covered them for the frames `onLoad` takes, which is a
  /// flat green flash at the start of every chance — the one thing the stage
  /// exists to avoid, since it is drawing the identical pitch already.
  @override
  Color backgroundColor() => const Color(0x00000000);

  /// The shared cache, so a second chance is not a second decode.
  @override
  Images get images => cutawayImages;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // The whole pitch, always — both goals have to be on screen or a script
    // that finishes at x = 0 finishes off camera.
    camera.viewfinder
      ..visibleGameSize = Vector2(pitchWidth, pitchHeight)
      ..position = Vector2(pitchWidth / 2, pitchHeight / 2)
      ..anchor = Anchor.center;

    world.add(PitchBackdrop());

    // Awaited once, on the first chance of the first match ever watched; from
    // then on every path is already in [cutawayImages] and this returns without
    // touching the disk.
    await preloadCutawaySprites();
    final sprites = <String, Sprite>{
      for (final path in cutawaySpritePaths())
        path: Sprite(cutawayImages.fromCache(path)),
    };

    // Attackers: the carrier plus everyone a beat names a run for. Built from
    // the script so there are exactly as many bodies as the passage uses.
    // The JS's pool: our names, the scorer's held back so no second figure
    // wears it, and a shirt number when the names run out.
    final pool = <String>[
      for (final n in names)
        if (scorerName == null || n != scorerName) shortName(n),
    ];
    String nameOr(String number) =>
        pool.isEmpty ? number : pool.removeAt(0);

    // **THE SCORER WEARS HIS OWN NAME FROM THE FIRST FRAME.** He used to be
    // handed it at the shot — `_shoot` relabelled the carrier and gave his old
    // name to whoever else was wearing the scorer's — so on the one passage a
    // player actually watches, two names on the pitch changed at the instant
    // the ball went in. Reported live and in the replay, which are the same
    // game. `_cast.finisher` is who takes the shot and is known before the
    // passage starts, so nothing has to change hands mid-run.
    final scorerLabel = ours && outcome == CutawayOutcome.goal && scorerName != null
        ? shortName(scorerName!)
        : null;
    final finisher = _cast.finisher;

    // **WE ARE GREEN AND THEY ARE RED, WHICHEVER SIDE HAS THE BALL.** The
    // attackers were always the green shirts and the defenders always the red
    // ones, so an opponent's goal was replayed with THEM in green attacking OUR
    // reds — the colour coding inverted on exactly the passage where it matters
    // most. Reported as "the scoring team is always green regardless of home or
    // away". The kit follows the club, not the direction of play; the idle pitch
    // has always done it this way (`idle_pitch_game.dart`), and the labels here
    // already did — our names, their numbers.
    final attackKit = ours ? 'green' : 'red';
    final defenceKit = ours ? 'red' : 'green';

    final starts = _attackerStarts();
    for (var i = 0; i < starts.length; i++) {
      final number = '${attackerNumbers[i % attackerNumbers.length]}';
      final mover = Mover(
        sprite: sprites['${attackKit}_${(i % 10) + 1}.png']!,
        start: _at(starts[i]),
        paceScale: 0.9 + _rng.nextDouble() * 0.35,
        label: !ours
            ? number
            : (i == finisher ? (scorerLabel ?? nameOr(number)) : nameOr(number)),
      );
      mover.target = mover.position.clone();
      attackers.add(mover);
      world.add(mover);
    }

    for (var i = 0; i < defensiveBlock.length; i++) {
      final number = '${defenderNumbers[i % defenderNumbers.length]}';
      final mover = Mover(
        sprite: sprites['${defenceKit}_${(i % 10) + 1}.png']!,
        start: _at(defensiveBlock[i]),
        paceScale: 0.82 + _rng.nextDouble() * 0.3,
        label: ours ? number : nameOr(number),
      );
      mover.target = mover.position.clone();
      defenders.add(mover);
      world.add(mover);
    }

    keeper = Mover(
      sprite: sprites['white_1.png']!,
      start: _at((p: keeperP, q: 0.5)),
      paceScale: 0.7,
      label: 'GK',
    );
    keeper.target = keeper.position.clone();
    world.add(keeper);

    ball = Ball(
      sprite: sprites['ball.png']!,
      start: attackers.first.position.clone(),
    );
    world.add(ball);

    // **TWENTY-TWO PAIRS OF EYES ON IT.** A figure with nothing to watch faces
    // its run and nothing else, which on a pitch where the ball is the only
    // thing happening reads as a squad of men ignoring the game. Read through
    // a closure rather than handed the vector, so nothing here depends on the
    // ball being built before the players.
    for (final mover in [...attackers, ...defenders, keeper]) {
      mover.watching = () => ball.position;
    }

    _beginBeat();
  }

  /// Where each attacker starts, and who receives each ball.
  late final AttackCast _cast = castFor(sequence);

  List<AttackPoint> _attackerStarts() => _cast.starts;

  void _beginBeat() {
    if (finished || beatIndex >= sequence.play.length) return;
    final beat = sequence.play[beatIndex];

    switch (beat) {
      case Start():
        // Already placed at load; nothing to do but move on.
        beatIndex++;
        _beginBeat();

      case Pass():
        final receiver = _cast.receiverAt[beatIndex];
        final style = passStyles[beat.kind] ?? passStyles['pass']!;
        final to = _at(beat.to);
        final flight = _Flight(
          from: ball.position.clone(),
          to: to,
          style: style,
          bendSide: _rng.nextBool() ? 1 : -1,
          // **THE BALL WAITS TO BE COLLECTED.** It used to change hands the
          // instant it landed, and the next frame drew it at the receiver's
          // feet wherever he had got to — a ball that moved with nobody
          // kicking it. It lies where it landed until he reaches it.
          onArrive: () => _loose = receiver,
        );
        // The receiver runs to MEET it, at the pace that gets him there —
        // which is the half that was missing. See [Mover.sprintTo].
        attackers[receiver].sprintTo(to, flight.duration);
        _flight = flight;

      case Dribble():
        // Carried: the ball is off the tween and knocked along ahead of the
        // carrier's feet by `update`.
        _flight = null;
        attackers[carrier].target = _at(beat.to);

      case Finish():
        _shoot(beat);
    }
  }

  void _shoot(Finish beat) {
    // **NOTHING IS RENAMED HERE, and that is the fix.** The JS forces the
    // scorer's real name onto the shooter's dot at this moment, and the port
    // copied it: the carrier took the scorer's name and handed his own to
    // whoever had been wearing it, so two labels on the pitch changed on the
    // frame the shot was struck. The scorer is labelled at kick-off now — see
    // `_cast.finisher` in [onLoad].
    final style = finishStyles[beat.style] ?? finishStyles['placed']!;
    // Where the ball ends up is the OUTCOME's business, not the script's — the
    // same passage has to be able to end in the net, in the keeper's hands or
    // in the stand.
    final goalMouth = _at((p: 1.04, q: 0.5));
    final target = switch (outcome) {
      CutawayOutcome.goal =>
        goalMouth + Vector2(0, (_rng.nextDouble() - 0.5) * 14),
      CutawayOutcome.saved => keeper.position.clone(),
      CutawayOutcome.post =>
        goalMouth + Vector2(0, _rng.nextBool() ? -11.5 : 11.5),
      CutawayOutcome.over => goalMouth + Vector2(0, -pitchHeight * 0.45),
      CutawayOutcome.wide => goalMouth + Vector2(0, _rng.nextBool() ? -22 : 22),
      CutawayOutcome.tackled => attackers[carrier].position.clone(),
    };

    if (style.keeperRush || style.round) {
      // He comes to narrow the angle. The striker going round him is the same
      // rush answered differently.
      keeper.target = attackers[carrier].position.clone();
    }

    // How hard it was hit, which is the whole of what a keeper can do about it —
    // see [_rebound].
    _shotSpeed = style.speed;
    _flight = _Flight(
      from: ball.position.clone(),
      to: target,
      style: (
        speed: style.speed,
        // A header leaves the ground; everything else is struck along it.
        air: beat.style == 'header' ? 0.4 : 0.0,
        // A free kick has to bend, or it goes through the wall it was given
        // for. **AN ORDINARY SHOT DOES NOT** — see the note on `_Flight`.
        bend: _freeKickTaken ? 0.22 : 0,
      ),
      isShot: true,
      bendSide: _rng.nextBool() ? 1 : -1,
      onArrive: _finish,
    );
    // Struck. The boot is on the ball THIS frame, which is the frame the kick
    // has to be heard on.
    struck.value++;
  }

  /// Scythed down. The passage becomes a free kick from wherever it happened.
  ///
  /// A free-kick script ENDS on the foul — there is no `Finish` beat after it —
  /// so without this the four of them ran out of instructions and the clip hung
  /// on a full-looking pitch until the match ended. A test walks every sequence
  /// to the end for exactly that reason.
  void _awardFreeKick() {
    if (_freeKickTaken) return;
    _freeKickTaken = true;

    final spot = attackers[carrier].position.clone();
    ball.position.setFrom(spot);
    ball.loft = 0;

    // **THE TAKER STANDS OVER IT**, and this is the last place the ball moved
    // with nobody at it. He was never told to stop: his target was still the
    // spot the DRIBBLE beat gave him, so for the beat of stillness the wall
    // needs he walked on past the ball — measured at 5.2 units, which is a
    // figure's own width — and then it flew off the empty grass behind him.
    // Watched from the couch that is "the ball still sometimes moving with no
    // player near them".
    //
    // **A target is not enough, because a `Mover` COASTS.** Arriving damps the
    // velocity at 6 per second rather than dropping it, so a man told to stand
    // where he already is still slides several units past it. `frozen` is what
    // the wall beside him uses and it is the same instruction: he has just been
    // scythed down, and stopping dead is what that looks like.
    attackers[carrier]
      ..target = spot
      ..frozen = true;

    // The wall: four defenders between the ball and the goal, ten yards off it,
    // and they stop thinking — a wall that kept tracking the ball would jog
    // out of the way of the shot it exists to block.
    final goalMouth = _at((p: 1.04, q: 0.5));
    final toGoal = (goalMouth - spot)..normalize();
    final across = Vector2(-toGoal.y, toGoal.x);
    for (var i = 0; i < defenders.length - 1; i++) {
      final offset = (i - (defenders.length - 2) / 2) * 3.4;
      defenders[i]
        ..position.setFrom(spot + toGoal * 18 + across * offset)
        ..target = defenders[i].position.clone()
        ..frozen = true;
    }
    // The last man stays alive as a runner in the box.
    defenders.last.target = goalMouth - toGoal * 12;

    // A beat of stillness before it is struck, so the wall is seen to form —
    // and the word is up for all of it. Longer than the 0.9 it was: a beat
    // nobody has time to look at the spot in is not a beat.
    _freeKickDelay = freeKickWait;
    foul.value = true;
  }

  bool _freeKickTaken = false;
  double _freeKickDelay = 0;

  /// How long the ball is spotted before it is struck, and how long the word is
  /// up for.
  static const double freeKickWait = 1.4;

  /// Whether the ball is spotted for a free kick and not yet struck.
  bool get freeKickPending => _freeKickDelay > 0;

  /// Bumped the instant the ball is STRUCK — see [_shoot].
  ///
  /// **THE SOUND AND THE PICTURE WERE ON DIFFERENT CLOCKS.** The match screen
  /// played the shot and the crowd off the MINUTE tick, and a passage runs a
  /// second or two of run-ups and passes before anybody shoots. So the net
  /// bulged in silence and the goal sound had already gone off while the ball
  /// was still in midfield — reported as the sounds and the action not syncing
  /// up at all.
  ///
  /// A counter rather than a flag: a notifier only fires on a CHANGE, and the
  /// question is "has it happened", which a bool that is already true cannot
  /// answer twice. Paired with [verdict], the two beats a shot has — struck, and
  /// arrived — are both watchable from outside the game.
  final ValueNotifier<int> struck = ValueNotifier(0);

  /// Whether a foul has just been given and the kick not yet taken.
  ///
  /// **A FREE KICK ARRIVED WITH NOTHING TO SAY IT WAS ONE.** The ball stopped
  /// dead in midfield, four defenders lined up, and a second later it flew:
  /// from the couch that reads as the ball doing something odd rather than as a
  /// man being fouled. The word goes up for the wait the wall needs, which is
  /// also the beat that shows WHERE it happened. Watched by the stage, like
  /// [verdict], because a headline wants the app's own type.
  final ValueNotifier<bool> foul = ValueNotifier(false);

  /// The verdict, once the ball has arrived. Watched by the stage, which draws
  /// the banner in Flutter rather than in Flame — a headline wants the app's own
  /// type, and Flame's text renderer has none of it.
  ///
  /// Always AFTER [struck]: `_finish` is only ever reached by the shot flight's
  /// `onArrive`, so a clip cannot deliver a verdict it never shot for.
  final ValueNotifier<CutawayOutcome?> verdict = ValueNotifier(null);

  /// How much of the OUTRO is left.
  ///
  /// **THE CLIP DOES NOT END WHEN THE BALL ARRIVES.** It did, and that is why a
  /// goal snapped back to an empty pitch the instant the ball hit the net — the
  /// one moment in a match worth watching, cut on the frame it happened. A goal
  /// gets long enough for the scorer to reach the corner flag with two of them
  /// chasing; everything else gets a beat to read the word.
  double _outro = 0;

  static const double _goalOutro = 2.6;
  static const double _missOutro = 1.0;

  /// How hard the shot was struck, from [finishStyles].
  double _shotSpeed = 150;

  /// Whether the ball has already come back off the frame or off a glove.
  ///
  /// The rebound's own arrival lands here again, so this is what stops it
  /// bouncing for ever.
  bool _rebounded = false;

  /// Below this, in the finish styles' own units, the gloves KEEP it.
  ///
  /// The two soft finishes — a header at 100 and a rounded finish at 120 — are
  /// gathered; a placed shot at 150, a volley at 175 and a long shot at 200 are
  /// pushed away. That is the same split `penalty_physics.dart` makes at
  /// `_holdSpeed`, for the same reason: what a keeper can do with a shot is
  /// decided by how hard it arrives.
  static const double _gloveHold = 140;

  /// What the ball does after it has been stopped, or null when it stops dead.
  ///
  /// **A SHOT DOES NOT END ON THE WOODWORK OR IN HIS HANDS.** Both outcomes
  /// froze every figure on the pitch with the ball parked on the point it
  /// arrived at, so the one thing a player is watching stopped mid-air on the
  /// frame it got interesting — reported from the couch as wanting the ball to
  /// come off the post and wanting a save to be a catch or a parry.
  _Flight? _rebound() {
    final goalMouth = _at((p: 1.04, q: 0.5));
    // Back up the pitch, away from the goal it was struck at.
    final back = attackingRight ? -1.0 : 1.0;
    final from = ball.position.clone();

    Vector2 onPitch(Vector2 v) => Vector2(
      v.x.clamp(2.0, pitchWidth - 2),
      v.y.clamp(2.0, pitchHeight - 2),
    );

    switch (outcome) {
      case CutawayOutcome.post:
        // Off the upright and back across the face. It carries most of its pace
        // — woodwork gives nothing back and takes little away — and it comes
        // out on the side it struck, which is what makes the post look like a
        // post rather than a wall.
        final side = from.y < goalMouth.y ? -1.0 : 1.0;
        return _Flight(
          from: from,
          to: onPitch(from + Vector2(back * 26, side * 9)),
          style: (speed: _shotSpeed * 0.62, air: 0.18, bend: 0),
          onArrive: _finish,
        );
      case CutawayOutcome.saved:
        // **CAUGHT, and there is nothing to draw.** He has it; the ball sits in
        // his gloves and the whistle-to-nothing that follows is the clip
        // stopping, which is what it already did.
        if (_shotSpeed < _gloveHold) return null;
        // Parried: away from his own goal and out toward the touchline, because
        // a keeper who cannot hold one pushes it where nobody is.
        final side = keeper.position.y < pitchHeight / 2 ? -1.0 : 1.0;
        return _Flight(
          from: from,
          to: onPitch(from + Vector2(back * 11, side * 24)),
          style: (speed: _shotSpeed * 0.34, air: 0.3, bend: 0),
          onArrive: _finish,
        );
      case CutawayOutcome.goal:
      case CutawayOutcome.wide:
      case CutawayOutcome.over:
      case CutawayOutcome.tackled:
        return null;
    }
  }

  void _finish() {
    _flight = null;
    verdict.value = outcome;

    if (outcome == CutawayOutcome.goal) {
      _celebrate();
      _outro = _goalOutro;
      return;
    }

    // The ball comes off the frame, or off a glove — see [_rebound]. The
    // verdict is already up, because what the ball does afterwards does not
    // change what happened; nobody is frozen yet, so the defence plays it out.
    if (!_rebounded) {
      final rebound = _rebound();
      if (rebound != null) {
        _rebounded = true;
        // He has got a hand to it and that is the end of his part in it.
        keeper.frozen = true;
        _flight = rebound;
        return;
      }
    }

    for (final m in [...attackers, ...defenders, keeper]) {
      m.frozen = true;
    }
    _outro = _missOutro;
  }

  /// The corner run.
  ///
  /// The JS sends the scorer to the flag and it is the right instinct: a goal has
  /// an AFTER, and the after is what makes it feel like one. The nearest corner
  /// on the attacking side, so he runs away from the goal he just scored in
  /// rather than back up the pitch — and two of the nearest teammates chase him
  /// rather than all of them, because a whole team arriving at once reads as a
  /// crowd rather than as a celebration.
  void _celebrate() {
    final scorer = attackers[carrier];
    final cornerX = attackingRight ? pitchWidth - 4.0 : 4.0;
    // Whichever corner he finished nearer, so he does not cross the goalmouth.
    final cornerY = scorer.position.y < pitchHeight / 2 ? 4.0 : pitchHeight - 4;
    final flag = Vector2(cornerX, cornerY);
    scorer
      ..target = flag
      ..celebrating = true;

    final chasers =
        [
          for (final m in attackers)
            if (m != scorer) m,
        ]..sort(
          (a, b) => a.position
              .distanceTo(scorer.position)
              .compareTo(b.position.distanceTo(scorer.position)),
        );
    for (var i = 0; i < chasers.length; i++) {
      if (i < 2) {
        // Behind him and fanned out, so three bodies arriving at one flag do
        // not stack into one.
        chasers[i]
          ..target = flag + Vector2(i == 0 ? -6 : -3, i == 0 ? 5 : -5)
          ..celebrating = true;
      } else {
        chasers[i].frozen = true;
      }
    }
    // Nobody in red goes anywhere. A defence that kept tracking through a
    // celebration is the one thing that would make it read as still in play.
    for (final m in [...defenders, keeper]) {
      m.frozen = true;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // The outro: the ball has arrived, the word is up, and the celebration is
    // running. `finished` is not set until it is over, so nothing else starts.
    if (_outro > 0) {
      _outro -= dt;
      if (_outro <= 0) {
        finished = true;
        for (final m in [...attackers, ...defenders, keeper]) {
          m.frozen = true;
        }
        onDone?.call(outcome);
      }
      return;
    }
    if (finished) return;

    if (_freeKickDelay > 0) {
      _freeKickDelay -= dt;
      if (_freeKickDelay <= 0) {
        // On his feet the instant he has struck it: the plant is for the WAIT,
        // and a scorer who cannot run is a celebration that does not happen.
        attackers[carrier].frozen = false;
        foul.value = false;
        // Curled, and harder than open play — that is what a free kick is.
        _shoot(const Finish('longshot'));
      }
      return;
    }

    final flight = _flight;
    if (flight != null) {
      flight.advance(dt);
      ball.position.setFrom(flight.position);
      ball.loft = flight.height;
      if (flight.done) {
        _flight = null;
        flight.onArrive();
      }
    } else if (beatIndex < sequence.play.length) {
      final loose = _loose;
      if (loose != null) {
        if (attackers[loose].position.distanceTo(ball.position) >
            _collectRadius) {
          _thinkDefenders(dt);
          return;
        }
        _loose = null;
        carrier = loose;
        beatIndex++;
        _beginBeat();
        if (_flight != null) {
          _thinkDefenders(dt);
          return;
        }
      }
      // At the carrier's feet, a step ahead of them — dribbling. Eased rather
      // than pinned: pinned, a turn swung the ball round him in one frame,
      // which is the same fault as the snap above.
      final me = attackers[carrier];
      final ahead = Vector2(math.cos(me.heading), math.sin(me.heading))
        ..scale(3.2);
      final want = me.position + ahead;
      ball.position.add((want - ball.position)..scale(math.min(1, 14 * dt)));
      ball.loft = 0;

      final beat = sequence.play[beatIndex];
      if (beat is Dribble &&
          me.position.distanceTo(_at(beat.to)) <
              MoverTuning.arriveRadius * 0.7) {
        if (beat.fouled) {
          _awardFreeKick();
        } else {
          beatIndex++;
          _beginBeat();
        }
      }
    }

    _thinkDefenders(dt);
  }

  /// The back four, the screen and the keeper.
  ///
  /// The line DROPS as the ball advances and shifts toward the ball's side
  /// without collapsing onto it — a flat line that ignored the ball would let
  /// every through ball walk in, and one that chased it would leave the pitch
  /// empty. The nearest defender presses the carrier; the keeper mirrors the
  /// ball along his line.
  void _thinkDefenders(double dt) {
    final ballAt = ball.position;
    // How far up the pitch the ball is, in the DEFENDERS' terms.
    final along = attackingRight
        ? ballAt.x / pitchWidth
        : 1 - ballAt.x / pitchWidth;

    var nearest = 0;
    var nearestDistance = double.infinity;
    for (var i = 0; i < defenders.length; i++) {
      final d = defenders[i].position.distanceTo(ballAt);
      if (d < nearestDistance) {
        nearestDistance = d;
        nearest = i;
      }
    }

    for (var i = 0; i < defenders.length; i++) {
      if (i == nearest && along > 0.35) {
        // Press the ball, but goal-side of it rather than through it.
        final goalward = attackingRight ? 3.5 : -3.5;
        defenders[i].target = Vector2(ballAt.x + goalward, ballAt.y);
        continue;
      }
      final lane = defensiveLanes[i];
      // The line sits just behind the ball and squeezes toward its side.
      final lineP = (along + 0.16).clamp(0.30, 0.99);
      final squeezed = lane + (ballAt.y / pitchHeight - lane) * 0.28;
      defenders[i].target = _at((p: lineP, q: squeezed));
    }

    // The keeper mirrors the ball along his line, damped so he is not glued
    // to it, unless a finish has already sent him out to narrow the angle.
    if (!finished && _flight?.isShot != true) {
      final line = _at((p: keeperP, q: 0.5));
      keeper.target = Vector2(
        line.x,
        line.y + (ballAt.y - pitchHeight / 2) * 0.42,
      );
    }
  }
}

/// A ball in flight along an eased, gently curved path.
class _Flight {
  _Flight({
    required this.from,
    required this.to,
    required this.style,
    required this.onArrive,
    this.isShot = false,
    this.bendSide = 1,
  }) : _duration = math.max(
         0.18,
         from.distanceTo(to) / math.max(1, style.speed),
       ) {
    // The bend is perpendicular to the flight, scaled by its length — a long
    // switch swerves, a three-yard square ball does not.
    //
    // **THE SIDE HAS TO VARY, and it did not.** `Vector2(-delta.y, delta.x)` is
    // always the same perpendicular, so every ball in every clip curved the same
    // way — which does not read as a struck ball, it reads as the ball drifting
    // for no reason with nobody near it. Randomised per flight now, and the
    // styles that had no business bending at all have had it taken off them: a
    // square pass along the ground goes straight.
    final delta = to - from;
    final length = delta.length;
    _control = Vector2(-delta.y, delta.x)
      ..normalize()
      ..scale(length * style.bend * bendSide);
  }

  final Vector2 from;
  final Vector2 to;
  final PassStyle style;

  /// How long the ball is in the air, which is the receiver's budget.
  double get duration => _duration;
  final void Function() onArrive;
  final bool isShot;

  /// Which way it curves, +1 or -1.
  final int bendSide;

  final double _duration;
  late final Vector2 _control;
  double _elapsed = 0;

  final Vector2 position = Vector2.zero();
  double height = 0;

  bool get done => _elapsed >= _duration;

  void advance(double dt) {
    _elapsed = math.min(_duration, _elapsed + dt);
    final raw = _duration <= 0 ? 1.0 : _elapsed / _duration;
    // Lofted balls travel at a constant rate; ground passes decelerate.
    final t = style.air > 0 ? _linear(raw) : _easeOut(raw);

    // Quadratic bezier through the offset control point.
    final oneMinus = 1 - t;
    final mid = (from + to)..scale(0.5);
    final control = mid + _control;
    position.setValues(
      oneMinus * oneMinus * from.x +
          2 * oneMinus * t * control.x +
          t * t * to.x,
      oneMinus * oneMinus * from.y +
          2 * oneMinus * t * control.y +
          t * t * to.y,
    );
    // A parabola over the flight, so it lands as it started.
    height = style.air * math.sin(t * math.pi);
  }
}
