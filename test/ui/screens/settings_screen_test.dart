/// The Settings screen.
///
/// What is checked here is mostly the WIRING — a control that writes nothing, or
/// writes the wrong key, looks identical to one that works. The two rules the
/// audio pair carries and the two reset rows are the cases where that had
/// actually gone wrong.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/i18n/detect.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/settings_audio_row.dart';
import 'package:merge_empire_fc/ui/screens/settings_controls.dart';
import 'package:merge_empire_fc/ui/screens/settings_screen.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

Future<ProviderContainer> pumpSettings(
  WidgetTester tester,
  SettingsTab tab, {
  void Function(Map<String, dynamic> state)? mutate,
}) async {
  final state = createDefaultState();
  mutate?.call(state);
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(gameProvider).load();

  // A TALL surface. The General tab is a real page — four cards, a language grid
  // and the danger group — and on the default 800×600 the bottom half of it is
  // never built, so a tap on a row below the fold silently hits nothing.
  tester.view.physicalSize = const Size(460, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

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

  test('the version in the footer is the version this build IS', () {
    // The JS reads `package.json`; there is no runtime equivalent here without
    // a plugin, so the constant is checked against `pubspec.yaml` instead. A
    // version string that has quietly drifted is worse than none — it is the
    // first thing a support message needs.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(declared, isNotNull, reason: 'pubspec has no version line');
    expect(appVersion, declared!.group(1));
  });

  group('the tabs', () {
    testWidgets('opening on a named tab lands on it', (tester) async {
      await pumpSettings(tester, SettingsTab.match);
      expect(find.byKey(const ValueKey('setting-matchSpeedFast')), findsOne);
    });

    testWidgets('the tab strip moves between tabs', (tester) async {
      await pumpSettings(tester, SettingsTab.general);
      await tester.tap(find.byKey(const ValueKey('settings-tab-match')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('setting-matchSpeedFast')), findsOne);
    });

    testWidgets('a swipe past the last tab does nothing', (tester) async {
      await pumpSettings(tester, SettingsTab.account);
      await tester.fling(
        find.byKey(const ValueKey('settings-body-account')),
        const Offset(-200, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sign-in-btn')), findsOne);
    });

    testWidgets('and every tab says which build this is', (tester) async {
      // The JS puts the footer on all four, and it is the only place in the game
      // that names a version.
      for (final tab in SettingsTab.values) {
        await pumpSettings(tester, tab);
        expect(
          find.byType(SettingsFooterCard),
          findsOne,
          reason: 'no footer on ${tab.name}',
        );
        expect(find.textContaining(appVersion), findsOne, reason: tab.name);
      }
    });
  });

  group('the general tab', () {
    testWidgets('a toggle writes its key to the save', (tester) async {
      final container = await pumpSettings(tester, SettingsTab.general);
      expect(settingsOf(container)['notificationsEnabled'], isTrue);
      await tester.tap(
        find.byKey(const ValueKey('setting-notificationsEnabled')),
      );
      await tester.pumpAndSettle();
      await settleSave(tester);
      expect(settingsOf(container)['notificationsEnabled'], isFalse);
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

    testWidgets('the club name row shows the name, or says it is not set', (
      tester,
    ) async {
      await pumpSettings(tester, SettingsTab.general);
      expect(find.text(t('settings.notSet')), findsOne);
      await pumpSettings(
        tester,
        SettingsTab.general,
        mutate: (s) => s['clubName'] = 'Ember Rovers',
      );
      expect(find.text('Ember Rovers'), findsOne);
    });

    testWidgets('and tapping it opens Colin\'s card', (tester) async {
      await pumpSettings(tester, SettingsTab.general);
      await tester.tap(find.byKey(const ValueKey('club-name-row')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('club-name-field')), findsOne);
      // His frame, not an invented dialog.
      expect(find.byKey(const ValueKey('coach-card')), findsOne);
    });

    testWidgets('a typed name is stored', (tester) async {
      final container = await pumpSettings(tester, SettingsTab.general);
      await tester.tap(find.byKey(const ValueKey('club-name-row')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('club-name-field')),
        'Ember Rovers',
      );
      await tester.tap(
        find.byKey(const ValueKey('coach-action-club_name.confirm')),
      );
      await tester.pumpAndSettle();
      await settleSave(tester);
      expect(container.read(gameProvider).state!['clubName'], 'Ember Rovers');
      expect(find.byKey(const ValueKey('club-name-field')), findsNothing);
    });

    testWidgets('a screened name is refused ON the card, not after it', (
      tester,
    ) async {
      // The card has to stay up for the message to have anywhere to appear.
      final container = await pumpSettings(tester, SettingsTab.general);
      await tester.tap(find.byKey(const ValueKey('club-name-row')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('club-name-field')),
        'Shit United',
      );
      await tester.tap(
        find.byKey(const ValueKey('coach-action-club_name.confirm')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('club-name-error')), findsOne);
      expect(find.byKey(const ValueKey('club-name-field')), findsOne);
      expect(
        container.read(gameProvider).state!['clubName'],
        isNot(contains('Shit')),
      );
      // And it clears on the next keystroke: a message about a name that is no
      // longer in the field is a message about nothing.
      await tester.enterText(
        find.byKey(const ValueKey('club-name-field')),
        'Ember Rovers',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('club-name-error')), findsNothing);
    });

    testWidgets('the dice puts a real name in the field', (tester) async {
      await pumpSettings(tester, SettingsTab.general);
      await tester.tap(find.byKey(const ValueKey('club-name-row')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('club-name-generate')));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('club-name-field')),
      );
      // In the field rather than only in the placeholder — a suggestion you then
      // have to retype is not a suggestion.
      expect(field.controller!.text.trim().length, greaterThan(2));
    });
  });

  group('the audio pair', () {
    testWidgets('the toggle writes its channel', (tester) async {
      final container = await pumpSettings(tester, SettingsTab.audio);
      expect(settingsOf(container)['soundEnabled'], isTrue);
      await tester.tap(find.byKey(const ValueKey('setting-soundEnabled')));
      await tester.pumpAndSettle();
      await settleSave(tester);
      expect(settingsOf(container)['soundEnabled'], isFalse);
    });

    testWidgets('the slider writes a 0..1 number', (tester) async {
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

    testWidgets('turning a channel on at 0% nudges it off silence', (
      tester,
    ) async {
      // A control that says it is on while nothing can be heard is
      // indistinguishable from a broken feature.
      final container = await pumpSettings(
        tester,
        SettingsTab.audio,
        mutate: (s) {
          final settings = s['settings'] as Map<String, dynamic>;
          settings['soundEnabled'] = false;
          settings['soundVolume'] = 0;
        },
      );
      await tester.tap(find.byKey(const ValueKey('setting-soundEnabled')));
      await tester.pumpAndSettle();
      await settleSave(tester);
      expect(settingsOf(container)['soundEnabled'], isTrue);
      expect(settingsOf(container)['soundVolume'], audioNudge);
    });

    testWidgets('dragging the volume off zero turns the channel back on', (
      tester,
    ) async {
      // Reaching for the volume is how a player says they want to hear it;
      // being made to find the toggle first is a step that explains nothing.
      final container = await pumpSettings(
        tester,
        SettingsTab.audio,
        mutate: (s) {
          final settings = s['settings'] as Map<String, dynamic>;
          settings['soundEnabled'] = false;
          settings['soundVolume'] = 0;
        },
      );
      await tester.drag(
        find.byKey(const ValueKey('setting-soundVolume')),
        const Offset(200, 0),
      );
      await tester.pumpAndSettle();
      await settleSave(tester);
      expect(settingsOf(container)['soundEnabled'], isTrue);
      expect(settingsOf(container)['soundVolume'], greaterThan(0));
    });

    testWidgets('and dragging it to zero turns the channel off', (
      tester,
    ) async {
      final container = await pumpSettings(tester, SettingsTab.audio);
      await tester.drag(
        find.byKey(const ValueKey('setting-soundVolume')),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      await settleSave(tester);
      expect(settingsOf(container)['soundVolume'], 0);
      expect(settingsOf(container)['soundEnabled'], isFalse);
    });

    testWidgets('music ships OFF, matching the schema', (tester) async {
      final container = await pumpSettings(tester, SettingsTab.audio);
      expect(settingsOf(container)['musicEnabled'], isNot(true));
    });
  });

  group('the match tab', () {
    testWidgets('the speed segment writes the flag both ways', (tester) async {
      final container = await pumpSettings(tester, SettingsTab.match);
      await tester.tap(find.byKey(const ValueKey('segment-2×')));
      await tester.pumpAndSettle();
      expect(settingsOf(container)['matchSpeedFast'], isTrue);
      await tester.tap(find.byKey(const ValueKey('segment-1×')));
      await tester.pumpAndSettle();
      await settleSave(tester);
      expect(settingsOf(container)['matchSpeedFast'], isFalse);
    });

    testWidgets('the pitch-view pair is two FLAGS, not one choice', (
      tester,
    ) async {
      // The cutaway can be on for both sides, one, or neither.
      final container = await pumpSettings(tester, SettingsTab.match);
      await tester.tap(
        find.byKey(ValueKey('segment-${t('settings.pitchView.ours')}')),
      );
      await tester.pumpAndSettle();
      expect(settingsOf(container)['cutawayOurTeam'], isFalse);
      expect(settingsOf(container)['cutawayOpponent'], isNot(false));
      await tester.tap(
        find.byKey(ValueKey('segment-${t('settings.pitchView.opp')}')),
      );
      await tester.pumpAndSettle();
      await settleSave(tester);
      expect(settingsOf(container)['cutawayOurTeam'], isFalse);
      expect(settingsOf(container)['cutawayOpponent'], isFalse);
    });

    testWidgets('Pro mode is shown but not switchable here', (tester) async {
      // The JS changes it only through the new-team flow. Shown rather than
      // hidden, because which mode you are playing is the biggest single thing
      // about a save.
      await pumpSettings(tester, SettingsTab.match);
      final segment = tester.widget<SettingsSegment>(
        find.byKey(const ValueKey('setting-hardMode')),
      );
      expect(segment.choices.map((c) => c.onTap), everyElement(isNull));
      expect(find.text(t('settings.difficulty.hint')), findsOne);
    });

    testWidgets('and the auto-sell rules are here, with their summary', (
      tester,
    ) async {
      // On the MATCH tab, where the JS has it — the rules fire when a signing
      // lands.
      await pumpSettings(tester, SettingsTab.match);
      expect(find.byKey(const ValueKey('auto-tier-row')), findsOne);
      expect(find.text(t('settings.autoTier.off')), findsOne);
    });
  });

  group('start over', () {
    testWidgets('lives on the general tab, under its own heading', (
      tester,
    ) async {
      // It had been on Account, which is the tab about signing in.
      await pumpSettings(tester, SettingsTab.general);
      expect(find.text(t('settings.startOver').toUpperCase()), findsOne);
      expect(find.byKey(const ValueKey('reset-btn')), findsOne);
      expect(find.byKey(const ValueKey('full-reset-btn')), findsOne);
    });

    testWidgets('asks first, and changes nothing until it is answered', (
      tester,
    ) async {
      final container = await pumpSettings(
        tester,
        SettingsTab.general,
        mutate: (s) => s['clubName'] = 'Ember Rovers',
      );
      await tester.tap(find.byKey(const ValueKey('reset-btn')));
      await tester.pumpAndSettle();
      expect(find.text(t('reset.title')), findsOne);
      expect(container.read(gameProvider).state!['clubName'], 'Ember Rovers');
    });

    testWidgets('and then actually resets', (tester) async {
      // Both rows used to open the card with an EMPTY handler behind the confirm
      // button: a player could read the warning, agree to it, and watch nothing
      // happen.
      final container = await pumpSettings(
        tester,
        SettingsTab.general,
        mutate: (s) => s['clubName'] = 'Ember Rovers',
      );
      await tester.tap(find.byKey(const ValueKey('reset-btn')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('coach-action-reset.confirm')),
      );
      await tester.pumpAndSettle();
      await settleSave(tester);
      expect(
        container.read(gameProvider).state!['clubName'],
        isNot('Ember Rovers'),
      );
      // And the game can still save, because there is no page reload here to
      // clear the reset's freeze.
      expect(container.read(gameProvider).frozen, isFalse);
    });

    testWidgets('a full reset asks first too, and then wipes it', (
      tester,
    ) async {
      final container = await pumpSettings(
        tester,
        SettingsTab.general,
        mutate: (s) => s['clubName'] = 'Ember Rovers',
      );
      await tester.tap(find.byKey(const ValueKey('full-reset-btn')));
      await tester.pumpAndSettle();
      expect(find.text(t('fullReset.title')), findsOne);
      await tester.tap(
        find.byKey(const ValueKey('coach-action-fullReset.confirm')),
      );
      await tester.pumpAndSettle();
      await settleSave(tester);
      expect(
        container.read(gameProvider).state!['clubName'],
        isNot('Ember Rovers'),
      );
    });
  });

  testWidgets('an M4 control is visible but disabled, not hidden', (
    tester,
  ) async {
    // A control that vanishes reads as a missing feature; one that explains
    // itself reads as a feature that is coming.
    await pumpSettings(tester, SettingsTab.account);
    for (final key in ['sign-in-btn', 'feedback-btn']) {
      final found = find.byKey(ValueKey(key));
      expect(found, findsOne, reason: key);
      expect(tester.widget<SettingsAction>(found).onTap, isNull, reason: key);
    }
    // And the rankings toggle, which the JS also disables whenever nobody is
    // signed in.
    expect(
      tester
          .widget<SettingsToggle>(
            find.byKey(const ValueKey('setting-rankingsVisible')),
          )
          .onChanged,
      isNull,
    );
  });

  testWidgets('the entries the JS has that the port was missing are here', (
    tester,
  ) async {
    await pumpSettings(tester, SettingsTab.general);
    for (final key in [
      'club-name-row',
      'team-names-btn',
      'rate-btn',
      'privacy-btn',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOne, reason: key);
    }
  });
}
