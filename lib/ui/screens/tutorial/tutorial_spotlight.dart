/// The dim, the hole, the ring and the hand — ported from `Tutorial.js`'s
/// `#tutorial-hole`, `#tut-ring` and `#tut-hand`.
///
/// **A step that waits on the save has to let the player REACH the thing.**
/// That is the whole reason this exists rather than a card: the JS lays a
/// full-screen blocker over the app and forwards a tap inside the target's rect
/// to the control underneath, so the only thing on screen that can be pressed
/// is the one being taught. A modal card cannot do that — it eats every tap,
/// including the one the step is asking for.
///
/// **The hole is a HOLE, not a lighter rectangle.** It is cut with
/// `BlendMode.dstOut` so what shows through is the live control, still
/// animating, still the player's own kit colours — a redrawn copy would drift
/// from the real one the moment either changed.
///
/// **And the input hole is four rectangles, not a hit-test override.** The dim
/// is painted by one `IgnorePointer` layer and the blocking is done by four
/// `AbsorbPointer`s laid around the hole, so the gap in the middle has no
/// widget over it at all and the tap simply lands on the app. A painter that
/// lied in `hitTest` would block or pass the whole layer, never a region of it.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// How round the cut-out's corners are. The JS's own 14px.
const double spotlightRadius = 14;

/// How far outside the control the hole and the ring sit.
const double spotlightPad = 6;

/// The scrim over everything that is not the target. The JS's `rgba(0,0,0,.72)`.
const Color spotlightScrim = Color(0xB8000000);

class TutorialSpotlight extends StatefulWidget {
  const TutorialSpotlight({
    super.key,
    required this.target,
    this.dragTo,
    this.child,
  });

  /// Where the control is, in global coordinates — or null, which dims the
  /// whole screen and shows neither ring nor hand. That is the JS's "no target"
  /// branch and it is a normal state: the control may be on a tab still
  /// animating in, or scrolled out of view.
  final Rect? target;

  /// Where the gesture FINISHES, for a step answered by a drag.
  ///
  /// **A merge is not a tap and the hand was miming one.** The cue rose to a
  /// card and pressed it, which is the wrong instruction for the one gesture in
  /// the game that starts on one thing and ends on another — reported from the
  /// couch, with the whole cue described: highlight both cards, move the hand to
  /// the first with its rings, run a dotted line across to the second, walk the
  /// hand along it, and let go at the far end.
  ///
  /// **The hole opens over BOTH**, and that is not decoration. A drag is
  /// resolved by hit-testing the pointer where it is now, so a drop target
  /// outside the hole is a drop target the input seal eats — the player would
  /// watch the cue and then find the gesture impossible. Each card still gets
  /// its OWN ring inside that hole, because two rings is what says "these two".
  final Rect? dragTo;

  /// The tooltip, laid over the top.
  final Widget? child;

  @override
  State<TutorialSpotlight> createState() => _TutorialSpotlightState();
}

/// The cue's arithmetic, out where a test can reach it.
///
/// The widget it belongs to is private and should stay so; what is worth
/// pinning is not the tree it builds but WHERE the fingertip is at each moment
/// and how closed the hand is — which is the whole of whether it reads as a
/// grab, a carry and a release.
Offset dragTipAt(double t, Offset rest, Offset from, Offset to) =>
    _DragHand.tipAt(t, rest, from, to);
double dragGripAt(double t) => _DragHand.gripAt(t);

/// The drag cue's own beat, and the four moments in it.
///
/// Longer than [tapCue], because it is four gestures rather than one: reach,
/// grab, carry, let go. At 1.5s the carry was a flick and the whole thing read
/// as a hand jumping between two cards.
const Duration dragCue = Duration(milliseconds: 2400);

/// Down on the card, and the rings that say so.
const double dragGrabAt = 0.20;

/// Where the carry starts and ends — the hold between the grab and the move is
/// what makes the grab read as a grab rather than as a passing touch.
const double dragCarryFrom = 0.32;
const double dragCarryTo = 0.72;

/// Let go, and the rings at the far end.
const double dragDropAt = dragCarryTo;

