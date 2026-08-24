/// Whether this device is struggling — the half of `utils/device.js` that has
/// to touch the platform.
///
/// **`util/device.dart` was ported, fixture-tested against the JS and called by
/// NOTHING.** Every threshold matched, the one-way promotion was implemented,
/// the parity harness compared seven constants — and no widget ever asked. The
/// whole policy it exists to serve was inert: `glass.css` names the backdrop
/// blur as the thing that most wants the opt-out ("on screen for a whole match
/// with a 2D clip playing over them"), and every pane blurred regardless.
///
/// **The promotion is ONE-WAY, which is the rule the engine states and the
/// reason this is a notifier rather than a stream.** Flipping back and forth
/// would rebuild crowds and swap animation timing mid-play, which reads as a
/// glitch rather than as an optimisation.
///
/// **The frame probe runs twice and then stops.** The JS's own delays — five
/// seconds in, then twenty-five — because a device is slowest while it is still
/// warming up, and a probe that kept sampling would be a permanent cost paid to
/// answer a question that has already been answered.
library;

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/util/device.dart';

/// Whether the cosmetic GPU work should be turned down.
final lowEndDeviceProvider = NotifierProvider<LowEndDevice, bool>(
  LowEndDevice.new,
);

/// Reads the hardware, when the platform will say. Null for either figure means
/// "not low-end" — see [isLowEndHardware], and the reason both are absent on
/// iOS.
typedef HardwareReading = ({num? memoryGb, num? cores});

/// The seam. Flutter exposes neither figure, so the default answers nothing at
/// all and the runtime probe carries the whole job — which is the signal the
/// JS's own comment says catches the class the static check misses anyway.
HardwareReading Function() readHardware = () => (memoryGb: null, cores: null);

class LowEndDevice extends Notifier<bool> {
  Timer? _first;
  Timer? _second;
  final List<num> _deltas = [];
  bool _sampling = false;

  @override
  bool build() {
    final hardware = readHardware();
    ref.onDispose(_stop);
    if (isLowEndHardware(
      memoryGb: hardware.memoryGb,
      cores: hardware.cores,
    )) {
      // Already answered. No probe: measuring a device we have decided about
      // is a cost with no outcome.
      return true;
    }
    _first = Timer(const Duration(milliseconds: firstSampleDelayMs), _sample);
    _second = Timer(const Duration(milliseconds: secondSampleDelayMs), _sample);
    return false;
  }

  void _stop() {
    _first?.cancel();
    _second?.cancel();
    if (_sampling) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      _sampling = false;
    }
  }

  /// Watch the delivered frames for one window, then decide.
  void _sample() {
    if (state || _sampling) return;
    _sampling = true;
    _deltas.clear();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    Timer(const Duration(milliseconds: sampleMs), () {
      if (!_sampling) return;
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      _sampling = false;
      // **One way.** Once it is true it never goes back.
      if (isStruggling(slowFrameFraction(_deltas))) state = true;
    });
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      // **`totalSpan` is the whole frame, build AND raster** — which is what
      // the JS measures too: it times the gap between animation callbacks, so
      // a frame that built fast and rasterised slowly still counts against the
      // budget. Taking only one half would call a GPU-bound device healthy.
      _deltas.add(timing.totalSpan.inMicroseconds / 1000);
    }
  }
}
