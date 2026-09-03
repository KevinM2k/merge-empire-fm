/// Starting a match, and settling it afterwards.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/quests.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/match/match_launcher.dart';

/// A save that can actually take the field.
Map<String, dynamic> readyState({
  int energy = 10,
  bool pro = false,
  int squad = 11,
}) {
  final s = createDefaultState();
  (s['energy'] as Map<String, dynamic>)['current'] = energy;
  (s['settings'] as Map<String, dynamic>)['hardMode'] = pro;
  (s['progression'] as Map<String, dynamic>)['seasonOpponents'] = [
    'Ayton',
    'Beeches',
    'Cadley',
    'Deeping',
    'Elton',
    'Fairby',
    'Gorton',
  ];

  final def = players.firstWhere((p) => p.tier == 1);
  final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
  for (var i = 0; i < squad; i++) {
    cells[i] = <String, dynamic>{
      'definitionId': def.id,
      'instanceId': 'c$i',
      'variant': 0,
    };
  }
  (s['squad'] as Map<String, dynamic>)['lineup'] = [
    for (var i = 0; i < squad && i < 11; i++)
      <String, dynamic>{
        'slotId': 's$i',
        'slotPosition': 'MID',
        'cardInstanceId': 'c$i',
      },
  ];
  return s;
}

int energyOf(Map<String, dynamic> s) =>
    ((s['energy'] as Map<String, dynamic>)['current'] as num).toInt();

