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
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/data/match_traits.dart' show matchTraitList;
import 'package:merge_empire_fc/engine/match_trait_engine.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/screens/squad/trait_reel.dart';
import 'package:merge_empire_fc/ui/screens/squad/traits_block.dart';
import 'package:merge_empire_fc/ui/widgets/trait_copy.dart';

import 'squad_screen_test.dart';

Map<String, dynamic> _cell(Map<String, dynamic> state, String id) =>
    ((state['grid'] as Map<String, dynamic>)['cells'] as List)
        .whereType<Map<String, dynamic>>()
        .firstWhere((c) => c['instanceId'] == id);

String _idOf(WidgetTester tester) =>
    tester.widget<TraitBlock>(find.byType(TraitBlock)).instanceId;

void main() {
  group('THE SECOND SLOT', () {
    // The gem gate went: MATCH is a tile you pick and roll, like PLAYER.
    testWidgets('IS OPEN ON EVERY CARD, with no gem asked for', (tester) async {
      final container = await pumpSquad(
        tester,
        mutate: (s) => (s['resources'] as Map<String, dynamic>)['gems'] = 0,
      );
      await openDetailOfFirst(tester, container);
      await scrollSheetTo(tester, 'detail-trait');
      expect(find.byKey(const ValueKey('matchslot-unlock')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('detail-trait-slot-match')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('matchtrait-reel-name')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-trait-roll')), findsOneWidget);
      expect(find.byKey(const ValueKey('matchslot-unlock')), findsNothing);
      expect(find.text(t('squad.trait.slot.locked')), findsNothing);
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
      // **THE MATCH TRAITS LIVE ON THEIR OWN TAB NOW.** The sheet opens on the
      // player pool — the slot every card has — and the match half is one tap
      // away rather than below fifteen rows of the other one.
      await tester.tap(
        find.byKey(const ValueKey('trait-catalogue-tab-match')),
      );
      await tester.pumpAndSettle();
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
      // And each says WHEN it fires and what each level is worth.
      expect(find.textContaining(matchTraitWhen(matchTraitList.last)), findsWidgets);
      expect(find.text('III ${matchTraitEffect(matchTraitList.last, matchTraitList.last.levels.last)}'), findsOneWidget);
    });

    testWidgets('AND THE TWO HALVES ARE ONE TAP APART', (tester) async {
      // Asked for from the couch: tabs, so the match traits are not buried
      // under a player pool that runs to fifteen rows.
      final container = await pumpSquad(tester);
      await openDetailOfFirst(tester, container);
      await scrollSheetTo(tester, 'detail-trait');
      await tester.tap(find.byKey(const ValueKey('detail-trait-catalogue')));
      await tester.pumpAndSettle();

      // It opens on the player pool, and the match pool is not in the tree.
      final firstMatch = ValueKey('trait-catalogue-${matchTraitList.first.id}');
      expect(find.byKey(firstMatch), findsNothing);
      expect(find.text(t('squad.traits.match_blurb')), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('trait-catalogue-tab-match')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(firstMatch), findsOneWidget);
      expect(find.text(t('squad.traits.match_blurb')), findsOneWidget);

      // And back again, so neither tab is a one-way door.
      await tester.tap(
        find.byKey(const ValueKey('trait-catalogue-tab-player')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(firstMatch), findsNothing);
    });
  });
}
