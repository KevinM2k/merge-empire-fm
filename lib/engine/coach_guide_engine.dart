/// **WHAT TO DO NEXT, said once and then never again.**
///
/// A third Colin, and the three do not overlap:
///
/// - `coach_tip_engine.dart` is the milestone LESSON — sixteen popups that fire
///   the first time something happens to you (a first injury, an empty tank).
///   It is about a thing the game has just done.
/// - `ui/shell/coach_tips.dart` is his running COMMENTARY — tab-scoped,
///   repeatable, muted on a cooldown. It is about the page in front of you.
/// - This is the ONBOARDING TRAIL. It is about the parts of the app a player
///   who has just finished the tutorial has not opened yet, and every entry is
///   spent the moment they open one.
///
/// **The tutorial teaches scouting, merging and a match, and stops.** It never
/// mentions the Squad tab, the Dugout, training, the Club or the Shop — and
/// `docs/increase-retention.md` is a table of what that costs: 91% of new
/// players start the tutorial, 59% finish it, and the funnel goes quiet after
/// it because there is nothing telling them where to go next. This is the
/// hand-off from the script to the game.
///
/// **A guide is spent by DOING, not by being shown.** That is the whole rule
/// and it is the one thing that separates this from a banner: Colin says "the
/// Squad tab is where your eleven lives", the player opens the Squad tab, and
/// he never says it again — including when they open it before he ever
/// mentioned it. The player is not told something they have already worked out.
///
/// **One at a time, and the list order IS the sequence.** The first entry that
/// is unlocked and unspent is the only one live, so a player is never handed
/// five things to do; finish one and the next appears. [unlocked] is therefore
/// only ever an EXTRA condition on top of that ordering.
///
/// **The ledger is `seenTips`, prefixed, because there must be exactly one.**
/// `coach_tip_engine.dart` says so in its own header and it is right: two of
/// them and an id spent in one comes back through the other. Every id here is
/// stored as `guide.<id>`, which cannot collide with a milestone tip and rides
/// the save, the migration and the cloud codec that already carry that list.
///
/// **Armed by the tutorial ENDING, not by the flag being true.** Every save
/// written before the port had a tutorial reads as finished — `settleTutorial`
/// says so — so keying on `tutorial.done` would have walked a manager fifteen
/// seasons deep through "the Squad tab is where your eleven lives". The trail
/// only exists for a save that actually watched the script finish, which is
/// what [armCoachGuides] records. A player who skips arms it too: skipping is
/// the strongest possible signal that nobody has shown them anything.
///
/// Deliberately Flutter-free: which trail marker is live is a question about the
/// save, and it is answered without a widget so it can be tested without one.
library;

import 'package:merge_empire_fc/engine/coach_tip_engine.dart'
    show hasSeenTip, markTipSeen;

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
List<dynamic> _list(Object? v) => v is List ? v : const [];
num _num(Object? v) => v is num ? v : 0;

/// One marker on the trail.
typedef CoachGuide = ({
  /// Its own id. Stored as `guide.<id>`; see [guideLedgerId].
  String id,

  /// What he says. English lives in `i18n/en_copy.dart` and the other nine in
  /// `i18n/copy/<id>_copy.dart` — a guide is one sentence a player reads in
  /// their own language or not at all.
  String bodyKey,

  /// Which tab the bottom bar should nudge while this is live, as a
  /// `ShellTab.name`, or null for a marker that points at nothing.
  ///
  /// **This is not where the guide is SAID.** He says it wherever the player is;
  /// this is where he is pointing.
  String? destination,

  /// What the player has to DO to spend it. Reported by whichever control the
  /// player used — see [completeCoachGuides].
  String trigger,

  /// An extra condition on top of the list's own ordering. See the header.
  bool Function(Map<String, dynamic>? state) unlocked,
});

/// Where a guide's id sits in `seenTips`.
String guideLedgerId(String id) => 'guide.$id';

/// The marker that says this save watched the tutorial finish. Kept in the same
/// list as the guides themselves so there is one thing to reset and one thing
/// for the cloud codec to carry.
const String coachGuidesArmedId = 'guide.armed';

/// A tab was opened. The trigger every tab marker keys on.
String tabTrigger(String tabName) => 'tab:$tabName';

/// The Dugout — the quick-nav menu behind the burger on the home screen.
const String dugoutTrigger = 'dugout';

/// A training session was opened.
const String trainingTrigger = 'training';

int _matchesPlayed(Map<String, dynamic>? s) =>
    _num(_map(s?['progression'])?['matchesPlayed']).toInt();

int _squadSize(Map<String, dynamic>? s) =>
    _list(_map(s?['grid'])?['cells']).where((c) => c != null).length;

