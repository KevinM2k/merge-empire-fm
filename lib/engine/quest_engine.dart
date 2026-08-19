/// Rolling, resolving and paying out both quest tracks. Ported from
/// `../merge-empire-fc/src/engine/questEngine.js`.
///
/// The two tracks do NOT share a resolution model, and conflating them is the
/// easiest way to break this file:
///
///   MATCH quests are EVALUATED. [resolveMatchQuests] runs once at full time,
///   reads the result, and decides pass or fail for all three. There is no
///   partial progress — a match quest is not "two thirds of a clean sheet".
///
///   SEASON quests are ACCUMULATED. [advanceQuest] ticks counters from the
///   action call sites across the whole campaign, and [setStreakProgress]
///   handles the streaks, whose progress can go DOWN.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/quests.dart';
import 'package:merge_empire_fc/engine/fixture_preview.dart';
import 'package:merge_empire_fc/engine/gem_engine.dart';
import 'package:merge_empire_fc/engine/goal_model.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/scout_engine.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

/// One gem per division, once ever. Seven divisions, so seven gems, lifetime.
const int capstoneGems = 1;

/// Rerolling is SEASON-ONLY, and costs a gem once the season's free rerolls are
/// spent.
///
/// Match quests are deliberately not rerollable: they are replaced free with
/// every fixture, so the reroll already exists — it is called playing the next
/// match, and charging for it would sell something the player gets anyway. A
/// season quest is the one you can actually be stuck with, for fourteen games.
///
/// The gem price is a SINK, which is the safe direction: it takes hard currency
/// out rather than minting it, so it cannot undermine the lifetime ceiling the
/// capstone enforces. A single reroll and a reroll-all cost the same — everyone
/// will reroll the lot, which is fine and deliberate; pricing per quest just
/// taxes people for reading carefully first.
const int rerollGemCost = 1;

/// TWO free rerolls, not one, and the reason is the capstone.
///
/// That pays one gem per division, once ever, and a division is settled in a
/// single season — so with one free reroll a player who drew badly twice paid
/// the ENTIRE prize for the right to earn it. Sink and faucet were the same
/// currency at the same size. Two covers the ordinary "bad draw, still bad"
/// case and leaves the gem price for the third, where it is a convenience
/// purchase rather than a tax on bad luck.
const int freeRerollsPerSeason = 2;

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

/// Rebuild the season tally for a save that predates it, from the fixture
/// results this season has already written.
///
/// Only what the results actually record can come back — goals, clean sheets,
/// wins and away wins. A comeback or a hat-trick isn't in there, and merges and
/// scouts are only kept as lifetime totals, so those start at zero on an
/// upgraded save and are right again from the next season. Recovering four of
/// them is worth it because it is what makes a reroll fair for the season the
/// player is in the middle of RIGHT NOW, rather than the one after.
Map<String, dynamic> _backfillSeasonTally(Map<String, dynamic>? state) {
  final tally = <String, dynamic>{};
  final prog = _map(state?['progression']);
  if (prog == null) return tally;

  final season = _num(prog['seasonCount'])?.toInt() ?? 1;
  final played = _num(prog['seasonMatchesPlayed'])?.toInt() ?? 0;
  final results = _map(prog['fixtureResults']) ?? const {};

  var goals = 0;
  var cleanSheets = 0;
  var wins = 0;
  var awayWins = 0;

  // The same bound the fixtureResults repair in the save migration uses: keys
  // are season-scoped but not RUN-scoped, so a prestige can leave a previous
  // run's results sitting above the mark. Slots below it are this season's.
  for (var m = 0; m < played; m++) {
    final fr = _map(results['s${season}_m$m']);
    if (fr == null) continue;
    goals += _num(fr['homeGoals'])?.toInt() ?? 0;
    if ((_num(fr['awayGoals'])?.toInt() ?? 0) == 0) cleanSheets++;
    if (fr['won'] == true) {
      wins++;
      if (fr['isHome'] == false) awayWins++;
    }
  }

  if (goals > 0) tally[QuestAction.goalsSeason] = goals;
  if (cleanSheets > 0) tally[QuestAction.cleanSheetsSeason] = cleanSheets;
  if (wins > 0) tally[QuestAction.matchWin] = wins;
  if (awayWins > 0) tally[QuestAction.awayWins] = awayWins;
  return tally;
}

