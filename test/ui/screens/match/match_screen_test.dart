/// The live match takeover.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/match/match_clock.dart';
import 'package:merge_empire_fc/ui/screens/match/match_statboard.dart';
import 'package:merge_empire_fc/ui/screens/match/match_screen.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

Map<String, dynamic> matchResult({
  bool won = true,
  bool drawn = false,
  int addedTime = 2,
  bool isHome = true,
  List<Map<String, dynamic>> events = const [],
}) => {
  'clubName': 'Testville',
  'opponentName': 'Ayton',
  'isHome': isHome,
  'won': won,
  'drawn': drawn,
  'addedTime': addedTime,
  'events': events,
};

Future<ProviderContainer> pumpMatch(
  WidgetTester tester,
  Map<String, dynamic> result, {
  void Function(Map<String, dynamic>)? onFinished,
  // Distinct per pump, so pumping a second match into the same tester builds a
  // fresh State rather than reusing one whose clock has already run out.
  String instance = 'a',
}) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(createDefaultState())}),
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
          home: MatchScreen(
            key: ValueKey('match-$instance'),
            result: result,
            onFinished: onFinished,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

MatchScreenState stateOf(WidgetTester tester) =>
    tester.state<MatchScreenState>(find.byType(MatchScreen));

Duration minuteDurationFor(int n) => minuteDuration(fast: false) * n;

/// The score, read off the two figures either side of the gutter.
///
/// It is two Texts rather than one "1 – 0" string because the scorecard shares
/// the next-match card's three-track shape — home, gutter, away — so each
/// figure sits over its own club's name.
String scoreOn(WidgetTester tester) {
  String at(String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key))).data ?? '';
  return '${at('match-score-left')} – ${at('match-score-right')}';
}

