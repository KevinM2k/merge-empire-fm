import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/engine/pitch_space.dart';

/// Which zone a point lands in, for pinning the frame: floor to a lane and a
/// band, the far edges folded onto the grid.
int zoneAt(PitchPoint p) {
  final lane = (p.x.clamp(0, 100) / laneWidth).floor().clamp(0, pitchLanes - 1);
  final band = (p.y.clamp(0, 100) / bandDepth).floor().clamp(0, pitchBands - 1);
  return zoneIndex(lane, band);
}

void main() {
  group('the grid', () {
    test('is five lanes by four bands', () {
      expect(pitchLanes, 5);
      expect(pitchBands, 4);
      expect(pitchZones, 20);
    });

    test('zone index is band-major and round-trips through lane and band', () {
      for (var band = 0; band < pitchBands; band++) {
        for (var lane = 0; lane < pitchLanes; lane++) {
          final z = zoneIndex(lane, band);
          expect(z, band * 5 + lane);
          expect(zoneLane(z), lane);
          expect(zoneBand(z), band);
          expect(zoneAt(zoneCentre(z)), z);
        }
      }
    });

    test('the keeper stands in band 3 and the striker in band 0', () {
      final f = formations['4-3-3']!;
      final gk = f.slots.firstWhere((s) => s.slotId == 'gk');
      final cf = f.slots.firstWhere((s) => s.slotId == 'cf');
      expect(zoneBand(zoneAt(slotPoint(gk))), 3);
      expect(zoneBand(zoneAt(slotPoint(cf))), 0);
      expect(zoneBand(zoneAt(slotPoint(cf))) == 0, isTrue);
      expect(zoneBand(zoneAt(slotPoint(gk))) == 0, isFalse);
    });
  });

  group('handedness', () {
    test(
      'the right-back stands on the right flank and the left-back on the left',
      () {
        final f = formations['4-4-2']!;
        final rb = f.slots.firstWhere((s) => s.slotId == 'rb');
        final lb = f.slots.firstWhere((s) => s.slotId == 'lb');
        expect(zoneFlank(zoneAt(slotPoint(rb))), Flank.right);
        expect(zoneFlank(zoneAt(slotPoint(lb))), Flank.left);
      },
    );

    test('lanes collapse two-one-two onto the flanks', () {
      expect([0, 1, 2, 3, 4].map(laneFlank), [
        Flank.right,
        Flank.right,
        Flank.centre,
        Flank.left,
        Flank.left,
      ]);
    });
  });

  group('mirroring the opponent', () {
    test('their right-back lines up against our left winger', () {
      final f = formations['4-3-3']!;
      final theirRb = mirrorPoint(
        slotPoint(f.slots.firstWhere((s) => s.slotId == 'rb')),
      );
      final ourLf = slotPoint(f.slots.firstWhere((s) => s.slotId == 'lf'));
      expect(zoneLane(zoneAt(theirRb)), zoneLane(zoneAt(ourLf)));
      // Their back line stands in the band our forwards attack.
      expect(zoneBand(zoneAt(theirRb)), 1);
      expect(zoneFlank(zoneAt(theirRb)), Flank.left);
    });

    test('their keeper ends up in front of the goal we attack', () {
      final gk = mirrorPoint((x: 50, y: 90));
      expect(gk, (x: 50, y: 10));
      expect(zoneBand(zoneAt(gk)), 0);
    });

    test('mirrorZone agrees with mirroring the centre point', () {
      for (var z = 0; z < pitchZones; z++) {
        expect(mirrorZone(z), zoneAt(mirrorPoint(zoneCentre(z))));
        expect(mirrorZone(mirrorZone(z)), z);
      }
    });
  });
}
