/// How the manager on the League diorama is FEELING, and what he does about it.
/// Ported from `../merge-empire-fc/src/data/managerMood.js`.
///
/// The walker used to be pure decoration: same tempo, same idle swing, whatever
/// had just happened on the pitch. This derives a mood from the club's results
/// and picks the touchline gestures that go with it — a fist pump after a
/// thrashing, arms folded when it is going badly, hands on head after a hiding.
///
/// Pure derivation, no UI: the scene puts the mood on the walker and the League
/// screen runs the gesture scheduler. Keeping it testable matters because the
/// thresholds have to agree with what Coach Colin SAYS about the same result — a
/// manager celebrating a result Colin has just called unacceptable is worse than
/// no reaction at all.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/manager_looks.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

final math.Random _rng = math.Random();

/// Mirrors JS `Math.random()`. The diorama is decoration; nothing about a match
/// depends on it.
double _defaultRand() => _rng.nextDouble();

/// The moods, best to worst. Declaration order is meaningful: the index is a
/// rank.
enum Mood { elated, pleased, neutral, glum, crushed }

/// How long a result keeps driving the mood.
///
/// Inside this window he is still reacting to the last match; outside it he
/// settles back to how the season as a whole is going. Long enough to survive a
/// browse through the other tabs, short enough that a win does not have him
/// beaming for the rest of the day.
const int freshMs = 8 * 60 * 1000;

// Margin thresholds, kept identical to the ones the match popup uses to choose
// Colin's post-match line, so the walker's body language and the coach's words
// always describe the same match.
const int _bigWinMargin = 3; // won by 3+ — a thrashing
const int _narrowMargin = 1; // lost by 1 — gutting, but close

// ── How good a DRAW was ─────────────────────────────────────────────────────
//
// A draw is the one result whose scoreline tells you nothing. A point away at
// the runaway leaders is a night out; the same point at home against the side
// bottom of the table is an inquest. Reading both as "neutral" is what let the
// robot dance play after being pegged back in the 90th.
//
// So a draw is scored on an EDGE: how much the point was against you. It is
// deliberately built out of the few things both callers can know — the cam
// mid-match and the diorama off a stored result — and every part is optional, so
// a save with none of it lands back on plain neutral, which is what draws did
// before this existed.

/// Matching the match engine's +3 home advantage: a point away is worth more
/// than the same point at home.
const int _drawHomeEdge = 3;

/// Led and got pegged back, or trailed and pulled it back.
const int _drawSwing = 5;

/// At or above this he will take it, and may celebrate.
const int _drawGood = 7;

/// At or below this it is two points dropped.
const int _drawBad = -7;

/// The mood for a DRAW, from the context around the scoreline.
///
/// [ratingGap] is theirs minus ours in squad rating, so positive means they were
/// the better side. [led] and [trailed] together cancel out on purpose — a 3-3
/// that swung both ways is a night at the football, not a grievance.
Mood moodForDraw({
  num ratingGap = 0,
  bool? isHome,
  bool led = false,
  bool trailed = false,
}) {
  var edge = ratingGap.isFinite ? ratingGap : 0;
  if (isHome == true) edge -= _drawHomeEdge;
  if (isHome == false) edge += _drawHomeEdge;
  if (led && !trailed) edge -= _drawSwing;
  if (trailed && !led) edge += _drawSwing;
  if (edge >= _drawGood) return Mood.pleased;
  if (edge <= _drawBad) return Mood.glum;
  return Mood.neutral;
}

final RegExp _scorePattern = RegExp(r'^(\d+)[–-](\d+)$');

/// The goal margin — ours minus theirs — for a stored result, or null when it
/// cannot be read.
///
/// Prefers the raw goal counts and falls back to parsing the display score,
/// which uses an en-dash and is home-team first, so it needs the home flag.
int? _marginOf(Map<String, dynamic>? r) {
  final ours = _num(r?['ourGoals']);
  final theirs = _num(r?['theirGoals']);
  if (ours != null && theirs != null) return (ours - theirs).toInt();
  final m = _scorePattern.firstMatch('${r?['score'] ?? ''}');
  if (m == null) return null;
  final home = int.parse(m.group(1)!);
  final away = int.parse(m.group(2)!);
  return r?['isHome'] == true ? home - away : away - home;
}

