/// The season boundary, and the prestige that eventually ends a career. Ported
/// from the season half of
/// `../merge-empire-fc/src/engine/progressionEngine.js`.
///
/// This is where nearly everything meets: the table decides the player's own
/// promotion or relegation, the pyramid shuffles around them, quests are swept
/// and redrawn, the squad ages, injuries get a head start over the break and
/// the next campaign's fixtures are drawn.
///
/// ORDER IS LOAD-BEARING throughout, and most of the ordering rules here exist
/// because getting one wrong shipped a bug once. They are called out where they
/// bite.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/auto_tier_engine.dart';
import 'package:merge_empire_fc/engine/cup_engine.dart';
import 'package:merge_empire_fc/engine/event_engine.dart';
import 'package:merge_empire_fc/engine/gem_engine.dart';
import 'package:merge_empire_fc/engine/league_pyramid.dart';
import 'package:merge_empire_fc/engine/league_table.dart';
import 'package:merge_empire_fc/engine/lineup_engine.dart';
import 'package:merge_empire_fc/engine/quest_engine.dart';
import 'package:merge_empire_fc/engine/season_fixtures.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart' show matchesPerSeason;
import 'package:merge_empire_fc/engine/transfer_engine.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

Map<String, dynamic> _branch(Map<String, dynamic> owner, String key) {
  final existing = _map(owner[key]);
  if (existing != null) return existing;
  final fresh = <String, dynamic>{};
  owner[key] = fresh;
  return fresh;
}

List<dynamic> _list(Map<String, dynamic> owner, String key) {
  final existing = owner[key];
  if (existing is List) return existing;
  final fresh = <dynamic>[];
  owner[key] = fresh;
  return fresh;
}

List<dynamic> _cells(Map<String, dynamic> state) =>
    _list(_branch(state, 'grid'), 'cells');

/// The action funnel — "the player just did a thing worth counting".
///
/// Two consumers, deliberately kept behind one call so a new call site can
/// never wire up one and forget the other: the season quest track and any
/// active event's reward track.
///
/// Events also emit their own types straight from the cup flow, which pass
/// through here harmlessly — the quest side ignores actions it doesn't know.
void trackEvent(Map<String, dynamic> state, String action, [num amount = 1]) {
  advanceQuest(state, action, amount);
  trackEventAction(state, action, amount);
}

/// The places that promote and relegate at the foot and head of a table.
const int _promotionPlaces = 2;

/// Directly promote the top two AI clubs and relegate the bottom two in the
/// player's own division, from the ACTUAL season table.
///
/// This replaces a rating nudge that the shuffle's own random noise could
/// override, which had last-placed sides reappearing the next season.
///
/// THE PLACES COME OFF THE WHOLE TABLE, and the AI clubs among them are the
/// ones this moves — the player is moved by [endSeason]'s own outcome. Slicing
/// the AI-only rows sent the top two AI clubs up REGARDLESS of where the player
/// finished, so a promoted player made it three clubs out of one league, and a
/// relegated one three down. The table says two up and two down; so does this.
///
/// Returns the names it moved, so the shuffle that follows can leave them
/// alone, and fills [statuses] with the badge each carries into the new season.
Set<String> _directPromoteRelegate(
  Map<String, dynamic> state,
  List<LeagueRow> table,
  String divId,
  Map<String, dynamic> statuses,
) {
  final moved = <String>{};
  final pyramid = _map(_map(state['progression'])?['leaguePyramid']);
  final divTeams = pyramid?[divId];
  if (pyramid == null || divTeams is! List) return moved;

  final divIdx = divisions.indexWhere((d) => d.id == divId);
  if (!table.any((r) => !r.isPlayer)) return moved;

  List<LeagueRow> aiIn(Iterable<LeagueRow> rows) => [
    for (final r in rows)
      if (!r.isPlayer) r,
  ];

  // `bump` is a THUNK, not a number, because the JS draws its random nudge
  // INSIDE the found-the-club branch. A table row can name a club that isn't in
  // this division's pyramid at all — the fabricated fallback rows are the stored
  // season opponents, which after a division change belong somewhere else — and
  // drawing for one that is never moved shifts every later number in the shared
  // stream, which shuffles the whole pyramid differently.
  void move(LeagueRow row, Division toDiv, String status, int Function() bump) {
    final idx = divTeams.indexWhere((t) => _map(t)?['name'] == row.name);
    if (idx < 0) return;
    final entry = _map(divTeams.removeAt(idx))!;
    final (lo, hi) = toDiv.opponentRatingRange;
    final rating = math.max(
      lo - 4,
      math.min(hi + 4, (_num(entry['rating'])?.toInt() ?? 0) + bump()),
    );
    (pyramid[toDiv.id] as List).add(
      ensureFormation({
        'name': entry['name'],
        'rating': rating,
        'formation': entry['formation'],
        'attackRatio': entry['attackRatio'],
      }, toDiv.id),
    );
    moved.add('${entry['name']}');
    statuses['${entry['name']}'] = {'status': status, 'division': toDiv.id};
  }

  if (divIdx > 0) {
    final lower = divisions[divIdx - 1];
    for (final loser in aiIn(
      table.skip(math.max(0, table.length - _promotionPlaces)),
    )) {
      move(loser, lower, 'relegated', () => -seeded.randomInt(3, 6));
    }
  }

  if (divIdx < divisions.length - 1) {
    final upper = divisions[divIdx + 1];
    for (final winner in aiIn(table.take(_promotionPlaces))) {
      move(winner, upper, 'promoted', () => seeded.randomInt(3, 7));
    }
  }

  return moved;
}

