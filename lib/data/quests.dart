/// The quest bank — the pool both tracks draw from. Ported from
/// `../merge-empire-fc/src/data/quests.js`.
///
/// TWO SCOPES, two completely different resolution models:
///
///   match   three rolled before each fixture, EVALUATED once at full time.
///           Nothing accumulates; a match quest either passed in that match or
///           it didn't.
///   season  three rolled at each season start, ACCUMULATED across the whole
///           campaign at the action call sites, or DERIVED by reading the save.
///
/// Difficulty scales two ways at once, which is the point of the range-plus-
/// curve shape: qualitatively a quest is simply absent below `minDiv` (a Sunday
/// League manager is never asked to win by six), and quantitatively `target` is
/// a function of the division index, so the same quest asks for more the higher
/// you climb.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/divisions.dart';

/// The action vocabulary.
///
/// The first six are the old challenge-type strings, UNCHANGED — the event
/// reward track mirrors this same space and references the values by string
/// rather than by import. Those six are load-bearing; don't rename them.
abstract final class QuestAction {
  // ── Legacy six, shared with the event reward track ──────────────────────
  static const String mergeCount = 'merge_count';
  static const String scoutCount = 'scout_count';
  static const String matchWin = 'match_win';

  /// Kept for the event reward track, which still emits it. No QUEST uses it —
  /// nothing calls the funnel with it, so a quest keyed to it could never
  /// progress. Don't add one without wiring a call site first.
  static const String coinsEarned = 'coins_earned_session';
  static const String reachTier = 'reach_tier';

  /// Also emitted for events, and also not a quest: "play 8 matches" completes
  /// itself by playing the season.
  static const String playMatches = 'play_matches';

  // ── Match-scoped, evaluated from the result ──────────────────────────────
  static const String cleanSheet = 'clean_sheet';
  static const String goalsInMatch = 'goals_in_match';
  static const String winMargin = 'win_margin';
  static const String defScores = 'def_scores';
  static const String winThisMatch = 'win_this_match';
  static const String comebackWin = 'comeback_win';
  static const String defyCoach = 'defy_coach';
  static const String noInjury = 'no_injury';
  static const String bothHalves = 'both_halves';
  static const String lateWinner = 'late_winner';
  static const String awayWin = 'away_win';

  // ── Season-scoped, accumulated ───────────────────────────────────────────
  static const String cleanSheetsSeason = 'clean_sheets_season';
  static const String goalsSeason = 'goals_season';
  static const String cleanSheetRun = 'clean_sheet_run';
  static const String winRun = 'win_run';
  static const String unbeatenRun = 'unbeaten_run';
  static const String underdogWins = 'underdog_wins';
  static const String comebackWins = 'comeback_wins';
  static const String awayWins = 'away_wins';
  static const String homeWins = 'home_wins';
  static const String hatTricks = 'hat_tricks';
  static const String scoringRun = 'scoring_run';

  // ── Match-scoped, the awkward ones ───────────────────────────────────────
  static const String midScores = 'mid_scores';
  static const String quickDouble = 'quick_double';

  // Decisions, not dice. These read what the MANAGER did — which tactic was on
  // the dial at the whistle, how many were tried, how many changes were made,
  // and whether one of them scored.
  static const String tacticWin = 'tactic_win';
  static const String tacticVariety = 'tactic_variety';
  static const String subsMade = 'subs_made';
  static const String subScores = 'sub_scores';
  static const String gkScores = 'gk_scores';
  static const String underdogWin = 'underdog_win';
  static const String weakDefCleanSheet = 'weak_def_clean_sheet';
  static const String shortHandedWin = 'short_handed_win';
  static const String winAfterInjury = 'win_after_injury';
  static const String scoreEarly = 'score_early';
  static const String scoreLate = 'score_late';
  static const String hatTrick = 'hat_trick';
  static const String threeScorers = 'three_scorers';
  static const String halftimeDeficitWin = 'halftime_deficit_win';
  static const String noTacticChangeWin = 'no_tactic_change_win';
  static const String awayCleanSheet = 'away_clean_sheet';
  static const String concedeAtMost = 'concede_at_most';
  static const String winSecondHalf = 'win_second_half';
  static const String veteranScores = 'veteran_scores';

  /// Derived from the save, with no call site — see [QuestDef.progress].
  static const String derived = 'derived';
}

/// Quest families.
///
/// Two quests already conflict when they share an ACTION — the "one ask per
/// roll" rule, which catches variants of one quest sized for different
/// divisions ("score 3" / "score 5"). It does NOT catch quests that ask for the
/// same thing by different routes, because those are different actions: "keep a
/// clean sheet", "shut out a stronger attack" and "win away without conceding"
/// were three separate actions and rolled together happily, which reads as one
/// quest printed three times.
///
/// A tag is the wider net. Two quests share a tag when passing one all but
/// guarantees passing the other, or when they would simply read as the same
/// ask. The roll treats a shared tag exactly like a shared action, so a whole
/// family collapses into one slot.
///
/// Tag things that OVERLAP, not things that merely rhyme: "score inside 15
/// minutes" and "score after the 88th" are both about timing and are still two
/// genuinely different matches, so they stay in separate families.
///
/// Families are CONNECTED GROUPS, not single tags: two quests sharing any tag
/// are in one family, and that merges transitively. A tag added to be "helpful"
/// on an unrelated pair can silently weld half the bank into one slot — a broad
/// "this one needs a win" across a dozen quests would chain SHUTOUT to MARGIN to
/// AWAY to COMEBACK and leave the roll one family to draw from.
abstract final class QuestTag {
  // ── Match ────────────────────────────────────────────────────────────────
  /// A clean sheet by any route, including "concede at most one".
  static const String shutout = 'shutout';

  /// Needs the fixture to be away from home.
  static const String away = 'away';

  /// Volume of goals in the match.
  static const String goals = 'goals';

  /// WHO scored — a hat-trick, N different scorers.
  static const String scorers = 'scorers';

  /// Win by N.
  static const String margin = 'margin';

  /// Hinges on the injury roll, including avoiding it.
  static const String injury = 'injury';

  /// A goal in the opening minutes.
  static const String early = 'early';

  /// A goal in the closing minutes.
  static const String late = 'late';

  /// Scoring either side of half time.
  static const String halves = 'halves';

  /// Goals bunched close together.
  static const String burst = 'burst';

  /// Winning from behind.
  static const String comeback = 'comeback';

  /// Out-playing them after the break.
  static const String secondHalf = 'second_half';

  /// About the tactic dial, not the football.
  static const String tactics = 'tactics';

  /// A particular KIND of player scores.
  static const String scorerType = 'scorer_type';

  /// Hinges on being rated below them.
  static const String underdog = 'underdog';

  // ── Season ───────────────────────────────────────────────────────────────
  /// Consecutive-match runs.
  static const String run = 'run';

  /// Season-long clean-sheet counting.
  static const String cleanSheets = 'clean_sheets';

