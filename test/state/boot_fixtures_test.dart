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

  /// **Every save this port has ever written started with no gems.**
  /// `grantTutorialGems` is the onboarding faucet — load-bearing rather than
  /// generous, since cups are the only other route and they do not start until
  /// the third division — and its only caller in the JS is the scripted
  /// tutorial, the one part of that game the port does not have.
  group('the welcome gift', () {
    test('A NEW PLAYER BOOTS WITH GEMS TO SPEND', () {
      final fresh = createDefaultState();
      expect(
        (fresh['resources'] as Map<String, dynamic>)['gems'],
        0,
        reason: 'the default state is the JS\'s and stays that way',
      );
      final c = boot(fresh);
      final gems =
          (c.read(gameProvider).state!['resources']
              as Map<String, dynamic>)['gems'];
      expect(gems, isA<num>());
      expect(gems as num, greaterThan(0));
    });

    test('and it pays ONCE PER PLAYER, not once per boot', () {
      // The ledger flag is what stops a relaunch being a faucet, and the ledger
      // survives both resets — so this is also what stops New Team being one.
      final store = MemorySaveStore({
        saveKeyPrimary: jsonEncode(createDefaultState()),
      });
      num gemsAfterBoot() {
        final c = ProviderContainer(
          overrides: [saveStoreProvider.overrideWithValue(store)],
        );
        addTearDown(c.dispose);
        c.read(gameRunnerProvider).boot();
        final state = c.read(gameProvider).state!;
        c.read(gameProvider).saveNow();
        return (state['resources'] as Map<String, dynamic>)['gems'] as num;
      }

      final first = gemsAfterBoot();
      expect(first, greaterThan(0));
      expect(gemsAfterBoot(), first);
      expect(gemsAfterBoot(), first);
    });
  });

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
