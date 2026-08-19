/// Where a queued popup opens.
///
/// The queue in `util/popup_queue.dart` decides WHEN; it has no BuildContext and
/// no opinion about widgets. This is the other half: it sits above the shell,
/// holds a context the queue's `show` callbacks can open into, and drains once
/// on mount so anything queued during boot opens as soon as there is somewhere
/// to put it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/boot_popups.dart';
import 'package:merge_empire_fc/ui/screens/transfers/transfer_offer_card.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';

class PopupHost extends ConsumerStatefulWidget {
  const PopupHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PopupHost> createState() => PopupHostState();
}

class PopupHostState extends ConsumerState<PopupHost> {
  @override
  void initState() {
    super.initState();
    // After the first frame: a popup opened during build would be pushing a
    // route while the tree that hosts it is still being built. Until then the
    // queue holds noHostBlocker, so anything boot queued has waited rather than
    // been dropped for want of somewhere to open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Queue what this boot owes BEFORE releasing the blocker, so the two are
      // one step and nothing drains against an empty queue first.
      final game = ref.read(gameProvider);
      queueBootPopups(
        context: () => context,
        game: game,
        offline: game.state == null
            ? (earned: 0, offlineMs: 0)
            : processOfflineEarnings(game.state!),
      );
      unblockPopups(noHostBlocker);
    });
    on('transfer:offered', _onIdleOffer);
  }

  /// An idle bid, brought to the player.
  ///
  /// `maybeGenerateIdleOffer` runs on the tick and announces here; nothing was
  /// listening, so an offer sat pending until it timed out five minutes later —
  /// and the timeout is scored as a DECLINE, grudge and all. A bid that costs
  /// you something has to be shown.
  ///
  /// The gate is claimed while the card is up so the next tick does not roll a
  /// second one behind it.
  Future<void> _onIdleOffer(Object? _) async {
    if (!mounted) return;
    final gates = ref.read(tickGatesProvider.notifier);
    final before = ref.read(tickGatesProvider);
    gates.state = (
      matchOpen: before.matchOpen,
      miniGameOpen: before.miniGameOpen,
      transferOpen: true,
      colinOnScreen: before.colinOnScreen,
    );
    try {
      if (mounted) await showTransferOffer(context, ref);
    } finally {
      if (mounted) {
        final now = ref.read(tickGatesProvider);
        gates.state = (
          matchOpen: now.matchOpen,
          miniGameOpen: now.miniGameOpen,
          transferOpen: false,
          colinOnScreen: now.colinOnScreen,
        );
      }
    }
  }

  @override
  void dispose() {
    off('transfer:offered', _onIdleOffer);
    blockPopups(noHostBlocker);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
