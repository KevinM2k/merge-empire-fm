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
import 'package:merge_empire_fc/engine/booking_engine.dart' show cardYellow;
import 'package:merge_empire_fc/util/sorting.dart' show stableSorted;
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

  /// **THE PARAMETERS THAT CAME WITH [textKey], and they were being dropped.**
  ///
  /// Two of the engine's own events write a `textParams` alongside their key —
  /// `commentary.snub` (`{opp}`) and `commentary.opp_sub` (`{opp}`) — and this
  /// record had nowhere to put them, so the feed handed `t()` an empty map. The
  /// snub line is the one that reached a screen: a grudge match opened with the
  /// literal text `{opp} are furious at the snub` in every language that has
  /// one.
  Map<String, Object?> params,

  /// `yellow`, `second_yellow` or `red` on a BOOKING, and null on everything
  /// else — see `booking_engine.dart`. Carried rather than derived because a
  /// second caution and a straight red are different offences and the feed has
  /// to say which.
  String? card,

  /// Which card instance the event is about, when the engine knows. A booking
  /// names one; so does the man who was sent off, which is what the suspension
  /// is written against.
  String? playerId,
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

List<TimelineEvent> timelineOf(
  Map<String, dynamic> result, {
  /// **THE PORT'S OWN EVENTS, merged on the way to the screen.**
  ///
  /// Bookings are not in the spec — nothing there books anybody — and they
  /// cannot travel in the RESULT either: `match_orchestration_parity_test` and
  /// the season difftest compare the result map field for field and the event
  /// array array for array, and forty-six of them failed on the first two
  /// attempts at putting them there. That is the harness being right twice.
  ///
  /// So the engine stays byte-identical to the JS and the referee lives where
  /// every other divergence in this port lives: on the screen. See
  /// `booking_engine.dart` and `MatchScreenState._bookings`.
  List<Map<String, dynamic>> bookings = const [],
}) {
  final raw = result['events'];
  if (raw is! List) return const [];
  return _byMinute([
    for (final e in [...raw, ...bookings])
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
          card: e['card'] as String?,
          playerId: e['playerInstanceId'] as String?,
          params: e['textParams'] is Map
              ? {
                  for (final entry in (e['textParams'] as Map).entries)
                    '${entry.key}': entry.value,
                }
              : const {},
        ),
  ]);
}

/// The events in the order the feed shows them.
///
/// **A STABLE sort, which `List.sort` is not.** Two things can land on the same
/// minute — a booking and a goal, the grudge line and the kick-off line — and
/// an unstable sort is free to put them either way round and to CHANGE ITS MIND
/// between rebuilds, so a pair of lines could swap places while the player was
/// reading them. Reported from the couch: whichever appeared first should stay
/// first. The tie-break is the order they arrived in, which for the merged list
/// is the engine's own events followed by the port's bookings.
List<TimelineEvent> _byMinute(List<TimelineEvent> events) => stableSorted(
  events,
  (TimelineEvent a, TimelineEvent b) => a.minute.compareTo(b.minute),
);

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

  /// `yellow`, `second_yellow` or `red` on a BOOKING row, null on every other.
  /// The row draws the card itself from this, and a second caution must not
  /// look like a straight red — see `booking_engine.dart`.
  String? card,

  /// Which card instance the row is about, when the engine names one.
  String? playerId,

  /// **THE MAN WHO CAME OFF, on a substitution row.** Null on every other line
  /// and on a change that withdrew nobody.
  ///
  /// A substitution is TWO players, and the row carried one: [aboutId] was the
  /// man coming on and the one going off existed only as a name inside the
  /// sentence. So the feed drew a single face and the change read as an
  /// arrival. Reported from the couch against a real commentary feed, which
  /// gives a substitution a block of its own with both men on it — see
  /// `_SwapRow` in `match_screen.dart`, which is what draws them.
  String? offId,
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

/// The flow lines that describe a card the referee did not show.
///
/// See the `commentary` case in [feedOf]. Two entries, both the spec's, and the
/// port cannot edit them out of the pool without moving every later seeded pick
/// in the match.
const Set<String> _claimsABooking = {
  'commentary.flow.firstB.2',
  'commentary.flow.secondB.3',
};

/// The bucket those lines come from. Named so the filler and the engine cannot
/// disagree about which pool is being emptied.
const String openFlowPrefix = 'commentary.flow.open.';

