/// The progression, events and leaderboard half of the save migration.
///
/// Split from `migration.dart` purely for size — these are the same sequence of
/// back-fills, called in order from `migrate()`. See that file's header for the
/// rules that govern all of them, in particular the deliberate split between
/// the seeded and unseeded RNGs.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/team_names.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/state/migration.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

Map<String, dynamic> _ensureMap(Map<String, dynamic> parent, String key) {
  final existing = parent[key];
  if (existing is Map<String, dynamic>) return existing;
  final fresh = <String, dynamic>{};
  parent[key] = fresh;
  return fresh;
}

// ── Progression ─────────────────────────────────────────────────────────────
void migrateProgression(Map<String, dynamic> data) {
  final prog = _map(data['progression']);
  if (prog == null) return;

  prog['matchesDrawn'] ??= 0;
  prog['seasonCount'] ??= 1;
  prog['seasonMatchesPlayed'] ??= 0;
  prog['seasonWins'] ??= 0;
  prog['seasonDraws'] ??= 0;
  prog['seasonLosses'] ??= 0;
  prog['seasonComplete'] ??= false;
  prog['seasonHistory'] ??= <dynamic>[];
  if (!prog.containsKey('lastMatchResult')) prog['lastMatchResult'] = null;
  prog['seasonOpponents'] ??= <dynamic>[];
  if (prog['achievements'] is! List) prog['achievements'] = <dynamic>[];
  if (prog['leagueTrophies'] is! List) prog['leagueTrophies'] = <dynamic>[];

  // Badge auto-tracking: before this existed the only way equippedBadgeId
  // became non-null was the player choosing one by hand, so treat any existing
  // choice as manual. Saves that never picked one opt into auto-tracking.
  prog['badgeManuallySet'] ??= prog['equippedBadgeId'] != null;

  _repairSeasonCounters(prog);

  // Back-fill the count field on existing achievement entries.
  for (final a in prog['achievements'] as List) {
    final m = _map(a);
    if (m != null && m['count'] is! num) m['count'] = 1;
  }

  // Seed achievementIdsThisRun from currently-unlocked ids, so existing players
  // do not get a wall of re-unlock banners before their next reset.
  if (prog['achievementIdsThisRun'] is! List) {
    prog['achievementIdsThisRun'] = <dynamic>[
      for (final a in prog['achievements'] as List) ?_map(a)?['id'],
    ];
  }

  _seedDiscoveredPlayers(data, prog);
  _migrateCups(prog);
}

/// Reconciles the league table's played/W/D/L counters against fixtureResults.
///
/// Those counters used to be incremented only when the player dismissed the
/// full-time popup, so backgrounding the app while it was open silently dropped
/// the increment even though the fixture record was already written.
///
/// Only slots BELOW seasonMatchesPlayed count, for two reasons. First,
/// fixtureResults keys are season-scoped rather than run-scoped, and prestige
/// restarts the season count at 1 — so from the first prestige onward every
/// season shares its keys with one the previous run already played, and a
/// prefix scan read those leftovers as this season's results. Second, a match
/// writes its slot at kick-off, so a healthy save can only ever have counters
/// LAGGING the records; an awarded count above the number of matches started is
/// corrupt by definition, which is why this corrects downward too.
void _repairSeasonCounters(Map<String, dynamic> prog) {
  final season = _num(prog['seasonCount'])?.toInt() ?? 1;
  final started = _num(prog['seasonMatchesPlayed'])?.toInt() ?? 0;
  final results = _map(prog['fixtureResults']) ?? const <String, dynamic>{};

  var recPlayed = 0;
  var recWon = 0;
  var recDrawn = 0;

  for (var m = 0; m < started; m++) {
    final fr = _map(results['s${season}_m$m']);
    if (fr == null) continue;
    recPlayed++;
    if (fr['won'] == true) {
      recWon++;
    } else if (fr['drawn'] == true) {
      recDrawn++;
    }
  }

  final awarded = _num(prog['seasonAwardedPlayed'])?.toInt() ?? 0;

  // Nothing recorded and nothing to correct downward: a save from before
  // fixtureResults existed keeps its counters rather than being zeroed.
  if (recPlayed > awarded || awarded > started) {
    prog['seasonAwardedPlayed'] = recPlayed;
    prog['seasonWins'] = recWon;
    prog['seasonDraws'] = recDrawn;
    prog['seasonLosses'] = math.max(0, recPlayed - recWon - recDrawn);
  }
}

