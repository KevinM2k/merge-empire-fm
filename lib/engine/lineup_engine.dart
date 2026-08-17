/// Lineup construction, ported from the rating-dependent half of
/// `../merge-empire-fc/src/data/formations.js`.
///
/// The formation table itself and the pure list surgery live in
/// `data/formations.dart`; these functions score players by effective rating
/// and fatigue, so they belong on the engine side of the dependency edge.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/player_energy_engine.dart';
import 'package:merge_empire_fc/engine/player_rating.dart';
import 'package:merge_empire_fc/state/card_instance.dart';

/// How much a player loses playing out of position.
///
/// A keeper anywhere else — or anyone in goal — is the worst case; a forward at
/// the back, or a defender up front, is nearly as bad; anything else is a mild
/// adjustment.
double positionPenalty(String playerPos, String slotPos) {
  if (playerPos == slotPos) return 0;
  if (playerPos == 'GK' || slotPos == 'GK') return 0.5;
  if ((playerPos == 'FWD' && slotPos == 'DEF') ||
      (playerPos == 'DEF' && slotPos == 'FWD')) {
    return 0.35;
  }
  return 0.2;
}

/// Fitness rounded to the whole percent the bar shows, so two players reading
/// the same on screen sort as equal rather than on sub-percent noise.
int _fitnessPct(CardInstance card) => (energyPct(card) * 100 + 0.5).floor();

class _Candidate {
  _Candidate(this.card, this.def, this.rating, this.fitnessPct);

  final CardInstance card;
  final PlayerDef def;
  final int rating;
  final int? fitnessPct;
}

class _Pair {
  const _Pair(this.eff, this.playerIdx, this.slotIdx);
  final double eff;
  final int playerIdx;
  final int slotIdx;
}

/// Auto-assigns the best available players to a formation's slots.
///
/// Pairs are scored by what a player actually contributes IN that slot. In Pro
/// mode ("Rotate") that is rating times position penalty times the fatigue
/// factor — the same maths the match uses — so a 76%-fit midfielder still beats
/// a fresher defender shoved into midfield, and fitness only separates players
/// of equal in-slot value. In Casual ("Auto") fitness is irrelevant.
List<LineupSlot> buildDefaultLineup(
  String? formationId,
  List<CardInstance?> gridCells, {
  bool fatigue = false,
}) {
  final slots = getFormation(formationId).slots;

  final candidates = <_Candidate>[];
  for (final card in gridCells) {
    if (card == null || !card.isSelectable) continue;
    final def = getPlayerDef(card.definitionId);
    if (def == null) continue;
    candidates.add(
      _Candidate(
        card,
        def,
        getEffectiveRating(card),
        fatigue ? _fitnessPct(card) : null,
      ),
    );
  }

  final pairs = <_Pair>[];
  for (var pi = 0; pi < candidates.length; pi++) {
    final p = candidates[pi];
    for (var si = 0; si < slots.length; si++) {
      final fat = fatigue ? fatigueRatingFactor(p.fitnessPct! / 100) : 1.0;
      final eff =
          p.rating * (1 - positionPenalty(p.def.position, slots[si].slotPosition)) * fat;
      pairs.add(_Pair(eff, pi, si));
    }
  }

  pairs.sort((a, b) {
    if (b.eff != a.eff) return b.eff.compareTo(a.eff);
    // Equal in-slot value: prefer the fresher player. Rotation flavour.
    if (!fatigue) return 0;
    return candidates[b.playerIdx].fitnessPct!
        .compareTo(candidates[a.playerIdx].fitnessPct!);
  });

  // Greedy assignment: take the best remaining pair whose player and slot are
  // both still free.
  final usedPlayers = <int>{};
  final usedSlots = <int>{};
  final assignments = <String, String>{};
  final target = candidates.length < slots.length ? candidates.length : slots.length;

  for (final pair in pairs) {
    if (usedPlayers.contains(pair.playerIdx) || usedSlots.contains(pair.slotIdx)) {
      continue;
    }
    usedPlayers.add(pair.playerIdx);
    usedSlots.add(pair.slotIdx);
    assignments[slots[pair.slotIdx].slotId] =
        candidates[pair.playerIdx].card.instanceId;
    if (usedSlots.length == target) break;
  }

  return [
    for (final slot in slots)
      LineupSlot(
        slotId: slot.slotId,
        slotPosition: slot.slotPosition,
        cardInstanceId: assignments[slot.slotId],
      ),
  ];
}

