/// The period keys, against the JS's own output.
///
/// **The ISO week is exactly the kind of arithmetic a fixture exists for.** A
/// week belongs to the year its THURSDAY falls in, so the first days of January
/// can be week 52 or 53 of the year before — and a board key that disagrees
/// with the shipped app's puts two runtimes' players in different buckets for
/// the same week. Every day of four years is compared, which covers every
/// week-numbering edge there is.
///
/// Dumped with `node` from `_dayKey` / `_weekKey` / `_monthKey` in
/// `../merge-empire-fc/src/services/leaderboardService.js`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/leaderboard_policy.dart';

void main() {
  test('EVERY DAY OF FOUR YEARS AGREES WITH THE JS', () {
    final rows =
        jsonDecode(
              File(
                'test/fixtures/leaderboard_period_keys.json',
              ).readAsStringSync(),
            )
            as List;
    expect(rows, hasLength(greaterThan(1400)));
    for (final raw in rows) {
      final row = raw as Map<String, dynamic>;
      final at = DateTime(row['y'] as int, row['m'] as int, row['d'] as int, 12);
      expect(leaderboardPeriodKey('1d', at), row['day'], reason: '$at');
      expect(leaderboardPeriodKey('7d', at), row['week'], reason: '$at');
      expect(leaderboardPeriodKey('30d', at), row['month'], reason: '$at');
    }
  });
}