/// The trail, in order. See the header: the order is the sequence.
final List<CoachGuide> coachGuides = [
  // **FIRST, AND IT IS THE ONE THE FUNNEL ASKED FOR.** The script hands the
  // player back on the home screen with eleven borrowed men just taken off
  // them, and nothing on that screen says the squad is somewhere else. The tab
  // is nudged as well as named — see `ui/shell/tab_bar.dart`.
  (
    id: 'players_tab',
    bodyKey: 'guide.players_tab',
    destination: 'grid',
    trigger: 'tab:grid',
    unlocked: (_) => true,
  ),
  // The eleven, and the bench. Held until there is a squad to look at: a Squad
  // tab with three bronze cards in it teaches nothing.
  (
    id: 'squad_tab',
    bodyKey: 'guide.squad_tab',
    destination: 'squad',
    trigger: 'tab:squad',
    unlocked: (s) => _squadSize(s) >= 3,
  ),
  // **The Dugout is nine tiles deep and one tap wide.** The table, the
  // fixtures, the quests, training and the daily reward all moved in there when
  // the diorama lost its orbs, so a player who never opens the burger has not
  // seen most of the game.
  (
    id: 'dugout',
    bodyKey: 'guide.dugout',
    destination: 'home',
    trigger: dugoutTrigger,
    unlocked: (s) => _matchesPlayed(s) >= 1,
  ),
  // Directly after it, because it is the reason to go back in: the tile they
  // have now seen is the one that makes a player better for free.
  (
    id: 'training',
    bodyKey: 'guide.training',
    destination: 'home',
    trigger: trainingTrigger,
    unlocked: (s) => _matchesPlayed(s) >= 1,
  ),
  // The ground, and what it pays. A couple of matches in, so the coins to spend
  // on it exist.
  (
    id: 'club_tab',
    bodyKey: 'guide.club_tab',
    destination: 'club',
    trigger: 'tab:club',
    unlocked: (s) => _matchesPlayed(s) >= 2,
  ),
  (
    id: 'shop_tab',
    bodyKey: 'guide.shop_tab',
    destination: 'shop',
    trigger: 'tab:shop',
    unlocked: (s) => _matchesPlayed(s) >= 3,
  ),
];

/// Record that this save watched the tutorial end — the one thing that turns
/// the trail on. See the header for why the flag is not enough.
void armCoachGuides(Map<String, dynamic> state) =>
    markTipSeen(state, coachGuidesArmedId);

/// Whether this save is on the trail at all.
bool coachGuidesArmed(Map<String, dynamic>? state) =>
    hasSeenTip(state, coachGuidesArmedId);

/// Whether [guide] has been spent.
bool coachGuideSpent(Map<String, dynamic>? state, CoachGuide guide) =>
    hasSeenTip(state, guideLedgerId(guide.id));

/// The one marker that is live, or null.
///
/// Null for a save that never saw the script finish, and null the moment the
/// last marker is spent — which is the ordinary state of the game and is why
/// nothing here has an "off" switch.
CoachGuide? nextCoachGuide(Map<String, dynamic>? state) {
  if (!coachGuidesArmed(state)) return null;
  for (final guide in coachGuides) {
    if (coachGuideSpent(state, guide)) continue;
    // **Skipped, not stalled.** A gate that is not met yet is a marker that is
    // not relevant yet, and holding the whole trail behind one of them would
    // let a player who sold down to two cards never be told about the Dugout.
    if (!guide.unlocked(state)) continue;
    return guide;
  }
  return null;
}

/// Is there anything left for [trigger] to spend?
///
/// **Asked BEFORE the write, not instead of it.** `GameState.update` schedules a
/// save and wakes the tree on every call, and a tab change is the commonest
/// thing that happens in this app — a manager fifteen seasons deep must not
/// write their save every time they look at the Shop.
bool coachGuidePending(Map<String, dynamic>? state, String trigger) {
  if (!coachGuidesArmed(state)) return false;
  return coachGuides.any(
    (g) => g.trigger == trigger && !coachGuideSpent(state, g),
  );
}

/// The player did something. Spends every marker keyed on it.
///
/// **Whether or not it was the live one**, which is the point: a player who
/// finds the Shop on their own has been to the Shop, and being told to go there
/// afterwards is the app not watching. Returns true when something was actually
/// spent, so a caller can save.
///
/// A no-op on a save that is not on the trail — otherwise every tab a
/// fifteen-season manager opens would write to their save for nothing.
bool completeCoachGuides(Map<String, dynamic>? state, String trigger) {
  if (state == null || !coachGuidesArmed(state)) return false;
  var spent = false;
  for (final guide in coachGuides) {
    if (guide.trigger != trigger) continue;
    if (coachGuideSpent(state, guide)) continue;
    markTipSeen(state, guideLedgerId(guide.id));
    spent = true;
  }
  return spent;
}
