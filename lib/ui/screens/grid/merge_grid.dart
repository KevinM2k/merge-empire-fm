/// The merge grid — the Players tab, and the game's core loop.
///
/// Three columns by thirteen rows, widening to four and five on a bigger screen
/// and narrowing to two on a small one, exactly the ladder `.grid-container`
/// climbs. A card is dragged onto another to merge, or onto an empty slot to
/// move; `merge_flow_engine.dart` owns every rule about which of those happened,
/// whether it was allowed and what the game counts for it, so this widget only
/// reports two indices and repaints.
///
/// **The cards are POSITIONED, not laid out by a grid delegate.** A `GridView`
/// rebuilds a reordered list in place, so the sort landed as an instant snap:
/// every card teleported and nothing told the player what had moved. Each card
/// is an `AnimatedPositioned` keyed by its instance instead, so changing its
/// index IS the animation — the JS does the same thing the hard way with a
/// measure/invert/play pass over `getBoundingClientRect`.
///
/// The JS carries a `pan-y` touch-action workaround, a `card-dragging` body
/// class and a 200ms hold before a drag starts, all to stop a card drag and the
/// tab swipe fighting over the same gesture. None of that is ported: Flutter's
/// gesture arena is what that code was hand-building, and `LongPressDraggable`
/// wins the arena on its own.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/engine/merge_engine.dart';
import 'package:merge_empire_fc/engine/merge_flow_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/grid/add_player_button.dart';
import 'package:merge_empire_fc/ui/screens/grid/auto_tier_sheet.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart';
import 'package:merge_empire_fc/ui/screens/grid/merge_burst.dart';
import 'package:merge_empire_fc/ui/screens/grid/scout_reveal.dart';
import 'package:merge_empire_fc/ui/screens/grid/sell_sheet.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';

/// `aspect-ratio: 3 / 4` on `.cell`.
const double _cellAspect = 4 / 3;
const double _gap = 6;
const double _pad = 8;

/// `.grid-container`'s column ladder, by viewport width.
int gridColumnsFor(double width) {
  if (width >= 800) return 5;
  if (width >= 640) return 4;
  if (width < 359) return 2;
  return Grid.cols;
}

class MergeGrid extends ConsumerStatefulWidget {
  const MergeGrid({super.key});

  @override
  ConsumerState<MergeGrid> createState() => MergeGridState();
}

class MergeGridState extends ConsumerState<MergeGrid> {
  /// The cell a merge just landed in, so exactly one card celebrates.
  int? _burstAt;
  int _burstTier = 1;

  /// The card under the finger, and the cells it could actually MERGE with.
  ///
  /// Everything that is not a target dims, which is the JS's
  /// `.grid-container.is-dragging` rule — and "not a target" is the exact merge
  /// rule, not "not the card in my hand". Dimming every other card said nothing:
  /// what a player needs to see mid-drag is which squares will take it.
  int? _dragging;
  Set<int> _targets = const {};

