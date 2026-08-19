/// Boot leaves a save able to show its fixtures and its table.
///
/// `initSeasonOpponents` was only ever called at a SEASON BOUNDARY, so a save
/// that had not finished a season — every new save, and every save made before
/// the schedule landed — had `seasonFixtures` null for good. The Fixtures sheet
/// reads that key and sat on its loading line permanently.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart';

void main() {
  ProviderContainer boot(Map<String, dynamic> state) {
    final c = ProviderContainer(
      overrides: [
        saveStoreProvider.overrideWithValue(
          MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
        ),
      ],
    );
    addTearDown(c.dispose);
    // Through the RUNNER, not `game.load()`: the sweeps a boot owes — the quest
    // tracks, the season's schedule, the manager's look — live in
    // `GameRunner.boot`, and that is the only thing the app calls.
    c.read(gameRunnerProvider).boot();
    return c;
  }

  test('a fresh save has a schedule after boot', () {
    final c = boot(createDefaultState());
    final prog =
        c.read(gameProvider).state!['progression'] as Map<String, dynamic>;
    expect(prog['seasonFixtures'], isNotNull);
    expect(prog['seasonFixtures'], isA<List<dynamic>>());
    expect(prog['seasonFixtures'] as List<dynamic>, isNotEmpty);
  });

  test('and the Fixtures sheet has rows to show', () {
    final c = boot(createDefaultState());
    expect(c.read(fixturesProvider), isNotEmpty);
  });

  test('and the table has a full division in it', () {
    final c = boot(createDefaultState());
    final rows = c.read(leagueTableProvider);
    // The player plus their opponents.
    expect(rows.length, greaterThan(1));
    expect(rows.where((r) => r.isPlayer), hasLength(1));
  });

  test('and the division does not reshuffle between reads', () {
    final c = boot(createDefaultState());
    final first = [for (final r in c.read(leagueTableProvider)) r.name];
    for (var i = 0; i < 5; i++) {
      expect(
        [for (final r in c.read(leagueTableProvider)) r.name],
        first,
        reason: 'the table swapped clubs on read $i',
      );
    }
  });
}