/// Make sure the quests branch exists and is shaped correctly.
///
/// Old saves and hand-built test states both come through here, so every read
/// below can assume the fields are present.
Map<String, dynamic> ensureQuests(Map<String, dynamic> state) {
  final q = _branch(state, 'quests');

  final match = _branch(q, 'match');
  if (!match.containsKey('fixtureKey')) match['fixtureKey'] = null;
  _list(match, 'active');

  // Free season rerolls used so far, refreshed each season. A save written
  // before the allowance went from one to two carries a BOOLEAN here; convert
  // rather than reset, or a player mid-season would be handed back a free
  // reroll they had already spent.
  final legacy = q['seasonFreeRerollUsed'];
  if (legacy is bool) {
    q['seasonFreeRerollsUsed'] = legacy ? 1 : 0;
    q.remove('seasonFreeRerollUsed');
  }
  final used = _num(q['seasonFreeRerollsUsed']);
  if (used == null || used < 0) q['seasonFreeRerollsUsed'] = 0;

  _list(q, 'season');
  _list(q, 'recent');
  if (_num(q['lastRolledSeason']) == null) q['lastRolledSeason'] = 0;
  if (_map(q['streaks']) == null) {
    q['streaks'] = <String, dynamic>{
      'cleanSheet': 0,
      'win': 0,
      'unbeaten': 0,
      'scoring': 0,
    };
  }

  // Everything this SEASON has done, whether or not a quest was watching at the
  // time — the record a quest rolled mid-season starts from. Absent means a save
  // written before it existed, which gets what the fixture list can prove
  // rather than a zeroed season.
  if (_map(q['seasonTally']) == null) {
    q['seasonTally'] = _backfillSeasonTally(state);
  }
  // Where each DELTA-measuring derived quest stood at kick-off. Empty on an old
  // save, which falls back to reading the value at roll time — the behaviour
  // that shipped, and self-correcting from the next season boundary.
  if (_map(q['seasonBaselines']) == null) {
    q['seasonBaselines'] = <String, dynamic>{};
  }

  _list(_branch(state, 'gemGrants'), 'questDivisionFirsts');

  // Drop quests whose definition no longer exists. The bank is data and it
  // changes between releases; a save holding a retired id used to render a row
  // with no text, no reward and a fallback icon, because every accessor quietly
  // produced nothing. Better to lose the row than to show a broken one — and
  // the roll functions top the track back up.
  bool known(Object? c) => getQuest(_map(c)?['id'] as String?) != null;
  final season = _list(q, 'season');
  if (season.any((c) => !known(c))) {
    q['season'] = season.where(known).toList();
  }
  final active = _list(match, 'active');
  if (active.any((c) => !known(c))) {
    match['active'] = active.where(known).toList();
  }

  return q;
}

List<Map<String, dynamic>> _seasonTrack(Map<String, dynamic> state) => [
  for (final c in _list(ensureQuests(state), 'season'))
    if (c is Map<String, dynamic>) c,
];

List<Map<String, dynamic>> _matchTrack(Map<String, dynamic> state) => [
  for (final c in _list(_branch(ensureQuests(state), 'match'), 'active'))
    if (c is Map<String, dynamic>) c,
];

int _currentDivIdx(Map<String, dynamic>? state) {
  final idx = divisionIndex(
    _map(state?['progression'])?['currentDivision'] as String?,
  );
  return idx < 0 ? 0 : idx;
}

// ── Rolling ─────────────────────────────────────────────────────────────────

/// Every quest of [scope] available at the player's current division.
///
/// Pro mode drops the coach quest — there are no tactic suggestions there, so
/// it would be undefeatable rather than merely hard.
List<QuestDef> eligibleQuests(Map<String, dynamic>? state, String scope) {
  final divIdx = _currentDivIdx(state);
  final hardMode = _map(state?['settings'])?['hardMode'] == true;
  return [
    for (final q in questBank)
      if (q.scope == scope &&
          isEligible(q, divIdx) &&
          !(hardMode && q.action == QuestAction.defyCoach))
        q,
  ];
}

/// What the roll knows about the situation, plus the two fields only the roll
/// itself reads.
typedef RollContext = ({QuestContext quest, int divIdx, int matchesLeft});

/// Everything a quest's feasibility check is allowed to look at: the upcoming
/// fixture, the squad that will play it, and the couple of save-wide facts a
/// season quest can be blocked by.
///
/// Built once per roll rather than per quest — the fixture preview recomputes
/// the whole squad rating, and none of this changes between three draws. The
/// fixture is only read for the MATCH scope: a season quest can't depend on one
/// fixture, and the preview isn't free.
RollContext questContext(
  Map<String, dynamic>? state, [
  String scope = 'match',
]) {
  FixturePreview? fixture;
  if (scope == 'match') {
    try {
      fixture = previewFixture(state);
    } catch (_) {
      fixture = null;
    }
  }

  final cells = _map(state?['grid'])?['cells'];
  final cards = <Map<String, dynamic>>[
    if (cells is List)
      for (final c in cells)
        if (c is Map<String, dynamic>) c,
  ];
  final fit = [
    for (final c in cards)
      if (c['injured'] != true) c,
  ];

  final rawLineup = _map(state?['squad'])?['lineup'];
  final lineupIds = <String>{
    if (rawLineup is List)
      for (final s in rawLineup)
        if (_map(s)?['cardInstanceId'] case final String id) id,
  };

  // No XI set means the sim draws its scorers from the whole squad, so "is
  // there a defender on the pitch" is really "is there a defender at all".
  final onPitch = lineupIds.isNotEmpty
      ? [
          for (final c in fit)
            if (lineupIds.contains(c['instanceId'])) c,
        ]
      : fit;
  String? positionOf(Map<String, dynamic> c) =>
      getPlayerDef(c['definitionId'] as String?)?.position;

  // League fixtures still to play. A season quest rolled at match 10 has four
  // matches to be won in, not fourteen. A cup tie advances season quests without
  // moving the counter, so this can only ever UNDERSTATE what is left — the safe
  // direction for a feasibility check.
  final matchesLeft = math.max(
    0,
    matchesPerSeason -
        (_num(_map(state?['progression'])?['seasonMatchesPlayed'])?.toInt() ??
            0),
  );

  // Faces left to meet WITHOUT being promoted. Each definition has two variants
  // and both are recorded separately, so the index is finite and a long save
  // fills it — but the whole index is not the target. A division reaches a slice
  // of it, and measuring against every face is what handed "discover 4 new
  // players" to a Sunday League save that had met all the faces it can produce.
  final met = <String>{
    if (_map(state?['progression'])?['discoveredPlayers']
        case final List<dynamic> d)
      for (final id in d) '$id',
  };
  var undiscovered = 0;
  for (final id in reachablePlayerDefIds(state)) {
    if (!met.contains('$id:m')) undiscovered++;
    if (!met.contains('$id:f')) undiscovered++;
  }

  // Which mini-games the player can actually open. All but Penalty Training are
  // locked behind Training facility tiers, so an arcade quest has to ask before
  // it is handed out.
  List<String> minigames;
  try {
    minigames = getUnlockedMinigames(_map(state?['clubAssets']));
  } catch (_) {
    minigames = const [];
  }

  return (
    divIdx: _currentDivIdx(state),
    matchesLeft: matchesLeft,
    quest: (
      isHome: fixture?.isHome,
      ourRating: fixture?.effectiveSquadRating ?? 0,
      oppRating: fixture?.effectiveOppRating,
      ourDefence: fixture?.ourDefenceRating ?? 0,
      oppAttack: fixture?.effOppAttackRating,
      fitCount: onPitch.length,
      // Fit players who aren't in the XI — the bench a substitution comes from.
      // With no lineup set there is no bench either: the sim fields the squad.
      benchCount: lineupIds.isEmpty
          ? 0
          : fit.where((c) => !lineupIds.contains(c['instanceId'])).length,
      defInLineup: onPitch.any((c) => positionOf(c) == 'DEF'),
      midInLineup: onPitch.any((c) => positionOf(c) == 'MID'),
      // Squad-wide, not lineup: the whole point of the quest is that you go and
      // field the keeper somewhere he can shoot.
      hasGK: fit.any((c) => positionOf(c) == 'GK'),
      oldestSeasons: fit.fold<int>(
        0,
        (m, c) => math.max(m, _num(c['seasonsPlayed'])?.toInt() ?? 0),
      ),
      undiscovered: undiscovered,
      minigames: minigames,
    ),
  );
}

