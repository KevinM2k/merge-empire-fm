/// Seeded PRNG, ported from `../merge-empire-fc/src/utils/random.js`.
///
/// The stream must match the JS original draw for draw: match simulation, cup
/// brackets and scout draws all run off it, and the differential tests compare
/// Dart output against node output on shared seeds.
///
/// That parity is the reason for all the explicit masking below. JS bitwise
/// operators coerce to int32 and `>>>` to uint32, while Dart ints are 64-bit —
/// so every step JS performs implicitly is spelled out here. `test/util/
/// random_test.dart` pins the result against reference values from node,
/// including the seeds where the wrap actually bites (-1, INT32_MIN, INT32_MAX).
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

/// Seeded off the wall clock, matching the JS module's `let seed = Date.now()`.
int _seed = DateTime.now().millisecondsSinceEpoch.toSigned(32);

/// `Math.imul` — a 32-bit signed multiply.
///
/// Both operands are int32, so the product needs at most 63 bits and fits a
/// Dart int on native before truncation.
int _imul(int a, int b) => (a * b).toSigned(32);

/// JS `x >>> n` — an unsigned 32-bit shift.
int _ushr(int x, int n) => x.toUnsigned(32) >> n;

double _mulberry32() {
  _seed = _seed.toSigned(32);
  _seed = (_seed + 0x6d2b79f5).toSigned(32);
  var t = _imul(_seed ^ _ushr(_seed, 15), 1 | _seed);
  // JS: t = (t + Math.imul(...)) ^ t — the `^` is what coerces the sum back to
  // int32, so the truncation belongs on the sum, not on the xor.
  t = (t + _imul(t ^ _ushr(t, 7), 61 | t)).toSigned(32) ^ t;
  return (t ^ _ushr(t, 14)).toUnsigned(32) / 4294967296;
}

void setSeed(int s) => _seed = s;

/// Run [fn] off a known seed, then put the shared stream back exactly where it
/// was. For anything that must come out the SAME every time it is computed — a
/// table the UI rebuilds on every render, say — while leaving gameplay's own
/// randomness untouched. Restores the seed even if [fn] throws.
T withSeed<T>(int s, T Function() fn) {
  final prev = _seed;
  _seed = s;
  try {
    return fn();
  } finally {
    _seed = prev;
  }
}

double random() => _mulberry32();

/// Inclusive of both [min] and [max].
int randomInt(int min, int max) =>
    (random() * (max - min + 1)).floor() + min;

/// One entry in a [weightedPick] pool.
class WeightedEntry<T> {
  const WeightedEntry(this.item, this.weight);

  final T item;
  final num weight;
}

/// Picks one item from [pool] using its weights.
T weightedPick<T>(List<WeightedEntry<T>> pool) {
  final total = pool.fold<num>(0, (sum, e) => sum + e.weight);
  var r = random() * total;
  for (final entry in pool) {
    r -= entry.weight;
    if (r <= 0) return entry.item;
  }
  return pool.last.item;
}

T pickRandom<T>(List<T> arr) => arr[(random() * arr.length).floor()];

/// Fisher-Yates, walking downward exactly as the JS does — the direction and
/// the `i + 1` bound are what make the permutation match.
List<T> shuffle<T>(List<T> arr) {
  final a = [...arr];
  for (var i = a.length - 1; i > 0; i--) {
    final j = (random() * (i + 1)).floor();
    final tmp = a[i];
    a[i] = a[j];
    a[j] = tmp;
  }
  return a;
}
