/// The live match takeover.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/game_state.dart' show saveDebounceMs;
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/match/match_clock.dart';
import 'package:merge_empire_fc/ui/screens/match/match_statboard.dart';
import 'package:merge_empire_fc/ui/screens/match/match_screen.dart';
import 'package:merge_empire_fc/ui/screens/match/subs_panel.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_providers.dart';
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

/// A save with a full squad and a bench, so the subs panel has both lists.
Map<String, dynamic> squadSave() {
  final state = createDefaultState();
  final cells = (state['grid'] as Map<String, dynamic>)['cells'] as List;
  final byPos = {
    for (final pos in ['GK', 'DEF', 'MID', 'FWD'])
      pos: players.firstWhere((p) => p.position == pos && p.tier == 1).id,
  };
  final order = [
    'GK',
    ...List.filled(5, 'DEF'),
    ...List.filled(5, 'MID'),
    ...List.filled(5, 'FWD'),
  ];
  for (var i = 0; i < 16; i++) {
    cells[i] = {
      'definitionId': byPos[order[i % order.length]]!,
      'instanceId': 'c$i',
      'variant': 0,
    };
  }
  return state;
}

Future<ProviderContainer> pumpMatch(
  WidgetTester tester,
  Map<String, dynamic> result, {
  void Function(Map<String, dynamic>)? onFinished,
  Map<String, dynamic>? save,
  // Distinct per pump, so pumping a second match into the same tester builds a
  // fresh State rather than reusing one whose clock has already run out.
  String instance = 'a',
}) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({
          saveKeyPrimary: jsonEncode(save ?? createDefaultState()),
        }),
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

