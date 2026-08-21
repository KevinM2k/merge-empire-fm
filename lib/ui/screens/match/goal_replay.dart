/// A goal, played again.
///
/// **The passage already exists.** `clipFor` builds a clip out of a timeline
/// event and `CutawayStage` plays one; both are seeded off the minute, so a
/// replay is not a recording — it is the same passage rebuilt from the same
/// number, which is why it comes out identical every time and costs nothing to
/// keep.
///
/// What was missing was a way to ask for one. A goal goes past in the feed
/// while the manager is reading the line above it, and the one thing a player
/// wants to see twice is the only thing on the screen they could not.
///
/// **It holds the match while it is up**, the way the subs panel does — the
/// caller pauses. A clock running behind a replay would put the manager back on
/// a match that had moved on without them.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_stage.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// Show one, and resolve when the player closes it.
Future<void> showGoalReplay(
  BuildContext context, {
  required CutawayClip clip,
  required int minute,
  required String title,
  required bool ours,
  Widget? scorer,
  bool scorerFromLeft = true,
}) => showDialog<void>(
  context: context,
  barrierDismissible: true,
  builder: (_) => GoalReplayDialog(
    clip: clip,
    minute: minute,
    title: title,
    ours: ours,
    scorer: scorer,
    scorerFromLeft: scorerFromLeft,
  ),
);

class GoalReplayDialog extends StatelessWidget {
  const GoalReplayDialog({
    required this.clip,
    required this.minute,
    required this.title,
    required this.ours,
    this.scorer,
    this.scorerFromLeft = true,
    super.key,
  });

  final CutawayClip clip;
  final int minute;

  /// The word for one of ours, and THEIR NAME for one of theirs — the same
  /// head the goal card in the feed carries, because it is the same goal.
  final String title;
  final bool ours;
  final Widget? scorer;
  final bool scorerFromLeft;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final ink = ours ? kit.accentBright : conceded;
    return Dialog(
      key: const ValueKey('goal-replay'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: kit.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  "$minute'",
                  style: TextStyle(
                    color: kit.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: ink,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('goal-replay-close'),
                  tooltip: t('common.close'),
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // The stage brings its own aspect ratio and its own idle pitch, so
            // the popup only has to say how wide the grass is.
            CutawayStage(
              clip: clip,
              scorer: scorer,
              scorerFromLeft: scorerFromLeft,
            ),
          ],
        ),
      ),
    );
  }
}

/// A goal AGAINST, in red.
///
/// **Not the kit.** Green is what this game uses for a thing going well for us,
/// on every screen, so an opponent's goal wearing it read as one of ours.
///
/// It lives here rather than on the match screen because both the feed's goal
/// card and this popup are the same goal wearing the same colour, and the
/// dependency has to run screen → widget rather than back.
const Color conceded = Color(0xFFE05A4A);
