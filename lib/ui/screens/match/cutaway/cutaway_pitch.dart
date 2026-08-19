/// The cutaway's pitch, and the space its scripts are written in. Ported from
/// the geometry half of `ui/components/ChanceCutaway.js`.
///
/// **Scripts are written in ATTACK SPACE, not in pitch coordinates.** A beat
/// says "p 0.90, q 0.44" — nine tenths of the way to the goal being attacked,
/// slightly left of centre — and [toPitch] turns that into a point on the
/// 200×120 pitch depending on which way this team is shooting. One table of
/// sequences therefore serves all four combinations of home/away and
/// ours/theirs, instead of four mirrored copies that would drift apart.
///
/// Deliberately Flutter-free: this is arithmetic, and the architecture test
/// keeps the engines and the data honest about that. The Flame layer converts
/// these into screen pixels.
library;

/// The pitch, in the units every script and every speed is quoted in.
const double pitchWidth = 200;
const double pitchHeight = 120;
const double pitchAspect = pitchWidth / pitchHeight;

/// A point in attack space.
///
/// [p] runs from the attacking side's own goal (0) to the goal they are
/// attacking (1.05 is the goal line itself). The 18-yard line sits near 0.90,
/// the penalty spot near 0.95 and the six-yard box near 0.99.
///
/// [q] is lateral: 0 is the top touchline, 1 the bottom, 0.5 the centre.
typedef AttackPoint = ({double p, double q});

/// A point on the pitch, in the 200×120 space.
typedef PitchPoint = ({double x, double y});

/// Where the keeper stands. The goal line is at p ≈ 1.05, so this is a yard or
/// so off it.
const double keeperP = 1.02;

/// Convert attack space to the pitch.
///
/// [attackingRight] is the whole of the mirroring: a team shooting left has its
/// p axis reversed and its q axis flipped with it, so a script's "inside-right
/// channel" stays the same side of the attacking player's view either way.
PitchPoint toPitch(AttackPoint at, {required bool attackingRight}) {
  // The goal mouths sit at x = 0 and x = 200, and p = 1.05 is the goal line —
  // so the usable range maps p∈[0, 1.05] onto the full width.
  const span = 1.05;
  final along = (at.p / span).clamp(-0.2, 1.2);
  return (
    x: attackingRight ? along * pitchWidth : (1 - along) * pitchWidth,
    y: attackingRight ? at.q * pitchHeight : (1 - at.q) * pitchHeight,
  );
}

/// The defensive block's starting shape, in attack space — high p is near the
/// goal being defended.
///
/// A back four and one screening midfielder, and no more: live positioning is
/// driven by lanes and a moving line, and every extra body turned the box into
/// a scrum nobody could read on a phone.
const List<AttackPoint> defensiveBlock = [
  (p: 0.78, q: 0.16),
  (p: 0.80, q: 0.38),
  (p: 0.80, q: 0.62),
  (p: 0.78, q: 0.84),
  (p: 0.62, q: 0.50), // the screen in front of them
];

/// The lane each defender is responsible for. The last is the screening mid.
const List<double> defensiveLanes = [0.16, 0.38, 0.62, 0.84, 0.50];

/// Squad numbers, so the side without names is still eleven individuals.
const List<int> defenderNumbers = [2, 5, 6, 3, 4];
const List<int> attackerNumbers = [9, 10, 11, 7, 8, 17, 20, 14];

/// How a mover behaves, in pitch units per second.
class MoverTuning {
  const MoverTuning._();

  /// Inside this radius a mover eases into its target rather than arriving at
  /// full pace, which is what stops players snapping to a stop.
  static const double arriveRadius = 5;

  /// Velocity smoothing per second. Low enough that players visibly accelerate
  /// and drift rather than changing direction instantly.
  static const double accel = 7;

  /// Cruise speed for a move with no time budget of its own.
  static const double baseSpeed = 34;
}

/// How a pass of each kind travels.
///
/// [air] is the lofted amplitude — how far the ball scales up and its shadow
/// drops at the top of the flight, which is the only way height reads on a flat
/// top-down pitch. Without it a cross and a square ball look identical, and a
/// header has nothing to be a header off.
typedef PassStyle = ({double speed, double air, double bend});

const Map<String, PassStyle> passStyles = {
  'pass': (speed: 105, air: 0, bend: 0.06),
  'through': (speed: 125, air: 0, bend: 0.03),
  'lofted': (speed: 64, air: 1.0, bend: 0.10),
  'cross': (speed: 82, air: 0.75, bend: 0.14),
  'cutback': (speed: 135, air: 0, bend: 0.02),
};

/// How a shot of each kind is struck.
///
/// [instant] is a ball struck the moment it arrives — a header or a volley,
/// with no settling touch. [round] takes it past the onrushing keeper first.
typedef FinishStyle = ({
  double speed,
  bool instant,
  bool round,
  bool keeperRush,
});

const Map<String, FinishStyle> finishStyles = {
  'placed': (speed: 150, instant: false, round: false, keeperRush: false),
  'oneonone': (speed: 130, instant: false, round: false, keeperRush: true),
  'rounded': (speed: 120, instant: false, round: true, keeperRush: false),
  'longshot': (speed: 200, instant: false, round: false, keeperRush: false),
  'header': (speed: 100, instant: true, round: false, keeperRush: false),
  'volley': (speed: 175, instant: true, round: false, keeperRush: false),
};

/// How often a plain one-on-one becomes the striker going round the keeper
/// rather than shooting early, so the same script does not always look the same.
const double roundKeeperChance = 0.38;
