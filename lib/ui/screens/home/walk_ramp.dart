/// The walking world's one clock, and the ease that brings it to a stop.
///
/// Ported from `LeagueScreen._rampWalk` and `PitchBallSim._stepWalk`. He plants
/// his feet for a `stops` gesture and the world has to stop travelling past him
/// — but he does not BRAKE, he eases off, which is the whole reason the JS does
/// this in script rather than in CSS: `animation-play-state` is binary and there
/// is nothing between running and paused.
///
/// Two things live here, and they are one idea.
///
/// **[WalkRamp] is the ease, as a pure function of the frame's timestamp.**
/// Not an accumulation: his legs, the strips he walks past and the stray ball
/// all have to agree about how fast the world is going, and two accumulations of
/// one number drift apart. Given the same `now` it returns the same rate and the
/// same distance to every caller, for ever.
///
/// **[WalkBeat] is the clock itself**, published once for the whole diorama.
/// Every layer used to own a controller and they were kept together by all
/// starting in the same frame — which held only because a stop restarted every
/// one of them from zero. A ramp cannot restart anything (his stride has to
/// continue THROUGH the slow-down, not snap back to the top of the cycle), so
/// the clock is shared instead of merely synchronised.
library;

import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// How long he takes to come to a stop, and to get going again.
///
/// The JS's `HALT_RAMP_MS`, and its reasoning: long enough to read as easing off
/// rather than braking, short enough that a 2.2s bow is still mostly a bow.
const Duration haltRamp = Duration(milliseconds: 380);

/// The walk's playback rate as it eases between walking and stopped.
///
/// Everything that exists only because he is moving reads this: his gait, every
/// strip that scrolls past him, and the stray ball's turf speed. A gesture's own
/// one-shot — the bow itself — is deliberately NOT ramped, so he folds at full
/// speed while the world behind him winds down.
@immutable
class WalkRamp {
  const WalkRamp({
    required this.from,
    required this.target,
    required this.since,
    required this.banked,
    this.ramp = haltRamp,
  });

  /// Walking at full pace, with nothing banked yet.
  const WalkRamp.walking()
    : from = 1,
      target = 1,
      since = 0,
      banked = 0,
      ramp = haltRamp;

  /// The rate the current ramp started from, and the one it is heading for.
  /// Both are playback rates: 1 walking, 0 stopped dead.
  final double from;
  final double target;

  /// When the ramp began, in the same seconds [rateAt] will be asked about.
  final double since;

  /// Walking-seconds already banked when it began. The ramp only describes what
  /// has happened since; this carries everything before it.
  final double banked;

  /// How long the ease takes.
  final Duration ramp;

  double get _rampSeconds => ramp.inMicroseconds / 1e6;

  /// How far through the ease [now] is, 0 to 1.
  double _progress(double now) {
    final r = _rampSeconds;
    if (r <= 0) return 1;
    final k = (now - since) / r;
    return k <= 0 ? 0 : (k >= 1 ? 1 : k);
  }

  /// The playback rate at [now].
  ///
  /// **Ease-out**: most of the speed goes early and the last of it trails off,
  /// which is how somebody stops walking. Linear reads as a machine winding
  /// down.
  double rateAt(double now) {
    final k = _progress(now);
    return from + (target - from) * (1 - (1 - k) * (1 - k));
  }

  /// Walking-seconds elapsed by [now] — real seconds with the rate applied, so
  /// a world at half speed banks half a second per second.
  ///
  /// The closed-form integral of [rateAt] rather than a sum of frames, which is
  /// what lets two readers agree exactly. Over the ease itself the mean rate is
  /// `from + 2(target - from)/3`; past it the world runs at [target].
  double walkedAt(double now) {
    final r = _rampSeconds;
    final k = _progress(now);
    final d = target - from;
    // ∫₀ᴷ (1-k)² dk = (1 - (1-K)³)/3.
    final under = (1 - (1 - k) * (1 - k) * (1 - k)) / 3;
    var walked = banked + r * (from * k + d * (k - under));
    if (k >= 1) walked += (now - since - r) * target;
    return walked;
  }

  /// Aim at a new rate from wherever the ease has got to.
  ///
  /// Reversing mid-ramp starts from the CURRENT rate rather than from the last
  /// target, so a gesture cut short by a tap winds back up from the speed he was
  /// actually walking at instead of snapping to a stop first.
  WalkRamp aim(double next, double now, {Duration ramp = haltRamp}) {
    if (next == target && from == target) return this;
    return WalkRamp(
      from: rateAt(now),
      target: next,
      since: now,
      banked: walkedAt(now),
      ramp: ramp,
    );
  }
}

/// The diorama's walk clock: how many HALF-strides he has taken.
///
/// Half-strides rather than whole ones because that is the unit the ground is
/// solved in — `groundEase` is the integral of one supporting foot's velocity
/// across one stance — while the figure wants the full cycle. Both come off this
/// one number, so the grass under his boot cannot drift from his boot.
///
/// Whole part is strides taken; fraction is where he is in the current one.
class WalkBeat extends InheritedNotifier<ValueNotifier<double>> {
  const WalkBeat({required super.notifier, required super.child, super.key});

  /// The scene's clock, or null when there is no scene — the customiser's chip
  /// and the widget tests both build a walker with no diorama around it, and he
  /// falls back to a clock of his own there.
  ///
  /// **A LOOKUP, not a dependency.** `dependOnInheritedWidgetOfExactType` on an
  /// `InheritedNotifier` rebuilds the caller on every tick, and every caller
  /// already listens to the notifier itself — so the whole rig was being
  /// rebuilt, art re-parsed, once a frame for a number its painter was going
  /// to read anyway.
  static ValueNotifier<double>? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<WalkBeat>()?.notifier;
}

/// A walk clock for a walker with no diorama around it.
///
/// **The customiser's preview is exactly that**, and it falls back to a clock of
/// its own — which is fine until something ELSE in the same box has to agree with
/// him. The backdrop behind him does: he walks in place and the world moves past
/// him, so a backdrop that holds still is a man on a treadmill.
///
/// No ramp, because nothing in a preview halts him: he is being dressed, not
/// managing. What it publishes is the same [WalkBeat] the diorama publishes, so
/// [ManagerWalker] picks it up without knowing which of the two it is in.
class WalkClock extends StatefulWidget {
  const WalkClock({required this.stride, required this.child, super.key});

  /// How long one full stride takes. The mood's own, from `walkDurationFor`.
  final Duration stride;

  final Widget child;

  @override
  State<WalkClock> createState() => _WalkClockState();
}

class _WalkClockState extends State<WalkClock>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _halfStrides = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(_onTick);
  double _last = 0;

  void _onTick(Duration elapsed) {
    final now = elapsed.inMicroseconds / 1e6;
    // **Clamped, like the diorama's own.** A ticker muted by `TickerMode` still
    // counts the time it spent muted, so a sheet reopened after a minute
    // elsewhere would hand the world a minute of travel in one frame.
    final step = math.min(now - _last, 0.05);
    _last = now;
    final halfStrideSeconds = widget.stride.inMicroseconds / 2e6;
    if (halfStrideSeconds > 0) _halfStrides.value += step / halfStrideSeconds;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Perpetual movement is exactly what reduce-motion exists to stop.
    if (MediaQuery.of(context).disableAnimations) {
      if (_ticker.isActive) _ticker.stop();
      return;
    }
    if (!_ticker.isActive) {
      _last = 0;
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _halfStrides.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      WalkBeat(notifier: _halfStrides, child: widget.child);
}