void _seedDiscoveredPlayers(
  Map<String, dynamic> data,
  Map<String, dynamic> prog,
) {
  final grid = _map(data['grid']);
  final cells = grid?['cells'];
  final gridCards = <CardInstance>[
    if (cells is List)
      for (final c in cells)
        if (CardInstance.from(c) case final card?)
          if (card.definitionId.isNotEmpty) card,
  ];

  if (prog['discoveredPlayers'] is! List) {
    final discovered = <dynamic>[];
    for (final card in gridCards) {
      final key = card.discoveryKey;
      if (!discovered.contains(key)) discovered.add(key);
    }
    prog['discoveredPlayers'] = discovered;
  }

  final counts = prog['playerFoundCounts'];
  if (counts is! Map<String, dynamic>) {
    // Seed from the current grid, using the grid count as a floor so existing
    // duplicates are not lost. Discovered-but-not-held cards get 1.
    final gridCounts = <String, int>{};
    for (final card in gridCards) {
      final key = card.discoveryKey;
      gridCounts[key] = (gridCounts[key] ?? 0) + 1;
    }
    prog['playerFoundCounts'] = <String, dynamic>{
      for (final key in prog['discoveredPlayers'] as List)
        if (key is String) key: math.max(1, gridCounts[key] ?? 0),
    };
  }
}

void _migrateCups(Map<String, dynamic> prog) {
  final cups = _map(prog['cups']);
  if (cups == null) {
    prog['cups'] = <String, dynamic>{
      'active': null,
      'history': <dynamic>[],
      'availableThisSeason': true,
    };
    return;
  }

  if (!cups.containsKey('active')) cups['active'] = null;
  if (cups['history'] is! List) cups['history'] = <dynamic>[];
  if (cups['availableThisSeason'] is! bool) cups['availableThisSeason'] = true;

  // Clear stale active runs that leaked across a season boundary. An older bug
  // could leave cups.active populated from a previous season, showing ghost
  // scores on the fixture list and causing the current season's round to be
  // skipped because the round counter was already advanced.
  final active = _map(cups['active']);
  final currentSeason = _num(prog['seasonCount'])?.toInt() ?? 1;
  if (active != null &&
      _num(active['startedSeason'])?.toInt() != currentSeason) {
    cups['active'] = null;
    cups['availableThisSeason'] = true;
    // Prune history entries tagged for this season — likely phantoms pushed by
    // the broken run. Without this, the cup looks already-played and refuses to
    // auto-start a fresh one on the next boot.
    cups['history'] = <dynamic>[
      for (final h in cups['history'] as List)
        if (_map(h) case final entry?)
          if (_num(entry['season'])?.toInt() != currentSeason) h,
    ];
  }
}

// ── One-time reseeds ────────────────────────────────────────────────────────

/// Rating-bands rebalance (2026): the per-tier bands lowered the whole rating
/// scale and division opponent ranges were retuned. Saves cached opponent
/// ratings drawn from the OLD higher ranges, leaving e.g. Elite opponents near
/// 78 against a new-scale squad of ~59. Reseed from the new ranges so the
/// gating works as designed.
///
/// Draws from the SEEDED stream, matching the JS — this is gameplay randomness.
void reseedRatingBands(Map<String, dynamic> data) {
  if (data['_ratingBandsReseed2026'] == true) return;
  final prog = _map(data['progression']);
  if (prog == null) return;

  final curDiv = getDivision(prog['currentDivision'] as String? ?? '');
  final season = _num(prog['seasonCount'])?.toInt() ?? 1;

  // Current-season fixtures the player is actively facing.
  final ratings = _map(prog['seasonOpponentRatings']);
  if (ratings != null) {
    final (lo, hi) = curDiv.opponentRatingRange;
    for (final key in ratings.keys) {
      if (key.startsWith('s${season}_')) {
        ratings[key] = seeded.randomInt(lo, hi);
      }
    }
  }

  // The AI pyramid driving promotion and relegation for every division.
  final pyramid = _map(prog['leaguePyramid']);
  if (pyramid != null) {
    pyramid.forEach((divId, teams) {
      if (teams is! List) return;
      final (lo, hi) = getDivision(divId).opponentRatingRange;
      for (final t in teams) {
        final team = _map(t);
        if (team != null && team['rating'] is num) {
          team['rating'] = seeded.randomInt(lo, hi);
        }
      }
    });
  }

  data['_ratingBandsReseed2026'] = true;
}

