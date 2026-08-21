/// The one-time milestone tips. Ported from
/// `../merge-empire-fc/src/ui/components/CoachTips.js`.
///
/// **The OTHER Colin.** `ui/shell/coach_tips.dart` is the floating head's
/// running commentary — tab-scoped, repeatable, muted on a cooldown. This is the
/// educational half: sixteen popups that fire the first time a player hits
/// something (a first injury, a first mergeable pair, an empty energy tank, Hard
/// mode's fitness bars) and then never again. The id goes into `state.seenTips`
/// and stays there until a full reset.
///
/// **`seenTips` was a ledger with no ledger in it.** It is in the schema and the
/// migration writes it, and until this landed nothing in the port had ever read
/// or written a single entry — so all sixteen tips, and the forty-four
/// `coachtip.*` strings sitting translated in all ten catalogues, were
/// unreachable.
///
/// **Order is priority.** The first tip whose condition holds and which has not
/// been seen is the one that shows, so an injury outranks an explainer about the
/// Club tab. Urgent and actionable beat passive.
///
/// Deliberately Flutter-free: which tip applies is a question about the save,
/// and it is answered without a widget so it can be tested without one.
library;

import 'package:merge_empire_fc/data/player_art.dart';
import 'package:merge_empire_fc/engine/auto_tier_engine.dart';
import 'package:merge_empire_fc/engine/player_energy_engine.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
List<dynamic> _list(Object? v) => v is List ? v : const [];
num _num(Object? v) => v is num ? v : 0;

/// What the player is looking at when the check runs.
///
/// The tab ids are the JS's, which are not quite the port's tab names: its
/// `league` is this app's home screen. Kept as the JS's so the conditions read
/// against the source they came from, and mapped once at the call site.
typedef CoachTipContext = ({
  /// `grid`, `squad`, `league`, `club`, `shop`, or null.
  String? tab,

  /// `minigames` for the training ground, or null.
  String? subtab,

  /// A match has just CLOSED. Deliberately not "completed": a tip that fired on
  /// the whistle would land over the result screen.
  bool postMatch,
});

const CoachTipContext noTipContext = (
  tab: null,
  subtab: null,
  postMatch: false,
);

/// What a tip's button does, when it has one.
enum CoachTipCta {
  /// Take me to the squad.
  squad,

  /// Open Settings, with the Auto-Sell row spotlit.
  autoSell,

  /// Open Settings.
  settings,

  /// Sign in, so the save is not only on this phone.
  connect,
}

/// One tip.
class CoachTip {
  const CoachTip({
    required this.id,
    required this.emoji,
    required this.applies,
    this.cta,
    this.ctaLabelKey,
    this.bodyParams,
  });

  final String id;

  /// The milestone's own badge, worn on the corner of Colin's card.
  ///
  /// **The one place an emoji is right.** The rest of the app draws its own line
  /// art, but these are sixteen unrelated one-off subjects — a hospital, a
  /// trophy, a stadium, a pair of lungs — and drawing sixteen glyphs used once
  /// each is not the same trade as drawing the icon set.
  final String emoji;

  /// Whether it applies to this save at this moment.
  final bool Function(Map<String, dynamic>? state, CoachTipContext ctx) applies;

  final CoachTipCta? cta;
  final String? ctaLabelKey;

  /// Anything the copy needs filling in.
  final Map<String, Object?> Function(Map<String, dynamic>? state)? bodyParams;

  /// Where the copy lives. Every one of these is already in all ten catalogues.
  String get titleKey => 'coachtip.$id.title';
  String get bodyKey => 'coachtip.$id.body';
}

/// Two grid cards make a mergeable pair when they share a definition AND a
/// gender, which is the actual merge rule.
///
/// **Deliberately not the division's ceiling**, which the grid's own gold ring
/// does check. This teaches the drag gesture at the moment it first becomes
/// possible, and a player whose only pair is above their league's cap still has
/// the gesture to learn.
bool hasMergeablePair(Map<String, dynamic>? state) {
  final seen = <String>{};
  for (final cell in _list(_map(state?['grid'])?['cells'])) {
    final c = _map(cell);
    if (c == null) continue;
    final key =
        '${c['definitionId']}|'
        '${isVariantFemale(_num(c['variant']).toInt()) ? 'f' : 'm'}';
    if (!seen.add(key)) return true;
  }
  return false;
}

int _filledCells(Map<String, dynamic>? state) => [
  for (final c in _list(_map(state?['grid'])?['cells']))
    if (_map(c) != null) c,
].length;

bool _hardMode(Map<String, dynamic>? s) =>
    _map(s?['settings'])?['hardMode'] == true;

