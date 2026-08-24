/// A merge as the PLAYER performs it — everything around `attemptMerge`.
///
/// Lifted out of `ui/components/Grid.js` (`_executeMerge`) and
/// `ui/screens/GridScreen.js` (`_mergeAll`), which is where all of it lived. The
/// port had the move and none of the bookkeeping, and each missing piece was
/// invisible from the grid itself:
///
/// - **Career totals never grew.** `attemptMerge` only counts when it is handed
///   a `stats` map, and the grid was not handing it one — so `totalMerges` and
///   `highestTier` sat at zero, and every achievement that reads them was
///   unreachable by merging.
/// - **The two merge quests could not advance.** Nothing called the action
///   funnel, which is what `season_merge` and `season_merge_hard` are counted
///   through.
/// - **A pending transfer offer for a merged card was never cancelled.** Both
///   parents are consumed, so the club that bid is left waiting on a player who
///   no longer exists.
/// - **Merge All was free.** The JS charges half a scout, and refuses when the
///   money is not there.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/quests.dart';
import 'package:merge_empire_fc/engine/merge_engine.dart';
import 'package:merge_empire_fc/engine/season_end.dart' show trackEvent;
import 'package:merge_empire_fc/engine/transfer_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/format.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

List<dynamic> _cells(Map<String, dynamic>? state) {
  final cells = _map(state?['grid'])?['cells'];
  return cells is List ? cells : const [];
}

/// The career ledger, repaired in place if the save has none.
///
/// A prestige preserves this branch while `stats` is wiped, which is why the
/// achievements read it first — so the count has to land here as well as there.
Map<String, dynamic> _careerStats(Map<String, dynamic> state) {
  final existing = _map(state['careerStats']);
  if (existing != null) return existing;
  final fresh = <String, dynamic>{
    'leagueWins': 0,
    'cupWins': 0,
    'matchesWon': 0,
    'totalMerges': 0,
  };
  state['careerStats'] = fresh;
  return fresh;
}

String? _instanceIdAt(List<dynamic> cells, int idx) =>
    idx >= 0 && idx < cells.length
    ? CardInstance.from(cells[idx])?.instanceId
    : null;

void _countMerges(Map<String, dynamic> state, int merges) {
  if (merges <= 0) return;
  final career = _careerStats(state);
  career['totalMerges'] = ((_num(career['totalMerges']) ?? 0) + merges).toInt();
  trackEvent(state, QuestAction.mergeCount, merges);
}

/// The tier ladder a merge has reached, reported to the quest track.
///
/// Below tier three there is nothing to say: the ladder starts where the quests
/// do, and `reach_tier` is a MAX action, so a lower number could never move it
/// anyway. Guarded here rather than there so the funnel is not called for a
/// value it will discard.
void _countHighestTier(Map<String, dynamic> state) {
  final highest = _num(_map(state['stats'])?['highestTier'])?.toInt() ?? 1;
  if (highest >= 3) trackEvent(state, QuestAction.reachTier, highest);
}

/// One merge the player dragged, and everything the game makes of it.
typedef MergeFlow = ({
  bool ok,
  MergeAction? action,
  String? reason,
  String? blocked,
  int? requiredTier,
  CardInstance? result,

  /// The tier of what came out, or 1 when nothing did.
  int tier,

  /// The merged card is a player nobody has ever seen before.
  bool isNewDiscovery,

  /// The club whose pending bid died with one of the parents, if any.
  String? grudgeTeam,

  /// Where the merged card ENDED UP, which is not always where it was dropped:
  /// closing the gaps behind a merge slides it down past every hole ahead of it.
  /// The celebration is played at this cell — a burst at the drop index would
  /// fire on whatever card slid into it.
  int? landedAt,
});

MergeFlow _flow(
  MergeResult result, {
  int tier = 1,
  bool isNewDiscovery = false,
  String? grudgeTeam,
  int? landedAt,
}) => (
  ok: result.ok,
  action: result.action,
  reason: result.reason,
  blocked: result.blocked,
  requiredTier: result.requiredTier,
  result: result.result,
  tier: tier,
  isNewDiscovery: isNewDiscovery,
  grudgeTeam: grudgeTeam,
  landedAt: landedAt,
);

