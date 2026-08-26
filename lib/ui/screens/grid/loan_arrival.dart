/// The loan stars dropping into the grid, one at a time. Ported from
/// `loan-card-enter` and the stagger that drives it in `ui/components/Tutorial.js`.
///
/// **The tutorial's own set-piece, and the port had none of it.** "See My Squad"
/// lends the club whatever it is short of a full eleven, and eight cards simply
/// existed on the next frame — a grid that was three cards deep was suddenly
/// full, with nothing to say where any of it came from. The JS drops each one in
/// half a second behind the last, which is the whole reason the step reads as
/// players ARRIVING rather than as a save being rewritten.
///
/// A card waits invisibly through its own delay — CSS `animation-fill-mode:
/// both`, and it matters: without it the whole loan appears at once and then
/// re-animates in order.
library;

import 'dart:async';

import 'package:flutter/material.dart';

/// The gap between one card starting and the next. The JS's `STAGGER_MS`, and
/// the figure the step was described by: about half a second each, so they flow
/// in rather than land together.
const Duration loanArrivalStagger = Duration(milliseconds: 500);

/// How long one card takes to arrive.
const Duration loanArrivalDuration = Duration(milliseconds: 1200);

/// How long the whole loan takes, for a caller that has to wait for it — the
/// tutorial does not put its next card up until the last player is on the grid.
/// The JS's own `totalMs`, tail included.
Duration loanArrivalWindow(int cards) => cards <= 0
    ? Duration.zero
    : loanArrivalDuration +
          loanArrivalStagger * cards +
          const Duration(seconds: 1);

/// `cubic-bezier(0.34, 1.56, 0.64, 1)` — it overshoots, which is what makes the
/// card land rather than stop.
const Curve _drop = Cubic(0.34, 1.56, 0.64, 1);

/// Where the first keyframe hands over to the second. The JS's `70%`.
const double _settleAt = 0.7;

/// One card falling in, [delay] after the ones before it.
///
/// A null [delay] is a card that is simply there — every card on the grid that
/// is not part of an arriving loan.
class LoanArrival extends StatefulWidget {
  const LoanArrival({super.key, required this.delay, required this.child});

  final Duration? delay;
  final Widget child;

  @override
  State<LoanArrival> createState() => _LoanArrivalState();
}

class _LoanArrivalState extends State<LoanArrival>
    with SingleTickerProviderStateMixin {
  /// **Null for a card that is not arriving, and that is not just tidiness.**
  /// Almost every card on the grid is one, and a `late final` controller is
  /// created by its own `dispose()` — which asks for a `Ticker` off a context
  /// that is already deactivated.
  AnimationController? _fall;
  Timer? _waiting;

  /// **Read ONCE, in `initState`.** The grid rebuilds on every save revision —
  /// which is every second, because idle income ticks — and the arriving set is
  /// derived, so a later rebuild says this card is no longer new. An arrival
  /// that took its cue from the current build would be cut off mid-fall.
  @override
  void initState() {
    super.initState();
    final delay = widget.delay;
    if (delay == null) return;
    final fall = _fall = AnimationController(
      vsync: this,
      duration: loanArrivalDuration,
    );
    if (delay == Duration.zero) {
      fall.forward();
      return;
    }
    _waiting = Timer(delay, () {
      if (mounted) fall.forward();
    });
  }

  @override
  void dispose() {
    _waiting?.cancel();
    _fall?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fall = _fall;
    if (fall == null) return widget.child;
    // Reduce-motion keeps the loan and drops the drop: the players are on the
    // grid, and the card that announced them said so.
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return AnimatedBuilder(
      animation: fall,
      child: widget.child,
      builder: (context, child) {
        final t = fall.value;
        // Two segments with the curve applied to each, as CSS does between
        // adjacent keyframes: down and in, then the overshoot settling out.
        final falling = t <= _settleAt;
        final e = _drop.transform(
          falling ? t / _settleAt : (t - _settleAt) / (1 - _settleAt),
        );
        final opacity = falling ? e.clamp(0.0, 1.0) : 1.0;
        final dy = falling ? -80 + 86 * e : 6 - 6 * e;
        final scale = falling ? 0.55 + 0.51 * e : 1.06 - 0.06 * e;

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
  }
}

/// The gap between one card leaving and the next. The JS's own 40ms — a tenth
/// of the arrival's stagger, because they LEAVE together and arrive one by one.
const Duration loanDepartureStagger = Duration(milliseconds: 40);

/// How long one card takes to go. `loan-card-exit` is `0.35s ease-in`.
const Duration loanDepartureDuration = Duration(milliseconds: 350);

/// The JS's `animDuration`: how long to hold the save still for.
///
/// **Nothing is removed until this has elapsed**, which is the whole shape of
/// the step — a card cannot animate itself out of a grid it has already been
/// deleted from.
Duration loanDepartureWindow(int cards) =>
    cards <= 0 ? Duration.zero : loanDepartureDuration + loanDepartureStagger * cards;

/// Where `loan-card-exit` hands over from its first keyframe to its second.
const double _liftAt = 0.4;

/// One card flying away, [delay] after the ones before it.
///
/// A null [delay] is a card that is staying — every card on the grid that is
/// not part of the loan going home.
class LoanDeparture extends StatefulWidget {
  const LoanDeparture({super.key, required this.delay, required this.child});

  final Duration? delay;
  final Widget child;

  @override
  State<LoanDeparture> createState() => _LoanDepartureState();
}

class _LoanDepartureState extends State<LoanDeparture>
    with SingleTickerProviderStateMixin {
  AnimationController? _leave;
  Timer? _waiting;

  @override
  void initState() {
    super.initState();
    final delay = widget.delay;
    if (delay == null) return;
    final leave = _leave = AnimationController(
      vsync: this,
      duration: loanDepartureDuration,
    );
    if (delay == Duration.zero) {
      leave.forward();
      return;
    }
    _waiting = Timer(delay, () {
      if (mounted) leave.forward();
    });
  }

  @override
  void dispose() {
    _waiting?.cancel();
    _leave?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leave = _leave;
    if (leave == null) return widget.child;
    // Reduce-motion takes the flight and keeps the fact: the cards are gone,
    // and the card that follows says so.
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: leave,
      // `pointer-events: none` on the class — a card on its way out must not
      // answer a drag.
      child: IgnorePointer(child: widget.child),
      builder: (context, child) {
        final t = leave.value;
        final lifting = t <= _liftAt;
        final e = Curves.easeIn.transform(
          lifting ? t / _liftAt : (t - _liftAt) / (1 - _liftAt),
        );
        final opacity = lifting ? 1.0 : (1 - e).clamp(0.0, 1.0);
        final dy = lifting ? -6 * e : -6 + 46 * e;
        final scale = lifting ? 1 + 0.08 * e : 1.08 - 0.68 * e;

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
  }
}
