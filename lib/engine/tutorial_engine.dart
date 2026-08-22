/// The nine steps, and the two players the club lends you for one match.
///
/// Ported from `STEPS` in `../merge-empire-fc/src/ui/components/Tutorial.js`.
/// **The copy was never the blocker; the CHOREOGRAPHY was** — which key is
/// which step, what each anchors to, and when the borrowed players come and go
/// — and none of that is recoverable from this repo. It is all in the spec, and
/// this is a port of it rather than a reconstruction.
///
/// **NINE steps, and the catalogue carries the corpses of a longer one.**
/// Fifty-six `tut.*` strings ship in ten languages and thirty of them belong to
/// steps the JS has since cut: `tut.merge`, `tut.sort`, `tut.tier_lock`,
/// `tut.squad_formation`, `tut.buy_asset`, `tut.buy_asset_action`,
/// `tut.go_players`, `tut.league_tabs`, `tut.league_progression`,
/// `tut.training_games` and `tut.sell` are referenced by nothing in `src/`
/// either. Porting them would be inventing a tutorial the shipped game does not
/// have — which is the same trap the transfer list and the coin-sink shelf set,
/// and the reason a shipped-copy gap is a QUESTION rather than a work item.
///
/// **A step ends one of two ways and never both.** Either it carries a button
/// (`buttonKey`) and the player taps to move on, or it carries a [condition]
/// and moves on the moment the save satisfies it — with `tut.complete_above`
/// under it saying so. That is the whole state machine.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/lineup_engine.dart';
import 'package:merge_empire_fc/engine/merge_engine.dart' show createInstance;
import 'package:merge_empire_fc/state/card_instance.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

/// Which screen a step belongs on.
enum TutorialTab { none, grid, league }

/// One beat of the script.
typedef TutorialStep = ({
  String id,
  String titleKey,
  String bodyKey,
  TutorialTab tab,

  /// The label on the button that moves it on, or null when a [condition] does.
  String? buttonKey,

  /// True once the save has done what the step is asking for. Null for a step
  /// that waits on the button instead.
  bool Function(Map<String, dynamic>? state)? condition,
});

List<dynamic> _cells(Map<String, dynamic>? state) {
  final cells = _map(state?['grid'])?['cells'];
  return cells is List ? cells : const [];
}

int _filled(Map<String, dynamic>? state) =>
    _cells(state).where((c) => c != null).length;

/// The script, in order.
///
/// The ids, the tabs, the keys and the conditions are the JS's own. Two steps
/// were inserted at old indices 3 and 6, which is what `migration.dart` has
/// been pinning all along — a save part-way through an older script has to land
/// somewhere sensible in this one.
final List<TutorialStep> tutorialSteps = [
  (
    id: 'welcome',
    titleKey: 'tut.welcome.title',
    bodyKey: 'tut.welcome.body',
    tab: TutorialTab.none,
    buttonKey: 'tut.welcome.btn',
    condition: null,
  ),
  (
    id: 'scout_1',
    titleKey: 'tut.scout_1.title',
    bodyKey: 'tut.scout_1.body',
    tab: TutorialTab.grid,
    buttonKey: null,
    condition: (s) => _filled(s) >= 1,
  ),
  (
    id: 'scout_2',
    titleKey: 'tut.scout_2.title',
    bodyKey: 'tut.scout_2.body',
    tab: TutorialTab.grid,
    buttonKey: null,
    condition: (s) => _filled(s) >= 3,
  ),
  (
    id: 'loan_boost',
    titleKey: 'tut.loan_boost.title',
    bodyKey: 'tut.loan_boost.body',
    tab: TutorialTab.grid,
    buttonKey: 'tut.loan_boost.btn',
    condition: null,
  ),
  (
    id: 'play_match',
    titleKey: 'tut.play_match.title',
    bodyKey: 'tut.play_match.body',
    tab: TutorialTab.grid,
    buttonKey: 'tut.play_match.btn',
    condition: null,
  ),
  (
    id: 'play_match_action',
    titleKey: 'tut.play_match_action.title',
    bodyKey: 'tut.play_match_action.body',
    tab: TutorialTab.league,
    buttonKey: null,
    // `seasonAwardedPlayed`, not `seasonMatchesPlayed`: the JS waits for the
    // match to have been SETTLED, which is the counter the rewards move.
    condition: (s) =>
        (_num(_map(s?['progression'])?['seasonAwardedPlayed'])?.toInt() ?? 0) >=
        1,
  ),
  (
    id: 'match_result_reaction',
    // Resolved at render time from `lastMatchResult` — four titles and four
    // bodies for won, drawn, lost and "no match on the save", which is the one
    // a resumed tutorial can land in.
    titleKey: 'tut.match_reaction.first_title',
    bodyKey: 'tut.match_reaction.first_body',
    tab: TutorialTab.league,
    buttonKey: 'common.ok',
    condition: null,
  ),
  (
    id: 'loan_depart',
    titleKey: 'tut.loan_depart.title',
    bodyKey: 'tut.loan_depart.body',
    tab: TutorialTab.grid,
    buttonKey: 'tut.loan_depart.btn',
    condition: null,
  ),
  (
    id: 'done',
    titleKey: 'tut.done.title',
    bodyKey: 'tut.done.body',
    tab: TutorialTab.league,
    buttonKey: 'tut.done.btn',
    condition: null,
  ),
];

