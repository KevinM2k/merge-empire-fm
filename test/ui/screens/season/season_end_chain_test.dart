/// What arrives after the season summary.
///
/// **The port had a season-end SCREEN and no season-end CHAIN.** The JS follows
/// the summary with the offseason report and, when the top flight has just been
/// won, the champions celebration — twenty translated strings between them with
/// nothing in `lib/` able to print one, over data `endSeason` has returned since
/// M1.
///
/// The two go through `enqueuePopup` rather than opening where they land, which
/// is what puts them in the JS's order without either knowing about the other —
/// and what stops either landing on top of a match.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/season/season_end_button.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';

/// A save with the season over and whatever news the test wants in it.
Map<String, dynamic> finishedSeason({
  String division = 'sunday_league',
  int injured = 0,
  int veterans = 0,
  int wins = 0,
}) {
  final s = createDefaultState();
  final prog = s['progression'] as Map<String, dynamic>;
  // **A veteran cannot be older than the career, and the migration enforces
  // it.** `migration.dart` clamps every card's `seasonsPlayed` to
  // `seasonCount` — it was written for an old multi-click season-end bug — so
  // a fourteen-season man dropped into a season-one save loads as a rookie and
  // never retires. The fixture has to be a save that could exist.
  prog['seasonCount'] = 15;
  prog['currentDivision'] = division;
  prog['seasonMatchesPlayed'] = matchesPerSeason;
  prog['seasonAwardedPlayed'] = matchesPerSeason;
  prog['seasonWins'] = wins;
  prog['seasonComplete'] = true;

  final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
  var slot = 0;
  for (var i = 0; i < injured; i++, slot++) {
    cells[slot] = <String, dynamic>{
      'definitionId': 'player_t1_mid',
      'instanceId': 'inj$i',
      'injured': true,
      // Already served: the offseason's ten-minute credit heals it outright.
      'injuredAt': 0,
      'injuryDurationMs': 1,
    };
  }
  for (var i = 0; i < veterans; i++, slot++) {
    cells[slot] = <String, dynamic>{
      'definitionId': 'player_t1_mid',
      'instanceId': 'vet$i',
      // One short of the retirement sweep, so ending the season trips it.
      'seasonsPlayed': 14,
    };
  }
  return s;
}

Future<ProviderContainer> pumpEnd(
  WidgetTester tester,
  Map<String, dynamic> save,
) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(save)}),
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
          home: const Scaffold(body: EndSeasonButton()),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('end-season')));
  await tester.pumpAndSettle();
  // The summary is a route; the chain runs once it is dismissed.
  await tester.tap(find.byKey(const ValueKey('season-end-continue')));
  await tester.pumpAndSettle();
  return container;
}

Future<void> settleSave(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: saveDebounceMs + 1));
}

void main() {
  setUp(resetPopupQueue);
  tearDown(() {
    resetPopupQueue();
    resetLocale();
  });

  testWidgets('A QUIET SEASON QUEUES NOTHING', (tester) async {
    await pumpEnd(tester, finishedSeason());
    expect(hasPopupWork(), isFalse);
    await settleSave(tester);
  });

  testWidgets('AN INJURY HEALED OVER THE BREAK IS A REPORT', (tester) async {
    await pumpEnd(tester, finishedSeason(injured: 2));
    expect(isPopupPending('offseason-report'), isTrue);
    await settleSave(tester);
  });

  testWidgets('and so is a veteran retiring', (tester) async {
    await pumpEnd(tester, finishedSeason(veterans: 1));
    expect(isPopupPending('offseason-report'), isTrue);
    await settleSave(tester);
  });

  testWidgets('WINNING THE TOP FLIGHT QUEUES THE CELEBRATION', (tester) async {
    // Champions Cup, first place — which is the same test `endSeason` uses to
    // stamp `wonChampionsCup`.
    await pumpEnd(
      tester,
      finishedSeason(division: 'champions_cup', wins: matchesPerSeason),
    );
    expect(isPopupPending('champions-celebration'), isTrue);
    await settleSave(tester);
  });

  testWidgets('and finishing anywhere else does not', (tester) async {
    await pumpEnd(tester, finishedSeason(division: 'champions_cup'));
    expect(isPopupPending('champions-celebration'), isFalse);
    await settleSave(tester);
  });

  testWidgets('THE REPORT COMES FIRST when a title season had news too', (
    tester,
  ) async {
    // The JS opens the celebration only once the report has been read: it is
    // the card that offers to end the career the report is about.
    await pumpEnd(
      tester,
      finishedSeason(
        division: 'champions_cup',
        wins: matchesPerSeason,
        injured: 1,
      ),
    );
    expect(isPopupPending('offseason-report'), isTrue);
    expect(isPopupPending('champions-celebration'), isTrue);
    expect(
      PopupPriority.offseasonReport,
      lessThan(PopupPriority.championsCelebration),
    );
    await settleSave(tester);
  });
}
