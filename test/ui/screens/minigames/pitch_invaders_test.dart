/// Pitch Invaders.
///
/// `recordWhackResult`, `whackDifficulty` and `whackMaxCatches` have been
/// ported and tested since M1 — including the clean-sheet counter a season
/// quest reads — and there was no board to play on. Ten catalogues carry
/// `game.whack.instructions`, `.caught`, `.caught_label`, `.fouls`, `.clean`
/// and `.full_time` with nothing able to reach one.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/mini_games.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/minigames/minigames_providers.dart';
import 'package:merge_empire_fc/ui/screens/minigames/pitch_invaders_screen.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic> saveWith() {
  final s = createDefaultState();
  // Tier 4 Training Ground, the rung Pitch Invaders sits on.
  (s['clubAssets'] as Map<String, dynamic>)[AssetCategory.training] = {
    'owned': true,
    'tier': 4,
    'invested': 0,
    'tapCount': 0,
  };
  return s;
}

/// The clock the screen's deadline is read against, moved by the test rather
/// than by the wall — `now()` is the port's `Date.now()` and the seam every
/// engine's timestamps already go through.
late int fakeNow;

Future<ProviderContainer> pumpGame(WidgetTester tester) async {
  // A phone-shaped, TALL surface. On the default 800x600 the nine-hole board
  // runs off the bottom, and a tap on a hole below the fold silently hits the
  // view instead.
  tester.view.physicalSize = const Size(420 * 3, 1400 * 3);
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
          home: const PitchInvadersScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

/// Advance both clocks together. The fake async clock drives the spawn timers
/// and the ticker; `now()` drives the deadline, and if the two drift apart the
/// session either never ends or ends immediately.
Future<void> advance(WidgetTester tester, int ms) async {
  const step = 16;
  for (var moved = 0; moved < ms; moved += step) {
    fakeNow += step;
    await tester.pump(const Duration(milliseconds: step));
  }
}

PitchInvadersScreenState stateOf(WidgetTester tester) =>
    tester.state<PitchInvadersScreenState>(find.byType(PitchInvadersScreen));

Future<void> closeGame(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: saveDebounceMs + 100));
}

