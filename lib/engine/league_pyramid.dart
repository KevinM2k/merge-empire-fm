/// The league pyramid — a persistent roster of AI clubs for every division,
/// promoted and relegated alongside the player at each season boundary.
///
/// Ported from the pyramid half of
/// `../merge-empire-fc/src/engine/progressionEngine.js`.
///
/// A club is stored as a raw map inside the save (`progression.leaguePyramid`),
/// so it stays a `Map<String, dynamic>` here rather than becoming a class. Key
/// insertion order is load-bearing: it decides the serialised bytes, and the
/// port has to round-trip a live player's save unchanged.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/team_names.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/sorting.dart';

/// A club's shape, and the attack-share that shape implies.
typedef AiFormation = ({String id, String style, double attackRatio});

/// Every AI side fields a real formation and derives its ATK/DEF from that
/// shape's position mix, exactly as the player's squad does. `attackRatio` is
/// therefore the formation's own average attack-share, not a free knob — the
/// free version produced ★77 "glass cannon" sides with DEF ~22 that a defensive
/// player farmed regardless of rating.
///
///   3-4-3 = (0.025 + 3·0.20 + 4·0.50 + 3·0.80)/11 = 0.457  (attacking)
///   4-3-3 = (0.025 + 4·0.20 + 3·0.50 + 3·0.80)/11 = 0.430  (attacking)
///   4-4-2 = (0.025 + 4·0.20 + 4·0.50 + 2·0.80)/11 = 0.402  (balanced)
///   5-3-2 = (0.025 + 5·0.20 + 3·0.50 + 2·0.80)/11 = 0.375  (defensive)
///   5-4-1 = (0.025 + 5·0.20 + 4·0.50 + 1·0.80)/11 = 0.348  (defensive)
///
/// The narrow 0.35–0.46 band keeps rating the dominant factor while formation
/// stays a readable flavour worth a few points either way.
const List<AiFormation> aiFormations = [
  (id: '3-4-3', style: 'attacking', attackRatio: 0.457),
  (id: '4-3-3', style: 'attacking', attackRatio: 0.430),
  (id: '4-4-2', style: 'balanced', attackRatio: 0.402),
  (id: '5-3-2', style: 'defensive', attackRatio: 0.375),
  (id: '5-4-1', style: 'defensive', attackRatio: 0.348),
];

final Map<String, AiFormation> _formationById = {
  for (final f in aiFormations) f.id: f,
};

/// 30% attacking / 40% balanced / 30% defensive.
///
/// The Champions League skips the most cautious 5-4-1 so the top flight isn't a
/// stalemate, but every side still fields a genuine shape.
///
/// Draws one seeded number always, and a SECOND only on the attacking and
/// bottom branches — the shape of the JS, and load-bearing for stream parity.
AiFormation randomFormation([String? divId]) {
  final r = seeded.random();
  if (r < 0.30) {
    return seeded.random() < 0.5 ? aiFormations[0] : aiFormations[1];
  }
  if (r < 0.70) return aiFormations[2];
  if (divId == 'champions_cup') return aiFormations[3];
  return seeded.random() < 0.5 ? aiFormations[3] : aiFormations[4];
}

/// Map a legacy (free) attack-share onto the closest real formation, so an
/// existing save keeps each club's personality while snapping onto the narrow
/// formation-derived band. This is what tames the old glass-cannon sides.
AiFormation formationForRatio(double? ratio, String? divId) {
  if (ratio == null) return randomFormation(divId);
  if (ratio >= 0.470) return aiFormations[0]; // 3-4-3
  if (ratio >= 0.415) return aiFormations[1]; // 4-3-3
  if (ratio >= 0.385) return aiFormations[2]; // 4-4-2
  if (ratio >= 0.360 || divId == 'champions_cup') return aiFormations[3]; // 5-3-2
  return aiFormations[4]; // 5-4-1
}

/// A fresh AI club: a rating plus a formation, with the formation's own average
/// attack-share carried on `attackRatio` — the field the match engine and the
/// fixture sim read, so ATK/DEF land on the player's scale.
Map<String, dynamic> makeTeam(String name, int rating, String? divId) {
  final f = randomFormation(divId);
  return {
    'name': name,
    'rating': rating,
    'formation': f.id,
    'attackRatio': f.attackRatio,
  };
}

