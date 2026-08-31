/// The bottom tab bar's ink, on every kit and in both themes.
///
/// **Reported as the bottom HUD making the icons invisible on some themes**,
/// and the cause is worth keeping written down because it is a trap the whole
/// palette is shaped like. The tabs printed `kit.accentInk` — the ink measured
/// against a FILLED accent, which is right for a button. The chrome was never a
/// filled accent: in dark mode it was the accent at 15% over black. So a pale
/// kit (yellow, cyan) resolved `accentInk` to the near-black `#0d0d0d` and
/// painted it onto a near-black bar.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart';
import 'package:merge_empire_fc/ui/shell/tab_bar.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/util/kit_theme.dart' show whiteInkMinContrast;
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// The kits the palette is most likely to break on: a mid green, a pale yellow,
/// a very dark claret, a pale cyan, and the two patterns with fixed tables.
const kits = ['#4caf50', '#fdd835', '#7b1d34', '#00bcd4', 'turf', 'humbug'];

/// sRGB's own transfer curve. It was `^2` here for a while, which is close
/// enough to eyeball and far enough out to disagree with `kit_theme.dart` about
/// which side of a threshold a cyan falls on.
double _channel(double v) =>
    v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

double _luma(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double contrast(Color a, Color b) {
  final x = _luma(a) + 0.05;
  final y = _luma(b) + 0.05;
  return x > y ? x / y : y / x;
}

Future<void> pumpBar(WidgetTester tester, String kitId, bool light) async {
  tester.view.physicalSize = const Size(400, 200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      key: ValueKey('$kitId$light'),
      theme: buildAppTheme(kitId: kitId, light: light),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: ShellTabBar(active: ShellTab.grid, onTap: (_) {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The bar's own middle stop, which is what a tab is standing on.
Color barUnder(WidgetTester tester) {
  final context = tester.element(find.byType(ShellTabBar));
  final kit = Theme.of(context).extension<KitTheme>()!;
  return hudChrome(kit, context).colors[1];
}

void main() {
  testWidgets('EVERY TAB IS VISIBLE ON EVERY KIT, in both themes', (
    tester,
  ) async {
    for (final kitId in kits) {
      for (final light in const [true, false]) {
        await pumpBar(tester, kitId, light);
        final bar = barUnder(tester);
        for (final tab in tabOrder) {
          if (tab == ShellTab.home) continue;
          final icon = tester.widget<Icon>(
            find.descendant(
              of: find.byKey(ValueKey('tab-${tab.name}')),
              matching: find.byType(Icon),
            ),
          );
          // 2:1 is a floor, not a target — a 22px glyph reads well below the
          // text thresholds, and what this is catching is the 1.05:1 that a
          // near-black ink on a near-black bar actually was.
          expect(
            contrast(icon.color!, bar),
            greaterThan(2),
            reason: '$kitId light=$light: ${tab.name} is invisible',
          );
        }
      }
    }
  });

  testWidgets('AND THE PLAY DISC IS THE CLUB, legibly', (tester) async {
    // It used to be inverted — the accent's ink filled the circle and the
    // accent drew the glyph — because the bar underneath was the accent. The
    // bar is neutral now, so the disc is the one thing in the row wearing the
    // strip, and the glyph has to read on it.
    for (final kitId in kits) {
      for (final light in const [true, false]) {
        await pumpBar(tester, kitId, light);
        final disc = tester.widget<Container>(
          find.descendant(
            of: find.byKey(const ValueKey('tab-home')),
            matching: find.byType(Container),
          ),
        );
        final fill = (disc.decoration as BoxDecoration).color!;
        final glyph = tester
            .widget<Icon>(
              find.descendant(
                of: find.byKey(const ValueKey('tab-home')),
                matching: find.byType(Icon),
              ),
            )
            .color!;
        // **The palette's own bar, not a rounder number.** `accentInk` picks
        // white unless white is genuinely unreadable, and `whiteInkMinContrast`
        // is where that line is drawn — the disc wears the accent EXACTLY as
        // chosen, which is what was asked for, so the ink it takes is the one
        // measured for that colour and the test has to hold it to the same
        // rule rather than to a stricter one it would fail on a mid green.
        expect(
          contrast(glyph, fill),
          greaterThanOrEqualTo(whiteInkMinContrast),
          reason: '$kitId light=$light: the glyph sank into the disc',
        );
        // **The RIM is what separates it, not the fill.** The fill is the
        // accent exactly — see `ShellTabBar` — and a pale club's exact accent
        // is 1.2:1 against a neutral bar, which is a colour question the disc
        // deliberately does not answer by changing the colour.
        final rim = (disc.decoration as BoxDecoration).border!.top.color;
        expect(
          contrast(Color.alphaBlend(rim, barUnder(tester)), barUnder(tester)),
          greaterThan(1.25),
          reason: '$kitId light=$light: the disc has no edge',
        );
      }
    }
  });

  testWidgets('and the ACTIVE tab is the one wearing the accent', (
    tester,
  ) async {
    for (final light in const [true, false]) {
      await pumpBar(tester, '#4caf50', light);
      Color inkOf(ShellTab tab) => tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(ValueKey('tab-${tab.name}')),
              matching: find.byType(Icon),
            ),
          )
          .color!;
      final active = inkOf(ShellTab.grid);
      final resting = inkOf(ShellTab.squad);
      expect(active, isNot(resting));
      // Green, not grey: the club is what says which tab you are on.
      expect(active.g, greaterThan(active.r));
      expect(
        contrast(active, barUnder(tester)),
        greaterThan(2),
        reason: 'light=$light',
      );
    }
  });
}
