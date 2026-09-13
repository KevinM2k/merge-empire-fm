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

/// A player's duel record, off `positional['duels']`.
typedef DuelRecord = ({String id, int won, int lost});

/// Our most-involved player — the most duels, ties to the better record — or
/// null when nobody on our side was recorded. AI pseudo-players (`ai:`) are
/// never ours.
///
/// The top of [duelRecords] rather than a second sweep of the same map: the
/// inspector needs the whole list in that order anyway, and two orderings of
/// one record that disagreed on a tie is exactly the bug CLAUDE.md's reuse rule
/// is about.
DuelRecord? busiestDuellist(Map<String, dynamic>? positional) {
  final all = duelRecords(positional, ours: true);
  return all.isEmpty ? null : all.first;
}

// ---------------------------------------------------------------------------
// The inspection layer.
//
// Everything below is computed ON DEMAND from the raw `ev` stream rather than
// baked into [positionalSummaryFromMaps], and that is deliberate. The summary
// persists — `lastMatchResult` and the cup history carry it — while `ev` lives
// only on the in-memory result the match and summary screens read. A per-player
// zone grid is twenty numbers a player and a matchup table is up to 121 rows; a
// season of those in the save is the bloat the library header warns about. The
// screens that want them have `ev` in hand, so they are paid for when they are
// looked at and nothing is paid when they are not.
//
// Every zone index in the stream is in the sim's ONE absolute frame (see
// `pitch_space.dart`), for both sides, so none of these needs to know whose
// half it is reading.
// ---------------------------------------------------------------------------

/// What a zone grid counts.
///
/// [touches] is every recorded duel and shot — the busy-ness the heatmap has
/// always painted. [shots] counts only shots that were not blocked, the same
/// population `positional['shots']` totals. [xg] sums their calibrated
/// probabilities, so that grid adds up to the side's expected goals.
enum ZoneMetric { touches, shots, xg }

/// Is this event in [metric]'s population, and what does it contribute?
double _contribution(Map<String, dynamic> e, ZoneMetric metric) {
  final type = e['t'];
  switch (metric) {
    case ZoneMetric.touches:
      return type == 'duel' || type == 'shot' ? 1 : 0;
    case ZoneMetric.shots:
      return type == 'shot' && e['o'] != 'blocked' ? 1 : 0;
    case ZoneMetric.xg:
      return type == 'shot' && e['o'] != 'blocked'
          ? ((e['xg'] as num?)?.toDouble() ?? 0)
          : 0;
  }
}

/// The events of a positional record, or empty when it holds none.
List<Map<String, dynamic>> positionalEvents(Map<String, dynamic>? positional) {
  final raw = positional?['ev'];
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e is Map<String, dynamic>) e,
  ];
}

/// The zone an event happened in, or -1 for one that cannot be placed.
int _zoneOf(Map<String, dynamic> e) {
  final z = (e['z'] as num?)?.toInt() ?? -1;
  return z >= 0 && z < pitchZones ? z : -1;
}

/// One side's twenty zones under [metric].
///
/// [ZoneMetric.touches] is the same population `positional['zone']` counts, and
/// `match_analysis_test` pins that the two agree — this exists so that the
/// three views the inspector offers come off one code path and one painter.
List<double> zoneGrid(
  Map<String, dynamic>? positional,
  String side,
  ZoneMetric metric,
) {
  final grid = List<double>.filled(pitchZones, 0);
  for (final e in positionalEvents(positional)) {
    if ((e['s'] as String? ?? 'ours') != side) continue;
    final z = _zoneOf(e);
    if (z < 0) continue;
    grid[z] += _contribution(e, metric);
  }
  return grid;
}

/// ONE PLAYER'S twenty zones — his individual heatmap.
///
/// Every event he was in, as the man on the ball (`p`) or the man who met him
/// (`op`), which is what makes this work for a defender too: a centre-back is
/// never the carrier of one of our attacks and would have an empty map if only
/// `p` counted. [ZoneMetric.shots] and [ZoneMetric.xg] stay the SHOOTER's, so a
/// defender's grid under either is empty by construction rather than by
/// accident — he was in those events, he did not take the shot.
List<double> playerZoneGrid(
  Map<String, dynamic>? positional,
  String playerId,
  ZoneMetric metric,
) {
  final grid = List<double>.filled(pitchZones, 0);
  for (final e in positionalEvents(positional)) {
    final onTheBall = '${e['p']}' == playerId;
    final met = e['op'] == playerId;
    if (!onTheBall && !met) continue;
    if (metric != ZoneMetric.touches && !onTheBall) continue;
    final z = _zoneOf(e);
    if (z < 0) continue;
    grid[z] += _contribution(e, metric);
  }
  return grid;
}