/// Fills empty slots without disturbing anyone already placed.
///
/// Called after scouting so a new arrival slots into any open position. Uses
/// the same scoring as [buildDefaultLineup], so a position match is always
/// preferred over raw rating.
List<LineupSlot> fillLineupGaps(
  List<LineupSlot> lineup,
  String? formationId,
  List<CardInstance?> gridCells,
) {
  final emptyIndices = <int>[
    for (var i = 0; i < lineup.length; i++)
      if (lineup[i].cardInstanceId == null) i,
  ];
  if (emptyIndices.isEmpty) return lineup;

  final existing = {
    for (final s in lineup)
      if (s.cardInstanceId != null) s.cardInstanceId,
  };

  final available = <CardInstance>[
    for (final c in gridCells)
      if (c != null && c.isSelectable && !existing.contains(c.instanceId)) c,
  ];
  if (available.isEmpty) return lineup;

  final pairs = <_Pair>[];
  for (var pi = 0; pi < available.length; pi++) {
    final def = getPlayerDef(available[pi].definitionId);
    if (def == null) continue;
    for (var ei = 0; ei < emptyIndices.length; ei++) {
      final eff =
          getEffectiveRating(available[pi]) *
          (1 - positionPenalty(def.position, lineup[emptyIndices[ei]].slotPosition));
      pairs.add(_Pair(eff, pi, ei));
    }
  }
  pairs.sort((a, b) => b.eff.compareTo(a.eff));

  final usedPlayers = <int>{};
  final usedSlots = <int>{};
  final assignments = <int, String>{};
  final target =
      available.length < emptyIndices.length ? available.length : emptyIndices.length;

  for (final pair in pairs) {
    if (usedPlayers.contains(pair.playerIdx) || usedSlots.contains(pair.slotIdx)) {
      continue;
    }
    usedPlayers.add(pair.playerIdx);
    usedSlots.add(pair.slotIdx);
    assignments[emptyIndices[pair.slotIdx]] = available[pair.playerIdx].instanceId;
    if (usedSlots.length == target) break;
  }

  return [
    for (var i = 0; i < lineup.length; i++)
      if (lineup[i].cardInstanceId != null)
        lineup[i]
      else if (assignments[i] case final id?)
        lineup[i].copyWith(cardInstanceId: id)
      else
        lineup[i],
  ];
}

/// Drops lineup entries for cards that have left the grid or can no longer be
/// picked, then fills the cleared slots.
///
/// A card still in the grid but no longer PICKABLE is as invalid as one that
/// has gone: a loaned-out player is at another club and the match engine rates
/// them zero. Vacating the slot is not benching anyone — they cannot play — and
/// it repairs a save where one was slotted in before the pickers learned to
/// exclude them.
List<LineupSlot> cleanAndFillLineup(
  List<LineupSlot> lineup,
  String? formationId,
  List<CardInstance?> gridCells,
) {
  final validIds = {
    for (final c in gridCells)
      if (c != null && !c.isUnavailable) c.instanceId,
  };

  final cleaned = [
    for (final slot in lineup)
      slot.cardInstanceId != null && validIds.contains(slot.cardInstanceId)
          ? slot
          : slot.copyWith(clearCard: true),
  ];

  return fillLineupGaps(cleaned, formationId, gridCells);
}

/// Puts the best available bench players into every hole in the saved lineup.
///
/// Call after anything that opens a slot (a starter sold, a transfer accepted)
/// or makes a benched player eligible again (an injury healing). An injury
/// vacates its victim's slot and nothing ever put anyone back: once healed, the
/// player sat on the bench looking perfectly fit while the XI kept kicking off
/// a man short.
///
/// NEVER call this while a match is being played. Filling the hole an injury
/// just left IS an auto-sub, and the manager makes that call.
///
/// Returns true when the lineup changed.
bool refillLineupFromBench(Map<String, dynamic> state) {
  final squad = state['squad'];
  if (squad is! Map) return false;

  final lineupRaw = squad['lineup'];
  if (lineupRaw is! List || lineupRaw.length != 11) return false;

  final lineup = <LineupSlot>[
    for (final s in lineupRaw)
      LineupSlot(
        slotId: (s as Map)['slotId'] as String? ?? '',
        slotPosition: s['slotPosition'] as String? ?? '',
        cardInstanceId: s['cardInstanceId'] as String?,
      ),
  ];

  final grid = state['grid'];
  final cells = grid is Map ? grid['cells'] : null;
  final cards = <CardInstance?>[
    if (cells is List)
      for (final c in cells) CardInstance.from(c),
  ];

  final next = cleanAndFillLineup(
    lineup,
    squad['formation'] as String? ?? defaultFormation,
    cards,
  );

  var changed = false;
  for (var i = 0; i < next.length; i++) {
    if (next[i].cardInstanceId != lineup[i].cardInstanceId) {
      changed = true;
      break;
    }
  }

  if (changed) {
    squad['lineup'] = [
      for (final s in next)
        <String, dynamic>{
          'slotId': s.slotId,
          'slotPosition': s.slotPosition,
          'cardInstanceId': s.cardInstanceId,
        },
    ];
  }
  return changed;
}
