/// Match quests: deciding at full time what passed, and what a live tracker can
/// honestly say before the whistle. Ported from the match half of
/// `../merge-empire-fc/src/engine/questEngine.js`.
///
/// Split from the rolling half because they are two different jobs against two
/// different inputs — that one reads the SAVE to decide what to hand out, this
/// one reads a match RESULT to decide what happened.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/quests.dart';
import 'package:merge_empire_fc/engine/quest_engine.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/sorting.dart';
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;
bool _flag(Object? v) => v == true;

/// A match result, as the simulation writes it.
///
/// Kept as a raw map for the same reason the save is: it crosses the boundary
/// between the sim, the match screen and this file, and every one of them adds
/// fields the others don't read.
typedef MatchResult = Map<String, dynamic>;

int _minute(Object? ev) => _num(_map(ev)?['minute'])?.toInt() ?? 0;

/// Every goal in the match, earliest first.
List<Map<String, dynamic>> _goalEvents(MatchResult? result) {
  final events = result?['events'];
  if (events is! List) return const [];
  final goals = [
    for (final e in events)
      if (_map(e)?['type'] == 'goal') _map(e)!,
  ];
  return stableSorted(goals, (a, b) => _minute(a) - _minute(b));
}

/// Our goals only, in minute order.
///
/// `home` is ALWAYS the player's side, whatever the venue — the sim uses it for
/// the player's goals and the fixture's own `isHome` for where it was played.
List<Map<String, dynamic>> _ourGoals(MatchResult? result) =>
    [for (final e in _goalEvents(result)) if (e['team'] == 'home') e];

/// A scorer's card, looked up in the grid by instance id.
Map<String, dynamic>? _scorerCard(
  Map<String, dynamic>? state,
  Map<String, dynamic>? ev,
) {
  final id = ev?['scorerInstanceId'];
  if (id == null) return null;
  final cells = _map(state?['grid'])?['cells'];
  if (cells is! List) return null;
  for (final c in cells) {
    if (_map(c)?['instanceId'] == id) return _map(c);
  }
  return null;
}

/// Did a player whose DEFINITION position is [position] score?
///
/// The definition, not the slot: a defender played up front is still a defender
/// for "score with a defender". The SLOT drives his odds of scoring, which is
/// the lever the player pulls to make these quests happen.
bool _positionScored(
  Map<String, dynamic>? state,
  MatchResult? result,
  String position,
) {
  for (final ev in _ourGoals(result)) {
    final card = _scorerCard(state, ev);
    if (card == null) continue;
    if (getPlayerDef(card['definitionId'] as String?)?.position == position) {
      return true;
    }
  }
  return false;
}

/// Won after conceding the opening goal.
bool _isComeback(MatchResult? result) {
  if (!_flag(result?['won'])) return false;
  final goals = _goalEvents(result);
  return goals.isNotEmpty && goals.first['team'] == 'away';
}

/// A goal at 80' or later that turned level-or-behind into ahead, in a match we
/// won.
bool _hasLateWinner(MatchResult? result) {
  if (!_flag(result?['won'])) return false;
  var ours = 0;
  var theirs = 0;
  for (final ev in _goalEvents(result)) {
    final wasAhead = ours > theirs;
    if (ev['team'] == 'home') {
      ours++;
    } else {
      theirs++;
    }
    if (ev['team'] == 'home' &&
        !wasAhead &&
        ours > theirs &&
        _minute(ev) >= 80) {
      return true;
    }
  }
  return false;
}

/// Two of our goals inside a [window]-minute stretch.
///
/// Reads consecutive pairs because the feed is already sorted by minute — if
/// any adjacent pair is close enough, some pair is.
bool _hasQuickDouble(MatchResult? result, int window) {
  final mins = [for (final e in _ourGoals(result)) _minute(e)];
  for (var i = 1; i < mins.length; i++) {
    if (mins[i] - mins[i - 1] <= window) return true;
  }
  return false;
}

/// Did a player brought ON in this match score?
bool _substituteScored(MatchResult? result) {
  final raw = result?['subbedOnIds'];
  if (raw is! List || raw.isEmpty) return false;
  final on = {for (final id in raw) '$id'};
  return _ourGoals(result).any((ev) => on.contains('${ev['scorerInstanceId']}'));
}

