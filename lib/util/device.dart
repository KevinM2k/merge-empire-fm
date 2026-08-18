/// Low-end device detection, as policy. Ported from the pure half of
/// `../merge-empire-fc/src/utils/device.js`.
///
/// It gates cosmetic-only GPU work: backdrop blur, crowd density, particle
/// counts, the walk-cycle frame rate. Two independent signals feed it, and only
/// their ARITHMETIC lives here — reading the hardware and driving the frame
/// probe are platform jobs and belong to the services and UI layers:
///
/// 1. A STATIC hardware heuristic ([isLowEndHardware]) — cheap and available
///    before first paint, but conservative. Both numbers are absent on iOS,
///    where the hardware copes fine, so missing values mean "not low-end". It
///    requires BOTH cores AND memory to be weak, because desktop browsers bucket
///    memory low — often reporting 4GB on a strong machine — and memory alone
///    false-flagged capable desktops and thinned their crowds.
/// 2. A RUNTIME frame-rate probe ([slowFrameFraction] and [isStruggling]) —
///    catches the large class of cheap Android phones the static check misses.
///    A big.LITTLE chip reports eight cores while being far slower than a
///    four-core desktop, so a 2GB octa-core budget tablet looks capable to the
///    heuristic and then stutters. Measuring delivered frames is the only
///    reliable way to tell those apart.
///
/// The promotion is ONE-WAY: once a device is marked low-end it stays that way
/// for the session. Flipping back and forth would rebuild crowds and swap
/// animation timing mid-play, which reads as a glitch.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

/// A frame slower than this missed its slot at 60Hz — the 16.7ms budget plus
/// headroom.
const double slowFrameMs = 24;

/// The share of slow frames in one window that means the device is struggling.
///
/// Deliberately high: a couple of janky frames are normal anywhere, and only a
/// sustained inability to keep up should count.
const double slowFrameRatio = 0.35;

/// The length of one sample window — long enough to average over a scroll or an
/// animation, short enough that the probe itself is a rounding error.
const int sampleMs = 2500;

/// Boot is inherently janky: parsing, first paint, art decode. Waiting for it to
/// settle is what stops every device looking low-end.
const int firstSampleDelayMs = 5000;

/// A second window, in case the first landed during an unlucky quiet moment.
const int secondSampleDelayMs = 25000;

/// Below this many frames a window says nothing worth acting on.
const int minSampleFrames = 20;

/// Frames longer than this are not steady-state rendering at all — a
/// backgrounded tab, or a modal blocking the thread for seconds.
const double absurdFrameMs = 500;

/// The static hardware heuristic.
///
/// [memoryGb] and [cores] are what the platform reports, and null for a platform
/// that will not say. Very low memory is decisive on its own: no desktop reports
/// 2GB or less.
bool isLowEndHardware({num? memoryGb, num? cores}) {
  if (memoryGb != null && memoryGb <= 2) return true;
  return (memoryGb != null && memoryGb <= 4) && (cores != null && cores <= 4);
}

/// The fraction of one window's frames that missed their slot, or null when the
/// window says nothing.
///
/// [deltas] is the gap between consecutive frames, in milliseconds. Absurd gaps
/// are dropped rather than counted, and a window with too few usable frames
/// comes back null so the caller does not judge a device on it.
double? slowFrameFraction(Iterable<num> deltas) {
  var total = 0;
  var slow = 0;
  for (final dt in deltas) {
    if (dt >= absurdFrameMs) continue;
    total++;
    if (dt > slowFrameMs) slow++;
  }
  return total >= minSampleFrames ? slow / total : null;
}

/// Whether a window's verdict promotes the device.
///
/// An inconclusive window — too few frames, or the app was in the background —
/// never promotes: the JS returns null for both, and null is not a complaint.
bool isStruggling(double? fraction) =>
    fraction != null && fraction >= slowFrameRatio;
