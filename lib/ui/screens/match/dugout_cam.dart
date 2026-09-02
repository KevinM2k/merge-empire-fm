/// The dugout cam — a broadcast cut-in that puts the MANAGER on screen during a
/// match, reacting to what just happened. Ported from
/// `ui/components/DugoutCam.js` and the `.dugout-cam` block of
/// `ui/styles/league-scene.css`.
///
/// Why it exists: ten axes of customisation and fifteen touchline emotes (nine
/// of them bought) rendered in exactly one place — the League diorama, where he
/// is a ~40px walker in a wide shot. This is the same rig at roughly twice that
/// size, cropped chest-up, which is the first time a hat, a haircut or a fist
/// pump has been legible at all.
///
/// **THE FIGURE IS THE SAME ONE, DELIBERATELY.** It is [ManagerWalker], with
/// its legs planted — so this needed no new art and cannot drift from what the
/// diorama shows. What it must NOT become is a front-facing rig: the head is
/// drawn in three-quarter profile and every hat, hair style, beard and face
/// item is geometry anchored to that silhouette. Turning him to camera means a
/// second wardrobe for every cosmetic in the shop, and until all of it exists
/// the front view can only show a SUBSET of what people bought — backwards for
/// a feature whose whole job is making purchases visible. A touchline camera
/// looks ALONG the technical area anyway; the crop is what sells the shot, not
/// the angle.
///
/// **BETWEEN gestures he is not still.** A planted walker with nothing else
/// running is a photograph, and at full time that is most of what anybody
/// watches. [_idle] is four loops on four periods that share no common
/// multiple, which is why the combination never visibly repeats.
///
/// When it may come up at all, and what he plays into the lens, is
/// `data/dugout_cam_policy.dart`. Nothing here decides; it only shows.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/data/dugout_cam_policy.dart';
import 'package:merge_empire_fc/data/manager_art.g.dart'
    show managerArtHeight, managerArtWidth;
import 'package:merge_empire_fc/data/manager_looks.dart' show ManagerLook;
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/home/gesture_poses.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_idle.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';

/// What the FRAME says, which is the scoreline rather than the mood.
///
/// The two are not always the same thing: pulling one back at 1-3 is a goal for
/// us and still a bad night, so his face and the border disagree on purpose.
enum CamTone { good, bad, flat }

/// Where the shot is being shown, which decides how long it lives.
///
/// **The two flags the JS carried are one thing here.** `variant` and `persist`
/// were always set together — a floating window leaves on its own, an inline
/// one stays for as long as the result does — so a caller could only ever get
/// them wrong.
enum CamVariant {
  /// A window over the match, bottom-right of the pitch, which plays one
  /// gesture and goes.
  float,

  /// Laid INTO the full-time feed instead, where it stays put: the whistle is
  /// where the reaction is worth printing beside the result, and it keeps
  /// reacting for as long as the shot is up.
  inline,
}

/// The crop: a window on x 23→101, y 22→84 of the rig's own 120×170 box —
/// chest-up, him centred, at roughly 1.5× the diorama's scale.
///
/// **The bounds are what hold the GESTURES**, which is the whole reason he is
/// here: the fist pump's hand tops out at y≈26, the wave reaches (73,29), the
/// point throws a hand out to x≈90 and the bow swings his head to (71,50).
/// Tighten this and the emote people paid for is the thing that gets cropped.
///
/// The scale is [camCropWidth] against the view's width and is UNIFORM — the
/// frame's 5:4 makes the visible height 62.4 art units, which is what the CSS's
/// four derived percentages work out to.
const double camCropLeft = 23;
const double camCropTop = 22;
const double camCropWidth = 78;

/// The frame's aspect. Wider than the rig, because a broadcast cut-in is a
/// landscape window and the crop is what makes it one.
const double camViewAspect = 5 / 4;


/// How long the REC dot's blink takes.
const Duration camRecBlink = Duration(milliseconds: 1100);

/// The handheld drift, on both the figure and the backdrop.
///
/// The camera is a camera. A slow drift, with the backdrop travelling FURTHER
/// than he does so it reads as an operator moving rather than as the whole
/// picture sliding. Tiny — the crop's bounds are what hold the gestures, and
/// this must not eat into them.
const Duration camHandheld = Duration(seconds: 11);