/// How long the hand takes to leave after the drop, before the loop restarts.
const double _dragLift = 0.14;

/// One beat of "somebody is tapping this", and how long it runs.
///
/// **The hand and the ripple are the same gesture**, so they are the same
/// clock: two controllers of equal length started a frame apart drift, and a
/// ripple that fires while the finger is on its way back down is not a tap.
const Duration tapCue = Duration(milliseconds: 1500);

/// Where in that beat the fingertip lands.
const double tapContact = 0.32;

/// How long the drop back takes.
const double _tapReturn = 0.23;

/// The ripple's life after contact, how wide it gets, and how far behind the
/// first ring the second one follows.
const double _tapSpread = 0.45;
const double tapRippleRadius = 30;
const double _tapSecondRing = 0.3;
const double _ringLeast = 7;

/// The hand's own box, and where the FINGERTIP is inside it.
///
/// **The tip is what has to land on the control, and it is nowhere near the
/// middle of the drawing** — the index finger is up and to the left, and the
/// palm fills the rest. Placing the box's centre under the target put the tip
/// three points off it, which on a small control is the difference between a
/// finger on the button and a finger beside it.
const Size handBox = Size(34, 40);
const Offset handTipInBox = Offset(14, 2.6);

/// How far below the control the hand waits. The JS's own two pixels.
const double _handRest = 2;

/// The furthest it will travel to press.
///
/// A hand that slides the height of a tall target is a swipe rather than a tap,
/// so past this it presses as deep as a button-sized control would take.
const double _tapReachMost = 52;

/// How far the hand travels to make contact.
///
/// **The fingertip lands in the MIDDLE of the control, not on its bottom
/// edge.** It rose seven points from below the button and pressed at the rim,
/// which is not where anybody puts a thumb — and with the ripple at the same
/// place, the whole cue happened along an edge instead of on the thing being
/// pressed. Asked for from the couch: the finger moves to the centre of the
/// button before it presses down.
double _tapReach(Rect hole) =>
    math.min(hole.height / 2 + _handRest + handTipInBox.dy, _tapReachMost);

