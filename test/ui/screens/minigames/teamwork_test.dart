/// Team Work — the memory grid.
///
/// `recordPairsResult` and `pairsDifficulty` have been ported and tested since
/// M1, clear bonus and all, and there was no board. Five `game.teamwork.*`
/// strings sat translated in ten catalogues with nothing able to reach one.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/mini_games.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/minigames/minigames_providers.dart';
import 'package:merge_empire_fc/ui/screens/minigames/teamwork_screen.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/util/format.dart';

Map<String, dynamic> saveWith() {
  final s = createDefaultState();
  // Tier 5 Training Ground, the rung Team Work sits on.
  (s['clubAssets'] as Map<String, dynamic>)[AssetCategory.training] = {
    'owned': true,
    'tier': 5,
    'invested': 0,
    'tapCount': 0,
  };
  return s;
}

Future<ProviderContainer> pumpGame(WidgetTester tester) async {
  // Six pairs is three rows of card-shaped tiles under a header; on the
  // default 800x600 the collect button is off the bottom.
  tester.view.physicalSize = const Size(420 * 3, 1600 * 3);
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
          home: const TeamworkScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

TeamworkScreenState stateOf(WidgetTester tester) =>
    tester.state<TeamworkScreenState>(find.byType(TeamworkScreen));

/// Wait out the opening peek, so the board is face-down and playable.
Future<void> endPeek(WidgetTester tester) async {
  await tester.pump(Duration(milliseconds: pairsDifficulty(0).peekMs + 50));
  await tester.pumpAndSettle();
}

Future<void> tapTile(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(ValueKey('pairs-tile-$index')));
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> closeGame(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: saveDebounceMs + 100));
}