  Future<void> _drop(int from, int to) async {
    final game = ref.read(gameProvider);
    final maxTier = ref.read(maxMergeTierProvider);
    // `performMerge`, not `attemptMerge`: the move is one line of what a merge
    // IS to the game — the career count, the quest track and a rival's dead bid
    // are the rest of it, and they lived in the JS screen.
    final result = game.update(
      (s) => performMerge(s, from, to, maxTier: maxTier),
    );
    // The engine says WHAT happened; the rest of the app decides what to make
    // of it. A refused drag is worth nothing at all — it has already said so on
    // the bus, where the toast layer is listening.
    if (!result.ok) return;
    // Only a MERGE is celebrated. A move and a swap are the player tidying up,
    // and applauding those would make the burst mean nothing.
    if (result.action != MergeAction.merge) return;
    setState(() {
      _burstAt = to;
      _burstTier = result.tier;
    });

    // A player nobody has ever seen gets the same turn-over a signing does. It
    // is the only card a merge produces that is worth stopping the grid for, and
    // reusing the scout's reveal is what stops the two drifting apart.
    if (!result.isNewDiscovery) return;
    final view = cardViewFor(
      gridCells(game.state)[to],
      proMode: ref.read(proModeProvider),
    );
    if (view == null || !mounted) return;
    await showScoutReveal(context, (
      cards: [(view: view, badge: null, isNewDiscovery: true, vanish: false)],
      caption: t('grid.new_player_found'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cells = ref.watch(gridCellsProvider);

    return Stack(
      children: [
        Column(
          children: [
            // The bar is the FIRST thing on the tab, above the grid. The port had
            // it under the cards with the pills on top, which is the JS's order
            // inverted: the pills are a readout and belong beside the last row
            // they describe, and the two controls a player came here to press
            // belong where the thumb lands first.
            const Padding(
              padding: EdgeInsets.fromLTRB(_pad, hudClearance, _pad, 0),
              child: ScoutActionBar(),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('merge-grid'),
                padding: const EdgeInsets.fromLTRB(_pad, _pad, _pad, 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = gridColumnsFor(
                      MediaQuery.sizeOf(context).width,
                    );
                    final cellW =
                        (constraints.maxWidth - _gap * (cols - 1)) / cols;
                    final cellH = cellW * _cellAspect;
                    final rows = (Grid.totalCells / cols).ceil();

                    Offset at(int i) => Offset(
                      (i % cols) * (cellW + _gap),
                      (i ~/ cols) * (cellH + _gap),
                    );

                    return Column(
                      children: [
                        SizedBox(
                          height: rows * cellH + (rows - 1) * _gap,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // The slots never move, so they are one static
                              // layer under every card. Only the cards animate.
                              for (final cell in cells)
                                Positioned(
                                  left: at(cell.index).dx,
                                  top: at(cell.index).dy,
                                  width: cellW,
                                  height: cellH,
                                  child: _SlotTarget(cell: cell, onDrop: _drop),
                                ),
                              for (final cell in cells)
                                if (cell.card != null)
                                  AnimatedPositioned(
                                    // Keyed by the CARD, not the slot — that is
                                    // what lets the widget follow its card into
                                    // a new index rather than being rebuilt in
                                    // place.
                                    key: ValueKey(
                                      'grid-card-${cell.instanceId}',
                                    ),
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.easeInOutCubic,
                                    left: at(cell.index).dx,
                                    top: at(cell.index).dy,
                                    width: cellW,
                                    height: cellH,
                                    child: _CardSlot(
                                      cell: cell,
                                      width: cellW,
                                      height: cellH,
                                      // Bright if it is the card in hand or a
                                      // square that can take it; dimmed if not.
                                      dimmed:
                                          _dragging != null &&
                                          _dragging != cell.index &&
                                          !_targets.contains(cell.index),
                                      bursting: _burstAt == cell.index,
                                      burstTier: _burstTier,
                                      onDragStart: () => setState(() {
                                        _dragging = cell.index;
                                        _targets = mergeTargetsFor(
                                          ref.read(gameProvider).state,
                                          cell.index,
                                        );
                                      }),
                                      onDragEnd: () => setState(() {
                                        _dragging = null;
                                        _targets = const {};
                                      }),
                                      onBurstDone: () {
                                        if (mounted && _burstAt == cell.index) {
                                          setState(() => _burstAt = null);
                                        }
                                      },
                                    ),
                                  ),
                            ],
                          ),
                        ),
                        // Under the last row of cards, which is where the JS puts
                        // them and what they describe.
                        const _GridStatusStrip(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        const _SortFab(),
      ],
    );
  }
}

/// Sort, as a floating action rather than a third button in the bar.
///
/// It EXISTS ONLY while the grid is out of order — which means it never needs a
/// label, because it only ever appears when pressing it does something. That is
/// also what freed the bar's width for the two controls a player actually uses.
class _SortFab extends ConsumerWidget {
  const _SortFab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    if (!ref.watch(gridNeedsSortProvider)) return const SizedBox.shrink();
    final game = ref.read(gameProvider);

    return Positioned(
      right: 14,
      bottom: 14,
      child: Material(
        key: const ValueKey('grid-sort'),
        color: kit.accent,
        borderRadius: BorderRadius.circular(999),
        elevation: 6,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => game.update((s) => sortGridByTier(gridCells(s))),
          child: Tooltip(
            message: t('players.sort'),
            child: SizedBox(
              height: 40,
              width: 48,
              child: Center(
                child: GameIcon('sort', size: 17, color: kit.accentInk),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How full the grid is, and what is being sold off it without asking.
///
/// The count is the JS's own pill, and it turns red at the roster limit — a
/// player who cannot sign has to be able to see why. The auto-sell pill sits
/// beside it because the rules FIRE here: a scouted card of a switched-on tier
/// never reaches this grid, and surfacing the rule next to the count is what
/// makes "that bronze card never arrived" explainable without going looking.
class _GridStatusStrip extends ConsumerWidget {
  const _GridStatusStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final counted = ref.watch(gridCountProvider);
    final full = counted.filled >= counted.max;
    final tutorialDone = ref.watch(tutorialDoneProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          _Pill(
            pillKey: 'grid-count',
            label: t('grid.player_count', {
              'count': counted.filled,
              'max': counted.max,
            }),
            // A red WASH, not red text on the standard plate: at capacity the
            // pill is the answer to "why can I not sign anyone", and it has to
            // carry from the corner of the eye.
            fill: full ? const Color(0x40E53935) : kit.surface2,
            ink: full ? const Color(0xFFE57373) : kit.accentBright,
            border: full ? const Color(0x80E53935) : kit.accent,
          ),
          // Hidden until the tutorial is done, where the rules are dormant
          // anyway — a switch that cannot do anything yet is worse than none.
          if (tutorialDone)
            _Pill(
              pillKey: 'grid-autosell',
              label:
                  '${t('settings.autoTier')}: '
                  '${ref.watch(autoTierSummaryProvider)}',
              fill: ref.watch(autoTierActiveProvider)
                  ? kit.accent.withValues(alpha: 0.16)
                  : kit.surface2,
              ink: ref.watch(autoTierActiveProvider)
                  ? kit.accentBright
                  : kit.textMuted,
              border: ref.watch(autoTierActiveProvider)
                  ? kit.accent
                  : kit.border,
              // Only this one is a button, so it carries the affordance the
              // badge does not.
              onTap: () => showAutoTierSheet(context),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.pillKey,
    required this.label,
    required this.fill,
    required this.ink,
    required this.border,
    this.onTap,
  });

  final String pillKey;
  final String label;
  final Color fill;
  final Color ink;
  final Color border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey(pillKey),
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: ink,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 5),
              Opacity(
                opacity: 0.7,
                child: GameIcon('chevron', size: 10, color: ink),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The empty slot, and the drop target over it.
///
/// The target lives on the SLOT rather than the card so a drop onto an empty
/// square still lands — the card layer only covers filled indices.
class _SlotTarget extends StatelessWidget {
  const _SlotTarget({required this.cell, required this.onDrop});

  final GridCell cell;
  final void Function(int from, int to) onDrop;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;

    if (cell.locked) {
      return _Slot(
        slotKey: 'grid-locked-${cell.index}',
        border: kit.border,
        fill: kit.surface,
        child: Icon(Icons.lock_outline, size: 16, color: kit.textMuted),
      );
    }

    return DragTarget<int>(
      // Keyed on the SLOT, not on whatever is sitting in it: the cards are their
      // own layer now, so a filled slot's drop target is a sibling of its card
      // rather than an ancestor.
      key: ValueKey('grid-drop-${cell.index}'),
      onWillAcceptWithDetails: (d) => d.data != cell.index,
      onAcceptWithDetails: (d) => onDrop(d.data, cell.index),
      builder: (context, candidate, _) => _Slot(
        slotKey: cell.card == null
            ? 'grid-empty-${cell.index}'
            : 'grid-slot-${cell.index}',
        border: candidate.isNotEmpty ? kit.accent : kit.border,
        fill: kit.surface,
        // A card sits on top of a filled slot, so the dashes only ever show
        // where there is nothing — which is what makes an empty square read as
        // a place a card could go.
        dashed: cell.card == null,
      ),
    );
  }
}

/// One card, draggable.
class _CardSlot extends ConsumerWidget {
  const _CardSlot({
    required this.cell,
    required this.width,
    required this.height,
    required this.dimmed,
    required this.bursting,
    required this.burstTier,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onBurstDone,
  });

  final GridCell cell;
  final double width;
  final double height;
  final bool dimmed;
  final bool bursting;
  final int burstTier;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final VoidCallback onBurstDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = cell.card!;
    final tile = PlayerCard(
      view: card,
      light: Theme.of(context).brightness == Brightness.light,
      // A tap opens the sell sheet; the DRAG is the merge. Two gestures, two
      // meanings, and the arena keeps them apart.
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
      child: AnimatedOpacity(
        // A square that cannot take the card recedes AND loses its colour. The
        // opacity alone was not enough: the cards are tier-coloured, so a bronze
        // at 28% still reads as bronze and the eye keeps offering it.
        opacity: dimmed ? 0.28 : 1,
        duration: const Duration(milliseconds: 150),
        child: ColorFiltered(
          colorFilter: dimmed
              ? const ColorFilter.matrix(_desaturated)
              : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
          child: LongPressDraggable<int>(
            data: cell.index,
            // A hold, not an instant grab: a flick across the grid is the tab
            // swipe, and the arena hands it over only once the hold has won.
            delay: const Duration(milliseconds: 200),
            onDragStarted: onDragStart,
            onDragEnd: (_) => onDragEnd(),
            onDraggableCanceled: (_, _) => onDragEnd(),
            onDragCompleted: onDragEnd,
            // The card under the finger is the SAME SIZE as the card it left, and
            // lifted rather than shrunk. It had been hard-coded to 84×108, so on
            // any phone wider than the smallest one a card visibly shrank the
            // moment it was picked up.
            feedback: Transform.scale(
              scale: 1.06,
              child: SizedBox(
                width: width,
                height: height,
                child: Material(
                  color: Colors.transparent,
                  elevation: 12,
                  borderRadius: BorderRadius.circular(12),
                  child: PlayerCard(
                    view: card,
                    light: Theme.of(context).brightness == Brightness.light,
                  ),
                ),
              ),
            ),
            // The slot it came from shows through as empty, which is the JS's
            // `.cell-floating`.
            childWhenDragging: const SizedBox.shrink(),
            child: SizedBox(
              key: ValueKey('grid-card-${cell.index}'),
              width: width,
              height: height,
              child: tile,
            ),
          ),
        ),
      ),
    );
  }
}

/// `saturate(0.15) brightness(0.7)`, as one matrix. The JS applies the two CSS
/// filters together; multiplying them out is one pass instead of two.
const List<double> _desaturated = <double>[
  0.2338,
  0.4571,
  0.0291,
  0,
  0,
  0.1488,
  0.5421,
  0.0291,
  0,
  0,
  0.1488,
  0.4571,
  0.1141,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

/// A slot with nothing in it: `1.5px dashed`, which Flutter's `Border` cannot
/// draw, so it is painted.
class _Slot extends StatelessWidget {
  const _Slot({
    required this.slotKey,
    required this.border,
    required this.fill,
    this.child,
    this.dashed = false,
  });

  final String slotKey;
  final Color border;
  final Color fill;
  final Widget? child;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: ValueKey(slotKey),
      painter: _SlotPainter(border: border, fill: fill, dashed: dashed),
      child: Center(child: child ?? const SizedBox.shrink()),
    );
  }
}

class _SlotPainter extends CustomPainter {
  const _SlotPainter({
    required this.border,
    required this.fill,
    required this.dashed,
  });

  final Color border;
  final Color fill;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    canvas.drawRRect(rect, Paint()..color = fill);
    final stroke = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    if (!dashed) {
      canvas.drawRRect(rect, stroke);
      return;
    }
    // 5-on, 4-off, walked along the rounded rect's own outline so the dashes
    // follow the corners instead of being clipped by them.
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, (d + 5).clamp(0, metric.length)),
          stroke,
        );
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_SlotPainter old) =>
      old.border != border || old.fill != fill || old.dashed != dashed;
}

/// The Players tab.
class GridScreen extends StatelessWidget {
  const GridScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      Semantics(label: t('nav.players'), child: const MergeGrid());
}
