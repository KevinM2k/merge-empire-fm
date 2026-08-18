/// The Play tab.
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
import 'package:merge_empire_fc/ui/screens/league/league_providers.dart';
import 'package:merge_empire_fc/ui/screens/league/league_screen.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

Future<void> settleSave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: saveDebounceMs + 100));

Future<ProviderContainer> pumpLeague(
  WidgetTester tester, {
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

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: const Scaffold(body: LeagueScreen()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

LeagueScreenState stateOf(WidgetTester tester) =>
    tester.state<LeagueScreenState>(find.byType(LeagueScreen));

/// A finished season, so the table and the schedule both have something in them.
void playedSeason(Map<String, dynamic> s) {
  final prog = s['progression'] as Map<String, dynamic>;
  prog['seasonOpponents'] = ['Ayton', 'Beeches', 'Cadley'];
  prog['seasonFixtures'] = [
    {
      'round': 1,
      'homeTeam': s['clubName'],
      'awayTeam': 'Ayton',
      'homeGoals': 2,
      'awayGoals': 1,
    },
    {
      'round': 2,
      'homeTeam': 'Beeches',
      'awayTeam': 'Cadley',
      'homeGoals': 0,
      'awayGoals': 0,
    },
    {'round': 3, 'homeTeam': 'Cadley', 'awayTeam': s['clubName']},
  ];
}

void main() {
  tearDown(resetLocale);

  group('the sub-tabs', () {
    testWidgets('open on Overview', (tester) async {
      await pumpLeague(tester);
      expect(stateOf(tester).subTab, LeagueSubTab.overview);
    });

    testWidgets('every one is reachable', (tester) async {
      await pumpLeague(tester);
      for (final tab in LeagueSubTab.values) {
        await tester.tap(find.byKey(ValueKey('league-subtab-${tab.name}')));
        await tester.pumpAndSettle();
        expect(stateOf(tester).subTab, tab);
      }
    });

    testWidgets('resetToOverview brings it home from anywhere', (tester) async {
      // What the bar's Play tab calls. Tapping Play is "take me home", and last
      // week's table is not home.
      await pumpLeague(tester);
      stateOf(tester).setSubTab(LeagueSubTab.table);
      await tester.pumpAndSettle();
      expect(stateOf(tester).subTab, LeagueSubTab.table);

      stateOf(tester).resetToOverview();
      await tester.pumpAndSettle();
      expect(stateOf(tester).subTab, LeagueSubTab.overview);
    });

    testWidgets('the diorama is named rather than half-built', (tester) async {
      // Its technique is gated on profile timings from a physical device, so
      // it stays named until those exist.
      await pumpLeague(tester);
      expect(
        find.byKey(const ValueKey('league-overview-pending')),
        findsOneWidget,
      );
    });

    testWidgets('training is a real list of drills now', (tester) async {
      await pumpLeague(tester);
      await tester.tap(find.byKey(const ValueKey('league-subtab-training')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('training-view')), findsOneWidget);
      expect(find.byKey(const ValueKey('training-penalty')), findsOneWidget);
    });
  });

  group('the table', () {
    testWidgets('lists the division and its rows', (tester) async {
      final container = await pumpLeague(tester, mutate: playedSeason);
      await tester.tap(find.byKey(const ValueKey('league-subtab-table')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('league-table')), findsOneWidget);
      expect(find.text(container.read(divisionNameProvider)), findsOneWidget);
      expect(container.read(leagueTableProvider), isNotEmpty);
    });

    testWidgets('marks the player s own club', (tester) async {
      // It is the row they came to look at; everything else is context for it.
      final container = await pumpLeague(tester, mutate: playedSeason);
      final rows = container.read(leagueTableProvider);
      expect(rows.where((r) => r.isPlayer).length, 1);
    });

    testWidgets('is sorted by position', (tester) async {
      final container = await pumpLeague(tester, mutate: playedSeason);
      final rows = container.read(leagueTableProvider);
      for (var i = 1; i < rows.length; i++) {
        expect(
          rows[i - 1].pts >= rows[i].pts,
          isTrue,
          reason: 'row $i out of order',
        );
      }
    });
  });

  group('the fixtures', () {
    testWidgets('list the schedule in round order', (tester) async {
      final container = await pumpLeague(tester, mutate: playedSeason);
      await tester.tap(find.byKey(const ValueKey('league-subtab-fixtures')));
      await tester.pumpAndSettle();

      final rows = container.read(fixturesProvider);
      expect(rows.length, 3);
      expect(rows.map((r) => r.round), [1, 2, 3]);
      expect(find.byKey(const ValueKey('league-fixtures')), findsOneWidget);
    });

    testWidgets('a played fixture carries its score, an unplayed one does not', (
      tester,
    ) async {
      final container = await pumpLeague(tester, mutate: playedSeason);
      final rows = container.read(fixturesProvider);
      expect(rows.first.played, isTrue);
      expect(rows.first.homeGoals, 2);
      expect(rows.last.played, isFalse);
      expect(rows.last.homeGoals, isNull);
    });

    testWidgets('the player s own games are marked', (tester) async {
      final container = await pumpLeague(tester, mutate: playedSeason);
      final rows = container.read(fixturesProvider);
      expect(rows.where((r) => r.involvesPlayer).length, 2);
      expect(rows[1].involvesPlayer, isFalse);
    });

    testWidgets('an unstarted season says so rather than showing nothing', (
      tester,
    ) async {
      await pumpLeague(tester);
      await tester.tap(find.byKey(const ValueKey('league-subtab-fixtures')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('league-fixtures-empty')),
        findsOneWidget,
      );
    });
  });

  group('playing a match', () {
    testWidgets('the fixtures tab offers a Play button', (tester) async {
      await pumpLeague(tester, mutate: playedSeason);
      await tester.tap(find.byKey(const ValueKey('league-subtab-fixtures')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play-match')), findsOneWidget);
    });

    testWidgets('a squad too small is refused, and told why', (tester) async {
      // canPlayMatch folds three refusals together; the button names which.
      await pumpLeague(tester, mutate: playedSeason);
      await tester.tap(find.byKey(const ValueKey('league-subtab-fixtures')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const ValueKey('play-match')))
            .onPressed,
        isNull,
      );
      expect(find.byKey(const ValueKey('play-blocked')), findsOneWidget);
    });

    testWidgets('a ready save can start one, and it takes over', (tester) async {
      final container = await pumpLeague(tester, mutate: readyToPlay);
      await tester.tap(find.byKey(const ValueKey('league-subtab-fixtures')));
      await tester.pumpAndSettle();

      final energyBefore = container.read(energyProvider);
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const ValueKey('play-match')))
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(const ValueKey('play-match')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('match-screen')), findsOneWidget);
      expect(container.read(energyProvider), lessThan(energyBefore));
      expect(container.read(tickGatesProvider).matchOpen, isTrue);

      // Close it: the clock is a periodic timer, and a test that walks away
      // mid-match leaves it pending.
      await tester.tap(find.byKey(const ValueKey('match-skip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('match-close')));
      await tester.pumpAndSettle();
      await settleSave(tester);
    });

    testWidgets('full time commits, and closing pays', (tester) async {
      // The coins land on dismissal, not at full time: the doubling offer lives
      // on the closing screen.
      final container = await pumpLeague(tester, mutate: readyToPlay);
      await tester.tap(find.byKey(const ValueKey('league-subtab-fixtures')));
      await tester.pumpAndSettle();

      final playedBefore =
          (container.read(gameProvider).state!['progression']
              as Map<String, dynamic>)['matchesPlayed'] as num;

      await tester.tap(find.byKey(const ValueKey('play-match')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('match-skip')));
      await tester.pumpAndSettle();

      // Full time: the season has moved on, and the gates are still claimed.
      expect(
        (container.read(gameProvider).state!['progression']
            as Map<String, dynamic>)['matchesPlayed'],
        greaterThan(playedBefore),
      );

      final coinsAtFullTime = container.read(coinsProvider);
      await tester.tap(find.byKey(const ValueKey('match-close')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('match-screen')), findsNothing);
      expect(container.read(coinsProvider), greaterThanOrEqualTo(coinsAtFullTime));
      expect(
        container.read(tickGatesProvider).matchOpen,
        isFalse,
        reason: 'the screen handed the gates back',
      );
      await settleSave(tester);
    });
  });
}

/// A save that can actually take the field.
void readyToPlay(Map<String, dynamic> s) {
  playedSeason(s);
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
}
