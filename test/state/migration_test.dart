import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/state/migration.dart';
import 'package:merge_empire_fc/state/save_codec.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic> _clone(Map<String, dynamic> m) =>
    jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

/// Deeply retypes a Dart literal into the shapes a JSON decode produces:
/// `Map<String, dynamic>` and `List<dynamic>`.
///
/// Real saves always arrive through `jsonDecode`, so a test that hands
/// migration a `List<Map<String, dynamic>>` is testing a shape that can never
/// occur — and would hide a genuine failure to append nulls when padding.
/// Done by hand rather than via jsonEncode so NaN and Infinity survive.
dynamic _dyn(Object? v) {
  if (v is Map) {
    return <String, dynamic>{
      for (final e in v.entries) e.key.toString(): _dyn(e.value),
    };
  }
  if (v is List) return <dynamic>[for (final e in v) _dyn(e)];
  return v;
}

/// A minimal legacy save — just a version and whatever the test needs.
Map<String, dynamic> _legacy([Map<String, dynamic> extra = const {}]) =>
    _dyn({'version': 1, ...extra}) as Map<String, dynamic>;

void main() {
  setUp(() {
    resetMigrationRandom();
    resetClock();
    seeded.setSeed(12345);
  });

  group('version gating', () {
    test('a null save migrates to null', () {
      expect(migrate(null), isNull);
    });

    test('a save with no version is rejected', () {
      expect(migrate(<String, dynamic>{}), isNull);
      expect(migrate({'version': 0}), isNull);
    });

    test('a save from a NEWER build is rejected, not downgraded', () {
      // Downgrading would silently discard fields this build knows nothing
      // about — the save must be preserved untouched instead.
      expect(migrate({'version': saveVersion + 1}), isNull);
    });

    test('a current-version save is accepted', () {
      expect(migrate({'version': saveVersion}), isNotNull);
    });
  });

  group('a fresh v7 save', () {
    test('migrates without losing or changing any real field', () {
      final fresh = createDefaultState();
      final before = _clone(fresh);
      final after = migrate(fresh)!;

      // Migration adds its own one-time flags, and builds the lineup a fresh
      // save leaves null — the JS does the same. Nothing else may differ.
      for (final key in before.keys) {
        // squad: the lineup is built. leaderboard: a save with no lbSchema is
        // forced onto the current schema. Both are asserted below.
        if (key == 'squad' || key == 'leaderboard') continue;
        expect(
          jsonEncode(after[key]),
          jsonEncode(before[key]),
          reason: 'migration changed "$key" on a fresh save',
        );
      }

      // Legitimate change one: an empty XI of the right shape.
      final lineup = (after['squad'] as Map)['lineup'] as List;
      expect(lineup.length, 11);
      expect(
        lineup.every((s) => (s as Map)['cardInstanceId'] == null),
        isTrue,
      );

      // Legitimate change two: the leaderboard is stamped with the current
      // schema and queued for a reseed. Every pre-existing field survives.
      final lb = after['leaderboard'] as Map;
      expect(lb['lbSchema'], 4);
      expect(lb['careerSeeded'], isFalse);
      expect(lb['pendingWrites'], isEmpty);
      for (final e in (before['leaderboard'] as Map).entries) {
        if (e.key == 'careerSeeded') continue;
        expect(lb[e.key], e.value, reason: 'leaderboard.${e.key}');
      }
    });

    test('is still losslessly encodable afterwards', () {
      final migrated = migrate(createDefaultState())!;
      expect(SaveCodec.isLossless(SaveCodec.encode(migrated)), isTrue);
    });

    test('only adds the expected one-time flags', () {
      final fresh = createDefaultState();
      final before = fresh.keys.toSet();
      final after = migrate(fresh)!.keys.toSet();

      expect(after.difference(before), {
        '_nameOrderFix2026',
        '_fanZoneGrandfathered',
        '_tapCountReset2025',
        '_ratingBandsReseed2026',
        '_fatigueTwoLayerReseed',
        '_prestigePoints2026',
      });
    });
  });

  group('idempotency', () {
    test('migrating twice equals migrating once', () {
      // Every back-fill must be safe to re-run: this is the boot path.
      final once = migrate(createDefaultState())!;
      final snapshot = jsonEncode(once);
      final twice = migrate(_clone(once))!;
      expect(jsonEncode(twice), snapshot);
    });

    test('a legacy save converges after one pass', () {
      final legacy = _legacy({
        'resources': {'fanCoins': 500, 'gems': 3},
        'grid': {
          'cells': [
            {'definitionId': 'player_t3_mid', 'instanceId': 'a'},
          ],
        },
        'progression': {'currentDivision': 'regional_league', 'seasonCount': 4},
      });

      final once = migrate(legacy)!;
      final snapshot = jsonEncode(once);
      expect(jsonEncode(migrate(_clone(once))!), snapshot);
    });
  });

  group('load-boundary sanitisation', () {
    test('a non-list grid becomes an empty list', () {
      final s = migrate(_legacy({'grid': {'cells': 'corrupt'}}))!;
      expect((s['grid'] as Map)['cells'], isA<List<dynamic>>());
    });

    test('a NaN coin balance is zeroed rather than poisoning income', () {
      final s = migrate(_legacy({'resources': {'fanCoins': double.nan}}))!;
      // Zeroed, then restored to the starting float because there are no
      // players — a broken start, not a hard-earned bankruptcy.
      expect((s['resources'] as Map)['fanCoins'], startingCoins);
    });

    test('an infinite coin balance is rejected', () {
      final s = migrate(
        _legacy({
          'resources': {'fanCoins': double.infinity},
          'grid': {'cells': [{'definitionId': 'player_t1_fwd', 'instanceId': 'a'}]},
        }),
      )!;
      expect((s['resources'] as Map)['fanCoins'], 0);
    });

    test('a negative coin balance is rejected', () {
      final s = migrate(
        _legacy({
          'resources': {'fanCoins': -500},
          'grid': {'cells': [{'definitionId': 'player_t1_fwd', 'instanceId': 'a'}]},
        }),
      )!;
      expect((s['resources'] as Map)['fanCoins'], 0);
    });

    test('a negative or NaN gem balance is floored to zero, never minted', () {
      for (final bad in [double.nan, double.infinity, -5]) {
        // Sanitisation zeroes it; the tutorial retro-pay then tops a
        // zero balance back up to the grant, which is correct — the point is
        // that the corrupt value never survives as currency.
        final s = migrate(
          _legacy({
            'tutorial': {'done': false, 'step': 1},
            'resources': {'fanCoins': 10, 'gems': bad},
          }),
        )!;
        expect((s['resources'] as Map)['gems'], 0, reason: '$bad');
      }
    });

    test('a fractional gem balance floors to a clean int', () {
      final s = migrate(_legacy({'resources': {'fanCoins': 10, 'gems': 3.9}}))!;
      expect((s['resources'] as Map)['gems'], 3);
    });

    test('a broke save WITH players keeps its zero balance', () {
      final s = migrate(
        _legacy({
          'resources': {'fanCoins': 0},
          'grid': {'cells': [{'definitionId': 'player_t1_fwd', 'instanceId': 'a'}]},
        }),
      )!;
      expect((s['resources'] as Map)['fanCoins'], 0);
    });
  });

  group('grid cards', () {
    Map<String, dynamic> withCard(Map<String, dynamic> card) =>
        _legacy({'grid': {'cells': [card]}});

    test('pads the grid to the current size', () {
      final s = migrate(withCard({'definitionId': 'player_t1_fwd', 'instanceId': 'a'}))!;
      expect(((s['grid'] as Map)['cells'] as List).length, Grid.totalCells);
    });

    test('back-fills variant, form, stats and energy', () {
      final s = migrate(withCard({'definitionId': 'player_t5_fwd', 'instanceId': 'a'}))!;
      final card = ((s['grid'] as Map)['cells'] as List).first as Map;

      expect(card['variant'], isA<int>());
      expect(card['form'], 0);
      expect(card['stats'], {
        'goals': 0,
        'assists': 0,
        'tackles': 0,
        'saves': 0,
        'matchesPlayed': 0,
      });
      expect(card['energy'], isNotNull);
      expect(card['energyUpdatedAt'], isNotNull);
    });

    test('repairs a partially-formed stats object', () {
      final s = migrate(
        withCard({
          'definitionId': 'player_t1_fwd',
          'instanceId': 'a',
          'stats': {'goals': 5, 'assists': 'corrupt'},
        }),
      )!;
      final stats = (((s['grid'] as Map)['cells'] as List).first as Map)['stats'] as Map;
      expect(stats['goals'], 5);
      expect(stats['assists'], 0);
    });

    test('clamps seasonsPlayed inflated by the old season-end bug', () {
      final s = migrate(
        _legacy({
          'grid': {
            'cells': [
              {'definitionId': 'player_t1_fwd', 'instanceId': 'a', 'seasonsPlayed': 99},
            ],
          },
          'progression': {'seasonCount': 3},
        }),
      )!;
      expect((((s['grid'] as Map)['cells'] as List).first as Map)['seasonsPlayed'], 3);
    });

    test('re-runs the name whitelist on load', () {
      // A save can arrive from cloud sync or a hand-edited store, so sanitised
      // has to be an invariant of the state, not just of the rename sheet.
      final s = migrate(
        withCard({
          'definitionId': 'player_t1_fwd',
          'instanceId': 'a',
          'customName': '<script>evil',
        }),
      )!;
      final card = ((s['grid'] as Map)['cells'] as List).first as Map;
      expect(card['customName'], 'script evil');
    });

    test('drops a custom name that sanitises to nothing', () {
      final s = migrate(
        withCard({
          'definitionId': 'player_t1_fwd',
          'instanceId': 'a',
          'customName': '<<>>',
        }),
      )!;
      final card = ((s['grid'] as Map)['cells'] as List).first as Map;
      expect(card.containsKey('customName'), isFalse);
    });

    test('recomputes display names once for the 2026 name-order fix', () {
      final s = migrate(
        withCard({
          'definitionId': 'player_t1_fwd',
          'instanceId': 'a',
          'variant': 0,
          'displayName': 'Flash Rodrigo', // old order
        }),
      )!;
      final card = ((s['grid'] as Map)['cells'] as List).first as Map;
      expect(card['displayName'], 'Rodrigo Flash');
      expect(s['_nameOrderFix2026'], isTrue);
    });

    test('back-fills a per-instance attack ratio', () {
      final s = migrate(withCard({'definitionId': 'player_t5_gk', 'instanceId': 'a'}))!;
      final card = ((s['grid'] as Map)['cells'] as List).first as Map;
      expect(card['attackRatio'], isNotNull);
      expect(card['attackRatio'], inInclusiveRange(0.0, 0.05));
    });
  });

  group('club assets', () {
    test('converts the legacy cell grid to fixed assets', () {
      final s = migrate(
        _legacy({
          'clubAssets': {
            'cells': [
              {'definitionId': 'stadium_t3'},
              {'definitionId': 'stadium_t1'},
              {'definitionId': 'merch_t2'},
            ],
          },
        }),
      )!;
      final assets = s['clubAssets'] as Map;
      expect((assets['STADIUM'] as Map)['tier'], 3);
      expect((assets['STADIUM'] as Map)['owned'], isTrue);
      expect((assets['MERCH'] as Map)['tier'], 2);
      expect((assets['MEDIA'] as Map)['owned'], isFalse);
    });

    test('every category is present after migration', () {
      final s = migrate(_legacy())!;
      expect((s['clubAssets'] as Map).keys, AssetCategory.all);
    });

    test('grandfathers a Fan Zone at the Stadium tier, exactly once', () {
      // Without this every existing save silently drops from up to +4 home
      // advantage to +1 — a nerf nobody asked for.
      final save = _legacy({
        'clubAssets': {
          for (final c in AssetCategory.all)
            c: {'owned': false, 'tier': 0, 'invested': 0, 'tapCount': 0},
        },
      });
      (((save['clubAssets'] as Map)['STADIUM']) as Map)
        ..['owned'] = true
        ..['tier'] = 5;

      final s = migrate(save)!;
      expect(((s['clubAssets'] as Map)['FANZONE'] as Map)['owned'], isTrue);
      expect(((s['clubAssets'] as Map)['FANZONE'] as Map)['tier'], 5);

      // Upgrading the Stadium afterwards must not hand out more free tiers.
      (((s['clubAssets'] as Map)['STADIUM']) as Map)['tier'] = 8;
      final again = migrate(_clone(s))!;
      expect(((again['clubAssets'] as Map)['FANZONE'] as Map)['tier'], 5);
    });

    test('does not grandfather a Fan Zone that is already owned', () {
      final save = _legacy({
        'clubAssets': {
          for (final c in AssetCategory.all)
            c: {'owned': false, 'tier': 0, 'invested': 0, 'tapCount': 0},
        },
      });
      final assets = save['clubAssets'] as Map;
      (assets['STADIUM'] as Map)..['owned'] = true..['tier'] = 5;
      (assets['FANZONE'] as Map)..['owned'] = true..['tier'] = 2;

      final s = migrate(save)!;
      expect(((s['clubAssets'] as Map)['FANZONE'] as Map)['tier'], 2);
    });

    test('resets inflated tap counts once', () {
      final save = _legacy({
        'clubAssets': {
          for (final c in AssetCategory.all)
            c: {'owned': true, 'tier': 1, 'invested': 0, 'tapCount': 99},
        },
      });
      final s = migrate(save)!;
      expect(((s['clubAssets'] as Map)['TRAINING'] as Map)['tapCount'], 0);
      expect(s['_tapCountReset2025'], isTrue);
    });
  });

  group('squad', () {
    test('builds a lineup when none exists', () {
      final s = migrate(
        _legacy({
          'grid': {
            'cells': [
              {'definitionId': 'player_t5_gk', 'instanceId': 'gk'},
              {'definitionId': 'player_t5_fwd', 'instanceId': 'fw'},
            ],
          },
        }),
      )!;
      final lineup = (s['squad'] as Map)['lineup'] as List;
      expect(lineup.length, 11);
      expect(
        lineup.map((e) => (e as Map)['cardInstanceId']).whereType<String>().length,
        2,
      );
    });

    test('migrates the removed 4-2-4 formation to 4-3-3', () {
      final s = migrate(_legacy({'squad': {'formation': '4-2-4'}}))!;
      expect((s['squad'] as Map)['formation'], '4-3-3');
      expect(((s['squad'] as Map)['lineup'] as List).length, 11);
    });

    test('drops the legacy bench field', () {
      final s = migrate(_legacy({'squad': {'bench': ['a', 'b']}}))!;
      expect((s['squad'] as Map).containsKey('bench'), isFalse);
    });

    test('rebuilds a lineup of the wrong length', () {
      final s = migrate(_legacy({'squad': {'formation': '4-3-3', 'lineup': [1, 2]}}))!;
      expect(((s['squad'] as Map)['lineup'] as List).length, 11);
    });
  });

  group('settings', () {
    test('falls back to English for a locale we no longer ship', () {
      final s = migrate(_legacy({'settings': {'locale': 'sv'}}))!;
      expect((s['settings'] as Map)['locale'], 'en');
    });

    test('keeps a locale we do ship', () {
      final s = migrate(_legacy({'settings': {'locale': 'ja'}}))!;
      expect((s['settings'] as Map)['locale'], 'ja');
    });

    test('drops auto-sell rules that are not a known action', () {
      // A corrupt or hand-edited save must not silently dispose of cards.
      final s = migrate(
        _legacy({
          'settings': {
            'autoTierActions': {'1': 'sell', '2': 'explode', '8': 'sell'},
          },
        }),
      )!;
      // Tiers 8 and 9 can never be auto-sold.
      expect((s['settings'] as Map)['autoTierActions'], {'1': 'sell'});
    });

    test('drops malformed saved pyramids', () {
      final s = migrate(
        _legacy({
          'settings': {
            'customPyramids': [
              {'id': 'a', 'label': 'Good', 'names': {'x': ['One']}},
              {'id': 'b'}, // missing label and names
              'nonsense',
            ],
          },
        }),
      )!;
      final kept = (s['settings'] as Map)['customPyramids'] as List;
      expect(kept.length, 1);
      expect((kept.first as Map)['id'], 'a');
    });
  });

  group('tutorial and tips', () {
    test('a save with no tutorial branch is treated as done', () {
      final s = migrate(_legacy())!;
      expect((s['tutorial'] as Map)['done'], isTrue);
    });

    test('shifts a mid-tutorial step index past the inserted steps', () {
      final s = migrate(_legacy({'tutorial': {'done': false, 'step': 6}}))!;
      expect((s['tutorial'] as Map)['step'], 8);
    });

    test('shifts an intermediate step by one', () {
      final s = migrate(_legacy({'tutorial': {'done': false, 'step': 3}}))!;
      expect((s['tutorial'] as Map)['step'], 4);
      expect((s['tutorial'] as Map)['borrowedPlayersAdded'], isTrue);
    });

    test('leaves the earliest steps alone', () {
      final s = migrate(_legacy({'tutorial': {'done': false, 'step': 2}}))!;
      expect((s['tutorial'] as Map)['step'], 2);
    });

    test('suppresses educational tips for existing players', () {
      // They already know the game.
      final s = migrate(_legacy())!;
      final tips = s['seenTips'] as List;
      expect(tips, contains('injury'));
      expect(tips, contains('merge'));
      // These two stay able to fire even for veterans.
      expect(tips, isNot(contains('save_progress')));
      expect(tips, isNot(contains('atk_def')));
    });
  });

  group('prestige and economy', () {
    test('recomputes the income multiplier at the current rate', () {
      final s = migrate(_legacy({'prestige': {'level': 3, 'incomeMultiplier': 3.375}}))!;
      expect(
        (s['prestige'] as Map)['incomeMultiplier'],
        closeTo(math.pow(1.1, 3).toDouble(), 1e-9),
      );
    });

    test('clamps an absurd prestige level so income cannot go non-finite', () {
      final s = migrate(_legacy({'prestige': {'level': 999999}}))!;
      expect((s['prestige'] as Map)['level'], 5000);
      expect(((s['prestige'] as Map)['incomeMultiplier'] as num).isFinite, isTrue);
    });

    test('rejects a negative prestige level', () {
      final s = migrate(_legacy({'prestige': {'level': -5}}))!;
      expect((s['prestige'] as Map)['level'], 0);
      expect((s['prestige'] as Map)['incomeMultiplier'], 1.0);
    });

    test('back-fills prestige points from the level, once', () {
      final s = migrate(_legacy({'prestige': {'level': 4}}))!;
      expect((s['prestige'] as Map)['points'], 4);
      expect(s['_prestigePoints2026'], isTrue);
    });

    test('clears a transfer offer that expired while the app was closed', () {
      setClock(() => 10 * 60 * 1000);
      final s = migrate(
        _legacy({
          'transferMarket': {
            'pendingOffer': {'offerId': 'x', 'createdAt': 0},
          },
        }),
      )!;
      expect((s['transferMarket'] as Map)['pendingOffer'], isNull);
    });

    test('keeps a fresh transfer offer', () {
      setClock(() => 60 * 1000);
      final s = migrate(
        _legacy({
          'transferMarket': {
            'pendingOffer': {'offerId': 'x', 'createdAt': 0},
          },
        }),
      )!;
      expect((s['transferMarket'] as Map)['pendingOffer'], isNotNull);
    });
  });

  group('club colours', () {
    test('remaps a retired kit colour to a kept one', () {
      final s = migrate(_legacy({'club': {'kitPrimaryColor': '#e74c3c'}}))!;
      expect((s['club'] as Map)['kitPrimaryColor'], '#0d47a1');
    });

    test('a doubly-retired colour lands on a kept one in a single lookup', () {
      // #3498db was retired to #00acc1, which was itself later retired.
      final s = migrate(_legacy({'club': {'kitPrimaryColor': '#3498db'}}))!;
      expect((s['club'] as Map)['kitPrimaryColor'], 'empire');
    });

    test('every retirement target is itself a kept colour', () {
      for (final target in retiredColours.values) {
        expect(
          retiredColours.containsKey(target),
          isFalse,
          reason: '$target is a retirement target but is itself retired',
        );
      }
    });

    test('a current colour is untouched', () {
      final s = migrate(_legacy({'club': {'kitPrimaryColor': '#4caf50'}}))!;
      expect((s['club'] as Map)['kitPrimaryColor'], '#4caf50');
    });
  });

  group('boosts', () {
    test('migrates legacy match-counter sponsors to season scope', () {
      final s = migrate(
        _legacy({
          'boosts': {'kitSponsorMatchesLeft': 5},
          'progression': {'seasonCount': 7},
        }),
      )!;
      expect((s['boosts'] as Map)['kitSponsorSeason'], 7);
      expect((s['boosts'] as Map).containsKey('kitSponsorMatchesLeft'), isFalse);
    });

    test('an expired legacy sponsor becomes inactive', () {
      final s = migrate(
        _legacy({
          'boosts': {'matchRevBoostMatchesLeft': 0},
          'progression': {'seasonCount': 7},
        }),
      )!;
      expect((s['boosts'] as Map)['matchRevBoostSeason'], isNull);
    });

    test('converts a sentinel VIP expiry into 30 days rather than cutting it off', () {
      setClock(() => 1000000);
      final s = migrate(
        _legacy({'boosts': {'vipExpiresAt': 9007199254740991}}),
      )!;
      final expiry = (s['boosts'] as Map)['vipExpiresAt'] as num;
      expect(expiry, 1000000 + 30 * 24 * 60 * 60 * 1000);
    });
  });

  group('season counter repair', () {
    test('reconciles counters that lagged the fixture records', () {
      // The counters used to increment only when the full-time popup was
      // dismissed, so backgrounding the app dropped them.
      final s = migrate(
        _legacy({
          'progression': {
            'seasonCount': 1,
            'seasonMatchesPlayed': 3,
            'seasonAwardedPlayed': 1,
            'fixtureResults': {
              's1_m0': {'won': true, 'homeGoals': 2},
              's1_m1': {'drawn': true, 'homeGoals': 1},
              's1_m2': {'won': false, 'drawn': false, 'homeGoals': 0},
            },
          },
        }),
      )!;
      final prog = s['progression'] as Map;
      expect(prog['seasonAwardedPlayed'], 3);
      expect(prog['seasonWins'], 1);
      expect(prog['seasonDraws'], 1);
      expect(prog['seasonLosses'], 1);
    });

    test('corrects downward when a counter exceeds matches started', () {
      // An awarded count above the number kicked off is corrupt by definition —
      // the old one-way repair could raise a polluted counter but never fix it.
      final s = migrate(
        _legacy({
          'progression': {
            'seasonCount': 1,
            'seasonMatchesPlayed': 1,
            'seasonAwardedPlayed': 9,
            'fixtureResults': {'s1_m0': {'won': true}},
          },
        }),
      )!;
      expect((s['progression'] as Map)['seasonAwardedPlayed'], 1);
    });

    test('ignores leftover fixtures from a previous run above the mark', () {
      // Keys are season-scoped, not run-scoped, and prestige restarts the
      // season count — so a prefix scan would read the old run's results.
      final s = migrate(
        _legacy({
          'progression': {
            'seasonCount': 1,
            'seasonMatchesPlayed': 1,
            'seasonAwardedPlayed': 0,
            'fixtureResults': {
              's1_m0': {'won': true},
              's1_m5': {'won': true},
              's1_m9': {'won': true},
            },
          },
        }),
      )!;
      expect((s['progression'] as Map)['seasonAwardedPlayed'], 1);
      expect((s['progression'] as Map)['seasonWins'], 1);
    });

    test('leaves a pre-fixtureResults save alone', () {
      final s = migrate(
        _legacy({
          'progression': {
            'seasonCount': 1,
            'seasonMatchesPlayed': 5,
            'seasonAwardedPlayed': 5,
            'seasonWins': 3,
          },
        }),
      )!;
      expect((s['progression'] as Map)['seasonWins'], 3);
    });
  });

  group('cups', () {
    test('clears an active run that leaked across a season boundary', () {
      final s = migrate(
        _legacy({
          'progression': {
            'seasonCount': 4,
            'cups': {
              'active': {'startedSeason': 2, 'round': 2},
              'history': [
                {'season': 4, 'cupId': 'phantom'},
                {'season': 2, 'cupId': 'real'},
              ],
              'availableThisSeason': false,
            },
          },
        }),
      )!;
      final cups = (s['progression'] as Map)['cups'] as Map;
      expect(cups['active'], isNull);
      expect(cups['availableThisSeason'], isTrue);
      // The phantom entry for this season is pruned; older history survives.
      expect((cups['history'] as List).length, 1);
      expect(((cups['history'] as List).first as Map)['cupId'], 'real');
    });

    test('keeps an active run from the current season', () {
      final s = migrate(
        _legacy({
          'progression': {
            'seasonCount': 4,
            'cups': {'active': {'startedSeason': 4}, 'history': <dynamic>[]},
          },
        }),
      )!;
      expect(((s['progression'] as Map)['cups'] as Map)['active'], isNotNull);
    });
  });

  group('team-name scrub', () {
    test('replaces stale placeholder names', () {
      final s = migrate(
        _legacy({
          'progression': {
            'seasonOpponents': ['Real Madrid', 'FC Reserve 3', 'Inter Blaze'],
          },
        }),
      )!;
      final names = (s['progression'] as Map)['seasonOpponents'] as List;
      expect(names[0], 'Real Madrid');
      expect(names[2], 'Inter Blaze');
      expect(names[1], isNot(startsWith('FC Reserve')));
      expect(names[1], isNotEmpty);
    });

    test('replaces blocked names in the pyramid', () {
      final s = migrate(
        _legacy({
          'progression': {
            'leaguePyramid': {
              'sunday_league': [
                {'name': 'Cocks United', 'rating': 20},
                {'name': 'Park Rovers', 'rating': 21},
              ],
            },
          },
        }),
      )!;
      final teams = ((s['progression'] as Map)['leaguePyramid'] as Map)['sunday_league'] as List;
      expect((teams[0] as Map)['name'], isNot(contains('Cocks')));
      expect((teams[1] as Map)['name'], 'Park Rovers');
      // The rest of the team survives the rebuild. The rating itself is
      // rewritten by the 2026 band reseed, which runs first — so assert it is
      // still a valid rating for this division rather than the original value.
      expect((teams[0] as Map)['rating'], inInclusiveRange(12, 24));
      expect((teams[0] as Map).containsKey('rating'), isTrue);
    });

    test('generated replacements do not collide within a division', () {
      final s = migrate(
        _legacy({
          'progression': {
            'leaguePyramid': {
              'sunday_league': [
                for (var i = 0; i < 8; i++) {'name': 'FC Reserve $i', 'rating': 20},
              ],
            },
          },
        }),
      )!;
      final teams = ((s['progression'] as Map)['leaguePyramid'] as Map)['sunday_league'] as List;
      final names = [for (final t in teams) (t as Map)['name'] as String];
      expect(names.toSet().length, names.length);
    });
  });

  group('rating-band reseed', () {
    test('reseeds cached opponent ratings into the new ranges, once', () {
      // Saves cached ratings drawn from the OLD higher ranges, leaving e.g.
      // Elite opponents near 78 against a new-scale squad of ~59.
      final s = migrate(
        _legacy({
          'progression': {
            'currentDivision': 'elite_league',
            'seasonCount': 1,
            'seasonOpponentRatings': {'s1_m0': 78, 's1_m1': 80, 's2_m0': 99},
          },
        }),
      )!;
      final ratings = (s['progression'] as Map)['seasonOpponentRatings'] as Map;
      final (lo, hi) = (48, 65); // elite_league
      expect(ratings['s1_m0'], inInclusiveRange(lo, hi));
      expect(ratings['s1_m1'], inInclusiveRange(lo, hi));
      // A different season's key is left alone.
      expect(ratings['s2_m0'], 99);
      expect(s['_ratingBandsReseed2026'], isTrue);
    });

    test('reseeds the whole pyramid into each division band', () {
      final s = migrate(
        _legacy({
          'progression': {
            'leaguePyramid': {
              'sunday_league': [{'name': 'A', 'rating': 90}],
              'champions_cup': [{'name': 'B', 'rating': 10}],
            },
          },
        }),
      )!;
      final pyramid = (s['progression'] as Map)['leaguePyramid'] as Map;
      expect(
        ((pyramid['sunday_league'] as List).first as Map)['rating'],
        inInclusiveRange(12, 24),
      );
      expect(
        ((pyramid['champions_cup'] as List).first as Map)['rating'],
        inInclusiveRange(68, 88),
      );
    });
  });

  group('fatigue reseed', () {
    test('restores a full bar on over-depleted cards, once', () {
      // The old model persisted the in-match dip, so a low-rated player could
      // sit near zero. The depletion was the bug.
      final s = migrate(
        _legacy({
          'grid': {
            'cells': [
              {'definitionId': 'player_t5_fwd', 'instanceId': 'a', 'energy': 2},
            ],
          },
        }),
      )!;
      final card = ((s['grid'] as Map)['cells'] as List).first as Map;
      expect(card['energy'], 56);
      expect(s['_fatigueTwoLayerReseed'], isTrue);
    });

    test('does not re-run on an already-migrated save', () {
      final once = migrate(
        _legacy({
          'grid': {
            'cells': [
              {'definitionId': 'player_t5_fwd', 'instanceId': 'a', 'energy': 2},
            ],
          },
        }),
      )!;
      (((once['grid'] as Map)['cells'] as List).first as Map)['energy'] = 10;
      final twice = migrate(_clone(once))!;
      expect((((twice['grid'] as Map)['cells'] as List).first as Map)['energy'], 10);
    });
  });

  group('gem ledger', () {
    test('retro-pays the tutorial gems exactly once', () {
      // Pre-existing saves were wrongly flagged as already-granted, so the
      // people who learned the game before gems existed never got them.
      final s = migrate(
        _legacy({
          'tutorial': {'done': true},
          'resources': {'fanCoins': 100, 'gems': 0},
        }),
      )!;
      expect((s['resources'] as Map)['gems'], tutorialGems);
      expect((s['gemGrants'] as Map)['tutorialBackfilled'], isTrue);

      // Spending them must not trigger a second payment.
      (s['resources'] as Map)['gems'] = 0;
      final again = migrate(_clone(s))!;
      expect((again['resources'] as Map)['gems'], 0);
    });

    test('does not pay someone who already has gems', () {
      final s = migrate(
        _legacy({
          'tutorial': {'done': true},
          'resources': {'fanCoins': 100, 'gems': 4},
        }),
      )!;
      expect((s['resources'] as Map)['gems'], 4);
    });

    test('does not pay someone still in the tutorial', () {
      final s = migrate(
        _legacy({
          'tutorial': {'done': false, 'step': 1},
          'resources': {'fanCoins': 100, 'gems': 0},
        }),
      )!;
      expect((s['resources'] as Map)['gems'], 0);
    });

    test('seeds the quest gem ledger EMPTY', () {
      // Back-filling would hand an established save several gems for quests it
      // never saw, and this ledger is what bounds the feature at seven gems.
      final s = migrate(
        _legacy({'progression': {'divisionsUnlocked': ['a', 'b', 'c']}}),
      )!;
      expect((s['gemGrants'] as Map)['questDivisionFirsts'], isEmpty);
    });
  });

  group('quests', () {
    test('drops the dead challenges branch', () {
      final s = migrate(_legacy({'challenges': {'daily': <dynamic>[]}}))!;
      expect(s.containsKey('challenges'), isFalse);
    });

    test('back-fills the whole quest shape', () {
      final s = migrate(_legacy())!;
      final q = s['quests'] as Map;
      expect(q['match'], {'fixtureKey': null, 'active': <dynamic>[]});
      expect(q['season'], isEmpty);
      expect(q['recent'], isEmpty);
      expect(q['lastRolledSeason'], 0);
      expect(q['streaks'], {'cleanSheet': 0, 'win': 0, 'unbeaten': 0});
    });
  });

  group('career counters', () {
    test('reconstructs career totals from surviving fixtures', () {
      // Prestige zeroes the season counters, which wiped a prestiged player's
      // global standing on the all-time board.
      final s = migrate(
        _legacy({
          'progression': {
            'matchesWon': 0,
            'matchesDrawn': 0,
            'fixtureResults': {
              'a': {'won': true, 'homeGoals': 3},
              'b': {'won': true, 'homeGoals': 1},
              'c': {'drawn': true, 'homeGoals': 2},
            },
          },
        }),
      )!;
      final prog = s['progression'] as Map;
      expect(prog['careerWins'], 2);
      expect(prog['careerDraws'], 1);
      expect(prog['careerGoalsFor'], 6);
      expect(prog['careerBackfillDone'], isTrue);
    });

    test('takes the live counters when they are higher', () {
      final s = migrate(
        _legacy({
          'progression': {'matchesWon': 50, 'matchesDrawn': 10, 'fixtureResults': <String, dynamic>{}},
        }),
      )!;
      expect((s['progression'] as Map)['careerWins'], 50);
      expect((s['progression'] as Map)['careerDraws'], 10);
    });

    test('recovers wins from careerStats after the soft-reset wipe', () {
      // resetState used to discard the career counters AND fixtureResults, so
      // this older counter is the only surviving high-water mark.
      final s = migrate(
        _legacy({
          'progression': {'careerWins': 0, 'careerDraws': 0, 'careerGoalsFor': 0},
          'careerStats': {'matchesWon': 120},
        }),
      )!;
      expect((s['progression'] as Map)['careerWins'], 120);
      expect((s['progression'] as Map)['careerResetRecoveryDone'], isTrue);
      expect((s['leaderboard'] as Map)['careerSeeded'], isFalse);
    });
  });

  group('shape back-fills', () {
    test('creates the Deadline Day shape so the engine need not guard', () {
      final s = migrate(_legacy())!;
      final session = (s['deadlineDay'] as Map)['session'] as Map;
      expect(session['listings'], isEmpty);
      expect(session['startedAt'], 0);
      expect(session['done'], isFalse);
    });

    test('repairs a partially-formed Deadline Day session', () {
      final s = migrate(
        _legacy({'deadlineDay': {'session': {'listings': 'corrupt'}}}),
      )!;
      expect(((s['deadlineDay'] as Map)['session'] as Map)['listings'], isEmpty);
    });

    test('creates the events shape', () {
      final s = migrate(_legacy())!;
      final e = s['events'] as Map;
      expect(e['active'], isEmpty);
      expect(e['progress'], isEmpty);
      expect(e['devOverride'], isNull);
    });

    test('back-fills firstWin from a legacy event trophy', () {
      final s = migrate(
        _legacy({
          'progression': {
            'leagueTrophies': [
              {'event': true, 'eventId': 'wc2026', 'playerNation': 'BRA'},
            ],
          },
        }),
      )!;
      final ep = ((s['events'] as Map)['progress'] as Map)['wc2026'] as Map;
      expect((ep['firstWin'] as Map)['playerNation'], 'BRA');
      expect((ep['firstWin'] as Map)['wonAt'], 0);
    });

    test('creates the age-verification shape and rejects bad values', () {
      final s = migrate(
        _legacy({'ageVerification': {'status': 'nonsense', 'source': 'hack'}}),
      )!;
      expect((s['ageVerification'] as Map)['status'], 'unknown');
      expect((s['ageVerification'] as Map)['source'], isNull);
    });

    test('drops a weather reading with no timestamp', () {
      // It could never be aged out, so it would pin the scene forever.
      final s = migrate(
        _legacy({'weather': {'live': {'condition': 'rain'}}}),
      )!;
      expect((s['weather'] as Map)['live'], isNull);
    });

    test('keeps a timestamped weather reading', () {
      final s = migrate(
        _legacy({'weather': {'live': {'condition': 'rain', 'fetchedAt': 123}}}),
      )!;
      expect((s['weather'] as Map)['live'], isNotNull);
    });

    test('forces the leaderboard onto schema 4 with a reseed', () {
      final s = migrate(_legacy({'leaderboard': {'lbSchema': 3, 'careerSeeded': true}}))!;
      final lb = s['leaderboard'] as Map;
      expect(lb['lbSchema'], 4);
      expect(lb['careerSeeded'], isFalse);
      expect(lb['pendingWrites'], isEmpty);
    });

    test('drops the never-surfaced rating feedback field', () {
      final s = migrate(_legacy({'rating': {'feedback': 'text'}}))!;
      expect((s['rating'] as Map).containsKey('feedback'), isFalse);
    });
  });
}
