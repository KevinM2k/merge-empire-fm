/// Time helpers, ported from `../merge-empire-fc/src/utils/time.js`.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

int _wallClock() => DateTime.now().millisecondsSinceEpoch;

int Function() _clock = _wallClock;

/// Override the clock. Engines read every timestamp through [now], so this is
/// the single seam that makes their tests deterministic — the JS side reaches
/// for `vi.setSystemTime` instead.
void setClock(int Function() clock) => _clock = clock;

void resetClock() => _clock = _wallClock;

int now() => _clock();

/// Never negative: a timestamp in the future reads as no time elapsed.
int msSince(int timestamp) {
  final delta = now() - timestamp;
  return delta > 0 ? delta : 0;
}

String formatDuration(int ms) {
  final totalSeconds = ms ~/ 1000;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  if (minutes > 0) return '${minutes}m ${seconds}s';
  return '${seconds}s';
}

T clamp<T extends num>(T value, T min, T max) =>
    value < min ? min : (value > max ? max : value);