/// Drag [from] onto [to]: merge, move or swap, and count whatever happened.
///
/// The two instance ids are read BEFORE the merge, because a merge consumes both
/// parents and the offer that has to be cancelled may be for either of them.
MergeFlow performMerge(
  Map<String, dynamic> state,
  int from,
  int to, {
  int? maxTier,
}) {
  final cells = _cells(state);
  final sourceId = _instanceIdAt(cells, from);
  final targetId = _instanceIdAt(cells, to);

  final result = attemptMerge(
    from,
    to,
    cells,
    stats: _map(state['stats']),
    maxTier: maxTier,
  );
  if (!result.ok) {
    // The one refusal worth explaining: the pair is fine and the DIVISION is
    // what said no, so the player is being told to keep climbing rather than
    // that they did something wrong.
    if (result.reason == 'division_locked') {
      emit('merge:refused', {
        'reason': 'division_locked',
        'tier': result.requiredTier,
      });
    }
    return _flow(result);
  }
  if (result.action != MergeAction.merge) return _flow(result);

  _countMerges(state, 1);
  _countHighestTier(state);

  // Rival interest tracks a card leaving the squad however it leaves, so a merge
  // does not strand a bid. Either parent may be the one that was wanted, and the
  // grudge is recorded whichever it was.
  final grudge =
      (sourceId == null ? null : notifyCardRemoved(state, sourceId)) ??
      (targetId == null ? null : notifyCardRemoved(state, targetId));
  if (grudge != null) emit('transfer:grudge', {'team': grudge});

  final newDef = getDefinition(result.result?.definitionId);
  // `merge:complete` fires synchronously inside [attemptMerge], so the discovery
  // listener has already counted this card by the time it is asked about — the
  // same coupling the scout flow relies on.
  final firstSighting = isFirstSighting(state, cells[to]);

  // The hole the source cell just became, closed up — see [closeGridGaps]. Here
  // rather than in `attemptMerge` because only a MERGE leaves a hole worth
  // closing: a move onto an empty square is the player placing a card, and
  // closing up after that would undo the placement.
  //
  // The merged card is KEPT where it was dropped, so the burst, the pop and the
  // new face all happen in the cell the player is looking at rather than a
  // neighbour bouncing into it.
  //
  // **After the read above, not before it.** `cells[to]` is only the new card
  // until this runs.
  final landedAt = closeGridGaps(cells, keepAt: to);

  emit('merge:happened');

  return _flow(
    result,
    tier: newDef?.tier ?? 1,
    isNewDiscovery: firstSighting,
    grudgeTeam: grudge,
    landedAt: landedAt,
  );
}

// ── Merge All ───────────────────────────────────────────────────────────────

/// What sweeping the grid costs: half a scout at this division's rate.
///
/// The division's BASE rate, deliberately — not [scoutCost]'s discounted one.
/// The Youth Academy discounts signings, and the JS prices this off
/// `SCOUT.BASE_COST_BY_DIV` directly, so an Academy does not quietly make the
/// sweep cheaper too.
int mergeAllCost(Map<String, dynamic>? state) {
  final divId = _map(state?['progression'])?['currentDivision'] as String?;
  final div = getDivision(divId ?? divisions.first.id);
  final base = Scout.baseCostByDiv[div.id] ?? Scout.baseCost;
  return roundCoins(base * 0.5);
}

/// How many pairs a sweep would actually eliminate.
///
/// **Run against a COPY, and SILENTLY: asking the question must not answer it.**
/// The copy was there from the start and protected the grid; what it did not
/// protect was the BUS. Every probe merge fired `merge:complete`, whose
/// listener re-syncs the lineup and writes to the save — so counting the pairs
/// behind a "Merge All (3)" button announced three merges that never happened,
/// on every rebuild of the button.
int mergeablePairs(Map<String, dynamic>? state, {int? maxTier}) {
  final probe = [
    for (final c in _cells(state))
      if (c is Map<String, dynamic>) <String, dynamic>{...c} else c,
  ];
  return mergeAll(
    probe,
    maxTier: maxTier ?? _divisionTier(state),
    announce: false,
  );
}

