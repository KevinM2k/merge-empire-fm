/// The live save, and everything that happens to it — against the JS it was
/// ported from.
///
/// The two resets are the load-bearing part, and they have the worst failure
/// mode in the codebase: the JS comments they carry read like a list of things
/// that went wrong in production — a full reset that took the player's gem
/// balance, a soft reset that zeroed the lifetime counters so the next boot
/// overwrote a real leaderboard standing with them, a preserved gem ledger that
/// re-armed every one-time faucet so resetting became the farm. Every one is a
/// paying player losing something they paid for, so the WHOLE state is compared
/// rather than the fields somebody remembered to check.
///
/// See `tool/dump_game_state_reference.mjs`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

final Map<String, dynamic> _ref =
    jsonDecode(
          File('test/fixtures/game_state_reference.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

List<Map<String, dynamic>> _rows(String key) =>
    (_ref[key] as List).cast<Map<String, dynamic>>();

Map<String, dynamic> _section(String key) => _ref[key] as Map<String, dynamic>;

final int _now = _ref['fixedNow'] as int;
final int _seed = _ref['seed'] as int;

/// The comparison drops `definitionRatios`.
///
/// It is drawn from the UNSEEDED stream in both runtimes — a per-install
/// randomisation of each card's ATK/DEF split, not a value the port has to
/// reproduce. What IS asserted about it is the property: a reset regenerates it,
/// with one entry per definition.
Map<String, dynamic> _withoutRatios(Map<String, dynamic> state) =>
    <String, dynamic>{
      for (final e in state.entries)
        if (e.key != 'definitionRatios') e.key: e.value,
    };

/// A save exactly as the reference had it before the reset ran.
Map<String, dynamic> _before(String label) {
  final row = _rows('resets').firstWhere((r) => r['label'] == label);
  return jsonDecode(jsonEncode(row['before'])) as Map<String, dynamic>;
}

/// A game state loaded from one save, on a store nothing else has touched.
({GameState game, MemorySaveStore store}) _loaded(Map<String, dynamic> save) {
  final store = MemorySaveStore({saveKeyPrimary: jsonEncode(save)});
  final game = GameState(store: store);
  seeded.setSeed(_seed);
  game.load();
  return (game: game, store: store);
}

void main() {
  setUp(() {
    setClock(() => _now);
    seeded.setSeed(_seed);
  });
  tearDown(resetClock);

  test('the default state matches the JS, seed for seed', () {
    // Shipped with the fixture so a difference in the SCHEMA cannot masquerade
    // as a difference in a reset — every reset starts from one of these.
    seeded.setSeed(_seed);
    expect(_withoutRatios(createDefaultState()), _ref['defaultState']);
  });

  group('parity — resetting', () {
    for (final row in _rows('resets')) {
      final label = row['label'] as String;
      test('the whole save comes out the same — $label', () {
        final loaded = _loaded(_before(label));
        final after = switch (label) {
          'softRich' || 'softBare' => loaded.game.resetState(),
          'softRichReplayTutorial' => loaded.game.resetState(
            replayTutorial: true,
          ),
          'fullRich' || 'fullBare' => loaded.game.fullResetState(),
          'fullRichKeepTutorial' => loaded.game.fullResetState(
            replayTutorial: false,
          ),
          _ => throw ArgumentError(label),
        };
        expect(_withoutRatios(after), row['after']);
        // And what landed in the store, which is what the next boot reads.
        expect(
          loaded.store.values.keys.toSet(),
          (row['stored'] as Map).keys.toSet(),
        );
        expect(
          _withoutRatios(
            jsonDecode(loaded.store.values[saveKeyPrimary]!)
                as Map<String, dynamic>,
          ),
          _withoutRatios(
            jsonDecode((row['stored'] as Map)[saveKeyPrimary] as String)
                as Map<String, dynamic>,
          ),
        );
        expect(
          loaded.store.values[resetPendingKey],
          (row['stored'] as Map)[resetPendingKey],
        );
      });
    }

    test('parity — a soft reset then a full one', () {
      // The shape a player who resets twice actually hits: the second must not
      // undo what the first preserved.
      final want = _section('softThenFull');
      final loaded = _loaded(_before('softRich'));
      expect(_withoutRatios(loaded.game.resetState()), want['soft']);
      expect(_withoutRatios(loaded.game.fullResetState()), want['full']);
    });
  });

  test('a reset regenerates the per-install ATK/DEF split', () {
    // The one field the comparison drops, so it is asserted as a property: a
    // fresh save gets a fresh split, one entry per definition.
    final loaded = _loaded(_before('softRich'));
    final before = Map<String, dynamic>.from(
      loaded.game.state!['definitionRatios'] as Map,
    );
    final after = loaded.game.resetState()['definitionRatios'] as Map;
    expect(after.keys.length, greaterThan(0));
    expect(after.keys.toSet(), isNot(isEmpty));
    // The reference save carries none, so this is also the back-fill path.
    expect(after, isNot(same(before)));
  });

  group('what a reset must never take', () {
    late GameState game;

    setUp(() => game = _loaded(_before('softRich')).game);

    test('the gem balance and the ledger, on either path', () {
      // Gems are hard currency. Wiping them revokes something that was paid
      // for, and wiping the ledger with them re-arms every one-time faucet, so
      // the reset itself becomes the farm.
      final before = (_before('softRich')['resources'] as Map)['gems'];
      for (final reset in [game.resetState, game.fullResetState]) {
        final after = reset();
        expect((after['resources'] as Map)['gems'], before, reason: '$reset');
        final grants = after['gemGrants'] as Map;
        expect(grants['tutorialGranted'], isTrue);
        expect(grants['tutorialBackfilled'], isTrue);
        expect(grants['divisionFirsts'], ['amateur_cup', 'regional_league']);
        expect(grants['cupFirsts'], ['regional_cup']);
        expect(grants['firstPrestigeDone'], isTrue);
        // The one per-run flag, dropped so the new run can win its own title.
        expect(grants['chlTitleThisRun'], isFalse);
      }
    });

    test('the login streak, because day 7 is a gem faucet', () {
      for (final reset in [game.resetState, game.fullResetState]) {
        final daily = reset()['dailyReward'] as Map;
        expect(daily['streak'], 19);
        expect(daily['longestStreak'], 22);
        expect(daily['totalClaims'], 41);
      }
    });

    test('anything bought with real money', () {
      for (final reset in [game.resetState, game.fullResetState]) {
        final shop = reset()['shop'] as Map;
        expect(shop['purchasedIds'], persistentIaps);
        expect(shop['totalSpent'], 4299);
        expect(shop['energyUpgraded'], isTrue);
        // A consumable is NOT an entitlement: the coin pile was spent.
        expect(shop['purchasedIds'], isNot(contains('coin_pile')));
      }
    });

    test('the look packs gems paid for', () {
      for (final reset in [game.resetState, game.fullResetState]) {
        final club = reset()['club'] as Map;
        expect(club['lookPacks'], ['pack_summer', 'pack_neon']);
        expect(club['lookItems'], isNotEmpty);
      }
    });
  });

  group('what a soft reset keeps and a full one does not', () {
    test('the career, the achievements and the prestige level', () {
      final soft = _loaded(_before('softRich')).game.resetState();
      expect((soft['progression'] as Map)['achievements'], hasLength(2));
      expect((soft['prestige'] as Map)['level'], 3);
      // Career totals ACCUMULATE rather than being replaced.
      expect((soft['careerStats'] as Map)['leagueWins'], 6);
      expect((soft['careerStats'] as Map)['matchesWon'], 143);
      // The lifetime leaderboard counters, which the next boot reseeds the
      // all-time row from. Zeroing them wiped a real global standing.
      expect((soft['progression'] as Map)['careerWins'], 143);
      expect((soft['progression'] as Map)['careerGoalsFor'], 620);

      final full = _loaded(_before('fullRich')).game.fullResetState();
      expect((full['progression'] as Map)['achievements'], isEmpty);
      expect((full['prestige'] as Map)['level'], 0);
      expect((full['careerStats'] as Map)['leagueWins'], 0);
      expect((full['progression'] as Map)['careerWins'], 0);
    });

    test('the cup looks, which a full reset takes with the cabinet', () {
      final soft = _loaded(_before('softRich')).game.resetState();
      expect((soft['club'] as Map)['cupLooksWon'], ['outfit:tracksuit']);
      final full = _loaded(_before('fullRich')).game.fullResetState();
      // Not empty — ABSENT. The fresh club never had the key, and a full reset
      // has no reason to write one back just to say the cabinet is bare.
      expect((full['club'] as Map).containsKey('cupLooksWon'), isFalse);
    });

    test('the settings, minus the auto-sell rules', () {
      // Those are a judgement about a squad that no longer exists: a new team
      // starts in Sunday League, where every draw is the bronze a late-game rule
      // was set to bin.
      final soft = _loaded(_before('softRich')).game.resetState();
      expect((soft['settings'] as Map)['locale'], 'fr');
      expect((soft['settings'] as Map)['hardMode'], isTrue);
      expect(soft['autoTier'], isNot(contains('rules')));
    });
  });

  test('the manager drops what he can no longer justify', () {
    // Against the FRESH state: the Fan Zone is gone and the packs are re-locked,
    // so a tier look he no longer has comes off. Cup looks are preserved above
    // and so survive it.
    final avatar = _loaded(_before('softRich')).game.resetState();
    final look = ((avatar['club'] as Map)['managerAvatar'] as Map);
    expect(look['outfit'], 'kit');
    expect(look['style'], 'crop');
    expect(look['beard'], 'none');
    expect(look['hat'], 'none');
  });

  group('the reset flag', () {
    test('names which reset it was', () {
      final soft = _loaded(_before('softRich'));
      soft.game.resetState();
      expect(soft.game.peekResetPending(), ResetMode.soft);

      final full = _loaded(_before('fullRich'));
      full.game.fullResetState();
      expect(full.game.peekResetPending(), ResetMode.full);
    });

    test('a peek does not consume it', () {
      // Every concurrent boot-sync path has to see it, and all of them
      // force-upload; only the path that actually overwrote the cloud clears it.
      final loaded = _loaded(_before('softRich'));
      loaded.game.resetState();
      expect(loaded.game.peekResetPending(), ResetMode.soft);
      expect(loaded.game.peekResetPending(), ResetMode.soft);
      loaded.game.clearResetPending();
      expect(loaded.game.peekResetPending(), isNull);
    });
  });

  test('a reset freezes saves, so a pending one cannot land on top', () {
    final loaded = _loaded(_before('softRich'));
    loaded.game.update((s) => s['clubName'] = 'About To Be Wiped');
    expect(loaded.game.savePending, isTrue);
    loaded.game.resetState();
    expect(loaded.game.frozen, isTrue);
    expect(loaded.game.savePending, isFalse);
    // And the write that follows is the fresh state, not the pending one.
    final stored =
        jsonDecode(loaded.store.values[saveKeyPrimary]!)
            as Map<String, dynamic>;
    expect(stored['clubName'], isNot('About To Be Wiped'));
  });

  test('dispose flushes a debounced write rather than dropping it', () {
    // dispose() is test-only, and a timer left armed would fire into a state
    // nobody owns any more — taking a real change with it.
    final loaded = _loaded(_before('softRich'));
    loaded.game.update((s) => s['clubName'] = 'Late Change FC');
    expect(loaded.game.savePending, isTrue);

    loaded.game.dispose();
    expect(loaded.game.savePending, isFalse);
    final stored =
        jsonDecode(loaded.store.values[saveKeyPrimary]!)
            as Map<String, dynamic>;
    expect(stored['clubName'], 'Late Change FC');
  });
}