class _TutorialSpotlightState extends State<TutorialSpotlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tap;

  @override
  void initState() {
    super.initState();
    // **Built here rather than lazily.** A spotlight with nothing to point at
    // draws neither hand nor ripple, so a lazy controller would be created for
    // the first time inside `dispose` — and a `vsync` looked up from a
    // deactivated element throws. It does not START here: see `build`.
    _tap = AnimationController(vsync: this, duration: tapCue);
  }

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final target = widget.target;
    final child = widget.child;
    // **THE DRAG'S END IS ONLY AN END WHILE BOTH ARE ON SCREEN.** Either anchor
    // can be unmeasured for a frame — a tab sliding in, a scroll — and a cue
    // that ran to a rect it had lost would walk the hand to the top-left
    // corner. With one of them missing this is the ordinary tap cue on
    // whichever is there.
    final drag = target == null ? null : widget.dragTo;
    // The hole covers BOTH squares: a drag is resolved by hit-testing the
    // pointer where it is NOW, so a drop target outside the hole is one the
    // input seal eats. See [TutorialSpotlight.dragTo].
    final hole = target == null
        ? null
        : (drag == null ? target : target.expandToInclude(drag)).inflate(
            spotlightPad,
          );
    // **The beat runs only while there is a hand to move.** A step whose
    // control has not been measured yet — a tab still sliding in — draws
    // neither hand nor ripple, and a controller repeating behind nothing is an
    // animation that never ends: every `pumpAndSettle` that reaches a
    // spotlight step hangs on it.
    //
    // The drag cue is four gestures rather than one, so it runs on its own
    // length — see [dragCue].
    final beatLength = drag == null ? tapCue : dragCue;
    if (_tap.duration != beatLength) {
      _tap
        ..stop()
        ..duration = beatLength;
    }
    if (hole == null) {
      _tap.stop();
    } else if (!_tap.isAnimating) {
      _tap.repeat();
    }

    return Stack(
      key: const ValueKey('tutorial-spotlight'),
      children: [
        // The dim, with the hole cut out of it. Never takes a tap — the four
        // blockers below decide what does.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _ScrimPainter(hole)),
          ),
        ),
        ..._blockersAround(hole),
        if (hole != null) ...[
          // **A RING EACH when there are two.** The hole has to be one shape —
          // it is what the input seal is cut out of — but a single ring round
          // both cards says "this area", and what the step means is "these
          // two". Asked for from the couch: highlight both cards.
          for (final ringed in drag == null
              ? [target!.inflate(spotlightPad)]
              : [
                  target!.inflate(spotlightPad),
                  drag.inflate(spotlightPad),
                ])
            Positioned(
              key: ValueKey(
                ringed == hole || drag == null
                    ? 'tutorial-ring'
                    : 'tutorial-ring-${ringed.left.round()}',
              ),
              left: ringed.left,
              top: ringed.top,
              width: ringed.width,
              height: ringed.height,
              child: IgnorePointer(child: _Ring(colour: kit.accentBright)),
            ),
          // **THE TAP ITSELF, where the fingertip meets the button.** The hand
          // sat dead still under the control pointing at it, which says "this
          // one" and not "press it" — and a first-time player looking at a
          // ring, a hand and a card is being shown three static things.
          // Reported from the couch: it should move as if it is clicking, with
          // the wave a tap leaves on a screen. Drawn rather than taken from the
          // Kenney pack — it is two circles and it has to be the kit's own
          // accent, which no bundled sprite can be.
          if (drag == null)
            Positioned(
              key: const ValueKey('tutorial-tap-ripple'),
              // On the middle of the control, because that is where the finger
              // now goes — see [_tapReach].
              left: hole.center.dx - tapRippleRadius,
              top: hole.center.dy - tapRippleRadius,
              width: tapRippleRadius * 2,
              height: tapRippleRadius * 2,
              child: IgnorePointer(
                child: _TapRipple(beat: _tap, colour: kit.accentBright),
              ),
            ),
          // The drag: rings where it is picked up, a dotted line across, rings
          // where it is let go. In that order under the hand, so the hand is
          // never behind its own trail.
          if (drag != null) ...[
            _DragPath(
              beat: _tap,
              from: target.center,
              to: drag.center,
              colour: kit.accentBright,
            ),
            for (final (at, where) in [
              (dragGrabAt, target.center),
              (dragDropAt, drag.center),
            ])
              Positioned(
                key: ValueKey('tutorial-drag-ripple-${at.toString()}'),
                left: where.dx - tapRippleRadius,
                top: where.dy - tapRippleRadius,
                width: tapRippleRadius * 2,
                height: tapRippleRadius * 2,
                child: IgnorePointer(
                  child: _DragRipple(
                    beat: _tap,
                    at: at,
                    colour: kit.accentBright,
                  ),
                ),
              ),
            _DragHand(beat: _tap, from: target.center, to: drag.center),
          ],
          // Under the control, pointing up at it — the JS puts it two pixels
          // below the bottom edge, with the FINGERTIP on the centre line.
          if (drag == null)
            Positioned(
              key: const ValueKey('tutorial-hand'),
              left: hole.center.dx - handTipInBox.dx,
              top: hole.bottom + _handRest,
              width: handBox.width,
              height: handBox.height,
              child: IgnorePointer(
                child: _TapHand(beat: _tap, reach: _tapReach(hole)),
              ),
            ),
        ],
        ?child,
      ],
    );
  }

  /// The four rectangles that eat taps everywhere except the hole.
  ///
  /// With no target the whole screen is blocked, which is right: a step with
  /// nothing to point at is one the player answers on the card.
  List<Widget> _blockersAround(Rect? hole) {
    if (hole == null) {
      return const [Positioned.fill(child: AbsorbPointer())];
    }
    return [
      Positioned(left: 0, right: 0, top: 0, height: math.max(0, hole.top),
          child: const AbsorbPointer()),
      Positioned(left: 0, right: 0, top: hole.bottom, bottom: 0,
          child: const AbsorbPointer()),
      Positioned(left: 0, width: math.max(0, hole.left), top: hole.top,
          height: hole.height, child: const AbsorbPointer()),
      Positioned(left: hole.right, right: 0, top: hole.top,
          height: hole.height, child: const AbsorbPointer()),
    ];
  }
}

