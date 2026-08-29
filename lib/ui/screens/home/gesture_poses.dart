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

  /// The NEAR leg alone, swinging about the hip and folding at the knee —
  /// a kick. Positive is backwards, like the walk's own tracks.
  double? kickThigh,
  double? kickShin,

  /// The index finger's opacity, 0 to 1.
  ///
  /// **Kept out of sight the rest of the time on purpose.** At this size a
  /// permanent finger makes the hand read as a lumpy mitten; it only exists for
  /// the three gestures that are pointing at something.
  double finger,
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
  kickThigh: null,
  kickShin: null,
  finger: 0,
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
    this.kickThigh,
    this.kickShin,
    this.finger,
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
  final GestureTrack? kickThigh;
  final GestureTrack? kickShin;

  /// `psvFingerShow`: out almost at once, away again at the end.
  final GestureTrack? finger;

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

/// The JS's `psvFingerShow`, which every pointing gesture shares.
const GestureTrack _fingerOut = [(0, 0), (0.12, 1), (0.88, 1), (1, 0)];

/// **CHIN UP while he is doing something outward, then back down.**
///
/// Not in the JS, which only tilts the head for the three gestures that are ABOUT
/// the head. But the mood now sets a resting tilt — a beaten manager walks looking
/// at the ground — and a man who points at the far post while still staring at his
/// own boots is worse than one who never looked down at all.
///
/// It returns to zero at both ends, and the mood baseline is added underneath, so
/// this LIFTS him from wherever he was carrying his head and hands him back to it.
/// Six degrees is enough: any more and a cheerful manager is looking at the sky —
/// which is the same reason `moodHeadTilt`'s up end came down.
const GestureTrack _chinUp = [(0, 0), (0.2, -6), (0.8, -6), (1, 0)];

/// **Gestures whose hand belongs IN FRONT of the face.**
///
/// The head and everything it wears is a stack of widgets ABOVE the rig's
/// painter — that is what lets a tilt take the hair, the beard, the glasses and
/// the hat with it — so a hand brought to the face is painted behind it.
/// Reported as head in hands putting the hands behind the head.
///
/// Named rather than derived. A rule like "the hand is above the chin" would
/// have to re-solve the two-bone chain for every frame of every gesture to
/// answer a question that is fixed the moment the pose is written down, and it
/// would guess wrong at the edges — a salute's hand is level with the brow and
/// a wave's is not, at angles a few degrees apart.
const Set<String> gestureHandsOverHead = {
  'handsonhead',
  'facepalm',
  'shush',
  'salute',
  'blowkiss',
  // Kissing the badge ends with the hand AT the mouth — see 'badgekiss'.
  'badgekiss',
};