/// Won with [strategy] on the dial at the final whistle.
///
/// The FINAL tactic, not merely one that was tried: the quest is "win playing
/// this", and somebody who flicked to it at 89' with the game already won
/// hasn't done that.
bool _wonPlaying(MatchResult? result, String? strategy) =>
    _flag(result?['won']) && result?['finalStrategy'] == strategy;

/// How many distinct tactics were used across the match.
int _tacticsTried(MatchResult? result) {
  final used = result?['strategiesUsed'];
  if (used is! List) return 0;
  return {for (final s in used) '$s'}.length;
}

/// Scored in both halves.
bool _scoredBothHalves(MatchResult? result) {
  final ours = _ourGoals(result);
  return ours.any((e) => _minute(e) <= 45) && ours.any((e) => _minute(e) > 45);
}

/// Won a match in which the coach asked for a change and you didn't make it.
///
/// "Defy" needs him to have ASKED for something — a suggestion the player was
/// already playing is agreement, not an instruction, so only a suggestion that
/// DIFFERED from the tactic on the dial at that moment is recorded. That
/// distinction is the whole fix: the coach revises his advice as the match
/// turns and frequently ends up recommending the tactic you chose before
/// kick-off, so reading only the LAST thing he said failed the quest for a
/// player who never listened to him at all.
///
/// So: he asked for at least one change, you never switched to what he was
/// asking for at the time, and you didn't end the match playing something he
/// had asked for either — the last clause catches a player who ignored "go
/// attacking" at 20' and then drifted into attacking on their own.
///
/// An old result has no list; it falls back to the single last-suggestion field
/// so a match in flight when the app updates still resolves.
bool _defiedCoach(MatchResult? result) {
  if (!_flag(result?['won'])) return false;

  final askedRaw = result?['coachAskedFor'];
  final asked = <String>[
    if (askedRaw is List && askedRaw.isNotEmpty)
      for (final s in askedRaw) '$s'
    else if (result?['coachSuggestedStrategy'] case final String s) s,
  ];
  if (asked.isEmpty) return false;
  if (_flag(result?['followedCoachSuggestion'])) return false;

  final finalStrategy = result?['finalStrategy'];
  return finalStrategy == null || !asked.contains('$finalStrategy');
}

/// Did a card whose DEFINITION position is GK score?
///
/// Only reachable by fielding a keeper outfield: scorer odds follow the slot a
/// player is played in, so a keeper left in goal keeps GK's tiny weight and
/// effectively never scores, while one pushed to FWD shoots like a forward.
/// That is the whole quest — it costs the off-position rating penalty and an
/// empty net.
bool _keeperScored(Map<String, dynamic>? state, MatchResult? result) =>
    _positionScored(state, result, 'GK');

/// Goals by scorer instance id, for hat-tricks and spread-the-load quests.
Map<String, int> _goalsByScorer(MatchResult? result) {
  final counts = <String, int>{};
  for (final ev in _ourGoals(result)) {
    final id = ev['scorerInstanceId'];
    if (id == null) continue;
    counts['$id'] = (counts['$id'] ?? 0) + 1;
  }
  return counts;
}

/// The running score at half time, from the goal feed.
({int ours, int theirs}) _halfTimeScore(MatchResult? result) {
  var ours = 0;
  var theirs = 0;
  for (final ev in _goalEvents(result)) {
    if (_minute(ev) > 45) break;
    if (ev['team'] == 'home') {
      ours++;
    } else {
      theirs++;
    }
  }
  return (ours: ours, theirs: theirs);
}

/// Won despite the opponent being rated higher on the day.
bool _wonAsUnderdog(MatchResult? result) =>
    _flag(result?['won']) &&
    (_num(result?['effectiveOppRating']) ?? 0) >
        (_num(result?['effectiveSquadRating']) ?? 0);

