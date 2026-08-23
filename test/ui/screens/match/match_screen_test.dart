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
import 'package:merge_empire_fc/data/dugout_cam_policy.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_game.dart'
    show CutawayOutcome;
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_stage.dart';
import 'package:merge_empire_fc/ui/screens/match/dugout_cam.dart';
import 'package:merge_empire_fc/ui/screens/match/goal_replay.dart';
import 'package:merge_empire_fc/ui/screens/match/match_clock.dart';
import 'package:merge_empire_fc/ui/screens/match/match_statboard.dart';
import 'package:merge_empire_fc/ui/screens/home/next_match_card.dart'
    show PosChip;
import 'package:merge_empire_fc/ui/screens/match/match_screen.dart';
import 'package:merge_empire_fc/ui/theme/glass.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart' show MatchRow;
import 'package:merge_empire_fc/ui/screens/match/subs_panel.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_providers.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/theme/sky.dart';
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
  // **REDUCED MOTION BY DEFAULT, as the walker's own harness is.** The dugout
  // cam is gated on it — `shouldCutIn` refuses the whole shot — and the shot
  // is the one thing on this screen that runs FOREVER: the idle loops and the
  // REC dot have no end, so `pumpAndSettle` under a live one never returns.
  // Every test below settles, and none of them is about the camera; the ones
  // that are pass `reduceMotion: false` and pump by hand.
  bool reduceMotion = true,
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
          // COPIED from the ambient data, not replaced: a bare
          // `MediaQueryData` has no SIZE, and the pitch band is a fraction of
          // the screen's height — so the stage, and everything measured
          // against it, silently collapses to nothing.
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion),
              child: MatchScreen(
                key: ValueKey('match-$instance'),
                result: result,
                onFinished: onFinished,
              ),
            ),
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

  // ── The dugout cam ────────────────────────────────────────────────────────
  //
  // Every test in this group asks for motion, because the whole feature is
  // gated on it: `shouldCutIn` refuses the shot outright under reduced motion,
  // which is what lets every other test on this screen settle. See `pumpMatch`.

  /// End the clip on the pitch, the way the stage does when its clip runs out.
  ///
  /// A Flame loop never settles, so a clip cannot be driven to its own end in a
  /// widget test — but its `onDone` is the same seam the running stage calls,
  /// and it is the one the cam actually hangs off.
  Future<void> endClip(WidgetTester tester) async {
    tester.widget<CutawayStage>(find.byType(CutawayStage)).onDone!(
      CutawayOutcome.goal,
    );
    await tester.pump();
  }

  group('THE DUGOUT CAM', () {
    testWidgets('THE GRASS BELONGS TO THE CHANCE — a clip closes him', (
      tester,
    ) async {
      // The float shot hangs bottom-right OVER the pitch, which is fine while
      // nothing is happening on it and exactly wrong the moment something is: a
      // goal's cut-in was still up when the next chance began, so the move it
      // covered was one the player never saw.
      await pumpMatch(
        tester,
        matchResult(
          events: [
            {'minute': 22, 'type': 'goal', 'team': 'home', 'scorer': 'Smith'},
            // `big`, or `clipFor` refuses it: a half-chance is not worth
            // stopping the clock for.
            {'minute': 34, 'type': 'chance', 'team': 'home',
             'shotResult': 'on_target', 'big': true},
          ],
        ),
        reduceMotion: false,
      );
      final state = stateOf(tester);
      await tester.pump(minuteDurationFor(22));
      await tester.pump();
      expect(state.clipPlaying, isTrue, reason: 'the goal drew no clip');
      await endClip(tester);
      expect(state.camUp, isTrue, reason: 'the goal never put him up');

      // The next chance cuts in, and he gives way rather than sharing it.
      await tester.pump(minuteDurationFor(12));
      await tester.pump();
      expect(state.clipPlaying, isTrue);
      expect(state.camUp, isFalse);
      await endClip(tester);
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
    });

    test('and the shot he hangs over is SMALLER than it was', () {
      // Nearly half the width of the pitch is not a cut-in, it is a second
      // picture. The inline shot stays wider — it covers nothing.
      expect(camFloatFraction, lessThan(camInlineFraction));
      expect(camFloatFraction, lessThanOrEqualTo(0.34));
      expect(camFloatMaxWidth, lessThan(camInlineMaxWidth));
    });

    testWidgets('A GOAL PUTS HIM ON SCREEN — but not before the move that '
        'scored it', (tester) async {
      // His reaction to a goal must not arrive ahead of the cutaway retelling
      // it, for exactly the reason the scoreboard's does not: the number would
      // explain the animation instead of the animation explaining the number.
      await pumpMatch(
        tester,
        matchResult(
          events: [
            {'minute': 22, 'type': 'goal', 'team': 'home', 'scorer': 'Smith'},
          ],
        ),
        reduceMotion: false,
      );
      final state = stateOf(tester);
      await tester.pump(minuteDurationFor(22));
      await tester.pump();
      expect(state.clipPlaying, isTrue);
      expect(
        state.camUp,
        isFalse,
        reason: 'he reacted to a goal nobody had been shown yet',
      );

      await endClip(tester);
      expect(state.camUp, isTrue);
      expect(find.byType(DugoutCam), findsOneWidget);
      // Over the pitch, which is where a broadcast puts a cut-in.
      final cam = tester.getRect(find.byType(DugoutCam));
      final stage = tester.getRect(find.byKey(const ValueKey('match-stage')));
      expect(stage.contains(cam.center), isTrue);
    });

    testWidgets('and he is gone again on his own', (tester) async {
      await pumpMatch(
        tester,
        matchResult(
          events: [
            {'minute': 22, 'type': 'goal', 'team': 'home', 'scorer': 'Smith'},
          ],
        ),
        reduceMotion: false,
      );
      final state = stateOf(tester);
      await tester.pump(minuteDurationFor(22));
      await tester.pump();
      await endClip(tester);
      expect(state.camUp, isTrue);

      // The window's whole life, plus a frame for the callback. The clock is
      // still running underneath, which is the point: the match does not stop
      // for his face.
      await tester.pump(camIn);
      await tester.pump(camHold + const Duration(seconds: 3));
      await tester.pump(camOut);
      await tester.pump(const Duration(milliseconds: 16));
      expect(state.camUp, isFalse);
    });

    testWidgets('THE WHISTLE TAKES THE CAMERA AWAY, not to him', (
      tester,
    ) async {
      // The full-time shot was the payoff the whole feature is for, laid into
      // the head of the feed. It has MOVED: this screen leaves at the whistle
      // and the summary opens on him, with the room for it. Two of him a second
      // apart is one too many.
      await pumpMatch(
        tester,
        matchResult(
          events: [
            {'minute': 22, 'type': 'goal', 'team': 'home', 'scorer': 'Smith'},
          ],
        ),
        reduceMotion: false,
      );
      final state = stateOf(tester);
      state.skipToEnd();
      await tester.pump();
      await tester.pump();
      expect(state.camUp, isFalse);
      expect(find.byType(DugoutCam), findsNothing);
    });

    testWidgets('THREE GOAL CUT-INS AND NO MORE', (tester) async {
      // A reaction shot on every goal of a 6-3 would be nine of them, and a
      // reaction that happens nine times stops being a reaction and becomes
      // furniture. Six goals here, and he may be on camera for three.
      //
      // The GAP is pinned in `dugout_cam_policy_test.dart` rather than here,
      // and it is worth saying why it cannot be seen from this side: a minute
      // is 120ms of real time, so a window that is up for about three seconds
      // spans twenty-five game minutes on its own — twice the gap. The
      // "he is already on screen" refusal gets there first at every live pace.
      await pumpMatch(
        tester,
        matchResult(
          events: [
            for (final m in [10, 15, 30, 50, 70, 85])
              {'minute': m, 'type': 'goal', 'team': 'home', 'scorer': 'Smith'},
          ],
        ),
        reduceMotion: false,
      );
      final state = stateOf(tester);
      for (var minute = 1; minute <= 88; minute++) {
        await tester.pump(minuteDurationFor(1));
        await tester.pump();
        if (state.clipPlaying) await endClip(tester);
      }
      expect(state.camGoalCuts, lessThanOrEqualTo(camMaxGoalCuts));
      expect(
        state.camGoalCuts,
        greaterThan(0),
        reason: 'six goals and he was never once on camera',
      );
    });

    testWidgets('THE 2D SWITCH GOVERNS IT TOO — there is no third switch', (
      tester,
    ) async {
      // Somebody who turned the cutaways off wants a quicker, quieter match,
      // and a third toggle in that menu is a worse answer than reading the two
      // that already say what they want.
      final save = createDefaultState();
      (save['settings'] as Map<String, dynamic>)['cutawayOurTeam'] = false;
      await pumpMatch(
        tester,
        matchResult(
          events: [
            {'minute': 22, 'type': 'goal', 'team': 'home', 'scorer': 'Smith'},
          ],
        ),
        save: save,
        reduceMotion: false,
      );
      final state = stateOf(tester);
      await tester.pump(minuteDurationFor(24));
      await tester.pump();
      expect(state.clipPlaying, isFalse, reason: 'the switch is off');
      expect(state.camUp, isFalse);

      // Full time takes the camera away rather than giving it to him — the
      // shot lives on the summary now.
      state.skipToEnd();
      await tester.pump();
      await tester.pump();
      expect(state.camUp, isFalse);
    });

    testWidgets('A GOAL IN STOPPAGE TIME GIVES UP THE CAMERA', (tester) async {
      // The window the whistle would cut in half, against a full-time shot
      // about the same goal that is seconds away and is the better picture.
      // And it must not spend one of the three on the way past.
      await pumpMatch(
        tester,
        matchResult(
          addedTime: 0,
          events: [
            {'minute': 90, 'type': 'goal', 'team': 'home', 'scorer': 'Smith'},
          ],
        ),
        reduceMotion: false,
      );
      final state = stateOf(tester);
      await tester.pump(minuteDurationFor(90));
      await tester.pump();
      if (state.clipPlaying) await endClip(tester);
      expect(state.camGoalCuts, 0);
      expect(
        state.camUp,
        isFalse,
        reason: 'two of him at once, over the result',
      );
    });

    testWidgets('REDUCED MOTION NEVER SEES HIM AT ALL', (tester) async {
      // The gate is in the policy rather than in the widget, so the shot is
      // refused before anything mounts.
      await pumpMatch(tester, matchResult());
      final state = stateOf(tester);
      state.skipToEnd();
      await tester.pumpAndSettle();
      expect(state.camUp, isFalse);
      expect(find.byType(DugoutCam), findsNothing);
    });
  });

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
    // **In the FOOTER, not in the gutter.** The gutter is a fixed 34px — what
    // makes the ratings line up under the club names — and "Full Time" wraps
    // inside it and grows the row, which moved the whole pitch band down a line
    // at the whistle. The minute stays between the clubs; the label goes where
    // there is width for it.
    expect(find.byKey(const ValueKey('match-full-time')), findsOneWidget);
    expect(find.text(t('match.full_time').toUpperCase()), findsOneWidget);
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
    testWidgets('THE WHISTLE LEAVES, it does not offer a button — $label', (
      tester,
    ) async {
      // **The full-width verdict button has gone.** `_leaveFullTime` already
      // takes the player off this page 1.4s after the sting, so the button was
      // a control for something that was going to happen anyway — holding a row
      // of height on the one screen with none, and inviting a tap that raced
      // the timer. The verdict is named on the summary, which is where the
      // payoff is.
      await pumpMatch(tester, result, instance: label);
      await tester.tap(find.byKey(const ValueKey('match-skip')));
      await tester.pumpAndSettle();
      expect(stateOf(tester).frame.finished, isTrue, reason: label);
      expect(find.byKey(const ValueKey('match-close')), findsNothing);
      // And the controls that only make sense while it is running go with it.
      expect(find.byKey(const ValueKey('match-skip')), findsNothing);
      expect(find.byKey(const ValueKey('match-subs')), findsNothing);
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

  testWidgets('THE QUEST OUTCOMES ARE NOT ON THIS SCREEN ANY MORE', (
    tester,
  ) async {
    // They were appended under a ninety-minute commentary feed, on a page still
    // showing a tactic strip and a Skip button — the payoff for the match below
    // the fold of the thing you had just watched. They are the summary screen's
    // now; what stays here is the COUNT, on the quests tab.
    await pumpMatch(tester, {
      ...matchResult(),
      'questResults': [
        {
          'id': 'match_clean_sheet',
          'icon': '🧱',
          'target': 1,
          'passed': true,
          'coins': 120,
        },
      ],
    });
    stateOf(tester).skipToEnd();
    await tester.pump();
    expect(find.byKey(const ValueKey('match-quests')), findsNothing);
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
    expect(stateOf(tester).frame.finished, isTrue);
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

    testWidgets('SHOWS THE PITCH at rest, not a table of numbers', (
      tester,
    ) async {
      // The band never moved, but what was IN it flipped between a football
      // pitch and the statistics every few minutes, which is what read as the
      // pitch coming and going. It is one pitch for the whole match now, with
      // an arrow for which way the game is running; the numbers are a tab.
      await pumpMatch(tester, played());
      expect(find.byType(CutawayStage), findsOneWidget);
      expect(find.byKey(const ValueKey('match-momentum')), findsOneWidget);
      expect(find.byKey(const ValueKey('match-statboard')), findsNothing);
    });

    testWidgets('AND THE NUMBERS ARE BEHIND THE BOARD\'S OWN BUTTON', (
      tester,
    ) async {
      // **The tab bar has gone** — a full row of chrome on a screen with none
      // to spare, serving two panels nobody watches while a match runs. The
      // statistics MOVED rather than went: deleting them would have stranded
      // `MatchStatboard` and `match.tab.stats`, which is the fault this repo's
      // sweeps exist to find.
      await pumpMatch(tester, played());
      expect(find.byKey(const ValueKey('match-tabs')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('match-stats-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('match-statboard')), findsOneWidget);
      // **It does NOT pause the match**, which the subs panel does: subs decide
      // what happens next and this is a look at what already has.
      expect(stateOf(tester).paused, isFalse);
      Navigator.of(
        tester.element(find.byKey(const ValueKey('match-stats-sheet'))),
      ).pop();
      await tester.pumpAndSettle();
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
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

  group('A GOAL CAN BE WATCHED AGAIN', () {
    /// A match with one of ours in the 22nd minute, run to full time so the
    /// card is in the feed.
    Future<MatchScreenState> feedWithGoal(
      WidgetTester tester, {
      String team = 'home',
    }) async {
      await pumpMatch(
        tester,
        matchResult(
          events: [
            {'minute': 22, 'type': 'goal', 'team': team, 'scorer': 'Smith'},
          ],
        ),
      );
      final state = stateOf(tester);
      state.skipToEnd();
      await tester.pumpAndSettle();
      return state;
    }

    /// Open the replay without settling — a Flame loop never settles, so the
    /// popup has to be pumped up by hand.
    Future<void> openReplay(WidgetTester tester, int minute) async {
      await tester.tap(find.byKey(ValueKey('feed-replay-$minute')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('THE CHIP IS ON THE GOAL AND NOWHERE ELSE', (tester) async {
      // The one thing a player wants to see twice was the only thing on the
      // screen they could not.
      await feedWithGoal(tester);
      expect(find.byKey(const ValueKey('feed-replay-22')), findsOneWidget);
      // Half time is a line in the feed and has no passage of play; the chip
      // is offered only where `clipFor` can actually build one.
      expect(find.byKey(const ValueKey('feed-replay-45')), findsNothing);
    });

    testWidgets('AND IT PLAYS THE PASSAGE THAT WAS WATCHED', (tester) async {
      // Seeded off the minute, so a replay is not a recording — it is the same
      // passage rebuilt from the same number. Another seed would be another
      // goal.
      final state = await feedWithGoal(tester);
      await openReplay(tester, 22);
      expect(find.byKey(const ValueKey('goal-replay')), findsOneWidget);
      final stage = tester.widget<CutawayStage>(
        find.descendant(
          of: find.byKey(const ValueKey('goal-replay')),
          matching: find.byType(CutawayStage),
        ),
      );
      expect(stage.clip?.seed, state.replayClipFor(22, ours: true)?.seed);
      expect(stage.clip?.outcome, CutawayOutcome.goal);
    });

    testWidgets('and THE MATCH WAITS while it is up', (tester) async {
      // The same bargain the subs panel strikes: coming back to a match that
      // had run on without you is what a popup over a live game does if the
      // clock does not stop.
      await pumpMatch(
        tester,
        matchResult(
          events: [
            {'minute': 10, 'type': 'goal', 'team': 'home', 'scorer': 'Smith'},
          ],
        ),
      );
      final state = stateOf(tester);
      state.skipToEnd();
      await tester.pumpAndSettle();
      expect(state.paused, isFalse);

      await openReplay(tester, 10);
      expect(state.paused, isTrue, reason: 'the clock ran under the replay');

      await tester.tap(find.byKey(const ValueKey('goal-replay-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('goal-replay')), findsNothing);
      expect(state.paused, isFalse);
    });

    testWidgets('AND THE WHISTLE DOES NOT CLOSE IT', (tester) async {
      // Full time leaves the commentary page on a timer, and `maybePop` pops
      // whatever is TOPMOST — so the whistle closed the replay the player had
      // just opened on the goal that won it, and left the finished match
      // sitting behind it.
      final state = await feedWithGoal(tester);
      expect(state.frame.finished, isTrue);
      await openReplay(tester, 22);
      expect(find.byKey(const ValueKey('goal-replay')), findsOneWidget);

      // And it stays up for as long as the player wants it.
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.byKey(const ValueKey('goal-replay')),
        findsOneWidget,
        reason: 'the whistle closed the replay',
      );
      await tester.tap(find.byKey(const ValueKey('goal-replay-close')));
      await tester.pumpAndSettle();
      expect(state.paused, isFalse);
    });

    testWidgets('THEIRS CAN BE WATCHED TOO, and it is red', (tester) async {
      // A goal against is still a passage of play; what changes is which way
      // it runs and what colour the head is.
      await feedWithGoal(tester, team: 'away');
      await openReplay(tester, 22);
      final dialog = tester.widget<GoalReplayDialog>(
        find.byType(GoalReplayDialog),
      );
      expect(dialog.ours, isFalse);
      expect(dialog.title, 'Ayton');
      // Ours attack right at home, so theirs run the other way.
      expect(dialog.clip.attackingRight, isFalse);
    });
  });

  group('THE COMMENTARY KNOWS WHO IT IS ABOUT', () {
    testWidgets('A GOAL CARRIES THE SCORER\'S FACE', (tester) async {
      // A goal line naming a player, next to the art of the player it names.
      // The portraits are bundled and `playerImagePath` already resolves them,
      // so what was missing was the row knowing who it was about rather than
      // holding a string with his name in it.
      await pumpMatch(
        tester,
        matchResult(
          events: [
            {
              'minute': 10,
              'type': 'goal',
              'team': 'home',
              'scorer': 'Bobby',
              'scorerInstanceId': 'c15',
            },
          ],
        ),
        save: squadSave(),
      );
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('match-feed')),
          matching: find.byType(PlayerFace),
        ),
        findsOneWidget,
        reason: 'the goal line named a player and drew nobody',
      );
    });

    testWidgets('A GOAL IS A CARD — the score it made, and his tally', (
      tester,
    ) async {
      // Every other line in the feed is one row of text and a goal was too:
      // the single most important thing that happens in a match, drawn exactly
      // like "nerves jangling all around the ground". `match.goal_card.title`,
      // `match.career_goal` and `match.career_goals` were translated ten times
      // over with nothing able to reach one of them.
      final save = squadSave();
      final cells = (save['grid'] as Map<String, dynamic>)['cells'] as List;
      (cells[0] as Map<String, dynamic>)['stats'] = {'goals': 4};
      await pumpMatch(
        tester,
        matchResult(
          events: [
            {
              'minute': 10,
              'type': 'goal',
              'team': 'home',
              'scorer': 'Bobby',
              'scorerInstanceId': 'c0',
            },
          ],
        ),
        save: save,
      );
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();

      final feed = find.byKey(const ValueKey('match-feed'));
      expect(
        find.descendant(
          of: feed,
          matching: find.text(t('match.goal_card.title')),
        ),
        findsOneWidget,
      );
      // The score the goal MADE, home side left.
      expect(
        find.descendant(of: feed, matching: find.text('1–0')),
        findsOneWidget,
      );
      // Four in the book plus the one he just scored — the save is not written
      // until the whistle, so the stored figure is a match behind.
      expect(
        find.descendant(
          of: feed,
          matching: find.text(t('match.career_goals', {'n': 5})),
        ),
        findsOneWidget,
      );
      await settleSave(tester);
    });

    testWidgets('and a brace counts BOTH before the save hears about it', (
      tester,
    ) async {
      final save = squadSave();
      final cells = (save['grid'] as Map<String, dynamic>)['cells'] as List;
      (cells[0] as Map<String, dynamic>)['stats'] = {'goals': 0};
      await pumpMatch(
        tester,
        matchResult(
          events: [
            for (final minute in [10, 40])
              {
                'minute': minute,
                'type': 'goal',
                'team': 'home',
                'scorer': 'Bobby',
                'scorerInstanceId': 'c0',
              },
          ],
        ),
        save: save,
      );
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
      final feed = find.byKey(const ValueKey('match-feed'));
      expect(
        find.descendant(
          of: feed,
          matching: find.text(t('match.career_goal', {'n': 1})),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: feed,
          matching: find.text(t('match.career_goals', {'n': 2})),
        ),
        findsOneWidget,
      );
      await settleSave(tester);
    });

    testWidgets('and a scorer who has LEFT still gets his line', (
      tester,
    ) async {
      // A sale mid-season must not take a goal off the feed. No card, no face —
      // and the ball glyph the row had before is what stands in.
      await pumpMatch(
        tester,
        matchResult(
          events: [
            {
              'minute': 10,
              'type': 'goal',
              'team': 'home',
              'scorer': 'Bobby',
              'scorerInstanceId': 'sold-long-ago',
            },
          ],
        ),
        save: squadSave(),
      );
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
      final feed = find.byKey(const ValueKey('match-feed'));
      expect(
        find.descendant(of: feed, matching: find.byType(PlayerFace)),
        findsNothing,
      );
      expect(
        find.descendant(of: feed, matching: find.byIcon(Icons.sports_soccer)),
        findsOneWidget,
      );
    });

    testWidgets('and an OPPONENT goal draws no face', (tester) async {
      // The engine picks scorers from our squad; one of theirs is nobody the
      // save has ever heard of.
      await pumpMatch(
        tester,
        matchResult(
          events: [
            {'minute': 10, 'type': 'goal', 'team': 'away'},
          ],
        ),
        save: squadSave(),
      );
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('match-feed')),
          matching: find.byType(PlayerFace),
        ),
        findsNothing,
      );
    });
  });

  group('THE CLOCK IS BACK IN THE BOARD, at the foot of it', () {
    testWidgets('THE MINUTE IS BETWEEN THE TWO CLUBS, and the bar is the '
        'card\'s bottom edge', (tester) async {
      // **This moves the clock a second time and the reason is the same both
      // times: SPACE.** It came into the board off its own `_ClockCard`, and
      // sat at the foot beside the competition label — the quietest strip on
      // the card. The gutter above the `VS` is the widest empty space on the
      // screen, and the bar is a hairline that was costing a gap and a row of
      // its own. Both asked for directly.
      await pumpMatch(tester, matchResult());
      final board = find.byKey(const ValueKey('match-scoreboard'));
      expect(board, findsOneWidget);
      expect(find.byKey(const ValueKey('match-clock-card')), findsNothing);
      final clock = find.descendant(
        of: board,
        matching: find.byKey(const ValueKey('match-clock')),
      );
      expect(clock, findsOneWidget);
      expect(
        find.descendant(
          of: board,
          matching: find.byType(LinearProgressIndicator),
        ),
        findsOneWidget,
      );
      // Between the two clubs: level with the names, and above the score.
      expect(
        tester.getCenter(clock).dx,
        closeTo(tester.getCenter(board).dx, 2),
      );
      expect(
        tester.getTopLeft(clock).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('match-score-left'))).dy,
        ),
      );
    });
  });

  group('THE BOARD IS THE FIXTURE CARD', () {
    testWidgets('AND THE POSITION CHIPS HAVE GONE', (tester) async {
      // **This reverses "it opens with the standings, like the home page
      // does".** The chips came across from the next-match card, where they
      // answer "who am I playing"; once the match is running that question is
      // answered, and the table is a tap away on the full-time screen. Asked
      // for directly, and the row they cost is the room the clock moved into.
      await pumpMatch(tester, matchResult());
      final board = find.byKey(const ValueKey('match-scoreboard'));
      expect(board, findsOneWidget);
      expect(
        find.descendant(of: board, matching: find.byType(PosChip)),
        findsNothing,
      );
      // Names and score: two bands on the card's own three-track row, which is
      // what makes the ratings line up under the club names.
      expect(
        find.descendant(of: board, matching: find.byType(MatchRow)),
        findsNWidgets(2),
      );
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
      await tester.tap(find.byKey(ValueKey('sub-slot-${slots.first.slotId}')));
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

    testWidgets('AND HE STAYS OFF ACROSS A REOPEN', (tester) async {
      // The rule only held for as long as the panel stayed up: the withdrawn set
      // lived on the panel while the COUNT was passed in from the screen, so
      // closing and reopening forgot who had been taken off. Two taps and a man
      // who had been substituted was back on the pitch.
      tallView(tester);
      final container = await pumpMatch(
        tester,
        matchResult(),
        save: squadSave(),
      );
      await tester.pump(minuteDurationFor(5));
      await openSubs(tester);
      final swap = await makeSub(tester, container);
      await tester.tap(find.byKey(const ValueKey('subs-done')));
      await tester.pumpAndSettle();

      // Back in, a fresh panel. He is on the bench and he must still be inert.
      await openSubs(tester);
      expect(
        tester.state<SubsPanelState>(find.byType(SubsPanel)).left,
        PlayerEnergy.maxSubs - 1,
        reason: 'the panel forgot the change had been made',
      );
      final slot = container
          .read(pitchSlotsProvider)
          .firstWhere((s) => s.cardInstanceId != null);
      await tester.tap(find.byKey(ValueKey('sub-slot-${slot.slotId}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('sub-bench-${swap.off}')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('coach-card')),
        findsNothing,
        reason: 'a withdrawn player was offered the pitch again after a reopen',
      );
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
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
      // Empty one slot, the way the sim does before the screen ever opens —
      // **and FLAG THE CARD, which the sim also does.** Vacating alone was half
      // the state: `simulateMatch` sets `injured` and then removes him, and a
      // fixture that only removes him is a hole nobody fell into.
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
        for (final raw in (s['grid'] as Map<String, dynamic>)['cells'] as List) {
          if (raw is Map<String, dynamic> &&
              raw['instanceId'] == slot.cardInstanceId) {
            raw['injured'] = true;
            raw['injuredAt'] = DateTime.now().millisecondsSinceEpoch;
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

      // **AND THE CASUALTY IS STILL STANDING IN HIS OWN SLOT**, rated zero and
      // crossed through. A gap says a man is missing without saying WHICH, on
      // the one panel whose job is picking his replacement — and if the manager
      // does not tap him he is off the pitch and worth nothing regardless, so
      // drawn is the version they can act on.
      //
      // DERIVED rather than stamped on the lineup row: that map is compared
      // field for field against the JS's by twenty-two parity rows, and a field
      // the JS does not write fails every one of them. An injured card that is
      // not in the eleven belongs in one of the holes, and the holes take them
      // by position first.
      expect(
        container
            .read(pitchSlotsProvider)
            .firstWhere((sl) => sl.slotId == slot.slotId)
            .vacatedBy,
        isNotNull,
        reason: 'the hole does not know whose it is',
      );

      // The bench is ALREADY OPEN on the hole — that is what the pre-pick buys.
      expect(find.byKey(const ValueKey('subs-bench-sheet')), findsOneWidget);
      // **The casualty is on the bench list too now that he is out of the
      // eleven**, and he is not a substitute — so the first FIT man is the one
      // this taps. Taking the raw first would be picking the injured player to
      // replace himself.
      final bench = container
          .read(benchProvider)
          .firstWhere((b) => b.instanceId != slot.cardInstanceId);
      await tester.tap(find.byKey(ValueKey('sub-bench-${bench.instanceId}')));
      await tester.pumpAndSettle();
      // Nobody comes off — there is nobody there — so the card says only who
      // comes on.
      expect(
        find.text(t('match.subs.feed_on', {'on': bench.card.name})),
        findsOneWidget,
      );
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

  group('THE LIVE QUEST TRACKER HAS GONE, and so has the tab bar', () {
    testWidgets('NOTHING ON THE SCREEN IS A TAB ANY MORE', (tester) async {
      // The bar was a full row of chrome serving two panels nobody watches
      // while a match runs. The quests auto-pay at the whistle and the summary
      // reports all three — winners and misses — so a running count here bought
      // height to say something nobody can act on; the statistics moved behind
      // the board's own chart button.
      await pumpMatch(tester, matchResult());
      expect(find.byKey(const ValueKey('match-tabs')), findsNothing);
      expect(find.byKey(const ValueKey('tab-quests')), findsNothing);
      expect(find.byKey(const ValueKey('tab-stats')), findsNothing);
      expect(find.byKey(const ValueKey('match-live-quests')), findsNothing);
      // And the commentary has the whole box.
      expect(find.byKey(const ValueKey('match-feed')), findsOneWidget);
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
    });

    testWidgets('AND THE FEED SITS ON GLASS, like everything else here', (
      tester,
    ) async {
      // It was a hand-rolled `DecoratedBox` with its own colour, radius and
      // border — one pane of glass and one painted box side by side, on a page
      // whose backdrop is a sky.
      await pumpMatch(tester, matchResult());
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('match-feed')),
          matching: find.byType(GlassPanel),
        ),
        findsWidgets,
      );
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

  group('COACH COLIN HAS A VOICE for the ninety minutes', () {
    // Twenty-four pooled `coach.match.*` strings were translated into ten
    // catalogues and not one of them had a caller: the screen a player watches
    // for ninety minutes was the one screen he said nothing on.
    testWidgets('and the whistle at the break is when he uses it', (
      tester,
    ) async {
      await pumpMatch(
        tester,
        matchResult(
          events: [
            {'minute': 45, 'type': 'halftime'},
          ],
        ),
        save: squadSave(),
      );
      expect(find.byKey(const ValueKey('match-coach-line')), findsNothing);
      await tester.pump(minuteDurationFor(46));
      await tester.pump();
      expect(find.byKey(const ValueKey('match-coach-line')), findsOneWidget);
    });

    testWidgets('and PRO MODE buys the numbers and gives up the advice', (
      tester,
    ) async {
      // The same bargain the subs panel strikes — the JS's `_coachHelpOn`.
      final save = squadSave();
      (save['settings'] as Map<String, dynamic>)['hardMode'] = true;
      await pumpMatch(
        tester,
        matchResult(
          events: [
            {'minute': 45, 'type': 'halftime'},
          ],
        ),
        save: save,
      );
      await tester.pump(minuteDurationFor(46));
      await tester.pump();
      expect(find.byKey(const ValueKey('match-coach-line')), findsNothing);
    });
  });
  group('ONE INSET DOWN THE PAGE', () {
    testWidgets('every band starts and ends on the same margin', (
      tester,
    ) async {
      // It was 13, 12 and 14 down the page with gaps of 6, 7 and 8 between
      // them, and a page of panels at four insets reads as unfinished before
      // anything on it is read.
      await pumpMatch(tester, matchResult());
      final width = tester.getSize(find.byKey(const ValueKey('match-screen'))).width;
      // The PANE of each band, not the padded box around it — the scoreboard's
      // key is on the widget that owns the padding.
      final board = tester.getRect(
        find
            .descendant(
              of: find.byKey(const ValueKey('match-scoreboard')),
              matching: find.byType(GlassPanel),
            )
            .first,
      );
      // Not the STAGE: it is an `AspectRatio` centred in its band, so the
      // pitch keeps its shape and gives the width back either side. Its
      // padding is the same; its pane is deliberately narrower.
      final feed = tester.getRect(
        find
            .ancestor(
              of: find.byKey(const ValueKey('match-feed')),
              matching: find.byType(GlassPanel),
            )
            .first,
      );
      for (final (name, rect) in [('board', board), ('feed', feed)]) {
        expect(rect.left, closeTo(matchInset, 1.5), reason: '$name left');
        expect(
          width - rect.right,
          closeTo(matchInset, 1.5),
          reason: '$name right',
        );
      }
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
    });
  });

  group('WHAT A MATCH STANDS UNDER', () {
    // **Dark mode gets the app's own background, flat.** The match took the
    // diorama's sky so that kicking off was not arriving somewhere else —
    // right in principle, and in dark mode the night sky's third stop is a
    // violet that reads as purple behind a page of glass panels. Reported
    // exactly that way.
    testWidgets('dark mode is flat, and it is the theme\'s own', (tester) async {
      late Decoration dark;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(kitId: '#4caf50', light: false),
          home: Builder(
            builder: (context) {
              dark = matchBackdrop(context: context, tier: 3);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final box = dark as BoxDecoration;
      expect(box.gradient, isNull, reason: 'still a sky');
      expect(box.color, isNotNull);
    });

    testWidgets('and LIGHT mode still gets one, because white is the bug', (
      tester,
    ) async {
      // A flat backdrop there is white, which is what the sky was introduced to
      // fix: pale panels on a pale page, and the whole match goes flat.
      late Decoration light;
      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('light'),
          theme: buildAppTheme(kitId: '#4caf50', light: true),
          home: Builder(
            builder: (context) {
              light = matchBackdrop(context: context, tier: 3);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final box = light as BoxDecoration;
      expect(box.gradient, isNotNull, reason: 'a white page under a white card');
      // The NIGHT sky, whichever theme is on — that is the one that gives a
      // bright page something to sit on.
      expect(
        (box.gradient! as LinearGradient).colors,
        skyColours(brightness: Brightness.dark, tier: 3),
      );
    });
  });

}
