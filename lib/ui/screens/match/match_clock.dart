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

/// One thing that happened, ready to show.
typedef TimelineEvent = ({
  int minute,
  String type,
  String? team,
  String? scorer,
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

/// The state of a match at some point through it.
typedef MatchFrame = ({
  int minute,
  int homeGoals,
  int awayGoals,
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
  var home = 0;
  var away = 0;
  for (final e in shown) {
    if (e.type != 'goal') continue;
    if (e.team == 'away') {
      away++;
    } else {
      home++;
    }
  }
  final end = fullTime((result['addedTime'] as num?)?.toInt() ?? 0);
  return (
    minute: minute,
    homeGoals: home,
    awayGoals: away,
    shown: shown,
    finished: minute >= end,
  );
}

/// How long one minute of match time takes on screen.
///
/// Fast mode is the player's own setting, and it halves the wait rather than
/// skipping anything: a match that skips events is a match whose story the
/// player did not get.
Duration minuteDuration({required bool fast}) =>
    Duration(milliseconds: fast ? 60 : 120);

// ── The feed ────────────────────────────────────────────────────────────────

/// One line of commentary, ready for `t()`.
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
}) {
  final out = <FeedLine>[];
  int? lastChance;
  // The score AS THE FEED HAS TOLD IT, which is what decides whether a goal
  // equalised or extended a lead.
  var ours = 0;
  var theirs = 0;
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
          final scorer = e.scorer;
          out.add((
            minute: e.minute,
            type: e.type,
            key:
                'commentary.goal.$status.'
                '${scorer == null || scorer.isEmpty ? 'no_scorer' : 'with_scorer'}',
            params: {'us': ourName, 'scorer': scorer ?? ''},
            seed: '${e.minute}-${scorer ?? ''}',
          ));
        } else {
          out.add((
            minute: e.minute,
            type: e.type,
            key: 'commentary.opp_goal',
            params: {'them': theirName},
            seed: '${e.minute}-opp',
          ));
        }
      case 'halftime':
        out.add((
          minute: e.minute,
          type: e.type,
          key: 'match.half_time',
          params: const {},
          seed: 'ht',
        ));
      case 'injury':
        out.add((
          minute: e.minute,
          type: e.type,
          key: 'commentary.injury',
          params: {'player': e.player ?? ''},
          seed: '${e.minute}-inj',
        ));
      case 'commentary':
        if (e.textKey != null) {
          out.add((
            minute: e.minute,
            type: e.type,
            key: e.textKey!,
            params: const {},
            seed: '${e.minute}-c',
          ));
        }
      case 'chance':
        final big = e.big || e.xg >= chanceFeedBigXg;
        final enoughGap =
            lastChance == null || e.minute - lastChance >= chanceFeedGap;
        if (!big || e.shotResult != 'on_target' || !enoughGap) continue;
        lastChance = e.minute;
        final mine = (e.team == 'home') == isHome;
        out.add((
          minute: e.minute,
          type: e.type,
          key: 'commentary.forces_save',
          params: {'who': mine ? ourName : theirName},
          seed: '${e.minute}-ch',
        ));
      // A corner is a momentum nudge and full time is the screen's own.
      default:
        continue;
    }
  }
  return out;
}
