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
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

class MergeGrid extends ConsumerWidget {
  const MergeGrid({super.key});

  void _drop(WidgetRef ref, int from, int to) {
    final game = ref.read(gameProvider);
    final maxTier = ref.read(maxMergeTierProvider);
    final result = game.update(
      (s) => attemptMerge(from, to, gridCells(s), maxTier: maxTier),
    );
    // The engine says WHAT happened; the rest of the app decides what to make
    // of it. A merge is worth a sound and an animation, a refused drag is not.
    if (result.ok) emit('card:placed', result.result?.instanceId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            itemBuilder: (context, i) => _Slot(cell: cells[i], onDrop: _drop),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: AddPlayerButton(),
        ),
      ],
    );
  }
}

class _Slot extends ConsumerWidget {
  const _Slot({required this.cell, required this.onDrop});

  final GridCell cell;
  final void Function(WidgetRef ref, int from, int to) onDrop;

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
        );
        return LongPressDraggable<int>(
          data: cell.index,
          // A hold, not an instant grab: a flick across the grid is the tab
          // swipe, and the arena hands it over only once the hold has won.
          delay: const Duration(milliseconds: 200),
          feedback: SizedBox(width: 84, height: 108, child: tile),
          childWhenDragging: _Empty(border: kit.border),
          child: tile,
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
