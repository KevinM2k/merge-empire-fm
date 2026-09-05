/// The ten steps, and the players the club lends you for one match.
///
/// Ported from `STEPS` in `../merge-empire-fc/src/ui/components/Tutorial.js`.
/// **The copy was never the blocker; the CHOREOGRAPHY was** — which key is
/// which step, what each anchors to, and when the borrowed players come and go
/// — and none of that is recoverable from this repo. It is all in the spec, and
/// this is a port of it rather than a reconstruction.
///
/// **TEN steps, and `tut.merge` is the one that came BACK.**
///
/// Fifty-six `tut.*` strings ship in ten languages and thirty of them belong to
/// steps the JS had cut: `tut.sort`, `tut.tier_lock`, `tut.squad_formation`,
/// `tut.buy_asset`, `tut.buy_asset_action`, `tut.go_players`, `tut.league_tabs`,
/// `tut.league_progression`, `tut.training_games` and `tut.sell` are referenced
/// by nothing in `src/` either. Porting them would be inventing a tutorial the
/// shipped game does not have — which is the same trap the transfer list and the
/// coin-sink shelf set, and the reason a shipped-copy gap is a QUESTION rather
/// than a work item.
///
/// **The question got an answer, and it is in `docs/increase-retention.md`.**
/// Measured on GA4 over August: of new Android `google-play / organic` users,
/// 91% start the tutorial, 74% play a match, 59% finish it — and **26% ever open
/// the merge grid.** The onboarding of a merge game never once asked the player
/// to merge two cards. The best-retaining cohort ever recorded (Instagram, 14–20
/// Aug: 35.6% D1, 31.2% week one) merged at 44%, against 26% for Play organic in
/// the same days — the widest gap in the table.
///
/// So `tut.merge` is back, between the scouting and the loan, and it cost no
/// copy: the title and the body have shipped in all ten languages the whole
/// time. It is added to `STEPS` in `Tutorial.js` in the same commit, because the
/// JS is the spec.
///
/// **Three things move together and none of them works alone**, which is why
/// they are one change:
///
/// 1. The third scout is forced to PAIR with one of the first two — see
///    `tutorialPairDefinition` in `scout_engine.dart`. A merge step in front of
///    three cards that cannot merge is a dead end, and the draw is weighted,
///    not fixed.
/// 2. The step goes before `loan_boost`, so the player is down to two of their
///    own when the loan is worked out — and [lendTutorialPlayers] fills by
///    POSITION SHORTAGE rather than a flat count, so it lends one more and the
///    side is still eleven. Nothing there needed changing.
/// 3. The condition is `stats.totalMerges`, which `attemptMerge` has counted
///    since the port landed.
///
/// **A step ends one of two ways and never both.** Either it carries a button
/// (`buttonKey`) and the player taps to move on, or it carries a [condition]
/// and moves on the moment the save satisfies it — with `tut.complete_above`
/// under it saying so. That is the whole state machine.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/data/player_art.dart' show isVariantFemale;
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/lineup_engine.dart';
import 'package:merge_empire_fc/engine/merge_engine.dart'
    show closeGridGaps, createInstance;
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/analytics.dart';

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

  /// The `ValueKey` of the control this step is about, or null.
  ///
  /// **The JS's `target` selector, in the only form this port has one.** The
  /// steps that carry one are exactly the ones that wait on the save, which is
  /// not a coincidence: a step the player has to DO something for is the only
  /// kind that needs to be told where. See
  /// `ui/screens/tutorial/tutorial_spotlight.dart`.
  String? targetKey,

  /// Where the gesture ENDS, for a step whose answer is a drag rather than a
  /// tap. Null for every step that is answered by pressing something.
  ///
  /// **A merge is not a tap and the hand was miming one.** The cue pointed at a
  /// card and pressed it, which is the wrong instruction for the one gesture in
  /// the game that starts on one thing and finishes on another — reported from
  /// the couch. With this set the spotlight opens over BOTH squares (a drop
  /// target outside the hole is a drop target the input seal blocks) and the
  /// hand grabs, carries and lets go.
  String? dragToKey,
});

List<dynamic> _cells(Map<String, dynamic>? state) {
  final cells = _map(state?['grid'])?['cells'];
  return cells is List ? cells : const [];
}

int _filled(Map<String, dynamic>? state) =>
    _cells(state).where((c) => c != null).length;

