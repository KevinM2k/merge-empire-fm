/// Keepy Uppys — the screen over the physics.
///
/// The sim itself is pinned frame by frame in `keepy_uppys_sim_test.dart`.
/// What is checked here is the wiring: that the arena builds a sim against its
/// own measured size, that a tap reaches it, that the run ends, and that the
/// WEIGHTED score with its bonus is what the engine is handed — banking `taps`
/// would pay the same for a cannonball as for a balloon.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/minigames/keepy_uppys_screen.dart';
import 'package:merge_empire_fc/ui/screens/minigames/minigame_countdown.dart';
import 'package:merge_empire_fc/ui/screens/minigames/minigames_providers.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

Map<String, dynamic> saveWith() {
  final s = createDefaultState();
  // Tier 2 Training Ground, the rung Keepy Uppys sits on.
  (s['clubAssets'] as Map<String, dynamic>)[AssetCategory.training] = {
    'owned': true,
    'tier': 2,
    'invested': 0,
    'tapCount': 0,
  };
  return s;
}

/// [counting] stops inside the 3-2-1 rather than running it out.
///
/// **THE BALL HANGS STILL BEHIND THE COUNT NOW** — see
/// `minigame_countdown.dart`. The sim is still built on the arena's first
/// layout, because the ball is placed against it; what waits for GO is the
/// ticker, so a test that wants a falling ball has to get past the count.
Future<ProviderContainer> pumpGame(
  WidgetTester tester, {
  bool counting = false,
}) async {
  tester.view.physicalSize = const Size(400 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

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
          // Seeded, so the opening drift is the same run every time.
          home: KeepyUppysScreen(random: math.Random(7)),
        ),
      ),
    ),
  );
  // Two frames: one to lay the arena out, one for the sim it builds against it.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  if (!counting) await runCountIn(tester);
  return container;
}

/// Run the 3-2-1 out.
///
/// **PUMPED UNTIL THE SCREEN SAYS SO, not for [miniGameCountdownMs]**: each
/// beat is restarted on the frame the last one finished, so a pumped count
/// overruns its own constant by a frame per beat.
Future<void> runCountIn(WidgetTester tester) async {
  for (var i = 0; i < 400 && stateOf(tester).counting; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(stateOf(tester).counting, isFalse, reason: 'the count never ended');
}

KeepyUppysScreenState stateOf(WidgetTester tester) =>
    tester.state<KeepyUppysScreenState>(find.byType(KeepyUppysScreen));

/// **No `pumpAndSettle` in this file.** The two clouds drift on repeating
/// controllers for as long as the arena is up, so the frame queue never goes
/// quiet and `pumpAndSettle` times out rather than settling. Every wait here is
/// an explicit number of frames.
///
/// Tap the ball where it currently is.
Future<void> tapBall(WidgetTester tester) async {
  final s = stateOf(tester);
  final sim = s.sim!;
  final arena = tester.getTopLeft(find.byKey(const ValueKey('ku-arena')));
  await tester.tapAt(arena + Offset(sim.x, sim.y));
  await tester.pump(const Duration(milliseconds: 16));
}

Future<void> closeGame(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: saveDebounceMs + 100));
}

