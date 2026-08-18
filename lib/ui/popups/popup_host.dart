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
      if (mounted) unblockPopups(noHostBlocker);
    });
  }

  @override
  void dispose() {
    blockPopups(noHostBlocker);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
