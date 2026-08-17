import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/state/card_instance.dart';

CardInstance _card(String id, {bool injured = false, bool listed = false, Object? loanedOut}) =>
    CardInstance({
      'instanceId': id,
      'definitionId': 'player_t1_mid',
      if (injured) 'injured': true,
      if (listed) 'listed': true,
      'loanedOut': ?loanedOut,
    });

void main() {
  group('the formation table', () {
    test('holds the five shipped shapes', () {
      expect(formations.keys.toSet(), {
        '4-3-3',
        '4-4-2',
        '4-2-3-1',
        '5-3-2',
        '3-5-2',
      });
    });

    test('the default is 4-3-3', () {
      expect(defaultFormation, '4-3-3');
      expect(formations.containsKey(defaultFormation), isTrue);
    });

    test('every formation fields exactly eleven players', () {
      formations.forEach((id, f) {
        expect(f.slots.length, 11, reason: id);
      });
    });

    test('every formation has exactly one keeper', () {
      formations.forEach((id, f) {
        expect(
          f.slots.where((s) => s.slotPosition == 'GK').length,
          1,
          reason: id,
        );
      });
    });

    test('slot ids are unique within a formation', () {
      formations.forEach((id, f) {
        expect(f.slots.map((s) => s.slotId).toSet().length, 11, reason: id);
      });
    });

    test('id matches the map key and label', () {
      formations.forEach((id, f) {
        expect(f.id, id);
        expect(f.label, id);
      });
    });

    test('styles are drawn from the known set', () {
      formations.forEach((id, f) {
        expect(
          ['attacking', 'balanced', 'defensive'],
          contains(f.style),
          reason: id,
        );
      });
    });

    test('every slot position is a real position', () {
      formations.forEach((id, f) {
        for (final s in f.slots) {
          expect(['GK', 'DEF', 'MID', 'FWD'], contains(s.slotPosition), reason: id);
        }
      });
    });

    test('every slot sits inside the pitch', () {
      formations.forEach((id, f) {
        for (final s in f.slots) {
          expect(s.x, inInclusiveRange(0, 100), reason: '$id ${s.slotId}');
          expect(s.y, inInclusiveRange(0, 100), reason: '$id ${s.slotId}');
        }
      });
    });

    test('the keeper stands deepest in every formation', () {
      formations.forEach((id, f) {
        final gk = f.slots.firstWhere((s) => s.slotPosition == 'GK');
        for (final s in f.slots.where((s) => s.slotPosition != 'GK')) {
          expect(gk.y, greaterThan(s.y), reason: '$id ${s.slotId}');
        }
      });
    });

    test('the shape name describes the outfield line-up', () {
      // 4-3-3 means four defenders, three midfielders, three forwards.
      formations.forEach((id, f) {
        final parts = id.split('-').map(int.parse).toList();
        final def = f.slots.where((s) => s.slotPosition == 'DEF').length;
        final mid = f.slots.where((s) => s.slotPosition == 'MID').length;
        final fwd = f.slots.where((s) => s.slotPosition == 'FWD').length;

        expect(def, parts.first, reason: '$id defenders');
        expect(fwd, parts.last, reason: '$id forwards');
        // Middle bands collapse into MID slots.
        expect(
          mid,
          parts.sublist(1, parts.length - 1).reduce((a, b) => a + b),
          reason: '$id midfielders',
        );
      });
    });
  });

  group('getFormation', () {
    test('returns a known formation', () {
      expect(getFormation('4-4-2').id, '4-4-2');
    });

    test('falls back to the default for an unknown id', () {
      expect(getFormation('9-0-1').id, defaultFormation);
    });

    test('falls back to the default for null', () {
      expect(getFormation(null).id, defaultFormation);
    });
  });

  group('benchCandidates', () {
    test('offers everyone not already on the pitch', () {
      final grid = [_card('a'), _card('b'), _card('c')];
      final lineup = [
        const LineupSlot(slotId: 'gk', slotPosition: 'GK', cardInstanceId: 'a'),
      ];

      expect(
        benchCandidates(grid, lineup).map((c) => c.instanceId),
        ['b', 'c'],
      );
    });

    test('keeps injured players on the bench list', () {
      // The panel renders them greyed with the reason — the manager is usually
      // there BECAUSE someone limped off, so seeing who else is out is the point.
      final grid = [_card('a', injured: true), _card('b')];
      expect(
        benchCandidates(grid, const []).map((c) => c.instanceId),
        ['a', 'b'],
      );
    });

    test('drops listed and loaned-out players', () {
      // They are at another club or advertised for sale, not at the ground.
      // Offering one spent a substitution to field a zero-rated ghost.
      final grid = [
        _card('a', listed: true),
        _card('b', loanedOut: 'rival'),
        _card('c'),
      ];
      expect(
        benchCandidates(grid, const []).map((c) => c.instanceId),
        ['c'],
      );
    });

    test('tolerates empty grid slots', () {
      final grid = [_card('a'), null, _card('b')];
      expect(benchCandidates(grid, const []).length, 2);
    });

    test('an empty lineup offers the whole grid', () {
      final grid = [_card('a'), _card('b')];
      expect(benchCandidates(grid, const []).length, 2);
    });

    test('ignores lineup slots with no card', () {
      final grid = [_card('a')];
      final lineup = [
        const LineupSlot(slotId: 'gk', slotPosition: 'GK', cardInstanceId: null),
      ];
      expect(benchCandidates(grid, lineup).length, 1);
    });
  });

  group('migrateLineup', () {
    List<LineupSlot> lineupFor(String formationId, List<String?> ids) {
      final slots = getFormation(formationId).slots;
      return [
        for (var i = 0; i < slots.length; i++)
          LineupSlot(
            slotId: slots[i].slotId,
            slotPosition: slots[i].slotPosition,
            cardInstanceId: ids.length > i ? ids[i] : null,
          ),
      ];
    }

    test('produces a lineup shaped like the target formation', () {
      final from = lineupFor('4-3-3', List.generate(11, (i) => 'c$i'));
      final to = migrateLineup(from, '4-4-2');

      expect(to.length, 11);
      expect(
        to.map((s) => s.slotId),
        getFormation('4-4-2').slots.map((s) => s.slotId),
      );
    });

    test('keeps position-matched players in their role', () {
      final from = lineupFor('4-3-3', List.generate(11, (i) => 'c$i'));
      final to = migrateLineup(from, '4-4-2');

      // c0 is the keeper in 4-3-3 and must still be the keeper in 4-4-2.
      expect(
        to.firstWhere((s) => s.slotPosition == 'GK').cardInstanceId,
        'c0',
      );
    });

    test('places every card somewhere when the counts allow', () {
      final from = lineupFor('4-3-3', List.generate(11, (i) => 'c$i'));
      final to = migrateLineup(from, '4-4-2');

      final placed = to.map((s) => s.cardInstanceId).whereType<String>().toSet();
      expect(placed.length, 11);
    });

    test('never places the same card twice', () {
      final from = lineupFor('4-3-3', List.generate(11, (i) => 'c$i'));
      for (final target in formations.keys) {
        final to = migrateLineup(from, target);
        final placed = to.map((s) => s.cardInstanceId).whereType<String>().toList();
        expect(placed.toSet().length, placed.length, reason: target);
      }
    });

    test('spare cards fall into whatever slots remain', () {
      // 4-3-3 has three forwards; 4-2-3-1 has one, so two forwards must be
      // rehoused rather than dropped.
      final from = lineupFor('4-3-3', List.generate(11, (i) => 'c$i'));
      final to = migrateLineup(from, '4-2-3-1');
      final placed = to.map((s) => s.cardInstanceId).whereType<String>().toSet();
      expect(placed.length, 11);
    });

    test('a partly empty lineup migrates without inventing cards', () {
      final from = lineupFor('4-3-3', ['c0', null, 'c2']);
      final to = migrateLineup(from, '4-4-2');
      final placed = to.map((s) => s.cardInstanceId).whereType<String>().toSet();
      expect(placed, {'c0', 'c2'});
    });

    test('migrating to the same formation is a no-op on assignments', () {
      final from = lineupFor('4-3-3', List.generate(11, (i) => 'c$i'));
      final to = migrateLineup(from, '4-3-3');
      expect(
        to.map((s) => s.cardInstanceId),
        from.map((s) => s.cardInstanceId),
      );
    });

    test('an unknown target formation falls back to the default', () {
      final from = lineupFor('4-3-3', List.generate(11, (i) => 'c$i'));
      final to = migrateLineup(from, 'nonsense');
      expect(
        to.map((s) => s.slotId),
        getFormation(defaultFormation).slots.map((s) => s.slotId),
      );
    });
  });
}
