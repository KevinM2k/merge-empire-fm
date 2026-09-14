/// The trait box: two slots, one reel, and the MATCH slot behind a gem.
///
/// The second slot spins THE SAME reel the first does — the machine was lifted
/// out rather than copied — and tapping a tile is what decides which pool the
/// reel under it holds.
///
/// Harness borrowed from `squad_screen_test.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/match_traits.dart' show matchTraitList;
import 'package:merge_empire_fc/engine/match_trait_engine.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/screens/squad/trait_reel.dart';
import 'package:merge_empire_fc/ui/screens/squad/traits_block.dart';

import 'squad_screen_test.dart';

Map<String, dynamic> _cell(Map<String, dynamic> state, String id) =>
    ((state['grid'] as Map<String, dynamic>)['cells'] as List)
        .whereType<Map<String, dynamic>>()
        .firstWhere((c) => c['instanceId'] == id);

String _idOf(WidgetTester tester) =>
    tester.widget<TraitBlock>(find.byType(TraitBlock)).instanceId;

void main() {
  group('THE SECOND SLOT', () {
    testWidgets('IS LOCKED UNTIL A GEM OPENS IT, through the shop\'s own confirm', (
      tester,
    ) async {
      final container = await pumpSquad(
        tester,
        mutate: (s) => (s['resources'] as Map<String, dynamic>)['gems'] = 3,
      );
      await openDetailOfFirst(tester, container);
      await scrollSheetTo(tester, 'detail-trait');

      // Locked: the reel under the box is the PLAYER one until MATCH is picked.
      expect(find.byKey(const ValueKey('detail-trait-slot-match')), findsOneWidget);
      expect(find.byKey(const ValueKey('matchtrait-reel-name')), findsNothing);
      expect(find.byKey(const ValueKey('trait-reel-name')), findsOneWidget);
      expect(find.byKey(const ValueKey('matchslot-unlock')), findsNothing);

      // Picked: the pane is the match slot's, and its button is the gem.
      await tester.tap(find.byKey(const ValueKey('detail-trait-slot-match')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('matchtrait-reel-name')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-trait-roll')), findsNothing);
      await scrollSheetTo(tester, 'matchslot-unlock');
      await tester.tap(find.byKey(const ValueKey('matchslot-unlock')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('spend-confirm-matchslot')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('spend-confirm-yes-matchslot')));
      await tester.pumpAndSettle();

      final state = container.read(gameProvider).state!;
      expect((state['resources'] as Map)['gems'], 2);
      expect(_cell(state, _idOf(tester))['matchSlot'], isTrue);
      // Open, and now the lit slot: the reel swapped to the match pool.
      expect(
        tester.state<TraitBlockState>(find.byType(TraitBlock)).slot,
        TraitSlot.match,
      );
      expect(find.byKey(const ValueKey('matchtrait-reel-name')), findsOneWidget);
      expect(find.byKey(const ValueKey('trait-reel-name')), findsNothing);
      expect(find.byKey(const ValueKey('detail-trait-roll')), findsOneWidget);
      await settleSave(tester);
    });

    testWidgets('and without a gem it stays shut and takes nothing', (
      tester,
    ) async {
      final container = await pumpSquad(
        tester,
        mutate: (s) => (s['resources'] as Map<String, dynamic>)['gems'] = 0,
      );
      await openDetailOfFirst(tester, container);
      await scrollSheetTo(tester, 'detail-trait');

      await tester.tap(find.byKey(const ValueKey('detail-trait-slot-match')));
      await tester.pumpAndSettle();
      await scrollSheetTo(tester, 'matchslot-unlock');
      await tester.tap(find.byKey(const ValueKey('matchslot-unlock')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('spend-confirm-yes-matchslot')));
      await tester.pumpAndSettle();
      // Short of gems the flow opens the gem shelf and buys nothing.
      final state = container.read(gameProvider).state!;
      expect((state['resources'] as Map)['gems'], 0);
      expect(_cell(state, _idOf(tester))['matchSlot'], isNull);
    });

    testWidgets('AN OPEN SLOT SPINS THE SAME REEL AND WRITES THE ROLL', (
      tester,
    ) async {
      final container = await pumpSquad(
        tester,
        mutate: (s) {
          (s['resources'] as Map<String, dynamic>)['fanCoins'] = 999999;
          for (final c in (s['grid'] as Map<String, dynamic>)['cells'] as List) {
            if (c is Map<String, dynamic>) c['matchSlot'] = true;
          }
        },
      );
      await openDetailOfFirst(tester, container);
      await scrollSheetTo(tester, 'detail-trait-roll');

      // One machine on the sheet, on the PLAYER pool until the tile is tapped.
      expect(find.byType(TraitReel), findsOneWidget);
      expect(find.byKey(const ValueKey('trait-reel-name')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('detail-trait-slot-match')));
      await tester.pumpAndSettle();
      expect(find.byType(TraitReel), findsOneWidget);
      expect(find.byKey(const ValueKey('matchtrait-reel-name')), findsOneWidget);
      expect(find.byKey(const ValueKey('matchtrait-reel-level')), findsOneWidget);

      final id = _idOf(tester);
      final before = (container.read(gameProvider).state!['resources'] as Map)['fanCoins'] as num;

      await tester.tap(find.byKey(const ValueKey('detail-trait-roll')));
      await tester.pump();
      await tester.pump(
        TraitReelState.spin + TraitReelState.flash + const Duration(milliseconds: 800),
      );
      await tester.pumpAndSettle();

      final state = container.read(gameProvider).state!;
      final written = matchTraitOf(CardInstance.from(_cell(state, id)));
      expect(written, isNotNull, reason: 'the roll was not written');
      expect((state['resources'] as Map)['fanCoins'], lessThan(before));
      // The first slot is untouched by a roll in the second.
      expect(_cell(state, id)['trait'], isNull);
      await settleSave(tester);
    });

    testWidgets('and tapping PLAYER again brings the first pool back', (
      tester,
    ) async {
      final container = await pumpSquad(
        tester,
        mutate: (s) {
          for (final c in (s['grid'] as Map<String, dynamic>)['cells'] as List) {
            if (c is Map<String, dynamic>) c['matchSlot'] = true;
          }
        },
      );
      await openDetailOfFirst(tester, container);
      await scrollSheetTo(tester, 'detail-trait-roll');
      await tester.tap(find.byKey(const ValueKey('detail-trait-slot-match')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('matchtrait-reel-name')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('detail-trait-slot-player')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('trait-reel-name')), findsOneWidget);
      expect(find.byKey(const ValueKey('matchtrait-reel-name')), findsNothing);
    });
  });

  group('EVERY TRAIT, IN ONE SHEET', () {
    testWidgets('lists this position\'s pool and the whole match pool, marking his', (
      tester,
    ) async {
      final container = await pumpSquad(
        tester,
        mutate: (s) {
          final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List;
          final first = cells.firstWhere((c) => c != null) as Map<String, dynamic>;
          first['matchSlot'] = true;
          first['matchTrait'] = <String, dynamic>{'id': 'fortress', 'level': 2};
        },
      );
      await openDetailOfFirst(tester, container);
      await scrollSheetTo(tester, 'detail-trait');
      await tester.tap(find.byKey(const ValueKey('detail-trait-catalogue')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('trait-catalogue')), findsOneWidget);
      // Every match trait is a row; `none` from the player pool is not.
      // The list builds lazily, so walk it by its own position rather than
      // by dragging — a drag inside a modal sheet is the sheet's to dismiss.
      final position = tester
          .state<ScrollableState>(find.descendant(
            of: find.byKey(const ValueKey('trait-catalogue')),
            matching: find.byType(Scrollable),
          ))
          .position;
      for (final trait in matchTraitList) {
        final row = find.byKey(ValueKey('trait-catalogue-${trait.id}'));
        while (row.evaluate().isEmpty && position.pixels < position.maxScrollExtent) {
          position.jumpTo(position.pixels + 150);
          await tester.pump();
        }
        expect(row, findsOneWidget, reason: trait.id);
      }
      expect(find.byKey(const ValueKey('trait-catalogue-none')), findsNothing);
    });
  });
}
