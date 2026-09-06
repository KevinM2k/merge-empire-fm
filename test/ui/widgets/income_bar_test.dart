/// The card's income bar, and which way it runs.
///
/// **Reported from the couch: a loan's red bar was going the wrong way — it
/// should be full and then run right to left until it is empty, because that is
/// the opposite of money coming in.** It was: the empty rect was pinned to the
/// bar's RIGHT edge, so the end that actually moved was its LEFT one, and that
/// end travelled left-to-right — the same direction of travel as the fill on
/// every other card on the grid. Two bars that move the same way say the same
/// thing, whatever colour they are.
///
/// The geometry is [incomeBarFill] rather than four lines inside a painter's
/// `paint`, so the direction can be asked about here rather than read off a
/// screenshot.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';

const Size bar = Size(90, 5);

void main() {
  group('a signing FILLS', () {
    test('from nothing to the full width', () {
      expect(incomeBarFill(bar, 0, drains: false).width, 0);
      expect(incomeBarFill(bar, 1, drains: false).width, bar.width);
    });

    test('and the end that moves is the RIGHT one, going right', () {
      var last = -1.0;
      for (var t = 0.0; t <= 1.0; t += 0.1) {
        final right = incomeBarFill(bar, t, drains: false).right;
        expect(right, greaterThanOrEqualTo(last), reason: 'at t=$t');
        last = right;
      }
      // The left post never moves, which is what leaves the right end free to
      // carry the meaning.
      for (var t = 0.0; t <= 1.0; t += 0.25) {
        expect(incomeBarFill(bar, t, drains: false).left, 0);
      }
    });
  });

  group('a loan EMPTIES', () {
    test('from the full width to nothing', () {
      // And `t = 0` is the full bar, which is also where the bar parks when
      // the phone is set to reduce motion — a loan is still costing money
      // while nothing is animating.
      expect(incomeBarFill(bar, 0, drains: true).width, bar.width);
      expect(incomeBarFill(bar, 1, drains: true).width, 0);
    });

    test('and the end that moves is the RIGHT one, going LEFT', () {
      // The whole report, in one assertion: the free edge walks the other way.
      var last = bar.width + 1;
      for (var t = 0.0; t <= 1.0; t += 0.1) {
        final right = incomeBarFill(bar, t, drains: true).right;
        expect(right, lessThanOrEqualTo(last), reason: 'at t=$t');
        last = right;
      }
      // Anchored at the same post as the fill. Anchoring it at the other one
      // is what made the two read alike: the rect emptied, but the edge doing
      // the emptying set off in the same direction as the one filling.
      for (var t = 0.0; t <= 1.0; t += 0.25) {
        expect(incomeBarFill(bar, t, drains: true).left, 0);
      }
    });

    test('as the mirror of the fill, frame for frame', () {
      // Same clock, read backwards: at any point in the cycle the two are the
      // same bar, one running out as the other runs in.
      for (var t = 0.0; t <= 1.0; t += 0.125) {
        expect(
          incomeBarFill(bar, t, drains: true).width +
              incomeBarFill(bar, t, drains: false).width,
          closeTo(bar.width, 0.0001),
          reason: 'at t=$t',
        );
      }
    });
  });

  test('a clock past its own ends is held at them', () {
    // The controller is repeating rather than clamped, and a frame delivered
    // at the wrap would otherwise paint a rect wider than the card.
    expect(incomeBarFill(bar, 1.4, drains: false).width, bar.width);
    expect(incomeBarFill(bar, -0.2, drains: false).width, 0);
    expect(incomeBarFill(bar, 1.4, drains: true).width, 0);
    expect(incomeBarFill(bar, -0.2, drains: true).width, bar.width);
  });
}