  /// Every season quest whose objective is WINNING MATCHES, whatever the
  /// flavour. "Win 8", "win 4 away", "beat 2 better sides" and "win 2 from
  /// behind" are one ask wearing four hats, and a track with all three slots
  /// filled from that set is a season of the thing the player was doing anyway.
  static const String wins = 'wins';

  /// Using the bench.
  static const String subs = 'subs';

  /// The mini-games corner.
  static const String arcade = 'arcade';

  /// Naming players.
  static const String rename = 'rename';

  /// Player sponsorship deals.
  static const String sponsor = 'sponsor';

  /// Incoming transfer offers.
  static const String transfer = 'transfer';

  /// How many players are at the club, or in the XI.
  static const String squadSize = 'squad_size';

  /// The club-asset grid.
  static const String facility = 'facility';

  /// Meeting new faces.
  static const String discovery = 'discovery';
}

/// What a quest pays. Coins are the ONLY quest reward.
///
/// `coins` is a PERCENTAGE OF ONE LEAGUE WIN, never a literal: the payout is
/// `coins * matchRevenueBase / 100`, and a win pays exactly `matchRevenueBase`.
/// So 25 is a quarter of a win at every division — 25 coins in Sunday League,
/// 30,000 in the Champions League.
typedef QuestReward = ({num coins});

/// What the roll knows about the situation a quest would land in.
///
/// Fields can be null when a fixture hasn't been rolled far enough to know — an
/// unplayed season has no opponent rating. Treat null as unknown and refuse:
/// better a quest that waits than one that can't be won.
typedef QuestContext = ({
  bool? isHome,
  num? oppRating,
  num ourRating,
  num? oppAttack,
  num ourDefence,
  bool defInLineup,
  bool midInLineup,
  bool hasGK,
  int oldestSeasons,
  int fitCount,
  int undiscovered,
  List<String> minigames,
  int benchCount,
});

/// Reads the save directly. Must never throw on a half-built one — a reader
/// that throws simply stops its quest ever progressing, which is worse than
/// returning zero.
typedef ProgressReader = num Function(Map<String, dynamic>? state);

/// Answers "could this quest be finished in the situation it would land in?"
typedef FeasibilityCheck = bool Function(QuestContext ctx, int target);

/// One quest in the bank.
class QuestDef {
  const QuestDef({
    required this.id,
    required this.scope,
    required this.action,
    required this.minDiv,
    required this.target,
    required this.reward,
    required this.icon,
    this.maxDiv,
    this.tags = const [],
    this.feasible,
    this.progress,
    this.baseline = false,
    this.lift,
    this.strategy,
  });

  final String id;

  /// `match` or `season`.
  final String scope;
  final String action;

  /// The lowest division this is offered at.
  final String minDiv;

  /// The highest, or null for "all the way up".
  final String? maxDiv;

  /// A function of the division index, so a literal target is a constant
  /// function. Always resolved through [resolveTarget], which floors it at one.
  final int Function(int divIdx) target;

  final QuestReward reward;

  /// An icon key the UI resolves. The data file stays UI-free.
  final String icon;

  final List<String> tags;

  /// Checked at roll time. Return false and the quest simply isn't drawn; it
  /// comes round again when the situation suits it.
  final FeasibilityCheck? feasible;

  /// Reads its own progress off the save rather than waiting for a call site.
  final ProgressReader? progress;

  /// Measure a DELTA from the start of the season rather than an absolute.
  ///
  /// Without it a quest reading a lifetime total would complete the instant it
  /// appeared. An absolute goal — "own a Tier 4 asset" — leaves it off.
  final bool baseline;

  /// A ceiling for a LEVEL-shaped derived quest, so a club already on tier
  /// three is asked for four rather than handed a finished quest.
  final int? lift;

  /// The tactic that has to be on the dial at the whistle.
  final String? strategy;
}

/// Everything a quest occupies a slot for: its action plus its family tags.
///
/// `derived` is deliberately NOT one of them. It marks a MECHANISM — "this
/// quest reads the save instead of counting an event" — shared by every quest
/// with no natural call site, and treating it as a family put renaming a
/// player, owning a facility, unlocking a look and playing a mini-game all in
/// one slot. That capped the season track at ONE derived quest, so two of the
/// three were always drawn from the accumulating pool, which is where every
/// win/goal/clean-sheet counter lives. The bank read as "win things" because
/// the tagging was quietly enforcing it.
List<String> questTags(QuestDef? quest) => [
  if (quest != null && quest.action != QuestAction.derived) quest.action,
  ...?quest?.tags,
];

/// A quest reads the save when it carries a progress function.
bool isDerived(QuestDef? quest) => quest?.progress != null;

/// Division id to ladder index, or -1 for an unknown id.
int divisionIndex(String? divId) => divisions.indexWhere((d) => d.id == divId);

abstract final class _Div {
  static const String sl = 'sunday_league';
  static const String al = 'amateur_cup';
  static const String rl = 'regional_league';
  static const String nl = 'national_league';
  static const String el = 'elite_league';
  static const String cl = 'continental';
}

// ── Feasibility checks ──────────────────────────────────────────────────────
//
// A quest can be impossible in the situation it was rolled into with no way for
// the player to know: "win away from home" cannot be done in a home game,
// "score with a veteran" cannot be done by a squad of rookies, "discover 8 new
// players" cannot be done by a save that has met nearly everyone. Handing one
// of those out isn't difficulty, it's a dead slot — and there are only three.
//
// Rules for writing one:
//   • Feasible means POSSIBLE, not likely. "Win after going behind" needs luck
//     and stays ungated; "win away" needs a fact about the fixture.
//   • Anything the player can still change after reading the quest is feasible.
//     A keeper only scores if you field him up front — that IS the quest, so it
//     asks whether the squad HAS a keeper, not whether he is already there.
//   • It cannot save a quest whose progress can't move AT ALL within its scope.
//     That is a design fault, not a situational one, and the answer is to cut
//     the quest.

abstract final class _Feasible {
  static bool away(QuestContext ctx, int _) => ctx.isHome == false;

  static bool underdog(QuestContext ctx, int _) =>
      ctx.oppRating != null && ctx.oppRating! > ctx.ourRating;

  static bool weakDef(QuestContext ctx, int _) =>
      ctx.oppAttack != null && ctx.ourDefence < ctx.oppAttack!;

  static bool defInXI(QuestContext ctx, int _) => ctx.defInLineup;

  static bool midInXI(QuestContext ctx, int _) => ctx.midInLineup;

  static bool ownsGK(QuestContext ctx, int _) => ctx.hasGK;

  static bool veteran(QuestContext ctx, int target) =>
      ctx.oldestSeasons >= target;

  static bool scorers(QuestContext ctx, int target) => ctx.fitCount >= target;

  /// The player index is finite and a long-running save fills it. Asking a
  /// complete index for eight more faces is unwinnable.
  static bool newPlayersLeft(QuestContext ctx, int target) =>
      ctx.undiscovered >= target;

