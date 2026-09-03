/// Starting a match, and settling it afterwards.
///
/// The gap between the fixture list and the match screen. Three steps, and the
/// ORDER of the last two is a decision the JS records rather than an accident:
///
/// 1. [matchStartBlocked] — cooldown, squad size, season over, energy.
/// 2. [beginMatch] — spends the pip and runs `simulateMatch`.
/// 3. `finalizeMatchOutcome` at FULL TIME, while the screen is still up, then
///    `applyMatchRewards` only once the player DISMISSES it. The rewards are
///    deferred on purpose: the doubling offer lives on the closing screen, and
///    crediting coins before it is answered would make the offer meaningless.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/engine/energy_engine.dart';
import 'package:merge_empire_fc/engine/goal_model.dart';
import 'package:merge_empire_fc/engine/match_orchestration.dart';
import 'package:merge_empire_fc/engine/tutorial_engine.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/quest_engine.dart';
import 'package:merge_empire_fc/engine/quest_match.dart';
import 'package:merge_empire_fc/state/card_instance.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

List<CardInstance?> _cells(Map<String, dynamic>? state) {
  final cells = _map(state?['grid'])?['cells'];
  if (cells is! List) return const [];
  return [for (final c in cells) CardInstance.from(c)];
}

/// Why a match cannot start, or null when it can.
///
/// One of: `season_over`, `squad_too_small`, `cooldown`, `no_energy`.
String? matchStartBlocked(Map<String, dynamic> state) {
  final prog = _map(state['progression']);
  if (prog?['seasonComplete'] == true) return 'season_over';
  // **A LINEUP OF INJURED MEN IS NOT A SIDE.** `hasEnoughPlayers` counts
  // HEALTHY cards on the grid and had no caller in `lib/` at all, which left
  // three shapes of "can we field a side" in the tree with only the narrowest
  // of them wired: filled lineup SLOTS, which an injured card still fills.
  // The JS's play button ANDs the two (`LeagueScreen.js`, `_updatePlayBtn`),
  // and the gate belongs at the SCREEN rather than in `canPlayMatch` — that is
  // a parity function whose refusals are pinned against the JS's own.
  if (!hasEnoughPlayers(_cells(state))) return 'squad_too_small';
  if (!canPlayMatch(state)) {
    // canPlayMatch folds three refusals together; separate them so the button
    // can say which one it is rather than just going grey.
    final lineup = _map(state['squad'])?['lineup'];
    if (lineup is List) {
      final filled = lineup
          .where((s) => _map(s)?['cardInstanceId'] != null)
          .length;
      if (filled < minSquadPlayers) return 'squad_too_small';
    }
    return 'cooldown';
  }
  // Pro mode charges no pip: fatigue is per player there, and it never locks
  // anyone out — a tired side just loses more.
  if (_map(state['settings'])?['hardMode'] == true) return null;
  if (!canSpendEnergy(state, Energy.matchCost)) return 'no_energy';
  return null;
}

/// **WHO IS IN THE STARTING ELEVEN AND NOT FIT TO BE, by name.**
///
/// Empty is the ordinary answer: the sim vacates a casualty's square as he goes
/// down and `restoreKickoffLineup` refuses to put him back, so an injured man
/// normally leaves a HOLE rather than a name on the team sheet. He can still be
/// in one — a lineup written before the injury, a save restored across the two,
/// a listed or loaned-out card that the engine rates at zero exactly as it does
/// an injured one — and every path there ends the same way: eleven names, ten
/// footballers, and nothing on the way to kick-off that says so.
///
/// The engine's own gate cannot say it. [matchStartBlocked] answers a REFUSAL
/// and this is not one: a manager is allowed to play a man short, and often has
/// no other choice. So this is a question rather than a rule, and the screen is
/// what asks it — see the coach card in `play_button.dart`.
///
/// `isSelectable` rather than `!injured`, which is the same filter the bench
/// picker uses: the match engine scores a loaned-out or listed player zero too,
/// and a side is just as short for one of those.
List<String> unfitStarters(Map<String, dynamic>? state) {
  final lineup = _map(state?['squad'])?['lineup'];
  if (lineup is! List) return const [];
  final byId = <String, CardInstance>{
    for (final card in _cells(state).nonNulls) card.instanceId: card,
  };
  return [
    for (final slot in lineup)
      if (_map(slot)?['cardInstanceId'] case final String id)
        if (byId[id] case final card?)
          if (!card.isSelectable) card.name('A player'),
  ];
}

/// Whether a pip is available without spending one.
bool canSpendEnergy(Map<String, dynamic>? state, int amount) {
  final energy = _map(state?['energy']);
  final current = energy?['current'];
  return current is num && current >= amount;
}

/// Spend what a match costs and simulate it.
///
/// Returns null when [matchStartBlocked] would have refused, having changed
/// nothing — the gate is asked before the pip moves.
Map<String, dynamic>? beginMatch(Map<String, dynamic> state) {
  if (matchStartBlocked(state) != null) return null;

  // A track to play FOR. The sheet rolls one when it is opened, but a player who
  // never opens it still has three quests riding on this match, and a match with
  // no track resolves to nothing at all.
  ensureMatchQuests(state);

  if (_map(state['settings'])?['hardMode'] != true) {
    final spent = spendEnergy(state, Energy.matchCost);
    if (!spent.ok) return null;
  }

  final division = _map(state['progression'])?['currentDivision'] as String?;
  // **THE TUTORIAL'S FIRST MATCH IS ALWAYS WON.** `simulateMatch` has taken a
  // `forceWin` since the port landed, with a comment naming this as its reason,
  // and nothing had ever passed it — so a new player could lose the one match
  // the game walks them through, which is the worst first impression this can
  // make. Read the flag BEFORE the sim: it counts matches played, and the sim
  // is about to make it one.
  final first = tutorialFirstMatch(state);
  return simulateMatch(state, division, forceWin: first);
}

/// Commit the result. Called at full time, with the screen still up.
///
/// The match quest track resolves HERE, with the final scoreline: match quests
/// auto-pay, because the player has already tapped through a match and a second
/// tap to claim is friction with no upside. **`resolveMatchQuests` had no caller
/// at all**, so every match quest the game drew went unjudged and unpaid.
///
/// The outcomes are written onto the result so the screen can list all three —
/// what was missed as well as what was won.
void settleMatch(Map<String, dynamic> state, Map<String, dynamic> result) {
  finalizeMatchOutcome(state, result);
  result['questResults'] = [
    for (final outcome in resolveMatchQuests(state, result))
      <String, dynamic>{
        'id': outcome.id,
        'icon': outcome.icon,
        'target': outcome.target,
        'passed': outcome.passed,
        'coins': outcome.granted.coins,
      },
  ];
  // The fixture has moved on, so the NEXT one's track is drawn here — inside the
  // update that advanced it. The next-match card only reads the track; making it
  // roll on mount meant every screen that mounts the shell queued a save just by
  // being looked at.
  ensureMatchQuests(state);
}

/// Pay the player. Called only once they have dismissed the screen.
void payMatch(Map<String, dynamic> state, Map<String, dynamic> result) =>
    applyMatchRewards(state, result);