/// How many merges this save has ever made — `attemptMerge`'s own tally.
int _merges(Map<String, dynamic>? state) =>
    _num(_map(state?['stats'])?['totalMerges'])?.toInt() ?? 0;

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
    targetKey: null,
    dragToKey: null,
  ),
  (
    id: 'scout_1',
    titleKey: 'tut.scout_1.title',
    bodyKey: 'tut.scout_1.body',
    tab: TutorialTab.grid,
    buttonKey: null,
    condition: (s) => _filled(s) >= 1,
    targetKey: 'add-player',
    dragToKey: null,
  ),
  (
    id: 'scout_2',
    titleKey: 'tut.scout_2.title',
    bodyKey: 'tut.scout_2.body',
    tab: TutorialTab.grid,
    buttonKey: null,
    condition: (s) => _filled(s) >= 3,
    targetKey: 'add-player',
    dragToKey: null,
  ),
  // **THE STEP THE FUNNEL WAS MISSING.** See the head of this file: 26% of new
  // players ever opened the merge grid, in a merge game. The condition is the
  // merge COUNTER rather than the shape of the grid — a player who merges and
  // then scouts again has still done what was asked, and counting cards would
  // send them round the loop.
  (
    id: 'merge',
    titleKey: 'tut.merge.title',
    bodyKey: 'tut.merge.body',
    tab: TutorialTab.grid,
    buttonKey: null,
    // **OR THERE IS NOTHING TO MERGE**, which is not a get-out. Two cases reach
    // it: a save resumed from the older nine-step script, which lands here
    // holding whatever it was holding; and any grid the pair-forcing above
    // could not fix, because both cards were already at their ceiling. A step
    // asking for something the board cannot do is worse than a step that steps
    // aside.
    condition: (s) => _merges(s) >= 1 || !gridHasMergeablePair(s),
    // **ONE CARD, not the whole grid.** `merge-grid` was the obvious target and
    // it is the wrong one: a spotlight the size of the screen dims nothing, and
    // the coach card picks whichever side of the hole has more room — so with
    // the grid as the hole it was thrown to the TOP of the screen with the hand
    // tapping down in the middle of the board. Reported from the couch. The
    // first cell is one of the pair in the ordinary case (see
    // [tutorialPairTwin], which twins the first card that can merge), it sits
    // near the top of the grid so the card rests where every card in this game
    // rests, and a hand on a CARD is the right cue for a gesture that starts on
    // one.
    // **THE SQUARE, NOT THE CARD IN IT.** `grid-card-<index>` sits inside the
    // card's `LongPressDraggable.child`, and a Draggable swaps its child for
    // `childWhenDragging` for the whole of a drag — so the one card the step is
    // about cannot be measured at the one moment the step is being answered.
    // `grid-slot-<index>` is the static layer the grid paints under every
    // filled cell, at the same rect, and no drag takes it out of the tree.
    targetKey: 'grid-slot-0',
    // The third card is the twin — `signPlayer` places it in the first empty
    // square, which is the third — so the drag runs from the first card to it.
    // See [tutorialPairTwin].
    dragToKey: 'grid-slot-2',
  ),
  (
    id: 'loan_boost',
    titleKey: 'tut.loan_boost.title',
    bodyKey: 'tut.loan_boost.body',
    tab: TutorialTab.grid,
    buttonKey: 'tut.loan_boost.btn',
    condition: null,
    targetKey: null,
    dragToKey: null,
  ),
  (
    id: 'play_match',
    titleKey: 'tut.play_match.title',
    bodyKey: 'tut.play_match.body',
    tab: TutorialTab.grid,
    buttonKey: 'tut.play_match.btn',
    condition: null,
    targetKey: null,
    dragToKey: null,
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
    targetKey: 'play-match',
    dragToKey: null,
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
    targetKey: null,
    dragToKey: null,
  ),
  (
    id: 'loan_depart',
    titleKey: 'tut.loan_depart.title',
    bodyKey: 'tut.loan_depart.body',
    tab: TutorialTab.grid,
    buttonKey: 'tut.loan_depart.btn',
    condition: null,
    targetKey: null,
    dragToKey: null,
  ),
  (
    id: 'done',
    titleKey: 'tut.done.title',
    bodyKey: 'tut.done.body',
    // **On the GRID, not the league screen.** The step before it empties the
    // grid, and the first thing a new manager has to do is fill it again — so
    // the script ends where the work is rather than sending them to the home
    // screen and then pointing back at the Players tab. Asked for from the
    // couch; it is also what lets Colin's tour open on "tap Scout".
    tab: TutorialTab.grid,
    buttonKey: 'tut.done.btn',
    condition: null,
    targetKey: null,
    dragToKey: null,
  ),
];

