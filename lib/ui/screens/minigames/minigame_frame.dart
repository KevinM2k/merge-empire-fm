/// The room a drill is played in.
///
/// **A BOARD IS SIZED BY THE SHORTER SIDE, and all seven were sized by the
/// width.** Every drill is a board with a line or two of chrome over it, laid
/// down a `Column` against whatever width the window handed it — which on a
/// phone is the same thing as laying it out against a portrait column, and on
/// a tablet held landscape is not. Two of them build the board itself out of
/// `Expanded` cards in a `Row`, so the card is a fraction of the WIDTH and the
/// board's height simply follows: on a 1194pt window Pitch Invaders' nine
/// holes came out 380pt across and the board half again taller than the window
/// it was in. That is why those two shipped inside a `SingleChildScrollView` —
/// it is what turned an overflow into a scroll — and the note over each of
/// those boards says in as many words that a board the player cannot see all
/// of is not a board.
///
/// Reported from the couch: the training games look bad on a tablet in
/// landscape and have to be scrolled.
///
/// So the play area takes its width from the HEIGHT it has been given, and the
/// window's surplus width becomes margin. Nothing changes on a phone held
/// upright — 0.72 of a phone's usable height is wider than a phone is — which
/// is what makes this safe to put under all seven at once: the cap only
/// engages on a window that is wide for its height, and that is the only shape
/// of window any of this was going wrong on.
///
/// The cap is half of the fix and cannot be all of it. A width cap stops a
/// board being drawn absurdly large; it does not stop one being drawn TALLER
/// than the room. The boards themselves hang off an `Expanded` and work their
/// tile size out of BOTH constraints — see [drillTileWidth], and see the Boot
/// Room, which had it right first and is what the other two were rebuilt
/// against.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// How wide a drill may be drawn, per unit of the height it has.
///
/// A little wider than a phone's own 9:16, because the chrome over and under
/// the board is not part of the board: at 0.72 a 780pt column comes out 560pt
/// across, which is a large phone's width and the shape all of these boards
/// were drawn against.
const double drillFrameAspect = 0.72;

/// And the narrowest a drill may be drawn, whatever [drillFrameAspect] makes
/// of the height.
///
/// **A CAP WORKED OUT OF THE HEIGHT NEEDS A FLOOR, because a landscape phone
/// has very little height.** 0.72 of what an 880×400 handset leaves under the
/// app bar is 248pt, and none of these pages is a 248pt page: the Boot Room's
/// moves-and-tiles line alone wants 330 and overflowed its row by 81. The
/// drills were drawn for a handset held upright, so that is the floor — under
/// it they are being asked to be something they were never laid out as.
///
/// It is a floor on the CAP and not on the drill: a window genuinely narrower
/// than this still gets its own width, because there is nothing else to give
/// it.
const double drillFrameLeast = 380;

/// The width a drill is drawn at, in a body with [room] to put it in.
///
/// The cap, the floor, and the window itself, in that order of who gives way:
/// a drill is never wider than [aspect] allows, never narrower than
/// [drillFrameLeast], and never wider than the room there actually is —
/// which is the one of the three that always wins.
double drillFitWidth(
  BoxConstraints room, {
  double aspect = drillFrameAspect,
}) {
  // A body inside a scroll view — or a hosted view — can hand down an
  // unbounded height, and there is nothing to work a width out from then. The
  // cap stands aside rather than collapsing to nothing.
  if (!room.hasBoundedHeight) return room.maxWidth;
  return math.min(
    room.maxWidth,
    math.max(room.maxHeight * aspect, drillFrameLeast),
  );
}

/// A drill's body: the width cap, and the page's own padding inside it.
///
/// Sits where each drill's `Padding` (or its `SingleChildScrollView`'s) used
/// to, INSIDE the `SafeArea` the screen already had — so the cap goes on with
/// the padding rather than being a fourth thing every screen has to remember.
class DrillFit extends StatelessWidget {
  const DrillFit({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.aspect = drillFrameAspect,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;

  final EdgeInsetsGeometry padding;

  /// The most width [child] may take per unit of the height it has.
  ///
  /// A drill whose picture is a camera rather than a board has its own answer
  /// — see `penaltySceneAspect`, which is the aspect the penalty view's four
  /// camera numbers were solved for.
  final double aspect;

  /// Where the capped column sits in the room left over. Top by default: the
  /// column fills the height, so this only decides where a child that does
  /// not — a scene rather than a page — is hung.
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final inner = Padding(padding: padding, child: child);
      if (!box.hasBoundedHeight) return inner;
      final room = box.maxHeight;
      return Align(
        alignment: alignment,
        child: SizedBox(
          width: drillFitWidth(box, aspect: aspect),
          // **TIGHT, not loose.** Every one of these drills hangs its board
          // off an `Expanded`, and an `Align` that passed the height down
          // loosely would hand the column a height it is not allowed to fill
          // — which is the overflow this exists to prevent, arriving by
          // another door.
          height: room,
          child: inner,
        ),
      );
    },
  );
}

/// The width of a tile that fits [cols] × [rows] of them into [room].
///
/// **BOTH CONSTRAINTS, which is the whole point.** A board that divides the
/// width by the column count is a board whose height is then whatever that
/// comes to — and on a window wide for its height, that is a good deal more
/// height than there is. Taking the smaller of the two answers is what makes a
/// board fit a window of any shape, and it is what the Boot Room's
/// `AspectRatio` has been doing since it shipped; this is the same sum written
/// out for the boards whose tiles are not square.
///
/// [aspect] is the tile's own width over its height and [gap] the gutter
/// between two of them — the gutter goes BETWEEN the tiles, which is the fault
/// both of these boards have already been fixed for once.
double drillTileWidth(
  BoxConstraints room, {
  required int cols,
  required int rows,
  required double gap,
  double aspect = 1,
}) {
  final byWidth = (room.maxWidth - gap * (cols - 1)) / cols;
  final byHeight = room.hasBoundedHeight
      ? (room.maxHeight - gap * (rows - 1)) / rows * aspect
      : byWidth;
  // Never negative: a board with no room left is a board of nothing, not a
  // board turned inside out.
  return math.max(0, math.min(byWidth, byHeight));
}
