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
    Future<Color> figureInk(WidgetTester tester, {required bool light}) async {
      late Color ink;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: light ? Brightness.light : Brightness.dark,
          ),
          home: Builder(
            builder: (context) {
              ink = coinFigureInk(context);
              return const SizedBox();
            },
          ),
        ),
      );
      return ink;
    }

    testWidgets('THE COIN FIGURE IS THE COIN\'S OWN GOLD, in both themes', (
      tester,
    ) async {
      // In light mode the figure was an amber — #E8A100 — chosen to clear
      // contrast on white. Beside the coin GLYPH, which is a filled disc and
      // stays actual gold because its black rim carries its own contrast, the
      // amber read as orange: two currencies in one pair.
      //
      // The way out was already half-built. The separation is bought with a dark
      // HALO rather than with lightness, so the hue does not have to give
      // anything up — see the shadow below.
      expect(await figureInk(tester, light: false), gameGold);
      expect(await figureInk(tester, light: true), gameGold);
    });

    testWidgets('and the halo is what makes it legible on white', (
      tester,
    ) async {
      // Without it, gold on a white page is unreadable — which is the whole
      // reason the amber existed. Both themes read in ONE tree: pumping twice
      // and reading a captured variable each time is how you end up asserting
      // the first theme against itself.
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
      expect(light, isNotEmpty, reason: 'gold on white with nothing behind it');
      expect(dark, isEmpty);
    });
  });
}