/// The mood from a SCORELINE.
///
/// Public because the dugout cam reads a match that has not been stored yet:
/// mid-match there is no last result to derive from, and reading the stored one
/// would have him reacting to the PREVIOUS game. Both callers come through here,
/// so the face at full time and the walker on the diorama an instant later can
/// never disagree.
///
/// [margin] is ours minus theirs, and null when it cannot be read. Everything
/// past [trophiesEarned] is DRAW context and is ignored by the win and loss
/// branches — it is all optional, and passing none of it makes a draw neutral,
/// exactly as it always was.
Mood moodForScore(
  int? margin, {
  bool won = false,
  bool drawn = false,
  num trophiesEarned = 0,
  num ratingGap = 0,
  bool? isHome,
  bool led = false,
  bool trailed = false,
}) {
  if (won) {
    // Silverware trumps the scoreline.
    if (trophiesEarned > 0) return Mood.elated;
    return margin != null && margin >= _bigWinMargin
        ? Mood.elated
        : Mood.pleased;
  }
  if (drawn) {
    return moodForDraw(
      ratingGap: ratingGap,
      isHome: isHome,
      led: led,
      trailed: trailed,
    );
  }
  if (margin != null && margin >= -_narrowMargin) return Mood.glum;
  return Mood.crushed;
}

/// The mood from one just-played result.
///
/// A stored result carries the draw context, so the diorama's walker and the
/// dugout cam's full-time shot — a second apart — read the same draw the same
/// way.
Mood _moodForResult(Map<String, dynamic> r) => moodForScore(
  _marginOf(r),
  won: r['won'] == true,
  drawn: r['drawn'] == true,
  trophiesEarned: _num(r['trophiesEarned']) ?? 0,
  ratingGap: _num(r['ratingGap']) ?? 0,
  isHome: r['isHome'] is bool ? r['isHome'] as bool : null,
  led: r['led'] == true,
  trailed: r['trailed'] == true,
);

/// The baseline mood from how the season is going, for when no result is fresh.
///
/// Points per game against the three-point maximum: title form lifts him, a
/// relegation season grinds him down.
Mood _moodForSeason(Map<String, dynamic>? p) {
  final w = _num(p?['seasonWins']) ?? 0;
  final d = _num(p?['seasonDraws']) ?? 0;
  final l = _num(p?['seasonLosses']) ?? 0;
  final played = w + d + l;
  // Too early to read anything into it.
  if (played < 3) return Mood.neutral;
  final rate = (w * 3 + d) / (played * 3);
  if (rate >= 0.70) return Mood.pleased;
  if (rate <= 0.28) return Mood.glum;
  return Mood.neutral;
}

/// The manager's current mood.
///
/// `fresh` is true while he is still reacting to the last match rather than to
/// the season as a whole.
({Mood mood, bool fresh}) deriveMood(Map<String, dynamic>? state, int nowMs) {
  final p = _map(state?['progression']);
  final r = _map(p?['lastMatchResult']);
  final playedAt = (_num(r?['playedAt']) ?? _num(p?['lastMatchAt']) ?? 0)
      .toInt();
  if (r != null && playedAt != 0 && nowMs - playedAt <= freshMs) {
    return (mood: _moodForResult(r), fresh: true);
  }
  return (mood: _moodForSeason(p), fresh: false);
}

// ── Gestures ────────────────────────────────────────────────────────────────
//
// One-shot arm animations played over the walk cycle — he never stops walking,
// because the scene is an endless runner. Each has a duration matching its
// keyframes and a per-mood weight; a missing weight means that mood never plays
// it, which is the point: only a manager who is doing well punches the air, and
// only one who is not holds his head.
//
// The first seven are what every manager does. The rest come from look packs and
// are the one cosmetic with no slot to equip: OWNING an emote is what puts it in
// this rota, so an unlocked pack changes what he DOES on the touchline rather
// than what he is wearing. Their weights are deliberately lower than the free
// ones — a bought emote that played constantly would crowd out the mood reading
// the rota exists for.

/// One touchline gesture.
class Gesture {
  const Gesture({
    required this.id,
    required this.ms,
    required this.weight,
    this.stops = false,
    this.fullTime = true,
    this.celebration = false,
  });

  final String id;
  final int ms;
  final Map<Mood, int> weight;

