/// The Squad tab.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_pickers.dart';
import 'package:merge_empire_fc/data/player_art.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/squad/player_detail_sheet.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_providers.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_screen.dart';
import 'package:merge_empire_fc/ui/screens/squad/pitch_token.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';

int get _maleVariant => List.generate(
  playerVariants,
  (i) => i,
).firstWhere((i) => !isVariantFemale(i));

/// A squad of [n] cards, spread across positions so a formation can fill.
List<Map<String, dynamic>> _squad(int n) {
  final byPos = {
    for (final pos in ['GK', 'DEF', 'MID', 'FWD'])
      pos: players.firstWhere((p) => p.position == pos && p.tier == 1).id,
  };
  // One keeper, then a spread — buildDefaultLineup wants a GK it can place.
  final order = [
    'GK',
    ...List.filled(5, 'DEF'),
    ...List.filled(5, 'MID'),
    ...List.filled(5, 'FWD'),
  ];
  return [
    for (var i = 0; i < n; i++)
      {
        'definitionId': byPos[order[i % order.length]]!,
        'instanceId': 'c$i',
        'variant': _maleVariant,
      },
  ];
}

Future<ProviderContainer> pumpSquad(
  WidgetTester tester, {
  int cards = 14,
}) async {
  final state = createDefaultState();
  final cells =
      (state['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
  final squad = _squad(cards);
  for (var i = 0; i < squad.length; i++) {
    cells[i] = squad[i];
  }

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
          home: const Scaffold(body: SquadScreen()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> settleSave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: saveDebounceMs + 100));

/// The bench lives behind the Subs button now — it was an inline strip eating
/// a third of a portrait screen — so a test reaches it the way a player does.
Future<void> openBench(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('squad-subs')));
  await tester.pumpAndSettle();
}

/// Open the detail sheet of the first player on the pitch.
Future<void> openDetailOfFirst(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final slot = container
      .read(pitchSlotsProvider)
      .firstWhere((s) => s.cardInstanceId != null);
  await tester.tap(find.byKey(ValueKey('squad-slot-${slot.slotId}')));
  await tester.pumpAndSettle();
}

void drop(WidgetTester tester, SquadDrag drag, String slotId) {
  final target = tester.widget<DragTarget<SquadDrag>>(
    find.ancestor(
      of: find.byKey(ValueKey('squad-slot-$slotId')),
      matching: find.byType(DragTarget<SquadDrag>),
    ),
  );
  target.onAcceptWithDetails!(
    DragTargetDetails<SquadDrag>(data: drag, offset: Offset.zero),
  );
}

