import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/engine/season_end.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

final Map<String, dynamic> _ref = jsonDecode(
  File('test/fixtures/season_end_reference.json').readAsStringSync(),
) as Map<String, dynamic>;

final Map<String, dynamic> _questRef = jsonDecode(
  File('test/fixtures/quest_engine_reference.json').readAsStringSync(),
) as Map<String, dynamic>;

/// Wall-clock stamps are the one thing the two runtimes cannot agree on, so
/// they are blanked on both sides. `signedSeason` rides along because the
/// fixture blanks it too — the sponsor test asserts the expiry itself.
const _timeKeys = {
  'startedAt',
  'endedAt',
  'lastMatchAt',
  'injuredAt',
  'energyUpdatedAt',
  'claimedAt',
  'scoredAt',
  'activatedAt',
  'signedSeason',
};

Object? _strip(Object? v) {
  if (v is List) return [for (final e in v) _strip(e)];
  if (v is Map) {
    return <String, dynamic>{
      for (final e in v.entries)
        '${e.key}': _timeKeys.contains(e.key) ? null : _strip(e.value),
    };
  }
  return v;
}

/// The reference save, dressed for a season boundary.
Map<String, dynamic> _state([Map<String, dynamic> over = const {}]) {
  final s = jsonDecode(jsonEncode(_questRef['state'])) as Map<String, dynamic>;
  s['prestige'] = <String, dynamic>{
    'level': 0,
    'incomeMultiplier': 1,
    'totalTrophies': 0,
    'points': 0,
  };
  s['careerStats'] = <String, dynamic>{'leagueWins': 0, 'cupWins': 0};
  s['club'] = <String, dynamic>{};
  s['boosts'] = <String, dynamic>{};
  s['gemGrants'] = <String, dynamic>{
    'tutorialGranted': false,
    'divisionFirsts': <dynamic>[],
    'cupFirsts': <dynamic>[],
    'firstPrestigeDone': false,
    'chlTitleThisRun': false,
    'questDivisionFirsts': <dynamic>[],
  };
  final prog = s['progression'] as Map<String, dynamic>;
  prog['cups'] = <String, dynamic>{
    'active': null,
    'history': <dynamic>[],
    'availableThisSeason': true,
  };
  prog['seasonHistory'] = <dynamic>[];
  prog['divisionsUnlocked'] = <dynamic>[
    'sunday_league',
    'amateur_cup',
    'regional_league',
  ];
  prog['stagnationBuffs'] = <String, dynamic>{};
  prog['seasonAwardedPlayed'] = 14;
  prog['seasonMatchesPlayed'] = 14;
  // Deep-copied: the scenario overrides are const literals, and a real save
  // arrives from JSON and is mutable throughout.
  prog.addAll(jsonDecode(jsonEncode(over)) as Map<String, dynamic>);
  return s;
}

/// The same squad the fixture dresses: a veteran about to retire, two injuries
/// either side of the close-season head start, an expiring sponsor and a
/// current one, and two players carrying form.
void _dressSquad(Map<String, dynamic> state) {
  final cells = (state['grid'] as Map<String, dynamic>)['cells'] as List;
  Map<String, dynamic> at(int i) => cells[i] as Map<String, dynamic>;
  at(0)['seasonsPlayed'] = 14;
  at(1)['seasonsPlayed'] = 9;
  at(2)
    ..['injured'] = true
    ..['injuredAt'] = 0
    ..['injuryDurationMs'] = 60 * 1000;
  at(3)
    ..['injured'] = true
    ..['injuredAt'] = 0
    ..['injuryDurationMs'] = 90 * 60 * 1000;
  at(4)['sponsor'] = {
    'name': 'Old Deal',
    'multiplier': 1.2,
    'signedSeason': 1,
  };
  at(5)['sponsor'] = {
    'name': 'New Deal',
    'multiplier': 1.2,
    'signedSeason': 4,
  };
  at(6)['form'] = 3;
  at(7)['form'] = -2;
}

