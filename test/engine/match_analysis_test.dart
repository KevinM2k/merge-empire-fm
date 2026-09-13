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

  // -------------------------------------------------------------------------
  // The inspection layer: the views a screen reads off the raw stream.
  // -------------------------------------------------------------------------

  group('zoneGrid', () {
    test('touches agree with the persisted zone counts, zone for zone', () {
      // The invariant that lets the inspector use ONE code path for all three
      // views: the on-demand grid and the summary's own aggregate are the same
      // population counted twice.
      final events = [
        _ev(z: 3),
        _ev(z: 3, o: 'lose'),
        _ev(z: 7, t: 'shot', o: 'miss', xg: 0.1),
        _ev(z: 7, t: 'shot', o: 'blocked'),
        _ev(z: 12, s: 'theirs', p: 'ai:rs', op: 'a'),
      ];
      final sum = positionalSummary(events);
      for (final side in positionalSides) {
        final persisted = (sum['zone'] as Map)[side] as List;
        final grid = zoneGrid(sum, side, ZoneMetric.touches);
        for (var z = 0; z < pitchZones; z++) {
          expect(grid[z], (persisted[z] as num).toDouble(), reason: '$side $z');
        }
      }
    });

    test('shots count only what was not blocked, and xG sums their chances', () {
      final sum = positionalSummary([
        _ev(z: 7, t: 'shot', o: 'miss', xg: 0.1),
        _ev(z: 7, t: 'shot', o: 'goal', xg: 0.25),
        _ev(z: 7, t: 'shot', o: 'blocked'),
        _ev(z: 7),
      ]);
      expect(zoneGrid(sum, 'ours', ZoneMetric.touches)[7], 4);
      expect(zoneGrid(sum, 'ours', ZoneMetric.shots)[7], 2);
      expect(zoneGrid(sum, 'ours', ZoneMetric.xg)[7], closeTo(0.35, 1e-9));
    });

    test('the xG grid adds up to the side total the summary reports', () {
      final sum = positionalSummary([
        _ev(z: 2, t: 'shot', o: 'goal', xg: 0.4),
        _ev(z: 7, t: 'shot', o: 'miss', xg: 0.125),
        _ev(z: 11, s: 'theirs', p: 'ai:rs', t: 'shot', o: 'miss', xg: 0.2),
      ]);
      final ours = zoneGrid(sum, 'ours', ZoneMetric.xg);
      expect(
        ours.fold<double>(0, (a, b) => a + b),
        closeTo(((sum['xg'] as Map)['ours'] as num).toDouble(), 1e-9),
      );
    });

    test('a record with no events, or a zone off the grid, is all zeros', () {
      expect(zoneGrid(null, 'ours', ZoneMetric.touches), List.filled(pitchZones, 0.0));
      expect(zoneGrid(const {}, 'ours', ZoneMetric.shots), List.filled(pitchZones, 0.0));
      final strayed = positionalSummaryFromMaps([
        {'m': 1, 'z': 99, 's': 'ours', 'p': 'a', 't': 'duel', 'o': 'win'},
      ]);
      expect(zoneGrid(strayed, 'ours', ZoneMetric.touches), List.filled(pitchZones, 0.0));
    });
  });

  group('playerZoneGrid', () {
    test('counts a man on the ball AND a man who met him', () {
      final sum = positionalSummary([
        _ev(z: 3, p: 'rf', op: 'ai:lb'),
        _ev(z: 3, p: 'rf', op: 'ai:lb', o: 'lose'),
        _ev(z: 8, p: 'cf', op: 'ai:rcb'),
      ]);
      // Our winger's own map, and the full-back's, are the same two events.
      expect(playerZoneGrid(sum, 'rf', ZoneMetric.touches)[3], 2);
      expect(playerZoneGrid(sum, 'rf', ZoneMetric.touches)[8], 0);
      expect(playerZoneGrid(sum, 'ai:lb', ZoneMetric.touches)[3], 2);
      expect(playerZoneGrid(sum, 'ai:rcb', ZoneMetric.touches)[8], 1);
    });

    test('a defender has no shots and no xG of his own', () {
      // He is in the event; he did not hit it. A defender's shot map being
      // empty is the point, not a gap.
      final sum = positionalSummary([
        _ev(z: 2, p: 'cf', op: 'ai:lcb', t: 'shot', o: 'goal', xg: 0.3),
      ]);
      expect(playerZoneGrid(sum, 'cf', ZoneMetric.shots)[2], 1);
      expect(playerZoneGrid(sum, 'cf', ZoneMetric.xg)[2], closeTo(0.3, 1e-9));
      expect(playerZoneGrid(sum, 'ai:lcb', ZoneMetric.touches)[2], 1);
      expect(playerZoneGrid(sum, 'ai:lcb', ZoneMetric.shots)[2], 0);
      expect(playerZoneGrid(sum, 'ai:lcb', ZoneMetric.xg)[2], 0);
    });

    test('the players\' touch maps add up to their side\'s', () {
      final events = [
        _ev(z: 3, p: 'rf', op: 'ai:lb'),
        _ev(z: 7, p: 'cf', op: 'ai:rcb', t: 'shot', o: 'miss', xg: 0.2),
        _ev(z: 9, p: 'lf', op: 'ai:rb', o: 'lose'),
      ];
      final sum = positionalSummary(events);
      final side = zoneGrid(sum, 'ours', ZoneMetric.touches);
      final summed = List<double>.filled(pitchZones, 0);
      for (final id in ['rf', 'cf', 'lf']) {
        final g = playerZoneGrid(sum, id, ZoneMetric.touches);
        for (var z = 0; z < pitchZones; z++) {
          summed[z] += g[z];
        }
      }
      expect(summed, side);
    });

    test('nobody by that name is an empty map, not a crash', () {
      final sum = positionalSummary([_ev(z: 3, p: 'rf', op: 'ai:lb')]);
      expect(
        playerZoneGrid(sum, 'nobody', ZoneMetric.touches),
        List.filled(pitchZones, 0.0),
      );
    });
  });

  group('matchups', () {
    test('tallies each pairing from the attacker\'s side of it', () {
      final sum = positionalSummary([
        _ev(z: 3, p: 'rf', op: 'ai:lb', o: 'win'),
        _ev(z: 3, p: 'rf', op: 'ai:lb', o: 'win'),
        _ev(z: 3, p: 'rf', op: 'ai:lb', o: 'lose'),
        _ev(z: 9, p: 'lf', op: 'ai:rb', o: 'lose'),
      ]);
      final all = matchups(sum);
      expect(all.first, (attacker: 'rf', defender: 'ai:lb', won: 2, lost: 1));
      expect(all.last, (attacker: 'lf', defender: 'ai:rb', won: 0, lost: 1));
    });

    test('a shot is a pairing with the man who tried to block it', () {
      final sum = positionalSummary([
        _ev(z: 2, p: 'cf', op: 'ai:gk', t: 'shot', o: 'goal', xg: 0.4),
        _ev(z: 2, p: 'cf', op: 'ai:gk', t: 'shot', o: 'blocked'),
      ]);
      expect(matchups(sum).single, (
        attacker: 'cf',
        defender: 'ai:gk',
        won: 1,
        lost: 1,
      ));
    });

    test('a side filter keeps only that side\'s attacks', () {
      final sum = positionalSummary([
        _ev(z: 3, p: 'rf', op: 'ai:lb'),
        _ev(z: 16, s: 'theirs', p: 'ai:rs', op: 'lcb'),
      ]);
      expect(matchups(sum, side: 'ours').single.attacker, 'rf');
      expect(matchups(sum, side: 'theirs').single.attacker, 'ai:rs');
      expect(matchups(sum).length, 2);
    });

    test('ties are broken by name, so the order never wobbles', () {
      final sum = positionalSummary([
        _ev(z: 3, p: 'rf', op: 'ai:lb'),
        _ev(z: 3, p: 'cf', op: 'ai:lcb'),
        _ev(z: 3, p: 'lf', op: 'ai:rb'),
      ]);
      expect(
        matchups(sum).map((m) => m.attacker),
        ['cf', 'lf', 'rf'],
      );
    });

    test('an unopposed event is nobody\'s matchup', () {
      final sum = positionalSummary([_ev(z: 3, p: 'rf', op: null)]);
      expect(matchups(sum), isEmpty);
    });
  });

  group('duelRecords', () {
    test('sorts by involvement and filters by side', () {
      final sum = positionalSummary([
        _ev(z: 3, p: 'rf', op: 'ai:lb'),
        _ev(z: 3, p: 'rf', op: 'ai:lb', o: 'lose'),
        _ev(z: 3, p: 'rf', op: 'ai:lb'),
        _ev(z: 9, p: 'lf', op: 'ai:rb'),
      ]);
      final ours = duelRecords(sum, ours: true);
      expect(ours.map((d) => d.id), ['rf', 'lf']);
      expect(ours.first, (id: 'rf', won: 2, lost: 1));
      expect(duelRecords(sum, ours: false).map((d) => d.id), [
        'ai:lb',
        'ai:rb',
      ]);
      expect(duelRecords(sum).length, 4);
    });

    test('busiestDuellist is the top of our list', () {
      final sum = positionalSummary([
        _ev(z: 3, p: 'rf', op: 'ai:lb'),
        _ev(z: 3, p: 'rf', op: 'ai:lb', o: 'lose'),
        _ev(z: 9, p: 'lf', op: 'ai:rb'),
      ]);
      expect(busiestDuellist(sum), duelRecords(sum, ours: true).first);
      expect(busiestDuellist(sum)?.id, 'rf');
    });

    test('no record, or nobody in it, is an empty list and a null best', () {
      expect(duelRecords(null), isEmpty);
      expect(duelRecords(const {}), isEmpty);
      expect(busiestDuellist(positionalSummary(const [])), isNull);
    });

    test('duelWinRate is the share, and null for nobody', () {
      expect(duelWinRate((id: 'rf', won: 3, lost: 1)), closeTo(0.75, 1e-9));
      expect(duelWinRate((id: 'rf', won: 0, lost: 0)), isNull);
      expect(duelWinRate(null), isNull);
    });
  });
}