/// The current value of a derived quest's own reader. Zero for anything that
/// throws.
num _derivedValue(QuestDef def, Map<String, dynamic>? state) {
  final reader = def.progress;
  if (reader == null) return 0;
  try {
    return reader(state);
  } catch (_) {
    return 0;
  }
}

/// The target THIS instance gets, which is not always the division's number.
///
/// A `lift` quest asks for a LEVEL the club is climbing, so a fixed division
/// target is wrong the moment the player is already past it — owning tier 3 and
/// being asked to reach tier 3 is a quest that was finished before it was
/// handed out. Lifting floors the ask at one above what they hold, up to the
/// `lift` value itself, which is the ceiling the level can reach. At the
/// ceiling nothing can be asked, and the already-satisfied check drops it.
///
/// This is NOT what `baseline` does. A baseline SUBTRACTS the starting value,
/// which is right for a counter ("scout ten more") and nonsense for a level —
/// a target of 3 against a tier-3 club would read as "climb three more tiers".
int questTarget(QuestDef def, Map<String, dynamic>? state, int divIdx) {
  final base = resolveTarget(def, divIdx);
  final lift = def.lift;
  if (def.progress == null || lift == null) return base;
  return math.max(base, math.min(lift, _derivedValue(def, state).toInt() + 1));
}

/// Where a DELTA-measuring derived quest counted from: the value its reader had
/// at kick-off of the season, not at the moment it was drawn.
///
/// That distinction is the whole point of the snapshot. Measuring from the draw
/// is right for a quest rolled AT the season boundary and wrong for one rolled
/// at match 10, which would ask a player who has already scouted thirty this
/// season to go and scout ten more in the four games left.
num _seasonBaselineFor(QuestDef def, Map<String, dynamic> state) {
  final q = ensureQuests(state);
  final snapped = _num(_map(q['seasonBaselines'])?[def.id]);
  return snapped ?? _derivedValue(def, state);
}

/// Read every delta-measuring derived quest in the bank, for the season about
/// to start.
///
/// The WHOLE bank, not just the three drawn: the point of the snapshot is to be
/// there for a quest rolled later in the season, which by definition isn't on
/// the track yet. Cheap enough to do unconditionally.
Map<String, dynamic> _snapshotSeasonBaselines(Map<String, dynamic> state) => {
  for (final def in questBank)
    if (def.scope == 'season' && def.progress != null && def.baseline)
      def.id: _derivedValue(def, state),
};

/// How far into this quest the season has ALREADY come, for a season quest
/// being handed out mid-campaign.
///
/// Rolling one at match 10 used to hand over a fourteen-match objective with
/// four matches to do it in — "score 50 goals" from zero, with the 34 already
/// scored counting for nothing. So the track no longer starts a quest from
/// zero: it starts from what the season has actually done, recorded whether or
/// not a quest was watching at the time.
///
/// The reading depends on what kind of counter it is, and getting that wrong is
/// how this turns into nonsense:
///   • a STREAK is a current run, not a total — five wins in a row is five in a
///     ROW, so it reads the live run and not the season's wins;
///   • a MAX action is a level already reached, and the tally holds the highest
///     seen rather than a sum;
///   • a DERIVED quest has no tally at all — it reads the save itself, and its
///     season-start baseline is what makes it a delta;
///   • everything else is a plain season total.
///
/// Match quests never come through here. They are rolled fresh for one fixture
/// and evaluated against that fixture alone, so there is nothing to carry in.
num seasonProgressSoFar(QuestDef? def, Map<String, dynamic> state) {
  if (def == null || def.scope != 'season') return 0;
  final q = ensureQuests(state);

  if (def.progress != null) {
    if (!def.baseline) return _derivedValue(def, state);
    return math.max(
      0,
      _derivedValue(def, state) - _seasonBaselineFor(def, state),
    );
  }

  final streakKey = streakStateKey[def.action];
  if (streakKey != null) {
    return math.max(0, _num(_map(q['streaks'])?[streakKey]) ?? 0);
  }

  return math.max(0, _num(_map(q['seasonTally'])?[def.action]) ?? 0);
}

