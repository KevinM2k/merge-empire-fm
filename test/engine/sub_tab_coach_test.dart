/// Colin's read on whichever LIST you are looking at.
///
/// **Fifteen `coach.*` strings with nothing able to print one**, and the reason
/// was structural: the JS has these as League SUB-TABS and the port has them as
/// SHEETS, and a sheet is a route — so it covers the floating coach by
/// construction.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/sub_tab_coach.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/state/state_schema.dart';

Map<String, dynamic> save({
  int played = 6,
  int wins = 3,
  int energy = 10,
  int injured = 0,
  int cards = 11,
  int tier = 3,
  String division = 'regional_league',
}) {
  final s = createDefaultState();
  final prog = s['progression'] as Map<String, dynamic>;
  prog['currentDivision'] = division;
  prog['seasonAwardedPlayed'] = played;
  prog['seasonMatchesPlayed'] = played;
  prog['seasonWins'] = wins;
  (s['energy'] as Map<String, dynamic>)['current'] = energy;
  final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
  for (var i = 0; i < cards; i++) {
    cells[i] = <String, dynamic>{
      'definitionId': 'player_t${tier}_mid',
      'instanceId': 'c$i',
      'injured': i < injured,
    };
  }
  return s;
}

void main() {
  tearDown(resetLocale);

  group('what he says about the TABLE', () {
    test('A TABLE MEANS NOTHING UNTIL THREE GAMES IN', () {
      // The JS's own threshold, and the reason the branch exists: a position
      // read off one result is a position nobody should be told to act on.
      expect(
        leagueTableTip(save(played: 2, wins: 2), cupIsDue: false)?.key,
        'coach.table.early',
      );
      expect(
        leagueTableTip(save(played: 3, wins: 0), cupIsDue: false)?.key,
        isNot('coach.table.early'),
      );
    });

    test('and mid-table names the POSITION out of the total', () {
      final tip = leagueTableTip(save(played: 6, wins: 2), cupIsDue: false);
      if (tip?.key == 'coach.table.mid') {
        expect(tip!.params['pos'], isA<int>());
        expect(tip.params['total'], isA<int>());
        expect(tip.params['ord'], isIn(['st', 'nd', 'rd', 'th']));
      }
    });

    test('THE ORDINAL IS THE JS\'S THREE CASES and no more', () {
      // It never reads past seven teams, so the eleventh/twelfth exception a
      // general routine needs has never come up — and a rule this port cannot
      // exercise is a rule nothing can check.
      expect(ordinalSuffix(1), 'st');
      expect(ordinalSuffix(2), 'nd');
      expect(ordinalSuffix(3), 'rd');
      expect(ordinalSuffix(4), 'th');
      expect(ordinalSuffix(7), 'th');
    });
  });

  group('what he says about the FIXTURES', () {
    test('THE TREATMENT ROOM COMES FIRST, at two or more', () {
      // The one thing on that list the player can do something about before
      // the next fixture.
      final tip = leagueFixturesTip(save(injured: 2), cupIsDue: false);
      expect(tip?.key, 'coach.fixtures.injured');
      expect(tip?.params['n'], 2);
      expect(
        leagueFixturesTip(save(injured: 1), cupIsDue: false)?.key,
        isNot('coach.fixtures.injured'),
      );
    });

    test('and a strong squad, a weak one and an even league each read', () {
      expect(
        leagueFixturesTip(
          save(tier: 7, division: 'sunday_league'),
          cupIsDue: false,
        )?.key,
        'coach.fixtures.dominant',
      );
      expect(
        leagueFixturesTip(
          save(tier: 1, division: 'champions_cup'),
          cupIsDue: false,
        )?.key,
        'coach.fixtures.weak',
      );
    });
  });

  group('THE CUP AND THE EMPTY TANK OUTRANK THE LIST', () {
    test('and each sub-tab has its OWN line for both', () {
      // Six strings, not two: the JS's note is that "no energy" on the table
      // should not read the same as on the fixtures, because both have real
      // state to comment on either way.
      expect(
        leagueTableTip(save(), cupIsDue: true)?.key,
        'coach.cup_due.table',
      );
      expect(
        leagueFixturesTip(save(), cupIsDue: true)?.key,
        'coach.cup_due.fixtures',
      );
      expect(
        leagueTableTip(save(energy: 1), cupIsDue: false)?.key,
        'coach.low_energy.table',
      );
      expect(
        leagueFixturesTip(save(energy: 1), cupIsDue: false)?.key,
        'coach.low_energy.fixtures',
      );
    });

    test('and they are marked as the thing to act on', () {
      expect(leagueTableTip(save(), cupIsDue: true)?.priority, isTrue);
      expect(leagueTableTip(save(), cupIsDue: false)?.priority, isFalse);
    });
  });

  group('the MINI-GAMES sheet', () {
    test('SAYS NOTHING UNLESS A CUP TIE IS DUE', () {
      // Training is free, so a tank at nought is not a reason to stay off a
      // sheet full of games that cost none.
      expect(leagueMinigamesTip(save(energy: 0), cupIsDue: false), isNull);
      expect(
        leagueMinigamesTip(save(), cupIsDue: true)?.key,
        'coach.cup_due.minigames',
      );
    });
  });

  group('every line he can reach', () {
    test('RESOLVES, and none of them prints its whole pool', () {
      final tips = <SubTabTip>[
        for (final t in [
          leagueTableTip(save(played: 1), cupIsDue: false),
          leagueTableTip(save(played: 6, wins: 5), cupIsDue: false),
          leagueTableTip(save(played: 6, wins: 0), cupIsDue: false),
          leagueTableTip(save(played: 6, wins: 2), cupIsDue: false),
          leagueTableTip(save(), cupIsDue: true),
          leagueTableTip(save(energy: 0), cupIsDue: false),
          leagueFixturesTip(save(injured: 3), cupIsDue: false),
          leagueFixturesTip(save(tier: 7, division: 'sunday_league'),
              cupIsDue: false),
          leagueFixturesTip(save(tier: 1, division: 'champions_cup'),
              cupIsDue: false),
          leagueFixturesTip(save(), cupIsDue: true),
          leagueFixturesTip(save(energy: 0), cupIsDue: false),
          leagueMinigamesTip(save(), cupIsDue: true),
        ])
          ?t,
      ];
      expect(tips, isNotEmpty);
      for (final tip in tips) {
        final line = tPoolStable(tip.key, tip.seed, tip.params);
        expect(line, isNot(contains('|')), reason: tip.key);
        expect(line, isNot(contains('{')), reason: tip.key);
        expect(line, isNot(contains('}')), reason: tip.key);
        expect(line, isNot(tip.key), reason: '${tip.key} is not in the catalogue');
      }
    });

    test('AND HIS WORDING HOLDS STILL for the same situation', () {
      // The sheet is rebuilt on every idle tick; a random pick would have him
      // rephrasing himself while it is open.
      final a = leagueTableTip(save(), cupIsDue: false)!;
      final b = leagueTableTip(save(), cupIsDue: false)!;
      expect(a.seed, b.seed);
      expect(
        tPoolStable(a.key, a.seed, a.params),
        tPoolStable(b.key, b.seed, b.params),
      );
    });
  });
}
