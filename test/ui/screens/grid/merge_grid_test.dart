/// The merge grid — the game's core loop.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart';
import 'package:merge_empire_fc/ui/screens/grid/merge_grid.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';

/// The lowest-tier player, so a merge of two makes a predictable third.
String get _baseDefId => players.firstWhere((p) => p.tier == 1).id;

Map<String, dynamic> _card(String id, String instanceId) => {
  'definitionId': id,
  'instanceId': instanceId,
};

Future<ProviderContainer> pumpGrid(
  WidgetTester tester, {
  Map<int, Map<String, dynamic>> cards = const {},
}) async {
  final state = createDefaultState();
  final cells = (state['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
  cards.forEach((i, card) => cells[i] = card);

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
          home: const Scaffold(body: MergeGrid()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> settleSave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: saveDebounceMs + 100));

int filledCells(ProviderContainer c) =>
    gridCells(c.read(gameProvider).state).where((x) => x != null).length;

void main() {
  group('the grid', () {
    testWidgets('is three columns wide, as the data says', (tester) async {
      await pumpGrid(tester);
      final delegate =
          tester.widget<GridView>(find.byType(GridView)).gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, Grid.cols);
    });

    testWidgets('offers a slot for every cell the schema holds', (tester) async {
      final container = await pumpGrid(tester);
      expect(container.read(gridCellsProvider).length, Grid.totalCells);
    });

    testWidgets('draws a card where the save has one', (tester) async {
      await pumpGrid(tester, cards: {0: _card(_baseDefId, 'a')});
      expect(find.byType(PlayerCard), findsWidgets);
      expect(
        find.byKey(const ValueKey('grid-card-0'), skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('and an empty slot where it does not', (tester) async {
      await pumpGrid(tester);
      expect(
        find.byKey(const ValueKey('grid-empty-0'), skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('shows slots past the roster as locked, not missing', (
      tester,
    ) async {
      // A grid that silently grows reads as a glitch; a locked slot reads as
      // something to work towards.
      final container = await pumpGrid(tester);
      final cells = container.read(gridCellsProvider);
      expect(cells.where((c) => c.locked), isNotEmpty);
      expect(cells.where((c) => c.locked).first.index, Grid.maxPlayers);
      expect(cells.last.locked, isTrue);
    });
  });

  group('dragging', () {
    testWidgets('two of a kind onto each other merges them', (tester) async {
      final container = await pumpGrid(
        tester,
        cards: {0: _card(_baseDefId, 'a'), 1: _card(_baseDefId, 'b')},
      );
      expect(filledCells(container), 2);

      final from = find.byKey(const ValueKey('grid-card-0'));
      final gesture = await tester.startGesture(tester.getCenter(from));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('grid-card-1'))),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      await settleSave(tester);

      // Two became one, and the one is a tier higher.
      expect(filledCells(container), 1);
      final survivor = container
          .read(gridCellsProvider)
          .firstWhere((c) => c.card != null)
          .card!;
      expect(survivor.tier, 2);
    });

    testWidgets('a card onto an empty slot moves it', (tester) async {
      final container = await pumpGrid(tester, cards: {0: _card(_baseDefId, 'a')});

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('grid-card-0'))),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('grid-empty-1'))),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(filledCells(container), 1, reason: 'moved, not duplicated');
      expect(container.read(gridCellsProvider)[0].card, isNull);
      expect(container.read(gridCellsProvider)[1].card, isNotNull);
    });

    testWidgets('a quick flick does not pick a card up', (tester) async {
      // The hold is what lets the tab swipe and a card drag share the grid.
      final container = await pumpGrid(
        tester,
        cards: {0: _card(_baseDefId, 'a'), 1: _card(_baseDefId, 'b')},
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('grid-card-0'))),
      );
      // Moved immediately, with no hold.
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('grid-card-1'))),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(filledCells(container), 2, reason: 'nothing merged');
    });
  });

  group('what the engine refuses', () {
    testWidgets('a loaned-in card cannot be merged away', (tester) async {
      // A loanee is not ours to consume: merging one would swallow a permanent
      // card and break the "they leave" contract.
      final container = await pumpGrid(
        tester,
        cards: {
          0: {..._card(_baseDefId, 'a'), 'loanMatchesLeft': 3},
          1: _card(_baseDefId, 'b'),
        },
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('grid-card-0'))),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('grid-card-1'))),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(filledCells(container), 2, reason: 'both still there');
    });

    testWidgets('a card dropped on itself changes nothing', (tester) async {
      final container = await pumpGrid(tester, cards: {0: _card(_baseDefId, 'a')});
      final before = jsonEncode(gridCells(container.read(gameProvider).state));

      final centre = tester.getCenter(find.byKey(const ValueKey('grid-card-0')));
      final gesture = await tester.startGesture(centre);
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.moveTo(centre);
      await gesture.up();
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(
        jsonEncode(gridCells(container.read(gameProvider).state)),
        before,
      );
    });
  });

  test('the card view is resolved through the engines, not guessed', () {
    final view = cardViewFor(_card(_baseDefId, 'a'))!;
    final def = getPlayerDef(_baseDefId)!;
    expect(view.tier, def.tier);
    expect(view.rating, getCardRating(def));
    expect(view.position, def.position);
    expect(view.injured, isFalse);
    expect(view.onLoan, isFalse);
  });

  test('an unknown definition yields no card rather than throwing', () {
    // A save from a future build must not white-screen the grid.
    expect(cardViewFor(_card('no-such-player', 'a')), isNull);
    expect(cardViewFor(null), isNull);
  });
}
