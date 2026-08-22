/// The screens, in the language that breaks them.
///
/// **German is the measured worst case** — "Verlängerung", "Mannschaftsaufstellung",
/// "Einkommenssteigerung" — and a layout that fits English fits nothing else.
/// This is that check mechanised rather than done by eye: Flutter reports an
/// overflow as a framework exception, and an exception in a widget test fails
/// it, so PUMPING each screen in each language at the narrowest phone the app
/// supports IS the assertion.
///
/// **A narrow viewport, not the default 800×600.** The test surface is wider
/// than most phones and taller than a lot of them, which is exactly the shape
/// that hides an overflow: the strings that break a layout break it at 320
/// points.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/detect.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/shell/app_shell.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

/// The narrowest phone worth supporting, in logical pixels — an iPhone SE.
const Size _small = Size(320, 568);

Future<ProviderContainer> pumpApp(WidgetTester tester, {bool light = false}) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(createDefaultState())}),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(gameRunnerProvider).boot();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          // Every live screen animates forever, so nothing here settles; the
          // walker and the scene both honour reduce-motion.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const AppShell(),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 32));
  return container;
}

void main() {
  setUp(() {
    // Physical size, not `MediaQuery`: the shell reads the view for its own
    // clearances and a MediaQuery override would leave those measuring the
    // wrong box.
  });

  tearDown(resetLocale);

  for (final locale in supportedLocales) {
    testWidgets('EVERY TAB LAYS OUT IN $locale, on a 320pt phone', (
      tester,
    ) async {
      tester.view.physicalSize = _small;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      setLocale(locale);

      final container = await pumpApp(tester);
      for (final tab in tabOrder) {
        container.read(shellControllerProvider.notifier).goTab(tab);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
    });
  }

  testWidgets('AND IN LIGHT MODE TOO, in the longest language', (tester) async {
    // The two themes lay out identically, but a light-mode-only widget that
    // nobody has seen in German would show up here and nowhere else.
    tester.view.physicalSize = _small;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    setLocale('de');

    final container = await pumpApp(tester, light: true);
    for (final tab in tabOrder) {
      container.read(shellControllerProvider.notifier).goTab(tab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
  });
}
