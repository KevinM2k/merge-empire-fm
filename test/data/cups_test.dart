import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/cups.dart';
import 'package:merge_empire_fc/data/divisions.dart';

void main() {
  group('the cup list', () {
    test('holds the four competitions in unlock order', () {
      expect(cups.map((c) => c.id), [
        'regional_cup',
        'national_cup',
        'continental_cup',
        'world_club_cup',
      ]);
    });

    test('names and short names', () {
      expect(cups.map((c) => c.name), [
        'Regional Cup',
        'National Cup',
        'Continental Cup',
        'World Club Cup',
      ]);
      expect(cups.map((c) => c.shortName), ['RC', 'NC', 'CC', 'WCC']);
    });

    test('unlock indices', () {
      expect(cups.map((c) => c.unlocksAtDivisionIdx), [2, 3, 4, 6]);
    });

    test('ids and short names are unique', () {
      expect(cups.map((c) => c.id).toSet().length, cups.length);
      expect(cups.map((c) => c.shortName).toSet().length, cups.length);
    });

    test('colours match their unlocking division', () {
      for (final cup in cups) {
        expect(
          cup.color,
          divisions[cup.unlocksAtDivisionIdx].color,
          reason: cup.id,
        );
      }
    });
  });

  group('structure', () {
    test('every cup runs the same QF to final pyramid', () {
      for (final cup in cups) {
        expect(
          cup.rounds,
          ['Quarter-Final', 'Semi-Final', 'Final'],
          reason: cup.id,
        );
      }
    });

    test('bump and prize arrays line up with the rounds', () {
      for (final cup in cups) {
        expect(cup.opponentRatingBump.length, cup.rounds.length, reason: cup.id);
        expect(cup.roundPrizeMult.length, cup.rounds.length, reason: cup.id);
      }
    });

    test('opponent bumps per cup', () {
      expect(cups.map((c) => c.opponentRatingBump), [
        [4, 10, 18],
        [6, 12, 22],
        [8, 14, 26],
        [10, 18, 30],
      ]);
    });

    test('round prize multipliers per cup', () {
      expect(cups.map((c) => c.roundPrizeMult), [
        [1.0, 1.4, 2.0],
        [1.0, 1.6, 2.2],
        [1.0, 1.6, 2.4],
        [1.0, 1.8, 2.8],
      ]);
    });

    test('there is no separate winner prize — the sponsor drop is the reward', () {
      for (final cup in cups) {
        expect(cup.winnerPrizeMult, 0, reason: cup.id);
      }
    });
  });

  group('difficulty and reward curves', () {
    test('opponents get harder every round', () {
      for (final cup in cups) {
        for (var i = 1; i < cup.opponentRatingBump.length; i++) {
          expect(
            cup.opponentRatingBump[i],
            greaterThan(cup.opponentRatingBump[i - 1]),
            reason: '${cup.id} round $i',
          );
        }
      }
    });

    test('the final is a significant jump, not another step', () {
      for (final cup in cups) {
        final semiStep = cup.opponentRatingBump[1] - cup.opponentRatingBump[0];
        final finalStep = cup.opponentRatingBump[2] - cup.opponentRatingBump[1];
        expect(finalStep, greaterThan(semiStep), reason: cup.id);
      }
    });

    test('prizes rise every round', () {
      for (final cup in cups) {
        for (var i = 1; i < cup.roundPrizeMult.length; i++) {
          expect(
            cup.roundPrizeMult[i],
            greaterThan(cup.roundPrizeMult[i - 1]),
            reason: '${cup.id} round $i',
          );
        }
      }
    });

    test('the opening round always pays a normal league win', () {
      for (final cup in cups) {
        expect(cup.roundPrizeMult.first, 1.0, reason: cup.id);
      }
    });

    test('later cups are harder and pay better than earlier ones', () {
      for (var i = 1; i < cups.length; i++) {
        expect(
          cups[i].opponentRatingBump.last,
          greaterThan(cups[i - 1].opponentRatingBump.last),
          reason: cups[i].id,
        );
        expect(
          cups[i].roundPrizeMult.last,
          greaterThanOrEqualTo(cups[i - 1].roundPrizeMult.last),
          reason: cups[i].id,
        );
      }
    });

    test('cups unlock strictly up the ladder and within it', () {
      for (var i = 1; i < cups.length; i++) {
        expect(
          cups[i].unlocksAtDivisionIdx,
          greaterThan(cups[i - 1].unlocksAtDivisionIdx),
        );
      }
      for (final cup in cups) {
        expect(cup.unlocksAtDivisionIdx, inInclusiveRange(0, divisions.length - 1));
      }
    });

    test('no cup unlocks in the bottom two divisions', () {
      // Regional League is the earliest, which is where the parallel track
      // starts being worth running.
      for (final cup in cups) {
        expect(cup.unlocksAtDivisionIdx, greaterThanOrEqualTo(2), reason: cup.id);
      }
    });
  });

  group('getCupById', () {
    test('finds a known cup', () {
      expect(getCupById('national_cup')?.name, 'National Cup');
    });

    test('returns null for an unknown id', () {
      expect(getCupById('fa_cup'), isNull);
      expect(getCupById(null), isNull);
    });
  });

  group('flavour pools', () {
    test('the opponent pool has 16 unique names', () {
      expect(cupOpponentPool.length, 16);
      expect(cupOpponentPool.toSet().length, 16);
    });

    test('the context pool has 12 unique lines', () {
      expect(cupOpponentContext.length, 12);
      expect(cupOpponentContext.toSet().length, 12);
    });

    test('every context line carries the {team} placeholder', () {
      for (final line in cupOpponentContext) {
        expect(line, contains('{team}'), reason: line);
      }
    });

    test('no pool entry is blank', () {
      for (final name in cupOpponentPool) {
        expect(name.trim(), isNotEmpty);
      }
      for (final line in cupOpponentContext) {
        expect(line.trim(), isNotEmpty);
      }
    });
  });
}
