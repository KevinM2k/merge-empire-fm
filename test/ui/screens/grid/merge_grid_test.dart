/// The merge grid — the game's core loop.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/player_art.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart';
import 'package:merge_empire_fc/ui/screens/grid/merge_burst.dart';
import 'package:merge_empire_fc/ui/screens/grid/merge_grid.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';
import 'package:merge_empire_fc/ui/widgets/player_portrait.dart';

/// The lowest-tier player, so a merge of two makes a predictable third.
String get _baseDefId => players.firstWhere((p) => p.tier == 1).id;

int get _maleVariant =>
    List.generate(playerVariants, (i) => i).firstWhere((i) => !isVariantFemale(i));
int get _femaleVariant =>
    List.generate(playerVariants, (i) => i).firstWhere(isVariantFemale);

/// A stored card.
///
/// `variant` is set explicitly and matched across a pair on purpose. A card
/// without one is backfilled at load with a RANDOM variant, and the merge rule
/// refuses two players of different genders — correctly, but it made a merge
/// test pass about one run in three. A real saved card always has a variant.
Map<String, dynamic> _card(String id, String instanceId, {int variant = 0}) => {
  'definitionId': id,
  'instanceId': instanceId,
  'variant': variant,
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


/// Drop the card at [from] onto [to] by driving the DragTarget directly.
///
/// A synthesised long-press drag is not reliably recognised in a widget test —
/// it passed about two runs in three — and a flaky test that asserts "nothing
/// merged" is worse than useless, because a gesture that silently fails makes
/// it pass. The gesture itself is Flutter's; what is ours is the WIRING, so
/// that is what this drives. The hold is asserted separately, as a contract.
void dropOn(WidgetTester tester, int from, Key to) {
  final target = tester.widget<DragTarget<int>>(
    find.ancestor(of: find.byKey(to), matching: find.byType(DragTarget<int>)),
  );
  target.onAcceptWithDetails!(
    DragTargetDetails<int>(data: from, offset: Offset.zero),
  );
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
    testWidgets('a card is picked up on a HOLD, not a flick', (tester) async {
      // The hold is what lets a card drag and the tab swipe share the grid. The
      // JS needs a pan-y touch-action rule, a body class and a hand-rolled
      // timer for this; the delay on the draggable is all of it here.
      await pumpGrid(tester, cards: {0: _card(_baseDefId, 'a')});
      final draggable = tester.widget<LongPressDraggable<int>>(
        find.ancestor(
          of: find.byKey(const ValueKey('grid-card-0')),
          matching: find.byType(LongPressDraggable<int>),
        ),
      );
      expect(draggable.delay, const Duration(milliseconds: 200));
      expect(draggable.data, 0);
    });

    testWidgets('two of a kind dropped on each other merge', (tester) async {
      final container = await pumpGrid(
        tester,
        cards: {0: _card(_baseDefId, 'a'), 1: _card(_baseDefId, 'b')},
      );
      expect(filledCells(container), 2);

      dropOn(tester, 0, const ValueKey('grid-card-1'));
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

    testWidgets('a card dropped on an empty slot moves', (tester) async {
      final container = await pumpGrid(
        tester,
        cards: {0: _card(_baseDefId, 'a')},
      );

      dropOn(tester, 0, const ValueKey('grid-empty-1'));
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(filledCells(container), 1, reason: 'moved, not duplicated');
      expect(container.read(gridCellsProvider)[0].card, isNull);
      expect(container.read(gridCellsProvider)[1].card, isNotNull);
    });

    testWidgets('two of the same player but different genders swap, not merge', (
      tester,
    ) async {
      // The engine's rule, and the reason a merge test needs an explicit
      // variant: a card loaded without one is backfilled with a random variant,
      // and a mismatched pair swaps rather than merging.
      final container = await pumpGrid(
        tester,
        cards: {
          0: _card(_baseDefId, 'a', variant: _maleVariant),
          1: _card(_baseDefId, 'b', variant: _femaleVariant),
        },
      );

      dropOn(tester, 0, const ValueKey('grid-card-1'));
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(filledCells(container), 2, reason: 'swapped, not merged');
    });

    testWidgets('a slot refuses a drop from itself', (tester) async {
      await pumpGrid(tester, cards: {0: _card(_baseDefId, 'a')});
      final target = tester.widget<DragTarget<int>>(
        find.ancestor(
          of: find.byKey(const ValueKey('grid-card-0')),
          matching: find.byType(DragTarget<int>),
        ),
      );
      expect(
        target.onWillAcceptWithDetails!(
          DragTargetDetails<int>(data: 0, offset: Offset.zero),
        ),
        isFalse,
      );
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

      dropOn(tester, 0, const ValueKey('grid-card-1'));
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(filledCells(container), 2, reason: 'both still there');
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

  group('Pro mode', () {
    test('casual cards carry no fitness, Pro ones do', () {
      final raw = _card(_baseDefId, 'a');
      expect(cardViewFor(raw)!.fitness, isNull);
      expect(cardViewFor(raw, proMode: true)!.fitness, isNotNull);
    });

    testWidgets('the grid reads Pro mode off the save', (tester) async {
      final container = await pumpGrid(
        tester,
        cards: {0: _card(_baseDefId, 'a')},
      );
      expect(container.read(gridCellsProvider)[0].card!.fitness, isNull);

      container.read(gameProvider).update(
        (s) => (s['settings'] as Map<String, dynamic>)['hardMode'] = true,
      );
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(container.read(gridCellsProvider)[0].card!.fitness, isNotNull);
    });
  });

  group('Add Player', () {
    testWidgets('an empty grid can be filled from the button', (tester) async {
      // The state the game opens in: no cards, nothing to merge, nobody to
      // field. This is the way out of it.
      final container = await pumpGrid(tester);
      expect(filledCells(container), 0);
      expect(find.byKey(const ValueKey('add-player')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('add-player')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(filledCells(container), 1);
      expect(find.byType(PlayerCard), findsWidgets);
    });

    testWidgets('and again, and again', (tester) async {
      final container = await pumpGrid(tester);
      for (var i = 1; i <= 3; i++) {
        await tester.tap(find.byKey(const ValueKey('add-player')));
        await tester.pumpAndSettle();
        await settleSave(tester);
        expect(filledCells(container), i);
      }
    });

    testWidgets('signing charges the coins', (tester) async {
      final container = await pumpGrid(tester);
      final before = container.read(coinsProvider);
      await tester.tap(find.byKey(const ValueKey('add-player')));
      await tester.pumpAndSettle();
      await settleSave(tester);
      expect(container.read(coinsProvider), lessThan(before));
    });

    testWidgets('a skint club is refused and told why', (tester) async {
      final container = await pumpGrid(tester);
      container.read(gameProvider).update(
        (s) => (s['resources'] as Map<String, dynamic>)['fanCoins'] = 0,
      );
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const ValueKey('add-player')))
            .onPressed,
        isNull,
      );
      expect(find.byKey(const ValueKey('add-player-blocked')), findsOneWidget);
      expect(filledCells(container), 0);
    });
  });

  group('the card art', () {
    testWidgets('a signed player has a portrait', (tester) async {
      // The variant table has carried skin, hair and gender since M1; the JS
      // header called the portraits "UI work for a later milestone".
      await pumpGrid(tester);
      await tester.tap(find.byKey(const ValueKey('add-player')));
      await tester.pumpAndSettle();
      await settleSave(tester);
      expect(find.byType(PlayerPortrait), findsWidgets);
    });

    test('every shipped variant resolves to a portrait', () {
      for (var i = 0; i < playerVariants; i++) {
        expect(cardViewFor(_card(_baseDefId, 'a', variant: i))!.variant, i);
      }
    });
  });

  group('selling', () {
    testWidgets('tapping a card opens the sell sheet', (tester) async {
      // Until this, the grid was one-way and a tap did nothing at all.
      await pumpGrid(tester, cards: {0: _card(_baseDefId, 'a')});
      await tester.tap(find.byKey(const ValueKey('grid-card-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sell-sheet')), findsOneWidget);
      expect(find.byKey(const ValueKey('sell-price')), findsOneWidget);
    });

    testWidgets('confirming sells at the price on screen', (tester) async {
      // The multiplier is rolled once, when the sheet opens. Rolling again on
      // confirm would pay out a different number from the one just agreed.
      final container = await pumpGrid(
        tester,
        cards: {0: _card(_baseDefId, 'a')},
      );
      final coinsBefore = container.read(coinsProvider);

      await tester.tap(find.byKey(const ValueKey('grid-card-0')));
      await tester.pumpAndSettle();
      final quoted = tester
          .widget<Text>(find.byKey(const ValueKey('sell-price')))
          .data!;

      await tester.ensureVisible(find.byKey(const ValueKey('sell-confirm')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sell-confirm')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(filledCells(container), 0, reason: 'the card is gone');
      final gained = container.read(coinsProvider) - coinsBefore;
      expect(formatCoins(gained), quoted);
    });

    testWidgets('cancelling changes nothing', (tester) async {
      final container = await pumpGrid(
        tester,
        cards: {0: _card(_baseDefId, 'a')},
      );
      final before = container.read(coinsProvider);

      await tester.tap(find.byKey(const ValueKey('grid-card-0')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('sell-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sell-cancel')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(filledCells(container), 1);
      expect(container.read(coinsProvider), before);
    });

    testWidgets('a loanee cannot be sold, and is told why', (tester) async {
      // Not ours to sell: the loan engine is still tracking a contract.
      await pumpGrid(
        tester,
        cards: {
          0: {..._card(_baseDefId, 'a'), 'loanMatchesLeft': 3},
        },
      );
      await tester.tap(find.byKey(const ValueKey('grid-card-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sell-blocked')), findsOneWidget);
      expect(find.byKey(const ValueKey('sell-confirm')), findsNothing);
    });
  });

  group('the merge celebration', () {
    testWidgets('a merge bursts at the cell it landed in', (tester) async {
      // Merging is the core action and it landed in silence.
      final container = await pumpGrid(
        tester,
        cards: {0: _card(_baseDefId, 'a'), 1: _card(_baseDefId, 'b')},
      );
      dropOn(tester, 0, const ValueKey('grid-card-1'));
      await tester.pump();

      final bursts = tester
          .stateList<MergeBurstState>(find.byType(MergeBurst))
          .where((b) => b.isPlaying);
      expect(bursts.length, 1, reason: 'exactly one cell celebrates');

      await tester.pumpAndSettle();
      await settleSave(tester);
      expect(filledCells(container), 1);
    });

    testWidgets('a move does not', (tester) async {
      // A move is the player tidying up; applauding it would make the burst
      // mean nothing.
      await pumpGrid(tester, cards: {0: _card(_baseDefId, 'a')});
      dropOn(tester, 0, const ValueKey('grid-empty-1'));
      await tester.pump();
      expect(
        tester
            .stateList<MergeBurstState>(find.byType(MergeBurst))
            .where((b) => b.isPlaying),
        isEmpty,
      );
      await tester.pumpAndSettle();
      await settleSave(tester);
    });

    testWidgets('a rarer merge is a louder one', (tester) async {
      // The JS scales the particle count by tier, so a Legend lands harder
      // than a bronze.
      expect(particlesForTier(9), greaterThan(particlesForTier(1)));
      // And an unknown tier is still drawable.
      expect(particlesForTier(99), greaterThan(0));
      expect(particlesForTier(0), greaterThan(0));
    });
  });
}
