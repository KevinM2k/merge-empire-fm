/// The scripted passages of play. Ported from `SEQUENCES` in
/// `ui/components/ChanceCutaway.js`.
///
/// Twenty-nine of them, and they are DATA: a list of beats in attack space (see
/// `cutaway_pitch.dart`), which is what lets one table serve both teams shooting
/// both ways. Adding a chance is adding an entry here, not writing animation.
///
/// A beat is one of:
///
/// - [Start] — where the carrier picks it up.
/// - [Pass] — to feet, along the ground.
/// - [Through] — slid into space for a runner to collect.
/// - [Lofted] — a high switch or a raking diagonal, airborne.
/// - [Cross] — whipped into the box, airborne.
/// - [Cutback] — pulled back hard and low from the byline.
/// - [Dribble] — carried, optionally beating a lunge or being scythed down.
/// - [Finish] — the shot, which ends the passage.
///
/// `run` gives the receiver's starting spot so the run to MEET the ball is
/// visible rather than the ball arriving at someone already standing there.
/// `who` re-targets an earlier attacker, which is how a one-two is written.
///
/// Deliberately Flutter-free.
library;

import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_pitch.dart';

/// One instruction in a passage of play.
sealed class Beat {
  const Beat();
}

/// Where the carrier starts with it.
class Start extends Beat {
  const Start(this.at);

  final AttackPoint at;
}

/// A ball played to a team-mate.
class Pass extends Beat {
  const Pass(
    this.to, {
    this.kind = 'pass',
    this.run,
    this.who,
    this.firstTime = false,
  });

  final AttackPoint to;

  /// Which entry of `passStyles` this travels as.
  final String kind;

  /// Where the receiver starts, so their run into the ball is seen.
  final AttackPoint? run;

  /// Re-target an attacker who already touched it — a one-two.
  final int? who;

  /// Played back without a settling touch.
  final bool firstTime;
}

/// The ball carried.
class Dribble extends Beat {
  const Dribble(this.to, {this.beats = false, this.fouled = false});

  final AttackPoint to;

  /// Skips past a lunging defender on the way.
  final bool beats;

  /// Scythed down — the passage becomes a free kick from here.
  final bool fouled;
}

/// The shot. Always last.
class Finish extends Beat {
  const Finish(this.style, {this.firstTime = false});

  /// Which entry of `finishStyles` this is struck as.
  final String style;

  final bool firstTime;
}

/// The other side starting with it and losing it.
///
/// The opponent nearest [from] carries or plays it toward [to] — which is THEIR
/// way, so a lower p — and one of ours cuts it out [cut] of the way along that
/// line. [push] lifts their whole block up the pitch at kick-in, so a deep
/// interception has somebody to steal it from and leaves them sprinting back.
///
/// The point of it: which side a clip is going to favour is no longer obvious
/// from the opening frame.
typedef Steal = ({
  AttackPoint from,
  AttackPoint to,
  String kind,
  double cut,
  double push,
});

/// One chance, start to finish.
class CutawaySequence {
  const CutawaySequence({
    required this.id,
    required this.weight,
    required this.play,
    this.freeKick = false,
    this.steal,
  });

  final String id;

  /// How often this comes up relative to the others.
  final double weight;

  final List<Beat> play;

  /// Ends in a foul, and the free kick is staged from wherever it happened.
  final bool freeKick;

  final Steal? steal;
}

