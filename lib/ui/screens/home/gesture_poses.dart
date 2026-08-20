/// The sixteen touchline gestures, as poses on the rig. Ported from the
/// `.is-gest-*` blocks and their keyframes in
/// `../merge-empire-fc/src/ui/styles/league-scene.css`.
///
/// **`manager_mood.dart` has carried all of this data since M1 and nothing ever
/// played it.** Sixteen gestures, their weights per mood, the gap between them,
/// `pickGesture` with its exclude-list, the `stops` and `fullTime` flags — all
/// ported, all tested, and the manager just walked. What was missing is the
/// poses, the scheduler and the tap. This file is the poses.
///
/// **A joint a gesture does not mention KEEPS WALKING.** That is not a
/// simplification, it is the CSS's semantics: `animation` on `.psv-armN`
/// replaces the walk cycle for that element and leaves every sibling alone. A
/// fist pump is one arm; the other arm swings on. So every track here is
/// nullable and null means "the walk still owns this joint" — which is why the
/// figure does not go rigid for two seconds every time he applauds.
///
/// Angles are the rig's own: degrees, clockwise, and he faces +x, so a positive
/// head rotation drops his chin toward his chest. The rest pose is the one the
/// walk cycle passes through — near arm 27, far arm -27, both forearms -52.
///
/// Deliberately Flutter-free apart from [Curve]: these are keyframes, and a
/// keyframe is arithmetic.
library;

import 'package:flutter/animation.dart';

/// One track: the angle at each point through the gesture, 0 to 1.
typedef GestureTrack = List<(double at, double deg)>;

/// Where every joint is at one instant. Null is "not this gesture's business".
typedef GesturePose = ({
  double? armNear,
  double? armFar,
  double? foreNear,
  double? foreFar,

  /// Chin toward the chest, about the base of the neck.
  double? head,

  /// The whole figure folding, about the HIP rather than the boots.
  double? body,

  /// Art units. The robot's hard-stepped rise.
  double? bodyLift,

  /// The legs counter-rotating a body fold, so they stay under him.
  double? legs,
});

const GesturePose _rest = (
  armNear: null,
  armFar: null,
  foreNear: null,
  foreFar: null,
  head: null,
  body: null,
  bodyLift: null,
  legs: null,
);

/// One gesture's tracks, and how its time is read.
class GestureAnimation {
  const GestureAnimation({
    this.armNear,
    this.armFar,
    this.foreNear,
    this.foreFar,
    this.head,
    this.body,
    this.bodyLift,
    this.legs,
    this.curve = Curves.easeInOut,
    this.cycleMs,
  });

  final GestureTrack? armNear;
  final GestureTrack? armFar;
  final GestureTrack? foreNear;
  final GestureTrack? foreFar;
  final GestureTrack? head;
  final GestureTrack? body;
  final GestureTrack? bodyLift;
  final GestureTrack? legs;

  /// Eased per SEGMENT, the way CSS eases a keyframe track — not once across the
  /// whole run.
  final Curve curve;

  /// When the tracks run on their own clock rather than the gesture's. Only the
  /// robot does: 1.4s a cycle, repeating inside a 2.4s gesture, so the second
  /// cycle is cut off partway — which is what the stylesheet actually says, and
  /// what makes him stop mid-move rather than settle.
  final int? cycleMs;
}

/// The rest angles a track returns to. Stated here rather than left implicit in
/// sixteen tracks: they are the walk cycle's own mid-swing values, and the
/// gestures were all drawn against them.
const double armNearRest = 27;
const double armFarRest = -27;
const double foreRest = -52;

/// `0%, 100%` at rest with a hold in the middle — by far the commonest shape
/// here, so it is written once.
GestureTrack _hold(double rest, double held, double from, double to) => [
  (0, rest),
  (from, held),
  (to, held),
  (1, rest),
];

