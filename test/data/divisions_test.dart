import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/divisions.dart';

void main() {
  group('the ladder', () {
    test('has 7 divisions in order', () {
      expect(divisions.map((d) => d.id), [
        'sunday_league',
        'amateur_cup',
        'regional_league',
        'national_league',
        'elite_league',
        'continental',
        'champions_cup',
      ]);
    });

    test('names and short names', () {
      expect(divisions.map((d) => d.name), [
        'Sunday League',
        'Amateur League',
        'Regional League',
        'National League',
        'Elite League',
        'Continental League',
        'Champions League',
      ]);
      expect(divisions.map((d) => d.shortName), [
        'SL',
        'AL',
        'RL',
        'NL',
        'EL',
        'CL',
        'ChL',
      ]);
    });

    test('match revenue bases', () {
      expect(divisions.map((d) => d.matchRevenueBase), [
        100,
        250,
        600,
        1500,
        4000,
        20000,
        120000,
      ]);
    });

    test('every division shares the 30s match cooldown', () {
      for (final d in divisions) {
        expect(d.matchCooldownMs, 30 * 1000, reason: d.id);
      }
    });

    test('colours', () {
      expect(divisions.map((d) => d.color), [
        '#8d6e63',
        '#78909c',
        '#66bb6a',
        '#42a5f5',
        '#ab47bc',
        '#ff7043',
        '#ffd700',
      ]);
    });

    test('ids are unique', () {
      expect(divisions.map((d) => d.id).toSet().length, divisions.length);
    });
  });

  group('progression invariants', () {
    test('matchRevenueBase rises every step', () {
      for (var i = 1; i < divisions.length; i++) {
        expect(
          divisions[i].matchRevenueBase,
          greaterThan(divisions[i - 1].matchRevenueBase),
        );
      }
    });

    test('tier caps rise by exactly one per division', () {
      for (var i = 0; i < divisions.length; i++) {
        expect(divisions[i].maxPlayerTier, i + 2, reason: divisions[i].id);
        expect(divisions[i].maxAssetTier, i + 2, reason: divisions[i].id);
      }
    });

    test('player and asset tier caps move together', () {
      for (final d in divisions) {
        expect(d.maxPlayerTier, d.maxAssetTier, reason: d.id);
      }
    });

    test('opponent rating ranges rise up the ladder', () {
      for (var i = 1; i < divisions.length; i++) {
        expect(
          divisions[i].opponentRatingRange.$1,
          greaterThanOrEqualTo(divisions[i - 1].opponentRatingRange.$1),
        );
        expect(
          divisions[i].opponentRatingRange.$2,
          greaterThan(divisions[i - 1].opponentRatingRange.$2),
        );
      }
    });

    test('every rating range is a valid low-high pair', () {
      for (final d in divisions) {
        final (lo, hi) = d.opponentRatingRange;
        expect(lo, lessThan(hi), reason: d.id);
        expect(lo, greaterThan(0), reason: d.id);
        expect(hi, lessThanOrEqualTo(100), reason: d.id);
      }
    });

    test('the opponent ceiling widens as you climb', () {
      // divisions.js: the band gets wider up the ladder, so the top division is
      // a genuine title race rather than a single beatable rating.
      final spreads = divisions
          .map((d) => d.opponentRatingRange.$2 - d.opponentRatingRange.$1)
          .toList();
      expect(spreads.last, greaterThan(spreads.first));
    });

    test('the edge a maxed squad holds shrinks as you climb', () {
      // The design note in divisions.js: a maxed squad is miles clear of the
      // best opponent at the bottom (~+7) and only just the best at the top
      // (~+1), which is what keeps the endgame a title race.
      const maxedTeamStar = <String, int>{
        'sunday_league': 31,
        'amateur_cup': 40,
        'regional_league': 48,
        'national_league': 57,
        'elite_league': 68,
        'continental': 79,
        'champions_cup': 89,
      };

      final edges = divisions
          .map((d) => maxedTeamStar[d.id]! - d.opponentRatingRange.$2)
          .toList();

      expect(edges.first, greaterThanOrEqualTo(6));
      expect(edges.last, lessThanOrEqualTo(2));
      expect(
        edges.last,
        lessThan(edges.first),
        reason: 'the difficulty curve must tighten, not loosen',
      );
    });

    test('every division has a scout and asset cost entry', () {
      for (final d in divisions) {
        expect(Scout.baseCostByDiv.containsKey(d.id), isTrue, reason: d.id);
        expect(Asset.baseCostByDiv.containsKey(d.id), isTrue, reason: d.id);
        expect(Minigame.baseByDiv.containsKey(d.id), isTrue, reason: d.id);
      }
    });
  });

  group('getDivision', () {
    test('returns the division for a known id', () {
      expect(getDivision('sunday_league').name, 'Sunday League');
      expect(getDivision('champions_cup').name, 'Champions League');
    });

    test('falls back to the first division for an unknown id', () {
      expect(getDivision('unknown').id, 'sunday_league');
    });

    test('falls back for an empty id', () {
      expect(getDivision('').id, 'sunday_league');
    });
  });

  group('getNextDivision', () {
    test('returns the next division up', () {
      expect(getNextDivision('sunday_league')?.id, 'amateur_cup');
      expect(getNextDivision('elite_league')?.id, 'continental');
    });

    test('returns null at the top', () {
      expect(getNextDivision('champions_cup'), isNull);
    });

    test('returns null for an unknown id', () {
      expect(getNextDivision('unknown'), isNull);
    });

    test('walks the whole ladder from the bottom', () {
      final walked = <String>['sunday_league'];
      var next = getNextDivision(walked.last);
      while (next != null) {
        walked.add(next.id);
        next = getNextDivision(next.id);
      }
      expect(walked, divisions.map((d) => d.id).toList());
    });
  });

  /// **Six mini-games ramp off this and there were two of it** — one in
  /// `penalty_game_engine.dart` documented as shared, and a
  /// character-for-character copy that lived in `boot_room_screen.dart` and was
  /// imported by four sibling screens. Nothing was broken yet, which is always
  /// the case at birth; the reason to have one is that two disagree later.
  group('currentDivisionIndex', () {
    Map<String, dynamic> stateIn(String id) => {
      'progression': <String, dynamic>{'currentDivision': id},
    };

    test('is the position on the ladder', () {
      for (var i = 0; i < divisions.length; i++) {
        expect(currentDivisionIndex(stateIn(divisions[i].id)), i,
            reason: divisions[i].id);
      }
    });

    test('AN UNREADABLE SAVE IS THE BOTTOM RUNG, not minus one', () {
      // Every caller feeds this straight into a difficulty table. A raw
      // `indexWhere` miss is -1, which is an easier opponent than the easiest
      // in the ones that clamp and a range error in the ones that index.
      expect(currentDivisionIndex(null), 0);
      expect(currentDivisionIndex({}), 0);
      expect(currentDivisionIndex({'progression': 'not a map'}), 0);
      expect(currentDivisionIndex(stateIn('no-such-division')), 0);
      expect(currentDivisionIndex({'progression': <String, dynamic>{}}), 0);
    });

    test('and it agrees with getDivision on the same save', () {
      // Two ways of asking which division a save is on, and the ladder is the
      // one place that answers both.
      for (final d in divisions) {
        final state = stateIn(d.id);
        expect(divisions[currentDivisionIndex(state)].id, getDivision(d.id).id);
      }
    });
  });
}
