/// The bench, ordered for the hole it is filling.
///
/// It came off the grid cells as they happened to be laid out, so the man who
/// plays where the hole is could be anywhere in it — and the subs panel is the
/// one moment a manager reads the bench against a clock.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_providers.dart';

/// A save whose grid holds one card per (position, tier) named below, in an
/// order that is deliberately NOT the answer.
ProviderContainer benchOf(List<(String, int)> spec) {
  final state = createDefaultState();
  final cells =
      (state['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
  for (var i = 0; i < spec.length; i++) {
    final (pos, tier) = spec[i];
    cells[i] = {
      'definitionId': players
          .firstWhere((p) => p.position == pos && p.tier == tier)
          .id,
      'instanceId': 'c$i',
      'variant': 0,
    };
  }
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
      ),
    ],
  );
  container.read(gameProvider).load();
  return container;
}

void main() {
  test('THE MEN WHO PLAY THERE LEAD, best first, then the rest in order', () {
    // Twelve cards: eleven go into the lineup, so the bench is what is left —
    // which is why the spec is long enough to leave several over.
    final container = benchOf(const [
      ('GK', 1),
      ('DEF', 1), ('DEF', 1), ('DEF', 1), ('DEF', 2),
      ('MID', 1), ('MID', 1), ('MID', 1), ('MID', 3),
      ('FWD', 1), ('FWD', 1), ('FWD', 4), ('FWD', 2), ('DEF', 5),
    ]);
    addTearDown(container.dispose);

    final bench = container.read(benchProvider);
    expect(bench, isNotEmpty, reason: 'nothing to order');

    for (final slot in const ['DEF', 'MID', 'FWD']) {
      final ordered = container.read(benchForSlotProvider(slot));
      expect(
        ordered.map((e) => e.instanceId).toSet(),
        bench.map((e) => e.instanceId).toSet(),
        reason: 'nobody may be dropped or duplicated',
      );

      // Two halves: the naturals, then the rest. Neither may interleave, and
      // rating never rises inside either.
      final naturals = ordered.takeWhile((e) => e.card.position == slot);
      final rest = ordered.skip(naturals.length);
      expect(
        rest.any((e) => e.card.position == slot),
        isFalse,
        reason: '$slot: a natural came after somebody who is not one',
      );
      for (final half in [naturals.toList(), rest.toList()]) {
        for (var i = 1; i < half.length; i++) {
          expect(
            half[i].card.rating,
            lessThanOrEqualTo(half[i - 1].card.rating),
            reason: '$slot: out of rating order',
          );
        }
      }
    }
  });

  test('and with no slot it is best first, full stop', () {
    final container = benchOf(const [
      ('GK', 1),
      ('DEF', 1), ('DEF', 1), ('DEF', 1), ('DEF', 2),
      ('MID', 1), ('MID', 1), ('MID', 1), ('MID', 3),
      ('FWD', 1), ('FWD', 1), ('FWD', 4), ('FWD', 2), ('DEF', 5),
    ]);
    addTearDown(container.dispose);
    final ordered = container.read(benchForSlotProvider(null));
    expect(ordered, isNotEmpty);
    for (var i = 1; i < ordered.length; i++) {
      expect(
        ordered[i].card.rating,
        lessThanOrEqualTo(ordered[i - 1].card.rating),
      );
    }
  });
}
