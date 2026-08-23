/// **EVERY EXPLICIT INK, AGAINST THE GROUND IT IS ACTUALLY ON.**
///
/// Reported twice and in the same words: "loads of the views don't work in light
/// mode, text looks wrong and you can't read it". The specific sightings — the
/// squad's Clear pill, the table's form chips and points, the commentary, the
/// end-of-game screen — were each fixed one at a time, which is exactly the
/// shape of a bug that keeps coming back.
///
/// This is the sweep. A `Text` with NO colour of its own takes the theme's ink
/// and is right by construction; the bug is only ever a HARDCODED one, and only
/// when the ground under it does not flip with the theme too. So: walk each
/// screen in light mode, find every `Text` that names a colour, find the
/// nearest ancestor that actually paints an opaque ground, and measure.
///
/// **Three to one, not four and a half.** This is a floor for "somebody can
/// read this", not an accessibility grade — the app has display type at 30pt on
/// coloured plates and holding all of it to small-text contrast would fail
/// things nobody has ever struggled with.
///
/// **And `accentInk` on the accent is exempt, because that pair has already
/// been argued.** `whiteInkMinContrast` is 2.2 and `kit_theme.dart` sets out
/// why: dark ink wins a straight comparison on most mid-tone accents — the
/// default green is 6.8 against black and 2.78 against white — so a "whichever
/// contrasts more" rule would repaint every filled button, the HUD and the tab
/// bar in black and throw away the white-on-accent look the game is built
/// around. `inkFor` exists to catch the kits where white genuinely disappears,
/// and it does. A sweep that overrode that would not be finding a bug, it would
/// be reversing a decision.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/club/club_screen.dart';
import 'package:merge_empire_fc/ui/screens/grid/merge_grid.dart';
import 'package:merge_empire_fc/ui/screens/match/match_screen.dart';
import 'package:merge_empire_fc/ui/screens/match/match_summary.dart';
import 'package:merge_empire_fc/ui/screens/home/home_screen.dart';
import 'package:merge_empire_fc/ui/screens/settings_screen.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_screen.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_screen.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

double _ratio(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

/// Any colour this widget paints, opaque or not.
///
/// **A translucent layer still darkens what is under it**, and treating one as
/// "no ground" is how a white dock label on a 55%-black capsule reads as white
/// on white. They are collected on the way up and composited in order — which
/// is what the screen actually does.
Color? _paints(Widget w) {
  Color? some(Color? c) => c == null || c.a <= 0 ? null : c;
  if (w is ColoredBox) return some(w.color);
  if (w is Material) return some(w.color);
  if (w is Card) return some(w.color);
  if (w is Container) {
    final direct = some(w.color);
    if (direct != null) return direct;
    final d = w.decoration;
    if (d is BoxDecoration) return some(d.color) ?? _fromGradient(d.gradient);
  }
  if (w is DecoratedBox) {
    final d = w.decoration;
    if (d is BoxDecoration) return some(d.color) ?? _fromGradient(d.gradient);
  }
  return null;
}

/// A gradient's own worst case: the stop a reader is least likely to manage.
Color? _fromGradient(Gradient? g) {
  if (g is! LinearGradient && g is! RadialGradient) return null;
  final colors = g is LinearGradient ? g.colors : (g as RadialGradient).colors;
  if (colors.isEmpty) return null;
  return colors.reduce(
    (a, b) => a.computeLuminance() < b.computeLuminance() ? a : b,
  );
}

/// Every hardcoded ink on screen, with the ground it sits on.
List<({Color ink, Color ground, String text})> inksOn(WidgetTester tester) {
  final out = <({Color ink, Color ground, String text})>[];
  for (final element in find.byType(Text).evaluate()) {
    final text = element.widget as Text;
    final glyph = text.style?.color;
    // No colour of its own is right by construction: it takes the theme's.
    if (glyph == null || glyph.a < 0.5) continue;
    // Every layer between the text and the first opaque one, nearest first.
    final layers = <Color>[];
    element.visitAncestorElements((ancestor) {
      final paint = _paints(ancestor.widget);
      if (paint != null) layers.add(paint);
      return paint == null || paint.a < 0.99;
    });
    if (layers.isEmpty || layers.last.a < 0.99) continue;
    // Composited back down: the furthest is the ground, and each nearer one
    // goes over it.
    var ground = layers.last;
    for (var i = layers.length - 2; i >= 0; i--) {
      ground = Color.alphaBlend(layers[i], ground);
    }
    // **AN EMBOSS IS READ BY WHICHEVER EDGE SEPARATES.** The grid's cell number
    // is drawn in the square's own colour on purpose — there is no ink at all,
    // what you see is a light edge below the glyph and a dark one above it. So
    // the candidates are the glyph AND its shadows, each composited onto the
    // ground it is actually over, and the best of them is what a reader is
    // looking at. Taking the glyph alone calls a working carve unreadable;
    // taking the strongest shadow calls a white highlight on a white square a
    // pass.
    final candidates = <Color>[
      glyph,
      for (final shadow in text.style?.shadows ?? const <Shadow>[])
        Color.alphaBlend(shadow.color, ground),
    ];
    final ink = candidates.reduce(
      (a, b) => _ratio(a, ground) >= _ratio(b, ground) ? a : b,
    );
    out.add((ink: ink, ground: ground, text: text.data ?? ''));
  }
  return out;
}

Future<void> pumpLight(WidgetTester tester, Widget screen) async {
  final state = createDefaultState();
  (state['settings'] as Map<String, dynamic>)['lightMode'] = true;
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(gameProvider).load();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(body: screen),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// A finished match, enough to draw the screen from.
Map<String, dynamic> _result() => {
  'clubName': 'Testville',
  'opponentName': 'Ayton',
  'isHome': true,
  'won': true,
  'drawn': false,
  'addedTime': 2,
  'events': const <Map<String, dynamic>>[],
  'homeGoals': 2,
  'awayGoals': 1,
  'coinsEarned': 300,
};

Widget matchScreen() => MatchScreen(result: _result());

Widget summaryScreen() => MatchSummaryScreen(result: _result());

void main() {
  for (final (name, screen) in <(String, Widget)>[
    ('the shop', const ShopScreen()),
    ('the squad', const SquadScreen()),
    ('the club', const ClubScreen()),
    ('settings', const SettingsScreen()),
    ('the grid', const GridScreen()),
    ('the home page', const HomeScreen()),
    // **The match and its summary are a DARK takeover in both themes** — see
    // `darkTakeoverThemeProvider`. Swept in light mode anyway, and that is the
    // point: the page forces its own theme, so what this proves is that the
    // forcing actually reaches every ink on it.
    ('the match', matchScreen()),
    ('the full-time report', summaryScreen()),
  ]) {
    testWidgets('$name reads in LIGHT MODE', (tester) async {
      await pumpLight(tester, screen);
      // `.first`: the settings screen nests a `Scaffold` of its own.
      final kit = Theme.of(
        tester.element(find.byType(Scaffold).first),
      ).extension<KitTheme>()!;
      final bad = [
        for (final row in inksOn(tester))
          if (_ratio(row.ink, row.ground) < 3 &&
              !(row.ground == kit.accent && row.ink == kit.accentInk))
            row,
      ];
      expect(
        bad,
        isEmpty,
        reason: bad
            .map(
              (b) =>
                  '"${b.text}" ${b.ink} on ${b.ground} '
                  '(${_ratio(b.ink, b.ground).toStringAsFixed(2)}:1)',
            )
            .join('\n'),
      );
    });
  }
}