void main() {
  tearDown(resetLocale);

  group('what pops up', () {
    test('is STEWARD, then dog, then invader — the bands, in order', () {
      // The order decides which band a roll lands in, so it is the order and
      // not just the three numbers that has to match.
      expect(pickInvader(0.0, 0.12, 0.08), Invader.steward);
      expect(pickInvader(0.119, 0.12, 0.08), Invader.steward);
      expect(pickInvader(0.12, 0.12, 0.08), Invader.dog);
      expect(pickInvader(0.199, 0.12, 0.08), Invader.dog);
      expect(pickInvader(0.2, 0.12, 0.08), Invader.invader);
      expect(pickInvader(1.0, 0.12, 0.08), Invader.invader);
    });

    test('and the dog is worth three while a steward costs one', () {
      expect(Invader.invader.value, 1);
      expect(Invader.dog.value, Whack.dogValue);
      expect(Invader.steward.value, -Whack.foulCost);
    });

    test('stewards get commoner as you climb; the dog never does', () {
      final sunday = whackDifficulty(0);
      final champions = whackDifficulty(6);
      expect(champions.stewardPct, greaterThan(sunday.stewardPct));
      expect(champions.dogPct, sunday.dogPct);
      expect(champions.spawnMs, lessThan(sunday.spawnMs));
      expect(champions.upMs, lessThan(sunday.upMs));
    });
  });

  testWidgets('the drill is REACHABLE — it is in the playable set', (
    tester,
  ) async {
    expect(playableMiniGames, contains(MiniGameKind.whack));
  });

  testWidgets('THE LEAD-IN COMES FIRST, and nothing pops before it', (
    tester,
  ) async {
    await pumpGame(tester);
    await advance(tester, Whack.leadInMs - 100);
    final s = stateOf(tester);
    expect(s.running, isFalse, reason: 'the session started early');
    expect(s.holes.every((h) => h == null), isTrue);

    await advance(tester, 200);
    expect(stateOf(tester).running, isTrue);
    await closeGame(tester);
  });

  testWidgets('entering does not spend the attempt — KICK-OFF does', (
    tester,
  ) async {
    // Walking out during the lead-in has cost nothing, so the cooldown must
    // not have started.
    final container = await pumpGame(tester);
    await advance(tester, Whack.leadInMs - 100);
    expect(
      miniGameReady(container.read(gameProvider).state!, MiniGameKind.whack),
      isTrue,
    );

    await advance(tester, 200);
    expect(
      miniGameReady(container.read(gameProvider).state!, MiniGameKind.whack),
      isFalse,
    );
    await closeGame(tester);
  });

  testWidgets('an INVADER is a catch and a STEWARD is a foul', (tester) async {
    await pumpGame(tester);
    await advance(tester, Whack.leadInMs + 100);
    final s = stateOf(tester);

    // Wait for something to be up, then tap whatever it is and check the
    // counter moved the way that thing should move it.
    var caught = 0;
    var fouls = 0;
    for (var i = 0; i < 40 && (caught == 0 || fouls == 0); i++) {
      final upIndex = s.holes.indexWhere((h) => h != null);
      if (upIndex >= 0) {
        final what = s.holes[upIndex]!;
        final before = s.catches;
        await tester.tap(find.byKey(ValueKey('pi-hole-$upIndex')));
        await tester.pump();
        switch (what) {
          case Invader.steward:
            fouls++;
            expect(s.catches, lessThanOrEqualTo(before));
            expect(s.fouls, fouls);
          case Invader.dog:
            caught++;
            expect(s.catches, before + Whack.dogValue);
          case Invader.invader:
            caught++;
            expect(s.catches, before + 1);
        }
      }
      await advance(tester, 100);
    }
    expect(caught, greaterThan(0), reason: 'nothing was ever catchable');
    await closeGame(tester);
  });

  testWidgets('a tapped hole is EMPTY — it cannot be farmed twice', (
    tester,
  ) async {
    await pumpGame(tester);
    await advance(tester, Whack.leadInMs + 100);
    final s = stateOf(tester);
    var index = -1;
    for (var i = 0; i < 40 && index < 0; i++) {
      index = s.holes.indexWhere((h) => h != null);
      if (index < 0) await advance(tester, 100);
    }
    expect(index, greaterThanOrEqualTo(0));

    await tester.tap(find.byKey(ValueKey('pi-hole-$index')));
    await tester.pump();
    final after = s.catches;
    expect(s.holes[index], isNull);
    await tester.tap(find.byKey(ValueKey('pi-hole-$index')));
    await tester.pump();
    expect(s.catches, after, reason: 'an empty hole paid a second time');
    await closeGame(tester);
  });

  testWidgets('THE CLOCK IS A DEADLINE, not a countdown', (tester) async {
    // A phone that backgrounds the app for five seconds and comes back gets
    // the right time remaining rather than five free seconds. Here the frames
    // stop and the clock does not, which is exactly that.
    await pumpGame(tester);
    await advance(tester, Whack.leadInMs + 100);
    final s = stateOf(tester);
    expect(s.over, isFalse);

    fakeNow += Whack.durationMs;
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      s.over,
      isTrue,
      reason: 'the session survived its own deadline passing',
    );
    await closeGame(tester);
  });

  testWidgets('full time empties the board and offers the reward', (
    tester,
  ) async {
    final container = await pumpGame(tester);
    await advance(tester, Whack.leadInMs + 100);
    final s = stateOf(tester);
    fakeNow += Whack.durationMs;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pumpAndSettle();

    expect(s.holes.every((h) => h == null), isTrue);
    expect(find.byKey(const ValueKey('pi-outcome')), findsOneWidget);
    expect(find.byKey(const ValueKey('pi-caught')), findsOneWidget);

    final before =
        (container.read(gameProvider).state!['resources']
                as Map<String, dynamic>)['fanCoins']
            as num;
    await tester.tap(find.byKey(const ValueKey('pi-collect')));
    await tester.pump();
    final after =
        (container.read(gameProvider).state!['resources']
                as Map<String, dynamic>)['fanCoins']
            as num;
    expect(after - before, s.coinsWon);
    await tester.pumpAndSettle();
    await closeGame(tester);
  });

  testWidgets('LEAVING BEFORE KICK-OFF banks nothing at all', (tester) async {
    final container = await pumpGame(tester);
    await advance(tester, Whack.leadInMs - 100);
    final before = jsonEncode(container.read(gameProvider).state!['stats']);
    await closeGame(tester);
    expect(
      jsonEncode(container.read(gameProvider).state!['stats']),
      before,
      reason: 'a session that never kicked off was counted',
    );
  });

  testWidgets('but leaving MID-SESSION banks it, once', (tester) async {
    final container = await pumpGame(tester);
    await advance(tester, Whack.leadInMs + 100);
    final s = stateOf(tester);
    for (var i = 0; i < 30; i++) {
      final index = s.holes.indexWhere((h) => h != null);
      if (index >= 0 && s.holes[index] != Invader.steward) {
        await tester.tap(find.byKey(ValueKey('pi-hole-$index')));
        await tester.pump();
      }
      if (s.catches > 0) break;
      await advance(tester, 100);
    }
    expect(s.catches, greaterThan(0));

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
          as Map<String, dynamic>)['whackRounds'],
      1,
      reason: 'the session was counted twice',
    );
  });

  testWidgets('EVERY HOLE IS THE SAME SIZE', (tester) async {
    // The gutter was `Padding(left: 8)` INSIDE each `Expanded`, so the first
    // column's tile was eight points narrower... on every column but the first.
    // The tile is an `AspectRatio`, so it was eight points shorter as well.
    // Reported as the left boxes being bigger than the rest.
    await pumpGame(tester);
    final sizes = [
      for (var i = 0; i < 9; i++)
        tester.getSize(find.byKey(ValueKey('pi-hole-$i'))),
    ];
    for (final size in sizes) {
      expect(size.width, closeTo(sizes.first.width, 0.5));
      expect(size.height, closeTo(sizes.first.height, 0.5));
    }
  });

  testWidgets('AND A TILE IS MOST OF THE WIDTH IT CAN BE', (tester) async {
    // A tile is a target you have seven hundred milliseconds to hit, and the
    // board was sharing what the instructions, the score row and the timer left
    // over. Asked for twice.
    await pumpGame(tester);
    final board = tester.getSize(find.byKey(const ValueKey('pi-board')));
    final tile = tester.getSize(find.byKey(const ValueKey('pi-hole-0')));
    // Three across two gutters: the tile cannot be more than a third, and it
    // should not be much less.
    expect(tile.width, greaterThan(board.width / 3 - 6));
    expect(tile.width * 3, greaterThan(board.width * 0.9));
  });
}