/// Two-layer fatigue rework: the old model drained flat points off rating and
/// PERSISTED the depleted value, so existing saves are badly over-depleted — a
/// low-rated player could sit near zero. There is no stored history to
/// reconstruct the correct new value, and the old depletion was the bug, so
/// reset every card to a full bar.
///
/// Runs for Pro AND Casual saves: a Casual save can switch to Pro later.
void reseedFatigue(Map<String, dynamic> data) {
  if (data['_fatigueTwoLayerReseed'] == true) return;

  final cells = _map(data['grid'])?['cells'];
  if (cells is List) {
    final nowMs = now();
    for (final c in cells) {
      final card = CardInstance.from(c);
      if (card == null) continue;
      final def = getPlayerDef(card.definitionId);
      if (def == null) continue;
      card.raw['energy'] = getCardRating(def, ratingBonus: card.ratingBonus);
      card.raw['energyUpdatedAt'] = nowMs;
    }
  }
  data['_fatigueTwoLayerReseed'] = true;
}

/// Prestige points (2026): one point is banked per prestige now. Back-fill
/// saves that prestiged before points existed.
void backfillPrestigePoints(Map<String, dynamic> data) {
  if (data['_prestigePoints2026'] == true) return;

  final prestige = _map(data['prestige']);
  if (prestige != null && prestige['points'] == null) {
    final level = _num(prestige['level'])?.toDouble() ?? 0;
    prestige['points'] = math.max(0, (level + 0.5).floor());
  }
  data['_prestigePoints2026'] = true;
}

// ── Team-name scrub ─────────────────────────────────────────────────────────

final RegExp _blocked = RegExp('cocks', caseSensitive: false);
final RegExp _staleReserve = RegExp(r'^FC Reserve', caseSensitive: false);

bool isBadTeamName(Object? name) =>
    name is! String ||
    name.isEmpty ||
    _blocked.hasMatch(name) ||
    _staleReserve.hasMatch(name);

/// Replaces stale placeholder and blocked names with generated ones, so players
/// never see a leftover "FC Reserve".
void scrubTeamNames(Map<String, dynamic> data) {
  final prog = _map(data['progression']);
  if (prog == null) return;

  final pyramid = _map(prog['leaguePyramid']);
  if (pyramid != null) {
    for (final divId in pyramid.keys.toList()) {
      final teams = pyramid[divId];
      if (teams is! List) continue;

      final usedInDiv = <String>{
        for (final t in teams)
          if (_map(t)?['name'] case final String n)
            if (!isBadTeamName(n)) n,
      };

      pyramid[divId] = <dynamic>[
        for (final t in teams)
          if (_map(t) case final team?)
            if (!isBadTeamName(team['name']))
              t
            else
              () {
                final newName = generateTeamName(divTier(divId), usedInDiv);
                usedInDiv.add(newName);
                return <String, dynamic>{...team, 'name': newName};
              }()
          else
            t,
      ];
    }
  }

  final opponents = prog['seasonOpponents'];
  if (opponents is List) {
    final used = <String>{
      for (final n in opponents)
        if (n is String && !isBadTeamName(n)) n,
    };
    prog['seasonOpponents'] = <dynamic>[
      for (final name in opponents)
        if (!isBadTeamName(name))
          name
        else
          () {
            final newName = generateTeamName('grassroots', used);
            used.add(newName);
            return newName;
          }(),
    ];
  }

  // v4: re-roll pyramid attackBias to a bimodal distribution so leagues carry a
  // clear mix of attack-minded, balanced and defence-minded teams.
  //
  // Unseeded, matching the JS Math.random() here.
  if (pyramid != null) {
    for (final teams in pyramid.values) {
      if (teams is! List) continue;
      for (final t in teams) {
        final team = _map(t);
        if (team == null) continue;
        final r = migrationRandom.nextDouble();
        team['attackBias'] = r < 0.35
            ? 0.55 + migrationRandom.nextDouble() * 0.35
            : r < 0.65
            ? migrationRandom.nextDouble() * 0.30 - 0.15
            : -(0.55 + migrationRandom.nextDouble() * 0.35);
      }
    }
  }
}

