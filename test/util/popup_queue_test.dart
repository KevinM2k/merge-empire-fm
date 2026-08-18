/// Ported from `../merge-empire-fc/src/ui/popupQueue.js`.
///
/// The stakes are why this is tested hard. `saveState()` stamps `lastSeen`
/// during boot, so by the time the welcome-back card is queued the offline
/// window has already been consumed — drop that entry and the player's overnight
/// earnings are gone, with nothing anywhere else holding them. A blocked queue
/// waits; it does not expire.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';

/// Records the order popups opened in and keeps their `done` callbacks, so a
/// test closes them when it chooses rather than on a timer.
class _Recorder {
  final List<String> opened = [];
  final Map<String, void Function()> close = {};

  PopupEntry entry(String id, int priority, {bool Function()? canShow}) {
    return PopupEntry(
      id: id,
      priority: priority,
      canShow: canShow,
      show: (done) {
        opened.add(id);
        close[id] = done;
      },
    );
  }
}

/// The drain is a microtask, so every assertion waits one turn of the loop.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  // The queue starts holding noHostBlocker so a popup queued at boot waits for
  // a host rather than being dropped. These tests are the host.
  setUp(() => unblockPopups(noHostBlocker));
  tearDown(resetPopupQueue);

  test('drains in priority order regardless of enqueue order', () async {
    final rec = _Recorder();
    enqueuePopup(rec.entry('daily', PopupPriority.dailyReward));
    enqueuePopup(rec.entry('welcome', PopupPriority.welcomeBack));
    await settle();

    // Only one is on screen, and it is the one queued second: draining on a
    // microtask is what lets everything enqueued in one run sort together.
    expect(rec.opened, ['welcome']);
    rec.close['welcome']!();
    await settle();
    expect(rec.opened, ['welcome', 'daily']);
  });

  test('ties break by insertion order', () async {
    final rec = _Recorder();
    enqueuePopup(rec.entry('first', 50));
    enqueuePopup(rec.entry('second', 50));
    await settle();
    rec.close['first']!();
    await settle();
    expect(rec.opened, ['first', 'second']);
  });

  test('re-queueing a pending id is a no-op', () async {
    final rec = _Recorder();
    enqueuePopup(rec.entry('a', 10));
    enqueuePopup(rec.entry('a', 10));
    await settle();
    expect(rec.opened, ['a']);
    expect(isPopupPending('a'), isTrue);
  });

  test('re-queueing the id that is ON SCREEN is also a no-op', () async {
    final rec = _Recorder();
    enqueuePopup(rec.entry('a', 10));
    await settle();
    enqueuePopup(rec.entry('a', 10));
    await settle();
    expect(rec.opened, ['a']);
  });

  test('a blocker holds everything back, and releasing it drains', () async {
    final rec = _Recorder();
    blockPopups('match');
    enqueuePopup(rec.entry('a', 10));
    await settle();
    expect(rec.opened, isEmpty);
    expect(arePopupsBlocked(), isTrue);
    expect(hasPopupWork(), isTrue, reason: 'it waits, it does not expire');

    unblockPopups('match');
    await settle();
    expect(rec.opened, ['a']);
  });

  test('a blocked entry survives however long it waits', () async {
    final rec = _Recorder();
    blockPopups('tutorial');
    enqueuePopup(rec.entry('welcome', PopupPriority.welcomeBack));
    // The JS this replaces polled every 2s, gave up after 30 tries, and dropped
    // the card silently. Nothing here may do that.
    for (var i = 0; i < 50; i++) {
      await settle();
    }
    expect(hasPopupWork(), isTrue);
    unblockPopups('tutorial');
    await settle();
    expect(rec.opened, ['welcome']);
  });

  test('two blockers both have to be released', () async {
    final rec = _Recorder();
    blockPopups('match');
    blockPopups('tutorial');
    enqueuePopup(rec.entry('a', 10));
    unblockPopups('match');
    await settle();
    expect(rec.opened, isEmpty);
    unblockPopups('tutorial');
    await settle();
    expect(rec.opened, ['a']);
  });

  test('releasing a blocker nobody held changes nothing', () async {
    final rec = _Recorder();
    unblockPopups('never-set');
    enqueuePopup(rec.entry('a', 10));
    await settle();
    expect(rec.opened, ['a']);
  });

  test('canShow is re-checked at show time, not enqueue time', () async {
    final rec = _Recorder();
    var allowed = true;
    enqueuePopup(rec.entry('gated', 10, canShow: () => allowed));
    enqueuePopup(rec.entry('after', 20));
    allowed = false;
    await settle();
    expect(rec.opened, ['after'], reason: 'state moved on while it waited');
  });

  test('a double done() does not drain two entries at once', () async {
    final rec = _Recorder();
    enqueuePopup(rec.entry('a', 10));
    enqueuePopup(rec.entry('b', 20));
    enqueuePopup(rec.entry('c', 30));
    await settle();
    rec.close['a']!();
    rec.close['a']!();
    await settle();
    expect(rec.opened, ['a', 'b']);
  });

  test('a show that throws releases the queue rather than wedging it', () async {
    final rec = _Recorder();
    enqueuePopup(
      PopupEntry(id: 'bad', priority: 10, show: (_) => throw StateError('x')),
    );
    enqueuePopup(rec.entry('good', 20));
    await settle();
    expect(rec.opened, ['good']);
    expect(activePopupId(), 'good');
  });

  test('reports what is on screen', () async {
    final rec = _Recorder();
    expect(isPopupActive(), isFalse);
    expect(activePopupId(), isNull);
    expect(hasPopupWork(), isFalse);

    enqueuePopup(rec.entry('a', 10));
    expect(hasPopupWork(), isTrue, reason: 'queued but not yet drained');
    await settle();
    expect(isPopupActive(), isTrue);
    expect(activePopupId(), 'a');

    rec.close['a']!();
    await settle();
    expect(isPopupActive(), isFalse);
    expect(hasPopupWork(), isFalse);
  });

  test('the two shipped priorities put the coins first', () {
    expect(PopupPriority.welcomeBack, lessThan(PopupPriority.dailyReward));
  });

  test('reset drops everything and re-holds the host blocker', () async {
    final rec = _Recorder();
    blockPopups('match');
    enqueuePopup(rec.entry('a', 10));
    resetPopupQueue();
    await settle();
    expect(rec.opened, isEmpty);
    expect(hasPopupWork(), isFalse);
    // Back to the boot state: no host, so nothing may open.
    expect(arePopupsBlocked(), isTrue);
  });

  test('nothing opens before a host releases the blocker', () async {
    // The state the app boots in. Dropping this entry is the player's overnight
    // coins gone, so it must wait.
    resetPopupQueue();
    final rec = _Recorder();
    enqueuePopup(rec.entry('welcome', PopupPriority.welcomeBack));
    await settle();
    expect(rec.opened, isEmpty);
    expect(hasPopupWork(), isTrue);

    unblockPopups(noHostBlocker);
    await settle();
    expect(rec.opened, ['welcome']);
  });
}
