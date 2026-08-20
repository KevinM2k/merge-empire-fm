/// Colin, on the four tabs that had nothing to say before.
///
/// The head is quiet until it is tapped, a dismissal MUTES the tip rather than
/// closing a window, and an urgent one gets through the mute anyway. All three
/// are about the ledger in the save, so all three are asserted against it.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/shell/app_shell.dart';
import 'package:merge_empire_fc/ui/shell/coach_floating.dart';
import 'package:merge_empire_fc/ui/shell/coach_tips.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/util/time.dart';

void main() {
  const fixedNow = 1700000000000;
  setUp(() {
    setLocale('en');
    setClock(() => fixedNow);
  });
  tearDown(resetClock);

  /// A save with a squad worth commenting on: nobody injured, nobody old, and a
  /// tier-2 ceiling so there is no merge to point at. That lands on the squad
  /// tab's traitless-XI tip, which carries its own dismiss key.
  Map<String, dynamic> squadSave() {
    final save = createDefaultState();
    (save['grid'] as Map<String, dynamic>)['cells'] = [
      for (var i = 0; i < 11; i++)
        <String, dynamic>{
          'instanceId': 'c$i',
          'definitionId': 'player_t2_def',
          'variant': 0,
        },
    ];
    return save;
  }

  late GameState game;

  Future<void> pumpCoach(
    WidgetTester tester, {
    ShellTab tab = ShellTab.squad,
    Map<String, dynamic>? save,
  }) async {
    final container = ProviderContainer(
      overrides: [
        saveStoreProvider.overrideWithValue(
          MemorySaveStore({saveKeyPrimary: jsonEncode(save ?? squadSave())}),
        ),
      ],
    );
    addTearDown(container.dispose);
    game = container.read(gameProvider)..load();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: ref.watch(appThemeProvider),
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(body: CoachFloating(tab: tab)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  final head = find.byKey(const ValueKey('coach-floating-head'));
  final bubble = find.byKey(const ValueKey('coach-floating-bubble'));

  Map<String, dynamic> ledger() =>
      (game.state!['ui'] as Map<String, dynamic>)['coachDismissals']
          as Map<String, dynamic>;

  group('the head', () {
    testWidgets('is there on a tab that has something to say', (tester) async {
      await pumpCoach(tester);
      expect(head, findsOneWidget);
      expect(
        bubble,
        findsNothing,
        reason: 'he is not a notification — he waits to be tapped',
      );
    });

    testWidgets('and is NOT there on the home tab, which has his orb', (
      tester,
    ) async {
      await pumpCoach(tester, tab: ShellTab.home);
      expect(head, findsNothing, reason: 'the same coach twice on one screen');
    });

    testWidgets('a tap opens what he has to say', (tester) async {
      await pumpCoach(tester);
      await tester.tap(head);
      await tester.pump();
      expect(bubble, findsOneWidget);
      expect(find.text(t('hint.squad_no_traits')), findsOneWidget);
    });
  });

  group('a dismissal', () {
    testWidgets('mutes the tip for its own cooldown, in the SAVE', (
      tester,
    ) async {
      await pumpCoach(tester);
      await tester.tap(head);
      await tester.pump();
      // A second tap on the head is the same as the X: he has been read.
      await tester.tap(head);
      // Past the save's own debounce — a dismissal schedules a write, and a
      // pending timer at the end of a widget test is a failure.
      await tester.pump(const Duration(seconds: 3));

      expect(head, findsNothing, reason: 'dismissed and still on screen');
      expect(
        ledger()['squad_no_traits'],
        fixedNow + coachDayCooldown.inMilliseconds,
        reason: 'keyed on the advice, and muted for a day',
      );
    });

    testWidgets('the X does the same thing', (tester) async {
      await pumpCoach(tester);
      await tester.tap(head);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('coach-floating-close')));
      await tester.pump(const Duration(seconds: 3));
      expect(head, findsNothing);
      expect(ledger(), isNotEmpty);
    });

    testWidgets('and so does a tap anywhere outside it', (tester) async {
      // Leaving it open-but-ignorable read as "it will not go away".
      await pumpCoach(tester);
      await tester.tap(head);
      await tester.pump();
      await tester.tapAt(const Offset(200, 60));
      await tester.pump(const Duration(seconds: 3));
      expect(head, findsNothing);
      expect(ledger(), isNotEmpty);
    });

    testWidgets('but a tap outside a CLOSED head is left alone', (
      tester,
    ) async {
      await pumpCoach(tester);
      await tester.tapAt(const Offset(200, 60));
      await tester.pump();
      expect(
        head,
        findsOneWidget,
        reason: 'an unrelated tap must not clear the nudge',
      );
      // And nothing was written: asking whether a tip is muted must not create
      // the ledger it is asking about.
      expect(
        (game.state!['ui'] as Map?)?.containsKey('coachDismissals') ?? false,
        isFalse,
      );
    });

    testWidgets('and it survives a rebuild, because it is in the save', (
      tester,
    ) async {
      await pumpCoach(tester);
      await tester.tap(head);
      await tester.pump();
      await tester.tap(head);
      await tester.pump(const Duration(seconds: 3));
      final muted = game.state!;

      // A fresh mount of the same save: the mute is a fact about the player, not
      // about the widget that was on screen when they tapped.
      await pumpCoach(tester, save: muted);
      expect(head, findsNothing);
    });
  });

  group('reachability', () {
    testWidgets('a player gets to him by switching tabs, from the shell', (
      tester,
    ) async {
      // **The rule this repo learned the hard way**: a widget test that
      // constructs the thing proves it works and says nothing about whether
      // anybody can get to it. So this one starts at the shell.
      final container = ProviderContainer(
        overrides: [
          saveStoreProvider.overrideWithValue(
            MemorySaveStore({saveKeyPrimary: jsonEncode(squadSave())}),
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
              home: const AppShell(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 32));

      // The app opens on the home tab, where his orb already carries him.
      expect(find.byKey(const ValueKey('coach-floating-head')), findsNothing);

      await tester.tap(find.text(t('nav.squad')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byKey(const ValueKey('coach-floating-head')),
        findsOneWidget,
        reason: 'four tabs out of five still have nothing to say',
      );
    });
  });

  group('the mute', () {
    test('lets an urgent tip through anyway', () {
      final save = squadSave();
      const tip = (
        text: 'Your keeper is on fire',
        category: 'squad',
        priority: true,
        dismissKey: 'urgent',
        cooldown: coachDismissCooldown,
      );
      dismissCoachTip(save, tip, fixedNow);
      expect(
        coachTipMuted(save, tip, fixedNow),
        isFalse,
        reason: 'a priority tip ignores its own cooldown',
      );
    });

    test('expires, rather than lasting forever', () {
      final save = squadSave();
      const tip = (
        text: 'Merge those two',
        category: 'grid',
        priority: false,
        dismissKey: 'merge',
        cooldown: coachDismissCooldown,
      );
      dismissCoachTip(save, tip, fixedNow);
      expect(coachTipMuted(save, tip, fixedNow + 1), isTrue);
      expect(
        coachTipMuted(
          save,
          tip,
          fixedNow + coachDismissCooldown.inMilliseconds + 1,
        ),
        isFalse,
      );
    });

    test('and prunes what has expired, so the ledger cannot grow forever', () {
      final save = squadSave();
      for (var i = 0; i < 50; i++) {
        dismissCoachTip(save, (
          text: 'tip $i',
          category: 'grid',
          priority: false,
          dismissKey: 'tip$i',
          cooldown: coachDismissCooldown,
        ), fixedNow);
      }
      final ui = save['ui'] as Map<String, dynamic>;
      expect((ui['coachDismissals'] as Map).length, 50);
      // One read past the cooldown clears the lot.
      coachTipMuted(save, (
        text: 'anything',
        category: 'grid',
        priority: false,
        dismissKey: 'anything',
        cooldown: coachDismissCooldown,
      ), fixedNow + coachDismissCooldown.inMilliseconds + 1);
      expect((ui['coachDismissals'] as Map), isEmpty);
    });
  });
}
