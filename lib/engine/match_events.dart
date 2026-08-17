/// Match event generation, ported from
/// `../merge-empire-fc/src/engine/matchEngine.js`.
///
/// ── The RNG split, which is load-bearing ────────────────────────────────────
///
/// This function mixes BOTH generators, line by line, and the split is
/// preserved exactly rather than tidied:
///
///   SEEDED  — every minute (`pickUnused`, `pickGoalMinute`), the weighted
///             scorer, and the commentary line index.
///   UNSEEDED — team attribution for commentary, chances and corners; the xG
///             roll; and the on-target roll.
///
/// Unifying them would look like an obvious cleanup and would silently change
/// every subsequent seeded draw in the match, breaking parity with the JS. The
/// consequence to be aware of: which minutes goals fall on IS reproducible from
/// a seed, but which side gets a given chance is NOT.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/util/random.dart' as seeded;

/// Goal-scoring probability weights by position.
///
/// Forwards score about 60% of goals, midfielders 27%, defenders 12%. Keepers
/// almost never — real ones score about once in 5,000 matches, and 0.5 here
/// keeps the freak header from a corner possible without your keeper topping
/// the charts.
const Map<String, double> goalScorerWeights = {
  'FWD': 60,
  'MID': 27,
  'DEF': 12,
  'GK': 0.5,
};

/// A player eligible to score.
class ScorerCandidate {
  const ScorerCandidate({
    required this.name,
    required this.position,
    required this.instanceId,
  });

  final String name;
  final String position;
  final String instanceId;
}

/// The unseeded generator, matching the JS `Math.random()` calls in this file.
math.Random _rng = math.Random();

/// Test seam.
void setEventRandom(math.Random rng) => _rng = rng;

void resetEventRandom() => _rng = math.Random();

/// Picks a scorer by position weight. Draws from the SEEDED stream.
///
/// Scorer odds follow the SLOT the player is fielded in rather than the card's
/// own position, which is what lets a keeper pushed up front actually score.
ScorerCandidate? pickWeightedScorer(List<ScorerCandidate> playerData) {
  if (playerData.isEmpty) return null;

  var total = 0.0;
  for (final p in playerData) {
    total += goalScorerWeights[p.position] ?? 20;
  }

  var r = seeded.random() * total;
  for (final p in playerData) {
    r -= goalScorerWeights[p.position] ?? 20;
    if (r <= 0) return p;
  }
  return playerData.last;
}

/// Keyed commentary pools. The actual strings live in the i18n catalogue; the
/// engine emits the key so the feed text follows the active locale.
const List<({List<int> range, String bucket, int count})> commentaryPools = [
  (range: [1, 1], bucket: 'open', count: 3),
  (range: [15, 30], bucket: 'firstA', count: 4),
  (range: [31, 44], bucket: 'firstB', count: 4),
  (range: [46, 60], bucket: 'secondA', count: 4),
  (range: [61, 75], bucket: 'secondB', count: 4),
  (range: [76, 88], bucket: 'closing', count: 5),
];

int _pickUnused(Set<int> used, int min, int max) {
  var m = 0;
  var tries = 0;
  do {
    m = seeded.randomInt(min, max);
    tries++;
  } while (used.contains(m) && tries < 30);
  used.add(m);
  return m;
}

/// Goal minutes are back-loaded like real football — roughly 45% in the first
/// half, 55% in the second, with a spike in the closing stages and stoppage
/// time — rather than uniform. Rejection-sampled against a piecewise weight,
/// falling back to plain uniform if it runs out of tries.
int _pickGoalMinute(Set<int> used, int min, int max) {
  for (var tries = 0; tries < 40; tries++) {
    final m = seeded.randomInt(min, max);
    if (used.contains(m)) continue;
    final w = m <= 45 ? 0.85 : (m <= 75 ? 1.0 : 1.4);
    if (seeded.random() < w / 1.4) {
      used.add(m);
      return m;
    }
  }
  return _pickUnused(used, min, max);
}

/// One thing that happened in a match.
class MatchEvent {
  const MatchEvent({
    required this.minute,
    required this.type,
    this.team,
    this.scorer,
    this.scorerInstanceId,
    this.textKey,
    this.xg,
    this.shotResult,
    this.big,
    this.player,
    this.addedTime,
  });

  final int minute;

  /// `goal`, `commentary`, `halftime`, `fulltime`, `chance`, `corner`,
  /// `injury`.
  final String type;

  final String? team;
  final String? scorer;
  final String? scorerInstanceId;
  final String? textKey;
  final double? xg;
  final String? shotResult;
  final bool? big;
  final String? player;
  final int? addedTime;
}

/// An injury to place in the feed.
typedef InjuryEntry = ({String name, int? minute});