void main() {
  tearDown(resetLocale);

  testWidgets('the drill is REACHABLE — it is in the playable set', (
    tester,
  ) async {
    expect(playableMiniGames, contains(MiniGameKind.keepyUppys));
  });

  testWidgets('EVERY drill in the catalogue now has a screen', (tester) async {
    // The line this whole run of work was about: `playableMiniGames` held two
    // for most of the port, so tiering the Training Ground unlocked drills
    // that could not be played.
    expect(playableMiniGames, hasLength(miniGameTitleKeys.length));
    for (final kind in miniGameTitleKeys.keys) {
      expect(playableMiniGames, contains(kind), reason: kind);
    }
  });

  testWidgets('THE ARENA IS MEASURED, and the ball placed against it', (
    tester,
  ) async {
    await pumpGame(tester);
    final sim = stateOf(tester).sim;
    expect(sim, isNotNull, reason: 'the arena never produced a ball');
    expect(sim!.arenaH, keepyArenaHeight);
    expect(sim.arenaW, greaterThan(0));
    // The JS's opening position: centred, a little over a quarter down. The
    // tolerance is one frame's drift — the sim is built on the first layout
    // and the loop has already run once by the time this can look at it.
    expect(sim.x, closeTo(sim.arenaW / 2, 1));
    expect(sim.y, closeTo(sim.arenaH * 0.28, 1));
    await closeGame(tester);
  });

  testWidgets('entering starts the cooldown, not finishing', (tester) async {
    final container = await pumpGame(tester);
    expect(
      miniGameReady(
        container.read(gameProvider).state!,
        MiniGameKind.keepyUppys,
      ),
      isFalse,
    );
    await closeGame(tester);
  });

  testWidgets('A TAP ON THE BALL KEEPS IT UP', (tester) async {
    await pumpGame(tester);
    final s = stateOf(tester);
    // Let it fall a little, so the kick is visibly a reversal.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(s.sim!.vy, greaterThan(0), reason: 'the ball never started falling');

    await tapBall(tester);
    expect(s.taps, 1);
    expect(s.sim!.vy, lessThan(0), reason: 'the tap did not send it up');
    await closeGame(tester);
  });

  testWidgets('and a tap NOWHERE NEAR it does nothing', (tester) async {
    await pumpGame(tester);
    final s = stateOf(tester);
    final arena = tester.getTopLeft(find.byKey(const ValueKey('ku-arena')));
    await tester.tapAt(arena + const Offset(6, 270));
    await tester.pump(const Duration(milliseconds: 16));
    expect(s.taps, 0, reason: 'the ball has no hitbox');
    await closeGame(tester);
  });

  testWidgets('THE FLOOR ENDS IT, and the result offers the coins', (
    tester,
  ) async {
    final container = await pumpGame(tester);
    final s = stateOf(tester);

    // Left alone from the opening drift, the balloon comes down. Deliberately
    // NOT tapped first: one tap sends it up nearly the height of the arena and
    // into the ceiling, and the fall back is hundreds of frames of nothing.
    for (var i = 0; i < 400 && !s.sim!.missed; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(s.sim!.missed, isTrue, reason: 'the balloon never came down');
    expect(find.byKey(const ValueKey('ku-missed')), findsOneWidget);

    // The miss card holds for a beat before the result.
    expect(s.over, isFalse);
    await tester.pump(keepyMissBeat + const Duration(milliseconds: 50));
    expect(s.over, isTrue);

    final before =
        (container.read(gameProvider).state!['resources']
                as Map<String, dynamic>)['fanCoins']
            as num;
    await tester.tap(find.byKey(const ValueKey('ku-collect')));
    await tester.pump();
    final after =
        (container.read(gameProvider).state!['resources']
                as Map<String, dynamic>)['fanCoins']
            as num;
    expect(after - before, s.coinsWon);
    await closeGame(tester);
  });

  testWidgets('THE ENGINE IS HANDED THE WEIGHTED SCORE, not the tap count', (
    tester,
  ) async {
    // A cannonball tap is worth two and a half balloon taps, and a full run
    // doubles the lot. Banking `taps` would pay the same for all three.
    final container = await pumpGame(tester);
    final s = stateOf(tester);
    final sim = s.sim!;
    sim.tapsByStage.setAll(0, [10, 15, 20]);
    sim.taps = 45;
    sim.bonus = true;
    expect(sim.bankedTaps, 166);

    await closeGame(tester);
    final stats =
        container.read(gameProvider).state!['stats'] as Map<String, dynamic>;
    expect(
      stats['keepyUppysBest'],
      166,
      reason: 'the raw tap count reached the engine',
    );
  });

  testWidgets('LEAVING MID-RUN banks the taps made, once', (tester) async {
    final container = await pumpGame(tester);
    final s = stateOf(tester);
    for (var i = 0; i < 3; i++) {
      await tapBall(tester);
    }
    expect(s.taps, 3);

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
    expect(
      (container.read(gameProvider).state!['stats']
          as Map<String, dynamic>)['keepyUppysRounds'],
      1,
      reason: 'the run was banked twice',
    );
  });

  group('THE COUNT IN', () {
    testWidgets('THE BALL HANGS STILL UNTIL GO', (tester) async {
      // It used to drop the instant the arena had been measured, which is one
      // frame after the screen opened — so the first fall was over before the
      // player had a hand anywhere near it.
      await pumpGame(tester, counting: true);
      final s = stateOf(tester);
      expect(find.byKey(const ValueKey('mg-countdown-3')), findsOneWidget);
      // The sim still exists — the ball is placed against the arena, so it is
      // built on that first layout; what waits is the ticker.
      expect(s.sim, isNotNull);
      final y = s.sim!.y;
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(s.counting, isTrue);
      expect(s.sim!.y, y, reason: 'the ball fell during the count');

      // And a tap on it during the count is not a keepy uppy.
      await tapBall(tester);
      expect(s.taps, 0, reason: 'the count was playable');

      await runCountIn(tester);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(s.sim!.y, isNot(y), reason: 'GO did not drop the ball');
      await closeGame(tester);
    });
  });
}
