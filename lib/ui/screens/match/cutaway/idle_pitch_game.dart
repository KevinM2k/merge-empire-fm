/// The match, between the chances.
///
/// **The pitch stopped being a picture of a pitch and became a picture of
/// nothing.** `CutawayStage` has drawn the markings the whole time and the
/// twenty-two bodies only ever existed for the two or three seconds of a
/// scripted chance — so ninety minutes of football was a green rectangle with an
/// arrow on it, and a clip arrived out of an empty field. Reported three times
/// across three sittings.
///
/// **It is not a second simulation.** The result is decided before a ball moves
/// and `CutawayGame` is the thing that retells a chance; this is the OTHER
/// state of the same stage — two sides holding a shape, the shape sliding with
/// the momentum the arrow is already reading, and the ball going about between
/// them. Nothing here decides anything, which is exactly why it can run for the
/// whole match.
///
/// **Driven off the same figure as the arrow**, so the two can never disagree:
/// the side with the run of play pushes up and the other drops off, which is
/// what a phone-sized pitch can show about pressure.
library;

import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/cache.dart' show Images;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_game.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_pitch.dart';

/// How far up the pitch a side's line slides between pinned back and camped in.
const double idleLineTravel = 0.17;

/// How often the shape is re-drawn around a new ball position, in seconds.
///
/// Slow: this is possession being kept, not a highlight. A shape that resets
/// every second reads as a scramble.
const double idleBeatSeconds = 2.6;

/// Where a side stands when it is holding its shape.
///
/// Eight outfield lanes and two banks, in the same `(p, q)` space the scripted
/// sequences use — so a body drifting here and a body in a clip are on the same
/// pitch and the handover costs nothing.
const List<AttackPoint> idleShape = [
  (p: 0.16, q: 0.50),
  (p: 0.32, q: 0.16),
  (p: 0.32, q: 0.38),
  (p: 0.32, q: 0.62),
  (p: 0.32, q: 0.84),
  (p: 0.50, q: 0.26),
  (p: 0.50, q: 0.50),
  (p: 0.50, q: 0.74),
  (p: 0.66, q: 0.34),
  (p: 0.66, q: 0.66),
  (p: 0.78, q: 0.50),
];

/// One side's line, pushed by [bias] and jittered so eleven men are not a comb.
///
/// [bias] is −1 (pinned in our own half) to 1 (camped in theirs). Pure, so the
/// shape can be pinned without a game loop.
AttackPoint idleSpotFor(
  AttackPoint base, {
  required double bias,
  required double wobble,
}) {
  final p = (base.p + bias.clamp(-1.0, 1.0) * idleLineTravel + wobble * 0.03)
      .clamp(0.04, 0.94);
  final q = (base.q + wobble * 0.05).clamp(0.06, 0.94);
  return (p: p, q: q);
}

/// Two sides holding a shape, and a ball between them.
/// The twenty-two run at the match's own speed too — see [CutawayGame].
class IdlePitchGame extends FlameGame with HasTimeScale {
  IdlePitchGame({required this.attackingRight, required this.momentum});

  /// Which way WE are kicking, so the same `(p, q)` reads for both venues.
  final bool attackingRight;

  /// −1 to 1, ours-positive. The arrow's own figure — see `momentumBias`.
  final ValueNotifier<double> momentum;

  final List<Mover> ours = [];
  final List<Mover> theirs = [];
  late final Ball ball;

  final math.Random _rng = math.Random(7);
  double _since = idleBeatSeconds;
  int _carrier = 0;
  bool _oursHaveIt = true;

  Vector2 _at(AttackPoint point) {
    final p = toPitch(point, attackingRight: attackingRight);
    return Vector2(p.x, p.y);
  }

  /// Transparent, so the markings the stage paints underneath show through.
  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Images get images => cutawayImages;

  @override
  Future<void> onLoad() async {
    camera.viewfinder
      ..visibleGameSize = Vector2(pitchWidth, pitchHeight)
      ..position = Vector2(pitchWidth / 2, pitchHeight / 2)
      ..anchor = Anchor.center;

    await preloadCutawaySprites();
    final sprites = <String, Sprite>{
      for (final path in cutawaySpritePaths())
        path: Sprite(cutawayImages.fromCache(path)),
    };

    for (var i = 0; i < idleShape.length; i++) {
      final us = Mover(
        sprite: sprites['green_${(i % 10) + 1}.png']!,
        start: _at(idleShape[i]),
        paceScale: 0.55 + _rng.nextDouble() * 0.2,
      );
      // Mirrored: their shape is ours seen from the other end.
      final them = Mover(
        sprite: sprites['red_${(i % 10) + 1}.png']!,
        start: _at((p: 1 - idleShape[i].p, q: 1 - idleShape[i].q)),
        paceScale: 0.55 + _rng.nextDouble() * 0.2,
      );
      us.target = us.position.clone();
      them.target = them.position.clone();
      ours.add(us);
      theirs.add(them);
      world
        ..add(us)
        ..add(them);
    }

    ball = Ball(
      sprite: sprites['ball.png']!,
      start: _at((p: 0.5, q: 0.5)),
    );
    world.add(ball);
    // Watching it, the same as in a chance — see [Mover.watching]. It is the
    // whole difference between a squad milling about and a squad in a match.
    for (final mover in [...ours, ...theirs]) {
      mover.watching = () => ball.position;
    }
    _reshape();
  }

  /// A new resting shape, and somebody else on the ball.
  void _reshape() {
    final bias = momentum.value.clamp(-1.0, 1.0);
    for (var i = 0; i < ours.length; i++) {
      ours[i].target = _at(
        idleSpotFor(
          idleShape[i],
          bias: bias,
          wobble: _rng.nextDouble() * 2 - 1,
        ),
      );
      final mirrored = (p: 1 - idleShape[i].p, q: 1 - idleShape[i].q);
      theirs[i].target = _at(
        idleSpotFor(
          mirrored,
          bias: -bias,
          wobble: _rng.nextDouble() * 2 - 1,
        ),
      );
    }
    // **Who has it follows the momentum**, but not slavishly: a side with the
    // run of play keeps the ball most of the time and not all of it, which is
    // the same shape the chance split takes.
    _oursHaveIt = _rng.nextDouble() < 0.5 + bias * 0.35;
    final side = _oursHaveIt ? ours : theirs;
    _carrier = _rng.nextInt(side.length);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _since += dt;
    if (_since >= idleBeatSeconds) {
      _since = 0;
      _reshape();
    }
    // The ball travels to whoever has it rather than being pinned to their
    // feet: a ball that teleports between players is the one thing on this
    // pitch that would read as broken.
    final side = _oursHaveIt ? ours : theirs;
    if (side.isEmpty) return;
    final feet = side[_carrier.clamp(0, side.length - 1)].position;
    final toFeet = feet - ball.position;
    final distance = toFeet.length;
    if (distance > 0.01) {
      final step = math.min(distance, 26 * dt);
      ball.position.add(toFeet.normalized()..scale(step));
    }
  }
}
