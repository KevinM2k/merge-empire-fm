/// What a manager who is standing still is DOING.
///
/// **Moved out of `dugout_cam.dart`, unchanged, because there were two managers
/// and only one of them was alive.** The cam built a complete idle — four
/// out-of-phase loops driving breath, weight, arm sway and a slow scan — and
/// the one on the HOME screen, which is the manager most players look at most,
/// had none of it: he walked, and between gestures that was all he did.
///
/// It sits beside the walker rather than beside the camera because it belongs
/// to the FIGURE, and because the dependency already ran cam → home for
/// `ManagerWalker` itself. The names are the cam's own so nothing there changed
/// but an import.
///
/// [ManagerIdle] is the driver: four clocks and the pose they make. Everything
/// else here is pure.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/ui/screens/home/gesture_poses.dart';

/// How the four idle loops are tuned, per mood.
///
/// Mood posture, on the same dial the diorama leans him with. Chest out on a
/// good night, head down on a bad one — and the idle TEMPO goes with it. A man
/// who has just won cannot keep still; a beaten one is slow, and breathes
/// DEEPER rather than less (the amplitude goes back up at [Mood.crushed] on
/// purpose — that is the sigh).
///
/// Amplitudes are in the rig's own art units and degrees, and the crop
/// magnifies by about 2.3×, so 0.65 here is a pixel and a half. That is the
/// intended size: this is meant to be noticed only when it stops.
typedef CamIdleTuning = ({
  /// The whole-body pitch. A couple of degrees forward reads as head down, a
  /// degree back as chest out.
  double lean,
  Duration breath,
  Duration sway,
  Duration weight,
  Duration scan,
  double breathUnits,
  double swayDegrees,
  double weightDegrees,
  double scanDegrees,
});

const Map<Mood, CamIdleTuning> camIdle = {
  Mood.elated: (
    lean: -1.5,
    breath: Duration(milliseconds: 2600),
    sway: Duration(milliseconds: 4000),
    weight: Duration(milliseconds: 5400),
    scan: Duration(milliseconds: 6400),
    breathUnits: 0.9,
    swayDegrees: 2.2,
    weightDegrees: 0.7,
    scanDegrees: 1.5,
  ),
  Mood.pleased: (
    lean: -0.5,
    breath: Duration(milliseconds: 3000),
    sway: Duration(milliseconds: 4600),
    weight: Duration(milliseconds: 6200),
    scan: Duration(milliseconds: 7300),
    breathUnits: 0.75,
    swayDegrees: 1.9,
    weightDegrees: 0.6,
    scanDegrees: 1.3,
  ),
  Mood.neutral: (
    lean: 0,
    breath: Duration(milliseconds: 3400),
    sway: Duration(milliseconds: 5100),
    weight: Duration(milliseconds: 7000),
    scan: Duration(milliseconds: 8300),
    breathUnits: 0.65,
    swayDegrees: 1.6,
    weightDegrees: 0.5,
    scanDegrees: 1.1,
  ),
  Mood.glum: (
    lean: 1.5,
    breath: Duration(milliseconds: 3900),
    sway: Duration(milliseconds: 5900),
    weight: Duration(milliseconds: 8000),
    scan: Duration(milliseconds: 9400),
    breathUnits: 0.8,
    swayDegrees: 1.3,
    weightDegrees: 0.42,
    scanDegrees: 0.9,
  ),
  Mood.crushed: (
    lean: 3,
    breath: Duration(milliseconds: 4400),
    sway: Duration(milliseconds: 6600),
    weight: Duration(milliseconds: 9000),
    scan: Duration(milliseconds: 10600),
    breathUnits: 1,
    swayDegrees: 1.1,
    weightDegrees: 0.36,
    scanDegrees: 0.75,
  ),
};

/// **Breath is asymmetric on purpose — in quickly, out slowly.** A symmetric
/// rise and fall reads as a bounce, which is the walk that was just turned off.
///
/// Negative is UP: the pose's lift is added to a y that grows downward.
const GestureTrack _breathTrack = [(0, 0), (0.38, -1), (1, 0)];

/// Shifting his weight. In profile there is no side-to-side, so it is a rock
/// about the boots — forward onto the balls of the feet and back.
const GestureTrack _weightTrack = [(0, -1), (0.5, 1), (1, -1)];

