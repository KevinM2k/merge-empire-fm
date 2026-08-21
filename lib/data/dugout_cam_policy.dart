/// WHEN the dugout cam cuts in, and WHAT he does when it does. Ported from
/// `ui/components/dugoutCamPolicy.js`.
///
/// The cam exists to put the manager's look and his EMOTES in front of the
/// player: both only ever appeared on the League diorama, at a size where a hat
/// is four pixels and a fist pump is a smudge. So the rules below are mostly
/// about restraint — a reaction shot on every goal of a 5-3 game stops being a
/// reaction and becomes furniture, and the match view is already carrying a
/// cutaway, a coach bubble, a quest banner and a subs panel.
///
/// **It is here rather than under `ui/` because it draws nothing.** Every
/// question the camera has to answer before it may mount is arithmetic over the
/// scoreline, the clock and the save, and that is the half worth pinning
/// against the JS — see `test/fixtures/dugout_cam_reference.json`. The widget
/// that acts on the answers is `ui/screens/match/dugout_cam.dart`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/manager_mood.dart';

final math.Random _rng = math.Random();

/// Mirrors JS `Math.random()`, as `manager_mood.dart` does. The camera is
/// decoration; nothing about a match depends on it.
double _defaultRand() => _rng.nextDouble();

/// Game-minutes between two goal cut-ins. Roughly the cutaway's own gap — a
/// goal inside this window still scores, it just doesn't get the camera.
const int camGapMinutes = 12;

/// Hard ceiling on goal cut-ins per match. A 6-3 thriller would otherwise be
/// nine of these; full time is exempt and doesn't count against it.
const int camMaxGoalCuts = 3;

/// What can bring the camera up. A [String] rather than an enum because these
/// are the JS's own trigger names and they cross into the settings map below.
enum CamTrigger {
  goalFor('goal_for'),
  goalAgainst('goal_against'),
  fullTime('full_time');

  const CamTrigger(this.id);

  final String id;
}

/// How long a floating cut-in is on screen: the entry transition (which the
/// widget's own animation has to match), the gesture, a beat to let the pose
/// land, then the exit. The widget reads these rather than keeping its own copy
/// — [camFitsBeforeFullTime] has to know the real number.
const Duration camIn = Duration(milliseconds: 220);
const Duration camHold = Duration(milliseconds: 900);
const Duration camOut = Duration(milliseconds: 200);

/// The whole window, gesture included.
Duration camWindow([Duration gesture = Duration.zero]) =>
    camIn + gesture + camHold + camOut;

/// Has a goal cut-in got time to finish before the whistle?
///
/// A goal in the 88th starts a window that is still on screen when the summary
/// arrives underneath it — two managers at once, and the one that matters is
/// the full-time shot. Rather than have the whistle interrupt a celebration
/// mid-pose, the late goal simply doesn't get the camera: the reaction it would
/// have shown is about to be replaced by a better one about the same goal.
///
/// [toFullTime] is REAL time, not game minutes — the clock's pace is a speed
/// setting, so the same 88th minute is twice as close at 2×. Pauses (a cutaway,
/// the subs panel) only ever push full time further out, so this errs toward
/// dropping a cut-in that would have fitted, never toward one that won't.
bool camFitsBeforeFullTime(Duration gesture, Duration? toFullTime) =>
    toFullTime == null || camWindow(gesture) <= toFullTime;

/// Which saved toggle governs a trigger, or null for one that is never gated.
///
/// The cam deliberately has NO setting of its own: someone who turned the 2D
/// cutaways off wants a quicker, quieter match, and a third switch in that menu
/// is a worse answer than reading the two that already say what they want. Full
/// time is always allowed — it's one shot, at the end, and it's the payoff the
/// whole feature is for.
String? camSettingKey(CamTrigger trigger) => switch (trigger) {
  CamTrigger.goalFor => 'cutawayOurTeam',
  CamTrigger.goalAgainst => 'cutawayOpponent',
  CamTrigger.fullTime => null,
};

/// Should the camera cut in?
///
/// **The ORDER of these refusals is load-bearing.** Reduced motion beats the
/// settings, the settings beat the full-time exemption, and the budget beats
/// the gap — a policy with the right rules in the wrong order agrees on most
/// inputs and then drops the one shot the feature exists for.
///
/// [minute] is the game-minute of the moment, [lastCutMinute] the minute of the
/// last cut-in, [goalCuts] how many goal cut-ins this match has spent, and
/// [reducedFx] the "keep it calm" gate.
bool shouldCutIn({
  required CamTrigger trigger,
  int minute = 0,
  int? lastCutMinute,
  int goalCuts = 0,
  Map<String, dynamic> settings = const {},
  bool reducedFx = false,
}) {
  if (reducedFx) return false;
  final key = camSettingKey(trigger);
  if (key != null && settings[key] == false) return false;
  if (trigger == CamTrigger.fullTime) return true;
  if (goalCuts >= camMaxGoalCuts) return false;
  if (lastCutMinute != null && minute - lastCutMinute < camGapMinutes) {
    return false;
  }
  return true;
}

/// How near the end a goal has to be to count as late drama.
const int lateWinnerMinutes = 5;

/// Did that goal WIN it, late?
///
/// Ours, inside the last few minutes, and it put us in front from level —
/// margin exactly +1 after it means the score before it was level. A late
/// equaliser is relief rather than elation and a fourth goal in a 4-0 isn't
/// drama, so neither qualifies.
bool isLateWinner({
  int minute = 0,
  int duration = 90,
  int ourGoals = 0,
  int theirGoals = 0,
}) => minute >= duration - lateWinnerMinutes && ourGoals - theirGoals == 1;

