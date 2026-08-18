/// The mini-games engine, against the JS it was ported from.
///
/// Two things here are worth pinning rather than eyeballing. Cooldowns do NOT
/// end one cooldown after the tap — the ready time is snapped UP to a shared
/// 30-second grid, so a port that subtracts naively is wrong by up to thirty
/// seconds every time, in the player's favour or against it depending on when
/// they played. And every payout runs the division's tapered base through two
/// club-asset multipliers before rounding, which is four chances to land a
/// number that looks plausible and is not what the JS pays.
///
/// See `tool/dump_mini_games_reference.mjs`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/util/time.dart';

final Map<String, dynamic> _ref =
    jsonDecode(
          File('test/fixtures/mini_games_reference.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

List<Map<String, dynamic>> _rows(String key) => [
  for (final r in _ref[key] as List) r as Map<String, dynamic>,
];

Map<String, dynamic> _section(String key) => _ref[key] as Map<String, dynamic>;

/// The state the reference was generated against.
Map<String, dynamic> _state({
  String division = 'sunday_league',
  int trainingTier = 0,
  int mediaTier = 0,
  bool stats = true,
  int energyCurrent = 0,
  Map<String, dynamic>? miniGames,
}) {
  final state = <String, dynamic>{
    'resources': <String, dynamic>{'fanCoins': 0, 'gems': 0, 'trophies': 0},
    'energy': <String, dynamic>{'current': energyCurrent, 'lastRegenAt': 0},
    'shop': <String, dynamic>{},
    'progression': <String, dynamic>{'currentDivision': division},
    'clubAssets': <String, dynamic>{
      'TRAINING': <String, dynamic>{
        'owned': trainingTier > 0,
        'tier': trainingTier,
        'invested': 0,
        'tapCount': 0,
      },
      'MEDIA': <String, dynamic>{
        'owned': mediaTier > 0,
        'tier': mediaTier,
        'invested': 0,
        'tapCount': 0,
      },
    },
  };
  if (stats) state['stats'] = <String, dynamic>{};
  if (miniGames != null) state['miniGames'] = miniGames;
  return state;
}

const _lastPlayedKeys = {
  MiniGameKind.penalty: 'penaltyLastPlayed',
  MiniGameKind.training: 'trainingLastPlayed',
  MiniGameKind.keepyUppys: 'keepyUppysLastPlayed',
  MiniGameKind.throughBall: 'throughBallLastPlayed',
  MiniGameKind.whack: 'whackLastPlayed',
  MiniGameKind.pairs: 'pairsLastPlayed',
  MiniGameKind.bootRoom: 'bootRoomLastPlayed',
};

/// Run [body] with the clock pinned to [at].
void _at(int at, void Function() body) {
  setClock(() => at);
  try {
    body();
  } finally {
    resetClock();
  }
}

void main() {
  setUp(() => setClock(() => 0));
  tearDown(resetClock);

  test('the ladder is the skip list', () {
    expect(MiniGameKind.all, _ref['skipKinds']);
    expect(skipKinds, _ref['skipKinds']);
  });

  test('parity — the reward base, across divisions and Media tiers', () {
    for (final row in _rows('rewardBase')) {
      expect(
        miniGameRewardBase(
          _state(
            division: row['division'] as String,
            mediaTier: row['mediaTier'] as int,
          ),
        ),
        row['base'],
        reason: '${row['division']} media ${row['mediaTier']}',
      );
    }
  });

  test('parity — cooldowns after the Training Ground discount', () {
    for (final row in _rows('effectiveCooldowns')) {
      expect(
        effectiveMiniGameCooldown(
          _state(trainingTier: row['trainingTier'] as int),
          row['kind'] as String,
        ),
        row['ms'],
        reason: '${row['kind']} tier ${row['trainingTier']}',
      );
    }
  });

  test('parity — readiness lands on the 30-second grid', () {
    for (final row in _rows('readiness')) {
      final kind = row['kind'] as String;
      final trainingTier = row['trainingTier'] as int;
      final lastPlayed = row['lastPlayed'] as int;
      final cooldown = effectiveMiniGameCooldown(
        _state(trainingTier: trainingTier),
        kind,
      );
      final readyAt = ((lastPlayed + cooldown) / 30000).ceil() * 30000;
      _at(readyAt + (row['offset'] as int), () {
        final state = _state(
          trainingTier: trainingTier,
          miniGames: <String, dynamic>{_lastPlayedKeys[kind]!: lastPlayed},
        );
        expect(
          miniGameReady(state, kind),
          row['ready'],
          reason:
              '$kind tier $trainingTier last $lastPlayed '
              'offset ${row['offset']}',
        );
      });
    }
  });

  test('parity — how long is left', () {
    _at(400000, () {
      for (final row in _rows('msUntil')) {
        final state = _state(
          miniGames: <String, dynamic>{
            for (final key in _lastPlayedKeys.values) key: 100000,
          },
        );
        expect(
          msUntilMiniGame(state, row['kind'] as String),
          row['ms'],
          reason: '${row['kind']}',
        );
      }
    });
  });

  test('parity — an unknown kind is nothing to wait for', () {
    final want = _section('unknownKind');
    final state = _state();
    startMiniGame(state, 'not_a_game');
    resetMiniGameCooldown(state, 'not_a_game');
    expect(miniGameReady(state, 'not_a_game'), want['ready']);
    expect(state['miniGames'], want['miniGames']);
    expect(msUntilMiniGame(state, 'not_a_game'), 0);
  });

  group('parity — the miniGames branch', () {
    test('is created whole, in the JS key order', () {
      // The order is what the save writes, so the two keys the schema knows
      // about come first and the five back-filled later follow.
      final want =
          _section('ensureBranch')['fromNothing'] as Map<String, dynamic>;
      final state = _state();
      _at(5000, () => startMiniGame(state, MiniGameKind.penalty));
      final mg = state['miniGames'] as Map<String, dynamic>;
      expect(mg.keys.toList(), want['keys']);
      expect(mg, want['values']);
    });

    test('back-fills the five the schema does not write', () {
      final want =
          _section('ensureBranch')['fromSchemaPair'] as Map<String, dynamic>;
      final state = _state(
        miniGames: <String, dynamic>{
          'penaltyLastPlayed': 7,
          'trainingLastPlayed': 9,
        },
      );
      startMiniGame(state, MiniGameKind.bootRoom);
      final mg = state['miniGames'] as Map<String, dynamic>;
      expect(mg.keys.toList(), want['keys']);
      expect(mg, want['values']);
    });
  });

  test('parity — starting stamps the clock, the skip winds it back', () {
    final want = _section('startAndReset');
    final state = _state();
    _at(1234567, () {
      for (final kind in MiniGameKind.all) {
        startMiniGame(state, kind);
      }
      expect(state['miniGames'], want['started']);
      for (final kind in MiniGameKind.all) {
        resetMiniGameCooldown(state, kind);
      }
      expect(state['miniGames'], want['reset']);
    });
  });

  test('parity — only games the player OWNS count toward the skip', () {
    for (final row in _rows('allOnCooldown')) {
      _at(1000000, () {
        final state = _state(trainingTier: row['trainingTier'] as int);
        if (row['played'] == true) {
          for (final kind in MiniGameKind.all) {
            startMiniGame(state, kind);
          }
        }
        final reason = 'tier ${row['trainingTier']} played ${row['played']}';
        expect(
          getUnlockedMinigames(state['clubAssets'] as Map<String, dynamic>),
          row['unlocked'],
          reason: reason,
        );
        expect(allMiniGamesOnCooldown(state), row['all'], reason: reason);
        expect(shouldPrefetchSkipAd(state), row['prefetch'], reason: reason);
      });
    }
  });

  test('parity — the free-skip ledger', () {
    final want = _section('skipLedger');
    final today = want['today'] as String;
    const yesterday = 'Mon Aug 17 2026';
    final state = _state();
    final steps = (want['steps'] as List).cast<Map<String, dynamic>>();

    void check(int i) {
      expect(
        skipAdsUsedToday(state, today),
        steps[i]['used'],
        reason: '${steps[i]['label']} used',
      );
      expect(
        skipAdsLeftToday(state, today),
        steps[i]['left'],
        reason: '${steps[i]['label']} left',
      );
      expect(
        state['shop'],
        steps[i]['shop'],
        reason: '${steps[i]['label']} shop',
      );
    }

    check(0);
    recordSkipAd(state, today);
    check(1);
    recordSkipAd(state, today);
    recordSkipAd(state, today);
    check(2);
    // Past the cap the button reprices to gems rather than dying, so the count
    // keeps climbing and only `left` floors at zero.
    recordSkipAd(state, today);
    check(3);
    (state['shop'] as Map)['skipAdDay'] = yesterday;
    (state['shop'] as Map)['skipAdCount'] = 3;
    check(4);
    recordSkipAd(state, today);
    check(5);

    final noShop = _state();
    noShop.remove('shop');
    recordSkipAd(noShop, today);
    expect(noShop['shop'], want['noShopBranch']);
  });

  group('parity — banking a session', () {
    /// Replay one reference row and compare everything the session touched.
    void expectRow(
      Map<String, dynamic> row,
      Object? Function(Map<String, dynamic> state) play, {
      bool stats = true,
      int energyCurrent = 0,
    }) {
      final label =
          '${row['label']} ${row['division']} media ${row['mediaTier']}';
      _at(9000000, () {
        final state = _state(
          division: row['division'] as String,
          mediaTier: row['mediaTier'] as int,
          stats: stats,
          energyCurrent: energyCurrent,
        );
        final returned = play(state);
        final want = row['returned'];
        if (want is Map && want.containsKey('hitTarget')) {
          final got = returned as ({int coins, bool hitTarget});
          expect(got.coins, want['coins'], reason: '$label coins');
          expect(got.hitTarget, want['hitTarget'], reason: '$label hitTarget');
        } else if (want is Map && want.containsKey('energyGranted')) {
          final got = returned as ({int coins, int energyGranted});
          expect(got.coins, want['coins'], reason: '$label coins');
          expect(
            got.energyGranted,
            want['energyGranted'],
            reason: '$label energyGranted',
          );
        } else if (want is Map) {
          // The single-number games hand back the coins directly; the JS wrapped
          // them in a one-key object.
          expect(returned, want['coins'], reason: '$label returned');
        } else {
          expect(returned, want, reason: '$label returned');
        }
        expect(
          (state['resources'] as Map)['fanCoins'],
          row['coins'],
          reason: '$label banked',
        );
        expect(state['stats'], row['stats'], reason: '$label stats');
        expect(
          state['miniGames'],
          row['miniGames'],
          reason: '$label miniGames',
        );
        expect(state['energy'], row['energy'], reason: '$label energy');
      });
    }

    const whackOpts = {
      'clean': (catches: 12, fouls: 0, dogs: 2),
      'fouled': (catches: 12, fouls: 1, dogs: 2),
      'blank': (catches: 0, fouls: 0, dogs: 0),
      'negative': (catches: -4, fouls: 0, dogs: -2),
      'fractional': (catches: 7.9, fouls: 0, dogs: 1.9),
      'media6': (catches: 20, fouls: 0, dogs: 3),
    };

    test('pitch invaders', () {
      for (final row in _rows('whack')) {
        final opts = whackOpts[row['label']];
        expectRow(
          row,
          (s) => opts == null
              ? recordWhackResult(s)
              : recordWhackResult(
                  s,
                  catches: opts.catches,
                  fouls: opts.fouls,
                  dogs: opts.dogs,
                ),
        );
      }
    });

    const bootRoomOpts = {
      'hitTarget': (tilesCleared: 90, target: 88, bestCascade: 7),
      'missedTarget': (tilesCleared: 40, target: 88, bestCascade: 3),
      'noTarget': (tilesCleared: 40, target: 0, bestCascade: 0),
    };

    test('boot room', () {
      for (final row in _rows('bootRoom')) {
        final opts = bootRoomOpts[row['label']];
        expectRow(
          row,
          (s) => opts == null
              ? recordBootRoomResult(s)
              : recordBootRoomResult(
                  s,
                  tilesCleared: opts.tilesCleared,
                  target: opts.target,
                  bestCascade: opts.bestCascade,
                ),
        );
      }
    });

    const pairsOpts = {
      'cleared': (pairsMatched: 6, totalPairs: 6, cleared: true),
      'partial': (pairsMatched: 3, totalPairs: 6, cleared: false),
      'overMatched': (pairsMatched: 9, totalPairs: 6, cleared: false),
    };

    test('pairs', () {
      for (final row in _rows('pairs')) {
        final opts = pairsOpts[row['label']];
        expectRow(
          row,
          (s) => opts == null
              ? recordPairsResult(s)
              : recordPairsResult(
                  s,
                  pairsMatched: opts.pairsMatched,
                  totalPairs: opts.totalPairs,
                  cleared: opts.cleared,
                ),
        );
      }
    });

    const keepyUppysTaps = {'long': 47, 'fractional': 12.7, 'negative': -3};

    test('keepy uppys', () {
      for (final row in _rows('keepyUppys')) {
        final taps = keepyUppysTaps[row['label']];
        expectRow(
          row,
          (s) => taps == null
              ? recordKeepyUppysResult(s)
              : recordKeepyUppysResult(s, taps: taps),
        );
      }
    });

    const throughBallRounds = {'perfect': 5, 'partial': 2, 'overRun': 9};

    test('through ball', () {
      for (final row in _rows('throughBall')) {
        final passed = throughBallRounds[row['label']];
        expectRow(
          row,
          (s) => passed == null
              ? recordThroughBallResult(s)
              : recordThroughBallResult(s, roundsPassed: passed),
        );
      }
    });

    const penaltyOpts = {
      'perfect': (scored: 5, total: 5),
      'partial': (scored: 2, total: 5),
      'overScored': (scored: 9, total: 5),
      'shortRound': (scored: 3, total: 3),
      'noStatsBranch': (scored: 5, total: 5),
    };

    test('penalty training', () {
      for (final row in _rows('penalty')) {
        final opts = penaltyOpts[row['label']];
        expectRow(
          row,
          (s) => opts == null
              ? recordPenaltyResult(s)
              : recordPenaltyResult(s, scored: opts.scored, total: opts.total),
          // Alone in the family, penalty will not CREATE the stats branch.
          stats: row['label'] != 'noStatsBranch',
        );
      }
    });

    const trainingOpts = {
      'perfect': (drillsHit: 8, drillTotal: 8),
      'partial': (drillsHit: 3, drillTotal: 8),
      'overHit': (drillsHit: 99, drillTotal: 8),
      'zeroTotal': (drillsHit: 4, drillTotal: 0),
      'upgradedTank': (drillsHit: 4, drillTotal: 4),
      'noStatsBranch': (drillsHit: 4, drillTotal: 4),
    };

    test('goalkeeper practice', () {
      for (final row in _rows('training')) {
        final opts = trainingOpts[row['label']];
        expectRow(
          row,
          (s) => opts == null
              ? recordTrainingComplete(s)
              : recordTrainingComplete(
                  s,
                  drillsHit: opts.drillsHit,
                  drillTotal: opts.drillTotal,
                ),
          stats: row['label'] != 'noStatsBranch',
          // The grant is zero, so the only thing the energy line does with a
          // fifteen-pip tank is clamp it back to ten. See the carried-over bug
          // in docs/REMAINING.md.
          energyCurrent: row['label'] == 'upgradedTank' ? 15 : 0,
        );
      }
    });

    test('counters accumulate, and the best-of ones only climb', () {
      final want = _section('repeated');
      _at(9000000, () {
        final state = _state(division: 'regional_league');
        recordWhackResult(state, catches: 10, fouls: 0, dogs: 1);
        recordWhackResult(state, catches: 4, fouls: 2, dogs: 0);
        recordKeepyUppysResult(state, taps: 30);
        recordKeepyUppysResult(state, taps: 12);
        recordBootRoomResult(
          state,
          tilesCleared: 90,
          target: 88,
          bestCascade: 9,
        );
        recordBootRoomResult(
          state,
          tilesCleared: 20,
          target: 88,
          bestCascade: 2,
        );
        recordPenaltyResult(state, scored: 5, total: 5);
        recordPenaltyResult(state, scored: 1, total: 5);
        expect((state['resources'] as Map)['fanCoins'], want['coins']);
        expect(state['stats'], want['stats']);
      });
    });
  });

  group('what lands in the save', () {
    test('every payout is a whole number of coins', () {
      _at(9000000, () {
        final state = _state(division: 'elite_league', mediaTier: 4);
        recordWhackResult(state, catches: 7, dogs: 1);
        recordBootRoomResult(state, tilesCleared: 51, target: 50);
        recordPairsResult(state, pairsMatched: 5, totalPairs: 6);
        recordKeepyUppysResult(state, taps: 23);
        recordThroughBallResult(state, roundsPassed: 3);
        recordPenaltyResult(state, scored: 4);
        recordTrainingComplete(state, drillsHit: 5, drillTotal: 7);
        expect((state['resources'] as Map)['fanCoins'], isA<int>());
        expect(() => jsonEncode(state), returnsNormally);
      });
    });

    test('a save with no branches at all still banks', () {
      _at(9000000, () {
        final state = <String, dynamic>{};
        expect(recordWhackResult(state, catches: 5), isA<int>());
        // No division to read, so the base falls through to the ladder's first
        // rung — 100, the same as Sunday League — rather than to nothing.
        expect((state['resources'] as Map)['fanCoins'], 60);
        expect(() => jsonEncode(state), returnsNormally);
      });
    });

    test('the default ledger day comes off the pinned clock', () {
      // `today` defaults to the wall clock through the same seam every engine
      // reads, which is what makes the daily reset testable at all.
      _at(DateTime(2026, 8, 18, 12).millisecondsSinceEpoch, () {
        final state = _state();
        recordSkipAd(state);
        expect((state['shop'] as Map)['skipAdDay'], 'Tue Aug 18 2026');
        expect(skipAdsUsedToday(state), 1);
        expect(skipAdsLeftToday(state), 2);
      });
      // A different day reads the same ledger as spent by somebody else.
      _at(DateTime(2026, 8, 19, 12).millisecondsSinceEpoch, () {
        final state = _state();
        (state['shop'] as Map)['skipAdDay'] = 'Tue Aug 18 2026';
        (state['shop'] as Map)['skipAdCount'] = 3;
        expect(skipAdsUsedToday(state), 0);
        expect(skipAdsLeftToday(state), 3);
      });
    });

    test('training on a save with no energy branch creates one', () {
      // The JS reads `state.energy.current` unguarded and would throw here. The
      // port creates the branch instead, which cannot change behaviour on a save
      // that has one — and the schema always writes it.
      _at(9000000, () {
        final state = _state();
        state.remove('energy');
        final result = recordTrainingComplete(
          state,
          drillsHit: 4,
          drillTotal: 4,
        );
        expect(result.energyGranted, 0);
        expect((state['energy'] as Map)['current'], 0);
      });
    });

    test('a null state reads as no skips spent', () {
      expect(skipAdsUsedToday(null, 'Tue Aug 18 2026'), 0);
      expect(skipAdsLeftToday(null, 'Tue Aug 18 2026'), 3);
    });
  });
}
