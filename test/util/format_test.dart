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
