/// The merge grid, derived from the save.
///
/// A cell is either a card or null, and the widget layer never reads the save
/// map directly — it takes the resolved [GridCell] list and hands indices back
/// to `attemptMerge`, which owns every rule about what a drag may do.
library;

import 'package:merge_empire_fc/engine/merge_engine.dart';
import 'package:merge_empire_fc/engine/merge_flow_engine.dart';

import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/engine/player_energy_engine.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';

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
CardView? cardViewFor(Object? raw, {bool proMode = false}) {
  final card = CardInstance.from(raw);
  if (card == null) return null;
  final def = getPlayerDef(card.definitionId);
  if (def == null) return null;
  return (
    name: getCardName(_map(raw), def.name),
    tier: def.tier,
    rating: getCardRating(def),
    position: def.position,
    injured: card.injured,
    onLoan: card.raw['loanMatchesLeft'] != null || card.loanedOut != null,
    variant: (card.raw['variant'] as num?)?.toInt() ?? 0,
    fitness: proMode ? energyPct(card) : null,
  );
}

/// Pro mode. Named for the old "Hard" label; the UI says Pro.
bool isProMode(Map<String, dynamic>? s) =>
    _map(s?['settings'])?['hardMode'] == true;

final gridCellsProvider = savePick<List<GridCell>>((s) {
  final cells = gridCells(s);
  // Slots past the roster the player owns are shown LOCKED rather than hidden:
  // a grid that silently grows by one reads as the game glitching, where a
  // locked slot reads as something to work towards.
  final owned = getMaxPlayers(s);
  final pro = isProMode(s);
  return [
    for (var i = 0; i < Grid.totalCells; i++)
      (
        index: i,
        instanceId: i < cells.length && cells[i] is Map<String, dynamic>
            ? (cells[i] as Map<String, dynamic>)['instanceId'] as String?
            : null,
        card: i < cells.length ? cardViewFor(cells[i], proMode: pro) : null,
        locked: i >= owned,
      ),
  ];
});

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
