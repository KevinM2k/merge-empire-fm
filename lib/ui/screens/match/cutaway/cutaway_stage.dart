/// The pitch the match is watched on, and the chances that cut in over it.
///
/// **The stage is persistent.** An empty pitch sits there between chances and a
/// clip cuts in over the SAME pitch — that is the whole point of it, and it is
/// why the markings are drawn in one place: a second hand-drawn set would be
/// visibly wrong the moment the two drifted apart.
///
/// A chance is `simulateMatch`'s decision, already made. Nothing here changes
/// what happened; it only shows it, the same division of labour `match_clock`
/// keeps for the feed.
library;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_game.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_pitch.dart';
import 'package:merge_empire_fc/ui/screens/match/match_clock.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_sequences.dart';

/// What a feed event should look like on the pitch, or null when it is not a
/// thing you watch — a half-time whistle has no passage of play.
CutawayOutcome? outcomeForEvent(TimelineEvent event) => switch (event.type) {
  'goal' => CutawayOutcome.goal,
  // A chance the keeper got to, or one that never troubled him. The engine
  // records only those two, so the post and the crossbar stay out of this
  // mapping rather than being invented here.
  'chance' when event.shotResult == 'on_target' => CutawayOutcome.saved,
  'chance' => CutawayOutcome.wide,
  _ => null,
};

/// One clip: which passage, which way, and how it ends.
typedef CutawayClip = ({
  CutawaySequence sequence,
  bool attackingRight,
  CutawayOutcome outcome,
  int seed,
});

/// Build the clip for an event, or null when there is nothing to show.
///
/// [ourSideLeft] is which end we defend, and [ours] whether this chance is
/// ours — together they decide which way the attack runs, so one sequence table
/// serves all four combinations.
CutawayClip? clipFor(
  TimelineEvent event, {
  required bool ourSideLeft,
  required bool ours,
  required int seed,
}) {
  final outcome = outcomeForEvent(event);
  if (outcome == null) return null;
  final roll = ((seed * 2654435761) % 100000) / 100000;
  return (
    sequence: pickSequence(roll),
    // Attacking away from the end you defend.
    attackingRight: ours ? ourSideLeft : !ourSideLeft,
    outcome: outcome,
    seed: seed,
  );
}

/// The pitch, with or without a chance running on it.
class CutawayStage extends StatelessWidget {
  const CutawayStage({required this.clip, this.onDone, super.key});

  /// Null shows the idle pitch — which is most of a match.
  final CutawayClip? clip;

  final void Function(CutawayOutcome outcome)? onDone;

  @override
  Widget build(BuildContext context) {
    final current = clip;
    return AspectRatio(
      aspectRatio: pitchAspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ColoredBox(
          color: PitchBackdrop.turf,
          child: current == null
              ? const CustomPaint(
                  key: ValueKey('cutaway-idle'),
                  painter: _IdlePitchPainter(),
                  size: Size.infinite,
                )
              : GameWidget(
                  // Keyed on the clip so a new chance builds a new game rather
                  // than resuming the last one mid-passage.
                  key: ValueKey('cutaway-${current.seed}'),
                  game: CutawayGame(
                    sequence: current.sequence,
                    attackingRight: current.attackingRight,
                    outcome: current.outcome,
                    seed: current.seed,
                    onDone: onDone,
                  ),
                ),
        ),
      ),
    );
  }
}

/// The empty pitch between chances.
///
/// Deliberately the same geometry as [PitchBackdrop] — it IS that, scaled to
/// the widget — so the clip cutting in does not visibly move the markings.
class _IdlePitchPainter extends CustomPainter {
  const _IdlePitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / pitchWidth, size.height / pitchHeight);
    PitchBackdrop().render(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IdlePitchPainter oldDelegate) => false;
}
