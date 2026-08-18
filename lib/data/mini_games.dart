/// Mini-game constants and difficulty curves, ported from
/// `../merge-empire-fc/src/data/miniGames.js`.
///
/// Seven games, one shape: a cooldown, a coin multiplier applied to the
/// division's mini-game base, and a difficulty curve interpolated across the
/// seven divisions from `divIdx` 0 (Sunday League) to 6 (Champions Cup). The
/// curves live here rather than in the engine because the launcher tiles read
/// them to describe a game before it is played.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

/// Where a division sits on the 0-to-1 difficulty ramp.
double _t(int divIdx) => math.max(0, math.min(6, divIdx)) / 6;

/// Penalty Training — the arcade shootout, never a cup-tie shootout.
class Penalty {
  const Penalty._();

  static const int cooldownMs = 5 * 60 * 1000;
  static const int attempts = 5;

  /// Coins per scored penalty, times the division's mini-game base.
  static const double rewardPerGoalMult = 0.25;

  /// The keeper's "smart dive" chance: the odds on each shot that they read the
  /// player's corner and save it outright, rather than diving at random. Runs
  /// from 5% at Sunday League to 30% at Champions Cup — which is why the quest
  /// bank counts penalties SCORED and not perfect rounds.
  static const double keeperSmartBase = 0.05;
  static const double keeperSmartMax = 0.30;
}

/// The keeper's chance of reading the shot, by division index.
double penaltyKeeperSmartChance(int divIdx) =>
    Penalty.keeperSmartBase +
    (Penalty.keeperSmartMax - Penalty.keeperSmartBase) * _t(divIdx);

/// Goalkeeper Practice — a timed run of tap-the-drill.
class Training {
  const Training._();

  static const int cooldownMs = 15 * 60 * 1000;

  /// A tight, punchy session rather than a long one.
  static const int durationMs = 16 * 1000;

  /// A brief "warming up" beat before the first drill.
  static const int leadInMs = 600;
  static const double rewardBaseMult = 3.5;

  static const int drillsBase = 4;
  static const int drillsMax = 12;

  /// The tap window was 950ms down to 320ms, which players reported as drills
  /// vanishing before they could reach them. These give real reaction time low
  /// down and something still quick, but reachable, at the top.
  static const int drillWindowBaseMs = 1700;
  static const int drillWindowMinMs = 700;

  /// No per-session energy. The only energy this game pays is the 3-day streak
  /// milestone.
  static const int energyGrant = 0;
}

typedef TrainingDifficulty = ({int drills, int windowMs});

TrainingDifficulty trainingDifficulty([int divIdx = 0]) {
  final t = _t(divIdx);
  return (
    drills:
        (Training.drillsBase + (Training.drillsMax - Training.drillsBase) * t)
            .round(),
    windowMs:
        (Training.drillWindowBaseMs +
                (Training.drillWindowMinMs - Training.drillWindowBaseMs) * t)
            .round(),
  );
}

/// Through Ball — a marker sweeps a bar, tap it inside the green zone.
///
/// Difficulty is fixed per SESSION by the player's division rather than
/// ramping round by round: at Sunday League the zone is wide and the sweep
/// slow, at Champions Cup it is tight and quick.
class ThroughBall {
  const ThroughBall._();

  static const int cooldownMs = 10 * 60 * 1000;
  static const int rounds = 5;
  static const double rewardPerRoundMult = 0.30;

  /// Green-zone width, as a percentage of the bar.
  static const double zoneEasyPct = 36;
  static const double zoneHardPct = 12;

  /// One full sweep of the bar.
  static const double sweepEasyMs = 1800;
  static const double sweepHardMs = 700;

  /// The zone is placed randomly within this band, so the player cannot tap
  /// rhythmically without watching.
  static const double zonePosMinPct = 18;
  static const double zonePosMaxPct = 82;
}

typedef ThroughBallDifficulty = ({double zonePct, double sweepMs});

ThroughBallDifficulty throughBallDifficulty([int divIdx = 0]) {
  final t = _t(divIdx);
  return (
    zonePct:
        ThroughBall.zoneEasyPct +
        (ThroughBall.zoneHardPct - ThroughBall.zoneEasyPct) * t,
    sweepMs:
        ThroughBall.sweepEasyMs +
        (ThroughBall.sweepHardMs - ThroughBall.sweepEasyMs) * t,
  );
}

/// Keepy Uppys — tap the ball up. It starts as a balloon and gets heavier every
/// few taps: balloon, football, bowling ball.
class KeepyUppys {
  const KeepyUppys._();

  static const int cooldownMs = 10 * 60 * 1000;
  static const double rewardPerTapMult = 0.06;
}

/// Pairs — memory match. Difficulty means more pairs and a shorter peek, and
/// nothing else: it is meant to stay casual.
class Pairs {
  const Pairs._();

  static const int cooldownMs = 8 * 60 * 1000;

  /// Fixed. This one does not scale.
  static const int lives = 5;

  static const double rewardPerPairMult = 0.45;

  /// Applied to the whole payout when the board is cleared.
  static const double clearBonusMult = 1.5;

  static const int pairsBase = 4;
  static const int pairsMax = 6;

  /// The look at the board before the cards turn over. Long enough for a read,
  /// short enough that memory still does the work.
  static const int peekBaseMs = 2500;
  static const int peekMinMs = 1800;

  /// How long a mismatched pair stays face-up before flipping back.
  static const int mismatchHideMs = 900;
}