/// Give [team] a valid formation, keeping `attackRatio` synced to it. Mutates
/// and returns the same map, as the JS does.
Map<String, dynamic> ensureFormation(Map<String, dynamic> team, String? divId) {
  final stored = team['formation'];
  final existing = stored is String ? _formationById[stored] : null;

  final f = existing ?? formationForRatio(_legacyShare(team), divId);
  team['formation'] = f.id;
  team['attackRatio'] = f.attackRatio;
  return team;
}

/// `attackRatio` if it has one, else a legacy `attackBias` folded onto the same
/// scale, else null (meaning "roll a fresh shape").
double? _legacyShare(Map<String, dynamic> team) {
  final ratio = team['attackRatio'];
  if (ratio is num) return ratio.toDouble();
  final bias = team['attackBias'];
  if (bias is num) {
    return math.max(
      0.12,
      math.min(0.88, oppBaseAtkShare + bias.toDouble() * oppBiasShare),
    );
  }
  return null;
}

/// Each league is an eight-club competition — the player occupies one of the
/// eight slots in their own division, leaving seven opponents and a 14-match
/// season. A league the player is only peeking at shows all eight AI sides.
const int teamsPerLeague = 8;

/// ATK/DEF for a stored club, tolerating every shape the field has ever held.
///
/// Mirrors the JS `opponentAtkDef(rating, team?.formation ?? team?.attackRatio
/// ?? OPP_BASE_ATK_SHARE)` exactly, including its one surprise: an UNRECOGNISED
/// formation string wins the `??` chain and then falls through to the base
/// share, so a corrupt `formation` shadows a perfectly good `attackRatio`.
TeamSplit splitForTeam(num rating, Map<String, dynamic>? team) {
  final chosen = team?['formation'] ?? team?['attackRatio'] ?? oppBaseAtkShare;
  if (chosen is String && aiFormationPositions.containsKey(chosen)) {
    return opponentAtkDef(rating, chosen);
  }
  return opponentAtkDefFromShare(
    rating,
    chosen is num ? chosen.toDouble() : oppBaseAtkShare,
  );
}

Map<String, dynamic> _progression(Map<String, dynamic> state) =>
    (state['progression'] as Map<String, dynamic>?) ??
    (state['progression'] = <String, dynamic>{});

/// The clubs in one division, as live mutable maps. Non-map entries in a
/// tampered save are dropped rather than crashing the table.
List<Map<String, dynamic>> _divisionTeams(Object? raw) {
  if (raw is! List) return [];
  return [
    for (final t in raw)
      if (t is Map<String, dynamic>) t,
  ];
}