int _matchesPlayed(Map<String, dynamic>? s) =>
    _num(_map(s?['progression'])?['matchesPlayed']).toInt();

bool _reachedElite(Map<String, dynamic>? s) => _list(
  _map(s?['progression'])?['divisionsUnlocked'],
).contains('elite_league');

/// Whether the save is attached to an account.
///
/// The JS asks `authService`; the port has no auth yet (M4), so it asks the
/// save the same question the cloud writer does — a uid on the leaderboard
/// block is what "signed in" means to everything else here.
bool isSignedInLocal(Map<String, dynamic>? s) =>
    _map(s?['leaderboard'])?['authUid'] != null;

/// Evaluated in order; the first that applies and has not been seen is shown.
final List<CoachTip> coachTips = [
  CoachTip(
    id: 'injury',
    emoji: '🏥',
    // Post-match only — after a game that left somebody injured, never on the
    // screen before one.
    applies: (s, ctx) =>
        ctx.postMatch &&
        _list(
          _map(s?['grid'])?['cells'],
        ).any((c) => _map(c)?['injured'] == true),
    cta: CoachTipCta.squad,
    ctaLabelKey: 'coachtip.injury.cta',
  ),
  CoachTip(
    id: 'promotion',
    emoji: '🏆',
    applies: (s, ctx) =>
        ctx.postMatch &&
        _list(_map(s?['progression'])?['leagueTrophies']).isNotEmpty,
  ),
  CoachTip(
    id: 'merge',
    emoji: '🔀',
    // The how-to, on the Players tab, when a pair exists and they have never
    // merged — the hold-and-drag gesture the tutorial no longer covers, taught
    // at the moment it is useful.
    applies: (s, ctx) =>
        ctx.tab == 'grid' &&
        _num(_map(s?['stats'])?['totalMerges']) == 0 &&
        hasMergeablePair(s),
  ),
  CoachTip(
    id: 'energy',
    emoji: '⚡',
    // After a game drains the tank, not at the instant pressing Play spends the
    // last pip — that would pop over the pre-match screen.
    applies: (s, ctx) =>
        ctx.postMatch && _num(_map(s?['energy'])?['current']) <= 0,
  ),
  CoachTip(
    id: 'fatigue',
    emoji: '😮‍💨',
    // Hard mode only: what the fitness bars under each player mean. They only
    // exist there.
    applies: (s, ctx) =>
        _hardMode(s) && ctx.tab == 'squad' && _matchesPlayed(s) >= 1,
  ),
  CoachTip(
    id: 'match_fitness',
    emoji: '🔋',
    // Hard mode only, once the XI's average has dropped below 90% — the moment
    // "match fitness is falling" becomes visible on the Play button. No button
    // on this one: subs live inside the match, not on any tab.
    applies: (s, ctx) =>
        _hardMode(s) && ctx.tab == 'league' && averageFitnessPct(s) < 90,
  ),
  CoachTip(
    id: 'subs_bench',
    emoji: '⇅',
    // Casual's counterpart. There is no fitness readout to hang the lesson on,
    // so it waits for a couple of games — the bench matters there for tactical
    // swaps and, more urgently, for covering an injury that no longer
    // auto-replaces itself.
    applies: (s, ctx) =>
        !_hardMode(s) && ctx.tab == 'league' && _matchesPlayed(s) >= 2,
  ),
  CoachTip(
    id: 'club_assets',
    emoji: '🏟️',
    applies: (s, ctx) => ctx.tab == 'club',
  ),
  CoachTip(
    id: 'training',
    emoji: '🏃',
    applies: (s, ctx) => ctx.subtab == 'minigames',
  ),
  CoachTip(
    id: 'traits',
    emoji: '✨',
    // Once they have a full team: traits matter when you are picking an XI, not
    // while still scouting bodies.
    applies: (s, ctx) => ctx.tab == 'squad' && _filledCells(s) >= 11,
  ),
  CoachTip(
    id: 'atk_def',
    emoji: '⚔️',
    // Suppressed in Hard mode — no coaching on tactics there.
    applies: (s, ctx) =>
        !_hardMode(s) && ctx.tab == 'squad' && _matchesPlayed(s) >= 3,
  ),
  CoachTip(
    id: 'auto_sell',
    emoji: '🏷️',
    // At the point the busywork starts to bite: by Elite League a bronze pull is
    // worth nothing but a trip to the Squad tab to sell it. Gated on the
    // DIVISION rather than a scout count so it lands on established saves too.
    // Skipped for anyone who found the setting themselves — a rule already
    // switched on has nothing to explain.
    applies: (s, ctx) => _reachedElite(s) && activeAutoTiers(s).isEmpty,
    cta: CoachTipCta.autoSell,
    ctaLabelKey: 'coachtip.auto_sell.cta',
  ),
  CoachTip(
    id: 'try_hard_mode',
    emoji: '🔥',
    applies: (s, ctx) => !_hardMode(s) && _reachedElite(s),
    cta: CoachTipCta.settings,
    ctaLabelKey: 'coachtip.try_hard_mode.cta',
  ),
  CoachTip(
    id: 'rename_player',
    emoji: '✏️',
    // Renaming lives behind the pencil in a player's sheet, which is easy never
    // to notice. Held back until there is a squad worth naming.
    applies: (s, ctx) => ctx.tab == 'squad' && _filledCells(s) >= 5,
  ),
  CoachTip(
    id: 'customise_manager',
    emoji: '✂️',
    // The CUSTOMISE pill under the walking manager. Waits a couple of matches so
    // it does not land in the same breath as the tutorial.
    applies: (s, ctx) => ctx.tab == 'league' && _matchesPlayed(s) >= 2,
  ),
  // No `sponsor` or `transfer_offer` entry. Neither is a tip OVER its offer any
  // more — each is a paragraph INSIDE it — so both take their one-time id
  // through [takeTipOnce] instead, which is why both still have `coachtip.*`
  // strings and still turn up in `seenTips`.
  CoachTip(
    id: 'save_progress',
    emoji: '☁️',
    // Only nags a player who is not signed in, and only once they are invested.
    applies: (s, ctx) => _matchesPlayed(s) >= 10 && !isSignedInLocal(s),
    bodyParams: (s) => {'n': _matchesPlayed(s)},
    cta: CoachTipCta.connect,
    ctaLabelKey: 'coachtip.save_progress.cta',
  ),
];