void main() {
  tearDown(resetLocale);

  group('the board', () {
    test('is two tiles per definition, and no definition twice', () {
      var i = 0;
      double roll() => (i++ * 7919 % 1000) / 1000;
      final defs = pickPairDefs(2, 6, roll);
      expect(defs, hasLength(6));
      expect(defs.map((d) => d.id).toSet(), hasLength(6));

      final tiles = dealTiles(defs, roll);
      expect(tiles, hasLength(12));
      for (final def in defs) {
        expect(tiles.where((t) => t.id == def.id), hasLength(2));
      }
    });

    test('DRAWS FROM THE TIER BAND around the division', () {
      double roll() => 0.5;
      for (final divIdx in [0, 3, 6]) {
        final defs = pickPairDefs(divIdx, 6, roll);
        for (final def in defs) {
          expect(def.tier, greaterThanOrEqualTo(divIdx - 1));
          expect(def.tier, lessThanOrEqualTo(divIdx + 3));
        }
      }
    });

    test('and falls back to the WHOLE catalogue rather than short-dealing', () {
      // A band too thin to fill the board must still give a full grid — a
      // memory game with a card missing its partner cannot be cleared.
      double roll() => 0;
      final defs = pickPairDefs(0, players.length, roll);
      expect(defs, hasLength(players.length));
    });

    test('is four columns, except at five pairs', () {
      expect(pairsColumns(4), 4);
      expect(pairsColumns(5), 5);
      expect(pairsColumns(6), 4);
    });

    test('gets bigger and the peek shorter as you climb', () {
      expect(pairsDifficulty(6).pairs, greaterThan(pairsDifficulty(0).pairs));
      expect(pairsDifficulty(6).peekMs, lessThan(pairsDifficulty(0).peekMs));
    });
  });

  testWidgets('the drill is REACHABLE — it is in the playable set', (
    tester,
  ) async {
    expect(playableMiniGames, contains(MiniGameKind.pairs));
  });

  testWidgets('THE PEEK COMES FIRST, and it locks the board', (tester) async {
    final container = await pumpGame(tester);
    final s = stateOf(tester);
    expect(s.locked, isTrue, reason: 'the board was playable during the peek');
    // Nothing spent yet — a peek is not a session.
    expect(
      miniGameReady(container.read(gameProvider).state!, MiniGameKind.pairs),
      isTrue,
    );

    await endPeek(tester);
    expect(s.locked, isFalse);
    expect(
      miniGameReady(container.read(gameProvider).state!, MiniGameKind.pairs),
      isFalse,
    );
    await closeGame(tester);
  });

  testWidgets('A MATCH STAYS UP and costs no life', (tester) async {
    await pumpGame(tester);
    final s = stateOf(tester);
    await endPeek(tester);

    final pair = s.positionsOf(s.tiles.first);
    await tapTile(tester, pair[0]);
    await tapTile(tester, pair[1]);
    expect(s.matchedPairs, 1);
    expect(s.lives, Pairs.lives);
    expect(s.locked, isFalse, reason: 'a match left the board locked');
    await closeGame(tester);
  });

  testWidgets('and a MISMATCH burns a life and flips both back', (
    tester,
  ) async {
    await pumpGame(tester);
    final s = stateOf(tester);
    await endPeek(tester);

    final a = 0;
    final b = s.tiles.indexWhere((t) => t.id != s.tiles[0].id);
    await tapTile(tester, a);
    await tapTile(tester, b);
    expect(s.lives, Pairs.lives - 1);
    expect(s.matchedPairs, 0);

    // Locked through the flip-back beat, so a third tap cannot land while the
    // two cards are still being compared.
    expect(s.locked, isTrue);
    await tester.pump(const Duration(milliseconds: Pairs.mismatchHideMs + 50));
    await tester.pumpAndSettle();
    expect(s.locked, isFalse);
    await closeGame(tester);
  });

  testWidgets('a SECOND TAP on the same card is not a second card', (
    tester,
  ) async {
    await pumpGame(tester);
    final s = stateOf(tester);
    await endPeek(tester);
    await tapTile(tester, 0);
    await tapTile(tester, 0);
    expect(s.lives, Pairs.lives, reason: 'a card was matched against itself');
    expect(s.matchedPairs, 0);
    await closeGame(tester);
  });

  testWidgets('CLEARING THE BOARD pays the clear bonus', (tester) async {
    final container = await pumpGame(tester);
    final s = stateOf(tester);
    await endPeek(tester);

    for (final def in {for (final t in s.tiles) t.id: t}.values) {
      final pair = s.positionsOf(def);
      await tapTile(tester, pair[0]);
      await tapTile(tester, pair[1]);
    }
    await tester.pumpAndSettle();
    expect(s.cleared, isTrue);
    expect(s.over, isTrue);
    expect(find.byKey(const ValueKey('pairs-outcome')), findsOneWidget);

    final before =
        (container.read(gameProvider).state!['resources']
                as Map<String, dynamic>)['fanCoins']
            as num;
    await tester.tap(find.byKey(const ValueKey('pairs-collect')));
    await tester.pump();
    final after =
        (container.read(gameProvider).state!['resources']
                as Map<String, dynamic>)['fanCoins']
            as num;

    // The board's worth without the bonus, so the bonus is what is being
    // checked rather than merely "some coins arrived".
    final plain = roundCoins(
      miniGameRewardBase(container.read(gameProvider).state) *
          Pairs.rewardPerPairMult *
          s.totalPairs,
    );
    expect(after - before, greaterThan(plain));
    expect(
      (container.read(gameProvider).state!['stats']
          as Map<String, dynamic>)['pairsCleared'],
      1,
    );
    await tester.pumpAndSettle();
    await closeGame(tester);
  });

  testWidgets('RUNNING OUT OF LIVES ends it, face up', (tester) async {
    await pumpGame(tester);
    final s = stateOf(tester);
    await endPeek(tester);

    // Five deliberate mismatches. The two cards are picked fresh each time so
    // a shuffle that happens to put a pair side by side cannot break this.
    for (var life = 0; life < Pairs.lives; life++) {
      final a = s.tiles.indexWhere((t) => !s.positionsOf(t).any((i) => false));
      final b = s.tiles.indexWhere((t) => t.id != s.tiles[a].id);
      await tapTile(tester, a);
      await tapTile(tester, b);
      await tester.pump(
        const Duration(milliseconds: Pairs.mismatchHideMs + 50),
      );
      await tester.pumpAndSettle();
    }
    expect(s.lives, 0);
    expect(s.over, isTrue);
    expect(s.cleared, isFalse);
    expect(find.text('💔 ${t('game.teamwork.out_of_lives')}'), findsOneWidget);
    await closeGame(tester);
  });

  testWidgets('LEAVING MID-BOARD banks the pairs found, once', (tester) async {
    final container = await pumpGame(tester);
    final s = stateOf(tester);
    await endPeek(tester);
    final pair = s.positionsOf(s.tiles.first);
    await tapTile(tester, pair[0]);
    await tapTile(tester, pair[1]);
    expect(s.matchedPairs, 1);

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
          as Map<String, dynamic>)['pairsRounds'],
      1,
    );
    expect(
      (container.read(gameProvider).state!['stats']
          as Map<String, dynamic>)['pairsCleared'],
      isNot(1),
      reason: 'an unfinished board was paid the clear bonus',
    );
  });

  testWidgets('but leaving DURING THE PEEK banks nothing', (tester) async {
    final container = await pumpGame(tester);
    final before = jsonEncode(container.read(gameProvider).state!['stats']);
    await closeGame(tester);
    expect(jsonEncode(container.read(gameProvider).state!['stats']), before);
  });
}