/// Two cards on the grid that could be dragged onto each other.
///
/// The whole rule `attemptMerge` applies, in the order it applies it: the same
/// definition, the same GENDER — a male and a female of one definition swap
/// rather than merge — and a definition that has something to merge INTO.
bool gridHasMergeablePair(Map<String, dynamic>? state) =>
    tutorialMergePair(state) != null;

/// Is the script sitting on the step that asks for a merge?
///
/// **While it is, a drag that is not a merge does nothing at all.** The input
/// seal is one rectangle and it has to hold both cards, so the squares between
/// them are inside it too — and a drag onto one of those is a SWAP, which
/// shuffles the board the step is pointing at and leaves the rings and the
/// dotted line aimed at squares the cards have left. Reported from the couch.
/// The only gesture the step accepts is the one it is teaching; anything else
/// is left where it was, which is the same answer as letting go over nothing.
bool tutorialMergeOnly(Map<String, dynamic>? state) =>
    tutorialStepFor(state)?.id == 'merge';

/// **WHICH TWO SQUARES**, not just whether there are two.
///
/// The merge step's cue drags from one card to another, and it pointed at
/// squares 0 and 2 — where the pair lands in the ordinary case, and only there.
/// A twin forced onto the SECOND card (which happens when the first is at the
/// division's ceiling) makes the pair 1 and 2, and the cue then mimed a drag
/// that is a SWAP: the hand did exactly what it was told and the cards did not
/// merge. Reported from the couch.
///
/// So the cue asks the grid instead. Grid order, so it is the first pair a
/// player scanning the board would find themselves.
({int from, int to})? tutorialMergePair(Map<String, dynamic>? state) {
  final cells = _cells(state);
  final maxTier = getDivision(
    '${_map(state?['progression'])?['currentDivision']}',
  ).maxPlayerTier;
  for (var i = 0; i < cells.length; i++) {
    final a = CardInstance.from(cells[i]);
    if (a == null) continue;
    for (var j = i + 1; j < cells.length; j++) {
      final b = CardInstance.from(cells[j]);
      if (b == null) continue;
      if (_pairs(a, b, maxTier)) return (from: i, to: j);
    }
  }
  return null;
}

bool _pairs(CardInstance a, CardInstance b, int maxTier) {
  if (a.definitionId != b.definitionId) return false;
  if (isVariantFemale(_variantOf(a)) != isVariantFemale(_variantOf(b))) {
    return false;
  }
  final into = getPlayerDef(a.definitionId)?.mergesInto;
  if (into == null) return false;
  // **AND THE DIVISION HAS TO ALLOW WHAT IT MAKES.** `attemptMerge` refuses a
  // merge whose result is above `maxPlayerTier` — two tier-2 cards in Sunday
  // League, whose cap is 2 — and a step waiting on a merge the grid will not
  // perform is a dead end. This is the same check, in the same order.
  final tier = getPlayerDef(into)?.tier;
  return tier == null || tier <= maxTier;
}

int _variantOf(CardInstance card) =>
    _num(card.raw['variant'])?.toInt() ?? 0;

List<CardInstance> _gridCards(Map<String, dynamic>? state) => [
  for (final raw in _cells(state)) ?CardInstance.from(raw),
];

/// The highest tier the scout may draw while the script is running, or null
/// once it is over.
///
/// **TIER ONE, because tier two cannot merge here.** Sunday League's scout pool
/// is the bottom two tiers and its own `maxPlayerTier` is 2 — so what a pair of
/// tier-2 cards would make is above the division's cap and `attemptMerge`
/// refuses it. A player walked through a merge step holding a pair of those is
/// being asked for something the grid will not do. Reported from the couch.
///
/// The whole script rather than the scouting steps alone: the loan lands
/// tier-5s and 6s on top of these, and a fourth card scouted mid-script would
/// otherwise reintroduce exactly the pair the step cannot use.
int? tutorialScoutMaxTier(Map<String, dynamic>? state) =>
    tutorialFinished(state) ? null : 1;