/// The arms hang and drift, OUT OF PHASE with each other so he does not look
/// like he is swinging both at once — which is a walk, not a stand.
const GestureTrack _armNearTrack = [(0, -1), (0.5, 1), (1, -1)];
const GestureTrack _armFarTrack = [(0, 0.62), (0.44, -0.7), (1, 0.62)];

/// He is watching the game. Small, and slow enough to read as attention rather
/// than as a tic — the head pivots at the base of the neck, so a degree here
/// moves the peak of a cap a long way.
const GestureTrack _scanTrack = [(0, -1), (0.3, 0.85), (0.62, -0.3), (1, -1)];

/// Where his joints sit while nothing else is driving them, at four given
/// clock positions.
///
/// Pure, and separate from the widget, because it is the whole of what
/// "standing still" means here and it is four tracks read against four
/// amplitudes — the kind of arithmetic that is invisible on screen at a pixel
/// and a half and obvious in a test.
///
/// [tilt] is the whole-body rotation, and it is the mood's LEAN and the weight
/// rock added: the stylesheet turns both about `50% 92%`, so two nested
/// rotations about the same point would be one rotation written twice.
({GesturePose pose, double tilt}) camIdleAt(
  CamIdleTuning tune, {
  required double breath,
  required double weight,
  required double sway,
  required double scan,
}) => (
  pose: (
    // The arms swing about the angles the walk rests them at, so the drift is
    // a nudge either side of where he already holds them.
    armNear: armNearRest + trackAt(_armNearTrack, sway)! * tune.swayDegrees,
    armFar: armFarRest + trackAt(_armFarTrack, sway)! * tune.swayDegrees,
    foreNear: null,
    foreFar: null,
    // The scan ADDS to however his mood has him carrying his head — see the
    // note in `manager_walker.dart`, which is where the two meet.
    head: trackAt(_scanTrack, scan)! * tune.scanDegrees,
    body: null,
    bodyLift: trackAt(_breathTrack, breath)! * tune.breathUnits,
    legs: null,
    finger: 0,
  ),
  tilt: tune.lean + trackAt(_weightTrack, weight)! * tune.weightDegrees,
);

/// Four clocks, and the pose they make.
///
/// **Four separate loops rather than one with four phases read off it**, and
/// the cam's own note is why: they never re-align, so the combination never
/// visibly repeats. One clock would re-align at every wrap, which is exactly
/// the repeat this avoids.
///
/// Reduced motion stops them and leaves him at rest — he is still drawn, he
/// just holds still, which is the same bargain every other loop in this app
/// strikes.
class ManagerIdle extends StatefulWidget {
  const ManagerIdle({super.key, required this.mood, required this.builder});

  final Mood mood;
  final Widget Function(BuildContext, ({GesturePose pose, double tilt}))
  builder;

  @override
  State<ManagerIdle> createState() => _ManagerIdleState();
}

class _ManagerIdleState extends State<ManagerIdle>
    with TickerProviderStateMixin {
  late CamIdleTuning _tune = camIdle[widget.mood] ?? camIdle[Mood.neutral]!;
  late final AnimationController _breath = _loop(_tune.breath);
  late final AnimationController _weight = _loop(_tune.weight);
  late final AnimationController _sway = _loop(_tune.sway);
  late final AnimationController _scan = _loop(_tune.scan);

  AnimationController _loop(Duration period) =>
      AnimationController(vsync: this, duration: period);

  List<AnimationController> get _all => [_breath, _weight, _sway, _scan];

  void _sync() {
    final run = !MediaQuery.of(context).disableAnimations;
    for (final c in _all) {
      if (run && !c.isAnimating) {
        c.repeat();
      } else if (!run && c.isAnimating) {
        c.stop();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ManagerIdle old) {
    super.didUpdateWidget(old);
    if (old.mood == widget.mood) return;
    // **The tempo goes with the mood** — a man who has just won cannot keep
    // still — so the clocks are re-timed rather than the pose being scaled.
    _tune = camIdle[widget.mood] ?? camIdle[Mood.neutral]!;
    _breath.duration = _tune.breath;
    _weight.duration = _tune.weight;
    _sway.duration = _tune.sway;
    _scan.duration = _tune.scan;
    _sync();
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge(_all),
    builder: (context, _) => widget.builder(
      context,
      camIdleAt(
        _tune,
        breath: _breath.value,
        weight: _weight.value,
        sway: _sway.value,
        scan: _scan.value,
      ),
    ),
  );
}
