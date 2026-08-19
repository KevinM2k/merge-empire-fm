/// What the Event screen reads. Ported from the state-reading half of
/// `ui/screens/EventScreen.js`.
///
/// The screen is the only one in the game driven by a REAL clock — a Deadline
/// Day listing burns a five-minute fuse whether or not anyone is looking — so
/// the values here are deliberately split in two:
///
/// - Anything that lives on the save is a derived provider, the way every other
///   screen reads. It moves when a deal lands.
/// - Anything that moves with the wall clock is NOT. A provider recomputed every
///   second would rebuild the whole feed under the player's finger and restart
///   every card's fuse. The screen holds one ticker and repaints the clock and
///   the fuses from it; see `deadline_day_view.dart`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/deadline_day.dart';
import 'package:merge_empire_fc/data/events.dart';
import 'package:merge_empire_fc/engine/deadline_day_engine.dart';
import 'package:merge_empire_fc/engine/event_engine.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// The event on screen, or null when the doors are shut.
///
/// The first ACTIVE one. More than one at a time is future work in the JS too,
/// and the note there is worth keeping rather than inventing an answer.
final activeEventProvider = savePick<String?>((s) {
  final active = activeEvents(s);
  return active.isEmpty ? null : active.first.id;
});

/// What to count down to while the doors are shut, or null when nothing is
/// coming and nothing just happened.
final upcomingEventProvider = savePick<String?>((s) {
  final preview = previewEvents(s);
  if (preview.isNotEmpty) return preview.first.id;
  // Shut for good on the last night of a window: the next occurrence is months
  // off, so nothing is in preview. An evening that just happened outranks a
  // countdown to nothing — the ledger is still worth showing.
  return justShutTodayEventId(s);
});

/// The event whose window ran and shut earlier today, or null.
String? justShutTodayEventId(Map<String, dynamic>? state) {
  for (final e in events) {
    if (tonightSummary(state, e) != null) return e.id;
  }
  return null;
}

/// Tonight's banked ledger, or null.
///
/// Between the doors shutting and midnight the evening still belongs to the
/// player, so the shut screen owes them the ledger rather than a countdown to
/// the next one. Keyed on the window's own start being TODAY, which expires the
/// block at midnight on its own. Null when the player never opened the app
/// during the window: a table of zeroes is a worse answer than no table.
Map<String, dynamic>? tonightSummary(Map<String, dynamic>? state, EventDef ev) {
  if (!ev.mechanics.contains('deadlineDay')) return null;
  if (state == null) return null;
  final history = ensureDeadlineDay(state)['history'];
  if (history is! List || history.isEmpty) return null;
  final latest = _map(history.first);
  if (latest == null) return null;
  final stamp = latest['windowStart'] ?? latest['endedAt'];
  if (stamp is! num) return null;
  final then = DateTime.fromMillisecondsSinceEpoch(stamp.toInt());
  final today = DateTime.fromMillisecondsSinceEpoch(now());
  final sameDay =
      then.year == today.year &&
      then.month == today.month &&
      then.day == today.day;
  return sameDay ? latest : null;
}

/// The occurrence we are inside, as start and end.
///
/// `end` matters as much as `start`: the session is bounded by the WINDOW, so
/// opening at 6:45 gives fifteen minutes rather than a fresh full-length run.
typedef DeadlineWindow = ({int start, int end});

const DeadlineWindow noWindow = (start: 0, end: 0);

DeadlineWindow deadlineWindow(Map<String, dynamic>? state, [int? nowMs]) {
  if (state == null) return noWindow;
  final at = nowMs ?? now();
  EventDef? ev;
  for (final e in activeEvents(state)) {
    if (e.mechanics.contains('deadlineDay')) {
      ev = e;
      break;
    }
  }
  if (ev == null) return noWindow;

  final occurrence = currentAnnualWindow(ev.trigger, at);
  if (occurrence != null) {
    // A window longer than one session is cut into back-to-back sessions
    // anchored to the window's own start. Without this `startedAt` is the
    // window's opening and all `maxSpawns` listings are scheduled inside the
    // first `sessionMs` of it — arrive later and every one has already expired,
    // so the feed is empty for the rest of the window. Inert on the real
    // schedule, where the window IS one session long.
    if (occurrence.end - occurrence.start <= sessionMs) {
      return (start: occurrence.start, end: occurrence.end);
    }
    final n = (at - occurrence.start) ~/ sessionMs;
    final start = occurrence.start + n * sessionMs;
    return (start: start, end: math.min(occurrence.end, start + sessionMs));
  }

  // Forced outside the real calendar: pretend the window opened on the last
  // whole hour. That has to be a FIXED instant rather than `now`, because it
  // keys the session and a start that drifted between renders would reset the
  // status to idle on every paint. Flooring also reproduces the real thing —
  // force it at ten past and you join ten minutes late, with ten minutes of
  // business already missed.
  if (_map(state['events'])?['devOverride'] == ev.id) {
    final trigger = ev.trigger;
    final len = trigger is AnnualWindowTrigger ? trigger.durationMs : sessionMs;
    final start = (at ~/ len) * len;
    return (start: start, end: start + len);
  }
  return noWindow;
}

/// Which sub-tabs an event offers.
///
/// Read off `mechanics` rather than fixed, so a cup event shows a bracket and
/// Deadline Day shows a trading floor without either having to know about the
/// other.
enum EventSubTab { deadline, cup, challenges }

String eventSubTabLabelKey(EventSubTab tab) => switch (tab) {
  EventSubTab.deadline => 'event.subtab.deadline',
  EventSubTab.cup => 'event.subtab.cup',
  EventSubTab.challenges => 'event.subtab.challenges',
};

List<EventSubTab> subTabsFor(EventDef? event) {
  final mechanics = event?.mechanics ?? const <String>[];
  final tabs = <EventSubTab>[
    if (mechanics.contains('deadlineDay')) EventSubTab.deadline,
    if (mechanics.contains('cup')) EventSubTab.cup,
    if (mechanics.contains('challenges')) EventSubTab.challenges,
  ];
  return tabs.isEmpty ? const [EventSubTab.cup] : tabs;
}

/// Everything on the trading floor that lives on the SAVE.
///
/// The fuses and the clock are not in here — see the header.
typedef DeadlineFloor = ({
  List<Listing> buy,
  List<Listing> sell,
  int missed,
  num coins,
});

/// Business that came and went: burnt its fuse, been turned down, been pulled,
/// or had its player leave by another route.
///
/// Counting only `expired` undercounts the churn. The line reads as a running
/// total of business the window did without us, so a deal we passed on belongs
/// in it just as much as one we never got to.
int missedCount(Map<String, dynamic> state) {
  final listings = ensureDeadlineDay(state)['session'];
  final raw = _map(listings)?['listings'];
  if (raw is! List) return 0;
  return raw.where((l) {
    final status = _map(l)?['status'];
    return status != 'live' && status != 'accepted';
  }).length;
}