class _ScrimPainter extends CustomPainter {
  const _ScrimPainter(this.hole);

  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    // A layer, so `dstOut` has something of its own to punch through rather
    // than clearing whatever the app had already drawn.
    canvas.saveLayer(bounds, Paint());
    canvas.drawRect(bounds, Paint()..color = spotlightScrim);
    if (hole != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(hole!, const Radius.circular(spotlightRadius)),
        Paint()..blendMode = BlendMode.dstOut,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.hole != hole;
}

/// The ring, expanding and fading on a loop — the same nudge the floating
/// coach's head wears, at the size of whatever it is drawn around.
class _Ring extends StatefulWidget {
  const _Ring({required this.colour});

  final Color colour;

  @override
  State<_Ring> createState() => _RingState();
}

class _RingState extends State<_Ring> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    builder: (context, _) {
      final t = _pulse.value;
      return Transform.scale(
        scale: 1 + t * 0.08,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(spotlightRadius),
            border: Border.all(
              color: widget.colour.withValues(alpha: 1 - t),
              width: 2.5,
            ),
          ),
        ),
      );
    },
  );
}

/// The pointing hand, path for path off `Tutorial.js`'s inline SVG — and
/// tapping, which the JS's does not do.
/// **THE WHOLE DRAG CUE**: reach, grab, carry along a dotted line, let go.
///
/// One clock for all of it, which is the same argument [tapCue] makes for the
/// hand and the ripple: four things on four controllers of equal length started
/// a frame apart drift, and a release that fires while the hand is still moving
/// is not a release.
class _DragHand extends StatelessWidget {
  const _DragHand({required this.beat, required this.from, required this.to});

  final Animation<double> beat;

  /// Where the fingertip rests, where it grabs, and where it lets go — all in
  /// the same coordinates the [Stack] is laid out in.
  final Offset from;
  final Offset to;

  /// Where the fingertip is at [t]. See [dragTipAt].
  static Offset tipAt(double t, Offset rest, Offset from, Offset to) {
    if (t < dragGrabAt) {
      return Offset.lerp(rest, from, Curves.easeOut.transform(t / dragGrabAt))!;
    }
    if (t < dragCarryFrom) return from;
    if (t < dragCarryTo) {
      return Offset.lerp(
        from,
        to,
        Curves.easeInOut.transform(
          (t - dragCarryFrom) / (dragCarryTo - dragCarryFrom),
        ),
      )!;
    }
    if (t < dragDropAt + _dragLift) return to;
    // Away, and back to where it started for the next loop.
    return Offset.lerp(
      to,
      rest,
      Curves.easeIn.transform(
        ((t - dragDropAt - _dragLift) / (1 - dragDropAt - _dragLift)).clamp(
          0.0,
          1.0,
        ),
      ),
    )!;
  }

  /// How closed the hand is at [t] — see [_HandPainter.grip] and [dragGripAt].
  static double gripAt(double t) {
    if (t < dragGrabAt) return 0;
    // Shut over the hold between reaching and moving, which is what makes the
    // grab a grab rather than a touch.
    if (t < dragCarryFrom) {
      return Curves.easeOut.transform(
        (t - dragGrabAt) / (dragCarryFrom - dragGrabAt),
      );
    }
    if (t < dragDropAt) return 1;
    // And open again on the release.
    if (t < dragDropAt + _dragLift) {
      return 1 - Curves.easeIn.transform((t - dragDropAt) / _dragLift);
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // It waits below the card it is going to pick up, the way the tap cue waits
    // below its button.
    final rest = from + const Offset(0, 26);
    return AnimatedBuilder(
      animation: beat,
      builder: (context, _) {
        final tip = tipAt(beat.value, rest, from, to);
        return Positioned(
          key: const ValueKey('tutorial-hand'),
          left: tip.dx - handTipInBox.dx,
          top: tip.dy - handTipInBox.dy,
          width: handBox.width,
          height: handBox.height,
          child: IgnorePointer(
            child: CustomPaint(painter: _HandPainter(grip: gripAt(beat.value))),
          ),
        );
      },
    );
  }
}

/// The line the drag runs along, drawn as it is travelled.
///
/// **Dotted, and it GROWS.** Asked for by name. A line that is simply there
/// from the start is a decoration between two cards; one that is drawn ahead of
/// the hand is an instruction, and the dashes are what stop it reading as a
/// connector in a diagram.
class _DragPath extends StatelessWidget {
  const _DragPath({
    required this.beat,
    required this.from,
    required this.to,
    required this.colour,
  });

