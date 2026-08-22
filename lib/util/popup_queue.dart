/// One place that decides which full-screen popup is on screen, and what shows
/// next when it closes. Ported from `../merge-empire-fc/src/ui/popupQueue.js`.
///
/// Before this the JS had three unrelated mechanisms and no single answer to "is
/// something already up": a polled retry that gave up after sixty seconds,
/// per-type singletons that knew nothing about each other, and DOM probes that
/// only saw the classes someone remembered to list.
///
/// Entries drain in priority order, one at a time, and a blocked queue WAITS
/// rather than expiring. That last part is load-bearing: the welcome-back card
/// holds coins that exist nowhere else. Boot stamps `lastSeen`, so the offline
/// window is already consumed by the time the card is queued — drop the entry
/// and the player's overnight earnings are gone. **Nothing here may time out or
/// discard.**
///
/// Popups outside the queue — offer sheets, the age gate, coach tips — still
/// exist; [hasPopupWork] is what they consult to stay out of the way.
///
/// Deliberately Flutter-free: the queue decides WHEN, the caller's `show`
/// decides what to put on screen.
library;

import 'dart:async';

/// Lower shows first.
abstract final class PopupPriority {
  /// Holds uncollected coins — always first, never dropped.
  static const int welcomeBack = 10;
  static const int dailyReward = 20;

  /// What the break did to the squad — who healed, whose sponsor lapsed, who
  /// retired. Behind the two above because both of those hold something the
  /// player can collect and this one is a report.
  static const int offseasonReport = 30;

  /// The night the game is won. Last in the season-end chain and last here —
  /// the JS opens it only once the offseason report has been read, because it
  /// is the card that offers to end the career the report is about.
  static const int championsCelebration = 40;
}

class PopupEntry {
  const PopupEntry({
    required this.id,
    required this.priority,
    required this.show,
    this.canShow,
  });

  /// Dedupe key. Re-queueing a pending id is a no-op.
  final String id;

  /// Lower shows first; ties break by queue order.
  final int priority;

  /// Must call its argument when the popup closes.
  final void Function(void Function() done) show;

  /// Re-checked at show time; false drops the entry, because the state moved on
  /// while it waited.
  final bool Function()? canShow;
}

class _Queued {
  _Queued(this.entry, this.seq);

  final PopupEntry entry;
  final int seq;
}

List<_Queued> _queue = [];
_Queued? _active;
int _seq = 0;
bool _drainScheduled = false;
final Set<String> _blockers = {noHostBlocker};

/// Drain on a microtask rather than inline, so everything enqueued in one
/// synchronous run is sorted together before anything opens.
///
/// Draining inline made priority almost meaningless: the first caller to enqueue
/// into an empty queue opened immediately, and later higher-priority entries
/// could only ever queue up BEHIND it.
void _scheduleDrain() {
  if (_drainScheduled) return;
  _drainScheduled = true;
  scheduleMicrotask(() {
    _drainScheduled = false;
    drainPopups();
  });
}

/// A popup is on screen right now.
bool isPopupActive() => _active != null;

/// Id of the popup on screen, or null.
String? activePopupId() => _active?.entry.id;

/// True if [id] is on screen or waiting its turn.
bool isPopupPending(String id) =>
    _active?.entry.id == id || _queue.any((e) => e.entry.id == id);

/// True while anything is on screen or waiting. Other UI checks this so a coach
/// tip cannot slip into the gap between one popup closing and the next opening.
bool hasPopupWork() => _active != null || _queue.isNotEmpty;

/// Held from the start, and released by the widget that can actually open a
/// popup.
///
/// Boot queues the welcome-back card long before any widget exists. Without this
/// the microtask drain would run first, the `show` callback would fail for want
/// of a host, and the catch below would treat that as "shown and closed" —
/// silently dropping the entry that holds the player's overnight coins. There is
/// no host, so this is a blocker like any other.
const String noHostBlocker = 'no-popup-host';

/// Nothing may open while a blocker is held — no host, a match, the tutorial.
bool arePopupsBlocked() => _blockers.isNotEmpty;

void blockPopups(String tag) => _blockers.add(tag);

void unblockPopups(String tag) {
  if (_blockers.remove(tag)) _scheduleDrain();
}

void enqueuePopup(PopupEntry entry) {
  if (isPopupPending(entry.id)) return;
  _queue.add(_Queued(entry, _seq++));
  _queue.sort((a, b) {
    final byPriority = a.entry.priority.compareTo(b.entry.priority);
    return byPriority != 0 ? byPriority : a.seq.compareTo(b.seq);
  });
  _scheduleDrain();
}

/// Start the next eligible popup, if the coast is clear.
void drainPopups() {
  if (_active != null || _blockers.isNotEmpty) return;
  while (_queue.isNotEmpty) {
    final next = _queue.removeAt(0);
    if (next.entry.canShow?.call() == false) continue;
    _active = next;
    var done = false;
    // Guard the callback: a double call would drain two entries at once and
    // stack them on screen.
    void finish() {
      if (done) return;
      done = true;
      if (identical(_active, next)) _active = null;
      drainPopups();
    }

    try {
      next.entry.show(finish);
    } catch (_) {
      // A popup that fails to open must not wedge everything behind it.
      finish();
    }
    return;
  }
}

/// Test and reset hook — drops everything without showing it.
void resetPopupQueue() {
  _queue = [];
  _active = null;
  _seq = 0;
  _drainScheduled = false;
  _blockers
    ..clear()
    ..add(noHostBlocker);
}