/// What a season ended in.
typedef SeasonOutcome = ({
  String outcome,
  int position,
  String oldDivision,
  String newDivision,
  num payout,
  int gemsAwarded,
  List<Map<String, dynamic>> ageingReport,
  ({int recovered, int shortened}) injuryReport,
  ({int expired}) sponsorReport,
});

/// The coin bonus for finishing in each place, as a multiple of one league win.
///
/// Promotion pays the most, mid-table gets something, and the bottom gets
/// nothing — scaled by the division so the number feels right at every tier.
const Map<int, int> _positionBonus = {
  1: 25,
  2: 18,
  3: 12,
  4: 8,
  5: 5,
  6: 3,
  7: 1,
  8: 0,
};

/// Close the season: settle the table, move everybody, pay out, age the squad
/// and draw the next campaign.
SeasonOutcome endSeason(Map<String, dynamic> state) {
  final prog = _branch(state, 'progression');
  final table = buildLeagueTable(state);
  final pos = table.indexWhere((r) => r.isPlayer) + 1;
  // Captured before the stats are reset below, and derived the same way the
  // table derives it, so the record the summary shows adds up.
  final seasonLosses = table
      .firstWhere(
        (r) => r.isPlayer,
        orElse: () => LeagueRow(
          name: '',
          isPlayer: true,
          played: 0,
          won: 0,
          drawn: 0,
          lost: 0,
          pts: 0,
          gd: 0,
        ),
      )
      .lost;

  final divId = '${prog['currentDivision']}';
  final divIdx = divisions.indexWhere((d) => d.id == divId);
  final season = _num(prog['seasonCount'])?.toInt() ?? 1;

  // Collect any season quest the player finished but never claimed, and settle
  // the division capstone — both BEFORE the promotion below moves the current
  // division. The capstone is credited to the division whose quests were
  // actually played, and running it after promotion would hand the gem to the
  // division above.
  sweepUnclaimedSeasonQuests(state);
  checkDivisionCapstone(state);

  var outcome = 'stayed';
  var newDivId = divId;
  if (pos <= 2 && divIdx < divisions.length - 1) {
    newDivId = divisions[divIdx + 1].id;
    outcome = 'promoted';
  } else if (pos >= 7 && divIdx > 0) {
    newDivId = divisions[divIdx - 1].id;
    outcome = 'relegated';
  }

  // Move the player's own division from the real table, then shuffle the rest
  // of the pyramid — skipping this division, which is already handled. The
  // moved set stops the shuffle bouncing a just-relegated club straight back.
  final seasonStatuses = <String, dynamic>{};
  final movedByDirect = _directPromoteRelegate(
    state,
    table,
    divId,
    seasonStatuses,
  );
  shufflePyramid(
    state,
    skipDivId: divId,
    recentlyMoved: movedByDirect,
    statuses: seasonStatuses,
  );

  _stampLastSeasonStatus(
    state,
    table: table,
    divId: divId,
    newDivId: newDivId,
    outcome: outcome,
    season: season,
    statuses: seasonStatuses,
  );

  // The season-end payout rewards the whole climb rather than the last match.
  final div = getDivision(divId);
  final bonusUnits =
      (_positionBonus[pos] ?? 0) + (outcome == 'promoted' ? 10 : 0);
  final payout = roundCoins(bonusUnits * div.matchRevenueBase);
  if (payout > 0) {
    final resources = _branch(state, 'resources');
    resources['fanCoins'] = (_num(resources['fanCoins']) ?? 0) + payout;
  }

  _list(prog, 'seasonHistory').add(<String, dynamic>{
    'season': season,
    'division': divId,
    'position': pos,
    'outcome': outcome,
    'payout': payout,
  });
  prog['lastSeasonPayout'] = payout;

  // A league title is going up — a top-two finish in the division — OR winning
  // the top flight, which cannot go up.
  //
  // **WINNING THE WHOLE LADDER USED TO COUNT FOR NOTHING HERE.** Promotion was
  // the only way a trophy was ever recorded and the Champions League is the
  // last division, so `pos <= 2 && divIdx < divisions.length - 1` can never be
  // true there: the title set `wonChampionsCup`, paid its gems, unlocked
  // prestige, and put nothing on a shelf and nothing in the career. The trophy
  // room's highest league shelf was Continental while
  // `assets/trophies/champions_cup.png` sat shipped and unreachable, and the
  // Champions CUP under the cups is a different competition — `world_club_cup`,
  // which merely renders as a similar name. Reported from the couch. Repeatable
  // by design: stay up, win it again, take another.
  //
  // **The JS has the same gap** — `progressionEngine.js`'s push is
  // `outcome === 'promoted'` too — so this is a deliberate divergence, and it is
  // in the engine rather than on a screen because a trophy and a career total
  // are RECORDS of something that happened, not captions.
  //
  // **It moves a field the parity harness compares**, which is why the count is
  // in the same branch as the trophy rather than beside it: `careerStats` is
  // checked as a whole map, so `season_end_test.dart` states the delta — one
  // per top-flight title, and nothing else — instead of the field being quietly
  // excluded. The failure on `topFlightChampion` and `topFlightMid` is what
  // found the line; read the note there before changing either.
  final wonTopFlight = pos == 1 && divIdx == divisions.length - 1;
  if (outcome == 'promoted' || wonTopFlight) {
    _list(prog, 'leagueTrophies').add(<String, dynamic>{
      'season': season,
      'division': divId,
      'position': pos,
    });
    final career = _branch(state, 'careerStats');
    career['leagueWins'] = (_num(career['leagueWins'])?.toInt() ?? 0) + 1;
    career['cupWins'] = _num(career['cupWins'])?.toInt() ?? 0;
  }

  var gemsAwarded = 0;
  if (divId == 'champions_cup' && pos == 1) {
    prog['wonChampionsCup'] = true;
    gemsAwarded += grantChampionsTitleGems(state);
  }
  // The first time this player has EVER reached one of the top three divisions.
  // Keyed on the lifetime ledger inside the grant, never on divisionsUnlocked.
  if (outcome == 'promoted') {
    gemsAwarded += grantDivisionFirstGems(state, newDivId);
  }

  _applyStagnation(prog, divId, outcome);

  prog['currentDivision'] = newDivId;
  final unlocked = _list(prog, 'divisionsUnlocked');
  if (!unlocked.contains(newDivId)) unlocked.add(newDivId);

  final ageingReport = _ageTheSquad(state);
  final counters = _resetSeasonCounters(state, season);
  final injuryReport = counters.injuries;

  emit('season:started', {'season': prog['seasonCount']});
  prog['seasonComplete'] = false;
  final shop = _map(state['shop']);
  if (shop != null) shop['luckyBootUses'] = 0;

  // No transfer offer until the player has played into the new season — a bid
  // landing before the first fixture feels random.
  holdOffersForNewSeason(state);

  // A fresh schedule for the new campaign.
  prog['seasonFixtures'] = null;
  initSeasonOpponents(state);

  // Cups refresh each season, so a player who skipped one gets another shot.
  // An active run carries over untouched. Through the cup engine's own
  // `refreshCupAvailability` rather than the flag: the engine that decides what
  // `availableThisSeason` means is the one that should set it, and it also
  // builds the branch on a save that has none — this used to skip silently
  // there.
  refreshCupAvailability(state);
  // Auto-enter the cup for the division — matching real football, where clubs
  // are scheduled into their cup rather than opting in.
  if (cupForDivision(state) != null && cupAvailable(state)) startCup(state);

  final result = (
    outcome: outcome,
    position: pos,
    oldDivision: divId,
    newDivision: newDivId,
    payout: payout,
    gemsAwarded: gemsAwarded,
    ageingReport: ageingReport,
    injuryReport: injuryReport,
    sponsorReport: counters.sponsors,
  );

  emit('season:ended', {
    'outcome': outcome,
    'position': pos,
    'seasonLosses': seasonLosses,
    'oldDivision': divId,
    'newDivision': newDivId,
    'payout': payout,
    'ageingReport': ageingReport,
    'injuryReport': {
      'recovered': injuryReport.recovered,
      'shortened': injuryReport.shortened,
    },
    'sponsorReport': {'expired': counters.sponsors.expired},
  });

  return result;
}