int _divisionTier(Map<String, dynamic>? state) {
  final divId = _map(state?['progression'])?['currentDivision'] as String?;
  return getDivision(divId ?? divisions.first.id).maxPlayerTier;
}

/// What a sweep did, or why it did not happen.
typedef MergeAllRun = ({
  bool ok,

  /// `no_pairs` or `insufficient_coins`.
  String? reason,
  int merges,
  int cost,

  /// Which squares the sweep's new cards ended up in, AFTER the gaps closed.
  ///
  /// **A sweep was invisible.** The grid simply arrived at its answer: no
  /// burst, no slide, nothing to say which pairs had gone. One merge has had
  /// the JS's full set-piece since it was ported and twelve at once had none of
  /// it — and the indices could not be taken from `mergeAll` directly, because
  /// closing the holes moves every card after them.
  List<int> landedAt,
});

/// Merge every pair on the grid, for a flat fee.
///
/// The fee is charged once for the sweep rather than per pair — it is a
/// convenience being bought, not a merge being sold — and it is checked before
/// anything moves, so a club that cannot afford it keeps both its coins and its
/// pairs.
MergeAllRun runMergeAll(Map<String, dynamic> state, {int? maxTier}) {
  final tier = maxTier ?? _divisionTier(state);
  final cost = mergeAllCost(state);
  if (mergeablePairs(state, maxTier: tier) == 0) {
    return (ok: false, reason: 'no_pairs', merges: 0, cost: cost, landedAt: const []);
  }

  final resources = _map(state['resources']);
  final coins = _num(resources?['fanCoins']) ?? 0;
  if (coins < cost) {
    emit('merge:refused', {'reason': 'insufficient_coins', 'coins': cost});
    return (
      ok: false,
      reason: 'insufficient_coins',
      merges: 0,
      cost: cost,
      landedAt: const [],
    );
  }

  final made = <String>{};
  final merges = mergeAll(
    _cells(state),
    stats: _map(state['stats']),
    maxTier: tier,
    mergedIds: made,
  );
  if (merges == 0) {
    return (ok: false, reason: 'no_pairs', merges: 0, cost: cost, landedAt: const []);
  }

  // **AND THE HOLES CLOSE.** Every merge empties the source's cell, so a sweep
  // of a dozen pairs leaves a dozen gaps scattered through the grid — reported
  // as "when I hit merge you have left gaps all over the grid". A DRAG merge has
  // closed them since `closeGridGaps` was written; the sweep never called it.
  //
  // No `keepAt`: that argument exists so a single merge's burst does not play
  // over a hole while a neighbour bounces into the cell the player was watching.
  // A sweep has no one cell being watched — it has twelve — so everything packs
  // to the front in the order it is already in.
  closeGridGaps(_cells(state));

  if (resources != null) {
    resources['fanCoins'] = (coins - cost).toInt();
  }
  _countMerges(state, merges);
  _countHighestTier(state);

  emit('coins:updated', _num(_map(state['resources'])?['fanCoins']));
  // One announcement for the sweep, not one per pair: the achievement check and
  // the quest counters both listen, and a twelve-pair sweep is one action the
  // player took.
  emit('merge:happened');

  // Read AFTER everything above has moved the grid about, which is the whole
  // reason ids came out of `mergeAll` rather than indices.
  final cells = _cells(state);
  return (
    ok: true,
    reason: null,
    merges: merges,
    cost: cost,
    landedAt: [
      for (var i = 0; i < cells.length; i++)
        if (CardInstance.from(cells[i]) case final c?
            when made.contains(c.instanceId))
          i,
    ],
  );
}
