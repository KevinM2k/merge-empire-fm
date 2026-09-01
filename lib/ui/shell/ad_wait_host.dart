/// The wait between tapping "watch a video" and a video.
///
/// **A warm ad opens on the tap and there is nothing to wait for.** This is for
/// the times there is: the first offer of a session, the seconds after a show
/// while the next ad loads, a slot that expired in the player's pocket, a
/// no-fill that takes the full [adLoadTimeout] to admit it. Ten seconds of a
/// button that did nothing is the shape of the bug this exists to stop.
///
/// **Above the Navigator, not inside the shell**, which is the whole reason it
/// is wired through `MaterialApp.builder`: the daily reward sheet and the
/// post-match card are ROUTES and stay open across their own video, so a scrim
/// in `AppShell`'s stack would sit underneath the very buttons it is guarding.
/// It also catches the one case a per-button spinner cannot — the energy sheet
/// pops itself before asking, so by the time the load starts there is no button
/// left to put a spinner on.
///
/// Two states, and they are deliberately not the same one:
///
/// - **Busy** — an invisible barrier that swallows taps. Instant, so a second
///   tap cannot land in the gap, and invisible so a warm ad does not flash a
///   scrim over the screen on its way to a video.
/// - **Slow** — the scrim and the spinner, after [adSpinnerDelay]. Only a tap
///   that is genuinely waiting on the network ever gets this far.
///
/// No words. The copy would need a new `t()` key, the catalogues are generated
/// from the JS and cannot grow one from this repo — see CLAUDE.md.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

class AdWaitHost extends ConsumerWidget {
  const AdWaitHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(adBusyProvider);
    if (busy == null) return const SizedBox.shrink();
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Positioned.fill(
      key: const ValueKey('ad-wait'),
      child: AbsorbPointer(
        // **The barrier is up before the scrim is.** Absorbing taps is the part
        // that has to be instant; showing something is the part that has to
        // wait, or every offer in the game flickers.
        child: AnimatedOpacity(
          opacity: busy.slow ? 1 : 0,
          duration: const Duration(milliseconds: 120),
          child: ColoredBox(
            color: kit.bg.withValues(alpha: 0.72),
            child: Center(
              child: CircularProgressIndicator(color: kit.accentBright),
            ),
          ),
        ),
      ),
    );
  }
}