  /// He PLANTS HIS FEET for it.
  ///
  /// He walks in place and the scene scrolls past him, so a gesture that stops
  /// the stride has to stop the scroll with it — otherwise the world keeps
  /// sliding past a man standing still, which is the one thing that gives the
  /// whole trick away. This flag is the only place that fact lives.
  final bool stops;

  /// False when the gesture makes no SENSE once the whistle has gone, whatever
  /// the mood — checking your watch is a question about how long is left, and
  /// the answer at full time is "none". A separate axis from the weights: a
  /// gesture can be perfectly good at 0-2 down in the 70th and absurd ten
  /// minutes later.
  final bool fullTime;

  /// Unambiguously CELEBRATING — dancing, bowing, kissing the badge, shushing
  /// the away end.
  ///
  /// These may only carry `elated` and `pleased` weights, and a test enforces
  /// it. The rule exists because the robot dance had a neutral weight and so
  /// played after a 2-2 in which we had been pegged back in the 90th: three
  /// actions' worth of joy for a result the manager was sick about. If a draw
  /// genuinely deserves a celebration, the DRAW ITSELF is scored `pleased` and
  /// these come back — which is the right way round, because then the mood, the
  /// face and the frame agree with the dance instead of contradicting it.
  final bool celebration;
}

const List<Gesture> gestures = [
  Gesture(
    id: 'fistpump',
    ms: 1500,
    weight: {Mood.elated: 6, Mood.pleased: 2},
    celebration: true,
  ),
  Gesture(
    id: 'applaud',
    ms: 1900,
    weight: {Mood.elated: 4, Mood.pleased: 5, Mood.neutral: 2},
  ),
  Gesture(
    id: 'point',
    ms: 1700,
    weight: {
      Mood.elated: 2,
      Mood.pleased: 3,
      Mood.neutral: 4,
      Mood.glum: 3,
      Mood.crushed: 1,
    },
  ),
  Gesture(
    id: 'checkwatch',
    ms: 1800,
    weight: {Mood.pleased: 2, Mood.neutral: 3, Mood.glum: 3, Mood.crushed: 2},
    fullTime: false,
  ),
  Gesture(
    id: 'armsfolded',
    ms: 2800,
    weight: {Mood.neutral: 3, Mood.glum: 5, Mood.crushed: 4},
  ),
  Gesture(
    id: 'handsonhips',
    ms: 2400,
    weight: {Mood.neutral: 2, Mood.glum: 5, Mood.crushed: 4},
  ),
  Gesture(id: 'handsonhead', ms: 2100, weight: {Mood.glum: 2, Mood.crushed: 6}),
  // ── Look-pack emotes ──
  Gesture(
    id: 'wave',
    ms: 1900,
    weight: {Mood.elated: 2, Mood.pleased: 3, Mood.neutral: 2},
  ),
  Gesture(
    id: 'blowkiss',
    ms: 2000,
    weight: {Mood.elated: 3, Mood.pleased: 2},
    celebration: true,
  ),
  Gesture(
    id: 'badgekiss',
    ms: 1800,
    weight: {Mood.elated: 3, Mood.pleased: 2},
    celebration: true,
  ),
  Gesture(
    id: 'shush',
    ms: 1900,
    weight: {Mood.elated: 4, Mood.pleased: 1},
    celebration: true,
  ),
  Gesture(
    id: 'salute',
    ms: 1700,
    weight: {Mood.elated: 2, Mood.pleased: 2, Mood.neutral: 2},
  ),
  Gesture(
    id: 'bow',
    ms: 2200,
    weight: {Mood.elated: 3, Mood.pleased: 2},
    stops: true,
    celebration: true,
  ),
  Gesture(
    id: 'robot',
    ms: 2400,
    weight: {Mood.elated: 3, Mood.pleased: 2},
    celebration: true,
  ),
  Gesture(
    id: 'fingerwag',
    ms: 1900,
    weight: {Mood.neutral: 2, Mood.glum: 3, Mood.crushed: 2},
  ),
  Gesture(id: 'facepalm', ms: 2100, weight: {Mood.glum: 3, Mood.crushed: 4}),
];

final List<String> gestureIds = [for (final g in gestures) g.id];

Gesture? getGesture(String? id) {
  for (final g in gestures) {
    if (g.id == id) return g;
  }
  return null;
}

