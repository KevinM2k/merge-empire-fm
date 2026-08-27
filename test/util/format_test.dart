import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/util/format.dart';

/// Every expectation is a value produced by the JS
/// (`../merge-empire-fc/src/utils/format.js`) under node at locale `en`.
/// The quirks are deliberate and preserved: formatCoins(999999) reads
/// "1,000.0k" rather than rolling over to "1.00M".
void main() {
  setUp(resetFormatLocale);

  group('formatCoins', () {
    const cases = <num, String>{
      0: '0',
      1: '1',
      999: '999',
      1000: '1,000',
      9999: '9,999',
      10000: '10.0k',
      12345: '12.3k',
      999999: '1,000.0k',
      1000000: '1.00M',
      1234567: '1.23M',
      999999999: '1,000.00M',
      1000000000: '1.00B',
      1234567890: '1.23B',
    };

    cases.forEach((input, expected) {
      test('$input -> $expected', () {
        expect(formatCoins(input), expected);
      });
    });

    test('floors fractional input', () {
      expect(formatCoins(999.9), '999');
    });
  });

  // **`trim` IS THE PORT'S, NOT THE JS'S**, which is why it is off by default:
  // several fixtures compare a `formatCoins` output field for field and a
  // rolled-over decimal there would be a parity failure rather than a
  // preference. It exists because "52000 coins" on a quest reward chip was
  // reported as a figure the eye has to count digits on, and "52.0k" as reading
  // like a measurement rather than a prize.
  group('formatCoins(trim: true)', () {
    const cases = <num, String>{
      // Under the abbreviation threshold there is no decimal to trim.
      9999: '9,999',
      10000: '10k',
      12345: '12.3k',
      52000: '52k',
      52500: '52.5k',
      1000000: '1M',
      1234567: '1.23M',
      1200000: '1.2M',
      1000000000: '1B',
      1234567890: '1.23B',
    };

    cases.forEach((input, expected) {
      test('$input -> $expected', () {
        expect(formatCoins(input, trim: true), expected);
      });
    });

    test('the untrimmed form is untouched, which is what the fixtures see', () {
      expect(formatCoins(52000), '52.0k');
      expect(formatCoins(1000000), '1.00M');
    });

    test('THE SEPARATOR IS STILL THE LOCALE\'S', () {
      // A `.0` strip would leave German's `52,0k` standing, so the trim is a
      // `NumberFormat` pattern rather than string surgery.
      setFormatLocale('de');
      expect(formatCoins(52000, trim: true), '52k');
      expect(formatCoins(52500, trim: true), '52,5k');
    });
  });

  group('formatCoinsCompact', () {
    const cases = <num, String>{
      0: '0',
      999: '999',
      1000: '1,000',
      99999: '99,999',
      100000: '100k',
      123456: '123k',
      999999: '999k',
      1000000: '1.0M',
      1234567: '1.2M',
      12345678: '12M',
      1000000000: '1.0B',
      1234567890: '1.2B',
      1000000000000: '1.0T',
      1500000000000: '1.5T',
      -1234: '-1,234',
      -1500000: '-1.5M',
    };

    cases.forEach((input, expected) {
      test('$input -> $expected', () {
        expect(formatCoinsCompact(input), expected);
      });
    });

    test('never rounds up across a unit boundary', () {
      // The whole reason it floors: 999,999,999 must read 999M, never 1000M.
      expect(formatCoinsCompact(999999999), '999M');
    });
  });

  group('formatPct', () {
    const cases = <num, String>{
      0: '+0%',
      5: '+5%',
      99: '+99%',
      200: '+200%',
      999: '+999%',
      1000: '+1.0k%',
      1500: '+1.5k%',
      9999: '+10.0k%',
      10000: '+10k%',
      15000: '+15k%',
      999999: '+1,000k%',
      1000000: '+1.0M%',
      2500000: '+2.5M%',
      -200: '-200%',
      -1500: '-1.5k%',
    };

    cases.forEach((input, expected) {
      test('$input -> $expected', () {
        expect(formatPct(input), expected);
      });
    });
  });

  group('formatRate', () {
    // A record list rather than a map: const maps cannot key on doubles.
    const cases = <(num, String)>[
      (0, '0.00/s'),
      (0.05, '0.05/s'),
      (1.5, '1.50/s'),
      (9.99, '9.99/s'),
      (10, '10.0/s'),
      (99.5, '99.5/s'),
      (999, '999.0/s'),
      (1000, '1.0k/s'),
      (12345, '12.3k/s'),
    ];

    for (final (input, expected) in cases) {
      test('$input -> $expected', () {
        expect(formatRate(input), expected);
      });
    }
  });

  group('roundCoins', () {
    const cases = <num?, num>{
      null: 0,
      0: 0,
      5: 5,
      9: 9,
      10: 10,
      55: 55,
      123: 125,
      1250: 1250,
      12345: 12500,
      123456: 125000,
      1234567: 1250000,
      -1234: -1250,
    };

    cases.forEach((input, expected) {
      test('$input -> $expected', () {
        expect(roundCoins(input), expected);
      });
    });

    test('values under 10 keep their exact value', () {
      for (var i = 0; i < 10; i++) {
        expect(roundCoins(i), i);
      }
    });

    test('always returns a whole number, not a double that happens to be whole', () {
      // Coin amounts go straight into the save, and a save is compared byte for
      // byte after a cloud round trip. `75.0` and `75` are equal as numbers and
      // DIFFERENT as JSON, so returning a double here would rewrite every coin
      // field the moment a match paid out.
      for (final n in <num>[0, 5, 9, 9.6, 10, 74.2, 100, 999, 1234, 987654.3]) {
        final rounded = roundCoins(n);
        expect(rounded, isA<int>(), reason: '$n');
        expect(jsonEncode({'coins': rounded}), '{"coins":$rounded}', reason: '$n');
      }
    });
  });

  group('locale', () {
    test('defaults to en', () {
      expect(getFormatLocale(), 'en');
    });

    test('grouping follows the injected locale', () {
      setFormatLocale('de');
      // German groups with a full stop rather than a comma.
      expect(formatCoins(1000), '1.000');
    });

    test('resetFormatLocale restores en', () {
      setFormatLocale('de');
      resetFormatLocale();
      expect(formatCoins(1000), '1,000');
    });
  });
}