  /// Six of the seven mini-games sit behind Training facility tiers. Asking a
  /// player to go and play one they can't open is the purest form of the dead
  /// slot this whole mechanism exists to prevent — and the division a quest is
  /// gated to says nothing about it, since the Training facility is bought with
  /// coins whenever the player fancies it. The per-game checks are named below
  /// so the bank can stay a compile-time constant.
  static bool _unlocked(QuestContext ctx, String game) =>
      ctx.minigames.contains(game);

  static bool throughBall(QuestContext ctx, int _) =>
      _unlocked(ctx, 'through_ball');
  static bool keepyUppys(QuestContext ctx, int _) =>
      _unlocked(ctx, 'keepy_uppys');
  static bool pairs(QuestContext ctx, int _) => _unlocked(ctx, 'pairs');
  static bool whack(QuestContext ctx, int _) => _unlocked(ctx, 'whack');
  static bool bootRoom(QuestContext ctx, int _) => _unlocked(ctx, 'boot_room');
  static bool training(QuestContext ctx, int _) => _unlocked(ctx, 'training');

  /// A substitution needs someone to bring on. A squad with no more fit players
  /// than the eleven on the pitch has no bench, so "make two changes" is a
  /// button that isn't there.
  static bool hasBench(QuestContext ctx, int target) =>
      ctx.benchCount >= math.max(1, target);
}

/// Where each streak's live run is kept on the save.
///
/// Streak actions track a CURRENT run, not a running total, so their progress
/// can go down as well as up. Keeping the run on the save is what lets a quest
/// rolled MID-season start from the run already going rather than from zero.
const Map<String, String> streakStateKey = {
  QuestAction.cleanSheetRun: 'cleanSheet',
  QuestAction.winRun: 'win',
  QuestAction.unbeatenRun: 'unbeaten',
  // Scoring in match after match is NOT a winning run — you can score in a
  // defeat — which is why it sits with the goal quests and not the win ones.
  QuestAction.scoringRun: 'scoring',
};

final Set<String> streakActions = streakStateKey.keys.toSet();

/// Season actions that can only advance when a MATCH is played, and at most
/// once per match.
///
/// This is what makes "can this still be finished" answerable. A season is a
/// fixed number of fixtures long, so a quest rolled mid-season asking for six
/// more wins with four to play is not hard, it is arithmetic: it cannot be
/// done.
///
/// Everything absent from this set is bounded by something other than the
/// fixture list — merges and scouts are limited by cards and energy, and a
/// player can do sixty of either in one sitting — so the matches left says
/// nothing about whether they are winnable.
const Set<String> perMatchActions = {
  QuestAction.matchWin,
  QuestAction.cleanSheetsSeason,
  QuestAction.awayWins,
  QuestAction.homeWins,
  QuestAction.scoringRun,
  QuestAction.underdogWins,
  QuestAction.comebackWins,
  QuestAction.hatTricks,
  QuestAction.cleanSheetRun,
  QuestAction.winRun,
  QuestAction.unbeatenRun,
};

/// The match-paced actions, plus season goals — the one with no exact
/// per-match ceiling, measured against the lambda soft cap instead.
const Set<String> matchPacedActions = {
  ...perMatchActions,
  QuestAction.goalsSeason,
};

/// Actions whose amount is a LEVEL REACHED, not a quantity to add up.
///
/// The call site passes an absolute value, so adding would be nonsense —
/// merging three tier-3 cards would read as "tier 9". These take the max.
const Set<String> maxActions = {QuestAction.reachTier};

// ── State readers for derived quests ────────────────────────────────────────

List<Map<String, dynamic>> _cardsOf(Map<String, dynamic>? state) {
  final grid = state?['grid'];
  final cells = grid is Map ? grid['cells'] : null;
  if (cells is! List) return const [];
  return [
    for (final c in cells)
      if (c is Map<String, dynamic>) c,
  ];
}

num _maxOf(Iterable<num> nums) => nums.fold<num>(0, (m, n) => n > m ? n : m);

num _renamedCount(Map<String, dynamic>? s) =>
    _cardsOf(s).where((c) => c['customName'] != null).length;

num _sponsoredCount(Map<String, dynamic>? s) =>
    _cardsOf(s).where((c) => c['sponsor'] != null).length;

num _squadSize(Map<String, dynamic>? s) => _cardsOf(s).length;

/// `clubAssets` also holds a `cells` list for the club grid, so filtering on
/// `owned` is what skips it.
num _bestAssetTier(Map<String, dynamic>? s) {
  final assets = s?['clubAssets'];
  if (assets is! Map) return 0;
  return _maxOf([
    for (final a in assets.values)
      if (a is Map && a['owned'] == true) (a['tier'] as num?) ?? 0,
  ]);
}

num _ownedCategories(Map<String, dynamic>? s) {
  final assets = s?['clubAssets'];
  if (assets is! Map) return 0;
  return AssetCategory.all
      .where((cat) => (assets[cat] as Map?)?['owned'] == true)
      .length;
}

num _lineupFilled(Map<String, dynamic>? s) {
  final squad = s?['squad'];
  final lineup = squad is Map ? squad['lineup'] : null;
  if (lineup is! List) return 0;
  return lineup
      .where((x) => x is Map && x['cardInstanceId'] != null)
      .length;
}

num _discovered(Map<String, dynamic>? s) {
  final prog = s?['progression'];
  final list = prog is Map ? prog['discoveredPlayers'] : null;
  return list is List ? list.length : 0;
}

num _stat(Map<String, dynamic>? s, String key) {
  final stats = s?['stats'];
  final v = stats is Map ? stats[key] : null;
  return v is num ? v : 0;
}

/// Every upgrade tap ever paid for, across all facilities. `clubAssets` also
/// holds a `cells` list, so the tap count is read defensively.
num _facilityTaps(Map<String, dynamic>? s) {
  final assets = s?['clubAssets'];
  if (assets is! Map) return 0;
  var total = 0;
  for (final a in assets.values) {
    if (a is Map && a['tapCount'] is num) total += (a['tapCount'] as num).toInt();
  }
  return total;
}

