/// The home screen.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/cups.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/home/home_screen.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';
import 'package:merge_empire_fc/ui/screens/home/pitch_scene.dart'
    show walkerScale;
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
          matching: find.text(container.read(divisionNameProvider)),
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
    Future<void> skipMatch(WidgetTester tester) async {
      final skip = find.byKey(const ValueKey('match-skip'));
      if (skip.evaluate().isNotEmpty) await tester.tap(skip);
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
      await tester.tap(find.byKey(const ValueKey('match-close')));
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

      await tester.tap(find.byKey(const ValueKey('match-close')));
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
      await tester.tap(find.byKey(const ValueKey('match-close')));
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
