/// Card creation, merging and grid placement, ported from
/// `../merge-empire-fc/src/engine/mergeEngine.js`.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/player_art.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/sorting.dart';
import 'package:merge_empire_fc/util/time.dart';

int _instanceCounter = 0;

/// Instance creation uses unseeded randomness, matching the JS
/// `Math.random()`. Drawing from the shared seeded stream would shift every
/// subsequent gameplay draw and break parity with the JS engines.
math.Random _rng = math.Random();

/// Test seam. Pass a seeded generator for deterministic instances.
void setMergeRandom(math.Random rng) => _rng = rng;

void resetMergeRandom() => _rng = math.Random();

/// Resets the instance counter. Tests only — ids must stay unique in a session.
void resetInstanceCounter() => _instanceCounter = 0;

/// Picks a variant index whose gender matches [female].
///
/// Used when merging: the merged card inherits its parents' gender rather than
/// re-rolling it, so two boys always merge into a boy and two girls into a girl.
int _pickVariantForGender(bool female) {
  final pool = <int>[
    for (var i = 0; i < playerVariants; i++)
      if (i < variants.length && variants[i].female == female) i,
  ];
  if (pool.isEmpty) return 0;
  return pool[_rng.nextInt(pool.length)];
}

int _jsRound(num v) => (v + 0.5).floor();

/// Creates a fresh card instance.
///
/// [preferredFemale] pins the gender — merges pass the parents' gender through;
/// a scout passes null and the variant is rolled freely.
CardInstance createInstance(String definitionId, {bool? preferredFemale}) {
  final variant = preferredFemale == null
      ? _rng.nextInt(playerVariants)
      : _pickVariantForGender(preferredFemale);

  final def = getPlayerDef(definitionId);

  // Gender-appropriate display name, for player cards only. Club assets go
  // through a different path and have no definition here.
  String? displayName;
  if (def != null) {
    final tierIdx = math.max(0, def.tier - 1);
    displayName = pickDisplayName(
      def.position,
      tierIdx,
      female: isVariantFemale(variant),
    );
  }

  // T9 is always exactly 100; everything else gets a small random spread so
  // two cards of the same tier and position have different ratings.
  final ratingBonus = def?.tier == 9 ? 0 : _rng.nextInt(5) - 2;

  // Per-instance ATK/DEF split: each card rolls its own ratio within its
  // position's range, so two copies of one definition genuinely differ.
  final (lo, hi) = ratioRange[def?.position] ?? (0.35, 0.65);
  final attackRatio =
      _jsRound((lo + _rng.nextDouble() * (hi - lo)) * 100) / 100;

  return CardInstance(<String, dynamic>{
    'definitionId': definitionId,
    'instanceId': '${definitionId}_${now()}_${_instanceCounter++}',
    'seasonsPlayed': 0,
    'form': 0,
    'variant': variant,
    'ratingBonus': ratingBonus,
    'attackRatio': attackRatio,
    // Pro-mode fatigue: a player card starts full, with a bar maxing at its
    // base rating. Club assets get no energy at all.
    if (def != null) 'energy': getCardRating(def, ratingBonus: ratingBonus),
    if (def != null) 'energyUpdatedAt': now(),
    'displayName': ?displayName,
    'stats': <String, dynamic>{
      'goals': 0,
      'assists': 0,
      'tackles': 0,
      'saves': 0,
      'matchesPlayed': 0,
    },
  });
}

PlayerDef? getDefinition(String? definitionId) => getPlayerDef(definitionId);

enum MergeAction { move, merge, swap }

/// The outcome of a drag.
class MergeResult {
  const MergeResult({
    required this.ok,
    this.action,
    this.reason,
    this.blocked,
    this.result,
    this.requiredTier,
  });

  final bool ok;
  final MergeAction? action;

  /// Why the drag did nothing: `same_cell`, `empty_source`,
  /// `unknown_definition`, `division_locked`.
  final String? reason;

  /// Which side of a loan arrangement blocked the merge: `loan` or `loan_out`.
  final String? blocked;

  final CardInstance? result;
  final int? requiredTier;
}

