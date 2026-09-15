/// The boost windows live during ONE match: what is on, until when, and what it
/// contributes to the numbers the remainder is rolled with.
///
/// Screen-owned for the length of the match and never saved. A boost is
/// debited from the inventory the moment it is tapped, so a match abandoned
/// mid-window has spent it — which is honest, and is the same rule the trait
/// reel plays by: pay before the animation, never after.
///
/// **DIFFERENT boosts overlap; the SAME one restarts.** A Roar and a Sharp
/// Shooting run together and lift two different axes, which is what makes the
/// strip worth having more than one of. Tapping a boost that is already live
/// spends another and sends its own window back to full from that minute — it
/// does not pile a second copy on the first, so the strip cannot be emptied
/// into one unbeatable ten minutes. See [MatchBoostState.start].
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

/// What one Crowd Roar is worth — ten per cent on the whole side, the same
/// unit a caution takes off one man.
const double crowdRoarMult = 1.10;

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
  ///
  /// **A BOOST ALREADY RUNNING IS RESTARTED, not stacked on.** Tapping a live
  /// Roar spends a second one and sends its window back to full from this
  /// minute — asked for from the couch in those terms: "if they tap it again
  /// and it's only 70% down, it just goes up to 100% again, not stacked."
  ///
  /// **Only against ITSELF.** Different boosts are different windows and still
  /// run together — a Roar and a Sharp Shooting are two lifts on two axes, and
  /// dropping one because the other started would be a different rule entirely.
  void start(String id, int minute, int windowMinutes) {
    if (windowMinutes <= 0) return;
    _live.removeWhere((b) => b.id == id);
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

  /// The squad-wide rating multiplier at [minute]: a Roar, or nothing.
  ///
  /// **No cap any more, because nothing can stack into one.** It used to
  /// multiply a Roar per live window under a 1.25 ceiling; [start] now keeps
  /// one window per boost, so the loop could only ever reach 1.10 and the
  /// ceiling was a number that could not be touched.
  double ratingMultAt(int minute) =>
      activeAt(minute).any((b) => b.id == 'crowd_roar') ? crowdRoarMult : 1.0;

  /// Our ATK at [minute]: Sharp Shooting up, a Bus down, both if both — two
  /// boosts, so two lifts. A second window of the SAME one cannot arise; see
  /// [start].
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
