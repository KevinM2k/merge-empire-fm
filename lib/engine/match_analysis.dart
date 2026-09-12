/// What the positional sim's recorded stream adds up to.
///
/// **New to the port** — the stream itself comes from `attack_sequence.dart`.
/// This turns a match's couple of hundred duels and shots into the figures a
/// screen reads: touches per zone for the heatmap, flank shares for the
/// analysis copy, every player's duel record and every shooter's line.
///
/// Everything here works on the EVENT MAPS (`PositionalEvent.toMap`), not the
/// objects, because a mid-match re-simulation has to keep the minutes already
/// played from the result and add the remainder's on top — see
/// [mergePositional] — and what it has by then is the maps.
///
/// `result['positional']` is plain JSON: a `MatchResult` crosses into the
/// save's digests and a Dart record in it throws on `jsonEncode`. The raw
/// `ev` list lives only on the in-memory result the match and summary screens
/// read — `lastMatchResult` and the cup history both copy scores, never the
/// result — so it never reaches the save.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/engine/attack_sequence.dart';
import 'package:merge_empire_fc/engine/pitch_space.dart';

const List<String> positionalSides = ['ours', 'theirs'];

/// The result field, from a recorded stream.
Map<String, dynamic> positionalSummary(List<PositionalEvent> events) =>
    positionalSummaryFromMaps([for (final e in events) e.toMap()]);

/// The same, from already-serialised events.
Map<String, dynamic> positionalSummaryFromMaps(List<Map<String, dynamic>> ev) {
  final zone = {
    for (final s in positionalSides) s: List<int>.filled(pitchZones, 0),
  };
  final flank = {
    for (final s in positionalSides)
      s: <String, int>{for (final f in Flank.values) f.name: 0},
  };
  final shots = {for (final s in positionalSides) s: 0};
  final goals = {for (final s in positionalSides) s: 0};
  final xg = {for (final s in positionalSides) s: 0.0};
  final duels = <String, Map<String, int>>{};
  final shooters = <String, Map<String, num>>{};

  for (final e in ev) {
    final side = e['s'] as String? ?? 'ours';
    final z = (e['z'] as num?)?.toInt() ?? 0;
    if (z < 0 || z >= pitchZones || !zone.containsKey(side)) continue;
    zone[side]![z]++;
    final type = e['t'];
    final outcome = e['o'];
    final p = '${e['p']}';
    final op = e['op'];
    if (type == 'duel' || type == 'shot') {
      // A shot is a duel with the blocker too: won it or had it blocked.
      final won = outcome == 'win' || outcome == 'goal' || outcome == 'miss';
      final mine = duels.putIfAbsent(p, () => {'w': 0, 'l': 0});
      mine[won ? 'w' : 'l'] = mine[won ? 'w' : 'l']! + 1;
      if (op is String) {
        final theirs = duels.putIfAbsent(op, () => {'w': 0, 'l': 0});
        theirs[won ? 'l' : 'w'] = theirs[won ? 'l' : 'w']! + 1;
      }
    }
    if (type == 'shot') {
      // Where the attack came down: the lane of the shot, in the SHOOTER's
      // own left and right — their right is our left.
      var lane = zoneLane(z);
      if (side == 'theirs') lane = pitchLanes - 1 - lane;
      final f = laneFlank(lane).name;
      flank[side]![f] = flank[side]![f]! + 1;
      if (outcome != 'blocked') {
        shots[side] = shots[side]! + 1;
        final x = (e['xg'] as num?)?.toDouble() ?? 0;
        xg[side] = xg[side]! + x;
        final line = shooters.putIfAbsent(
          p,
          () => {'shots': 0, 'goals': 0, 'xg': 0.0},
        );
        line['shots'] = line['shots']! + 1;
        line['xg'] = (line['xg']! as double) + x;
        if (outcome == 'goal') {
          goals[side] = goals[side]! + 1;
          line['goals'] = line['goals']! + 1;
        }
      }
    }
  }

  return {
    'ev': ev,
    'zone': zone,
    'flank': flank,
    'shots': shots,
    'goals': goals,
    'xg': {for (final s in positionalSides) s: _round3(xg[s]!)},
    'duels': duels,
    'shooters': {
      for (final e in shooters.entries)
        e.key: {
          'shots': e.value['shots'],
          'goals': e.value['goals'],
          'xg': _round3(e.value['xg']! as double),
        },
    },
  };
}

double _round3(double v) => (v * 1000).round() / 1000;

/// A re-simulated remainder keeps what was already played and adds its own.
Map<String, dynamic> mergePositional(
  Map<String, dynamic>? existing,
  int fromMinute,
  List<PositionalEvent> remainder,
) {
  final kept = <Map<String, dynamic>>[
    if (existing?['ev'] is List)
      for (final e in existing!['ev'] as List)
        if (e is Map<String, dynamic> &&
            ((e['m'] as num?)?.toInt() ?? 0) <= fromMinute)
          e,
  ];
  return positionalSummaryFromMaps([
    ...kept,
    for (final e in remainder) e.toMap(),
  ]);
}

/// A side's share of its attacks down each flank, 0..1, or all zero with no
/// shots to speak of.
Map<Flank, double> flankShares(Map<String, dynamic>? positional, String side) {
  final raw = (positional?['flank'] as Map?)?[side];
  final counts = {
    for (final f in Flank.values)
      f: ((raw is Map ? raw[f.name] : null) as num?)?.toDouble() ?? 0,
  };
  final total = counts.values.fold(0.0, (a, b) => a + b);
  return {for (final f in Flank.values) f: total > 0 ? counts[f]! / total : 0};
}
