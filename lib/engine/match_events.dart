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
    this.zone,
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

  /// The zone a goal or a chance was struck from — `pitch_space.dart`'s twenty,
  /// in the sim's absolute frame — or null for an event the positional record
  /// did not produce.
  ///
  /// It travels so the 2D cutaway can run the passage down the flank the attack
  /// actually came down. Without it the passage was a blind weighted pick and
  /// could sweep down the left under commentary naming a right-sided move.
  final int? zone;

  /// The feed entry as the match result stores it.
  ///
  /// A result crosses the sim, the match screen and the quest engine, so it
  /// stays a raw map for the same reason the save does. Only the fields this
  /// event actually carries are written — except a goal's scorer, which keeps
  /// its keys even when nobody is credited, because an away goal has no scorer
  /// and the readers index the two lists against each other.
  Map<String, dynamic> toMap() => {
    'minute': minute,
    'type': type,
    if (team != null) 'team': team,
    if (type == 'goal') 'scorer': scorer,
    if (type == 'goal') 'scorerInstanceId': scorerInstanceId,
    // A CHANCE has a shooter too, once the feed is built off the positional
    // record — the man the sim had hitting it. Written only when there is one,
    // so a chance from the fallback path stays exactly the map it always was.
    // The NAME travels with the id for the same reason a goal's does: a player
    // sold before full time still had the chance, and the pitch needs something
    // to put on his dot once the card has gone.
    if (type == 'chance' && scorerInstanceId != null) ...{
      'scorer': scorer,
      'scorerInstanceId': scorerInstanceId,
    },
    if (zone != null) 'zone': zone,
    if (textKey != null) 'textKey': textKey,
    if (xg != null) 'xg': xg,
    if (shotResult != null) 'shotResult': shotResult,
    if (big != null) 'big': big,
    if (player != null) 'player': player,
    if (addedTime != null) 'addedTime': addedTime,
  };
}

/// An injury to place in the feed.
typedef InjuryEntry = ({String name, int? minute});

/// One shot the positional sim actually recorded.
///
/// **THE SIM IS THE AUTHORITY ON WHAT HAPPENED, and the feed used to invent all
/// of it.** `attack_sequence.dart` settles the score by running attacks: it
/// knows the minute, which side was attacking, WHO hit it, the zone it came
/// from and the calibrated probability it went in. The feed took none of that —
/// goal minutes came off [_pickGoalMinute], the scorer off [pickWeightedScorer]
/// and chances off an unseeded coin with a made-up xG — so the commentary could
/// credit a striker the sim never had shooting, and the 2D cutaway, picking its
/// passage blind, could sweep down the left while the text said right. A player
/// watching that is being told two different things about one moment.
typedef RecordedShot = ({
  int minute,

  /// `ours` or `theirs` — the sim's own word for the side attacking.
  String side,

  /// The shooter: one of our card instance ids, or the AI's `ai:<slot>`.
  String playerId,

  /// `goal`, `miss` or `blocked`.
  String outcome,

  /// `pitch_space.dart`'s twenty, in the sim's absolute frame.
  int zone,

  double xg,
});

/// **WHY THE FEED STILL ROLLS WHAT IT NO LONGER USES.**
///
/// Sourcing the feed from the positional record is a PRESENTATION change: the
/// scoreline was settled before [generateMatchEvents] was called and must come
/// out the other side untouched. But the goal-minute picker, the weighted scorer
/// and the invented chance loop all draw from the seeded stream, and
/// `util/random.dart`'s stream is shared with everything that happens after —
/// including, in a re-simulated remainder and in every later match of a season,
/// the sequences that DECIDE scorelines. Skip those draws and the whole season
/// reshuffles: measured at 583 of 672 golden scorelines moving, with goals a
/// match drifting 2.42 to 2.33. Nothing was wrong with the new numbers; they
/// were simply a different roll of the same dice, and a golden churn that size
/// hides whatever else a commit did.
///
/// So every draw the old code made is still made, in the same order, and the
/// answer is thrown away wherever the record has a better one. `match_events_test`
/// pins it both ways: with a record and without, the feed consumes the identical
/// stream, and without one it is byte-identical.
///
/// Dropping the discarded draws later is a one-line change and a golden
/// regeneration — worth doing deliberately, not as a side effect of this.
const bool drawsAreStreamStable = true;

/// The xG at which a chance is worth watching. The JS's own threshold, and the
/// cutaway re-checks it.
const double bigChanceXg = 0.22;

