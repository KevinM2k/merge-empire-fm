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

/// The same grid with animations LEFT ON, for the handful of tests that are about
/// an animation rather than about what it animates.
Future<ProviderContainer> pumpGridAnimated(
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
  // One frame, not `pumpAndSettle`: the mergeable ring loops for ever with
  // animations on, so settling is the one thing this harness cannot do.
  await tester.pump();
  return container;
}

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
          // A mergeable pair pulses forever, so `pumpAndSettle` would never
          // settle. The ring honours reduce-motion; declaring it here is what a
          // device with that setting on would do.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
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
        tester.widget<InkWell>(find.byKey(const ValueKey('add-player'))).onTap,
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

    testWidgets('a fresh save is offered it, because it is not mid-tutorial', (
      tester,
    ) async {
      // It used to be withheld here, on the grounds that the auto-tier rules are
      // dormant during the tutorial and a switch onto them would do nothing.
      // True, and unreachable: the tutorial is not ported, nothing sets
      // `tutorial.done`, and a fresh save sat behind this gate — along with the
      // x-N batch control, sponsors, rival bids and auto-tier — permanently.
      await pumpGrid(tester);
      expect(find.byKey(const ValueKey('grid-autosell')), findsOneWidget);
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

    testWidgets('and is dead, not gone, with nothing to merge', (tester) async {
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

    testWidgets('and a tidy-up is never a cutscene', (tester) async {
      // A move and a swap are the player tidying up. Now that a signing flies
      // into its square, the thing to hold is that shuffling cards around does
      // NOT — every tidy-up would otherwise open a reveal over the grid.
      await pumpGrid(
        tester,
        cards: {
          0: _card(_baseDefId, 'a', variant: _maleVariant),
          2: _card(_baseDefId, 'b', variant: _femaleVariant),
        },
      );
      dropOn(tester, 0, 1);
      await tester.pump();
      expect(find.byKey(const ValueKey('scout-reveal')), findsNothing);
      dropOn(tester, 1, 2);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('scout-reveal')),
        findsNothing,
        reason: 'a swap is not a signing either',
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

    testWidgets('and every layer of it is the JS\'s own', (tester) async {
      // The counts had been `6 + tier * 2`, which spends less on the rarest
      // merge in the game than the JS spends on a bronze one.
      expect(particlesForTier(1), 18);
      expect(particlesForTier(5), 26);
      expect(particlesForTier(7), 38);
      // One shockwave, two from tier four, three from tier seven.
      expect(ringsForTier(1), 1);
      expect(ringsForTier(4), 2);
      expect(ringsForTier(7), 3);
      expect(peakForTier(7), greaterThan(peakForTier(5)));
      expect(peakForTier(5), greaterThan(peakForTier(1)));
    });

    testWidgets('the burst wears the TIER colours, not the kit', (
      tester,
    ) async {
      expect(mergeBurstColours(1), isNot(mergeBurstColours(7)));
      expect(
        mergeBurstColours(99),
        mergeBurstColours(5),
        reason: 'gold, where the JS table runs out',
      );
      expect(
        mergeBurstColours(7, coins: true),
        mergeBurstColours(1, coins: true),
        reason: 'a card being cashed in reads as money, not as its tier',
      );
    });

    testWidgets('a merge POPS the card, off its bottom edge', (tester) async {
      await pumpGridAnimated(
        tester,
        cards: {
          0: _card(_baseDefId, 'a', variant: _maleVariant),
          1: _card(_baseDefId, 'b', variant: _maleVariant),
        },
      );
      dropOn(tester, 0, 1);
      await tester.pump();
      // The two cards go together first; the burst starts when the flight lands.
      await tester.pump(const Duration(milliseconds: 320));
      final card = find.byType(PlayerCard);
      final rest = tester.getRect(card);

      // The squash, then the stretch — the JS's 90ms and 150ms.
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        tester.getRect(card).height,
        lessThan(rest.height),
        reason: 'squashed first',
      );
      await tester.pump(const Duration(milliseconds: 160));
      final popped = tester.getRect(card);
      expect(popped.height, greaterThan(rest.height), reason: 'then stretched');
      expect(
        popped.bottom,
        moreOrLessEquals(rest.bottom, epsilon: 1.5),
        reason: 'pivoted on the bottom edge, so it grows out of its square',
      );

      // And settles back into the square it started in.
      await tester.pump(mergeBurstDuration);
      expect(
        tester.getRect(card).height,
        moreOrLessEquals(rest.height, epsilon: 1),
      );
      await settleSave(tester);
    });

    testWidgets('and the cell itself blows out, briefly', (tester) async {
      await pumpGridAnimated(
        tester,
        cards: {
          0: _card(_baseDefId, 'a', variant: _maleVariant),
          1: _card(_baseDefId, 'b', variant: _maleVariant),
        },
      );
      dropOn(tester, 0, 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));

      int filters() => tester
          .widgetList(
            find.descendant(
              of: find.byType(MergeBurst),
              matching: find.byType(ColorFiltered),
            ),
          )
          .length;
      await tester.pump(const Duration(milliseconds: 100));
      final flashing = filters();
      // The flash is 350ms of the JS's `brightness(3) saturate(2)` decaying.
      await tester.pump(const Duration(milliseconds: 400));
      expect(filters(), lessThan(flashing), reason: 'and then it is over');
      await tester.pump(mergeBurstDuration);
      await settleSave(tester);
    });

    testWidgets('reduce-motion merges without the celebration', (tester) async {
      await pumpGrid(
        tester,
        cards: {
          0: _card(_baseDefId, 'a', variant: _maleVariant),
          1: _card(_baseDefId, 'b', variant: _maleVariant),
        },
      );
      dropOn(tester, 0, 1);
      await tester.pump();
      final card = find.byType(PlayerCard);
      final rest = tester.getRect(card);
      await tester.pump(const Duration(milliseconds: 240));
      expect(
        tester.getRect(card),
        rest,
        reason: 'the merge happened; nothing moved to say so',
      );
      await tester.pumpAndSettle();
      await settleSave(tester);
    });
  });

  group('what a held card can merge with', () {
    testWidgets('a matching pair is a target, a different player is not', (
      tester,
    ) async {
      // The rule the grid greys out by, and it is the merge rule exactly — not
      // "everything except the card in my hand". Dimming every other card said
      // nothing about which squares would take it.
      final other = players
          .firstWhere((p) => p.tier == 1 && p.id != _baseDefId)
          .id;
      final container = await pumpGrid(
        tester,
        cards: {
          0: _card(_baseDefId, 'a', variant: _maleVariant),
          1: _card(_baseDefId, 'b', variant: _maleVariant),
          2: _card(other, 'c', variant: _maleVariant),
        },
      );
      final targets = mergeTargetsFor(container.read(gameProvider).state, 0);
      expect(targets, contains(1));
      expect(targets, isNot(contains(2)));
      // Never itself.
      expect(targets, isNot(contains(0)));
    });

    testWidgets('and two of the same player of different genders are not', (
      tester,
    ) async {
      // They swap rather than merge, so offering the swap as a merge target
      // promises something the engine then refuses.
      final container = await pumpGrid(
        tester,
        cards: {
          0: _card(_baseDefId, 'a', variant: _maleVariant),
          1: _card(_baseDefId, 'b', variant: _femaleVariant),
        },
      );
      expect(mergeTargetsFor(container.read(gameProvider).state, 0), isEmpty);
    });

    testWidgets('a loaned card in hand has no targets at all', (tester) async {
      // Deliberately the whole grid: dropping it still swaps, and the point is
      // that nothing is offered as a MERGE before the player lets go.
      final container = await pumpGrid(
        tester,
        cards: {
          0: {
            ..._card(_baseDefId, 'a', variant: _maleVariant),
            'loanMatchesLeft': 3,
          },
          1: _card(_baseDefId, 'b', variant: _maleVariant),
        },
      );
      expect(mergeTargetsFor(container.read(gameProvider).state, 0), isEmpty);
    });

    testWidgets('and a loaned card is never a target either', (tester) async {
      final container = await pumpGrid(
        tester,
        cards: {
          0: _card(_baseDefId, 'a', variant: _maleVariant),
          1: {
            ..._card(_baseDefId, 'b', variant: _maleVariant),
            'loanMatchesLeft': 3,
          },
        },
      );
      expect(mergeTargetsFor(container.read(gameProvider).state, 0), isEmpty);
    });
  });

  group('the drop target for an OCCUPIED cell', () {
    testWidgets('exists, and is the card itself', (tester) async {
      // The cards are their own layer over the slots, so a drop onto an occupied
      // cell hit the card and never reached a DragTarget underneath it — merging
      // stopped working entirely the moment the sort animation went in. The
      // target has to be ON the card.
      await pumpGrid(
        tester,
        cards: {
          0: _card(_baseDefId, 'a', variant: _maleVariant),
          1: _card(_baseDefId, 'b', variant: _maleVariant),
        },
      );
      for (final i in [0, 1]) {
        final target = find.byKey(ValueKey('grid-drop-$i'));
        expect(target, findsOneWidget, reason: 'cell $i has no drop target');
        // And it is inside the CARD's subtree, not a sibling under it.
        expect(
          find.descendant(
            of: target,
            matching: find.byKey(ValueKey('grid-card-$i')),
          ),
          findsOneWidget,
          reason: 'cell $i target is not on the card, so a drop misses it',
        );
      }
    });

    testWidgets('and exactly ONE target per cell', (tester) async {
      // Two would both accept, and the one underneath could never be reached.
      await pumpGrid(
        tester,
        cards: {0: _card(_baseDefId, 'a', variant: _maleVariant)},
      );
      expect(find.byKey(const ValueKey('grid-drop-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('grid-drop-1')), findsOneWidget);
    });

    testWidgets('and an empty cell keeps its own on the slot layer', (
      tester,
    ) async {
      await pumpGrid(tester);
      expect(find.byKey(const ValueKey('grid-drop-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('grid-empty-0')), findsOneWidget);
    });
  });

  group('the merge hint', () {
    testWidgets('marks BOTH halves of a pair, and nothing else', (
      tester,
    ) async {
      final other = players
          .firstWhere((p) => p.tier == 1 && p.id != _baseDefId)
          .id;
      final container = await pumpGrid(
        tester,
        cards: {
          0: _card(_baseDefId, 'a', variant: _maleVariant),
          1: _card(_baseDefId, 'b', variant: _maleVariant),
          2: _card(other, 'c', variant: _maleVariant),
        },
      );
      expect(container.read(mergeableCellsProvider), {0, 1});
    });

    testWidgets('and marks nothing at all with no pair on the grid', (
      tester,
    ) async {
      final container = await pumpGrid(
        tester,
        cards: {0: _card(_baseDefId, 'a', variant: _maleVariant)},
      );
      expect(container.read(mergeableCellsProvider), isEmpty);
    });
  });

  group('a card arrives when it LANDS, not before', () {
    testWidgets('the square stays empty until the reveal is over', (
      tester,
    ) async {
      // The engine has to place a signing to allocate its square, so without
      // holding it back the card is already sitting in the cell it is about to
      // be flown into — and the flight lands on top of itself.
      final container = await pumpGrid(tester);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('add-player')));
      await tester.pump();

      expect(container.read(gridPendingProvider), isNotEmpty);
      expect(
        container.read(gridCellsProvider).where((c) => c.card != null),
        isEmpty,
        reason: 'in the save, not yet on the grid',
      );

      await tester.pump(scoutRevealHold(1) + const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(container.read(gridPendingProvider), isEmpty);
      expect(
        container.read(gridCellsProvider).where((c) => c.card != null),
        hasLength(1),
        reason: 'and then it is there',
      );
      await settleSave(tester);
    });

    testWidgets('a card moved by hand does not glide there afterwards', (
      tester,
    ) async {
      // The player watched it travel under their own finger; sliding it again
      // afterwards is the app repeating something they just did.
      await pumpGridAnimated(
        tester,
        cards: {0: _card(_baseDefId, 'a', variant: _maleVariant)},
      );
      dropOn(tester, 0, 4);
      await tester.pump();
      final moved = tester.getRect(find.byType(PlayerCard));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.getRect(find.byType(PlayerCard)),
        moved,
        reason: 'already where it was put',
      );
      // Explicit pumps, not `pumpAndSettle`: the animated harness has loops in
      // it that never settle.
      await settleSave(tester);
    });

    testWidgets('but a SORT glides, because it reorders everything', (
      tester,
    ) async {
      final low = players.firstWhere((p) => p.tier == 1).id;
      final high = players.firstWhere((p) => p.tier > 1).id;
      await pumpGridAnimated(
        tester,
        cards: {
          0: _card(low, 'a', variant: _maleVariant),
          1: _card(high, 'b', variant: _maleVariant),
        },
      );
      final before = tester.getRect(find.byKey(const ValueKey('grid-card-b')));
      await tester.tap(find.byKey(const ValueKey('grid-sort')));
      await tester.pump();
      final atStart = tester.getRect(find.byKey(const ValueKey('grid-card-b')));
      expect(atStart, before, reason: 'it has not jumped — it is on its way');
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.getRect(find.byKey(const ValueKey('grid-card-b'))),
        isNot(before),
      );
      await settleSave(tester);
    });
  });

  group('the way home', () {
    testWidgets('the grid lends the reveal a way to find a square', (
      tester,
    ) async {
      final container = await pumpGrid(tester);
      await tester.pump();
      expect(
        container.read(scoutLandingProvider),
        isNotNull,
        reason: 'nothing else knows where a cell is',
      );
    });

    testWidgets('and hands it back when the grid leaves the screen', (
      tester,
    ) async {
      final container = await pumpGrid(tester);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(
        container.read(scoutLandingProvider),
        isNull,
        reason: 'a card must not fly into a grid that is gone',
      );
    });

    testWidgets('a square below the fold is scrolled onto the screen first', (
      tester,
    ) async {
      final container = await pumpGrid(tester);
      await tester.pump();
      final viewport = tester.getRect(find.byKey(const ValueKey('merge-grid')));
      final far = Grid.totalCells - 1;
      final before = tester.getRect(
        find.byKey(ValueKey('grid-locked-$far'), skipOffstage: false),
      );
      expect(
        before.top,
        greaterThan(viewport.bottom),
        reason: 'the last row is a long way down',
      );

      final pending = container.read(scoutLandingProvider)!([far]);
      await tester.pumpAndSettle();
      final rect = (await pending).single;
      expect(rect, isNotNull);
      expect(rect!.top, greaterThanOrEqualTo(viewport.top));
      expect(rect.bottom, lessThanOrEqualTo(viewport.bottom));
    });

    testWidgets('and an unknown cell is no rect rather than a throw', (
      tester,
    ) async {
      final container = await pumpGrid(tester);
      await tester.pump();
      final pending = container.read(scoutLandingProvider)!([9999]);
      await tester.pumpAndSettle();
      expect((await pending).single, isNull);
    });
  });

  group('the two cards go together', () {
    testWidgets('a merge flies the card into the one it merges with', (
      tester,
    ) async {
      // The port applied the merge and burst on the spot, so a pair vanished and
      // a new card appeared with nothing joining the two events — the move read
      // as a glitch. It has to travel.
      //
      // Pumped WITHOUT reduce-motion, because the flight is the thing under test
      // and reduce-motion skips it by design.
      final container = await pumpGridAnimated(
        tester,
        cards: {
          0: _card(_baseDefId, 'a', variant: _maleVariant),
          1: _card(_baseDefId, 'b', variant: _maleVariant),
        },
      );
      dropOn(tester, 0, 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(
        find.byKey(const ValueKey('grid-flying-card')),
        findsOneWidget,
        reason: 'nothing travelled between the two cells',
      );

      // And it is gone once it lands, so the burst fires on a clear cell.
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('grid-flying-card')), findsNothing);
      // Driven, not settled: this harness runs WITH animations, and the grid
      // now carries a looping income bar on every card — a loop never settles,
      // which is the whole reason every other harness declares reduce-motion.
      await tester.pump(const Duration(milliseconds: 600));
      await settleSave(tester);
      expect(filledCells(container), 1);
    });

    testWidgets('and reduce-motion merges without the flight', (tester) async {
      // The RESULT is not decoration, so it still happens — only the travel goes.
      final container = await pumpGrid(
        tester,
        cards: {
          0: _card(_baseDefId, 'a', variant: _maleVariant),
          1: _card(_baseDefId, 'b', variant: _maleVariant),
        },
      );
      dropOn(tester, 0, 1);
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(find.byKey(const ValueKey('grid-flying-card')), findsNothing);
      expect(filledCells(container), 1);
    });
  });
}
