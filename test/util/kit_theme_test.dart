/// The kit palette, pinned against the live JS.
///
/// Two different kinds of check live here, and they are not equally strong:
///
/// - The LIGHT theme, turf's dark theme and any club colour's dark theme are
///   derived — real arithmetic, independently implemented, genuinely verified.
/// - Five of the six pattern kits' DARK themes are hand-picked tables in the JS,
///   transcribed here. For those the fixture is a regression guard — it catches
///   the JS moving, and it caught the transcription — not an independent
///   derivation. Said plainly rather than left to look stronger than it is.
///
/// Regenerate with tool/dump_kit_theme_reference.mjs.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/kit_palette.dart';
import 'package:merge_empire_fc/util/kit_theme.dart';

void main() {
  final reference =
      jsonDecode(
            File('test/fixtures/kit_theme_reference.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  // The JS writes CSS custom properties; the port returns an object. This maps
  // one onto the other so the fixture stays the JS's own output, unedited.
  final fields = <String, String Function(KitSurfaces)>{
    '--color-bg': (s) => s.bg,
    '--color-surface': (s) => s.surface,
    '--color-surface-2': (s) => s.surface2,
    '--color-border': (s) => s.border,
    '--color-text-muted': (s) => s.textMuted,
    '--color-accent': (s) => s.accent,
    '--color-accent-bright': (s) => s.accentBright,
    '--color-accent-bright-ink': (s) => s.accentBrightInk,
  };

  for (final mode in ['dark', 'light']) {
    final light = mode == 'light';
    final kits = reference[mode] as Map<String, dynamic>;

    for (final entry in kits.entries) {
      final expected = entry.value as Map<String, dynamic>;

      test('$mode ${entry.key} matches the JS', () {
        final got = buildKitSurfaces(kitId: entry.key, light: light);
        fields.forEach((cssVar, read) {
          expect(read(got), expected[cssVar], reason: '$cssVar on ${entry.key}');
        });
      });
    }
  }

  test('the art hue rotation matches the JS', () {
    for (final mode in ['dark', 'light']) {
      final kits = reference[mode] as Map<String, dynamic>;
      for (final entry in kits.entries) {
        final expected = (entry.value as Map<String, dynamic>)['--kit-hue-rotate'];
        final got = buildKitSurfaces(kitId: entry.key, light: mode == 'light');
        expect('${got.hueRotate}deg', expected, reason: '$mode ${entry.key}');
      }
    }
  });

  // The one deliberate divergence. The JS light path calls inkFor and its
  // comment says why; the dark DERIVED path kept the older lightness > 55 test,
  // which hands white ink to a pale accent — invisible text on the button.
  // Recorded under "Fixed in the port rather than carried" in docs/REMAINING.md.
  group('accent ink is measured, not guessed', () {
    for (final hex in ['#ffd700', '#00c8ff']) {
      test('$hex takes dark ink in dark mode, unlike the JS', () {
        // darkModeInkDark, not inkDark: the fix changes WHICH ink is picked,
        // never the two the JS paints with.
        expect(
          buildKitSurfaces(kitId: hex, light: false).accentInk,
          darkModeInkDark,
        );
        expect(
          (reference['dark'] as Map)[hex]['--color-accent-ink'],
          inkLight,
          reason: 'the JS bug being diverged from should still be in the fixture',
        );
      });

      test('$hex already agreed in light mode, and still does', () {
        expect(
          buildKitSurfaces(kitId: hex, light: true).accentInk,
          (reference['light'] as Map)[hex]['--color-accent-ink'],
        );
      });
    }

    for (final hex in ['#4caf50', '#e53935', '#1a237e', '#ffffff', '#000000']) {
      test('$hex agrees with the JS, so nothing else moved', () {
        expect(
          buildKitSurfaces(kitId: hex, light: false).accentInk,
          (reference['dark'] as Map)[hex]['--color-accent-ink'],
        );
      });
    }

    test('the five tabulated dark kits keep their hand-picked ink', () {
      // empire's #001418 is neither black nor white — the author picked cyan's
      // ink by hand here while the derived path stayed wrong.
      for (final kit in ['humbug', 'sunset', 'midnight', 'empire', 'void']) {
        expect(
          buildKitSurfaces(kitId: kit, light: false).accentInk,
          (reference['dark'] as Map)[kit]['--color-accent-ink'],
          reason: kit,
        );
      }
    });
  });

  group('a kit id off the save cannot brick the app', () {
    for (final bad in ['no-such-kit', '', 'rgb(1,2,3)', 'TURF']) {
      test('${bad.isEmpty ? '(empty)' : bad} falls back to the default green', () {
        for (final light in [true, false]) {
          expect(
            buildKitSurfaces(kitId: bad, light: light).accent,
            buildKitSurfaces(kitId: defaultKitColor, light: light).accent,
            reason: 'light=$light',
          );
        }
      });
    }
  });

  test('every shipped pattern kit is themed in both modes', () {
    for (final id in kitPatterns.keys) {
      for (final light in [true, false]) {
        final s = buildKitSurfaces(kitId: id, light: light);
        expect(s.accent, isNotEmpty, reason: '$id light=$light');
        expect(s.bg, isNotEmpty, reason: '$id light=$light');
      }
    }
  });
}