/// Lazily build the pyramid — one list of [teamsPerLeague] clubs per division.
///
/// The first call migrates a legacy `seasonOpponents` list into the player's
/// current division, so an existing save keeps its familiar rivals.
///
/// [topUp] fills short divisions with fresh clubs. It defaults true, which is
/// what a boot or a corrupt save wants. [shufflePyramid] passes FALSE: it runs
/// straight after the player's division has been emptied of four clubs, and
/// padding here filled that league with invented sides before the clubs that
/// actually earned promotion could arrive — which pushed it over the limit, and
/// the trim-by-rating at the end of the shuffle then deleted the arrivals,
/// since a just-promoted side is the weakest thing in its new league. Every
/// season quietly threw away the clubs that came up and replaced them with
/// strangers. The normalisation runs AFTER the moves, so it pads there instead.
Map<String, dynamic> ensureLeaguePyramid(
  Map<String, dynamic> state, {
  bool topUp = true,
}) {
  final prog = _progression(state);
  final stored = prog['leaguePyramid'];

  if (stored is Map<String, dynamic>) {
    final usedNames = <String>{};
    for (final id in stored.keys) {
      for (final t in _divisionTeams(stored[id])) {
        final name = t['name'];
        if (name is String && name.isNotEmpty) usedNames.add(name);
      }
    }

    var migrated = false;
    for (final div in divisions) {
      var arr = stored[div.id];
      // A division entirely absent (a save from before it was added) or
      // corrupted to a non-list would make the shuffle crash on the map/filter
      // below. Rebuild it empty and let the top-up populate it.
      if (arr is! List) {
        arr = <dynamic>[];
        stored[div.id] = arr;
        migrated = true;
      }
      final list = arr;

      if (topUp && list.length < teamsPerLeague) {
        final tier = divTier(div.id);
        final (lo, hi) = div.opponentRatingRange;
        while (list.length < teamsPerLeague) {
          final name = generateTeamName(tier, usedNames);
          usedNames.add(name);
          list.add(makeTeam(name, seeded.randomInt(lo, hi), div.id));
        }
        migrated = true;
      }

      // Migrate legacy clubs onto real formations, converting free/glass-cannon
      // attack ratios and legacy `attackBias` onto the narrow band.
      for (final t in _divisionTeams(list)) {
        final f = t['formation'];
        if (f is! String || !_formationById.containsKey(f)) {
          ensureFormation(t, div.id);
          migrated = true;
        }
      }
    }

    if (migrated) prog['leaguePyramid'] = stored;
    return stored;
  }

  final pyramid = <String, dynamic>{};
  final used = <String>{};
  for (final div in divisions) {
    final tier = divTier(div.id);
    final (lo, hi) = div.opponentRatingRange;
    final names = <String>[];
    while (names.length < teamsPerLeague) {
      final name = generateTeamName(tier, used);
      used.add(name);
      names.add(name);
    }
    pyramid[div.id] = [
      for (final name in names) makeTeam(name, seeded.randomInt(lo, hi), div.id),
    ];
  }

  // Carry legacy opponents forward into the player's current league.
  final curDiv = prog['currentDivision'];
  final legacy = prog['seasonOpponents'];
  if (curDiv is String &&
      legacy is List &&
      legacy.length >= 7 &&
      pyramid[curDiv] != null) {
    final legacyRatings =
        (prog['seasonOpponentRatings'] as Map<String, dynamic>?) ?? const {};
    final season = (prog['seasonCount'] as num?)?.toInt() ?? 1;
    final range = getDivision(curDiv).opponentRatingRange;
    final copied = <Map<String, dynamic>>[
      for (var i = 0; i < legacy.length; i++)
        makeTeam(
          '${legacy[i]}',
          (legacyRatings['s${season}_o$i'] as num?)?.toInt() ??
              seeded.randomInt(range.$1, range.$2),
          curDiv,
        ),
    ];
    final usedNames = {for (final t in copied) t['name'] as String};
    final curTier = divTier(curDiv);
    while (copied.length < teamsPerLeague) {
      final name = generateTeamName(curTier, usedNames);
      usedNames.add(name);
      copied.add(
        makeTeam(name, seeded.randomInt(range.$1, range.$2), curDiv),
      );
    }
    pyramid[curDiv] = copied.take(teamsPerLeague).toList();
  }

  prog['leaguePyramid'] = pyramid;
  return pyramid;
}

