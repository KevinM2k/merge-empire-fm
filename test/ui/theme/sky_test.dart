/// The sky, and the two dials that decide it.
///
/// The whole point of the file under test is that the two dials do DIFFERENT
/// jobs — the theme picks the hour, the tier picks the grandeur — so most of
/// what is checked here is that neither has quietly taken over the other's job.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_assets.dart' show maxAssetTier;
import 'package:merge_empire_fc/ui/theme/sky.dart';

/// Perceived lightness, near enough to compare two skies by.
double _luma(Color c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;

double _skyLuma({required Brightness brightness, required int tier}) {
  final colours = skyColours(brightness: brightness, tier: tier);
  return colours.map(_luma).reduce((a, b) => a + b) / colours.length;
}

void main() {
  group('day or night is the THEME', () {
    test('light is day and dark is night, at every tier', () {
      for (var tier = 0; tier <= maxAssetTier; tier++) {
        expect(
          _skyLuma(brightness: Brightness.light, tier: tier),
          greaterThan(_skyLuma(brightness: Brightness.dark, tier: tier)),
          reason: 'tier $tier is not brighter in light mode than in dark',
        );
      }
    });

    test('and the darkest daylight still beats the brightest night', () {
      // The two ramps must not overlap, or a player at a park ground in light
      // mode gets a sky darker than an arena at night and the setting stops
      // meaning anything.
      var darkestDay = double.infinity;
      var brightestNight = 0.0;
      for (var tier = 0; tier <= maxAssetTier; tier++) {
        darkestDay = [
          darkestDay,
          _skyLuma(brightness: Brightness.light, tier: tier),
        ].reduce((a, b) => a < b ? a : b);
        brightestNight = [
          brightestNight,
          _skyLuma(brightness: Brightness.dark, tier: tier),
        ].reduce((a, b) => a > b ? a : b);
      }
      expect(darkestDay, greaterThan(brightestNight));
    });

    test('nightScene is the only place the mapping is stated', () {
      expect(nightScene(Brightness.dark), isTrue);
      expect(nightScene(Brightness.light), isFalse);
    });
  });

  group('grandeur is the TIER', () {
    test('the day ramp deepens with the ground', () {
      // Deeper, not darker as a mood: a bigger stadium does not change the
      // weather, so both ends stay unmistakably daytime — checked above — and
      // what moves is the saturation of the blue.
      expect(
        _skyLuma(brightness: Brightness.light, tier: maxAssetTier),
        lessThan(_skyLuma(brightness: Brightness.light, tier: 0)),
      );
    });

    test('and the night ramp deepens with it too', () {
      expect(
        _skyLuma(brightness: Brightness.dark, tier: maxAssetTier),
        lessThan(_skyLuma(brightness: Brightness.dark, tier: 0)),
      );
    });

    test('every step along either ramp is a step, not a plateau', () {
      for (final brightness in Brightness.values) {
        for (var tier = 1; tier <= maxAssetTier; tier++) {
          expect(
            _skyLuma(brightness: brightness, tier: tier),
            lessThan(_skyLuma(brightness: brightness, tier: tier - 1)),
            reason: '$brightness tier $tier matches tier ${tier - 1}',
          );
        }
      }
    });

    test('a tier off the end of the ladder clamps rather than running on', () {
      // The save is the source of the tier and a bad one must not paint a
      // colour off the end of the lerp.
      expect(
        skyColours(brightness: Brightness.dark, tier: 99),
        skyColours(brightness: Brightness.dark, tier: maxAssetTier),
      );
      expect(
        skyColours(brightness: Brightness.light, tier: -3),
        skyColours(brightness: Brightness.light, tier: 0),
      );
    });
  });

  group('the gradient', () {
    test('runs top to bottom over the whole box', () {
      final g = skyGradient(brightness: Brightness.light, tier: 4);
      expect(g.begin, Alignment.topCenter);
      expect(g.end, Alignment.bottomCenter);
      expect(g.stops!.first, 0);
      expect(g.stops!.last, 1);
      expect(g.colors.length, g.stops!.length);
    });

    test('and gets lighter toward the horizon in both themes', () {
      // The sky is brightest where it meets the ground, which is what puts the
      // light source above and behind the scene rather than in it.
      for (final brightness in Brightness.values) {
        final colours = skyColours(brightness: brightness, tier: 3);
        expect(_luma(colours.last), greaterThan(_luma(colours.first)));
      }
    });

    test('the haze is the sky at the HORIZON, not overhead', () {
      final colours = skyColours(brightness: Brightness.dark, tier: 6);
      expect(skyHaze(brightness: Brightness.dark, tier: 6), colours.last);
    });
  });

  group('floodlights', () {
    test('are built by the tier, at the JS\'s own counts', () {
      expect(floodlightCount(0), 0);
      expect(floodlightCount(3), 0);
      expect(floodlightCount(4), 1);
      expect(floodlightCount(6), 1);
      expect(floodlightCount(7), 2);
      expect(floodlightCount(8), 2);
    });

    test('and are LIT by the theme', () {
      // A pylon standing there unlit in daylight is the difference between a big
      // club in the afternoon and the same club at night. If the tier decided
      // both, the theme would be cosmetic.
      expect(floodlightsLit(brightness: Brightness.dark, tier: 4), isTrue);
      expect(floodlightsLit(brightness: Brightness.light, tier: 4), isFalse);
      expect(floodlightsLit(brightness: Brightness.light, tier: 8), isFalse);
    });

    test('and nothing is lit at a ground that has none', () {
      expect(floodlightsLit(brightness: Brightness.dark, tier: 3), isFalse);
    });
  });
}
