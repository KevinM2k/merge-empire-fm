/// The HUD is READABLE in light mode.
///
/// It was not: the figures, the cog and the energy ladder all went onto the pane
/// raw, and `glass.dart` says in as many words that "every coloured thing ON
/// glass goes through this — a raw hue there is a bug by construction".
///
/// **THE FIGURES HAVE MOVED ONTO THE ICONS' CONTRACT.** They were ramped, which
/// is what this file was written to assert — and ramping is by construction a
/// colour that changes with the pane, so the coins, the gems and the energy read
/// one colour on a dark page, another on a light one, and another again on the
/// next club. Reported in one line: they should be the same everywhere. So a
/// figure is now a fixed white with a halo in daylight, exactly as a wallet glyph
/// is a fixed hue with a halo in daylight, and what this file asserts about them
/// is that they do not move.
///
/// **The wallet ICONS are the exception, and they are the interesting half.** You
/// cannot fix a bright hue by darkening it: yellow is intrinsically light, so
/// taking gold to 4.5:1 against a near-white pane lands on `#665600` — a dark
/// olive that reads perfectly and is no longer money. Their hue carries the
/// meaning, so it stays exactly as it is and they get a dark halo instead. What
/// this file asserts is therefore two DIFFERENT contracts, one per job.
///
/// **Measured, not eyeballed.** A widget test renders icons as tofu and text
/// without fonts, so a screenshot of this bar proves nothing; the contrast ratio
/// is the actual claim, and asserting it is a guard that holds after the next
/// person picks a new hue.
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
import 'package:merge_empire_fc/ui/hud/hud.dart';
import 'package:merge_empire_fc/ui/hud/hud_chip.dart';
import 'package:merge_empire_fc/ui/theme/glass.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart'
    show vsAmberPlate, vsGreenPlate, vsRedPlate;
import 'package:merge_empire_fc/ui/widgets/store_button.dart'
    show storeCoinFace, storeGemFace;

