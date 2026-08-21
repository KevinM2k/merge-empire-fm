/// Keepy Uppys' physics.
///
/// Pure, `dart:math` only, and no Flutter — the ball is the whole game and it
/// is all arithmetic, so it is pinned frame by frame against a node dump of the
/// JS's own loop (`tool/dump_keepy_uppys_reference.mjs`).
///
/// Three balls, not one. It starts as a balloon that barely falls and hardens
/// every so many taps: balloon → football → cannonball, each with its own
/// gravity, reach, kick and wall damping. Survive all three and the whole
/// payout doubles.
///
/// **The reward is WEIGHTED, not counted.** A tap on the cannonball is worth
/// two and a half times a tap on the balloon, so the score the engine banks is
/// the weighted sum rather than `taps` — which is why the tally is kept per
/// stage instead of as one number.
library;

import 'dart:math' as math;

/// One stage of ball.
class KeepyStage {
  const KeepyStage({
    required this.minTaps,
    required this.emoji,
    required this.size,
    required this.labelKey,
    required this.gravity,
    required this.hitRadius,
    required this.bouncePower,
    required this.wallDamping,
    required this.rewardMult,
  });

  final int minTaps;

  /// Null for the cannonball, which is drawn rather than typed.
  final String? emoji;
  final double size;
  final String labelKey;

  /// Pixels per frame at 60fps; the loop scales by `dt` to stay frame-rate
  /// independent.
  final double gravity;
  final double hitRadius;
  final double bouncePower;
  final double wallDamping;
  final double rewardMult;
}

const List<KeepyStage> keepyStages = [
  KeepyStage(
    minTaps: 0,
    emoji: '🎈',
    size: 52,
    labelKey: 'game.keepy.balloon',
    gravity: 0.025,
    hitRadius: 44,
    bouncePower: 3.8,
    wallDamping: 0.45,
    rewardMult: 1.0,
  ),
  KeepyStage(
    minTaps: 10,
    emoji: '⚽',
    size: 44,
    labelKey: 'game.keepy.football',
    gravity: 0.13,
    hitRadius: 34,
    bouncePower: 7.5,
    wallDamping: 0.62,
    rewardMult: 1.5,
  ),
  KeepyStage(
    minTaps: 25, // 10 balloon + 15 football
    emoji: null,
    size: 40,
    labelKey: 'game.keepy.cannonball',
    gravity: 0.42,
    hitRadius: 26,
    bouncePower: 11.5,
    wallDamping: 0.68,
    rewardMult: 2.5,
  ),
];

/// Survive all three stages — 10 balloon + 15 football + 20 cannonball.
const int keepyBonusTarget = 45;

/// The whole payout, doubled, on a full run.
const double keepyBonusMult = 2.0;

/// Which ball [taps] taps in.
KeepyStage stageFor(int taps) {
  for (var i = keepyStages.length - 1; i >= 0; i--) {
    if (taps >= keepyStages[i].minTaps) return keepyStages[i];
  }
  return keepyStages.first;
}

int stageIndexFor(int taps) => keepyStages.indexOf(stageFor(taps));

/// The ball, and the run it is having.
class KeepyUppysSim {
  KeepyUppysSim({
    required this.arenaW,
    required this.arenaH,
    required double Function() random,
  }) : _random = random {
    x = arenaW / 2;
    y = arenaH * 0.28;
    // The one draw the physics takes. It is first, and it is the only one —
    // an extra draw anywhere shifts every later number.
    vx = (_random() - 0.5) * 0.6;
    vy = -0.2;
  }

  final double arenaW, arenaH;
  final double Function() _random;

  late double x, y, vx, vy;
  double angle = 0;
  int taps = 0;
  final List<int> tapsByStage = [0, 0, 0];
  bool bonus = false;
  bool missed = false;

  KeepyStage get stage => stageFor(taps);

  /// One frame. [dt] is 1.0 at 60fps.
  ///
  /// Returns false once the ball is out at the bottom, which ends the session.
  bool step(double dt) {
    if (missed || bonus) return false;
    final s = stage;
    vy += s.gravity * dt;
    x += vx * dt;
    y += vy * dt;

    // The collision radius is deliberately smaller than the hit radius: the
    // ball may touch the walls at its own edge, but the player is allowed to
    // reach for it well outside that.
    final r = s.size * 0.42;

    if (x - r < 0) {
      x = r;
      vx = vx.abs() * s.wallDamping;
    }
    if (x + r > arenaW) {
      x = arenaW - r;
      vx = -vx.abs() * s.wallDamping;
    }
    if (y - r < 0) {
      y = r;
      vy = vy.abs() * s.wallDamping;
    }
    // The floor is the end. It is checked against the ball's TOP edge, not its
    // centre, so it is gone rather than merely low.
    if (y - r > arenaH) {
      missed = true;
      return false;
    }

    // The balloon drifts; anything heavier spins with its own sideways speed.
    if (s.emoji != '🎈') angle += vx * 2.5 * dt;
    return true;
  }

  /// A tap at [tapX], [tapY] in arena coordinates. True if it connected.
  bool tap(double tapX, double tapY) {
    if (missed || bonus) return false;
    final s = stage;
    final dx = x - tapX;
    final dy = y - tapY;
    if (math.sqrt(dx * dx + dy * dy) > s.hitRadius) return false;

    vy = -s.bouncePower;
    // WHERE on the ball it was hit is the whole control scheme: catch it on
    // the left and it goes right. Capped, or a glancing tap fires it sideways
    // faster than the player can follow.
    vx = math.max(-4, math.min(4, dx * 0.12));

    tapsByStage[stageIndexFor(taps)]++;
    taps++;
    if (taps >= keepyBonusTarget) bonus = true;
    return true;
  }

  /// The score the engine banks: each tap worth its own stage's multiplier.
  int get weightedTaps {
    var sum = 0.0;
    for (var i = 0; i < keepyStages.length; i++) {
      sum += tapsByStage[i] * keepyStages[i].rewardMult;
    }
    return sum.round();
  }

  /// What [weightedTaps] becomes once the full-run bonus is applied.
  int get bankedTaps =>
      bonus ? (weightedTaps * keepyBonusMult).round() : weightedTaps;
}
