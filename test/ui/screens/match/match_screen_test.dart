/// The live match takeover.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/sound_defs.dart';
import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'package:merge_empire_fc/services/sound_service.dart';
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
import 'package:merge_empire_fc/ui/screens/match/match_clock.dart';
import 'package:merge_empire_fc/ui/screens/match/match_statboard.dart';
import 'package:merge_empire_fc/ui/screens/home/next_match_card.dart'
    show PosChip;
import 'package:merge_empire_fc/ui/screens/home/home_screen.dart' show playPageGap;
import 'package:merge_empire_fc/ui/screens/match/match_screen.dart';
import 'package:merge_empire_fc/ui/theme/glass.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart' show MatchRow;
import 'package:merge_empire_fc/ui/screens/match/subs_panel.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';
import 'package:merge_empire_fc/ui/screens/squad/pitch_token.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_providers.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/theme/sky.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/engine/squad_rating.dart' show CardStats;
import 'package:merge_empire_fc/engine/booking_engine.dart';

Map<String, dynamic> matchResult({
  bool won = true,
  bool drawn = false,
  int addedTime = 2,
  bool isHome = true,
  List<Map<String, dynamic>> events = const [],
  // **A FIXTURE THE REFEREE HAS NOTHING TO DO IN.** The screen rolls its own
  // bookings off this key, and an absent one hashes to seed 0 — which books
  // three players and sends one off, so every test that played a match was
  // suddenly answering a red-card coach card it had never asked for. Nine
  // failed on it, none of them about cards.
  //
  // `s1_m44` is a quiet afternoon for BOTH sides — the referee books the
  // opposition too, on its own stream. A test that WANTS a card passes a key
  // that produces one.
  String? fixtureKey = 's1_m44',
}) => {
  'clubName': 'Testville',
  'fixtureKey': fixtureKey,
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
  bool fast = false,
  List<Override> overrides = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({
          saveKeyPrimary: jsonEncode(save ?? createDefaultState()),
        }),
      ),
      ...overrides,
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
                fast: fast,
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

/// A backend that only remembers what it was asked to play.
class _EarBackend implements SoundBackend {
  final List<String> played = [];

  @override
  Future<void> playSfx(
    String name,
    Uint8List wav, {
    required double volume,
    required bool overlap,
    required Duration length,
  }) async => played.add(name);

  @override
  Future<void> playAsset(String asset, {required double volume}) async {}
  @override
  Future<void> setMusic(
    String? asset, {
    required double volume,
    required bool fade,
  }) async {}
  @override
  Future<void> setMusicVolume(double volume) async {}
  @override
  Future<void> pauseMusic() async {}
  @override
  Future<void> resumeMusic() async {}
  @override
  Future<void> stopAllSfx() async {}
}