// ── Career counters ─────────────────────────────────────────────────────────

/// Lifetime career counters, which survive prestige.
///
/// The all-time leaderboard derives from these rather than the season counters,
/// which prestige zeroes — that bug wiped a prestiged player's global standing.
/// Back-fill from the surviving fixture history and take the larger of that and
/// the live counters: for an un-prestiged save the counters are truth; for one
/// whose counters were prestige-reset, the fixtures recover the real totals.
void backfillCareerCounters(Map<String, dynamic> data) {
  final prog = _map(data['progression']);
  if (prog == null) return;

  // Once the counters exist and the one-off recovery has run there is nothing
  // left to do, so skip the fixture scan entirely on every subsequent boot.
  final needsBackfill =
      prog['careerWins'] == null ||
      prog['careerDraws'] == null ||
      prog['careerGoalsFor'] == null ||
      prog['careerBackfillDone'] != true;

  if (needsBackfill) {
    var recW = 0;
    var recD = 0;
    num recG = 0;

    final results = _map(prog['fixtureResults']) ?? const <String, dynamic>{};
    for (final v in results.values) {
      final fr = _map(v);
      if (fr == null) continue;
      // Engine convention: homeGoals is always the player's goals.
      recG += _num(fr['homeGoals']) ?? 0;
      if (fr['won'] == true) {
        recW++;
      } else if (fr['drawn'] == true) {
        recD++;
      }
    }

    prog['careerWins'] ??= math.max(
      _num(prog['matchesWon'])?.toInt() ?? 0,
      recW,
    );
    prog['careerDraws'] ??= math.max(
      _num(prog['matchesDrawn'])?.toInt() ?? 0,
      recD,
    );
    prog['careerGoalsFor'] ??= recG;

    // One-off recovery for the prestige-wipe bug: if the surviving fixtures
    // show more wins or draws than the reset counters, this save's all-time row
    // was zeroed. Bump the counters to the reconstruction and force a reseed.
    if (prog['careerBackfillDone'] != true) {
      prog['careerBackfillDone'] = true;
      if (recW > (_num(prog['matchesWon'])?.toInt() ?? 0) ||
          recD > (_num(prog['matchesDrawn'])?.toInt() ?? 0)) {
        prog['careerWins'] = math.max(
          _num(prog['careerWins'])?.toInt() ?? 0,
          recW,
        );
        prog['careerDraws'] = math.max(
          _num(prog['careerDraws'])?.toInt() ?? 0,
          recD,
        );
        prog['careerGoalsFor'] = math.max(
          _num(prog['careerGoalsFor']) ?? 0,
          recG,
        );
        final lb = _map(data['leaderboard']);
        if (lb != null) lb['careerSeeded'] = false;
      }
    }
  }

  // One-off recovery for the soft-reset wipe bug: the reset used to replace the
  // whole progression object, discarding the career counters instead of
  // carrying them forward — and it wiped fixtureResults too, so the block above
  // cannot reconstruct them. careerStats.matchesWon is a separate, older
  // counter incremented in lockstep on every win that DOES survive every reset,
  // so use it as a high-water mark. Draws and goals cannot be recovered this
  // way, so this is a partial repair — far better than an all-time board at
  // roughly zero.
  if (prog['careerResetRecoveryDone'] != true) {
    prog['careerResetRecoveryDone'] = true;
    final surviving =
        _num(_map(data['careerStats'])?['matchesWon'])?.toInt() ?? 0;
    if (surviving > (_num(prog['careerWins'])?.toInt() ?? 0)) {
      prog['careerWins'] = surviving;
      final lb = _map(data['leaderboard']);
      if (lb != null) {
        lb['careerSeeded'] = false;
        lb['allTimeRepairDone'] = false;
      }
    }
  }
}

