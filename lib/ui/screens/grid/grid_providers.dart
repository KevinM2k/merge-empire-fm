/// The merge grid, derived from the save.
///
/// A cell is either a card or null, and the widget layer never reads the save
/// map directly — it takes the resolved [GridCell] list and hands indices back
/// to `attemptMerge`, which owns every rule about what a drag may do.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/merge_engine.dart';
import 'package:merge_empire_fc/engine/merge_flow_engine.dart';

import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/player_art.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/traits.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/engine/player_energy_engine.dart';
import 'package:merge_empire_fc/engine/scout_signing_engine.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';
import 'package:merge_empire_fc/ui/widgets/trait_copy.dart';

/// One slot: a card, an empty slot the player has room for, or a slot beyond
/// the roster they have not grown into yet.
typedef GridCell = ({
  int index,
  String? instanceId,
  CardView? card,
  bool locked,
});

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

List<dynamic> gridCells(Map<String, dynamic>? state) {
  final cells = _map(state?['grid'])?['cells'];
  return cells is List ? cells : const [];
}

/// The view for one stored card, resolved through the same engines the rest of
/// the game uses — the widget is handed values, never asked to compute them.
/// [state] and [maxTier] are what the MERGE GRID adds and nothing else needs.
///
/// The income line and its bar are a grid concern — the JS's pickers pass
/// `hideIncome` and then none of the rate maths runs at all. A bench sheet is
/// asking "who goes on", not "who earns what", and a looping bar on every card
/// in a modal is a screenful of animation nobody is reading.
CardView? cardViewFor(
  Object? raw, {
  bool proMode = false,
  Map<String, dynamic>? state,
  int? maxTier,
}) {
  final card = CardInstance.from(raw);
  if (card == null) return null;
  final def = getPlayerDef(card.definitionId);
  if (def == null) return null;
  // A borrowed player earns nothing for us, so his card carries no rate — the
  // JS hides the line on one for the same reason.
  //
  // **EITHER KIND OF BORROWED.** `loanMatchesLeft` is the discriminator the
  // loan engine cares about — see its own note on why — and the tutorial lends
  // a side with nothing but `borrowed: true` on it. `idle_engine` has always
  // paid that flag nothing, so the card was quietly earning on screen and
  // never said LOANED, on the eleven cards a brand new player looks at first.
  // Reported from the couch.
  final borrowed =
      card.raw['loanMatchesLeft'] != null || card.raw['borrowed'] == true;
  return (
    name: getCardName(_map(raw), def.name),
    tier: def.tier,
    rating: getCardRating(def),
    position: def.position,
    injured: card.injured,
    onLoan: borrowed || card.loanedOut != null,
    variant: (card.raw['variant'] as num?)?.toInt() ?? 0,
    fitness: proMode ? energyPct(card) : null,
    // What he actually pays, per second, with every club multiplier in it — so
    // the numbers on the grid sum to the rate the HUD shows.
    incomePerSec: borrowed || state == null
        ? null
        : cardIncomePerSec(state, card),
    // Two different ends of the ladder, and they mean different things: MAXED
    // is the top of the game and CAPPED is the top of THIS DIVISION, which
    // moves when you go up.
    maxed: def.mergesInto == null,
    atCap: maxTier != null && def.tier >= maxTier && def.mergesInto != null,
    // **Resolved HERE, like every other value on the view.** The widget is
    // handed what to draw and never asked what a trait is; the catalogue is
    // what names it, and the definition is only the fallback.
    trait: _traitFor(card.raw['trait']),
  );
}

/// The glyph, the level and the localised title of a card's trait, or null for
/// a card carrying none — or one whose id the data no longer knows.
({String icon, String level, String title})? _traitFor(Object? raw) {
  if (raw is! Map<String, dynamic>) return null;
  final trait = getTrait(raw['id'] as String?);
  if (trait == null) return null;
  final level = (raw['level'] as num?)?.toInt();
  return (
    icon: trait.icon,
    level: (level == null ? null : getTraitLevel(trait, level)?.label) ?? '',
    title: traitTitle(raw),
  );
}