/// Would this quest be complete the instant it was handed out?
///
/// Two ways that happens. A DERIVED quest reads a fact off the save (a full XI,
/// an owned facility), so an established club satisfies plenty of them before
/// ever being asked. And any season quest rolled MID-season starts from what the
/// season has already done, so a good campaign can have cleared the ask before
/// the quest appears.
///
/// Neither is handed out. A quest that is already finished isn't a quest, it is
/// a payout — and on the reroll path the player has just spent a gem on it.
bool _alreadySatisfied(QuestDef def, Map<String, dynamic> state, int divIdx) {
  // A match quest is evaluated against one fixture that hasn't been played, so
  // there is nothing it can arrive already holding.
  if (def.scope != 'season') return false;
  return seasonProgressSoFar(def, state) >= questTarget(def, state, divIdx);
}

/// Can a season quest still be FINISHED in the fixtures that are left?
///
/// The seeded start makes a mid-season roll fair; this makes it possible.
/// They are different failures: seeding fixes "your 34 goals count for
/// nothing", and this fixes "six more wins, four to play" — which isn't a hard
/// quest, it is an arithmetic impossibility.
///
/// Only actions paced by the fixture list can be judged this way. Merges and
/// scouts are bounded by cards and energy, so the games left says nothing about
/// them and they are never blocked here.
///
/// For the once-per-match actions the bound is exact: N more wins needs N more
/// matches, and a run of N needs N of them in a row. Goals are the exception —
/// the sampler is Poisson and has no hard ceiling on a single scoreline — so
/// they are measured against the fastest rate the simulation can be made to run
/// at. Needing more than that every remaining match isn't a challenge, it is a
/// quest that finishes the season unfinished.
bool fitsInSeason(QuestDef? def, num target, num soFar, int? matchesLeft) {
  if (def == null || def.scope != 'season') return true;
  if (!matchPacedActions.contains(def.action)) return true;
  if (matchesLeft == null) return true;
  final remaining = target - soFar;
  if (remaining <= 0) return true;
  return perMatchActions.contains(def.action)
      ? remaining <= matchesLeft
      : remaining <= maxGoalRate * matchesLeft;
}

/// Can this quest be WON in the fixture that's coming up?
///
/// A quest with no check always can. Anything that throws is treated as
/// infeasible: a predicate that can't be evaluated is not a licence to hand out
/// a quest that might be impossible.
bool _isFeasible(QuestDef def, QuestContext ctx, int target) {
  final check = def.feasible;
  if (check == null) return true;
  try {
    return check(ctx, target);
  } catch (_) {
    return false;
  }
}

/// The quests that may actually be HANDED OUT right now: eligible for the
/// division, not already satisfied by the save, still finishable in the
/// season's remaining fixtures, and — for match quests — actually winnable in
/// the fixture about to be played.
///
/// Every roll path draws from this rather than [eligibleQuests], so "switch it
/// for another one" is the default behaviour and not something each caller has
/// to remember. [ctx] is optional so a caller drawing several times can build
/// the fixture context once instead of per draw.
List<QuestDef> rollableQuests(
  Map<String, dynamic> state,
  String scope, [
  RollContext? ctx,
]) {
  final divIdx = _currentDivIdx(state);
  final rollCtx = ctx ?? questContext(state, scope);
  return [
    for (final def in eligibleQuests(state, scope))
      if (!_alreadySatisfied(def, state, divIdx) &&
          _isFeasible(def, rollCtx.quest, resolveTarget(def, divIdx)) &&
          fitsInSeason(
            def,
            questTarget(def, state, divIdx),
            seasonProgressSoFar(def, state),
            rollCtx.matchesLeft,
          ))
        def,
  ];
}

/// A fresh quest instance for the track. The one place an instance is shaped.
Map<String, dynamic> _makeInstance(
  QuestDef def,
  Map<String, dynamic> state,
  int divIdx,
) {
  final target = questTarget(def, state, divIdx);
  final soFar = math.min(seasonProgressSoFar(def, state), target);
  return <String, dynamic>{
    'id': def.id,
    'target': target,
    'progress': soFar,
    'completed': soFar >= target,
    'claimedAt': null,
    // A derived quest measuring a DELTA counts from where its reader stood at
    // the START OF THE SEASON. Without a baseline at all, "scout 10 players"
    // read against a lifetime total would be complete the moment it appeared;
    // from the moment it ROLLED, a quest drawn at match 10 would ignore
    // everything the season had already done.
    'baseline': def.progress != null && def.baseline
        ? _seasonBaselineFor(def, state)
        : 0,
  };
}