/// Which side of a loan arrangement blocks a merge, if either.
///
/// A loanee is not ours to consume, and merging one would quietly swallow a
/// permanent card and break the "they leave" contract. A player lent OUT is at
/// another club: consuming them would destroy a card we are contractually due
/// back, and the borrowing side would hold a player who no longer exists.
String? loanBlock(CardInstance c) {
  if (c.raw['loanMatchesLeft'] != null) return 'loan';
  if (c.loanedOut != null) return 'loan_out';
  return null;
}

/// Attempts to merge or move a card between two grid slots, mutating [cells].
///
/// [maxTier] caps merges by division.
MergeResult attemptMerge(
  int sourceIdx,
  int targetIdx,
  List<dynamic> cells, {
  Map<String, dynamic>? stats,
  int? maxTier,
}) {
  if (sourceIdx == targetIdx) {
    return const MergeResult(ok: false, reason: 'same_cell');
  }

  final sourceCard = CardInstance.from(cells[sourceIdx]);
  if (sourceCard == null) {
    return const MergeResult(ok: false, reason: 'empty_source');
  }

  final targetCard = CardInstance.from(cells[targetIdx]);

  if (targetCard == null) {
    cells[targetIdx] = sourceCard.raw;
    cells[sourceIdx] = null;
    return const MergeResult(ok: true, action: MergeAction.move);
  }

  void swap() {
    cells[sourceIdx] = targetCard.raw;
    cells[targetIdx] = sourceCard.raw;
  }

  // Different cards — swap positions so the grid can be rearranged.
  if (targetCard.definitionId != sourceCard.definitionId) {
    swap();
    return const MergeResult(ok: true, action: MergeAction.swap);
  }

  // Swap rather than refuse on a loan block: the drag still does something, so
  // it reads as a rule and not a dead grid.
  final blocked = loanBlock(sourceCard) ?? loanBlock(targetCard);
  if (blocked != null) {
    swap();
    return MergeResult(ok: true, action: MergeAction.swap, blocked: blocked);
  }

  final def = getDefinition(sourceCard.definitionId);
  if (def == null) {
    return const MergeResult(ok: false, reason: 'unknown_definition');
  }

  // The gender rule applies to player cards only — club assets have no gender,
  // so two same-def assets with different random variants must still merge.
  final sourceVariant = (sourceCard.raw['variant'] as num?)?.toInt() ?? 0;
  final targetVariant = (targetCard.raw['variant'] as num?)?.toInt() ?? 0;
  if (isVariantFemale(sourceVariant) != isVariantFemale(targetVariant)) {
    swap();
    return const MergeResult(ok: true, action: MergeAction.swap);
  }

  // Same definition but already at the ceiling — swap so pairs of legendary
  // cards can still be rearranged.
  if (def.mergesInto == null) {
    swap();
    return const MergeResult(ok: true, action: MergeAction.swap);
  }

  if (maxTier != null) {
    final nextDef = getDefinition(def.mergesInto);
    if (nextDef != null && nextDef.tier > maxTier) {
      return MergeResult(
        ok: false,
        reason: 'division_locked',
        requiredTier: nextDef.tier,
      );
    }
  }

  // The merged card inherits its parents' gender — they are required to match,
  // so either parent's variant names the right pool.
  final newCard = createInstance(
    def.mergesInto!,
    preferredFemale: isVariantFemale(sourceVariant),
  );
  cells[targetIdx] = newCard.raw;
  cells[sourceIdx] = null;

  if (stats != null) {
    stats['totalMerges'] = ((stats['totalMerges'] as num?)?.toInt() ?? 0) + 1;
    final newDef = getDefinition(def.mergesInto);
    final highest = (stats['highestTier'] as num?)?.toInt() ?? 1;
    if (newDef != null && newDef.tier > highest) {
      stats['highestTier'] = newDef.tier;
    }
  }

  emit('merge:complete', {
    'newCard': newCard,
    'newDef': getDefinition(def.mergesInto),
  });
  return MergeResult(ok: true, action: MergeAction.merge, result: newCard);
}

/// Index of the first empty slot, or -1.
///
/// Treats null and a missing entry alike — old saves sometimes had undefined
/// slots.
int findFirstEmpty(List<dynamic> cells) => cells.indexWhere((c) => c == null);