/// Pro mode. Named for the old "Hard" label; the UI says Pro.
bool isProMode(Map<String, dynamic>? s) =>
    _map(s?['settings'])?['hardMode'] == true;

/// Cards that are IN the save but should not be on the grid yet.
///
/// A signing is placed by the engine — that is what allocates its square and
/// charges for it — and only then turned over. So for the length of the reveal
/// the card is in the cell the player is about to watch it fly into, and the
/// flight landed on top of a card that was already sitting there. Held back by
/// instance id until the reveal has finished, so the square is empty until the
/// card arrives in it.
final gridPendingProvider = StateProvider<Set<String>>((_) => const {});

/// The tutorial's loan is going home, and the grid is showing it leave.
///
/// **Set BEFORE the save loses them and cleared after**, which is the only way
/// round the obvious problem: a card cannot fly out of a square it has already
/// been deleted from. The tutorial holds the removal for
/// [loanDepartureWindow], and this is what tells the grid to spend that window
/// animating rather than sitting still — see `tutorial_overlay.dart`.
final loanDepartingProvider = StateProvider<bool>((_) => false);

final gridCellsProvider = Provider<List<GridCell>>((ref) {
  ref.watch(saveRevisionProvider);
  final s = ref.watch(gameProvider).state ?? const <String, dynamic>{};
  final pending = ref.watch(gridPendingProvider);
  final cells = gridCells(s);
  // Slots past the roster the player owns are shown LOCKED rather than hidden:
  // a grid that silently grows by one reads as the game glitching, where a
  // locked slot reads as something to work towards.
  final owned = getMaxPlayers(s);
  final pro = isProMode(s);
  return [
    for (var i = 0; i < Grid.totalCells; i++)
      if (_pendingAt(cells, i, pending))
        // Empty for now: the card is in the save but still in the air.
        (index: i, instanceId: null, card: null, locked: i >= owned)
      else
        (
          index: i,
          instanceId: i < cells.length && cells[i] is Map<String, dynamic>
              ? (cells[i] as Map<String, dynamic>)['instanceId'] as String?
              : null,
          card: i < cells.length
              ? cardViewFor(
                  cells[i],
                  proMode: pro,
                  state: s,
                  maxTier: getDivision(
                    _map(s['progression'])?['currentDivision'] as String? ??
                        divisions.first.id,
                  ).maxPlayerTier,
                )
              : null,
          locked: i >= owned,
        ),
  ];
});

/// The players the tutorial has lent the club, in grid order.
///
/// **The flag is on the stored instance, not on [GridCell].** A borrowed player
/// is a tutorial fact rather than a card fact — nothing else on the grid asks
/// and the view already carries `onLoan` for the pill — so it stays out of the
/// record every square in the game is built from and is asked for here instead.
final loanCardIdsProvider = Provider<List<String>>((ref) {
  ref.watch(saveRevisionProvider);
  final s = ref.watch(gameProvider).state;
  return [
    for (final raw in gridCells(s))
      if (_map(raw) case final cell?)
        if (cell['borrowed'] == true)
          if (cell['instanceId'] case final String id) id,
  ];
});

/// The instance ids a batch of signings landed in, for [gridPendingProvider].
///
/// Read off the CELLS rather than the signings, because a `Signing` carries the
/// square it went into and not the card that ended up there.
Set<String> pendingInstanceIds(
  Map<String, dynamic>? state,
  List<Signing> placed,
) {
  final cells = gridCells(state);
  return {
    for (final signing in placed)
      if (signing.idx case final idx?)
        if (idx < cells.length && cells[idx] is Map<String, dynamic>)
          if ((cells[idx] as Map<String, dynamic>)['instanceId']
              case final String id)
            id,
  };
}

bool _pendingAt(List<dynamic> cells, int i, Set<String> pending) {
  if (pending.isEmpty || i >= cells.length) return false;
  final cell = cells[i];
  return cell is Map<String, dynamic> && pending.contains(cell['instanceId']);
}