/// A pairing and how it went, always from the ATTACKER's point of view:
/// [won] is his, [lost] is the defender's.
typedef Matchup = ({String attacker, String defender, int won, int lost});

/// Every attacker-versus-defender pairing in the record, the most-contested
/// first, ties to the attacker's better record and then by name so the order
/// is stable for a screen or a golden.
///
/// [side] keeps only the pairings where that side was attacking; null takes
/// both. A shot counts as a pairing with the man who tried to block it, which
/// is how the sequence records one.
List<Matchup> matchups(Map<String, dynamic>? positional, {String? side}) {
  final tally = <(String, String), ({int won, int lost})>{};
  for (final e in positionalEvents(positional)) {
    if (side != null && (e['s'] as String? ?? 'ours') != side) continue;
    final type = e['t'];
    if (type != 'duel' && type != 'shot') continue;
    final op = e['op'];
    if (op is! String) continue;
    final outcome = e['o'];
    final won = outcome == 'win' || outcome == 'goal' || outcome == 'miss';
    final key = ('${e['p']}', op);
    final held = tally[key] ?? (won: 0, lost: 0);
    tally[key] = won
        ? (won: held.won + 1, lost: held.lost)
        : (won: held.won, lost: held.lost + 1);
  }
  final out = <Matchup>[
    for (final e in tally.entries)
      (
        attacker: e.key.$1,
        defender: e.key.$2,
        won: e.value.won,
        lost: e.value.lost,
      ),
  ];
  out.sort((a, b) {
    final byTotal = (b.won + b.lost).compareTo(a.won + a.lost);
    if (byTotal != 0) return byTotal;
    final byWon = b.won.compareTo(a.won);
    if (byWon != 0) return byWon;
    final byAttacker = a.attacker.compareTo(b.attacker);
    return byAttacker != 0 ? byAttacker : a.defender.compareTo(b.defender);
  });
  return out;
}

/// Every recorded player's duel record, the most-involved first — the list
/// [busiestDuellist] takes its answer off.
///
/// [ours] true drops the AI pseudo-players (`ai:`), false keeps only them, null
/// takes everyone. Ties go to the better record and then to the id, so two
/// identical lines never swap places between runs.
List<DuelRecord> duelRecords(Map<String, dynamic>? positional, {bool? ours}) {
  final raw = positional?['duels'];
  if (raw is! Map) return const [];
  final out = <DuelRecord>[];
  for (final e in raw.entries) {
    final id = '${e.key}';
    if (ours != null && ours == id.startsWith('ai:')) continue;
    final rec = e.value;
    if (rec is! Map) continue;
    final won = (rec['w'] as num?)?.toInt() ?? 0;
    final lost = (rec['l'] as num?)?.toInt() ?? 0;
    if (won + lost == 0) continue;
    out.add((id: id, won: won, lost: lost));
  }
  out.sort((a, b) {
    final byTotal = (b.won + b.lost).compareTo(a.won + a.lost);
    if (byTotal != 0) return byTotal;
    final byWon = b.won.compareTo(a.won);
    return byWon != 0 ? byWon : a.id.compareTo(b.id);
  });
  return out;
}

/// A duel record as a win rate, or null when there is nothing to rate.
double? duelWinRate(DuelRecord? record) {
  if (record == null || record.won + record.lost == 0) return null;
  return record.won / (record.won + record.lost);
}

/// A zone grid's share by flank, read in the OWNER's own left and right.
///
/// The same collapse [flankShares] does — lanes 0–1 right, 2 centre, 3–4 left,
/// reversed for the side attacking the other way — over a grid instead of the
/// persisted tally, so the inspector's flank bars follow whatever view is on
/// screen and narrow with it to one player.
///
/// **It is not the same POPULATION as [flankShares]**, and that is deliberate
/// rather than a drift: the persisted tally counts every shot ATTEMPTED,
/// blocked ones included, because that is where the attack got to; a grid
/// counts whatever its [ZoneMetric] counts. `match_analysis_test` pins that the
/// two differ by exactly the blocked shots and nothing else.
Map<Flank, double> gridFlankShares(List<num> grid, {required bool theirs}) {
  final counts = {for (final f in Flank.values) f: 0.0};
  for (var z = 0; z < pitchZones && z < grid.length; z++) {
    final v = grid[z].toDouble();
    if (v <= 0) continue;
    var lane = zoneLane(z);
    if (theirs) lane = pitchLanes - 1 - lane;
    final f = laneFlank(lane);
    counts[f] = counts[f]! + v;
  }
  final total = counts.values.fold(0.0, (a, b) => a + b);
  return {for (final f in Flank.values) f: total > 0 ? counts[f]! / total : 0};
}