/// How he's feeling AT THIS MOMENT of the match — not how the save says he
/// feels, which is still describing the last match until this one is stored.
///
/// Full time runs the final score through [moodForScore], the same function the
/// diorama uses, so the face on the whistle and the walk on the League tab a
/// second later agree. The two goal moments are read live off the scoreline the
/// goal just made: going 3-1 up is a different feeling from pulling one back at
/// 1-3, and the cam would be worthless if both got the same fist pump.
///
/// [ratingGap], [isHome], [led] and [trailed] only reach a DRAW, where the
/// score on its own says nothing about how the night went.
Mood camMood({
  required CamTrigger trigger,
  int ourGoals = 0,
  int theirGoals = 0,
  num trophiesEarned = 0,
  bool lateWinner = false,
  num ratingGap = 0,
  bool? isHome,
  bool led = false,
  bool trailed = false,
}) {
  final margin = ourGoals - theirGoals;
  // A goal that wins it in the last few minutes is the loudest a touchline
  // gets, and the scoreline alone cannot see it: 1-0 is a modest margin however
  // it was got, so both the goal and the whistle would otherwise read
  // "pleased" for the most euphoric thing that happens in a football match. It
  // carries through to full time on purpose — the whistle is where the rush
  // actually lands, and by then the score is just 1-0 again.
  if (lateWinner && margin > 0) return Mood.elated;
  return switch (trigger) {
    CamTrigger.fullTime => moodForScore(
      margin,
      won: margin > 0,
      drawn: margin == 0,
      trophiesEarned: trophiesEarned,
      ratingGap: ratingGap,
      isHome: isHome,
      led: led,
      trailed: trailed,
    ),
    CamTrigger.goalFor => margin >= 2 ? Mood.elated : Mood.pleased,
    CamTrigger.goalAgainst => margin <= -2 ? Mood.crushed : Mood.glum,
  };
}

/// The gesture he plays into the lens, or null for "he just stands there and
/// his face does the work" — which is a real outcome, not a failure:
/// [pickGesture] only rolls emotes the player OWNS, and that ownership being
/// visible is the entire point of putting him on camera.
///
/// [fullTime] drops the gestures that are about a game still being played — a
/// man checking how long is left, ten seconds after the whistle.
Gesture? camGesture(
  Mood mood, [
  double Function()? rand,
  Map<String, dynamic>? state,
  bool fullTime = false,
]) => pickGesture(mood, rand, state, (fullTime: fullTime, exclude: const []));

/// Gap between gestures while the cam STAYS UP — i.e. the full-time shot, which
/// lives as long as the result does. One gesture and then a statue was the old
/// behaviour, and it read as a man who had finished reacting.
///
/// The tempo IS the reading. A beaten manager should look like he can't settle:
/// head in hands, then hands on hips, then arms folded, one after another with
/// barely a breath between them. A happy one gets a long enough gap that his
/// celebration stays an event rather than a twitch — the same restraint
/// [gestureGapMs] exists for on the diorama, but on a shot the player looks at
/// for seconds rather than minutes, so every number here is shorter.
const Map<Mood, (int, int)> camRotaGapMs = {
  Mood.elated: (2600, 4600),
  Mood.pleased: (3200, 5600),
  Mood.neutral: (4000, 7000),
  Mood.glum: (1300, 2400),
  Mood.crushed: (1000, 2000),
};

/// How many of his last gestures the rota refuses to repeat. TWO, not one:
/// avoiding only the previous one leaves A-B-A-B, which is a loop with an extra
/// step in it — and the moods this matters most for have a pool dominated by
/// exactly two poses, so that is what it actually produced.
const int camRotaMemory = 2;

/// One beat of the rota: what he does next, and how long after the last one.
///
/// [recent] is what he has just done, newest first, and is avoided while the
/// mood has anything else to offer — "on repeat" should read as a man running
/// out of ways to be unhappy, not as one animation cycling. A mood with fewer
/// gestures than the memory falls back to repeating rather than standing still.
///
/// A null [CamRotaBeat.gesture] means the mood has nothing the player owns; the
/// caller then leaves him standing, which is the pre-rota behaviour.
({Gesture? gesture, Duration gap}) camRotaBeat(
  Mood mood, [
  double Function()? rand,
  Map<String, dynamic>? state,
  List<String> recent = const [],
]) {
  final (lo, hi) = camRotaGapMs[mood] ?? camRotaGapMs[Mood.neutral]!;
  final exclude = recent.take(camRotaMemory).toList();
  // **TWO DRAWS, in this order** — the gesture first and the gap second, which
  // is the JS's order and therefore the one the fixture was taken in. Reading
  // the gap first would give a different rota from the same seed.
  final gesture = pickGesture(mood, rand, state, (
    fullTime: true,
    exclude: exclude,
  ));
  final roll = (rand ?? _defaultRand)();
  return (
    gesture: gesture,
    // Microseconds rather than whole milliseconds: the JS's `lo + rand() * (hi
    // - lo)` is a float, and rounding it into a millisecond here would be the
    // one place the port quietly disagreed with the number the fixture holds.
    gap: Duration(microseconds: ((lo + roll * (hi - lo)) * 1000).round()),
  );
}
