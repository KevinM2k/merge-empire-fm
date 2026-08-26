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
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_game.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/idle_pitch_game.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_pitch.dart';
import 'package:merge_empire_fc/ui/screens/match/match_clock.dart';
import 'package:merge_empire_fc/data/players.dart' show getPlayerDef;
import 'package:merge_empire_fc/ui/screens/squad/player_detail_sheet.dart'
    show cardById;
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_sequences.dart';

/// What a feed event should look like on the pitch, or null when it is not a
/// thing you watch — a half-time whistle has no passage of play.
///
/// **The odds are `_resolveOutcome` in `ChanceCutaway.js`.** The engine records
/// only on target or off, and this used to map those straight to a save and a
/// miss — so the post was never hit, while `woodwork` played for every save
/// and `commentary.hit_post` shipped in ten languages with no caller. The JS
/// rolls the ending on the clip, and so does this; [roll] is the clip's own
/// seeded draw. Its `bar` is folded into [CutawayOutcome.post] (the same
/// commentary covers both) and `blocked` into `wide` — there is no defender's
/// block on this pitch.
CutawayOutcome? outcomeForEvent(TimelineEvent event, {double roll = 0}) =>
    switch (event.type) {
      'goal' => CutawayOutcome.goal,
      'chance' when event.shotResult == 'on_target' => roll < 0.58
          ? CutawayOutcome.saved
          : roll < 0.76
          ? CutawayOutcome.over
          : CutawayOutcome.post,
      'chance' => roll < 0.30
          ? CutawayOutcome.wide
          : roll < 0.54
          ? CutawayOutcome.over
          : roll < 0.84
          ? CutawayOutcome.post
          : CutawayOutcome.wide,
      _ => null,
    };

/// The feed line for a chance the pitch has just retold — `_endCutaway`'s
/// table in `MatchPopup.js`, so the commentary says what was shown.
String commentaryKeyFor(CutawayOutcome outcome) => switch (outcome) {
  CutawayOutcome.post => 'commentary.hit_post',
  CutawayOutcome.over => 'commentary.shot_over',
  CutawayOutcome.wide => 'commentary.shot_wide',
  CutawayOutcome.tackled => 'commentary.dispossessed',
  CutawayOutcome.saved || CutawayOutcome.goal => 'commentary.forces_save',
};

/// One clip: which passage, which way, and how it ends.
typedef CutawayClip = ({
  CutawaySequence sequence,
  bool attackingRight,
  CutawayOutcome outcome,
  int seed,
  /// Whether the attacking side is OURS — which side wears the names.
  bool ours,
  /// Our eleven's names, in the JS's order (the lineup, last slot first).
  List<String> names,
  /// The goalscorer, forced onto whoever takes the shot.
  String? scorerName,
});

/// A label as the JS's `_short` prints it: the last word of the name — the
/// surname, or the whole of a one-word name — cut to eight and an ellipsis
/// past nine.
String shortName(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  final s = parts.isEmpty || parts.last.isEmpty ? name : parts.last;
  return s.length > 9 ? '${s.substring(0, 8)}…' : s;
}

/// Our eleven's names for the dots, the JS's `_ourSurnames`: the lineup read
/// last slot first, each slot's card by name. A slot with no card is skipped.
List<String> lineupNames(Map<String, dynamic>? state) {
  final squad = state?['squad'];
  final lineup = squad is Map ? squad['lineup'] : null;
  if (lineup is! List) return const [];
  final out = <String>[];
  for (final raw in lineup.reversed) {
    if (raw is! Map) continue;
    final name = cardDisplayName(state, '${raw['cardInstanceId'] ?? ''}');
    if (name != null && name.isNotEmpty) out.add(name);
  }
  return out;
}

