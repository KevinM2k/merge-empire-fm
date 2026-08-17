import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/traits.dart';

/// The effect vector of a level, used to assert the file's central design rule:
/// no two traits do the same mechanical job.
List<num> _vector(TraitLevel l) => [
  l.atkBonus,
  l.defBonus,
  l.incomeBonus,
  l.matchRevBonus,
  l.injuryReduction,
  l.teamInjuryReduction,
  l.agingReduction,
  l.recoveryBonus,
  l.staminaMult ?? 0,
];

void main() {
  group('the trait bank', () {
    test('holds 21 traits', () {
      // 4 FWD + 4 MID + 4 DEF + 3 GK + `none` + 5 universal.
      expect(traits.length, 21);
      expect(traitList.length, 21);
    });

    test('every key matches its trait id', () {
      traits.forEach((key, trait) {
        expect(trait.id, key);
      });
    });

    test('every trait has a name, icon, type and description', () {
      for (final t in traitList) {
        expect(t.name, isNotEmpty, reason: t.id);
        expect(t.icon, isNotEmpty, reason: t.id);
        expect(t.type, isNotEmpty, reason: t.id);
        expect(t.desc, isNotEmpty, reason: t.id);
      }
    });

    test('every trait has exactly three levels, numbered 1 to 3', () {
      for (final t in traitList) {
        expect(t.levels.map((l) => l.level), [1, 2, 3], reason: t.id);
      }
    });

    test('level labels are I / II / III except for none', () {
      for (final t in traitList.where((t) => t.id != 'none')) {
        expect(t.levels.map((l) => l.label), ['I', 'II', 'III'], reason: t.id);
      }
      expect(traits['none']!.levels.map((l) => l.label), ['', '', '']);
    });

    test('positions are real, and universals declare null', () {
      for (final t in traitList) {
        if (t.positions == null) continue;
        for (final p in t.positions!) {
          expect(['FWD', 'MID', 'DEF', 'GK'], contains(p), reason: t.id);
        }
      }
    });

    test('every position has four dedicated traits', () {
      for (final pos in ['FWD', 'MID', 'DEF', 'GK']) {
        final dedicated =
            traitList.where((t) => t.positions?.contains(pos) ?? false);
        expect(dedicated.length, pos == 'GK' ? 3 : 4, reason: pos);
      }
    });
  });

  group('the design rules', () {
    test('no two traits share an effect vector at any level', () {
      // The file states this outright: every trait is mechanically distinct.
      // `none` is the deliberate all-zero exception.
      final seen = <String, String>{};
      for (final t in traitList.where((t) => t.id != 'none')) {
        for (final l in t.levels) {
          final key = '${l.level}:${_vector(l).join(",")}';
          expect(
            seen.containsKey(key),
            isFalse,
            reason: '${t.id} L${l.level} duplicates ${seen[key]}',
          );
          seen[key] = '${t.id} L${l.level}';
        }
      }
    });

    test('every trait except none actually does something', () {
      for (final t in traitList.where((t) => t.id != 'none')) {
        for (final l in t.levels) {
          expect(
            _vector(l).any((v) => v != 0),
            isTrue,
            reason: '${t.id} L${l.level} has no effect',
          );
        }
      }
    });

    test('none has no effect at any level', () {
      for (final l in traits['none']!.levels) {
        expect(_vector(l).every((v) => v == 0), isTrue);
      }
    });

    test('every effect grows with level', () {
      for (final t in traitList.where((t) => t.id != 'none')) {
        for (var i = 1; i < t.levels.length; i++) {
          final prev = _vector(t.levels[i - 1]);
          final now = _vector(t.levels[i]);
          for (var axis = 0; axis < prev.length; axis++) {
            if (prev[axis] == 0 && now[axis] == 0) continue;
            // staminaMult is the one axis where lower is stronger.
            if (axis == 8) {
              expect(now[axis], lessThan(prev[axis]), reason: '${t.id} stamina');
            } else {
              expect(
                now[axis],
                greaterThan(prev[axis]),
                reason: '${t.id} L${i + 1} axis $axis',
              );
            }
          }
        }
      }
    });

    test('an effect axis a trait uses at level 1 is used at every level', () {
      for (final t in traitList.where((t) => t.id != 'none')) {
        final first = _vector(t.levels.first);
        for (final l in t.levels.skip(1)) {
          final v = _vector(l);
          for (var axis = 0; axis < first.length; axis++) {
            expect(
              first[axis] == 0,
              v[axis] == 0,
              reason: '${t.id} axis $axis appears or vanishes between levels',
            );
          }
        }
      }
    });

    test('a universal never beats the best position trait at its own job', () {
      // Universals trade peak power for never being wasted.
      final allrounder = getTraitLevel(traits['allrounder'], 3)!;
      expect(allrounder.atkBonus, lessThan(getTraitLevel(traits['finisher'], 3)!.atkBonus));
      expect(allrounder.defBonus, lessThan(getTraitLevel(traits['ironwall'], 3)!.defBonus));

      final crowd = getTraitLevel(traits['crowdpleaser'], 3)!;
      expect(crowd.incomeBonus, lessThan(getTraitLevel(traits['playmaker'], 3)!.incomeBonus));
      expect(crowd.matchRevBonus, lessThan(getTraitLevel(traits['commanding'], 3)!.matchRevBonus));
    });

    test('the named superlatives hold', () {
      // Each description claims a "biggest" — the numbers must agree.
      num best(String axis) {
        num top = 0;
        for (final t in traitList) {
          final l = getTraitLevel(t, 3)!;
          final v = switch (axis) {
            'income' => l.incomeBonus,
            'matchRev' => l.matchRevBonus,
            'injury' => l.injuryReduction,
            'aging' => l.agingReduction,
            _ => 0,
          };
          if (v > top) top = v;
        }
        return top;
      }

      expect(getTraitLevel(traits['playmaker'], 3)!.incomeBonus, best('income'));
      expect(getTraitLevel(traits['commanding'], 3)!.matchRevBonus, best('matchRev'));
      expect(getTraitLevel(traits['tough'], 3)!.injuryReduction, best('injury'));
      expect(getTraitLevel(traits['rock'], 3)!.agingReduction, best('aging'));
    });

    test('only sweeper cuts injury risk squad-wide', () {
      final squadWide =
          traitList.where((t) => getTraitLevel(t, 3)!.teamInjuryReduction > 0);
      expect(squadWide.map((t) => t.id), ['sweeper']);
    });

    test('only iron_lungs touches stamina', () {
      final stamina = traitList.where((t) => t.type == 'stamina');
      expect(stamina.map((t) => t.id), ['iron_lungs']);
      expect(
        traitList.where((t) => t.levels.any((l) => l.staminaMult != null)).map((t) => t.id),
        ['iron_lungs'],
      );
    });
  });

  group('scaling constants', () {
    test('values', () {
      expect(traitStatScale, 0.38);
      expect(traitXiStarTarget, 5);
    });

    test('the scale shrinks bonuses rather than growing them', () {
      // It exists because flat bonuses hit the 100 clamp and inverted the
      // power curve at the top of the ladder.
      expect(traitStatScale, greaterThan(0));
      expect(traitStatScale, lessThan(1));
    });

    test('the XI target stays under the smallest division edge', () {
      // divisions.js tunes its bands against a maxed squad's NO-TRAIT star,
      // with the Champions ceiling ~1 point under it. A much larger target
      // would erase the "edge shrinks as you climb" curve.
      expect(traitXiStarTarget, lessThanOrEqualTo(7));
    });
  });

  group('getTrait / getTraitLevel', () {
    test('finds a known trait', () {
      expect(getTrait('finisher')?.name, 'Finisher');
    });

    test('returns null for an unknown or null id', () {
      expect(getTrait('nonesuch'), isNull);
      expect(getTrait(null), isNull);
    });

    test('finds a level', () {
      expect(getTraitLevel(traits['finisher'], 2)?.atkBonus, 8);
    });

    test('returns null for a missing level or trait', () {
      expect(getTraitLevel(traits['finisher'], 4), isNull);
      expect(getTraitLevel(traits['finisher'], 0), isNull);
      expect(getTraitLevel(null, 1), isNull);
    });
  });

  group('getTraitPoolForPosition', () {
    test('offers position traits first, then universals', () {
      final pool = getTraitPoolForPosition('FWD');
      final ids = pool.map((t) => t.id).toList();

      expect(ids.take(4), ['finisher', 'pressing', 'poacher', 'speedster']);
      expect(ids, contains('allrounder'));
      expect(ids, isNot(contains('ironwall')));
    });

    test('excludes stamina traits outside Pro mode', () {
      // A Casual player must never roll a trait that does nothing for them.
      expect(
        getTraitPoolForPosition('MID').map((t) => t.id),
        isNot(contains('iron_lungs')),
      );
    });

    test('includes stamina traits in Pro mode', () {
      expect(
        getTraitPoolForPosition('MID', hardMode: true).map((t) => t.id),
        contains('iron_lungs'),
      );
    });

    test('a null position returns the whole usable list', () {
      expect(getTraitPoolForPosition(null).length, traitList.length - 1);
      expect(
        getTraitPoolForPosition(null, hardMode: true).length,
        traitList.length,
      );
    });

    test('every position gets a non-trivial pool', () {
      for (final pos in ['FWD', 'MID', 'DEF', 'GK']) {
        expect(
          getTraitPoolForPosition(pos).length,
          greaterThanOrEqualTo(8),
          reason: pos,
        );
      }
    });

    test('no trait appears twice in a pool', () {
      for (final pos in ['FWD', 'MID', 'DEF', 'GK']) {
        final ids = getTraitPoolForPosition(pos, hardMode: true).map((t) => t.id).toList();
        expect(ids.toSet().length, ids.length, reason: pos);
      }
    });

    test('the none trait is offered as a universal', () {
      // It is positions: null, so it lands in the universal half — which is how
      // a roll can clear an existing trait.
      expect(getTraitPoolForPosition('FWD').map((t) => t.id), contains('none'));
    });
  });
}
