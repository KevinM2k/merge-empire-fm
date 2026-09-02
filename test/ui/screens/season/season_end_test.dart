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
import 'package:merge_empire_fc/engine/match_tactics.dart'
    show matchesPerSeason;
import 'package:merge_empire_fc/engine/season_end.dart';
import 'package:merge_empire_fc/ui/screens/match/play_button.dart';
import 'package:merge_empire_fc/ui/screens/season/season_end_screen.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/widgets/report_scroll.dart';
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

  testWidgets('THE LAST MATCH TAKES YOU THERE, with nothing to press', (
    tester,
  ) async {
    // **A finished season used to hand back a Play tab that could not play.**
    // `settleMatch` sets `seasonComplete` at full time and the only thing that
    // ever acted on it was the button this screen swaps in — so the fourteenth
    // match ended, the game went back to the tab, and the player was left
    // holding a save whose one legal move was to press End Season, free to
    // wander the rest of the app first. Reported as being allowed to carry on
    // when the season is over.
    final state = finishedSeason(complete: false);
    (state['progression'] as Map<String, dynamic>)['seasonMatchesPlayed'] =
        matchesPerSeason - 1;
    final container = await pumpPlayArea(tester, state);
    expect(seasonOf(container), 3);
    expect(find.byKey(const ValueKey('play-match')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('play-match')));
    await tester.pumpAndSettle();
    final skip = find.byKey(const ValueKey('match-skip'));
    if (skip.evaluate().isNotEmpty) await tester.tap(skip);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    // **FULL TIME WAITS TO BE DISMISSED.** The commentary page used to leave on
    // its own 1.4s after the sting; it holds now so the ninety minutes can be
    // read back, and the row of controls becomes one CONTINUE.
    final go = find.byKey(const ValueKey('match-continue'));
    expect(go, findsOneWidget, reason: 'full time offered no way out');
    await tester.tap(go);
    await tester.pumpAndSettle();

    // The report, then out of it — and NOTHING else is pressed after this.
    //
    // **SCROLLED TO, because the whole report scrolls now.** The payout and
    // the decline used to be pinned under the scroll; on a report built to fit
    // one screen that bought nothing and left a hole above the money, so both
    // went into it. The link is then below the fold on a 600-point test
    // viewport — which is what a player on a short phone sees too, and they
    // scroll. `warnIfMissed` is the thing that catches this going wrong.
    final out = find.byKey(const ValueKey('summary-no-thanks'));
    expect(
      out,
      findsOneWidget,
      reason: 'full time should be showing the report',
    );
    await tester.scrollUntilVisible(out, 120);
    await tester.pumpAndSettle();
    await tester.tap(out);
    await tester.pumpAndSettle();
    // **WAIT FOR THE SCREEN, not for a number of milliseconds.** The chain
    // after the report — the bid, the sponsor, the rating prompt — runs before
    // the season settles, and parts of it are genuinely asynchronous. A fixed
    // pump is a race that this passes alone and loses when the suite is running
    // it alongside forty other files.
    // **AND A BID IS ANSWERED IF ONE CAME IN.** `maybeGenerateOffer` rolls
    // after every match, so about a third of the runs of this test put a
    // transfer offer up between the report and the season — a real dialog,
    // waiting for a real answer, which is exactly what a player would see. A
    // test that walked past it looked like a flaky season screen, and chasing
    // that is what turned up the two real bugs above it. Parked with a tap
    // outside, which is the one dismissal that decides nothing.
    for (var i = 0; i < 60; i++) {
      if (find.byKey(const ValueKey('season-end')).evaluate().isNotEmpty) break;
      if (find.byKey(const ValueKey('transfer-offer')).evaluate().isNotEmpty) {
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
      }
      // **AND THE SPONSOR ROLL IS THE OTHER HALF OF THAT.** `_afterMatch`
      // offers a sponsor on the matches where no bid came in, so it is the
      // same coin flip seen from the other side — and a coach card has no
      // barrier to tap through, so the dismissal above walks straight past it
      // and this loop would run out with the card still up. Its own Decline
      // is what a player has.
      final sponsor = find.byKey(const ValueKey('sponsor-offer'));
      if (sponsor.evaluate().isNotEmpty) {
        await tester.tap(
          find.descendant(
            of: sponsor,
            matching: find.byKey(const ValueKey('coach-action-common.decline')),
          ),
        );
        await tester.pumpAndSettle();
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    await settleSave(tester);

    expect(
      find.byKey(const ValueKey('season-end')),
      findsOneWidget,
      reason: 'the season closed itself',
    );
    expect(seasonOf(container), 4, reason: 'and the next campaign is drawn');
    expect(container.read(seasonCompleteProvider), isFalse);
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

  testWidgets('A SHORT SEASON STARTS AT THE TOP, like full time', (
    tester,
  ) async {
    // **THIS REVERSES A DECISION, and the reversal was asked for.** The page
    // was centred in the room the pinned foot left it, because a stack of
    // cards over a pinned foot put the report against the status bar with 420
    // points of nothing under it — measured on this phone. Centring closed
    // that hole and introduced a different one: the first card is the RESULT,
    // and a result that floats down the page as the report grows or shrinks
    // reads as the page settling rather than as the verdict. Reported from the
    // couch in as many words — the screen is vertically centred, which is
    // wrong, use the end-of-match screen — and full time has been top-aligned
    // for exactly this reason since it was asked for there.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(kitId: '#4caf50', light: false),
        home: SeasonEndScreen(outcome: outcome(position: 3), seasonNumber: 2),
      ),
    );
    await tester.pumpAndSettle();

    final page = tester.getRect(find.byType(ReportScroll));
    final head = tester.getRect(find.byKey(const ValueKey('season-end-title')));
    // The report's own top inset and nothing more — the room falls BELOW the
    // last card, above the pinned foot, which is where full time puts it.
    expect(
      head.top - page.top,
      lessThan(30),
      reason: 'the result is floating down the page again',
    );
    // And it still fits, so nothing here made the page scroll.
    final position = tester
        .widget<Scrollable>(find.byType(Scrollable).first)
        .controller
        ?.position;
    expect(position?.maxScrollExtent ?? 0, closeTo(0, 0.5));
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

  testWidgets('THE PAGE IS GROUPS, not one column on the background', (
    tester,
  ) async {
    // Every line of this screen used to sit loose on `kit.bg` at the same
    // distance from the page and from everything else, so nothing said which
    // of them belonged together — reported exactly that way. `screens.css`
    // carries `.se-hero`, `.se-line` and `.se-card` and the port had ported
    // the contents of all three and none of the containers.
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
          winnerName: 'Ayton',
          finalTable: [
            LeagueRow(
              name: 'Ayton',
              isPlayer: false,
              played: 14,
              won: 10,
              drawn: 2,
              lost: 2,
              pts: 32,
              gd: 18,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The place, the verdict and the three figures are ONE box.
    final hero = find.ancestor(
      of: find.byKey(const ValueKey('season-end-position')),
      matching: find.byType(DecoratedBox),
    );
    expect(hero, findsWidgets);
    expect(
      find.descendant(
        of: hero.first,
        matching: find.byKey(const ValueKey('season-end-stats')),
      ),
      findsOneWidget,
      reason: 'the figures are not in the same box as the result',
    );
    expect(
      find.descendant(
        of: hero.first,
        matching: find.byKey(const ValueKey('season-end-outcome')),
      ),
      findsOneWidget,
    );
    // And the payout is NOT: it rides in the pinned foot with the way out,
    // which is what the button is collecting. `.se-cta` in the spec.
    expect(
      find.descendant(
        of: hero.first,
        matching: find.byKey(const ValueKey('season-end-payout')),
      ),
      findsNothing,
    );
    final payout = tester.getRect(
      find.byKey(const ValueKey('season-end-payout')),
    );
    final button = tester.getRect(
      find.byKey(const ValueKey('season-end-continue')),
    );
    expect(payout.bottom, lessThanOrEqualTo(button.top));
    expect(
      button.bottom,
      greaterThan(tester.getRect(hero.first).bottom),
      reason: 'the way out is pinned under the summary, not inside it',
    );
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
