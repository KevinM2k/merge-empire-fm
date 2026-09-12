/// The fixtures sheet.
///
/// **`fixtures.opp_rating` and `fixtures.opp_rating_est` had no caller.** The
/// opponent's rating is drawn as a bare number in an unlabelled 34px column,
/// between a club name and a score — and the sentence identifying it, including
/// the one that explains what the tilde means, has shipped in ten languages
/// since the generator first ran.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/cups.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/players.dart' show players;
import 'package:merge_empire_fc/engine/cup_engine.dart'
    show activeCup, commitCupRound, prepareCupRound;
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart'
    show ourCupTiesProvider;
import 'package:merge_empire_fc/ui/screens/home/league_sheets.dart';
import 'package:merge_empire_fc/ui/screens/match/cup_launcher.dart'
    show beginCupRound, cupDueAfterMatches, settleCupRound;
import 'package:merge_empire_fc/util/random.dart' show setSeed;
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

Future<ProviderContainer> pumpFixtures(
  WidgetTester tester, {
  bool dropOpponentRatings = false,
  void Function(Map<String, dynamic> save)? mutate,
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
  // Through the RUNNER: the season's schedule is one of the sweeps a boot owes,
  // and `game.load()` alone leaves the sheet with nothing to draw.
  final save = container.read(gameRunnerProvider).boot();
  if (dropOpponentRatings) {
    (save['progression'] as Map<String, dynamic>).remove('seasonOpponentRatings');
  }
  mutate?.call(save);
  // A mutation that commits a cup round fires the wiring, which arms the save
  // debounce; flush it here or the test ends with a timer still pending.
  container.read(gameProvider).saveNow();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: const Scaffold(body: FixturesView()),
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

/// Every fixture row's rating number, paired with the sentence it carries.
List<({String shown, String tip})> ratings(WidgetTester tester) => [
  for (final tip in tester.widgetList<Tooltip>(find.byType(Tooltip)))
    if (tip.child case final Text text
        when '${text.key}'.contains('fixture-rating-'))
      (shown: text.data ?? '', tip: tip.message ?? ''),
];

void main() {
  tearDown(resetLocale);

  testWidgets('THE OPPONENT RATING SAYS WHAT IT IS', (tester) async {
    await pumpFixtures(tester);
    final rows = ratings(tester);
    expect(rows, isNotEmpty, reason: 'no fixture row drew a rating at all');
    for (final row in rows) {
      final n = int.parse(row.shown.replaceAll('~', ''));
      final estimated = row.shown.startsWith('~');
      expect(
        row.tip,
        t(
          estimated ? 'fixtures.opp_rating_est' : 'fixtures.opp_rating',
          {'rating': n},
        ),
      );
      // The placeholder is filled, not printed.
      expect(row.tip, isNot(contains('{rating}')));
      expect(row.tip, contains('$n'));
    }
  });

  testWidgets('AND AN ESTIMATE SAYS SO IN WORDS, not only with a tilde', (
    tester,
  ) async {
    // The tilde was the whole signal, which is a convention the player has to
    // already know — and `fixtures.opp_rating_est` spells it out ("estimated
    // ~division midpoint") in ten languages with nothing able to reach it.
    //
    // **A booted save has no estimated rows**, and finding that out is half the
    // value of writing this: `seasonOpponentRatings` is materialised for the
    // whole season by the boot sweep, so `ratingEstimated` is only true on a
    // save whose ratings have not been drawn. That is the state to build, not
    // one to hope a fresh save happens to be in.
    await pumpFixtures(tester, dropOpponentRatings: true);
    final rows = ratings(tester);
    expect(rows, isNotEmpty);
    expect(rows.every((r) => r.shown.startsWith('~')), isTrue);
    for (final row in rows) {
      final n = int.parse(row.shown.replaceAll('~', ''));
      expect(row.tip, t('fixtures.opp_rating_est', {'rating': n}));
      expect(row.tip, isNot(t('fixtures.opp_rating', {'rating': n})));
    }
  });


  /// Eleven fit cards on the grid and in the lineup.
  ///
  /// `beginCupRound` goes through `matchStartBlocked`, which refuses a squad
  /// too small — and a booted default save has nobody on the grid, so without
  /// this every attempt comes back null and a seeded search for a shootout
  /// searches nothing at all. (It did: 400 seeds, no ties.)
  void fieldASide(Map<String, dynamic> save) {
    final def = players.firstWhere((p) => p.tier == 1);
    final cells = (save['grid'] as Map<String, dynamic>)['cells'] as List;
    for (var i = 0; i < 11; i++) {
      cells[i] = <String, dynamic>{
        'definitionId': def.id,
        'instanceId': 'c\$i',
        'variant': 0,
      };
    }
    (save['squad'] as Map<String, dynamic>)['lineup'] = [
      for (var i = 0; i < 11; i++)
        <String, dynamic>{
          'slotId': 's\$i',
          'slotPosition': 'MID',
          'cardInstanceId': 'c\$i',
        },
    ];
  }

  /// A quarter-final due next, with the bracket drawn and nothing played of it.
  /// The shape the screenshot was taken in.
  void cupDueNext(Map<String, dynamic> save) {
    final prog = save['progression'] as Map<String, dynamic>;
    final cup = cups.first;
    prog['currentDivision'] = divisions[cup.unlocksAtDivisionIdx].id;
    prog['seasonMatchesPlayed'] = cupDueAfterMatches.first;
    prog['cups'] = <String, dynamic>{
      'availableThisSeason': false,
      'active': <String, dynamic>{
        'cupId': cup.id,
        'round': 0,
        'opponents': [for (final r in cup.rounds) 'Everton $r'],
        'opponentMeta': [
          for (final _ in cup.rounds)
            <String, dynamic>{
              'divId': prog['currentDivision'],
              'rating': 60,
              'attackRatio': 0.5,
            },
        ],
        'contexts': <dynamic>[],
        'results': <dynamic>[],
        'startedAt': 0,
        'startedSeason': 1,
      },
      'history': <dynamic>[],
    };
  }

  /// The same bracket, played through the engine: round one won, round two
  /// lost. `commitCupRound` is what nulls `active` and files the run, so the
  /// save this leaves behind is the engine's own shape rather than a hand-built
  /// guess at it.
  void cupRunOver(Map<String, dynamic> save) {
    cupDueNext(save);
    final prog = save['progression'] as Map<String, dynamic>;
    final first = prepareCupRound(save)!;
    commitCupRound(save, true, first, homeGoals: 3, awayGoals: 1);
    prog['seasonMatchesPlayed'] = cupDueAfterMatches[1];
    final second = prepareCupRound(save)!;
    commitCupRound(save, false, second, homeGoals: 0, awayGoals: 2);
  }

  testWidgets('GOING OUT DOES NOT DELETE THE TIES ALREADY PLAYED', (
    tester,
  ) async {
    // **Reported from the couch: "the fixtures are now all gone from my list,
    // even the one I apparently won."** `commitCupRound` nulls
    // `progression.cups.active` the moment a run ends and moves the whole run
    // — bracket and results — into `cups.history`; this provider read `active`
    // alone, so an elimination erased every tie from the fixture list,
    // including the rounds that were WON. Going out of a cup is not the cup
    // never having happened.
    final container = await pumpFixtures(tester, mutate: cupRunOver);
    final save = container.read(gameProvider).state!;
    expect(
      activeCup(save),
      isNull,
      reason: 'the run did not actually end, so nothing is being tested',
    );

    final ties = container.read(ourCupTiesProvider);
    expect(
      ties,
      hasLength(2),
      reason: 'the played ties went with the bracket',
    );
    expect(ties.every((t) => t.played), isTrue);
    expect(ties.first.won, isTrue);
    expect(ties.last.won, isFalse);
    // And nothing in a finished run is still to come.
    expect(ties.any((t) => t.isNext), isFalse);
    // The rounds AFTER the exit are fixtures that will never happen; listing
    // them would say the run is still alive.
    expect(ties.length, lessThan(cups.first.rounds.length));

    // On the sheet, not just in the provider: the won tie's score is there to
    // be read.
    expect(find.textContaining('Everton'), findsWidgets);
    expect(
      find.byKey(ValueKey('fixture-cup-score-${cupDueAfterMatches.first - 1}')),
      findsOneWidget,
      reason: 'the tie that was won has no score on the sheet',
    );
  });

  testWidgets('A LEVEL CUP SCORE SAYS WHAT SETTLED IT', (tester) async {
    // **A knockout cannot end level, so the bracket recording one means
    // penalties.** The shootout's winning goal used to be folded into the
    // stored score — a tie watched to a 1-1 went in as a 2-1 — and unfolding it
    // left a level score on this sheet sitting beside a W with nothing to
    // explain the pair. Reported as the cup scores being wrong, from both
    // sides of the same fold.
    final container = await pumpFixtures(tester, mutate: (save) {
      cupDueNext(save);
      final tie = prepareCupRound(save)!;
      // As `settleCupRound` records one: the ninety minutes, and `won`
      // travelling beside them rather than inside them.
      commitCupRound(save, true, tie, homeGoals: 1, awayGoals: 1);
    });

    final row = cupDueAfterMatches.first - 1;
    expect(container.read(ourCupTiesProvider).first.won, isTrue);
    expect(find.byKey(ValueKey('fixture-cup-score-$row')), findsOneWidget);
    expect(
      find.byKey(ValueKey('fixture-cup-pens-$row')),
      findsOneWidget,
      reason: 'a 1-1 beside a W with nothing to explain it',
    );
    expect(find.text(t('fixtures.on_pens')), findsOneWidget);
  });

  testWidgets('AND A REAL SHOOTOUT WALKS THE WHOLE WAY TO THE SHEET', (
    tester,
  ) async {
    // **The journey, not the pieces.** The test above hand-commits a 1-1, which
    // proves the ROW and assumes the engine can produce one; `cup_launcher`'s
    // own tests prove the settle and never draw anything. This is the report
    // end to end: a tie the engine really did send to penalties, settled the
    // way the screen settles it, landing on the sheet the player then opens.
    //
    // Seeded until one comes up rather than hand-built, so the score, `won` and
    // the shootout all come from the same roll — which is the thing that was
    // disagreeing.
    late Map<String, dynamic> shootout;
    var found = false;
    final container = await pumpFixtures(tester, mutate: (save) {
      fieldASide(save);
      cupDueNext(save);
      for (var seed = 0; seed < 400 && !found; seed++) {
        setSeed(seed);
        // A pip per attempt: `beginCupRound` spends one, and a save that runs
        // dry stops handing back ties rather than saying so.
        (save['energy'] as Map<String, dynamic>)['current'] = 10;
        (save['progression'] as Map<String, dynamic>)['lastMatchAt'] = 0;
        final tie = beginCupRound(save);
        if (tie == null) continue;
        final pens = tie.result['penaltyShootout'];
        if (pens is! Map<String, dynamic>) {
          // Not a shootout: put the round back and roll again.
          cupDueNext(save);
          continue;
        }
        shootout = pens;
        settleCupRound(save, tie);
        found = true;
      }
    });
    expect(found, isTrue, reason: 'no seed in 400 produced a shootout');

    final tie = container.read(ourCupTiesProvider).first;
    // The ninety minutes, level — the shootout's winning goal is not in here.
    expect(
      tie.ourGoals,
      tie.theirGoals,
      reason: 'the winning penalty was folded back into the scoreline',
    );
    // And whoever won the penalties won the tie.
    expect(tie.won, shootout['playerWins']);
    expect(
      shootout['homeScore'],
      isNot(shootout['awayScore']),
      reason: 'a shootout that settled nothing',
    );
    expect(
      (shootout['homeScore'] as int) > (shootout['awayScore'] as int),
      tie.won,
      reason: 'the tie went to the side with fewer penalties',
    );

    // On the sheet: the level score, the marker that explains it, and the dot.
    final row = cupDueAfterMatches.first - 1;
    expect(find.byKey(ValueKey('fixture-cup-score-$row')), findsOneWidget);
    expect(find.byKey(ValueKey('fixture-cup-pens-$row')), findsOneWidget);
    final dot = tester.widget<Widget>(
      find.byKey(ValueKey('fixture-cup-result-$row')),
    );
    expect(
      (dot as dynamic).result,
      tie.won ? 'W' : 'L',
      reason: 'the dot disagrees with the shootout',
    );
  });

  testWidgets('and a tie settled inside the ninety says nothing extra', (
    tester,
  ) async {
    final container = await pumpFixtures(tester, mutate: (save) {
      cupDueNext(save);
      commitCupRound(save, true, prepareCupRound(save)!,
          homeGoals: 3, awayGoals: 1);
    });

    final row = cupDueAfterMatches.first - 1;
    expect(container.read(ourCupTiesProvider).first.won, isTrue);
    expect(find.byKey(ValueKey('fixture-cup-pens-$row')), findsNothing);
  });

  testWidgets('and a LIVE run still comes off the live bracket', (
    tester,
  ) async {
    // The stale-history guard: a save that has been through a migration can
    // carry a history row for a season whose run is still open, and the open
    // one is the truth about it.
    final container = await pumpFixtures(tester, mutate: (save) {
      cupRunOver(save);
      cupDueNext(save);
    });
    final ties = container.read(ourCupTiesProvider);
    expect(ties, hasLength(cups.first.rounds.length));
    expect(ties.first.played, isFalse);
    expect(ties.first.isNext, isTrue);
  });

  testWidgets('A DUE TIE NAMES THE CLUB, and it is the one marked next', (
    tester,
  ) async {
    // Reported with a screenshot: a Continental Cup quarter-final due, the tie
    // on the sheet reading only "Quarter-Final / Continental Cup", and NEXT
    // MATCH sitting over the LEAGUE game underneath it. "My next match is a cup
    // game vs Everton but if you look at fixtures, you can see Everton nowhere
    // and you can see it thinks my next match is Rangers."
    await pumpFixtures(tester, mutate: cupDueNext);

    // The club is on the tie.
    expect(
      find.textContaining('Everton'),
      findsWidgets,
      reason: 'the bracket knew who it was the whole time',
    );

    // And NEXT MATCH is said once, immediately above the tie rather than above
    // a league fixture that is not next.
    final headings = find.text(t('play.nextMatch').toUpperCase());
    expect(headings, findsOneWidget);

    final list = tester.widget<ListView>(
      find.byKey(const ValueKey('league-fixtures')),
    );
    final children = (list.childrenDelegate as SliverChildListDelegate).children;
    final headingAt = children.indexWhere(
      (w) => tester.any(find.descendant(
        of: find.byWidget(w),
        matching: find.text(t('play.nextMatch').toUpperCase()),
      )),
    );
    expect(headingAt, greaterThan(-1));
    // The row DIRECTLY under the heading is the tie — its round and its club,
    // not a league fixture.
    final under = find.byWidget(children[headingAt + 1]);
    expect(
      find.descendant(of: under, matching: find.text(cups.first.rounds.first)),
      findsOneWidget,
      reason: 'NEXT MATCH heads the tie, not the league game after it',
    );
    expect(
      find.descendant(
        of: under,
        matching: find.textContaining('Everton'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('A CUP TIE CARRIES A RATING AND A RESULT, like every other row', (
    tester,
  ) async {
    // **Reported from the couch: "in fixtures, you don\'t show the result for a
    // cup game — we need the W D L badge next to it just like any other game.
    // Should also show the opponent rating."** Both were missing on the one
    // kind of row a cup run is remembered by: the outcome was carried by the
    // score\'s colour alone, exactly the fault the league rows had before the
    // form dot went in, and there was no rating column at all.
    final container = await pumpFixtures(tester, mutate: cupRunOver);
    final ties = container.read(ourCupTiesProvider);
    expect(ties, hasLength(2));

    // Round one was won, round two lost — one dot each, and they say so.
    for (final tie in ties) {
      final dot = find.byKey(ValueKey('fixture-cup-result-${tie.afterMatch}'));
      expect(
        dot,
        findsOneWidget,
        reason: 'the ${tie.roundName} has no result badge',
      );
      expect(
        find.descendant(of: dot, matching: find.text(tie.won ? 'W' : 'L')),
        findsOneWidget,
      );
    }

    // A played tie reports what it was ACTUALLY played at, off its own result
    // rather than off the bracket, and does not call that an estimate.
    for (final tie in ties) {
      expect(tie.rating, isNotNull);
      expect(tie.ratingEstimated, isFalse);
      final rating = find.byKey(
        ValueKey('fixture-cup-rating-${tie.afterMatch}'),
      );
      expect(rating, findsOneWidget);
      expect(tester.widget<Text>(rating).data, '${tie.rating}');
    }
  });

  testWidgets('AND AN UNPLAYED ONE STILL DOES, off the drawn bracket', (
    tester,
  ) async {
    // The rating is the reason to open the sheet on a cup week — the bracket is
    // drawn out of the divisions ABOVE, so "how hard is this one" is a question
    // the league column never has to answer. `opponentMeta` has held the drawn
    // club\'s real rating since `startCup` built it.
    final container = await pumpFixtures(tester, mutate: cupDueNext);
    final ties = container.read(ourCupTiesProvider);
    expect(ties, hasLength(cups.first.rounds.length));
    expect(ties.every((t) => !t.played), isTrue);
    expect(ties.every((t) => t.rating == 60), isTrue);
    expect(ties.every((t) => !t.ratingEstimated), isTrue);
    expect(
      find.byKey(ValueKey('fixture-cup-rating-${ties.first.afterMatch}')),
      findsOneWidget,
    );
    // Nothing has been played, so nothing wears a badge.
    expect(
      find.byKey(ValueKey('fixture-cup-result-${ties.first.afterMatch}')),
      findsNothing,
    );
  });

  testWidgets('and a bracket with no meta says its number is a guess', (
    tester,
  ) async {
    // A run drawn before `opponentMeta` existed has nothing to read, and the
    // tie jitters ±4 around `squadRating + bump` at kickoff — which a sheet may
    // not draw for. It shows the midpoint the jitter is centred on and wears
    // the tilde the league rows use for the same admission.
    final container = await pumpFixtures(tester, mutate: (save) {
      cupDueNext(save);
      (activeCup(save)!)['opponentMeta'] = <dynamic>[];
    });
    final ties = container.read(ourCupTiesProvider);
    expect(ties, isNotEmpty);
    expect(ties.every((t) => t.ratingEstimated), isTrue);
    // The bumps rise round on round, so the estimates never fall. Not strictly:
    // a fresh save's squad is weak enough that the low clamp catches the early
    // rounds, and 20 is the floor a cup opponent is allowed.
    expect(ties.first.rating! <= ties.last.rating!, isTrue);
    expect(ties.every((t) => t.rating! >= 20), isTrue);
    final shown = tester.widget<Text>(
      find.byKey(ValueKey('fixture-cup-rating-${ties.first.afterMatch}')),
    );
    expect(
      shown.data,
      '~${ties.first.rating}',
      reason: 'an estimate must wear the tilde the league rows use',
    );
  });

  testWidgets('and it is in the player\'s language', (tester) async {
    setLocale('de');
    await pumpFixtures(tester);
    final rows = ratings(tester);
    expect(rows, isNotEmpty);
    expect(
      rows.every((r) => !r.tip.contains('Estimated opponent rating')),
      isTrue,
    );
    expect(rows.first.tip, isNotEmpty);
  });
}