/// The backdrop's own clock: the crowd bouncing, the bench high-fiving or
/// shaking heads, one beat of it.
///
/// **THE PEOPLE BEHIND HIM MOVE NOW.** The crowd was five still discs and the
/// bench four painted men who changed pose only when the tone did, so the one
/// living thing in the shot was the manager — reported as the cam needing to be
/// much more animated, with people happy in the background, high-fiving,
/// shaking heads. A period no other loop shares, for the same reason the four
/// idle clocks do not.
const Duration camLife = Duration(milliseconds: 2300);

/// How wide the floating window is, against the pitch it hangs over — and the
/// bounds either side of that, because a fraction of a tablet is a portrait and
/// the same fraction of a small phone is a stamp.
///
/// **Smaller than it was (0.44), because it covers the one thing on the screen
/// worth watching.** It was reported as being in the way and it is: a shot that
/// takes nearly half the width of the pitch is not a cut-in, it is a second
/// picture. It also gives way outright the moment a chance starts — see
/// `match_screen.dart` — so the size is about the QUIET minutes it hangs over.
const double camFloatFraction = 0.34;
const double camFloatMinWidth = 104;
const double camFloatMaxWidth = 150;

/// And the inline shot, which is wider because it is not covering anything.
const double camInlineFraction = 0.64;
const double camInlineMinWidth = 120;
const double camInlineMaxWidth = 186;

/// One beat of the rota: what he does next, and how long after the last one.
typedef CamRota =
    ({Gesture? gesture, Duration gap}) Function(List<String> recent);

class DugoutCam extends StatefulWidget {
  const DugoutCam({
    required this.mood,
    required this.kit,
    required this.skin,
    required this.hair,
    this.look,
    this.gesture,
    this.minute,
    this.tone = CamTone.flat,
    this.variant = CamVariant.float,
    this.rota,
    this.onDone,
    super.key,
  });

  /// How he is taking it, which drives his mouth, his lean and his idle tempo.
  final Mood mood;

  /// The club's colour — the rig paints itself from it.
  final Color kit;
  final Color skin;
  final Color hair;

  /// What he is wearing, from `club.managerAvatar`.
  final ManagerLook? look;

  /// The gesture he plays into the lens, or null for "he just stands there and
  /// his face does the work" — which is a real outcome, not a failure:
  /// [camGesture] only rolls emotes the player OWNS, and that ownership being
  /// visible is the entire point of putting him on camera.
  final Gesture? gesture;

  /// The clock stamp for the caption, e.g. `62'`. Null at full time.
  final String? minute;

  /// The frame's colour, which is the SCORELINE's rather than the mood's.
  final CamTone tone;

  final CamVariant variant;

  /// Keeps him reacting for as long as the shot is up, and only
  /// [CamVariant.inline] has one.
  ///
  /// One gesture followed by a statue read as a man who had finished having
  /// feelings about the result — worst of all when he had just lost, where the
  /// whole job of the shot is to make "he is not happy" unmistakable. The rota
  /// decides the tempo; see [camRotaGapMs].
  final CamRota? rota;

  /// Fired after a floating window has left. Never for an inline one, which
  /// stays until it is taken away.
  final VoidCallback? onDone;

  @override
  State<DugoutCam> createState() => _DugoutCamState();
}

