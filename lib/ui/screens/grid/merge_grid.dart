/// The merge grid — the Players tab, and the game's core loop.
///
/// Three columns by thirteen rows. A card is dragged onto another to merge, or
/// onto an empty slot to move; `attemptMerge` owns every rule about which of
/// those happened and whether it was allowed, so this widget only reports two
/// indices and repaints.
///
/// The JS carries a `pan-y` touch-action workaround, a `card-dragging` body
/// class and a 200ms hold before a drag starts, all to stop a card drag and the
/// tab swipe fighting over the same gesture. None of it is ported: Flutter's
/// gesture arena is what that code was hand-building, and `LongPressDraggable`
/// wins the arena on its own.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/engine/merge_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/grid/add_player_button.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart';
import 'package:merge_empire_fc/ui/screens/grid/merge_burst.dart';
import 'package:merge_empire_fc/ui/screens/grid/sell_sheet.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';

class MergeGrid extends ConsumerStatefulWidget {
  const MergeGrid({super.key});

  @override
  ConsumerState<MergeGrid> createState() => MergeGridState();
}

class MergeGridState extends ConsumerState<MergeGrid> {
  /// The cell a merge just landed in, so exactly one card celebrates.
  int? _burstAt;
  int _burstTier = 1;

  void _drop(WidgetRef ref, int from, int to) {
    final game = ref.read(gameProvider);
    final maxTier = ref.read(maxMergeTierProvider);
    final result = game.update(
      (s) => attemptMerge(from, to, gridCells(s), maxTier: maxTier),
    );
    // The engine says WHAT happened; the rest of the app decides what to make
    // of it. A refused drag is worth nothing at all.
    if (!result.ok) return;
    // Only a MERGE is celebrated. A move and a swap are the player tidying up,
    // and applauding those would make the burst mean nothing.
    if (result.action == MergeAction.merge) {
      setState(() {
        _burstAt = to;
        _burstTier = getPlayerDef(result.result?.definitionId)?.tier ?? 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cells = ref.watch(gridCellsProvider);

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            key: const ValueKey('merge-grid'),
            padding: const EdgeInsets.fromLTRB(8, 64, 8, 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: Grid.cols,
              childAspectRatio: 0.78,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: cells.length,
            itemBuilder: (context, i) => _Slot(
              cell: cells[i],
              onDrop: _drop,
              bursting: _burstAt == i,
              burstTier: _burstTier,
              onBurstDone: () {
                if (mounted && _burstAt == i) setState(() => _burstAt = null);
              },
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [_GridTools(), SizedBox(height: 8), AddPlayerButton()],
          ),
        ),
      ],
    );
  }
}

/// Merge All and Sort.
///
/// Both take themselves away when they would do nothing — a "Merge All (0)"
/// and a Sort on an already-sorted grid are buttons that answer a tap with
/// silence, which teaches the player to stop pressing them.
class _GridTools extends ConsumerWidget {
  const _GridTools();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairs = ref.watch(mergeablePairsProvider);
    final needsSort = ref.watch(gridNeedsSortProvider);
    final maxTier = ref.watch(maxMergeTierProvider);
    final game = ref.read(gameProvider);
    if (pairs == 0 && !needsSort) return const SizedBox.shrink();

    return Row(
      children: [
        if (pairs > 0)
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('merge-all'),
              onPressed: () {
                game.update((s) => mergeAll(gridCells(s), maxTier: maxTier));
                // One announcement for the batch, not one per pair: the
                // achievement sweep and the quest counters both listen, and a
                // twelve-pair sweep is one action the player took.
                emit('merge:happened');
              },
              icon: const Icon(Icons.merge, size: 16),
              label: Text('${t('players.mergeAll')} ($pairs)'),
            ),
          ),
        if (pairs > 0 && needsSort) const SizedBox(width: 8),
        if (needsSort)
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('grid-sort'),
              onPressed: () => game.update((s) => sortGridByTier(gridCells(s))),
              icon: const Icon(Icons.sort, size: 16),
              label: Text(t('players.sort')),
            ),
          ),
      ],
    );
  }
}

class _Slot extends ConsumerWidget {
  const _Slot({
    required this.cell,
    required this.onDrop,
    this.bursting = false,
    this.burstTier = 1,
    this.onBurstDone,
  });

  final GridCell cell;
  final void Function(WidgetRef ref, int from, int to) onDrop;
  final bool bursting;
  final int burstTier;
  final VoidCallback? onBurstDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;

    if (cell.locked) {
      return _Empty(
        key: ValueKey('grid-locked-${cell.index}'),
        border: kit.border,
        child: Icon(Icons.lock_outline, size: 16, color: kit.textMuted),
      );
    }

    final card = cell.card;

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != cell.index,
      onAcceptWithDetails: (details) => onDrop(ref, details.data, cell.index),
      builder: (context, candidate, _) {
        final hovered = candidate.isNotEmpty;
        if (card == null) {
          return _Empty(
            key: ValueKey('grid-empty-${cell.index}'),
            border: hovered ? kit.accent : kit.border,
          );
        }
        final tile = PlayerCard(
          key: ValueKey('grid-card-${cell.index}'),
          view: card,
          light: Theme.of(context).brightness == Brightness.light,
          selected: hovered,
          // A tap opens the sell sheet; the DRAG is the merge. Two gestures,
          // two meanings, and the arena keeps them apart.
          onTap: () {
            final id = cell.instanceId;
            if (id != null) {
              showSellSheet(context, ref, instanceId: id, view: card);
            }
          },
        );
        return MergeBurst(
          tier: burstTier,
          playing: bursting,
          onDone: onBurstDone,
          child: LongPressDraggable<int>(
            data: cell.index,
            // A hold, not an instant grab: a flick across the grid is the tab
            // swipe, and the arena hands it over only once the hold has won.
            delay: const Duration(milliseconds: 200),
            feedback: SizedBox(width: 84, height: 108, child: tile),
            childWhenDragging: _Empty(border: kit.border),
            child: tile,
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({super.key, required this.border, this.child});

  final Color border;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Center(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// The Players tab.
class GridScreen extends StatelessWidget {
  const GridScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      Semantics(label: t('nav.players'), child: const MergeGrid());
}
