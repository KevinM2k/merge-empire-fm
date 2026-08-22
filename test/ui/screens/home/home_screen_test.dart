/// The home screen.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart' show coachAlert;
import 'package:merge_empire_fc/data/cups.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/manager_looks.dart' show styleVaultId;
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart'
    show matchesPerSeason, opponentsPerSeason;
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/home/fixture_caption.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/home/home_screen.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';
import 'package:merge_empire_fc/engine/weather_engine.dart' show windAccelFor;
import 'package:merge_empire_fc/providers/weather_providers.dart';
import 'package:merge_empire_fc/ui/screens/home/pitch_ball.dart';
import 'package:merge_empire_fc/ui/screens/home/pitch_scene.dart'
    show PitchScene, walkerScale;
import 'package:merge_empire_fc/ui/screens/match/cup_launcher.dart';
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

Future<void> settleSave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: saveDebounceMs + 100));

Future<ProviderContainer> pumpHome(
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
          // The home screen's walker loops forever, so `pumpAndSettle` would
          // never settle. He honours reduce-motion; declaring it here is what a
          // device with that setting on would do.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),

          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Table, fixtures and training are quick-nav destinations now rather than
/// sub-tabs, so a test reaches them the way a player does: through the burger.
Future<void> openFromMenu(WidgetTester tester, String labelKey) async {
  await tester.tap(find.byKey(const ValueKey('dock-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('quick-nav-$labelKey')));
  await tester.pumpAndSettle();
}

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

  group('the stray ball', () {
    // **Reachability, which is the whole point of testing it here.** The sim is
    // pinned against the JS frame by frame in `pitch_ball_test.dart` and that
    // says nothing about whether a player ever sees a ball — four engines in
    // this port have been fully ported, fully tested and never called.
    testWidgets('is on the diorama at all', (tester) async {
      final container = await pumpHome(tester);
      addTearDown(container.dispose);
      expect(
        find.byKey(const ValueKey('pitch-ball')),
        findsOneWidget,
        reason: 'no ball on the pitch',
      );
      // In HIS box, so it is scaled by the same number he is and a distance
      // means the same thing to it as to his boot.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('pitch-walker')),
          matching: find.byKey(const ValueKey('pitch-ball')),
        ),
        findsOneWidget,
        reason: 'the ball is not parented to the walker',
      );
    });

    testWidgets('and the weather actually reaches it', (tester) async {
      // `windAccelFor` was ported and tested with NO READER: the service
      // fetched a reading, the engine resolved a gust, and nothing in the game
      // was ever blown by it. A storm is the one condition that moves a ball.
      final container = await pumpHome(tester);
      addTearDown(container.dispose);
      final scene = tester.widget<PitchScene>(find.byType(PitchScene));
      expect(
        scene.ballWind,
        windAccelFor(container.read(weatherProvider).condition).toDouble(),
        reason: 'the ball is not reading the weather',
      );
    });

    testWidgets('A CARRY BEATS A GESTURE — his arms are full', (tester) async {
      final container = await pumpHome(tester);
      addTearDown(container.dispose);
      PitchBall ball() => tester.widget<PitchBall>(find.byType(PitchBall));
      ManagerWalker man() =>
          tester.widget<ManagerWalker>(find.byType(ManagerWalker));

      expect(man().carrying, isFalse);
      ball().onCue(BallCue.hold);
      await tester.pump();
      expect(man().carrying, isTrue, reason: 'he never took hold of it');

      // And nothing can start a gesture while he has it: arms cannot do two
      // things at once and the ball is the one that is visibly in them.
      await tester.tap(
        find.byKey(const ValueKey('pitch-walker')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(
        man().gesture,
        isNull,
        reason: 'a gesture played over a ball in his hands',
      );

      ball().onCue(BallCue.release);
      await tester.pump();
      expect(man().carrying, isFalse, reason: 'he never let go');
      await tester.tap(
        find.byKey(const ValueKey('pitch-walker')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(
        man().gesture,
        isNotNull,
        reason: 'he stayed blocked after putting the ball down',
      );
    });

    testWidgets('and an ignored ball is SNUBBED, not just missed', (
      tester,
    ) async {
      // Without a tell it reads as the ball getting lost rather than left. He
      // folds his arms as it goes past — head in hands when he has had enough.
      final container = await pumpHome(tester);
      addTearDown(container.dispose);
      tester.widget<PitchBall>(find.byType(PitchBall)).onCue(BallCue.ignore);
      await tester.pump();
      final man = tester.widget<ManagerWalker>(find.byType(ManagerWalker));
      expect(man.gesture?.gesture.id, 'armsfolded');
    });
  });

  group('he plants his feet, and then he walks on', () {
    testWidgets('THE HALT ENDS ON ITS OWN', (tester) async {
      // It did not. The scene read `_cue.gesture.stops` and the cue is never
      // cleared, so the world stopped for the bow and STAYED stopped until the
      // next gesture happened along — up to sixteen seconds of a man walking on
      // a pitch that was not moving. The JS clears the gesture on a timer for
      // its own length, so this does too.
      final container = await pumpHome(
        tester,
        mutate: (s) {
          // Pleased, so `bow` is in the pool at all — it is the one gesture that
          // stops him, and only a manager having a good season takes one.
          final p = s['progression'] as Map<String, dynamic>;
          p['seasonWins'] = 10;
          p['seasonDraws'] = 0;
          p['seasonLosses'] = 0;
          // And owned, because it comes from a look pack.
          (s['shop'] as Map<String, dynamic>)['purchasedIds'] = [styleVaultId];
        },
      );
      addTearDown(container.dispose);
      await tester.pump();

      PitchScene scene() => tester.widget<PitchScene>(find.byType(PitchScene));
      expect(scene().frozen, isFalse, reason: 'he started off planted');

      // A tap plays one immediately. `bow` is a weight-2 entry in a pool of
      // twenty-odd, so this finds one quickly and gives up rather than hanging.
      final walker = find.byKey(const ValueKey('pitch-walker'));
      var taps = 0;
      while (!scene().frozen && taps < 400) {
        await tester.tap(walker, warnIfMissed: false);
        await tester.pump();
        taps++;
      }
      expect(
        scene().frozen,
        isTrue,
        reason: 'no stopping gesture came up in $taps taps',
      );

      // `bow` is 2,200ms. Still planted just before it ends, walking after.
      await tester.pump(const Duration(milliseconds: 2100));
      expect(scene().frozen, isTrue, reason: 'he straightened up early');
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        scene().frozen,
        isFalse,
        reason: 'the world never started again — see the note on _halted',
      );
    });
  });

  group('the layout', () {
    testWidgets('has no sub-tabs — the burger holds them', (tester) async {
      // The strip across the top was the arrangement the JS moved away from.
      await pumpHome(tester);
      expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);
      for (final name in ['overview', 'table', 'fixtures', 'training']) {
        expect(
          find.byKey(ValueKey('league-subtab-$name')),
          findsNothing,
          reason: name,
        );
      }
    });

    testWidgets('CUSTOMISE stands between the two orbs, level with them', (
      tester,
    ) async {
      // He is the player's avatar and the pill is his own control, so it shares
      // the dock's rail rather than hiding in the burger. Level BY
      // CONSTRUCTION: the JS had the docks and the badge anchored two different
      // ways, and the day the Deadline Day strip joined the footer they stopped
      // agreeing.
      await pumpHome(tester);
      final pill = find.byKey(const ValueKey('dock-customise'));
      expect(pill, findsOneWidget, reason: 'no way to dress him');
      final coach = tester.getRect(find.byKey(const ValueKey('dock-coach')));
      final menu = tester.getRect(find.byKey(const ValueKey('dock-menu')));
      final box = tester.getRect(pill);
      expect(box.center.dx, greaterThan(coach.right));
      expect(box.center.dx, lessThan(menu.left));
      expect(box.bottom, closeTo(coach.bottom, 8));
    });

    testWidgets('THE PRESTIGE ORB IS NOT THERE until the cup is won', (
      tester,
    ) async {
      // `canPrestige` gates it, and on every save before a Champions League
      // there is nothing to offer — so the right-hand column is the burger
      // alone and the dock row is exactly what it was.
      await pumpHome(tester);
      expect(find.byKey(const ValueKey('dock-prestige')), findsNothing);
    });

    testWidgets('and it LEADS THE COLUMN above the burger once it is', (
      tester,
    ) async {
      // The dock's own note: "the burger, bottom right, with Prestige above it
      // when it is available". Above rather than beside, so the menu does not
      // move under a thumb that has learned where it is.
      await pumpHome(
        tester,
        mutate: (s) =>
            (s['progression'] as Map<String, dynamic>)['wonChampionsCup'] =
                true,
      );
      final orb = find.byKey(const ValueKey('dock-prestige'));
      expect(orb, findsOneWidget, reason: 'no way to start a new adventure');
      final star = tester.getRect(orb);
      final menu = tester.getRect(find.byKey(const ValueKey('dock-menu')));
      expect(star.bottom, lessThanOrEqualTo(menu.top));
      expect(star.center.dx, closeTo(menu.center.dx, 1));
      // And it nags, because nothing else on this screen mentions it.
      expect(find.byKey(const ValueKey('prestige-dot')), findsOneWidget);
    });

    testWidgets('tapping it opens the offer', (tester) async {
      await pumpHome(
        tester,
        mutate: (s) =>
            (s['progression'] as Map<String, dynamic>)['wonChampionsCup'] =
                true,
      );
      await tester.tap(find.byKey(const ValueKey('dock-prestige')));
      await tester.pumpAndSettle();
      expect(find.text(t('prestige.title')), findsOneWidget);
    });

    testWidgets('and he stands just over it, not up the pitch', (tester) async {
      // 12px above the pill. He used to be derived from the footer's FULL
      // height, dock row included, which stood him a whole orb too high.
      await pumpHome(tester);
      final pill = tester.getRect(find.byKey(const ValueKey('dock-customise')));
      // His BOOTS, not his box: there are 17.5 art units of empty picture under
      // his soles, and measuring the box put his feet two dozen pixels above the
      // line — which is what had him hovering over his own shadow.
      final box = tester.getRect(find.byType(ManagerWalker));
      final feet = box.bottom - walkerFootOffset * walkerScale;
      expect(feet, closeTo(pill.top - 12, 1));
    });

    testWidgets('Colin is bottom left and the burger bottom right', (
      tester,
    ) async {
      await pumpHome(tester);
      final coach = tester.getCenter(find.byKey(const ValueKey('dock-coach')));
      final menu = tester.getCenter(find.byKey(const ValueKey('dock-menu')));
      final size = tester.getSize(find.byKey(const ValueKey('home-screen')));

      expect(coach.dx, lessThan(size.width / 2));
      expect(menu.dx, greaterThan(size.width / 2));
      // Both sit in the bottom third, level with each other.
      expect(coach.dy, greaterThan(size.height * 0.66));
      expect(coach.dy, closeTo(menu.dy, 1));
    });

    testWidgets('Colin has something to say', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.byKey(const ValueKey('dock-coach')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('coach-bubble')), findsOneWidget);
    });

    testWidgets('training is reachable from the burger', (tester) async {
      await pumpHome(tester);
      await openFromMenu(tester, 'subnav.training');
      expect(find.byKey(const ValueKey('training-view')), findsOneWidget);
      expect(find.byKey(const ValueKey('training-penalty')), findsOneWidget);
    });
  });

  group('the table', () {
    testWidgets('lists the division and its rows', (tester) async {
      final container = await pumpHome(tester, mutate: playedSeason);
      await openFromMenu(tester, 'subnav.table');

      expect(find.byKey(const ValueKey('league-table')), findsOneWidget);
      // Scoped to the sheet: the home screen behind it names the division too.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('league-table')),
          // Upper-cased, because every sheet title is — see `SheetHeader`.
          matching: find.text(
            container.read(divisionNameProvider).toUpperCase(),
          ),
        ),
        findsOneWidget,
      );
      expect(container.read(leagueTableProvider), isNotEmpty);
    });

    testWidgets('marks the player s own club', (tester) async {
      // It is the row they came to look at; everything else is context for it.
      final container = await pumpHome(tester, mutate: playedSeason);
      final rows = container.read(leagueTableProvider);
      expect(rows.where((r) => r.isPlayer).length, 1);
    });

    testWidgets('is sorted by position', (tester) async {
      final container = await pumpHome(tester, mutate: playedSeason);
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
      final container = await pumpHome(tester, mutate: playedSeason);
      await openFromMenu(tester, 'subnav.fixtures');

      final rows = container.read(fixturesProvider);
      expect(rows.length, 3);
      expect(rows.map((r) => r.round), [1, 2, 3]);
      expect(find.byKey(const ValueKey('league-fixtures')), findsOneWidget);
    });

    testWidgets(
      'a played fixture carries its score, an unplayed one does not',
      (tester) async {
        final container = await pumpHome(tester, mutate: playedSeason);
        final rows = container.read(fixturesProvider);
        expect(rows.first.played, isTrue);
        expect(rows.first.homeGoals, 2);
        expect(rows.last.played, isFalse);
        expect(rows.last.homeGoals, isNull);
      },
    );

    testWidgets('the player s own games are marked', (tester) async {
      final container = await pumpHome(tester, mutate: playedSeason);
      final rows = container.read(fixturesProvider);
      expect(rows.where((r) => r.involvesPlayer).length, 2);
      expect(rows[1].involvesPlayer, isFalse);
    });

    testWidgets('an unstarted season says so rather than showing nothing', (
      tester,
    ) async {
      await pumpHome(tester);
      await openFromMenu(tester, 'subnav.fixtures');
      expect(
        find.byKey(const ValueKey('league-fixtures-empty')),
        findsOneWidget,
      );
    });

    group('THE PANEL IS OUR OWN SEASON', () {
      /// A season two matches in, with a result on each.
      void ourSeason(Map<String, dynamic> s) {
        final prog = s['progression'] as Map<String, dynamic>;
        prog['seasonCount'] = 1;
        prog['seasonMatchesPlayed'] = 2;
        prog['seasonOpponents'] = [
          'Ayton',
          'Beeches',
          'Cadley',
          'Dunmore',
          'Elder',
          'Fenwick',
          'Garrow',
        ];
        prog['fixtureResults'] = {
          // `homeGoals` is OURS whatever the venue was.
          's1_m0': {'homeGoals': 2, 'awayGoals': 1, 'won': true},
          's1_m1': {'homeGoals': 0, 'awayGoals': 3, 'won': false},
        };
        prog['seasonOpponentRatings'] = {'s1_o0': 31};
      }

      testWidgets('EVERY ROW IS ONE OF OURS, named by the opponent', (
        tester,
      ) async {
        // It used to render the whole division's grid as neutral "Ayton v
        // Beeches" rows — a table that exists to feed the standings' form dots
        // and is not what a manager opens Fixtures for.
        final container = await pumpHome(tester, mutate: ourSeason);
        final rows = container.read(ourFixturesProvider);
        expect(rows, hasLength(matchesPerSeason));
        expect(rows.map((r) => r.opponent), everyElement(isNotEmpty));
        // Two legs, so each opponent appears exactly twice.
        expect(rows.where((r) => r.opponent == 'Ayton'), hasLength(2));
      });

      testWidgets('and the two legs are at DIFFERENT grounds', (tester) async {
        final container = await pumpHome(tester, mutate: ourSeason);
        final rows = container.read(ourFixturesProvider);
        for (var i = 0; i < opponentsPerSeason; i++) {
          final legs = rows.where((r) => r.matchNum % opponentsPerSeason == i);
          expect(
            legs.map((r) => r.isHome).toSet(),
            hasLength(2),
            reason: 'opponent $i is at the same ground twice',
          );
        }
      });

      testWidgets('A PLAYED ONE WEARS THE FORM DOT the standings use', (
        tester,
      ) async {
        // How a fixture went was carried by the SCORE'S COLOUR and nothing else —
        // a green `2 - 1` against a red `0 - 3`, which asks the player to read a
        // hue off two digits and says nothing at all on a row they have not
        // played. The dot is the same green-amber-red the standings, the summary
        // and the HUD all read, and it needs no copy: W, D and L are the letters
        // the table already prints.
        final container = await pumpHome(tester, mutate: ourSeason);
        await openFromMenu(tester, 'subnav.fixtures');

        final ours = container.read(ourFixturesProvider);
        final played = ours.where((f) => f.played).toList();
        expect(played, isNotEmpty, reason: 'this save has played no fixtures');
        for (final f in played) {
          expect(
            find.byKey(ValueKey('fixture-result-${f.matchNum}')),
            findsOneWidget,
            reason: 'fixture ${f.matchNum} has no result dot',
          );
        }
        // And an unplayed one does NOT get one — an empty slot is what keeps the
        // scores above and below it in one column.
        for (final f in ours.where((f) => !f.played)) {
          expect(
            find.byKey(ValueKey('fixture-result-${f.matchNum}')),
            findsNothing,
          );
        }
      });

      testWidgets('THE SCORE IS ORIENTED to the ground it was played on', (
        tester,
      ) async {
        // Football's own convention puts the home side's goals on the left, and
        // a stored result keeps ours in `homeGoals` whatever the venue was.
        final container = await pumpHome(tester, mutate: ourSeason);
        await openFromMenu(tester, 'subnav.fixtures');
        final first = container.read(ourFixturesProvider).first;
        expect(first.played, isTrue);
        expect(
          find.text(first.isHome ? '2 - 1' : '1 - 2'),
          findsOneWidget,
          reason: 'the score was printed the wrong way round',
        );
      });

      testWidgets('THE VENUE LEADS EVERY ROW', (tester) async {
        final container = await pumpHome(tester, mutate: ourSeason);
        await openFromMenu(tester, 'subnav.fixtures');
        final rows = container.read(ourFixturesProvider);
        for (final row in rows.take(3)) {
          expect(
            find.byKey(ValueKey('fixture-venue-${row.matchNum}')),
            findsOneWidget,
            reason: 'match ${row.matchNum}',
          );
        }
      });

      testWidgets('and the three GROUP HEADINGS split the season', (
        tester,
      ) async {
        final container = await pumpHome(tester, mutate: ourSeason);
        await openFromMenu(tester, 'subnav.fixtures');
        expect(
          find.text(t('play.previousMatches').toUpperCase()),
          findsOneWidget,
        );
        expect(find.text(t('play.nextMatch').toUpperCase()), findsOneWidget);
        expect(find.text(t('play.comingUp').toUpperCase()), findsOneWidget);
        // Exactly one row is next, and it is the one after the played ones.
        final next = container.read(ourFixturesProvider).where((r) => r.isNext);
        expect(next, hasLength(1));
        expect(next.first.matchNum, 2);
      });

      testWidgets('an UNPLAYED opponent rating says it is an estimate', (
        tester,
      ) async {
        // A number that does not say it is a guess is a number the player will
        // hold the game to.
        final container = await pumpHome(tester, mutate: ourSeason);
        final rows = container.read(ourFixturesProvider);
        // The pyramid's own boot sweep may restate a stored rating, so what is
        // pinned is the DISTINCTION rather than the number: one we have played
        // is known, one we have not is a guess off the division's midpoint.
        expect(rows.first.ratingEstimated, isFalse);
        expect(rows.first.rating, greaterThan(0));
        expect(rows.last.ratingEstimated, isTrue);
      });
    });
  });

  group('playing a match', () {
    testWidgets('the home screen offers the Play button directly', (
      tester,
    ) async {
      // It used to sit under the fixture list, which put the one control the
      // whole screen exists for two taps deep.
      await pumpHome(tester, mutate: playedSeason);
      expect(find.byKey(const ValueKey('play-match')), findsOneWidget);
    });

    testWidgets('a squad too small is refused ON the button', (tester) async {
      // canPlayMatch folds three refusals together; the button names which — and
      // it says so on its own LABEL rather than in a caption underneath. A
      // caption reflows the footer every time the reason appears, and the footer
      // is what the walker's height is measured from.
      await pumpHome(tester, mutate: playedSeason);

      expect(
        tester.widget<InkWell>(find.byKey(const ValueKey('play-match'))).onTap,
        isNull,
      );
      expect(find.byKey(const ValueKey('play-blocked')), findsNothing);
    });

    /// Jump to full time — unless the clock beat us to it.
    ///
    /// `pumpAndSettle` on the way in advances the match clock while the route
    /// animates, so on an unlucky run there is no skip left to press and the
    /// test fails on the finder rather than on anything it is about. Which of
    /// the two got there first is not the assertion.
    /// Skip to the whistle and let the screen take itself off.
    ///
    /// **The 1.4s leave is a plain `Timer`**, so `pumpAndSettle` alone does not
    /// reach it — it advances the clock only while frames are pending, and a
    /// finished match schedules none. The pump is what fires it.
    Future<void> skipMatch(WidgetTester tester) async {
      final skip = find.byKey(const ValueKey('match-skip'));
      if (skip.evaluate().isNotEmpty) await tester.tap(skip);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();
    }

    testWidgets('a ready save can start one, and it takes over', (
      tester,
    ) async {
      final container = await pumpHome(tester, mutate: readyToPlay);

      final energyBefore = container.read(energyProvider);
      expect(
        tester.widget<InkWell>(find.byKey(const ValueKey('play-match'))).onTap,
        isNotNull,
      );

      await tester.tap(find.byKey(const ValueKey('play-match')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('match-screen')), findsOneWidget);
      expect(container.read(energyProvider), lessThan(energyBefore));
      expect(container.read(tickGatesProvider).matchOpen, isTrue);

      // Close it: the clock is a periodic timer, and a test that walks away
      // mid-match leaves it pending.
      await skipMatch(tester);
      // **No close button any more**: the whistle leaves the commentary page
      // on its own 1.4s after the sting, so settling is what dismisses it.
      await tester.pumpAndSettle();
      await settleSave(tester);
    });

    testWidgets('a due cup tie renames the button and is what gets played', (
      tester,
    ) async {
      // The cup engine was reachable by nothing: a club could be entered into a
      // cup and never play a round of it.
      final container = await pumpHome(tester, mutate: cupTieDue);
      expect(
        find.textContaining(cups.first.rounds.first),
        findsOneWidget,
        reason: 'the round is the headline, not "Play"',
      );

      await tester.tap(find.byKey(const ValueKey('play-match')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('match-screen')), findsOneWidget);

      await skipMatch(tester);

      // Full time: the tie is in the bracket and the prize is paid.
      final cupsBranch =
          (container.read(gameProvider).state!['progression']
                  as Map<String, dynamic>)['cups']
              as Map<String, dynamic>;
      final active = cupsBranch['active'] as Map<String, dynamic>?;
      final history = cupsBranch['history'] as List;
      expect(
        active != null ? (active['results'] as List) : history,
        isNotEmpty,
        reason: 'won and moved on, or knocked out and filed',
      );

      // **No close button any more**: the whistle leaves the commentary page
      // on its own 1.4s after the sting, so settling is what dismisses it.
      await tester.pumpAndSettle();
      await settleSave(tester);
    });

    testWidgets('a league fixture says Play Match, and quotes the pip', (
      tester,
    ) async {
      // `play.playMatch`, not the tab bar's `nav.play` — the button on the
      // screen and the tab that reaches it are different words in the JS. The
      // energy cost rides on it too, casual only.
      await pumpHome(tester, mutate: readyToPlay);
      expect(find.text(t('play.playMatch')), findsOneWidget);
      expect(find.byKey(const ValueKey('play-energy-cost')), findsOneWidget);
    });

    testWidgets('full time commits, and closing pays', (tester) async {
      // The coins land on dismissal, not at full time: the doubling offer lives
      // on the closing screen.
      final container = await pumpHome(tester, mutate: readyToPlay);

      final playedBefore =
          (container.read(gameProvider).state!['progression']
                  as Map<String, dynamic>)['matchesPlayed']
              as num;

      await tester.tap(find.byKey(const ValueKey('play-match')));
      await tester.pumpAndSettle();
      await skipMatch(tester);

      // Full time: the season has moved on, and the gates are still claimed.
      expect(
        (container.read(gameProvider).state!['progression']
            as Map<String, dynamic>)['matchesPlayed'],
        greaterThan(playedBefore),
      );

      final coinsAtFullTime = container.read(coinsProvider);
      // **No close button any more**: the whistle leaves the commentary page
      // on its own 1.4s after the sting, so settling is what dismisses it.
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('match-screen')), findsNothing);
      expect(
        container.read(coinsProvider),
        greaterThanOrEqualTo(coinsAtFullTime),
      );
      expect(
        container.read(tickGatesProvider).matchOpen,
        isFalse,
        reason: 'the screen handed the gates back',
      );
      await settleSave(tester);
    });
  });

  group('the round controls are ONE control', () {
    /// The disc inside a dock orb, whichever orb it is.
    BoxDecoration discOf(WidgetTester tester, String key) => tester
        .widgetList<Container>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(Container),
          ),
        )
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.shape == BoxShape.circle);

    testWidgets('THE DOCK ORBS ARE CIRCLES, like the floating coach', (
      tester,
    ) async {
      // They were rounded squares while the same coach on every other screen was
      // a ringed disc — one control, two shapes, depending which tab you were
      // on.
      final container = await pumpHome(tester);
      addTearDown(container.dispose);
      for (final orb in ['dock-coach', 'dock-menu']) {
        expect(
          discOf(tester, orb).shape,
          BoxShape.circle,
          reason: '$orb is not a circle',
        );
      }
      await settleSave(tester);
    });

    testWidgets('and the nag is the ONE red, wherever it appears', (
      tester,
    ) async {
      // The floating coach's badge and this one are the same badge; two reds a
      // shade apart is two badges.
      final container = await pumpHome(tester);
      addTearDown(container.dispose);
      final nags = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.shape == BoxShape.circle && d.color == coachAlert);
      expect(
        nags,
        isNotEmpty,
        reason: 'the home nag is not the shared alert red',
      );
      await settleSave(tester);
    });
  });

  group('the fixture caption', () {
    testWidgets('names the competition and the match', (tester) async {
      // Without it the card is two clubs and a VS: no competition, and no place
      // in the season at all.
      await pumpHome(tester, mutate: readyToPlay);
      expect(find.byKey(const ValueKey('fixture-caption')), findsOneWidget);
      final label = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('fixture-caption'))),
      ).read(fixtureLabelProvider);
      expect(find.text(label.competition.toUpperCase()), findsOneWidget);
      expect(find.text(label.round.toUpperCase()), findsOneWidget);
      expect(label.round, contains('1'), reason: 'the first match of a season');
      // NO ELLIPSIS. A division's name is a name, and "PREMIER DIVISI…" is not
      // one — the line scales down instead.
      for (final text in tester.widgetList<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('fixture-caption')),
          matching: find.byType(Text),
        ),
      )) {
        expect(text.overflow, isNot(TextOverflow.ellipsis), reason: text.data);
      }
    });

    testWidgets('and sits ABOVE the card, not in it', (tester) async {
      await pumpHome(tester, mutate: readyToPlay);
      final caption = tester.getRect(
        find.byKey(const ValueKey('fixture-caption')),
      );
      final card = tester.getRect(
        find.byKey(const ValueKey('next-match-card')),
      );
      expect(caption.bottom, lessThanOrEqualTo(card.top + 0.5));
    });
  });
}

/// A save that can actually take the field.
/// Ready to play, and a cup tie due instead of the league game.
///
/// The division matters: below the Regional League there is no cup to be entered
/// into at all.
void cupTieDue(Map<String, dynamic> s) {
  readyToPlay(s);
  final prog = s['progression'] as Map<String, dynamic>;
  prog['currentDivision'] = divisions[cups.first.unlocksAtDivisionIdx].id;
  prog['seasonMatchesPlayed'] = cupDueAfterMatches.first;
  final cup = cups.first;
  prog['cups'] = <String, dynamic>{
    'availableThisSeason': false,
    'active': <String, dynamic>{
      'cupId': cup.id,
      'round': 0,
      'opponents': [for (final r in cup.rounds) 'Rival $r'],
      'opponentMeta': [
        for (final _ in cup.rounds)
          <String, dynamic>{
            'divId': prog['currentDivision'],
            'rating': 50,
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