/// Which of the four `tut.match_reaction.*` pairs this save has earned.
///
/// `first` is not "the first match" — it is NO match, which a tutorial resumed
/// on a fresh save can be sitting in.
String matchReactionKind(Map<String, dynamic>? state) {
  final result = _map(_map(state?['progression'])?['lastMatchResult']);
  if (result == null) return 'first';
  if (result['won'] == true) return 'win';
  if (result['drawn'] == true) return 'draw';
  return 'loss';
}

/// Where the script is, or null once it is finished.
TutorialStep? tutorialStepFor(Map<String, dynamic>? state) {
  final tut = _map(state?['tutorial']);
  if (tut == null || tut['done'] == true) return null;
  final i = _num(tut['step'])?.toInt() ?? 0;
  return i >= 0 && i < tutorialSteps.length ? tutorialSteps[i] : null;
}

/// Move on, and mark it finished when the script runs out.
void advanceTutorial(Map<String, dynamic> state) {
  final tut = _map(state['tutorial']);
  if (tut == null) return;
  final next = (_num(tut['step'])?.toInt() ?? 0) + 1;
  tut['step'] = next;
  if (next >= tutorialSteps.length) tut['done'] = true;
}

/// Give up on it. The save keeps whatever it has been lent.
///
/// **The borrowed players are NOT taken back here**, deliberately: the step
/// that returns them also pays the 500, and a player who skips out between the
/// two has been lent eleven men rather than robbed of them. The JS does the
/// same by simply never reaching `loan_depart`.
void skipTutorial(Map<String, dynamic> state) {
  final tut = _map(state['tutorial']);
  if (tut == null) return;
  tut['done'] = true;
}

/// The squad a full XI needs: one keeper, four at the back, three and three.
const Map<String, int> tutorialSquadTarget = {
  'GK': 1,
  'DEF': 4,
  'MID': 3,
  'FWD': 3,
};

/// Lend the club whatever it is short of a full side.
///
/// **Shortage by POSITION, not a flat eleven.** The player has scouted three of
/// their own by now and they could be anything; what the next step needs is a
/// side that can take the field, so the loan fills the holes and no more.
/// Tiers alternate 5 and 6 so the borrowed men are visibly better than the
/// bronze the player owns — which is the whole point of the step.
///
/// Guarded on its own flag: it runs on a button, and a double tap must not lend
/// twice.
int lendTutorialPlayers(Map<String, dynamic> state) {
  final tut = _map(state['tutorial']);
  if (tut == null || tut['borrowedPlayersAdded'] == true) return 0;

  final cells = _cells(state);
  final have = <String, int>{};
  for (final raw in cells) {
    final card = CardInstance.from(raw);
    if (card == null) continue;
    final position = getPlayerDef(card.definitionId)?.position;
    if (position != null) have[position] = (have[position] ?? 0) + 1;
  }

  var lent = 0;
  for (final position in const ['GK', 'DEF', 'MID', 'FWD']) {
    final short = (tutorialSquadTarget[position] ?? 0) - (have[position] ?? 0);
    for (var i = 0; i < short; i++) {
      final index = cells.indexWhere((c) => c == null);
      if (index < 0) break;
      final tier = i.isEven ? 5 : 6;
      cells[index] = {
        ...createInstance('player_t${tier}_${position.toLowerCase()}').raw,
        'borrowed': true,
      };
      lent++;
    }
  }

  // So the borrowed men count toward the rating on screen AND toward the sim.
  final squad = _map(state['squad']);
  if (squad != null) {
    squad['formation'] ??= defaultFormation;
    syncLineupWithGrid(state);
  }
  tut['borrowedPlayersAdded'] = true;
  return lent;
}

/// What the club pays you when it takes them back.
const int tutorialFarewellCoins = 500;

/// Take them back, and pay for the trouble.
///
/// The lineup is repaired rather than rebuilt: a slot naming a card that has
/// gone is emptied, and everything the player put somewhere on purpose stays
/// where they put it.
int returnTutorialPlayers(Map<String, dynamic> state) {
  final tut = _map(state['tutorial']);
  if (tut == null || tut['borrowedPlayersRemoved'] == true) return 0;

  final cells = _cells(state);
  var taken = 0;
  for (var i = 0; i < cells.length; i++) {
    if (_map(cells[i])?['borrowed'] == true) {
      cells[i] = null;
      taken++;
    }
  }

  final kept = {
    for (final raw in cells)
      if (CardInstance.from(raw) case final c?) c.instanceId,
  };
  final lineup = _map(state['squad'])?['lineup'];
  if (lineup is List) {
    for (final raw in lineup) {
      final slot = _map(raw);
      if (slot == null) continue;
      final id = slot['cardInstanceId'];
      if (id != null && !kept.contains(id)) slot['cardInstanceId'] = null;
    }
  }

  final resources = _map(state['resources']);
  if (resources != null) {
    resources['fanCoins'] =
        (_num(resources['fanCoins'])?.toInt() ?? 0) + tutorialFarewellCoins;
  }
  tut['borrowedPlayersRemoved'] = true;
  return taken;
}
