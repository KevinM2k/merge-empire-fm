/// Differential test: the Dart achievement catalogue and engine against the JS
/// they were ported from.
///
/// The catalogue is eighty-one PREDICATES over the save. Most take one line to
/// write and one line to get subtly wrong — `>=` for `>`, the wrong stat, a career
/// total where a per-run one was meant — and none of it is visible until a player
/// reports a trophy that will not unlock.
///
/// So every predicate is fired against the state the JS says should unlock it, and
/// against a blank one that must not, and the WHOLE set of ids that fire is
/// compared. That catches a predicate which is too loose as well as one that is too
/// tight.
///
/// See `tool/dump_achievements_reference.mjs`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/achievements.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/engine/achievement_engine.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/time.dart';

final Map<String, dynamic> ref = jsonDecode(
  File('test/fixtures/achievements_reference.json').readAsStringSync(),
) as Map<String, dynamic>;

final int fixedNow = ref['fixedNow'] as int;

Object? _json(Object? v) => jsonDecode(jsonEncode(v));

List<Map<String, dynamic>> _rows(String key) => [
  for (final r in ref[key] as List) r as Map<String, dynamic>,
];

/// A save with nothing achieved, matching the dump script's own.
Map<String, dynamic> _blankState() => {
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

Map<String, dynamic> _card([Map<String, dynamic> over = const {}]) => {
  'instanceId': 'c0',
  'definitionId': 'player_t3_mid',
  'seasonsPlayed': 0,
  ...over,
};

Map<String, dynamic> _allAssetsOwned() => {
  for (final c in AssetCategory.all) c: {'owned': true, 'tier': 1},
};

/// The state patch that unlocks each achievement, mirroring the dump script's
/// `unlockers` table. Keyed by id so a new achievement with no case is REPORTED
/// rather than silently skipped.
final Map<String, Map<String, dynamic>> _unlockerStates = {
  'reach_amateur': {'progression': {'currentDivision': 'amateur_cup'}},
  'reach_regional': {'progression': {'currentDivision': 'regional_league'}},
  'reach_national': {'progression': {'currentDivision': 'national_league'}},
  'reach_elite': {'progression': {'currentDivision': 'elite_league'}},
  'reach_continental': {'progression': {'currentDivision': 'continental'}},
  'reach_champions': {'progression': {'currentDivision': 'champions_cup'}},
  'prestige_level_1': {'prestige': {'level': 1}},
  'prestige_level_3': {'prestige': {'level': 3}},
  'prestige_level_5': {'prestige': {'level': 5}},
  'prestige_level_10': {'prestige': {'level': 10}},

  'first_promotion': <String, dynamic>{},
  'relegated_once': <String, dynamic>{},
  'first_league_title': {
    'progression': {'leagueTrophies': [<String, dynamic>{}]},
  },
  'five_league_titles': {
    'progression': {
      'leagueTrophies': [
        for (var i = 0; i < 5; i++) <String, dynamic>{},
      ],
    },
  },
  'play_5_seasons': {'progression': {'seasonCount': 5}},
  'play_10_seasons': {'progression': {'seasonCount': 10}},
  'play_20_seasons': {'progression': {'seasonCount': 20}},
  'win_league_undefeated': <String, dynamic>{},

  'first_cup_win': {'careerStats': {'cupWins': 1}},
  'cup_treble': {'careerStats': {'cupWins': 3}},
  'cup_dynasty': {'careerStats': {'cupWins': 10}},

  'first_merge': <String, dynamic>{},
  'merge_50': {'careerStats': {'totalMerges': 50}},
  'merge_200': {'careerStats': {'totalMerges': 200}},
  'merge_500': {'careerStats': {'totalMerges': 500}},
  'merge_to_silver': {'stats': {'highestTier': 3}},
  'merge_to_gold': {'stats': {'highestTier': 5}},
  'merge_to_superstar': {'stats': {'highestTier': 6}},
  'merge_to_legend': {'stats': {'highestTier': 7}},
  'merge_to_world': {'stats': {'highestTier': 8}},

  'first_win': <String, dynamic>{},
  'win_25_matches': {'careerStats': {'matchesWon': 25}},
  'win_100_matches': {'careerStats': {'matchesWon': 100}},
  'win_500_matches': {'careerStats': {'matchesWon': 500}},
  'comeback_win': <String, dynamic>{},
  'tactician': <String, dynamic>{},
  'mind_games': <String, dynamic>{},
  'gaffers_call': <String, dynamic>{},
  'iron_curtain': <String, dynamic>{},

  'hard_debut': {'settings': {'hardMode': true}},
  'hard_first_win': {'settings': {'hardMode': true}},
  'hard_marathon': {
    'grid': {
      'cells': [
        {
          'instanceId': 'c0',
          'definitionId': 'player_t3_mid',
          'seasonsPlayed': 0,
          'trait': {'id': 'iron_lungs', 'level': 1},
        },
      ],
    },
  },
  'hard_title': {'settings': {'hardMode': true}},
  'hard_champions': {'settings': {'hardMode': true}},
  'hard_25_wins': {'careerStats': {'hardModeWins': 25}},
  'hard_100_wins': {'careerStats': {'hardModeWins': 100}},

  'use_veteran_7s': {
    'grid': {'cells': [{'instanceId': 'c0', 'definitionId': 'player_t3_mid', 'seasonsPlayed': 7}]},
  },
  'use_veteran_10s': {
    'grid': {'cells': [{'instanceId': 'c0', 'definitionId': 'player_t3_mid', 'seasonsPlayed': 10}]},
  },
  'full_squad_16': <String, dynamic>{},
  'first_sponsor': {
    'grid': {
      'cells': [
        {
          'instanceId': 'c0',
          'definitionId': 'player_t3_mid',
          'seasonsPlayed': 0,
          'sponsor': {'multiplier': 1.5},
        },
      ],
    },
  },
  'three_sponsors': <String, dynamic>{},
  'scout_25': {'stats': {'totalScouts': 25}},
  'scout_100': {'stats': {'totalScouts': 100}},

  'own_tier3_asset': {
    'clubAssets': {'TRAINING': {'owned': true, 'tier': 3}},
  },
  'own_tier6_asset': {
    'clubAssets': {'TRAINING': {'owned': true, 'tier': 6}},
  },
  'own_all_categories': <String, dynamic>{},

  'coins_10k': {'stats': {'maxCoinsReached': 10000}},
  'coins_100k': {'stats': {'maxCoinsReached': 100000}},
  'coins_1m': {'stats': {'maxCoinsReached': 1000000}},
  'coins_1b': {'stats': {'maxCoinsReached': 1000000000}},

  'first_transfer_accept': {'stats': {'transfersAccepted': 1}},
  'five_transfer_accept': {'stats': {'transfersAccepted': 5}},
  'first_transfer_decline': {'stats': {'transfersDeclined': 1}},
  'first_sponsor_decline': {'stats': {'sponsorsDeclined': 1}},
  'grudge_revenge': <String, dynamic>{},
  'sell_tier5_player': <String, dynamic>{},

  'penalty_perfect': {'stats': {'perfectPenalties': 1}},
  'penalty_ten_rounds': {'stats': {'penaltyRounds': 10}},
  'training_perfect': {'stats': {'perfectTrainings': 1}},
  'training_streak_10': {'dailyReward': {'longestStreak': 10}},
  'training_streak_30': {'dailyReward': {'longestStreak': 30}},
  'through_ball_perfect': {'stats': {'perfectThroughBalls': 1}},
  'whack_clean': {'stats': {'whackCleanRounds': 1}},
  'whack_dogs_10': {'stats': {'whackDogs': 10}},
  'boot_room_cascade': {'stats': {'bootRoomBestCascade': 4}},

  'wc_win': {
    'events': {
      'progress': {
        'wc2026': {
          'firstWin': {'playerNation': 'BRA'},
        },
      },
    },
  },

  'reset_first': {'stats': {'resetCount': 1}},
  'reset_with_legendary': {'stats': {'everHadLegendaryAtReset': true}},
  'reset_veteran': {'stats': {'maxSeasonsAtReset': 10}},
  'reset_top_division': {'stats': {'everResetFromTopDivision': true}},
  'reset_after_prestige': {'stats': {'maxPrestigeLevelAtReset': 1}},
};

/// The few cases whose state is easier built than written out.
Map<String, dynamic> _stateFor(String id) {
  final patch = _unlockerStates[id];
  if (patch == null) throw ArgumentError('no unlocker case for $id');
  final state = _deepMerge(_blankState(), patch);
  switch (id) {
    case 'full_squad_16':
      (state['grid'] as Map)['cells'] = [
        for (var i = 0; i < 16; i++) _card({'instanceId': 'c$i'}),
      ];
    case 'three_sponsors':
      (state['grid'] as Map)['cells'] = [
        for (var i = 0; i < 3; i++)
          _card({'instanceId': 'c$i', 'sponsor': {'multiplier': 1.5}}),
      ];
    case 'own_all_categories':
      state['clubAssets'] = _allAssetsOwned();
  }
  return state;
}

Map<String, dynamic> _deepMerge(
  Map<String, dynamic> base,
  Map<String, dynamic> patch,
) {
  patch.forEach((k, v) {
    final existing = base[k];
    if (v is Map<String, dynamic> && existing is Map<String, dynamic>) {
      _deepMerge(existing, v);
    } else {
      base[k] = jsonDecode(jsonEncode(v));
    }
  });
  return base;
}

/// The event a case fires with, read straight off the fixture so the two sides
/// cannot drift.
AchievementEvent _eventFrom(Map<String, dynamic> row) {
  final e = row['event'] as Map<String, dynamic>;
  return (type: '${e['type']}', data: e['data'] as Map<String, dynamic>?);
}

void main() {
  setUp(() => setClock(() => fixedNow));
  tearDown(() {
    resetClock();
    clearBus();
  });

  group('the catalogue', () {
    test('is the same set, in the same order, with the same fields', () {
      final want = ref['catalogue'] as List;
      expect(achievements, hasLength(81));
      expect(achievements, hasLength(want.length));
      for (var i = 0; i < achievements.length; i++) {
        final a = achievements[i];
        final w = want[i] as Map<String, dynamic>;
        final why = '${a.id} (index $i)';
        expect(a.id, w['id'], reason: why);
        expect(a.title, w['title'], reason: why);
        expect(a.description, w['description'], reason: why);
        expect(a.category, w['category'], reason: why);
        // Four of these are raw markup in the JS; the port names a drawn icon
        // instead and the KIND is what is compared.
        expect(
          a.iconAsset ?? 'emoji',
          w['iconKind'],
          reason: '$why — icon kind',
        );
        expect(a.icon, w['icon'], reason: '$why — emoji');
        expect(a.progress != null, w['hasProgress'], reason: why);
        expect(a.progressText != null, w['hasProgressText'], reason: why);
        expect(a.availability, w['availability'], reason: why);
        expect(a.availabilityKey, w['availabilityKey'], reason: why);
      }
    });

    test('every id is unique', () {
      final ids = achievements.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every achievement sits in a known category', () {
      for (final a in achievements) {
        expect(achievementCategories, contains(a.category), reason: a.id);
        expect(categoryLabels.keys, contains(a.category), reason: a.id);
      }
    });

    test('the categories and their labels match the JS', () {
      expect(achievementCategories, ref['categories']);
      expect(categoryLabels, ref['categoryLabels']);
      expect(AssetCategory.all.length, ref['assetCategoryCount']);
    });

    test('lookup by id matches the JS', () {
      expect(getAchievementDef('reach_amateur')?.id, ref['getByIdKnown']);
      expect(getAchievementDef('nope'), ref['getByIdUnknown']);
      expect(getAchievementDef(null), isNull);
    });

    test('every achievement has an unlocker case', () {
      // The fixture reports any the dump script had no case for; this reports any
      // THIS side is missing. Either way a new achievement cannot land untested.
      expect(ref['missingUnlockers'], isEmpty);
      final missing = [
        for (final a in achievements)
          if (!_unlockerStates.containsKey(a.id)) a.id,
      ];
      expect(missing, isEmpty);
    });
  });

  group('every predicate', () {
    test('fires for exactly the same ids the JS fires for', () {
      final rows = _rows('predicates');
      expect(rows, hasLength(81));
      for (final row in rows) {
        final id = '${row['id']}';
        final state = _stateFor(id);
        final unlocked = checkAchievements(state, _eventFrom(row))
            .map((a) => a.id)
            .toList()
          ..sort();
        expect(unlocked, row['unlocked'], reason: '$id — unlocked set');
        expect(unlocked.contains(id), row['firesForItself'], reason: id);

        // The reward each id paid, so the table is pinned with the predicates.
        final stored = (state['progression'] as Map)['achievements'] as List;
        expect(
          {
            for (final a in stored)
              '${(a as Map)['id']}': a['coinsRewarded'],
          },
          row['rewards'],
          reason: '$id — rewards',
        );
      }
    });

    test('none of them fires on a blank save', () {
      // A predicate too loose shows up here rather than as a trophy handed out for
      // nothing.
      for (final row in _rows('predicates')) {
        expect(row['blankUnlocks'], isEmpty);
      }
      final state = _blankState();
      expect(checkAchievements(state), isEmpty);
      expect(_json(state['progression']), {
        'currentDivision': 'sunday_league',
        'achievements': <Object?>[],
        'achievementIdsThisRun': <Object?>[],
      });
    });
  });

  group('near misses', () {
    /// The state patch each near-miss case was run with, mirroring the dump.
    Map<String, dynamic> stateFor(String label) {
      final patch = switch (label) {
        'hard win in casual mode' => {'settings': {'hardMode': false}},
        'hard title in casual mode' => {'settings': {'hardMode': false}},
        'hard champions from another division' => {'settings': {'hardMode': true}},
        'a tier below silver' => {'stats': {'highestTier': 2}},
        'one short of five titles' => {
          'progression': {
            'leagueTrophies': [for (var i = 0; i < 4; i++) <String, dynamic>{}],
          },
        },
        'one coin short of 10k' => {'stats': {'maxCoinsReached': 9999}},
        'an asset owned at a lower tier' => {
          'clubAssets': {'TRAINING': {'owned': true, 'tier': 2}},
        },
        'an asset at tier but NOT owned' => {
          'clubAssets': {'TRAINING': {'owned': false, 'tier': 9}},
        },
        'all categories but one' => {
          'clubAssets': {
            for (final c in AssetCategory.all.skip(1))
              c: {'owned': true, 'tier': 1},
          },
        },
        'a veteran one season short' => {
          'grid': {'cells': [_card({'seasonsPlayed': 6})]},
        },
        'fifteen players' => {
          'grid': {
            'cells': [
              for (var i = 0; i < 15; i++) _card({'instanceId': 'c$i'}),
            ],
          },
        },
        'a different trait' => {
          'grid': {
            'cells': [
              _card({'trait': {'id': 'tough', 'level': 1}}),
            ],
          },
        },
        'an unknown division' => {
          'progression': {'currentDivision': 'nonsense'},
        },
        _ => <String, dynamic>{},
      };
      return _deepMerge(_blankState(), patch);
    }

    test('an event that ALMOST matches unlocks exactly what the JS unlocks', () {
      // Without these, a predicate that drops one of its conditions still passes
      // every positive case — the clean sheet in iron_curtain, the half-time
      // deficit in comeback_win, and so on.
      final rows = _rows('nearMisses');
      expect(rows, hasLength(28));
      for (final row in rows) {
        final label = '${row['label']}';
        final unlocked = checkAchievements(stateFor(label), _eventFrom(row))
            .map((a) => a.id)
            .toList()
          ..sort();
        expect(unlocked, row['unlocked'], reason: label);
      }
    });

    test('a definition id of the wrong type is shrugged off', () {
      // The JS is untyped and simply finds nothing. A typed port throws on the
      // cast, which is exactly what the try/catch around each predicate is for —
      // the outcome has to be the same either way.
      final row = _rows('nearMisses')
          .firstWhere((r) => r['label'] == 'sold, definition id is a number');
      late List<UnlockedAchievement> got;
      expect(
        () => got = checkAchievements(_blankState(), _eventFrom(row)),
        returnsNormally,
      );
      expect(got.map((a) => a.id).toList(), row['unlocked']);
      expect(got, isEmpty);
    });
  });

  group('progress bars', () {
    test('match the JS on a blank save and on an unlocking one', () {
      // A wrong target reads as a goal that never fills.
      final rows = _rows('progress');
      expect(rows, hasLength(40));
      for (final row in rows) {
        final id = '${row['id']}';
        final def = getAchievementDef(id)!;
        expect(def.progress, isNotNull, reason: id);

        final onBlank = def.progress!(_blankState());
        final wantBlank = row['onBlank'] as Map<String, dynamic>;
        expect(onBlank.current, wantBlank['current'], reason: '$id — blank');
        expect(onBlank.target, wantBlank['target'], reason: '$id — blank');

        final onUnlocking = def.progress!(_stateFor(id));
        final wantUnlocking = row['onUnlocking'] as Map<String, dynamic>;
        expect(
          onUnlocking.current,
          wantUnlocking['current'],
          reason: '$id — unlocking',
        );
        expect(
          onUnlocking.target,
          wantUnlocking['target'],
          reason: '$id — unlocking',
        );

        if (row['text'] != null) {
          expect(def.progressText, isNotNull, reason: id);
          expect(
            def.progressText!(_stateFor(id)),
            row['text'],
            reason: '$id — label',
          );
        }
      }
    });
  });

  group('the engine', () {
    test('a blank boot unlocks nothing and stores nothing', () {
      final want = ref['blankBoot'] as Map<String, dynamic>;
      final state = _blankState();
      expect(checkAchievements(state).map((a) => a.id).toList(), want['unlocked']);
      expect(
        _json((state['progression'] as Map)['achievements']),
        want['stored'],
      );
    });

    test('running twice does not pay twice', () {
      final want = ref['idempotent'] as Map<String, dynamic>;
      final state = _deepMerge(_blankState(), {
        'progression': {'currentDivision': 'champions_cup'},
      });
      final first = checkAchievements(state).map((a) => a.id).toList()..sort();
      final second = checkAchievements(state).map((a) => a.id).toList();
      expect(first, want['first']);
      expect(second, want['second']);
      expect(second, isEmpty);
      expect(
        _json((state['progression'] as Map)['achievements']),
        want['stored'],
      );
      expect(
        _json((state['progression'] as Map)['achievementIdsThisRun']),
        want['thisRun'],
      );
    });

    test('an achievement earned in an earlier run does NOT re-unlock', () {
      // The engine keeps a per-run list cleared on reset, and a branch that
      // increments a count when an id fires again — but the ever-unlocked guard
      // makes that branch unreachable, so nothing re-fires and no count moves.
      // This pins the JS behaviour, NOT the intent. See docs/REMAINING.md.
      final want = ref['afterReset'] as Map<String, dynamic>;
      final state = _deepMerge(_blankState(), {
        'progression': {
          'currentDivision': 'amateur_cup',
          'achievements': [
            {
              'id': 'reach_amateur',
              'unlockedAt': 1,
              'coinsRewarded': 200,
              'count': 1,
            },
          ],
          'achievementIdsThisRun': <Object?>[],
        },
      });
      final got = checkAchievements(state);
      expect(
        [
          for (final a in got)
            {'id': a.id, 'isReUnlock': a.isReUnlock, 'count': a.count},
        ],
        want['unlocked'],
      );
      expect(got, isEmpty);
      expect(
        _json((state['progression'] as Map)['achievements']),
        want['stored'],
      );
    });

    test('a wrecked bucket is repaired, keeping the highest count', () {
      final state = _deepMerge(_blankState(), {
        'progression': {
          'achievements': [
            {'id': 'dup', 'unlockedAt': 1, 'count': 1},
            {'id': 'dup', 'unlockedAt': 2, 'count': 4},
            {'id': 'dup', 'unlockedAt': 3, 'count': 2},
            null,
            {'noId': true},
          ],
        },
      });
      checkAchievements(state);
      expect(
        _json((state['progression'] as Map)['achievements']),
        ref['dedupe'],
      );
    });

    test('a predicate that throws is treated as not met', () {
      // Eighty of these run on boot, and one bad read on a half-migrated save must
      // not stop the app starting.
      final want = ref['throwingCheck'] as Map<String, dynamic>;
      final state = _blankState();
      state['grid'] = {'cells': null};
      late List<UnlockedAchievement> got;
      expect(() => got = checkAchievements(state), returnsNormally);
      expect(want['threw'], isFalse);
      expect(got.map((a) => a.id).toList(), want['unlocked']);
    });

    test('a null save is a no-op', () {
      expect(checkAchievements(null), ref['nullState']);
      expect(checkAchievements(null), isEmpty);
    });

    test('getUnlockedIds reads the bucket', () {
      final state = _deepMerge(_blankState(), {
        'progression': {
          'achievements': [
            {'id': 'a'},
            {'id': 'b'},
          ],
        },
      });
      expect((getUnlockedIds(state).toList()..sort()), ref['getUnlockedIds']);
      expect(getUnlockedIds(null), isEmpty);
    });

    test('builds the branch on a save that has none', () {
      final state = <String, dynamic>{};
      expect(() => checkAchievements(state), returnsNormally);
      final prog = state['progression'] as Map;
      expect(prog['achievements'], isEmpty);
      expect(prog['achievementIdsThisRun'], isEmpty);
    });
  });
}