// ── Deadline Day, events, gems, rating, leaderboard, misc ───────────────────

Map<String, dynamic> _freshDeadlineSession() => <String, dynamic>{
  'windowStart': 0,
  'startedAt': 0,
  'endsAt': 0,
  'listings': <dynamic>[],
  'spawned': 0,
  'marquees': 0,
  'done': false,
  'summary': null,
};

/// Back-fills the whole Deadline Day shape so the engine can read
/// `deadlineDay.session.listings` without guarding every hop. An absent session
/// is indistinguishable from a never-played one, which is what an old save
/// wants.
void migrateDeadlineDay(Map<String, dynamic> data) {
  final dd = _map(data['deadlineDay']);
  if (dd == null) {
    data['deadlineDay'] = <String, dynamic>{
      'session': _freshDeadlineSession(),
      'history': <dynamic>[],
    };
    return;
  }

  if (_map(dd['session']) == null) dd['session'] = _freshDeadlineSession();
  final s = _map(dd['session'])!;

  if (s['listings'] is! List) s['listings'] = <dynamic>[];
  for (final k in [
    'windowStart',
    'startedAt',
    'endsAt',
    'spawned',
    'marquees',
  ]) {
    if (s[k] is! num) s[k] = 0;
  }
  if (s['done'] is! bool) s['done'] = false;
  if (!s.containsKey('summary')) s['summary'] = null;
  if (dd['history'] is! List) dd['history'] = <dynamic>[];
}

/// Always back-fills the top-level event shape so engine code can read
/// `events.active` without null-guarding everywhere.
void migrateEvents(Map<String, dynamic> data) {
  final events = _map(data['events']);
  if (events == null) {
    data['events'] = <String, dynamic>{
      'active': <dynamic>[],
      'progress': <String, dynamic>{},
      'history': <dynamic>[],
      'devOverride': null,
    };
  } else {
    if (events['active'] is! List) events['active'] = <dynamic>[];
    if (events['history'] is! List) events['history'] = <dynamic>[];
    if (_map(events['progress']) == null) {
      events['progress'] = <String, dynamic>{};
    }
    if (!events.containsKey('devOverride')) events['devOverride'] = null;
  }

  // Back-fill firstWin from legacy event-flagged trophies pushed before the
  // record existed, so an older save can still show the nation and date.
  final progress = _ensureMap(_ensureMap(data, 'events'), 'progress');
  final trophies = _map(data['progression'])?['leagueTrophies'];
  if (trophies is! List) return;

  for (final t in trophies) {
    final tr = _map(t);
    if (tr == null || tr['event'] == null || tr['eventId'] == null) continue;
    final eventId = tr['eventId'] as String;

    var ep = _map(progress[eventId]);
    if (ep == null) {
      ep = <String, dynamic>{
        'score': 0,
        'claimedTiers': <dynamic>[],
        'challenges': <String, dynamic>{},
        'cup': null,
      };
      progress[eventId] = ep;
    }

    ep['firstWin'] ??= <String, dynamic>{
      'playerNation': tr['playerNation'],
      'wonAt': 0, // legacy entries carry no timestamp
    };
  }
}