class _DugoutCamState extends State<DugoutCam> with TickerProviderStateMixin {
  /// The entry and the exit, on one clock: forward to arrive, back to leave.
  /// Its duration is retimed on the way out, because the two are not the same
  /// length.
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: camIn,
    reverseDuration: camOut,
  );

  /// The four idle loops, and the two the camera itself is on.
  ///
  /// **Four separate clocks rather than one shared one**, because the whole
  /// trick is four periods with no common multiple: nothing here is
  /// individually visible, and because they never re-align the combination
  /// never visibly repeats. One clock with four phases read off it would
  /// re-align at every wrap, which is exactly the repeat this avoids.
  late final AnimationController _breath = _loop(camIdle[widget.mood]!.breath);
  late final AnimationController _weight = _loop(camIdle[widget.mood]!.weight);
  late final AnimationController _swayArms = _loop(camIdle[widget.mood]!.sway);
  late final AnimationController _scan = _loop(camIdle[widget.mood]!.scan);
  late final AnimationController _rec = _loop(camRecBlink);
  late final AnimationController _drift = _loop(camHandheld);
  late final AnimationController _life = _loop(camLife);

  AnimationController _loop(Duration period) =>
      AnimationController(vsync: this, duration: period);

  /// What he is playing right now, as the cue the walker starts from.
  GestureCue? _cue;

  /// Gesture ids just played, newest first — the rota's memory.
  final List<String> _recent = [];

  final List<Timer> _timers = [];

  bool _left = false;

  @override
  void initState() {
    super.initState();
    _play(widget.gesture);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // **Reduced motion is belt and braces here.** `shouldCutIn` refuses the
    // whole shot before it can mount, so this only matters for the day that
    // gate moves — but the idle is the one part of the picture that runs
    // forever, and a widget test cannot settle while it does.
    final still = MediaQuery.of(context).disableAnimations;
    if (still) {
      _entry.value = 1;
      for (final c in [
        _breath,
        _weight,
        _swayArms,
        _scan,
        _rec,
        _drift,
        _life,
      ]) {
        c.stop();
        c.value = 0;
      }
      return;
    }
    if (_entry.status == AnimationStatus.dismissed) _entry.forward();
    for (final c in [
      _breath,
      _weight,
      _swayArms,
      _scan,
      _rec,
      _drift,
      _life,
    ]) {
      if (!c.isAnimating) c.repeat();
    }
  }

  /// One gesture, start to finish, and whatever the shot does after it.
  void _play(Gesture? gesture) {
    if (gesture != null) {
      _cue = GestureCue(gesture);
      _recent.insert(0, gesture.id);
      if (_recent.length > camRotaMemory) _recent.removeLast();
    }
    final ms = Duration(milliseconds: gesture?.ms ?? 0);
    if (widget.variant == CamVariant.inline) {
      // He stays until the shot is taken away, so he keeps reacting.
      if (widget.rota != null) _scheduleRota(ms);
      return;
    }
    // **The window's own life, and it is [camWindow] to the millisecond** —
    // the entry, the gesture, a beat to let the pose land, then the exit. It
    // has to be: `camFitsBeforeFullTime` decides whether a late goal gets the
    // camera at all by asking how long this will be up, and a widget that
    // outlived its own policy's answer is the two-managers-at-once bug that
    // rule exists to stop.
    _after(camIn + ms + camHold, _leave);
  }

  /// Keep him reacting for as long as the shot is up.
  ///
  /// **Chained rather than intervalled** — the next gap is measured from the
  /// END of the gesture that just played, so a 2.4s pose and a 1.5s one leave
  /// the same pause behind them. A rota with no gesture to offer ends the loop
  /// and leaves him standing, which is the pre-rota behaviour.
  void _scheduleRota(Duration afterGesture) {
    final beat = widget.rota!(List.unmodifiable(_recent));
    final next = beat.gesture;
    if (next == null) return;
    _after(afterGesture + beat.gap, () {
      setState(() => _play(next));
    });
  }

  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    _entry.reverse().whenComplete(() {
      if (mounted) widget.onDone?.call();
    });
  }

  void _after(Duration delay, VoidCallback run) {
    late Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      if (mounted) run();
    });
    _timers.add(timer);
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    for (final c in [
      _entry,
      _breath,
      _weight,
      _swayArms,
      _scan,
      _rec,
      _drift,
      _life,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The handheld drift, as a fraction of the box. The far layer travels
  /// further, and is scaled up so its own edges never come into frame.
  Offset _driftBy({required bool far}) {
    final t = Curves.easeInOut.transform(
      1 - ((_drift.value * 2) - 1).abs(),
    );
    return far
        ? Offset.lerp(
            const Offset(0.009, -0.004),
            const Offset(-0.011, 0.005),
            t,
          )!
        : Offset.lerp(
            const Offset(-0.004, 0.002),
            const Offset(0.005, -0.003),
            t,
          )!;
  }

  @override
  Widget build(BuildContext context) {
    final tune = camIdle[widget.mood] ?? camIdle[Mood.neutral]!;
    final inline = widget.variant == CamVariant.inline;
    final frame = _CamFrame(
      tone: widget.tone,
      inline: inline,
      view: AspectRatio(
        key: const ValueKey('dugout-cam-view'),
        aspectRatio: camViewAspect,
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([_drift, _life]),
                builder: (context, _) => FractionalTranslation(
                  translation: _driftBy(far: true),
                  // Scaled so the drift never pulls the backdrop's own edge
                  // into frame.
                  child: Transform.scale(
                    scale: 1.03,
                    child: _CamBackdrop(
                      tone: widget.tone,
                      kit: widget.kit,
                      phase: _life.value,
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: Listenable.merge([
                  _breath,
                  _weight,
                  _swayArms,
                  _scan,
                  _drift,
                ]),
                builder: (context, _) {
                  final idle = camIdleAt(
                    tune,
                    breath: _breath.value,
                    weight: _weight.value,
                    sway: _swayArms.value,
                    scan: _scan.value,
                  );
                  return FractionalTranslation(
                    translation: _driftBy(far: false),
                    child: _CamFigure(
                      look: widget.look,
                      kit: widget.kit,
                      skin: widget.skin,
                      hair: widget.hair,
                      mood: widget.mood,
                      cue: _cue,
                      idle: idle.pose,
                      tilt: idle.tilt,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      bar: _CamBar(minute: widget.minute, blink: _rec),
    );

    return AnimatedBuilder(
      animation: _entry,
      builder: (context, child) {
        final k = Curves.easeInOut.transform(_entry.value);
        return Opacity(
          opacity: k,
          child: Transform.translate(
            // Inline rises a shorter way and from a shallower scale: it is
            // arriving IN a list rather than flying over a pitch.
            offset: Offset(0, (1 - k) * (inline ? 6 : 10)),
            child: Transform.scale(
              scale: 1 - (1 - k) * (inline ? 0.02 : 0.04),
              child: child,
            ),
          ),
        );
      },
      child: frame,
    );
  }
}

/// The rig, cropped chest-up.
class _CamFigure extends StatelessWidget {
  const _CamFigure({
    required this.look,
    required this.kit,
    required this.skin,
    required this.hair,
    required this.mood,
    required this.cue,
    required this.idle,
    required this.tilt,
  });

  final ManagerLook? look;
  final Color kit;
  final Color skin;
  final Color hair;
  final Mood mood;
  final GestureCue? cue;
  final GesturePose idle;
  final double tilt;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // One art unit, in pixels. The scale is UNIFORM — the frame's aspect is
      // what decides how much of the rig's height fits, and the four CSS
      // percentages are this same number written four ways.
      final unit = box.maxWidth / camCropWidth;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -camCropLeft * unit,
            top: -camCropTop * unit,
            width: managerArtWidth * unit,
            height: managerArtHeight * unit,
            child: Transform.rotate(
              angle: tilt * math.pi / 180,
              alignment: camBootPivot,
              child: ManagerWalker(
                look: look,
                kit: kit,
                skin: skin,
                hair: hair,
                mood: mood,
                // **His legs are planted and the rest of him is not.**
                walking: false,
                standing: true,
                gesture: cue,
                idle: idle,
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// The dugout behind him, in three flat bands — blurred crowd above, the roof's
/// lip, then the seat backs he stands in front of.
///
/// **Fixed dark colours in both themes**, because it is a camera feed and a
/// light-mode dugout is just a mistake.
class _CamBackdrop extends StatelessWidget {
  const _CamBackdrop({
    required this.tone,
    required this.kit,
    required this.phase,
  });

  final CamTone tone;
  final Color kit;

  /// Where in [camLife] the backdrop is, 0–1.
  final double phase;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF16241A), Color(0xFF0B120C)],
      ),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: FractionallySizedBox(
            heightFactor: 0.38,
            widthFactor: 1,
            child: _CamCrowd(tone: tone, phase: phase),
          ),
        ),
        // The roof's lip, starting where the crowd is still behind it.
        const Align(
          alignment: Alignment(0, -1 + 2 * (0.33 / (1 - 0.09))),
          child: FractionallySizedBox(
            heightFactor: 0.09,
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0A0F0B), Color(0xFF182119)],
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: 0.27,
            widthFactor: 1,
            child: _CamBench(tone: tone, kit: kit, phase: phase),
          ),
        ),
      ],
    ),
  );
}

/// Five blurred heads in the stand behind the roof. Not a crowd simulation —
/// five discs and a blur, which at this size is what a crowd looks like.
class _CamCrowd extends StatelessWidget {
  const _CamCrowd({required this.tone, required this.phase});

  final CamTone tone;
  final double phase;

  static const List<(double x, double y, Color colour)> heads = [
    (0.12, 0.60, Color(0xFF47506A)),
    (0.34, 0.35, Color(0xFF6B5340)),
    (0.56, 0.62, Color(0xFF3F5A4A)),
    (0.78, 0.32, Color(0xFF5D4B63)),
    (0.92, 0.66, Color(0xFF4A5566)),
  ];

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: 0.75,
    child: ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 1.6, sigmaY: 1.6),
      child: CustomPaint(
        painter: CrowdPainter(tone: tone, phase: phase),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

/// **THE STAND REACTS.** On a goal for us the heads jump — each on its own
/// beat, so it is a crowd rather than a chorus line; on one against they sink
/// and sway; between, they shift the way people do when nothing is happening.
class CrowdPainter extends CustomPainter {
  const CrowdPainter({required this.tone, required this.phase});

  final CamTone tone;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF1B2430),
    );
    for (final (i, (x, y, colour)) in _CamCrowd.heads.indexed) {
      // Every head on its own offset into the beat.
      final t = (phase + i * 0.19) % 1.0;
      final wave = math.sin(t * 2 * math.pi);
      final (dx, dy) = switch (tone) {
        // Up off the seat and back down; only the top half of the sine, so
        // nobody sinks through the row in front.
        CamTone.good => (wave * 0.4, -math.max(0.0, wave) * size.height * 0.22),
        // Slumped, and rocking.
        CamTone.bad => (wave * 0.9, size.height * 0.06),
        CamTone.flat => (wave * 0.6, wave * size.height * 0.02),
      };
      canvas.drawCircle(
        Offset(x * size.width + dx, y * size.height + dy),
        3,
        Paint()..color = colour,
      );
    }
  }

  @override
  bool shouldRepaint(CrowdPainter old) =>
      old.phase != phase || old.tone != tone;
}

