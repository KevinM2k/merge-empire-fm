/// The Settings screen.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/detect.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/settings_screen.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

Future<ProviderContainer> pumpSettings(
  WidgetTester tester,
  SettingsTab tab,
) async {
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
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: SettingsScreen(initialTab: tab),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Map<String, dynamic> settingsOf(ProviderContainer c) =>
    c.read(gameProvider).state!['settings'] as Map<String, dynamic>;

/// Every write arms the 2s debounced save. Pump past it, or the test ends with
/// a timer still pending and the binding rightly complains.
Future<void> settleSave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: saveDebounceMs + 100));

void main() {
  tearDown(resetLocale);

  // The guard the i18n module deferred, now that there is a picker to check.
  // A device language resolving to a catalogue the picker cannot switch back
  // from is a trap the player has no way out of.
  test('the language picker lists exactly the shipped locales', () {
    expect(
      settingsLanguages.map((l) => l.id).toList()..sort(),
      supportedLocales.toList()..sort(),
    );
  });

  test('every language has a flag and a native label', () {
    for (final l in settingsLanguages) {
      expect(l.flag, isNotEmpty, reason: l.id);
      expect(l.label, isNotEmpty, reason: l.id);
    }
  });

  testWidgets('opening on a named tab lands on it', (tester) async {
    await pumpSettings(tester, SettingsTab.match);
    expect(find.byKey(const ValueKey('setting-matchSpeedFast')), findsOneWidget);
  });

  testWidgets('a toggle writes its key to the save', (tester) async {
    final container = await pumpSettings(tester, SettingsTab.audio);
    expect(settingsOf(container)['soundEnabled'], isTrue);
    await tester.tap(find.byKey(const ValueKey('setting-soundEnabled')));
    await tester.pumpAndSettle();
    await settleSave(tester);
    expect(settingsOf(container)['soundEnabled'], isFalse);
  });

  testWidgets('a volume slider writes a 0..1 number', (tester) async {
    final container = await pumpSettings(tester, SettingsTab.audio);
    await tester.drag(
      find.byKey(const ValueKey('setting-soundVolume')),
      const Offset(-200, 0),
    );
    await tester.pumpAndSettle();
    await settleSave(tester);
    final value = settingsOf(container)['soundVolume'] as num;
    expect(value, lessThan(1));
    expect(value, greaterThanOrEqualTo(0));
  });

  testWidgets('picking a language moves the whole app and the save', (
    tester,
  ) async {
    final container = await pumpSettings(tester, SettingsTab.general);
    await tester.tap(find.byKey(const ValueKey('language-fr')));
    await tester.pumpAndSettle();
    await settleSave(tester);
    expect(getLocale(), 'fr');
    expect(settingsOf(container)['locale'], 'fr');
  });

  testWidgets('the tab strip moves between tabs', (tester) async {
    await pumpSettings(tester, SettingsTab.general);
    await tester.tap(find.byKey(const ValueKey('settings-tab-match')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('setting-matchSpeedFast')), findsOneWidget);
  });

  testWidgets('a swipe past the last tab does nothing', (tester) async {
    await pumpSettings(tester, SettingsTab.account);
    await tester.fling(
      find.byKey(const ValueKey('settings-body-account')),
      const Offset(-200, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reset-btn')), findsOneWidget);
  });

  testWidgets('Pro mode is shown but not switchable here', (tester) async {
    // The JS changes it only through the new-team flow.
    await pumpSettings(tester, SettingsTab.match);
    final tile = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('setting-hardMode')),
    );
    expect(tile.onChanged, isNull);
  });

  testWidgets('reset asks first and changes nothing until it is answered', (
    tester,
  ) async {
    final container = await pumpSettings(tester, SettingsTab.account);
    final before = container.read(gameProvider).state!['clubName'];
    await tester.tap(find.byKey(const ValueKey('reset-btn')));
    await tester.pumpAndSettle();
    expect(find.text(t('reset.title')), findsOneWidget);
    expect(container.read(gameProvider).state!['clubName'], before);
  });

  testWidgets('full reset asks first too', (tester) async {
    await pumpSettings(tester, SettingsTab.account);
    await tester.tap(find.byKey(const ValueKey('full-reset-btn')));
    await tester.pumpAndSettle();
    expect(find.text(t('fullReset.title')), findsOneWidget);
  });

  testWidgets('an M4 control is visible but disabled, not hidden', (
    tester,
  ) async {
    // A control that vanishes reads as a missing feature; one that explains
    // itself reads as a feature that is coming.
    await pumpSettings(tester, SettingsTab.account);
    for (final key in ['sign-in-btn', 'feedback-btn']) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
      expect(
        tester.widget<ElevatedButton>(find.byKey(ValueKey(key))).onPressed,
        isNull,
        reason: key,
      );
    }
    expect(find.text(t('settings.comingSoon')), findsNWidgets(2));
  });
}