/// A sound engine with every match cue loaded and an ear on the back of it.
({SoundService service, _EarBackend ear}) earOn() {
  final ear = _EarBackend();
  final service = SoundService(
    backend: ear,
    render: () => {
      for (final name in soundDefs.keys) name: Uint8List(1),
    },
  )..warmUpNow();
  return (service: service, ear: ear);
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

/// Bring a feed row into view.
///
/// **THE FEED IS LONGER THAN IT WAS, and the goal is at the bottom of it.**
/// It reads newest-first, and a match with a real squad now also carries
/// the referee's cards — so a goal in the tenth minute sits under three
/// bookings and a lazy `ListView` never builds it. Nothing is wrong with
/// the row; the test was reading a viewport rather than a list.
Future<void> reachFeed(WidgetTester tester, Finder target) async {
  if (target.evaluate().isNotEmpty) return;
  await tester.scrollUntilVisible(
    target,
    120,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('match-feed')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
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

  group('THE SOUND IS THE ENDING THE PITCH SHOWED', () {
    // `woodwork` played for every on-target chance of theirs — a save, on the
    // pitch, and the frame rattling in the speakers. Reported as the post
    // sounding when nothing was going on and saves playing a post sound.
    Map<String, dynamic> theirBigChance() => matchResult(
      events: [
        {
          'minute': 22,
          'type': 'chance',
          'team': 'away',
          'xg': 0.5,
          'shotResult': 'on_target',
          'big': true,
        },
      ],
    );

    Future<_EarBackend> verdict(
      WidgetTester tester,
      CutawayOutcome outcome,
    ) async {
      final sound = earOn();
      await pumpMatch(
        tester,
        theirBigChance(),
        reduceMotion: false,
        overrides: [soundServiceProvider.overrideWithValue(sound.service)],
      );
      final state = stateOf(tester);
      await tester.pump(minuteDurationFor(22));
      await tester.pump();
      expect(state.clipPlaying, isTrue);
      sound.ear.played.clear();
      tester.widget<CutawayStage>(find.byType(CutawayStage)).onVerdict!(
        outcome,
      );
      await tester.pump();
      return sound.ear;
    }

    testWidgets('a SAVE is the crowd, not the post', (tester) async {
      final ear = await verdict(tester, CutawayOutcome.saved);
      expect(ear.played, contains('crowdOoh'));
      expect(ear.played, isNot(contains('woodwork')));
    });

    testWidgets('and the post is the post', (tester) async {
      final ear = await verdict(tester, CutawayOutcome.post);
      expect(ear.played, contains('woodwork'));
    });

    testWidgets('and a shot that misses everything is nothing', (tester) async {
      final ear = await verdict(tester, CutawayOutcome.over);
      expect(ear.played, isNot(contains('woodwork')));
      expect(ear.played, isNot(contains('crowdOoh')));
    });
  });

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
      // **OFF THE GRASS.** He floated over the pitch, and the pitch is live for
      // the whole match — so the move after the goal was played behind him.
      // The corner of the commentary is where nothing is happening.
      final cam = tester.getRect(find.byType(DugoutCam));
      final stage = tester.getRect(find.byKey(const ValueKey('match-stage')));
      final feed = tester.getRect(find.byKey(const ValueKey('match-feed')));
      expect(stage.overlaps(cam), isFalse, reason: 'the cut-in covers the pitch');
      expect(feed.contains(cam.center), isTrue);
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
    await reachFeed(tester, find.text(t('commentary.halftime_level')));
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

  testWidgets('half time is named, and says what the score MEANS', (
    tester,
  ) async {
    // The head names the break — it used to be the only thing that did, with
    // the words "Half Time" repeated underneath as the line. `_processEvent`
    // in `MatchPopup.js` picks a verdict off the score instead, and all three
    // of its keys were translated in ten catalogues with no caller here.
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
    await reachFeed(tester, find.text(t('match.half_time').toUpperCase()));
    expect(find.text(t('match.half_time').toUpperCase()), findsOneWidget);
    await reachFeed(tester, find.text(t('commentary.halftime_level')));
    expect(find.text(t('commentary.halftime_level')), findsOneWidget);
    expect(
      find.text(t('match.half_time')),
      findsNothing,
      reason: 'the row said its own name twice',
    );
  });

  testWidgets('and it is the verdict the SCORE earns', (tester) async {
    await pumpMatch(
      tester,
      matchResult(
        events: [
          {'minute': 20, 'type': 'goal', 'team': 'home', 'scorer': 'Smith'},
          {'minute': 45, 'type': 'halftime'},
        ],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('match-skip')));
    await tester.pumpAndSettle();
    await reachFeed(
      tester,
      find.text(t('commentary.halftime_ahead', {'us': 'Testville'})),
    );
    expect(
      find.text(t('commentary.halftime_ahead', {'us': 'Testville'})),
      findsOneWidget,
    );
  });

  testWidgets('AND SOMEBODY WRITES IT UP, at the head of the commentary', (
    tester,
  ) async {
    // The feed is newest-first, so the head of the list is the end of the
    // match. Asked for from the couch: the write-up is the last word ON THE
    // COMMENTARY PAGE, not a panel on the report screen after it.
    await pumpMatch(tester, matchResult(), save: squadSave());
    expect(find.byKey(const ValueKey('summary-report')), findsNothing);
    stateOf(tester).skipToEnd();
    await tester.pumpAndSettle();
    final report = find.byKey(const ValueKey('summary-report'));
    expect(report, findsOneWidget);
    final prose = tester
        .widgetList<Text>(
          find.descendant(of: report, matching: find.byType(Text)),
        )
        .map((w) => w.data ?? '')
        .join(' ');
    expect(prose, contains('Ayton'));
    await settleSave(tester);
  });

  testWidgets('A GRUDGE OPENS WITH TWO LINES, not one said twice', (
    tester,
  ) async {
    // **The cache was keyed on the minute, not on the line.** `feedOf` seeds a
    // commentary row `1-c`, so the engine's opening flow line and the grudge's
    // own `commentary.snub` — both minute 1 — shared an entry and the second
    // rendered the first's text. Reported from the couch: the same commentary
    // item twice at the start of a grudge match.
    await pumpMatch(
      tester,
      matchResult(
        events: [
          {
            'minute': 1,
            'type': 'commentary',
            'textKey': 'commentary.snub',
            'textParams': {'opp': 'Ayton'},
          },
          {
            'minute': 1,
            'type': 'commentary',
            'textKey': 'commentary.flow.open.1',
          },
        ],
      ),
    );
    stateOf(tester).skipToEnd();
    await tester.pumpAndSettle();
    final snub = t('commentary.snub', {'opp': 'Ayton'});
    await reachFeed(tester, find.text(snub));
    expect(find.text(snub), findsOneWidget);
    expect(
      find.text(t('commentary.flow.open.1')),
      findsOneWidget,
      reason: 'the second line printed the first line\'s text',
    );
  });

  group('THE REFEREE', () {
    // Nothing in the spec books anybody, so all of this is the port's own — and
    // the rule that shapes it is that a SECOND YELLOW is not a straight red.
    // One is a caution too many; the other is violent conduct or denying a
    // goalscoring opportunity. Asked for from the couch in those words.
    testWidgets('books players, and the feed shows the card', (tester) async {
      // A fixture the referee is busy in, chosen the way a player would meet
      // one: `s1_m13` books two.
      final container = await pumpMatch(
        tester,
        matchResult(fixtureKey: 's1_m13'),
        save: squadSave(),
      );
      expect(container, isNotNull);
      final state = stateOf(tester);
      expect(
        state.bookings,
        isNotEmpty,
        reason: 'a full squad and the referee never reached for a pocket',
      );
      state.skipToEnd();
      await tester.pumpAndSettle();

      final card = state.bookings.first['card'] as String;
      // The head names the offence — three different words for three different
      // things — and the card itself is drawn beside it.
      // The write-up heads the feed at full time, so the card rows start one
      // screen down. A plain drag rather than `reachFeed`: two players were
      // booked and `scrollUntilVisible` insists on exactly one target.
      await tester.drag(
        find.byKey(const ValueKey('match-feed')),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(find.text(t('match.card.$card').toUpperCase()), findsWidgets);
      expect(find.byType(CardGlyph), findsWidgets);

      // And the whistle put them on the players' records, beside their goals.
      final cells =
          (container.read(gameProvider).state!['grid']
              as Map<String, dynamic>)['cells']
          as List;
      final booked = {
        for (final b in state.bookings) '${b['playerInstanceId']}',
      };
      expect(
        [
          for (final cell in cells)
            if (cell is Map<String, dynamic> &&
                booked.contains(cell['instanceId']))
              (cell['stats'] as Map?)?['yellows'],
        ],
        everyElement(isNotNull),
      );
      await settleSave(tester);
    });

    testWidgets('THEIR CARDS ARE COUNTED ONCE, watched or skipped', (
      tester,
    ) async {
      // A caught bug rather than a reported one, and it came in with the fix
      // for the reported one. Their cards now cut their rating, and the tally
      // was being incremented in two places: the live dispatch as the clock
      // reaches each card, and `_catchUpSendingsOff` over every booking at the
      // whistle. Ours are guarded by `_cautioned` and `_sentOff` being SETS;
      // theirs had nothing, so a fully watched match re-counted every
      // opposition card at full time and re-rolled the remainder against a side
      // punished twice.
      // **`s1_m2`, whose only away card is in the 17th minute.** Chosen rather
      // than reached for: a watched match cannot be pumped to the 84th here —
      // it holds on a cutaway or a coach card well before then — so a fixture
      // whose card lands early is the difference between exercising the live
      // path and only looking like it. The first version used `s1_m13`, whose
      // away card is at 84, and passed with either guard removed.
      final container = await pumpMatch(
        tester,
        matchResult(fixtureKey: 's1_m2'),
        save: squadSave(),
      );
      expect(container, isNotNull);
      final state = stateOf(tester);
      final theirs = [
        for (final b in state.bookings)
          if (b['team'] == 'away') b,
      ];
      expect(
        theirs,
        isNotEmpty,
        reason: 'this fixture was chosen because their referee is busy in it',
      );

      // Watch past every one of them, then finish — which is what runs the
      // catch-up over the whole list.
      final last = theirs
          .map((b) => (b['minute'] as num).toInt())
          .reduce((a, b) => a > b ? a : b);
      // **Until the CLOCK passes it, not for that many pumps.** A pump of one
      // minute's duration does not always advance the match a minute, so
      // counting pumps left the last card unreached and the watched path
      // untested — which is how the first version of this passed with the guard
      // taken out.
      for (var i = 0; i < 400 && state.frame.minute <= last; i++) {
        await tester.pump(minuteDurationFor(1));
      }
      expect(
        state.frame.minute,
        greaterThan(last),
        reason: 'the clock never reached their card, so nothing was watched',
      );
      expect(
        state.oppCards.yellows + state.oppCards.sendOffs,
        theirs.length,
        reason: 'the live dispatch missed one of their cards',
      );

      state.skipToEnd();
      await tester.pumpAndSettle();

      final wantSendOffs = theirs
          .where((b) => cardSendsOff('${b['card']}'))
          .length;
      final wantYellows = theirs.length - wantSendOffs;
      expect(
        state.oppCards.sendOffs,
        wantSendOffs,
        reason: 'their dismissals were counted twice',
      );
      expect(
        state.oppCards.yellows,
        // A second yellow stops counting as a caution: he is off, not booked.
        wantYellows -
            theirs.where((b) => '${b['card']}' == cardSecondYellow).length,
        reason: 'their cautions were counted twice',
      );
      await settleSave(tester);
    });

    testWidgets('and the same fixture books the same players', (tester) async {
      // Seeded off the fixture key, so a match replays what it did — the same
      // promise the cutaway makes about its passages.
      List<Object?> cardsOf(MatchScreenState s) =>
          [for (final b in s.bookings) '${b['minute']}:${b['card']}'];
      await pumpMatch(tester, matchResult(fixtureKey: 's1_m13'), save: squadSave());
      final first = cardsOf(stateOf(tester));
      await pumpMatch(tester, matchResult(fixtureKey: 's1_m13'), save: squadSave());
      expect(cardsOf(stateOf(tester)), first);
    });

    testWidgets('and it books THEM too, in the club\'s name', (tester) async {
      // The port never names an opposition player — not at a goal, not
      // anywhere — so their card is written about the club. Asked for from the
      // couch: "they can get yellow cards as well, its not just us."
      final container = await pumpMatch(
        tester,
        matchResult(fixtureKey: 's1_m13'),
        save: squadSave(),
      );
      expect(container, isNotNull);
      final state = stateOf(tester);
      final theirs = [
        for (final b in state.bookings)
          if (b['team'] == 'away') b,
      ];
      expect(theirs, isNotEmpty, reason: 'only one side was ever bookable');
      // Nothing of theirs reaches the save: no name, no ban, no record.
      //
      // **This checked `playerInstanceId == null` and now checks the id is a
      // MARKER**, which is the same claim made properly. Their cards grew an id
      // when they started costing their side a rating — the tally is
      // incremented by the live clock and again by the whistle's catch-up, so
      // something has to say "this card, once". It is `oppcard-N`, which is not
      // and can never be a card instance: it names a position in their own
      // synthetic eleven, and nothing keyed on it is ever written to the grid.
      expect(
        theirs.every((b) => '${b['playerInstanceId']}'.startsWith('oppcard-')),
        isTrue,
      );
      expect(
        theirs.every((b) => b['player'] == null),
        isTrue,
        reason: 'the port never names an opposition player',
      );
      final cells =
          (container.read(gameProvider).state!['grid']
              as Map<String, dynamic>)['cells']
          as List;
      final ids = {
        for (final c in cells)
          if (c is Map<String, dynamic>) c['instanceId'],
      };
      expect(
        theirs.every((b) => !ids.contains(b['playerInstanceId'])),
        isTrue,
        reason: 'a marker must never collide with one of our players',
      );
      expect(
        state.bookings.where((b) => b['team'] == 'home').length,
        lessThan(state.bookings.length),
      );
      state.skipToEnd();
      await tester.pumpAndSettle();
      await settleSave(tester);
    });

    testWidgets('AND A SENDING-OFF IS PLAYED OUT BY THE TEN WHO ARE LEFT', (
      tester,
    ) async {
      // **The card used to be theatre.** The scoreline is decided at kickoff by
      // `generateMatchEvents` and the port cannot touch that — it is pinned
      // field for field — but `reSimulateRemainder` reads the LIVE lineup, and
      // it is what a mid-match tactic switch already goes through. Reported
      // from the couch: "my rating didn't update so I don't know if the loss of
      // that player actually counted."
      //
      // `s1_m39` is the fixture the referee shows a straight red in.
      final container = await pumpMatch(
        tester,
        matchResult(fixtureKey: 's1_m39'),
        save: squadSave(),
      );
      final state = stateOf(tester);
      final off = [
        for (final b in state.bookings)
          if (b['team'] != 'away' && cardSendsOff('${b['card']}'))
            '${b['playerInstanceId']}',
      ];
      expect(off, hasLength(1), reason: 'nobody was sent off in s1_m39');

      final before = container.read(pitchSlotsProvider).length;
      state.skipToEnd();
      await tester.pumpAndSettle();

      // His slot is empty, so the eleven really are ten — which is what
      // `reSimulateRemainder` reads when it rolls the rest of the match.
      final onPitch = container
          .read(pitchSlotsProvider)
          .where((s) => s.cardInstanceId != null)
          .map((s) => s.cardInstanceId)
          .toList();
      expect(container.read(pitchSlotsProvider), hasLength(before));
      expect(onPitch, isNot(contains(off.single)));
      await settleSave(tester);
    });

    testWidgets('a booked man is worth ten per cent less, and shows it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420 * 3, 2000 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final container = await pumpMatch(
        tester,
        matchResult(),
        save: squadSave(),
      );
      final slot = container.read(pitchSlotsProvider).firstWhere(
        (s) => s.cardInstanceId != null,
      );
      final booked = slot.cardInstanceId!;
      await tester.pump(minuteDurationFor(5));
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(kitId: 'classic', light: false),
          home: UncontrolledProviderScope(
            container: container,
            child: Scaffold(
              body: SubsPanel(
                used: 0,
                withdrawn: const {},
                onSub: (_) {},
                cautioned: {booked},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The caution is drawn on him, and the number is the reduced one — which
      // is the number the manager is deciding against.
      expect(find.byType(CardGlyph), findsOneWidget);
      final shown = tester
          .widgetList<PitchToken>(find.byType(PitchToken))
          .firstWhere((t) => t.slot.cardInstanceId == booked);
      expect(shown.slot.effRating, (slot.effRating * yellowCardRatingMult).round());
      expect(shown.slot.effRating, lessThan(slot.effRating));
    });

    test('AND THE BENCH IS COMPARED AGAINST WHAT HE IS WORTH NOW', () {
      // "When a player has a yellow and ratings drop and we go to bench, it's
      // still comparing the player's ratings before the game vs the subs — it
      // should use his rating now, which is the one after his yellow card."
      // The ten per cent came off the token drawn on the pitch and off nothing
      // else, so the tile that says "this man is better than the one coming
      // off" was answering about a player who no longer existed — in the one
      // place a manager acts on the answer.
      //
      // Asserted on the BASIS rather than through the panel: the chip prints
      // the bench man's own rating either way and carries the comparison in its
      // colour, so a widget test sees the same numbers and proves nothing.
      const clean = CardStats(
        attack: 60,
        defence: 40,
        rating: 50,
        baseAttack: 61,
        baseDefence: 41,
        baseRating: 51,
      );

      expect(bookedStats(clean, false), same(clean), reason: 'no card, no cut');

      final booked = bookedStats(clean, true);
      expect(booked.rating, (50 * yellowCardRatingMult).round());
      expect(booked.attack, (60 * yellowCardRatingMult).round());
      expect(booked.defence, (40 * yellowCardRatingMult).round());
      expect(booked.rating, lessThan(clean.rating));

      // **THE BASE TRIO IS UNTOUCHED.** Those are what the CARD is worth — the
      // number on the Players tab, the number a sale is priced off — and a
      // booking is a fact about this afternoon rather than about him.
      expect(booked.baseRating, clean.baseRating);
      expect(booked.baseAttack, clean.baseAttack);
      expect(booked.baseDefence, clean.baseDefence);
    });

    testWidgets('and a man who is OFF cannot be taken off', (tester) async {
      tester.view.physicalSize = const Size(420 * 3, 2000 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final container = await pumpMatch(
        tester,
        matchResult(),
        save: squadSave(),
      );
      final off = container
          .read(pitchSlotsProvider)
          .firstWhere((s) => s.cardInstanceId != null);
      await tester.pump(minuteDurationFor(5));
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(kitId: 'classic', light: false),
          home: UncontrolledProviderScope(
            container: container,
            child: Scaffold(
              body: SubsPanel(
                used: 0,
                withdrawn: const {},
                onSub: (_) {},
                sentOff: {off.cardInstanceId!},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('sub-slot-${off.slotId}')));
      await tester.pumpAndSettle();
      expect(
        tester.state<SubsPanelState>(find.byType(SubsPanel)).selectedSlot,
        isNull,
        reason: 'a sending-off is not a substitution going spare',
      );
      // He is still drawn, with the card over him — a hole would not say WHO.
      expect(find.byType(CardGlyph), findsOneWidget);
    });

    testWidgets('a SECOND yellow is drawn as two cards, not one', (
      tester,
    ) async {
      // The word says which offence it was; the picture is the half a player
      // actually looks at, so it has to agree.
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(kitId: 'classic', light: false),
          home: const Scaffold(
            body: Row(
              children: [
                CardGlyph(card: cardYellow),
                CardGlyph(card: cardSecondYellow),
                CardGlyph(card: cardRed),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('card-glyph-second-yellow')),
        findsOneWidget,
      );
      // And the two straight ones are one rectangle each, in their own colour.
      final plain = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => (c.decoration as BoxDecoration?)?.color)
          .toSet();
      expect(plain, contains(cardYellowInk));
      expect(plain, contains(cardRedInk));
    });
  });

  testWidgets('THE FEED SAYS WHAT KIND OF THING HAPPENED', (tester) async {
    // Asked for from the couch: a goal gets a card and a heading, and
    // everything else went past as a bare sentence. Every word here is shipped
    // copy — `match.subs` is the panel's own title and `match.tab.tactics`
    // named the tab bar that came off this screen, which left it translated in
    // ten catalogues with nothing able to print it.
    await pumpMatch(
      tester,
      matchResult(
        events: [
          {
            'minute': 60,
            'type': 'opp_sub',
            'textKey': 'commentary.opp_sub',
            'textParams': {'opp': 'Ayton'},
          },
        ],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('match-skip')));
    await tester.pumpAndSettle();
    await reachFeed(tester, find.text(t('match.subs').toUpperCase()));
    expect(find.text(t('match.subs').toUpperCase()), findsOneWidget);
    expect(
      find.text(t('commentary.opp_sub', {'opp': 'Ayton'})),
      findsOneWidget,
      reason: 'their changes never reached the feed at all',
    );
  });

  testWidgets('and a grudge line prints its opponent, not a brace', (
    tester,
  ) async {
    // `commentary.snub` takes `{opp}`, the timeline dropped `textParams` on the
    // floor, and a grudge match opened by showing the player that brace.
    await pumpMatch(
      tester,
      matchResult(
        events: [
          {
            'minute': 1,
            'type': 'commentary',
            'textKey': 'commentary.snub',
            'textParams': {'opp': 'Ayton'},
          },
        ],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('match-skip')));
    await tester.pumpAndSettle();
    expect(find.textContaining('{opp}'), findsNothing);
    await reachFeed(tester, find.text(t('commentary.snub', {'opp': 'Ayton'})));
    expect(find.text(t('commentary.snub', {'opp': 'Ayton'})), findsOneWidget);
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

  group('A GOAL IS WATCHED AGAIN ON THE REPORT, NOT IN THE FEED', () {
    testWidgets('THE FEED CARRIES NO REPLAY CONTROL', (tester) async {
      // `MatchPopup.js` tags a goal's feed item with `feed-replay-icon` and the
      // port carried it across, chip and all. Asked for from the couch: the
      // replay belongs on the full-time report and nowhere else. A control that
      // stops the clock to show a passage the player is still in the middle of
      // is the wrong offer at the wrong moment.
      //
      // The one thing this has to prove is that the goal is still a CARD with
      // its caption — the chip shared that row, and taking a widget out of a
      // Row is where a layout quietly loses the thing next to it.
      await pumpMatch(
        tester,
        matchResult(
          events: [
            {'minute': 22, 'type': 'goal', 'team': 'home', 'scorer': 'Smith'},
          ],
        ),
      );
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.replay), findsNothing);
      expect(find.text(t('match.replay')), findsNothing);
      // The write-up now heads the feed, so the goal card is one scroll down.
      await reachFeed(tester, find.text(t('match.goal_card.title')));
      expect(find.text(t('match.goal_card.title')), findsOneWidget);
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
      await reachFeed(tester, find.byType(PlayerFace));
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
      await reachFeed(tester, find.text(t('match.goal_card.title')));

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
        find.descendant(of: feed, matching: find.text('1-0')),
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
      await reachFeed(tester, find.text(t('match.career_goal', {'n': 1})));
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
      // The ball is the goal card's own mark, and it is the only one on that
      // row for a scorer the save no longer holds.
      await reachFeed(tester, find.byIcon(Icons.sports_soccer));
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

    group('AND IT OPENS ON THE TACTIC THE CARD WAS SET TO', () {
      // **Reported from the couch: "when I choose a tactic in the drop down
      // it's not filtering through to the game, I have to repick in game".**
      // `playMatch` never stamps a `strategyId` — the JS's does not either —
      // so reading the result alone made every kickoff Balanced.
      Map<String, dynamic> savedAs(String id) {
        final s = squadSave();
        (s['squad'] as Map<String, dynamic>)['strategyId'] = id;
        return s;
      }

      /// The result as `playMatch` actually leaves it: no `strategyId` on it.
      Map<String, dynamic> asPlayed() =>
          playable()..remove('strategyId');

      testWidgets('the strip lights the SAVE\'s tactic', (tester) async {
        await pumpMatch(tester, asPlayed(), save: savedAs('parkTheBus'));
        expect(stateOf(tester).strategy, 'parkTheBus');
        stateOf(tester).skipToEnd();
        await tester.pumpAndSettle();
      });

      testWidgets('and switching still counts as a change', (tester) async {
        // The whole point of opening on it: picking the one already on is a
        // no-op, so a screen that opened on the wrong one turned the player's
        // FIRST pick into the switch.
        final result = asPlayed();
        await pumpMatch(tester, result, save: savedAs('parkTheBus'));
        await tester.pump(minuteDurationFor(20));
        stateOf(tester).applyStrategy('parkTheBus');
        await tester.pump();
        expect(
          result['strategyChanged'],
          isFalse,
          reason: 'repicking what the card already set counted as a switch',
        );
        stateOf(tester).skipToEnd();
        await tester.pumpAndSettle();
      });

      testWidgets('and a result that HAS one still wins', (tester) async {
        // A screen re-entered after a switch: `reSimulateRemainder` has
        // written the field and it is newer than the save's.
        final result = playable()..['strategyId'] = 'highPress';
        await pumpMatch(tester, result, save: savedAs('parkTheBus'));
        expect(stateOf(tester).strategy, 'highPress');
        stateOf(tester).skipToEnd();
        await tester.pumpAndSettle();
      });

      test('and the helper answers with no save at all', () {
        expect(kickoffStrategy(const {}, null), 'balanced');
        expect(
          kickoffStrategy(const {}, {
            'squad': {'strategyId': 'counterAttack'},
          }),
          'counterAttack',
        );
      });
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
      // **THE BENCH OPENS FILTERED TO THE HOLE'S OWN LINE**, which is the point
      // of the filter — so a test picking an arbitrary bench card has to widen
      // it first, the same way a manager looking outside the position would.
      await tester.tap(find.byKey(const ValueKey('subs-bench-filter-ALL')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('sub-bench-${bench.instanceId}')));
      await tester.pumpAndSettle();
      await confirmSub(tester);
      return (off: slot.cardInstanceId!, on: bench.instanceId);
    }

    testWidgets('THE CONFIRMATION SHOWS THE SWAP, not just a heading', (
      tester,
    ) async {
      // **Reported from the couch: "I assume the coach is meant to confirm who
      // you are swapping? Right now it just says subs with nothing in it".**
      // It was the heading `match.subs` over the FEED line — the sentence
      // written for the commentary after the change — and nothing on the card
      // was the two players it decides between.
      tallView(tester);
      final container = await pumpMatch(
        tester,
        matchResult(),
        save: squadSave(),
      );
      await openSubs(tester);
      final slot = container
          .read(pitchSlotsProvider)
          .firstWhere((s) => s.cardInstanceId != null);
      final bench = container.read(benchProvider).first;
      await tester.tap(find.byKey(ValueKey('sub-slot-${slot.slotId}')));
      await tester.pumpAndSettle();
      // The bench opens filtered to the hole's own line — see `makeSub`.
      await tester.tap(find.byKey(const ValueKey('subs-bench-filter-ALL')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('sub-bench-${bench.instanceId}')));
      await tester.pumpAndSettle();

      final card = find.byKey(const ValueKey('subs-confirm'));
      expect(card, findsOneWidget);
      // BOTH cards, so the swap is a picture and not a caption.
      expect(
        find.descendant(
          of: card,
          matching: find.byKey(const ValueKey('subs-confirm-off')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.byKey(const ValueKey('subs-confirm-on')),
        ),
        findsOneWidget,
      );
      // And the line under them still names them both.
      final off = container
          .read(pitchSlotsProvider)
          .firstWhere((s) => s.slotId == slot.slotId)
          .card!;
      expect(
        find.text(
          t('match.subs.feed', {'off': off.name, 'on': bench.card.name}),
        ),
        findsOneWidget,
      );

      await confirmSub(tester);
      await tester.tap(find.byKey(const ValueKey('subs-done')));
      await tester.pumpAndSettle();
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
      await settleSave(tester);
    });

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
      // **And TWO on the narrowest, which is `.bench-grid`'s own
      // `max-width: 359px` step.** The floor of three was overriding it — and
      // three across 320 points is precisely the "too small to read the face
      // on" case the floor exists to prevent, so it was enforcing the fault
      // rather than stopping it on the one size where it matters most.
      expect(benchColumns(320), 2, reason: 'the narrowest phones there are');
      expect(benchColumns(359), 2);
      // And never below two, however small the sheet gets.
      expect(benchColumns(120), 2);
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

    testWidgets('A MAN WHO IS OFF CANNOT SCORE AFTERWARDS', (tester) async {
      // **The remainder is re-rolled against the side that is actually on the
      // pitch**, and a substitution did not do it — only a tactic switch did.
      // So bringing your best striker on at 60' changed nothing about the
      // result, and `match_sub_scores` was unwinnable: it asks for a goal
      // attributed to a man who came on, `reSimulateRemainder` draws its
      // scorers from the LIVE lineup, and nothing re-drew them after a change.
      //
      // Asserted from the other end because it is the deterministic half: the
      // man taken OFF is out of the pool, so no goal after the change can be
      // his. Before the fix the kickoff event kept his name on the 70th-minute
      // goal.
      tallView(tester);
      final container = await pumpMatch(
        tester,
        matchResult(
          events: [
            {
              'minute': 70,
              'type': 'goal',
              'team': 'home',
              'scorer': 'Starter',
              'scorerInstanceId': 'c0',
            },
          ],
        ),
        save: squadSave(),
      );
      await tester.pump(minuteDurationFor(5));
      await openSubs(tester);
      final swap = await makeSub(tester, container, spent: {});
      expect(swap.off, isNotNull);

      final after = [
        for (final e
            in stateOf(tester).widget.result['events'] as List<dynamic>)
          if (e is Map<String, dynamic> &&
              e['type'] == 'goal' &&
              ((e['minute'] as num?) ?? 0) > 5)
            e['scorerInstanceId'],
      ];
      expect(
        after,
        isNot(contains(swap.off)),
        reason: 'a substituted player scored after he had been taken off',
      );
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
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
      // The bench opens filtered to the hole's own line — see `makeSub`.
      await tester.tap(find.byKey(const ValueKey('subs-bench-filter-ALL')));
      await tester.pumpAndSettle();
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

    testWidgets('AND IT IS NOT IN A BOX OF ITS OWN', (tester) async {
      // Every line already draws its own plate — that is what makes a line a
      // line rather than a paragraph — so the `GlassPanel` around the lot was
      // a box full of boxes, and the two borders 8px apart down each side were
      // the only thing it added. Asked for directly.
      await pumpMatch(tester, matchResult());
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('match-feed')),
          matching: find.byType(GlassPanel),
        ),
        findsNothing,
      );
      // The scoreboard still has one: the feed is the exception, not the rule.
      expect(find.byType(GlassPanel), findsWidgets);
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
      await settleSave(tester);
    });

    testWidgets('and it says which speed it is on', (tester) async {
      await pumpMatch(tester, matchResult());
      expect(find.text('1×'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('match-speed')));
      await tester.pump();
      expect(find.text('2×'), findsOneWidget);
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
      // The tap writes the setting, which arms the debounced save.
      await settleSave(tester);
    });

    testWidgets('it OPENS on the setting', (tester) async {
      // Two matches in a row should not need the same tap twice.
      await pumpMatch(tester, matchResult());
      expect(stateOf(tester).fast, isFalse);
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
    });

    testWidgets('AND THE TAP IS WHAT WRITES THAT SETTING', (tester) async {
      // It was live-only, so `PlayMatchButton` opened every match at 1x and a
      // manager who had settled on 2x re-tapped it every single game —
      // reported directly. The button and the settings screen's own `1x | 2x`
      // are two doors onto one preference now.
      final container = await pumpMatch(tester, matchResult());
      bool stored() {
        final settings = container.read(gameProvider).state?['settings'];
        return settings is Map && settings['matchSpeedFast'] == true;
      }
      expect(stored(), isFalse);

      await tester.tap(find.byKey(const ValueKey('match-speed')));
      await tester.pump();
      expect(stored(), isTrue);

      await tester.tap(find.byKey(const ValueKey('match-speed')));
      await tester.pump();
      expect(stored(), isFalse, reason: 'and back down again');
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
      await settleSave(tester);
    });

    testWidgets('AND IT IS THE PITCH\'S SPEED, not just the clock\'s', (
      tester,
    ) async {
      // The clock's period halved and the grass did not, so at 2x a passage
      // ran at its own pace against a match going twice as fast — reported as
      // 2x not speeding the 2D pitch up. See `CutawayGame`'s `HasTimeScale`.
      await pumpMatch(tester, matchResult(), fast: true);
      expect(tester.widget<CutawayStage>(find.byType(CutawayStage)).fast, isTrue);

      await tester.tap(find.byKey(const ValueKey('match-speed')));
      await tester.pump();
      expect(
        tester.widget<CutawayStage>(find.byType(CutawayStage)).fast,
        isFalse,
        reason: 'and it is LIVE — the grass follows the button down too',
      );
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
      await settleSave(tester);
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
      // **THE SAME SHAPE HE TAKES EVERYWHERE ELSE**: bottom-left, over a
      // dimmed page, and a tap anywhere is done with it. It was a bubble laid
      // across the width of the screen with no scrim and no way out but
      // waiting. Asked for directly.
      expect(find.byKey(const ValueKey('match-coach-head')), findsOneWidget);
      await tester.tapAt(const Offset(20, 20));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('match-coach-line')),
        findsNothing,
        reason: 'a tap outside left it there',
      );
    });

    testWidgets('AND THE PITCH STAYS LIT WHILE HE TALKS', (tester) async {
      // He is reacting to something that has just happened on the grass and
      // the match does not stop while he says so — dimming the pitch dimmed
      // the one thing on the page still moving. Asked for directly. Only the
      // PAINT is cut out: the tap-anywhere catcher still covers the hole.
      await pumpMatch(
        tester,
        matchResult(
          events: [
            {'minute': 45, 'type': 'halftime'},
          ],
        ),
        save: squadSave(),
      );
      await tester.pump(minuteDurationFor(46));
      await tester.pump();
      expect(find.byKey(const ValueKey('match-coach-line')), findsOneWidget);

      final scrim = find.byType(ClipPath).first;
      final box = tester.getRect(scrim);
      final clip = tester.widget<ClipPath>(scrim).clipper!.getClip(box.size);
      Offset local(Offset global) => global - box.topLeft;
      final stage = tester.getRect(find.byKey(const ValueKey('match-stage')));
      expect(
        clip.contains(local(stage.center)),
        isFalse,
        reason: 'the grass is under the scrim',
      );
      expect(
        clip.contains(local(box.center + Offset(0, box.height / 3))),
        isTrue,
        reason: 'and everything else stopped being dimmed',
      );

      // The tap that dismisses him still lands over the hole.
      await tester.tapAt(stage.center);
      await tester.pump();
      expect(find.byKey(const ValueKey('match-coach-line')), findsNothing);
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
  testWidgets('AND EVERY MOMENT THE PITCH TOLD IS OFFERED BACK', (
    tester,
  ) async {
    // Goals and chances alike: the clip is rebuilt from the minute and the
    // match's own seed rather than recorded, so asking for one again costs
    // nothing and gives back the passage that was played. Asked for from the
    // couch — anything that made it to the 2D pitch should be replayable from
    // the full-time panel, and the stats stand aside while it runs.
    // **THE CLOCK HAS TO RUN.** A skipped match retells nothing — `clipFor` is
    // only ever asked on the minute it lands — so the panel honestly offers
    // nothing back. This one watches the goal go in.
    await pumpMatch(
      tester,
      matchResult(
        events: [
          {'minute': 10, 'type': 'goal', 'team': 'home', 'scorer': 'Smith'},
        ],
      ),
      reduceMotion: false,
    );
    final state = stateOf(tester);
    await tester.pump(minuteDurationFor(10));
    await tester.pump();
    expect(state.clipPlaying, isTrue, reason: 'the goal drew no clip');
    await endClip(tester);
    state.skipToEnd();
    await tester.pumpAndSettle();

    expect(state.retoldMinutes, isNotEmpty, reason: 'the pitch told nothing');

    // **ON THE LINE, not on the stats panel.** It spent one round as a strip of
    // minute chips over the pitch and was asked for here instead: the sentence
    // that describes the moment is where a player is already reading about it.
    // The write-up heads the feed at full time, so the lines it describes
    // start one scroll down.
    final chip = find.byKey(const ValueKey('feed-replay'));
    await reachFeed(tester, chip);
    expect(chip, findsOneWidget);

    await tester.tap(chip);
    await tester.pump();
    // The stats get out of the way of the grass they are laid on.
    expect(find.byKey(const ValueKey('pitch-stats')), findsNothing);
    expect(state.clipPlaying, isTrue);
  });

  testWidgets('but NOT while the match is still being played', (tester) async {
    // The ninety minutes are a thing you watch, and a control that stops the
    // clock to show you a passage you are still in the middle of is the wrong
    // offer at the wrong moment. Asked for from the couch, and it is why the
    // spec's own `feed-replay-icon` came off in the first place.
    await pumpMatch(
      tester,
      matchResult(
        events: [
          {'minute': 10, 'type': 'goal', 'team': 'home', 'scorer': 'Smith'},
        ],
      ),
      reduceMotion: false,
    );
    final state = stateOf(tester);
    await tester.pump(minuteDurationFor(10));
    await tester.pump();
    await endClip(tester);
    await tester.pump(minuteDurationFor(2));
    expect(state.frame.finished, isFalse);
    expect(find.byKey(const ValueKey('feed-replay')), findsNothing);
    state.skipToEnd();
    await tester.pumpAndSettle();
  });

  testWidgets('AND AT FULL TIME THEY ARE ON THE PITCH', (tester) async {
    // The page holds at the whistle now rather than leaving on a timer, which
    // leaves the stage showing a pitch with nothing happening on it while what
    // the ninety minutes came to sits behind the board one tap away. Asked for
    // from the couch: put them on the grass, in transparent boxes.
    await pumpMatch(
      tester,
      matchResult(
        events: [
          {'minute': 10, 'type': 'goal', 'team': 'home', 'scorer': 'Smith'},
        ],
      ),
    );
    expect(find.byKey(const ValueKey('pitch-stats')), findsNothing);

    stateOf(tester).skipToEnd();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pitch-stats')), findsOneWidget);
    // Every row the board would show, on the grass — possession leads it.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('pitch-stats')),
        matching: find.text(t('match.stat.possession')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('THE STATISTICS ARE BEHIND THE BOARD, and nowhere else', (
    tester,
  ) async {
    // **Both visible doors have now been turned down.** It was a `STATS` pill
    // in the scoreboard's top-right corner — rejected, because it was the one
    // control on the page that was not in the page's row of controls. It was
    // then a fourth button in that row — rejected too, because four buttons is
    // more than the row has width for. What is left is the board itself, which
    // is where a hand goes anyway: the numbers are what the panel is about, so
    // tapping them to see more of them costs no height at all.
    await pumpMatch(tester, matchResult());
    expect(
      find.byKey(const ValueKey('match-stats-glyph')),
      findsNothing,
      reason: 'the row is back to three controls',
    );
    await tester.tap(find.byKey(const ValueKey('match-stats-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('match-stats-sheet')), findsOneWidget);
  });


  testWidgets('AND IT IS THE SAME SEAM THE PLAY PAGE USES', (tester) async {
    // Six here and twelve there meant walking from one screen to the other
    // halved the spacing — reported as the play-match popup's margins not being
    // fixed, immediately after the Play page's own were set to twelve.
    expect(matchGap, playPageGap);
  });

  group('ONE INSET DOWN THE PAGE', () {
    testWidgets('AND THE AIR ABOVE THE TACTICS IS THE AIR BELOW THEM', (
      tester,
    ) async {
      // The cooldown bar was a two-point row UNDER the panel and inside the
      // strip's own padding, so the gap below the buttons was eight and the gap
      // above them six — on the control the eye returns to most.
      await pumpMatch(tester, matchResult());
      final strip = tester.getRect(find.byKey(const ValueKey('match-tactics')));
      // **AND A LINE OF COMMENTARY STARTS WHERE A TACTIC DOES.** The feed used
      // to pay the inset twice — once for the band and again inside each plate
      // — so it started 20 points in against the strip's 13. Reported as the
      // commentary having more margin than the tactics.
      expect(
        tester.getRect(find.byKey(const ValueKey('match-commentary'))).left,
        closeTo(strip.left, 0.5),
      );
      final pitch = tester.getRect(find.byKey(const ValueKey('match-stage')));
      final feed = tester.getRect(
        find.byKey(const ValueKey('match-commentary')),
      );
      expect(strip.top - pitch.bottom, closeTo(feed.top - strip.bottom, 0.5));
    });

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
        find.byKey(const ValueKey('match-commentary')),
      );
      expect(board.left, closeTo(matchInset, 1.5), reason: 'board left');
      expect(
        width - board.right,
        closeTo(matchInset, 1.5),
        reason: 'board right',
      );
      expect(feed.left, closeTo(matchInset, 1.5), reason: 'feed left');
      expect(
        width - feed.right,
        closeTo(matchInset, 1.5),
        reason: 'feed right',
      );
      stateOf(tester).skipToEnd();
      await tester.pumpAndSettle();
    });
  });

  group('WHAT A MATCH STANDS UNDER', () {
    // **The spec's answer, and two attempts at improving on it were wrong.**
    // `.match-page` says the ground is the Play screen's sky at the same
    // stadium tier, in BOTH themes — "it used to be a hardcoded near-black in
    // both, which made light mode a black hole in an otherwise light app".
    //
    // The purple that got reported was never the sky. The spec's next
    // paragraph is the half the port had missed: "there is NO light-mode flip
    // — every panel is the scorecard's glass in both themes, because the ground
    // is the sky." The port's panels flipped with the theme, so in dark mode
    // they were thin enough to let the night sky's violet through.
    testWidgets('it is the SKY, at this tier, whichever theme is on', (
      tester,
    ) async {
      for (final light in [true, false]) {
        late Decoration under;
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(light),
            theme: buildAppTheme(kitId: '#4caf50', light: light),
            home: Builder(
              builder: (context) {
                under = matchBackdrop(context: context, tier: 3);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        final gradient = (under as BoxDecoration).gradient! as LinearGradient;
        expect(
          gradient.colors,
          skyColours(
            brightness: light ? Brightness.light : Brightness.dark,
            tier: 3,
          ),
          reason: 'light: $light',
        );
      }
    });

    testWidgets('AND ITS PANELS FOLLOW THE THEME, which reverses a decision', (
      tester,
    ) async {
      // **The spec says the opposite, and the reporter overruled it.**
      // `.match-page` in the stylesheet is explicit: "there is NO light-mode
      // flip, and that is the whole point — every panel is the scorecard's
      // glass in both themes, because the ground is the sky and the sky is a
      // daylight blue at the low tiers whatever the theme." The port did that,
      // and it was reported twice as the play screen and the end-of-match
      // screen looking identical in light mode. A player who has chosen light
      // mode and gets a dark page has been ignored by the app, which is worse
      // than a pale panel on a pale sky.
      //
      // So `darkGlass` comes off and the sky flips with the theme, which it
      // already knows how to do. The near-black-on-near-black ink that the
      // forced-dark takeover existed to fix cannot come back: it was the ink
      // being light-themed over dark glass, and now neither is forced.
      await pumpMatch(tester, matchResult());
      final panels = tester.widgetList<GlassPanel>(find.byType(GlassPanel));
      expect(panels, isNotEmpty);
      for (final panel in panels) {
        expect(panel.darkGlass, isNull, reason: 'null follows the theme');
      }
    });
  });

}