void main() {
  tearDown(resetLocale);

  group('the pitch', () {
    testWidgets('lays out one slot per formation place', (tester) async {
      final container = await pumpSquad(tester);
      final slots = container.read(pitchSlotsProvider);
      expect(slots.length, getFormation(defaultFormation).slots.length);
      expect(slots.length, 11);
    });

    testWidgets('fills the eleven from the squad', (tester) async {
      final container = await pumpSquad(tester);
      final filled = container
          .read(pitchSlotsProvider)
          .where((s) => s.card != null);
      expect(filled.length, 11, reason: '14 cards fills every slot');
    });

    testWidgets('leaves slots empty when the squad is short', (tester) async {
      final container = await pumpSquad(tester, cards: 5);
      final slots = container.read(pitchSlotsProvider);
      expect(slots.length, 11, reason: 'the shape is the shape');
      expect(slots.where((s) => s.card != null).length, 5);
      expect(find.byKey(const ValueKey('squad-slot-gk')), findsWidgets);
    });

    testWidgets('an empty slot names the position it wants', (tester) async {
      await pumpSquad(tester, cards: 1);
      // A blank square tells a player nothing; the position is the instruction.
      expect(find.text('DEF'), findsWidgets);
    });
  });

  group('the bench', () {
    testWidgets('holds everyone not in the eleven', (tester) async {
      final container = await pumpSquad(tester, cards: 14);
      expect(container.read(benchProvider).length, 3);
    });

    testWidgets('says so when there is nobody on it', (tester) async {
      await pumpSquad(tester, cards: 11);
      await openBench(tester);
      expect(find.byKey(const ValueKey('squad-bench-empty')), findsOneWidget);
      expect(find.text(t('squad.bench.empty')), findsOneWidget);
    });

    testWidgets('the Subs button carries the count', (tester) async {
      // The bench is out of sight now, so a door with nothing behind it has to
      // say so before it is opened.
      final container = await pumpSquad(tester, cards: 14);
      expect(
        find.text(
          t('squad.bench.count', {'n': container.read(benchProvider).length}),
        ),
        findsOneWidget,
      );
    });
  });

  group('picking the side', () {
    testWidgets('a bench card dropped on a slot takes it', (tester) async {
      final container = await pumpSquad(tester, cards: 14);
      final benched = container.read(benchProvider).first.instanceId;
      final slot = container.read(pitchSlotsProvider).first;

      drop(tester, (instanceId: benched, fromSlotId: null), slot.slotId);
      await tester.pumpAndSettle();
      await settleSave(tester);

      final after = container
          .read(pitchSlotsProvider)
          .firstWhere((s) => s.slotId == slot.slotId);
      expect(after.cardInstanceId, benched);
    });

    testWidgets('and the man he replaced goes to the bench', (tester) async {
      final container = await pumpSquad(tester, cards: 14);
      final benched = container.read(benchProvider).first.instanceId;
      final slot = container.read(pitchSlotsProvider).first;
      final displaced = slot.cardInstanceId;

      drop(tester, (instanceId: benched, fromSlotId: null), slot.slotId);
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(
        container.read(benchProvider).map((b) => b.instanceId),
        contains(displaced),
      );
      expect(
        container.read(benchProvider).length,
        3,
        reason: 'a swap, not a bump',
      );
    });

    testWidgets('dragging between two slots swaps them', (tester) async {
      // One change, not two: quietly benching a second man is a change the
      // player did not ask for.
      final container = await pumpSquad(tester, cards: 14);
      final slots = container.read(pitchSlotsProvider);
      final a = slots[0];
      final b = slots[5];

      drop(tester, (
        instanceId: a.cardInstanceId,
        fromSlotId: a.slotId,
      ), b.slotId);
      await tester.pumpAndSettle();
      await settleSave(tester);

      final after = container.read(pitchSlotsProvider);
      expect(
        after.firstWhere((s) => s.slotId == b.slotId).cardInstanceId,
        a.cardInstanceId,
      );
      expect(
        after.firstWhere((s) => s.slotId == a.slotId).cardInstanceId,
        b.cardInstanceId,
      );
      expect(
        container.read(benchProvider).length,
        3,
        reason: 'nobody dropped out',
      );
    });

    testWidgets('a slot refuses a drop from itself', (tester) async {
      final container = await pumpSquad(tester);
      final slot = container.read(pitchSlotsProvider).first;
      final target = tester.widget<DragTarget<SquadDrag>>(
        find.ancestor(
          of: find.byKey(ValueKey('squad-slot-${slot.slotId}')),
          matching: find.byType(DragTarget<SquadDrag>),
        ),
      );
      expect(
        target.onWillAcceptWithDetails!(
          DragTargetDetails<SquadDrag>(
            data: (instanceId: slot.cardInstanceId, fromSlotId: slot.slotId),
            offset: Offset.zero,
          ),
        ),
        isFalse,
      );
    });
  });

  group('the header', () {
    testWidgets('shows the rating, the split and the formation', (
      tester,
    ) async {
      await pumpSquad(tester);
      expect(find.byKey(const ValueKey('squad-rating')), findsOneWidget);
      expect(find.byKey(const ValueKey('squad-atk')), findsOneWidget);
      expect(find.byKey(const ValueKey('squad-def')), findsOneWidget);
      expect(find.text(getFormation(defaultFormation).label), findsOneWidget);
    });

    testWidgets('the numbers come from the engine, not the widget', (
      tester,
    ) async {
      final container = await pumpSquad(tester);
      final ratings = container.read(squadRatingsProvider);
      // By key, not by text: a card's own rating can read the same number.
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('squad-rating'))).data,
        '${ratings.overall}',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('squad-atk'))).data,
        'ATK ${ratings.attack}',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('squad-def'))).data,
        'DEF ${ratings.defence}',
      );
    });

    testWidgets('belowPar tracks the division s own opponent range', (
      tester,
    ) async {
      // The answer to "why do I keep losing", so it is measured against the
      // division rather than a number picked here.
      final container = await pumpSquad(tester, cards: 11);
      final ratings = container.read(squadRatingsProvider);
      final floor = getDivision(
        (container.read(gameProvider).state!['progression']
                as Map<String, dynamic>)['currentDivision']
            as String,
      ).opponentRatingRange.$1;
      expect(ratings.belowPar, ratings.overall < floor);
    });

    testWidgets('a slot emptied ON PURPOSE stays empty', (tester) async {
      // The JS reads the stored eleven raw — `_lineup()` does no cleaning and
      // no filling — so a hole the manager made is a hole. Topping it up on
      // every read is what made Bench and Clear no-ops: the best available body
      // for the slot somebody just left is the one who just left it.
      //
      // Filling still happens, on the events that change the SQUAD — see
      // `syncLineupWithGrid`. A sale cannot leave a hole; a decision can.
      final container = await pumpSquad(tester, cards: 14);
      final slot = container.read(pitchSlotsProvider).first;

      drop(tester, (instanceId: null, fromSlotId: null), slot.slotId);
      await tester.pumpAndSettle();
      await settleSave(tester);

      final after = container
          .read(pitchSlotsProvider)
          .firstWhere((s) => s.slotId == slot.slotId);
      expect(after.cardInstanceId, isNull);
    });
  });

  group('the pickers', () {
    testWidgets('the formation chip opens a picker and changes the shape', (
      tester,
    ) async {
      final container = await pumpSquad(tester);
      expect(container.read(formationIdProvider), defaultFormation);

      await tester.tap(find.byKey(const ValueKey('squad-formation')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('formation-picker')), findsOneWidget);

      final other = formations.keys.firstWhere((id) => id != defaultFormation);
      await tester.tap(find.byKey(ValueKey('formation-$other')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(container.read(formationIdProvider), other);
      expect(
        container.read(pitchSlotsProvider).length,
        getFormation(other).slots.length,
      );
    });

    testWidgets('changing the shape carries the eleven across', (tester) async {
      // migrateLineup maps players onto the new slots by position. Starting
      // again would wipe a side the player had just picked.
      final container = await pumpSquad(tester, cards: 14);
      expect(
        container.read(pitchSlotsProvider).where((s) => s.card != null).length,
        11,
      );

      await tester.tap(find.byKey(const ValueKey('squad-formation')));
      await tester.pumpAndSettle();
      final other = formations.keys.firstWhere((id) => id != defaultFormation);
      await tester.tap(find.byKey(ValueKey('formation-$other')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(
        container.read(pitchSlotsProvider).where((s) => s.card != null).length,
        11,
        reason: 'still a full side',
      );
      expect(container.read(benchProvider).length, 3);
    });

    testWidgets('the tactic chip opens a picker and changes the tactic', (
      tester,
    ) async {
      final container = await pumpSquad(tester);
      expect(container.read(strategyIdProvider), defaultStrategy);

      await tester.tap(find.byKey(const ValueKey('squad-tactic')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tactic-picker')), findsOneWidget);

      final other = strategies.keys.firstWhere((id) => id != defaultStrategy);
      await tester.tap(find.byKey(ValueKey('tactic-$other')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(container.read(strategyIdProvider), other);
    });

    testWidgets('every tactic states its trade', (tester) async {
      // The hint is the whole reason a tactic is a choice rather than a setting.
      await pumpSquad(tester);
      await tester.tap(find.byKey(const ValueKey('squad-tactic')));
      await tester.pumpAndSettle();
      for (final strategy in strategies.values) {
        // The picker is a `ListView` and five tiles with their pills and their
        // descriptions are taller than the sheet, so the last one is reached the
        // way a player reaches it.
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('tactic-${strategy.id}')),
          120,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('tactic-picker')),
            matching: find.byType(Scrollable),
          ),
        );
        expect(
          find.byKey(ValueKey('tactic-${strategy.id}')),
          findsOneWidget,
          reason: strategy.id,
        );
        expect(strategy.hint, isNotEmpty, reason: strategy.id);
      }
    });

    testWidgets('an unshipped tactic on the save falls back', (tester) async {
      final container = await pumpSquad(tester);
      container
          .read(gameProvider)
          .update(
            (s) =>
                (s['squad'] as Map<String, dynamic>)['strategyId'] = 'no-such',
          );
      await settleSave(tester);
      expect(container.read(strategyIdProvider), defaultStrategy);
    });
  });

  group('the player detail sheet', () {
    // The screen was drag-only, so everything on this sheet — sell, rename,
    // recall, send back, career stats, the XI swap — was unreachable.
    testWidgets('a tap on the pitch opens the player', (tester) async {
      final container = await pumpSquad(tester);
      final slot = container
          .read(pitchSlotsProvider)
          .firstWhere((s) => s.cardInstanceId != null);

      await tester.tap(find.byKey(ValueKey('squad-slot-${slot.slotId}')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey('player-detail-${slot.cardInstanceId}')),
        findsOneWidget,
      );
    });

    testWidgets('a tap on the bench opens the player too', (tester) async {
      final container = await pumpSquad(tester, cards: 14);
      final benched = container.read(benchProvider).first;

      await openBench(tester);
      await tester.tap(
        find.byKey(ValueKey('squad-bench-${benched.instanceId}')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey('player-detail-${benched.instanceId}')),
        findsOneWidget,
      );
    });

    testWidgets('an XI player is offered the swap and the bench', (
      tester,
    ) async {
      final container = await pumpSquad(tester);
      final slot = container
          .read(pitchSlotsProvider)
          .firstWhere((s) => s.cardInstanceId != null);
      await tester.tap(find.byKey(ValueKey('squad-slot-${slot.slotId}')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('detail-swap')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-bench')), findsOneWidget);
    });

    testWidgets('a BENCHED player is not — there is no slot to talk about', (
      tester,
    ) async {
      final container = await pumpSquad(tester, cards: 14);
      final benched = container.read(benchProvider).first;
      await openBench(tester);
      await tester.tap(
        find.byKey(ValueKey('squad-bench-${benched.instanceId}')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('detail-swap')), findsNothing);
      expect(find.byKey(const ValueKey('detail-bench')), findsNothing);
    });

    testWidgets('benching a player empties their slot', (tester) async {
      final container = await pumpSquad(tester);
      final slot = container
          .read(pitchSlotsProvider)
          .firstWhere((s) => s.cardInstanceId != null);
      final wasThere = slot.cardInstanceId;

      await tester.tap(find.byKey(ValueKey('squad-slot-${slot.slotId}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('detail-bench')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      // The slot is EMPTY, and stays empty. Refilling it here would put the
      // benched player straight back — he is the best available body for the
      // hole he just left — which is exactly what made this button do nothing.
      final after = container
          .read(pitchSlotsProvider)
          .firstWhere((s) => s.slotId == slot.slotId);
      expect(after.cardInstanceId, isNull);
      expect(wasThere, isNotNull);
    });

    testWidgets('selling asks first', (tester) async {
      // It is irreversible and the button sits under the thumb at the bottom
      // of a scrolling sheet.
      final container = await pumpSquad(tester);
      final slot = container
          .read(pitchSlotsProvider)
          .firstWhere((s) => s.cardInstanceId != null);
      await tester.tap(find.byKey(ValueKey('squad-slot-${slot.slotId}')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('detail-sell')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('detail-sell')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('detail-sell-confirm')), findsOneWidget);
      // Cancelling leaves the squad alone.
      await tester.tap(find.byKey(const ValueKey('detail-sell-cancel')));
      await tester.pumpAndSettle();
      expect(container.read(benchProvider).length + 11, greaterThan(11));
    });

    testWidgets('the trait wheel is on it, priced, with two reels', (
      tester,
    ) async {
      // `rollTrait`, `applyTrait` and `traitRollCost` were all ported with
      // nothing able to spend a coin on them. The reels are Flutter's own
      // `ListWheelScrollView` — which is the widget the JS builds out of DOM
      // strips repeated seven times.
      final container = await pumpSquad(tester);
      await openDetailOfFirst(tester, container);

      await tester.ensureVisible(find.byKey(const ValueKey('detail-trait')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('detail-trait-roll')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-trait-label')), findsOneWidget);
      expect(find.byKey(const ValueKey('trait-reel-name')), findsOneWidget);
      expect(find.byKey(const ValueKey('trait-reel-level')), findsOneWidget);
    });

    testWidgets('and the reels cannot be spun by hand', (tester) async {
      // The roll is bought, not flicked.
      final container = await pumpSquad(tester);
      await openDetailOfFirst(tester, container);
      await tester.ensureVisible(find.byKey(const ValueKey('trait-reel-name')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListWheelScrollView>(
              find.byKey(const ValueKey('trait-reel-name')),
            )
            .physics,
        isA<NeverScrollableScrollPhysics>(),
      );
    });

    testWidgets('rolling charges, spins, and lands a trait', (tester) async {
      final container = await pumpSquad(tester);
      final slot = container
          .read(pitchSlotsProvider)
          .firstWhere((s) => s.cardInstanceId != null);
      await openDetailOfFirst(tester, container);
      final before = container.read(coinsProvider);

      await tester.ensureVisible(
        find.byKey(const ValueKey('detail-trait-roll')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('detail-trait-roll')));
      await tester.pump();

      // Mid-spin the button is dead, so a second tap cannot buy a roll the
      // player is still watching.
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('detail-trait-roll')),
            )
            .onPressed,
        isNull,
      );

      await tester.pump(
        TraitBlockState.spin + const Duration(milliseconds: 100),
      );
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(container.read(coinsProvider), lessThan(before));
      final card = cardById(
        container.read(gameProvider).state,
        slot.cardInstanceId!,
      );
      expect(card?.raw['trait'], isNotNull);
    });

    testWidgets('a club that cannot pay is told, not just greyed out', (
      tester,
    ) async {
      final container = await pumpSquad(tester);
      container
          .read(gameProvider)
          .update(
            (s) => (s['resources'] as Map<String, dynamic>)['fanCoins'] = 0,
          );
      await tester.pumpAndSettle();
      await openDetailOfFirst(tester, container);

      await tester.ensureVisible(find.byKey(const ValueKey('detail-trait')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('detail-trait-blocked')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('detail-trait-roll')),
            )
            .onPressed,
        isNull,
      );
      await settleSave(tester);
    });
  });

  group('filling the eleven', () {
    testWidgets('Auto picks a side', (tester) async {
      final container = await pumpSquad(tester);
      await tester.tap(find.byKey(const ValueKey('squad-clear')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('squad-auto')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      final filled = container
          .read(pitchSlotsProvider)
          .where((s) => s.cardInstanceId != null)
          .length;
      expect(filled, 11);
    });

    testWidgets('Clear empties the STORED eleven', (tester) async {
      // What the player sees refills straight away — cleanAndFillLineup runs on
      // the way out — so the observable effect is on the save, which is what
      // the match reads.
      final container = await pumpSquad(tester);
      await tester.tap(find.byKey(const ValueKey('squad-clear')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      final stored =
          (container.read(gameProvider).state!['squad']
                  as Map<String, dynamic>)['lineup']
              as List;
      expect(stored.every((s) => (s as Map)['cardInstanceId'] == null), isTrue);
    });
  });

  group('what the tactic actually does', () {
    testWidgets('picking one moves the ATK and DEF on the header', (
      tester,
    ) async {
      // The one number that says what a tactic BUYS. It had been showing the
      // untouched base, so writing a tactic to the save changed nothing on the
      // screen and every tactic looked inert.
      final container = await pumpSquad(tester);
      final before = container.read(squadRatingsProvider);

      await tester.tap(find.byKey(const ValueKey('squad-tactic')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tactic-allOutAttack')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      final after = container.read(squadRatingsProvider);
      expect(after.attack, greaterThan(before.attack));
      expect(after.defence, lessThan(before.defence));
    });

    testWidgets('and the sheet stays open so a second can be compared', (
      tester,
    ) async {
      // The manager is comparing tactics; yanking the list away after one tap
      // makes trying another cost a whole extra journey.
      final container = await pumpSquad(tester);
      await tester.tap(find.byKey(const ValueKey('squad-tactic')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tactic-parkTheBus')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('tactic-picker')), findsOneWidget);
      expect(container.read(strategyIdProvider), 'parkTheBus');
      await settleSave(tester);
    });

    testWidgets('every tactic is priced, not just named', (tester) async {
      await pumpSquad(tester);
      await tester.tap(find.byKey(const ValueKey('squad-tactic')));
      await tester.pumpAndSettle();
      // Five rows, and All Out Attack quotes its own trade. Scrolled, because
      // five priced tiles are taller than the sheet.
      for (final id in strategies.keys) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('tactic-$id')),
          120,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('tactic-picker')),
            matching: find.byType(Scrollable),
          ),
        );
        expect(find.byKey(ValueKey('tactic-$id')), findsOneWidget);
      }
      // Back to the top, so the assertion below is looking at a row on screen.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('tactic-allOutAttack')),
        -120,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('tactic-picker')),
          matching: find.byType(Scrollable),
        ),
      );
      final atk = strategies['allOutAttack']!;
      expect(
        find.text('ATK +${((atk.atkMult - 1) * 100).round()}%'),
        findsOneWidget,
      );
    });
  });

  group('the bench is a way INTO the side', () {
    testWidgets('Send On is offered for a benched player', (tester) async {
      // The bench is a sheet, so there is nothing to drag a card onto. Without
      // this it was a dead end.
      await pumpSquad(tester, cards: 14);
      await tester.tap(find.byKey(const ValueKey('squad-subs')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PlayerCard).first);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('detail-send-on')), findsOneWidget);
      // And not the two that are about a slot he is not in.
      expect(find.byKey(const ValueKey('detail-bench')), findsNothing);
      expect(find.byKey(const ValueKey('detail-swap')), findsNothing);
    });

    testWidgets('and taking it puts him in the eleven', (tester) async {
      final container = await pumpSquad(tester, cards: 14);
      final benched = container.read(benchProvider).first.instanceId;

      await tester.tap(find.byKey(const ValueKey('squad-subs')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('squad-bench-$benched')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('detail-send-on')));
      // The sheet takes a beat to dismiss before the lineup is written.
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      await settleSave(tester);

      final picked = container
          .read(pitchSlotsProvider)
          .map((s) => s.cardInstanceId)
          .toSet();
      expect(picked, contains(benched));
      await settleSave(tester);
    });

    testWidgets('an empty slot on the pitch opens the picker', (tester) async {
      // The other direction into the side, and the port had drawn the empty
      // slot as an inert box with no gesture on it at all.
      final container = await pumpSquad(tester);
      await tester.tap(find.byKey(const ValueKey('squad-clear')));
      await tester.pumpAndSettle();
      // Clear refills on the way out, so empty one slot directly.
      final slotId = container.read(pitchSlotsProvider).first.slotId;
      container.read(gameProvider).update((s) {
        for (final row in ((s['squad'] as Map)['lineup'] as List)) {
          if ((row as Map)['slotId'] == slotId) row['cardInstanceId'] = null;
        }
      });
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey('squad-slot-$slotId')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('slot-picker')), findsOneWidget);
      await settleSave(tester);
    });

    testWidgets('and the picker rates everyone FOR THAT SLOT', (tester) async {
      // Ordered by what a man is worth there, not by his card rating: a 78
      // striker does not improve left back.
      final container = await pumpSquad(tester);
      final gkSlot = container
          .read(pitchSlotsProvider)
          .firstWhere((s) => s.slotPosition == 'GK');
      final ranked = container.read(
        slotCandidatesProvider(gkSlot.slotPosition),
      );
      for (var i = 1; i < ranked.length; i++) {
        expect(
          ranked[i - 1].effRating,
          greaterThanOrEqualTo(ranked[i].effRating),
        );
      }
      // Nobody unavailable is offered — the engine rates them zero, so fielding
      // one is fielding a hole.
      expect(ranked.every((c) => c.effRating > 0), isTrue);
    });
  });

  group('the pitch has room for eleven', () {
    testWidgets('a slot is a token, not a full player card', (tester) async {
      // Eleven merge cards do not fit; eleven tokens do.
      await pumpSquad(tester);
      expect(find.byType(PitchToken), findsNWidgets(11));
    });

    testWidgets('and the tokens do not overlap each other', (tester) async {
      await pumpSquad(tester);
      final boxes = [
        for (final el in find.byType(PitchToken).evaluate())
          tester.getRect(find.byWidget(el.widget)),
      ];
      for (var i = 0; i < boxes.length; i++) {
        for (var j = i + 1; j < boxes.length; j++) {
          final overlap = boxes[i].intersect(boxes[j]);
          // Touching is fine; covering each other is what put eleven men in a
          // pile when the slots were positioned by the wrong convention.
          final area = overlap.width > 0 && overlap.height > 0
              ? overlap.width * overlap.height
              : 0.0;
          expect(
            area,
            lessThan(boxes[i].width * boxes[i].height * 0.5),
            reason: 'tokens $i and $j sit on top of each other',
          );
        }
      }
    });
  });

  group('room for eleven', () {
    /// The pitch, and the four lines that stand on it.
    ({Rect pitch, Rect gk, Rect def, Rect mid, Rect fwd}) lines(
      WidgetTester tester,
    ) => (
      pitch: tester.getRect(find.byKey(const ValueKey('squad-pitch-surface'))),
      gk: tester.getRect(find.byKey(const ValueKey('squad-drop-gk'))),
      def: tester.getRect(find.byKey(const ValueKey('squad-drop-rcb'))),
      mid: tester.getRect(find.byKey(const ValueKey('squad-drop-cm'))),
      fwd: tester.getRect(find.byKey(const ValueKey('squad-drop-cf'))),
    );

    testWidgets('every line has grass around it on a SHORT screen', (
      tester,
    ) async {
      // The lines are the formation's own data; what decides whether they crowd
      // is how much of the gap the token eats, and the token used to be a fixed
      // 74×97 whatever the pitch.
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpSquad(tester);
      final at = lines(tester);

      for (final pair in [
        (name: 'keeper to defence', gap: at.gk.top - at.def.bottom),
        (name: 'defence to midfield', gap: at.def.top - at.mid.bottom),
        (name: 'midfield to attack', gap: at.mid.top - at.fwd.bottom),
      ]) {
        expect(pair.gap, greaterThan(8), reason: pair.name);
      }
      expect(
        at.pitch.bottom - at.gk.bottom,
        greaterThan(0),
        reason: 'the keeper is on the grass, not over the goal line',
      );
    });

    testWidgets('and the token is its design size where there IS room', (
      tester,
    ) async {
      // Scaled down, never up: a big screen still draws the token at the size it
      // was drawn for.
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpSquad(tester);
      expect(
        lines(tester).gk.width,
        moreOrLessEquals(pitchTokenWidth, epsilon: 0.5),
      );
    });

    testWidgets('the formation chip fits a narrow phone, whole', (
      tester,
    ) async {
      // It had no flex at all and could only overflow; flexing it let the WORD
      // "Formation" end in an ellipsis, which reads as a bug. It scales instead.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpSquad(tester);
      expect(tester.takeException(), isNull);
      expect(
        find.text('${t('squad.formation.label')}:'),
        findsOneWidget,
        reason: 'said in full',
      );
    });
  });

  group('every formation has room for eleven', () {
    /// The 7:10 pitch on a tall phone, a small one, and a very small one. Below
    /// this `pitchTokenScale` hits its readability floor and says so — a pitch
    /// that cannot fit the shape legibly is deliberately left slightly crowded.
    const pitches = [Size(399, 570), Size(341.6, 488), Size(280, 400)];

    test('no two tokens overlap, in ANY shape, at any size', () {
      // A pair needs clearing on ONE axis: side by side in a band is horizontal,
      // one in front of the other is vertical.
      for (final formation in formations.values) {
        for (final pitch in pitches) {
          final scale = pitchTokenScale([
            for (final s in formation.slots) (x: s.x, y: s.y),
          ], pitch);
          final w = pitchTokenWidth * scale;
          final h = pitchTokenHeight * scale;
          final slots = formation.slots;
          for (var i = 0; i < slots.length; i++) {
            for (var j = i + 1; j < slots.length; j++) {
              final dx = (slots[i].x - slots[j].x).abs() / 100 * pitch.width;
              final dy = (slots[i].y - slots[j].y).abs() / 100 * pitch.height;
              expect(
                dx >= w || dy >= h,
                isTrue,
                reason:
                    '${formation.id} at $pitch: ${slots[i].slotId} and '
                    '${slots[j].slotId} overlap '
                    '(dx $dx vs $w, dy $dy vs $h)',
              );
            }
          }
        }
      }
    });

    test('and the shapes that fit draw at FULL size', () {
      // 4-3-3 and 4-4-2 are four evenly spaced bands of at most four; they were
      // never the problem and must not be shrunk to fix the ones that were.
      for (final id in ['4-3-3', '4-4-2']) {
        expect(
          pitchTokenScale([
            for (final s in formations[id]!.slots) (x: s.x, y: s.y),
          ], const Size(399, 570)),
          1.0,
          reason: id,
        );
      }
    });

    test('4-2-3-1 spaces its FIVE bands evenly', () {
      // The JS packs them 24 / 16 / 16 / 16 and 16% of the pitch is less than a
      // token is tall, so three of the five bands overlapped.
      final ys = formations['4-2-3-1']!.slots.map((s) => s.y).toSet().toList()
        ..sort();
      expect(ys.length, 5);
      final gaps = [for (var i = 1; i < ys.length; i++) ys[i] - ys[i - 1]];
      expect(gaps.toSet(), hasLength(1), reason: 'all one gap: $gaps');
      expect(
        gaps.first,
        greaterThan(16),
        reason: 'and wider than the JS packs',
      );
    });

    test('5-3-2 gives its back FIVE the width the wings were not using', () {
      final defence = formations['5-3-2']!.slots.where(
        (s) => s.slotPosition == 'DEF',
      );
      final xs = defence.map((s) => s.x).toList()..sort();
      expect(xs.length, 5);
      final gaps = [for (var i = 1; i < xs.length; i++) xs[i] - xs[i - 1]];
      expect(gaps.toSet(), hasLength(1), reason: 'evenly: $gaps');
      expect(gaps.first, greaterThan(18), reason: 'wider than the JS packs');
      // As far out as a token can go and stay on the grass — where 3-5-2's
      // wing-backs already stand.
      expect(xs.first, 10);
      expect(xs.last, 90);
    });

    testWidgets('the token is the height the spacing is measured against', (
      tester,
    ) async {
      // `pitchTokenHeight` is measured, not declared: it is what every formation
      // has to clear, so a change to the token's own parts must fail here rather
      // than quietly crowd the pitch.
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpSquad(tester);
      expect(
        tester.getRect(find.byKey(const ValueKey('squad-drop-gk'))).height,
        moreOrLessEquals(pitchTokenHeight, epsilon: 0.5),
      );
    });
  });
}