/// Draw [count] distinct quests of [scope], avoiding anything in the no-repeat
/// window.
///
/// If the eligible pool is too small to honour the window, the window is
/// progressively relaxed rather than returning a short list — an early division
/// has few quests and would otherwise starve.
List<Map<String, dynamic>> rollQuests(
  Map<String, dynamic> state,
  String scope,
  int count, [
  List<String> exclude = const [],
]) {
  final q = ensureQuests(state);
  final divIdx = _currentDivIdx(state);
  final excluded = exclude.toSet();
  final ctx = questContext(state, scope);
  final pool = [
    for (final def in rollableQuests(state, scope, ctx))
      if (!excluded.contains(def.id)) def,
  ];
  if (pool.isEmpty) return [];

  final recentIds = [for (final r in _list(q, 'recent')) '$r'];
  var blocked = recentIds.toSet();
  var candidates = [
    for (final def in pool)
      if (!blocked.contains(def.id)) def,
  ];
  // Relax the window until there is enough to fill the slots, or we have
  // dropped it entirely and just take what the pool has.
  if (candidates.length < count) {
    // The JS feeds `max(0, pool.length - count)` to `slice(-n)`, where
    // `slice(-0)` returns the WHOLE array rather than none of it. Both branches
    // fall through to taking the entire pool a line later, so the quirk changes
    // nothing — this says what it means instead.
    final keep = math.max(0, pool.length - count);
    blocked = recentIds.sublist(math.max(0, recentIds.length - keep)).toSet();
    candidates = [
      for (final def in pool)
        if (!blocked.contains(def.id)) def,
    ];
    if (candidates.length < count) candidates = [...pool];
  }

  // One ask per roll: never two quests from the same FAMILY, where a family is
  // an action plus its tags. The action half stops variants of one quest
  // meeting ("score 3" and "score 5" are sized for different divisions). The
  // tag half stops different actions that amount to the same ask.
  //
  // Seeded from `exclude`, which is the caller's way of saying "these are
  // staying on the track" — the top-up paths pass the survivors. It must NOT
  // read the live track directly: on a full redraw that track is about to be
  // thrown away, and banning its families shrinks the choice for no reason at
  // exactly the divisions that can least afford it.
  final usedTags = <String>{
    for (final id in excluded) ...questTags(getQuest(id)),
  };
  final picked = <QuestDef>[];

  void take(List<QuestDef> list) {
    for (final def in list) {
      if (picked.length >= count) break;
      final tags = questTags(def);
      if (picked.contains(def) || tags.any(usedTags.contains)) continue;
      usedTags.addAll(tags);
      picked.add(def);
    }
  }

  take(seeded.shuffle([...candidates]));
  // One ask per roll OUTRANKS the no-repeat window. A quest the player saw two
  // fixtures ago is invisible; two "score N goals" side by side is not. So when
  // the window-filtered candidates can't fill the slots with distinct families,
  // reopen the whole pool before even considering a repeat. (Sunday League is
  // the case that forced this: nine eligible match quests, eight distinct
  // actions, a window of eight — the window alone could starve the roll into a
  // duplicate.)
  if (picked.length < count) take(seeded.shuffle([...pool]));
  // Last resort: the pool genuinely hasn't the distinct actions to fill it.
  for (final def in seeded.shuffle([...pool])) {
    if (picked.length >= count) break;
    if (!picked.contains(def)) picked.add(def);
  }

  final seen = [...recentIds, for (final d in picked) d.id];
  q['recent'] = seen.sublist(math.max(0, seen.length - noRepeatWindow));

  return [for (final def in picked) _makeInstance(def, state, divIdx)];
}

/// Roll the match track.
///
/// [fixtureKey] identifies the upcoming match, so a re-render or a screen
/// remount reuses the same three quests instead of silently redrawing them
/// under the player.
List<Map<String, dynamic>> rollMatchQuests(
  Map<String, dynamic> state,
  String? fixtureKey,
) {
  final q = ensureQuests(state);
  final match = _branch(q, 'match');
  final active = _list(match, 'active');

  if (match['fixtureKey'] == fixtureKey && active.length >= matchQuestCount) {
    return _matchTrack(state);
  }
  // Same fixture, short track: a retired quest was pruned out from under it.
  // Top up rather than redrawing the set the player has already read.
  if (match['fixtureKey'] == fixtureKey && active.isNotEmpty) {
    active.addAll(
      rollQuests(state, 'match', matchQuestCount - active.length, [
        for (final c in _matchTrack(state)) '${c['id']}',
      ]),
    );
    return _matchTrack(state);
  }

  match['fixtureKey'] = fixtureKey;
  match['active'] = rollQuests(state, 'match', matchQuestCount);
  emit('quests:rolled', {'scope': 'match', 'quests': match['active']});
  return _matchTrack(state);
}

/// The key that identifies the match a player is about to play.
///
/// The same shape `simulateMatch` stamps on its result (`s1_m0`), because that is
/// what pins a match track to a fixture: a re-render, a tab switch or a screen
/// reopening must not redraw quests the player has already read, and a match
/// being PLAYED must move them on.
String nextFixtureKey(Map<String, dynamic>? state) {
  final prog = _map(state?['progression']);
  final season = _num(prog?['seasonCount'])?.toInt() ?? 1;
  final played = _num(prog?['seasonMatchesPlayed'])?.toInt() ?? 0;
  return 's${season}_m$played';
}

/// Whether [ensureMatchQuests] would actually change anything.
///
/// **A guard, not a nicety.** `ensureMatchQuests` is idempotent but every call
/// still goes through `update`, and `update` queues a save — so a screen that
/// asks on every build debounce-saves the whole game for no change at all. The
/// JS carries the same guard, in the same words: "Only go through updateState
/// when a roll is actually needed."
///
/// `< matchQuestCount`, not `== 0`: a quest retired from the bank is pruned out
/// of the active track by [ensureQuests], and a track of two would otherwise sit
/// short for the whole fixture because this never asked for a top-up.
bool matchQuestsNeedRoll(Map<String, dynamic>? state) {
  if (state == null) return false;
  final match = _map(ensureQuests(state)['match']);
  final active = match?['active'];
  final count = active is List ? active.length : 0;
  return match?['fixtureKey'] != nextFixtureKey(state) ||
      count < matchQuestCount;
}