/// Evaluate one match quest against a finished match.
bool evaluateMatchQuest(
  Map<String, dynamic>? state,
  QuestDef def,
  int target,
  MatchResult? result,
) {
  final ourGoals = _num(result?['homeGoals'])?.toInt() ?? 0;
  final theirGoals = _num(result?['awayGoals'])?.toInt() ?? 0;

  switch (def.action) {
    case QuestAction.winThisMatch:
      return _flag(result?['won']);
    case QuestAction.cleanSheet:
      return theirGoals == 0;
    case QuestAction.goalsInMatch:
      return ourGoals >= target;
    case QuestAction.winMargin:
      return _flag(result?['won']) && (ourGoals - theirGoals) >= target;
    case QuestAction.noInjury:
      return (_num(result?['injuryCount'])?.toInt() ?? 0) == 0;
    case QuestAction.awayWin:
      return _flag(result?['won']) && result?['isHome'] == false;
    case QuestAction.defScores:
      return _positionScored(state, result, 'DEF');
    case QuestAction.midScores:
      return _positionScored(state, result, 'MID');
    case QuestAction.quickDouble:
      return _hasQuickDouble(result, target);
    // The tactic rides on the DEFINITION rather than the target, because the
    // target is a number the UI interpolates and a tactic id is not.
    case QuestAction.tacticWin:
      return _wonPlaying(result, def.strategy);
    case QuestAction.tacticVariety:
      return _tacticsTried(result) >= target;
    case QuestAction.subsMade:
      return (_num(result?['subsUsed'])?.toInt() ?? 0) >= target;
    case QuestAction.subScores:
      return _substituteScored(result);
    case QuestAction.comebackWin:
      return _isComeback(result);
    case QuestAction.lateWinner:
      return _hasLateWinner(result);
    case QuestAction.bothHalves:
      return _scoredBothHalves(result);
    case QuestAction.defyCoach:
      return _defiedCoach(result);
    case QuestAction.gkScores:
      return _keeperScored(state, result);
    case QuestAction.underdogWin:
      return _wonAsUnderdog(result);
    // "Concede none with a back line that had no business keeping them out."
    // Measured against the opponent's attack rather than a fixed number, so it
    // means the same thing at every division.
    case QuestAction.weakDefCleanSheet:
      return theirGoals == 0 &&
          (_num(result?['ourDefenceRating']) ?? 0) <
              (_num(result?['effOppAttackRating']) ?? 0);
    case QuestAction.shortHandedWin:
      final events = result?['events'];
      return _flag(result?['won']) &&
          events is List &&
          events.any((e) => _map(e)?['type'] == 'no_sub');
    case QuestAction.winAfterInjury:
      return _flag(result?['won']) &&
          (_num(result?['injuryCount'])?.toInt() ?? 0) >= 1;
    case QuestAction.scoreEarly:
      return _ourGoals(result).any((e) => _minute(e) <= target);
    case QuestAction.scoreLate:
      return _ourGoals(result).any((e) => _minute(e) >= 88);
    case QuestAction.hatTrick:
      return _goalsByScorer(result).values.any((n) => n >= target);
    case QuestAction.threeScorers:
      return _goalsByScorer(result).length >= target;
    case QuestAction.halftimeDeficitWin:
      final ht = _halfTimeScore(result);
      return _flag(result?['won']) && ht.theirs > ht.ours;
    case QuestAction.noTacticChangeWin:
      return _flag(result?['won']) && !_flag(result?['strategyChanged']);
    case QuestAction.awayCleanSheet:
      return _flag(result?['won']) &&
          result?['isHome'] == false &&
          theirGoals == 0;
    case QuestAction.concedeAtMost:
      return theirGoals <= target;
    case QuestAction.winSecondHalf:
      final ht = _halfTimeScore(result);
      return (ourGoals - ht.ours) > (theirGoals - ht.theirs);
    case QuestAction.veteranScores:
      return _ourGoals(result).any((ev) {
        final card = _scorerCard(state, ev);
        return card != null &&
            (_num(card['seasonsPlayed'])?.toInt() ?? 0) >= target;
      });
    default:
      return false;
  }
}

// ── Live status, for the in-match tracker ───────────────────────────────────

/// The three states a match quest can be in WHILE the match is still running.
///
/// `pending` is the honest answer for anything that can't be called yet — most
/// quests hinge on the final result and are undecided until the whistle.
enum QuestLive { done, missed, pending }