final Map<String, GestureAnimation> _animations = {
  // ── FIST PUMP. Three pumps, and the only gesture whose track does not return
  // to rest in the middle: it is a repeated motion, not a pose held.
  'fistpump': const GestureAnimation(
    armNear: [
      (0, armNearRest),
      (0.16, -78),
      (0.34, -58),
      (0.50, -80),
      (0.66, -60),
      (0.82, -76),
      (1, armNearRest),
    ],
    foreNear: [
      (0, foreRest),
      (0.16, -116),
      (0.34, -86),
      (0.50, -118),
      (0.66, -88),
      (0.82, -114),
      (1, foreRest),
    ],
  ),
  // ── APPLAUD. Both hands, because one hand clapping is a wave.
  'applaud': const GestureAnimation(
    armNear: [
      (0, armNearRest),
      (0.18, -4),
      (0.30, -16),
      (0.42, -4),
      (0.54, -16),
      (0.66, -4),
      (0.78, -16),
      (0.88, -4),
      (1, armNearRest),
    ],
    armFar: [
      (0, armFarRest),
      (0.18, -4),
      (0.30, 8),
      (0.42, -4),
      (0.54, 8),
      (0.66, -4),
      (0.78, 8),
      (0.88, -4),
      (1, armFarRest),
    ],
    foreNear: [
      (0, foreRest),
      (0.18, -108),
      (0.30, -96),
      (0.42, -108),
      (0.54, -96),
      (0.66, -108),
      (0.78, -96),
      (0.88, -108),
      (1, foreRest),
    ],
    foreFar: [
      (0, foreRest),
      (0.18, -108),
      (0.30, -96),
      (0.42, -108),
      (0.54, -96),
      (0.66, -108),
      (0.78, -96),
      (0.88, -108),
      (1, foreRest),
    ],
  ),
  'point': GestureAnimation(
    armNear: _hold(armNearRest, -52, 0.20, 0.80),
    foreNear: _hold(foreRest, -56, 0.20, 0.80),
  ),
  // ── CHECK WATCH. He looks at the wrist he is reading, which is the whole
  // difference between checking the time and holding an arm up.
  'checkwatch': GestureAnimation(
    armNear: _hold(armNearRest, -40, 0.22, 0.78),
    foreNear: _hold(foreRest, -85, 0.22, 0.78),
    head: _hold(0, 15, 0.22, 0.78),
  ),
  'armsfolded': GestureAnimation(
    armNear: _hold(armNearRest, 30, 0.14, 0.86),
    foreNear: _hold(foreRest, -115, 0.14, 0.86),
    armFar: _hold(armFarRest, 23, 0.14, 0.86),
    foreFar: _hold(foreRest, -141, 0.14, 0.86),
  ),
  'handsonhead': GestureAnimation(
    head: _hold(0, 20, 0.20, 0.80),
    armNear: _hold(armNearRest, -78, 0.20, 0.80),
    armFar: _hold(armFarRest, -78, 0.20, 0.80),
    foreNear: _hold(foreRest, -113, 0.20, 0.80),
    foreFar: _hold(foreRest, -113, 0.20, 0.80),
  ),
  'handsonhips': GestureAnimation(
    armNear: _hold(armNearRest, 44, 0.14, 0.86),
    foreNear: _hold(foreRest, -106, 0.14, 0.86),
    armFar: _hold(armFarRest, 38, 0.14, 0.86),
    foreFar: _hold(foreRest, -101, 0.14, 0.86),
  ),
  // ── WAVE. The arm goes UP and stays; the wave is in the forearm.
  'wave': const GestureAnimation(
    armNear: [(0, armNearRest), (0.16, -150), (0.84, -150), (1, armNearRest)],
    foreNear: [
      (0, foreRest),
      (0.16, -22),
      (0.34, -2),
      (0.50, -22),
      (0.66, -2),
      (0.84, -22),
      (1, foreRest),
    ],
  ),
  'blowkiss': const GestureAnimation(
    armNear: [
      (0, armNearRest),
      (0.22, -58),
      (0.40, -58),
      (0.62, -80),
      (0.82, -80),
      (1, armNearRest),
    ],
    foreNear: [
      (0, foreRest),
      (0.22, -119),
      (0.40, -119),
      (0.62, -37),
      (0.82, -37),
      (1, foreRest),
    ],
  ),
  'badgekiss': const GestureAnimation(
    armNear: [
      (0, armNearRest),
      (0.20, -30),
      (0.48, -52),
      (0.80, -30),
      (1, armNearRest),
    ],
    foreNear: [
      (0, foreRest),
      (0.20, -118),
      (0.48, -146),
      (0.80, -118),
      (1, foreRest),
    ],
  ),
  'shush': GestureAnimation(
    armNear: _hold(armNearRest, -38, 0.14, 0.86),
    foreNear: _hold(foreRest, -127, 0.14, 0.86),
  ),
  // ── SALUTE. Snapped up rather than eased: the curve is the gesture.
  'salute': GestureAnimation(
    armNear: _hold(armNearRest, -117, 0.12, 0.82),
    foreNear: _hold(foreRest, -88, 0.12, 0.82),
    curve: const Cubic(0.2, 0.9, 0.3, 1),
  ),
  // ── BOW. The body folds about the HIP and the legs cancel it, so he bends
  // rather than toppling. The head leads the fold, which is what sells it.
  //
  // **His arms just HANG.** An earlier cut swept the near arm across the waist,
  // which on top of a body fold is two gestures at once — and the arm was the
  // one you noticed. (The stylesheet still carries `psvGestBowArm` and
  // `psvGestBowFore` keyframes with nothing bound to them; they are that cut.)
  'bow': GestureAnimation(
    body: _hold(0, 16, 0.26, 0.74),
    legs: _hold(0, -16, 0.26, 0.74),
    head: _hold(0, 11, 0.26, 0.74),
    armNear: _hold(armNearRest, 0, 0.10, 0.90),
    armFar: _hold(armFarRest, 0, 0.10, 0.90),
  ),
  // ── ROBOT. **`steps()` is the whole joke**: every other gesture on this rig
  // eases, so hard-stepped joints read as mechanical instantly. Each track sits
  // on its value and jumps to the next, which is what a linear curve between two
  // identical keyframes gives for free.
  'robot': const GestureAnimation(
    curve: Curves.linear,
    cycleMs: 1400,
    armNear: [
      (0, armNearRest),
      (0.15, armNearRest),
      (0.25, -96),
      (0.40, -96),
      (0.50, -142),
      (0.65, -142),
      (0.75, -70),
      (0.90, -70),
      (1, armNearRest),
    ],
    armFar: [
      (0, armFarRest),
      (0.15, armFarRest),
      (0.25, -70),
      (0.40, -70),
      (0.50, -34),
      (0.65, -34),
      (0.75, -110),
      (0.90, -110),
      (1, armFarRest),
    ],
    foreNear: [
      (0, foreRest),
      (0.08, -96),
      (0.15, -96),
      (0.25, -4),
      (0.40, -4),
      (0.50, -88),
      (0.65, -88),
      (0.75, -20),
      (0.90, -20),
      (1, foreRest),
    ],
    foreFar: [
      (0, foreRest),
      (0.08, -4),
      (0.15, -4),
      (0.25, -88),
      (0.40, -88),
      (0.50, -20),
      (0.65, -20),
      (0.75, -96),
      (0.90, -96),
      (1, foreRest),
    ],
    body: [
      (0, 0),
      (0.15, 0),
      (0.25, 2.5),
      (0.40, 2.5),
      (0.50, 0),
      (0.65, 0),
      (0.75, -2.5),
      (0.90, -2.5),
      (1, 0),
    ],
    bodyLift: [
      (0, 0),
      (0.15, 0),
      (0.25, -2),
      (0.40, -2),
      (0.50, 0),
      (0.65, 0),
      (0.75, -2),
      (0.90, -2),
      (1, 0),
    ],
  ),
  // ── FINGER WAG. The arm holds and the forearm does the telling-off.
  'fingerwag': const GestureAnimation(
    armNear: [(0, armNearRest), (0.18, -48), (0.82, -48), (1, armNearRest)],
    foreNear: [
      (0, foreRest),
      (0.18, -79),
      (0.26, -103),
      (0.34, -79),
      (0.42, -103),
      (0.50, -79),
      (0.58, -103),
      (0.66, -79),
      (0.74, -103),
      (0.82, -79),
      (1, foreRest),
    ],
  ),
  'facepalm': GestureAnimation(
    armNear: _hold(armNearRest, -82, 0.34, 0.84),
    foreNear: _hold(foreRest, -107, 0.34, 0.84),
  ),
};