/// Make sure a track exists for the next match, rolling one only if needed.
///
/// **The port had no caller for [rollMatchQuests] at all**, so the match track
/// was empty for every match ever played: three quests per fixture, each with a
/// payout, none of which could be drawn, shown or won. Called from the places
/// that either SHOW the track or consume it, and idempotent so all of them can.
List<Map<String, dynamic>> ensureMatchQuests(Map<String, dynamic> state) =>
    rollMatchQuests(state, nextFixtureKey(state));

/// Roll the season track.
///
/// Called at a season boundary; [seasonCount] guards against re-rolling
/// mid-season, which would wipe accumulated progress.
List<Map<String, dynamic>> rollSeasonQuests(
  Map<String, dynamic> state, [
  int? seasonCount,
]) {
  final q = ensureQuests(state);
  final season =
      seasonCount ??
      _num(_map(state['progression'])?['seasonCount'])?.toInt() ??
      1;
  final track = _list(q, 'season');

  if (q['lastRolledSeason'] == season && track.length >= seasonQuestCount) {
    return _seasonTrack(state);
  }
  // Mid-season top-up after a prune — never a full redraw, which would wipe
  // progress on the quests that are still perfectly valid.
  if (q['lastRolledSeason'] == season && track.isNotEmpty) {
    track.addAll(
      rollQuests(state, 'season', seasonQuestCount - track.length, [
        for (final c in _seasonTrack(state)) '${c['id']}',
      ]),
    );
    refreshDerivedQuests(state);
    return _seasonTrack(state);
  }

  // Safety net for any path that rolls a new season without sweeping first.
  // Idempotent — the season end has normally already done this. No capstone
  // check here: by this point the current division may already be the one we
  // were just promoted INTO, and crediting it a gem for quests played elsewhere
  // is exactly the bug that split exists to prevent.
  sweepUnclaimedSeasonQuests(state);
  q['lastRolledSeason'] = season;
  q['seasonFreeRerollsUsed'] = 0;
  // The season's record starts empty, and every roll below reads it — so it has
  // to be cleared BEFORE the draw, or the new campaign's quests would arrive
  // pre-loaded with the last one's goals. Same for the streaks: a run doesn't
  // carry over a summer.
  q['seasonTally'] = <String, dynamic>{};
  q['streaks'] = <String, dynamic>{
    'cleanSheet': 0,
    'win': 0,
    'unbeaten': 0,
    'scoring': 0,
  };
  q['seasonBaselines'] = _snapshotSeasonBaselines(state);
  q['season'] = rollQuests(state, 'season', seasonQuestCount);
  emit('quests:rolled', {'scope': 'season', 'quests': q['season']});
  return _seasonTrack(state);
}

// ── Rewards ─────────────────────────────────────────────────────────────────

/// Scale a quest's coin reward to the player's division.
///
/// The bank's number is a PERCENTAGE OF ONE LEAGUE WIN — a win pays exactly
/// `matchRevenueBase`, so 25 means a quarter of a win at every division. Never
/// a literal amount: the base spans 100 to 120,000, so a fixed number is
/// worthless at the top and breaks the economy at the bottom.
int questRewardCoins(Map<String, dynamic>? state, num? coinsMultiplier) {
  if (coinsMultiplier == null || coinsMultiplier == 0) return 0;
  final base = getDivision(
    '${_map(state?['progression'])?['currentDivision']}',
  ).matchRevenueBase;
  return math.max(1, (coinsMultiplier * base / 100).round());
}

/// What a quest actually paid.
typedef QuestGrant = ({int coins});

/// Apply a quest reward. Coins are the only thing quests pay, and the two
/// omissions are deliberate: energy is monetised, so granting it gives away
/// what the shop charges for; and a scout voucher is priced in gems, so every
/// one handed out would leak past the lifetime ceiling the capstone enforces.
QuestGrant payQuestReward(Map<String, dynamic> state, QuestDef def) {
  final coins = questRewardCoins(state, def.reward.coins);
  if (coins <= 0) return (coins: 0);
  final resources = _branch(state, 'resources');
  resources['fanCoins'] = (_num(resources['fanCoins']) ?? 0) + coins;
  emit('coins:updated', resources['fanCoins']);
  return (coins: coins);
}

/// Recompute every derived season quest from the current save.
///
/// Derived quests have no call site of their own — they read facts off the save
/// (a renamed card, an owned asset tier, a sponsored player), which is what
/// lets the bank ask for things with no natural event to hook. The cost is
/// latency: this runs when quests are advanced, at full time, and whenever the
/// quest popup renders, so a rename shows up on the next of those rather than
/// the instant it happens.
///
/// Completion is STICKY. A derived value can fall — sell the sponsored player —
/// and that must not retract a quest the player has already finished.
void refreshDerivedQuests(Map<String, dynamic> state) {
  for (final inst in _seasonTrack(state)) {
    if (inst['completed'] == true) continue;
    final def = getQuest(inst['id'] as String?);
    final reader = def?.progress;
    if (def == null || reader == null) continue;

    final num raw;
    try {
      raw = reader(state);
    } catch (_) {
      continue;
    }

    final target = _num(inst['target']) ?? 0;
    final value = math.max(0, raw - (_num(inst['baseline']) ?? 0));
    inst['progress'] = math.min(value, target);
    if ((_num(inst['progress']) ?? 0) >= target) {
      inst['completed'] = true;
      emit('quest:completed', {'quest': inst, 'def': def, 'scope': 'season'});
    }
  }
}

// ── Season accumulation ─────────────────────────────────────────────────────

