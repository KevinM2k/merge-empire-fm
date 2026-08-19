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

  /// `on_target` or `off`, on a chance. The feed does not use it; the 2D
  /// cutaway does, because it is the difference between a save and a miss.
  String? shotResult,
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
