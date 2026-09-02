/// The bottom sheet — one of the three popup shapes.
///
/// The same shape `openShellSheet` uses for Trophies, Player Index and the
/// Leaderboard; this is the general form for anything else that rises.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/ui/shell/screen_covered.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// **[heightFraction] IS A CEILING, NOT A HEIGHT.** Every sheet hugs what is in
/// it and stops at the cap, which is the spec's own rule and its own words:
/// `.ps-sheet .ps-panel` is `height: auto; max-height: min(85vh, 780px)`, over
/// "tall sections (table, fixtures) all clamp to the same height, short ones
/// (training) don't leave a void below their content."
///
/// The port had it as a fixed `FractionallySizedBox` with a per-sheet fraction,
/// so a sheet holding three quests was 80% of the phone whatever was in it —
/// reported as popups taking more room than they need, and as the season quests
/// sheet being mostly empty at the bottom. Fitting is not an opt-in any more;
/// what a call site chooses is how far its sheet may GROW.
///
/// **A body has to be able to say how tall it is, or nothing changes.** A
/// `ListView` fills whatever it is given, so a sheet built on one wants
/// `shrinkWrap: true`, and a `Column` wants `MainAxisSize.min` with `Flexible`
/// rather than `Expanded` round its scrolling part. The cap is what makes that
/// safe: the list is measured against a bounded box and scrolls past it.
Future<T?> showBottomSheetPopup<T>(
  BuildContext context, {
  required Widget child,
  double heightFraction = 0.75,
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
              // **THE FRAME PAYS FOR THE GRABBER, so no sheet has to.**
              // The handle is an overlay rather than a row — see below — which
              // kept every sheet its full height and left the clearance to the
              // content: the ones with a [SheetHeader] happened to have enough
              // and the ones without had none, so a title, a first row or a
              // chart started underneath the bar. Reported from the couch:
              // "all of these popups should have some space at the top for the
              // grabber, some of them do but not all, the bench is a good
              // example." Twelve is where the bar's own bottom edge is.
              Padding(
                padding: const EdgeInsets.only(top: sheetGrabberSpace),
                child: child,
              ),
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

/// The room a sheet leaves above its content for [_DragHandle].
///
/// The handle is 8pt of padding, a 4pt bar and 8pt more, so its bar ends at
/// twelve — which is the least a sheet can start at without drawing over it.
const double sheetGrabberSpace = 12;

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

/// The sheet's box: as tall as its content needs, up to the cap.
class _Frame extends StatelessWidget {
  const _Frame({
    super.key,
    required this.heightFraction,
    required this.child,
  });

  final double heightFraction;
  final Widget child;

  /// The absolute ceiling, on top of the fraction — `min(85vh, 780px)` in the
  /// spec. On a tall phone a fraction alone keeps growing, and past this a sheet
  /// is a screen that arrived from the wrong direction.
  static const double maxSheetHeight = 780;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: math.min(
        MediaQuery.sizeOf(context).height * heightFraction,
        maxSheetHeight,
      ),
    ),
    // Bottom-anchored and only as tall as it needs, which is what a sheet
    // showing four tiles should be.
    child: child,
  );
}