/// Back-fills the gem faucet ledger so the gem engine never has to null-guard,
/// then runs the one-time tutorial retro-pay.
void migrateGemLedger(Map<String, dynamic> data) {
  if (data['gemUnlocks'] is! List) data['gemUnlocks'] = <dynamic>[];

  final tutorialDone = _map(data['tutorial'])?['done'] == true;
  final grants = _map(data['gemGrants']);

  if (grants == null) {
    data['gemGrants'] = <String, dynamic>{
      'tutorialGranted': tutorialDone,
      'divisionFirsts': <dynamic>[],
      'cupFirsts': <dynamic>[],
      'firstPrestigeDone': (_num(_map(data['prestige'])?['level']) ?? 0) > 0,
      'chlTitleThisRun': false,
    };
  } else {
    if (grants['tutorialGranted'] is! bool) grants['tutorialGranted'] = false;
    if (grants['divisionFirsts'] is! List) {
      grants['divisionFirsts'] = <dynamic>[];
    }
    if (grants['cupFirsts'] is! List) grants['cupFirsts'] = <dynamic>[];
    if (grants['firstPrestigeDone'] is! bool) {
      grants['firstPrestigeDone'] = false;
    }
    if (grants['chlTitleThisRun'] is! bool) grants['chlTitleThisRun'] = false;
  }

  final ledger = _ensureMap(data, 'gemGrants');

  // ONE-TIME RETRO-PAY of the tutorial's gems.
  //
  // The block above used to mark every pre-existing save as already-granted, on
  // the reasoning that those players were past that moment. The effect was that
  // everyone who learned the game before gems existed never received the grant
  // at all — the flag said "paid" and nothing had been.
  //
  // Keyed on its OWN flag rather than tutorialGranted, because that is exactly
  // the thing that was wrongly set: it cannot tell "already paid" from
  // "retro-flagged and never paid". Its flag is set unconditionally, so this
  // runs at most once per save whatever the balance does afterwards.
  //
  // The zero-balance test keeps it away from anyone who already has their gems.
  // Someone who earned them and has since spent them is topped up once —
  // accepted: it is five gems, one time, and the alternative denies the people
  // this is actually for.
  if (ledger['tutorialBackfilled'] != true) {
    ledger['tutorialBackfilled'] = true;
    final resources = _ensureMap(data, 'resources');
    if (tutorialDone && (_num(resources['gems']) ?? 0) == 0) {
      resources['gems'] = tutorialGems;
    }
  }

  if (ledger['questDivisionFirsts'] is! List) {
    ledger['questDivisionFirsts'] = <dynamic>[];
  }
}

void migrateRatingPrompt(Map<String, dynamic> data) {
  final rating = _map(data['rating']);
  if (rating == null) {
    data['rating'] = <String, dynamic>{
      'status': 'pending',
      'promptCount': 0,
      'lastPromptAt': 0,
      'nextPromptAt': 0,
    };
    return;
  }
  if (rating['status'] is! String) rating['status'] = 'pending';
  for (final k in ['promptCount', 'lastPromptAt', 'nextPromptAt']) {
    if (rating[k] is! num) rating[k] = 0;
  }
  rating.remove('feedback'); // never surfaced server-side
}

void migrateLeaderboard(Map<String, dynamic> data) {
  final lb = _map(data['leaderboard']);
  if (lb == null) {
    // allTimeRepairDone is written here even though the JS create-branch omits
    // it — there, the else branch adds it on the NEXT boot, so a legacy save
    // takes two passes to settle. Both builds reach the same state; including
    // it makes the migration idempotent in one.
    data['leaderboard'] = <String, dynamic>{
      'playerId': null,
      'authUid': null,
      'lastSubmittedAt': 0,
      'careerSeeded': false,
      'anonymousLinked': false,
      'rankingsVisible': true,
      'allTimeRepairDone': false,
    };
  } else {
    if (lb['playerId'] != null && lb['playerId'] is! String) {
      lb['playerId'] = null;
    }
    if (lb['authUid'] != null && lb['authUid'] is! String) lb['authUid'] = null;
    if (lb['lastSubmittedAt'] is! num) lb['lastSubmittedAt'] = 0;
    if (lb['careerSeeded'] is! bool) lb['careerSeeded'] = false;
    if (lb['anonymousLinked'] is! bool) lb['anonymousLinked'] = false;
    if (lb['rankingsVisible'] is! bool) lb['rankingsVisible'] = true;
    if (lb['metaClubName'] != null && lb['metaClubName'] is! String) {
      lb['metaClubName'] = null;
    }
    if (lb['allTimeRepairDone'] is! bool) lb['allTimeRepairDone'] = false;
  }

  // Leaderboard schema v4 forces a one-time career reseed into the new paths.
  // Old-schema rows are orphaned rather than migrated, and queued writes must
  // not replay onto dead paths. (v3 was the row/period change; v4 is the
  // goals_for repair — away matches used to record the opponent's goals.)
  final board = _ensureMap(data, 'leaderboard');
  if (_num(board['lbSchema'])?.toInt() != 4) {
    board['lbSchema'] = 4;
    board['careerSeeded'] = false;
    board['prestigeSynced'] = null;
    board['metaClubName'] = null;
    board['pendingWrites'] = <dynamic>[];
  }
}

