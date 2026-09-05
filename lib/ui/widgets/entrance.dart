/// The way a page's pieces ARRIVE when a tab opens.
///
/// **The tabs stopped sliding, and a page that simply appears reads as still.**
/// The 220ms slide was dropped because Impeller rastered the diorama at 40-50ms
/// a frame while it moved; what it had been doing for the eye was saying "you
/// have gone somewhere". This puts that back at the other end of the cost
/// curve: nothing moves except the things on the page. **Each piece is NOT
/// THERE, and then it is** — invisible, then it zooms up out of its own centre,
/// overshoots its square and settles into it, one after another from the
/// top-left of the page to the bottom-right, the whole page landing in well
/// under half a second. Asked for from the couch, tab by tab, and then
/// sharpened four times: not "on the screen and moving down" but off it, then
/// on; top-left to bottom-right; appear, bounce in, settle, really quick; and
/// NO downward motion — a zoom, not a drop. The eleven onto the pitch, the
/// cards onto the grid, the facilities and the shop tiles onto their shelves,
/// the next-match card on the home screen.
///
/// **The order is the caller's [EntranceItem.index].** A grid's row-major index
/// already reads top-left to bottom-right; the pitch ranks its eleven by row
/// and then column, because a formation's slot order is a football order (the
/// keeper first) and not a reading one.
///
/// **The fade is a `saveLayer` per item and it is paid for ~300ms per open.**
/// Twenty-six cards on the grid, eleven on the pitch, on a renderer with no
/// raster cache (see `impeller-no-raster-cache` in the notes) — so the
/// `Opacity` exists only while a piece is arriving and the settled tree carries
/// no layer at all. At opacity zero Flutter paints nothing, which is what "not
/// on the screen" means here.
///
/// **Replayed on every OPEN, not only on mount.** `IndexedStack` keeps every tab
/// alive, so a mount-time animation would run once per session and then never.
/// [TabEntrance] carries a per-tab generation the shell bumps each time that tab
/// becomes the one in front, and every [EntranceItem] under it restarts when the
/// number changes. **Outside a shell — a sheet, a test — there is no scope and
/// nothing moves.** The arrival is about a tab opening; a sheet has its own
/// slide, and a widget test that measures a card's rectangle two frames after
/// mount must find it where the layout put it.
///
/// Reduced motion (`MediaQuery.disableAnimations`) lands everything in place.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// How long [count] pieces take to all be in place, from the tab opening.
///
/// For anything that has to WAIT for the arrival — the tutorial's loan going
/// home shatters eleven cards that had better have finished arriving first.
Duration entranceWindow(
  int count, {
  Duration duration = const Duration(milliseconds: 220),
  Duration stagger = const Duration(milliseconds: 35),
  int maxStaggered = 12,
}) => count <= 0
    ? Duration.zero
    : duration + stagger * math.min(count - 1, maxStaggered);

/// "This tab has just been opened for the Nth time." See the library note.
class TabEntrance extends InheritedWidget {
  const TabEntrance({
    required this.generation,
    required super.child,
    this.openedAt,
    super.key,
  });

  final int generation;

  /// When this opening happened. **A piece that mounts long after it does not
  /// arrive** — a scouted card landing on the grid a minute into the session
  /// is not the page opening, and it popped in from a dot at the end of its
  /// flight, which read as a white flash. Null means "just now".
  final DateTime? openedAt;

  static TabEntrance? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabEntrance>();

  /// How long after an open a newly mounted piece still counts as arriving
  /// with the page. Generous: a tab's first frame can be slow.
  static const Duration mountWindow = Duration(milliseconds: 800);

  bool get recentlyOpened =>
      openedAt == null ||
      DateTime.now().difference(openedAt!) < mountWindow;

  @override
  bool updateShouldNotify(TabEntrance old) => old.generation != generation;
}

/// One piece of a page, arriving.
class EntranceItem extends StatefulWidget {
  const EntranceItem({
    required this.child,
    this.index = 0,
    this.from = Offset.zero,
    this.duration = const Duration(milliseconds: 220),
    this.stagger = const Duration(milliseconds: 35),
    this.maxStaggered = 12,
    this.scaleFrom = 0.15,
    super.key,
  });

  final Widget child;

  /// Its place in the order. Item N starts N staggers after item zero.
  final int index;

  /// Where it starts, as a fraction of its own size. **Zero by default**: the
  /// piece zooms in where it belongs and does not travel. Asked for in those
  /// words — no downward motion on the cards.
  final Offset from;

  /// How long ONE item's travel takes, bounce included.
  ///
  /// **Measured off the reference, not guessed.** A 60fps recording of the
  /// game this was asked to match (a collection grid, opened from its tab bar)
  /// has each tile going from nothing to settled in five or six frames, the
  /// next column starting a frame or two behind, the next row about six — so
  /// ten tiles land in well under half a second. The first draft here was 360ms
  /// a tile and read as slow; the frames gave 160, and that read as a touch too
  /// fast on the couch — so this sits between the two.
  final Duration duration;

  /// The gap between one item starting and the next.
  final Duration stagger;

  /// The grid has twenty-six squares and a page's worth is about twelve: past
  /// this the stagger stops growing, so the last row is not still arriving
  /// after the player has started reading.
  final int maxStaggered;

  final double scaleFrom;

  @override
  State<EntranceItem> createState() => _EntranceItemState();
}

class _EntranceItemState extends State<EntranceItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    value: 1,
  );
  int? _generation;

  /// The item's own start, as a fraction of the whole run.
  double _lead = 0;

  /// One overshoot and settle — the bounce. Its value passes 1 on the way in,
  /// which is what carries the piece past its square and back.
  static const Curve _bounce = Curves.easeOutBack;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = TabEntrance.of(context);
    final generation = scope?.generation;
    if (generation == _generation) return;
    final first = _generation == null;
    _generation = generation;
    // No scope, or a tab that has never been in front (the shell mounts all
    // five at once): sit still, in place. So does a piece mounting on a tab
    // that has been open a while — see [TabEntrance.openedAt].
    if (generation == null ||
        generation == 0 ||
        (first && !scope!.recentlyOpened)) {
      _ctrl.value = 1;
      return;
    }
    _replay();
  }

  void _replay() {
    if (MediaQuery.of(context).disableAnimations) {
      _ctrl.value = 1;
      return;
    }
    final delay = widget.stagger * math.min(widget.index, widget.maxStaggered);
    final total = widget.duration + delay;
    _lead = total.inMicroseconds == 0
        ? 0
        : delay.inMicroseconds / total.inMicroseconds;
    _ctrl.duration = total;
    _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    child: widget.child,
    builder: (context, child) {
      // Linear progress through this item's own travel, then the bounce on it.
      final p = Interval(_lead, 1).transform(_ctrl.value);
      if (p >= 1) return child!;
      final t = _bounce.transform(p);
      final scale = widget.scaleFrom + (1 - widget.scaleFrom) * t;
      // Solid almost at once: the reference tiles grow from a dot rather than
      // fade, and the fade here only stops the dot itself from flashing.
      final opacity = (p / 0.25).clamp(0.0, 1.0);
      final zoom = Transform.scale(scale: scale, child: child);
      return Opacity(
        opacity: opacity,
        child: widget.from == Offset.zero
            ? zoom
            : FractionalTranslation(
                translation: widget.from * (1 - t),
                child: zoom,
              ),
      );
    },
  );
}