List<dynamic> _seen(Map<String, dynamic> state) {
  final list = state['seenTips'];
  if (list is List) return list;
  return state['seenTips'] = <dynamic>[];
}

/// Whether [id] has already been spent.
bool hasSeenTip(Map<String, dynamic>? state, String id) =>
    _list(state?['seenTips']).contains(id);

/// Which tip to show now, or null.
///
/// **Onboarding wins.** Never over the tutorial — the JS reads `tutorial.done`
/// and so does this, as `!= false` rather than `== true`, because most saves
/// predate the flag and reading them as mid-tutorial has already cost this port
/// two controls.
CoachTip? pickCoachTip(Map<String, dynamic>? state, CoachTipContext ctx) {
  if (_map(state?['tutorial'])?['done'] == false) return null;
  final seen = _list(state?['seenTips']);
  for (final tip in coachTips) {
    if (seen.contains(tip.id)) continue;
    if (tip.applies(state, ctx)) return tip;
  }
  return null;
}

/// Spend a tip id.
void markTipSeen(Map<String, dynamic> state, String id) {
  final seen = _seen(state);
  if (!seen.contains(id)) seen.add(id);
}

/// Claim a one-time id for a surface that says Colin's piece ITSELF rather than
/// having a tip pop up over it — the sponsor offer and the rival's bid both
/// carry their explainer as a paragraph inside the card.
///
/// Returns true once, ever, per save. **The ledger has to stay in one place**:
/// two of them and a tip already spent elsewhere would come back.
bool takeTipOnce(Map<String, dynamic>? state, String id) {
  if (state == null) return false;
  if (_map(state['tutorial'])?['done'] == false) return false;
  if (_list(state['seenTips']).contains(id)) return false;
  markTipSeen(state, id);
  return true;
}

/// Mark every already-satisfied tip as seen.
///
/// Run when onboarding ends, so the tutorial's own forced match and scouts do
/// not trigger a pile of tips the moment it closes. **Only conditions that turn
/// true LATER should ever fire** — a tip is a thing you have just discovered,
/// not a summary of what the tutorial made you do.
///
/// **NOTHING CALLS THIS YET, and that is stated rather than left to be found.**
/// The port has no onboarding tutorial, so there is no moment for it: a save
/// with no `tutorial.done` reads as finished, which is exactly what makes the
/// tips live from a player's first minute here. It is the JS's rule, ported and
/// tested, waiting for the screen that needs it — and the flag it keys on is
/// already in the schema and already written by the migration.
void baselineCoachTips(Map<String, dynamic> state, CoachTipContext ctx) {
  for (final tip in coachTips) {
    if (!hasSeenTip(state, tip.id) && tip.applies(state, ctx)) {
      markTipSeen(state, tip.id);
    }
  }
}