/// The seat backs, and the substitutes sitting on them.
class _CamBench extends StatelessWidget {
  const _CamBench({required this.tone, required this.kit, required this.phase});

  final CamTone tone;
  final Color kit;
  final double phase;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: BenchPainter(tone: tone, kit: kit, phase: phase),
    child: const SizedBox.expand(),
  );
}

/// **THERE IS SOMEBODY BEHIND HIM NOW.**
///
/// The dugout was a run of empty seat backs, so every shot was one man against
/// a fence — reported as the cam needing more life. It is a BENCH: four
/// substitutes in the club's kit, each at his own height and his own distance
/// along it, and they react to what the shot is about. A goal for us and they
/// are up off the seat with their arms in the air; one against and they are
/// slumped forward with their heads down.
///
/// Painted rather than rigged, and deliberately: they are six pixels of head
/// and a shoulder line at this size, behind a manager who is the subject. A
/// second `ManagerWalker` back there would be four more rigs to keep in step
/// with him for something nobody looks straight at.
///
/// **AND THEY KEEP MOVING.** A goal for us is not four men frozen with their
/// arms up: the two pairs turn to each other and HIGH-FIVE on the beat, and
/// bounce between. One against and the heads hang and shake, slowly, the way
/// a bench does when it has just watched one go in. Between, they look about.
class BenchPainter extends CustomPainter {
  const BenchPainter({
    required this.tone,
    required this.kit,
    required this.phase,
  });

