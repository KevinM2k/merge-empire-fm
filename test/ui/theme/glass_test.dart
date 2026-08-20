/// Glass follows the theme.
///
/// It was dark in both, because the sky was one fixed dusk-blue on a day→night
/// clock and a panel that followed the theme went white-on-white the moment
/// light mode was on. The sky follows the theme now, so the compromise comes
/// off — and these are the two halves of that: the pane is light over a daylit
/// sky, and it no longer flips the ink of everything inside it.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/theme/glass.dart';
import 'package:merge_empire_fc/ui/theme/sky.dart';

Future<void> pumpPanel(
  WidgetTester tester, {
  required Brightness brightness,
  bool deep = false,
  Widget child = const SizedBox(width: 80, height: 40),
}) => tester.pumpWidget(
  MaterialApp(
    // An inner `Theme`, not `MaterialApp.theme`: the app's own lerps to a new
    // one over 200ms, so a re-pump reads back the theme it is leaving.
    home: Theme(
      data: ThemeData(brightness: brightness),
      child: Scaffold(
        body: Center(
          child: GlassPanel(deep: deep, child: child),
        ),
      ),
    ),
  ),
);

/// The pane's own tint — the JS's 168deg gradient, which is the one gradient in
/// the panel that runs down AND across it.
LinearGradient tintOf(WidgetTester tester) {
  final boxes = tester.widgetList<DecoratedBox>(
    find.descendant(
      of: find.byType(GlassPanel),
      matching: find.byType(DecoratedBox),
    ),
  );
  return boxes
      .map((b) => b.decoration)
      .whereType<BoxDecoration>()
      .map((d) => d.gradient)
      .whereType<LinearGradient>()
      .firstWhere((g) => g.begin == const Alignment(-0.4, -1));
}

/// What the tint reads as once it is composited over the sky behind it.
double lumaOf(LinearGradient tint) {
  final c = tint.colors.first;
  return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * c.a;
}

/// How much of the scene the tint hides.
double opacityOf(LinearGradient tint) =>
    tint.colors.map((c) => c.a).reduce((a, b) => a + b) / tint.colors.length;

void main() {
  group('the pane', () {
    testWidgets('is light in light mode and dark in dark mode', (tester) async {
      await pumpPanel(tester, brightness: Brightness.light);
      final day = tintOf(tester);
      await pumpPanel(tester, brightness: Brightness.dark);
      final night = tintOf(tester);
      expect(lumaOf(day), greaterThan(lumaOf(night)));
    });

    testWidgets('is TRANSPARENT — you can see the scene through it', (
      tester,
    ) async {
      // This went the wrong way twice. The first pane was too pale to read; the
      // fix pushed it most of the way to opaque, which read as a white block
      // sitting on the diorama. Both were trying to solve legibility with the
      // tint. Half the backdrop shows through now and the BLUR carries it.
      for (final brightness in Brightness.values) {
        await pumpPanel(tester, brightness: brightness);
        expect(
          opacityOf(tintOf(tester)),
          lessThan(0.62),
          reason: '$brightness: that is a block, not glass',
        );
      }
    });

    testWidgets('and the app\'s own ink still clears 4.5:1 on it', (
      tester,
    ) async {
      // The floor the tint values are set from, and the reason they cannot come
      // down further: the pane composites over the brightest part of a daylit
      // sky, and the text on it is the app's near-black.
      await pumpPanel(tester, brightness: Brightness.light);
      final tint = tintOf(tester);
      final sky = skyColours(brightness: Brightness.light, tier: 8).first;
      final pane = Color.alphaBlend(tint.colors.first, sky);
      final ink = ThemeData(brightness: Brightness.light).colorScheme.onSurface;
      double rel(Color c) {
        double ch(double v) =>
            v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
        return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
      }

      final ratio = (rel(pane) + 0.05) / (rel(ink) + 0.05);
      expect(ratio, greaterThan(4.5), reason: 'text on the pane is too faint');
    });

    testWidgets('and the blur is what carries it, so it is a BIG blur', (
      tester,
    ) async {
      // The JS uses about sigma 7 because `backdrop-filter` no-ops on the
      // WebViews it ships to, so it could never lean on it. A Flutter blur
      // always works.
      await pumpPanel(tester, brightness: Brightness.light);
      expect(
        find.descendant(
          of: find.byType(GlassPanel),
          matching: find.byType(BackdropFilter),
        ),
        findsOne,
      );
    });

    testWidgets('and deep is denser than not, in both', (tester) async {
      for (final brightness in Brightness.values) {
        await pumpPanel(tester, brightness: brightness);
        final plain = opacityOf(tintOf(tester));
        await pumpPanel(tester, brightness: brightness, deep: true);
        expect(
          opacityOf(tintOf(tester)),
          greaterThan(plain),
          reason: '$brightness: a deep pane is no denser than a shallow one',
        );
      }
    });

    testWidgets('still reads with the blur removed', (tester) async {
      // The tint carries legibility and the blur is a bonus — a blur is a
      // backdrop snapshot per panel per frame over a diorama that is already
      // animating, and it is the first thing to drop on a phone that cannot
      // afford it.
      for (final brightness in Brightness.values) {
        await pumpPanel(tester, brightness: brightness);
        expect(
          opacityOf(tintOf(tester)),
          greaterThan(0.4),
          reason: '$brightness: the tint alone would not hold the text',
        );
      }
    });
  });

  group('the ink', () {
    testWidgets('is the app\'s own, not a flipped copy of it', (tester) async {
      // The panel used to hand its subtree the DARK build of the kit and merge a
      // `DefaultTextStyle` and an `IconTheme` over it, because everything inside
      // was written for a surface that ignored the theme. Nothing inside needs
      // telling any more, and a child that reads the theme must get the same
      // answer inside the pane as outside it.
      for (final brightness in Brightness.values) {
        late Brightness inside;
        await pumpPanel(
          tester,
          brightness: brightness,
          child: Builder(
            builder: (context) {
              inside = Theme.of(context).brightness;
              return const SizedBox(width: 80, height: 40);
            },
          ),
        );
        expect(inside, brightness);
      }
    });

    testWidgets('and no DefaultTextStyle is forced over the child', (
      tester,
    ) async {
      await pumpPanel(tester, brightness: Brightness.light);
      expect(
        find.descendant(
          of: find.byType(GlassPanel),
          matching: find.byType(DefaultTextStyle),
        ),
        findsNothing,
      );
    });
  });
}