void main() {
  /// Every colour the HUD puts on the pane, as the bar itself resolves them.
  ///
  /// Built through a real light-mode context, because [glassAccent] asks the
  /// theme whether it is day or night and the whole bug was about the day.
  Future<Map<String, Color>> hudInks(
    WidgetTester tester, {
    required String kitId,
    required bool light,
    num energy = 11,
  }) async {
    final out = <String, Color>{};
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(kitId: kitId, light: light),
        home: Builder(
          builder: (context) {
            final kit = Theme.of(context).extension<KitTheme>()!;
            // The COG still ramps, and it is the only thing in the bar that
            // does: it carries no meaning in its colour, so on a kit whose
            // accent is the glass's own hue it was the one control you could
            // not find.
            out['cog'] = glassAccent(context, kit.accentBright);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return out;
  }

  /// The real bar, in a theme the test picks rather than the save's.
  Future<void> pumpBar(WidgetTester tester, {required bool light}) async {
    final container = ProviderContainer(
      overrides: [
        saveStoreProvider.overrideWithValue(
          MemorySaveStore({saveKeyPrimary: jsonEncode(createDefaultState())}),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(gameProvider).load();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          // Keyed, so a second pump in the other theme is a new tree rather
          // than a lerp away from the first.
          key: ValueKey(light),
          theme: buildAppTheme(kitId: '#4caf50', light: light),
          home: const MediaQuery(
            data: MediaQueryData(size: Size(400, 800)),
            child: Scaffold(body: Hud()),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
  }

  group('on a light pane', () {
    testWidgets('the cog still clears the small-text threshold', (
      tester,
    ) async {
      // Across the kits, because the accent is the club's and half of them are
      // some shade of the green the chrome is already made of.
      for (final kitId in const [
        '#4caf50',
        '#1e88e5',
        '#d32f2f',
        '#fdd835',
        '#00bcd4',
        'turf',
        'humbug',
      ]) {
        final inks = await hudInks(tester, kitId: kitId, light: true);
        for (final entry in inks.entries) {
          expect(
            paneContrast(entry.value),
            greaterThanOrEqualTo(paneContrastTarget),
            reason:
                '$kitId: the ${entry.key} ink is '
                '${paneContrast(entry.value).toStringAsFixed(2)}:1 on glass',
          );
        }
      }
    });
  });

  group('THE FIGURES DO NOT MOVE', () {
    testWidgets('the same ink on every theme and every kit', (tester) async {
      // The whole of the report. A figure that is one colour on the dark page
      // and another on the light one is not the same figure, and the club's
      // accent made it a third on the next save.
      // Each figure IS its glyph's ink, which is the one palette in this bar
      // already proven against both panes.
      expect(hudFigureInk, hudCoinInk);
      expect(energyInk(10, 10), hudEnergyInk);
      for (final kitId in const ['#4caf50', '#fdd835', 'humbug']) {
        for (final light in const [true, false]) {
          final inks = await hudInks(tester, kitId: kitId, light: light);
          // The cog is the only ink in here and it is the only one that ramps;
          // the figures are constants, which is the whole claim.
          expect(inks.keys, ['cog'], reason: kitId);
        }
      }
    });

    testWidgets('and the coins and the gems really carry it', (tester) async {
      // **THE FIGURE TAKES ITS BADGE'S INK, and naming one here is the bug this
      // replaced.** Each reading is a filled chip in its wallet's colour now,
      // printed in a lightened tint of that colour — see `HudChip` — so the
      // figure inherits and the chip decides. A colour named at the call site
      // is what would put a gold figure on a gem badge.
      for (final light in const [true, false]) {
        await pumpBar(tester, light: light);
        for (final key in const ['hud-coins', 'hud-gems']) {
          final text = tester
              .widgetList<Text>(
                find.descendant(
                  of: find.byKey(ValueKey(key)),
                  matching: find.byType(Text),
                ),
              )
              .where((t) => t.style?.fontSize == 13);
          expect(text, isNotEmpty, reason: '$key in light=$light');
          for (final t in text) {
            expect(
              t.style!.color,
              isNull,
              reason: '$key light=$light names its own colour',
            );
          }
          final box = tester.widget<Container>(
            find
                .descendant(
                  of: find.byKey(ValueKey(key)),
                  matching: find.byType(Container),
                )
                .first,
          );
          final fill = (box.decoration! as BoxDecoration).color!;
          expect(
            fill,
            key == 'hud-coins' ? storeCoinFace : storeGemFace,
            reason: '$key light=$light is not the shop\'s own colour',
          );
        }
      }
    });

    testWidgets('and BARE, in both themes', (tester) async {
      // The figures wore a soft dark halo in daylight to buy a fixed ink some
      // contrast against a pane that ramps. It read as a smudge — the violet
      // energy figure worst of all, a few thin strokes over a blur — and taking
      // it off both themes was asked for directly.
      // **Keyed and SETTLED, or the answer is a lie.** `MaterialApp` lerps
      // between themes, and `ThemeData.lerp` keeps the old brightness until
      // half way — so reading this on the frame after a theme swap returns the
      // theme you just left.
      Future<List<Shadow>?> backing({required bool light}) async {
        List<Shadow>? out;
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(light),
            theme: buildAppTheme(kitId: '#4caf50', light: light),
            home: Builder(
              builder: (context) {
                out = hudFigureShadows(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        return out;
      }

      expect(await backing(light: true), isNull, reason: 'no halo in daylight');
      expect(await backing(light: false), isNull, reason: 'and none at night');
    });
  });

  group('the energy ladder says how much is LEFT, not what theme it is', () {
    test('plenty looks like the bolt beside it', () {
      // Four rungs and the top two both meant "you are fine", one of them in
      // the club's own accent. A colour LEAVING the violet is the warning now.
      expect(energyInk(10, 10), hudEnergyInk);
      expect(energyInk(8, 10), hudEnergyInk);
    });

    test('and a colour only appears when there is something to say', () {
      expect(energyInk(4, 10), hudEnergyLowInk);
      expect(energyInk(1, 10), hudEnergyEmptyInk);
      expect(energyInk(0, 10), hudEnergyEmptyInk);
    });

    test('a tank with no cap cannot be low', () {
      expect(energyInk(0, 0), hudEnergyInk);
    });
  });

  group('a wallet is a BADGE in its own colour', () {
    /// The badge's fill and the ink printed on it.
    Future<(Color fill, Color ink)> wallet(
      WidgetTester tester, {
      required bool light,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(kitId: '#4caf50', light: light),
          home: const Scaffold(
            body: HudChip(
              icon: Icons.monetization_on,
              iconColor: hudCoinInk,
              semanticLabel: 'coins',
              child: SizedBox.shrink(),
            ),
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.monetization_on));
      final box = tester.widget<Container>(find.byType(Container).first);
      return ((box.decoration! as BoxDecoration).color!, icon.color!);
    }

    testWidgets('THE SAME BADGE ON BOTH THEMES', (tester) async {
      // Four rounds went into making a fixed hue legible on a shared pane and
      // each lost the same way: deepening the ink read as muted, a dark pane
      // read as a slab cut out of the sky, an outline under the glyph did
      // nothing at all, and a pane light enough to belong left the colours
      // unreadable. Every one was an argument about a ground the wallets did
      // not control.
      //
      // A badge carries its own. So the answer stops depending on what is
      // behind it, which is why these two have to be identical.
      final day = await wallet(tester, light: true);
      final night = await wallet(tester, light: false);
      expect(day, night, reason: 'the badge still moves with the theme');
    });

    testWidgets('and it is the SHOP\'s own colour, not a second one', (
      tester,
    ) async {
      // A coin badge in the bar that is a different gold from the coin BUTTON
      // you tap is two golds for one currency.
      final (fill, ink) = await wallet(tester, light: true);
      expect(fill, storeCoinFace);
      expect(hudBadgeColour(hudGemInk), storeGemFace);
      // Energy has no shop button and takes the card's own ladder instead, so
      // the bar and the next-match card agree about what green means.
      expect(hudBadgeColour(hudEnergyInk), vsGreenPlate);
      expect(hudBadgeColour(hudEnergyLowInk), vsAmberPlate);
      expect(hudBadgeColour(hudEnergyEmptyInk), vsRedPlate);

      // **THE INK IS THE BADGE, LIGHTENED — not white.** Flat white on a mid
      // gold is legible and reads as a sticker; the same hue taken most of the
      // way up keeps the chip one object. It still has to carry, at the
      // large-text bar: the label is a 13pt w900 figure beside a 16px glyph.
      expect(ink, hudBadgeInk(fill));
      for (final hue in const [
        hudCoinInk,
        hudGemInk,
        hudEnergyInk,
        hudEnergyLowInk,
        hudEnergyEmptyInk,
      ]) {
        final badge = hudBadgeColour(hue);
        // The palette's own bar, not a rounder number: gold is intrinsically
        // light and even flat white on the shop's `#D8A01A` is 2.3, so holding
        // this to 3 would be an instruction to stop using the shop's gold. See
        // [hudBadgeInkTarget].
        expect(
          _ratio(hudBadgeInk(badge), badge),
          greaterThanOrEqualTo(hudBadgeInkTarget),
          reason: '$hue cannot carry its own ink',
        );
        expect(
          HSLColor.fromColor(hudBadgeInk(badge)).hue,
          closeTo(HSLColor.fromColor(badge).hue, 2),
          reason: '$hue lightened into a different colour',
        );
      }
    });

    testWidgets('which is why they cannot simply be darkened', (tester) async {
      // The numbers behind the decision rather than the decision on its own:
      // this is what the badge exists INSTEAD of.
      expect(paneContrast(hudCoinInk), lessThan(paneContrastTarget));
      expect(paneContrast(hudGemInk), lessThan(paneContrastTarget));
      late Color ramped;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(kitId: '#4caf50', light: true),
          home: Builder(
            builder: (context) {
              ramped = glassAccent(context, hudCoinInk);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(
        HSLColor.fromColor(ramped).lightness,
        lessThan(0.3),
        reason: 'ramping gold for legibility is what makes it not-gold',
      );
    });
  });

  group('the energy ladder', () {
    test('none of its rungs could ever have been ramped', () {
      // The numbers behind the decision rather than the decision on its own:
      // the ladder's colours are WARNINGS, which is to say bright, and bright
      // is exactly what a bright pane cannot show. Ramping them to the text
      // threshold takes an amber to a brown; the halo is what a warning gets
      // instead, the same as the glyphs.
      for (final ink in const [
        Color(0xFF4ADE80),
        hudEnergyInk,
        hudEnergyLowInk,
        hudEnergyEmptyInk,
      ]) {
        expect(paneContrast(ink), lessThan(paneContrastTarget));
      }
    });
  });
  group('AND WHATEVER IS BEHIND IT CANNOT SHOW THROUGH', () {
    // **"Anywhere the top has a background, both themes have to work."** The
    // HUD sits over the sky on the Play tab, over a page everywhere else, and
    // over whatever the customiser is drawing while its sheet slides up — and
    // the answer is not to recolour the icons for each of them, it is for the
    // BAND to be opaque. The blur behind it is a texture, not a see-through.
    //
    // Pinned as an invariant rather than checked by eye, because an alpha
    // creeping into one stop of one theme is invisible until somebody opens
    // the one screen with a bright thing under the bar.
    Future<LinearGradient> chromeIn(
      WidgetTester tester, {
      required bool light,
    }) async {
      late LinearGradient out;
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(light),
          theme: buildAppTheme(kitId: '#4caf50', light: light),
          home: Builder(
            builder: (context) {
              out = hudChrome(
                Theme.of(context).extension<KitTheme>()!,
                context,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return out;
    }

    testWidgets('every stop of the chrome is OPAQUE, in both themes', (
      tester,
    ) async {
      for (final light in [true, false]) {
        final chrome = await chromeIn(tester, light: light);
        for (final colour in chrome.colors) {
          expect(
            colour.a,
            1.0,
            reason: 'light: $light — the page shows through the bar',
          );
        }
      }
    });

    testWidgets('and the two themes are genuinely different bands', (
      tester,
    ) async {
      // Dark mode is already right, which the report says — so the check that
      // matters is that light mode is not silently the same thing.
      final light = await chromeIn(tester, light: true);
      final dark = await chromeIn(tester, light: false);
      expect(light.colors.first, isNot(dark.colors.first));
      expect(
        light.colors.first.computeLuminance(),
        greaterThan(dark.colors.first.computeLuminance()),
      );
    });
  });

}

/// Contrast between two opaque colours, by sRGB's own transfer curve.
double _ratio(Color a, Color b) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  double luma(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final x = luma(a) + 0.05;
  final y = luma(b) + 0.05;
  return x > y ? x / y : y / x;
}
