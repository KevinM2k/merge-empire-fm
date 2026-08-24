/// Playing a cup tie. Lifted out of `_playCupMatch` in `ui/screens/LeagueScreen.js`.
///
/// **The cup was unreachable.** `cup_engine` is fully ported and tested, and
/// `endSeason` even auto-enters the player into their division's cup — matching
/// real football, where clubs are scheduled into a cup rather than opting in —
/// but nothing called `prepareCupRound` or `commitCupRound`, so the tie could
/// never be played. A player could win a league, be entered into a cup, and
/// watch it sit there for the whole season.
///
/// The split into prepare and commit is the JS's and it is load-bearing: the
/// round is SIMULATED before the screen opens so the feed has something to play
/// out, and committed at full time so a result the player has changed on the way
/// through is the one that goes into the bracket. Only the Lucky Boot is spent up
/// front, because it is a one-shot consumable and cancelling out of the screen
/// must not hand it back.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/cups.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/cup_engine.dart';
import 'package:merge_empire_fc/engine/energy_engine.dart';
import 'package:merge_empire_fc/engine/match_events.dart';
import 'package:merge_empire_fc/engine/quest_engine.dart';
import 'package:merge_empire_fc/engine/quest_match.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/screens/match/match_launcher.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

/// How many league matches must be played before each cup round comes round.
///
/// The JS keeps these in the screen, twice: `cupInsertAt` places the tie in the
/// fixture list at `{3: 0, 8: 1, 12: 2}`, and the play button uses `idx + 1`
/// because a tie is due AFTER that league match has been played. One list here,
/// so the fixture list and the button can never disagree.
const List<int> cupDueAfterMatches = [4, 9, 13];

/// Is a cup tie the next thing to play?
///
/// Cups sit BETWEEN league games: the fixture index does not move for a tie, so
/// the league season is not shortened by one.
bool cupDue(Map<String, dynamic>? state) {
  final run = activeCup(state);
  if (run == null) return false;
  if (cupForDivision(state) == null) return false;
  final round = _num(run['round'])?.toInt() ?? 0;
  if (round >= cupDueAfterMatches.length) return false;
  final played =
      _num(_map(state?['progression'])?['seasonMatchesPlayed'])?.toInt() ?? 0;
  return played >= cupDueAfterMatches[round];
}

/// The cup and the round a due tie belongs to, or null when none is due.
({Cup cup, int round, String roundName})? nextCupRound(
  Map<String, dynamic>? state,
) {
  if (!cupDue(state)) return null;
  final run = activeCup(state);
  final cup = getCupById(run?['cupId'] as String?);
  final round = _num(run?['round'])?.toInt() ?? 0;
  if (cup == null || round >= cup.rounds.length) return null;
  return (cup: cup, round: round, roundName: cup.rounds[round]);
}

/// A simulated tie, and the result the screen plays out.
typedef CupTie = ({Map<String, dynamic> result, PreparedCupRound prepared});

/// Spend what a tie costs, simulate it, and hand back something playable.
///
/// Returns null when it could not start, having changed nothing.
CupTie? beginCupRound(Map<String, dynamic> state) {
  if (!cupDue(state)) return null;
  // The same gate a league game uses: a cup tie is not a way round a cooldown,
  // an empty pip or a squad too small to field.
  if (matchStartBlocked(state) != null) return null;

  if (_map(state['settings'])?['hardMode'] != true) {
    final spent = spendEnergy(state, Energy.matchCost);
    if (!spent.ok) return null;
  }

  // A cup tie carries the match quest track exactly as a league game does. The
  // fixture key does not move for a tie — cups sit between league games — so the
  // quests on the Play screen are the ones this tie is judged against, and
  // leaving them unresolved made a cup tie the one match where they counted for
  // nothing.
  ensureMatchQuests(state);

  final prepared = prepareCupRound(state);
  if (prepared == null) return null;

  final cup = getCupById(prepared.cupId);
  final rounds = cup?.rounds.length ?? 1;

  // The shootout's winning goal is folded into the scoreline by the engine, so
  // `won` and the recorded score agree. The FEED must play the ninety minutes
  // only — a shootout is not a goal in the ninetieth minute — so it is taken back
  // out here and the shootout is reported at the final whistle instead.
  final shootout = prepared.penaltyShootout;
  final regulationHome =
      prepared.homeGoals - (shootout != null && prepared.won ? 1 : 0);
  final regulationAway =
      prepared.awayGoals - (shootout != null && !prepared.won ? 1 : 0);

  final result = <String, dynamic>{
    'divisionId': prepared.cupId,
    // `tName` takes an id or a `{id, name}` map, not the data object: the JS's
    // cups are plain objects and Dart's are not.
    'divisionName':
        '🏆 ${tName('cup', {'id': prepared.cupId, 'name': cup?.name})} '
        '· ${prepared.roundName}',
    'clubName': state['clubName'] ?? t('common.your_club'),
    'opponentName': prepared.opponentName,
    // A cup tie is played at home. The JS says so and the bracket has no venue.
    'isHome': true,
    'homeGoals': prepared.homeGoals,
    'awayGoals': prepared.awayGoals,
    'won': prepared.won,
    'drawn': false,
    'squadRating': prepared.squadRating,
    'opponentRating': prepared.opponentRating,
    'ourAttackRating': prepared.ourAttackRating,
    'ourDefenceRating': prepared.ourDefenceRating,
    'effOppAttackRating': prepared.effOppAttackRating,
    'effOppDefenceRating': prepared.effOppDefenceRating,
    'coinsEarned': prepared.earned,
    'trophiesEarned': 0,
    'injuredName': prepared.injuredName,
    'injuryCount': prepared.injuries.length,
    'isCup': true,
    'cupIsFinal': prepared.isFinal,
    'cupIsSemi': prepared.round == rounds - 2 && rounds >= 2,
    // Stored as a plain map, not the record: this result reaches the screen and
    // the quest engine, and a record on the way through a `Map<String, dynamic>`
    // is the kind of thing that only fails when it is serialised.
    // **THE KICKS TRAVEL WITH IT.** The engine simulates a shootout kick by
    // kick — `simulatePenaltyShootout` builds the whole list, sudden death and
    // all — and only the three totals were carried through, so a tie decided on
    // penalties reached the screen as a one-goal defeat the player never saw
    // decided. That is the JS's own warning about this exact field: "a 2-2 tie
    // surfacing as lost 2-3 with no penalties shown".
    'penaltyShootout': shootout == null
        ? null
        : <String, dynamic>{
            'playerWins': shootout.playerWins,
            'homeScore': shootout.homeScore,
            'awayScore': shootout.awayScore,
            'kicks': [
              for (final kick in shootout.kicks)
                <String, dynamic>{
                  'team': kick.team,
                  'scored': kick.scored,
                  'suddenDeath': kick.suddenDeath,
                },
            ],
          },
    'events': [
      for (final e in generateMatchEvents(
        homeGoals: regulationHome < 0 ? 0 : regulationHome,
        awayGoals: regulationAway < 0 ? 0 : regulationAway,
        playerData: _takers(state),
        injuries: [
          for (final injury in prepared.injuries)
            (name: injury.name ?? '', minute: injury.minute),
        ],
      ))
        e.toMap(),
    ],
  };

  return (result: result, prepared: prepared);
}

