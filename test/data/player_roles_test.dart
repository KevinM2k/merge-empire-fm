import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/data/player_roles.dart';

FormationSlot _slot(String formation, String id) =>
    formations[formation]!.slots.firstWhere((s) => s.slotId == id);

void main() {
  group('the role table', () {
    test('holds three roles and a natural setting', () {
      expect(playerRoles.keys.toSet(), {
        'winger',
        'insideForward',
        'widePlaymaker',
      });
      expect(roleIds.first, naturalRole);
      expect(roleIds.length, 4);
      for (final r in playerRoles.entries) {
        expect(r.value.id, r.key);
        expect(r.value.across, greaterThan(0));
        expect(r.value.along, greaterThan(0));
      }
    });

    test('a winger goes outside, the other two come in', () {
      expect(playerRoles['winger']!.inward, lessThan(0));
      expect(playerRoles['insideForward']!.inward, greaterThan(0));
      expect(playerRoles['widePlaymaker']!.inward, greaterThan(0));
      // And the playmaker is the one who drops.
      expect(playerRoles['widePlaymaker']!.forward, lessThan(0));
      expect(playerRoles['insideForward']!.forward, greaterThan(0));
    });
  });

  group('isWideSlot', () {
    test('is the outer quarter, for a midfielder or a forward', () {
      expect(isWideSlot(_slot('4-4-2', 'rm')), isTrue);
      expect(isWideSlot(_slot('4-4-2', 'lm')), isTrue);
      expect(isWideSlot(_slot('4-3-3', 'rf')), isTrue);
      expect(isWideSlot(_slot('4-3-3', 'lf')), isTrue);
      expect(isWideSlot(_slot('4-2-3-1', 'rw')), isTrue);
      expect(isWideSlot(_slot('3-5-2', 'lwb')), isTrue);
      expect(isWideSlot(_slot('3-5-2', 'rcm')), isFalse);
      expect(isWideSlot(_slot('4-4-2', 'rcm')), isFalse);
      expect(isWideSlot(_slot('4-3-3', 'cf')), isFalse);
    });

    test('never a defender or the keeper, however wide they stand', () {
      expect(isWideSlot(_slot('5-3-2', 'rb')), isFalse);
      expect(isWideSlot(_slot('4-4-2', 'lb')), isFalse);
      expect(isWideSlot(_slot('4-4-2', 'gk')), isFalse);
    });

    test('every shape offers at least two wide slots', () {
      for (final f in formations.values) {
        expect(
          f.slots.where(isWideSlot).length,
          greaterThanOrEqualTo(2),
          reason: f.id,
        );
      }
    });
  });

  group('reading the save', () {
    test('rolesOf keeps only known roles', () {
      expect(rolesOf(null), isEmpty);
      expect(rolesOf({}), isEmpty);
      expect(rolesOf({'roles': 'x'}), isEmpty);
      expect(
        rolesOf({
          'roles': {
            'rf': 'insideForward',
            'lf': 'sweeper',
            'rm': 3,
            'lm': 'winger',
          },
        }),
        {'rf': 'insideForward', 'lm': 'winger'},
      );
    });

    test('roleFor is the role or null', () {
      expect(roleFor({'rf': 'winger'}, 'rf'), playerRoles['winger']);
      expect(roleFor({'rf': 'winger'}, 'lf'), isNull);
      expect(roleFor({'rf': 'nonsense'}, 'rf'), isNull);
      expect(roleFor(null, 'rf'), isNull);
    });
  });
}
