/// Scouting draws. Ported from `../merge-empire-fc/src/engine/scoutEngine.js`.
///
/// Calling [pickScoutDefinition] in a loop is what makes a batch scout behave:
/// every call re-reads the grid, so the position bias and the tier-9 uniqueness
/// filter both account for the cards placed earlier in the SAME batch. A batch
/// that built its pool once up front could hand over four goalkeepers, or two
/// of the globally unique tier 9.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/coin_sink_engine.dart';
import 'package:merge_empire_fc/engine/merge_engine.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;

/// Roughly one keeper, a back four, a midfield and a couple up top — the shape
/// a player needs before extras are useful. Positions under target are drawn
/// first.
const Map<String, int> posTargets = {'GK': 1, 'DEF': 4, 'MID': 5, 'FWD': 2};

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

List<dynamic> _cells(Map<String, dynamic>? state) {
  final cells = _map(state?['grid'])?['cells'];
  return cells is List ? cells : const [];
}

/// How many of each position are currently in the grid.
Map<String, int> countPositions(List<dynamic>? cells) {
  final counts = {'GK': 0, 'DEF': 0, 'MID': 0, 'FWD': 0};
  for (final raw in cells ?? const []) {
    final def = getDefinition(_map(raw)?['definitionId'] as String?);
    if (def == null) continue;
    counts[def.position] = (counts[def.position] ?? 0) + 1;
  }
  return counts;
}

/// The pool a single scout draws from, after every filter.
///
/// Kept separate from the pick so a test can assert on the pool without
/// fighting the RNG.
List<seeded.WeightedEntry<String>> buildScoutDrawPool(
  Map<String, dynamic>? state, {
  int? minTier,
}) {
  final divisionId = '${_map(state?['progression'])?['currentDivision']}';
  var pool = buildScoutPool(divisionId);

  // A Guaranteed Scout voucher's floor. Applied FIRST and never relaxed — every
  // filter below may only narrow what is left, so the guarantee cannot be
  // traded away by the position bias.
  //
  // Tier 9 leaves the pool along with everything under the floor: it is the one
  // uncraftable, globally unique chase card, and a tier-8 floor would otherwise
  // have made a voucher the cheapest route to it.
  if (minTier != null) {
    pool = [
      for (final e in pool)
        if (getDefinition(e.item) case final def?)
          if (def.tier >= minTier && def.tier <= 8) e,
    ];
    if (pool.isEmpty) return const [];
  }

  // Tier 9 is globally unique — once one is in the squad it leaves the pool.
  final hasT9 = _cells(state).any(
    (c) => getDefinition(_map(c)?['definitionId'] as String?)?.tier == 9,
  );
  if (hasT9) {
    pool = [
      for (final e in pool)
        if (getDefinition(e.item)?.tier != 9) e,
    ];
  }

  // Bias toward the positions the squad is short on, but only when that leaves
  // something to draw from.
  final counts = countPositions(_cells(state));
  final needed = [
    for (final entry in posTargets.entries)
      if ((counts[entry.key] ?? 0) < entry.value) entry.key,
  ];
  if (needed.isNotEmpty) {
    final biased = [
      for (final e in pool)
        if (needed.contains(getDefinition(e.item)?.position)) e,
    ];
    if (biased.isNotEmpty) pool = biased;
  }

  return pool;
}

/// Every player definition the save can still MEET without leaving this
/// division.
///
/// The player index is global but a division only reaches a slice of it: Sunday
/// League scouts the bottom two tiers and merges cap at tier two, so a handful
/// of definitions exist for it and the rest are behind a promotion. Counting
/// the whole book is what let "discover 4 new players" land on a save that had
/// already met every face it could reach.
///
/// Derived from the LIVE pools rather than a tier table, so a change to the
/// scout odds or a coin sink's draw can't leave this advertising faces the game
/// won't hand over.
Set<String> reachablePlayerDefIds(Map<String, dynamic>? state) {
  final divisionId = '${_map(state?['progression'])?['currentDivision']}';
  final divIdx = () {
    final i = divisions.indexWhere((d) => d.id == divisionId);
    return i < 0 ? 0 : i;
  }();

  final ids = <String>{};

  for (final e in buildScoutPool(divisionId)) {
    ids.add(e.item);
  }

  // Anything merging can build, capped at the division's own ceiling.
  final maxTier = getDivision(divisionId).maxPlayerTier;
  for (final p in players) {
    if (p.tier <= maxTier) ids.add(p.id);
  }

  // The coin sinks that place cards, once they are unlocked. The Youth Academy
  // draws ABOVE the merge cap — tiers 3 to 5 in the Amateur League, where
  // merges stop at 3 — so leaving it out would withhold a winnable quest.
  for (final (sinkId, pool) in <(String, List<seeded.WeightedEntry<String>> Function(int))>[
    ('youth_academy', youthAcademyPool),
    ('lucky_pack', luckyPackPool),
  ]) {
    if (!isUnlocked(state, sinkId)) continue;
    for (final e in pool(divIdx)) {
      ids.add(e.item);
    }
  }

  return ids;
}

/// One definition id for a single scout, or null when the pool is empty.
///
/// [minTier] is a Guaranteed Scout voucher's floor — the draw above it still
/// uses the division's own weights, so a voucher raises the bottom of the roll
/// without flattening it.
String? pickScoutDefinition(Map<String, dynamic>? state, {int? minTier}) {
  final pool = buildScoutDrawPool(state, minTier: minTier);
  if (pool.isEmpty) return null;
  return seeded.weightedPick(pool);
}