/// The card the next scout has to DUPLICATE, or null when it may draw freely.
///
/// **A MERGE STEP IN FRONT OF THREE CARDS THAT CANNOT MERGE IS A DEAD END**,
/// and the scout draw is weighted rather than fixed: `buildScoutDrawPool`
/// biases toward the positions the squad is short of, so three cards from the
/// bottom two tiers of Sunday League pair often and are in no way guaranteed to.
/// The player would be told to drag one onto its twin with no twin on the board.
///
/// So the THIRD card — and only the third, and only during the script — is a
/// copy of one of the first two, gender included. `signPlayer` still makes its
/// draw first, so the seeded sequence is untouched and every later roll in the
/// game falls exactly where it did; what changes is which definition gets
/// placed. If the first two already pair, this returns null and the draw
/// stands.
CardInstance? tutorialPairTwin(Map<String, dynamic>? state) {
  if (tutorialFinished(state)) return null;
  if (tutorialStepFor(state)?.id != 'scout_2') return null;
  final cards = _gridCards(state);
  if (cards.length != 2) return null;
  if (gridHasMergeablePair(state)) return null;
  final maxTier = getDivision(
    '${_map(state?['progression'])?['currentDivision']}',
  ).maxPlayerTier;
  for (final card in cards) {
    // Twinning a card at the division's ceiling would build the pair the merge
    // is refused for — see [_pairs].
    if (_pairs(card, card, maxTier)) return card;
  }
  return null;
}

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

/// Is the script over — or was it never running?
///
/// **A save with no `tutorial` branch, or a null `done`, is FINISHED.** That is
/// every save written before the flag existed, and most of the saves in the
/// wild; requiring an explicit `true` read all of them as mid-tutorial, which
/// hid the ×N batch control and the auto-sell pill from players who had
/// finished years ago. One implementation, because two answers to this question
/// is how the batch control and the batch SIZE came to disagree.
bool tutorialFinished(Map<String, dynamic>? state) {
  final tutorial = state?['tutorial'];
  if (tutorial is! Map) return true;
  return tutorial['done'] != false;
}

/// **The tutorial's guaranteed first win.**
///
/// A player losing the one match the game walks them through is the worst
/// first impression the port can make, and `simulateMatch` has taken a
/// `forceWin` since the port landed — with a comment naming the tutorial —
/// that nothing ever passed. The JS's own condition, exactly: the script is
/// still running AND no match has been played.
///
/// **`matchesPlayed`, not `seasonAwardedPlayed`.** This asks whether the player
/// has ever kicked off, which survives a season rolling over; the step that
/// waits for the result asks whether the rewards have MOVED, which is a
/// different counter and a different question.
bool tutorialFirstMatch(Map<String, dynamic>? state) {
  if (tutorialFinished(state)) return false;
  final played = _num(_map(state?['progression'])?['matchesPlayed']);
  return (played?.toInt() ?? 0) == 0;
}

/// Where the script is, or null once it is finished.
TutorialStep? tutorialStepFor(Map<String, dynamic>? state) {
  final tut = _map(state?['tutorial']);
  if (tut == null || tut['done'] == true) return null;
  final i = _num(tut['step'])?.toInt() ?? 0;
  return i >= 0 && i < tutorialSteps.length ? tutorialSteps[i] : null;
}

/// **Has the save DONE what the step is asking for?**
///
/// Three of the nine steps end this way rather than on a button — scout one,
/// scout three, play a match — and for a long time nothing in `lib/` called
/// `condition` at all. Every one of those three was a dead end: the card said
/// go and do it, the player went and did it, and the script sat where it was.
/// A tutorial that cannot be finished is worse than none, because it is the
/// first thing a new player meets.
///
/// False for a step that waits on its button, and for a finished script.
bool tutorialConditionMet(Map<String, dynamic>? state) {
  final step = tutorialStepFor(state);
  return step?.condition?.call(state) ?? false;
}