// ── The bank ────────────────────────────────────────────────────────────────
//
// COINS ARE THE ONLY QUEST REWARD, and every number below is a PERCENTAGE OF
// ONE LEAGUE WIN. That anchor is the whole balance. Sunday League pays 100 a
// win against a 200-coin scout, so a quest worth "1000" would be ten wins for
// one objective — the first cut of this table did exactly that, and three
// season quests plus a match's worth came to more coins than the entire season
// of football they sat on top of. Budget: a match quest is 15–45% of a win (all
// three is about one extra win, and you won't land all three), a season quest
// is 60–150% spread over a fourteen-match campaign (all three is about 20% on
// top of match income). A test caps both bands.
//
// NOTHING ELSE IS PAYABLE. Energy is monetised — rewarded ads and the energy
// IAP both sell it — so a quest granting it would give away the thing the shop
// charges for. Scout vouchers are priced in gems, which would leak past the
// lifetime ceiling the division capstone exists to enforce. Coins are the
// campaign's reward currency; the capstone gem is the only hard-currency route.
//
// PARTICIPATION IS NOT AN OBJECTIVE. A quest has to ask for something the
// player wouldn't get by default, or it is a receipt for existing rather than a
// reward for doing. "Play 8 matches" completes itself over any season, so it is
// gone and a test blocks it coming back. The line is about DEFAULT behaviour,
// not effort: "play 3 mini-games" is fine even though it is also participation,
// because mini-games are a corner of the app most players never open. Pushing
// someone somewhere new is the point; counting what they were doing anyway is
// not.
//
// "SCORE WITH A GOALKEEPER" IS IN THE BANK, and the reason it is playable
// rather than a one-in-three-hundred novelty is that scorer odds follow the
// SLOT, not the card: a keeper left in goal carries GK's tiny weight and
// effectively never scores, while a keeper played at FWD shoots exactly as
// often as a real forward. The off-position penalty is a RATING penalty and
// does not touch scorer odds at all. So the quest costs you a weaker XI and an
// empty net, and pays a proper chance of the goal.