/// Places a fresh instance in the first empty slot.
({bool ok, int? idx, String? reason}) placeCard(
  String definitionId,
  List<dynamic> cells,
) {
  final idx = findFirstEmpty(cells);
  if (idx == -1) return (ok: false, idx: null, reason: 'grid_full');
  final card = createInstance(definitionId);
  cells[idx] = card.raw;
  emit('card:placed', {'card': card});
  return (ok: true, idx: idx, reason: null);
}

/// Merges every mergeable pair greedily until none remain.
///
/// Sponsored cards are included — the sponsor is dropped on the merged result,
/// exactly as a manual drag-merge does. Returns the number of merges performed.
int mergeAll(List<dynamic> cells, {Map<String, dynamic>? stats, int? maxTier}) {
  var totalMerges = 0;
  var keepGoing = true;

  while (keepGoing) {
    keepGoing = false;

    for (var i = 0; i < cells.length; i++) {
      final a = CardInstance.from(cells[i]);
      if (a == null) continue;

      // Skip loanees outright. attemptMerge would swap them, which is not
      // progress — so the pair would be shuffled around the grid on every
      // Merge All with nothing to show for it.
      if (a.raw['loanMatchesLeft'] != null) continue;

      final def = getDefinition(a.definitionId);
      if (def?.mergesInto == null) continue;

      if (maxTier != null) {
        final nextDef = getDefinition(def!.mergesInto);
        if (nextDef != null && nextDef.tier > maxTier) continue;
      }

      for (var j = i + 1; j < cells.length; j++) {
        final b = CardInstance.from(cells[j]);
        if (b == null) continue;
        if (b.raw['loanMatchesLeft'] != null) continue;
        if (b.definitionId != a.definitionId) continue;

        // Skip mismatched genders — attemptMerge would swap them instead of
        // merging, eating the outer loop's progress tracking.
        final av = (a.raw['variant'] as num?)?.toInt() ?? 0;
        final bv = (b.raw['variant'] as num?)?.toInt() ?? 0;
        if (isVariantFemale(av) != isVariantFemale(bv)) continue;

        final result = attemptMerge(
          i,
          j,
          cells,
          stats: stats,
          maxTier: maxTier,
        );
        if (result.ok && result.action == MergeAction.merge) {
          totalMerges++;
          keepGoing = true;
          break;
        }
      }
      if (keepGoing) break;
    }
  }
  return totalMerges;
}

/// Pack the grid tier-first, best-rated first, with the gaps closed up.
///
/// Lifted out of `ui/components/Grid.js`, which does the sort inline in the
/// screen the way `mergeAll`'s neighbours were before they moved here. Nulls do
/// not sort — they are absence, not a value — so the filled cards are ordered
/// and written back from the top, which closes every gap as a side effect.
///
/// Returns true when anything moved, so a caller can skip an animation that has
/// nothing to show.
bool sortGridByTier(List<dynamic> cells) {
  final filled = [for (final c in cells) ?c];
  final before = [for (final c in cells) CardInstance.from(c)?.instanceId];

  // Stable, so two cards of the same tier and rating keep the order the player
  // last left them in rather than being shuffled by a tie.
  final sorted = stableSorted(filled, (Object? a, Object? b) {
    final cardA = CardInstance.from(a);
    final cardB = CardInstance.from(b);
    final defA = getPlayerDef(cardA?.definitionId);
    final defB = getPlayerDef(cardB?.definitionId);
    final byTier = (defB?.tier ?? 0) - (defA?.tier ?? 0);
    if (byTier != 0) return byTier;
    final ratingA = getCardRating(defA, ratingBonus: cardA?.ratingBonus ?? 0);
    final ratingB = getCardRating(defB, ratingBonus: cardB?.ratingBonus ?? 0);
    return ratingB - ratingA;
  });

  for (var i = 0; i < cells.length; i++) {
    cells[i] = i < sorted.length ? sorted[i] : null;
  }

  for (var i = 0; i < cells.length; i++) {
    if (CardInstance.from(cells[i])?.instanceId != before[i]) return true;
  }
  return false;
}

/// Whether a sort would change anything — so the button can take itself away
/// when the grid is already in order, rather than sitting there doing nothing.
bool gridNeedsSort(List<dynamic> cells) {
  final probe = [...cells];
  return sortGridByTier(probe);
}
