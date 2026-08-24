/// The pitch fills the band it is given, on every screen shape.
///
/// **Reported four times as the pitch looking letterboxed**, and the first
/// three passes each found something real without ending it. The reason they
/// could all be right and the report still stand is that the band the match
/// screen asks for is a fraction of screen HEIGHT while the pitch's
/// requirement scales with WIDTH — so the cap binds on a short screen and on a
/// wide one, and not on the modern tall phone the fixes were checked against.
///
/// `fittedTilt` was a contain fit, so when the cap bound the slack went into
/// bars down the sides. Measured, before the fix: an iPhone SE drew 84% of the
/// pitch with 28 points of dead green each side, an iPad mini 81% with 67.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_pitch.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_stage.dart';
import 'package:merge_empire_fc/ui/screens/match/match_screen.dart';

/// What the projection actually covers inside [band].
Rect _drawn(Size plane, Size band) => MatrixUtils.transformRect(
  fittedTilt(plane, into: band),
  Offset.zero & plane,
);

void main() {
  // Logical sizes, shortest edge first — the shapes the band is asked for on.
  const devices = <String, Size>{
    'iPhone SE': Size(375, 667),
    'iPhone 15': Size(393, 852),
    'iPhone 15 Pro Max': Size(430, 932),
    'Pixel 7': Size(412, 915),
    'iPad mini': Size(744, 1133),
  };

  group('THE PITCH FILLS ITS BAND', () {
    for (final entry in devices.entries) {
      test('on a ${entry.key}', () {
        final screen = entry.value;
        final width = screen.width - matchInset * 2;
        // The match screen's own cap — see `match_screen.dart`.
        final height = screen.height * 0.16;
        final band = Size(width, height);
        final plane = Size(width, width / pitchAspect);
        final drawn = _drawn(plane, band);

        // The inset is room for the touchlines, not a margin: three points all
        // round is the whole of the slack that is allowed.
        expect(
          drawn.width,
          closeTo(width - pitchFitInset * 2, 1),
          reason: 'dead green down the sides',
        );
        expect(
          drawn.height,
          closeTo(height - pitchFitInset * 2, 1),
          reason: 'dead green above and below',
        );
      });
    }

    test('and the stretch that costs stays modest', () {
      // Filling a band of a different shape means scaling the axes apart. That
      // is safe on a PROJECTION in a way it would not be on a photograph — the
      // tilt is already a choice about how much foreshortening to show, so a
      // squatter band reads as a shallower camera. What would not be safe is an
      // unbounded stretch, so the worst case across the shapes above is pinned.
      var worst = 1.0;
      for (final screen in devices.values) {
        final width = screen.width - matchInset * 2;
        final band = Size(width, screen.height * 0.16);
        final ratio =
            (band.height - pitchFitInset * 2) /
            (tiltedBandHeight(width) - pitchFitInset * 2);
        if (ratio < worst) worst = ratio;
      }
      expect(worst, greaterThan(0.75), reason: 'the pitch is being squashed');
    });
  });
}
