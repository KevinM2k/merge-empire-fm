/// The clock that plays a finished match out.
///
/// `simulateMatch` decides the whole ninety minutes up front — every goal, every
/// injury, every line of commentary, with its own seeded draws. Nothing here may
/// change any of it: this is a PLAYBACK, and the only thing it owns is when each
/// already-decided event appears on screen.
///
/// Keeping the two apart is what lets the differential harness prove the match
/// engine against the JS without a widget anywhere near it.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

// The engine's own pool table, so the opening filler and the events it is
// filling around cannot disagree about how many lines the bucket holds. Pure
// Dart, like this file: nothing here reaches for Flutter.
import 'package:merge_empire_fc/engine/match_events.dart' show commentaryPools;

/// One thing that happened, ready to show.
typedef TimelineEvent = ({
  int minute,
  String type,
  String? team,
  String? scorer,

  /// WHICH card scored, by instance id. The name is what gets printed; this is
  /// what a face can be resolved from, and the engine has always written it —
  /// `finalizeMatchOutcome` attributes career goals by it.
  String? scorerId,
  String? textKey,

  /// `on_target` or `off`, on a chance. The 2D cutaway needs it — it is the
  /// difference between a save and a miss — and so does the feed, which only
  /// surfaces a chance that was actually on target.
  String? shotResult,

  /// A big chance. The engine marks one at xG 0.22 and the JS's feed re-checks
  /// at 0.30, which is why both travel.
  bool big,
  double xg,

  /// Who went down, on an injury.
  String? player,
});

/// The name to force onto the shooter's dot for a clip, or null for no name.
///
/// **LIVE, THEN THE NAME THE RESULT RECORDED — and the fallback was missing.**
/// The feed and the full-time scorers card have both resolved a scorer this way
/// since the snapshot bug was fixed: ask the save what the card is called now,
/// and if the card is gone, print what it was called when it scored, because a
/// player who has since been sold still scored. The two cutaway call sites had
/// only the live half, so a sold scorer resolved to null, the shooter's dot was
/// never forced to his name, and the pitch put a generic lineup name on the man
/// the feed directly above it had just named. Reported as the commentary and
/// the replay needing to be the same player, and it was the one half of that
/// row that could be found by reading after all.
///
/// Pure and shared rather than the same `??` written at two call sites: they
/// are the live cut and the replay OF that cut, and the one thing they must
/// never do is disagree with each other.
String? clipScorerName(
  Map<String, dynamic>? save,
  TimelineEvent event, {
  required bool ours,
  required String? Function(Map<String, dynamic>? save, String id) nameOf,
}) {
  if (!ours || event.type != 'goal') return null;
  return nameOf(save, event.scorerId ?? '') ?? event.scorer;
}

/// The state of a match at some point through it.
///
/// **`team: 'home'` on an event means US, not the home side.** The engine builds
/// the goal list from the result's own `homeGoals`/`awayGoals`, which are ours
/// and theirs — `won` is `homeGoals > awayGoals` with no reference to `isHome`
/// — and it picks the scorer from OUR squad whenever the team is `home`. So the
/// tally here is ours and theirs, and it is named that way: calling it
/// home/away is what put our score under the opponent's name on every away
/// fixture, and played the crowd's disappointment for our goals.
typedef MatchFrame = ({
  int minute,
  int ourGoals,
  int theirGoals,
  List<TimelineEvent> shown,
  bool finished,
});

/// Ninety plus whatever the referee found.
int fullTime(int addedTime) => 90 + (addedTime < 0 ? 0 : addedTime);

List<TimelineEvent> timelineOf(Map<String, dynamic> result) {
  final raw = result['events'];
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e is Map<String, dynamic>)
        (
          minute: (e['minute'] as num?)?.toInt() ?? 0,
          type: e['type'] as String? ?? '',
          team: e['team'] as String?,
          scorer: e['scorer'] as String?,
          scorerId: e['scorerInstanceId'] as String?,
          textKey: e['textKey'] as String?,
          shotResult: e['shotResult'] as String?,
          big: e['big'] == true,
          xg: (e['xg'] as num?)?.toDouble() ?? 0,
          player: e['player'] as String?,
        ),
  ]..sort((a, b) => a.minute.compareTo(b.minute));
}