/// A result-shaped snapshot of a match IN PROGRESS, for [liveMatchQuestStatus].
///
/// [firedEvents] is the prefix of the result's events the viewer has actually
/// shown — NOT the whole list. The sim writes all ninety minutes up front, so
/// reading the result directly would have the tracker ticking a quest off for a
/// goal that hasn't been played yet.
///
/// Goals and injuries are recounted from that prefix rather than copied off the
/// result for the same reason, and the verdict is forced false until the clock
/// is up: the sim's answer is already sitting on the result object, and letting
/// it through would settle every "win the match" quest at kick-off.
MatchResult partialMatchResult(
  MatchResult? result,
  List<dynamic>? firedEvents,
  int minute, [
  int duration = 90,
]) {
  final events = firedEvents ?? const [];
  var homeGoals = 0;
  var awayGoals = 0;
  var injuryCount = 0;

  for (final raw in events) {
    final ev = _map(raw);
    if (ev?['type'] == 'goal') {
      if (ev!['team'] == 'home') {
        homeGoals++;
      } else {
        awayGoals++;
      }
    } else if (ev?['type'] == 'injury') {
      injuryCount++;
    }
  }

  // Once the whistle has gone the result itself is authoritative again, and the
  // recount is only a fallback for a caller with no tallies on it. Before then
  // the recount is the ONLY honest source: the tallies on the result describe a
  // match that hasn't finished being watched.
  final finished = minute >= duration;
  Object? pick(Object? own, int counted) => finished ? (own ?? counted) : counted;

  return <String, dynamic>{
    ...?result,
    'events': events,
    'homeGoals': pick(result?['homeGoals'], homeGoals),
    'awayGoals': pick(result?['awayGoals'], awayGoals),
    'injuryCount': pick(result?['injuryCount'], injuryCount),
    'minute': minute,
    'duration': duration,
    'won': finished && _flag(result?['won']),
    'drawn': finished && _flag(result?['drawn']),
  };
}

