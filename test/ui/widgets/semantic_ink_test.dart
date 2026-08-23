/// The reds and the greens, in both themes.
///
/// **The same bug on four screens at once, always with dark mode right** — a
/// colour chosen against a dark surface and printed unchanged on a light one.
/// `vsRedOn` / `vsGreenOn` have carried both halves since the stat rows were
/// written; what was missing was call sites, and for colours that arrive as
/// DATA there was no context to call them from at all.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart';

Future<Map<String, Color>> inksIn(WidgetTester tester, {required bool light}) async {
  final out = <String, Color>{};
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(kitId: '#4caf50', light: light),
      key: ValueKey(light),
      home: Builder(
        builder: (context) {
          out['red'] = vsRedOn(context);
          out['green'] = vsGreenOn(context);
          out['amber'] = vsAmberOn(context);
          out['dataGreen'] = semanticInk(context, const Color(0xFF4ADE80));
          out['dataRed'] = semanticInk(context, const Color(0xFFF87171));
          out['dataAmber'] = semanticInk(context, const Color(0xFFFBBF24));
          out['gold'] = semanticInk(context, const Color(0xFFFFD700));
          out['club'] = semanticInk(context, const Color(0xFF7FD4FF));
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return out;
}

void main() {
  testWidgets('THE PAIR IS DIFFERENT IN THE TWO THEMES', (tester) async {
    final dark = await inksIn(tester, light: false);
    final light = await inksIn(tester, light: true);
    for (final key in ['red', 'green', 'amber']) {
      expect(dark[key], isNot(light[key]), reason: key);
    }
  });

  testWidgets('and the LIGHT one is dark enough to read on white', (
    tester,
  ) async {
    // Small text on a light pane; the dark-mode pair is `#4ADE80` at 1.9:1,
    // which is a figure nobody can read in daylight.
    final light = await inksIn(tester, light: true);
    for (final key in ['red', 'green', 'amber']) {
      expect(
        light[key]!.computeLuminance(),
        lessThan(0.25),
        reason: key,
      );
    }
  });

  group('semanticInk, for colours that arrive as DATA', () {
    testWidgets('MAPS THE DARK-MODE VALUES to their light counterparts', (
      tester,
    ) async {
      final light = await inksIn(tester, light: true);
      expect(light['dataGreen'], light['green']);
      expect(light['dataRed'], light['red']);
      expect(light['dataAmber'], light['amber']);
    });

    testWidgets('leaves dark mode alone entirely', (tester) async {
      final dark = await inksIn(tester, light: false);
      expect(dark['dataGreen'], const Color(0xFF4ADE80));
      expect(dark['dataRed'], const Color(0xFFF87171));
      expect(dark['dataAmber'], const Color(0xFFFBBF24));
    });

    testWidgets('AND EVERY GOLD IN THE PALETTE, not just the one', (
      tester,
    ) async {
      // The table's points figure is `#FFD700` and it printed unchanged on a
      // white page — the one column the standings exist for, in daylight
      // yellow. Reported straight off the table.
      final light = await inksIn(tester, light: true);
      expect(light['gold'], light['amber']);
    });

    testWidgets('AND HANDS BACK ANYTHING IT DOES NOT RECOGNISE', (
      tester,
    ) async {
      // Safe to run a whole column through: a club accent and a tier colour
      // are deliberate and neither is this bug.
      final light = await inksIn(tester, light: true);
      expect(light['club'], const Color(0xFF7FD4FF));
    });
  });
  group('AND THE PLATE FOLLOWS THE THEME', () {
    // **The dark plate in both themes was itself a fix, and it caused the next
    // report.** It answered "the red and green are too dark" — tinted fills
    // behind a near-black light-mode ink are grey boxes — and a row of
    // near-black chips on a daylit table is a set of holes in it, which is what
    // came back off the standings. Dark keeps its plate; light gets a wash of
    // the chip's own hue with the deep ink over it.
    testWidgets('dark keeps the near-black one the bright three want', (
      tester,
    ) async {
      late Color plate;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(kitId: '#4caf50', light: false),
          home: Builder(
            builder: (context) {
              plate = semanticPlate(context, vsGreenBright);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(plate.computeLuminance(), lessThan(0.05));
      expect(plate.a, 1.0, reason: 'the page shows through the plate');
    });

    testWidgets('AND LIGHT DOES NOT — it is a wash of the ink itself', (
      tester,
    ) async {
      late Color plate;
      late Color ink;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(kitId: '#4caf50', light: true),
          home: Builder(
            builder: (context) {
              ink = semanticInk(context, vsGreenBright);
              plate = semanticPlate(context, ink);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(plate.a, lessThan(0.3), reason: 'a hole in a daylit table');
      expect(plate.r, ink.r);
    });

    test('and the bright three read against the DARK plate', () {
      // The figure this is measured against is the one the light-mode pair was
      // introduced for: 1.9:1 on white. On the plate all three clear 4.5:1,
      // which is the small-text bar.
      double ratio(Color ink, Color on) {
        final a = ink.computeLuminance();
        final b = on.computeLuminance();
        return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
      }

      const plate = Color(0xFF1A1F26);
      for (final ink in [vsGreenBright, vsRedBright, vsAmberBright]) {
        expect(ratio(ink, plate), greaterThan(4.5), reason: '$ink');
      }
    });
  });
}
