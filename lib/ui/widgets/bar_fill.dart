/// A fill across a track: a fraction of its width, and ALL of its height.
///
/// **`heightFactor: 1` is the entire reason this widget exists**, and it has
/// been the same bug four separate times — the next-match card's ATK/DEF tracks,
/// the Play button's cooldown sweep, Deadline Day's fuse, and the player card's
/// income bar. Every one of them was drawn, at no height at all.
///
/// The mechanism: a `FractionallySizedBox` given a `widthFactor` and no
/// `heightFactor` passes the incoming height constraint through LOOSE, and a
/// `ColoredBox` or `DecoratedBox` with no child takes the smallest size it is
/// allowed. Both halves are needed for the fault, which is why it keeps coming
/// back: the code looks right, the widget is in the tree, and a test that only
/// asks "is it there" passes.
///
/// So no track states the factor for itself any more. If a fill is a fraction of
/// a bar, it is one of these.
library;

import 'package:flutter/material.dart';

class BarFill extends StatelessWidget {
  const BarFill({
    super.key,
    required this.fraction,
    required this.child,
    this.alignment = Alignment.centerLeft,
  });

  /// 0..1 of the track's width. Clamped here rather than at every call site: a
  /// fraction derived from a clock can run a hair past 1 on the first frame.
  final double fraction;

  /// The fill itself — usually a `ColoredBox` or a rounded `DecoratedBox`, and
  /// deliberately childless, which is the half of the fault this widget fixes.
  final Widget child;

  /// Which end it grows from. A countdown sweeping away to the right wants
  /// `centerRight`.
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: FractionallySizedBox(
      alignment: alignment,
      widthFactor: fraction.clamp(0.0, 1.0),
      heightFactor: 1,
      child: child,
    ),
  );
}
