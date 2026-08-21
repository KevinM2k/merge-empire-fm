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

    testWidgets('THE MONEY IS GOLD, in both themes and bare', (tester) async {
      // Two answers have been tried under this test and both were worse than
      // the problem. A dark halo under the digits reads as a BORDER at any size
      // worth putting money in; the JS's bronze `#a86523` is legible on a white
      // page and is not what money looks like. The contrast belongs to the
      // surface under the figure, not to the figure.
      final ink = await figureInks(tester);
      expect(ink.dark, gameGold);
      expect(ink.light, gameGold);
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