/// Who came up, who went down and who lifted the title — stamped now so the
/// NEXT season's tables can badge them.
///
/// The player's own badge is stored apart from the name map: an unnamed save's
/// "Your Club" must not collide with an AI club, and the player's name can
/// change mid-run. The top flight has no promotion, so its champion is settled
/// from the real table when the player is in it.
void _stampLastSeasonStatus(
  Map<String, dynamic> state, {
  required List<LeagueRow> table,
  required String divId,
  required String newDivId,
  required String outcome,
  required int season,
  required Map<String, dynamic> statuses,
}) {
  String? playerStatus;
  if (divId == 'champions_cup' && table.isNotEmpty) {
    final winner = table.first;
    if (winner.isPlayer) {
      playerStatus = 'champion';
    } else {
      statuses[winner.name] = {'status': 'champion', 'division': divId};
    }
  }
  if (playerStatus == null && outcome != 'stayed') playerStatus = outcome;

  _branch(state, 'progression')['lastSeasonStatus'] = <String, dynamic>{
    'season': season,
    'player': playerStatus,
    'playerDivision': newDivId,
    'teams': statuses,
  };
}

/// The per-division stagnation buff: a point of ATK and DEF for every season
/// stuck, capped.
///
/// Promotion clears a point off the division you are leaving; relegation adds
/// one in the division below because you failed, and mid-table adds one because
/// nothing happened. The Champions League is skipped entirely — it has no
/// promotion to escape by, so the buff would accumulate for ever.
void _applyStagnation(Map<String, dynamic> prog, String divId, String outcome) {
  final buffs = _branch(prog, 'stagnationBuffs');
  final current = _num(buffs[divId])?.toInt() ?? 0;
  if (divId != 'champions_cup') {
    buffs[divId] = outcome == 'promoted'
        ? math.max(0, current - 1)
        : math.min(10, current + 1);
  }
  // Clear anything that accumulated in the top flight before this rule.
  buffs['champions_cup'] = 0;
}

