/// The rules the achievement engine has to obey, as distinct from which
/// predicates fire.
///
/// The parity fixture pins all eighty-one predicates against the JS; this pins the
/// bookkeeping, the fallbacks nothing else reaches, and the one place where the JS
/// contradicts its own comment.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/achievements.dart';
import 'package:merge_empire_fc/engine/achievement_engine.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/time.dart';

const int _now = 1700000000000;
const AchievementEvent _boot = (type: 'boot', data: null);

Map<String, dynamic> _state() => {
  'progression': {
    'currentDivision': 'sunday_league',
    'achievements': <Object?>[],
    'achievementIdsThisRun': <Object?>[],
  },
  'grid': {'cells': <Object?>[]},
  'stats': <String, dynamic>{},
  'resources': {'fanCoins': 0},
  'clubAssets': <String, dynamic>{},
  'settings': {'hardMode': false},
  'careerStats': <String, dynamic>{},
  'prestige': {'level': 0},
};

List<Object?> _bucket(Map<String, dynamic> s) =>
    (s['progression'] as Map)['achievements'] as List;

void main() {
  setUp(() => setClock(() => _now));
  tearDown(() {
    resetClock();
    clearBus();
  });

  group('the catalogue holds together', () {
    test('every reward is a real, non-negative number', () {
      for (final a in achievements) {
        final reward = achievementCoinRewards[a.id] ?? defaultAchievementReward;
        expect(reward, greaterThanOrEqualTo(0), reason: a.id);
      }
    });

    test('the reward table names nothing that is not in the catalogue', () {
      // A reward keyed to an id that no longer exists pays nothing to nobody and
      // hides the fact that the achievement it was written for has gone.
      final ids = achievements.map((a) => a.id).toSet();
      for (final id in achievementCoinRewards.keys) {
        expect(ids, contains(id), reason: '$id has a reward but no achievement');
      }
    });

    test('prestige pays no coins — the reward is the multiplier itself', () {
      // Coins here would trivialise the new run.
      for (final id in ['prestige_level_1', 'prestige_level_3',
        'prestige_level_5', 'prestige_level_10']) {
        expect(achievementCoinRewards[id], 0, reason: id);
      }
    });

    test('every title and description says something', () {
      for (final a in achievements) {
        expect(a.title, isNotEmpty, reason: a.id);
        expect(a.description, isNotEmpty, reason: a.id);
        // One of the two icon routes, never both and never neither.
        expect(
          (a.icon != null) ^ (a.iconAsset != null),
          isTrue,
          reason: '${a.id} must have exactly one of icon / iconAsset',
        );
      }
    });

    test('a progress bar never has a target of zero', () {
      // A zero target is a bar that cannot be drawn.
      for (final a in achievements) {
        if (a.progress == null) continue;
        expect(a.progress!(_state()).target, greaterThan(0), reason: a.id);
      }
    });

    test('an event-gated achievement says when it could be earned', () {
      // Once the event closes it becomes un-earnable for anyone who missed it, so
      // the window has to be stated.
      for (final a in achievements) {
        if (a.category != 'events') continue;
        expect(a.availability, isNotNull, reason: a.id);
        expect(a.availabilityKey, isNotNull, reason: a.id);
      }
    });
  });

  group('bookkeeping', () {
    test('an unlock is recorded with its reward and a timestamp', () {
      final state = _state();
      (state['prestige'] as Map)['level'] = 1;
      final got = checkAchievements(state);
      expect(got.map((a) => a.id), ['prestige_level_1']);
      expect(_bucket(state), [
        {
          'id': 'prestige_level_1',
          'unlockedAt': _now,
          'coinsRewarded': 0,
          'count': 1,
        },
      ]);
      expect(
        (state['progression'] as Map)['achievementIdsThisRun'],
        ['prestige_level_1'],
      );
    });

    test('an unlock is announced on the bus, for the listener that pays it', () {
      // The coin grant is applied by the listener, which has the state-mutation
      // wrapper needed to trigger a save — so the event has to carry the amount.
      final seen = <Map<String, dynamic>>[];
      on('achievement:unlocked', (payload) {
        if (payload is Map<String, dynamic>) seen.add(payload);
      });
      final state = _state();
      (state['progression'] as Map)['currentDivision'] = 'amateur_cup';
      checkAchievements(state);
      expect(seen, hasLength(1));
      expect(seen.first['id'], 'reach_amateur');
      expect(seen.first['coinsRewarded'], 200);
      expect(seen.first['isReUnlock'], isFalse);
      expect(seen.first['count'], 1);
    });

    test('a second sweep in the same run pays nothing more', () {
      final state = _state();
      (state['progression'] as Map)['currentDivision'] = 'champions_cup';
      final first = checkAchievements(state);
      expect(first, isNotEmpty);
      expect(checkAchievements(state), isEmpty);
      expect(_bucket(state), hasLength(first.length));
    });

    test('an unknown reward falls back to the default rather than nothing', () {
      // Most of the cup, Pro-mode and mini-game achievements have no entry, so the
      // fallback is load-bearing rather than defensive.
      final state = _state();
      (state['careerStats'] as Map)['cupWins'] = 1;
      final got = checkAchievements(state);
      final cup = got.firstWhere((a) => a.id == 'first_cup_win');
      expect(achievementCoinRewards.containsKey('first_cup_win'), isFalse);
      expect(cup.coinsRewarded, defaultAchievementReward);
    });

    test('builds the branch on a save that has none at all', () {
      final state = <String, dynamic>{};
      expect(() => checkAchievements(state), returnsNormally);
      final prog = state['progression'] as Map;
      expect(prog['achievements'], isEmpty);
      expect(prog['achievementIdsThisRun'], isEmpty);
    });

    test('repairs a bucket that is not a list', () {
      final state = _state();
      (state['progression'] as Map)['achievements'] = 'nonsense';
      (state['progression'] as Map)['achievementIdsThisRun'] = 42;
      expect(() => checkAchievements(state), returnsNormally);
      expect(_bucket(state), isEmpty);
    });

    test('a null save is a no-op rather than a crash', () {
      expect(checkAchievements(null), isEmpty);
      expect(getUnlockedIds(null), isEmpty);
    });
  });

  group('the dead re-unlock path', () {
    test('an achievement earned in an earlier run stays earned, and silent', () {
      // The engine clears a per-run list on reset so achievements "become
      // re-unlockable in new runs", and carries a branch that increments a count
      // when one fires again. The ever-unlocked guard makes that branch
      // unreachable, so neither happens.
      //
      // This test pins the JS BEHAVIOUR, not its stated intent. If the guard is
      // ever removed deliberately, this is the test that will say so — and turning
      // it on means every achievement re-pays on every reset, which is an economy
      // decision. See docs/REMAINING.md.
      final state = _state();
      (state['progression'] as Map)['currentDivision'] = 'amateur_cup';
      (state['progression'] as Map)['achievements'] = [
        {
          'id': 'reach_amateur',
          'unlockedAt': 1,
          'coinsRewarded': 200,
          'count': 1,
        },
      ];

      final got = checkAchievements(state);
      expect(got, isEmpty, reason: 'nothing re-fires');
      final entry = _bucket(state).first as Map;
      expect(entry['count'], 1, reason: 'the count never moves');
      expect(entry['unlockedAt'], 1, reason: 'the timestamp is not refreshed');
      expect(
        (state['progression'] as Map)['achievementIdsThisRun'],
        isEmpty,
        reason: 'and the per-run list stays empty, so clearing it achieves nothing',
      );
    });
  });

  group('fallbacks nothing else reaches', () {
    test('cups won falls back to counting the cup history', () {
      // A save written before the career counter existed still has the history.
      final state = _state();
      (state['careerStats'] as Map).remove('cupWins');
      (state['progression'] as Map)['cups'] = {
        'history': [
          {'outcome': 'won'},
          {'outcome': 'lost'},
          {'outcome': 'won'},
          {'outcome': 'won'},
        ],
      };
      final got = checkAchievements(state).map((a) => a.id).toSet();
      expect(got, contains('first_cup_win'));
      expect(got, contains('cup_treble'));
      expect(got, isNot(contains('cup_dynasty')));
      expect(getAchievementDef('cup_treble')!.progress!(state).current, 3);
    });

    test('the career counter wins over the history when both are there', () {
      final state = _state();
      (state['careerStats'] as Map)['cupWins'] = 0;
      (state['progression'] as Map)['cups'] = {
        'history': [
          {'outcome': 'won'},
          {'outcome': 'won'},
        ],
      };
      // Null-coalescing, so a recorded ZERO stops the fallback.
      expect(
        checkAchievements(state).map((a) => a.id),
        isNot(contains('first_cup_win')),
      );
    });

    test('coins fall back to the live balance when no high-water mark exists', () {
      final state = _state();
      (state['stats'] as Map).remove('maxCoinsReached');
      (state['resources'] as Map)['fanCoins'] = 10000;
      expect(
        checkAchievements(state).map((a) => a.id),
        contains('coins_10k'),
      );
    });

    test('matches won falls back to the per-run counter', () {
      final state = _state();
      (state['careerStats'] as Map).remove('matchesWon');
      (state['progression'] as Map)['matchesWon'] = 25;
      final got = checkAchievements(state).map((a) => a.id).toSet();
      expect(got, contains('first_win'));
      expect(got, contains('win_25_matches'));
    });

    test('merges fall back to the stats counter', () {
      final state = _state();
      (state['stats'] as Map)['totalMerges'] = 50;
      final got = checkAchievements(state).map((a) => a.id).toSet();
      expect(got, contains('first_merge'));
      expect(got, contains('merge_50'));
    });
  });

  group('the International Cup description', () {
    final def = getAchievementDef('wc_win')!;

    test('names the nation from the event record', () {
      final state = _state();
      state['events'] = {
        'progress': {
          'wc2026': {
            'firstWin': {'playerNation': 'BRA'},
          },
        },
      };
      final desc = def.descriptionWhenUnlocked!(state);
      expect(desc?.i18nKey, 'ach.desc_won.wc_win');
      expect(desc?.params['nation'], 'BRA');
    });

    test('falls back to a legacy trophy entry', () {
      final state = _state();
      (state['progression'] as Map)['leagueTrophies'] = [
        {'event': true, 'eventId': 'wc2026', 'playerNation': 'ARG'},
      ];
      expect(def.descriptionWhenUnlocked!(state)?.params['nation'], 'ARG');
      // And the check itself accepts the legacy shape.
      expect(def.check(state, _boot), isTrue);
    });

    test('falls back to the live cup, then gives up quietly', () {
      final state = _state();
      state['events'] = {
        'progress': {
          'wc2026': {
            'firstWin': <String, dynamic>{},
            'cup': {'playerNation': 'ESP'},
          },
        },
      };
      expect(def.descriptionWhenUnlocked!(state)?.params['nation'], 'ESP');

      // Nothing to name at all — null, rather than an empty sentence.
      final bare = _state();
      bare['events'] = {
        'progress': {
          'wc2026': {'firstWin': <String, dynamic>{}},
        },
      };
      expect(def.descriptionWhenUnlocked!(bare), isNull);
      expect(def.descriptionWhenUnlocked!(_state()), isNull);
    });
  });

  group('progress labels', () {
    test('read as a capped percentage for the big coin goals', () {
      for (final (id, target) in [('coins_1m', 1000000), ('coins_1b', 1000000000)]) {
        final def = getAchievementDef(id)!;
        final state = _state();

        (state['stats'] as Map)['maxCoinsReached'] = 0;
        expect(def.progressText!(state), startsWith('0.0%'));

        (state['stats'] as Map)['maxCoinsReached'] = target ~/ 2;
        expect(def.progressText!(state), startsWith('50.0%'));

        // Capped, so a run that blows past the goal does not read as 4000%.
        (state['stats'] as Map)['maxCoinsReached'] = target * 40;
        expect(def.progressText!(state), startsWith('100.0%'));
      }
    });
  });
}