  final CamTone tone;
  final Color kit;

  /// Where in [camLife] the bench is, 0–1.
  final double phase;

  /// Who high-fives whom: the man at each index and his neighbour.
  static const List<(int, int)> _pairs = [(0, 1), (2, 3)];

  /// One seat back and the gap after it, in pixels — the stylesheet's own 11
  /// and 2.
  static const double slat = 11;
  static const double gap = 2;

  /// Where each substitute sits, across the bench, and how tall he is relative
  /// to the strip. Uneven on purpose: four men at the same pitch and the same
  /// height is a fence with faces on it.
  static const List<(double, double)> _subs = [
    (0.12, 1.00),
    (0.31, 0.92),
    (0.70, 0.96),
    (0.88, 0.88),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF1A221D),
    );
    final seat = Paint()..color = const Color(0xFF232C26);
    for (var x = 0.0; x < size.width; x += slat + gap) {
      canvas.drawRect(Rect.fromLTWH(x, 0, slat, size.height), seat);
    }

    // **UP, or HEADS DOWN.** The one thing a bench does that a fence cannot.
    final lift = switch (tone) {
      CamTone.good => -0.16,
      CamTone.bad => 0.10,
      CamTone.flat => 0.0,
    };
    final shirt = Paint()..color = kit;
    final trim = Paint()..color = Color.lerp(kit, Colors.black, 0.45)!;
    final skin = Paint()..color = const Color(0xFFD9A473);
    // The slap lands at the top of the beat and the hands part again.
    final slap = math.max(0.0, math.sin(phase * 2 * math.pi));
    for (final (i, (at, scale)) in _subs.indexed) {
      final unit = size.height * 0.34 * scale;
      // A goal for us has them bouncing on the seat, each a little out of step.
      final bounce = tone == CamTone.good
          ? -math.max(0.0, math.sin((phase + i * 0.23) * 2 * math.pi)) *
                unit *
                0.14
          : 0.0;
      final cx = size.width * at;
      // The seat line they sit ON, so a slumped man drops toward it rather than
      // through it.
      final base = size.height * (0.98 + lift * 0.35) + bounce;
      // Shoulders: a rounded bar, wider than the head, sitting on the seat.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            cx - unit * 0.62,
            base - unit * 1.05,
            unit * 1.24,
            unit * 1.05,
          ),
          Radius.circular(unit * 0.34),
        ),
        shirt,
      );
      // A collar, so the shirt is a shirt.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            cx - unit * 0.30,
            base - unit * 1.05,
            unit * 0.60,
            unit * 0.16,
          ),
          Radius.circular(unit * 0.08),
        ),
        trim,
      );
      // The head: hanging and SHAKING on a goal against, looking about the
      // rest of the time, still only while celebrating — the arms carry that.
      final headSway = switch (tone) {
        CamTone.bad => math.sin((phase * 2 + i * 0.31) * 2 * math.pi) * 0.10,
        CamTone.flat => math.sin((phase + i * 0.37) * 2 * math.pi) * 0.07,
        CamTone.good => 0.0,
      };
      canvas.drawCircle(
        Offset(cx + headSway * unit, base - unit * (1.05 + 0.34 * (1 + lift))),
        unit * 0.34,
        skin,
      );
      if (tone == CamTone.good) {
        // Which neighbour he is turned to.
        final partner = _pairs
            .where((p) => p.$1 == i || p.$2 == i)
            .map((p) => p.$1 == i ? p.$2 : p.$1)
            .firstOrNull;
        final toward = partner == null ? 0.0 : (_subs[partner].$1 - at).sign;
        final arm = Paint()
          ..color = kit
          ..strokeWidth = unit * 0.22
          ..strokeCap = StrokeCap.round;
        for (final side in const [-1.0, 1.0]) {
          final shoulderX = cx + side * unit * 0.55;
          final shoulder = Offset(shoulderX, base - unit * 0.95);
          if (side == toward && partner != null) {
            // **THE HIGH-FIVE.** The inner arm swings toward the partner and
            // the two hands meet at the top of the beat, halfway between them.
            final meetX = (cx + size.width * _subs[partner].$1) / 2;
            final hand = Offset(
              shoulderX + (meetX - shoulderX) * slap,
              base - unit * (1.55 + 0.45 * slap),
            );
            canvas.drawLine(shoulder, hand, arm);
          } else {
            // The outer arm is up, and punches with the beat.
            canvas.drawLine(
              shoulder,
              Offset(cx + side * unit * 0.62, base - unit * (1.75 + 0.20 * slap)),
              arm,
            );
          }
        }
      }
    }

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 1),
      Paint()..color = Colors.white.withValues(alpha: 0.09),
    );
  }

  @override
  bool shouldRepaint(BenchPainter old) =>
      old.tone != tone || old.kit != kit || old.phase != phase;
}