/// Age every player by a season, and emit the milestones the coach warns on.
List<Map<String, dynamic>> _ageTheSquad(Map<String, dynamic> state) {
  for (final raw in _cells(state)) {
    final card = _map(raw);
    if (card == null) continue;
    // A loanee doesn't age — a loan is measured in matches, not seasons, and
    // they will be gone long before an ageing penalty could matter. Ageing them
    // would also let a loan drift toward the retirement sweep.
    if (card['loanMatchesLeft'] != null) continue;

    final s = (_num(card['seasonsPlayed'])?.toInt() ?? 0) + 1;
    card['seasonsPlayed'] = s;

    const milestones = {
      10: ('at-risk', 0, 5),
      11: ('declining', 10, 4),
      12: ('declining', 20, 3),
      13: ('sell-now', 30, 2),
      14: ('final-season', 40, 1),
    };
    final milestone = milestones[s];
    if (milestone == null) continue;
    emit('player:ageing', {
      'card': card,
      'milestone': milestone.$1,
      if (milestone.$2 > 0) 'penalty': milestone.$2,
      'seasonsLeft': milestone.$3,
    });
  }

  // After ageing, the veterans who have run out of seasons leave.
  return processAgeRegression(state);
}

/// Reset the season counters, roll the new quest track, and give injuries and
/// sponsors their close-season treatment.
({({int recovered, int shortened}) injuries, ({int expired}) sponsors})
_resetSeasonCounters(Map<String, dynamic> state, int oldSeason) {
  final prog = _branch(state, 'progression');
  prog['seasonCount'] = oldSeason + 1;

  // Zeroed BEFORE the quest roll, not after: the roll won't hand out a quest
  // that can't be finished in the fixtures left, and at this point the counter
  // still reads the full season just played — so a track rolled against it
  // would find nothing match-paced feasible and draw three merge quests.
  prog['seasonMatchesPlayed'] = 0;
  // And AFTER the season bump, which the roll keys off to avoid re-rolling
  // mid-season and wiping accumulated progress.
  rollSeasonQuests(state, prog['seasonCount'] as int);

  final cups = _map(prog['cups']);
  if (cups != null) cups['active'] = null;

  prog['seasonAwardedPlayed'] = 0;
  prog['seasonWins'] = 0;
  // The last match belongs to the previous campaign — don't let its commentary
  // leak into the fresh season's coach panel.
  prog['lastMatchResult'] = null;
  // Draws and losses used to accumulate across seasons, which surfaced as
  // wildly wrong records on the position card.
  prog['seasonDraws'] = 0;
  prog['seasonLosses'] = 0;

  // Form decays by one toward zero at each boundary. Injuries get a ten-minute
  // head start — not a full heal, just enough that the new season doesn't begin
  // with a full limp from the last match of the old one. A player sponsor is a
  // one-season deal, so anything signed in a previous season expires now, and a
  // legacy sponsor with no stamp is treated as expired too.
  const offseasonRecoveryMs = 10 * 60 * 1000;
  final newSeason = prog['seasonCount'] as int;
  var recovered = 0;
  var shortened = 0;
  var expired = 0;

  for (final raw in _cells(state)) {
    final card = _map(raw);
    if (card == null) continue;

    final form = _num(card['form'])?.toInt() ?? 0;
    if (form != 0) card['form'] = form > 0 ? form - 1 : form + 1;

    final sponsor = _map(card['sponsor']);
    if (sponsor != null) {
      final signed = _num(sponsor['signedSeason'])?.toInt();
      if (signed == null || signed < newSeason) {
        card['sponsor'] = null;
        expired++;
      }
    }

    if (card['injured'] != true) continue;
    final duration = _num(card['injuryDurationMs'])?.toInt() ?? 0;
    final elapsed = now() - (_num(card['injuredAt'])?.toInt() ?? now());
    if (duration - elapsed <= offseasonRecoveryMs) {
      card['injured'] = false;
      card['injuredAt'] = null;
      card['injuryDurationMs'] = null;
      recovered++;
    } else {
      card['injuryDurationMs'] = duration - offseasonRecoveryMs;
      shortened++;
    }
  }

  // Everyone who healed over the break goes back in the running for a starting
  // slot — their injury left one open and nothing else ever fills it.
  if (recovered > 0) refillLineupFromBench(state);

  return (
    injuries: (recovered: recovered, shortened: shortened),
    sponsors: (expired: expired),
  );
}