/// Who can be credited with a goal: the fit players in the XI.
///
/// Excludes the injured and anyone left out, so a goal cannot be credited to a
/// player who has already gone off — [prepareCupRound] has applied its injuries
/// by this point, so the lineup read here is the post-substitution one.
List<ScorerCandidate> _takers(Map<String, dynamic> state) {
  final lineup = _map(state['squad'])?['lineup'];
  final picked = <String>{
    if (lineup is List)
      for (final slot in lineup)
        if (_map(slot)?['cardInstanceId'] case final String id) id,
  };
  final cells = _map(state['grid'])?['cells'];
  return [
    if (cells is List)
      for (final raw in cells)
        if (CardInstance.from(raw) case final card?)
          if (!card.injured &&
              (picked.isEmpty || picked.contains(card.instanceId)))
            if (getPlayerDef(card.definitionId) case final def?)
              ScorerCandidate(
                name: card.name(),
                position: def.position,
                instanceId: card.instanceId,
              ),
  ];
}

/// Commit the tie at full time, with the screen still up.
///
/// Returns the sponsor drop a win rolled, so the caller can offer it.
///
/// **When in-match tactic changes arrive this needs revisiting.** The JS carries
/// the popup's final goals back onto its prepared result before committing, so a
/// tactic change that turned a win into a defeat is what goes into the bracket.
/// `PreparedCupRound` is a record and cannot be mutated, and nothing here can
/// change a result yet — so `won` is passed through and the goals are the
/// prepared ones. A screen that can change them will have to hand them in.
CupSponsorDrop? settleCupRound(Map<String, dynamic> state, CupTie tie) {
  // **WHAT THE SCREEN ENDED ON, not what was simulated before it opened.** An
  // in-match tactic change re-simulates the remainder and rewrites the result's
  // scoreline in place, so the two disagree the moment a player uses the tactic
  // control — the bracket recorded a 2-1 while the feed had just played out a
  // 3-1.
  final finalHome = _num(tie.result['homeGoals'])?.toInt() ?? tie.prepared.homeGoals;
  final finalAway = _num(tie.result['awayGoals'])?.toInt() ?? tie.prepared.awayGoals;
  var won = tie.result['won'] == true;

  // **A CUP TIE CANNOT END LEVEL**, and a re-simulation is free to make it
  // level — which the ninety-minute engine has no opinion about, because in the
  // league a draw is a result. The shootout that was rolled for exactly this
  // case decides it; re-rolling one here would be a second draw from the same
  // hat and could disagree with the kicks already on the save.
  if (finalHome == finalAway) {
    final shootout = _map(tie.result['penaltyShootout']);
    won = shootout != null
        ? shootout['playerWins'] == true
        : tie.prepared.won;
  }

  final drop = commitCupRound(
    state,
    won,
    tie.prepared,
    homeGoals: finalHome,
    awayGoals: finalAway,
  );
  tie.result['questResults'] = [
    for (final outcome in resolveMatchQuests(state, tie.result))
      <String, dynamic>{
        'id': outcome.id,
        'icon': outcome.icon,
        'target': outcome.target,
        'passed': outcome.passed,
        'coins': outcome.granted.coins,
      },
  ];
  return drop;
}
