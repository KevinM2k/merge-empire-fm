/// The league table sheet.
///
/// **Every one of the fifteen `table.*` strings was unreachable**, which is the
/// loudest tell this repo has: the catalogues are generated from the JS, so a
/// translated string nothing can print is a feature the port dropped, named and
/// counted in ten languages. Two different faults were hiding in the one gap.
///
/// The column letters came off with the JS's four-column header, which the port
/// replaced with a micro-line on purpose — and the letters went on being drawn,
/// in English, in a widget nobody re-read. The badge went missing outright:
/// `season_end` has stamped `lastSeasonStatus` every rollover since M1 and
/// nothing has ever read it.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/league_table.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/home/league_sheets.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

/// The clubs the badges were pinned to, discovered from the table that is
/// actually on screen.
///
/// **The names cannot be hardcoded and the first draft of this test did.** A
/// fresh `createDefaultState()` and the same save after `GameState.load()` name
/// the division's clubs DIFFERENTLY — the pyramid is reseeded on the way in —
/// so three statuses keyed to "Anchor Athletic" badged nobody and the test
/// proved the empty case twice while claiming to prove the full one.
late String promotedClub;
late String relegatedClub;
late String championClub;
late String elsewhereClub;

Future<void> pumpTable(WidgetTester tester, {bool lastSeason = false}) async {
  tester.view.physicalSize = const Size(420 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(createDefaultState())}),
      ),
    ],
  );
  addTearDown(container.dispose);
  final save = container.read(gameProvider).load();

  if (lastSeason) {
    // Read the division's real clubs off the loaded save, then give four of
    // them a move — three that landed HERE and one that landed somewhere else,
    // so the rule `seasonStatusFor` exists to enforce has something to refuse.
    final rows = buildLeagueTable(save).where((r) => !r.isPlayer).toList();
    promotedClub = rows[0].name;
    relegatedClub = rows[1].name;
    championClub = rows[2].name;
    elsewhereClub = rows[3].name;
    (save['progression'] as Map<String, dynamic>)['lastSeasonStatus'] =
        <String, dynamic>{
          'season': 3,
          'player': null,
          'playerDivision': 'sunday_league',
          'teams': <String, dynamic>{
            promotedClub: {
              'status': 'promoted',
              'division': 'sunday_league',
            },
            relegatedClub: {
              'status': 'relegated',
              'division': 'sunday_league',
            },
            championClub: {'status': 'champion', 'division': 'sunday_league'},
            elsewhereClub: {
              'status': 'promoted',
              'division': 'champions_cup',
            },
          },
        };
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: const Scaffold(body: LeagueTableView()),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Every glyph currently on the table, in row order.
List<String> markersOn(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .where((d) => d == '🏆' || d == '↑' || d == '↓')
    .toList();

void main() {
  tearDown(resetLocale);

  group('the P/W/D/L micro-line', () {
    testWidgets('IS DRAWN IN THE PLAYER\'S LANGUAGE, not in English', (
      tester,
    ) async {
      // German is S/S/U/N and French is M/V/N/D. This printed `P12 · 7W 3D 2L`
      // to every one of them, because the letters were literals inside a
      // `TextSpan` rather than the four keys the catalogue carries for them.
      setLocale('de');
      await pumpTable(tester);
      final line = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.textSpan?.toPlainText() ?? '')
          .firstWhere((s) => s.contains('·'), orElse: () => '');
      expect(line, isNotEmpty, reason: 'no P/W/D/L line on the table at all');
      expect(line, contains(t('table.col_drawn')));
      expect(line, contains(t('table.col_lost')));
      // And the English letters are gone rather than sitting beside them.
      expect(line.contains('D '), isFalse);
      expect(line.endsWith('L'), isFalse);
    });

    testWidgets('and English still reads P · W D L', (tester) async {
      await pumpTable(tester);
      final line = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.textSpan?.toPlainText() ?? '')
          .firstWhere((s) => s.contains('·'), orElse: () => '');
      expect(line, matches(RegExp(r'P\d+ · \d+W \d+D \d+L')));
    });
  });

  group('what a club did last season', () {
    testWidgets('NOTHING IS BADGED ON A SAVE WITH NO LAST SEASON', (
      tester,
    ) async {
      // Season one, which is every new player. `lastSeasonStatus` is null until
      // the first rollover, and a legend keying symbols nobody can see is
      // furniture.
      await pumpTable(tester);
      expect(markersOn(tester), isEmpty);
      expect(
        find.byKey(const ValueKey('league-last-season-legend')),
        findsNothing,
      );
    });

    testWidgets('the three moves each get their own glyph', (tester) async {
      await pumpTable(tester, lastSeason: true);
      final markers = markersOn(tester);
      // Three on rows, three more in the legend.
      expect(markers.where((m) => m == '🏆').length, 2);
      expect(markers.where((m) => m == '↑').length, 2);
      expect(markers.where((m) => m == '↓').length, 2);
    });

    testWidgets('AND A CLUB THAT MOVED SOMEWHERE ELSE IS NOT BADGED HERE', (
      tester,
    ) async {
      // The rule `seasonStatusFor` exists to enforce, all the way through to
      // the screen: a badge lights up in the league the move landed in, never
      // in the one the club left. Elsewhere FC was promoted INTO the Champions
      // Cup, so on the Sunday League table it is just another club.
      await pumpTable(tester, lastSeason: true);
      final row = find.ancestor(
        of: find.text(elsewhereClub),
        matching: find.byType(Row),
      );
      if (row.evaluate().isNotEmpty) {
        expect(
          find.descendant(of: row.first, matching: find.text('↑')),
          findsNothing,
        );
      }
      // Whether or not that club is in this division's table at all, exactly
      // three rows carry a marker — the three that moved INTO this league.
      final onRows = tester
          .widgetList<Text>(
            find.byWidgetPredicate(
              (w) =>
                  w is Text &&
                  w.key is ValueKey &&
                  '${(w.key as ValueKey).value}'.startsWith(
                    'league-last-season-',
                  ),
            ),
          )
          .length;
      expect(onRows, 3);
    });

    testWidgets('the legend names them in the player\'s language', (
      tester,
    ) async {
      setLocale('de');
      await pumpTable(tester, lastSeason: true);
      expect(
        find.byKey(const ValueKey('league-last-season-legend')),
        findsOneWidget,
      );
      expect(find.text('Aufsteiger'), findsOneWidget);
      expect(find.text('Absteiger'), findsOneWidget);
      expect(find.text('Meister'), findsOneWidget);
    });

    testWidgets('and the long form is the tooltip, not the row', (
      tester,
    ) async {
      // The catalogue ships both shapes: `table.was_promoted` is a sentence and
      // `table.legend_promoted` is a word. The sentence has nowhere to sit on a
      // table row, so it is what the marker says when you hold it.
      await pumpTable(tester, lastSeason: true);
      final tips = tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .map((w) => w.message)
          .toList();
      expect(tips, contains(t('table.was_promoted')));
      expect(tips, contains(t('table.was_relegated')));
      expect(tips, contains(t('table.was_champion')));
    });
  });
}
