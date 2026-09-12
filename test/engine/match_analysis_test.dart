import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/attack_sequence.dart';
import 'package:merge_empire_fc/engine/match_analysis.dart';
import 'package:merge_empire_fc/engine/pitch_space.dart';

PositionalEvent _ev({
  int m = 10,
  required int z,
  String s = 'ours',
  String p = 'a',
  String? op = 'x',
  String t = 'duel',
  String o = 'win',
  double? xg,
}) => PositionalEvent(
  minute: m,
  zone: z,
  side: s,
  playerId: p,
  opponentId: op,
  type: t,
  outcome: o,
  xg: xg,
);

void main() {
  group('positionalSummary', () {
    test('an empty stream is all zeros and encodes', () {
      final sum = positionalSummary(const []);
      expect(sum['ev'], isEmpty);
      expect((sum['zone'] as Map)['ours'], List.filled(pitchZones, 0));
      expect((sum['shots'] as Map)['theirs'], 0);
      expect((sum['xg'] as Map)['ours'], 0);
      expect(sum['duels'], isEmpty);
      expect(() => jsonEncode(sum), returnsNormally);
    });

    test('counts touches per zone for each side in our frame', () {
      final sum = positionalSummary([
        _ev(z: 7),
        _ev(z: 7),
        _ev(z: 12, s: 'theirs', p: 'ai:rs', op: 'a'),
      ]);
      final ours = (sum['zone'] as Map)['ours'] as List;
      final theirs = (sum['zone'] as Map)['theirs'] as List;
      expect(ours[7], 2);
      expect(ours[12], 0);
      expect(theirs[12], 1);
    });

    test('a duel is a win for one and a loss for the other', () {
      final sum = positionalSummary([
        _ev(z: 7, p: 'a', op: 'x', o: 'win'),
        _ev(z: 7, p: 'a', op: 'x', o: 'lose'),
        _ev(z: 7, p: 'a', op: 'y', o: 'win'),
      ]);
      final duels = sum['duels'] as Map;
      expect(duels['a'], {'w': 2, 'l': 1});
      expect(duels['x'], {'w': 1, 'l': 1});
      expect(duels['y'], {'w': 0, 'l': 1});
    });

    test('a shot counts as a duel with the blocker, blocked or not', () {
      final sum = positionalSummary([
        _ev(z: 2, p: 'a', op: 'gk', t: 'shot', o: 'blocked'),
        _ev(z: 2, p: 'a', op: 'gk', t: 'shot', o: 'miss', xg: 0.2),
        _ev(z: 2, p: 'a', op: 'gk', t: 'shot', o: 'goal', xg: 0.3),
      ]);
      expect((sum['duels'] as Map)['a'], {'w': 2, 'l': 1});
      expect((sum['duels'] as Map)['gk'], {'w': 1, 'l': 2});
      expect((sum['shots'] as Map)['ours'], 2);
      expect((sum['goals'] as Map)['ours'], 1);
      expect((sum['xg'] as Map)['ours'], closeTo(0.5, 1e-9));
      expect((sum['shooters'] as Map)['a'], {
        'shots': 2,
        'goals': 1,
        'xg': 0.5,
      });
    });

    test(
      'flank is the lane of the shot, in the shooter\'s own left and right',
      () {
        final sum = positionalSummary([
          // Our shot from lane 0 — OUR right.
          _ev(z: zoneIndex(0, 0), t: 'shot', o: 'miss', xg: 0.1),
          _ev(z: zoneIndex(2, 0), t: 'shot', o: 'blocked'),
          // Their shot from OUR lane 0, which is THEIR left.
          _ev(
            z: zoneIndex(0, 3),
            s: 'theirs',
            p: 'ai:lf',
            t: 'shot',
            o: 'miss',
            xg: 0.1,
          ),
          // A duel is not an attack that came down anywhere yet.
          _ev(z: zoneIndex(4, 1)),
        ]);
        final flank = sum['flank'] as Map;
        expect(flank['ours'], {'right': 1, 'centre': 1, 'left': 0});
        expect(flank['theirs'], {'right': 0, 'centre': 0, 'left': 1});
      },
    );

    test('ignores an event whose zone is off the grid', () {
      final sum = positionalSummaryFromMaps([
        {'m': 1, 'z': 99, 's': 'ours', 'p': 'a', 't': 'duel', 'o': 'win'},
        {'m': 1, 'z': -1, 's': 'ours', 'p': 'a', 't': 'duel', 'o': 'win'},
        {'m': 1, 'z': 3, 's': 'nobody', 'p': 'a', 't': 'duel', 'o': 'win'},
      ]);
      expect((sum['zone'] as Map)['ours'], List.filled(pitchZones, 0));
      expect(sum['duels'], isEmpty);
    });
  });

  group('mergePositional', () {
    test('keeps the minutes already played and adds the remainder', () {
      final first = positionalSummary([
        _ev(m: 10, z: 7),
        _ev(m: 60, z: 8),
        _ev(m: 70, z: 9, t: 'shot', o: 'goal', xg: 0.4),
      ]);
      final merged = mergePositional(first, 60, [
        _ev(m: 75, z: 12, t: 'shot', o: 'miss', xg: 0.2),
      ]);
      final ours = (merged['zone'] as Map)['ours'] as List;
      expect(ours[7], 1);
      expect(ours[8], 1);
      expect(ours[9], 0, reason: 'the 70th-minute shot was re-simulated away');
      expect(ours[12], 1);
      expect((merged['goals'] as Map)['ours'], 0);
      expect((merged['ev'] as List).length, 3);
    });

    test('with nothing before is just the remainder', () {
      final merged = mergePositional(null, 45, [_ev(m: 50, z: 1)]);
      expect((merged['ev'] as List).length, 1);
    });
  });

  group('flankShares', () {
    test('normalises a side\'s flank counts', () {
      final sum = positionalSummary([
        _ev(z: zoneIndex(0, 0), t: 'shot', o: 'miss', xg: 0.1),
        _ev(z: zoneIndex(1, 0), t: 'shot', o: 'miss', xg: 0.1),
        _ev(z: zoneIndex(2, 0), t: 'shot', o: 'miss', xg: 0.1),
        _ev(z: zoneIndex(4, 0), t: 'shot', o: 'miss', xg: 0.1),
      ]);
      final shares = flankShares(sum, 'ours');
      expect(shares[Flank.right], 0.5);
      expect(shares[Flank.centre], 0.25);
      expect(shares[Flank.left], 0.25);
    });

    test('is all zero with nothing to share and on a missing field', () {
      expect(flankShares(null, 'ours').values.every((v) => v == 0), isTrue);
      expect(
        flankShares(
          positionalSummary(const []),
          'theirs',
        ).values.every((v) => v == 0),
        isTrue,
      );
    });
  });
}