/// A card's display name, or null when the save no longer has it.
String? cardDisplayName(Map<String, dynamic>? state, String instanceId) {
  if (instanceId.isEmpty) return null;
  final card = cardById(state, instanceId);
  final def = getPlayerDef(card?.definitionId);
  if (card == null || def == null) return null;
  return card.name(def.name);
}

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
  List<String> names = const [],
  String? scorerName,
}) {
  if (!(ours ? ourTeamOn : opponentOn)) return null;
  if (event.type == 'chance') {
    if (!event.big && event.xg < cutawayBigXg) return null;
    if (lastCutawayMinute != null &&
        event.minute - lastCutawayMinute < cutawayGapMinutes) {
      return null;
    }
  }
  final roll = ((seed * 2654435761) % 100000) / 100000;
  // A second draw off the same seed, so the passage and its ending are picked
  // independently and a replay gets both back.
  final outcome = outcomeForEvent(
    event,
    roll: (((seed + 1) * 2654435761) % 100000) / 100000,
  );
  if (outcome == null) return null;
  return (
    sequence: pickSequence(roll),
    // Attacking away from the end you defend.
    attackingRight: ours ? ourSideLeft : !ourSideLeft,
    outcome: outcome,
    seed: seed,
    ours: ours,
    names: names,
    scorerName: scorerName,
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
    this.onStruck,
    this.onVerdict,
    this.scorer,
    this.scorerFromLeft = true,
    this.momentum,
    this.attackingRight = true,
    this.onGrass,
    super.key,
  });

  /// Drawn ON the pitch between chances — under the markings, in the pitch's
  /// own perspective. The momentum shading was a sibling of the stage in screen
  /// space, so it lay flat across the tilted pitch and the surround alike.
  final Widget? onGrass;

  /// Null shows the idle pitch — which is most of a match.
  final CutawayClip? clip;

  final void Function(CutawayOutcome outcome)? onDone;

  /// The ball has been STRUCK — the frame the boot is on it.
  ///
  /// **THE SOUND WAS ON THE MINUTE AND THE PICTURE WAS ON THE CLIP.** A passage
  /// runs a second or two of run-ups and passes before anybody shoots, and the
  /// match screen fired the shot and the crowd the instant the minute ticked. So
  /// the goal was heard while the ball was still in midfield and the net bulged
  /// in silence — reported as the sounds and the action not syncing up at all.
  ///
  /// These two are the passage's own beats, so a caller can hang a cue on the
  /// moment rather than on a guess at how long the moment takes to arrive.
  /// [onVerdict] always follows [onStruck]: the game only reaches a verdict
  /// through the shot's own flight.
  final VoidCallback? onStruck;

  /// The ball has ARRIVED, and this is what happened to it.
  final void Function(CutawayOutcome outcome)? onVerdict;

  /// Who to stand on the touchline the moment the ball goes in, or null when
  /// there is nobody to name — theirs, or one of ours the save has lost.
  ///
  /// It arrives with the VERDICT rather than with the clip: shown from the
  /// start it would tell the player the ball was going in before it did.
  final Widget? scorer;

  /// Which touchline he comes on from — ours, so he enters from the edge he
  /// then rests against rather than out of nothing in the middle of the grass.
  final bool scorerFromLeft;

  /// The arrow's own figure, ours-positive. Given, the stage keeps twenty-two
  /// bodies on the pitch between chances and slides their shape with it — see
  /// [IdlePitchGame]. Null draws the markings alone, which is what every test
  /// that is not about the idle pitch wants.
  final ValueNotifier<double>? momentum;

  /// Which way WE are kicking, so the idle shape reads the same way the clips
  /// do at both venues.
  final bool attackingRight;

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
    _syncIdle();
  }

  @override
  void didUpdateWidget(CutawayStage old) {
    super.didUpdateWidget(old);
    _syncGame();
    _syncIdle();
  }

  /// The idle pitch, built once and kept for the whole match.
  ///
  /// One instance rather than one per gap: rebuilding it every time a clip ends
  /// would reload the sprites and reset the shape, and the shape holding across
  /// a chance is what makes the clip read as part of the same match rather than
  /// as a cutaway to somewhere else.
  IdlePitchGame? _idle;

  void _syncIdle() {
    final momentum = widget.momentum;
    if (momentum == null) {
      _idle = null;
      return;
    }
    _idle ??= IdlePitchGame(
      attackingRight: widget.attackingRight,
      momentum: momentum,
    );
  }

  /// A NEW passage means a new game; the same passage means the same one.
  ///
  /// Keyed on the clip's seed, which is what identifies a chance — the minute it
  /// happened in. Everything else about the clip is derived from it.
  void _syncGame() {
    final clip = widget.clip;
    if (clip == null) {
      _listen(null);
      _game = null;
      _seed = null;
      return;
    }
    if (_seed == clip.seed && _game != null) return;
    _seed = clip.seed;
    final game = CutawayGame(
      sequence: clip.sequence,
      attackingRight: clip.attackingRight,
      outcome: clip.outcome,
      seed: clip.seed,
      ours: clip.ours,
      names: clip.names,
      scorerName: clip.scorerName,
      onDone: widget.onDone,
    );
    _listen(game);
    _game = game;
  }

  /// The game whose beats are being relayed, so the listeners come off the one
  /// they were put on — `_game` has already moved on by then.
  CutawayGame? _heard;

  void _listen(CutawayGame? game) {
    _heard?.struck.removeListener(_onStruck);
    _heard?.verdict.removeListener(_onVerdict);
    _heard = game;
    if (game == null) return;
    game.struck.addListener(_onStruck);
    game.verdict.addListener(_onVerdict);
  }

  void _onStruck() {
    // A counter, so the first bump is 1 — see `CutawayGame.struck`.
    if ((_heard?.struck.value ?? 0) > 0) widget.onStruck?.call();
  }

  void _onVerdict() {
    final outcome = _heard?.verdict.value;
    if (outcome != null) widget.onVerdict?.call(outcome);
  }

  @override
  void dispose() {
    _listen(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // **NO `AspectRatio` — THE STAGE FILLS WHAT IT IS GIVEN.** It held the
    // pitch's own aspect, so a box shorter than that aspect made the stage
    // NARROWER than the box: dead green down both sides and a band of it below,
    // which is exactly what a screenshot of a chance showed. The caller decides
    // the band's shape; `fittedTilt` fits the projection into whatever arrives,
    // so a shallow box is simply a shallow pitch.
    // **UNLESS NOBODY HAS GIVEN IT ONE.** The goal replay mounts this inside a
    // column with no height to hand down, and it was the aspect that used to
    // supply one — so filling the box there asks for infinity. Bounded, the
    // caller decides; unbounded, the pitch's own aspect still does.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (constraints.hasBoundedHeight) {
          // **AND IT ONLY TAKES THE HEIGHT THE PITCH USES.** The band is a cap,
          // not an instruction: given more room than the tilted pitch needs,
          // the stage filled it and the surplus was dead turf under the near
          // touchline — reported as most of the 2D match view being missing,
          // with a shot of a pitch sitting in the top half of a green box.
          // `tiltedBandHeight` is the height that makes the fit exact, so
          // asking for it can never leave a gap and never crops.
          final want = width.isFinite ? tiltedBandHeight(width) : null;
          return want != null && want < constraints.maxHeight
              ? SizedBox(height: want, child: _stage(context))
              : _stage(context);
        }
        // **THE TILTED shape, not the pitch's own.** A flat pitch's aspect
        // leaves the box nearly half empty once the projection has
        // foreshortened it — a small pitch adrift in a tall green rectangle,
        // which is what the goal replay looked like. See [tiltedBandHeight].
        return width.isFinite
            ? SizedBox(height: tiltedBandHeight(width), child: _stage(context))
            : AspectRatio(aspectRatio: pitchAspect, child: _stage(context));
      },
    );
  }

  Widget _stage(BuildContext context) {
    final game = _game;
    return SizedBox.expand(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ColoredBox(
          // **NOT the turf** — see [PitchBackdrop.surround]. Filling this with
          // the pitch's own green is what made the trapezoid invisible and the
          // pitch look cropped.
          color: PitchBackdrop.surround,
          child: game == null
              ? _InPerspective(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const CustomPaint(
                        key: ValueKey('cutaway-idle'),
                        painter: _IdlePitchPainter(lines: false),
                        size: Size.infinite,
                      ),
                      // See [CutawayStage.onGrass]: under the lines.
                      ?widget.onGrass,
                      const CustomPaint(
                        painter: _IdlePitchPainter(turf: false),
                        size: Size.infinite,
                      ),
                      // **THE BODIES ARE FOR CHANCES, and this reverses "the
                      // match, between the chances".** They were added because
                      // ninety minutes was a green rectangle with an arrow on
                      // it and a clip arrived out of an empty field — which was
                      // true, and the answer turned out to be worse than the
                      // problem: twenty-two figures drifting through a passage
                      // nobody is being told about is motion carrying no
                      // information, on the one band a player looks at to find
                      // out what just happened.
                      //
                      // Asked for directly, twice. The markings, the momentum
                      // arrow and the clips are what the band is for, and all
                      // three survive an empty pitch — a chance now ARRIVES,
                      // which is most of what makes it read as a chance.
                      //
                      // `IdlePitchGame` is kept and still built, because it is
                      // the same rig a clip runs on and deleting it would take
                      // the shape solver with it. It is simply not mounted.
                    ],
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
  const _IdlePitchPainter({this.turf = true, this.lines = true});

  /// Either half on its own, so something can be drawn between them.
  final bool turf;
  final bool lines;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / pitchWidth, size.height / pitchHeight);
    final backdrop = PitchBackdrop();
    if (turf) backdrop.renderTurf(canvas);
    if (lines) backdrop.renderLines(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IdlePitchPainter old) =>
      old.turf != turf || old.lines != lines;
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
/// **NEGATIVE, and that is the whole of the fix.** Flutter's +y is DOWN, so a
/// positive `rotateX` pushes the BOTTOM of the pitch away and pulls the top
/// toward the viewer — the far touchline ended up at the bottom of the band,
/// which is a camera lying on the grass behind the near goal. A broadcast's
/// high wide has the far touchline at the TOP and foreshortened.
///
/// **And stronger than it was.** 0.22 read as a pitch that was very slightly
/// not-flat rather than as a pitch seen from anywhere; this is about 24 degrees.
/// The trade is the one the old comment named — past this the far half stops
/// being a place a chance can be understood in, and that is the one thing this
/// band is for — so it is deliberately at the top of the range rather than past
/// it.
/// **STRONGER THREE TIMES, and every time the reason was SPACE.** -0.22 was a
/// pitch that was slightly not-flat; -0.42 and -0.62 were each still short of
/// the broadcast wide the screenshot showed. At -0.80 (about 46 degrees) the
/// far half really foreshortens, which is what lets the BAND be shorter without
/// the pitch looking cropped — a tilted plane needs less height on screen to
/// cover the same ground.
///
/// This is only safe because of [fittedTilt]: the projection widens the near
/// edge past its own box, so without the fit each of these steps pushed more of
/// the near touchline off the sides.
const double pitchTilt = 0;

/// How strong the vanishing is. Still short of a wedge: the pitch is wide and
/// shallow in this band, and past this the far touchline converges to a point
/// rather than to a line.
const double pitchVanish = 0;

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

/// The tilt, FITTED so the whole pitch stays inside its box.
///
/// **A perspective divide makes the near edge WIDER than the box it came from**,
/// so tilting about the centre and stopping there runs both near corners off the
/// sides of the frame — and the stronger the tilt, the more of the touchline
/// goes with them. Reported with a screenshot: the near side has to be fully
/// visible and the FAR side is the one that narrows.
///
/// So the quad is measured after the projection and scaled back down about its
/// own centre until it fits. That is also what makes a stronger tilt safe to
/// ask for, and a stronger tilt is what buys the band its height back — a
/// foreshortened plane covers the same ground in less screen.
/// [plane] is the flat pitch's own box; [into] is the band it has to end up
/// inside. They are DIFFERENT boxes and that is the point — the plane keeps the
/// pitch's aspect so nothing on it is letterboxed, and the band is whatever
/// height the screen could spare.
/// The tilt about the plane's own centre, before anything is fitted.
Matrix4 _about(Size plane) {
  final centre = Offset(plane.width / 2, plane.height / 2);
  return Matrix4.identity()
    ..translateByDouble(centre.dx, centre.dy, 0, 1)
    ..multiply(_tilted())
    ..translateByDouble(-centre.dx, -centre.dy, 0, 1);
}

/// How tall a band [width] across has to be for the tilted pitch to FILL it.
///
/// The projection spreads the near edge and foreshortens the far one, so a box
/// holding the flat pitch's aspect is about two-fifths dead green. Measured
/// rather than a constant: the perspective divide is in absolute units, so the
/// shape a tilt comes out as depends on how big the plane is.
double tiltedBandHeight(double width) {
  if (width <= 0) return 0;
  final plane = Size(width, width / pitchAspect);
  final bounds = MatrixUtils.transformRect(_about(plane), Offset.zero & plane);
  if (bounds.width <= 0) return plane.height;
  // The inset both ways, so the band it asks for is the one the fit will
  // actually use.
  final drawn = math.max(1.0, width - pitchFitInset * 2);
  return bounds.height * (drawn / bounds.width) + pitchFitInset * 2;
}

/// The box the fit works inside: the band, less [pitchFitInset] all round.
Size _inset(Size box) => Size(
  math.max(0, box.width - pitchFitInset * 2),
  math.max(0, box.height - pitchFitInset * 2),
);

/// How much room the fit leaves round the pitch, so the touchlines are drawn
/// INSIDE the box rather than along its edge.
///
/// **A line on the clip boundary is a line that is not there.** The fit put the
/// quad's corners at 0 and at the band's exact height, so the far and near
/// touchlines — one antialiased pixel each — landed half on the `ClipRRect` and
/// half off it. Reported as the pitch missing its top and bottom.
const double pitchFitInset = 3;

Matrix4 fittedTilt(Size plane, {Size? into}) {
  final band = _inset(into ?? plane);
  if (plane.isEmpty || band.isEmpty) return Matrix4.identity();
  final about = _about(plane);
  final bounds = MatrixUtils.transformRect(about, Offset.zero & plane);
  if (bounds.width <= 0 || bounds.height <= 0) return about;
  // **PER AXIS, so the pitch FILLS the band it was given.**
  //
  // This was `math.min` of the two — a contain fit — which meant a band whose
  // shape did not match the projection's got bars on the slack axis. The
  // callers' comments have said "a shallow box is simply a shallow pitch" and
  // "which `fittedTilt` handles by construction" since the band stopped being
  // an `AspectRatio`, and neither was true: a uniform scale cannot make a quad
  // fill a box of a different shape, so the band the match screen caps at 16%
  // of screen height letterboxed the moment that cap bound.
  //
  // **It binds on short and on wide screens, and not on a modern tall phone**,
  // which is why three passes over this band each found something real and a
  // fourth report still came in. Measured: an iPhone SE drew 84% of the pitch
  // with 28 points of dead green down each side, an iPad mini 81% with 67.
  //
  // Stretching a projection is safe in a way stretching a photograph is not —
  // the tilt is already a choice about how much foreshortening to show, so a
  // squatter band reads as a shallower camera rather than as a distorted
  // pitch. The worst case those two devices ask for is 0.81 of the height,
  // which is inside the range the tilt varies over anyway.
  final sx = band.width / bounds.width;
  final sy = band.height / bounds.height;
  // Centred on the FULL box, not on the inset one: the inset is room for the
  // lines, not a margin to sit inside.
  final whole = into ?? plane;
  return Matrix4.identity()
    ..translateByDouble(whole.width / 2, whole.height / 2, 0, 1)
    ..scaleByDouble(sx, sy, 1, 1)
    ..translateByDouble(-bounds.center.dx, -bounds.center.dy, 0, 1)
    ..multiply(about);
}

class _InPerspective extends StatelessWidget {
  const _InPerspective({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    // **The fit needs the SIZE.** The perspective divide is in absolute units,
    // so how far the near edge spreads depends on how tall the band actually
    // is — a constant would be right at one screen height and wrong at every
    // other.
    builder: (context, constraints) {
      final band = constraints.biggest;
      // **THE PLANE KEEPS THE PITCH'S OWN ASPECT, and that is what stopped
      // there being TWO pitches.** Flame fits `visibleGameSize` into the widget
      // preserving aspect, so on a band wider-and-shorter than the pitch the
      // GAME letterboxed itself — a small pitch of players inside a full-width
      // pitch of markings, which is exactly what a chance looked like.
      //
      // Giving the layers a plane of the right shape and tilting THAT into the
      // band means the markings and the game are the same rectangle again, and
      // the band's height is free to be whatever the screen can spare.
      final plane = Size(band.width, band.width / pitchAspect);
      return SizedBox.expand(
        child: Transform(
          transform: fittedTilt(plane, into: band),
          // Filtered: the mown stripes are hairlines and nearest-neighbour on
          // a tilted plane is a staircase.
          filterQuality: FilterQuality.medium,
          // **`OverflowBox`, BECAUSE A `SizedBox` HERE DID NOTHING.** The
          // expand above is TIGHT, and a `SizedBox` can only narrow the
          // constraints it is handed — so the layers went on being laid out at
          // the BAND's shape while the transform was fitted for the plane's.
          // The markings stretched to a band two-thirds the height of the plane
          // and Flame, which fits `visibleGameSize` preserving aspect,
          // letterboxed itself inside them: a small pitch of players sitting in
          // a wide pitch of markings, both of them floating high in the box.
          // That is the two-pitches screenshot, and it is the same bug the last
          // fix was aimed at rather than a new one.
          //
          // Top-left, because [fittedTilt] measures from `Offset.zero & plane`
          // and a centred child would be drawn half a plane out of register
          // with its own projection.
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: plane.width,
            maxWidth: plane.width,
            minHeight: plane.height,
            maxHeight: plane.height,
            child: child,
          ),
        ),
      );
    },
  );
}