/// End-of-season shuffle across the whole pyramid. Each league's top two clubs
/// promote (with a rating bump) and its bottom two relegate (with a cut). The
/// player isn't in these lists — their own move is [endSeason]'s business.
///
/// [recentlyMoved] excludes clubs already moved this season-end, so a side that
/// has just been relegated can't bounce straight back up.
///
/// [statuses], when passed, collects the last-season badge each moved club
/// carries into the new campaign. Only the season-end path passes it; a bare
/// shuffle records nothing.
void shufflePyramid(
  Map<String, dynamic> state, {
  String? skipDivId,
  Set<String>? recentlyMoved,
  Map<String, dynamic>? statuses,
}) {
  final pyramid = ensureLeaguePyramid(state, topUp: false);

  // Rank each league by rating plus a little noise, so the table isn't a pure
  // restatement of the ratings.
  final ranked = <String, List<Map<String, dynamic>>>{};
  for (final div in divisions) {
    if (div.id == skipDivId) continue;
    final entries = <Map<String, dynamic>>[];
    for (final t in _divisionTeams(pyramid[div.id])) {
      if (recentlyMoved?.contains(t['name']) ?? false) continue;
      entries.add({
        ...t,
        'score': ((t['rating'] as num?) ?? 0) + seeded.random() * 12,
      });
    }
    stableSort(
      entries,
      (a, b) => ((b['score'] as num) - (a['score'] as num)).sign.toInt(),
    );
    ranked[div.id] = entries;
  }

  // Collect the moves first and apply them second, so a club can't be counted
  // both as leaving its league and as arriving in the one above.
  final moves = <({String kind, Map<String, dynamic> team, int from, int to})>[];
  for (var i = 0; i < divisions.length; i++) {
    if (divisions[i].id == skipDivId) continue;
    final teams = ranked[divisions[i].id];
    if (teams == null) continue;
    if (i < divisions.length - 1 && teams.length > 1) {
      moves.add((kind: 'promote', team: teams[0], from: i, to: i + 1));
      moves.add((kind: 'promote', team: teams[1], from: i, to: i + 1));
    }
    if (i > 0 && teams.length > 1) {
      moves.add((
        kind: 'relegate',
        team: teams[teams.length - 1],
        from: i,
        to: i - 1,
      ));
      moves.add((
        kind: 'relegate',
        team: teams[teams.length - 2],
        from: i,
        to: i - 1,
      ));
    }
  }

  if (statuses != null) {
    // Nobody promotes out of the top flight, so its winner is the one club a
    // move can't describe. Record the title first and let the move loop
    // overwrite it in the degenerate case where the same club also went down.
    final topId = divisions.last.id;
    final top = ranked[topId];
    if (top != null && top.isNotEmpty) {
      statuses['${top.first['name']}'] = {
        'status': 'champion',
        'division': topId,
      };
    }
    for (final m in moves) {
      statuses['${m.team['name']}'] = {
        'status': m.kind == 'promote' ? 'promoted' : 'relegated',
        'division': divisions[m.to].id,
      };
    }
  }

  // Clone, then apply. A club's attacking style is its formation now — a real,
  // stable shape — so there's no per-season ratio drift to apply.
  final next = <String, List<Map<String, dynamic>>>{};
  for (final div in divisions) {
    next[div.id] = [
      for (final t in _divisionTeams(pyramid[div.id]))
        ensureFormation({...t}, div.id),
    ];
  }

  for (final m in moves) {
    final fromArr = next[divisions[m.from].id]!;
    final idx = fromArr.indexWhere((t) => t['name'] == m.team['name']);
    if (idx >= 0) fromArr.removeAt(idx);
  }

  for (final m in moves) {
    final toDiv = divisions[m.to];
    final (lo, hi) = toDiv.opponentRatingRange;
    // Promotion brings signings stepping up; relegation loses the stars. Clamp
    // so a rating can't drift far from the destination league's band.
    final bump = m.kind == 'promote'
        ? seeded.randomInt(3, 7)
        : -seeded.randomInt(3, 6);
    final rating = math.max(
      lo - 4,
      math.min(hi + 4, ((m.team['rating'] as num?) ?? 0).toInt() + bump),
    );
    next[toDiv.id]!.add(
      ensureFormation({
        'name': m.team['name'],
        'rating': rating,
        'formation': m.team['formation'],
        'attackRatio': m.team['attackRatio'],
      }, toDiv.id),
    );
  }

  // Every league should settle at [teamsPerLeague]. The top and bottom see net
  // imbalances (the top takes two from below and sheds two of its own; the
  // bottom needs two new reserves to replace the pair sent up). Normalise.
  for (final div in divisions) {
    final arr = next[div.id]!;
    if (arr.length == teamsPerLeague) continue;
    if (arr.length < teamsPerLeague) {
      final usedNames = <String>{};
      for (final d in divisions) {
        for (final t in next[d.id]!) {
          final n = t['name'];
          if (n is String) usedNames.add(n);
        }
      }
      final tier = divTier(div.id);
      final (lo, hi) = div.opponentRatingRange;
      while (arr.length < teamsPerLeague) {
        final name = generateTeamName(tier, usedNames);
        usedNames.add(name);
        arr.add(makeTeam(name, seeded.randomInt(lo, hi), div.id));
      }
    } else {
      // Too many — cut the weakest extras. Never happens in the steady state,
      // but it protects against edge-case drift.
      stableSort(
        arr,
        (a, b) =>
            ((b['rating'] as num? ?? 0) - (a['rating'] as num? ?? 0)).sign.toInt(),
      );
      arr.length = teamsPerLeague;
    }
  }

  _progression(state)['leaguePyramid'] = <String, dynamic>{
    for (final div in divisions) div.id: next[div.id]!,
  };
}
