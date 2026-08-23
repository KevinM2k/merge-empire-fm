/// The bottom sheet — one of the three popup shapes.
///
/// The same shape `openShellSheet` uses for Trophies, Player Index and the
/// Leaderboard; this is the general form for anything else that rises.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/ui/shell/screen_covered.dart';
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
  // **THE SCREEN UNDERNEATH STOPS ANIMATING while this is up.** A modal bottom
  // sheet is a `PopupRoute` — it rises over the current route without pushing
  // it out — so nothing tells the tab body it has stopped being looked at, and
  // on the home tab that is a pitch scene, weather, a ball and a walking
  // manager still running behind something opaque. See [screenCoveredProvider].
  //
  // Guarded: this helper is called from places that may not sit under a
  // `ProviderScope` in a test, and a sheet that cannot open is worse than one
  // that opens over a screen still ticking.
  ProviderContainer? container;
  try {
    container = ProviderScope.containerOf(context, listen: false);
    container.read(screenCoveredProvider.notifier).state++;
  } catch (_) {
    container = null;
  }
  void uncover() {
    final held = container;
    if (held == null) return;
    container = null;
    final n = held.read(screenCoveredProvider);
    if (n > 0) held.read(screenCoveredProvider.notifier).state = n - 1;
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // See [_DragHandle]: the handle is the drag target, so this is what makes
    // the gesture reach the route at all.
    enableDrag: true,
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
        child: SafeArea(
          top: false,
          // **THE HANDLE IS AN OVERLAY, not a row.** Tapping outside was the
          // only way out of a sheet that covers most of the screen — reported
          // as hard to close — and a drag needs a target the scrolling body
          // does not eat, which is what the bar at the top is.
          //
          // In a `Stack` rather than a `Column` because every sheet in the game
          // sizes itself to a fraction of the screen: a row above the content
          // takes twenty points off every one of them, and the ones that were
          // already tight lost their bottom button. Over the content it costs
          // nothing, and the space it sits in is a sheet's own top margin.
          child: Stack(
            children: [
              child,
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(child: _DragHandle(colour: kit.textMuted)),
              ),
            ],
          ),
        ),
      ),
    ),
  ).whenComplete(uncover);
}

/// The bar at the top of a sheet, and the thing you pull it down by.
///
/// Padded generously: a 4px bar is a 4px target, and the whole point is that a
/// thumb finds it without being aimed.
class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Container(
      key: const ValueKey('sheet-drag-handle'),
      width: 38,
      height: 4,
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(2),
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
