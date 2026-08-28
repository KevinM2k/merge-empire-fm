/// Portrait only, on a phone.
///
/// **The game is a portrait game.** Every screen is built as one column — the
/// grid, the squad's eleven, the match feed under a scoreboard — and none of
/// them has a landscape layout to fall back on. Turned sideways on a phone the
/// HUD, the tab strip and the page all compete for 400 points of height and the
/// result is unusable. Reported from an Android handset.
///
/// **A tablet and an unfolded fold are a different device**, which is why this
/// is a measurement rather than a flat lock: there is room for the same column
/// with the sky either side of it, and taking landscape away from a device that
/// can hold it would be worse than the bug.
///
/// The JS has no equivalent — a browser has no orientation to claim — so the
/// threshold is the platform's own: 600dp of shortest side is where Android
/// switches to its tablet resources and where Material's own breakpoints put
/// the line.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Where a phone stops and a tablet starts, in logical pixels of SHORTEST side.
///
/// The shortest side, not the width, because it is the one figure that does not
/// move when the device is rotated — so the answer is the same in both
/// orientations and the lock cannot oscillate.
const double tabletShortestSide = 600;

/// The orientations a device with this shortest side may play in.
///
/// Pure, so the threshold is testable without a binding: the widget below is
/// the only part that touches the platform channel.
List<DeviceOrientation> orientationsFor(double shortestSide) =>
    shortestSide >= tabletShortestSide
    ? const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]
    : const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown];

/// Applies [orientationsFor] to the device the app is actually running on.
///
/// It re-asks whenever the metrics change — a fold opening is a genuine change
/// of device, not a rotation — and it asks through `MediaQuery` rather than the
/// view, so a test can hand it a size.
class OrientationLock extends StatefulWidget {
  const OrientationLock({required this.child, super.key});

  final Widget child;

  @override
  State<OrientationLock> createState() => _OrientationLockState();
}

class _OrientationLockState extends State<OrientationLock> {
  /// The last set asked for. Held so an unrelated metrics change — the keyboard,
  /// the notification shade — does not fire a platform call per frame.
  List<DeviceOrientation>? _applied;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wanted = orientationsFor(MediaQuery.sizeOf(context).shortestSide);
    if (_applied != null && _sameAs(wanted)) return;
    _applied = wanted;
    SystemChrome.setPreferredOrientations(wanted);
  }

  bool _sameAs(List<DeviceOrientation> wanted) {
    final held = _applied!;
    if (held.length != wanted.length) return false;
    for (var i = 0; i < held.length; i++) {
      if (held[i] != wanted[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
