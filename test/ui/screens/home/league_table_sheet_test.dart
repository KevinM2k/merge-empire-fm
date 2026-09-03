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
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/engine/fixture_preview.dart';
import 'package:merge_empire_fc/engine/league_table.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart' show opponentsPerSeason;
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart';
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

Future<void> pumpTable(
  WidgetTester tester, {
  bool lastSeason = false,
  int matchesPlayed = 0,
}) async {
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
  // Every division's table is played out to the round YOU are on — a fresh save
  // is round zero, so the whole pyramid honestly reads P0 and a test that
  // forgets to advance it proves nothing about the simulation.
  if (matchesPlayed > 0) {
    (save['progression'] as Map<String, dynamic>)['seasonMatchesPlayed'] =
        matchesPlayed;
  }

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

  /// **`Division.name` is the English literal on the data record**, and all
  /// seven names have shipped translated in ten catalogues since the generator
  /// first ran — German reads Sonntagsliga, Regionalliga, Champions-Liga.
  /// `tName` exists for exactly this and its own doc names divisions first; the
  /// trophy room and the pyramid editor already went through it, and the header
  /// a player looks at most did not.
  ///
  /// The same fault as `trait_copy.dart`'s — "every trait in the game was
  /// untranslatable and a French player's Finisher was still called Finisher" —
  /// on the most-shown proper noun in the game.
  group('the division is NAMED in the player\'s language', () {
    testWidgets('the header and the way back both go through the catalogue', (
      tester,
    ) async {
      setLocale('de');
      await pumpTable(tester);
      expect(find.text('SONNTAGSLIGA'), findsOneWidget);
      expect(find.text('SUNDAY LEAGUE'), findsNothing);

      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('AMATEURLIGA'), findsOneWidget);
      final back = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('league-back-to-own')),
          matching: find.byType(Text),
        ),
      );
      expect(back.data, contains('Sonntagsliga'));
    });

    test('and every division on the ladder has a translated name', () {
      // The gap between the catalogue's count and the caller's is the work
      // queue; here they have to match exactly, or a division somewhere down
      // the pyramid quietly reverts to English.
      for (final locale in ['de', 'fr', 'es']) {
        setLocale(locale);
        for (final d in divisions) {
          final named = tName('division', {'id': d.id, 'name': d.name});
          expect(
            named,
            isNot(d.name),
            reason: '$locale still calls ${d.id} by its English name',
          );
        }
      }
    });
  });

  group('browsing the pyramid', () {
    testWidgets('IT OPENS ON YOUR OWN DIVISION', (tester) async {
      // Seven leagues in the pager and only one of them is yours. Opening
      // anywhere else would make the control that exists to show you the rest
      // of the ladder cost a swipe to get back from.
      await pumpTable(tester);
      expect(
        find.byKey(const ValueKey('league-table-sunday_league')),
        findsOneWidget,
      );
      // `SheetHeader` upper-cases the title itself.
      expect(
        find.text(divisions.first.name.toUpperCase()),
        findsOneWidget,
      );
      // And there is nothing to go back to, so nothing offers it.
      expect(find.byKey(const ValueKey('league-back-to-own')), findsNothing);
    });

    testWidgets('a swipe shows the league above, played out in full', (
      tester,
    ) async {
      // `buildPyramidTable` plays every AI fixture through the same sampler the
      // player's own league pre-simulates with — it had no caller at all, so
      // the whole ladder was invisible. A table of clubs on zero points is what
      // a table nobody simulated looks like.
      await pumpTable(tester, matchesPlayed: 6);
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('league-table-amateur_cup')),
        findsOneWidget,
      );
      expect(find.text(divisions[1].name.toUpperCase()), findsOneWidget);
      final lines = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.textSpan?.toPlainText() ?? '')
          .where((t) => t.contains('·'))
          .toList();
      expect(lines, isNotEmpty);
      expect(
        lines.where((l) => l.startsWith('P0 ')),
        isEmpty,
        reason: 'a division nobody played reads P0 all the way down',
      );
    });

    testWidgets('AND THE WAY BACK NAMES THE LEAGUE IT GOES TO', (tester) async {
      await pumpTable(tester);
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      final back = find.byKey(const ValueKey('league-back-to-own'));
      expect(back, findsOneWidget);
      // `table.back_to_league` is '⚽ Back to {division}' — the placeholder is
      // the point, and a button reading "Back to {division}" is the bug that
      // shape of string invites.
      final label = tester.widget<Text>(
        find.descendant(of: back, matching: find.byType(Text)),
      );
      expect(label.data, contains(divisions.first.name));
      expect(label.data, isNot(contains('{division}')));

      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('league-table-sunday_league')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('league-back-to-own')), findsNothing);
    });

    testWidgets('the hint says what the dots only imply', (tester) async {
      await pumpTable(tester);
      expect(find.byKey(const ValueKey('league-swipe-hint')), findsOneWidget);
      expect(find.text(t('table.swipe_to_cycle')), findsOneWidget);
    });

    testWidgets('AND A LEAGUE RENDERS THE SAME EVERY TIME YOU LOOK', (
      tester,
    ) async {
      // The engine's own promise, and the reason it seeds off (season,
      // division) rather than drawing from the shared stream: "a table that
      // reshuffled itself on each visit would be worse than the rounding ever
      // was". Nothing about the sampled table is stored, so the only thing
      // holding it still is that seed.
      await pumpTable(tester, matchesPlayed: 6);
      Future<List<String>> browseToAmateurCup() async {
        await tester.drag(find.byType(PageView), const Offset(-400, 0));
        await tester.pumpAndSettle();
        final rows = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byKey(const ValueKey('league-table-amateur_cup')),
                matching: find.byType(Text),
              ),
            )
            .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
            .toList();
        await tester.drag(find.byType(PageView), const Offset(400, 0));
        await tester.pumpAndSettle();
        return rows;
      }

      final first = await browseToAmateurCup();
      expect(first, isNotEmpty);
      expect(await browseToAmateurCup(), first);
    });

    testWidgets('and browsing never stamps movement on your own table', (
      tester,
    ) async {
      // `buildLeagueTable` writes `prevPos` and `posDelta` back into the save
      // for the next-match card to read. `buildPyramidTable` stores nothing —
      // which is why the pager asks the provider for YOUR league and the engine
      // for everyone else's. Six leagues browsed must not leave six leagues'
      // worth of movement behind.
      await pumpTable(tester, matchesPlayed: 6);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LeagueTableView)),
      );
      List<int?> deltas() => container
          .read(leagueTableProvider)
          .map((r) => r.posDelta)
          .toList();

      final before = deltas();
      for (var i = 0; i < 3; i++) {
        await tester.drag(find.byType(PageView), const Offset(-400, 0));
        await tester.pumpAndSettle();
      }
      expect(deltas(), before);
    });
  });

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

  group('THE RATING COLUMN TAKES NO MODIFIERS, on any row', () {
    // Reported from the couch: "my team is 88 with +4 home modifier but when I
    // look in the table it's saying my team is 92. The table should not be
    // taking any modifiers into account, for me nor AI teams."
    //
    // It was measuring two different things in one column. Every AI row is the
    // club's stored figure out of `seasonOpponentRatings` with nothing added;
    // the player's row was `effectiveSquadRating`, which is what the side walks
    // out at in the NEXT FIXTURE — home advantage, the stagnation buff and the
    // relegation lift all folded in. A standing does not change because the
    // next game happens to be at home.
    test('the player\'s row is the base rating, not the next fixture\'s', () {
      final container = ProviderContainer(
        overrides: [
          saveStoreProvider.overrideWithValue(
            MemorySaveStore({saveKeyPrimary: jsonEncode(createDefaultState())}),
          ),
        ],
      );
      addTearDown(container.dispose);
      final save = container.read(gameProvider).load();
      save['clubName'] = 'Testville';
      // A crowd, so the next fixture actually carries something to leak.
      (save['clubAssets'] as Map<String, dynamic>)[AssetCategory.fanzone] = {
        'owned': true,
        'tier': 3,
      };
      final prog = save['progression'] as Map<String, dynamic>;
      final season = (prog['seasonCount'] as num?)?.toInt() ?? 1;
      var played = 0;
      while (!fixtureIsHome(season, played % opponentsPerSeason, played)) {
        played++;
      }
      prog['seasonMatchesPlayed'] = played;

      final preview = previewFixture(save)!;
      expect(
        preview.isHome && preview.ourHomeAdv > 0,
        isTrue,
        reason: 'nothing was being added, so nothing could leak',
      );
      expect(
        preview.effectiveSquadRating.round(),
        greaterThan(preview.squadRating),
        reason: 'the two figures are the same, so the test proves nothing',
      );

      expect(
        container.read(leagueRatingsProvider)['Testville'],
        preview.squadRating,
        reason: 'the table is quoting the next fixture rather than the squad',
      );
    });
  });
}
