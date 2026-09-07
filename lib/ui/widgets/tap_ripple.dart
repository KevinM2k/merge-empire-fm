/// Rings that follow the finger, anywhere in the app.
///
/// **THE PRESS CUE'S THIRD CHANNEL.** The click and the buzz are fired from the
/// theme's splash factory, which is a Material affordance: it needs an `InkWell`
/// under the finger, so a tap on the pitch, on the crowd, on a card's empty
/// margin gets nothing. This one answers the POINTER, so every tap anywhere is
/// answered whether or not the thing under it was a button. Asked for from the
/// couch, off another game.
///
/// **A LISTENER, NOT A GESTURE DETECTOR, and it is the whole reason this is
/// safe.** A `GestureDetector` competes in the arena — it can win a tap the
/// button underneath wanted, and a flourish that eats presses is a bug rather
/// than a touch. `Listener` never competes: every listener on the hit-test path
/// sees the pointer, and the button still gets its tap.
///
/// **NOT THE TUTORIAL'S RIPPLE, and the two are not one widget waiting to
/// happen.** `tutorial_spotlight.dart` draws rings too, but they belong to the
/// coaching hand: same controller as the finger, aimed at a measured rect,
/// running whether or not anybody has touched the screen. This one has no
/// clock of its own until a pointer arrives and no target but the pointer.
/// Sharing them would mean one painter taking its position from a rect on some
/// frames and from a finger on others.
///
/// **ONE PAINTER, ONE TICKER, AND NO `setState`.** It wraps the entire app, so a
/// rebuild per frame would rebuild the whole tree for a decoration. The ripples
/// are a list the painter holds by reference and the ticker repaints through a
/// `Listenable` — nothing above the `CustomPaint` is ever rebuilt, and the
/// ticker is stopped the moment the last ring dies.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// How long one ripple lives, start to gone.
///
/// **Landed between two reports.** 620ms read as too quick to follow and 900ms
/// read as LAG — which is the more useful of the two, because what lagged was
/// not the pace, it was the tail: a hard ease-out spends its last third barely
/// moving, and a ring that hangs there fading looks like the app is behind the
/// finger rather than answering it. So the life came back down AND the curve
/// came off — see [tapRippleRingRadius].
const Duration tapRippleLife = Duration(milliseconds: 640);

/// The rings in one ripple, and how far apart they set off.
///
/// **TWO, not three.** Three inside twenty points is a thicket — they overlap
/// for most of the life and read as one fat blurred circle, which is the same
/// report as "too many" and "hard to see" at once. Two with a longer gap have
/// room to be seen as two.
const int tapRippleRings = 2;
const double tapRippleStagger = 0.26;

/// Where a ring starts and stops, in logical pixels.
///
/// **SMALL. It is a touch, not a splash.** The first pass ran to 64 points —
/// most of the width of a button — and reported back from the couch as far too
/// big: rings that wide stop reading as a response to the finger and start
/// reading as something the screen did. This is about a fingertip's width all
/// in, so the ripple stays under the hand that made it.
const double tapRippleStart = 3;
const double tapRippleSpread = 19;

/// The most that can be alive at once. A drum-roll of taps is the case: past
/// this the oldest is dropped rather than the newest refused, because the ring
/// under the finger NOW is the one the player is looking at.
const int tapRippleMax = 6;

/// How far through its life ring [index] of a ripple at [t] is, or null when it
/// has not set off yet or is already gone.
///
/// A function so the stagger can be asserted without a screen: the arithmetic is
/// the whole of the effect and none of it needs a ticker.
double? tapRippleRingProgress(double t, int index) {
  final delay = index * tapRippleStagger;
  final span = 1 - (tapRippleRings - 1) * tapRippleStagger;
  final p = (t - delay) / span;
  return p < 0 || p > 1 ? null : p;
}

/// The ring's radius at [p], easing out — fast off the finger, still moving at
/// the edge. `easeOut`, not `easeOutCubic`: the cubic is 95% of the way there at
/// two thirds of the life, so the rest of it is a stationary ring fading, which
/// is what read as lag.
double tapRippleRingRadius(double p) =>
    tapRippleStart + Curves.easeOut.transform(p) * tapRippleSpread;

/// And its opacity, which is gone before the radius stops moving.
///
/// **Half again as strong as the first pass**, which peaked at 0.5 and was
/// reported as hard to see. It fades on a square law rather than linearly, so
/// the ring is at its most legible where it starts — under the finger — and
/// still leaves quietly.
double tapRippleOpacity(double p) => (1 - p) * (1 - p) * 0.85;

class _Ripple {
  _Ripple(this.at, this.born);

  final Offset at;
  final Duration born;
}

/// Wraps the app. Draws over it, never takes a press off it.
class TapRipples extends StatefulWidget {
  const TapRipples({required this.child, this.enabled = true, super.key});

  final Widget child;

  /// The player's switch — see `tapRipplesEnabledProvider`. Turning it off
  /// leaves the listener in place and spawns nothing, so there is no second
  /// tree shape to be wrong about.
  final bool enabled;

  @override
  State<TapRipples> createState() => _TapRipplesState();
}