/// The match as it stood at [minute].
///
/// The score is counted from the goals already SHOWN rather than taken from the
/// result, so the number on screen can never run ahead of the commentary that
/// explains it.
MatchFrame frameAt(
  Map<String, dynamic> result,
  int minute, {
  List<TimelineEvent>? timeline,
}) {
  final events = timeline ?? timelineOf(result);
  final shown = [
    for (final e in events)
      if (e.minute <= minute) e,
  ];
  var ours = 0;
  var theirs = 0;
  for (final e in shown) {
    if (e.type != 'goal') continue;
    if (e.team == 'away') {
      theirs++;
    } else {
      ours++;
    }
  }
  final end = fullTime((result['addedTime'] as num?)?.toInt() ?? 0);
  return (
    minute: minute,
    ourGoals: ours,
    theirGoals: theirs,
    shown: shown,
    finished: minute >= end,
  );
}

/// How long one minute of match time takes on screen.
///
/// Fast mode is the player's own setting, and it halves the wait rather than
/// skipping anything: a match that skips events is a match whose story the
/// player did not get.
///
/// **THE SPEC'S OWN NUMBERS, and the port had been running at a third of a
/// minute.** `MatchPopup.js` ticks one minute per `TICK_MS = 350`, halved to
/// `TICK_MS_FAST = 175` — the port had 120 and 60, so a ninety-minute match
/// went by in eleven seconds and the ×2 was six. Reported as "1× seems to have
/// gone fast and 2× is far too fast". A whole match is about half a minute at
/// these, which is what the commentary was written to be read at.
const int matchMinuteMs = 350;
const int matchMinuteMsFast = 175;

Duration minuteDuration({required bool fast}) =>
    Duration(milliseconds: fast ? matchMinuteMsFast : matchMinuteMs);

// ── The feed ────────────────────────────────────────────────────────────────

/// One line of commentary, ready for `t()`.
/// What a GOAL line carries beyond its sentence.
///
/// A goal in the feed is a CARD, not a row: the minute, the word GOAL, the score
/// it made, the scorer with his face and his tally, and the commentary line
/// under it as the caption it always was. `match.goal_card.title`,
/// `match.career_goal` and `match.career_goals` were translated into all ten
/// catalogues with nothing able to reach one of them.
///
/// [left] and [right] are the score AS THE BOARD SHOWS IT — home side left —
/// so the widget never has to know which way round the fixture is.
///
/// [tallyInMatch] is how many this man has scored TODAY, including this one.
/// The season's total is on his card and the two are added at the point of
/// drawing, because the save is not written until the whistle.
typedef GoalCard = ({int left, int right, int tallyInMatch, bool ours});

typedef FeedLine = ({
  int minute,
  String type,
  String key,
  Map<String, Object?> params,

  /// Several of these keys are POOLS — a goal has nine ways of being described.
  /// The pick has to be stable, because the feed rebuilds on every tick of the
  /// clock and a sentence that rerolls under the reader is worse than one
  /// sentence.
  String seed,

  /// The extras a GOAL is drawn with, or null on every other line.
  GoalCard? goal,

  /// Who the line is ABOUT, by card instance id, when it is about one of ours.
  ///
  /// A goal naming a player, next to the art of the player it names — the
  /// portraits are bundled and `playerImagePath` already resolves them, so what
  /// was missing was the row knowing who it was about rather than holding a
  /// string with his name in it. Null on everything else, including an opponent
  /// goal: the engine picks scorers from OUR squad, and a face for a man the
  /// save has never heard of cannot be drawn.
  String? aboutId,
});

/// How long the feed waits before mentioning another chance, in minutes.
///
/// The JS's own gap, and its reason: a chance every seven minutes is a wall of
/// "forces a save" that nobody reads.
const int chanceFeedGap = 10;

/// The xG at which the FEED calls a chance big.
///
/// **Higher than the engine's own 0.22**, deliberately: the engine's flag marks
/// what the match statistics count as a big chance, and the feed is a stricter
/// filter on top of it — a line for every one of those is still too many.
const double chanceFeedBigXg = 0.30;

/// **THE OPENING IS TOO QUIET, and the engine cannot be what fixes it.**
///
/// `commentaryPools` puts the `open` bucket at [1, 1] and the next one,
/// `firstA`, anywhere in 15..30. So a match says one thing at kick-off and then
/// nothing for between fourteen and twenty-nine minutes. Reported exactly that
/// way — the commentary being too quiet when a game starts and nothing
/// happening for fifteen or twenty minutes.
///
/// **Chances cannot fill it**, which is worth stating because relaxing their
/// filter is the obvious first idea and the arithmetic kills it: there are
/// about thirteen in a match spread over eighty-eight minutes, so fewer than
/// two land before minute fifteen and only half of those are on target. Letting
/// every one of them through buys about one line.
///
/// **And the pool table is not this repo's to move.** It is the JS's, and
/// `match_orchestration_reference.json` pins the events it produces field for
/// field — 363 commentary lines — which cannot be regenerated from a cloud
/// container. So the engine emits exactly what it always emitted and the
/// divergence lives on the SCREEN, which is where this port puts them.
///
/// The `open` pool has THREE lines and a match printed one of them. All three
/// are said now, spread across the window the engine leaves empty. The engine's
/// own seeded pick still leads, so what a match opens with has not changed —
/// what follows it is two lines of atmosphere instead of silence.
const List<int> openingFillMinutes = [6, 11];

