import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/util/time.dart';

void main() {
  tearDown(resetClock);

  group('now', () {
    test('returns a value bracketed by the wall clock', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final result = now();
      final after = DateTime.now().millisecondsSinceEpoch;

      expect(result, greaterThanOrEqualTo(before));
      expect(result, lessThanOrEqualTo(after));
    });

    test('can be overridden for deterministic tests', () {
      setClock(() => 1700000000000);
      expect(now(), 1700000000000);
    });

    test('resetClock restores the wall clock', () {
      setClock(() => 1);
      resetClock();
      expect(now(), greaterThan(1700000000000));
    });
  });

  group('msSince', () {
    test('returns elapsed time for a past timestamp', () {
      setClock(() => 10000);
      expect(msSince(5000), 5000);
    });

    test('returns 0 for a future timestamp', () {
      setClock(() => 10000);
      expect(msSince(19999), 0);
    });

    test('returns 0 for the current instant', () {
      setClock(() => 10000);
      expect(msSince(10000), 0);
    });
  });

  group('formatDuration', () {
    test('formats seconds', () {
      expect(formatDuration(45000), '45s');
    });

    test('formats minutes', () {
      expect(formatDuration(90000), '1m 30s');
    });

    test('formats hours', () {
      expect(formatDuration(7500000), '2h 5m');
    });

    test('formats zero', () {
      expect(formatDuration(0), '0s');
    });

    test('drops sub-second remainders', () {
      expect(formatDuration(1999), '1s');
    });

    test('an exact hour reads 0m', () {
      expect(formatDuration(3600000), '1h 0m');
    });

    test('an exact minute reads 0s', () {
      expect(formatDuration(60000), '1m 0s');
    });
  });

  group('clamp', () {
    test('leaves an in-range value alone', () {
      expect(clamp(5, 0, 10), 5);
    });

    test('raises a value below the floor', () {
      expect(clamp(-5, 0, 10), 0);
    });

    test('lowers a value above the ceiling', () {
      expect(clamp(15, 0, 10), 10);
    });

    test('handles the boundaries themselves', () {
      expect(clamp(0, 0, 10), 0);
      expect(clamp(10, 0, 10), 10);
    });

    test('works with doubles', () {
      expect(clamp(1.5, 0.0, 1.0), 1.0);
    });
  });
}
