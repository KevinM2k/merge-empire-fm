/// The four local notifications, delivered. Ported from the `LocalNotifications`
/// calls in `../merge-empire-fc/src/main.js`.
///
/// **`engine/notification_plan.dart` decides; this only sends.** Everything
/// about whether an alert is worth sending and what second it fires on is
/// arithmetic on the save and lives there.
///
/// **`androidScheduleMode` is the whole reason this file has a comment.** It is
/// the port of `allowWhileIdle: true`, which every one of the JS's four passes
/// and has to:
///
///   allowWhileIdle   → setExactAndAllowWhileIdle / setAndAllowWhileIdle, on
///                      RTC_WAKEUP
///   omitted          → setExact / set, on plain RTC
///
/// RTC rather than RTC_WAKEUP is the whole problem: it does not wake a sleeping
/// device, so Doze defers it indefinitely — and a phone asleep at 6pm is the
/// NORMAL case for a backgrounded game. The cost is precision, since idle alarms
/// are throttled to roughly one per nine minutes, and for an appointment and
/// three nudges "a few minutes late" beats "silently never".
///
/// **`SCHEDULE_EXACT_ALARM` is deliberately NOT asked for.** It needs a Play
/// Console declaration and this is not an alarm clock, so this lands on the
/// inexact branch — which is fine, but only WITH the idle exemption.
library;

import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:merge_empire_fc/engine/notification_plan.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The Android channel. One, because all four are the same kind of thing to a
/// player: the game telling them something is ready.
const String noticeChannelId = 'merge_empire_reminders';

/// Everything that touches the platform, and nothing else. A test replaces this.
abstract class NoticeBackend {
  /// Ask, once. False means the player said no — and a no is FINAL as far as
  /// this app is concerned: it never asks twice and never explains.
  Future<bool> requestPermission();

  Future<void> schedule(ScheduledNotice notice);

  Future<void> cancel(Iterable<int> ids);
}

class PluginNoticeBackend implements NoticeBackend {
  PluginNoticeBackend([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    // **The zone database, loaded once.** `zonedSchedule` takes a `TZDateTime`
    // and there is no local zone until this runs; `setLocalLocation` is what
    // makes `tz.local` the device's own rather than UTC.
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(DateTime.now().timeZoneName));
    } catch (_) {
      // `timeZoneName` is an abbreviation rather than an IANA zone on some
      // platforms. UTC is the fallback, which shifts only the 6pm appointment
      // and only on a device this could not identify.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Asked for explicitly below instead, so the prompt lands when the
          // app first backgrounds rather than on the splash screen.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    await _init();
    try {
      if (Platform.isIOS) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await ios?.requestPermissions(alert: true, sound: true) ?? false;
      }
      if (Platform.isAndroid) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await android?.requestNotificationsPermission() ?? false;
      }
    } catch (_) {
      // No platform under it — a widget test, or a desktop build.
    }
    return false;
  }

  @override
  Future<void> schedule(ScheduledNotice notice) async {
    await _init();
    await _plugin.zonedSchedule(
      id: notice.id,
      title: notice.title,
      body: notice.body,
      scheduledDate: _at(notice.atMs),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          noticeChannelId,
          'Reminders',
          importance: Importance.defaultImportance,
          icon: 'ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // See the note at the head of this file. This is `allowWhileIdle`.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// **A local wall-clock instant.** `TZDateTime` is what the plugin wants and
  /// the device's own zone is the right one for all four: three are relative to
  /// now, and the fourth is a 6pm LOCAL appointment.
  tz.TZDateTime _at(int ms) =>
      tz.TZDateTime.from(DateTime.fromMillisecondsSinceEpoch(ms), tz.local);

  @override
  Future<void> cancel(Iterable<int> ids) async {
    await _init();
    for (final id in ids) {
      await _plugin.cancel(id: id);
    }
  }
}

/// Arm what the plan says, withdraw what it does not.
///
/// **SCHEDULE FIRST, withdraw afterwards — the order matters and always has.**
/// The callers include the app going to the background, which is exactly the
/// moment Android may freeze the process; cancelling first leaves NOTHING armed
/// if the freeze lands in between. Re-writing an id needs no cancel of its own —
/// the id is the alarm's identity, so writing it replaces what was there.
Future<void> armNotices(
  Map<String, dynamic>? state, {
  required int now,
  NoticeBackend? backend,
}) async {
  final notices = plannedNotices(state, now: now);
  final send = backend ?? noticeBackend;
  try {
    if (notices.isEmpty) {
      await send.cancel(allNoticeIds());
      return;
    }
    if (!await send.requestPermission()) return;
    for (final notice in notices) {
      await send.schedule(notice);
    }
    // Whatever the plan did NOT ask for, including the tail of the old
    // eight-wide deadline block — ids that may still be armed on a device
    // updating from a release that booked a batch.
    final armed = {for (final n in notices) n.id};
    await send.cancel(allNoticeIds().where((id) => !armed.contains(id)));
  } catch (_) {
    // Not on a platform that has them, or the player revoked permission after
    // granting it. Neither is worth telling anybody about.
  }
}

/// Withdraw the lot. Called on RESUME: an alert is only ever useful while the
/// app is away, and one that arrives while the player is looking at the game is
/// the game interrupting itself.
Future<void> clearNotices({NoticeBackend? backend}) async {
  try {
    await (backend ?? noticeBackend).cancel(allNoticeIds());
  } catch (_) {
    // As above.
  }
}

/// The app's own, swapped in tests.
NoticeBackend noticeBackend = PluginNoticeBackend();
