/// Goalkeeper Practice.
///
/// `recordTrainingComplete` and `trainingDifficulty` have been ported and
/// tested since M1, energy clamp and all, and there was no session to play.
/// `game.training.intro`, `.session_complete`, `.drills_hit`, `.coins`,
/// `.energy`, `mg.warming_up` and `mg.keep_going` sat translated in ten
/// catalogues with nothing able to reach one.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/data/art_paths.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/mini_games.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/minigames/goalkeeper_practice_screen.dart';
import 'package:merge_empire_fc/ui/screens/minigames/keeper_view.dart';
import 'package:merge_empire_fc/ui/screens/minigames/penalty_view.dart'
    show backdropRectFor;
import 'package:merge_empire_fc/ui/screens/minigames/minigame_countdown.dart';
import 'package:merge_empire_fc/ui/screens/minigames/minigames_providers.dart';
import 'package:merge_empire_fc/ui/screens/minigames/training_view.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic> saveWith() {
  final s = createDefaultState();
  // Tier 1 Training Ground, the rung Goalkeeper Practice sits on.
  (s['clubAssets'] as Map<String, dynamic>)[AssetCategory.training] = {
    'owned': true,
    'tier': 1,
    'invested': 0,
    'tapCount': 0,
  };
  return s;
}

late int fakeNow;

/// [counting] stops inside the 3-2-1 rather than running it out.
///
/// **THE SESSION IS BEHIND A COUNT NOW** — see `minigame_countdown.dart`. The
/// watch bar, the schedule and `_startedAt` all begin on GO, so a test that
/// plays a session has to get past it first, and every test here plays one.
Future<ProviderContainer> pumpGame(
  WidgetTester tester, {
  bool counting = false,
}) async {
  tester.view.physicalSize = const Size(420 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  fakeNow = DateTime.utc(2026, 3, 1).millisecondsSinceEpoch;
  setClock(() => fakeNow);
  addTearDown(resetClock);

  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(saveWith())}),
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
          home: const GoalkeeperPracticeScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  if (!counting) await runCountIn(tester);
  return container;
}

/// Run the 3-2-1 out.
///
/// **PUMPED UNTIL THE SCREEN SAYS SO, not for [miniGameCountdownMs].** Each
/// beat is restarted on the frame the last one finished, so a count pumped in
/// 100ms steps takes a frame per beat longer than its own constant — and a
/// fixed advance leaves the session's origin a couple of ticks adrift from
/// whatever the test then measures against it.
Future<void> runCountIn(WidgetTester tester) async {
  for (var i = 0; i < 200 && stateOf(tester).counting; i++) {
    await advance(tester, trainingTickMs);
  }
  expect(stateOf(tester).counting, isFalse, reason: 'the count never ended');
}

/// Advance the fake clock and the tick timer together. The session reads
/// `now()` for its own elapsed time, so a pump that moves one and not the other
/// is a session that never progresses.
Future<void> advance(WidgetTester tester, int ms) async {
  for (var moved = 0; moved < ms; moved += trainingTickMs) {
    fakeNow += trainingTickMs;
    await tester.pump(const Duration(milliseconds: trainingTickMs));
  }
}

GoalkeeperPracticeScreenState stateOf(WidgetTester tester) =>
    tester.state<GoalkeeperPracticeScreenState>(
      find.byType(GoalkeeperPracticeScreen),
    );

Future<void> closeGame(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: saveDebounceMs + 100));
}

