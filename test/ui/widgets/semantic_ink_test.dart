/// The reds and the greens, in both themes.
///
/// **The same bug on four screens at once, always with dark mode right** — a
/// colour chosen against a dark surface and printed unchanged on a light one.
/// `vsRedOn` / `vsGreenOn` have carried both halves since the stat rows were
/// written; what was missing was call sites, and for colours that arrive as
/// DATA there was no context to call them from at all.
library;

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

    testWidgets('AND HANDS BACK ANYTHING IT DOES NOT RECOGNISE', (
      tester,
    ) async {
      // Safe to run a whole column through: a gold, a club accent and a tier
      // colour are all deliberate and none of them is this bug.
      final light = await inksIn(tester, light: true);
      expect(light['gold'], const Color(0xFFFFD700));
    });
  });
}
