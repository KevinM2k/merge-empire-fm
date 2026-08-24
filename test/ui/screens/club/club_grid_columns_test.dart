/// How many facility cards go across.
///
/// **The stylesheet has no `minmax` at this size.** The grid used to compute a
/// column count from a `minmax(165px, 1fr)` it said was the JS's, and that rule
/// is nowhere in `screens.css`: `.club-grid` is two columns flat, three from
/// 640, four from 800, and only past 1100 does it measure.
///
/// The arithmetic happened to agree across every width a phone has, which is
/// exactly why a wrong citation can sit unnoticed — it was right by coincidence
/// and would have drifted the first time either number was touched.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/club/club_screen.dart';

void main() {
  test('two across on a phone, whatever the phone', () {
    for (final width in [320.0, 360.0, 390.0, 430.0, 639.0]) {
      expect(AssetGridColumns.at(width), 2, reason: '$width');
    }
  });

  test('three from 640 and four from 800 — the stylesheet\'s own steps', () {
    expect(AssetGridColumns.at(640), 3);
    expect(AssetGridColumns.at(799), 3);
    expect(AssetGridColumns.at(800), 4);
    expect(AssetGridColumns.at(1099), 4);
  });

  test('and past 1100 it MEASURES, which is the only breakpoint that does', () {
    // `auto-fill, minmax(200px, 1fr)`.
    expect(AssetGridColumns.at(1100), greaterThanOrEqualTo(4));
    expect(AssetGridColumns.at(2000), greaterThan(AssetGridColumns.at(1100)));
  });

  test('never fewer than one, however narrow', () {
    expect(AssetGridColumns.at(10), greaterThanOrEqualTo(1));
  });
}