const List<QuestDef> questBank = [
  // ══ MATCH ═════════════════════════════════════════════════════════════════
  QuestDef(
    id: 'match_clean_sheet',
    scope: 'match',
    action: QuestAction.cleanSheet,
    minDiv: _Div.sl,
    target: _one,
    tags: [QuestTag.shutout],
    reward: (coins: 25),
    icon: 'goal',
  ),
  QuestDef(
    id: 'match_score_2',
    scope: 'match',
    action: QuestAction.goalsInMatch,
    minDiv: _Div.sl,
    maxDiv: _Div.al,
    target: _two,
    tags: [QuestTag.goals],
    reward: (coins: 15),
    icon: 'ball',
  ),
  QuestDef(
    id: 'match_score_scaling',
    scope: 'match',
    action: QuestAction.goalsInMatch,
    minDiv: _Div.sl,
    // Three at Sunday League climbing to six at Champions — the same ask, sized
    // to the squad you are expected to have.
    target: _scoreScaling,
    tags: [QuestTag.goals],
    reward: (coins: 20),
    icon: 'ball',
  ),
  QuestDef(
    id: 'match_win_margin_2',
    scope: 'match',
    action: QuestAction.winMargin,
    minDiv: _Div.sl,
    maxDiv: _Div.nl,
    target: _two,
    tags: [QuestTag.margin],
    reward: (coins: 20),
    icon: 'target',
  ),
  QuestDef(
    id: 'match_win_margin_scaling',
    scope: 'match',
    action: QuestAction.winMargin,
    minDiv: _Div.rl,
    target: _marginScaling,
    tags: [QuestTag.margin],
    reward: (coins: 28),
    icon: 'target',
  ),
  QuestDef(
    id: 'match_no_injury',
    scope: 'match',
    action: QuestAction.noInjury,
    minDiv: _Div.al,
    target: _one,
    tags: [QuestTag.injury],
    reward: (coins: 18),
    icon: 'bandage',
  ),
  QuestDef(
    id: 'match_both_halves',
    scope: 'match',
    action: QuestAction.bothHalves,
    minDiv: _Div.al,
    target: _one,
    tags: [QuestTag.halves],
    reward: (coins: 22),
    icon: 'stopwatch',
  ),
  QuestDef(
    id: 'match_away_win',
    scope: 'match',
    action: QuestAction.awayWin,
    minDiv: _Div.al,
    target: _one,
    tags: [QuestTag.away],
    feasible: _Feasible.away,
    reward: (coins: 25),
    icon: 'globe',
  ),
  QuestDef(
    id: 'match_def_scores',
    scope: 'match',
    action: QuestAction.defScores,
    // About one match in four. Rare enough to feel like a story, common enough
    // to land.
    minDiv: _Div.rl,
    target: _one,
    tags: [QuestTag.scorerType],
    feasible: _Feasible.defInXI,
    reward: (coins: 35),
    icon: 'shield',
  ),
  QuestDef(
    id: 'match_comeback',
    scope: 'match',
    action: QuestAction.comebackWin,
    minDiv: _Div.rl,
    target: _one,
    tags: [QuestTag.comeback],
    reward: (coins: 35),
    icon: 'flame',
  ),
  QuestDef(
    id: 'match_late_winner',
    scope: 'match',
    action: QuestAction.lateWinner,
    minDiv: _Div.nl,
    target: _one,
    tags: [QuestTag.late],
    reward: (coins: 35),
    icon: 'stopwatch',
  ),
  QuestDef(
    id: 'match_defy_coach',
    scope: 'match',
    action: QuestAction.defyCoach,
    // Win having picked a tactic the coach did NOT recommend. Gated late: it
    // asks you to understand the tactic system well enough to overrule it.
    minDiv: _Div.nl,
    target: _one,
    tags: [QuestTag.tactics],
    reward: (coins: 40),
    icon: 'megaphone',
  ),
  QuestDef(
    id: 'match_clean_sheet_win_big',
    scope: 'match',
    action: QuestAction.winMargin,
    minDiv: _Div.el,
    target: _identity,
    tags: [QuestTag.margin],
    reward: (coins: 40),
    icon: 'swords',
  ),
  QuestDef(
    id: 'match_score_many',
    scope: 'match',
    action: QuestAction.goalsInMatch,
    minDiv: _Div.el,
    target: _scoreMany,
    tags: [QuestTag.goals],
    reward: (coins: 40),
    icon: 'target',
  ),

  // ── Match: the awkward ones ───────────────────────────────────────────────
  // Everything below asks for a SHAPE of win rather than a win, which is the
  // point — the bank exists to stop a season of "score more than them".
  QuestDef(
    id: 'match_concede_max_one',
    scope: 'match',
    action: QuestAction.concedeAtMost,
    // A CEILING, not a count, so it stays flat across divisions — scaling it
    // would make the quest easier as you climb.
    minDiv: _Div.sl,
    maxDiv: _Div.nl,
    target: _one,
    tags: [QuestTag.shutout],
    reward: (coins: 18),
    icon: 'shield',
  ),
  QuestDef(
    id: 'match_score_early',
    scope: 'match',
    action: QuestAction.scoreEarly,
    // Also a ceiling — minutes, not goals.
    minDiv: _Div.sl,
    target: _fifteen,
    tags: [QuestTag.early],
    reward: (coins: 20),
    icon: 'stopwatch',
  ),
  QuestDef(
    id: 'match_no_tactic_change',
    scope: 'match',
    action: QuestAction.noTacticChangeWin,
    minDiv: _Div.sl,
    maxDiv: _Div.rl,
    target: _one,
    tags: [QuestTag.tactics],
    reward: (coins: 18),
    icon: 'shield',
  ),
  QuestDef(
    id: 'match_win_second_half',
    scope: 'match',
    action: QuestAction.winSecondHalf,
    minDiv: _Div.sl,
    target: _one,
    tags: [QuestTag.secondHalf],
    reward: (coins: 20),
    icon: 'flame',
  ),
  QuestDef(
    id: 'match_two_scorers',
    scope: 'match',
    action: QuestAction.threeScorers,
    minDiv: _Div.sl,
    maxDiv: _Div.nl,
    target: _two,
    tags: [QuestTag.goals, QuestTag.scorers],
    feasible: _Feasible.scorers,
    reward: (coins: 20),
    icon: 'squad',
  ),
  QuestDef(
    id: 'match_three_scorers',
    scope: 'match',
    action: QuestAction.threeScorers,
    minDiv: _Div.rl,
    target: _three,
    tags: [QuestTag.goals, QuestTag.scorers],
    feasible: _Feasible.scorers,
    reward: (coins: 30),
    icon: 'squad',
  ),
  QuestDef(
    id: 'match_score_late',
    scope: 'match',
    action: QuestAction.scoreLate,
    minDiv: _Div.al,
    target: _one,
    tags: [QuestTag.late],
    reward: (coins: 25),
    icon: 'stopwatch',
  ),
  QuestDef(
    id: 'match_win_after_injury',
    scope: 'match',
    action: QuestAction.winAfterInjury,
    minDiv: _Div.al,
    target: _one,
    tags: [QuestTag.injury],
    reward: (coins: 25),
    icon: 'bandage',
  ),
  QuestDef(
    id: 'match_away_clean_sheet',
    scope: 'match',
    action: QuestAction.awayCleanSheet,
    minDiv: _Div.al,
    target: _one,
    tags: [QuestTag.shutout, QuestTag.away],
    feasible: _Feasible.away,
    reward: (coins: 30),
    icon: 'globe',
  ),
  QuestDef(
    id: 'match_underdog_win',
    scope: 'match',
    action: QuestAction.underdogWin,
    minDiv: _Div.rl,
    target: _one,
    tags: [QuestTag.underdog],
    feasible: _Feasible.underdog,
    reward: (coins: 35),
    icon: 'swords',
  ),
  QuestDef(
    id: 'match_veteran_scores',
    scope: 'match',
    action: QuestAction.veteranScores,
    minDiv: _Div.rl,
    target: _three,
    tags: [QuestTag.scorerType],
    feasible: _Feasible.veteran,
    reward: (coins: 28),
    icon: 'star',
  ),
  QuestDef(
    id: 'match_hat_trick',
    scope: 'match',
    action: QuestAction.hatTrick,
    minDiv: _Div.rl,
    target: _three,
    tags: [QuestTag.goals, QuestTag.scorers],
    reward: (coins: 40),
    icon: 'target',
  ),
  QuestDef(
    id: 'match_halftime_deficit',
    scope: 'match',
    action: QuestAction.halftimeDeficitWin,
    minDiv: _Div.nl,
    target: _one,
    tags: [QuestTag.comeback, QuestTag.secondHalf],
    reward: (coins: 40),
    icon: 'flame',
  ),
  QuestDef(
    id: 'match_short_handed',
    scope: 'match',
    action: QuestAction.shortHandedWin,
    // No feasibility gate: neither mode auto-replaces an injured player any
    // more, so an injury always leaves a hole in the XI until the manager subs
    // from the bench themselves.
    minDiv: _Div.nl,
    target: _one,
    tags: [QuestTag.injury],
    reward: (coins: 38),
    icon: 'shield',
  ),
  QuestDef(
    id: 'match_weak_def_clean_sheet',
    scope: 'match',
    action: QuestAction.weakDefCleanSheet,
    // Measured against the opponent's attack, so "outgunned at the back" means
    // the same thing at Regional as it does at Champions.
    //
    // Tagged UNDERDOG as well as SHUTOUT, because "shut out a stronger attack"
    // and "beat a better-rated side" are one ask told twice — both are "do
    // something good against a team above you", and drawn together they read as
    // a single quest printed on two rows.
    minDiv: _Div.el,
    target: _one,
    tags: [QuestTag.shutout, QuestTag.underdog],
    feasible: _Feasible.weakDef,
    reward: (coins: 42),
    icon: 'shield',
  ),
  QuestDef(
    id: 'match_mid_scores',
    scope: 'match',
    action: QuestAction.midScores,
    // The gentlest of the three "who scored" quests — a midfield three carries
    // real scorer weight, so this lands without rearranging anything. DEF and
    // GK are the same trick at rising cost.
    minDiv: _Div.sl,
    target: _one,
    tags: [QuestTag.scorerType],
    feasible: _Feasible.midInXI,
    reward: (coins: 20),
    icon: 'squad',
  ),
  QuestDef(
    id: 'match_quick_double',
    scope: 'match',
    action: QuestAction.quickDouble,
    // Two goals inside a five-minute window. Not a volume quest — you can do it
    // in a 2-1 win and fail it 4-0 — which is why it sits in its own family
    // rather than with the goal counters.
    minDiv: _Div.al,
    target: _five,
    tags: [QuestTag.burst],
    reward: (coins: 32),
    icon: 'flame',
  ),

  // ── Match: things the MANAGER does ────────────────────────────────────────
  // The rest of the bank asks the eleven for something and hopes. These ask the
  // person holding the phone, and that is the difference between a quest you
  // notice afterwards and one you set out to do. They share the TACTICS family
  // with "defy the coach" and "win without touching the dial" — the last of
  // those is the exact opposite of using three, and they must never be printed
  // side by side.
  QuestDef(
    id: 'match_tactic_variety',
    scope: 'match',
    action: QuestAction.tacticVariety,
    // No luck in it at all: three taps on the dial and it is done. The point is
    // to get a player who has never opened the tactics strip to open it.
    minDiv: _Div.sl,
    target: _three,
    tags: [QuestTag.tactics],
    reward: (coins: 20),
    icon: 'megaphone',
  ),
  QuestDef(
    id: 'match_win_attacking',
    scope: 'match',
    action: QuestAction.tacticWin,
    // All Out Attack trades attack for defence. Winning on it is a genuine
    // gamble the player chooses to take.
    minDiv: _Div.al,
    target: _one,
    strategy: 'allOutAttack',
    tags: [QuestTag.tactics],
    reward: (coins: 30),
    icon: 'swords',
  ),
  QuestDef(
    id: 'match_win_press',
    scope: 'match',
    action: QuestAction.tacticWin,
    // High Press carries a raised injury modifier — the risk IS the quest.
    minDiv: _Div.rl,
    target: _one,
    strategy: 'highPress',
    tags: [QuestTag.tactics],
    reward: (coins: 32),
    icon: 'flame',
  ),
  QuestDef(
    id: 'match_win_counter',
    scope: 'match',
    action: QuestAction.tacticWin,
    // The underdog's tactic, and the swingiest on the dial.
    minDiv: _Div.rl,
    target: _one,
    strategy: 'counterAttack',
    tags: [QuestTag.tactics],
    reward: (coins: 32),
    icon: 'target',
  ),
  QuestDef(
    id: 'match_use_subs',
    scope: 'match',
    action: QuestAction.subsMade,
    // The bench is in both modes now and most players never touch it. Two
    // changes, no conditions — a quest you simply decide to complete.
    minDiv: _Div.sl,
    target: _two,
    tags: [QuestTag.subs],
    feasible: _Feasible.hasBench,
    reward: (coins: 22),
    icon: 'sort',
  ),
  QuestDef(
    id: 'match_sub_scores',
    scope: 'match',
    action: QuestAction.subScores,
    // Bring someone on and have them score. Half decision, half nerve — the
    // earlier you make the change the longer he has to find one.
    minDiv: _Div.al,
    target: _one,
    tags: [QuestTag.subs],
    feasible: _Feasible.hasBench,
    reward: (coins: 40),
    icon: 'star',
  ),
  QuestDef(
    id: 'match_gk_scores',
    scope: 'match',
    action: QuestAction.gkScores,
    // The daft one, and it works because scorer odds follow the SLOT a player
    // is fielded in: leave the keeper in goal and it will never happen, push
    // him up front and he shoots like a forward. You pay the off-position
    // rating penalty and an empty net for the privilege.
    minDiv: _Div.el,
    target: _one,
    tags: [QuestTag.scorerType],
    feasible: _Feasible.ownsGK,
    reward: (coins: 45),
    icon: 'goal',
  ),

  // ══ SEASON ════════════════════════════════════════════════════════════════
  QuestDef(
    id: 'season_merge',
    scope: 'season',
    action: QuestAction.mergeCount,
    minDiv: _Div.sl,
    target: _seasonMerge,
    reward: (coins: 70),
    icon: 'merge',
  ),
  QuestDef(
    id: 'season_scout',
    scope: 'season',
    action: QuestAction.scoutCount,
    minDiv: _Div.sl,
    target: _seasonScout,
    reward: (coins: 70),
    icon: 'userAdd',
  ),
  QuestDef(
    id: 'season_wins',
    scope: 'season',
    action: QuestAction.matchWin,
    // A season is fourteen matches, so this tops out at ten — demanding, but
    // not a near-perfect record.
    minDiv: _Div.sl,
    target: _seasonWins,
    tags: [QuestTag.run, QuestTag.wins],
    reward: (coins: 90),
    icon: 'trophy',
  ),
  QuestDef(
    id: 'season_clean_sheets',
    scope: 'season',
    action: QuestAction.cleanSheetsSeason,
    minDiv: _Div.sl,
    target: _halfPlus3,
    tags: [QuestTag.cleanSheets],
    reward: (coins: 90),
    icon: 'goal',
  ),
  QuestDef(
    id: 'season_goals',
    scope: 'season',
    action: QuestAction.goalsSeason,
    minDiv: _Div.sl,
    target: _seasonGoals,
    tags: [QuestTag.goals],
    reward: (coins: 80),
    icon: 'ball',
  ),
  QuestDef(
    id: 'season_reach_tier',
    scope: 'season',
    action: QuestAction.reachTier,
    // Targets the division's own player-tier ceiling, so it always asks for the
    // best card the league can actually produce.
    minDiv: _Div.sl,
    target: _divisionMaxPlayerTier,
    reward: (coins: 100),
    icon: 'star',
  ),
  QuestDef(
    id: 'season_win_run',
    scope: 'season',
    action: QuestAction.winRun,
    minDiv: _Div.al,
    target: _halfPlus3,
    tags: [QuestTag.run, QuestTag.wins],
    reward: (coins: 110),
    icon: 'flame',
  ),
  QuestDef(
    id: 'season_unbeaten_run',
    scope: 'season',
    action: QuestAction.unbeatenRun,
    minDiv: _Div.al,
    target: _halfPlus4,
    tags: [QuestTag.run, QuestTag.wins],
    reward: (coins: 100),
    icon: 'shield',
  ),
  QuestDef(
    id: 'season_clean_sheet_run',
    scope: 'season',
    action: QuestAction.cleanSheetRun,
    minDiv: _Div.rl,
    target: _halfPlus2,
    tags: [QuestTag.cleanSheets],
    reward: (coins: 120),
    icon: 'goal',
  ),
  QuestDef(
    id: 'season_merge_hard',
    scope: 'season',
    action: QuestAction.mergeCount,
    minDiv: _Div.el,
    target: _seasonMergeHard,
    reward: (coins: 130),
    icon: 'merge',
  ),
  QuestDef(
    id: 'season_wins_hard',
    scope: 'season',
    action: QuestAction.matchWin,
    minDiv: _Div.cl,
    target: _eleven,
    tags: [QuestTag.run, QuestTag.wins],
    reward: (coins: 150),
    icon: 'crown',
  ),

  // ── Season: things a player would otherwise never do ──────────────────────
  // Most of these are DERIVED — they read the save directly, because "rename a
  // player" and "get someone sponsored" have no event to hook.
  QuestDef(
    id: 'season_rename',
    scope: 'season',
    action: QuestAction.derived,
    minDiv: _Div.sl,
    target: _one,
    progress: _renamedCount,
    tags: [QuestTag.rename],
    reward: (coins: 70),
    icon: 'tag',
  ),
  QuestDef(
    id: 'season_rename_many',
    scope: 'season',
    action: QuestAction.derived,
    minDiv: _Div.rl,
    target: _three,
    progress: _renamedCount,
    tags: [QuestTag.rename],
    reward: (coins: 100),
    icon: 'tag',
  ),
  QuestDef(
    id: 'season_full_lineup',
    scope: 'season',
    action: QuestAction.derived,
    minDiv: _Div.sl,
    target: _eleven,
    progress: _lineupFilled,
    tags: [QuestTag.squadSize],
    reward: (coins: 70),
    icon: 'squad',
  ),
  QuestDef(
    id: 'season_squad_depth',
    scope: 'season',
    action: QuestAction.derived,
    minDiv: _Div.sl,
    target: _squadDepth,
    progress: _squadSize,
    tags: [QuestTag.squadSize],
    reward: (coins: 80),
    icon: 'userAdd',
  ),
  QuestDef(
    id: 'season_asset_tier',
    scope: 'season',
    action: QuestAction.derived,
    minDiv: _Div.sl,
    target: _assetTier,
    // A LEVEL, not a count: a club already on tier three is asked for four
    // rather than handed a finished quest. Eight is the ceiling.
    progress: _bestAssetTier,
    lift: 8,
    tags: [QuestTag.facility],
    reward: (coins: 90),
    icon: 'club',
  ),
  QuestDef(
    id: 'season_all_categories',
    scope: 'season',
    action: QuestAction.derived,
    minDiv: _Div.rl,
    target: _allCategories,
    progress: _ownedCategories,
    tags: [QuestTag.facility],
    reward: (coins: 120),
    icon: 'bank',
  ),
  QuestDef(
    id: 'season_discover',
    scope: 'season',
    action: QuestAction.derived,
    minDiv: _Div.sl,
    target: _plus4,
    progress: _discovered,
    baseline: true,
    feasible: _Feasible.newPlayersLeft,
    tags: [QuestTag.discovery],
    reward: (coins: 80),
    icon: 'book',
  ),

  // ── The arcade ────────────────────────────────────────────────────────────
  // Several mini-games ship with the app and, until this block, exactly one of
  // them was ever asked for. They are the best material the bank has for the
  // thing a football quest can't be — an objective that isn't "win the match" —
  // so each gets a quest and they share the ARCADE family, which keeps two of
  // them off the same track.
  //
  // Every target here is FLAT, and that is not laziness. Every other season
  // target climbs with the division because the squad climbs with it; these are
  // capped by the WALL CLOCK — each game sits behind a cooldown of five to
  // fifteen minutes, and a fourteen-match season played end to end takes well
  // under an hour. A promotion doesn't make the day longer.
  QuestDef(
    id: 'season_minigames',
    scope: 'season',
    action: QuestAction.derived,
    // Participation, but in a corner of the app most players never open — which
    // is the distinction the header draws.
    minDiv: _Div.sl,
    target: _three,
    progress: _penaltyRounds,
    baseline: true,
    tags: [QuestTag.arcade],
    reward: (coins: 70),
    icon: 'keepyUppys',
  ),
  QuestDef(
    id: 'season_through_ball',
    scope: 'season',
    action: QuestAction.derived,
    minDiv: _Div.sl,
    target: _two, // ten-minute cooldown
    progress: _throughBallRounds,
    baseline: true,
    tags: [QuestTag.arcade],
    feasible: _Feasible.throughBall,
    reward: (coins: 70),
    icon: 'target',
  ),
  QuestDef(
    id: 'season_keepy_uppys',
    scope: 'season',
    action: QuestAction.derived,
    minDiv: _Div.sl,
    target: _two, // ten-minute cooldown
    progress: _keepyUppysRounds,
    baseline: true,
    tags: [QuestTag.arcade],
    feasible: _Feasible.keepyUppys,
    reward: (coins: 70),
    icon: 'keepyUppys',
  ),
  QuestDef(
    id: 'season_pairs',
    scope: 'season',
    action: QuestAction.derived,
    // CLEARED, not played — the board is the whole game, and finishing it is
    // the only outcome worth asking for.
    minDiv: _Div.sl,
    target: _two, // eight-minute cooldown
    progress: _pairsCleared,
    baseline: true,
    tags: [QuestTag.arcade],
    feasible: _Feasible.pairs,
    reward: (coins: 80),
    icon: 'squad',
  ),
  QuestDef(
    id: 'season_whack',
    scope: 'season',
    action: QuestAction.derived,
    // CATCHES across the season, not rounds: the seven-minute cooldown is the
    // shortest in the bank, so counting rounds here would be the softest quest
    // in the game. A catch count survives a bad session and rewards a good one.
    minDiv: _Div.sl,
    target: _forty,
    progress: _whackCatches,
    baseline: true,
    tags: [QuestTag.arcade],
    feasible: _Feasible.whack,
    reward: (coins: 80),
    icon: 'invader',
  ),
  QuestDef(
    id: 'season_boot_room',
    scope: 'season',
    action: QuestAction.derived,
    // Hitting the tile TARGET once, not playing the board. ONE, where the other
    // arcade quests ask two: this is the only one that needs a good session
    // rather than a session, and it sits on the longest cooldown in the bank.
    minDiv: _Div.sl,
    target: _one, // twelve-minute cooldown
    progress: _bootRoomTargets,
    baseline: true,
    tags: [QuestTag.arcade],
    feasible: _Feasible.bootRoom,
    reward: (coins: 90),
    icon: 'bootRoom',
  ),
  QuestDef(
    id: 'season_perfect_training',
    scope: 'season',
    action: QuestAction.derived,
    minDiv: _Div.al,
    target: _one, // fifteen-minute cooldown
    progress: _perfectTrainings,
    baseline: true,
    tags: [QuestTag.arcade],
    feasible: _Feasible.training,
    reward: (coins: 100),
    icon: 'shield',
  ),
  QuestDef(
    id: 'season_penalties_scored',
    scope: 'season',
    action: QuestAction.derived,
    // The high-division penalty quest, and the one that replaces "score a
    // perfect round" up there. A perfect round is a LOTTERY whose odds get
    // worse as you climb — the keeper reads more shots at every division — so
    // five from five falls from about one round in five to one in twenty-five,
    // at the division where the player has least time to spare. A CUMULATIVE
    // count keeps what you score, so it stays a fair ask at every division while
    // still costing several visits.
    minDiv: _Div.rl,
    target: _plus5,
    progress: _penaltiesScored,
    baseline: true,
    tags: [QuestTag.arcade],
    reward: (coins: 100),
    icon: 'ball',
  ),
  QuestDef(
    id: 'season_perfect_penalty',
    scope: 'season',
    action: QuestAction.derived,
    // Capped at Regional, where five from five is still a reasonable round
    // rather than the lottery it becomes at Champions.
    minDiv: _Div.sl,
    maxDiv: _Div.rl,
    target: _one,
    progress: _perfectPenalties,
    baseline: true,
    tags: [QuestTag.arcade],
    reward: (coins: 110),
    icon: 'target',
  ),
  QuestDef(
    id: 'season_sponsor',
    scope: 'season',
    action: QuestAction.derived,
    minDiv: _Div.al,
    target: _one,
    progress: _sponsoredCount,
    tags: [QuestTag.sponsor],
    reward: (coins: 90),
    icon: 'handshake',
  ),
  QuestDef(
    id: 'season_sponsor_many',
    scope: 'season',
    action: QuestAction.derived,
    minDiv: _Div.nl,
    target: _three,
    progress: _sponsoredCount,
    tags: [QuestTag.sponsor],
    reward: (coins: 130),
    icon: 'handshake',
  ),
  QuestDef(
    id: 'season_transfer_accept',
    scope: 'season',
    action: QuestAction.derived,
    minDiv: _Div.al,
    target: _one,
    progress: _transfersAccepted,
    baseline: true,
    tags: [QuestTag.transfer],
    reward: (coins: 90),
    icon: 'scales',
  ),
  QuestDef(
    id: 'season_transfer_decline',
    scope: 'season',
    action: QuestAction.derived,
    minDiv: _Div.al,
    target: _two,
    progress: _transfersDeclined,
    baseline: true,
    tags: [QuestTag.transfer],
    reward: (coins: 80),
    icon: 'scales',
  ),
  QuestDef(
    id: 'season_sponsor_decline',
    scope: 'season',
    action: QuestAction.derived,
    // Saying no is a decision, and the only quest in the bank that rewards
    // turning money down.
    minDiv: _Div.al,
    target: _one,
    progress: _sponsorsDeclined,
    baseline: true,
    tags: [QuestTag.sponsor],
    reward: (coins: 80),
    icon: 'handshake',
  ),
  QuestDef(
    id: 'season_facility_invest',
    scope: 'season',
    action: QuestAction.derived,
    // Taps, not tiers: season_asset_tier asks for the LEVEL, this asks for the
    // habit of feeding the club grid, and they share a family so only one runs.
    minDiv: _Div.sl,
    target: _facilityInvest,
    progress: _facilityTaps,
    baseline: true,
    tags: [QuestTag.facility],
    reward: (coins: 90),
    icon: 'club',
  ),
  QuestDef(
    id: 'season_away_wins',
    scope: 'season',
    action: QuestAction.awayWins,
    minDiv: _Div.al,
    target: _halfPlus2,
    tags: [QuestTag.wins],
    reward: (coins: 100),
    icon: 'globe',
  ),
  QuestDef(
    id: 'season_underdog_wins',
    scope: 'season',
    action: QuestAction.underdogWins,
    minDiv: _Div.rl,
    target: _thirdPlus1,
    tags: [QuestTag.wins],
    reward: (coins: 120),
    icon: 'swords',
  ),
  QuestDef(
    id: 'season_comebacks',
    scope: 'season',
    action: QuestAction.comebackWins,
    minDiv: _Div.nl,
    target: _thirdPlus1,
    tags: [QuestTag.wins],
    reward: (coins: 120),
    icon: 'flame',
  ),
  QuestDef(
    id: 'season_home_wins',
    scope: 'season',
    action: QuestAction.homeWins,
    // Seven of the fourteen are at home, so this tops out at five of seven.
    minDiv: _Div.sl,
    target: _thirdPlus3,
    tags: [QuestTag.wins],
    reward: (coins: 90),
    icon: 'club',
  ),
  QuestDef(
    id: 'season_scoring_run',
    scope: 'season',
    action: QuestAction.scoringRun,
    // A run of matches scored in — which a beaten team can extend, so it is
    // pointedly NOT a winning run and doesn't sit in that family.
    minDiv: _Div.sl,
    target: _halfPlus4,
    tags: [QuestTag.goals],
    reward: (coins: 100),
    icon: 'ball',
  ),
  QuestDef(
    id: 'season_hat_tricks',
    scope: 'season',
    action: QuestAction.hatTricks,
    minDiv: _Div.el,
    target: _quarterPlus1,
    tags: [QuestTag.goals, QuestTag.scorers],
    reward: (coins: 140),
    icon: 'target',
  ),
];

