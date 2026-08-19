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
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

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

    testWidgets('the trait wheel is on it, priced', (tester) async {
      // `rollTrait`, `applyTrait` and `traitRollCost` were all ported with
      // nothing able to spend a coin on them.
      final container = await pumpSquad(tester);
      await openDetailOfFirst(tester, container);

      await tester.ensureVisible(find.byKey(const ValueKey('detail-trait')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('detail-trait-roll')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-trait-label')), findsOneWidget);
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
}
