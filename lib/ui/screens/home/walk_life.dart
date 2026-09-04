/// What a walking man does with his head between gestures.
///
/// **He walked forwards and looked forwards, for minutes at a time.** The
/// gesture rota fires every so often and between cues the figure was a man on
/// rails: the stride, the blink, and nothing else above the shoulders. A person
/// walking a touchline glances up at the stand, looks down at the grass in
/// front of him, nods to himself, lets his eyes wander — small things, none of
/// them a gesture, and their absence is most of what "he looks bored" means.
///
/// So this is a SCHEDULE of small head and eye movements on its own clock. Pure:
/// seconds in, a head angle and a gaze out, so a test can walk the whole cycle.
/// The cycle is a fixed list of beats with uneven lengths — it repeats, but at
/// half a minute nobody counts, and a fixed list means a frame costs a handful
/// of comparisons rather than a walk down a growing history.
///
/// Degrees are the rig's own: positive drops the chin. Gaze is in eye units,
/// +x forward (the way he faces), +y down; the painter scales it to the socket.
library;

import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// One beat of the cycle: how long it lasts and what he does in it.
typedef LifeBeat = ({double seconds, LifeAction action});

enum LifeAction {
  /// Eyes front, nothing added.
  none,

  /// A look UP at the stand — the crowd is above and behind the touchline.
  lookUp,

  /// A look down at the grass in front of his boots.
  lookDown,

  /// Two small nods to himself.
  nod,

  /// The eyes go back over his shoulder without the head following.
  glanceBack,

  /// A longer, slower look up and along the stand.
  survey,
}

/// The cycle. Uneven on purpose: a metronome reads as a tic.
const List<LifeBeat> lifeCycle = [
  (seconds: 3.4, action: LifeAction.none),
  (seconds: 2.6, action: LifeAction.lookUp),
  (seconds: 4.2, action: LifeAction.none),
  (seconds: 1.7, action: LifeAction.nod),
  (seconds: 3.0, action: LifeAction.lookDown),
  (seconds: 5.1, action: LifeAction.none),
  (seconds: 2.2, action: LifeAction.glanceBack),
  (seconds: 3.8, action: LifeAction.survey),
  (seconds: 2.9, action: LifeAction.none),
  (seconds: 1.5, action: LifeAction.nod),
  (seconds: 3.6, action: LifeAction.none),
];

/// The whole cycle's length, in seconds.
final double lifeCycleSeconds = lifeCycle.fold(0, (a, b) => a + b.seconds);

/// How far the head goes, in degrees, per action. Small: the mood already
/// carries the head a few degrees and a gesture can take it twenty; these sit
/// under both.
const double lifeLookUp = -8;
const double lifeLookDown = 6;
const double lifeNod = 2.4;
const double lifeSurvey = -5.5;

/// How long the head takes to get there and back. The eyes lead by being
/// quicker — see [_gazeIn].
const double _headIn = 0.45;
const double _headOut = 0.55;
const double _gazeIn = 0.18;
const double _gazeOut = 0.35;

/// **THE TURN.** A side-on rig can still twist at the waist: [turn] runs -1
/// (shoulders turned AWAY, toward the stand across the pitch) to 1 (turned to
/// the camera). The torso broadens and the shoulders slide; the head keeps its
/// profile. Looking up at the stand turns him away a little.
const double lifeTurnToStand = -0.45;

/// Where his head and eyes are, [seconds] into the walk.
({double head, Offset gaze, double turn}) walkLifeAt(double seconds) {
  if (seconds.isNaN || seconds.isInfinite) {
    return (head: 0, gaze: Offset.zero, turn: 0);
  }
  var t = seconds % lifeCycleSeconds;
  if (t < 0) t += lifeCycleSeconds;
  for (final beat in lifeCycle) {
    if (t < beat.seconds) return _beatAt(beat, t);
    t -= beat.seconds;
  }
  return (head: 0, gaze: Offset.zero, turn: 0);
}

/// An envelope that rises over [inS], holds, and falls over [outS], eased.
double _hold(double t, double length, double inS, double outS) {
  if (t < inS) return Curves.easeInOut.transform((t / inS).clamp(0, 1));
  if (t > length - outS) {
    return Curves.easeInOut.transform(
      ((length - t) / outS).clamp(0, 1),
    );
  }
  return 1;
}

({double head, Offset gaze, double turn}) _beatAt(LifeBeat beat, double t) {
  final len = beat.seconds;
  switch (beat.action) {
    case LifeAction.none:
      return (head: 0, gaze: Offset.zero, turn: 0);
    case LifeAction.lookUp:
      final env = _hold(t, len, _headIn, _headOut);
      return (
        head: lifeLookUp * env,
        // Up, and a touch back — the stand is across the pitch.
        gaze: const Offset(-0.25, -0.75) * _hold(t, len, _gazeIn, _gazeOut),
        turn: lifeTurnToStand * env,
      );
    case LifeAction.lookDown:
      return (
        head: lifeLookDown * _hold(t, len, _headIn, _headOut),
        gaze: const Offset(0.35, 0.7) * _hold(t, len, _gazeIn, _gazeOut),
        turn: 0,
      );
    case LifeAction.nod:
      // Two nods across the beat, faded at both ends so it starts and stops
      // from level.
      final env = _hold(t, len, 0.25, 0.3);
      return (
        head: lifeNod * math.sin(t / len * 4 * math.pi) * env,
        gaze: Offset(0, 0.25 * math.sin(t / len * 4 * math.pi) * env),
        turn: 0,
      );
    case LifeAction.glanceBack:
      return (
        head: 0,
        gaze: const Offset(-0.85, -0.15) * _hold(t, len, _gazeIn, _gazeOut),
        turn: 0,
      );
    case LifeAction.survey:
      // Up and away, then the eyes track along the stand from back to front.
      final env = _hold(t, len, _headIn + 0.2, _headOut + 0.2);
      final along = (t / len) * 2 - 1;
      return (
        head: lifeSurvey * env,
        gaze: Offset(0.6 * along, -0.65) * env,
        turn: lifeTurnToStand * 1.2 * env,
      );
  }
}