  final Animation<double> beat;
  final Offset from;
  final Offset to;
  final Color colour;

  /// How much of the line is down at [t], or null before it starts.
  static double? progress(double t) {
    if (t < dragGrabAt) return null;
    if (t < dragCarryFrom) return 0;
    if (t < dragCarryTo) {
      return ((t - dragCarryFrom) / (dragCarryTo - dragCarryFrom)).clamp(
        0.0,
        1.0,
      );
    }
    // It stays up through the release and fades with the hand.
    return 1;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: beat,
    builder: (context, _) {
      final p = progress(beat.value);
      if (p == null) return const SizedBox.shrink();
      return Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            key: const ValueKey('tutorial-drag-path'),
            painter: _DragPathPainter(
              from: from,
              to: to,
              progress: p,
              colour: colour,
            ),
          ),
        ),
      );
    },
  );
}

class _DragPathPainter extends CustomPainter {
  const _DragPathPainter({
    required this.from,
    required this.to,
    required this.progress,
    required this.colour,
  });

  final Offset from;
  final Offset to;
  final double progress;
  final Color colour;

  /// The dash and the gap. Short enough to read as dots at the length these
  /// lines actually run — two cards on one row of the grid.
  static const double _dash = 5;
  static const double _gap = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final line = to - from;
    final length = line.distance * progress;
    if (length <= 0) return;
    final step = line / line.distance;
    final paint = Paint()
      ..color = colour
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var at = 0.0; at < length; at += _dash + _gap) {
      final end = math.min(at + _dash, length);
      canvas.drawLine(from + step * at, from + step * end, paint);
    }
  }

  @override
  bool shouldRepaint(_DragPathPainter old) =>
      old.progress != progress ||
      old.from != from ||
      old.to != to ||
      old.colour != colour;
}

/// The rings, at whichever end of the drag is happening.
class _DragRipple extends StatelessWidget {
  const _DragRipple({
    required this.beat,
    required this.at,
    required this.colour,
  });

  final Animation<double> beat;

  /// When in the beat this end fires — [dragGrabAt] or [dragDropAt].
  final double at;
  final Color colour;

  static double? progress(double t, double at) {
    if (t < at) return null;
    final p = (t - at) / _tapSpread;
    return p > 1 ? null : p;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: beat,
    builder: (context, _) {
      final p = progress(beat.value, at);
      if (p == null) return const SizedBox.shrink();
      return CustomPaint(painter: _RipplePainter(p, colour));
    },
  );
}

class _TapHand extends StatelessWidget {
  const _TapHand({required this.beat, required this.reach});

  final Animation<double> beat;

  /// How far it has to travel to reach the middle of the control.
  final double reach;

  /// How far up the hand is at [t], as a negative offset: it rises to the
  /// button, holds nothing, and drops back.
  static double lift(double t, double reach) {
    if (t < tapContact) {
      return -reach * Curves.easeOut.transform(t / tapContact);
    }
    if (t < tapContact + _tapReturn) {
      return -reach *
          (1 - Curves.easeIn.transform((t - tapContact) / _tapReturn));
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: beat,
    builder: (context, _) => Transform.translate(
      offset: Offset(0, lift(beat.value, reach)),
      child: const CustomPaint(painter: _HandPainter()),
    ),
  );
}

/// The wave a tap leaves behind, at the point the fingertip lands.
class _TapRipple extends StatelessWidget {
  const _TapRipple({required this.beat, required this.colour});

