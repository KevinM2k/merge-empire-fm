/// Colin's tour after the tutorial, in the shell — see `engine/guide_engine.dart`
/// for the chain itself and `test/engine/guide_engine_test.dart` for its rules.
/// This is the wiring: the corner says the step, opening the tab it points at
/// spends the step, and a card landing spends the scout.

/// **The bar itself stays quiet.** There was a pulsing pill round whichever tab
/// the outstanding step led to, and it went — see `ui/shell/guide.dart`. What
/// is asserted here is that opening a tab still spends the step it belonged to,
/// which is the half of the mechanism that survived.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/coach_tip_engine.dart';
import 'package:merge_empire_fc/engine/guide_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart' show saveDebounceMs;
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/home/coach_bubble.dart';
import 'package:merge_empire_fc/ui/screens/placeholder_screen.dart';
import 'package:merge_empire_fc/ui/shell/app_shell.dart';
import 'package:merge_empire_fc/ui/shell/coach_floating.dart';
import 'package:merge_empire_fc/ui/shell/coach_tips.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

Map<String, dynamic> _toured({bool completed = true}) {
  final s = createDefaultState();
  (s['tutorial'] as Map<String, dynamic>)
    ..['done'] = true
    ..['completed'] = completed;
  // Eleven on the grid, so the pool has things to say too — the tour has to
  // OUTRANK them, not merely fill a silence.
  (s['grid'] as Map<String, dynamic>)['cells'] = [
    for (var i = 0; i < 11; i++)
      <String, dynamic>{
        'instanceId': 'c$i',
        'definitionId': 'player_t2_def',
        'variant': 0,
      },
  ];
  return s;
}

ProviderContainer _container(Map<String, dynamic> save) {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(save)}),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(gameProvider).load();
  return container;
}

Future<ProviderContainer> _pumpShell(
  WidgetTester tester,
  Map<String, dynamic> save,
) async {
  final container = _container(save);
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
          home: AppShell(
            screenFor: (tab) => PlaceholderScreen(
              key: ValueKey('screen-${tab.name}'),
              label: tab.name,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 32));
  return container;
}

/// The save debounce, so no timer outlives the test.
Future<void> _settleSave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: saveDebounceMs + 100));

void main() {
  setUp(() => setLocale('en'));
  tearDown(() {
    resetLocale();
    resetBus();
  });

  group('WHAT THE CORNER SAYS', () {
    test('the tour outranks the pool on a tab it has a step for', () {
      final s = _toured();
      expect(
        coachTipFor(s, ShellTab.grid)?.text,
        guideText(guideSteps.firstWhere((g) => g.id == 'scout')),
      );
      expect(coachTipFor(s, ShellTab.grid)?.category, 'guide');
    });

    test('and steps aside once the step is spent', () {
      final s = _toured();
      markGuideDone(s, 'scout');
      markGuideDone(s, 'squad_tab');
      expect(coachTipFor(s, ShellTab.grid)?.category, 'grid');
    });

    test('a save that was only SETTLED as done hears the pool, as before', () {
      expect(coachTipFor(_toured(completed: false), ShellTab.grid)?.category,
          'grid');
    });

    test('and the home orb carries the home steps, ahead of the match read', () {
      final c = _container(_toured());
      final tips = c.read(coachTipsProvider);
      expect(tips.first.id, 'guide.dugout');
      expect(tips.length, greaterThan(1), reason: 'the match read is still there');
    });

    testWidgets('the corner head says it on the squad tab', (tester) async {
      final container = _container(_toured());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => MaterialApp(
              theme: ref.watch(appThemeProvider),
              home: const MediaQuery(
                data: MediaQueryData(disableAnimations: true),
                child: Scaffold(body: CoachFloating(tab: ShellTab.squad)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('coach-floating-head')));
      await tester.pump();
      expect(find.text(t('guide.squad_fill')), findsOneWidget);
    });
  });

  group('THE BAR', () {
    testWidgets('the bar draws nothing for the tour, on any tab', (
      tester,
    ) async {
      final c = await _pumpShell(tester, _toured());
      // The step furthest along that ever lit a tab: the scout is spent, so
      // "open the Squad tab" is the one outstanding.
      await tester.tap(find.byKey(const ValueKey('tab-grid')));
      await tester.pump(const Duration(milliseconds: 32));
      await tester.pump(const Duration(milliseconds: 32));
      emit('card:placed', {'card': null});
      await tester.pump(const Duration(milliseconds: 32));
      expect(hasSeenTip(c.read(gameProvider).state!, 'guide.scout'), isTrue);
      expect(find.byKey(const ValueKey('guide-glow-pill')), findsNothing);
      await _settleSave(tester);
    });

    testWidgets('a card landing spends the scout, and opening Squad spends it', (
      tester,
    ) async {
      final c = await _pumpShell(tester, _toured());
      await tester.tap(find.byKey(const ValueKey('tab-grid')));
      await tester.pump(const Duration(milliseconds: 32));
      await tester.pump(const Duration(milliseconds: 32));
      emit('card:placed', {'card': null});
      await tester.pump(const Duration(milliseconds: 32));
      final save = c.read(gameProvider).state!;
      expect(hasSeenTip(save, 'guide.scout'), isTrue);
      await _settleSave(tester);

      // Opening the Squad tab spends the step that pointed at it.
      await tester.tap(find.byKey(const ValueKey('tab-squad')));
      await tester.pump(const Duration(milliseconds: 32));
      await tester.pump(const Duration(milliseconds: 32));
      expect(hasSeenTip(c.read(gameProvider).state!, 'guide.squad_tab'), isTrue);
      await _settleSave(tester);
    });

    testWidgets('and a settled save is not written to on a tab switch', (
      tester,
    ) async {
      final c = await _pumpShell(tester, _toured(completed: false));
      await tester.tap(find.byKey(const ValueKey('tab-grid')));
      await tester.pump(const Duration(milliseconds: 32));
      await tester.pump(const Duration(milliseconds: 32));
      emit('card:placed', {'card': null});
      await tester.pump(const Duration(milliseconds: 32));
      final seen = c.read(gameProvider).state!['seenTips'] as List? ?? [];
      expect(seen.where((e) => '$e'.startsWith('guide.')), isEmpty);
    });
  });
}
