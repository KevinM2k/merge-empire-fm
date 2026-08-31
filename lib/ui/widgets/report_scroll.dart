/// A report page: PLACED in the room it has when it is short, scrolling when it
/// is long.
///
/// **A SCROLL VIEW WITH A PINNED FOOT LEAVES A HOLE, and both report screens
/// had one.** Full time and the end of a season are the same shape — a stack of
/// cards over a foot that is pinned so the way out is never more than a thumb
/// away — and the stack is usually shorter than the phone. A `ListView` or a
/// `SingleChildScrollView` puts short content at the TOP of its viewport, so
/// what a player sees is the report crammed against the status bar, a third of
/// the screen of nothing, and then the button. Reported as both screens looking
/// a little ugly, which is exactly what a large unexplained gap looks like.
///
/// Measured before it was believed: on a 390×844 phone the season summary left
/// 420 points empty between the last card and the foot — half the page — and
/// full time left 125 between the manager and the money.
///
/// **Centred, not spread.** Pushing the cards apart to fill the space would
/// break the grouping they were given on purpose; moving the whole block to the
/// middle of the room it has keeps every gap between them exactly as it was.
/// And it costs nothing when the content IS long: the minimum height is the
/// viewport, so a full page pushes past it and scrolls as before.
///
/// Two constructors because the two call sites are shaped differently and
/// neither should have to be rewritten to use this: [ReportScroll.new] takes
/// the child a `SingleChildScrollView` already had, and [ReportScroll.list]
/// takes the `padding` and `children` a `ListView` already had.
library;

import 'package:flutter/material.dart';

class ReportScroll extends StatelessWidget {
  const ReportScroll({
    super.key,
    this.padding = EdgeInsets.zero,
    this.alignment = Alignment.center,
    required this.child,
  });

  /// The `ListView` shape: a padding and a list of cards.
  ///
  /// `MainAxisSize.min` matters — the Column has to hug its cards so there is
  /// something for [Center] to centre. At `max` it fills the minimum height
  /// itself and the hole comes straight back.
  ReportScroll.list({
    super.key,
    this.padding = EdgeInsets.zero,
    this.alignment = Alignment.center,
    required List<Widget> children,
  }) : child = Column(
         mainAxisSize: MainAxisSize.min,
         crossAxisAlignment: CrossAxisAlignment.stretch,
         children: children,
       );

  final EdgeInsets padding;

  /// Where a SHORT page sits in the room it has.
  ///
  /// Centred is the default and is what the hole above was about. Full time
  /// asks for [Alignment.topCenter] instead: its first card is the scoreline,
  /// and a scoreline that floats down the page as the report below it grows or
  /// shrinks reads as the page settling rather than as the result. Asked for
  /// directly.
  final AlignmentGeometry alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      padding: padding,
      child: ConstrainedBox(
        // The viewport LESS the padding, because the padding is outside the
        // constrained box: counting it twice makes every short page scroll by
        // exactly the padding, which is a page that jiggles for no reason.
        constraints: BoxConstraints(
          minHeight: (box.maxHeight - padding.vertical).clamp(0.0, box.maxHeight),
        ),
        child: Align(alignment: alignment, child: child),
      ),
    ),
  );
}