// ── Target curves ───────────────────────────────────────────────────────────
// Named rather than inlined because Dart closures cannot be const, and a named
// function keeps the bank readable at the call site.

int _one(int _) => 1;
int _two(int _) => 2;
int _three(int _) => 3;
int _five(int _) => 5;
int _eleven(int _) => 11;
int _fifteen(int _) => 15;
int _forty(int _) => 40;
int _identity(int d) => d;
int _scoreScaling(int d) => 3 + d ~/ 2;
int _marginScaling(int d) => 2 + d ~/ 2;
int _scoreMany(int d) => 5 + (d - 4);
int _seasonMerge(int d) => 15 + d * 8;
int _seasonScout(int d) => 10 + d * 5;
int _seasonWins(int d) => 4 + d;
int _seasonGoals(int d) => 20 + d * 6;
int _seasonMergeHard(int d) => 60 + (d - 4) * 20;
int _halfPlus2(int d) => 2 + d ~/ 2;
int _halfPlus3(int d) => 3 + d ~/ 2;
int _halfPlus4(int d) => 4 + d ~/ 2;
int _thirdPlus1(int d) => 1 + d ~/ 3;
int _thirdPlus3(int d) => 3 + d ~/ 3;
int _quarterPlus1(int d) => 1 + d ~/ 4;
int _squadDepth(int d) => 12 + d * 2;
int _assetTier(int d) => math.min(2 + d, 8);
int _plus4(int d) => 4 + d;
int _plus5(int d) => 5 + d;
int _facilityInvest(int d) => 4 + d * 2;
int _allCategories(int _) => AssetCategory.all.length;
int _divisionMaxPlayerTier(int d) =>
    d >= 0 && d < divisions.length ? divisions[d].maxPlayerTier : 2;