final Map<String, GestureAnimation> _animations = {
  // ── FIST PUMP. Three pumps, and the only gesture whose track does not return
  // to rest in the middle: it is a repeated motion, not a pose held.
  // **THE FIST STAYS OUT IN FRONT OF HIM.** `foreNear` is the forearm's angle
  // relative to the upper arm, so the ELBOW angle is `180 + foreNear` — and at
  // -116 that is a 64° elbow, which folds the fist back past his own chin.
  //
  // **AND IT WAS STILL GRAZING HIS FACE at the top of the pump**, reported as
  // going a little too close. Measured rather than eyeballed: the skull is
  // drawn at (59, 41.5) r12.5 — the art's (62, 48.5) less [_headSetBack] and
  // [_headLift] — the hand is a 7.4-wide oval, and at the old peak of
  // (-84, -90) the two were **0.96 art units apart**, which at this scale is
  // touching.
  //
  // The lever is the ELBOW, not the shoulder. `armNear` cannot push the elbow
  // any further forward than -90 (18 units dead ahead of the shoulder), so
  // opening the elbow is the only thing that moves the fist away from the
  // face — and it moves it FORWARD and UP rather than down, which is why the
  // peak is now higher than it was: (78.3, 41.9) against (76.1, 43.4), with
  // 3.09 units of daylight. The pump is also bigger than before, 16° of
  // shoulder against 10°.
  'fistpump': const GestureAnimation(
    armNear: [
      (0, armNearRest),
      (0.16, -90),
      (0.34, -74),
      (0.50, -90),
      (0.66, -74),
      (0.82, -88),
      (1, armNearRest),
    ],
    foreNear: [
      (0, foreRest),
      (0.16, -78),
      (0.34, -62),
      (0.50, -78),
      (0.66, -62),
      (0.82, -76),
      (1, foreRest),
    ],
    head: _chinUp,
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
    head: _chinUp,
  ),
  // **POINTING NEEDS THE FINGER**, or it is a fist held out at the pitch. The JS
  // shares one `psvFingerShow` across all three of its pointing gestures.
  'point': GestureAnimation(
    armNear: _hold(armNearRest, -52, 0.20, 0.80),
    foreNear: _hold(foreRest, -56, 0.20, 0.80),
    finger: _fingerOut,
    head: _chinUp,
  ),
  // ── CHECK WATCH. He looks at the wrist he is reading, which is the whole
  // difference between checking the time and holding an arm up.
  'checkwatch': GestureAnimation(
    armNear: _hold(armNearRest, -40, 0.22, 0.78),
    foreNear: _hold(foreRest, -85, 0.22, 0.78),
    head: _hold(0, 15, 0.22, 0.78),
  ),
  // ── ARMS FOLDED. **Two faults, and the second is about the PAINT ORDER.**
  //
  // The first is that the forearms were nowhere near each other: the near hand
  // sat at (67.5, 79.4) and the far one at (67.2, 68.9), ten and a half units
  // apart, which is one arm across the belly and another across the chest —
  // not a fold. They are 5.4 apart now, both across the mid-chest, the near
  // forearm lying on top of the far one.
  //
  // The second is why the pose read as a SINGLE arm however the angles were
  // set. `_WalkerPainter` draws far arm, then body, then near arm, so the far
  // forearm is BEHIND the torso — and the torso runs x 47.9 to 69.9, which is
  // exactly the band a folded forearm crosses. The far arm was drawn and then
  // painted over, every frame. So the far hand now finishes at (72.2, 76.5),
  // past the shirt's front edge, where it emerges below and in front of the
  // near one: the two of them are what makes it read as folded rather than as
  // one arm held across.
  'armsfolded': GestureAnimation(
    armNear: _hold(armNearRest, 25, 0.14, 0.86),
    foreNear: _hold(foreRest, -135.5, 0.14, 0.86),
    armFar: _hold(armFarRest, 13.5, 0.14, 0.86),
    foreFar: _hold(foreRest, -112, 0.14, 0.86),
  ),
  'handsonhead': GestureAnimation(
    head: _hold(0, 20, 0.20, 0.80),
    armNear: _hold(armNearRest, -78, 0.20, 0.80),
    armFar: _hold(armFarRest, -78, 0.20, 0.80),
    foreNear: _hold(foreRest, -113, 0.20, 0.80),
    foreFar: _hold(foreRest, -113, 0.20, 0.80),
  ),
  // ── HANDS ON HIPS. **SOLVED, not transcribed — the only pose here that is.**
  //
  // The JS's numbers are 44 and -106, and on the JS's arm they land a hand on a
  // hip. On this one they do not: the redraw relengthened the arm (shoulder to
  // elbow 19, elbow to hand 19.6) and the same angles put the elbow at x 42.8 —
  // five units OUTSIDE his back, the torso stopping at 47.9 — with the hand at
  // (60, 85), which is the middle of his belly. An elbow sticking out behind a man
  // patting his stomach is not the gesture.
  //
  // So the target is the hip and the angles come out of it: two-bone IK onto (65,
  // 89) near and (63, 90) far, which is the top corner of the shorts on each side.
  // A pose is a place a hand goes, not a pair of numbers — and when the limb it
  // hangs off changes length, the numbers have to.
  'handsonhips': GestureAnimation(
    armNear: _hold(armNearRest, 24.9, 0.14, 0.86),
    foreNear: _hold(foreRest, -85, 0.14, 0.86),
    armFar: _hold(armFarRest, 28.4, 0.14, 0.86),
    foreFar: _hold(foreRest, -83.2, 0.14, 0.86),
  ),
  // ── WAVE. The arm goes UP and stays; the wave is in the forearm.
  //
  // **THE ARM WENT THROUGH HIS HEAD, and the numbers say so plainly.** At the
  // old -150 the upper arm is very nearly vertical, which on this rig puts the
  // elbow at (65.0, 46.4) — and the skull as drawn is a circle at (59, 41.5)
  // with r12.5, so the elbow was **10.2 units INSIDE it** and the forearm 9.6.
  // Only the hand cleared, popping out above the crown with the whole limb
  // that carried it painted behind the face. Reported exactly as the arm going
  // behind the head.
  //
  // It is not a layering fault and adding this to [gestureHandsOverHead] would
  // be the wrong fix twice over: an arm drawn OVER the head at these angles
  // covers his face instead of hiding behind it. The pose is what is wrong.
  //
  // **The shoulder is only ~15 units below the skull's centre and the upper arm
  // is 18 long, so any raised arm puts the elbow at head height.** The way out
  // is forward rather than up: at -101 the elbow sits at (73.6, 58.4), just
  // clear of the jaw and in front of it, and the forearm comes up from there
  // with a 113° elbow — which is what a wave is anyway. Solved against the
  // skull rather than picked: every joint clears it with room, and the hand at
  // (77.8, 38.3) is beside his head where a wave belongs.
  //
  // The rock then fans FORWARD from that hold rather than either side of it,
  // because the backswing is the half that runs back into the face: at -74 the
  // forearm is already touching it again.
  'wave': const GestureAnimation(
    armNear: [(0, armNearRest), (0.16, -101), (0.84, -101), (1, armNearRest)],
    foreNear: [
      (0, foreRest),
      (0.16, -67),
      (0.34, -45),
      (0.50, -67),
      (0.66, -45),
      (0.84, -67),
      (1, foreRest),
    ],
    head: _chinUp,
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
  // ── BADGE KISS. **TWO PLACES, and it only ever had one.** The gesture is
  // touch the badge, then kiss the hand — and the old track was a single
  // in-and-out that did neither: the hand started out in front of him at
  // (75.9, 60.1), which is thin air, and came in to (63.8, 53.5), which is
  // 3.3 units INSIDE the skull. So the one keyframe that was meant to be the
  // badge landed on his jaw, and was painted behind it.
  //
  // Both targets are solved onto real places now. The badge is the upper chest
  // at (66, 67) — inside the torso's own 47.9..69.9 band, so the hand is ON him
  // rather than reaching past — held while he touches it; then the arm comes
  // up and forward and the hand finishes at (70.1, 48.6), which is the mouth
  // the art draws at (71, 55.5) less the head's set-back and lift.
  //
  // **Which is why it joins [gestureHandsOverHead].** A hand at the mouth is in
  // front of the face by definition, and without that pass the kiss is the
  // second half of the gesture disappearing behind his own chin — the same
  // fault the pose had.
  'badgekiss': const GestureAnimation(
    armNear: [
      (0, armNearRest),
      (0.22, 21),
      (0.38, 21),
      (0.58, -67),
      (0.74, -67),
      (1, armNearRest),
    ],
    foreNear: [
      (0, foreRest),
      (0.22, -147),
      (0.38, -147),
      (0.58, -120),
      (0.74, -120),
      (1, foreRest),
    ],
  ),
  'shush': GestureAnimation(
    armNear: _hold(armNearRest, -38, 0.14, 0.86),
    foreNear: _hold(foreRest, -127, 0.14, 0.86),
    finger: _fingerOut,
    head: _chinUp,
  ),
  // ── KICK. Not a celebration and not in the rota: the stray ball's, cued by
  // the screen when he is about to play it back (see `PitchBall.onStrike`).
  // The near thigh draws back, then snaps through with the shin extending, and
  // the contact lands at 0.6 — which is where the ball leaves his boot.
  'kick': const GestureAnimation(
    kickThigh: [(0, 0), (0.30, 24), (0.60, -58), (1, 0)],
    kickShin: [(0, 0), (0.30, 52), (0.60, -6), (1, 0)],
    armNear: [(0, armNearRest), (0.30, armNearRest + 14), (0.60, armNearRest - 22), (1, armNearRest)],
    curve: Curves.easeInOut,
  ),
  // ── SALUTE. Snapped up rather than eased: the curve is the gesture.
  'salute': GestureAnimation(
    armNear: _hold(armNearRest, -117, 0.12, 0.82),
    foreNear: _hold(foreRest, -88, 0.12, 0.82),
    head: _chinUp,
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
  //
  // **Its ARM-UP hold was the worst reach on the rig, and no playthrough
  // reported it — `gesture_reach_test` did.** The near arm held (-142, -88),
  // which raises the upper arm to near-vertical and then folds the forearm
  // BACK across the top of the skull: the hand landed at (51.3, 34.6), behind
  // the head's own centre line, 5.8 units inside the circle with the forearm
  // 15.8 inside it. The far arm's third hold, (-110, -96), was 9.8 inside on
  // the same diagonal. So a third of this gesture was an arm that went up and
  // simply was not there.
  //
  // The shoulder sits ~15 units under the skull's centre and the upper arm is
  // 18 long, so the elbow reaches its furthest FORWARD at -90 (x 74, just past
  // the head's front edge at 71.5) and every angle past that swings it in
  // behind the face. Both holds are at -90-ish now with the forearm rising in
  // FRONT of the head instead of over it — same right angle, same stepped
  // read, and the hand is on screen.
  'robot': const GestureAnimation(
    curve: Curves.linear,
    cycleMs: 1400,
    armNear: [
      (0, armNearRest),
      (0.15, armNearRest),
      (0.25, -96),
      (0.40, -96),
      (0.50, -90),
      (0.65, -90),
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
      (0.75, -88),
      (0.90, -88),
      (1, armFarRest),
    ],
    foreNear: [
      (0, foreRest),
      (0.08, -96),
      (0.15, -96),
      (0.25, -4),
      (0.40, -4),
      (0.50, -78),
      (0.65, -78),
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
      (0.75, -74),
      (0.90, -74),
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
    finger: _fingerOut,
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

/// One keyframe track, read at [phase] and eased per SEGMENT — the way CSS
/// eases a keyframe list, rather than once across the whole run.
///
/// Public because the dugout cam's idle is four keyframe tracks on four clocks
/// of its own, and wants exactly this reading. A second sampler is how the idle
/// and the gestures would end up disagreeing about what `ease-in-out` means on
/// the same rig.
double? trackAt(
  GestureTrack? track,
  double phase, [
  Curve curve = Curves.easeInOut,
]) => _at(track, phase, curve);

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
    kickThigh: _at(a.kickThigh, phase, a.curve),
    kickShin: _at(a.kickShin, phase, a.curve),
    // Linear, not the gesture's curve: it is an appearance, not a movement.
    finger: _at(a.finger, phase, Curves.linear) ?? 0,
  );
}