/// The caption bar — the thing that makes it read as a camera rather than as a
/// sticker.
class _CamBar extends StatelessWidget {
  const _CamBar({required this.minute, required this.blink});

  final String? minute;
  final Listenable blink;

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF0A0F0B),
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
    child: Row(
      children: [
        AnimatedBuilder(
          animation: blink,
          builder: (context, child) {
            final v = blink is Animation<double>
                ? (blink as Animation<double>).value
                : 0.0;
            // Down and back up across the cycle, so the dot pulses rather than
            // snapping off.
            return Opacity(
              opacity: 1 - 0.75 * (1 - ((v * 2) - 1).abs()),
              child: child,
            );
          },
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFFFF4D4D),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            t('match.dugout_cam'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _label,
          ),
        ),
        if (minute != null) ...[
          const SizedBox(width: 6),
          Text(
            minute!,
            style: _label.copyWith(
              color: const Color(0xFFCFE4D2).withValues(alpha: 0.75),
              letterSpacing: 0.35,
            ),
          ),
        ],
      ],
    ),
  );

  static const TextStyle _label = TextStyle(
    color: Color(0xFFCFE4D2),
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.95,
    height: 1.2,
  );
}

/// The window itself: the border, the corners and the shadow.
class _CamFrame extends StatelessWidget {
  const _CamFrame({
    required this.tone,
    required this.inline,
    required this.view,
    required this.bar,
  });