/// Retire anyone who has reached fifteen seasons.
///
/// Players decline gradually through the ageing penalty — a stat deduction, not
/// a tier change — and then leave the squad entirely. Returns a report so the
/// UI can summarise the year's departures.
List<Map<String, dynamic>> processAgeRegression(Map<String, dynamic> state) {
  final report = <Map<String, dynamic>>[];
  final cells = _cells(state);

  for (var i = 0; i < cells.length; i++) {
    final card = _map(cells[i]);
    if (card == null) continue;
    if ((_num(card['seasonsPlayed'])?.toInt() ?? 0) < 15) continue;

    final oldDef = getPlayerDef(card['definitionId'] as String?);
    cells[i] = null;
    report.add(<String, dynamic>{
      'playerName': getCardName(card, 'Veteran'),
      'fromTier': oldDef?.tier ?? 1,
      'fromTierName': oldDef?.tierName ?? 'Veteran',
      'toTier': 0,
      'toTierName': 'Retired',
      'retired': true,
      'ageingPenalty': 0,
    });
  }

  if (report.isNotEmpty) emit('players:aged', report);
  return report;
}

/// Kept as a no-op for save compatibility — divisions are season-gated through
/// [endSeason]'s promotion, and the trophy-based unlock was removed when the
/// unlock-trophy data was dropped.
void checkDivisionUnlock(Map<String, dynamic>? state) {}

