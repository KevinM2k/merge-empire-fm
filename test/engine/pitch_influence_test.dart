import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/data/player_roles.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/pitch_influence.dart';
import 'package:merge_empire_fc/engine/pitch_space.dart';

/// Which zone a point lands in, for pinning the frame: floor to a lane and a
/// band, the far edges folded onto the grid.
int zoneAt(PitchPoint p) {
  final lane = (p.x.clamp(0, 100) / laneWidth).floor().clamp(0, pitchLanes - 1);
  final band = (p.y.clamp(0, 100) / bandDepth).floor().clamp(0, pitchBands - 1);
  return zoneIndex(lane, band);
}

List<InfluenceMap> teamAttackingInfluence(List<FormationSlot> slots) => [
  for (final s in slots) attackingInfluence(s),
];

List<InfluenceMap> teamDefensiveInfluence(List<FormationSlot> slots) => [
  for (final s in slots) defensiveInfluence(s),
];

FormationSlot _slot(String formation, String id) =>
    formations[formation]!.slots.firstWhere((s) => s.slotId == id);

void main() {
  group('magnitude', () {
    test('a map sums to the position weight from match_tactics', () {
      for (final f in formations.values) {
        for (final s in f.slots) {
          expect(
            attackingInfluence(s).mass,
            closeTo(attackWeights[s.slotPosition]!, 1e-9),
            reason: '${f.id} ${s.slotId} attacking',
          );
          expect(
            defensiveInfluence(s).mass,
            closeTo(defenceWeights[s.slotPosition]!, 1e-9),
            reason: '${f.id} ${s.slotId} defensive',
          );
        }
      }
    });

    test('the keeper has no attacking influence anywhere', () {
      final gk = attackingInfluence(_slot('4-3-3', 'gk'));
      expect(gk.mass, 0);
      expect(gk.zones.every((w) => w == 0), isTrue);
    });

    test('no zone weight is negative', () {
      for (final f in formations.values) {
        for (final s in f.slots) {
          expect(attackingInfluence(s).zones.every((w) => w >= 0), isTrue);
          expect(defensiveInfluence(s).zones.every((w) => w >= 0), isTrue);
        }
      }
    });

    test('team presence is the sum of the eleven', () {
      final maps = teamAttackingInfluence(formations['4-4-2']!.slots);
      final team = InfluenceMap.sum(maps);
      final expected = maps.fold(0.0, (a, m) => a + m.mass);
      expect(team.mass, closeTo(expected, 1e-9));
      expect(
        team.mass,
        closeTo(
          formations['4-4-2']!.slots.fold(
            0.0,
            (a, s) => a + attackWeights[s.slotPosition]!,
          ),
          1e-9,
        ),
      );
    });
  });

  group('shape', () {
    test('spreads wider across the pitch than along it', () {
      expect(influenceAcross, greaterThan(influenceAlong));
      // Anchored on a zone centre, the next lane outweighs the next band.
      final centre = zoneIndex(2, 2);
      final m = influenceAround(zoneCentre(centre), mass: 1);
      final across = m[zoneIndex(3, 2)];
      final along = m[zoneIndex(2, 1)];
      expect(m.peakZone, centre);
      expect(across, greaterThan(along));
    });

    test("a 4-3-3 winger's peak attacking zone is the attacking wide band", () {
      for (final id in ['rf', 'lf']) {
        final peak = attackingInfluence(_slot('4-3-3', id)).peakZone;
        expect(zoneBand(peak), 0, reason: id);
        expect(
          zoneFlank(peak),
          id == 'rf' ? Flank.right : Flank.left,
          reason: id,
        );
      }
    });

    test('a full-back defends his own flank', () {
      final rb = defensiveInfluence(_slot('4-4-2', 'rb'));
      final lb = defensiveInfluence(_slot('4-4-2', 'lb'));
      expect(zoneFlank(rb.peakZone), Flank.right);
      expect(zoneFlank(lb.peakZone), Flank.left);
      expect(rb.flankMass(Flank.right), greaterThan(rb.flankMass(Flank.left)));
      expect(lb.flankMass(Flank.left), greaterThan(lb.flankMass(Flank.right)));
    });

    test(
      'the attacking anchor sits ahead of the slot and the defensive one behind',
      () {
        final cm = _slot('4-3-3', 'cm');
        final own = zoneBand(zoneAt(slotPoint(cm)));
        final atk = attackingInfluence(cm);
        final def = defensiveInfluence(cm);
        // A midfielder standing in band 1 attacks into band 0 more than he
        // defends there, and defends band 2 more than he attacks it.
        expect(own, 1);
        expect(atk.bandMass(0), greaterThan(def.bandMass(0)));
        expect(def.bandMass(2), greaterThan(atk.bandMass(2)));
      },
    );

    test(
      'a forward attacks the attacking band, a defender defends his own',
      () {
        final cf = attackingInfluence(_slot('4-3-3', 'cf'));
        final rcb = defensiveInfluence(_slot('4-3-3', 'rcb'));
        expect(zoneBand(cf.peakZone), 0);
        // The centre-back's work lands in his own box — band 3, the band the
        // mirrored opposing striker attacks into — so the two actually meet.
        expect(zoneBand(rcb.peakZone), 3);
        final theirCf = attackingInfluence(_slot('4-3-3', 'cf')).mirrored();
        expect(zoneBand(theirCf.peakZone), 3);
        expect(cf.bandMass(0), greaterThan(cf.mass / 2));
      },
    );

    test('a central player leaves most of his mass in the centre', () {
      final cf = attackingInfluence(_slot('4-3-3', 'cf'));
      expect(cf.flankMass(Flank.centre), greaterThan(cf.flankMass(Flank.left)));
      expect(
        cf.flankMass(Flank.centre),
        greaterThan(cf.flankMass(Flank.right)),
      );
      expect(
        cf.flankMass(Flank.left),
        closeTo(cf.flankMass(Flank.right), 1e-9),
      );
    });
  });

  group('mirroring', () {
    test('a mirrored map has the same mass in the reflected zones', () {
      final rf = attackingInfluence(_slot('4-3-3', 'rf'));
      final theirs = rf.mirrored();
      expect(theirs.mass, closeTo(rf.mass, 1e-9));
      for (var z = 0; z < pitchZones; z++) {
        expect(theirs[z], rf[mirrorZone(z)]);
      }
      // Their right winger attacks into the band in front of OUR keeper, on
      // OUR left.
      expect(zoneBand(theirs.peakZone), 3);
      expect(zoneFlank(theirs.peakZone), Flank.left);
    });
  });

  group('the AI shapes', () {
    test('every AI slot builds both maps', () {
      aiFormationSlots.forEach((id, slots) {
        final atk = InfluenceMap.sum(teamAttackingInfluence(slots));
        final def = InfluenceMap.sum(teamDefensiveInfluence(slots));
        expect(atk.mass, greaterThan(0), reason: id);
        expect(def.mass, greaterThan(0), reason: id);
        // Defence is heaviest in the own half, attack in the opponent's.
        expect(
          def.bandMass(2) + def.bandMass(3),
          greaterThan(def.bandMass(0) + def.bandMass(1)),
          reason: id,
        );
        expect(
          atk.bandMass(0) + atk.bandMass(1),
          greaterThan(atk.bandMass(2) + atk.bandMass(3)),
          reason: id,
        );
      });
    });
  });

  group('roles', () {
    final rf = _slot('4-3-3', 'rf');
    final lf = _slot('4-3-3', 'lf');

    test('move where the work lands and never how much of it there is', () {
      for (final role in playerRoles.values) {
        final withRole = attackingInfluence(rf, role: role);
        expect(
          withRole.mass,
          closeTo(attackingInfluence(rf).mass, 1e-9),
          reason: role.id,
        );
        expect(
          withRole.zones,
          isNot(attackingInfluence(rf).zones),
          reason: role.id,
        );
      }
      expect(defensiveInfluence(rf).zones, defensiveInfluence(rf).zones);
    });

    test('an inside forward comes in off the flank, a winger stays out', () {
      final natural = attackingInfluence(rf);
      final inside = attackingInfluence(rf, role: playerRoles['insideForward']);
      final winger = attackingInfluence(rf, role: playerRoles['winger']);
      expect(
        inside.flankMass(Flank.centre),
        greaterThan(natural.flankMass(Flank.centre) * 1.5),
      );
      expect(
        winger.flankMass(Flank.right),
        greaterThanOrEqualTo(natural.flankMass(Flank.right)),
      );
      expect(
        winger.flankMass(Flank.centre),
        lessThan(natural.flankMass(Flank.centre)),
      );
    });

    test('inward is toward the centre from EITHER side', () {
      final right = attackingInfluence(rf, role: playerRoles['insideForward']);
      final left = attackingInfluence(lf, role: playerRoles['insideForward']);
      // The mean lane, not the peak: a slot on a lane boundary peaks by
      // tie-break, and the tie breaks the same way on both sides.
      double meanLane(InfluenceMap m) {
        var sum = 0.0;
        for (var z = 0; z < pitchZones; z++) {
          sum += zoneLane(z) * m[z];
        }
        return sum / m.mass;
      }

      expect(
        meanLane(right),
        greaterThan(meanLane(attackingInfluence(rf)) + 0.4),
      );
      expect(meanLane(left), lessThan(meanLane(attackingInfluence(lf)) - 0.4));
      // Mirror images of each other, to rounding.
      for (var z = 0; z < pitchZones; z++) {
        expect(
          left[z],
          closeTo(right[zoneIndex(4 - zoneLane(z), zoneBand(z))], 1e-9),
          reason: 'zone $z',
        );
      }
    });

    test('a wide playmaker drops in, so more of him is in the band behind', () {
      final natural = attackingInfluence(rf);
      final maker = attackingInfluence(rf, role: playerRoles['widePlaymaker']);
      expect(maker.bandMass(1), greaterThan(natural.bandMass(1) * 1.5));
      expect(maker.bandMass(0), lessThan(natural.bandMass(0)));
    });
  });
}
