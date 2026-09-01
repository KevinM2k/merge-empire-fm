/// Which way the game is going, drawn on the pitch it is going on.
///
/// **The pitch used to come and go.** It was mounted only for a chance and taken
/// away after, and what stood in its place between chances was the statistics —
/// so the band flipped between a football pitch and a table of numbers every few
/// minutes. The pitch stays now, and this is what it shows when nothing is
/// happening on it: one arrow, pointing at the goal the run of play is heading
/// for, sliding toward that goal as the pressure builds and turning round when
/// the game does.
///
/// It is a READING, not a simulation. Nothing here decides anything — the match
/// was over before the screen opened — and the only input is the same possession
/// figure the stat board prints.
library;

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// The two shades the arrow is drawn in, both taken off `PitchBackdrop.turf`
/// (`#2D6A2D`). Ours reads as a lit stripe, theirs as a shadow on the same
/// grass — one colour each, and neither of them see-through.
const Color momentumOurs = Color(0xFF4E9C4A);
const Color momentumTheirs = Color(0xFF1C4A22);

/// How much of the game is OURS, from -1 (all theirs) to 1 (all ours).
///
/// [dangerHome] is where the CHANCES are coming from, home-positive — see
/// `LiveStats.dangerHome`. **Not possession**, which is the bug this arrow had:
/// possession carries the tactic and the chance attribution does not, so the
/// arrow could point hard one way while the chances went on falling the other.
///
/// The old doc, for the figure it used to read: the stat board's own possession,
/// home-positive and already
/// clamped to 28–72; [isHome] turns that into our share. It says nothing about
/// which way the arrow points — that is [MomentumArrow.attackingRight], because
/// which end we are shooting at is a fact about the fixture rather than about
/// who is on top.
double momentumBias({required double dangerHome, required bool isHome}) {
  final ourShare = isHome ? dangerHome : 100 - dangerHome;
  return ((ourShare - 50) / _biasSpan).clamp(-1.0, 1.0);
}

/// **EIGHTEEN, not twenty-two.** `dangerHome` is clamped to 20–80, so a
/// denominator of 22 asked for the very edge of that range before the arrow
/// went anywhere near full pressure — and a real match sits inside about ±12 of
/// level, which came out as a third of the arrow's travel. Reported from the
/// couch as needing to move left and right a good deal more. Eighteen puts a
/// 68/32 spell of chances at full stretch, which is a side genuinely on top.
const double _biasSpan = 18;

/// The arrow, and the glide between two readings.
///
/// Animated rather than snapped: possession moves on every chance, and an arrow
/// that jumps reads as a bug rather than as a game swinging.
class MomentumArrow extends StatelessWidget {
  const MomentumArrow({
    required this.bias,
    required this.attackingRight,
    required this.ours,
    required this.theirs,
    super.key,
  });

  /// From [momentumBias]. Positive is US on top, whichever way we are kicking.
  final double bias;

  /// Which way OUR goals go. **At home we attack right and away we attack
  /// left** — the same rule the 2D pitch follows, so the arrow and the passage
  /// of play it turns into cannot point opposite ways.
  final bool attackingRight;

  /// The colour of a move going our way, and of one going theirs.
  final Color ours;
  final Color theirs;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: attackingRight ? bias : -bias),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => CustomPaint(
        key: const ValueKey('match-momentum'),
        size: Size.infinite,
        painter: _ArrowPainter(
          bias: t,
          // Whose move it is, which is NOT which way it is going: away from
          // home, our best spell points left.
          ours: attackingRight ? ours : theirs,
          theirs: attackingRight ? theirs : ours,
        ),
      ),
    ),
  );
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({
    required this.bias,
    required this.ours,
    required this.theirs,
  });

  final double bias;
  final Color ours;
  final Color theirs;

  /// How far off the halfway line the arrow gets at full pressure, as a share
  /// of the pitch. Kept short of the box, so at its furthest it is still a
  /// reading of territory rather than a marker on the goal.
  ///
  /// **0.26 was not enough to read as movement**, and it compounded with the
  /// bias's own span: a realistic spell gave about half a bias, and half of 26%
  /// of the pitch is a shift of a dozen points on a phone — an arrow that
  /// technically moves. Reported from the couch. See [_biasSpan] for the other
  /// half of it.
  static const double travel = 0.34;

  @override
  void paint(Canvas canvas, Size size) {
    final right = bias >= 0;
    final strength = bias.abs();
    // **OPAQUE, and ONE colour.** It was the kit at 30–75% alpha, so the mown
    // stripes ran straight through it and the arrow read as a smear rather than
    // as a mark on the grass. A solid shade of the turf itself is what a pitch
    // graphic actually looks like — ours a shade lighter than the grass, theirs
    // a shade darker, so which way the game is going is legible before the
    // direction is.
    final colour = right ? ours : theirs;

    // **AN ARROW THAT MOVES, not a half of the pitch shaded in.** The old
    // wedge was anchored on the attacking side's own goal-line and reached
    // toward the other end — so with us on top it darkened OUR half, and the
    // more we pressed the more of our own end it covered. Read from the couch
    // as pointing the wrong way, which in effect it was. This one sits on the
    // halfway line when the game is level, points at the goal under pressure,
    // and SLIDES toward it as the pressure builds: their spell is an arrow
    // coming at our goal, and when we take over it turns round and goes back
    // up the pitch at theirs.
    final dir = right ? 1.0 : -1.0;
    // Never nothing. A dead-level game is still a game being played, and an
    // empty pitch reads as a screen that has stopped working — so the arrow
    // has a floor length and grows with the swing.
    final span = size.width * (0.16 + 0.20 * strength);
    // **AND THE POINT STAYS ON THE PITCH.** With [travel] opened up, a full
    // spell put the tip past the goal line — an arrow half off the grass reads
    // as a drawing error rather than as pressure. It presses right up to the
    // six-yard box and stops.
    final room = size.width * 0.97 - span / 2;
    final cx = (size.width / 2 + dir * size.width * travel * strength).clamp(
      size.width - room,
      room,
    );
    final head = span * 0.36;
    final top = size.height * 0.16;
    final bottom = size.height - top;
    final mid = size.height / 2;
    final tail = cx - dir * span / 2;
    final tip = cx + dir * span / 2;
    final shoulder = tip - dir * head;

    final arrow = Path()
      ..moveTo(tail, top)
      ..lineTo(shoulder, top)
      ..lineTo(tip, mid)
      ..lineTo(shoulder, bottom)
      ..lineTo(tail, bottom)
      // The notch that makes it an arrow rather than a house on its side.
      ..lineTo(tail + dir * head * 0.45, mid)
      ..close();

    // Solid at the point, fading back along the shaft: the tip is the reading
    // and the shaft is where it came from.
    canvas.drawPath(
      arrow,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(tail, 0),
          Offset(tip, 0),
          [
            colour.withValues(alpha: 0.22 + 0.18 * strength),
            colour.withValues(alpha: 0.62 + 0.30 * strength),
          ],
        ),
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.bias != bias || old.ours != ours || old.theirs != theirs;
}