/// Advance every active season quest matching [action] by [amount].
///
/// Streak actions are ignored here — their progress is not monotonic, so they
/// go through [setStreakProgress] instead.
///
/// The season TALLY is kept whether or not a quest is watching. That is the
/// point of it: a quest rolled at match 10 needs to know what the first nine
/// did, and by definition it wasn't on the track to be advanced by them.
void advanceQuest(Map<String, dynamic> state, String action, [num amount = 1]) {
  final q = ensureQuests(state);
  // The cheapest place to keep derived quests honest: every tracked action
  // funnels through here, so a merge or a scout also re-reads them.
  refreshDerivedQuests(state);
  // Streaks are excluded deliberately — a run isn't a total, so summing it
  // would be meaningless. The live run is already kept on the save, which is
  // what a streak quest is seeded from.
  if (streakActions.contains(action)) return;

  final isMax = maxActions.contains(action);
  final tally = _branch(q, 'seasonTally');
  final current = _num(tally[action]) ?? 0;
  tally[action] = isMax ? math.max(current, amount) : current + amount;

  for (final inst in _seasonTrack(state)) {
    if (inst['completed'] == true) continue;
    final def = getQuest(inst['id'] as String?);
    if (def == null || def.action != action) continue;
    final target = _num(inst['target']) ?? 0;
    final progress = _num(inst['progress']) ?? 0;
    // A MAX action's amount is a level already reached, not an increment.
    inst['progress'] = isMax
        ? math.min(math.max(progress, amount), target)
        : math.min(progress + amount, target);
    if ((_num(inst['progress']) ?? 0) >= target) {
      inst['completed'] = true;
      emit('quest:completed', {'quest': inst, 'def': def, 'scope': 'season'});
    }
  }
}

/// Absolute-set a streak quest's progress.
///
/// Progress tracks the CURRENT run, so it falls back to zero when the run
/// breaks — but a quest already completed stays completed. Losing a match must
/// not retract a reward the player has earned, and possibly already claimed.
void setStreakProgress(Map<String, dynamic> state, String action, num value) {
  for (final inst in _seasonTrack(state)) {
    final def = getQuest(inst['id'] as String?);
    if (def == null || def.action != action) continue;
    if (inst['completed'] == true) continue;
    final target = _num(inst['target']) ?? 0;
    inst['progress'] = math.min(math.max(0, value), target);
    if ((_num(inst['progress']) ?? 0) >= target) {
      inst['completed'] = true;
      emit('quest:completed', {'quest': inst, 'def': def, 'scope': 'season'});
    }
  }
}

// ── Rerolling ───────────────────────────────────────────────────────────────

/// Free rerolls still standing this season.
int freeRerollsLeft(Map<String, dynamic> state) => math.max(
  0,
  freeRerollsPerSeason -
      (_num(ensureQuests(state)['seasonFreeRerollsUsed'])?.toInt() ?? 0),
);

/// What the next season reroll costs, in gems. Zero while a free one stands.
int rerollCost(Map<String, dynamic> state) =>
    freeRerollsLeft(state) > 0 ? 0 : rerollGemCost;

/// Can the season track be rerolled?
///
/// False when every quest is already finished — there would be nothing to swap,
/// and charging for that would be theft.
bool canReroll(Map<String, dynamic> state) {
  final track = _seasonTrack(state);
  if (!track.any((c) => c['completed'] != true)) return false;
  return rerollCost(state) == 0 || canAffordGems(state, rerollGemCost);
}

/// What a reroll did.
typedef RerollResult = ({
  bool ok,
  String? reason,
  int cost,
  List<({String from, String to})> replaced,
});

/// Swap out every unfinished season quest and charge for it.
///
/// There is deliberately no per-quest variant. It existed, and at the same
/// price as this it was a dominated choice — nobody rerolls one for a gem when
/// the same gem rerolls the lot — so it was UI that could only ever be a
/// mistake to press.
///
/// COMPLETED quests are never rerolled: they are holding an unclaimed reward,
/// and swapping one out would destroy coins the player has already earned.
///
/// Replacements avoid every id currently on the track, so a reroll always
/// visibly changes something.
RerollResult rerollQuests(Map<String, dynamic> state) {
  final q = ensureQuests(state);
  final track = _list(q, 'season');
  final targets = [
    for (final c in _seasonTrack(state))
      if (c['completed'] != true) c,
  ];
  if (targets.isEmpty) {
    return (
      ok: false,
      reason: 'nothing_to_reroll',
      cost: 0,
      replaced: const [],
    );
  }

  final divIdx = _currentDivIdx(state);
  // Rollable, not merely eligible — a reroll that hands back a quest the save
  // already satisfies is the same bug as rolling one, and costs a gem.
  //
  // Drawn BEFORE the charge. The pool narrows as a season runs out, so "there
  // is nothing to swap to" is a reachable state late on — and taking a gem for
  // a track that comes back unchanged is the one outcome a reroll must never
  // have.
  final pool = rollableQuests(state, 'season');
  final onTrack = {for (final c in _seasonTrack(state)) '${c['id']}'};
  if (!pool.any((def) => !onTrack.contains(def.id))) {
    return (
      ok: false,
      reason: 'nothing_to_reroll',
      cost: 0,
      replaced: const [],
    );
  }

  final cost = rerollCost(state);
  if (cost > 0 && !spendGems(state, cost, 'quest_reroll')) {
    return (
      ok: false,
      reason: 'not_enough_gems',
      cost: cost,
      replaced: const [],
    );
  }
  if (cost == 0) {
    q['seasonFreeRerollsUsed'] =
        (_num(q['seasonFreeRerollsUsed'])?.toInt() ?? 0) + 1;
  }

  final replaced = <({String from, String to})>[];

  for (final inst in targets) {
    final live = _seasonTrack(state);
    final taken = {for (final c in live) '${c['id']}'};
    // The same one-ask-per-roll rule the initial roll uses — a reroll must not
    // hand back a different sizing of a quest already on the track, nor a
    // different route to the same objective.
    final takenTags = <String>{
      for (final c in live)
        if (!identical(c, inst)) ...questTags(getQuest(c['id'] as String?)),
    };

    var candidates = [
      for (final def in pool)
        if (!taken.contains(def.id) && !questTags(def).any(takenTags.contains))
          def,
    ];
    if (candidates.isEmpty) {
      candidates = [
        for (final def in pool)
          if (!taken.contains(def.id)) def,
      ];
    }
    if (candidates.isEmpty) break;

    final def = seeded.shuffle([...candidates]).first;
    final idx = track.indexWhere((c) => identical(c, inst));
    if (idx < 0) continue;
    track[idx] = _makeInstance(def, state, divIdx);
    replaced.add((from: '${inst['id']}', to: def.id));
  }

  // A derived replacement still needs its first read — it starts at whatever
  // the save already says, it just can't start at DONE.
  refreshDerivedQuests(state);
  emit('quests:rerolled', {'cost': cost, 'replaced': replaced});
  return (ok: true, reason: null, cost: cost, replaced: replaced);
}