/// Builds the full event feed for a match.
///
/// [chanceWeights] biases team attribution; omitted, it falls back to the
/// scoreline. [addedTime] only applies to full-match calls.
List<MatchEvent> generateMatchEvents({
  required int homeGoals,
  required int awayGoals,
  List<ScorerCandidate> playerData = const [],
  List<InjuryEntry> injuries = const [],
  int minMin = 1,
  int maxMin = 90,
  ({double home, double away})? chanceWeights,
  int? addedTime,
}) {
  final resolvedAdded = maxMin == 90 ? (addedTime ?? seeded.randomInt(1, 5)) : 0;
  final fullTimeMin = maxMin + resolvedAdded;

  final events = <MatchEvent>[];
  final used = <int>{45, fullTimeMin};

  // A re-simulation kicked off in the last playable minute — a tactics change
  // during stoppage time — can hand us a minMin already past the last minute
  // before full time. Clamp so the goal minute never exceeds its max,
  // otherwise the picker only ever rolls fullTimeMin itself (already reserved),
  // stacking duplicates on the full-time marker and stranding it mid-array.
  final goalMax = fullTimeMin - 1;
  final goalMin = math.min(math.max(minMin, 1), goalMax);

  final allGoals = [
    ...List.filled(homeGoals, 'home'),
    ...List.filled(awayGoals, 'away'),
  ];

  for (final team in allGoals) {
    final minute = _pickGoalMinute(used, goalMin, goalMax);
    final scorer =
        team == 'home' && playerData.isNotEmpty ? pickWeightedScorer(playerData) : null;
    events.add(
      MatchEvent(
        minute: minute,
        type: 'goal',
        team: team,
        scorer: scorer?.name,
        scorerInstanceId: scorer?.instanceId,
      ),
    );
  }

  // Chance weights are needed up here so commentary can be team-tagged.
  final wHome = math.max(0.1, chanceWeights?.home ?? (homeGoals + 1));
  final wAway = math.max(0.1, chanceWeights?.away ?? (awayGoals + 1));
  final wTotal = wHome + wAway;

  for (final pool in commentaryPools) {
    if (pool.range[1] < minMin || pool.range[0] > maxMin) continue;
    final poolMin = math.max(pool.range[0], minMin);
    final poolMax = math.min(pool.range[1], maxMin);
    final minute = _pickUnused(used, poolMin, poolMax);
    // UNSEEDED, matching the JS.
    final team = (_rng.nextDouble() * wTotal) < wHome ? 'home' : 'away';
    final idx = seeded.randomInt(0, pool.count - 1);
    events.add(
      MatchEvent(
        minute: minute,
        type: 'commentary',
        team: team,
        textKey: 'commentary.flow.${pool.bucket}.$idx',
      ),
    );
  }

  // One flavour line somewhere in the added-time window.
  if (resolvedAdded > 0 && fullTimeMin > 91) {
    final atMin = _pickUnused(
      used,
      math.min(math.max(minMin, 91), goalMax),
      goalMax,
    );
    final team = (_rng.nextDouble() * wTotal) < wHome ? 'home' : 'away';
    final idx = seeded.randomInt(0, 3);
    events.add(
      MatchEvent(
        minute: atMin,
        type: 'commentary',
        team: team,
        textKey: 'commentary.flow.addedtime.$idx',
      ),
    );
  }

  if (maxMin >= 45 && minMin <= 45) {
    events.add(const MatchEvent(minute: 45, type: 'halftime'));
  }
  if (maxMin >= 90) {
    events.add(
      MatchEvent(
        minute: fullTimeMin,
        type: 'fulltime',
        addedTime: resolvedAdded,
      ),
    );
  }

  // Non-goal chances, which drive the momentum bar.
  final span = fullTimeMin - minMin + 1;
  final chanceCount = (span / 7 + 0.5).floor();
  for (var i = 0; i < chanceCount; i++) {
    final m = _pickUnused(used, math.min(math.max(minMin, 2), goalMax), goalMax);
    final team = (_rng.nextDouble() * wTotal) < wHome ? 'home' : 'away';
    final xg = 0.08 + _rng.nextDouble() * 0.22;
    // On-target probability scales with xG — better chances are likelier to hit
    // the target.
    final onTarget = _rng.nextDouble() < (0.25 + xg * 1.2);
    events.add(
      MatchEvent(
        minute: m,
        type: 'chance',
        team: team,
        xg: xg,
        shotResult: onTarget ? 'on_target' : 'off',
        big: xg >= 0.22,
      ),
    );
  }

  // Corners, separate from chances.
  final cornerCount = math.max(2, (span / 15 + 0.5).floor());
  for (var i = 0; i < cornerCount; i++) {
    final m = _pickUnused(used, math.min(math.max(minMin, 3), goalMax), goalMax);
    final team = (_rng.nextDouble() * wTotal) < wHome ? 'home' : 'away';
    events.add(MatchEvent(minute: m, type: 'corner', team: team));
  }

  for (final inj in injuries) {
    if (inj.minute != null) {
      used.add(inj.minute!);
      events.add(
        MatchEvent(minute: inj.minute!, type: 'injury', player: inj.name),
      );
    } else {
      final injMin = math.max(minMin, 20);
      final injMax = math.min(maxMin, 85);
      if (injMin < injMax) {
        events.add(
          MatchEvent(
            minute: _pickUnused(used, injMin, injMax),
            type: 'injury',
            player: inj.name,
          ),
        );
      }
    }
  }

  events.sort((a, b) => a.minute.compareTo(b.minute));
  return events;
}
