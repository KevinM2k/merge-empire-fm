/// Whether the boot's cloud restore has settled.
///
/// **THE SPLASH IS THE PLACE A RESTORE IS ALLOWED TO COST TIME, and it was not
/// waiting for one.** The JS gates its splash on the cloud restore and fades
/// out when that completes *or times out* — `main.js` is explicit that a slow
/// network must never trap a player there. The port had ported the splash's
/// face and its minimum window and none of its gate, so the two halves of the
/// boot ran past each other: the splash lifted on a fixed clock while
/// `_restoreSessionAndCloud` was still in the air, and a restore that landed a
/// beat later swapped the whole save out from under a player who was already
/// looking at their squad.
///
/// **It does NOT reinstate waiting on the network to draw**, which
/// `game_host.dart` rejected on purpose and was right to: the first frame is
/// still drawn immediately and the restore is still fired and forgotten. What
/// changes is only what covers it. The splash is already on screen, already
/// holding a minimum window, and already going to fade — this decides which
/// moment it fades ON.
///
/// A completer rather than a flag: the splash has to be able to WAIT for it,
/// and it is set exactly once per launch whichever way the restore ends —
/// restored, unchanged, offline, or thrown.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long the splash will hold for a restore before giving up on it.
///
/// **The number is this port's, and it has to be said plainly**: the JS's own
/// timeout is in `main.js` and `../merge-empire-fc` is not cloned in a cloud
/// container, so it could not be read. Six seconds is chosen against the rule
/// rather than against the source — long enough that a normal mobile round
/// trip lands inside it, short enough that nobody on a dead network thinks the
/// game has hung. The minimum window is 2.6s, so the worst case a player can
/// see is a splash about twice as long as the usual one.
const bootGateTimeout = Duration(seconds: 6);

/// Set once, when the boot's restore has settled whichever way it went.
class BootGate {
  final Completer<void> _settled = Completer<void>();

  /// Completes when the restore is done with. Never throws: a restore that
  /// failed is still a restore that has finished, and the splash's only
  /// question is whether the save is still moving.
  Future<void> get settled => _settled.future;

  bool get isSettled => _settled.isCompleted;

  void settle() {
    if (!_settled.isCompleted) _settled.complete();
  }
}

final bootGateProvider = Provider<BootGate>((ref) => BootGate());
