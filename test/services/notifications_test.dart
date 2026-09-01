/// Arming and withdrawing, at the seam rather than at the platform.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/notification_plan.dart';
import 'package:merge_empire_fc/services/notifications.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/util/time.dart';

final int _now = DateTime(2026, 4, 14, 10).millisecondsSinceEpoch;

class _Fake implements NoticeBackend {
  _Fake({this.granted = true});

  bool granted;
  bool throwOnSchedule = false;
  final List<ScheduledNotice> scheduled = [];
  final List<int> cancelled = [];
  int permissionAsks = 0;

  int permissionChecks = 0;

  @override
  Future<bool> requestPermission() async {
    permissionAsks += 1;
    return granted;
  }

  /// **Asked without asking** — the Settings note reads this, and requesting
  /// there would put a system prompt in front of somebody who merely opened
  /// the screen.
  @override
  Future<bool> permissionGranted() async {
    permissionChecks += 1;
    return granted;
  }

  @override
  Future<void> schedule(ScheduledNotice notice) async {
    if (throwOnSchedule) throw StateError('no platform');
    scheduled.add(notice);
  }

  @override
  Future<void> cancel(Iterable<int> ids) async => cancelled.addAll(ids);
}

Map<String, dynamic> _save({bool notifications = true, int energy = 0}) {
  final s = createDefaultState();
  (s['settings'] as Map<String, dynamic>)['notificationsEnabled'] =
      notifications;
  (s['energy'] as Map<String, dynamic>)
    ..['current'] = energy
    ..['lastRegenAt'] = _now;
  return s;
}

void main() {
  setUp(() => setClock(() => _now));
  tearDown(resetClock);

  test('a NO is final — nothing is armed', () async {
    final fake = _Fake(granted: false);
    await armNotices(_save(), now: _now, backend: fake);
    await armNotices(_save(), now: _now, backend: fake);
    expect(fake.scheduled, isEmpty);
  });

  test('ARMING NEVER RAISES A PROMPT, because it runs on the way OUT', () async {
    // **This is the bug that stopped every reminder in the app.** `armNotices`
    // is called from the `paused` lifecycle branch and nowhere else, and
    // Android 13+ shows notification permission as a runtime dialog — which
    // cannot be raised over an activity that is being paused. So the request
    // answered false every time and the schedule below it never ran. It CHECKS
    // now; the asking happens in the foreground — see [ensureNoticePermission].
    final fake = _Fake(granted: false);
    await armNotices(_save(), now: _now, backend: fake);
    expect(fake.permissionAsks, 0, reason: 'prompted while backgrounding');
    expect(fake.permissionChecks, greaterThan(0));
  });

  test('and a granted one arms without asking anything', () async {
    final fake = _Fake();
    await armNotices(_save(), now: _now, backend: fake);
    expect(fake.scheduled, isNotEmpty);
    expect(fake.permissionAsks, 0);
  });

  group('ASKING, at a moment a dialog can appear', () {
    setUp(resetNotices);
    tearDown(resetNotices);

    test('an ungranted permission is asked for once a process', () async {
      final fake = _Fake(granted: false);
      expect(await ensureNoticePermission(backend: fake), isFalse);
      expect(await ensureNoticePermission(backend: fake), isFalse);
      expect(fake.permissionAsks, 1, reason: 'nagged on every resume');
    });

    test('AND THE TOGGLE ASKS ANYWAY, because that is the player asking', () async {
      // Somebody who has just switched the setting on has said what they want,
      // whatever this process did earlier in the session.
      final fake = _Fake(granted: false);
      await ensureNoticePermission(backend: fake);
      await ensureNoticePermission(backend: fake, force: true);
      expect(fake.permissionAsks, 2);
    });

    test('one already granted is never asked for at all', () async {
      final fake = _Fake();
      expect(await ensureNoticePermission(backend: fake), isTrue);
      expect(fake.permissionAsks, 0);
    });
  });

  test('IT SCHEDULES FIRST AND WITHDRAWS AFTERWARDS', () async {
    // The order matters and always has: the callers include the app going to
    // the background, which is exactly the moment Android may freeze the
    // process. Cancelling first leaves NOTHING armed if the freeze lands in
    // between.
    final fake = _Fake();
    await armNotices(_save(), now: _now, backend: fake);
    expect(fake.scheduled, isNotEmpty);
    final armed = {for (final n in fake.scheduled) n.id};
    for (final id in fake.cancelled) {
      expect(armed, isNot(contains(id)), reason: 'withdrew what it just armed');
    }
    // And what it did not arm, it withdrew — the old eight-wide deadline block
    // included, so a device updating from a release that booked a batch does
    // not get a week of duplicates.
    expect({...armed, ...fake.cancelled}, allNoticeIds().toSet());
  });

  test('and the switch turned off withdraws everything, without asking', () async {
    final fake = _Fake();
    await armNotices(_save(notifications: false), now: _now, backend: fake);
    expect(fake.scheduled, isEmpty);
    expect(fake.cancelled.toSet(), allNoticeIds().toSet());
    expect(
      fake.permissionAsks,
      0,
      reason: 'asked for a permission it had no use for',
    );
  });

  test('a null save arms nothing and withdraws everything', () async {
    final fake = _Fake();
    await armNotices(null, now: _now, backend: fake);
    expect(fake.scheduled, isEmpty);
    expect(fake.cancelled.toSet(), allNoticeIds().toSet());
  });

  test('A PLATFORM THAT THROWS IS A NO-OP, not a crash', () async {
    // Not on a platform that has notifications, or the player revoked the
    // permission after granting it. Neither is worth telling anybody about, and
    // neither may take the app down on the way to the background.
    final fake = _Fake()..throwOnSchedule = true;
    await armNotices(_save(), now: _now, backend: fake);
    expect(fake.scheduled, isEmpty);
  });

  test('clearing takes down every id this app has ever armed', () async {
    final fake = _Fake();
    await clearNotices(backend: fake);
    expect(fake.cancelled.toSet(), allNoticeIds().toSet());
  });

  group('checking without asking', () {
    test('THEY ARE DIFFERENT QUESTIONS', () async {
      // Conflating them shows a permission prompt to somebody who only opened
      // Settings — which is why the note reads one and the arming reads the
      // other.
      final fake = _Fake(granted: false);
      expect(await fake.permissionGranted(), isFalse);
      expect(fake.permissionAsks, 0, reason: 'checking asked');
      expect(fake.permissionChecks, 1);
    });
  });
}