class _TapRipplesState extends State<TapRipples>
    with SingleTickerProviderStateMixin {
  final List<_Ripple> _live = <_Ripple>[];

  /// What the painter repaints on. The value is the frame's elapsed time, which
  /// is also what every ripple's age is measured against.
  final ValueNotifier<Duration> _now = ValueNotifier<Duration>(Duration.zero);

  /// **BUILT IN `initState`, not lazily.** `createTicker` reads `TickerMode`
  /// off the element, so a ticker made for the first time in `dispose` — which
  /// is what a screen that was never tapped would do — looks up an ancestor of
  /// a widget that has already been deactivated.
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _live.removeWhere((r) => elapsed - r.born > tapRippleLife);
      _now.value = elapsed;
      // Nothing left to draw. A ticker running over a still screen is a
      // frame's work every frame, for nothing.
      if (_live.isEmpty) _ticker.stop();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _now.dispose();
    super.dispose();
  }

  void _spawn(Offset at) {
    if (!widget.enabled) return;
    // **The one accessibility switch this has to read.** "Reduce motion" is a
    // request not to animate, and a decoration is exactly what it is for.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    if (!_ticker.isActive) {
      // **A RESTARTED TICKER COUNTS FROM ZERO AGAIN**, so a ripple born against
      // the last run's clock would sit in the future and never draw. The list is
      // empty whenever the ticker is stopped, so zeroing here is the whole fix.
      _now.value = Duration.zero;
      _ticker.start();
    }
    if (_live.length >= tapRippleMax) _live.removeAt(0);
    _live.add(_Ripple(at, _now.value));
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Listener(
      // The app fills the window, so this is only ever reached where nothing
      // else was hit — but a tap on a gap is still a tap.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) => _spawn(event.localPosition),
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          // **`IgnorePointer`, or the decoration becomes a barrier**: a
          // `CustomPaint` filling the window absorbs every press under it.
          IgnorePointer(
            child: CustomPaint(
              painter: _RipplePainter(
                ripples: _live,
                now: _now,
                colour: kit.accentBright,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// **THE GROUND UNDER THIS IS UNKNOWABLE, so the ring carries its own
/// contrast.** It draws over every screen in the app — a card, a light page,
/// and the match's dark green pitch, which is where it was reported as nearly
/// invisible. Nothing at the top of the tree can know what is beneath the
/// finger: the pitch is a dark takeover under a theme that may well be light,
/// so reading the ambient brightness would answer for the page rather than for
/// the grass.
///
/// So every ring is two strokes: a dark halo, then the ring itself lifted most
/// of the way to white. That is `coin_figure`'s answer in another place — you
/// cannot fix a colour you cannot see by tinting it, you buy the contrast from
/// what is behind it — and it keeps a trace of the kit rather than dropping the
/// palette rule outright.
const double _haloWidth = 2.2;
const double _haloAlpha = 0.42;
const double _towardsWhite = 0.7;

/// The kit's accent, lifted far enough towards white that no club's colour can
/// sink into what it is drawn on. A function so the floor can be asserted for
/// a green kit on green grass, which is the case that was reported.
///
/// **Seven tenths of the way, and it was measured rather than guessed**: at
/// six the deepest kits — the maroon, the near-black — come out at 0.38
/// luminance, which is a mid grey and exactly the ring that was lost. The trace
/// of the club left at seven is enough to tell two kits apart side by side.
Color tapRippleInk(Color accent) =>
    Color.lerp(accent, const Color(0xFFFFFFFF), _towardsWhite)!;

class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.ripples,
    required this.now,
    required this.colour,
  }) : ink = tapRippleInk(colour),
       super(repaint: now);

  /// Held BY REFERENCE — the state mutates this list and the painter reads it
  /// on the next repaint, which is what keeps the widget out of `setState`.
  final List<_Ripple> ripples;
  final ValueListenable<Duration> now;
  final Color colour;

  /// [colour] lifted towards white — see the note above.
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final elapsed = now.value;
    for (final ripple in ripples) {
      final age =
          (elapsed - ripple.born).inMicroseconds /
          tapRippleLife.inMicroseconds;
      if (age < 0 || age > 1) continue;
      for (var i = 0; i < tapRippleRings; i++) {
        final p = tapRippleRingProgress(age, i);
        if (p == null) continue;
        final radius = tapRippleRingRadius(p);
        // The trailing ring is the fainter and the thinner, so the ripple has a
        // front rather than reading as two unrelated circles. The line thins as
        // it goes: a 2.4pt stroke on a 20pt circle is a blob.
        final width = 1.7 * (1 - p) + 0.5;
        final alpha = tapRippleOpacity(p) * (1 - i * 0.15);
        canvas.drawCircle(
          ripple.at,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width + _haloWidth
            ..color = const Color(0xFF000000).withValues(
              alpha: alpha * _haloAlpha,
            ),
        );
        canvas.drawCircle(
          ripple.at,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width
            ..color = ink.withValues(alpha: alpha),
        );
      }
    }
  }

  // The list and the clock are the same objects every frame; `repaint` is what
  // actually drives this, so a rebuild only ever changes the colour.
  @override
  bool shouldRepaint(_RipplePainter old) => old.colour != colour;
}
