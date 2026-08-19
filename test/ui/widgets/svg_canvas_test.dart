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
import 'package:merge_empire_fc/data/manager_art.g.dart';
import 'package:merge_empire_fc/ui/widgets/svg_canvas.dart';

void main() {
  group('parsing', () {
    test('reads the view box, and falls back to the club art s own', () {
      expect(viewBoxOf('<svg viewBox="0 0 80 80"></svg>'), const Size(80, 80));
      expect(
        viewBoxOf('<svg viewBox="0 0 200 100"></svg>'),
        const Size(200, 100),
      );
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
      final nodes = parseSvg(
        '<svg><g><defs></defs><rect fill="#fff"/></g></svg>',
      );
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

    test('the stadium hero\'s gradients are read, not skipped', () {
      // This test used to assert the OPPOSITE — that gradients were beyond the
      // painter — and it was recording a real loss: a `fill="url(#id)"` resolved
      // to no colour, and a shape with neither fill nor stroke is skipped, so
      // twenty gradient fills in the club art were drawing nothing at all.
      for (final svg in stadiumBackgrounds) {
        final gradients = parseGradients(svg);
        expect(gradients, isNotEmpty, reason: 'a hero with no gradient?');
        for (final g in gradients.values) {
          expect(
            g.colours.length,
            greaterThanOrEqualTo(2),
            reason: 'a one-stop gradient is a colour',
          );
          expect(g.offsets.length, g.colours.length);
        }
      }
    });

    test('and they are no longer offered as drawables', () {
      // A gradient is a definition, not a shape: leaving the elements in the
      // node list had the painter walking three tags per gradient to skip them.
      for (final svg in stadiumBackgrounds) {
        final types = parseSvg(svg).map((n) => n.type).toSet();
        expect(types, isNot(contains('linearGradient')));
        expect(types, isNot(contains('radialGradient')));
        expect(types, isNot(contains('stop')));
      }
    });

    test('a radial gradient keeps its own centre and radius', () {
      final g = parseGradients(
        '<svg><defs><radialGradient id="g" cx="0.35" cy="0.2" r="0.8">'
        '<stop offset="0" stop-color="#ffffff"/>'
        '<stop offset="1" stop-color="#000000"/>'
        '</radialGradient></defs></svg>',
      )['g']!;
      expect(g.radial, isTrue);
      expect(g.cx, 0.35);
      expect(g.cy, 0.2);
      expect(g.r, 0.8);
    });

    test('a gradient with one stop is not a gradient', () {
      expect(
        parseGradients(
          '<svg><defs><linearGradient id="g">'
          '<stop offset="0" stop-color="#fff"/>'
          '</linearGradient></defs></svg>',
        ),
        isEmpty,
      );
    });
  });

  group('paths', () {
    /// The bounds a path covers, which is what proves a segment was drawn: a
    /// dropped curve leaves the box at the start point.
    Rect boundsOf(String d) => const SvgPainter(
      nodes: [],
      viewBox: Size(100, 100),
    ).parsePath(d)!.getBounds();

    test('a cubic actually curves', () {
      // `C` was not in the old command class, so its six numbers were read as
      // extra arguments to the `M` before it: the path was a moveTo and nothing
      // else, so the box was empty and nothing was drawn.
      final box = boundsOf('M10 90 C10 10 90 10 90 90');
      expect(box.width, closeTo(80, 0.01));
      expect(box.height, greaterThan(40), reason: 'it has to rise');
      expect(box.top, lessThan(50));
    });

    test('and a path of only a move covers nothing, as it should', () {
      expect(boundsOf('M10 90').isEmpty, isTrue);
    });

    test('every manager part draws something', () {
      // All 66 of them are cubics. Before this they were a moveTo and nothing
      // else, which is why the walking figure hand-transcribes its hair.
      var drawn = 0;
      for (final entry in managerHair.values) {
        for (final svg in [entry.$1, entry.$2]) {
          if (svg.isEmpty) continue;
          drawn++;
          expect(parseSvg(svg), isNotEmpty, reason: svg.substring(0, 40));
        }
      }
      expect(drawn, greaterThan(10));
    });

    test('an arc draws its curve', () {
      // The club art draws every crowd seat as a half-circle arc — hundreds of
      // them — and `A` was not a command either, so they were all dropped.
      final box = boundsOf('M0 10 a5 5 0 0 1 10 0 Z');
      expect(box.width, closeTo(10, 0.01));
      expect(box.height, greaterThan(4), reason: 'the dome of the arc');
    });

    test('a percentage stop is read as a fraction', () {
      // The stadium art writes `offset="0%"`, the badges write `offset="0"`.
      final g = parseGradients(
        '<svg><defs><linearGradient id="g">'
        '<stop offset="0%" stop-color="#000000"/>'
        '<stop offset="40%" stop-color="#888888"/>'
        '<stop offset="100%" stop-color="#ffffff"/>'
        '</linearGradient></defs></svg>',
      )['g']!;
      expect(g.offsets, [0.0, 0.4, 1.0]);
    });

    test('the relative and smooth forms are understood too', () {
      for (final d in [
        'm10 10 l10 0 l0 10 z',
        'M10 10 h20 v20 z',
        'M10 10 C20 0 30 0 40 10 S60 20 70 10',
        'M10 10 Q20 0 30 10 T50 10',
      ]) {
        expect(() => boundsOf(d), returnsNormally, reason: d);
      }
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
              svg:
                  '<svg viewBox="0 0 80 80">'
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