/// A substitution writes the lineup, which arms the debounced save.
Future<void> settleSave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: saveDebounceMs + 100));

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

  testWidgets('the score is counted from what has been SHOWN, not the result', (
    tester,
  ) async {
    // The whole ninety minutes is decided before this screen opens, so the
    // tally has to be built from the events the player has actually seen — take
    // it off the result and the board opens at full time.
    //
    // WHEN a shown goal reaches the board is a separate contract, and the
    // cutaway owns it: see 'THE SCORE WAITS FOR THE CUTAWAY TO PLAY IT'.
    await pumpMatch(
      tester,
      matchResult(
        events: [
          {'minute': 80, 'type': 'goal', 'team': 'away', 'scorer': 'Them'},
        ],
      ),
    );
    await tester.pump(minuteDurationFor(40));
    expect(scoreOn(tester), '0 – 0');
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

    testWidgets('THE SCORE WAITS FOR THE CUTAWAY TO PLAY IT', (tester) async {
      // It did not, and it spoiled the only suspense the match has: the minute
      // ticked, the goal landed on the board and in the feed, and THEN the 2D
      // pitch played out the move whose ending you had already been told. The
      // number explained the animation instead of the animation explaining the
      // number.
      //
      // The clock still shows the minute — a chance IS happening at 22 — but
      // what has been TOLD is a separate question from where the match is.
      await pumpMatch(
        tester,
        matchResult(
          events: [
            {'minute': 22, 'type': 'goal', 'team': 'home', 'scorer': 'Smith'},
          ],
        ),
      );
      final state = stateOf(tester);
      expect(state.frame.ourGoals, 0, reason: 'a goal before kickoff');

      // Run the clock to the goal's own minute. The clip is up now and the
      // clock has stopped under it.
      await tester.pump(minuteDurationFor(22));
      await tester.pump();
      expect(state.clipPlaying, isTrue, reason: 'the goal was never shown');
      expect(state.frame.minute, 22, reason: 'the clock lost the minute');
      expect(
        state.frame.ourGoals,
        0,
        reason: 'the scoreboard gave the goal away while it was still playing',
      );

      // And it is only ever HELD, never lost: with no clip on the pitch the
      // goal is counted. `skipToEnd` is the real path that clears one — a clip
      // cannot be driven to its own end in a widget test, because the stage is
      // a Flame loop and a Flame loop never settles.
      state.skipToEnd();
      await tester.pumpAndSettle();
      expect(state.clipPlaying, isFalse);
      expect(state.frame.ourGoals, 1, reason: 'the goal never landed at all');
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

  group('SUBSTITUTIONS', () {
    /// A TALL surface. The panel is an eleven, a bench and two headings; on the
    /// default 800x600 most of it is never built, and a finder cannot reach
    /// what the list has not made yet.
    void tallView(WidgetTester tester) {
      tester.view.physicalSize = const Size(420 * 3, 2000 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    /// Open the panel the way a manager does.
    Future<void> openSubs(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('match-subs')));
      await tester.pumpAndSettle();
    }

    /// Say yes to the "X off, Y on" card, and let the bench close behind it.
    Future<void> confirmSub(WidgetTester tester) async {
      await tester.tap(
        find.byKey(const ValueKey('coach-action-common.confirm')),
      );
      await tester.pumpAndSettle();
    }

    /// Take somebody off and bring the first bench player on.
    /// [spent] is who has already been withdrawn: they are on the bench now,
    /// and the panel will not let them back on — so a test that keeps picking
    /// the first bench row would silently stop making changes.
    Future<({String off, String on})> makeSub(
      WidgetTester tester,
      ProviderContainer container, {
      Set<String> spent = const {},
    }) async {
      final slot = container
          .read(pitchSlotsProvider)
          .firstWhere(
            (s) =>
                s.cardInstanceId != null && !spent.contains(s.cardInstanceId),
          );
      final bench = container
          .read(benchProvider)
          .firstWhere((b) => !spent.contains(b.instanceId));
      // Tap him on the PITCH — the panel is the same pitch as the Squad tab now
      // — which opens the bench from the bottom. Then the bench card, then the
      // confirmation: a substitution asks before it happens.
      await tester.tap(find.byKey(ValueKey('sub-slot-${slot.slotId}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('sub-bench-${bench.instanceId}')));
      await tester.pumpAndSettle();
      await confirmSub(tester);
      return (off: slot.cardInstanceId!, on: bench.instanceId);
    }


    testWidgets('THE PANEL IS THE SAME PITCH, and the bench comes up on a tap', (
      tester,
    ) async {
      // It was two scrolling lists, which asks the manager to rebuild the shape
      // in their head from position labels — while the shape IS the information,
      // and they already know it from the Squad tab.
      tallView(tester);
      final container = await pumpMatch(
        tester,
        matchResult(),
        save: squadSave(),
      );
      await openSubs(tester);
      expect(find.byKey(const ValueKey('subs-panel')), findsOneWidget);
      expect(find.byKey(const ValueKey('pitch-board')), findsOneWidget);
      final slots = container.read(pitchSlotsProvider);
      expect(slots.length, 11);
      for (final slot in slots) {
        expect(
          find.byKey(ValueKey('sub-slot-${slot.slotId}')),
          findsOneWidget,
          reason: '${slot.slotId} is not on the pitch',
        );
      }
      expect(container.read(benchProvider), isNotEmpty);

      // The bench is behind a tap, from the bottom, the way the Squad tab does
      // it — not a second list sharing the screen.
      expect(find.byKey(const ValueKey('subs-bench-sheet')), findsNothing);
      await tester.tap(
        find.byKey(ValueKey('sub-slot-${slots.first.slotId}')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('subs-bench-sheet')), findsOneWidget);
      // Tap the barrier to send it away — a modal sheet has no back button.
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('subs-done')));
      await tester.pumpAndSettle();
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
      await settleSave(tester);
    });

    test('THE BENCH IS THREE ACROSS on a phone, and wider on a tablet', () {
      // A max-extent delegate fitted as many 92px cards as the width allowed,
      // which is four on most phones — four across a sheet an inch or two wide
      // leaves each card too small to read the face on. Three is the floor, not
      // the answer: a tablet earns the columns its width actually pays for.
      expect(benchColumns(360), 3, reason: 'a small phone');
      expect(benchColumns(430), 3, reason: 'a large phone');
      expect(benchColumns(834), greaterThan(3), reason: 'a tablet');
      // And it never narrows below three, however small the sheet gets.
      expect(benchColumns(120), 3);
    });

    testWidgets('THE CLOCK WAITS while it is open', (tester) async {
      // Choosing is not watching.
      tallView(tester);
      await pumpMatch(tester, matchResult(), save: squadSave());
      await tester.pump(minuteDurationFor(5));
      final state = stateOf(tester);
      await openSubs(tester);
      expect(state.paused, isTrue);
      final at = state.frame.minute;
      await tester.pump(minuteDurationFor(20));
      expect(state.frame.minute, at, reason: 'the match ran on without us');

      await tester.tap(find.byKey(const ValueKey('subs-done')));
      await tester.pumpAndSettle();
      expect(state.paused, isFalse);
      state.skipToEnd();
      await tester.pumpAndSettle();
      await settleSave(tester);
    });

    testWidgets('A CHANGE SWAPS THE ELEVEN and the quests can see it', (
      tester,
    ) async {
      // `subsUsed` and `subbedOnIds` are what `match_use_subs` and
      // `match_sub_scores` read, and neither could move off its kickoff value.
      tallView(tester);
      final result = matchResult();
      final container = await pumpMatch(tester, result, save: squadSave());
      await tester.pump(minuteDurationFor(5));
      await openSubs(tester);
      final swap = await makeSub(tester, container);

      final onNow = container
          .read(pitchSlotsProvider)
          .map((s) => s.cardInstanceId)
          .toList();
      expect(onNow, contains(swap.on));
      expect(onNow, isNot(contains(swap.off)));

      await tester.tap(find.byKey(const ValueKey('subs-done')));
      await tester.pumpAndSettle();
      expect(result['subsUsed'], 1);
      expect(result['subbedOnIds'], [swap.on]);
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
      await settleSave(tester);
    });

    testWidgets('and it SAYS SO in the feed', (tester) async {
      tallView(tester);
      final container = await pumpMatch(
        tester,
        matchResult(),
        save: squadSave(),
      );
      await tester.pump(minuteDurationFor(5));
      await openSubs(tester);
      await makeSub(tester, container);
      await tester.tap(find.byKey(const ValueKey('subs-done')));
      await tester.pumpAndSettle();
      // One of the two lines, depending on whether anyone came off — here
      // somebody did.
      expect(find.textContaining(RegExp(r'off,.*on\.')), findsOneWidget);
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
      await settleSave(tester);
    });

    testWidgets('THE KICKOFF ELEVEN GOES BACK at full time', (tester) async {
      // A substitution is a change for THIS match. Letting it stand would make
      // a 70th-minute gamble next week's team without anyone asking.
      tallView(tester);
      final container = await pumpMatch(
        tester,
        matchResult(addedTime: 0),
        save: squadSave(),
      );
      await tester.pump(minuteDurationFor(5));
      final before = container
          .read(pitchSlotsProvider)
          .map((s) => s.cardInstanceId)
          .toList();
      await openSubs(tester);
      final swap = await makeSub(tester, container);
      await tester.tap(find.byKey(const ValueKey('subs-done')));
      await tester.pumpAndSettle();
      expect(
        container.read(pitchSlotsProvider).map((s) => s.cardInstanceId),
        contains(swap.on),
      );

      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
      expect(
        container
            .read(pitchSlotsProvider)
            .map((s) => s.cardInstanceId)
            .toList(),
        before,
        reason: 'the substitution became next week\'s team',
      );
      await settleSave(tester);
    });

    testWidgets('THE CAP IS REAL, and it says so when it bites', (
      tester,
    ) async {
      tallView(tester);
      final container = await pumpMatch(
        tester,
        matchResult(),
        save: squadSave(),
      );
      await tester.pump(minuteDurationFor(5));
      await openSubs(tester);
      final panel = tester.state<SubsPanelState>(find.byType(SubsPanel));
      expect(panel.left, PlayerEnergy.maxSubs);
      final spent = <String>{};
      for (var i = 0; i < PlayerEnergy.maxSubs; i++) {
        spent.add((await makeSub(tester, container, spent: spent)).off);
      }
      expect(panel.left, 0);
      expect(find.text(t('match.subs.none_left')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('subs-done')));
      await tester.pumpAndSettle();
      expect(stateOf(tester).subsUsed, PlayerEnergy.maxSubs);
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
      await settleSave(tester);
    });

    testWidgets('NOBODY WHO HAS BEEN OFF GOES BACK ON', (tester) async {
      tallView(tester);
      final container = await pumpMatch(
        tester,
        matchResult(),
        save: squadSave(),
      );
      await tester.pump(minuteDurationFor(5));
      await openSubs(tester);
      final swap = await makeSub(tester, container);
      // He is on the bench now, and he must not be offerable.
      expect(
        container.read(benchProvider).map((b) => b.instanceId),
        contains(swap.off),
      );
      final slot = container
          .read(pitchSlotsProvider)
          .firstWhere((s) => s.cardInstanceId != null);
      await tester.tap(find.byKey(ValueKey('sub-slot-${slot.slotId}')));
      await tester.pumpAndSettle();
      // He is on the bench and the tap does nothing, so the sheet stays open.
      await tester.tap(find.byKey(ValueKey('sub-bench-${swap.off}')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('coach-card')),
        findsNothing,
        reason: 'a withdrawn player was offered the pitch again',
      );
      // Send the bench away, so Back to match is reachable behind it.
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(
        container.read(pitchSlotsProvider).map((s) => s.cardInstanceId),
        isNot(contains(swap.off)),
        reason: 'a withdrawn player came back on',
      );
      await tester.tap(find.byKey(const ValueKey('subs-done')));
      await tester.pumpAndSettle();
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
      await settleSave(tester);
    });

    testWidgets('AN INJURY OPENS IT BY ITSELF, with the hole picked', (
      tester,
    ) async {
      // Nobody is ever subbed on automatically — that is the manager's call —
      // so the alternative is a side quietly finishing with ten men because
      // the player was reading the feed.
      tallView(tester);
      final save = squadSave();
      final container = await pumpMatch(
        tester,
        matchResult(
          events: [
            {'minute': 10, 'type': 'injury', 'team': 'home', 'player': 'Ada'},
          ],
        ),
        save: save,
      );
      // Empty one slot, the way the sim does before the screen ever opens.
      final slot = container
          .read(pitchSlotsProvider)
          .firstWhere((s) => s.cardInstanceId != null);
      container.read(gameProvider).update((s) {
        final rows = (s['squad'] as Map<String, dynamic>)['lineup'] as List;
        for (final row in rows) {
          if (row is Map<String, dynamic> && row['slotId'] == slot.slotId) {
            row['cardInstanceId'] = null;
          }
        }
      });
      await tester.pump();

      await tester.pump(minuteDurationFor(11));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('subs-panel')),
        findsOneWidget,
        reason: 'an injury left the manager reading the feed',
      );
      expect(stateOf(tester).paused, isTrue);
      // Already picked: one tap on the bench finishes it.
      final panel = tester.state<SubsPanelState>(find.byType(SubsPanel));
      expect(panel.selectedSlot, slot.slotId);

      // The bench is ALREADY OPEN on the hole — that is what the pre-pick buys.
      expect(find.byKey(const ValueKey('subs-bench-sheet')), findsOneWidget);
      final bench = container.read(benchProvider).first;
      await tester.tap(find.byKey(ValueKey('sub-bench-${bench.instanceId}')));
      await tester.pumpAndSettle();
      // Nobody comes off — there is nobody there — so the card says only who
      // comes on.
      expect(find.text(t('match.subs.feed_on', {'on': bench.card.name})),
          findsOneWidget);
      await confirmSub(tester);
      expect(
        container.read(pitchSlotsProvider).map((s) => s.cardInstanceId),
        contains(bench.instanceId),
      );
      await tester.tap(find.byKey(const ValueKey('subs-done')));
      await tester.pumpAndSettle();
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
      await settleSave(tester);
    });

    testWidgets('but THEIR injury is not our problem', (tester) async {
      tallView(tester);
      await pumpMatch(
        tester,
        matchResult(
          events: [
            {'minute': 10, 'type': 'injury', 'team': 'away', 'player': 'Them'},
          ],
        ),
        save: squadSave(),
      );
      await tester.pump(minuteDurationFor(11));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('subs-panel')), findsNothing);
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
    });

    testWidgets('and the button is GONE at full time', (tester) async {
      tallView(tester);
      await pumpMatch(tester, matchResult(addedTime: 0), save: squadSave());
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('match-subs')), findsNothing);
    });
  });

  group('THE LIVE QUEST TRACKER', () {
    /// A save carrying the three quests this match is being played for.
    Map<String, dynamic> withQuests(List<String> ids) {
      final state = squadSave();
      state['quests'] = {
        'match': {
          'active': [
            for (final id in ids)
              {'id': id, 'target': 1, 'progress': 0, 'completed': false},
          ],
        },
        'season': <Object?>[],
      };
      return state;
    }

    Future<void> openQuests(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('tab-quests')));
      await tester.pumpAndSettle();
    }

    String markFor(WidgetTester tester, String id) =>
        tester.widget<Text>(find.byKey(ValueKey('live-quest-mark-$id'))).data!;

    testWidgets('IS REACHABLE — a tab, not a full-time surprise', (
      tester,
    ) async {
      // `partialMatchResult` and `liveMatchQuestStatus` are ported, documented
      // and tested, and had no caller: the three quests a match is being played
      // FOR were invisible until the whistle said how they went.
      await pumpMatch(
        tester,
        matchResult(),
        save: withQuests(['match_score_2', 'match_clean_sheet']),
      );
      expect(find.byKey(const ValueKey('match-tabs')), findsOneWidget);
      await openQuests(tester);
      expect(find.byKey(const ValueKey('match-live-quests')), findsOneWidget);
      expect(find.byKey(const ValueKey('live-quest-match_score_2')), findsOne);
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
    });

    testWidgets('a quest that has HAPPENED cannot un-happen', (tester) async {
      await pumpMatch(
        tester,
        matchResult(
          events: [
            {'minute': 10, 'type': 'goal', 'team': 'home', 'scorer': 'Bobby'},
          ],
        ),
        save: withQuests(['match_score_2']),
      );
      await openQuests(tester);
      expect(markFor(tester, 'match_score_2'), '·');

      await tester.pump(minuteDurationFor(11));
      await tester.pumpAndSettle();
      expect(markFor(tester, 'match_score_2'), '✓');
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
    });

    testWidgets('and one that can NO LONGER happen is gone', (tester) async {
      await pumpMatch(
        tester,
        matchResult(
          events: [
            {'minute': 10, 'type': 'goal', 'team': 'away'},
          ],
        ),
        save: withQuests(['match_clean_sheet']),
      );
      await openQuests(tester);
      expect(markFor(tester, 'match_clean_sheet'), '·');

      await tester.pump(minuteDurationFor(11));
      await tester.pumpAndSettle();
      expect(
        markFor(tester, 'match_clean_sheet'),
        '✕',
        reason: 'the clean sheet survived a goal',
      );
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
    });

    testWidgets('THE TRACKER CANNOT RUN AHEAD OF THE CLOCK', (tester) async {
      // The sim writes all ninety minutes up front, so a tracker reading the
      // result would tick a quest off for a goal nobody has watched yet.
      await pumpMatch(
        tester,
        matchResult(
          events: [
            {'minute': 80, 'type': 'goal', 'team': 'home', 'scorer': 'Late'},
          ],
        ),
        save: withQuests(['match_score_2']),
      );
      await openQuests(tester);
      await tester.pump(minuteDurationFor(20));
      await tester.pumpAndSettle();
      expect(
        markFor(tester, 'match_score_2'),
        '·',
        reason: 'a goal that has not been played yet was counted',
      );
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
    });

    testWidgets('with NO quests there is no tab strip at all', (tester) async {
      // A tab that opens an empty panel is a control for nothing.
      await pumpMatch(tester, matchResult(), save: withQuests([]));
      expect(find.byKey(const ValueKey('match-tabs')), findsNothing);
      expect(find.byKey(const ValueKey('match-feed')), findsOneWidget);
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
    });
  });

  group('THE SPEED BUTTON', () {
    testWidgets('HALVES THE WAIT, live, without skipping anything', (
      tester,
    ) async {
      // The setting decides how a match OPENS; the button is for the moment ten
      // minutes in when the manager has seen enough of this one.
      await pumpMatch(tester, matchResult());
      final state = stateOf(tester);
      expect(state.fast, isFalse);

      await tester.pump(minuteDurationFor(10));
      final atNormal = state.frame.minute;
      expect(atNormal, 10);

      await tester.tap(find.byKey(const ValueKey('match-speed')));
      await tester.pump();
      expect(state.fast, isTrue);

      // The same wall-clock again, at double speed, is twice the minutes.
      await tester.pump(minuteDurationFor(10));
      expect(state.frame.minute, atNormal + 20);
      state.skipToEnd();
      await tester.pumpAndSettle();
    });

    testWidgets('and it says which speed it is on', (tester) async {
      await pumpMatch(tester, matchResult());
      expect(find.text('1×'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('match-speed')));
      await tester.pump();
      expect(find.text('2×'), findsOneWidget);
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
    });

    testWidgets('it OPENS on the setting', (tester) async {
      // Two matches in a row should not need the same tap twice.
      await pumpMatch(tester, matchResult());
      expect(stateOf(tester).fast, isFalse);
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
    });
  });
}