/// Where a match quest stands part way through the match: won already, gone
/// already, or still live.
///
/// This is NOT a second implementation of [evaluateMatchQuest] and must never
/// grow into one. That function answers "did it pass", once, off a finished
/// match. This answers a different question — "can it still happen" — and only
/// two kinds of quest can be answered early:
///
///   done    the quest asks for something that HAPPENED, and a thing that has
///           happened cannot un-happen. A goal is scored, a defender scored it,
///           three different players are on the sheet.
///   missed  the quest asks for something that can no longer happen. The clean
///           sheet is gone the instant they score; "score inside 15 minutes" is
///           gone at 16'; a tactic change kills "win without touching the dial".
///
/// Everything else is `pending`, because it hinges on the final score — "win by
/// two" is not missed at 0-0 in the 89th, it is simply undecided, and guessing
/// there would put a cross against a quest the player then goes and wins.
///
/// Once the clock is up this hands over to [evaluateMatchQuest], so the tracker
/// and the full-time summary can never disagree about the same quest.
QuestLive liveMatchQuestStatus(
  Map<String, dynamic>? state,
  QuestDef? def,
  int target,
  MatchResult? partial,
) {
  if (def == null) return QuestLive.pending;
  final minute = _num(partial?['minute'])?.toInt() ?? 0;
  final duration = _num(partial?['duration'])?.toInt() ?? 90;
  if (minute >= duration) {
    return evaluateMatchQuest(state, def, target, partial)
        ? QuestLive.done
        : QuestLive.missed;
  }

  final theirGoals = _num(partial?['awayGoals'])?.toInt() ?? 0;
  final ourGoals = _num(partial?['homeGoals'])?.toInt() ?? 0;
  final pastHalfTime = minute > 45;

  QuestLive settled(bool won) => won ? QuestLive.done : QuestLive.pending;
  QuestLive alive(bool ok) => ok ? QuestLive.pending : QuestLive.missed;

  switch (def.action) {
    // ── Done the moment it happens ────────────────────────────────────────
    case QuestAction.goalsInMatch:
      return settled(ourGoals >= target);
    case QuestAction.defScores:
      return settled(_positionScored(state, partial, 'DEF'));
    case QuestAction.midScores:
      return settled(_positionScored(state, partial, 'MID'));
    case QuestAction.tacticVariety:
      // Counting up as the dial is turned, and it can't go down.
      return settled(_tacticsTried(partial) >= target);
    case QuestAction.subsMade:
      return settled((_num(partial?['subsUsed'])?.toInt() ?? 0) >= target);
    case QuestAction.subScores:
      return settled(_substituteScored(partial));
    case QuestAction.quickDouble:
      // Two goals close together is a thing that HAPPENS and can't un-happen.
      // It can't be ruled out early either — there is time for a quick two
      // until the last whistle.
      return settled(_hasQuickDouble(partial, target));
    case QuestAction.gkScores:
      return settled(_keeperScored(state, partial));
    case QuestAction.veteranScores:
      return settled(
        _ourGoals(partial).any((ev) {
          final card = _scorerCard(state, ev);
          return card != null &&
              (_num(card['seasonsPlayed'])?.toInt() ?? 0) >= target;
        }),
      );
    case QuestAction.hatTrick:
      return settled(_goalsByScorer(partial).values.any((n) => n >= target));
    case QuestAction.threeScorers:
      return settled(_goalsByScorer(partial).length >= target);
    case QuestAction.scoreLate:
      return settled(_ourGoals(partial).any((e) => _minute(e) >= 88));

    // ── Done the moment it happens, and can also run out of time ──────────
    case QuestAction.scoreEarly:
      if (_ourGoals(partial).any((e) => _minute(e) <= target)) {
        return QuestLive.done;
      }
      return alive(minute <= target);
    case QuestAction.bothHalves:
      final ours = _ourGoals(partial);
      final first = ours.any((e) => _minute(e) <= 45);
      final second = ours.any((e) => _minute(e) > 45);
      if (first && second) return QuestLive.done;
      return alive(first || !pastHalfTime);

    // ── Can only be LOST early; winning them needs the final whistle ──────
    case QuestAction.cleanSheet:
      return alive(theirGoals == 0);
    case QuestAction.concedeAtMost:
      return alive(theirGoals <= target);
    case QuestAction.awayCleanSheet:
      return alive(partial?['isHome'] == false && theirGoals == 0);
    case QuestAction.weakDefCleanSheet:
      // The rating half is fixed at kick-off, so a back line that isn't
      // actually the underdog kills this one before a ball is kicked.
      return alive(
        theirGoals == 0 &&
            (_num(partial?['ourDefenceRating']) ?? 0) <
                (_num(partial?['effOppAttackRating']) ?? 0),
      );
    case QuestAction.noInjury:
      return alive((_num(partial?['injuryCount'])?.toInt() ?? 0) == 0);
    case QuestAction.awayWin:
      return alive(partial?['isHome'] == false);
    case QuestAction.underdogWin:
      return alive(
        (_num(partial?['effectiveOppRating']) ?? 0) >
            (_num(partial?['effectiveSquadRating']) ?? 0),
      );
    case QuestAction.noTacticChangeWin:
      return alive(!_flag(partial?['strategyChanged']));
    case QuestAction.defyCoach:
      return alive(!_flag(partial?['followedCoachSuggestion']));
    case QuestAction.comebackWin:
      // Scoring first is exactly what a comeback isn't.
      final goals = _goalEvents(partial);
      return alive(goals.isEmpty || goals.first['team'] != 'home');
    case QuestAction.halftimeDeficitWin:
      if (!pastHalfTime) return QuestLive.pending;
      final ht = _halfTimeScore(partial);
      return alive(ht.theirs > ht.ours);

    // WIN_MARGIN, LATE_WINNER, WIN_SECOND_HALF, SHORT_HANDED_WIN,
    // WIN_AFTER_INJURY and WIN_THIS_MATCH all land here: every one can still be
    // won with the last kick, so there is nothing honest to show but "in play".
    default:
      return QuestLive.pending;
  }
}

/// One row of the full-time quest summary.
typedef MatchQuestOutcome = ({
  String id,
  String icon,
  int target,
  bool passed,
  QuestGrant granted,
});

