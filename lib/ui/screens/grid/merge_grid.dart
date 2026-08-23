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

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

/// The one clock every merge-ready ring beats to.
///
/// **They were each their own.** `_MergeRing` owned an `AnimationController` and
/// called `repeat()` the moment its card became mergeable — so a card that
/// qualified later started its cycle from zero, and a grid with three pairs on it
/// pulsed in three different phases. Identical animations out of step read as a
/// fault in the game rather than as a hint about the cards.
///
/// One controller, inherited, so they cannot drift: a ring that appears
/// mid-cycle joins the beat already in progress.
class GridPulse extends InheritedWidget {
  const GridPulse({super.key, required this.clock, required super.child});

  final Animation<double> clock;

  /// Null when there is no grid above — a widget test pumping a card alone.
  static Animation<double>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GridPulse>()?.clock;

  @override
  bool updateShouldNotify(GridPulse old) => old.clock != clock;
}

class MergeGridState extends ConsumerState<MergeGrid>
    with TickerProviderStateMixin {
  /// The shared beat. One cycle is the JS's 1.2s.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  /// The cells a merge just landed in.
  ///
  /// **A SET, because Merge All is a dozen of them at once.** One drag is one
  /// card celebrating and a sweep is twelve, in unison — which is the whole
  /// difference between a grid that arrives at its answer and one you watch
  /// solve itself.
  Set<int> _burstAt = const {};
  int _burstTier = 1;

  /// How long a card takes to slide to a new index, and the one card that is
  /// exempt.
  ///
  /// **The card the player DRAGGED does not travel; everything else does.** They
  /// carried it to its square under their own finger, so gliding it there
  /// afterwards is the app repeating something they just did. But on a SWAP the
  /// other card is displaced by a move it had no part in, and it has to be seen
  /// going — otherwise a card the player was not touching teleports.
  ///
  /// The same pair of rules covers the sort, which exempts nothing: every card
  /// moved and none of them was dragged.
  Duration _slide = const Duration(milliseconds: 350);
  String? _placedByHand;

  /// The card under the finger, and the cells it could actually MERGE with.
  ///
  /// Everything that is not a target dims, which is the JS's
  /// `.grid-container.is-dragging` rule — and "not a target" is the exact merge
  /// rule, not "not the card in my hand". Dimming every other card said nothing:
  /// what a player needs to see mid-drag is which squares will take it.
  int? _dragging;
  Set<int> _targets = const {};

  /// Driven by the drag, so a card can be carried off the visible rows.
  final ScrollController _scroll = ScrollController();

  /// One key per cell, so anything outside the grid can be told where a square
  /// IS. Hung off the slot layer rather than the card layer: the slots never
  /// move, where a card's own widget is mid-animation exactly when it is asked.
  final Map<int, GlobalKey> _slotKeys = {};

  GlobalKey _slotKey(int index) => _slotKeys.putIfAbsent(index, GlobalKey.new);

  /// **A SWEEP, WATCHED.** Merge All used to arrive at its answer — the grid
  /// simply changed. Every pair bursts at once and the survivors slide into the
  /// holes, which is the same set-piece one drag has had since it was ported,
  /// played twelve times over.
  void burstSweep(List<int> at, int tier) {
    if (at.isEmpty) return;
    animateNextSlide();
    setState(() {
      _burstAt = at.toSet();
      _burstTier = tier;
    });
    // **AND IT SCROLLS TO THE FOOT OF THE STACK.** The sweep packs everything
    // to the front, so on a grid of thirteen rows with four on screen the
    // result of a dozen merges is very often above or below wherever the player
    // happened to be — a set-piece played somewhere they cannot see is the same
    // as no set-piece. The LAST merged cell is the end of the run, which is
    // where the new cards are.
    final last = at.reduce((a, b) => a > b ? a : b);
    WidgetsBinding.instance.addPostFrameCallback((_) => scrollToSlot(last));
  }

  /// Bring one cell into view, low on the screen so what is above it is the run
  /// it belongs to rather than empty grid.
  Future<void> scrollToSlot(int index) async {
    if (!mounted || !_scroll.hasClients) return;
    final target = _slotKeys[index]?.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      alignment: 0.75,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  /// Let EVERY card glide. Called by the sort, which reorders the whole grid and
  /// so has no card the player put anywhere.
  void animateNextSlide() {
    setState(() {
      _slide = const Duration(milliseconds: 350);
      _placedByHand = null;
    });
  }

  /// Runs while the finger is held inside an edge band.
  Timer? _edgeScroll;
  double _edgeDelta = 0;

  @override
  void initState() {
    super.initState();
    // The grid lends the scout reveal a way home. Nothing watches this, so
    // setting it costs no rebuild; the frame's delay is so that it is never set
    // while the frame that mounted the grid is still being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(scoutLandingProvider.notifier).state = _landingRects;
      }
    });
  }

  /// Handed back when the grid leaves the tree — in `deactivate` rather than
  /// `dispose`, because `ref` is already gone by then. A resolver left behind
  /// would fly a card into a grid that is no longer on screen.
  @override
  void deactivate() {
    if (ref.read(scoutLandingProvider) == _landingRects) {
      ref.read(scoutLandingProvider.notifier).state = null;
    }
    super.deactivate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Stopped under reduce-motion, which is also what lets a widget test settle.
    // The rings still DRAW — a merge-ready card has something to say either way
    // — they simply hold at the start of the cycle.
    if (MediaQuery.disableAnimationsOf(context)) {
      if (_pulse.isAnimating) {
        _pulse
          ..stop()
          ..value = 0;
      }
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _edgeScroll?.cancel();
    _scroll.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// Where these cells are on screen, for a reveal to fly its cards into.
  ///
  /// **It scrolls first.** The engine fills the first free slots, which on a
  /// grid with thirteen rows and four on screen is very often below the fold —
  /// and a card flying to a square nobody can see is worse than one that does
  /// not fly. The batch's own middle is centred, which covers the whole batch
  /// because those free slots sit together.
  Future<List<Rect?>> _landingRects(List<int> idxs) async {
    if (!mounted || idxs.isEmpty) return const [];
    final sorted = [...idxs]..sort();
    final middle = _slotKeys[sorted[sorted.length ~/ 2]]?.currentContext;
    if (middle != null && _scroll.hasClients) {
      await Scrollable.ensureVisible(
        middle,
        alignment: 0.5,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    }
    if (!mounted) return const [];
    // A frame after the scroll, so what is measured is where the scroll left it.
    await SchedulerBinding.instance.endOfFrame;
    if (!mounted) return const [];
    return [for (final idx in idxs) _slotRect(idx)];
  }

  Rect? _slotRect(int index) {
    final box =
        _slotKeys[index]?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Scroll the grid while a card is held near the top or bottom edge.
  ///
  /// The grid is thirteen rows and the screen holds about four, so without this a
  /// merge between a card on the first row and its twin on the ninth cannot be
  /// made at all: the drag has nowhere to go. The band is a fixed 72px rather
  /// than a fraction of the height — it has to be a thumb's width whatever the
  /// phone.
  void _autoScroll(Offset globalPosition) {
    if (!_scroll.hasClients) return;
    // **THE BAND IS MEASURED AGAINST WHAT SCROLLS**, not against the screen. It
    // was taken off this widget's own box, which starts at the top of the phone —
    // behind the HUD and above the action bar — so a card had to be dragged
    // under the glass and most of the way off the top before the grid moved.
    //
    // Off the scroll position rather than a second key: the `Scrollable` already
    // has a context and it is by definition the thing that scrolls, so the two
    // cannot disagree about which box is meant.
    final box =
        _scroll.position.context.notificationContext?.findRenderObject()
            as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPosition);
    const band = 72.0;
    final height = box.size.height;

    // Speed ramps with how far INTO the band the finger is, so the edge nudges
    // and the very corner races.
    var delta = 0.0;
    if (local.dy < band) {
      delta = -(band - local.dy) / band * 18;
    } else if (local.dy > height - band) {
      delta = (local.dy - (height - band)) / band * 18;
    }
    _edgeDelta = delta;

    if (delta == 0) {
      _stopAutoScroll();
      return;
    }
    _edgeScroll ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_scroll.hasClients || _dragging == null) return;
      _scroll.jumpTo(
        (_scroll.offset + _edgeDelta).clamp(
          0.0,
          _scroll.position.maxScrollExtent,
        ),
      );
    });
  }

  void _stopAutoScroll() {
    _edgeScroll?.cancel();
    _edgeScroll = null;
    _edgeDelta = 0;
  }

  Future<void> _drop(int from, int to) async {
    // Set before the update, so the frame that moves the cards is already the
    // frame that knows which of them was carried there by hand.
    _slide = const Duration(milliseconds: 350);
    _placedByHand = ref.read(gridCellsProvider)[from].instanceId;
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

    // **NO FLIGHT.** A ghost of the source card travelling into the target was
    // put in to join the two events, on the reasoning that a pair vanishing and
    // a new card appearing reads as a glitch. It does — but only if you did not
    // watch it happen, and on this screen you always did: the only way to reach
    // a merge is to drag one card onto the other. Re-flying it is the app
    // showing the player the journey they just made, and it delays the one thing
    // they are waiting for.
    //
    // What joins the two events is the BURST, which is now the JS's full
    // set-piece — see `merge_burst.dart`. It fires on the frame the merge lands.
    if (!mounted) return;
    setState(() {
      // Where the card LANDED, not where it was dropped: closing the gaps
      // behind a merge slides it down past any hole ahead of it, and a burst at
      // the drop index would go off over whatever card slid up into it.
      _burstAt = {result.landedAt ?? to};
      _burstTier = result.tier;
    });

    // A player nobody has ever seen gets the same turn-over a signing does. It
    // is the only card a merge produces that is worth stopping the grid for, and
    // reusing the scout's reveal is what stops the two drifting apart.
    if (!result.isNewDiscovery) return;
    final cell = gridCells(game.state)[to];
    final view = cardViewFor(cell, proMode: ref.read(proModeProvider));
    if (view == null || !mounted) return;

    // Held back for the length of the reveal, as a signing is: the card is
    // already in the square it is about to be flown into.
    final pending = cell is Map<String, dynamic>
        ? {if (cell['instanceId'] case final String id) id}
        : const <String>{};
    if (pending.isNotEmpty) {
      ref.read(gridPendingProvider.notifier).state = pending;
    }
    try {
      await showScoutReveal(
        context,
        (
          cards: [
            (
              view: view,
              badge: null,
              isNewDiscovery: true,
              vanish: false,
              idx: to,
            ),
          ],
          caption: t('grid.new_player_found'),
        ),
        // Back into the square it came out of — the cell that just merged.
        landing: _landingRects,
      );
    } finally {
      if (pending.isNotEmpty && ref.exists(gridPendingProvider)) {
        ref.read(gridPendingProvider.notifier).state = const {};
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cells = ref.watch(gridCellsProvider);
    // The gold ring goes on at REST only: mid-drag the dimming is the message,
    // and a pulsing card under a lifted one is two cues fighting.
    final mergeable = ref.watch(mergeableCellsProvider);

    return GridPulse(
      clock: _pulse,
      child: Stack(
        children: [
          Column(
            children: [
              // The bar is the FIRST thing on the tab, above the grid. The port had
              // it under the cards with the pills on top, which is the JS's order
              // inverted: the pills are a readout and belong beside the last row
              // they describe, and the two controls a player came here to press
              // belong where the thumb lands first.
              Padding(
                padding: EdgeInsets.fromLTRB(
                  _pad,
                  hudClearanceOf(context),
                  _pad,
                  0,
                ),
                child: const ScoutActionBar(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('merge-grid'),
                  controller: _scroll,
                  // **THE PLATFORM'S OWN BOUNCE, on both of them.** The default
                  // is per-platform — Android clamps dead at each end — and a
                  // list that stops without giving reads as having hit a wall
                  // rather than as having reached the bottom. The rest of the app
                  // takes the default; this is the longest scroll in the game and
                  // the one a thumb lives in.
                  physics: const BouncingScrollPhysics(
                    parent: RangeMaintainingScrollPhysics(),
                  ),
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
                                    child: KeyedSubtree(
                                      key: _slotKey(cell.index),
                                      child: _SlotTarget(
                                        cell: cell,
                                        onDrop: _drop,
                                      ),
                                    ),
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
                                      duration: cell.instanceId == _placedByHand
                                          ? Duration.zero
                                          : _slide,
                                      curve: Curves.easeInOutCubic,
                                      left: at(cell.index).dx,
                                      top: at(cell.index).dy,
                                      width: cellW,
                                      height: cellH,
                                      child: _CardSlot(
                                        cell: cell,
                                        onDrop: _drop,
                                        mergeable:
                                            _dragging == null &&
                                            mergeable.contains(cell.index),
                                        onDragUpdate: _autoScroll,
                                        width: cellW,
                                        height: cellH,
                                        // Bright if it is the card in hand or a
                                        // square that can take it; dimmed if not.
                                        dimmed:
                                            _dragging != null &&
                                            _dragging != cell.index &&
                                            !_targets.contains(cell.index),
                                        bursting: _burstAt.contains(cell.index),
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
                                          // Each square clears its OWN mark, so
                                          // a sweep's dozen do not have to
                                          // finish in step to stop.
                                          if (mounted &&
                                              _burstAt.contains(cell.index)) {
                                            setState(
                                              () => _burstAt = {..._burstAt}
                                                ..remove(cell.index),
                                            );
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
      ),
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
          onTap: () {
            // The one case worth animating: the whole grid reorders at once and
            // a player needs telling what moved.
            context
                .findAncestorStateOfType<MergeGridState>()
                ?.animateNextSlide();
            game.update((s) => sortGridByTier(gridCells(s)));
          },
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
            // Flexible: on a 320pt phone in German the pill is wider than the
            // bar it sits in. Found by the long-language sweep.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ink,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
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

    // A FILLED cell's drop target lives on the card itself — see `_CardSlot`.
    // Two targets for one cell would both accept, and the one underneath could
    // never be reached anyway.
    if (cell.card != null) {
      return _Slot(
        slotKey: 'grid-slot-${cell.index}',
        border: kit.border,
        fill: kit.surface,
      );
    }

    return DragTarget<int>(
      key: ValueKey('grid-drop-${cell.index}'),
      onWillAcceptWithDetails: (d) => d.data != cell.index,
      onAcceptWithDetails: (d) => onDrop(d.data, cell.index),
      builder: (context, candidate, _) => _Slot(
        slotKey: 'grid-empty-${cell.index}',
        border: candidate.isNotEmpty ? kit.accent : kit.border,
        fill: kit.surface,
        // Dashes only where there is nothing, which is what makes an empty
        // square read as a place a card could go.
        dashed: true,
        // WHICH square it is, 1-based. An empty grid is a field of identical
        // dashed boxes with nothing to say how far along it you are looking, and
        // now that a merge closes the gaps behind it (see `closeGridGaps`) the
        // first numbered box is always the next card's home — so the number is
        // also how many players you have, plus one.
        //
        // Faint on purpose: it is a label on the background, and the moment it
        // competes with the cards next to it the grid reads as a numbered form.
        child: Text(
          '${cell.index + 1}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: kit.textMuted.withValues(alpha: 0.22),
          ),
        ),
      ),
    );
  }
}

/// One card, draggable.
/// One card, draggable — and the DROP TARGET for its own cell.
///
/// **The target is here, not on the slot layer.** The cards are their own layer
/// over the slots so they can animate into a new index, which means a drop onto
/// an occupied cell hits the CARD: a DragTarget underneath it is never reached,
/// and merging stopped working entirely the moment that layer went in. An empty
/// cell keeps its target on the slot layer, where nothing is in the way.
class _CardSlot extends ConsumerWidget {
  const _CardSlot({
    required this.cell,
    required this.onDrop,
    required this.width,
    required this.height,
    required this.dimmed,
    required this.mergeable,
    required this.bursting,
    required this.burstTier,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onDragUpdate,
    required this.onBurstDone,
  });

  final GridCell cell;
  final void Function(int from, int to) onDrop;
  final double width;
  final double height;
  final bool dimmed;

  /// This card's twin is somewhere on the grid.
  final bool mergeable;
  final bool bursting;
  final int burstTier;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final void Function(Offset globalPosition) onDragUpdate;
  final VoidCallback onBurstDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = cell.card!;
    final light = Theme.of(context).brightness == Brightness.light;
    final tile = PlayerCard(
      view: card,
      light: light,
      // A tap opens the sell sheet; the DRAG is the merge. Two gestures, two
      // meanings, and the arena keeps them apart.
      onTap: () {
        final id = cell.instanceId;
        if (id != null) {
          showSellSheet(context, ref, instanceId: id, view: card);
        }
      },
    );

    return DragTarget<int>(
      key: ValueKey('grid-drop-${cell.index}'),
      onWillAcceptWithDetails: (d) => d.data != cell.index,
      onAcceptWithDetails: (d) => onDrop(d.data, cell.index),
      builder: (context, candidate, _) => MergeBurst(
        tier: burstTier,
        playing: bursting,
        onDone: onBurstDone,
        child: AnimatedOpacity(
          // A square that cannot take the card recedes AND loses its colour. The
          // opacity alone was not enough: the cards are tier-coloured, so a
          // bronze at 28% still reads as bronze and the eye keeps offering it.
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
              // Carrying a card into the edge band scrolls the grid.
              onDragUpdate: (d) => onDragUpdate(d.globalPosition),
              // The card under the finger is the SAME SIZE as the card it left,
              // and lifted rather than shrunk. It had been hard-coded to 84×108,
              // so on any phone wider than the smallest one a card visibly shrank
              // the moment it was picked up.
              feedback: Transform.scale(
                scale: 1.06,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: Material(
                    color: Colors.transparent,
                    elevation: 12,
                    borderRadius: BorderRadius.circular(12),
                    child: PlayerCard(view: card, light: light),
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
                child: _MergeRing(
                  // Gold says "there is a pair here"; white says "let go and it
                  // happens".
                  on: mergeable || candidate.isNotEmpty,
                  hot: candidate.isNotEmpty,
                  child: tile,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The spatial merge hint: a pulsing gold ring on any card whose twin is
/// elsewhere on the grid, so a player spots the pair at a glance instead of
/// reading nine names.
///
/// Two stacked rings crossfading rather than one animated shadow. The JS makes
/// the same trade for the same reason: animating a box-shadow repaints an 18–28px
/// blur on every mergeable card every frame, and on a grid with several pairs
/// that alone eats the budget on a low-end phone. Crossfading fixed rings
/// animates opacity, which composites.
class _MergeRing extends StatelessWidget {
  const _MergeRing({required this.on, required this.hot, required this.child});

  final bool on;
  final bool hot;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!on) return child;
    final clock = GridPulse.maybeOf(context);
    if (clock == null) return _ring(context, 0);
    return AnimatedBuilder(
      animation: clock,
      builder: (context, _) => _ring(context, clock.value),
    );
  }

  Widget _ring(BuildContext context, double phase) {
    final ink = hot ? Colors.white : const Color(0xFFFFD700);
    // 1.00 → 1.04 → 1.00 across the cycle, the bloom crossfading with it.
    final t = math.sin(phase * math.pi * 2 - math.pi / 2) * 0.5 + 0.5;

    return Transform.scale(
      scale: 1 + 0.04 * t,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          // Painted OVER the card, so the portrait and the stat chips can
          // never obscure it.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  // The ring is a BORDER. It was a `BoxShadow` with
                  // `BlurStyle.inner` and no blur radius, which is not an
                  // inset outline — with nothing to blur it fills the whole
                  // rounded rect, so every card with a pair on the grid came
                  // out a flat gold tile with the player buried under it.
                  // The CSS this came from says `inset 0 0 0 3px`; the 3px is
                  // the spread of a stroke, not of a shadow.
                  border: Border.all(
                    // Thinner and quieter than the CSS's 3px at 95%. On a
                    // grid with several pairs on it that ring was the
                    // loudest thing on the screen and the cards underneath
                    // were reading as yellow rather than as their own tier.
                    color: ink.withValues(alpha: 0.8),
                    width: 2,
                  ),
                  // The bloom, which IS a shadow — and has a blur radius, so
                  // `inner` gives the glow inside the stroke that the second
                  // CSS shadow does.
                  boxShadow: [
                    BoxShadow(
                      color: ink.withValues(alpha: 0.16 + 0.16 * t),
                      blurRadius: 14 + 8 * t,
                      spreadRadius: -2,
                      blurStyle: BlurStyle.inner,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