/// The gap between gestures, low to high, in milliseconds.
///
/// A happy manager is a busy one; a beaten one is busy in a different way, head
/// in hands. It is the mid-table shrug that should be quietest, or the scene
/// turns into a fidget.
const Map<Mood, (int, int)> gestureGapMs = {
  Mood.elated: (3200, 8000),
  Mood.pleased: (5000, 11000),
  Mood.neutral: (8000, 16000),
  Mood.glum: (6000, 13000),
  Mood.crushed: (4500, 10000),
};

/// A random gap before the next gesture for a mood.
double nextGestureDelay(Mood mood, [double Function()? rand]) {
  final range = gestureGapMs[mood] ?? gestureGapMs[Mood.neutral]!;
  return range.$1 + (rand ?? _defaultRand)() * (range.$2 - range.$1);
}

/// A weighted pick of a gesture for a mood, or null when the mood has no
/// gestures at all — callers must handle "he just walks".
///
/// Pass [state] to roll only from the emotes the player owns. The free gestures
/// are ungated, so a save owning no packs behaves exactly as it did before
/// emotes existed; omit it for an unrestricted roll.
///
/// [fullTime] drops the gestures that only make sense while there is still a
/// game to play.
///
/// [exclude] is a list of ids the caller has just used, for a rota that has to
/// keep moving. It is a FILTER rather than a reroll because the weights are
/// lopsided — a crushed manager's pool is mostly two gestures, and rerolling
/// until one of them is not picked lands back on them often enough to read as a
/// loop. Ignored when it would leave nothing: with two owned gestures and a
/// memory of two, alternating is the only thing left.
Gesture? pickGesture(
  Mood mood, [
  double Function()? rand,
  Map<String, dynamic>? state,
  ({bool fullTime, List<String> exclude}) opts = (
    fullTime: false,
    exclude: const [],
  ),
]) {
  final eligible = [
    for (final g in gestures)
      if ((g.weight[mood] ?? 0) > 0 &&
          !(opts.fullTime && !g.fullTime) &&
          (state == null || isLookUnlocked(state, 'emote', g.id)))
        g,
  ];
  final fresh = [
    for (final g in eligible)
      if (!opts.exclude.contains(g.id)) g,
  ];
  final pool = fresh.isNotEmpty ? fresh : eligible;
  if (pool.isEmpty) return null;
  final total = pool.fold<int>(0, (n, g) => n + g.weight[mood]!);
  var roll = (rand ?? _defaultRand)() * total;
  for (final g in pool) {
    roll -= g.weight[mood]!;
    if (roll < 0) return g;
  }
  return pool.last;
}

// ── What he does with the ball ──────────────────────────────────────────────
//
// Picked each time a stray ball reaches his feet. Mood tilts it: on a good day
// he will volley one back or boot it into the stand, on a bad day he is more
// likely to pick it up flatly or let it run past him entirely.

const List<String> ballPlays = ['pass', 'chip', 'clear', 'pickup', 'ignore'];

const Map<Mood, Map<String, int>> _ballPlayWeight = {
  Mood.elated: {'pass': 4, 'chip': 3, 'clear': 3, 'pickup': 2, 'ignore': 0},
  Mood.pleased: {'pass': 5, 'chip': 3, 'clear': 2, 'pickup': 2, 'ignore': 1},
  Mood.neutral: {'pass': 6, 'chip': 2, 'clear': 1, 'pickup': 3, 'ignore': 1},
  Mood.glum: {'pass': 5, 'chip': 1, 'clear': 1, 'pickup': 3, 'ignore': 3},
  Mood.crushed: {'pass': 4, 'chip': 1, 'clear': 1, 'pickup': 3, 'ignore': 4},
};

/// A weighted pick of what he does with an arriving ball.
String pickBallPlay(Mood mood, [double Function()? rand]) {
  final w = _ballPlayWeight[mood] ?? _ballPlayWeight[Mood.neutral]!;
  final total = ballPlays.fold<int>(0, (n, id) => n + (w[id] ?? 0));
  var roll = (rand ?? _defaultRand)() * total;
  for (final id in ballPlays) {
    roll -= w[id] ?? 0;
    if (roll < 0) return id;
  }
  return 'pass';
}