void main() {
  group('the gate', () {
    test('a ready save can start', () {
      expect(matchStartBlocked(readyState()), isNull);
    });

    test('a finished season cannot', () {
      final s = readyState();
      (s['progression'] as Map<String, dynamic>)['seasonComplete'] = true;
      expect(matchStartBlocked(s), 'season_over');
    });

    test('too few players cannot, and says which refusal it is', () {
      // canPlayMatch folds three refusals together; the button needs to know
      // which, or it just goes grey with no explanation.
      final s = readyState(squad: 2);
      expect(matchStartBlocked(s), 'squad_too_small');
    });

    test('AND A LINEUP OF INJURED MEN IS NOT A SIDE EITHER', () {
      // `hasEnoughPlayers` counts HEALTHY cards on the GRID and had no caller
      // in `lib/` at all, so the only gate was filled lineup SLOTS — which an
      // injured card still fills. The JS's play button ANDs the two.
      final s = readyState(squad: 3);
      for (final c in (s['grid'] as Map<String, dynamic>)['cells'] as List) {
        if (c is Map<String, dynamic>) c['injured'] = true;
      }
      expect(matchStartBlocked(s), 'squad_too_small');
    });

    test('and one fit man short of three is the boundary', () {
      final s = readyState(squad: 11);
      final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List;
      var injured = 0;
      for (final c in cells) {
        if (c is Map<String, dynamic> && injured < 9) {
          c['injured'] = true;
          injured++;
        }
      }
      // Two fit, and the eleven slots are all still filled.
      expect(matchStartBlocked(s), 'squad_too_small');

      (cells.firstWhere((c) => c is Map && c['injured'] == true)
          as Map<String, dynamic>)['injured'] = false;
      expect(matchStartBlocked(s), isNull);
    });

    test('no energy cannot, in casual', () {
      expect(matchStartBlocked(readyState(energy: 0)), 'no_energy');
    });

    test('but Pro mode charges no pip at all', () {
      // Fatigue is per player there, and it never locks anyone out — a tired
      // side just loses more.
      expect(matchStartBlocked(readyState(energy: 0, pro: true)), isNull);
    });
  });

  group('beginning', () {
    test('spends a pip and returns a result', () {
      final s = readyState(energy: 5);
      final result = beginMatch(s);
      expect(result, isNotNull);
      expect(energyOf(s), 5 - Energy.matchCost);
      expect(result!['homeGoals'], isA<int>());
      expect(result['awayGoals'], isA<int>());
      expect(result['opponentName'], isNotEmpty);
    });

    test('Pro mode plays for free', () {
      final s = readyState(energy: 5, pro: true);
      expect(beginMatch(s), isNotNull);
      expect(energyOf(s), 5, reason: 'no pip charged');
    });

    test('a blocked start changes nothing at all', () {
      // The gate is asked before the pip moves.
      final s = readyState(energy: 0);
      expect(beginMatch(s), isNull);
      expect(energyOf(s), 0);
    });

    test('a season that is over plays nothing', () {
      final s = readyState();
      (s['progression'] as Map<String, dynamic>)['seasonComplete'] = true;
      final before = energyOf(s);
      expect(beginMatch(s), isNull);
      expect(energyOf(s), before);
    });
  });

  group('settling', () {
    test('full time commits the outcome', () {
      final s = readyState();
      final before =
          ((s['progression'] as Map<String, dynamic>)['matchesPlayed'] as num)
              .toInt();
      final result = beginMatch(s)!;
      settleMatch(s, result);
      expect(
        ((s['progression'] as Map<String, dynamic>)['matchesPlayed'] as num)
            .toInt(),
        greaterThan(before),
      );
    });

    test('the match FEE arrives only when the player closes the screen', () {
      // Deferred on purpose: the doubling offer lives on the closing screen,
      // and crediting before it is answered would make the offer meaningless.
      //
      // Measured against the quest payouts rather than against zero. A match
      // quest AUTO-PAYS at full time — the player has already tapped through a
      // match, and a second tap to claim is friction with no upside — so "full
      // time pays nothing" was only true while nothing resolved the track, and
      // the assertion turned flaky the moment something did: it held or failed
      // depending on whether a randomly drawn quest happened to come off.
      final s = readyState();
      final result = beginMatch(s)!;
      final beforeCoins = coinsOf(s);

      settleMatch(s, result);
      final quests = (result['questResults'] as List)
          .cast<Map<String, dynamic>>();
      final questCoins = quests.fold<num>(
        0,
        (sum, q) => sum + ((q['coins'] as num?) ?? 0),
      );
      expect(
        coinsOf(s),
        beforeCoins + questCoins,
        reason: 'the quests, and nothing else',
      );

      payMatch(s, result);
      expect(coinsOf(s), greaterThanOrEqualTo(beforeCoins + questCoins));
    });

    test('and the match track is judged at full time, all three of it', () {
      // `resolveMatchQuests` had no caller at all: every match quest the game
      // drew went unjudged and unpaid.
      final s = readyState();
      final result = beginMatch(s)!;
      settleMatch(s, result);

      final quests = result['questResults'];
      expect(quests, isA<List<dynamic>>());
      expect((quests as List).length, matchQuestCount);
      for (final entry in quests.cast<Map<String, dynamic>>()) {
        expect(entry['id'], isA<String>());
        expect(entry['passed'], isA<bool>());
      }
    });

    test('a match played without opening the sheet still has a track', () {
      final s = readyState();
      (s['quests'] as Map<String, dynamic>)['match'] = <String, dynamic>{
        'fixtureKey': null,
        'active': <dynamic>[],
      };
      beginMatch(s);
      final active =
          ((s['quests'] as Map<String, dynamic>)['match']
                  as Map<String, dynamic>)['active']
              as List;
      expect(active.length, matchQuestCount);
    });
  });

  group('WHO IS ON THE TEAM SHEET AND SHOULD NOT BE', () {
    // Asked for from the couch: "if I try to start with an injured player I
    // should be warned when I press play match by a big Coach Colin popup with
    // a continue or go back button." The warning is on the screen — see
    // `play_button.dart` — and this is the question it asks.
    test('a fit eleven has nothing to say', () {
      expect(unfitStarters(readyState()), isEmpty);
    });

    test('an injured man in the XI is NAMED', () {
      final s = readyState();
      for (final raw in (s['grid'] as Map<String, dynamic>)['cells'] as List) {
        if (raw is Map<String, dynamic> && raw['instanceId'] == 'c3') {
          raw['injured'] = true;
          raw['injuredAt'] = 0;
          raw['injuryDurationMs'] = 60 * 60 * 1000;
        }
      }
      final unfit = unfitStarters(s);
      expect(unfit, hasLength(1), reason: 'the one man unfit was not named');
      expect(unfit.single, isNotEmpty);
    });

    test('and a man on the BENCH is not the manager\'s problem', () {
      // He is not being fielded, so there is nothing to warn about — a card
      // that fires for a squad injury would fire on nearly every fixture.
      final s = readyState(squad: 12);
      for (final raw in (s['grid'] as Map<String, dynamic>)['cells'] as List) {
        if (raw is Map<String, dynamic> && raw['instanceId'] == 'c11') {
          raw['injured'] = true;
          raw['injuredAt'] = 0;
          raw['injuryDurationMs'] = 60 * 60 * 1000;
        }
      }
      expect(unfitStarters(s), isEmpty);
    });

    test('AND A HOLE IS NOT A NAME EITHER', () {
      // The ordinary shape of an injury: the sim vacates the square as he goes
      // down. There is nobody to sub out, so there is nothing to say.
      final s = readyState();
      final lineup = (s['squad'] as Map<String, dynamic>)['lineup'] as List;
      (lineup.first as Map<String, dynamic>)['cardInstanceId'] = null;
      expect(unfitStarters(s), isEmpty);
    });

    test('a null save is not a squad in trouble', () {
      expect(unfitStarters(null), isEmpty);
    });
  });
}

int coinsOf(Map<String, dynamic> s) =>
    ((s['resources'] as Map<String, dynamic>)['fanCoins'] as num).toInt();