/// The candidate with that instance id, or null when the squad no longer has
/// one — a shooter substituted off before full time, most often.
ScorerCandidate? _candidateFor(List<ScorerCandidate> pool, String instanceId) {
  for (final c in pool) {
    if (c.instanceId == instanceId) return c;
  }
  return null;
}

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

  /// The positional record's shots, in the order the sim took them. Given, the
  /// goals and the chances in the feed ARE these shots; empty, the feed is
  /// invented exactly as it always was — which is still the path for a result
  /// with no record, and `match_events_test` keeps both pinned.
  List<RecordedShot> shots = const [],

  /// Which side of the fixture we are on, for the one event type whose `team`
  /// names the home CLUB rather than us. See [venueTaggedEvents] in
  /// `match_clock.dart`: a goal's `home` is ours whatever the venue, a chance's
  /// `home` is the home club, and the two conventions are load-bearing at the
  /// other end. Only read when [shots] is non-empty.
  bool isHome = true,
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

  // The record's own shots, split the way the feed needs them. A shot that went
  // in is a goal event; everything else is a chance.
  final recordedGoals = <String, List<RecordedShot>>{'ours': [], 'theirs': []};
  final recordedChances = <RecordedShot>[];
  for (final shot in shots) {
    if (shot.outcome == 'goal') {
      recordedGoals[shot.side]?.add(shot);
    } else {
      recordedChances.add(shot);
    }
  }

  /// A GOAL's `team` is ours or theirs, whatever the venue — the goal list is
  /// built off `homeGoals`/`awayGoals`, which are ours and theirs.
  String goalTeam(String side) => side == 'ours' ? 'home' : 'away';

  /// A CHANCE's `team` is the home CLUB, because `chanceWeights` is written
  /// venue-first and `eventIsOurs` reads it that way. Keeping the two
  /// conventions exactly as they were is deliberate: they are documented at the
  /// far end and a screen depends on the difference.
  String chanceTeam(String side) =>
      (side == 'ours') == isHome ? 'home' : 'away';

  /// The goals one side scored, the recorded ones first.
  ///
  /// **A RECORDED GOAL KEEPS ITS OWN MINUTE AND ITS OWN SCORER.** What stays
  /// invented is the remainder, and there is a real reason for one: λ past what
  /// the shots can carry is rolled as plain Poisson on top (see
  /// `calibrateShots`), so a side can finish with more goals than it had shots
  /// recorded and those goals have nobody behind them. They get the old picked
  /// minute and the old weighted scorer — which is also the whole path for a
  /// result with no positional record at all, so the draw order there is
  /// untouched: minute then scorer, our goals before theirs.
  void addGoals(String side, int count) {
    final recorded = recordedGoals[side] ?? const <RecordedShot>[];
    for (var i = 0; i < count; i++) {
      // **DRAWN EVEN WHEN THE RECORD ANSWERS, AND THEN THROWN AWAY** — see
      // [drawsAreStreamStable] for why, because this reads like a mistake and
      // is not one.
      final pickedMinute = _pickGoalMinute(used, goalMin, goalMax);
      final pickedScorer = side == 'ours' && playerData.isNotEmpty
          ? pickWeightedScorer(playerData)
          : null;
      final shot = i < recorded.length ? recorded[i] : null;
      events.add(
        MatchEvent(
          minute: shot?.minute.clamp(goalMin, goalMax).toInt() ?? pickedMinute,
          type: 'goal',
          team: goalTeam(side),
          // A recorded goal is credited to the man who hit it. The weighted pick
          // stays for a goal with no shot behind it — λ past what the shots can
          // carry is rolled as plain Poisson on top (see `calibrateShots`), so a
          // side can finish with more goals than recorded shots and those have
          // nobody behind them.
          scorer: shot == null
              ? pickedScorer?.name
              : (side == 'ours'
                    ? _candidateFor(playerData, shot.playerId)?.name
                    : null),
          scorerInstanceId: shot == null
              ? pickedScorer?.instanceId
              : (side == 'ours'
                    ? _candidateFor(playerData, shot.playerId)?.instanceId
                    : null),
          zone: shot?.zone,
        ),
      );
    }
  }

  addGoals('ours', homeGoals);
  addGoals('theirs', awayGoals);

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
  //
  // **THE INVENTED ONES ARE STILL ROLLED IN FULL and then dropped** when the
  // record has shots — [drawsAreStreamStable] again. What reaches the feed is
  // the shots the sim actually took: minute, side, shooter, zone and xG all its
  // own, so the feed, the momentum bar and the 2D passage become three readings
  // of ONE set of events instead of three separate inventions.
  final span = fullTimeMin - minMin + 1;
  final chanceCount = (span / 7 + 0.5).floor();
  final fromTheRecord = recordedChances.isNotEmpty;
  for (var i = 0; i < chanceCount; i++) {
    final m = _pickUnused(used, math.min(math.max(minMin, 2), goalMax), goalMax);
    final team = (_rng.nextDouble() * wTotal) < wHome ? 'home' : 'away';
    final xg = 0.08 + _rng.nextDouble() * 0.22;
    // On-target probability scales with xG — better chances are likelier to hit
    // the target.
    final onTarget = _rng.nextDouble() < (0.25 + xg * 1.2);
    if (fromTheRecord) continue;
    events.add(
      MatchEvent(
        minute: m,
        type: 'chance',
        team: team,
        xg: xg,
        shotResult: onTarget ? 'on_target' : 'off',
        big: xg >= bigChanceXg,
      ),
    );
  }
  for (final shot in recordedChances) {
    events.add(
      MatchEvent(
        // Two shots may share a minute because two shots genuinely did.
        minute: shot.minute
            .clamp(math.min(math.max(minMin, 2), goalMax), goalMax)
            .toInt(),
        type: 'chance',
        team: chanceTeam(shot.side),
        xg: shot.xg,
        // A block is not a shot that tested the keeper, and the cutaway has no
        // defender's block to draw — `outcomeForEvent` folds one into a shot off
        // target, which is what it already does with the JS's `blocked`.
        shotResult: shot.outcome == 'miss' ? 'on_target' : 'off',
        big: shot.xg >= bigChanceXg,
        scorer: shot.side == 'ours'
            ? _candidateFor(playerData, shot.playerId)?.name
            : null,
        scorerInstanceId: shot.side == 'ours'
            ? _candidateFor(playerData, shot.playerId)?.instanceId
            : null,
        zone: shot.zone,
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
