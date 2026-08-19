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
import 'package:merge_empire_fc/engine/auto_tier_engine.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/engine/merge_flow_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart';
import 'package:merge_empire_fc/ui/screens/grid/merge_burst.dart';
import 'package:merge_empire_fc/ui/screens/grid/merge_grid.dart';
import 'package:merge_empire_fc/ui/screens/grid/scout_reveal.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/ui/widgets/player_portrait.dart';

/// The lowest-tier player, so a merge of two makes a predictable third.
String get _baseDefId => players.firstWhere((p) => p.tier == 1).id;

int get _maleVariant => List.generate(
  playerVariants,
  (i) => i,
).firstWhere((i) => !isVariantFemale(i));
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
  bool tutorialDone = false,
}) async {
  final state = createDefaultState();
  final cells =
      (state['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
  cards.forEach((i, card) => cells[i] = card);
  (state['tutorial'] as Map<String, dynamic>)['done'] = tutorialDone;

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

/// Drop the card at [from] onto the slot at [to] by driving the DragTarget.
///
/// A synthesised long-press drag is not reliably recognised in a widget test —
/// it passed about two runs in three — and a flaky test that asserts "nothing
/// merged" is worse than useless, because a gesture that silently fails makes
/// it pass. The gesture itself is Flutter's; what is ours is the WIRING, so
/// that is what this drives. The hold is asserted separately, as a contract.
///
/// Addressed by slot INDEX rather than by the widget in it: the cards are their
/// own animated layer now, so a card's drop target is its sibling, not its
/// ancestor.
void dropOn(WidgetTester tester, int from, int to) {
  final target = tester.widget<DragTarget<int>>(
    find.byKey(ValueKey('grid-drop-$to')),
  );
  target.onAcceptWithDetails!(
    DragTargetDetails<int>(data: from, offset: Offset.zero),
  );
}

Future<void> settleSave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: saveDebounceMs + 100));

/// Tap Add Player and let the reveal run its course.
///
/// The button turns its cards over before it hands the grid back, and stays dead
/// for the duration — so a test that only pumps until the frames stop finds the
/// reveal still up and the next tap ignored.
Future<void> tapAddPlayer(WidgetTester tester, {int cards = 1}) async {
  await tester.tap(find.byKey(const ValueKey('add-player')));
  // One frame to MOUNT the reveal — its hold only starts counting once it is on
  // screen, so a single long pump would insert it at the end of the very window
  // it was supposed to run inside, and leave it up with a timer pending.
  await tester.pump();
  await tester.pump(scoutRevealHold(cards) + const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
  await settleSave(tester);
}

int filledCells(ProviderContainer c) =>
    gridCells(c.read(gameProvider).state).where((x) => x != null).length;

void main() {
  group('the grid', () {
    testWidgets('is three columns wide, as the data says', (tester) async {
      await pumpGrid(tester);
      // The cards are positioned rather than delegated to a grid, so the column
      // count is the ladder `.grid-container` climbs — asserted at the width a
      // phone actually has.
      expect(gridColumnsFor(400), Grid.cols);
      expect(gridColumnsFor(320), 2);
      expect(gridColumnsFor(700), 4);
      expect(gridColumnsFor(900), 5);
    });

    testWidgets('offers a slot for every cell the schema holds', (
      tester,
    ) async {
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

      dropOn(tester, 0, 1);
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

      dropOn(tester, 0, 1);
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

      dropOn(tester, 0, 1);
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(filledCells(container), 2, reason: 'swapped, not merged');
    });

    testWidgets('a slot refuses a drop from itself', (tester) async {
      await pumpGrid(tester, cards: {0: _card(_baseDefId, 'a')});
      final target = tester.widget<DragTarget<int>>(
        find.byKey(const ValueKey('grid-drop-0')),
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

      dropOn(tester, 0, 1);
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

      container
          .read(gameProvider)
          .update(
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

      await tapAddPlayer(tester);

      expect(filledCells(container), 1);
      expect(find.byType(PlayerCard), findsWidgets);
    });

    testWidgets('and again, and again', (tester) async {
      final container = await pumpGrid(tester);
      for (var i = 1; i <= 3; i++) {
        await tapAddPlayer(tester);
        expect(filledCells(container), i);
      }
    });

    testWidgets('signing charges the coins', (tester) async {
      final container = await pumpGrid(tester);
      final before = container.read(coinsProvider);
      await tapAddPlayer(tester);
      expect(container.read(coinsProvider), lessThan(before));
    });

    testWidgets('a skint club is refused, with the price still on show', (
      tester,
    ) async {
      // The whole group greys out together and KEEPS its price. A caption under
      // the bar would say the same thing and reflow the grid down every time the
      // coins ran out, which is why the JS does not have one — the dead button
      // carrying a number the HUD says you cannot afford is the explanation.
      final container = await pumpGrid(tester);
      container
          .read(gameProvider)
          .update(
            (s) => (s['resources'] as Map<String, dynamic>)['fanCoins'] = 0,
          );
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(
        tester
            .widget<InkWell>(find.byKey(const ValueKey('add-player')))
            .onTap,
        isNull,
      );
      expect(find.text(t('players.addPlayer')), findsOneWidget);
      expect(filledCells(container), 0);
    });
  });

  group('the status strip', () {
    testWidgets('counts what is on the grid against what it holds', (
      tester,
    ) async {
      final container = await pumpGrid(
        tester,
        cards: {0: _card(_baseDefId, 'a')},
      );
      expect(
        find.text(
          t('grid.player_count', {
            'count': 1,
            'max': getMaxPlayers(container.read(gameProvider).state),
          }),
        ),
        findsOneWidget,
      );
    });

    testWidgets('carries the auto-sell rule, because it fires HERE', (
      tester,
    ) async {
      // A scouted card of a switched-on tier never reaches this grid, so the
      // rule has to be visible from it.
      await pumpGrid(tester, tutorialDone: true);
      expect(find.byKey(const ValueKey('grid-autosell')), findsOneWidget);
      expect(find.textContaining(t('settings.autoTier.off')), findsOneWidget);
    });

    testWidgets('and opens the sheet that sets it', (tester) async {
      final container = await pumpGrid(tester, tutorialDone: true);
      // The pills sit under the LAST row of cards, so reaching them means
      // scrolling the grid — which is where the JS puts them and what they
      // describe. The Settings row carries the same sheet for anyone who does
      // not want the scroll.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('grid-autosell')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('grid-autosell')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('auto-tier-sheet')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('auto-tier-1')));
      await tester.pumpAndSettle();
      await settleSave(tester);
      expect(activeAutoTiers(container.read(gameProvider).state), contains(1));
    });

    testWidgets('mid-tutorial the pill is not offered at all', (tester) async {
      // The rules are dormant then, so a switch onto them would do nothing.
      await pumpGrid(tester);
      expect(find.byKey(const ValueKey('grid-autosell')), findsNothing);
      expect(find.byKey(const ValueKey('grid-count')), findsOneWidget);
    });
  });

  group('the tools row', () {
    testWidgets('Merge carries its price', (tester) async {
      // The sweep is a convenience being bought, so the fee is on the button
      // rather than discovered after the tap. No pair count: the JS label is
      // the word and the price, and the count was the port's own addition.
      final container = await pumpGrid(
        tester,
        cards: {0: _card(_baseDefId, 'a'), 1: _card(_baseDefId, 'b')},
      );
      final cost = mergeAllCost(container.read(gameProvider).state);
      expect(cost, greaterThan(0));

      final labels = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('merge-all')),
              matching: find.byType(Text),
            ),
          )
          .map((w) => w.data ?? '')
          .join(' ');
      expect(labels, contains(t('players.merge')));
      expect(labels, contains(formatCoins(cost)));
    });

    testWidgets('tapping it sweeps the grid and charges once', (tester) async {
      final container = await pumpGrid(
        tester,
        cards: {
          0: _card(_baseDefId, 'a'),
          1: _card(_baseDefId, 'b'),
          2: _card(_baseDefId, 'c'),
          3: _card(_baseDefId, 'd'),
        },
      );
      final cost = mergeAllCost(container.read(gameProvider).state);
      final coinsBefore = container.read(coinsProvider);

      await tester.tap(find.byKey(const ValueKey('merge-all')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(filledCells(container), lessThan(4));
      expect(container.read(coinsProvider), coinsBefore - cost);
    });

    testWidgets('a club that cannot pay sees the price on a dead button', (
      tester,
    ) async {
      // Dead rather than hidden: the pairs are still there and so is the reason
      // they cannot be swept.
      final container = await pumpGrid(
        tester,
        cards: {0: _card(_baseDefId, 'a'), 1: _card(_baseDefId, 'b')},
      );
      container
          .read(gameProvider)
          .update(
            (s) => (s['resources'] as Map<String, dynamic>)['fanCoins'] = 0,
          );
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(
        tester.widget<InkWell>(find.byKey(const ValueKey('merge-all'))).onTap,
        isNull,
      );
      expect(filledCells(container), 2);
    });

    testWidgets('and is dead, not gone, with nothing to merge', (
      tester,
    ) async {
      // Hidden would reflow the bar every time a pair appeared or went. It
      // stays put and goes dead, which is what the JS does.
      await pumpGrid(tester, cards: {0: _card(_baseDefId, 'a')});
      expect(find.byKey(const ValueKey('merge-all')), findsOneWidget);
      expect(
        tester.widget<InkWell>(find.byKey(const ValueKey('merge-all'))).onTap,
        isNull,
      );
    });
  });

  group('the card art', () {
    testWidgets('a signed player has a portrait', (tester) async {
      // PNG-first, like the JS: the generated art with the drawn portrait as
      // its fallback. The variant table has carried skin, hair and gender
      // since M1, and it now picks which of the two files to ask for.
      await pumpGrid(tester);
      await tapAddPlayer(tester);

      final art = tester.widgetList<ArtImage>(find.byType(ArtImage));
      expect(art, isNotEmpty);
      expect(art.first.path, startsWith('assets/players/'));
      expect(art.first.fallback, isA<PlayerPortrait>());
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
      dropOn(tester, 0, 1);
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
      dropOn(tester, 0, 1);
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
