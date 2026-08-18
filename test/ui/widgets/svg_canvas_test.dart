/// The primitive painter behind the club artwork.
///
/// Not a general SVG renderer: it covers exactly the elements
/// `assets/clubArt.js` composes from, and skips anything else rather than
/// throwing — art is decoration, and one bad flourish should not blank a tile.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_art.g.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/ui/widgets/svg_canvas.dart';

void main() {
  group('parsing', () {
    test('reads the view box, and falls back to the club art s own', () {
      expect(viewBoxOf('<svg viewBox="0 0 80 80"></svg>'), const Size(80, 80));
      expect(viewBoxOf('<svg viewBox="0 0 200 100"></svg>'), const Size(200, 100));
      expect(viewBoxOf('<svg></svg>'), const Size(80, 80));
    });

    test('lifts every primitive out in document order', () {
      final nodes = parseSvg(
        '<svg viewBox="0 0 80 80">'
        '<rect x="1" y="2" width="3" height="4" fill="#fff"/>'
        '<circle cx="5" cy="6" r="7" fill="#000"/>'
        '<text x="8" y="9" fill="#111">HI</text>'
        '</svg>',
      );
      expect(nodes.map((n) => n.type), ['rect', 'circle', 'text']);
      expect(nodes[0].attrs['width'], '3');
      expect(nodes[2].text, 'HI');
    });

    test('drops the wrappers that draw nothing', () {
      final nodes = parseSvg('<svg><g><defs></defs><rect fill="#fff"/></g></svg>');
      expect(nodes.map((n) => n.type), ['rect']);
    });
  });

  group('the shipped artwork', () {
    test('every category and tier parses to something drawable', () {
      for (final category in AssetCategory.all) {
        for (var tier = 1; tier <= maxAssetTier; tier++) {
          final nodes = parseSvg(clubArtFor(category, tier));
          expect(nodes, isNotEmpty, reason: '$category t$tier');
        }
      }
    });

    test('an unknown category still draws, rather than blanking', () {
      // The category comes off the save.
      expect(parseSvg(clubArtFor('NOPE', 1)), isNotEmpty);
    });

    test('a tier past the artwork clamps to the last one', () {
      expect(clubArtFor('STADIUM', 99), clubArtFor('STADIUM', 6));
      expect(clubArtFor('STADIUM', 0), clubArtFor('STADIUM', 1));
    });

    test('every element in the TILES is one the painter knows', () {
      // The guarantee that makes skipping-the-unknown safe rather than lossy —
      // for the tiles, which is what the Club screen draws.
      const known = {
        'rect',
        'circle',
        'ellipse',
        'polygon',
        'line',
        'path',
        'text',
      };
      final seen = <String>{};
      for (final category in AssetCategory.all) {
        for (var tier = 1; tier <= maxAssetTier; tier++) {
          seen.addAll(parseSvg(clubArtFor(category, tier)).map((n) => n.type));
        }
      }
      expect(seen.difference(known), isEmpty, reason: 'unhandled: $seen');
    });

    test('the stadium HERO needs gradients, which the painter has not got', () {
      // Recorded rather than hidden: the six background images use
      // linearGradient / radialGradient / stop, and nothing else in the game
      // does. Drawing them means teaching the painter `fill="url(#id)"` and a
      // <defs> table first, so the hero stays unrendered until then and this
      // test says exactly why.
      final seen = <String>{};
      for (final svg in stadiumBackgrounds) {
        seen.addAll(parseSvg(svg).map((n) => n.type));
      }
      expect(seen, contains('linearGradient'));
      expect(seen, contains('radialGradient'));
    });
  });

  group('drawing', () {
    testWidgets('paints without throwing, at any size', (tester) async {
      for (final size in [const Size(24, 24), const Size(200, 200)]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox.fromSize(
                size: size,
                child: SvgArt(svg: clubArtFor(AssetCategory.stadium, 6)),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$size');
      }
    });

    testWidgets('every shipped tile paints', (tester) async {
      for (final category in AssetCategory.all) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 64,
                height: 64,
                child: SvgArt(svg: clubArtFor(category, 3)),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: category);
      }
    });

    testWidgets('nonsense is skipped rather than thrown on', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 40,
            height: 40,
            child: SvgArt(
              svg: '<svg viewBox="0 0 80 80">'
                  '<wobble x="1"/>'
                  '<rect fill="not-a-colour" width="10" height="10"/>'
                  '<path d="Z"/>'
                  '<polygon points="1,2"/>'
                  '</svg>',
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