/// Per-definition ratios are generated once per save and re-rolled on prestige.
/// Per-instance ratios are back-filled so two copies of one definition get
/// distinct ATK/DEF values.
///
/// Both use unseeded randomness, matching the JS.
void migrateRatios(Map<String, dynamic> data) {
  final ratios = _map(data['definitionRatios']);
  if (ratios == null || ratios.isEmpty) {
    data['definitionRatios'] = generateDefinitionRatios();
  }

  final cells = _map(data['grid'])?['cells'];
  if (cells is! List) return;

  for (final c in cells) {
    final card = CardInstance.from(c);
    if (card == null || card.raw['attackRatio'] != null) continue;
    final def = getPlayerDef(card.definitionId);
    final (lo, hi) = ratioRange[def?.position] ?? (0.35, 0.65);
    final rolled = lo + migrationRandom.nextDouble() * (hi - lo);
    card.raw['attackRatio'] = ((rolled * 100) + 0.5).floor() / 100;
  }
}

void migrateAgeVerification(Map<String, dynamic> data) {
  final av = _map(data['ageVerification']);
  if (av == null) {
    data['ageVerification'] = <String, dynamic>{
      'status': 'unknown',
      'source': null,
      'checkedAt': 0,
      'parentalConsentGiven': false,
      'parentalConsentAt': 0,
    };
    return;
  }
  if (!['unknown', 'child', 'teen', 'adult'].contains(av['status'])) {
    av['status'] = 'unknown';
  }
  if (av['source'] != 'play_api') av['source'] = null;
  if (av['checkedAt'] is! num) av['checkedAt'] = 0;
  if (av['parentalConsentGiven'] is! bool) av['parentalConsentGiven'] = false;
  if (av['parentalConsentAt'] is! num) av['parentalConsentAt'] = 0;
}

/// Nothing here needs recovering: the location is re-derived from the device
/// timezone on the next boot, and a missing reading just means the seasonal
/// model draws the weather until the first fetch lands.
void migrateWeather(Map<String, dynamic> data) {
  final w = _map(data['weather']);
  if (w == null) {
    data['weather'] = <String, dynamic>{
      'timeZone': null,
      'lat': null,
      'lon': null,
      'locationSource': null,
      'live': null,
      'failedAt': null,
    };
    return;
  }
  if (w['lat'] is! num || w['lon'] is! num) {
    w['lat'] = null;
    w['lon'] = null;
  }
  // A reading with no timestamp can never be aged out, so it would pin the
  // scene to one condition forever. Drop it and refetch.
  final live = _map(w['live']);
  if (live == null || live['fetchedAt'] is! num) w['live'] = null;
  if (w['failedAt'] is! num) w['failedAt'] = null;
}

/// Quests replaced the old daily-challenge branch.
///
/// `challenges` never rendered — its bar was never mounted, so the daily list
/// stayed empty on every save that ever existed. There is no progress worth
/// carrying across, only a dead branch to drop.
///
/// The gem ledger is seeded EMPTY, not back-filled from division history:
/// back-filling would hand an established save several gems for quests it never
/// saw, and that ledger is the only thing bounding the feature at seven gems
/// for the lifetime of an account.
void migrateQuests(Map<String, dynamic> data) {
  data.remove('challenges');

  final quests = _ensureMap(data, 'quests');

  final match = _map(quests['match']);
  if (match == null) {
    quests['match'] = <String, dynamic>{
      'fixtureKey': null,
      'active': <dynamic>[],
    };
  } else if (match['active'] is! List) {
    match['active'] = <dynamic>[];
  }

  if (quests['season'] is! List) quests['season'] = <dynamic>[];
  if (quests['recent'] is! List) quests['recent'] = <dynamic>[];
  if (quests['lastRolledSeason'] is! num) quests['lastRolledSeason'] = 0;

  if (_map(quests['streaks']) == null) {
    quests['streaks'] = <String, dynamic>{
      'cleanSheet': 0,
      'win': 0,
      'unbeaten': 0,
    };
  }
}
