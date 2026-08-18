/// The bottom sheet — one of the three popup shapes.
///
/// The same shape `openShellSheet` uses for Trophies, Player Index and the
/// Leaderboard; this is the general form for anything else that rises.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

Future<T?> showBottomSheetPopup<T>(
  BuildContext context, {
  required Widget child,
  double heightFraction = 0.75,
}) {
  final kit = Theme.of(context).extension<KitTheme>()!;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      key: const ValueKey('bottom-sheet-popup'),
      heightFactor: heightFraction,
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