  final Animation<double> beat;
  final Color colour;

  /// How far through the ripple's own life [t] is, or null before it starts.
  static double? progress(double t) {
    if (t < tapContact) return null;
    final p = (t - tapContact) / _tapSpread;
    return p > 1 ? null : p;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: beat,
    builder: (context, _) {
      final p = progress(beat.value);
      if (p == null) return const SizedBox.shrink();
      return CustomPaint(painter: _RipplePainter(p, colour));
    },
  );
}

class _RipplePainter extends CustomPainter {
  const _RipplePainter(this.progress, this.colour);

  final double progress;
  final Color colour;

  /// **TWO rings, in white over a dark backing.** One thin ring in the club's
  /// accent was drawn on top of a button wearing that same accent, so the cue
  /// that says "press this" was the hardest thing on the screen to see — and a
  /// single wave reads as a shape appearing rather than something spreading.
  /// Reported from the couch. The rim is the hand's own white-on-dark, which is
  /// what makes both read over any control and over the dim; the accent stays
  /// as the wash under them.
  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    // The second ring is the same wave, later — so the first one has moved on
    // by the time it appears.
    for (final (i, at) in [progress, progress - _tapSecondRing].indexed) {
      if (at <= 0) continue;
      final radius =
          _ringLeast +
          (tapRippleRadius - _ringLeast) * Curves.easeOut.transform(at);
      final fade = 1 - at;
      if (i == 0) {
        canvas.drawCircle(
          centre,
          radius,
          Paint()..color = colour.withValues(alpha: 0.3 * fade),
        );
      }
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = const Color(0xFF1A1F2E).withValues(alpha: 0.4 * fade),
      );
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..color = Colors.white.withValues(alpha: 0.95 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.progress != progress || old.colour != colour;
}

class _HandPainter extends CustomPainter {
  const _HandPainter({this.grip = 0});

  /// **0 a pointing hand, 1 a closed grab.** Asked for from the couch with the
  /// rest of the drag cue: the hand has to turn into a grab and back again, or
  /// a hand sliding across the screen is a hand pointing at things on its way
  /// past rather than one carrying something.
  ///
  /// It is the INDEX FINGER and nothing else — the three knuckles beside it are
  /// already curled, so bringing the one extended finger down to their line is
  /// the whole difference between the two poses, and it means the palm, the
  /// thumb and the outline are the same drawing throughout.
  final double grip;

  /// The JS's own `viewBox="0 0 40 46"`.
  static const Size _viewBox = Size(40, 46);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _viewBox.width, size.height / _viewBox.height);
    double y(double open, double closed) => open + (closed - open) * grip;
    final knuckle = y(3, 15.5);
    final base = y(7, 18.5);
    final path = Path()
      ..moveTo(13, 21)
      ..lineTo(13, base)
      ..quadraticBezierTo(13, knuckle, 16.5, knuckle)
      ..quadraticBezierTo(20, knuckle, 20, base)
      ..lineTo(20, 19)
      ..quadraticBezierTo(20, 16, 24, 16)
      ..quadraticBezierTo(27, 16, 27, 19)
      ..lineTo(27, 21)
      ..quadraticBezierTo(27, 18, 30, 18)
      ..quadraticBezierTo(33, 18, 33, 21)
      ..lineTo(33, 23)
      ..quadraticBezierTo(33, 21, 35, 21)
      ..quadraticBezierTo(37.5, 21, 37.5, 24)
      ..lineTo(37.5, 33)
      ..quadraticBezierTo(37.5, 42, 26, 42)
      ..lineTo(20, 42)
      ..quadraticBezierTo(13, 42, 9, 37)
      ..lineTo(3.5, 29)
      ..quadraticBezierTo(1.5, 26, 4, 24)
      ..quadraticBezierTo(6.5, 22, 8.5, 25)
      ..lineTo(13, 31)
      ..close();
    // White with a dark outline, which is what makes it read on a dimmed
    // screen AND on whatever colour the control underneath happens to be.
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF1A1F2E),
    );
  }

  @override
  bool shouldRepaint(_HandPainter old) => old.grip != grip;
}