/// The bucket those lines come from. Named so the filler and the engine cannot
/// disagree about which pool is being emptied.
const String openFlowPrefix = 'commentary.flow.open.';

/// **WHICH CHANCES THE PLAYER ACTUALLY SEES.**
///
/// There are about thirteen chances in a match and the feed prints three or
/// four of them: a chance earns a line only if it was big AND on target AND far
/// enough from the last one. The SOUND was hung on the event instead, so every
/// one of the thirteen played a kick and every on-target one played the crowd
/// on top of it — nine or ten noises a match with nothing on screen to belong
/// to. Reported as miss noises happening with no action, and the rule the
/// report gives is the right one: if no action, no noise.
///
/// Derived by running the feed rather than by re-stating its rules. The gap
/// filter is stateful across the whole list — it is measured from the last
/// chance that was SHOWN, not the last that happened — so a second copy of that
/// logic would drift the first time either half moved.
Set<int> feedChanceMinutes(
  List<TimelineEvent> events, {
  Map<int, String> clippedChanceKeys = const {},
}) => {
  for (final line in feedOf(
    events,
    // The names only reach a line's parameters, never the filter.
    ourName: '',
    theirName: '',
    isHome: true,
    clippedChanceKeys: clippedChanceKeys,
  ))
    if (line.type == 'chance') line.minute,
};

