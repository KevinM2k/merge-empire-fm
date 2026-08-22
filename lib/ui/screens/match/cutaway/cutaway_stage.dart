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

import 'package:flame/game.dart' show GameWidget;
import 'package:merge_empire_fc/i18n/i18n.dart';
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

/// The smallest chance worth cutting to, as the JS's own threshold.
const double cutawayBigXg = 0.22;

/// Game-minutes between chance cutaways. **Goals are exempt** — they are always
/// worth showing.
///
/// The JS's `CUTAWAY_GAP_MINS`, and the pacing matters more here than it reads:
/// the engine generates a chance about every SEVEN minutes, so without a gap the
/// screen is a cutaway with a match happening somewhere behind it.
const int cutawayGapMinutes = 12;

/// Build the clip for an event, or null when there is nothing to show.
///
/// [ourSideLeft] is which end we defend, and [ours] whether this chance is
/// ours — together they decide which way the attack runs, so one sequence table
/// serves all four combinations.
///
/// **THREE REASONS TO SHOW NOTHING, and the port honoured none of them.**
///
/// 1. **The player switched it off.** `cutawayOurTeam` and `cutawayOpponent`
///    are in the schema, in the migration and on the Settings screen as two
///    independent flags — and nothing here read either, so both switches did
///    nothing at all.
/// 2. **It was not a big chance.** The engine marks one at [cutawayBigXg]; the
///    rest are a statistic, not a passage of play worth watching.
/// 3. **The last one was too recent.** See [cutawayGapMinutes].
CutawayClip? clipFor(
  TimelineEvent event, {
  required bool ourSideLeft,
  required bool ours,
  required int seed,
  bool ourTeamOn = true,
  bool opponentOn = true,
  int? lastCutawayMinute,
}) {
  if (!(ours ? ourTeamOn : opponentOn)) return null;
  if (event.type == 'chance') {
    if (!event.big && event.xg < cutawayBigXg) return null;
    if (lastCutawayMinute != null &&
        event.minute - lastCutawayMinute < cutawayGapMinutes) {
      return null;
    }
  }
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
  const CutawayStage({
    required this.clip,
    this.onDone,
    this.scorer,
    this.scorerFromLeft = true,
    super.key,
  });

  /// Null shows the idle pitch — which is most of a match.
  final CutawayClip? clip;

  final void Function(CutawayOutcome outcome)? onDone;

  /// Who to stand on the touchline the moment the ball goes in, or null when
  /// there is nobody to name — theirs, or one of ours the save has lost.
  ///
  /// It arrives with the VERDICT rather than with the clip: shown from the
  /// start it would tell the player the ball was going in before it did.
  final Widget? scorer;

  /// Which touchline he comes on from — ours, so he enters from the edge he
  /// then rests against rather than out of nothing in the middle of the grass.
  final bool scorerFromLeft;

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
              ? const _InPerspective(
                  child: CustomPaint(
                    key: ValueKey('cutaway-idle'),
                    painter: _IdlePitchPainter(),
                    size: Size.infinite,
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    // **THE PITCH IS IN PERSPECTIVE, and the markings, the
                    // players and the ball are all IN it** — because it is one
                    // transform over the layers that are the pitch, rather than
                    // a picture of a pitch with flat things standing on it.
                    // That is the whole reason it could not be a photograph or
                    // a PNG in a trapezoid: everything on the grass has to sit
                    // in the same projection, and the only way to get that for
                    // free is for the projection to be applied once, to all of
                    // it.
                    //
                    // The overlays — the verdict, the scorer's badge — stay
                    // FLAT. They are a broadcast graphic laid over the picture,
                    // not something on the pitch, and a headline that leans
                    // away from the reader is a headline nobody reads.
                    // The markings, painted UNDER the game.
                    //
                    // `onLoad` is async however warm the cache is, so there is
                    // always at least one frame where the world is empty. On a
                    // bare background that frame is a flat green flash; on the
                    // same pitch the clip is about to draw it is invisible,
                    // because it is already the picture.
                    _InPerspective(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const CustomPaint(
                            painter: _IdlePitchPainter(),
                            size: Size.infinite,
                          ),
                          GameWidget(
                            key: ValueKey('cutaway-${game.seed}'),
                            game: game,
                            // Transparent, so the markings underneath show
                            // through until the world has something in it.
                            backgroundBuilder: (_) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    // The word, over the top. In FLUTTER rather than in Flame: a
                    // headline wants the app's own type and a spring, and Flame's
                    // text renderer has neither.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ValueListenableBuilder<CutawayOutcome?>(
                          valueListenable: game.verdict,
                          builder: (context, outcome, _) =>
                              _Verdict(outcome: outcome),
                        ),
                      ),
                    ),
                    if (widget.scorer case final scorer?)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ValueListenableBuilder<CutawayOutcome?>(
                            valueListenable: game.verdict,
                            builder: (context, outcome, _) => _ScorerSlide(
                              shown: outcome == CutawayOutcome.goal,
                              fromLeft: widget.scorerFromLeft,
                              child: scorer,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The scorer, arriving from his own touchline.
///
/// Slides in and fades up — 420ms on an exponential ease-out with no overshoot,
/// because it is a player arriving rather than a springy UI chip. Transform and
/// opacity only, so it composes over a clip that is already animating.
///
/// No exit: the pitch is torn down under him the moment the clip resolves, so he
/// goes with the grass he is standing on.
class _ScorerSlide extends StatelessWidget {
  const _ScorerSlide({
    required this.shown,
    required this.fromLeft,
    required this.child,
  });

  final bool shown;
  final bool fromLeft;
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: fromLeft ? Alignment.bottomLeft : Alignment.bottomRight,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: AnimatedSlide(
        offset: shown ? Offset.zero : Offset(fromLeft ? -1.4 : 1.4, 0),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutExpo,
        child: AnimatedOpacity(
          opacity: shown ? 1 : 0,
          duration: const Duration(milliseconds: 420),
          child: child,
        ),
      ),
    ),
  );
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

/// GOAL, SAVED, MISSED.
///
/// **A chance with no word on it is a chance you have to work out.** The passage
/// ends, the ball is somewhere, and whether that was a goal or a save is a thing
/// the player reads off the ball's position — which on a 200px pitch is asking a
/// lot. The word is the whole point of the cutaway landing.
///
/// The engine only ever records two kinds of chance — on target and off — so
/// there are three words and not six. The post and the crossbar are in
/// [CutawayOutcome] because the geometry can draw them, and they never arrive.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.outcome});

  final CutawayOutcome? outcome;

  /// Which of the three, and in what colour.
  ({String key, Color ink})? get _word => switch (outcome) {
    null => null,
    CutawayOutcome.goal => (key: 'mg.goal', ink: const Color(0xFF4ADE80)),
    CutawayOutcome.saved => (key: 'mg.saved', ink: const Color(0xFF7FD4FF)),
    // Wide, over, off the frame — one word for all of them, because from here
    // they are the same event.
    _ => (key: 'mg.miss', ink: const Color(0xFFFFC247)),
  };

  @override
  Widget build(BuildContext context) {
    final word = _word;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      // Springs in and holds. It is on screen for a second at most, so a fade
      // out would spend most of that fading.
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: Tween<double>(begin: 0.55, end: 1).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Cubic(0.34, 1.56, 0.64, 1),
          ),
        ),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: word == null
          ? const SizedBox.shrink(key: ValueKey('cutaway-verdict-none'))
          : Center(
              key: ValueKey('cutaway-verdict-${word.key}'),
              child: Text(
                t(word.key),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: word.ink,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  height: 1,
                  // On grass, so it carries its own separation — and a heavy one,
                  // because the turf under it is mid-green and the word is
                  // bright.
                  shadows: const [
                    Shadow(color: Color(0xCC000000), blurRadius: 8),
                    Shadow(
                      color: Color(0x99000000),
                      blurRadius: 2,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// How far the camera is raised behind the pitch, in radians.
///
/// **Small on purpose.** This is a broadcast's high wide, not a corner-flag
/// camera: the far touchline foreshortens, the near one opens out, and every
/// marking stays readable. Past about fifteen degrees the far half stops being
/// a place a chance can be understood in, which is the one thing this band is
/// for.
const double pitchTilt = 0.22;

/// How strong the vanishing is. A gentle value: the pitch is wide and short in
/// this band, so a strong perspective turns it into a wedge.
const double pitchVanish = 0.0011;

/// The pitch, seen from a camera rather than from directly above.
///
/// **DRAWN, not a photograph laid in a trapezoid.** Everything on the grass —
/// the markings, the twenty-two bodies, the ball, the momentum arrow — has to
/// sit in the same projection, and the only way to get that without teaching
/// each of them about it is to apply the projection ONCE, to all of them
/// together. `CutawayGame` and `_IdlePitchPainter` go on working in the same
/// flat coordinates they always did.
Matrix4 _tilted() => Matrix4.identity()
  ..setEntry(3, 2, pitchVanish)
  ..rotateX(pitchTilt);

class _InPerspective extends StatelessWidget {
  const _InPerspective({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Transform(
    // About the CENTRE, so the pitch keeps its band rather than sliding up out
    // of it — a rotation about the top edge would take the far half off screen.
    alignment: Alignment.center,
    // Built through `Transform`'s own helpers rather than naming `Matrix4`:
    // `flame/game.dart` re-exports the 32-bit one and Flutter's transforms want
    // the 64-bit one, and this file imports both.
    transform: _tilted(),
    // Filtered: the mown stripes are hairlines and nearest-neighbour on a tilted
    // plane is a staircase.
    filterQuality: FilterQuality.medium,
    child: child,
  );
}
