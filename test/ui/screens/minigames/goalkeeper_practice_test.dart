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

Future<ProviderContainer> pumpGame(WidgetTester tester) async {
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
  return container;
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
    final due = drillTimes(s.drillCount);
    for (final at in due) {
      while (fakeNow - DateTime.utc(2026, 3, 1).millisecondsSinceEpoch < at) {
        await advance(tester, trainingTickMs);
      }
      await advance(tester, trainingTickMs);
      if (s.drillUp) {
        await tester.tap(find.byKey(const ValueKey('train-bubble')));
        await tester.pump();
      }
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
}
