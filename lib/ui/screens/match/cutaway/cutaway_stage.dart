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
///
/// **The game is built ONCE per chance and held.** It was constructed inline in
/// `build` — `GameWidget(game: CutawayGame(...))` — and the match screen calls
/// `setState` on every simulated minute, so every tick handed `GameWidget` a
/// brand-new game object, which it dutifully detached the running one for and
/// attached in its place. The passage restarted from its first beat about once
/// a second and reloaded its sprites doing it. That is the judder, and it is
/// also most of the flashing.
class CutawayStage extends StatefulWidget {
  const CutawayStage({required this.clip, this.onDone, super.key});

  /// Null shows the idle pitch — which is most of a match.
  final CutawayClip? clip;

  final void Function(CutawayOutcome outcome)? onDone;

  @override
  State<CutawayStage> createState() => _CutawayStageState();
}

class _CutawayStageState extends State<CutawayStage> {
  CutawayGame? _game;
  int? _seed;

  @override
  void initState() {
    super.initState();
    _syncGame();
  }

  @override
  void didUpdateWidget(CutawayStage old) {
    super.didUpdateWidget(old);
    _syncGame();
  }

  /// A NEW passage means a new game; the same passage means the same one.
  ///
  /// Keyed on the clip's seed, which is what identifies a chance — the minute it
  /// happened in. Everything else about the clip is derived from it.
  void _syncGame() {
    final clip = widget.clip;
    if (clip == null) {
      _game = null;
      _seed = null;
      return;
    }
    if (_seed == clip.seed && _game != null) return;
    _seed = clip.seed;
    _game = CutawayGame(
      sequence: clip.sequence,
      attackingRight: clip.attackingRight,
      outcome: clip.outcome,
      seed: clip.seed,
      onDone: widget.onDone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return AspectRatio(
      aspectRatio: pitchAspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ColoredBox(
          color: PitchBackdrop.turf,
          child: game == null
              ? const CustomPaint(
                  key: ValueKey('cutaway-idle'),
                  painter: _IdlePitchPainter(),
                  size: Size.infinite,
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    // The markings, painted UNDER the game.
                    //
                    // `onLoad` is async however warm the cache is, so there is
                    // always at least one frame where the world is empty. On a
                    // bare background that frame is a flat green flash; on the
                    // same pitch the clip is about to draw it is invisible,
                    // because it is already the picture.
                    const CustomPaint(
                      painter: _IdlePitchPainter(),
                      size: Size.infinite,
                    ),
                    GameWidget(
                      key: ValueKey('cutaway-${game.seed}'),
                      game: game,
                      // Transparent, so the markings underneath show through
                      // until the world has something in it.
                      backgroundBuilder: (_) => const SizedBox.shrink(),
                    ),
                  ],
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
