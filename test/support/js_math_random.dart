/// A `math.Random` whose stream is JS `Math.random()`, made reproducible.
///
/// The match engine mixes the seeded gameplay stream with bare `Math.random` —
/// team attribution, the xG roll, the per-match save and tackle counts — and the
/// split is load-bearing, so a parity fixture that pinned only the seeded half
/// would leave a third of the feed uncompared. The node dump replaces
/// `Math.random` with a second mulberry32 and this drives the identical stream on
/// this side, which makes the unseeded half comparable too.
///
/// Bit-for-bit the same algorithm as `util/random.dart`, kept separate because
/// that one is a single global stream and these two must not share state.
library;

import 'dart:math' as math;

class JsMathRandom implements math.Random {
  JsMathRandom(this._seed);

  int _seed;

  static int _imul(int a, int b) => (a * b).toSigned(32);
  static int _ushr(int x, int n) => x.toUnsigned(32) >> n;

  @override
  double nextDouble() {
    _seed = _seed.toSigned(32);
    _seed = (_seed + 0x6d2b79f5).toSigned(32);
    var t = _imul(_seed ^ _ushr(_seed, 15), 1 | _seed);
    // The `^` is what coerces the sum back to int32 in JS, so the truncation
    // belongs on the sum rather than on the xor.
    t = (t + _imul(t ^ _ushr(t, 7), 61 | t)).toSigned(32) ^ t;
    return (t ^ _ushr(t, 14)).toUnsigned(32) / 4294967296;
  }

  /// JS has no integer generator — every call site there is
  /// `Math.floor(Math.random() * n)`, which is exactly this.
  @override
  int nextInt(int max) => (nextDouble() * max).floor();

  @override
  bool nextBool() => nextDouble() < 0.5;
}
