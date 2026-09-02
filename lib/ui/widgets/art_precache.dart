/// **KEEP THE SQUAD'S FACES DECODED ACROSS A BACKGROUND.**
///
/// Reported from a handset, and the shape of the report is the whole diagnosis:
/// "lag when i scroll things — only for the first few times then it feels
/// better, until i go away and come back then it does it again." That is not a
/// frame budget problem, which would be constant; it is first-use raster work,
/// and the thing that resets it is leaving the app.
///
/// Android sends `onTrimMemory` when an app goes to the background and Flutter's
/// engine answers it by emptying the image cache. So every portrait on the
/// Players tab is decoded again the first time it is scrolled past, one at a
/// time, on the raster thread, while the thumb is moving. `ArtImage` already
/// decodes at the size it will be DRAWN at — see its own note about the reveal
/// stuttering on its first frame — which makes each decode cheap; there are just
/// thirty-eight of them and they all land at once.
///
/// So they are asked for up front instead, off the frame, where nobody is
/// waiting: at boot and again on every resume. `precacheImage` de-duplicates
/// against the live cache, so a resume that did not lose anything costs nothing.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/data/art_paths.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/state/card_instance.dart';

/// Every distinct portrait the grid is currently holding.
///
/// A `Set`, because a squad of thirty-eight is very often a dozen distinct
/// drawings — the same tier and position in the same variant is the same file.
Set<String> gridArtPaths(Map<String, dynamic>? state) {
  final grid = state?['grid'];
  final cells = grid is Map<String, dynamic> ? grid['cells'] : null;
  if (cells is! List) return const {};
  return {
    for (final raw in cells)
      if (CardInstance.from(raw) case final card?)
        if (getPlayerDef(card.definitionId) case final def?)
          playerImagePath(def.position, def.tier, card.variant),
  };
}

/// Warm the decoder for [paths]. Never awaited by a caller that is drawing.
///
/// Failures are swallowed on purpose: a path that is not in the bundle is
/// already handled at the point of use by `ArtImage.fallback`, and a precache
/// is an optimisation — it must never be able to take a screen down.
Future<void> precacheArt(BuildContext context, Iterable<String> paths) async {
  for (final path in paths) {
    if (!context.mounted) return;
    try {
      await precacheImage(AssetImage(path), context);
    } catch (_) {
      // See above.
    }
  }
}