/// Which line of that pool is about the FIRST WHISTLE rather than about the
/// opening period, and so may only ever be said at kick-off.
///
/// `commentary.flow.open.0` is "Kick-off! Both sides finding their feet." The
/// other two are atmosphere — early pressure, a loud crowd — and read correctly
/// at any minute in the window. See [openingFillMinutes].
const int openKickoffIndex = 0;

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

  /// The clock, so nothing can be said before it happens.
  ///
  /// **THE FILLER LINES WERE JUMPING THE CLOCK, and they were the only thing
  /// that could.** Everything else in this list comes from an event that has
  /// already been SHOWN — the caller hands `frame.shown` — but the kick-off
  /// pool's spare lines are minted here at [openingFillMinutes] and merged in
  /// by minute, with nothing to check them against. So a match in its third
  /// minute already had "11' Early pressure from the midfield" on the page, and
  /// a goal in the eighth went in UNDER it. Reported from the couch in exactly
  /// those terms.
  ///
  /// Null means "no clock" — the whole match at once, which is what
  /// [feedChanceMinutes] wants when it derives the chance filter.
  int? minute,
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
            card: null,
            playerId: null,
            offId: null,
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
            card: null,
            playerId: null,
            offId: null,
          ));
        }
      case 'halftime':
        // **THE VERDICT AT THE BREAK, which was three shipped strings nothing
        // could reach.** The line was `match.half_time` — the same key the row's
        // own HEAD prints — so the interval read "45' HALF TIME" over the words
        // "Half Time", the one row in the feed that said its own name twice and
        // nothing else. `_processEvent` in `MatchPopup.js` picks between
        // `commentary.halftime_ahead`, `_behind` and `_level` off the score as
        // the feed has told it, and all three are translated in ten catalogues
        // with no caller in the port.
        out.add((
          minute: e.minute,
          type: e.type,
          key: ours > theirs
              ? 'commentary.halftime_ahead'
              : theirs > ours
              ? 'commentary.halftime_behind'
              : 'commentary.halftime_level',
          // `halftime_level` takes none, and a spare parameter is ignored.
          params: {'us': ourName},
          seed: 'ht',
          goal: null,
          aboutId: null,
          card: null,
          playerId: null,
          offId: null,
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
          card: null,
          playerId: null,
          offId: null,
        ));
      case 'commentary':
        // **AN ATMOSPHERE LINE MAY NOT CLAIM A BOOKING.** Two of the JS's flow
        // pools do — `firstB.2` is "The ref books a midfielder for a late
        // challenge" and `secondB.3` is "Yellow card for time-wasting" — and
        // they were harmless colour for as long as nobody was ever actually
        // booked. The port has a referee now, with real cards drawn beside real
        // names, so those two lines are the feed contradicting itself: a
        // booking with no card, no player and no consequence. Reported from the
        // couch — "it has to be a real yellow card, or just drop that."
        //
        // Dropped at the BOUNDARY rather than in the catalogue. The pools are
        // generated from the spec and the engine picks a line by INDEX, so
        // removing an entry would shift every later pick in the match. The
        // minute simply carries no line, which is what a filtered chance
        // already does.
        if (e.textKey != null && !_claimsABooking.contains(e.textKey)) {
          out.add((
            minute: e.minute,
            type: e.type,
            key: e.textKey!,
            // The engine's own — see [TimelineEvent.params]. Empty on the flow
            // pools, which take none; `{opp}` on the grudge line, which was
            // printing that brace to players.
            params: e.params,
            seed: '${e.minute}-c',
            goal: null,
            aboutId: null,
            card: null,
            playerId: null,
            offId: null,
          ));
          // And the rest of the kick-off pool, into the quiet after it. See
          // [openingFillMinutes].
          if (e.textKey!.startsWith(openFlowPrefix)) {
            final pool = commentaryPools.firstWhere(
              (({List<int> range, String bucket, int count}) p) =>
                  p.bucket == 'open',
            );
            // **THE KICK-OFF LINE IS THE KICK-OFF LINE, and it cannot be
            // moved.** `open.0` is "Kick-off! Both sides finding their feet." —
            // it is about the first whistle rather than about the opening
            // period — and when the engine's seeded pick landed on one of the
            // other two, this offered it as filler and a match printed "6'
            // Kick-off" six minutes in. Reported from the couch. The other two
            // lines are atmosphere and travel fine; the pool is one line
            // shorter than it looks.
            final rest = [
              for (var i = 0; i < pool.count; i++)
                if (i != openKickoffIndex) '$openFlowPrefix$i',
            ]..remove(e.textKey);
            for (var i = 0; i < openingFillMinutes.length && i < rest.length; i++) {
              // Not yet, if the clock has not reached it — see [minute].
              if (minute != null && openingFillMinutes[i] > minute) continue;
              filled.add((
                minute: openingFillMinutes[i],
                type: e.type,
                key: rest[i],
                params: const {},
                seed: '${openingFillMinutes[i]}-c',
                goal: null,
                aboutId: null,
                card: null,
                playerId: null,
                offId: null,
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
        // **THE ENGINE'S `home` MEANS US, whatever the venue** — the goal case
        // twenty lines up reads it that way (`ourGoal = e.team == 'home'`), and
        // so does `homeGoals`/`awayGoals` everywhere else. This line folded
        // [isHome] back in on top of that, which is the identity XORed with the
        // venue: right at home, and inverted at every away fixture. Reported
        // from the couch three times in one match — "Iron Stars hit the
        // woodwork" when the player IS Iron Stars, playing away, and the clip
        // that ran was the opposition's.
        //
        // [isHome] is for ORDERING a scoreline, not for deciding whose chance
        // it was; the goal branch already uses it that way and only that way.
        final mine = e.team == 'home';
        out.add((
          minute: e.minute,
          type: e.type,
          key: shown ?? 'commentary.forces_save',
          params: {'who': mine ? ourName : theirName},
          seed: '${e.minute}-ch',
          goal: null,
          aboutId: null,
          card: null,
          playerId: null,
          offId: null,
        ));
      // **THEIR CHANGES, which the port dropped on the floor.**
      //
      // `buildMatchResult` pushes one `opp_sub` per entry in the AI's rotation
      // plan — the same plan the simulation consumed, so the line, the badge
      // bump and the maths describe one reality — and it writes the key and the
      // parameters onto the event itself. This fell through to `default` and
      // said nothing, so `commentary.opp_sub` was translated in ten catalogues
      // and unreachable, and the only substitutions a player ever saw in ninety
      // minutes were their own. Asked for from the couch, in exactly those
      // terms: a feed with substitutions in it.
      // **THE REFEREE'S POCKET.** A booking is a real moment in a match and the
      // feed carries it like one — the minute, the word, and a line naming the
      // player. `commentary.booking.*` is the port's own copy, because nothing
      // in the spec books anybody.
      //
      // **A SECOND YELLOW IS ITS OWN LINE.** It is a caution too many, where a
      // straight red is violent conduct or denying a goalscoring opportunity —
      // asked for from the couch in those words, and the two must not read the
      // same. `booking_engine` carries the distinction and this is where it
      // reaches the page.
      case 'booking':
        // **THEIRS READS DIFFERENTLY BECAUSE IT HAS TO.** The port never names
        // an opposition player — not at a goal, not anywhere — so their card is
        // written about the club. Same three offences, three more lines.
        final oppCard = e.team == 'away';
        out.add((
          minute: e.minute,
          type: e.type,
          key:
              'commentary.booking.${oppCard ? 'opp_' : ''}${e.card ?? cardYellow}',
          params: {
            'player': e.player ?? '',
            'us': ourName,
            'opp': theirName,
          },
          seed: '${e.minute}-card',
          goal: null,
          // **NO FACE ON THIS ROW.** A goal draws its scorer because the goal
          // is about him; a booking is about the CARD, and the card is already
          // in the head beside the minute. A portrait as well would be two
          // marks in front of one sentence, which is the rule the injury row
          // already follows. `playerId` still travels — the suspension is
          // written against it.
          aboutId: null,
          card: e.card,
          playerId: e.playerId,
          offId: null,
        ));
      case 'opp_sub':
        out.add((
          minute: e.minute,
          type: e.type,
          key: e.textKey ?? 'commentary.opp_sub',
          params: e.params,
          seed: '${e.minute}-oppsub',
          goal: null,
          aboutId: null,
          card: null,
          playerId: null,
          offId: null,
        ));
      // **THE WHISTLE IS HIS WORD, AND HIS WORD IS NOT THE FEED'S.** The nine
      // `commentary.*` results lines — `thriller_*`, `demolition`, `drubbing`,
      // `high_scoring_*`, `nervy_one_nil`, `nil_nil` — were routed through here
      // for a round, on the reasoning that the final whistle is the last row of
      // the commentary. It is, and they still cannot go in it: every one of
      // them is written in the FIRST PERSON — "we took {opp} apart", "we came
      // away with a point", "dust yourselves off" — and this feed is an
      // independent commentator describing two clubs. Reported from the couch
      // in exactly those terms: in commentary it cannot be "we".
      //
      // **They are the manager talking to you about your own team**, which is
      // Colin, so that is where they went: `MatchScreenState._sayFullTimeWord`
      // puts the reaction in his bubble at the bottom-left, the same shape the
      // rest of his match talk already takes. `fullTimeReactionKey` still picks
      // which one and is still quiet after an ordinary afternoon.
      //
      // So the whistle earns no row, and it is not a hole in the feed: the
      // third-party write-up of the same result is `match_report.dart`, which
      // sits at the head of this list at full time.
      // A corner is a momentum nudge.
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