// ── Prestige ────────────────────────────────────────────────────────────────

/// **ADDED per prestige, not COMPOUNDED.** The JS raises 1.1 to the level
/// (`LeagueScreen.js`), which is 117x at fifty prestiges — a curve that stops
/// being a bonus and becomes the whole economy. A flat tenth per adventure is
/// the divergence: two prestiges reads 1.2x, fifty reads 6x.
const double _prestigeIncomeBonus = 0.1;

/// Winning the Champions League unlocks prestige PERMANENTLY for that run — the
/// option stays available even if the club is later relegated.
bool canPrestige(Map<String, dynamic>? state) =>
    _map(state?['progression'])?['wonChampionsCup'] == true;

/// How many adventures this save has already finished. Zero on one that has
/// never prestiged, which is also what an un-migrated save reads as.
int prestigeLevel(Map<String, dynamic>? state) =>
    _num(_map(state?['prestige'])?['level'])?.toInt() ?? 0;

/// **PRO MODE IS EARNED, not a setting you were always allowed.**
///
/// It used to be offered from the first minute. It is a whole second game —
/// player fatigue, squad rotation, live substitutions, a different trait pool,
/// different daily rewards and quests, no auto-pick — and offering all of that
/// to somebody who has not finished the first one is offering a difficulty they
/// have no way to judge.
///
/// **THE GATE IS WINNING THE CHAMPIONS LEAGUE**, which is [canPrestige]'s own
/// condition and one step earlier than what stood here.
///
/// It used to be PRESTIGING ONCE, and the fault in that is not the difficulty
/// of it: nobody knows what prestige is. It is a word this game uses for
/// "conquer the top flight and start again", and a padlock whose only
/// explanation is "Prestige for the first time" answers an unknown control
/// with an unknown word. Asked for in those terms. Winning the Champions
/// League is the same achievement said in the language of the game rather than
/// of its meta-loop, and every player who has prestiged has done it already.
///
/// **`prestigeLevel` stays in the condition, and it is not redundant.** A
/// prestige RESETS `progression`, `wonChampionsCup` with it — so a player on
/// their second adventure would otherwise have the difficulty they earned
/// taken back off them at the reset.
///
/// **A save already IN Pro keeps it.** Anyone who turned it on before the gate
/// existed has been playing it, and taking a difficulty away from a running
/// career is a worse thing than letting one save keep something it earned by
/// being early.
bool proModeUnlocked(Map<String, dynamic>? state) =>
    canPrestige(state) ||
    prestigeLevel(state) > 0 ||
    _map(state?['settings'])?['hardMode'] == true;

/// The permanent income multiplier at [level] — the engine's own arithmetic,
/// exposed rather than restated.
///
/// A screen offering the NEXT adventure has to name the number it will pay, and
/// a card that computed the curve for itself would sooner or later promise a
/// multiplier the reset did not hand over. [performPrestige] reads this too, so
/// there is one sum in the game.
double prestigeMultiplierFor(int level) =>
    1 + _prestigeIncomeBonus * (level < 0 ? 0 : level);

/// What a prestige did.
typedef PrestigeResult = ({
  bool ok,
  int gemsAwarded,
  int level,
  double multiplier,
});

