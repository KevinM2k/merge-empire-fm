/// The HUD is READABLE in light mode.
///
/// It was not: the figures, the cog and the energy ladder all went onto the pane
/// raw, and `glass.dart` says in as many words that "every coloured thing ON
/// glass goes through this — a raw hue there is a bug by construction".
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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart';
import 'package:merge_empire_fc/ui/hud/hud_chip.dart';
import 'package:merge_empire_fc/ui/theme/glass.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

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
            out['figure'] = glassAccent(context, kit.accentBright);
            out['cog'] = glassAccent(context, kit.accentBright);
            out['energyFigure'] = glassAccent(
              context,
              energyInk(context, energy, 10, kit.accentBright),
            );
            out['cap'] = glassMuted(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return out;
  }

  group('on a light pane', () {
    testWidgets('every ink in the bar clears the small-text threshold', (
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

    testWidgets('and so does the energy ladder at every step of it', (
      tester,
    ) async {
      // Green, amber and red are all bright by design — they are warnings — and
      // bright is exactly what a bright pane cannot show.
      for (final energy in const [10, 8, 4, 1, 0]) {
        final inks = await hudInks(
          tester,
          kitId: '#4caf50',
          light: true,
          energy: energy,
        );
        expect(
          paneContrast(inks['energyFigure']!),
          greaterThanOrEqualTo(paneContrastTarget),
          reason: 'at $energy energy',
        );
      }
    });

    testWidgets('the cap is quieter than the figure, but still readable', (
      tester,
    ) async {
      final inks = await hudInks(tester, kitId: '#4caf50', light: true);
      // It was the figure's own colour at 60% alpha — under the threshold, so
      // "11/10" read as "11" and a smudge.
      expect(
        paneContrast(inks['cap']!),
        greaterThanOrEqualTo(paneContrastTarget),
      );
    });
  });

  group('the wallet icons keep the colour they MEAN', () {
    /// The icon as the chip resolves it, and whether it was given a backing.
    Future<(Color, bool)> walletIcon(
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
      return (icon.color!, (icon.shadows ?? const []).isNotEmpty);
    }

    testWidgets('gold stays gold in daylight, and gets a halo instead', (
      tester,
    ) async {
      final (colour, haloed) = await walletIcon(tester, light: true);
      expect(colour, hudCoinInk, reason: 'the coin stopped being yellow');
      expect(haloed, isTrue, reason: 'a bright hue on a bright pane needs one');
    });

    testWidgets('and at night it needs no help at all', (tester) async {
      final (colour, haloed) = await walletIcon(tester, light: false);
      expect(colour, hudCoinInk);
      expect(
        haloed,
        isFalse,
        reason: 'the vivid hues were chosen FOR a dark pane',
      );
    });

    testWidgets('which is why they cannot simply be darkened', (tester) async {
      // The numbers behind the decision, rather than the assertion on its own.
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
    test("its own greens are the reason the figures are ramped", () {
      expect(
        paneContrast(const Color(0xFF4ADE80)),
        lessThan(paneContrastTarget),
      );
    });
  });
}
