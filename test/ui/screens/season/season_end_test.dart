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
import 'package:merge_empire_fc/engine/league_table.dart' show LeagueRow;
import 'package:merge_empire_fc/engine/season_end.dart';
import 'package:merge_empire_fc/ui/screens/match/play_button.dart';
import 'package:merge_empire_fc/ui/screens/season/season_end_screen.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
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

/// A settled season, for pumping the page on its own.
SeasonOutcome outcome({required int position}) => (
  outcome: position <= 2 ? 'promoted' : 'stayed',
  position: position,
  oldDivision: 'sunday_league',
  newDivision: 'sunday_league',
  payout: 1200,
  gemsAwarded: 0,
  ageingReport: const <Map<String, dynamic>>[],
  injuryReport: (recovered: 0, shortened: 0),
  sponsorReport: (expired: 0),
);

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

  testWidgets('THE SEASON IN THREE FIGURES, not a position mislabelled', (
    tester,
  ) async {
    // `season.end.stat_record` is the W-D-L line and `season.end.stat_goals`
    // the scoreline — both sat translated in ten catalogues with nothing able
    // to print either, while the screen's one row used `stat_record` as the
    // LABEL for the position. The spec makes the place the hero and the three
    // figures a band under it.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(kitId: '#4caf50', light: false),
        home: SeasonEndScreen(
          outcome: outcome(position: 3),
          seasonNumber: 2,
          record: const (
            wins: 7,
            draws: 3,
            losses: 4,
            goalsFor: 21,
            goalsAgainst: 14,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('season-end-stats')), findsOneWidget);
    expect(find.text('24'), findsOneWidget, reason: 'seven wins and three draws');
    expect(find.text('7-3-4'), findsOneWidget);
    expect(find.text('21:14'), findsOneWidget);
    // And the place carries its ordinal rather than standing as a bare figure.
    final place = tester.widget<Text>(
      find.byKey(const ValueKey('season-end-position')),
    );
    expect(place.textSpan!.toPlainText(), '3rd');
  });

  testWidgets('and a caller with no record draws the page without the band', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(kitId: '#4caf50', light: false),
        home: SeasonEndScreen(outcome: outcome(position: 1), seasonNumber: 1),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('season-end-stats')), findsNothing);
    expect(find.byKey(const ValueKey('season-end-position')), findsOneWidget);
  });

  testWidgets('WHO WON IT, and how the cup went', (tester) async {
    // `season.end.won_by`, `won_by_you`, `cup_won` and `cup_out` had all sat
    // translated in ten catalogues with nothing able to print one. The winner
    // is the one fact this page can give that the player's own row cannot.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(kitId: '#4caf50', light: false),
        home: SeasonEndScreen(
          outcome: outcome(position: 4),
          seasonNumber: 1,
          winnerName: 'Cobble Street Albion',
          cup: (cupId: 'regional_cup', outcome: 'won', roundReached: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('season-end-winner')), findsOneWidget);
    expect(find.textContaining('Cobble Street Albion'), findsOneWidget);
    expect(find.byKey(const ValueKey('season-end-cup')), findsOneWidget);
  });

  testWidgets('and OUR name gets the other sentence', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(kitId: '#4caf50', light: false),
        home: SeasonEndScreen(
          outcome: outcome(position: 1),
          seasonNumber: 1,
          winnerName: 'Your Club',
          winnerIsUs: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // "You won the {div}", not "Your Club won the {div}".
    expect(find.textContaining('Your Club won'), findsNothing);
    expect(find.byKey(const ValueKey('season-end-winner')), findsOneWidget);
    // And no cup line at all when there was no run.
    expect(find.byKey(const ValueKey('season-end-cup')), findsNothing);
  });

  testWidgets('THE FINAL TABLE IS THERE, and it is FOLDED', (tester) async {
    // Twenty rows of a division the player has just spent a season in is not
    // what they came to this page for — the verdict is — but the one who wants
    // to check the club below them should not have to leave to do it.
    // `season.end.view_table` and `hide_table` are two more keys that shipped
    // in ten languages with nothing able to print either.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(kitId: '#4caf50', light: false),
        home: SeasonEndScreen(
          outcome: outcome(position: 2),
          seasonNumber: 1,
          finalTable: [
            for (var i = 0; i < 8; i++)
              LeagueRow(
                name: 'Club $i',
                isPlayer: i == 1,
                played: 14,
                won: 8 - i,
                drawn: 2,
                lost: 4 + i,
                pts: 26 - i * 3,
                gd: 5 - i,
              ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(t('season.end.view_table')), findsOneWidget);
    expect(find.byKey(const ValueKey('season-end-table')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('season-end-table-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('season-end-table')), findsOneWidget);
    expect(find.text(t('season.end.hide_table')), findsOneWidget);
    expect(find.text('Club 0'), findsOneWidget);
  });

  testWidgets('and no table at all when nobody handed one over', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(kitId: '#4caf50', light: false),
        home: SeasonEndScreen(outcome: outcome(position: 1), seasonNumber: 1),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('season-end-table-toggle')),
      findsNothing,
    );
  });

  testWidgets('AND WHAT THE QUESTS CAME TO, with the autopay note', (
    tester,
  ) async {
    // `season.end.quests_done` and `quests_autopay` are the last two keys off
    // this page's shelf. Read-only by construction: `endSeason` has already
    // swept the track by the time the page is up, and the autopay line is the
    // copy that says so.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(kitId: '#4caf50', light: false),
        home: SeasonEndScreen(
          outcome: outcome(position: 5),
          seasonNumber: 1,
          quests: const [
            (
              id: 'a',
              text: 'Win five',
              progress: 5,
              target: 5,
              completed: true,
              claimed: true,
              coins: 100,
            ),
            (
              id: 'b',
              text: 'Score ten',
              progress: 4,
              target: 10,
              completed: false,
              claimed: false,
              coins: 100,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('season-end-quests')), findsOneWidget);
    expect(
      find.text(t('season.end.quests_done', {'n': 1, 'total': 2})),
      findsOneWidget,
    );
    expect(find.text(t('season.end.quests_autopay')), findsOneWidget);
  });

  testWidgets('and a season with no track says nothing about one', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(kitId: '#4caf50', light: false),
        home: SeasonEndScreen(outcome: outcome(position: 1), seasonNumber: 1),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('season-end-quests')), findsNothing);
  });
}