/// Start a new adventure: back to Sunday League, with a permanent income
/// multiplier and everything hard-currency intact.
PrestigeResult performPrestige(Map<String, dynamic> state, {bool toPro = false}) {
  if (!canPrestige(state)) {
    return (ok: false, gemsAwarded: 0, level: 0, multiplier: 1);
  }

  final prestige = _map(state['prestige']);
  final newLevel = (_num(prestige?['level'])?.toInt() ?? 0) + 1;
  final newMultiplier = prestigeMultiplierFor(newLevel);
  final resources = _branch(state, 'resources');
  final totalTrophies =
      (_num(prestige?['totalTrophies'])?.toInt() ?? 0) +
      (_num(resources['trophies'])?.toInt() ?? 0);
  // Accrue-only for now — a future perk tree will spend them.
  final points = (_num(prestige?['points'])?.toInt() ?? 0) + 1;

  final prog = _branch(state, 'progression');
  resources['trophies'] = 0;
  prog['currentDivision'] = 'sunday_league';
  prog['divisionsUnlocked'] = <dynamic>['sunday_league'];
  // Re-gate prestige. Without this the flag set on the first cup win survives
  // every reset, so the option stays permanently unlocked and the player can
  // spam it — inflating the prestige level with zero match activity.
  prog['wonChampionsCup'] = false;
  for (final key in [
    'matchesPlayed',
    'matchesWon',
    'matchesDrawn',
    'seasonMatchesPlayed',
    'seasonWins',
    'seasonDraws',
    'seasonLosses',
    'lastMatchAt',
  ]) {
    prog[key] = 0;
  }
  prog['seasonComplete'] = false;

  _branch(state, 'grid')['cells'] = List<dynamic>.filled(
    Grid.totalCells,
    null,
    growable: true,
  );
  state['clubAssets'] = defaultClubAssets();
  final squad = _map(state['squad']);
  if (squad != null) squad['bench'] = <dynamic>[];

  // `resources` is mutated in place rather than replaced, which is what carries
  // GEMS through — they are hard currency and must survive prestige exactly as
  // they survive a New Team. Rebuilding this object would silently wipe them.
  resources['fanCoins'] = (startingCoins * newMultiplier).round();
  state['prestige'] = <String, dynamic>{
    'level': newLevel,
    'incomeMultiplier': newMultiplier,
    'totalTrophies': totalTrophies,
    'points': points,
  };

  // Gems and the lifetime ledger are untouched — real money bought them, or a
  // milestone that only happens once did. Only the per-run title flag clears,
  // so the new adventure can win its own Champions League.
  final grants = _map(state['gemGrants']);
  if (grants != null) grants['chlTitleThisRun'] = false;
  final gemsAwarded = grantPrestigeGems(state);

  // VIP was bought against the pre-prestige level; now that we have advanced,
  // clear it so the next purchase is required.
  final boosts = _map(state['boosts']);
  if (boosts?['vipActive'] == true && boosts?['vipPrestigeLevel'] != null) {
    boosts!['vipActive'] = false;
    boosts['vipPrestigeLevel'] = null;
    boosts['vipExpiresAt'] = 0;
    final shop = _map(state['shop']);
    if (shop != null) {
      shop['vipPrestigeLevel'] = null;
      shop['vipExpiresAt'] = 0;
    }
  }

  // A new adventure starts back in Sunday League, where every draw is the
  // bronze the old career's rules were set to bin.
  clearTierActions(state);

  // Manager cosmetics, on the same terms as a New Team reset: every route to a
  // look pack sits outside the run's economy, so none of them is undone by
  // resetting the coin balance above.
  //
  // Must run AFTER the club assets are rebuilt: the sanitiser reads the live
  // Fan Zone tier, and the point is to measure the face against the fresh club
  // rather than the one that just ended.
  final club = _map(state['club']);
  if (club != null) {
    club['lookPacks'] = persistentLookPacks(state);
    club['lookItems'] = persistentLookItems(state);
    if (club['managerAvatar'] != null) {
      club['managerAvatar'] = sanitizeAvatar(state, club['managerAvatar']);
    }
  }

  prog['leaguePyramid'] = null;
  prog['seasonOpponents'] = <dynamic>[];
  // A fresh adventure has no previous season, and the old run's promotions
  // would otherwise badge clubs in a pyramid that no longer exists.
  prog['lastSeasonStatus'] = null;
  // Restarting the counter at one means every season number in the new run is
  // one the finished run already played, so anything keyed by season has to go
  // with it — otherwise the new run reads the old one's records as its own.
  prog['seasonOpponentRatings'] = <String, dynamic>{};
  prog['seasonFixtures'] = null;
  prog['seasonCount'] = 1;
  prog['fixtureResults'] = <String, dynamic>{};
  prog['seasonAwardedPlayed'] = 0;
  prog['opponentTablePositions'] = <String, dynamic>{};
  prog['lastMatchResult'] = null;

  final cups = _map(prog['cups']);
  if (cups != null) {
    cups['active'] = null;
    // Cup wins the old run lifted are kept where they belong — the career stats
    // and the cosmetics ledger, neither of which prestige touches. This list is
    // the per-run slate: which cups THIS adventure has entered.
    cups['history'] = <dynamic>[];
  }
  // A new run may enter its division's cup, same as a new season may.
  refreshCupAvailability(state);
  prog['leagueTrophies'] = <dynamic>[];
  // Allow the achievements to be re-unlocked in the new run.
  prog['achievementIdsThisRun'] = <dynamic>[];
  // A new pyramid is a fresh start everywhere.
  prog['stagnationBuffs'] = <String, dynamic>{};

  state['definitionRatios'] = generateDefinitionRatios();

  // **AND THE NEW ADVENTURE GETS A SEASON TO PLAY, which it did not.**
  // Everything above tears the old run's league down — the pyramid, the
  // schedule, the opponents and their ratings — and nothing built it back. The
  // only other place that does is `game_runner.dart` at BOOT, so a fresh
  // adventure was unplayable until the app was restarted: the fixture preview
  // fell through to its literal "Opponent", there was no stored rating to print
  // so the scoreline read "?", the fixtures list waited for a schedule that was
  // never generated, and the table drew teams with an empty rating column.
  // Reported from the couch, all four at once, immediately after prestiging.
  //
  // LAST, so everything it reads is already final — the division is
  // `sunday_league`, `seasonCount` is back to 1 (which is what the rating keys
  // are stamped with) and the pyramid is null, which is how
  // `ensureLeaguePyramid` knows to build a new one.
  //
  // **`endSeason` has always done exactly this**, on the line after it nulls
  // the schedule — see `_resetSeasonCounters`. This is the same line at the
  // other season boundary, and the JS is missing it in the same place, so the
  // prestige fixture pins `leaguePyramid: null`; `season_end_test.dart` states
  // that divergence rather than dropping the key from the comparison.
  initSeasonOpponents(state);

  emit('prestige:complete', {
    'level': newLevel,
    'multiplier': newMultiplier,
    // **Analytics only, and it rides the event rather than being read off the
    // save.** The caller writes `settings.hardMode` AFTER this returns — see
    // the ordering note in `ui/popups/prestige_card.dart` — so a listener
    // asking the save would always get the pre-switch answer and the whole
    // `difficulty_switch` funnel would read as nobody ever choosing Pro.
    'toPro': toPro,
    // The season the new adventure starts in — always one, and carried anyway
    // so the line that announces it reads the event rather than reaching back
    // into a save the reset has just rewritten.
    'season': _num(prog['seasonCount'])?.toInt() ?? 1,
  });

  return (
    ok: true,
    gemsAwarded: gemsAwarded,
    level: newLevel,
    multiplier: newMultiplier,
  );
}