// ── Named stat readers ──────────────────────────────────────────────────────

num _penaltyRounds(Map<String, dynamic>? s) => _stat(s, 'penaltyRounds');
num _throughBallRounds(Map<String, dynamic>? s) => _stat(s, 'throughBallRounds');
num _keepyUppysRounds(Map<String, dynamic>? s) => _stat(s, 'keepyUppysRounds');
num _pairsCleared(Map<String, dynamic>? s) => _stat(s, 'pairsCleared');
num _whackCatches(Map<String, dynamic>? s) => _stat(s, 'whackCatches');
num _bootRoomTargets(Map<String, dynamic>? s) => _stat(s, 'bootRoomTargets');
num _perfectTrainings(Map<String, dynamic>? s) => _stat(s, 'perfectTrainings');
num _penaltiesScored(Map<String, dynamic>? s) => _stat(s, 'penaltiesScored');
num _perfectPenalties(Map<String, dynamic>? s) => _stat(s, 'perfectPenalties');
num _transfersAccepted(Map<String, dynamic>? s) => _stat(s, 'transfersAccepted');
num _transfersDeclined(Map<String, dynamic>? s) => _stat(s, 'transfersDeclined');
num _sponsorsDeclined(Map<String, dynamic>? s) => _stat(s, 'sponsorsDeclined');

final Map<String, QuestDef> _byId = {for (final q in questBank) q.id: q};

/// A quest definition by id, or null for an unknown one.
QuestDef? getQuest(String? id) => id == null ? null : _byId[id];

/// How many of each scope are active at once.
const int matchQuestCount = 3;
const int seasonQuestCount = 3;

/// How many recently-used ids to hold back from the next roll, so the same
/// quest doesn't reappear immediately. Trimmed automatically when the eligible
/// pool is too small to honour it.
const int noRepeatWindow = 8;

/// A quest's target for a division.
///
/// Always at least one, so a curve can never produce an instantly-complete
/// quest at the bottom of the ladder.
int resolveTarget(QuestDef quest, int divIdx) {
  final raw = quest.target(divIdx);
  return raw.isFinite ? math.max(1, raw) : 1;
}

/// Is this quest available at the given division index?
bool isEligible(QuestDef quest, int divIdx) {
  if (divIdx < 0) return false;
  final min = divisionIndex(quest.minDiv);
  if (min >= 0 && divIdx < min) return false;
  final maxDiv = quest.maxDiv;
  if (maxDiv != null) {
    final max = divisionIndex(maxDiv);
    if (max >= 0 && divIdx > max) return false;
  }
  return true;
}
