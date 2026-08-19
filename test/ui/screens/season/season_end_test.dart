/// Closing a season.
///
/// Without this the game stops at the fourteenth match: the engine sets
/// `seasonComplete`, every gate refuses, and there is no route onward.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/match/play_button.dart';
import 'package:merge_empire_fc/ui/screens/season/season_end_screen.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

Map<String, dynamic> finishedSeason({bool complete = true}) {
  final s = createDefaultState();
  final prog = s['progression'] as Map<String, dynamic>;
  prog['seasonComplete'] = complete;
  prog['seasonCount'] = 3;
  prog['seasonOpponents'] = [
    'Ayton',
    'Beeches',
    'Cadley',
    'Deeping',
    'Elton',
    'Fairby',
    'Gorton',
  ];
  (s['energy'] as Map<String, dynamic>)['current'] = 10;

  final def = players.firstWhere((p) => p.tier == 1);
  final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
  for (var i = 0; i < 11; i++) {
    cells[i] = <String, dynamic>{
      'definitionId': def.id,
      'instanceId': 'c$i',
      'variant': 0,
    };
  }
  (s['squad'] as Map<String, dynamic>)['lineup'] = [
    for (var i = 0; i < 11; i++)
      <String, dynamic>{
        'slotId': 's$i',
        'slotPosition': 'MID',
        'cardInstanceId': 'c$i',
      },
  ];
  return s;
}

Future<ProviderContainer> pumpPlayArea(
  WidgetTester tester,
  Map<String, dynamic> state,
) async {
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
          // The Play button carries a shimmer that loops forever, so
          // `pumpAndSettle` would never settle. It honours reduce-motion;
          // declaring it here is what a device with that setting on would do.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const Scaffold(body: Center(child: PlayMatchButton())),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> settleSave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: saveDebounceMs + 100));

int seasonOf(ProviderContainer c) =>
    ((c.read(gameProvider).state!['progression']
            as Map<String, dynamic>)['seasonCount']
        as num)
        .toInt();

void main() {
  tearDown(resetLocale);

  testWidgets('a finished season offers a way ON, not a refusal', (
    tester,
  ) async {
    // The dead end this replaced: every gate said no and nothing said what to
    // do about it.
    final container = await pumpPlayArea(tester, finishedSeason());
    expect(container.read(seasonCompleteProvider), isTrue);
    expect(find.byKey(const ValueKey('end-season')), findsOneWidget);
    expect(find.byKey(const ValueKey('play-match')), findsNothing);
  });

  testWidgets('an unfinished season offers the match instead', (tester) async {
    await pumpPlayArea(tester, finishedSeason(complete: false));
    expect(find.byKey(const ValueKey('play-match')), findsOneWidget);
    expect(find.byKey(const ValueKey('end-season')), findsNothing);
  });

  testWidgets('closing it rolls the season on and shows what happened', (
    tester,
  ) async {
    final container = await pumpPlayArea(tester, finishedSeason());
    expect(seasonOf(container), 3);

    await tester.tap(find.byKey(const ValueKey('end-season')));
    await tester.pumpAndSettle();
    await settleSave(tester);

    expect(find.byKey(const ValueKey('season-end')), findsOneWidget);
    expect(find.byKey(const ValueKey('season-end-outcome')), findsOneWidget);
    expect(seasonOf(container), 4, reason: 'the next campaign is drawn');
    expect(
      container.read(seasonCompleteProvider),
      isFalse,
      reason: 'and the block is lifted',
    );
  });

  testWidgets('the summary names the season that FINISHED', (tester) async {
    // endSeason rolls seasonCount on as part of its work, so the number has to
    // be captured before the call or the summary reports the wrong year.
    await pumpPlayArea(tester, finishedSeason());
    await tester.tap(find.byKey(const ValueKey('end-season')));
    await tester.pumpAndSettle();
    await settleSave(tester);

    expect(find.text(t('season.end.title', {'n': 3})), findsOneWidget);
    expect(find.text(t('season.end.continue', {'n': 4})), findsOneWidget);
  });

  testWidgets('and dismissing it returns to the match button', (tester) async {
    final container = await pumpPlayArea(tester, finishedSeason());
    await tester.tap(find.byKey(const ValueKey('end-season')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('season-end-continue')));
    await tester.pumpAndSettle();
    await settleSave(tester);

    expect(find.byKey(const ValueKey('season-end')), findsNothing);
    expect(find.byKey(const ValueKey('play-match')), findsOneWidget);
    expect(container.read(seasonCompleteProvider), isFalse);
  });

  testWidgets('the payout and position are reported', (tester) async {
    await pumpPlayArea(tester, finishedSeason());
    await tester.tap(find.byKey(const ValueKey('end-season')));
    await tester.pumpAndSettle();
    await settleSave(tester);

    expect(find.byKey(const ValueKey('season-end-position')), findsOneWidget);
    expect(find.byKey(const ValueKey('season-end-payout')), findsOneWidget);
  });
}
