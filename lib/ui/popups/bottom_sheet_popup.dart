/// The bottom sheet — one of the three popup shapes.
///
/// The same shape `openShellSheet` uses for Trophies, Player Index and the
/// Leaderboard; this is the general form for anything else that rises.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// [heightFraction] is a CEILING, not a height, when [fitContent] is set: a
/// sheet with four tiles in it should be four tiles tall, and one that takes
/// two thirds of the screen to show them reads as a screen that failed to load.
Future<T?> showBottomSheetPopup<T>(
  BuildContext context, {
  required Widget child,
  double heightFraction = 0.75,
  bool fitContent = false,
}) {
  final kit = Theme.of(context).extension<KitTheme>()!;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _Frame(
      key: const ValueKey('bottom-sheet-popup'),
      heightFraction: heightFraction,
      fitContent: fitContent,
      child: Container(
        decoration: BoxDecoration(
          color: kit.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          border: Border.all(color: kit.border),
        ),
        child: SafeArea(top: false, child: child),
      ),
    ),
  );
}

/// The sheet's box: a fraction of the screen, or as tall as its content needs up
/// to that fraction.
class _Frame extends StatelessWidget {
  const _Frame({
    super.key,
    required this.heightFraction,
    required this.fitContent,
    required this.child,
  });

  final double heightFraction;
  final bool fitContent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!fitContent) {
      return FractionallySizedBox(heightFactor: heightFraction, child: child);
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * heightFraction,
      ),
      // Bottom-anchored and only as tall as it needs, which is what a sheet
      // showing four tiles should be.
      child: child,
    );
  }
}
