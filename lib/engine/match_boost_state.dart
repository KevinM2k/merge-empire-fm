/// The boost windows live during ONE match: what is on, until when, and what it
/// contributes to the numbers the remainder is rolled with.
///
/// Screen-owned for the length of the match and never saved. A boost is
/// debited from the inventory the moment it is tapped, so a match abandoned
/// mid-window has spent it — which is honest, and is the same rule the trait
/// reel plays by: pay before the animation, never after.
///
/// **Windows stack and overlap.** Two Crowd Roars multiply, under a cap, so
/// the strip cannot be emptied into one unbeatable ten minutes; two buses do
/// not make the game twice as dead, because the damping is a floor rather than
/// a product. The two axes never touch each other.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

/// What one Crowd Roar is worth — ten per cent on the whole side, the same
/// unit a caution takes off one man.
const double crowdRoarMult = 1.10;

/// The most stacked Roars may reach. Two are 1.21; a third is where it stops.
const double maxCrowdRoarStack = 1.25;

/// **The two windows are RATING lifts, on the board.** Both began as goal-rate
/// multipliers — a dead game for the Bus, a loaded coin for Sharp Shooting —
/// and neither could be seen doing anything; the numbers at the top of the
/// match never moved. Asked for from the couch, twice. Bigger than the
/// Roar's ten per cent since each buys one stat.
///
/// Everyone behind the ball: BOTH sides' ATK down, ours and theirs — a
/// dead game, on the board's two attack figures.
const double parkTheBusAttack = 0.75;

/// OUR attack under Sharp Shooting; defence and the other side untouched.
const double sharpShootingAttack = 1.25;

/// One live window. `toMinute` is exclusive: a 25-minute window tapped at 40
/// pays through 64 and is gone at 65, which is the minute the re-sim fires.
class LiveBoost {
  const LiveBoost({
    required this.id,
    required this.fromMinute,
    required this.toMinute,
  });

  final String id;
  final int fromMinute;
  final int toMinute;

  bool coversMinute(int minute) => minute >= fromMinute && minute < toMinute;
}

class MatchBoostState {
  final List<LiveBoost> _live = [];

  /// Every window not yet expired, in the order they were started.
  List<LiveBoost> get live => List.unmodifiable(_live);

  /// Open a window. A zero-length window — a retrospective boost — is nothing
  /// to track: its effect is applied once by the screen and has no "until".
  void start(String id, int minute, int windowMinutes) {
    if (windowMinutes <= 0) return;
    _live.add(
      LiveBoost(id: id, fromMinute: minute, toMinute: minute + windowMinutes),
    );
  }

  /// Drop every window that has closed by [minute] and return them, so the
  /// screen can post each one's `.over` line. Each window is reported once.
  List<LiveBoost> expireThrough(int minute) {
    final closed = [
      for (final b in _live)
        if (b.toMinute <= minute) b,
    ];
    _live.removeWhere((b) => b.toMinute <= minute);
    return closed;
  }

  /// What is live at [minute], for the bar's bands.
  List<LiveBoost> activeAt(int minute) => [
    for (final b in _live)
      if (b.coversMinute(minute)) b,
  ];

  /// The latest minute any window of [id] runs to, or null when none is live.
  int? endOf(String id) {
    int? end;
    for (final b in _live) {
      if (b.id != id) continue;
      if (end == null || b.toMinute > end) end = b.toMinute;
    }
    return end;
  }

  /// The squad-wide rating multiplier at [minute]: stacked Roars, capped.
  double ratingMultAt(int minute) {
    var mult = 1.0;
    for (final b in activeAt(minute)) {
      if (b.id == 'crowd_roar') mult *= crowdRoarMult;
    }
    return math.min(maxCrowdRoarStack, mult);
  }

  /// Our ATK at [minute]: Sharp Shooting up, a Bus down, both if both. A
  /// second window of the same boost does not stack — it is a state, not a
  /// product.
  double ourAttackMultAt(int minute) {
    final live = activeAt(minute);
    var mult = 1.0;
    if (live.any((b) => b.id == 'sharp_shooting')) mult *= sharpShootingAttack;
    if (live.any((b) => b.id == 'park_the_bus')) mult *= parkTheBusAttack;
    return mult;
  }

  /// THEIR ATK at [minute]: a Bus, or nothing.
  double oppAttackMultAt(int minute) =>
      activeAt(minute).any((b) => b.id == 'park_the_bus')
          ? parkTheBusAttack
          : 1.0;
}