  final CamTone tone;
  final bool inline;
  final Widget view;
  final Widget bar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // **The frame is the SCORELINE's colour, not the mood's** — see [CamTone].
    final border = switch (tone) {
      CamTone.good => scheme.primary.withValues(alpha: 0.62),
      CamTone.bad => scheme.error.withValues(alpha: 0.55),
      CamTone.flat => scheme.outlineVariant,
    };
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C130D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x6B000000),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      // Clipped to the border's radius LESS its width, which is the curve of
      // the hole the children are sitting in — the same fix the player cards
      // needed, and for the same reason: a child filling the box paints over
      // the border's own curve.
      clipBehavior: Clip.antiAlias,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        // **THE BAR IS LAST, AND THE SCENE TAKES WHAT IS LEFT.**
        //
        // Both children used to size themselves, so an inline frame stretched
        // taller than they wanted — which is every full-time report, where the
        // quest panel beside it decides the row's height — left a band of empty
        // backdrop under the label. Reported from the couch: use the whole
        // space, label at the bottom, him in the rest of it.
        //
        // **The scene stays an `AspectRatio` inside that `Expanded`, and that
        // is the whole subtlety.** The obvious move is a `SizedBox.expand`, and
        // it takes the report down: this frame sits under the report's
        // `IntrinsicHeight`, an expanding box has no intrinsic height to
        // report, so the query walks on into the scene and hits a
        // `LayoutBuilder` — "does not support returning intrinsic dimensions",
        // and then `RenderBox was not laid out` for the rest of the page.
        // `AspectRatio` answers the intrinsic pass from the width, and when it
        // is later handed tight constraints it simply fills them. Both
        // questions, one widget.
        //
        // Only inline has a bounded height to expand into; the float sizes
        // itself from that same aspect and must keep its own shape.
        child: Column(
          mainAxisSize: inline ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (inline) Expanded(child: view) else view,
            bar,
          ],
        ),
      ),
    );
  }
}