/// Resolve the whole match track at full time, and feed the same result into
/// the season track.
///
/// Match quests AUTO-PAY: the player has already tapped through a match, and a
/// second tap to claim is friction with no upside. Season quests still require
/// a claim — that is what makes the badge a reason to come back.
///
/// Returns ALL three with what each paid, because the result screen lists them
/// all so the player sees what they MISSED as well as what they won. A caller
/// that only wants payouts filters on `passed`.
List<MatchQuestOutcome> resolveMatchQuests(
  Map<String, dynamic> state,
  MatchResult? result,
) {
  final q = ensureQuests(state);
  final match = _map(q['match'])!;
  final results = <MatchQuestOutcome>[];

  final active = match['active'];
  for (final raw in (active is List ? active : const [])) {
    final inst = _map(raw);
    if (inst == null) continue;
    final def = getQuest(inst['id'] as String?);
    if (def == null) continue;

    final target = _num(inst['target'])?.toInt() ?? 0;
    var passed = false;
    try {
      passed = inst['completed'] != true &&
          evaluateMatchQuest(state, def, target, result);
    } catch (_) {
      passed = false;
    }

    if (!passed) {
      results.add((
        id: def.id,
        icon: def.icon,
        target: target,
        passed: false,
        granted: (coins: 0),
      ));
      continue;
    }

    inst['completed'] = true;
    inst['progress'] = target;
    inst['claimedAt'] = now();
    final granted = payQuestReward(state, def);
    // The target rides along so the result screen can interpolate the quest
    // text — which is per-division — without re-reading the save.
    results.add((
      id: def.id,
      icon: def.icon,
      target: target,
      passed: true,
      granted: granted,
    ));
    emit('quest:completed', {
      'quest': inst,
      'def': def,
      'scope': 'match',
      'granted': granted,
    });
  }

  applyMatchToSeasonQuests(state, result);

  if (_flag(result?['isCup'])) {
    // A cup tie is NOT the fixture these quests were rolled for. Cups sit
    // between league games and never move the season counter, so the fixture
    // key doesn't change — and a cup round is always played at home. Clearing
    // the track here meant a cup tie could eat "win away from home": a quest
    // the match it was spent on could not possibly have passed.
    //
    // So a cup tie PAYS what it happened to satisfy — that is why it resolves
    // at all — and leaves the rest standing for the league match they were
    // drawn for. Dropping the finished ones lets the roll top the track back up
    // for the same fixture, so the player gets three live quests again.
    match['active'] = [
      for (final c in (active is List ? active : const []))
        if (_map(c)?['completed'] != true) c,
    ];
    return results;
  }

  // The league fixture is played — the next one rolls a fresh three.
  match['fixtureKey'] = null;
  match['active'] = <dynamic>[];

  return results;
}

/// Push a finished match into the season track: the accumulating counters and
/// the four streaks.
///
/// Split from [resolveMatchQuests] so it stays readable and can be tested on
/// its own.
void applyMatchToSeasonQuests(
  Map<String, dynamic> state,
  MatchResult? result,
) {
  final q = ensureQuests(state);
  final ourGoals = _num(result?['homeGoals'])?.toInt() ?? 0;
  final theirGoals = _num(result?['awayGoals'])?.toInt() ?? 0;
  final won = _flag(result?['won']);
  final drawn = _flag(result?['drawn']);
  final cleanSheet = theirGoals == 0;

  // PLAY_MATCHES and MATCH_WIN are deliberately NOT advanced here. They are
  // owned by the call site that also feeds the event reward track — counting
  // them in both places would double every match. Only the quest-specific,
  // result-derived counters live here.
  if (ourGoals > 0) advanceQuest(state, QuestAction.goalsSeason, ourGoals);
  if (cleanSheet) advanceQuest(state, QuestAction.cleanSheetsSeason);
  if (_wonAsUnderdog(result)) advanceQuest(state, QuestAction.underdogWins);
  if (_isComeback(result)) advanceQuest(state, QuestAction.comebackWins);
  if (won && result?['isHome'] == false) {
    advanceQuest(state, QuestAction.awayWins);
  }
  if (won && result?['isHome'] != false) {
    advanceQuest(state, QuestAction.homeWins);
  }
  if (_goalsByScorer(result).values.any((n) => n >= 3)) {
    advanceQuest(state, QuestAction.hatTricks);
  }

  final streaks = _map(q['streaks'])!;
  streaks['cleanSheet'] =
      cleanSheet ? (_num(streaks['cleanSheet']) ?? 0) + 1 : 0;
  streaks['win'] = won ? (_num(streaks['win']) ?? 0) + 1 : 0;
  streaks['unbeaten'] =
      (won || drawn) ? (_num(streaks['unbeaten']) ?? 0) + 1 : 0;
  // A scoring run survives a defeat — it breaks on a blank, not on a loss.
  streaks['scoring'] = ourGoals > 0 ? (_num(streaks['scoring']) ?? 0) + 1 : 0;

  setStreakProgress(
    state,
    QuestAction.cleanSheetRun,
    _num(streaks['cleanSheet']) ?? 0,
  );
  setStreakProgress(state, QuestAction.winRun, _num(streaks['win']) ?? 0);
  setStreakProgress(
    state,
    QuestAction.unbeatenRun,
    _num(streaks['unbeaten']) ?? 0,
  );
  setStreakProgress(
    state,
    QuestAction.scoringRun,
    _num(streaks['scoring']) ?? 0,
  );
}