/// True when this gesture has a pose to play. Every id in
/// `manager_mood.dart`'s table does; the check exists so a future emote cannot
/// silently freeze the figure in its rest pose.
bool hasGesturePose(String id) => _animations.containsKey(id);

double? _at(GestureTrack? track, double phase, Curve curve) {
  if (track == null || track.isEmpty) return null;
  for (var i = 0; i < track.length - 1; i++) {
    final (from, a) = track[i];
    final (to, b) = track[i + 1];
    if (phase > to) continue;
    final span = to - from;
    if (span <= 0) return b;
    return a + (b - a) * curve.transform(((phase - from) / span).clamp(0, 1));
  }
  return track.last.$2;
}

/// Where every joint is, [progress] of the way through gesture [id].
///
/// Returns the rest pose — every field null, so the walk owns everything — for
/// an unknown id, because a gesture nobody drew must not stop him walking.
GesturePose gesturePose(String id, double progress, {int? gestureMs}) {
  final a = _animations[id];
  if (a == null) return _rest;
  // The robot runs its own repeating cycle inside the gesture's life; everything
  // else reads the gesture's own 0→1.
  final phase = a.cycleMs == null || gestureMs == null
      ? progress.clamp(0.0, 1.0)
      : (progress * gestureMs / a.cycleMs!) % 1;
  return (
    armNear: _at(a.armNear, phase, a.curve),
    armFar: _at(a.armFar, phase, a.curve),
    foreNear: _at(a.foreNear, phase, a.curve),
    foreFar: _at(a.foreFar, phase, a.curve),
    head: _at(a.head, phase, a.curve),
    body: _at(a.body, phase, a.curve),
    bodyLift: _at(a.bodyLift, phase, a.curve),
    legs: _at(a.legs, phase, a.curve),
  );
}