/// What a season came to, before [endSeason] settles it and rolls the counters
/// on — the numbers the season-overview page is made of.
///
/// **`endSeason` is what makes these unavailable afterwards**, which is why
/// this is read first and carried: it resets `seasonWins`, `seasonDraws` and
/// `seasonLosses` for the new campaign as part of its work, and the summary is
/// about the season that just finished.
typedef SeasonRecord = ({
  int wins,
  int draws,
  int losses,
  int goalsFor,
  int goalsAgainst,
});

/// Read the finished season's record off the save.
///
/// The goals come out of `fixtureResults`, keyed `s{season}_m{n}`, where
/// `homeGoals` is always OURS whatever the venue was — the match engine's own
/// convention, and the same one `league_table.dart` has to undo when it is
/// working out somebody else's result.
SeasonRecord seasonRecordOf(Map<String, dynamic> state) {
  final prog = _map(state['progression']) ?? const {};
  final season = _num(prog['seasonCount'])?.toInt() ?? 1;
  final results = _map(prog['fixtureResults']) ?? const {};
  var goalsFor = 0;
  var goalsAgainst = 0;
  for (var m = 0; m < matchesPerSeason; m++) {
    final row = results['s${season}_m$m'];
    if (row is! Map<String, dynamic>) continue;
    goalsFor += _num(row['homeGoals'])?.toInt() ?? 0;
    goalsAgainst += _num(row['awayGoals'])?.toInt() ?? 0;
  }
  return (
    wins: _num(prog['seasonWins'])?.toInt() ?? 0,
    draws: _num(prog['seasonDraws'])?.toInt() ?? 0,
    losses: _num(prog['seasonLosses'])?.toInt() ?? 0,
    goalsFor: goalsFor,
    goalsAgainst: goalsAgainst,
  );
}

/// Points, the way a table counts them.
int seasonPoints(SeasonRecord record) => record.wins * 3 + record.draws;
