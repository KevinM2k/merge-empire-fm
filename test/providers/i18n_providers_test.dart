/// The locale, bridged to the widget tree.
///
/// Container setup follows `test/providers/game_providers_test.dart`: seed the
/// store with a save rather than loading a default and mutating it, so the
/// locale is already on the save before the first read.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/detect.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/providers/i18n_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';

void main() {
  tearDown(resetLocale);

  String saveWith(String? locale) {
    final s = createDefaultState();
    final settings = s['settings'] as Map<String, dynamic>;
    if (locale == null) {
      settings.remove('locale');
    } else {
      settings['locale'] = locale;
    }
    return jsonEncode(s);
  }

  ProviderContainer containerWith(String? locale) {
    final container = ProviderContainer(
      overrides: [
        saveStoreProvider.overrideWithValue(
          MemorySaveStore({saveKeyPrimary: saveWith(locale)}),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(gameProvider).load();
    return container;
  }

  test('reads the locale off the save and applies it', () {
    final container = containerWith('fr');
    expect(container.read(localeProvider), 'fr');
    expect(getLocale(), 'fr');
  });

  test('an unshipped locale on the save lands on English', () {
    final container = containerWith('xx');
    expect(container.read(localeProvider), 'en');
    expect(getLocale(), 'en');
  });

  test('a save with no locale at all lands on English', () {
    // A legacy save predating the setting must not boot to no strings.
    final container = containerWith(null);
    expect(container.read(localeProvider), 'en');
  });

  test('set() writes the save and moves the lookup', () {
    final container = containerWith('en');
    container.read(localeProvider.notifier).set('ja');
    expect(getLocale(), 'ja');
    expect(container.read(localeProvider), 'ja');
    final save = container.read(gameProvider).state!;
    expect((save['settings'] as Map<String, dynamic>)['locale'], 'ja');
  });

  test('notifies listeners when the locale moves', () {
    final container = containerWith('en');
    final seen = <String>[];
    container.listen(
      localeProvider,
      (_, next) => seen.add(next),
      fireImmediately: false,
    );
    container.read(localeProvider.notifier).set('de');
    expect(seen, ['de']);
  });

  testWidgets('Arabic gives the tree a right-to-left directionality', (
    tester,
  ) async {
    final container = containerWith('ar');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            locale: Locale(ref.watch(localeProvider)),
            supportedLocales: supportedLocales.map(Locale.new),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Text('x'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.text('x'))), TextDirection.rtl);
  });

  testWidgets('and English a left-to-right one', (tester) async {
    final container = containerWith('en');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            locale: Locale(ref.watch(localeProvider)),
            supportedLocales: supportedLocales.map(Locale.new),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Text('x'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.text('x'))), TextDirection.ltr);
  });
}
