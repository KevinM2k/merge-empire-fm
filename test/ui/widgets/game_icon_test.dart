/// The game's icon set actually PAINTS.
///
/// Every glyph in `icons.js` puts `fill`/`stroke` on the `<svg>` root and lets
/// its paths inherit — so a painter that reads attributes per node draws fifty-
/// nine empty boxes and nothing says so. This asserts the inheritance rather
/// than the appearance: a node with no drawable paint is the exact failure.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/svg_canvas.dart';

void main() {
  group('every icon in the set', () {
    test('parses to at least one drawable node', () {
      for (final entry in gameIcons.entries) {
        final nodes = parseSvg(entry.value);
        expect(
          nodes,
          isNotEmpty,
          reason: '${entry.key} parsed to nothing at all',
        );
      }
    });

    test('and every node carries a paint it can actually draw with', () {
      for (final entry in gameIcons.entries) {
        // Resolved the way GameIcon resolves it — `currentColor` is not a colour
        // the painter understands, so the substitution is part of the contract.
        final resolved = entry.value.replaceAll('currentColor', '#ffffffff');
        for (final node in parseSvg(resolved)) {
          final fill = node.attrs['fill'];
          final stroke = node.attrs['stroke'];
          final hasFill = fill != null && fill != 'none';
          final hasStroke = stroke != null && stroke != 'none';
          expect(
            hasFill || hasStroke,
            isTrue,
            reason:
                '${entry.key}: a ${node.type} with neither fill nor stroke is '
                'skipped by the painter — the root attributes are not being '
                'inherited',
          );
        }
      }
    });

    test('and the stroked family keeps its 1.8 weight', () {
      // One family, one line weight. A glyph that lost the root's stroke-width
      // falls back to 1 and reads thinner than everything beside it.
      final nodes = parseSvg(
        gameIcons['coin']!.replaceAll('currentColor', '#ffffffff'),
      );
      expect(nodes, isNotEmpty);
      for (final node in nodes) {
        expect(node.attrs['stroke-width'], '1.8');
      }
    });
  });

  group('the currency is ONE colour', () {
    /// Both themes in ONE tree. Pumping twice and reading a captured variable
    /// each time reads the theme MID-LERP — `MaterialApp` animates a theme
    /// change, so the second pump's first frame is still the first theme.
    Future<({Color light, Color dark})> figureInks(WidgetTester tester) async {
      late Color light;
      late Color dark;
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              Theme(
                data: ThemeData(brightness: Brightness.light),
                child: Builder(
                  builder: (context) {
                    light = coinFigureInk(context);
                    return const SizedBox();
                  },
                ),
              ),
              Theme(
                data: ThemeData(brightness: Brightness.dark),
                child: Builder(
                  builder: (context) {
                    dark = coinFigureInk(context);
                    return const SizedBox();
                  },
                ),
              ),
            ],
          ),
        ),
      );
      return (light: light, dark: dark);
    }

    testWidgets('THE MONEY IS YELLOW IN BOTH — a different yellow in light', (
      tester,
    ) async {
      // **This test asserted one literal for both themes, and the reasoning
      // under it has expired.** It said the contrast belongs to the SURFACE
      // rather than the figure — which was true while the match pages were dark
      // glass in both themes. They are not any more: a player who chose light
      // mode and got a dark page was being ignored by the app, and that was
      // reported twice. Once the surface is a light pane, `#FFD700` is 1.1:1
      // and the biggest number on the full-time report is invisible.
      //
      // The RULE the game runs on — money yellow, gems blue, ads orange, real
      // money green — is untouched: this is the same hue, and `gameGoldLight`
      // is the JS's own `--color-gold` from its light block rather than a
      // second value invented here. A halo is still not the answer, and the
      // test below still holds it out.
      final ink = await figureInks(tester);
      expect(ink.dark, gameGold);
      expect(ink.light, gameGoldLight);
      // Same family rather than a retint for its own sake. The JS's light gold
      // is a warmer amber than its bright one — 30 degrees round the wheel at
      // most, which is still yellow-into-amber and nowhere near a red or a
      // green.
      expect(
        (HSLColor.fromColor(ink.light).hue -
                HSLColor.fromColor(gameGold).hue)
            .abs(),
        lessThan(30),
      );
    });

    testWidgets('and there is no halo, in either theme', (tester) async {
      // Both themes read in ONE tree: pumping twice and reading a captured
      // variable each time is how you end up asserting the first theme against
      // itself.
      late List<Shadow> light;
      late List<Shadow> dark;
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              Theme(
                data: ThemeData(brightness: Brightness.light),
                child: Builder(
                  builder: (context) {
                    light = coinFigureShadows(context);
                    return const SizedBox();
                  },
                ),
              ),
              Theme(
                data: ThemeData(brightness: Brightness.dark),
                child: Builder(
                  builder: (context) {
                    dark = coinFigureShadows(context);
                    return const SizedBox();
                  },
                ),
              ),
            ],
          ),
        ),
      );
      expect(light, isEmpty, reason: 'the bronze carries its own contrast');
      expect(dark, isEmpty);
    });
  });
}