/// What each event says in the feed, and which say nothing at all.
///
/// **Ported from `_processEvent` in `MatchPopup.js`, and the point is what it
/// LEAVES OUT.** The port fell through to printing `event.type`, so a corner
/// read as the word "corner", a chance as "chance", and full time as
/// "fulltime" — three raw, untranslated strings straight from the engine, on
/// the one screen a player watches for ninety minutes.
///
/// The JS's rules:
///
/// - **A corner gets NO line.** It nudges the momentum bar and that is all it
///   is for; a corner is not news.
/// - **A chance gets one only if it was BIG and ON TARGET**, and only if it has
///   been [chanceFeedGap] minutes since the last one. There is a chance about
///   every seven minutes, so without both filters the feed is nothing else.
/// - **Full time is the screen's own**, not a line in the list.
List<FeedLine> feedOf(
  List<TimelineEvent> events, {
  required String ourName,
  required String theirName,
  required bool isHome,
  /// The commentary key for each chance the 2D pitch has retold, by minute.
  ///
  /// **A retold chance ALWAYS gets a line, and the line says what was shown**
  /// — `_endCutaway` in `MatchPopup.js`. Every chance printed "forces a save"
  /// whatever the clip had just drawn, so the ball went over the bar and the
  /// feed said the keeper had it.
  Map<int, String> clippedChanceKeys = const {},

  /// How the SAVE names a scorer, given his instance id.
  ///
  /// **The feed and the 2D pitch were reading two different names for one
  /// goal.** `event.scorer` is a snapshot taken when the events were generated;
  /// everything the pitch draws — the shooter's own dot in `cutaway_game.dart`,
  /// the replay's badge, the full-time scorers card — resolves the card LIVE
  /// through `cardDisplayName`. Two readings of one question, and they stop
  /// agreeing the moment anything happens to the card between the whistle and
  /// the replay. Reported as the commentary and the replay needing to name the
  /// same man.
  ///
  /// The snapshot stays as the fallback: it is the only name left for a card
  /// the save no longer has, which is exactly the case a live lookup cannot
  /// answer.
  String? Function(String instanceId)? nameOf,
}) {
  final out = <FeedLine>[];
  /// The kick-off pool's other lines, held back until the end so they can be
  /// merged in at the minutes they belong to — see [openingFillMinutes].
  final filled = <FeedLine>[];
  int? lastChance;
  // The score AS THE FEED HAS TOLD IT, which is what decides whether a goal
  // equalised or extended a lead.
  var ours = 0;
  var theirs = 0;
  // How many each man has scored in THIS match so far — the JS's
  // `_matchGoalsByPlayer`, and the reason the tally can be right before the
  // save has heard about the game.
  final today = <String, int>{};
  for (final e in events) {
    switch (e.type) {
      case 'goal':
        // **A GOAL IS DESCRIBED, not just attributed.** The port printed the
        // scorer's name and nothing else, while eight `commentary.goal.*` pools
        // and `commentary.opp_goal` sat translated in ten catalogues with
        // nothing able to reach one.
        //
        // Which pool depends on what the goal DID to the score, and that is the
        // whole point of them: equalising, pulling one back, going ahead and
        // stretching a lead are four different moments and the feed should not
        // read the same for all four.
        final ourGoal = e.team == 'home';
        if (ourGoal) {
          ours += 1;
        } else {
          theirs += 1;
        }
        if (ourGoal) {
          final status = ours == theirs
              ? 'equalise'
              : ours - 1 > theirs
              ? 'extend'
              : ours > theirs
              ? 'lead'
              : 'pullback';
          final id = e.scorerId;
          final scorer = (id == null ? null : nameOf?.call(id)) ?? e.scorer;
          if (id != null) today[id] = (today[id] ?? 0) + 1;
          out.add((
            minute: e.minute,
            type: e.type,
            key:
                'commentary.goal.$status.'
                '${scorer == null || scorer.isEmpty ? 'no_scorer' : 'with_scorer'}',
            params: {'us': ourName, 'scorer': scorer ?? ''},
            seed: '${e.minute}-${scorer ?? ''}',
            goal: (
              left: isHome ? ours : theirs,
              right: isHome ? theirs : ours,
              tallyInMatch: id == null ? 0 : today[id]!,
              ours: true,
            ),
            aboutId: e.scorerId,
          ));
        } else {
          out.add((
            minute: e.minute,
            type: e.type,
            key: 'commentary.opp_goal',
            params: {'them': theirName},
            seed: '${e.minute}-opp',
            goal: (
              left: isHome ? ours : theirs,
              right: isHome ? theirs : ours,
              tallyInMatch: 0,
              ours: false,
            ),
            aboutId: null,
          ));
        }
      case 'halftime':
        out.add((
          minute: e.minute,
          type: e.type,
          key: 'match.half_time',
          params: const {},
          seed: 'ht',
          goal: null,
          aboutId: null,
        ));
      case 'injury':
        out.add((
          minute: e.minute,
          type: e.type,
          key: 'commentary.injury',
          params: {'player': e.player ?? ''},
          seed: '${e.minute}-inj',
          goal: null,
          aboutId: null,
        ));
      case 'commentary':
        if (e.textKey != null) {
          out.add((
            minute: e.minute,
            type: e.type,
            key: e.textKey!,
            params: const {},
            seed: '${e.minute}-c',
            goal: null,
            aboutId: null,
          ));
          // And the rest of the kick-off pool, into the quiet after it. See
          // [openingFillMinutes].
          if (e.textKey!.startsWith(openFlowPrefix)) {
            final pool = commentaryPools.firstWhere(
              (({List<int> range, String bucket, int count}) p) =>
                  p.bucket == 'open',
            );
            final rest = [
              for (var i = 0; i < pool.count; i++) '$openFlowPrefix$i',
            ]..remove(e.textKey);
            for (var i = 0; i < openingFillMinutes.length && i < rest.length; i++) {
              filled.add((
                minute: openingFillMinutes[i],
                type: e.type,
                key: rest[i],
                params: const {},
                seed: '${openingFillMinutes[i]}-c',
                goal: null,
                aboutId: null,
              ));
            }
          }
        }
      case 'chance':
        final shown = clippedChanceKeys[e.minute];
        final big = e.big || e.xg >= chanceFeedBigXg;
        final enoughGap =
            lastChance == null || e.minute - lastChance >= chanceFeedGap;
        if (shown == null &&
            (!big || e.shotResult != 'on_target' || !enoughGap)) {
          continue;
        }
        lastChance = e.minute;
        final mine = (e.team == 'home') == isHome;
        out.add((
          minute: e.minute,
          type: e.type,
          key: shown ?? 'commentary.forces_save',
          params: {'who': mine ? ourName : theirName},
          seed: '${e.minute}-ch',
          goal: null,
          aboutId: null,
        ));
      // A corner is a momentum nudge and full time is the screen's own.
      default:
        continue;
    }
  }
  if (filled.isEmpty) return out;
  // Merged rather than appended, and STABLY: the engine hands its events in
  // minute order and the feed keeps it, so the filler has to fall where its
  // minute puts it. Ties go to the line that was already there — a goal in the
  // sixth minute reads before the atmosphere line that shares it.
  final merged = [
    for (var i = 0; i < out.length; i++) (i, out[i]),
    for (var i = 0; i < filled.length; i++) (out.length + i, filled[i]),
  ]..sort((a, b) {
    final m = a.$2.minute.compareTo(b.$2.minute);
    return m != 0 ? m : a.$1.compareTo(b.$1);
  });
  return [for (final line in merged) line.$2];
}
