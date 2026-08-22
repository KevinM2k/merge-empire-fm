/// Whether something opaque is sitting over the tab body.
///
/// **THE SECOND ANIMATED SCREEN.** A modal bottom sheet is a `PopupRoute`: it
/// rises OVER the current route without pushing it out, so nothing in Flutter
/// tells the screen underneath that it has stopped being looked at, and its
/// tickers keep running. On the home tab that is the pitch scene, the weather,
/// the ball and a walking manager, all animating behind an opaque sheet — which
/// is precisely the diagnosis the customiser's lag was reported with, and the
/// half the first profile of it never measured. It profiled the BUILD.
///
/// A COUNT rather than a flag, because sheets stack: the gem shelf opens over
/// the confirm that could not be paid for, and the first one closing must not
/// hand the frames back while the second is still up.
///
/// The shell reads it and switches `TickerMode` off for the covered body. It
/// does NOT hide anything — the sheet is opaque, so there is nothing to see;
/// what stops is the clock.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

final screenCoveredProvider = StateProvider<int>((ref) => 0);

/// True while anything opaque is over the tab body.
final screenIsCoveredProvider = Provider<bool>(
  (ref) => ref.watch(screenCoveredProvider) > 0,
);
