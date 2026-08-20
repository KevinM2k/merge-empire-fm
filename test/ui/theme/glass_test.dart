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
  GlassDensity density = GlassDensity.panel,
  Widget child = const SizedBox(width: 80, height: 40),
}) => tester.pumpWidget(
  MaterialApp(
    // An inner `Theme`, not `MaterialApp.theme`: the app's own lerps to a new
    // one over 200ms, so a re-pump reads back the theme it is leaving.
    home: Theme(
      data: ThemeData(brightness: brightness),
      child: Scaffold(
        body: Center(
          child: GlassPanel(density: density, child: child),
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

/// WCAG contrast against the brightest pane the app draws — the same reference
/// `glassAccent` works to.
double contrastOnPane(Color ink) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  final lum = 0.2126 * ch(ink.r) + 0.7152 * ch(ink.g) + 0.0722 * ch(ink.b);
  return (0.62 + 0.05) / (lum + 0.05);
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
          lessThan(0.45),
          reason: '$brightness: that is a block, not glass',
        );
        expect(
          opacityOf(tintOf(tester)),
          greaterThan(0.1),
          reason: '$brightness: that is not a pane at all',
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
        await pumpPanel(
          tester,
          brightness: brightness,
          density: GlassDensity.deep,
        );
        expect(
          opacityOf(tintOf(tester)),
          greaterThan(plain),
          reason: '$brightness: a deep pane is no denser than a shallow one',
        );
      }
    });

    testWidgets('and the pane is what it is in BOTH themes', (tester) async {
      // Neither one is allowed to drift into being a slab while the other stays
      // glass, which is how the light recipe got to near-opaque the first time.
      await pumpPanel(tester, brightness: Brightness.light);
      final day = opacityOf(tintOf(tester));
      await pumpPanel(tester, brightness: Brightness.dark);
      final night = opacityOf(tintOf(tester));
      expect((day - night).abs(), lessThan(0.2));
    });
  });

  group('a colour on a pane', () {
    testWidgets('is darkened until it CLEARS 4.5:1 in light mode', (
      tester,
    ) async {
      // Our own club name was `accentBright` — `#259328` on the default kit,
      // which against a bright pane is 2.4:1. Under the 3:1 large text needs,
      // let alone 4.5, and it was the most important text on the card.
      await pumpPanel(tester, brightness: Brightness.light);
      final context = tester.element(find.byType(GlassPanel));
      for (final raw in const [
        Color(0xFF259328), // the default kit's accent
        Color(0xFFFF6B4A), // the Attack tactic's hue
        Color(0xFF4ADE80), // the mint a +1 used to be
        Color(0xFFFFC247), // the Press tactic's amber
      ]) {
        final out = glassAccent(context, raw);
        expect(
          contrastOnPane(out),
          greaterThan(4.4),
          reason: 'still unreadable: $raw -> $out',
        );
      }
    });

    testWidgets('and it keeps the HUE — it darkens, it does not go grey', (
      tester,
    ) async {
      // The colour is the signal. A green that clears contrast by turning into
      // charcoal has thrown the signal away to pass the test.
      await pumpPanel(tester, brightness: Brightness.light);
      final context = tester.element(find.byType(GlassPanel));
      const raw = Color(0xFF259328);
      final out = glassAccent(context, raw);
      expect(out.g, greaterThan(out.r * 2));
      expect(out.g, greaterThan(out.b * 2));
    });

    testWidgets('a colour already dark enough is left alone', (tester) async {
      await pumpPanel(tester, brightness: Brightness.light);
      final context = tester.element(find.byType(GlassPanel));
      const already = Color(0xFF16222E);
      expect(glassAccent(context, already), already);
    });

    testWidgets('and in DARK mode nothing is touched', (tester) async {
      // A bright accent on a dark pane is the pairing it was chosen for.
      await pumpPanel(tester, brightness: Brightness.dark);
      final context = tester.element(find.byType(GlassPanel));
      for (final raw in const [Color(0xFF6EF772), Color(0xFF4ADE80)]) {
        expect(glassAccent(context, raw), raw);
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

    testWidgets('and the pane publishes that ink to its subtree', (
      tester,
    ) async {
      // A pane is a SURFACE, and a surface owes its subtree an ink — nothing
      // inside one should have to know it is on one. What went wrong before was
      // pushing a whole flipped THEME in, which is a different thing: a theme
      // carries a palette, a page colour and a hundred component defaults, none
      // of which a pane has any business changing.
      for (final brightness in Brightness.values) {
        late TextStyle inside;
        await pumpPanel(
          tester,
          brightness: brightness,
          child: Builder(
            builder: (context) {
              inside = DefaultTextStyle.of(context).style;
              return const SizedBox(width: 80, height: 40);
            },
          ),
        );
        expect(inside.color, glassText(tester.element(find.byType(GlassPanel))));
      }
    });

    testWidgets('and the ink is NOT the app\'s own near-black', (tester) async {
      // `onSurface` is a black with a green cast, chosen for a white page. On a
      // pane floating over a blue sky it reads hard and slightly bilious.
      await pumpPanel(tester, brightness: Brightness.light);
      final context = tester.element(find.byType(GlassPanel));
      expect(
        glassText(context),
        isNot(Theme.of(context).colorScheme.onSurface),
      );
      // And it gives up nothing: still darker than the muted ink beside it, and
      // still very dark.
      final ink = glassText(context);
      final muted = glassMuted(context);
      expect(ink.a, greaterThan(muted.a));
      expect(0.2126 * ink.r + 0.7152 * ink.g + 0.0722 * ink.b, lessThan(0.2));
    });
  });
}