/// How many cards are on the grid, and how many it may hold.
///
/// One provider rather than two, because the pill compares them: a `filled` that
/// rebuilt without its `max` could paint itself full against a stale limit.
final gridCountProvider = savePick<({int filled, int max})>(
  (s) => (
    filled: gridCells(s).where((c) => c != null).length,
    max: getMaxPlayers(s),
  ),
);

/// The highest tier this division may hold.
final maxMergeTierProvider = savePick<int>((s) {
  final id = _map(s['progression'])?['currentDivision'] as String?;
  return getDivision(id ?? divisions.first.id).maxPlayerTier;
});

/// How many pairs a Merge All would actually eliminate.
///
/// Counted rather than assumed, because the button carries the number and a
/// "Merge All (0)" is a button that does nothing.
final mergeablePairsProvider = savePick<int>((s) => mergeablePairs(s));

/// What the sweep costs — half a scout, on the button beside the count.
final mergeAllCostProvider = savePick<int>(mergeAllCost);

/// Whether sorting would move anything. The button takes itself away when the
/// grid is already in order rather than sitting there doing nothing.
final gridNeedsSortProvider = savePick<bool>(
  (s) => gridNeedsSort(gridCells(s)),
);

/// Whether this save is in Pro mode. Watched by anything whose LABEL changes
/// with it, not just its behaviour.
final proModeProvider = savePick<bool>(isProMode);

/// The cells the card at [from] could actually MERGE with.
///
/// Ported from `_markDragTargets` in `components/Grid.js`, and the rule is
/// exact: the same definition, not caught in a loan either way, a tier that has
/// somewhere to go, and the same gender. Anything else dims while the card is in
/// the air.
///
/// A LOAN-BLOCKED card in hand has no targets at all, which greys the whole grid
/// out — deliberately. Dropping it still swaps; the point is that the grid stops
/// offering a merge before the player lets go of it.
///
/// **The DIVISION's ceiling counts too.** `mergesInto` only says the card has a
/// next tier at all; whether this division allows it is `maxPlayerTier`, which
/// `attemptMerge` checks and refuses with `division_locked`. Without it here, a
/// pair the league will not let you make wore the gold ring and lit up as a drop
/// target — the grid promised a merge and then turned it down.
Set<int> mergeTargetsFor(Map<String, dynamic>? state, int from) {
  final cells = gridCells(state);
  if (from < 0 || from >= cells.length) return const {};
  final source = CardInstance.from(cells[from]);
  if (source == null || loanBlock(source) != null) return const {};
  final sourceFemale = isVariantFemale(source.variant);
  final divisionId = _map(state?['progression'])?['currentDivision'] as String?;
  final maxTier = getDivision(divisionId ?? divisions.first.id).maxPlayerTier;

  final out = <int>{};
  for (var i = 0; i < cells.length; i++) {
    if (i == from) continue;
    final c = CardInstance.from(cells[i]);
    if (c == null || loanBlock(c) != null) continue;
    if (c.definitionId != source.definitionId) continue;
    final into = getPlayerDef(c.definitionId)?.mergesInto;
    if (into == null) continue;
    if ((getPlayerDef(into)?.tier ?? 0) > maxTier) continue;
    if (isVariantFemale(c.variant) != sourceFemale) continue;
    out.add(i);
  }
  return out;
}

/// Every cell whose twin is somewhere else on the grid.
///
/// The spatial merge hint: a card with a partner out there wears a pulsing gold
/// ring, so a player spots the pair at a glance instead of reading nine names.
/// Computed once for the whole grid rather than per card — a card asking "is
/// anyone my twin" is the same sweep twenty-six times over.
final mergeableCellsProvider = savePick<Set<int>>((s) {
  final cells = gridCells(s);
  final out = <int>{};
  for (var i = 0; i < cells.length; i++) {
    if (out.contains(i)) continue;
    final targets = mergeTargetsFor(s, i);
    if (targets.isEmpty) continue;
    out.add(i);
    out.addAll(targets);
  }
  return out;
});
