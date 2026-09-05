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
/// bars down the sides. Measured, before that fix: an iPhone SE drew 84% of the
/// pitch with 28 points of dead green each side, an iPad mini 81% with 67.
///
/// **And then the CAP itself turned out to be the bigger half.** 16% of screen
/// height is 140 points on a 402x874 phone where the spec's own rule asks for
/// 226 — so the pitch filled its band and the band was 62% of the size the
/// pitch is drawn for. See [stageBandHeight].
///
/// **And then the stretch went.** Filling a shallower band by scaling the axes
/// apart was visible on a tablet, where the feed's floor binds hard: the ratio
/// went out. The pitch keeps its shape now, at [stageFitWidth], and the band
/// shows [PitchBackdrop.surround] down either side of it when it must.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_game.dart';
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

  /// What the stage and the feed share, near enough: everything else on the
  /// column is fixed. The real figure is measured — see the `LayoutBuilder` in
  /// `match_screen.dart` — and this is only here to exercise the floors.
  double poolOn(Size screen) => screen.height - 84 - 60;

  group('THE PITCH FILLS ITS BAND AND KEEPS ITS SHAPE', () {
    for (final entry in devices.entries) {
      test('on a ${entry.key}', () {
        final screen = entry.value;
        final width = screen.width - matchInset * 2;
        final height = stageBandHeight(
          width: width,
          pool: poolOn(screen),
          hasTacticStrip: true,
        );
        final fit = stageFitWidth(width, height);
        expect(fit, lessThanOrEqualTo(width + 0.01));
        final band = Size(fit, height);
        final plane = Size(fit, fit / pitchAspect);
        final drawn = _drawn(plane, band);

        // The inset is room for the touchlines, not a margin: three points all
        // round is the whole of the slack that is allowed inside the fit.
        expect(
          drawn.width,
          closeTo(fit - pitchFitInset * 2, 1),
          reason: 'dead green down the sides of the fit',
        );
        expect(
          drawn.height,
          closeTo(height - pitchFitInset * 2, 1),
          reason: 'dead green above and below',
        );
        // And NO stretch: the band the fit is drawn in is the one its own
        // tilt asks for, so the axes are scaled together.
        expect(
          tiltedBandHeight(fit),
          closeTo(height, 0.5),
          reason: 'the pitch is being squashed',
        );
      });
    }

    test('a phone gets the full width and a tablet gets borders', () {
      // The feed's floor binds on a tablet held wide, so the band is shallower
      // than the tilt needs; the pitch narrows to keep its shape and the
      // surround shows either side. A modern phone's band is the pitch's own.
      double fitOn(Size screen) {
        final width = screen.width - matchInset * 2;
        return stageFitWidth(
          width,
          stageBandHeight(
            width: width,
            pool: poolOn(screen),
            hasTacticStrip: true,
          ),
        );
      }
      // Within a few points: the floors bind by a hair even on the phone.
      expect(fitOn(devices['iPhone 15']!), closeTo(devices['iPhone 15']!.width - matchInset * 2, 6));
      // Upright, the mini's pool is deep enough; on its side it is not.
      const landscape = Size(1133, 744);
      expect(fitOn(landscape), lessThan(landscape.width - matchInset * 2 - 100));
    });

    test('and a band deep enough is not narrowed at all', () {
      expect(stageFitWidth(349, tiltedBandHeight(349) + 40), 349);
      expect(stageFitWidth(349, double.infinity), 349);
    });
  });

  group('AND THE BAND IS THE PITCH\'S OWN SHAPE', () {
    test('which is what 16% of screen height was not', () {
      // The number this replaced, on the phone it was checked against.
      const screen = Size(402, 874);
      final width = screen.width - matchInset * 2;
      expect(
        stageBandHeight(
          width: width,
          pool: poolOn(screen),
          hasTacticStrip: true,
        ),
        closeTo(width / pitchAspect, 0.5),
      );
      expect(screen.height * 0.16, lessThan(width / pitchAspect * 0.7));
    });

    test('and the feed keeps its floor on a screen too short for both', () {
      // A pool that cannot pay for the aspect gives the difference back rather
      // than pushing the commentary off the bottom.
      const pool = 420.0;
      final h = stageBandHeight(
        width: 349,
        pool: pool,
        hasTacticStrip: true,
      );
      expect(h, lessThan(349 / pitchAspect));
      expect(
        pool - h - tacticStripHeight - matchGap * 2,
        greaterThanOrEqualTo(feedMinHeight - 0.5),
      );
    });

    test('but never below the point a move stops being readable', () {
      expect(
        stageBandHeight(width: 349, pool: 200, hasTacticStrip: true),
        stageMinHeight,
      );
    });
  });

  group('AND WHAT IS OUTSIDE THE TOUCHLINES IS NOT TURF', () {
    // **The pitch and the not-pitch were the same green.** The stage backs its
    // clip box with a flat fill and it was `PitchBackdrop.turf` — the identical
    // colour the pitch is painted in. A tilted pitch is a trapezoid in a
    // rectangle, so the two triangles beside the far touchline were the same
    // grass as the pitch: a green box with faint lines floating in the middle
    // of it, nowhere near its edges. Reported as most of the pitch missing.
    //
    // The fit is not what was wrong — `fittedTilt` puts all four corners inside
    // the band, three points in, which the group above pins. What was wrong is
    // that there was nothing to SEE the trapezoid against.
    test('so the trapezoid has an edge to be seen against', () {
      expect(
        PitchBackdrop.surround,
        isNot(PitchBackdrop.turf),
        reason: 'the surround is the turf again — the pitch has no visible edge',
      );
      // Darker, not merely different: the space beyond a touchline reads as
      // shadow, and a lighter surround would pull the eye off the pitch.
      expect(
        PitchBackdrop.surround.computeLuminance(),
        lessThan(PitchBackdrop.turf.computeLuminance()),
      );
    });

    test('and flat, the far touchline spans the band less its inset', () {
      const band = Size(375, 135);
      final plane = Size(band.width, band.width / pitchAspect);
      final m = fittedTilt(plane, into: band);
      final farLeft = MatrixUtils.transformPoint(m, Offset.zero);
      final farRight = MatrixUtils.transformPoint(m, Offset(plane.width, 0));
      expect(
        farRight.dx - farLeft.dx,
        closeTo(band.width - pitchFitInset * 2, 0.5),
      );
    });
  });
}