typedef PairsDifficulty = ({int pairs, int peekMs});

PairsDifficulty pairsDifficulty([int divIdx = 0]) {
  final t = _t(divIdx);
  return (
    pairs: (Pairs.pairsBase + (Pairs.pairsMax - Pairs.pairsBase) * t).round(),
    peekMs: (Pairs.peekBaseMs + (Pairs.peekMinMs - Pairs.peekBaseMs) * t)
        .round(),
  );
}

/// Pitch Invaders — whack-a-mole through nine gaps in the hoardings.
///
/// Invaders are worth one, the dog on the pitch three, and a steward is the one
/// thing not to tap. The session is a fixed length of wall clock, so difficulty
/// is entirely a question of how fast things move.
class Whack {
  const Whack._();

  static const int cooldownMs = 7 * 60 * 1000;
  static const int holes = 9; // 3x3
  static const int durationMs = 22 * 1000;

  /// A "here they come" beat before the first pop-up.
  static const int leadInMs = 800;

  static const double rewardPerCatchMult = 0.12;
  static const int dogValue = 3;

  /// Tapping a steward burns a catch.
  static const int foulCost = 1;

  /// Gap between pop-ups: a gentle trickle at Sunday League, busy at Champions.
  static const int spawnBaseMs = 900;
  static const int spawnMinMs = 420;

  /// How long one stays up before ducking back down.
  static const int upBaseMs = 1400;
  static const int upMinMs = 720;

  /// Share of pop-ups that are stewards, which get commoner as you climb, and
  /// dogs, which stay a treat at every level.
  static const double stewardBasePct = 0.12;
  static const double stewardMaxPct = 0.30;
  static const double dogPct = 0.08;
}

typedef WhackDifficulty = ({
  int spawnMs,
  int upMs,
  double stewardPct,
  double dogPct,
});

WhackDifficulty whackDifficulty([int divIdx = 0]) {
  final t = _t(divIdx);
  return (
    spawnMs: (Whack.spawnBaseMs + (Whack.spawnMinMs - Whack.spawnBaseMs) * t)
        .round(),
    upMs: (Whack.upBaseMs + (Whack.upMinMs - Whack.upBaseMs) * t).round(),
    stewardPct:
        Whack.stewardBasePct + (Whack.stewardMaxPct - Whack.stewardBasePct) * t,
    dogPct: Whack.dogPct,
  );
}

/// A rough ceiling for the launcher tile's "up to" hint: every non-steward
/// pop-up caught, dogs paying triple. Nobody reaches it — it assumes a perfect
/// session, which is exactly what "up to" means.
int whackMaxCatches([int divIdx = 0]) {
  final d = whackDifficulty(divIdx);
  final popUps = (Whack.durationMs / d.spawnMs).floor();
  final dogs = popUps * d.dogPct;
  final invaders = popUps * (1 - d.stewardPct - d.dogPct);
  return math.max(1, (invaders + dogs * Whack.dogValue).round());
}

/// Boot Room — match-3 on the kit shelf.
///
/// Coins are per TILE cleared, so a cascade pays for itself and there is no
/// separate combo currency to explain. A swap that matches nothing snaps back
/// and costs no move.
class BootRoom {
  const BootRoom._();

  static const int cooldownMs = 12 * 60 * 1000;
  static const int cols = 6;
  static const int rows = 6;

  static const double rewardPerTileMult = 0.030;

  /// Applied to the whole payout when the tile target is met.
  static const double targetBonusMult = 1.4;

  /// Moves per session, falling as you climb — the board also gains a sixth kit
  /// type up there, so runs are rarer and each move has to count.
  static const int movesBase = 14;
  static const int movesMin = 10;

  /// FIVE types is the floor, not four. On a 6x6 board four types cascades out
  /// of control: simulated sessions averaged 107 tiles cleared with
  /// eighteen-deep chains, paying six times what Goalkeeper Practice pays for a
  /// game that plays itself. Five is where a chain still feels earned.
  static const int typesBase = 5;
  static const int typesMax = 6;

  /// Expected tiles cleared PER MOVE, which is what the target is built from.
  /// Measured over 400 simulated sessions per division at each setting, taking
  /// the midpoint between a player picking legal moves at random and one always
  /// picking the best available — roughly where a competent casual player
  /// lands. The sixth kit type is the big step: it cuts the yield by a third,
  /// which is why the target cannot just ramp with division.
  static const double yieldPerMove5 = 6.3;
  static const double yieldPerMove6 = 4.8;
}

typedef BootRoomDifficulty = ({int moves, int types, int target});

/// The target FALLS as you climb, which is not a mistake: the BOARD is what
/// gets harder (fewer moves, one more kit type), so the same tile count would
/// go from a stretch to an impossibility. Deriving the ask from the move count
/// and the measured yield keeps it at roughly the same difficulty everywhere,
/// and means it cannot drift if the move curve is ever retuned.
BootRoomDifficulty bootRoomDifficulty([int divIdx = 0]) {
  final t = _t(divIdx);
  final moves =
      (BootRoom.movesBase + (BootRoom.movesMin - BootRoom.movesBase) * t)
          .round();
  final types =
      (BootRoom.typesBase + (BootRoom.typesMax - BootRoom.typesBase) * t)
          .round();
  final yieldPerMove = types >= 6
      ? BootRoom.yieldPerMove6
      : BootRoom.yieldPerMove5;
  return (moves: moves, types: types, target: (moves * yieldPerMove).round());
}
