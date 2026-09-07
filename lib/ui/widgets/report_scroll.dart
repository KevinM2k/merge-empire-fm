/// A report page: PLACED in the room it has when it is short, scrolling when it
/// is long.
///
/// **A SCROLL VIEW WITH A PINNED FOOT LEAVES A HOLE, and both report screens
/// had one.** Full time and the end of a season are the same shape — a stack of
/// cards over a foot carrying what the game paid and the way out — and the
/// stack is usually shorter than the phone. A `ListView` or a
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
    this.footer,
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
    List<Widget>? footer,
    required List<Widget> children,
  }) : child = Column(
         mainAxisSize: MainAxisSize.min,
         crossAxisAlignment: CrossAxisAlignment.stretch,
         children: children,
       ),
       footer = footer == null
           ? null
           : Column(
               mainAxisSize: MainAxisSize.min,
               crossAxisAlignment: CrossAxisAlignment.stretch,
               children: footer,
             );

  final EdgeInsets padding;

  /// Where a SHORT page sits in the room it has.
  ///
  /// Centred is the default and is what the hole above was about. **Both
  /// report screens ask for [Alignment.topCenter] instead**, and for the same
  /// reason: the first card is the RESULT — the scoreline at full time, the
  /// division and the finishing place at the end of a season — and a result
  /// that floats down the page as the report below it grows or shrinks reads
  /// as the page settling rather than as the verdict. Full time asked for it
  /// first; the season end was reported later, in as many words, as being
  /// vertically centred when it should not be.
  ///
  /// The default stays centred rather than following them, because the two
  /// arguments are different: centring is what closes the hole, and topCenter
  /// is what a page whose first card is a headline wants instead. A third
  /// report with no headline should get the default.
  final AlignmentGeometry alignment;

  /// The block that goes LAST and goes at the BOTTOM.
  ///
  /// The foot of both reports — what the match paid and the way out — is one
  /// decision, and a report too short to fill the phone left it floating in the
  /// middle of the page under the cards. Given here it sits on the bottom edge
  /// of the viewport when there is room and flows straight after the cards when
  /// there is not, which is where a scrolled page puts it anyway. [alignment]
  /// is unused with a footer: the cards are at the top and the foot is at the
  /// foot.
  final Widget? footer;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final foot = footer;
      return SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          // The viewport LESS the padding, because the padding is outside the
          // constrained box: counting it twice makes every short page scroll by
          // exactly the padding, which is a page that jiggles for no reason.
          constraints: BoxConstraints(
            minHeight: (box.maxHeight - padding.vertical)
                .clamp(0.0, box.maxHeight),
          ),
          child: foot == null
              ? Align(alignment: alignment, child: child)
              // `spaceBetween` and not a `Spacer`: the scroll gives this column
              // an unbounded height, so a flex child throws, while the space
              // left over after `minHeight` is applied divides fine.
              : Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [child, foot],
                ),
        ),
      );
    },
  );
}