const Map<String, Map<String, dynamic>> _scenarios = {
  'promoted': {'seasonWins': 13, 'seasonDraws': 1},
  'midTable': {'seasonWins': 6, 'seasonDraws': 3},
  'relegated': {'seasonWins': 0, 'seasonDraws': 1},
  'bottomDivision': {
    'currentDivision': 'sunday_league',
    'seasonWins': 0,
    'seasonDraws': 0,
  },
  'topFlightChampion': {
    'currentDivision': 'champions_cup',
    'seasonWins': 14,
    'seasonDraws': 0,
  },
  'topFlightMid': {
    'currentDivision': 'champions_cup',
    'seasonWins': 6,
    'seasonDraws': 2,
  },
  'stagnating': {
    'seasonWins': 6,
    'seasonDraws': 3,
    'stagnationBuffs': {'regional_league': 9},
  },
};

Map<String, dynamic> _played(String scenario) {
  seeded.setSeed(1234);
  final state = _state(_scenarios[scenario]!);
  _dressSquad(state);
  return state;
}

Map<String, dynamic> _prog(Map<String, dynamic> s) =>
    s['progression'] as Map<String, dynamic>;

void main() {
  setUp(() => setClock(() => 1700000000000));
  tearDown(() {
    resetClock();
    clearBus();
  });

  group('parity — endSeason', () {
    for (final label in _scenarios.keys) {
      test('settles the season identically — $label', () {
        // The highest-stakes function in the game, and most of its bugs have
        // been ORDERING bugs — which only a full before-and-after comparison
        // catches.
        final state = _played(label);
        final result = endSeason(state);
        final want = _ref[label] as Map<String, dynamic>;
        final w = want['result'] as Map<String, dynamic>;

        expect(result.outcome, w['outcome'], reason: label);
        expect(result.position, w['position'], reason: label);
        expect(result.oldDivision, w['oldDivision'], reason: label);
        expect(result.newDivision, w['newDivision'], reason: label);
        expect(result.payout, w['payout'], reason: label);
        expect(result.gemsAwarded, w['gemsAwarded'], reason: label);
        expect(result.ageingReport, w['ageingReport'], reason: label);
        expect(
          {
            'recovered': result.injuryReport.recovered,
            'shortened': result.injuryReport.shortened,
          },
          w['injuryReport'],
          reason: label,
        );
        expect(
          {'expired': result.sponsorReport.expired},
          w['sponsorReport'],
          reason: label,
        );

        final wantProg = want['progression'] as Map<String, dynamic>;
        for (final key in wantProg.keys) {
          expect(_strip(_prog(state)[key]), wantProg[key],
              reason: '$label $key');
        }

        expect(state['resources']['fanCoins'], want['coins'], reason: label);
        expect(state['resources']['gems'], want['gems'], reason: label);
        expect(state['careerStats'], want['careerStats'], reason: label);
        expect(_strip(state['quests']), want['quests'], reason: label);
        expect(
          [
            for (final c in (state['grid'] as Map<String, dynamic>)['cells']
                as List)
              if (c != null)
                _strip({
                  'instanceId': (c as Map)['instanceId'],
                  'seasonsPlayed': c['seasonsPlayed'],
                  'injured': c['injured'] == true,
                  'injuryDurationMs': c['injuryDurationMs'],
                  'sponsor': c['sponsor'],
                  'form': c['form'] ?? 0,
                }),
          ],
          want['cards'],
          reason: label,
        );
      });
    }
  });

  group('parity — prestige', () {
    test('starts a new adventure identically', () {
      seeded.setSeed(99);
      final state = _state({
        'currentDivision': 'champions_cup',
        'wonChampionsCup': true,
      });
      state['resources']['trophies'] = 42;
      state['club'] = <String, dynamic>{
        'lookPacks': ['pack_legend', 'pack_retired'],
        'lookItems': ['hat:tophat', 'hair:slick'],
        'cupLooksWon': ['regional_cup'],
        'managerAvatar': {'hat': 'diamond', 'style': 'slick', 'build': 'broad'},
      };
      (state['clubAssets'] as Map<String, dynamic>)['FANZONE'] = {
        'owned': true,
        'tier': 8,
        'invested': 0,
        'tapCount': 0,
      };
      state['boosts'] = <String, dynamic>{
        'vipActive': true,
        'vipPrestigeLevel': 0,
        'vipExpiresAt': 999,
      };
      (state['settings'] as Map<String, dynamic>)['autoTierActions'] = {
        '1': 'sell',
        '2': 'sell',
      };

      final result = performPrestige(state);
      final want = _ref['prestige'] as Map<String, dynamic>;
      final w = want['result'] as Map<String, dynamic>;

      expect(result.ok, w['ok']);
      expect(result.gemsAwarded, w['gemsAwarded']);
      expect(result.level, w['level']);
      expect(result.multiplier, closeTo((w['multiplier'] as num).toDouble(), 1e-12));

      expect(state['resources']['fanCoins'], want['coins']);
      expect(state['resources']['gems'], want['gems']);
      expect(state['resources']['trophies'], want['trophies']);
      expect(state['prestige'], want['prestige']);
      expect(state['careerStats'], want['careerStats']);
      expect(state['gemGrants'], want['gemGrants']);
      expect(state['boosts'], want['boosts']);
      expect(state['settings']['autoTierActions'], want['autoTierActions']);

      final wantClub = want['club'] as Map<String, dynamic>;
      final club = state['club'] as Map<String, dynamic>;
      expect(club['lookPacks'], wantClub['lookPacks']);
      expect(club['lookItems'], wantClub['lookItems']);
      expect(club['cupLooksWon'], wantClub['cupLooksWon']);
      expect(
        (club['managerAvatar'] as Map)['hat'],
        wantClub['managerAvatarHat'],
      );
      expect(
        (club['managerAvatar'] as Map)['style'],
        wantClub['managerAvatarStyle'],
      );

      final wantProg = want['progression'] as Map<String, dynamic>;
      for (final key in wantProg.keys) {
        expect(_prog(state)[key], wantProg[key], reason: key);
      }

      final cells = (state['grid'] as Map<String, dynamic>)['cells'] as List;
      expect(cells.every((c) => c == null), want['gridEmpty']);
      expect(cells.length, want['gridLength']);
    });

    test('refuses a run that has not won the top flight', () {
      seeded.setSeed(99);
      expect(performPrestige(_state()).ok, _ref['prestigeRefused']['ok']);
    });
  });

  group('the season outcome', () {
    test('a top-two finish goes up', () {
      final state = _played('promoted');
      final result = endSeason(state);
      expect(result.outcome, 'promoted');
      expect(result.position, lessThanOrEqualTo(2));
      expect(_prog(state)['currentDivision'], 'national_league');
    });

    test('a bottom-two finish goes down', () {
      final state = _played('relegated');
      expect(endSeason(state).outcome, 'relegated');
      expect(_prog(state)['currentDivision'], 'amateur_cup');
    });

    test('nothing drops out of the bottom division', () {
      final state = _played('bottomDivision');
      final result = endSeason(state);
      expect(result.outcome, 'stayed');
      expect(_prog(state)['currentDivision'], 'sunday_league');
    });

    test('nothing is promoted out of the top flight', () {
      final state = _played('topFlightChampion');
      expect(endSeason(state).outcome, 'stayed');
      expect(_prog(state)['currentDivision'], 'champions_cup');
    });

    test('the new division is unlocked and never duplicated', () {
      final state = _played('promoted');
      endSeason(state);
      final unlocked = _prog(state)['divisionsUnlocked'] as List;
      expect(unlocked, contains('national_league'));
      expect(unlocked.toSet().length, unlocked.length);
    });
  });

  group('the payout', () {
    test('rewards the climb, and pays nothing at the bottom', () {
      expect(endSeason(_played('promoted')).payout, greaterThan(0));
      expect(endSeason(_played('midTable')).payout, greaterThan(0));
      expect(endSeason(_played('relegated')).payout, 0);
    });

    test('scales with the division', () {
      expect(
        endSeason(_played('topFlightMid')).payout,
        greaterThan(endSeason(_played('midTable')).payout),
      );
    });

    test('is filed in the season history', () {
      final state = _played('promoted');
      final result = endSeason(state);
      final history = _prog(state)['seasonHistory'] as List;
      expect(history, hasLength(1));
      expect((history.single as Map)['payout'], result.payout);
      expect((history.single as Map)['outcome'], 'promoted');
      expect(_prog(state)['lastSeasonPayout'], result.payout);
    });
  });

  group('the badges the next season shows', () {
    test('the player is badged in the league the move landed in', () {
      final state = _played('promoted');
      endSeason(state);
      final status = _prog(state)['lastSeasonStatus'] as Map<String, dynamic>;
      expect(status['player'], 'promoted');
      expect(status['playerDivision'], 'national_league');
    });

    test('and stored APART from the club name map', () {
      // An unnamed save's "Your Club" must not collide with an AI club, and the
      // player's name can change mid-run.
      final state = _played('promoted');
      endSeason(state);
      final status = _prog(state)['lastSeasonStatus'] as Map<String, dynamic>;
      expect((status['teams'] as Map).containsKey('Test Town'), isFalse);
    });

    test('only the TOP division gets a champion badge', () {
      // Everywhere else the winner went up, and a trophy sitting in the league
      // above would read as a mistake.
      final top = _played('topFlightChampion');
      endSeason(top);
      expect((_prog(top)['lastSeasonStatus'] as Map)['player'], 'champion');

      final lower = _played('promoted');
      endSeason(lower);
      expect((_prog(lower)['lastSeasonStatus'] as Map)['player'], 'promoted');
    });

    test('every badged club names the division it moved INTO', () {
      final state = _played('midTable');
      endSeason(state);
      final teams =
          (_prog(state)['lastSeasonStatus'] as Map)['teams'] as Map;
      expect(teams, isNotEmpty);
      for (final entry in teams.values) {
        expect(
          (entry as Map)['status'],
          anyOf('promoted', 'relegated', 'champion'),
        );
      }
    });
  });

  group('the trophy and the gems', () {
    test('going up lifts a league trophy and a career win', () {
      final state = _played('promoted');
      endSeason(state);
      expect(_prog(state)['leagueTrophies'], hasLength(1));
      expect(state['careerStats']['leagueWins'], 1);
    });

    test('staying up lifts nothing', () {
      final state = _played('midTable');
      endSeason(state);
      // The list isn't even created — it is written only on a promotion.
      expect(_prog(state)['leagueTrophies'] ?? <dynamic>[], isEmpty);
      expect(state['careerStats']['leagueWins'], 0);
    });

    test('winning the top flight unlocks prestige and pays a gem', () {
      final state = _played('topFlightChampion');
      final gemsBefore = state['resources']['gems'] as num;
      final result = endSeason(state);
      expect(_prog(state)['wonChampionsCup'], isTrue);
      expect(result.gemsAwarded, 1);
      expect(state['resources']['gems'], gemsBefore + 1);
    });

    test('and only once per run', () {
      final state = _played('topFlightChampion');
      endSeason(state);
      final after = state['resources']['gems'];
      _prog(state)
        ..['seasonAwardedPlayed'] = 14
        ..['seasonWins'] = 14;
      endSeason(state);
      expect(state['resources']['gems'], after);
    });

    test('reaching a top-three division for the first time pays a gem', () {
      final state = _played('promoted');
      _prog(state)['currentDivision'] = 'national_league';
      final result = endSeason(state);
      expect(result.newDivision, 'elite_league');
      expect(result.gemsAwarded, 1);
    });
  });

  group('the stagnation buff', () {
    test('rises for a season that went nowhere', () {
      final state = _played('midTable');
      endSeason(state);
      expect(_prog(state)['stagnationBuffs']['regional_league'], 1);
    });

    test('and for a relegation, in the division you failed in', () {
      final state = _played('relegated');
      endSeason(state);
      expect(_prog(state)['stagnationBuffs']['regional_league'], 1);
    });

    test('a promotion takes one off the division you left', () {
      final state = _played('promoted');
      _prog(state)['stagnationBuffs'] = {'regional_league': 4};
      endSeason(state);
      expect(_prog(state)['stagnationBuffs']['regional_league'], 3);
    });

    test('and never below zero', () {
      final state = _played('promoted');
      endSeason(state);
      expect(_prog(state)['stagnationBuffs']['regional_league'], 0);
    });

    test('it caps, so a stuck division cannot climb for ever', () {
      final state = _played('stagnating');
      endSeason(state);
      expect(_prog(state)['stagnationBuffs']['regional_league'], 10);
    });

    test('the top flight never accumulates one', () {
      // It has no promotion to escape by, so the buff would grow for ever.
      final state = _played('topFlightMid');
      _prog(state)['stagnationBuffs'] = {'champions_cup': 7};
      endSeason(state);
      expect(_prog(state)['stagnationBuffs']['champions_cup'], 0);
    });
  });

  group('the squad over the summer', () {
    test('everybody ages a season', () {
      final state = _played('midTable');
      endSeason(state);
      final cells = (state['grid'] as Map<String, dynamic>)['cells'] as List;
      final one = cells.firstWhere(
        (c) => (c as Map?)?['instanceId'] == 'c1',
      ) as Map;
      expect(one['seasonsPlayed'], 10);
    });

    test('a loanee does not age', () {
      // A loan is measured in matches, not seasons, and ageing one would let it
      // drift toward the retirement sweep.
      final state = _played('midTable');
      final cells = (state['grid'] as Map<String, dynamic>)['cells'] as List;
      (cells[8] as Map)
        ..['loanMatchesLeft'] = 4
        ..['seasonsPlayed'] = 3;
      endSeason(state);
      expect((cells[8] as Map)['seasonsPlayed'], 3);
    });

    test('a fifteen-season veteran retires', () {
      final state = _played('midTable');
      final report = endSeason(state).ageingReport;
      expect(report, hasLength(1));
      expect(report.single['retired'], isTrue);
      expect(report.single['toTierName'], 'Retired');
      final cells = (state['grid'] as Map<String, dynamic>)['cells'] as List;
      expect(cells.any((c) => (c as Map?)?['instanceId'] == 'c0'), isFalse);
    });

    test('a nearly-healed injury clears over the break', () {
      final state = _played('midTable');
      final result = endSeason(state);
      // Both dressed injuries were stamped long ago, so both have run their
      // course — the break only has to finish them off.
      expect(result.injuryReport.recovered, 2);
      final cells = (state['grid'] as Map<String, dynamic>)['cells'] as List;
      for (final id in ['c2', 'c3']) {
        final card = cells.firstWhere(
          (c) => (c as Map?)?['instanceId'] == id,
        ) as Map;
        expect(card['injured'], isFalse, reason: id);
        expect(card['injuryDurationMs'], isNull, reason: id);
      }
    });

    test('a fresh long injury is SHORTENED by ten minutes, not healed', () {
      // Not a full heal — just a head start, so the new season doesn't begin
      // with a full limp from the last match of the old one.
      final state = _played('midTable');
      final cells = (state['grid'] as Map<String, dynamic>)['cells'] as List;
      (cells[3] as Map)
        ..['injured'] = true
        ..['injuredAt'] = now()
        ..['injuryDurationMs'] = 90 * 60 * 1000;
      final result = endSeason(state);
      expect(result.injuryReport.shortened, 1);
      final long = cells.firstWhere(
        (c) => (c as Map?)?['instanceId'] == 'c3',
      ) as Map;
      expect(long['injured'], isTrue);
      expect(long['injuryDurationMs'], 90 * 60 * 1000 - 10 * 60 * 1000);
    });

    test('a sponsor is a one-season deal', () {
      final state = _played('midTable');
      final result = endSeason(state);
      expect(result.sponsorReport.expired, 1);
      final cells = (state['grid'] as Map<String, dynamic>)['cells'] as List;
      expect(
        (cells.firstWhere((c) => (c as Map?)?['instanceId'] == 'c4') as Map)['sponsor'],
        isNull,
      );
      expect(
        (cells.firstWhere((c) => (c as Map?)?['instanceId'] == 'c5') as Map)['sponsor'],
        isNotNull,
      );
    });

    test('form decays one step toward zero, from either side', () {
      final state = _played('midTable');
      endSeason(state);
      final cells = (state['grid'] as Map<String, dynamic>)['cells'] as List;
      expect(
        (cells.firstWhere((c) => (c as Map?)?['instanceId'] == 'c6') as Map)['form'],
        2,
      );
      expect(
        (cells.firstWhere((c) => (c as Map?)?['instanceId'] == 'c7') as Map)['form'],
        -1,
      );
    });
  });

  group('the new campaign', () {
    test('the season counter advances and the record is wiped', () {
      final state = _played('midTable');
      endSeason(state);
      expect(_prog(state)['seasonCount'], 4);
      for (final key in [
        'seasonMatchesPlayed',
        'seasonAwardedPlayed',
        'seasonWins',
        'seasonDraws',
        'seasonLosses',
      ]) {
        expect(_prog(state)[key], 0, reason: key);
      }
      expect(_prog(state)['seasonComplete'], isFalse);
      expect(_prog(state)['lastMatchResult'], isNull);
    });

    test('a fresh fixture list is drawn', () {
      final state = _played('midTable');
      endSeason(state);
      expect((_prog(state)['seasonFixtures'] as List), hasLength(56));
      expect((_prog(state)['seasonOpponents'] as List), hasLength(7));
    });

    test('a fresh quest track is rolled, against the NEW division', () {
      final state = _played('promoted');
      endSeason(state);
      final track = (state['quests'] as Map)['season'] as List;
      expect(track, hasLength(3));
      for (final inst in track) {
        expect((inst as Map)['claimedAt'], isNull);
      }
    });

    test('an unclaimed quest is swept before the track is replaced', () {
      // Nobody should lose coins they earned for not tapping a button.
      final state = _played('midTable');
      final quests = state['quests'] as Map<String, dynamic>? ?? <String, dynamic>{};
      state['quests'] = quests;
      quests['season'] = <dynamic>[
        <String, dynamic>{
          'id': 'season_wins',
          'target': 1,
          'progress': 1,
          'completed': true,
          'claimedAt': null,
          'baseline': 0,
        },
      ];
      quests['lastRolledSeason'] = 3;
      final before = state['resources']['fanCoins'] as num;
      endSeason(state);
      expect(state['resources']['fanCoins'], greaterThan(before));
    });

    test('the cup opens again and the player is entered automatically', () {
      // Matching real football, where clubs are scheduled into their cup rather
      // than opting in.
      final state = _played('midTable');
      endSeason(state);
      final cups = _prog(state)['cups'] as Map<String, dynamic>;
      expect(cups['availableThisSeason'], isFalse);
      expect(cups['active'], isNotNull);
    });

    test('a save with no cups branch is opened one, not skipped', () {
      // The rollover used to write the flag itself and guard on the branch
      // existing, so a save without one silently got no cup at all. It goes
      // through the cup engine's own `refreshCupAvailability` now, which builds
      // the branch — one rule, in the engine that decides what the flag means.
      final state = _played('midTable');
      _prog(state).remove('cups');
      endSeason(state);
      final cups = _prog(state)['cups'] as Map<String, dynamic>;
      expect(cups, isNotNull);
      // Entered on the way out, exactly as a save that had the branch is.
      expect(cups['active'], isNotNull);
    });

    test('the Lucky Boot allowance resets', () {
      final state = _played('midTable');
      (state['shop'] as Map<String, dynamic>)['luckyBootUses'] = 3;
      endSeason(state);
      expect(state['shop']['luckyBootUses'], 0);
    });

    test('announces the ending and the start', () {
      final seen = <String>[];
      on('season:ended', (_) => seen.add('ended'));
      on('season:started', (_) => seen.add('started'));
      endSeason(_played('midTable'));
      expect(seen, containsAll(['ended', 'started']));
    });
  });

  group('prestige', () {
    Map<String, dynamic> championState() {
      seeded.setSeed(99);
      final state = _state({
        'currentDivision': 'champions_cup',
        'wonChampionsCup': true,
      });
      return state;
    }

    test('is refused until the top flight is won', () {
      expect(canPrestige(_state()), isFalse);
      expect(performPrestige(_state()).ok, isFalse);
      expect(canPrestige(championState()), isTrue);
    });

    test('AND WINNING IT IS WHAT UNLOCKS PRO, not prestiging', () {
      // The gate used to be a prestige, and the fault was not the difficulty:
      // nobody knows what prestige is. The padlock's whole explanation was
      // "Prestige for the first time", which answers an unknown control with
      // an unknown word. Winning the Champions League is the same achievement
      // one step earlier, in the language of the game.
      expect(proModeUnlocked(_state()), isFalse);
      expect(proModeUnlocked(championState()), isTrue);
    });

    test('and a player on their SECOND adventure keeps it', () {
      // A prestige resets `progression`, `wonChampionsCup` with it — so
      // without the level in the condition the difficulty a player earned
      // would be taken back off them at the reset.
      final state = championState();
      performPrestige(state);
      expect(canPrestige(state), isFalse, reason: 'the flag really is gone');
      expect(proModeUnlocked(state), isTrue);
    });

    test('re-gates itself, so it cannot be spammed', () {
      // Without this the flag survives every reset, so the option stays
      // permanently unlocked and the level inflates with no matches played.
      final state = championState();
      performPrestige(state);
      expect(canPrestige(state), isFalse);
    });

    test('carries the gems through — hard currency survives', () {
      final state = championState();
      final gemsBefore = state['resources']['gems'] as num;
      final result = performPrestige(state);
      expect(state['resources']['gems'], gemsBefore + result.gemsAwarded);
    });

    test('and the lifetime ledger with them', () {
      final state = championState();
      (state['gemGrants'] as Map<String, dynamic>)['divisionFirsts'] = [
        'elite_league',
      ];
      performPrestige(state);
      expect(state['gemGrants']['divisionFirsts'], ['elite_league']);
      // Only the per-run title flag clears, so the new adventure can win its
      // own Champions League.
      expect(state['gemGrants']['chlTitleThisRun'], isFalse);
    });

    test('the first prestige ever pays a bonus, and only the first', () {
      final first = championState();
      final firstResult = performPrestige(first);
      final second = championState();
      (second['gemGrants'] as Map<String, dynamic>)['firstPrestigeDone'] = true;
      expect(performPrestige(second).gemsAwarded, lessThan(firstResult.gemsAwarded));
    });

    test('seeds the coin balance against the new multiplier', () {
      final state = championState();
      final result = performPrestige(state);
      expect(
        state['resources']['fanCoins'],
        (startingCoins * result.multiplier).round(),
      );
    });

    test('empties the grid to its full length', () {
      final state = championState();
      performPrestige(state);
      final cells = (state['grid'] as Map<String, dynamic>)['cells'] as List;
      expect(cells, hasLength(Grid.totalCells));
      expect(cells.every((c) => c == null), isTrue);
    });

    test('drops back to Sunday League with nothing else unlocked', () {
      final state = championState();
      performPrestige(state);
      expect(_prog(state)['currentDivision'], 'sunday_league');
      expect(_prog(state)['divisionsUnlocked'], ['sunday_league']);
    });

    test('clears everything keyed by season number', () {
      // The counter restarts at one, so every season number in the new run is
      // one the finished run already played.
      final state = championState();
      _prog(state)
        ..['fixtureResults'] = {'s3_m0': {'homeGoals': 2}}
        ..['seasonOpponentRatings'] = {'s3_o0': 60};
      performPrestige(state);
      expect(_prog(state)['seasonCount'], 1);
      expect(_prog(state)['fixtureResults'], isEmpty);
      expect(_prog(state)['seasonOpponentRatings'], isEmpty);
      expect(_prog(state)['leaguePyramid'], isNull);
      expect(_prog(state)['lastSeasonStatus'], isNull);
    });

    test('keeps the cup cosmetics and career stats, wipes the per-run slate', () {
      final state = championState();
      state['club'] = <String, dynamic>{
        'cupLooksWon': ['world_club_cup'],
      };
      state['careerStats'] = <String, dynamic>{'leagueWins': 4, 'cupWins': 2};
      _prog(state)['cups'] = <String, dynamic>{
        'active': <String, dynamic>{'cupId': 'x'},
        'history': <dynamic>[
          <String, dynamic>{'cupId': 'regional_cup'},
        ],
        'availableThisSeason': false,
      };
      performPrestige(state);
      expect(state['club']['cupLooksWon'], ['world_club_cup']);
      expect(state['careerStats'], {'leagueWins': 4, 'cupWins': 2});
      expect(_prog(state)['cups']['history'], isEmpty);
      expect(_prog(state)['cups']['active'], isNull);
      expect(_prog(state)['cups']['availableThisSeason'], isTrue);
    });

    test('switches the auto-sell rules back off', () {
      // A fresh career starts back where bronze is all there is.
      final state = championState();
      (state['settings'] as Map<String, dynamic>)['autoTierActions'] = {
        '1': 'sell',
      };
      performPrestige(state);
      expect(state['settings']['autoTierActions'], isEmpty);
    });

    test('keeps the manager cosmetics but re-measures the face', () {
      // The sanitiser reads the LIVE Fan Zone tier, and the point is to measure
      // against the fresh club rather than the one that just ended.
      final state = championState();
      (state['clubAssets'] as Map<String, dynamic>)['FANZONE'] = {
        'owned': true,
        'tier': 8,
      };
      state['club'] = <String, dynamic>{
        'lookPacks': ['pack_legend'],
        'lookItems': ['hat:tophat'],
        'managerAvatar': {'style': 'slick', 'hat': 'tophat'},
      };
      performPrestige(state);
      expect(state['club']['lookPacks'], ['pack_legend']);
      expect(state['club']['lookItems'], ['hat:tophat']);
      // The tier-8 hair goes with the old club; the pack hat stays.
      expect((state['club']['managerAvatar'] as Map)['style'], isNot('slick'));
      expect((state['club']['managerAvatar'] as Map)['hat'], 'tophat');
    });

    test('clears a prestige-linked VIP', () {
      final state = championState();
      state['boosts'] = <String, dynamic>{
        'vipActive': true,
        'vipPrestigeLevel': 0,
        'vipExpiresAt': 999,
      };
      performPrestige(state);
      expect(state['boosts']['vipActive'], isFalse);
      expect(state['boosts']['vipExpiresAt'], 0);
    });

    test('accrues a prestige point and banks the trophies', () {
      final state = championState();
      state['resources']['trophies'] = 42;
      performPrestige(state);
      expect(state['prestige']['points'], 1);
      expect(state['prestige']['totalTrophies'], 42);
      expect(state['resources']['trophies'], 0);
    });

    test('announces the new adventure', () {
      Object? announced;
      on('prestige:complete', (v) => announced = v);
      performPrestige(championState());
      expect((announced as Map)['level'], 1);
    });
  });

  test('checkDivisionUnlock is a no-op kept for save compatibility', () {
    expect(() => checkDivisionUnlock(_state()), returnsNormally);
    expect(() => checkDivisionUnlock(null), returnsNormally);
  });
}