/// Move on, and mark it finished when the script runs out.
void advanceTutorial(Map<String, dynamic> state) {
  final tut = _map(state['tutorial']);
  if (tut == null) return;
  final from = _num(tut['step'])?.toInt() ?? 0;
  final next = from + 1;
  tut['step'] = next;
  if (next >= tutorialSteps.length) {
    tut['done'] = true;
    // Distinct from `done`, which a settle or a reset also writes: this says
    // the script RAN here, and is what starts Colin's tour (`guide_engine`).
    tut['completed'] = true;
  }

  // **THE ONE FUNNEL THAT DECIDES WHETHER A PLAYER STAYS**, and it reported
  // nothing at all. A tutorial is nine chances to lose someone and the only
  // question worth asking of it is WHICH step they left on — which no other
  // event in the app can answer, because a player who quits mid-script simply
  // stops appearing.
  //
  // Logged from the engine rather than the overlay for the reason the daily
  // reward and gem events are: this is the one function that moves the script,
  // the overlay is not, and an event on a screen is an event a second caller
  // silently skips.
  final id = from >= 0 && from < tutorialSteps.length
      ? tutorialSteps[from].id
      : 'unknown';
  // **The JS's four names, not tidier ones.** The port ships into the same
  // Firebase project under the same app id, so a renamed event ends the series
  // FC has been filling and starts a new one at the update boundary — see the
  // head of `services/analytics_wiring.dart`.
  if (from == 0) {
    logAppEvent('tutorial_started', {
      'resumed_at_step': id,
      'resumed_at_index': from,
    });
  }
  logAppEvent('tutorial_step_viewed', {'step_id': id, 'step_index': from});
  if (tut['done'] == true) {
    logAppEvent('tutorial_completed', {'steps': tutorialSteps.length});
  }
}

/// Give up on it. **And the loan goes home with it.**
///
/// **It used to keep them**, on the reasoning that the step which returns them
/// also pays the 500, so a player who skips out between the two has been lent
/// eleven men rather than robbed of them. The JS does the same by simply never
/// reaching `loan_depart`.
///
/// That is the wrong trade and it was reported as one: a skip that leaves
/// eleven tier-5 and tier-6 players on the grid hands the whole early game away
/// to anyone who taps Skip at the right moment — which is a moment the script
/// itself walks them to — and it leaves a save carrying `borrowed` cards with
/// nothing left in the script to take them back. They go, immediately, and the
/// grid closes up behind them, which is the thing that would otherwise leave
/// the player's own cards scattered.
///
/// **AND THE FAREWELL IS NOT PAID.** It was, on the reasoning that a skip
/// should not be a robbery — and that made skipping the tutorial the fastest 500
/// coins in the game, which is worse than either. The money belongs to
/// `loan_depart`, the step that says the club is taking them back and thanks you
/// for it; walking out is not that step. Reported from the couch.
void skipTutorial(Map<String, dynamic> state) {
  final tut = _map(state['tutorial']);
  if (tut == null) return;
  // **Read BEFORE the flag is set**, because `tutorialStepFor` answers null for
  // a finished script — which would file every skip in the game under nothing.
  final step = tutorialStepFor(state);
  tut['done'] = true;
  // Guarded on its own flag, so a skip after `loan_depart` has already run is a
  // no-op rather than a second pass over the grid.
  returnTutorialPlayers(state, pay: false);
  logAppEvent('tutorial_skipped', {
    'at_step_id': step?.id ?? 'unknown',
    'at_step_index': _num(tut['step'])?.toInt() ?? 0,
  });
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
///
/// **[pay] is false for a SKIP, and that is the whole of the difference.** The
/// farewell is what the club gives you for finishing the script — it belongs to
/// `loan_depart`, the step that says so — and handing it to somebody who walked
/// out makes skipping the tutorial the fastest 500 coins in the game. Reported
/// from the couch. The loan still goes home either way: a skip that kept eleven
/// tier-5 and tier-6 players would be worse again.
int returnTutorialPlayers(Map<String, dynamic> state, {bool pay = true}) {
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
  // **And the player's own three slide back to the front.** Eleven borrowed
  // cards leaving out of the middle of a grid leaves the three the player
  // started with wherever the loan happened to put them, with holes in
  // between — and the card that follows says "now build our team" over it.
  // `closeGridGaps` is the same pack the grid already does after a merge:
  // order kept, gaps closed, nothing reordered. Asked for from the couch.
  closeGridGaps(cells);

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
  if (pay && resources != null) {
    resources['fanCoins'] =
        (_num(resources['fanCoins'])?.toInt() ?? 0) + tutorialFarewellCoins;
  }
  tut['borrowedPlayersRemoved'] = true;
  return taken;
}