// ── Claiming ────────────────────────────────────────────────────────────────

/// What a claim did.
typedef ClaimOutcome = ({
  bool ok,
  String? reason,
  QuestGrant? granted,
  CapstoneAward? capstone,
});

/// Claim a completed season quest. Idempotent: a second call is a no-op.
ClaimOutcome claimQuest(Map<String, dynamic> state, String questId) {
  Map<String, dynamic>? inst;
  for (final c in _seasonTrack(state)) {
    if (c['id'] == questId) inst = c;
  }
  if (inst == null) {
    return (ok: false, reason: 'unknown_quest', granted: null, capstone: null);
  }
  if (inst['completed'] != true) {
    return (ok: false, reason: 'not_complete', granted: null, capstone: null);
  }
  if (inst['claimedAt'] != null) {
    return (
      ok: false,
      reason: 'already_claimed',
      granted: null,
      capstone: null,
    );
  }

  final def = getQuest(questId);
  if (def == null) {
    return (ok: false, reason: 'unknown_quest', granted: null, capstone: null);
  }

  final granted = payQuestReward(state, def);
  inst['claimedAt'] = now();
  emit('quest:claimed', {'quest': inst, 'def': def, 'granted': granted});

  return (
    ok: true,
    reason: null,
    granted: granted,
    capstone: checkDivisionCapstone(state),
  );
}

/// What a sweep paid out.
typedef SweepResult = ({int count, int coins});

/// Pay out every season quest that is complete but never claimed, and mark it
/// claimed.
///
/// Called at a season boundary: the season roll replaces the track wholesale,
/// so without this a quest finished in week three and left uncollected is
/// destroyed with no payout and no warning. Nobody should lose coins they
/// earned for not tapping a button — the claim is there as a reason to come
/// back, not as a deadline.
///
/// Deliberately does NOT check the division capstone. That is credited to a
/// specific division, and the season end changes the current division on
/// promotion or relegation BEFORE the new quests roll — so the caller runs the
/// capstone check itself, while the division is still the one whose quests were
/// actually played.
SweepResult sweepUnclaimedSeasonQuests(Map<String, dynamic> state) {
  var coins = 0;
  var count = 0;
  for (final inst in _seasonTrack(state)) {
    if (inst['completed'] != true || inst['claimedAt'] != null) continue;
    final def = getQuest(inst['id'] as String?);
    if (def == null) continue;
    final granted = payQuestReward(state, def);
    inst['claimedAt'] = now();
    coins += granted.coins;
    count += 1;
  }
  if (count > 0) emit('quests:swept', {'count': count, 'coins': coins});
  return (count: count, coins: coins);
}

/// How many season quests are complete but not yet claimed — the badge count.
int unclaimedCount(Map<String, dynamic> state) => _seasonTrack(
  state,
).where((c) => c['completed'] == true && c['claimedAt'] == null).length;

// ── The division capstone — the one and only gem route ──────────────────────

/// A capstone payout.
typedef CapstoneAward = ({String divisionId, int gems});

/// Clear every season quest in a division and take one gem — ONCE EVER for that
/// division, ledgered where a reset cannot reach it. Seven divisions, so this
/// feature's hard lifetime ceiling is seven gems.
///
/// Why bounded this tightly: cosmetics are safe to farm, but the gem sinks are
/// power items, so a renewable gem faucet would become a renewable pipeline
/// into squad strength. A once-per-division award is bounded by something the
/// player cannot farm.
CapstoneAward? checkDivisionCapstone(Map<String, dynamic> state) {
  ensureQuests(state);
  final divId = _map(state['progression'])?['currentDivision'];
  if (divId is! String || divId.isEmpty) return null;

  final ledger = _list(_branch(state, 'gemGrants'), 'questDivisionFirsts');
  if (ledger.contains(divId)) return null;

  final track = _seasonTrack(state);
  if (track.isEmpty) return null;
  if (!track.every((c) => c['completed'] == true && c['claimedAt'] != null)) {
    return null;
  }

  ledger.add(divId);
  addGems(state, capstoneGems, 'quest_division_capstone');
  emit('quest:capstone', {'divisionId': divId, 'gems': capstoneGems});
  return (divisionId: divId, gems: capstoneGems);
}
