/// The second trait slot on the player sheet.
///
/// A gem opens it, coins spin it, and it spins THE SAME reel the first slot
/// does — the machine was lifted out of `TraitBlock` rather than copied, and
/// the assertion that both reels are on one sheet is what says so.
///
/// Harness borrowed from `squad_screen_test.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/match_trait_engine.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/screens/squad/match_trait_block.dart';
import 'package:merge_empire_fc/ui/screens/squad/trait_reel.dart';

import 'squad_screen_test.dart';

Map<String, dynamic> _cell(Map<String, dynamic> state, String id) =>
    ((state['grid'] as Map<String, dynamic>)['cells'] as List)
        .whereType<Map<String, dynamic>>()
        .firstWhere((c) => c['instanceId'] == id);

void main() {
  group('THE SECOND SLOT', () {
    testWidgets('IS LOCKED UNTIL A GEM OPENS IT', (tester) async {
      final container = await pumpSquad(
        tester,
        mutate: (s) => (s['resources'] as Map<String, dynamic>)['gems'] = 3,
      );
      await openDetailOfFirst(tester, container);
      await scrollSheetTo(tester, 'detail-matchtrait');

      expect(find.byKey(const ValueKey('matchslot-unlock')), findsOneWidget);
      expect(find.byKey(const ValueKey('matchtrait-reel-name')), findsNothing);
      expect(find.byKey(const ValueKey('detail-matchtrait-roll')), findsNothing);
      // The first slot's reel is still there and untouched.
      expect(find.byKey(const ValueKey('trait-reel-name')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('matchslot-unlock')));
      await tester.pumpAndSettle();

      final state = container.read(gameProvider).state!;
      expect((state['resources'] as Map)['gems'], 2);
      final id = tester
          .widget<MatchTraitBlock>(find.byType(MatchTraitBlock))
          .instanceId;
      expect(_cell(state, id)['matchSlot'], isTrue);
      expect(find.byKey(const ValueKey('matchtrait-reel-name')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-matchtrait-roll')), findsOneWidget);
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
      await scrollSheetTo(tester, 'detail-matchtrait');

      expect(find.byKey(const ValueKey('matchslot-blocked')), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('matchslot-unlock')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      final state = container.read(gameProvider).state!;
      expect((state['resources'] as Map)['gems'], 0);
      expect(find.byKey(const ValueKey('matchtrait-reel-name')), findsNothing);
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
      await scrollSheetTo(tester, 'detail-matchtrait-roll');

      // Two reels, one machine: both are the shared widget.
      expect(find.byType(TraitReel), findsNWidgets(2));
      expect(find.byKey(const ValueKey('matchtrait-reel-name')), findsOneWidget);
      expect(find.byKey(const ValueKey('matchtrait-reel-level')), findsOneWidget);

      final id = tester
          .widget<MatchTraitBlock>(find.byType(MatchTraitBlock))
          .instanceId;
      final before = (container.read(gameProvider).state!['resources'] as Map)['fanCoins'] as num;

      await tester.tap(find.byKey(const ValueKey('detail-matchtrait-roll')));
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
  });
}