const List<CutawaySequence> cutawaySequences = [
  // Midfield split pass — striker curves off the shoulder of the last man and
  // runs through one-on-one.
  CutawaySequence(
    id: 'through_center',
    weight: 1.6,
    play: [
      Start((p: 0.36, q: 0.45)),
      Pass((p: 0.56, q: 0.55)),
      Pass((p: 0.90, q: 0.44), kind: 'through', run: (p: 0.62, q: 0.33)),
      Finish('oneonone'),
    ],
  ),
  // Slid down the inside-right channel for a runner arriving across the box.
  CutawaySequence(
    id: 'through_channel',
    weight: 1.2,
    play: [
      Start((p: 0.40, q: 0.62)),
      Pass((p: 0.58, q: 0.72)),
      Pass((p: 0.90, q: 0.66), kind: 'through', run: (p: 0.60, q: 0.52)),
      Finish('placed'),
    ],
  ),
  // Winger knocks it past the fullback outside and whips an early cross onto
  // the striker's head at the near post.
  CutawaySequence(
    id: 'cross_right_header',
    weight: 2.0,
    play: [
      Start((p: 0.44, q: 0.78)),
      Dribble((p: 0.80, q: 0.94), beats: true),
      Pass((p: 0.955, q: 0.47), kind: 'cross', run: (p: 0.68, q: 0.55)),
      Finish('header'),
    ],
  ),
  // Left-wing cross hung to the far post, met on the volley.
  CutawaySequence(
    id: 'cross_left_volley',
    weight: 1.8,
    play: [
      Start((p: 0.44, q: 0.22)),
      Dribble((p: 0.78, q: 0.06), beats: true),
      Pass((p: 0.93, q: 0.585), kind: 'cross', run: (p: 0.66, q: 0.42)),
      Finish('volley'),
    ],
  ),
  // Overlap to the byline, hard low cut-back to the spot, swept in first time.
  CutawaySequence(
    id: 'cutback_right',
    weight: 1.6,
    play: [
      Start((p: 0.52, q: 0.60)),
      Pass((p: 0.70, q: 0.85), run: (p: 0.55, q: 0.90)),
      Dribble((p: 1.00, q: 0.92)),
      Pass((p: 0.945, q: 0.56), kind: 'cutback', run: (p: 0.72, q: 0.50)),
      Finish('placed', firstTime: true),
    ],
  ),
  // Solo slalom — picks it up on the left, cuts inside past two lunges.
  CutawaySequence(
    id: 'solo_slalom',
    weight: 1.2,
    play: [
      Start((p: 0.40, q: 0.26)),
      Dribble((p: 0.56, q: 0.36), beats: true),
      Dribble((p: 0.70, q: 0.46), beats: true),
      Dribble((p: 0.83, q: 0.50)),
      Finish('placed'),
    ],
  ),
  // Won deep, carried at pace, sprung wide, slid across for a runner.
  CutawaySequence(
    id: 'counter_break',
    weight: 1.5,
    play: [
      Start((p: 0.10, q: 0.48)),
      Dribble((p: 0.32, q: 0.53)),
      Pass((p: 0.55, q: 0.70), run: (p: 0.34, q: 0.76)),
      Pass((p: 0.90, q: 0.56), kind: 'through', run: (p: 0.58, q: 0.47)),
      Finish('placed'),
    ],
  ),
  // One-two — into the target man's feet, darts on, first-time return.
  CutawaySequence(
    id: 'one_two',
    weight: 1.2,
    play: [
      Start((p: 0.58, q: 0.44)),
      Pass((p: 0.68, q: 0.58)),
      Pass((p: 0.90, q: 0.46), kind: 'through', who: 0, firstTime: true),
      Finish('placed'),
    ],
  ),
  // Raking diagonal to the far wing, headed home from the centre.
  CutawaySequence(
    id: 'switch_cross',
    weight: 1.2,
    play: [
      Start((p: 0.46, q: 0.20)),
      Pass((p: 0.66, q: 0.86), kind: 'lofted', run: (p: 0.52, q: 0.92)),
      Pass((p: 0.955, q: 0.50), kind: 'cross', run: (p: 0.70, q: 0.44)),
      Finish('header'),
    ],
  ),
  // Worked to the edge and laid back for a midfielder arriving.
  CutawaySequence(
    id: 'edge_strike',
    weight: 1.0,
    play: [
      Start((p: 0.64, q: 0.64)),
      Pass((p: 0.78, q: 0.56)),
      Pass((p: 0.70, q: 0.44), run: (p: 0.55, q: 0.42), firstTime: true),
      Finish('longshot', firstTime: true),
    ],
  ),
  // Quick triangles round the D, then the killer ball inside the fullback.
  CutawaySequence(
    id: 'tiki_box',
    weight: 1.0,
    play: [
      Start((p: 0.56, q: 0.38)),
      Pass((p: 0.64, q: 0.58)),
      Pass((p: 0.74, q: 0.40), firstTime: true),
      Pass((p: 0.91, q: 0.53), kind: 'through', run: (p: 0.70, q: 0.62)),
      Finish('placed'),
    ],
  ),

  // ── Free kicks: the passage ends with the foul, and the wall, the box runs
  //    and the curled shot are staged from wherever it happened.
  CutawaySequence(
    id: 'fk_center',
    weight: 0.7,
    freeKick: true,
    play: [
      Start((p: 0.55, q: 0.56)),
      Dribble((p: 0.73, q: 0.50), fouled: true),
    ],
  ),
  CutawaySequence(
    id: 'fk_wide',
    weight: 0.7,
    freeKick: true,
    play: [
      Start((p: 0.58, q: 0.24)),
      Dribble((p: 0.77, q: 0.30), fouled: true),
    ],
  ),
  CutawaySequence(
    id: 'fk_right',
    weight: 0.6,
    freeKick: true,
    play: [
      Start((p: 0.60, q: 0.80)),
      Dribble((p: 0.76, q: 0.72), fouled: true),
    ],
  ),
  CutawaySequence(
    id: 'fk_edge',
    weight: 0.5,
    freeKick: true,
    play: [
      Start((p: 0.66, q: 0.44)),
      Dribble((p: 0.82, q: 0.54), fouled: true),
    ],
  ),

  // ── Taken round the keeper ────────────────────────────────────────────────
  CutawaySequence(
    id: 'through_round_keeper',
    weight: 1.3,
    play: [
      Start((p: 0.42, q: 0.52)),
      Pass((p: 0.58, q: 0.42)),
      Pass((p: 0.84, q: 0.52), kind: 'through', run: (p: 0.60, q: 0.62)),
      Finish('rounded'),
    ],
  ),
  // Dinked over the top, taken down on the run, keeper rounded before the
  // covering defenders get back.
  CutawaySequence(
    id: 'lofted_over_top',
    weight: 1.1,
    play: [
      Start((p: 0.34, q: 0.36)),
      Pass((p: 0.80, q: 0.44), kind: 'lofted', run: (p: 0.52, q: 0.30)),
      Finish('rounded'),
    ],
  ),

  // ── Turnovers — the other lot start with it and lose it ───────────────────
  // High press: they try to play out, it is cut out on the edge of their own
  // box and squared for a first-time finish.
  CutawaySequence(
    id: 'turnover_press_high',
    weight: 1.2,
    steal: (
      from: (p: 0.80, q: 0.30),
      to: (p: 0.68, q: 0.66),
      kind: 'pass',
      cut: 0.55,
      push: 0,
    ),
    play: [
      Start((p: 0.74, q: 0.50)),
      Pass((p: 0.88, q: 0.62), run: (p: 0.74, q: 0.72)),
      Finish('placed', firstTime: true),
    ],
  ),
  // Deep interception with their whole side committed forward.
  CutawaySequence(
    id: 'turnover_counter_deep',
    weight: 1.4,
    steal: (
      from: (p: 0.40, q: 0.62),
      to: (p: 0.14, q: 0.42),
      kind: 'pass',
      cut: 0.5,
      push: 0.40,
    ),
    play: [
      Start((p: 0.27, q: 0.52)),
      Pass((p: 0.58, q: 0.74), run: (p: 0.34, q: 0.80)),
      Pass((p: 0.90, q: 0.56), kind: 'through', run: (p: 0.60, q: 0.46)),
      Finish('oneonone'),
    ],
  ),
  // Robbed carrying it out of midfield — down the line and hung to the far post.
  CutawaySequence(
    id: 'turnover_wide_break',
    weight: 1.2,
    steal: (
      from: (p: 0.52, q: 0.72),
      to: (p: 0.34, q: 0.80),
      kind: 'carry',
      cut: 0.5,
      push: 0.22,
    ),
    play: [
      Start((p: 0.43, q: 0.76)),
      Pass((p: 0.84, q: 0.86), kind: 'through', run: (p: 0.58, q: 0.88)),
      Pass((p: 0.95, q: 0.50), kind: 'cross', run: (p: 0.68, q: 0.46)),
      Finish('header'),
    ],
  ),
  // Their pass across the middle is read and picked off.
  CutawaySequence(
    id: 'turnover_solo_break',
    weight: 1.1,
    steal: (
      from: (p: 0.46, q: 0.42),
      to: (p: 0.28, q: 0.54),
      kind: 'pass',
      cut: 0.5,
      push: 0.30,
    ),
    play: [
      Start((p: 0.37, q: 0.48)),
      Dribble((p: 0.74, q: 0.52), beats: true),
      Finish('rounded'),
    ],
  ),

  // ── More open play ────────────────────────────────────────────────────────
  CutawaySequence(
    id: 'byline_square',
    weight: 1.2,
    play: [
      Start((p: 0.60, q: 0.16)),
      Dribble((p: 1.00, q: 0.10), beats: true),
      Pass((p: 0.99, q: 0.50), kind: 'cutback', run: (p: 0.80, q: 0.44)),
      Finish('placed', firstTime: true),
    ],
  ),
  CutawaySequence(
    id: 'long_ball_flick',
    weight: 1.0,
    play: [
      Start((p: 0.14, q: 0.50)),
      Pass((p: 0.66, q: 0.46), kind: 'lofted', run: (p: 0.50, q: 0.42)),
      Pass((p: 0.86, q: 0.58), run: (p: 0.62, q: 0.66), firstTime: true),
      Finish('volley'),
    ],
  ),
  CutawaySequence(
    id: 'wing_one_two',
    weight: 1.1,
    play: [
      Start((p: 0.50, q: 0.82)),
      Pass((p: 0.66, q: 0.90), run: (p: 0.56, q: 0.94)),
      Pass((p: 0.86, q: 0.80), kind: 'through', who: 0, firstTime: true),
      Pass((p: 0.93, q: 0.48), kind: 'cutback', run: (p: 0.74, q: 0.52)),
      Finish('placed', firstTime: true),
    ],
  ),
  CutawaySequence(
    id: 'cut_in_curler',
    weight: 1.2,
    play: [
      Start((p: 0.52, q: 0.88)),
      Dribble((p: 0.72, q: 0.70), beats: true),
      Dribble((p: 0.82, q: 0.62)),
      Finish('longshot'),
    ],
  ),
  CutawaySequence(
    id: 'cross_knockdown',
    weight: 1.0,
    play: [
      Start((p: 0.50, q: 0.14)),
      Pass((p: 0.92, q: 0.34), kind: 'cross', run: (p: 0.68, q: 0.30)),
      Pass((p: 0.93, q: 0.58), run: (p: 0.80, q: 0.64), firstTime: true),
      Finish('placed', firstTime: true),
    ],
  ),
  CutawaySequence(
    id: 'run_from_deep',
    weight: 0.9,
    play: [
      Start((p: 0.18, q: 0.54)),
      Dribble((p: 0.42, q: 0.48)),
      Dribble((p: 0.62, q: 0.56), beats: true),
      Dribble((p: 0.78, q: 0.50), beats: true),
      Finish('placed'),
    ],
  ),
  CutawaySequence(
    id: 'switch_far_post',
    weight: 1.0,
    play: [
      Start((p: 0.48, q: 0.84)),
      Pass((p: 0.68, q: 0.12), kind: 'lofted', run: (p: 0.54, q: 0.08)),
      Pass((p: 0.94, q: 0.62), kind: 'cross', run: (p: 0.70, q: 0.56)),
      Finish('volley'),
    ],
  ),
  CutawaySequence(
    id: 'hold_up_layoff',
    weight: 1.0,
    play: [
      Start((p: 0.44, q: 0.60)),
      Pass((p: 0.78, q: 0.50)),
      Pass((p: 0.70, q: 0.64), run: (p: 0.56, q: 0.68), firstTime: true),
      Finish('longshot', firstTime: true),
    ],
  ),

  // ── Six more, asked for from the couch: dribbling, heading, volleying. ─────
  //
  // **The shape of the twenty-nine above is the brief for these.** Nearly all
  // of them are three or four beats ending in a shot from about the same
  // distance, so a run of clips reads as one passage with the numbers moved
  // about. What each of these adds is a MOMENT the set had none of: a nutmeg
  // and a shot on the turn, a header back across goal from a corner, a scissor
  // volley from the edge, a keeper's throw breaking three men clear, a byline
  // rabona-angle cutback met on the half-volley, and a defender striding out of
  // his own half with nobody willing to close him.
  //
  // Added to `SEQUENCES` in `ChanceCutaway.js` in the same commit, because the
  // JS is the spec and a passage that exists on one side only is the drift this
  // repo's fixtures exist to catch.

  // Beaten twice in the same three yards, then a shot on the turn.
  CutawaySequence(
    id: 'nutmeg_turn',
    weight: 1.1,
    play: [
      Start((p: 0.46, q: 0.36)),
      Dribble((p: 0.62, q: 0.40), beats: true),
      Dribble((p: 0.74, q: 0.44), beats: true),
      Dribble((p: 0.80, q: 0.52), beats: true),
      Finish('placed'),
    ],
  ),
  // A corner: hung to the back post, headed BACK across the six-yard box and
  // nodded in. Two headers, which nothing else here has.
  CutawaySequence(
    id: 'corner_back_post',
    weight: 1.3,
    play: [
      Start((p: 1.02, q: 0.98)),
      Pass((p: 0.95, q: 0.14), kind: 'cross', run: (p: 0.86, q: 0.20)),
      Pass((p: 0.965, q: 0.48), kind: 'lofted', run: (p: 0.90, q: 0.40),
          firstTime: true),
      Finish('header', firstTime: true),
    ],
  ),
  // Half-cleared to the edge and hit back through the crowd on the volley.
  CutawaySequence(
    id: 'edge_scissor_volley',
    weight: 1.1,
    play: [
      Start((p: 0.88, q: 0.30)),
      Pass((p: 0.66, q: 0.50), kind: 'lofted', run: (p: 0.60, q: 0.46)),
      Finish('volley', firstTime: true),
    ],
  ),
  // The keeper's throw, three passes, and it is a two-on-one before they have
  // turned round. The longest passage in the set, on purpose: it is the one
  // that reads as a BREAK rather than as a move.
  CutawaySequence(
    id: 'keeper_throw_break',
    weight: 1.0,
    play: [
      Start((p: 0.06, q: 0.50)),
      Pass((p: 0.30, q: 0.80), kind: 'through', run: (p: 0.16, q: 0.86)),
      Dribble((p: 0.64, q: 0.86)),
      Pass((p: 0.86, q: 0.58), kind: 'cutback', run: (p: 0.58, q: 0.52)),
      Finish('oneonone'),
    ],
  ),
  // To the byline the hard way, cut back off the deck and met on the drop.
  CutawaySequence(
    id: 'byline_half_volley',
    weight: 1.2,
    play: [
      Start((p: 0.58, q: 0.16)),
      Dribble((p: 0.86, q: 0.05), beats: true),
      Dribble((p: 1.00, q: 0.08)),
      Pass((p: 0.90, q: 0.52), kind: 'cutback', run: (p: 0.70, q: 0.46)),
      Finish('volley', firstTime: true),
    ],
  ),
  // A centre-half walks it out of his own half because nobody will go to him,
  // and hits it from thirty. The one passage that starts behind the halfway
  // line with the ball at somebody's feet.
  CutawaySequence(
    id: 'defender_stride_out',
    weight: 0.9,
    play: [
      Start((p: 0.10, q: 0.44)),
      Dribble((p: 0.34, q: 0.46)),
      Dribble((p: 0.56, q: 0.50)),
      Dribble((p: 0.70, q: 0.52), beats: true),
      Finish('longshot'),
    ],
  ),
];

/// Pick a passage, weighted.
///
/// [roll] is a 0..1 draw, taken by the caller so the choice is seeded with the
/// rest of the clip — the same seed has to replay the same chance.
CutawaySequence pickSequence(
  double roll, {
  bool Function(CutawaySequence)? where,
}) {
  final pool = [
    for (final s in cutawaySequences)
      if (where == null || where(s)) s,
  ];
  final usable = pool.isEmpty ? cutawaySequences : pool;
  final total = usable.fold<double>(0, (sum, s) => sum + s.weight);
  var cursor = roll.clamp(0.0, 0.999999) * total;
  for (final s in usable) {
    cursor -= s.weight;
    if (cursor < 0) return s;
  }
  return usable.last;
}
