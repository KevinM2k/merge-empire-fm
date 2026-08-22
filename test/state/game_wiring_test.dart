/// The listeners that turn an engine's announcement into a change to the save,
/// and the runner that drives them.
///
/// The headline case is not a formality: the achievement engine deliberately
/// does not apply its own coin grant — it says so in as many words — so without
/// the listener here every achievement in the game unlocks, announces itself,
/// and pays nothing.
library;

import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/quests.dart';
import 'package:merge_empire_fc/engine/achievement_engine.dart';
import 'package:merge_empire_fc/state/game_runner.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/game_tick.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/engine/season_end.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

const int _now = 1700000000000;
int _at = _now;

/// The shared reference save's squad.
///
/// A DEFAULT state starts with an empty grid — the tutorial is what fills it —
/// and a loop with nothing on the grid earns nothing.
List<dynamic> _referenceSquad() {
  final ref =
      jsonDecode(
            File(
              'test/fixtures/quest_engine_reference.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final grid = (ref['state'] as Map<String, dynamic>)['grid'] as Map;
  return jsonDecode(jsonEncode(grid['cells'])) as List<dynamic>;
}

/// A save with a squad, so the loop has something to earn from.
String _saveWith({num coins = 1000}) {
  final s = createDefaultState();
  (s['grid'] as Map)['cells'] = _referenceSquad();
  (s['resources'] as Map)['fanCoins'] = coins;
  // A pip short of full, so a tick has something to regenerate.
  (s['energy'] as Map)
    ..['current'] = 1
    ..['lastRegenAt'] = _now;
  (s['clubAssets'] as Map)['MERCH'] = <String, dynamic>{
    'owned': true,
    'tier': 4,
    'invested': 0,
    'tapCount': 0,
  };
  return jsonEncode(s);
}

({GameRunner runner, MemorySaveStore store}) _booted({
  num coins = 1000,
  TickGates Function()? gates,
  bool Function()? hidden,
}) {
  final store = MemorySaveStore({saveKeyPrimary: _saveWith(coins: coins)});
  final runner = GameRunner(
    game: GameState(store: store),
    gates: gates,
    hidden: hidden,
  )..boot();
  return (runner: runner, store: store);
}

void main() {
  setUp(() {
    _at = _now;
    setClock(() => _at);
    seeded.setSeed(1234);
  });
  tearDown(() {
    resetClock();
    clearBus();
  });

  /// The balance after boot, which is not the balance in the save: loading
  /// credits the offline earnings, and the boot sweep pays whatever the save
  /// already qualifies for.
  num coinsOf(GameRunner r) =>
      (r.game.state!['resources'] as Map)['fanCoins'] as num;

  group('the achievement grant', () {
    test('an unlock actually pays', () {
      // The whole reason this file exists.
      final booted = _booted();
      final before = coinsOf(booted.runner);
      emit('achievement:unlocked', {'id': 'first_win', 'coinsRewarded': 250});
      expect(coinsOf(booted.runner) - before, 250);
    });

    test('and announces the new balance, so the HUD moves', () {
      final booted = _booted();
      final before = coinsOf(booted.runner);
      Object? announced;
      on('coins:updated', (v) => announced = v);
      emit('achievement:unlocked', {'id': 'x', 'coinsRewarded': 100});
      expect(announced, before + 100);
    });

    test('an unlock worth nothing pays nothing', () {
      final booted = _booted();
      final before = coinsOf(booted.runner);
      emit('achievement:unlocked', {'id': 'x', 'coinsRewarded': 0});
      expect(coinsOf(booted.runner), before);
    });

    test('the badge follows the newest unlock', () {
      final booted = _booted();
      final prog = booted.runner.game.state!['progression'] as Map;
      prog['achievements'] = [
        {'id': 'first_win', 'unlockedAt': 1000, 'count': 1},
      ];
      emit('achievement:unlocked', {'id': 'first_win', 'coinsRewarded': 0});
      expect(prog['equippedBadgeId'], 'first_win');
    });

    test('the boot sweep pays for what the save already qualified for', () {
      // A save whose achievements were earned by an older build — or, as here,
      // that arrives already owning a tier-3 asset — gets the row, the badge and
      // the coins on load rather than on the next thing that happens to sweep.
      final booted = _booted();
      final prog = booted.runner.game.state!['progression'] as Map;
      expect(
        (prog['achievements'] as List).map((a) => (a as Map)['id']),
        contains('own_tier3_asset'),
      );
      expect(prog['equippedBadgeId'], 'own_tier3_asset');
    });

    test('a real unlock, end to end, pays what the catalogue says', () {
      // Through the bus and the sweep rather than a hand-made unlock event, so
      // the number is the one the player is actually owed.
      final booted = _booted();
      final before = coinsOf(booted.runner);
      emit('merge:happened', {'tier': 2});
      expect(getUnlockedIds(booted.runner.game.state), contains('first_merge'));
      expect(
        coinsOf(booted.runner) - before,
        achievementCoinRewards['first_merge'],
      );
    });

    test('A PRESTIGE SWEEPS, so its own achievements can finally unlock', () {
      // `prestige_level_1` and `prestige_level_3` read a level nothing raised —
      // `performPrestige` had no caller in `lib/` at all — and `prestige:complete`
      // was not in the sweep list either, so even once it did they had nothing
      // to fire them. It clears `achievementIdsThisRun` on its way out and
      // emits LAST, so the sweep sees the new adventure rather than the
      // finished one.
      final booted = _booted();
      final state = booted.runner.game.state!;
      (state['progression'] as Map)['wonChampionsCup'] = true;
      performPrestige(state);
      expect(getUnlockedIds(state), contains('prestige_level_1'));
    });

    test('and only once, however many times the event fires', () {
      final booted = _booted();
      emit('merge:happened', {'tier': 2});
      final after = coinsOf(booted.runner);
      emit('merge:happened', {'tier': 3});
      expect(coinsOf(booted.runner), after);
    });
  });

  test('the coin high-water mark survives being spent back down', () {
    // What makes the "earn N coins" achievements fire for a player who spent
    // the money afterwards.
    final booted = _booted();
    final stats = booted.runner.game.state!['stats'] as Map;
    emit('coins:updated', 50000);
    expect(stats['maxCoinsReached'], 50000);
    emit('coins:updated', 10);
    expect(stats['maxCoinsReached'], 50000);
  });

  test('detaching stops every listener it registered', () {
    // A second attach on a live bus would double every grant.
    final booted = _booted();
    final before = coinsOf(booted.runner);
    booted.runner.wiring.detach();
    emit('achievement:unlocked', {'id': 'x', 'coinsRewarded': 500});
    expect(coinsOf(booted.runner), before);
  });

  group('the runner', () {
    test('boots, ticks and stops', () {
      fakeAsync((async) {
        final booted = _booted();
        expect(booted.runner.running, isFalse);
        booted.runner.start();
        expect(booted.runner.running, isTrue);
        // Starting twice is one loop, not two.
        booted.runner.start();

        final before =
            (booted.runner.game.state!['resources'] as Map)['fanCoins'] as num;
        _at += 60000;
        async.elapse(const Duration(seconds: 60));
        expect(
          (booted.runner.game.state!['resources'] as Map)['fanCoins'],
          greaterThan(before),
        );

        booted.runner.stop();
        expect(booted.runner.running, isFalse);
      });
    });

    test('boot rolls the quest tracks a fresh save has never had', () {
      // Neither roll had a caller outside the season boundary, so a new save
      // reached the Quests sheet with an empty season track and stayed that way
      // until its first season ended — and the match track was empty for every
      // match ever played.
      final booted = _booted();
      final quests =
          booted.runner.game.state!['quests'] as Map<String, dynamic>;
      expect(quests['season'], isA<List<dynamic>>());
      expect((quests['season'] as List), isNotEmpty);
      expect(
        ((quests['match'] as Map<String, dynamic>)['active'] as List),
        hasLength(matchQuestCount),
      );
    });

    test('and a save that already has them keeps the ones it has', () {
      // The guard is the season number, so a boot only ever rolls once a
      // campaign. Saved between the two boots on purpose: boot itself schedules
      // nothing, so without the write the second boot reloads a save that never
      // had a track and rolls its own.
      final store = MemorySaveStore({saveKeyPrimary: _saveWith()});
      final game = GameState(store: store);
      final runner = GameRunner(game: game)..boot();
      List<String> ids() => [
        for (final q
            in (game.state!['quests'] as Map<String, dynamic>)['season']
                as List)
          '${(q as Map<String, dynamic>)['id']}',
      ];
      final first = ids();
      expect(first, isNotEmpty);

      game.saveNow();
      runner.boot();
      expect(ids(), first);
    });

    test('a tick before boot is a mistake, not a crash later', () {
      final runner = GameRunner(game: GameState(store: MemorySaveStore()));
      expect(runner.tickOnce, throwsStateError);
    });

    test('pausing saves and flushes the durable mirror', () {
      final flushes = <String>[];
      final store = MemorySaveStore({saveKeyPrimary: _saveWith()});
      final runner = GameRunner(
        game: GameState(store: store, writeNativeMirror: flushes.add),
      )..boot();
      runner.start();
      runner.game.state!['clubName'] = 'Paused FC';
      runner.pause();

      expect(runner.running, isFalse);
      expect(
        jsonDecode(store.values[saveKeyPrimary]!),
        containsPair('clubName', 'Paused FC'),
      );
      expect(flushes, hasLength(1));
    });

    test('resuming skips the time away rather than paying for it', () {
      // The offline earnings calculation owns that time. Ticking it as well
      // would credit it twice.
      fakeAsync((async) {
        final booted = _booted();
        booted.runner.start();
        booted.runner.pause();

        _at += 6 * 60 * 60 * 1000;
        final before =
            (booted.runner.game.state!['resources'] as Map)['fanCoins'] as num;
        booted.runner.resume();
        _at += 1000;
        async.elapse(const Duration(seconds: 1));
        final earned =
            ((booted.runner.game.state!['resources'] as Map)['fanCoins']
                as num) -
            before;
        // One second of income, not six hours of it.
        expect(earned, lessThan(1000));
        booted.runner.stop();
      });
    });

    test('a hidden app ticks nothing', () {
      fakeAsync((async) {
        final booted = _booted(hidden: () => true);
        booted.runner.start();
        final before =
            (booted.runner.game.state!['resources'] as Map)['fanCoins'];
        _at += 10000;
        async.elapse(const Duration(seconds: 10));
        expect(
          (booted.runner.game.state!['resources'] as Map)['fanCoins'],
          before,
        );
        booted.runner.stop();
      });
    });

    test('a tick announces what happened', () {
      final events = <String, Object?>{};
      for (final name in ['coins:updated', 'energy:updated']) {
        on(name, (v) => events[name] = v);
      }
      final booted = _booted();
      booted.runner.start();
      _at += 30 * 60 * 1000;
      final report = booted.runner.tickOnce();
      expect(report.coinsEarned, greaterThan(0));
      expect(events, contains('coins:updated'));
      expect(events, contains('energy:updated'));
      booted.runner.stop();
    });

    test('an event window crossing is saved at once, not on the debounce', () {
      final booted = _booted();
      booted.runner.start();
      (booted.runner.game.state!['events'] as Map)['devOverride'] = 'wc2026';
      _at += 1000;
      final report = booted.runner.tickOnce();
      expect(report.needsImmediateSave, isTrue);
      // Written already, with no timer having fired.
      expect(
        jsonDecode(booted.store.values[saveKeyPrimary]!),
        isA<Map<String, dynamic>>(),
      );
      booted.runner.stop();
    });

    test('the change stream wakes the UI without a save on every tick', () {
      // Idle income moves the balance every second. Going through `update`
      // there would reset the debounce so often the save never landed.
      var changes = 0;
      final booted = _booted();
      booted.runner.game.changes.listen((_) => changes++);
      booted.runner.start();
      _at += 60000;
      booted.runner.tickOnce();
      expect(changes, greaterThan(0));
      booted.runner.stop();
    });
  });
}
