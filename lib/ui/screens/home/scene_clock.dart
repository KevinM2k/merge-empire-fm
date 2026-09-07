/// One clock for a layer that lives on its own time — the sky's weather, the
/// park's trees — handed to every tile of a strip rather than run per tile.
///
/// **A tile added later ran its own ticker, from zero.** The park strip is one
/// segment repeated across the width and each copy owned a ticker, so a tile
/// added when the screen widened (a fold opening, a late inset) swayed on a
/// younger clock than its neighbours — and at every loop wrap the trees snapped
/// to a different phase. Reported from the couch as the trees jumping. One
/// clock above the row, and the copies cannot disagree.
///
/// **And the step is clamped, as the walk's is.** A ticker muted by `TickerMode`
/// still counts the time it spent muted, so a cloud read off a raw elapsed
/// count leapt a third of the sky the moment a sheet closed. It owes nobody the
/// drift it did not draw.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// The most one frame may advance the clock, in seconds.
const double sceneClockMaxStep = 0.05;

class SceneClock extends StatefulWidget {
  const SceneClock({required this.builder, this.active = true, super.key});

  /// Stopped and held where it froze while false; carries on from there.
  final bool active;

  /// Built once. The layers listen to the clock rather than rebuilding here.
  final Widget Function(BuildContext context, ValueListenable<double> clock)
  builder;

  @override
  State<SceneClock> createState() => _SceneClockState();
}

class _SceneClockState extends State<SceneClock>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _seconds = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(_onTick);

  /// The ticker's elapsed at the last frame; the clock advances on the
  /// difference, so a mute or a restart cannot warp it.
  double _last = 0;

  void _onTick(Duration elapsed) {
    final now = elapsed.inMicroseconds / 1e6;
    _seconds.value += math.min(now - _last, sceneClockMaxStep);
    _last = now;
  }

  void _sync() {
    final run = widget.active && !MediaQuery.disableAnimationsOf(context);
    if (run == _ticker.isActive) return;
    if (run) {
      // A stopped ticker restarts its elapsed at zero.
      _last = 0;
      _ticker.start();
    } else {
      _ticker.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(SceneClock old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _seconds);
}