void main() {
  tearDown(resetLocale);

  group('the schedule', () {
    test('LEADS IN, spreads out, and COOLS DOWN', () {
      for (final count in [4, 8, 12]) {
        final times = drillTimes(count);
        expect(times, hasLength(count));
        expect(
          times.first,
          greaterThanOrEqualTo(Training.leadInMs),
          reason: 'a drill landed before the player was looking',
        );
        // The last one's window has to close inside the session, which is what
        // the final tenth is reserved for.
        expect(
          times.last,
          lessThanOrEqualTo((Training.durationMs * 0.9).round()),
        );
        for (var i = 1; i < times.length; i++) {
          expect(times[i], greaterThan(times[i - 1]));
        }
      }
    });

    test('and it is EVENLY spread, not front-loaded', () {
      final times = drillTimes(8);
      final gaps = [
        for (var i = 1; i < times.length; i++) times[i] - times[i - 1],
      ];
      for (final gap in gaps) {
        expect(gap, closeTo(gaps.first, 1));
      }
    });

    test('more drills and a tighter window as you climb', () {
      expect(
        trainingDifficulty(6).drills,
        greaterThan(trainingDifficulty(0).drills),
      );
      expect(
        trainingDifficulty(6).windowMs,
        lessThan(trainingDifficulty(0).windowMs),
      );
    });
  });

  testWidgets('the drill is REACHABLE — it is in the playable set', (
    tester,
  ) async {
    expect(playableMiniGames, contains(MiniGameKind.training));
  });

  testWidgets('THE HEADING IS A HEADING, not the drill counter', (
    tester,
  ) async {
    // `mg.drills` is "Drills: {hit} / {total}", and the list asked for it with
    // no parameters — so the section header rendered its own braces.
    expect(t('mg.drills'), contains('{hit}'));
    expect(t('training.title'), isNot(contains('{')));
  });

  testWidgets('entering starts the cooldown, not finishing', (tester) async {
    final container = await pumpGame(tester);
    await tester.pump();
    expect(
      miniGameReady(container.read(gameProvider).state!, MiniGameKind.training),
      isFalse,
    );
    await closeGame(tester);
  });

  testWidgets('NOTHING SPAWNS during the lead-in', (tester) async {
    await pumpGame(tester);
    await advance(tester, Training.leadInMs - trainingTickMs * 2);
    expect(stateOf(tester).drillsAppeared, 0);
    expect(find.text(t('mg.warming_up')), findsOneWidget);
    await closeGame(tester);
  });

  testWidgets('A DRILL APPEARS, and tapping it counts', (tester) async {
    await pumpGame(tester);
    final s = stateOf(tester);
    // Far enough in for the first drill to be due.
    await advance(tester, drillTimes(s.drillCount).first + trainingTickMs * 2);
    expect(s.drillUp, isTrue, reason: 'no drill ever appeared');

    await tester.tap(find.byKey(const ValueKey('train-bubble')));
    await tester.pump();
    expect(s.drillsHit, 1);
    expect(s.drillUp, isFalse);
    expect(find.byKey(const ValueKey('train-flash')), findsOneWidget);
    await closeGame(tester);
  });

  testWidgets('and one LEFT ALONE expires rather than waiting forever', (
    tester,
  ) async {
    await pumpGame(tester);
    final s = stateOf(tester);
    await advance(tester, drillTimes(s.drillCount).first + trainingTickMs * 2);
    expect(s.drillUp, isTrue);

    await advance(tester, trainingDifficulty(0).windowMs + trainingTickMs * 2);
    expect(s.drillUp, isFalse, reason: 'the window never closed');
    expect(s.drillsHit, 0);
    await closeGame(tester);
  });

  testWidgets('EVERY DRILL PROMISED ACTUALLY APPEARS', (tester) async {
    // `game.training.intro` tells the player how many are coming. A schedule
    // that does not deliver them all makes that line a lie.
    await pumpGame(tester);
    final s = stateOf(tester);
    await advance(tester, Training.durationMs + trainingTickMs * 2);
    expect(s.drillsAppeared, s.drillCount);
    await closeGame(tester);
  });

  testWidgets('full time replaces the session with the summary', (
    tester,
  ) async {
    final container = await pumpGame(tester);
    final s = stateOf(tester);
    await advance(tester, Training.durationMs + trainingTickMs * 2);
    await tester.pumpAndSettle();

    expect(s.done, isTrue);
    expect(find.byKey(const ValueKey('train-summary')), findsOneWidget);
    // The bar and the stage are GONE, not merely scrolled past — the JS hides
    // them so the collect button lands where the drills were.
    expect(find.byKey(const ValueKey('train-stage')), findsNothing);
    expect(find.byKey(const ValueKey('train-bar-fill')), findsNothing);
    // Energy is zero today, so its block is hidden rather than showing "+0⚡".
    expect(find.byKey(const ValueKey('train-energy')), findsNothing);

    final before =
        (container.read(gameProvider).state!['resources']
                as Map<String, dynamic>)['fanCoins']
            as num;
    await tester.tap(find.byKey(const ValueKey('train-collect')));
    await tester.pump();
    final after =
        (container.read(gameProvider).state!['resources']
                as Map<String, dynamic>)['fanCoins']
            as num;
    expect(after - before, s.coinsWon);
    await tester.pumpAndSettle();
    await closeGame(tester);
  });

  testWidgets('a PERFECT session pays more than a missed one', (tester) async {
    // The payout scales with how many were hit, which is the whole reason to
    // tap them.
    final container = await pumpGame(tester);
    final s = stateOf(tester);
    // **WAIT FOR THE BUBBLE, do not compute when it is due.** This used to
    // walk `drillTimes` against the wall clock, which pinned the test to the
    // session's own origin — and the origin moved when the count-in went in
    // front of it (`_kickOff` sets `_startedAt`, and a coarse-pumped count
    // overruns `miniGameCountdownMs` by a frame per beat). Waiting for
    // `drillUp` asks the question the test is actually about.
    for (var i = 0; i < s.drillCount; i++) {
      for (var guard = 0; guard < 300 && !s.drillUp; guard++) {
        await advance(tester, trainingTickMs);
      }
      expect(s.drillUp, isTrue, reason: 'drill $i never appeared');
      await tester.tap(find.byKey(const ValueKey('train-bubble')));
      await tester.pump();
    }
    expect(s.drillsHit, s.drillCount, reason: 'a drill was unreachable');

    await advance(tester, Training.durationMs);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('train-collect')));
    await tester.pump();

    final missed = recordTrainingComplete(
      jsonDecode(jsonEncode(saveWith())) as Map<String, dynamic>,
      drillsHit: 0,
      drillTotal: s.drillCount,
    );
    expect(s.coinsWon, greaterThan(missed.coins));
    await tester.pumpAndSettle();
    await closeGame(tester);
    // The whole state is untouched by the reference call above.
    expect(container.read(gameProvider).state, isNotNull);
  });

  testWidgets('LEAVING MID-SESSION banks it, once', (tester) async {
    final container = await pumpGame(tester);
    final s = stateOf(tester);
    await advance(tester, drillTimes(s.drillCount).first + trainingTickMs * 2);
    await tester.tap(find.byKey(const ValueKey('train-bubble')));
    await tester.pump();
    expect(s.drillsHit, 1);

    final before =
        (container.read(gameProvider).state!['resources']
                as Map<String, dynamic>)['fanCoins']
            as num;
    await closeGame(tester);
    final after =
        (container.read(gameProvider).state!['resources']
                as Map<String, dynamic>)['fanCoins']
            as num;
    expect(after, greaterThan(before));
  });

  testWidgets('the Training list still builds with every game playable', (
    tester,
  ) async {
    // The list's job was to say WHY a row could not be tapped. With all seven
    // built, the only remaining noes are the tier and the cooldown.
    final container = ProviderContainer(
      overrides: [
        saveStoreProvider.overrideWithValue(
          MemorySaveStore({saveKeyPrimary: jsonEncode(saveWith())}),
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
            home: const Scaffold(body: TrainingView()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Upper-cased by `SheetHeader`, which is the one rule for a sheet's title.
    expect(find.text(t('training.title').toUpperCase()), findsOneWidget);
    expect(find.text(t('settings.comingSoon')), findsNothing);
  });
  testWidgets('THE WHISTLE IS THE LAST SHOT, not the clock', (tester) async {
    // Sitting on an empty scene watching a bar run down is the player being
    // made to watch nothing happen. Every shot has been faced, so the session
    // is over — and it ends WITHOUT the clock reaching the end.
    await pumpGame(tester);
    final state = stateOf(tester);
    // Face them all: tap the ball whenever one is up.
    var elapsed = 0;
    while (elapsed < Training.durationMs) {
      final bubble = find.byKey(const ValueKey('train-bubble'));
      if (bubble.evaluate().isNotEmpty) {
        await tester.tap(bubble);
        await tester.pump();
      }
      await advance(tester, trainingTickMs);
      elapsed += trainingTickMs;
      if (find.byKey(const ValueKey('train-summary')).evaluate().isNotEmpty) break;
    }
    expect(state.drillsAppeared, state.drillCount);
    expect(
      elapsed,
      lessThan(Training.durationMs),
      reason: 'it waited out the clock with nothing left to face',
    );
    await closeGame(tester);
  });

  group('THE SHOTS ARE FOOTBALLS COMING AT YOU', () {
    test('every drill wears the same face, and it is a ball', () {
      // It was five in rotation — a runner, a target, a bolt, a flame — which
      // is a list of drills rather than a keeper facing shots.
      expect(drillFace, '⚽');
    });

    test('and it starts small, because that is how distance reads', () {
      // A flat scene has exactly one cue for a ball travelling toward the
      // camera; the penalty scene got it from `_eyeZ` and this game never had
      // it at all.
      expect(drillStartScale, lessThan(0.5));
      expect(drillStartScale, greaterThan(0));
    });

    group('NO TWO SHOTS IN A ROW ARE THE SAME SHOT', () {
      test('the window jitters either side of the session\'s own', () {
        final windows = [
          for (var i = 0; i <= 10; i++) drillWindowFor(1700, i / 10),
        ];
        expect(windows.toSet().length, greaterThan(3));
      });

      test('but NEVER easier than the division asked for', () {
        // A jitter that can lengthen the window is a difficulty ramp with a
        // hole in it — the whole game gets harder as you climb and this must
        // not undo that.
        for (var i = 0; i <= 10; i++) {
          expect(drillWindowFor(1700, i / 10), lessThanOrEqualTo(1700));
        }
      });

      test('and never so short that nobody could reach it', () {
        expect(drillWindowFor(400, 1), greaterThanOrEqualTo(360));
      });
    });
  });


  group('THE VIEW IS FROM THE GOAL, LOOKING OUT', () {
    // It was the forest backdrop with a ball growing on it, so the only thing
    // in the frame that said where the camera stood was the growth itself.
    // Reported from the couch in as many words: the posts and the pitch in
    // front of us, and then exactly what we do now.
    Size stageOf(double width) => Size(width, width / keeperStageAspect);
    const view = Size(384, 384 / keeperStageAspect);

    test('the ground runs AWAY from the camera and never past the horizon', () {
      final horizon = keeperHorizon * view.height;
      expect(keeperGround(keeperNearDepth(view), view).dy, closeTo(384 / keeperStageAspect, 0.01));
      var last = double.infinity;
      for (final depth in [3.0, 5.5, 11.0, 16.5, 30.0, 52.5, 105.0, 400.0]) {
        final y = keeperGround(depth, view).dy;
        expect(y, lessThan(last), reason: '$depth m');
        expect(y, greaterThan(horizon), reason: '$depth m');
        last = y;
      }
    });

    test('and the markings stack in the order a keeper sees them', () {
      // Nearest first — the six-yard line, the box, the halfway line — and all
      // of it between the bottom edge and the treeline.
      expect(
        keeperGround(sixYardDepth, view).dy,
        greaterThan(keeperGround(boxDepth, view).dy),
      );
      expect(
        keeperGround(boxDepth, view).dy,
        greaterThan(keeperGround(halfwayDepth, view).dy),
      );
      expect(keeperGround(sixYardDepth, view).dy, lessThan(view.height));
      expect(
        keeperGround(farGoalDepth, view).dy,
        greaterThan(keeperHorizon * view.height),
      );
    });

    test('THE PENALTY AREA IS THE ONE MARKING WHOLLY IN FRAME', () {
      // What the lens is tuned against: its front corners are the widest thing
      // that has to be in the picture.
      for (final side in [-1.0, 1.0]) {
        final x = keeperProject(side * boxHalfWidth, 0, boxDepth, view).dx;
        expect(x, greaterThan(0));
        expect(x, lessThan(view.width));
      }
      // And the six-yard box is NOT, because it is nearer and so angularly
      // wider — its corners are off the sides, which is why it reads as a line
      // across the grass rather than as a box. A lens that fitted them would
      // leave the penalty area a small rectangle in the middle of the frame.
      expect(
        keeperProject(sixYardHalfWidth, 0, sixYardDepth, view).dx,
        greaterThan(view.width),
      );
      expect(
        keeperProject(-sixYardHalfWidth, 0, sixYardDepth, view).dx,
        lessThan(0),
      );
    });

    test('and everything converges on straight ahead', () {
      for (final depth in [5.5, 16.5, 52.5, 400.0]) {
        expect(keeperGround(depth, view).dx, view.width / 2, reason: '$depth m');
      }
    });

    test('ONE LENS, NOT TWO — a square metre is SQUARE', () {
      // **The fault the goal frame made visible.** The scene used to scale
      // sideways by the frame's width and downward by its height, which is two
      // different lenses, so every shape was stretched by whatever the stage's
      // aspect happened to be. On a portrait stage that stretch is vertical and
      // large: a 3:1 goal came out taller than wide.
      for (final width in [284.0, 384.0, 600.0]) {
        final v = stageOf(width);
        for (final depth in [5.0, 16.5, 40.0]) {
          final across =
              keeperProject(0.5, 0, depth, v).dx -
              keeperProject(-0.5, 0, depth, v).dx;
          final up =
              keeperProject(0, 0, depth, v).dy -
              keeperProject(0, 1, depth, v).dy;
          expect(across, closeTo(up, 1e-9), reason: 'at $width, $depth m');
        }
      }
    });

    test('A GOAL IS WIDER THAN IT IS TALL', () {
      // Reported in one line: it is a soccer goal. The frame IS the goal — see
      // the note on the wide lens for why the posts cannot be projected — so
      // the mouth it leaves has to read as one.
      for (final width in [260.0, 284.0, 320.0, 384.0, 412.0, 600.0]) {
        final v = stageOf(width);
        final mouthWide = (keeperMouthRight - keeperMouthLeft) * v.width;
        final mouthTall = v.height - keeperBarBottom * v.width;
        expect(mouthWide, greaterThan(mouthTall), reason: 'at $width');
        // And not so wide that there is no goal left to shoot into.
        expect(mouthWide / mouthTall, lessThan(3.5), reason: 'at $width');
      }
    });

    test('AND THERE IS SKY OVER THE BAR AND GRASS IN FRONT OF THE LINE', () {
      // **The window was a slot.** 1.85 with the bar 2% of the width below the
      // rim put the crossbar ON the top edge and left the near grass a strip,
      // so the ball arrived out of a letterbox. Asked for from the couch: a lot
      // more above and below, even though the ball only ever goes into the
      // goal — the picture is the point. One lens off the WIDTH is what makes
      // that free: the goal is drawn the same size either way.
      for (final width in [260.0, 284.0, 320.0, 384.0, 412.0, 600.0]) {
        final v = stageOf(width);
        expect(
          keeperBarDrop * v.width,
          greaterThan(0.06 * v.height),
          reason: 'at $width: nothing over the bar to be a stand',
        );
        expect(
          keeperBarBottom * v.width,
          lessThan(keeperHorizon * v.height),
          reason: 'at $width: a bar 2.44m up is above a keeper\'s eye',
        );
        expect(
          (1 - keeperHorizon) * v.height,
          greaterThan(0.45 * v.width),
          reason: 'at $width: the grass a shot crosses is the bigger half',
        );
      }
    });

    test('and the bar is the same aluminium as the posts', () {
      // Sizing one off the width and the other off the height made the bar
      // thinner than the posts by whatever the stage's aspect was — the same
      // anamorphic fault as the lens, in the one place the eye checks it.
      expect(keeperBarThick, keeperPostWidth);
    });

    test("THE TREELINE STANDS ON THE PITCH'S OWN HORIZON", () {
      // Fitted, the art's own field stands up behind the pitch at a different
      // perspective — the hill the penalty screen was reported for. Placed, its
      // ground line IS the seam, and it is one number both of them read.
      final rect = backdropRectFor(keeperHorizon * view.height, view);
      // 0.62 is where the Kenney backdrops put their own ground line.
      expect(
        rect.top + 0.62 * rect.height,
        closeTo(keeperHorizon * view.height, 0.5),
      );
      // Never narrower than the frame, or there is a gap down each side.
      expect(rect.width, greaterThanOrEqualTo(view.width));
    });
  });

  group('A DRILL STAYS INSIDE THE FRAME', () {
    test('never behind a post, never over the bar, at any phone width', () {
      // **The bands are FRACTIONS and the ball is 56 points**, and the two only
      // ever agreed by luck: on a 384-point stage the far end of the left band
      // put the ball's edge three tenths of a point inside the right post, and
      // on a 320-point phone it put fifteen points of the ball BEHIND it.
      // Nothing said so while the stage was a photograph — a ball near the edge
      // was just a ball near the edge — and the frame is what makes it a fault.
      for (final width in [260.0, 284.0, 320.0, 384.0, 412.0, 600.0]) {
        final stage = Size(width, width / keeperStageAspect);
        for (var i = 0; i <= 10; i++) {
          for (var j = 0; j <= 10; j++) {
            final centre = drillCentre(
              0.15 + 0.55 * i / 10,
              0.10 + 0.70 * j / 10,
              stage,
            );
            final why = 'at $width, roll $i/$j';
            expect(
              centre.dx - bubbleSize / 2,
              greaterThanOrEqualTo(keeperMouthLeft * width - 0.01),
              reason: why,
            );
            expect(
              centre.dx + bubbleSize / 2,
              lessThanOrEqualTo(keeperMouthRight * width + 0.01),
              reason: why,
            );
            expect(
              centre.dy - bubbleSize / 2,
              greaterThanOrEqualTo(keeperBarBottom * stage.width - 0.01),
              reason: why,
            );
            expect(
              centre.dy + bubbleSize / 2,
              lessThanOrEqualTo(stage.height + 0.01),
              reason: why,
            );
          }
        }
      }
    });

    test('and the spread it has always had survives a stage that fits', () {
      // HELD, not re-spread. On a phone wide enough for the bands the ball is
      // exactly where it has always been — the drill is unchanged and the frame
      // is only what it cannot leave.
      const stage = Size(384, 384 / keeperStageAspect);
      expect(
        drillCentre(0.15, 0.10, stage),
        Offset(0.10 * 384 + 28, 0.15 * stage.height + 28),
      );
      expect(
        drillCentre(0.70, 0.80, stage),
        Offset(0.80 * 384 + 28, 0.70 * stage.height + 28),
      );
    });
  });

  testWidgets('THE POSTS AND THE PITCH ARE ON THE STAGE', (tester) async {
    await pumpGame(tester);
    expect(find.byType(KeeperView), findsOneWidget);
    await closeGame(tester);
  });

  testWidgets('THE GOAL HAS A HORIZON BEHIND IT', (tester) async {
    // `art_paths.dart` says what the backdrops are for in as many words: a goal
    // standing against a wash of flat colour has nothing behind it. The penalty
    // screen has had one since they were bundled and this drill — the other one
    // with a goal in it — was still on `surface2`.
    await pumpGame(tester);
    final art = tester.widget<ArtImage>(
      find.byKey(const ValueKey('train-backdrop')),
    );
    // FOREST, not the penalty screen's grass: the two drills should not be the
    // same picture with different rules on top.
    expect(art.path, backdropPath(Backdrop.forest));
    expect(art.path, isNot(backdropPath(Backdrop.grass)));
    await closeGame(tester);
  });

  group('THE COUNT IN', () {
    testWidgets('holds the session — no ball is struck before GO', (
      tester,
    ) async {
      // The watch bar and the shot schedule both run off `_startedAt`, and it
      // used to be set in `initState` — so the first ball was in flight before
      // the player had looked at the goal.
      await pumpGame(tester, counting: true);
      expect(find.byKey(const ValueKey('mg-countdown-3')), findsOneWidget);
      await advance(tester, drillTimes(4).first + 500);
      final s = stateOf(tester);
      expect(s.counting, isTrue, reason: 'the count is not three seconds long');
      expect(s.drillsAppeared, 0, reason: 'a shot came in during the count');
      expect(s.drillUp, isFalse);
      // And the bar has not started either.
      expect(
        tester
            .widget<FractionallySizedBox>(
              find.byKey(const ValueKey('train-bar-fill')),
            )
            .widthFactor,
        0,
      );

      await runCountIn(tester);
      await advance(tester, drillTimes(s.drillCount).first + trainingTickMs * 3);
      expect(find.byKey(const ValueKey('mg-countdown-go')), findsNothing);
      expect(s.drillsAppeared, greaterThan(0), reason: 'GO did not kick off');
      await closeGame(tester);
    });

    testWidgets('and the GOAL is behind it, not replaced by it', (
      tester,
    ) async {
      await pumpGame(tester, counting: true);
      expect(find.byType(KeeperView), findsOneWidget);
      await closeGame(tester);
    });
  });
}
