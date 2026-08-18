/// The kit palette as a Flutter theme.
///
/// The arithmetic is already pinned against the JS in
/// `test/util/kit_theme_test.dart`; what is checked here is the conversion to
/// `Color`, the extension plumbing, and the three save values the theme follows.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/kit_palette.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

ProviderContainer containerWith(void Function(Map<String, dynamic> state) mutate) {
  final state = createDefaultState();
  mutate(state);
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(gameProvider).load();
  return container;
}

void main() {
  group('cssColor', () {
    test('parses the three forms the palette emits', () {
      expect(cssColor('#ff0000'), const Color(0xFFFF0000));
      expect(cssColor('#000000'), const Color(0xFF000000));
      // Short hex: humbug's dark background is written '#111'.
      expect(cssColor('#111'), const Color(0xFF111111));
      // hsl(), which is what every derived surface is.
      expect(cssColor('hsl(0,100%,50%)'), const Color(0xFFFF0000));
      expect(cssColor('hsl(120,100%,50%)'), const Color(0xFF00FF00));
      expect(cssColor('hsl(0,0%,0%)'), const Color(0xFF000000));
      expect(cssColor('hsl(0,0%,100%)'), const Color(0xFFFFFFFF));
    });

    test('an unparseable value falls back rather than throwing', () {
      // Nothing should ever reach this, but a theme that throws is a white
      // screen on launch and the value ultimately traces back to the save.
      expect(cssColor('nonsense'), isA<Color>());
    });
  });

  group('the theme', () {
    test('every shipped kit builds, in both modes, carrying the extension', () {
      for (final id in [...kitPatterns.keys, '#4caf50', '#ffd700']) {
        for (final light in [true, false]) {
          final kit = buildAppTheme(
            kitId: id,
            light: light,
          ).extension<KitTheme>();
          expect(kit, isNotNull, reason: '$id light=$light');
          expect(kit!.background, isNotNull, reason: '$id light=$light');
        }
      }
    });

    test('light and dark differ', () {
      final dark =
          buildAppTheme(kitId: '#4caf50', light: false).extension<KitTheme>()!;
      final light =
          buildAppTheme(kitId: '#4caf50', light: true).extension<KitTheme>()!;
      expect(dark.bg, isNot(light.bg));
      expect(dark.surface, isNot(light.surface));
    });

    test('the two striped kits get a stripe decoration, the rest a gradient', () {
      for (final id in ['turf', 'humbug']) {
        expect(
          buildAppTheme(kitId: id, light: false).extension<KitTheme>()!.background,
          isA<StripeDecoration>(),
          reason: id,
        );
      }
      for (final id in ['sunset', 'midnight', 'empire', 'void', '#4caf50']) {
        expect(
          buildAppTheme(kitId: id, light: false).extension<KitTheme>()!.background,
          isA<BoxDecoration>(),
          reason: id,
        );
      }
    });

    test('lerp returns a KitTheme rather than throwing', () {
      // ThemeData animates between themes on a kit change; an extension that
      // cannot lerp throws mid-animation rather than at build time.
      final a =
          buildAppTheme(kitId: '#4caf50', light: false).extension<KitTheme>()!;
      final b =
          buildAppTheme(kitId: '#e53935', light: false).extension<KitTheme>()!;
      expect(a.lerp(b, 0.5), isA<KitTheme>());
      // Across kinds of decoration too, which cannot be interpolated.
      final striped =
          buildAppTheme(kitId: 'turf', light: false).extension<KitTheme>()!;
      expect(a.lerp(striped, 0.5), isA<KitTheme>());
    });

    test('copyWith replaces only what it is given', () {
      final a =
          buildAppTheme(kitId: '#4caf50', light: false).extension<KitTheme>()!;
      final b = a.copyWith(accent: const Color(0xFF123456));
      expect(b.accent, const Color(0xFF123456));
      expect(b.bg, a.bg);
    });

    testWidgets('is reachable from a descendant context', (tester) async {
      late KitTheme seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(kitId: 'turf', light: false),
          home: Builder(
            builder: (context) {
              seen = Theme.of(context).extension<KitTheme>()!;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen.accent, isNotNull);
    });
  });

  group('the theme follows the save', () {
    test('reads the club kit', () {
      final container = containerWith((s) {
        (s['club'] as Map<String, dynamic>)['kitPrimaryColor'] = 'humbug';
      });
      expect(container.read(kitIdProvider), 'humbug');
    });

    test('light mode defaults to true, matching the schema', () {
      expect(containerWith((_) {}).read(lightModeProvider), isTrue);
    });

    test('light mode is read off settings', () {
      final container = containerWith((s) {
        (s['settings'] as Map<String, dynamic>)['lightMode'] = false;
      });
      expect(container.read(lightModeProvider), isFalse);
      expect(container.read(appThemeProvider).brightness, Brightness.dark);
    });

    test('a themed event forces dark over the player s light mode', () {
      final container = containerWith((_) {});
      expect(container.read(appThemeProvider).brightness, Brightness.light);
      container.read(forcedDarkProvider.notifier).state = true;
      expect(container.read(appThemeProvider).brightness, Brightness.dark);
      container.read(forcedDarkProvider.notifier).state = false;
      expect(container.read(appThemeProvider).brightness, Brightness.light);
    });

    test('a missing club branch does not throw', () {
      final container = containerWith((s) => s.remove('club'));
      expect(container.read(kitIdProvider), defaultKitColor);
    });
  });
}
