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
library;

import 'dart:math' as math;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_pitch.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_sequences.dart';

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

/// Kenney's white smoke puff, eight frames.
///
/// Its own cache because it is its own directory — the pitch sprites are under
/// `assets/pitch/` and a `flame` `Images` carries one prefix.
final Images fxImages = Images(prefix: 'assets/fx/');

List<String> puffPaths() => [for (var i = 0; i < 8; i++) 'puff_$i.png'];

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
  await fxImages.loadAll(puffPaths());
}

/// A puff of smoke where something happened.
///
/// **Kenney's frames rather than a procedural burst**, and the split is worth
/// keeping straight: the merge burst stays procedural because it has to draw in
/// whatever colour the tier is at whatever size the card is, which a sprite sheet
/// cannot do. This is the other case — a fixed white puff at a fixed size, where
/// eight hand-painted frames beat anything drawn from primitives and the whole
/// eight cost 140KB.
class Puff extends SpriteAnimationComponent {
  Puff({required Vector2 at, required double diameter, double speed = 0.055})
    : super(
        position: at.clone(),
        size: Vector2.all(diameter),
        anchor: Anchor.center,
        removeOnFinish: true,
        priority: 50,
        animation: SpriteAnimation.spriteList(
          [for (final path in puffPaths()) Sprite(fxImages.fromCache(path))],
          stepTime: speed,
          loop: false,
        ),
      );
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
  final double paceScale;

  /// A surname or a shirt number. Null draws nothing.
  final String? label;

  Vector2 target = Vector2.zero();
  final Vector2 _velocity = Vector2.zero();

  /// Which way the figure is facing, in radians. Sprites are drawn facing up,
  /// so a heading of zero points along -Y.
  double heading = 0;

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
    }

    final step = _velocity * dt;
    position.add(step);
    // One stride per ~4.2 units covered.
    _stride = (_stride + step.length / 4.2) % 1;
    if (_velocity.length2 > 1) {
      // atan2(x, -y): the sprite's "up" is -Y, so a heading of zero is north.
      heading = math.atan2(_velocity.x, -_velocity.y);
    }
  }

  @override
  void render(Canvas canvas) {
    final rock = math.sin(_stride * 2 * math.pi);
    // Two strides per bob: the body rises on each footfall, not on each pair.
    final bob = math.sin(_stride * 4 * math.pi);
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
        ..color = Colors.black.withValues(alpha: 0.28 * (1 - height * 0.4)),
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

  @override
  void render(Canvas canvas) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, pitchWidth, pitchHeight),
      Paint()..color = turf,
    );
    // Mown stripes. Ten bands, every other one lifted.
    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.035);
    for (var i = 0; i < 10; i += 2) {
      canvas.drawRect(Rect.fromLTWH(i * 20, 0, 20, pitchHeight), stripe);
    }

    canvas.drawRect(
      const Rect.fromLTWH(3, 3, pitchWidth - 6, pitchHeight - 6),
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

/// A scripted chance, played out.
class CutawayGame extends FlameGame {
  CutawayGame({
    required this.sequence,
    required this.attackingRight,
    required this.outcome,
    required this.seed,
    this.onDone,
  });

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
    final starts = _attackerStarts();
    for (var i = 0; i < starts.length; i++) {
      final mover = Mover(
        sprite: sprites['green_${(i % 10) + 1}.png']!,
        start: _at(starts[i]),
        paceScale: 0.9 + _rng.nextDouble() * 0.35,
      );
      mover.target = mover.position.clone();
      attackers.add(mover);
      world.add(mover);
    }

    for (var i = 0; i < defensiveBlock.length; i++) {
      final mover = Mover(
        sprite: sprites['red_${(i % 10) + 1}.png']!,
        start: _at(defensiveBlock[i]),
        paceScale: 0.82 + _rng.nextDouble() * 0.3,
      );
      mover.target = mover.position.clone();
      defenders.add(mover);
      world.add(mover);
    }

    keeper = Mover(
      sprite: sprites['white_1.png']!,
      start: _at((p: keeperP, q: 0.5)),
      paceScale: 0.7,
    );
    keeper.target = keeper.position.clone();
    world.add(keeper);

    ball = Ball(
      sprite: sprites['ball.png']!,
      start: attackers.first.position.clone(),
    );
    world.add(ball);

    _beginBeat();
  }

  /// Where each attacker starts.
  ///
  /// The first is the carrier's opening spot; the rest come from the `run`
  /// fields, which is what makes a receiver's run into the ball visible instead
  /// of the ball arriving at somebody already standing there.
  List<AttackPoint> _attackerStarts() {
    final out = <AttackPoint>[];
    for (final beat in sequence.play) {
      if (beat is Start) out.add(beat.at);
      if (beat is Pass && beat.run != null && beat.who == null) {
        out.add(beat.run!);
      }
    }
    // A script that never names a run still needs somebody to pass to.
    while (out.length < 2) {
      out.add((p: 0.5, q: out.isEmpty ? 0.5 : 0.35));
    }
    return out;
  }

  /// Whoever receives the next ball.
  int _receiverFor(Pass beat, int nextFreeAttacker) =>
      beat.who ?? math.min(nextFreeAttacker, attackers.length - 1);

  int _nextAttacker = 1;

  void _beginBeat() {
    if (finished || beatIndex >= sequence.play.length) return;
    final beat = sequence.play[beatIndex];

    switch (beat) {
      case Start():
        // Already placed at load; nothing to do but move on.
        beatIndex++;
        _beginBeat();

      case Pass():
        final receiver = _receiverFor(beat, _nextAttacker);
        if (beat.who == null && _nextAttacker < attackers.length - 1) {
          _nextAttacker++;
        }
        final style = passStyles[beat.kind] ?? passStyles['pass']!;
        final to = _at(beat.to);
        // The receiver runs to MEET it, so the two arrive together.
        attackers[receiver].target = to.clone();
        _flight = _Flight(
          from: ball.position.clone(),
          to: to,
          style: style,
          bendSide: _rng.nextBool() ? 1 : -1,
          onArrive: () {
            carrier = receiver;
            beatIndex++;
            _beginBeat();
          },
        );

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

    // The strike itself. Small and quick — it is the puff off the turf as the
    // boot goes through the ball, not an explosion.
    world.add(Puff(at: ball.position.clone(), diameter: 7, speed: 0.04));

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

    // A beat of stillness before it is struck, so the wall is seen to form.
    _freeKickDelay = 0.9;
  }

  bool _freeKickTaken = false;
  double _freeKickDelay = 0;

  /// The verdict, once the ball has arrived. Watched by the stage, which draws
  /// the banner in Flutter rather than in Flame — a headline wants the app's own
  /// type, and Flame's text renderer has none of it.
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

  void _finish() {
    _flight = null;
    verdict.value = outcome;

    if (outcome == CutawayOutcome.goal) {
      _celebrate();
      _outro = _goalOutro;
      return;
    }

    // A puff where it ended — the keeper's gloves, or the turf past the post.
    world.add(Puff(at: ball.position.clone(), diameter: 11));
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
    // Two puffs at the net: the ball hitting it, then the net settling.
    world.add(Puff(at: ball.position.clone(), diameter: 14));

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
      // At the carrier's feet, a step ahead of them — dribbling.
      final me = attackers[carrier];
      final ahead = Vector2(math.sin(me.heading), -math.cos(me.heading))
        ..scale(3.2);
      ball.position.setFrom(me.position + ahead);
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
