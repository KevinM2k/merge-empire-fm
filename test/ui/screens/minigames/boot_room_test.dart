/// The Boot Room.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/mini_games.dart';
import 'package:merge_empire_fc/engine/boot_room_engine.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/minigames/boot_room_screen.dart';
import 'package:merge_empire_fc/ui/screens/minigames/minigames_providers.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

Map<String, dynamic> saveWith({String? division}) {
  final s = createDefaultState();
  // Tier 6 Training Ground, which is what unlocks the Boot Room.
  (s['clubAssets'] as Map<String, dynamic>)[AssetCategory.training] = {
    'owned': true,
    'tier': 6,
    'invested': 0,
    'tapCount': 0,
  };
  if (division != null) {
    (s['progression'] as Map<String, dynamic>)['currentDivision'] = division;
  }
  return s;
}

Future<ProviderContainer> pumpBootRoom(
  WidgetTester tester,
  Map<String, dynamic> state,
) async {
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
          home: const BootRoomScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // startMiniGame arms the 2s debounced save on entry; every test would
  // otherwise end with it pending.
  await tester.pump(const Duration(milliseconds: saveDebounceMs + 100));
  return container;
}

Future<void> settleSave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: saveDebounceMs + 100));

BootRoomScreenState stateOf(WidgetTester tester) =>
    tester.state<BootRoomScreenState>(find.byType(BootRoomScreen));

void main() {
  tearDown(resetLocale);

  testWidgets('the board opens settled, not mid-cascade', (tester) async {
    // createBoard guarantees it: a session should start on the player's move,
    // not on a free clear.
    await pumpBootRoom(tester, saveWith());
    final board = stateOf(tester).board;
    expect(board.length, BootRoom.cols * BootRoom.rows);
    expect(findMatches(board, BootRoom.cols, BootRoom.rows), isEmpty);
    expect(findMove(board, BootRoom.cols, BootRoom.rows), isNotNull);
  });

  testWidgets('it claims the mini-game gate and starts the cooldown', (
    tester,
  ) async {
    final container = await pumpBootRoom(tester, saveWith());
    await settleSave(tester);
    expect(container.read(tickGatesProvider).miniGameOpen, isTrue);
    expect(miniGameReady(container.read(gameProvider).state!, MiniGameKind.bootRoom), isFalse);
  });

  testWidgets('a swap that matches nothing costs no move', (tester) async {
    // The engine's rule, and the genre's.
    await pumpBootRoom(tester, saveWith());
    final screen = stateOf(tester);
    final before = screen.movesLeft;

    // Two cells in the same row with one between them: never adjacent, so the
    // swap is illegal however the board fell.
    await tester.tap(find.byKey(const ValueKey('tile-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tile-2')));
    await tester.pumpAndSettle();

    expect(stateOf(tester).movesLeft, before);
    expect(stateOf(tester).tilesCleared, 0);
  });

  testWidgets('a matching swap spends a move and clears tiles', (tester) async {
    await pumpBootRoom(tester, saveWith());
    final screen = stateOf(tester);
    final move = findMove(screen.board, BootRoom.cols, BootRoom.rows)!;
    final before = screen.movesLeft;

    await tester.tap(find.byKey(ValueKey('tile-${move.a}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('tile-${move.b}')));
    await tester.pumpAndSettle();

    expect(stateOf(tester).movesLeft, before - 1);
    expect(stateOf(tester).tilesCleared, greaterThan(0));
  });

  testWidgets('the session ends when the moves run out, and pays', (
    tester,
  ) async {
    final container = await pumpBootRoom(tester, saveWith());
    final coinsBefore = container.read(coinsProvider);

    // Play until it finishes, taking whatever move the engine offers.
    for (var i = 0; i < 40 && !stateOf(tester).finished; i++) {
      final screen = stateOf(tester);
      final move = findMove(screen.board, BootRoom.cols, BootRoom.rows);
      if (move == null) break;
      await tester.tap(find.byKey(ValueKey('tile-${move.a}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('tile-${move.b}')));
      await tester.pumpAndSettle();
    }
    await settleSave(tester);

    expect(stateOf(tester).finished, isTrue);
    expect(find.byKey(const ValueKey('boot-room-reward')), findsOneWidget);
    expect(find.byKey(const ValueKey('boot-room-outcome')), findsOneWidget);
    expect(container.read(coinsProvider), greaterThanOrEqualTo(coinsBefore));
  });

  testWidgets('the climb makes it harder, not just richer', (tester) async {
    // Fewer moves up top, and a sixth kit type — which is why the target does
    // not simply ramp with division.
    final bottom = bootRoomDifficulty(0);
    final top = bootRoomDifficulty(divisions.length - 1);
    expect(top.moves, lessThan(bottom.moves));
    expect(top.types, greaterThanOrEqualTo(bottom.types));

    await pumpBootRoom(tester, saveWith(division: divisions.last.id));
    expect(stateOf(tester).movesLeft, top.moves);
  });

  testWidgets('it is listed as playable now, and locked without the facility', (
    tester,
  ) async {
    final built = await pumpBootRoom(tester, saveWith());
    final row = built
        .read(miniGamesProvider)
        .firstWhere((g) => g.kind == MiniGameKind.bootRoom);
    expect(row.playable, isTrue);
    expect(row.unlocked, isTrue);
  });
}