void main() {
  tearDown(resetLocale);

  testWidgets('opens goalless, on the clock', (tester) async {
    await pumpMatch(
      tester,
      matchResult(
        events: [
          {'minute': 10, 'type': 'goal', 'team': 'home', 'scorer': 'Bobby'},
        ],
      ),
    );
    expect(scoreOn(tester), '0 – 0');
    expect(stateOf(tester).frame.minute, 0);
  });

  testWidgets('claims the tick gates while it is up', (tester) async {
    // Without this the loop drops a transfer bid or Coach Colin on top of the
    // match — the whole reason the gates are a record.
    final container = await pumpMatch(tester, matchResult());
    await tester.pump();
    expect(container.read(tickGatesProvider).matchOpen, isTrue);
  });

  testWidgets('and hands them back when it goes', (tester) async {
    final container = await pumpMatch(tester, matchResult());
    await tester.pump();
    expect(container.read(tickGatesProvider).matchOpen, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(container.read(tickGatesProvider).matchOpen, isFalse);
  });

  testWidgets('the score only moves when its goal is shown', (tester) async {
    await pumpMatch(
      tester,
      matchResult(
        events: [
          {'minute': 10, 'type': 'goal', 'team': 'home', 'scorer': 'Bobby'},
          {'minute': 80, 'type': 'goal', 'team': 'away', 'scorer': 'Them'},
        ],
      ),
    );
    // Nine minutes in, nothing yet.
    await tester.pump(minuteDurationFor(9));
    expect(scoreOn(tester), '0 – 0');

    await tester.pump(minuteDurationFor(2));
    expect(scoreOn(tester), '1 – 0');
  });

  testWidgets('runs to full time and says so', (tester) async {
    var finished = 0;
    await pumpMatch(
      tester,
      matchResult(addedTime: 1),
      onFinished: (_) => finished++,
    );
    await tester.pump(minuteDurationFor(95));
    await tester.pumpAndSettle();

    expect(stateOf(tester).frame.finished, isTrue);
    expect(find.text(t('match.full_time')), findsOneWidget);
    expect(finished, 1);
  });

  testWidgets('reports finishing exactly once', (tester) async {
    var finished = 0;
    await pumpMatch(
      tester,
      matchResult(addedTime: 0),
      onFinished: (_) => finished++,
    );
    await tester.pump(minuteDurationFor(120));
    await tester.pumpAndSettle();
    expect(finished, 1);
  });

  testWidgets('skipping jumps to the end without changing the result', (
    tester,
  ) async {
    // The match was decided before the first whistle, so a skip costs the
    // player the story and nothing else.
    Map<String, dynamic>? reported;
    await pumpMatch(
      tester,
      matchResult(
        addedTime: 3,
        events: [
          {'minute': 10, 'type': 'goal', 'team': 'home', 'scorer': 'Bobby'},
          {'minute': 88, 'type': 'goal', 'team': 'home', 'scorer': 'Bobby'},
        ],
      ),
      onFinished: (r) => reported = r,
    );
    await tester.tap(find.byKey(const ValueKey('match-skip')));
    await tester.pumpAndSettle();

    expect(scoreOn(tester), '2 – 0');
    expect(stateOf(tester).frame.finished, isTrue);
    expect(reported, isNotNull);
  });

  for (final (label, result) in [
    ('victory', matchResult()),
    ('draw', matchResult(won: false, drawn: true)),
    ('defeat', matchResult(won: false)),
  ]) {
    testWidgets('the verdict names a $label', (tester) async {
      await pumpMatch(tester, result, instance: label);
      await tester.tap(find.byKey(const ValueKey('match-skip')));
      await tester.pumpAndSettle();
      expect(find.text(t('match.$label')), findsOneWidget, reason: label);
    });
  }

  testWidgets('a commentary line resolves its translation key', (tester) async {
    // The engine emits KEYS, which is why the i18n layer had to land first.
    await pumpMatch(
      tester,
      matchResult(
        events: [
          {
            'minute': 5,
            'type': 'commentary',
            'team': 'home',
            'textKey': 'commentary.halftime_level',
          },
        ],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('match-skip')));
    await tester.pumpAndSettle();
    expect(find.text(t('commentary.halftime_level')), findsOneWidget);
    expect(find.text('commentary.halftime_level'), findsNothing);
  });

  group('the match quests at full time', () {
    /// The shape `settleMatch` writes onto the result once the track is judged.
    List<Map<String, dynamic>> outcomes() => [
      {
        'id': 'match_clean_sheet',
        'icon': '🧱',
        'target': 1,
        'passed': true,
        'coins': 120,
      },
      {
        'id': 'match_win_margin',
        'icon': '💪',
        'target': 2,
        'passed': false,
        'coins': 0,
      },
    ];

    testWidgets('are not shown while the match is still running', (
      tester,
    ) async {
      await pumpMatch(tester, {...matchResult(), 'questResults': outcomes()});
      expect(find.byKey(const ValueKey('match-quests')), findsNothing);
    });

    testWidgets('list what was won AND what was missed', (tester) async {
      // The misses are the point of showing all three: they are what makes the
      // next set worth reading.
      await pumpMatch(tester, {...matchResult(), 'questResults': outcomes()});
      stateOf(tester).skipToEnd();
      await tester.pump();

      expect(find.byKey(const ValueKey('match-quests')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('match-quest-match_clean_sheet')),
        findsOneWidget,
      );
      expect(find.text(t('quests.missed')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('match-quests-total')),
        findsOneWidget,
        reason: 'one of them paid',
      );
    });

    testWidgets('and a match with no track shows nothing at all', (
      tester,
    ) async {
      await pumpMatch(tester, matchResult());
      stateOf(tester).skipToEnd();
      await tester.pump();
      expect(find.byKey(const ValueKey('match-quests')), findsNothing);
    });

    testWidgets('a track where nothing came off has no total', (tester) async {
      await pumpMatch(tester, {
        ...matchResult(),
        'questResults': [
          {
            'id': 'match_clean_sheet',
            'icon': '🧱',
            'target': 1,
            'passed': false,
            'coins': 0,
          },
        ],
      });
      stateOf(tester).skipToEnd();
      await tester.pump();
      expect(find.byKey(const ValueKey('match-quests')), findsOneWidget);
      expect(find.byKey(const ValueKey('match-quests-total')), findsNothing);
    });
  });

  testWidgets('half time is named rather than shown as a type', (tester) async {
    await pumpMatch(
      tester,
      matchResult(
        events: [
          {'minute': 45, 'type': 'halftime'},
        ],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('match-skip')));
    await tester.pumpAndSettle();
    expect(find.text(t('match.half_time')), findsOneWidget);
  });

  testWidgets('a match with no events still finishes', (tester) async {
    var finished = 0;
    await pumpMatch(tester, matchResult(), onFinished: (_) => finished++);
    await tester.tap(find.byKey(const ValueKey('match-skip')));
    await tester.pumpAndSettle();
    expect(finished, 1);
    expect(find.byKey(const ValueKey('match-close')), findsOneWidget);
  });

  group('the stage', () {
    /// A match with something in it, so the board has counts to show.
    Map<String, dynamic> played() => matchResult(
      events: [
        {
          'minute': 10,
          'type': 'chance',
          'team': 'home',
          'shotResult': 'on_target',
        },
        {'minute': 22, 'type': 'goal', 'team': 'home', 'scorer': 'Smith'},
        {'minute': 40, 'type': 'corner', 'team': 'away'},
        {'minute': 61, 'type': 'chance', 'team': 'away', 'shotResult': 'off'},
      ],
    );

    testWidgets('is one band that never leaves', (tester) async {
      // The flicker WAS this: the port mounted the pitch only for a chance and
      // took it away after, so the band itself appeared and vanished and the
      // page reflowed around it twice per chance.
      await pumpMatch(tester, played());
      expect(find.byKey(const ValueKey('match-stage')), findsOneWidget);
      final atKickoff = tester.getRect(
        find.byKey(const ValueKey('match-stage')),
      );

      await tester.pump(const Duration(seconds: 5));
      expect(find.byKey(const ValueKey('match-stage')), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const ValueKey('match-stage'))),
        atKickoff,
        reason: 'the band moved or resized mid-match',
      );
    });

    testWidgets('shows the STATS at rest', (tester) async {
      // What the band is for when nothing is happening — the numbers the
      // commentary underneath is describing.
      await pumpMatch(tester, played());
      expect(find.byKey(const ValueKey('match-statboard')), findsOneWidget);
    });

    test('and the board counts off the same events as the feed', () {
      // One reality read twice. A shot in the commentary is a shot on the board,
      // because they are the same event.
      final result = played();
      final frame = frameAt(result, 90);
      final stats = liveStatsFor(
        frame: frame,
        result: result,
        isHome: true,
        strategyId: 'balanced',
      );
      final shots = stats.rows.firstWhere(
        (({int away, int home, String key, String labelKey}) r) =>
            r.key == 'shots',
      );
      // Two chances and a goal, and a goal is also a shot.
      expect(shots.home + shots.away, 3);
      // The goal was ours and on target; the away chance was off.
      final onTarget = stats.rows.firstWhere(
        (({int away, int home, String key, String labelKey}) r) =>
            r.key == 'sot',
      );
      expect(onTarget.home, 2);
      expect(onTarget.away, 0);
      final corners = stats.rows.firstWhere(
        (({int away, int home, String key, String labelKey}) r) =>
            r.key == 'corners',
      );
      expect(corners.away, 1);
      // A share of one quantity, so the two halves are the whole of it.
      expect(stats.possHome + stats.possAway, 100);
    });
  });

  group('an AWAY fixture', () {
    /// `team: 'home'` on an event means US, whichever ground we are on: the
    /// engine builds the goal list from the result's own `homeGoals`/
    /// `awayGoals`, which are ours and theirs, and picks the scorer from OUR
    /// squad whenever the team is `home`. The board, by contrast, is laid out
    /// home-side-left. Handing the tally straight to it put our score under the
    /// opponent's name on every away fixture.
    testWidgets('PUTS OUR SCORE UNDER OUR OWN NAME', (tester) async {
      await pumpMatch(
        tester,
        matchResult(
          isHome: false,
          events: [
            {'minute': 10, 'type': 'goal', 'team': 'home', 'scorer': 'Bobby'},
            {'minute': 20, 'type': 'goal', 'team': 'home', 'scorer': 'Ada'},
            {'minute': 30, 'type': 'goal', 'team': 'away'},
          ],
        ),
      );
      // Straight to full time: a goal cuts a clip and the clock waits for it,
      // so walking the clock forward stops at the first one.
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
      // Away: the opponent is the home side, so they are on the LEFT — with
      // their one goal, not our two.
      expect(scoreOn(tester), '1 – 2');
    });

    testWidgets('and the SAME fixture at home reads the other way round', (
      tester,
    ) async {
      await pumpMatch(
        tester,
        matchResult(
          events: [
            {'minute': 10, 'type': 'goal', 'team': 'home', 'scorer': 'Bobby'},
            {'minute': 20, 'type': 'goal', 'team': 'home', 'scorer': 'Ada'},
            {'minute': 30, 'type': 'goal', 'team': 'away'},
          ],
        ),
      );
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
      expect(scoreOn(tester), '2 – 1');
    });

    testWidgets('AN AWAY WIN IS A WIN, not a defeat', (tester) async {
      // The final whistle's sting was picked by flipping the tally on
      // `isHome`, so an away win played the defeat cue. What the screen calls
      // it at full time is the same number, so the label pins it.
      await pumpMatch(
        tester,
        matchResult(
          isHome: false,
          addedTime: 0,
          events: [
            {'minute': 10, 'type': 'goal', 'team': 'home', 'scorer': 'Bobby'},
          ],
        ),
      );
      final state = stateOf(tester);
      state.skipToEnd();
      await tester.pumpAndSettle();
      expect(state.frame.ourGoals, 1);
      expect(state.frame.theirGoals, 0);
    });
  });

  group('THE TACTIC STRIP', () {
    /// A result with enough on it for `reSimulateRemainder` to work with.
    ///
    /// It rewrites the scoreline in place from the ratings, so a result with
    /// none of them re-decides the match as 0-0 and proves nothing.
    Map<String, dynamic> playable() => {
      ...matchResult(
        addedTime: 0,
        events: [
          {'minute': 10, 'type': 'goal', 'team': 'home', 'scorer': 'Bobby'},
          {'minute': 70, 'type': 'goal', 'team': 'away'},
          {'minute': 80, 'type': 'goal', 'team': 'home', 'scorer': 'Ada'},
        ],
      ),
      'strategyId': 'balanced',
      'strategiesUsed': ['balanced'],
      'strategyChanged': false,
      'followedCoachSuggestion': false,
      'ourAttackRating': 60,
      'ourDefenceRating': 55,
      'effectiveSquadRating': 58,
      'effOppAttackRating': 50,
      'effOppDefenceRating': 52,
      'effectiveOppRating': 51,
      'opponentRating': 51,
      'homeGoals': 2,
      'awayGoals': 1,
    };

    testWidgets('is on screen, with every tactic on it', (tester) async {
      await pumpMatch(tester, playable());
      expect(find.byKey(const ValueKey('match-tactics')), findsOneWidget);
      for (final id in strategyStrip) {
        expect(
          find.byKey(ValueKey('match-tactic-$id')),
          findsOneWidget,
          reason: id,
        );
      }
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
    });

    testWidgets('A TAP ON IT REACHES THE ENGINE', (tester) async {
      // The strip is the only route to `reSimulateRemainder`, so a test that
      // only calls the method proves the method.
      final result = playable();
      await pumpMatch(tester, result);
      await tester.pump(minuteDurationFor(20));
      await tester.tap(find.byKey(const ValueKey('match-tactic-parkTheBus')));
      await tester.pump();
      expect(stateOf(tester).strategy, 'parkTheBus');
      expect(result['strategyChanged'], isTrue);
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
    });

    testWidgets('A CHANGE RE-DECIDES THE REST, and keeps what has happened', (
      tester,
    ) async {
      // `reSimulateRemainder` is 350 ported, tested lines with no caller in
      // `lib/`. Events whose minute has passed are kept — a goal whose cutaway
      // is still playing being the case that matters — and everything later is
      // replaced.
      final result = playable();
      await pumpMatch(tester, result);
      await tester.pump(minuteDurationFor(30));
      final state = stateOf(tester);
      final at = state.frame.minute;

      state.applyStrategy('allOutAttack');
      await tester.pump();

      final events = (result['events'] as List).cast<Map<String, dynamic>>();
      expect(
        events.where((e) => (e['minute'] as num) <= at).length,
        greaterThan(0),
        reason: 'the minutes already played were thrown away',
      );
      expect(
        events.any((e) => e['type'] == 'goal' && (e['minute'] as num) <= at),
        isTrue,
        reason: 'a goal the feed had already shown was un-scored',
      );
      state.skipToEnd();
      await tester.pumpAndSettle();
    });

    testWidgets('AND THE QUESTS CAN SEE IT — four fields nothing could set', (
      tester,
    ) async {
      // Five quests and four achievements read these. Three of the four were
      // unwinnable: nothing in the port could make `strategyChanged` true.
      final result = playable();
      await pumpMatch(tester, result);
      await tester.pump(minuteDurationFor(20));
      expect(result['strategyChanged'], isFalse);

      stateOf(tester).applyStrategy('parkTheBus');
      await tester.pump();
      expect(result['strategyChanged'], isTrue);
      expect(result['finalStrategy'], 'parkTheBus');
      expect(result['strategiesUsed'], containsAll(['balanced', 'parkTheBus']));
      expect(result['strategyId'], 'parkTheBus');
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
    });

    testWidgets('the change SAYS SO in the feed', (tester) async {
      await pumpMatch(tester, playable());
      await tester.pump(minuteDurationFor(20));
      stateOf(tester).applyStrategy('highPress');
      await tester.pump();
      expect(
        find.text(
          t('pause.tactics_change', {
            'name': t('strategy.highPress.name'),
            'hint': t('strategy.highPress.hint'),
          }),
        ),
        findsOneWidget,
      );
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
    });

    testWidgets('A SECOND CHANGE HAS TO WAIT', (tester) async {
      // The remainder is genuinely re-rolled on every switch, so a strummed
      // strip is a player re-rolling the result until they like it.
      await pumpMatch(tester, playable());
      await tester.pump(minuteDurationFor(20));
      final state = stateOf(tester);
      state.applyStrategy('highPress');
      await tester.pump();
      expect(state.tacticOnCooldown, isTrue);

      state.applyStrategy('parkTheBus');
      await tester.pump();
      expect(state.strategy, 'highPress', reason: 'the cooldown did nothing');

      await tester.pump(tacticCooldown + const Duration(milliseconds: 50));
      expect(state.tacticOnCooldown, isFalse);
      state.applyStrategy('parkTheBus');
      await tester.pump();
      expect(state.strategy, 'parkTheBus');
      state.skipToEnd();
      await tester.pumpAndSettle();
    });

    testWidgets('and picking the ONE ALREADY ON does nothing at all', (
      tester,
    ) async {
      final result = playable();
      await pumpMatch(tester, result);
      await tester.pump(minuteDurationFor(20));
      stateOf(tester).applyStrategy('balanced');
      await tester.pump();
      expect(
        result['strategyChanged'],
        isFalse,
        reason: 'a no-op counted as a tactical switch',
      );
      expect(stateOf(tester).tacticOnCooldown, isFalse);
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
    });

    testWidgets('AT FULL TIME THE STRIP IS GONE', (tester) async {
      // There is no remainder to re-decide, and a live control over a finished
      // match is a control that lies.
      final result = playable();
      await pumpMatch(tester, result);
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('match-tactics')), findsNothing);
      stateOf(tester).applyStrategy('highPress');
      await tester.pump();
      expect(result['strategyChanged'], isFalse);
    });
  });
}
