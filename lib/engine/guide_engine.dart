/// What Colin tells a player to do NEXT, once the tutorial has let go of them.
///
/// **The tutorial teaches the grid and stops.** Nine steps: scout, merge, play
/// a match, wave the loan players off. It never mentions the Squad tab, the
/// Dugout, the club's ground or the shop — and a player who has just finished
/// it is standing on an emptied grid with no idea that four of the five tabs
/// exist. Reported from the couch as people getting lost. The script ENDS on
/// the Players tab, so the tour opens with the thing to do there — scout —
/// rather than with a finger pointing at the tab they are already on.
///
/// So this is a short, ordered list of nudges, each about one tab, each spoken
/// from the corner Colin already occupies on that tab — and **each one is said
/// until it is DONE and then never again.** "Go and buy some players" stops the
/// moment a player is bought; "the Dugout has training in it" stops the moment
/// the Dugout is opened. Not muted for ten minutes like his ordinary tips: spent,
/// the way a milestone tip is, because once you have done a thing you know how.
///
/// **It runs only for a save whose script RAN TO THE END here.** The flag is
/// `tutorial.completed`, written by `advanceTutorial` and nothing else.
/// `tutorial.done` is not enough: `settleTutorial` sets that on every old save
/// that has ever played, and a reset sets it too, so keying on it would hand a
/// veteran of forty seasons a tour of the tab bar.
///
/// Flutter-free, like the rest of the engine: which nudge is due is a question
/// about the save, and it is answered without a widget.
library;

import 'package:merge_empire_fc/engine/coach_tip_engine.dart'
    show hasSeenTip, markTipSeen;
import 'package:merge_empire_fc/i18n/i18n.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
List<dynamic> _list(Object? v) => v is List ? v : const [];

/// The five tabs, as the engine knows them. The shell's own enum lives in
/// `lib/ui`, which the engine may not import; `guideTabOf` in the UI maps one to
/// the other.
enum GuideTab { grid, squad, home, club, shop }

/// The tab's name in the bar, so a nudge can say "the Squad tab" in the words
/// the bar itself uses, in every language.
const Map<GuideTab, String> guideTabLabelKey = {
  GuideTab.grid: 'nav.players',
  GuideTab.squad: 'nav.squad',
  GuideTab.home: 'nav.play',
  GuideTab.club: 'nav.club',
  GuideTab.shop: 'nav.shop',
};

/// One nudge.
class GuideStep {
  const GuideStep({
    required this.id,
    required this.tab,
    this.leadsTo,
    this.satisfied,
  });

  /// Names the copy (`guide.<id>`) and the ledger entry.
  final String id;

  /// Where he says it.
  final GuideTab tab;

  /// The tab the nudge points AT, if it points at one. Opening that tab is
  /// what completes the step, and its name is what `guide.<id>`'s `{tab}`
  /// resolves to.
  ///
  /// **It does not light the bar.** The tour used to pulse a filled pill round
  /// whichever tab the outstanding step led to, and the Squad tab wearing one
  /// the moment a card landed read as an alert rather than a nudge — nobody
  /// could tell what it was FOR. Reported from the couch. The corner already
  /// says it in words; a second, wordless copy of the same instruction in the
  /// chrome is the part that confused.
  final GuideTab? leadsTo;

  /// Whether the save already shows the thing done, for the steps that leave a
  /// mark on it: a filled eleven, a facility owned. The ledger is checked too.
  final bool Function(Map<String, dynamic> save)? satisfied;

  String get copyKey => 'guide.$id';
  String get seenId => 'guide.$id';
}

bool _lineupFilled(Map<String, dynamic> s) {
  final cards = _list(_map(s['grid'])?['cells']).nonNulls.length;
  if (cards == 0) return false;
  final filled = _list(_map(s['squad'])?['lineup'])
      .where((row) => _map(row)?['instanceId'] != null)
      .length;
  // Everyone they own is on the pitch, or the pitch is full: either way there
  // is no empty slot left to tell them about.
  return filled >= 11 || filled >= cards;
}

bool _ownsAnAsset(Map<String, dynamic> s) =>
    (_map(s['clubAssets']) ?? const {}).values.any(
      (a) => _map(a)?['owned'] == true,
    );

/// The tour, in order. **Order is the chain**: on any one tab the first step
/// not yet done is the one he says, so "now open the Squad tab" cannot come
/// before "buy some players" on the same screen.
const List<GuideStep> guideSteps = [
  GuideStep(id: 'scout', tab: GuideTab.grid),
  GuideStep(id: 'squad_tab', tab: GuideTab.grid, leadsTo: GuideTab.squad),
  GuideStep(id: 'squad_fill', tab: GuideTab.squad, satisfied: _lineupFilled),
  GuideStep(id: 'dugout', tab: GuideTab.home),
  GuideStep(id: 'club_tab', tab: GuideTab.home, leadsTo: GuideTab.club),
  GuideStep(id: 'club_buy', tab: GuideTab.club, satisfied: _ownsAnAsset),
  GuideStep(id: 'shop_tab', tab: GuideTab.club, leadsTo: GuideTab.shop),
];

/// Is the tour running at all? Only for a save whose script finished HERE.
bool guideActive(Map<String, dynamic>? save) =>
    _map(save?['tutorial'])?['completed'] == true;

/// Done, by the ledger or by the save itself.
bool guideStepDone(Map<String, dynamic> save, GuideStep step) =>
    hasSeenTip(save, step.seenId) || (step.satisfied?.call(save) ?? false);

/// The nudge due on [tab], or null when the tour is over there.
GuideStep? guideStepFor(Map<String, dynamic>? save, GuideTab tab) {
  if (save == null || !guideActive(save)) return null;
  for (final step in guideSteps) {
    if (step.tab == tab && !guideStepDone(save, step)) return step;
  }
  return null;
}

/// What he says for [step], resolved.
String guideText(GuideStep step) => t(step.copyKey, {
  if (step.leadsTo != null) 'tab': t(guideTabLabelKey[step.leadsTo]!),
});

/// Spend a step. **Spent, not muted**: it never comes back.
void markGuideDone(Map<String, dynamic> save, String id) =>
    markTipSeen(save, 'guide.$id');

/// The player has opened [tab], so every step that was pointing at it is done.
void guideTabOpened(Map<String, dynamic> save, GuideTab tab) {
  if (!guideActive(save)) return;
  for (final step in guideSteps) {
    if (step.leadsTo == tab) markTipSeen(save, step.seenId);
  }
}
