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

  group('formatClock — the countdown as a readout, not as prose', () {
    // `formatDuration` is the other shape and they are not interchangeable:
    // that one is prose beside a sentence, this is the figure a sign-in popup
    // puts under "available tomorrow" at twice the size.
    test('two digits a field, always', () {
      expect(formatClock(0), '00:00:00');
      expect(formatClock(9000), '00:00:09');
      expect(formatClock(9 * 60 * 1000 + 9000), '00:09:09');
      expect(formatClock(9 * 3600 * 1000), '09:00:00');
    });

    test('and the seconds field is the one that moves', () {
      expect(formatClock(15 * 3600000 + 12 * 60000 + 34000), '15:12:34');
    });

    test('HOURS ARE UNBOUNDED — a clock that rolls into days went backwards', () {
      // 00:14 after showing 1d reads as fourteen minutes left.
      expect(formatClock(49 * 3600 * 1000), '49:00:00');
    });

    test('and an elapsed deadline reads nought, never counts up', () {
      expect(formatClock(-5000), '00:00:00');
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

  group('dateString', () {
    // Reproduces JS `Date.prototype.toDateString()` to the character. Not a
    // display string: the daily ledgers key off it and the key is written to the
    // save, so a different format reads every existing `shop.skipAdDay` as
    // another day and hands the player their allowance back on the next boot.
    //
    // Built from local DateTimes rather than fixed epoch stamps so the test says
    // the same thing in every timezone, which is what the JS does too — it
    // formats local wall-clock time.
    test('matches node, weekday and padded day included', () {
      expect(
        dateString(DateTime(2026, 8, 18, 12).millisecondsSinceEpoch),
        'Tue Aug 18 2026',
      );
      expect(
        dateString(DateTime(2026, 8, 5, 12).millisecondsSinceEpoch),
        'Wed Aug 05 2026',
      );
      expect(
        dateString(DateTime(2026, 1, 1, 12).millisecondsSinceEpoch),
        'Thu Jan 01 2026',
      );
      expect(
        dateString(DateTime(1999, 12, 31, 12).millisecondsSinceEpoch),
        'Fri Dec 31 1999',
      );
    });

    test('every weekday and month name is reachable', () {
      // Sunday is index 0 in the JS name table and 7 in Dart's `weekday`, so a
      // wrong wrap shows up on exactly one day of the week.
      final names = <String>{};
      for (var i = 0; i < 7; i++) {
        names.add(
          dateString(
            DateTime(2026, 3, 1 + i, 12).millisecondsSinceEpoch,
          ).split(' ').first,
        );
      }
      expect(names, {'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'});

      final months = <String>[];
      for (var m = 1; m <= 12; m++) {
        months.add(
          dateString(
            DateTime(2026, m, 15, 12).millisecondsSinceEpoch,
          ).split(' ')[1],
        );
      }
      expect(months, [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ]);
    });

    test('defaults to the clock, which tests can pin', () {
      final at = DateTime(2026, 8, 18, 12).millisecondsSinceEpoch;
      setClock(() => at);
      addTearDown(resetClock);
      expect(dateString(), 'Tue Aug 18 2026');
    });
  });
}
