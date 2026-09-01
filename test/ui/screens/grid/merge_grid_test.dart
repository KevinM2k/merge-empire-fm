/// The merge grid — the game's core loop.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart' show hudClearance;
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/player_art.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/data/traits.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/auto_tier_engine.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/engine/merge_flow_engine.dart';
import 'package:merge_empire_fc/engine/sell_card_engine.dart';
import 'package:merge_empire_fc/engine/tutorial_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart';
import 'package:merge_empire_fc/ui/screens/grid/loan_arrival.dart';
import 'package:merge_empire_fc/ui/widgets/trait_copy.dart';
import 'package:merge_empire_fc/ui/screens/grid/merge_burst.dart';
import 'package:merge_empire_fc/ui/screens/grid/merge_grid.dart';
import 'package:merge_empire_fc/ui/screens/grid/scout_reveal.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
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
  // **TRUE by default, and it used to be false and INERT.** `settleTutorial`
  // marked every save finished on the way in, so this parameter said `false`
  // in twenty-eight tests and none of them was mid-tutorial. It settles only a
  // save with evidence of play now — there is a tutorial to be in the middle
  // of — so the default has to say what these tests actually mean.
  bool tutorialDone = true,
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
  // **TRUE by default, and it used to be false and INERT.** `settleTutorial`
  // marked every save finished on the way in, so this parameter said `false`
  // in twenty-eight tests and none of them was mid-tutorial. It settles only a
  // save with evidence of play now — there is a tutorial to be in the middle
  // of — so the default has to say what these tests actually mean.
  bool tutorialDone = true,
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

    testWidgets('AND `max-width: 359px` INCLUDES 359', (tester) async {
      // The one thing a CSS breakpoint says that a `<` does not. Read as
      // `width < 359`, a 359-point viewport got three columns where the shipped
      // app gives two — one point wide, and only on the narrowest phones there
      // are, which is exactly the width that rule exists for.
      await pumpGrid(tester);
      expect(gridColumnsFor(359), 2);
      expect(gridColumnsFor(360), Grid.cols);
    });

    testWidgets('and past 1100 it MEASURES rather than stopping at five', (
      tester,
    ) async {
      // `auto-fill, minmax(200px, 1fr)`. On a tablet the grid was five wide
      // with the rest of the row empty.
      await pumpGrid(tester);
      expect(gridColumnsFor(1100), greaterThanOrEqualTo(5));
      expect(gridColumnsFor(1600), greaterThan(gridColumnsFor(1100)));
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

  test('AND A TUTORIAL LOANEE IS ON LOAN, flag or no flag', () {
    // The tutorial lends eleven men with `borrowed: true` and no
    // `loanMatchesLeft` — the loan engine's own discriminator — so the first
    // cards a new player ever sees earned an income line on screen and never
    // said LOANED. `idle_engine` has paid that flag nothing all along.
    final view = cardViewFor(
      {..._card(_baseDefId, 'a'), 'borrowed': true},
      state: createDefaultState(),
    )!;
    expect(view.onLoan, isTrue);
    expect(view.incomePerSec, isNull, reason: 'a borrowed man earns us nothing');
  });

  group('THE TRAIT REACHES THE CARD', () {
    // The badge is only worth drawing if a real save can fill it: the trait
    // lives on the card instance as `{id, level}`, and the view is where every
    // other value on a card is resolved.
    test('a card carrying one hands the view its glyph, level and title', () {
      final view = cardViewFor({
        ..._card(_baseDefId, 'a'),
        'trait': {'id': 'finisher', 'level': 3},
      })!;
      expect(view.trait?.icon, traits['finisher']!.icon);
      expect(view.trait?.level, 'III');
      // The localised title, which is what the badge gives a screen reader.
      expect(view.trait?.title, traitTitle({'id': 'finisher', 'level': 3}));
    });

    test(
      'and a card with none, or one the data has never heard of, has none',
      () {
        expect(cardViewFor(_card(_baseDefId, 'a'))!.trait, isNull);
        expect(
          cardViewFor({
            ..._card(_baseDefId, 'a'),
            'trait': {'id': 'no-such-trait', 'level': 1},
          })!.trait,
          isNull,
        );
      },
    );
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

    testWidgets('BOTH PILLS HAVE A GROUND, whatever they are saying', (
      tester,
    ) async {
      // They painted a translucent wash and nothing underneath it — 16% of the
      // accent when auto-sell is on, 25% of a red at the roster limit. That
      // reads as a tint over a plain page and as a see-through label over the
      // ones this game draws, with the humbug stripes running through the words.
      // Reported off exactly those two backdrops.
      await pumpGrid(tester, tutorialDone: true);
      final kit = Theme.of(
        tester.element(find.byType(MergeGrid)),
      ).extension<KitTheme>()!;
      for (final key in ['grid-count', 'grid-autosell']) {
        final fill =
            (tester
                        .widget<Container>(
                          find
                              .descendant(
                                of: find.byKey(ValueKey(key)),
                                matching: find.byType(Container),
                              )
                              .first,
                        )
                        .decoration
                    as BoxDecoration)
                .color!;
        expect(fill.a, 1, reason: '$key still shows the backdrop through it');
      }
      // And the tint is BLENDED rather than dropped: an accent wash on the
      // plate is not the plate.
      expect(pillGround(kit, const Color(0x40E53935)), isNot(kit.surface2));
      expect(pillGround(kit, null), kit.surface2);
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

    testWidgets('the quote holds across a reopen, and says when it moves', (
      tester,
    ) async {
      // The roll used to happen on every open, so closing and reopening the
      // sheet shopped for a better price — a slot machine the player pulls
      // rather than a market that moves. One offer stands per window, and the
      // countdown is what makes "time your sale" a thing the game does.
      resetMarketQuotes();
      await pumpGrid(tester, cards: {0: _card(_baseDefId, 'a')});
      await tester.tap(find.byKey(const ValueKey('grid-card-0')));
      await tester.pumpAndSettle();
      final quoted = tester
          .widget<Text>(find.byKey(const ValueKey('sell-price')))
          .data!;
      final countdown = tester
          .widget<Text>(find.byKey(const ValueKey('sell-refresh')))
          .data!;
      expect(
        int.parse(RegExp(r'(\d+)').firstMatch(countdown)!.group(1)!),
        inInclusiveRange(1, marketWindow.inSeconds),
      );

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('sell-cancel')),
        240,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const ValueKey('sell-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('grid-card-0')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('sell-price'))).data,
        quoted,
      );
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

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('sell-confirm')),
        240,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sell-confirm')));
      await tester.pumpAndSettle();
      // **AND IT ASKS FIRST.** Selling is irreversible and the button sits under
      // the thumb at the foot of a sheet, so a mis-tap costs a player.
      expect(find.byKey(const ValueKey('coach-card')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('coach-action-common.sell')));
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
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('sell-cancel')),
        240,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sell-cancel')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(filledCells(container), 1);
      expect(container.read(coinsProvider), before);
    });

    testWidgets('the LIVE cancel does not look disabled', (tester) async {
      // **An enabled Cancel wore a disabled button's clothes.** The sheet asked
      // `styleFrom` for `foregroundColor: kit.textMuted` — the very colour
      // `mouldedButtonStyle` uses for `deadInk` — over `side: kit.border`,
      // which is its disabled border. So the one live way out of an
      // irreversible sale read as greyed out.
      await pumpGrid(tester, cards: {0: _card(_baseDefId, 'a')});
      await tester.tap(find.byKey(const ValueKey('grid-card-0')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('sell-cancel')),
        240,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      final label = find.descendant(
        of: find.byKey(const ValueKey('sell-cancel')),
        matching: find.byType(Text),
      );
      final ink = DefaultTextStyle.of(tester.element(label.first)).style.color;
      final kit = Theme.of(
        tester.element(find.byKey(const ValueKey('sell-cancel'))),
      ).extension<KitTheme>()!;
      expect(
        ink,
        isNot(kit.textMuted),
        reason: 'that is the colour a DISABLED moulded button uses',
      );
      // **AND IT IS RED, because this one is a REFUSAL.** A bare outline is
      // right for a cancel beside an action of equal weight; this one sits next
      // to selling a player, which cannot be undone, and the pair reads better
      // as go/stop than as one button and one hole. Asked for directly.
      expect(ink, Colors.white, reason: 'white on the red face');
      // And the red is painted in the `backgroundBuilder` like every other
      // moulded face: `backgroundColor` colours the layer UNDERNEATH it and
      // fails silently, which is the trap `architecture_test.dart` guards.
      final style = tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('sell-cancel')))
          .style!;
      expect(
        style.backgroundColor?.resolve(const {})?.a,
        0,
        reason: 'a moulded face is painted in the backgroundBuilder, never here',
      );
      expect(style.backgroundBuilder, isNotNull);

      // The sheet's market offer owns a 1Hz countdown, so it has to be shut
      // before the binding checks for pending timers.
      await tester.tap(find.byKey(const ValueKey('sell-cancel')));
      await tester.pumpAndSettle();
      await settleSave(tester);
    });

    testWidgets('and neither button carries a second outline', (tester) async {
      // `side` is drawn by the button's own Material on the FULL button rect,
      // while the moulded face sits 4pt inside it — so a `side` here put a
      // second outline 4pt ABOVE the first, a ridge along the top edge. Both
      // buttons' Materials have to stay bare for the moulded shape to be the
      // only shape on them.
      await pumpGrid(tester, cards: {0: _card(_baseDefId, 'a')});
      await tester.tap(find.byKey(const ValueKey('grid-card-0')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('sell-cancel')),
        240,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      for (final key in ['sell-cancel', 'sell-confirm']) {
        final materials = find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Material),
        );
        expect(materials, findsWidgets, reason: '$key drew no Material at all');
        for (final element in materials.evaluate()) {
          final material = element.widget as Material;
          expect(
            material.color?.a ?? 0,
            0,
            reason: '$key fills behind its own face, burying the edge bar',
          );
          final shape = material.shape;
          if (shape is RoundedRectangleBorder) {
            expect(
              shape.side.style,
              BorderStyle.none,
              reason: '$key draws a second outline off its Material',
            );
          }
        }
      }

      await tester.tap(find.byKey(const ValueKey('sell-cancel')));
      await tester.pumpAndSettle();
      await settleSave(tester);
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

      // **THE SENTENCE IS ABOUT SELLING, and about a player who is THEIRS.**
      // It used to be `event.deadline.blocked_loan_card` — 'A borrowed player
      // is not yours to lend on.' — which is about lending, was written for the
      // Deadline Day board, and was the same sentence a player of OURS out on
      // loan got. `squad.detail.cannot_sell_loan` has shipped in all ten
      // catalogues with no caller in `lib/` the whole time.
      expect(
        find.text(t('squad.detail.cannot_sell_loan', {'matches': '3'})),
        findsOneWidget,
      );
      expect(find.text(t('event.deadline.blocked_loan_card')), findsNothing);
    });

    testWidgets('and one of OURS out on loan is told the other thing', (
      tester,
    ) async {
      // The two directions are not the same rule and were the same sentence.
      // This one is ours — the way out is a recall, so the copy names it.
      await pumpGrid(
        tester,
        cards: {
          0: {
            ..._card(_baseDefId, 'a'),
            'loanedOut': {'toTeam': 'Rovers', 'matchesLeft': 2},
          },
        },
      );
      await tester.tap(find.byKey(const ValueKey('grid-card-0')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('sell-confirm')), findsNothing);
      final blocked = tester.widget<Text>(
        find.byKey(const ValueKey('sell-blocked')),
      );
      expect(
        blocked.data,
        contains('Rovers'),
        reason: 'the club he is AT is the thing the recall needs naming',
      );
      expect(
        blocked.data,
        isNot(t('squad.detail.cannot_sell_loan', {'matches': '0'})),
        reason: 'that is the sentence for a player who is not ours',
      );
      expect(find.text(t('event.deadline.blocked_loan_card')), findsNothing);
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

    testWidgets('and a pair the DIVISION will not allow is not a target', (
      tester,
    ) async {
      // Sunday League caps players at tier 2, so two tier-2s have nowhere to go
      // in it: `attemptMerge` refuses them with `division_locked`. They wore the
      // gold ring and lit up as a drop target anyway — the grid offered a merge
      // and the engine then turned it down.
      final tierTwo = players.firstWhere((p) => p.tier == 2).id;
      final container = await pumpGrid(
        tester,
        cards: {
          0: _card(tierTwo, 'a', variant: _maleVariant),
          1: _card(tierTwo, 'b', variant: _maleVariant),
        },
      );
      expect(mergeTargetsFor(container.read(gameProvider).state, 0), isEmpty);
      // And the ring is off with it.
      expect(container.read(mergeableCellsProvider), isEmpty);
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

    testWidgets('AND ADD PLAYER FLIES IT HOME, like a merge does', (
      tester,
    ) async {
      // **The one path whose flight was never asserted.** `flyingHome` had no
      // caller anywhere: the landing RECTS are covered here, and whether a
      // reveal ever turned one into a journey was not — on either path. The
      // merge path was fine; this one was reported from a handset as the cards
      // zooming away and then appearing in place, which is what a reveal with
      // no flights does on its way out.
      // **`pumpGridAnimated`, and that matters.** The ordinary harness runs
      // under reduce-motion, where a reveal drops the journey BY DESIGN — a
      // test on it would assert the absence of the thing it is about.
      await pumpGridAnimated(tester);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('add-player')));
      await tester.pump();
      // Past the FLIP but not past the hold: settling here would run the
      // reveal's own timer out and dismiss it, and there would be nothing left
      // to watch leave.
      await tester.pump(scoutRevealSkipAfter + const Duration(milliseconds: 32));

      final overlay = find.byType(ScoutRevealOverlay);
      expect(overlay, findsOneWidget, reason: 'no reveal to fly out of');
      await tester.tap(find.byKey(const ValueKey('scout-reveal')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.state<ScoutRevealOverlayState>(overlay).flyingHome,
        1,
        reason: 'it faded out instead of travelling',
      );

      // Hand-pumped out: the grid's merge pulse loops forever, which is the
      // whole reason this harness exists alongside the reduce-motion one.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 32));
      }
      await settleSave(tester);
    });

    testWidgets('EVEN WHEN THE SQUARE IS DOWN THE GRID and the tap is quick', (
      tester,
    ) async {
      // **The case the report is about, and it PASSES — which is the finding.**
      // A signing goes to the first EMPTY square, so on a grid with anything in
      // it the landing has to SCROLL, and the ask for it is fired and not
      // awaited. That looked like the answer: a player who dismisses the moment
      // the card can be tapped beats the scroll, `_capture` finds nothing, and
      // the reveal leaves with no flights — cards fading where they are while
      // the grid fills in behind, which is exactly what was reported.
      //
      // It does not happen here. Dismissed at the earliest frame a tap is
      // allowed, on a grid that has to scroll, the flight is still there. So
      // whatever the handset is doing is not this, and the race is pinned shut
      // either way.
      await pumpGridAnimated(
        tester,
        cards: {
          for (var i = 0; i < 12; i++) i: _card(_baseDefId, 'c$i'),
        },
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('add-player')));
      await tester.pump();
      // The earliest a tap is allowed to dismiss it, and nothing more.
      await tester.pump(scoutRevealSkipAfter + const Duration(milliseconds: 16));

      final overlay = find.byType(ScoutRevealOverlay);
      expect(overlay, findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('scout-reveal')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.state<ScoutRevealOverlayState>(overlay).flyingHome,
        1,
        reason: 'the exit beat the scroll and left with nowhere to go',
      );

      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 32));
      }
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

    testWidgets('AND LENDS IT AGAIN WHEN IT COMES BACK', (tester) async {
      // **The pairing only balanced once, and that is the bug.** `deactivate`
      // hands the resolver back; only `initState` ever handed one out. So the
      // first thing that re-parented the grid — a tab switch, a rebuild that
      // moves it — ran `deactivate` and then `activate`, and from that moment
      // `scoutLandingProvider` was null for the life of the app.
      //
      // `add_player_button.dart` reads that provider. The merge path calls the
      // grid's resolver directly and never touched it. Which is why a signing
      // faded out where it stood while a merge, three lines away in the same
      // overlay, still flew home — reported exactly that way, every time.
      final container = await pumpGrid(tester);
      await tester.pump();
      expect(container.read(scoutLandingProvider), isNotNull);

      // A re-parent: the same grid, moved in the tree. This is what a tab
      // switch does to it, and the `GlobalKey` is what makes it a MOVE rather
      // than a fresh mount — so `initState` does not run again and `activate`
      // does, which is the whole point.
      final key = GlobalKey();
      Future<void> pumpAt({required bool nested}) => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => MaterialApp(
              theme: ref.watch(appThemeProvider),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
              home: Scaffold(
                body: nested
                    ? Center(child: MergeGrid(key: key))
                    : MergeGrid(key: key),
              ),
            ),
          ),
        ),
      );
      await pumpAt(nested: false);
      await tester.pumpAndSettle();
      await pumpAt(nested: true);
      await tester.pumpAndSettle();

      expect(
        container.read(scoutLandingProvider),
        isNotNull,
        reason: 'a signing has had nowhere to fly since the first re-parent',
      );
      await settleSave(tester);
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

  group('the pulse is ONE pulse', () {
    testWidgets('every merge-ready card beats together', (tester) async {
      // Each ring used to own its own controller and start it the moment its
      // card became mergeable, so a grid with several pairs on it pulsed in
      // several different phases — which reads as a fault rather than a hint.
      await pumpGridAnimated(
        tester,
        cards: {
          0: _card(_baseDefId, 'a', variant: _maleVariant),
          1: _card(_baseDefId, 'b', variant: _maleVariant),
          2: _card(_baseDefId, 'c', variant: _maleVariant),
          3: _card(_baseDefId, 'd', variant: _maleVariant),
        },
      );
      await tester.pump(const Duration(milliseconds: 300));

      // `getRect`, not `RenderBox.size`: the ring scales its card with a
      // `Transform`, which does not change the child's LAYOUT size — so the
      // rendered rect is the only thing that carries the phase, and measuring
      // `size` here would have asserted nothing at all.
      final cards = find.byType(PlayerCard);
      final drawn = [
        for (var i = 0; i < 4; i++) tester.getRect(cards.at(i)).height,
      ];
      final laidOut = tester.renderObject<RenderBox>(cards.first).size.height;
      expect(
        drawn.first,
        isNot(moreOrLessEquals(laidOut, epsilon: 0.05)),
        reason: 'mid-pulse, so the scale is on — otherwise this proves nothing',
      );
      expect(
        drawn.map((h) => h.toStringAsFixed(3)).toSet(),
        hasLength(1),
        reason: 'four cards, one phase — got $drawn',
      );
      await settleSave(tester);
    });

    testWidgets('and a card that joins late joins the beat in progress', (
      tester,
    ) async {
      // The case the old code could not do: a controller starting from zero
      // half way through everyone else's cycle.
      final container = await pumpGridAnimated(
        tester,
        cards: {
          0: _card(_baseDefId, 'a', variant: _maleVariant),
          1: _card(_baseDefId, 'b', variant: _maleVariant),
        },
      );
      await tester.pump(const Duration(milliseconds: 600));

      // Two more, arriving mid-cycle.
      container.read(gameProvider).update((s) {
        final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List;
        cells[2] = _card(_baseDefId, 'c', variant: _maleVariant);
        cells[3] = _card(_baseDefId, 'd', variant: _maleVariant);
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      final cards = find.byType(PlayerCard);
      final drawn = [
        for (var i = 0; i < 4; i++) tester.getRect(cards.at(i)).height,
      ];
      expect(
        drawn.map((h) => h.toStringAsFixed(3)).toSet(),
        hasLength(1),
        reason: 'still one phase — got $drawn',
      );
      await settleSave(tester);
    });
  });

  group('a merge is the payoff, not a journey', () {
    testWidgets('the card the player dragged does NOT fly again', (
      tester,
    ) async {
      // A ghost travelling into the target was put in to join the two events. It
      // does — but only if you did not watch it happen, and the only way to reach
      // a merge is to drag one card onto the other. What joins them is the burst.
      final container = await pumpGridAnimated(
        tester,
        cards: {
          0: _card(_baseDefId, 'a', variant: _maleVariant),
          1: _card(_baseDefId, 'b', variant: _maleVariant),
        },
      );
      dropOn(tester, 0, 1);
      await tester.pump();
      expect(find.byKey(const ValueKey('grid-flying-card')), findsNothing);
      // And the celebration is already running on the frame the merge landed.
      expect(
        tester
            .stateList<MergeBurstState>(find.byType(MergeBurst))
            .where((b) => b.isPlaying),
        isNotEmpty,
        reason: 'no waiting for a flight to finish first',
      );
      await tester.pump(mergeBurstDuration);
      await settleSave(tester);
      expect(filledCells(container), 1);
    });

    testWidgets('a SWAP moves the displaced card, not the dragged one', (
      tester,
    ) async {
      // The one the player carried is where they put it. The other was displaced
      // by a move it had no part in, so it has to be seen going.
      await pumpGridAnimated(
        tester,
        cards: {
          0: _card(_baseDefId, 'a', variant: _maleVariant),
          1: _card(_baseDefId, 'b', variant: _femaleVariant),
        },
      );
      final draggedAt = tester.getRect(
        find.byKey(const ValueKey('grid-card-a')),
      );
      final displacedAt = tester.getRect(
        find.byKey(const ValueKey('grid-card-b')),
      );
      dropOn(tester, 0, 1);
      await tester.pump();

      expect(
        tester.getRect(find.byKey(const ValueKey('grid-card-a'))),
        displacedAt,
        reason: 'the dragged card is simply there',
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('grid-card-b'))),
        displacedAt,
        reason:
            'and the displaced one has not jumped — it is still setting off',
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.getRect(find.byKey(const ValueKey('grid-card-b'))),
        draggedAt,
        reason: 'and arrives where the dragged card came from',
      );
      await settleSave(tester);
    });
  });

  group('dragging near an edge', () {
    testWidgets('THE BAND IS INSIDE THE LIST, not the top of the phone', (
      tester,
    ) async {
      // It was measured off the screen's own box, which starts behind the HUD and
      // above the action bar — so a card had to be dragged under the glass and
      // most of the way off the top before the grid moved.
      await pumpGrid(tester, cards: {0: _card(_baseDefId, 'a')});
      final viewport = tester.getRect(find.byKey(const ValueKey('merge-grid')));
      // The list starts well below the top of the screen, which is the whole
      // point: anything measured from zero is measuring the wrong thing.
      expect(
        viewport.top,
        greaterThan(hudClearance),
        reason:
            'the list is not clear of the HUD, so the band cannot be either',
      );
    });

    testWidgets('and the list BOUNCES at each end', (tester) async {
      // A list that stops dead reads as having hit a wall rather than as having
      // reached the bottom. The default is per-platform and Android clamps.
      //
      // **AND `AlwaysScrollable` OUTSIDE IT, which is the half that was
      // missing.** Bouncing physics only give at an end the view will let a
      // drag reach: with the content no taller than the viewport — an early
      // save, or a tall phone — the drag is refused outright and there is
      // nothing to bounce. Reported as the Players tab not having the bounce
      // the other tabs do, which is exactly the case a one-card grid is in.
      await pumpGrid(tester, cards: {0: _card(_baseDefId, 'a')});
      final view = tester.widget<SingleChildScrollView>(
        find.byKey(const ValueKey('merge-grid')),
      );
      expect(view.physics, isA<AlwaysScrollableScrollPhysics>());
      expect(view.physics?.parent, isA<BouncingScrollPhysics>());
    });
  });

  group('the loan stars arriving', () {
    testWidgets('DROP IN ONE AT A TIME, not all on one frame', (tester) async {
      // The tutorial's own set-piece: eight players appearing at once is the
      // save being rewritten, half a second apart it is players walking in.
      final container = await pumpGridAnimated(tester, tutorialDone: false);
      final lent = container.read(gameProvider).update(lendTutorialPlayers);
      expect(lent, greaterThan(2), reason: 'nothing was lent to watch');
      await tester.pump();

      final delays = tester
          .widgetList<LoanArrival>(find.byType(LoanArrival))
          .map((w) => w.delay)
          .whereType<Duration>()
          .toList();
      expect(delays, hasLength(lent));
      expect(
        delays.toSet(),
        hasLength(lent),
        reason: 'a shared delay is not a stagger',
      );
      expect(delays, contains(Duration.zero));
      expect(delays, contains(loanArrivalStagger));
      await tester.pump(loanArrivalWindow(lent));
      await settleSave(tester);
    });

    testWidgets('AND A CARD ALREADY THERE DOES NOT RE-ARRIVE', (tester) async {
      // A save reopened mid-tutorial would otherwise replay the whole loan
      // every time the Players tab was visited.
      final state = createDefaultState();
      (state['tutorial'] as Map<String, dynamic>)['done'] = false;
      lendTutorialPlayers(state);

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
      await tester.pump();
      expect(
        tester
            .widgetList<LoanArrival>(find.byType(LoanArrival))
            .where((w) => w.delay != null),
        isEmpty,
        reason: 'they were already on the grid',
      );
    });
  });

  group('A LOCKED SQUARE IS VISIBLE, NOT OPAQUE', () {
    // Every square used to take `kit.surface` flat, so on the theme that ships
    // — light — the row of locked ones across the foot of the grid was a set of
    // solid near-white tiles, and the loudest thing on the page was the part of
    // it you cannot use. Reported directly.
    testWidgets('the fill, the rim and the padlock are all a wash', (
      tester,
    ) async {
      await pumpGrid(tester);
      final kit = Theme.of(
        tester.element(find.byType(MergeGrid)),
      ).extension<KitTheme>()!;
      final skin = lockedSlotSkin(kit);
      expect(skin.fill.a, lessThan(1));
      expect(skin.border.a, lessThan(1));
      expect(skin.ink.a, lessThan(1));
      // A wash OF THE SURFACE, not a second grey — the backdrop behind the grid
      // is turf or humbug, and any fixed fill that looks quiet on one is wrong
      // on the other.
      expect(skin.fill.withValues(alpha: 1), kit.surface);
    });

    testWidgets('AND THE PADLOCK IS STILL THERE TO SEE', (tester) async {
      // Subtle is not absent: the square has to read as a square that is
      // locked, which is the half of the report the alphas could have lost.
      await pumpGrid(tester);
      const last = Grid.totalCells - 1;
      expect(
        find.byKey(const ValueKey('grid-locked-$last'), skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byIcon(Icons.lock_outline, skipOffstage: false),
        findsWidgets,
      );
    });
  });
}
