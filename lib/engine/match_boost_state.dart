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

/// The goal rate for BOTH sides under a Bus. Under half, so a parked side is
/// visibly a different match rather than a slightly quieter one.
const double parkTheBusGoalRate = 0.45;

/// OUR attack under Sharp Shooting; defence and the other side untouched.
/// A rating lift rather than a goal-rate one, because a goal rate is a
/// loaded coin nobody can see — the ATK figure on the board has to jump.
/// Bigger than the Roar's ten per cent since it buys one stat only.
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

  /// The goal-rate damping at [minute]: a Bus, or nothing. A floor, not a
  /// product — see the header.
  double goalRateMultAt(int minute) =>
      activeAt(minute).any((b) => b.id == 'park_the_bus')
          ? parkTheBusGoalRate
          : 1.0;

  /// Our ATK alone: Sharp Shooting, or nothing.
  double ourAttackMultAt(int minute) =>
      activeAt(minute).any((b) => b.id == 'sharp_shooting')
          ? sharpShootingAttack
          : 1.0;
}
