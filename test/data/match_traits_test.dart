import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/match_traits.dart';

void main() {
  group('the match trait pool', () {
    test('IS TWELVE, AND EVERY ONE IS CONDITIONAL', () {
      expect(matchTraitList.length, 12);
      expect(matchTraits.length, 12);
      // The whole balance argument: a trait that fires in every match would
      // move the baseline squad star the division bands are tuned against.
      for (final t in matchTraitList) {
        expect(t.condition, isNotNull, reason: '${t.id} has no condition');
      }
    });

    test('every key matches its trait id', () {
      matchTraits.forEach((key, trait) {
        expect(trait.id, key);
      });
    });

    test('every trait has a name, icon and description', () {
      for (final t in matchTraitList) {
        expect(t.name, isNotEmpty, reason: t.id);
        expect(t.icon, isNotEmpty, reason: t.id);
        expect(t.desc, isNotEmpty, reason: t.id);
      }
    });

    test('every trait has three levels, labelled I / II / III', () {
      for (final t in matchTraitList) {
        expect(t.levels.map((l) => l.level), [1, 2, 3], reason: t.id);
        expect(t.levels.map((l) => l.label), ['I', 'II', 'III'], reason: t.id);
      }
    });

    // **THE LADDER IS THE BALANCE, so it is asserted rather than commented.**
    // A rarer condition must be worth at least as much at every level, or the
    // common traits are strictly better and the rare ones are dead rolls.
    //
    // Super Sub is not on it: its condition is not a frequency but a decision
    // the manager makes, so it is priced separately below.
    test('A RARER CONDITION CARRIES A BIGGER NUMBER AT EVERY LEVEL', () {
      const ordered = [
        'fortress',
        'away_day',
        'big_game',
        'fast_starter',
        'relegation_scrapper',
        'last_gasp',
        'cup_fighter',
        'derby_devil',
      ];
      for (var i = 1; i < ordered.length; i++) {
        final prev = matchTraits[ordered[i - 1]]!;
        final cur = matchTraits[ordered[i]]!;
        for (var l = 0; l < 3; l++) {
          expect(
            cur.levels[l].mult,
            greaterThanOrEqualTo(prev.levels[l].mult),
            reason: '${cur.id} L${l + 1} must not be under ${prev.id}',
          );
        }
      }
    });

    // The only condition the MANAGER triggers, so it may out-lift the rarest
    // roll of the dice. Ten Man Wall is excluded: its number is per head across
    // the whole side and is not comparable to a single man's.
    test('Super Sub is the biggest single-player lift', () {
      final sub = matchTraits['super_sub']!;
      for (final t in matchTraitList) {
        if (t.id == 'super_sub') continue;
        if (t.condition == MatchTraitCondition.booked) continue;
        if (t.condition == MatchTraitCondition.injuryShrug) continue;
        if (t.condition == MatchTraitCondition.tenMen) continue;
        for (var l = 0; l < 3; l++) {
          expect(sub.levels[l].mult, greaterThan(t.levels[l].mult),
              reason: '${t.id} L${l + 1}');
        }
      }
    });

    test('a level III is always worth more than its own level I', () {
      for (final t in matchTraitList) {
        expect(t.levels[2].mult, greaterThan(t.levels[0].mult), reason: t.id);
      }
    });

    test('a rating multiplier is a lift, never a cut', () {
      for (final t in matchTraitList) {
        if (t.condition == MatchTraitCondition.booked) continue;
        if (t.condition == MatchTraitCondition.injuryShrug) continue;
        for (final l in t.levels) {
          expect(l.mult, greaterThan(1.0), reason: '${t.id} ${l.label}');
        }
      }
    });

    // Ice Veins REPLACES the 0.9 rather than adding to it, so its ladder runs
    // up toward 1.0 and its level III is a man who plays exactly as he did.
    test('Ice Veins climbs to exactly 1.0', () {
      final ice = matchTraits['ice_veins']!;
      expect(ice.condition, MatchTraitCondition.booked);
      expect(ice.levels.map((l) => l.mult), [0.94, 0.97, 1.00]);
    });

    test('Warrior is a probability', () {
      final w = matchTraits['warrior']!;
      expect(w.condition, MatchTraitCondition.injuryShrug);
      for (final l in w.levels) {
        expect(l.mult, inExclusiveRange(0, 1), reason: l.label);
      }
    });

    test('Ten Man Wall is squad-wide, so it is capped', () {
      expect(matchTraitSquadCap, 0.12);
      final wall = matchTraits['ten_man_wall']!;
      expect(wall.condition, MatchTraitCondition.tenMen);
      expect(wall.levels[2].mult - 1, lessThan(matchTraitSquadCap));
    });

    test('lookups tolerate a null or unknown id', () {
      expect(getMatchTrait(null), isNull);
      expect(getMatchTrait('nope'), isNull);
      expect(getMatchTraitLevel(null, 1), isNull);
      expect(getMatchTraitLevel(matchTraits['fortress'], 4), isNull);
      expect(getMatchTraitLevel(matchTraits['fortress'], 2)?.label, 'II');
    });
  });
}
