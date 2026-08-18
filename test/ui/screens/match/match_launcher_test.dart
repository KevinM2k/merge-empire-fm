/// Starting a match, and settling it afterwards.
library;

import 'package:flutter_test/flutter_test.dart';
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

    test('the coins arrive only when the player closes the screen', () {
      // Deferred on purpose: the doubling offer lives on the closing screen,
      // and crediting before it is answered would make the offer meaningless.
      final s = readyState();
      final result = beginMatch(s)!;
      final beforeCoins =
          ((s['resources'] as Map<String, dynamic>)['fanCoins'] as num).toInt();

      settleMatch(s, result);
      expect(
        ((s['resources'] as Map<String, dynamic>)['fanCoins'] as num).toInt(),
        beforeCoins,
        reason: 'full time pays nothing',
      );

      payMatch(s, result);
      expect(
        ((s['resources'] as Map<String, dynamic>)['fanCoins'] as num).toInt(),
        greaterThanOrEqualTo(beforeCoins),
      );
    });
  });
}
