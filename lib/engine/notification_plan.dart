/// What the phone should be told, and when. Ported from the four
/// `schedule*Notification` blocks in `../merge-empire-fc/src/main.js`.
///
/// **THE DECISION IS PURE AND THE DELIVERY IS NOT**, which is why they are two
/// files: everything about whether an alert is worth sending, what it says and
/// what second it fires on is arithmetic on the save, and that is all here.
/// `services/notifications.dart` takes the answer to the platform.
///
/// **Fourteen `notif.*` strings were translated into ten languages and nothing
/// could print one of them.** The whole feature was left behind in the port —
/// this is the queue's own loudest tell, shipped copy with no caller.
///
/// **`allowWhileIdle` is not a flag this file passes**, but it is the reason the
/// file is worth having, so it is recorded here as well as at the seam: on
/// Android the plugin picks its `AlarmManager` call from that one flag, and
/// without it an alarm is `RTC` rather than `RTC_WAKEUP` — which does not wake a
/// sleeping device, so Doze defers it indefinitely. A phone asleep at 6pm is the
/// NORMAL case for a backgrounded game. The cost is precision (idle alarms are
/// throttled to roughly one per nine minutes), and for an appointment and three
/// nudges "a few minutes late" beats "silently never".
library;

import 'package:merge_empire_fc/data/events.dart';
import 'package:merge_empire_fc/engine/daily_reward_engine.dart';
import 'package:merge_empire_fc/engine/energy_engine.dart';
import 'package:merge_empire_fc/engine/player_energy_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/state/card_instance.dart';

/// **The ids are the JS's own, and they are a contract with the DEVICE.** An
/// alarm already out there is addressed by its id, so changing one of these
/// orphans whatever a previous release armed — it can no longer be withdrawn and
/// fires anyway.
const int energyNoticeId = 9001;
const int comebackNoticeId = 9002;
const int streakNoticeId = 9003;
const int deadlineNoticeId = 9010;

/// **The width of the OLD deadline block, and it has to stay eight.** That slot
/// used to book a contiguous batch of eight days ahead; a save updating from
/// such a release has up to eight alarms already armed, and they have to be
/// withdrawn or they fire on top of the one that replaced them.
const int deadlineNoticeCount = 8;

/// Twenty hours — long enough that it lands on the following day, short enough
/// that it is still the same habit.
const int comebackDelayMs = 20 * 60 * 60 * 1000;

/// 8pm local. Late enough to matter and early enough to act on before the
/// streak resets at midnight.
const int streakNoticeHour = 20;

/// One alert, ready to hand to the platform.
typedef ScheduledNotice = ({int id, String title, String body, int atMs});

/// Whether the player wants any of this at all.
bool notificationsEnabled(Map<String, dynamic>? state) {
  final settings = state?['settings'];
  return settings is Map<String, dynamic>
      ? settings['notificationsEnabled'] != false
      : false;
}

List<CardInstance?> _cells(Map<String, dynamic>? state) {
  final grid = state?['grid'];
  final cells = grid is Map<String, dynamic> ? grid['cells'] : null;
  if (cells is! List) return const [];
  // **`CardInstance.from`, not an `is` check.** The save is JSON, so a grid
  // cell is a `Map` and never a `CardInstance` — so this returned eleven nulls
  // for every real save and Pro mode's squad-fitness alert could not fire at
  // all. It went unseen because the test put `CardInstance` objects into
  // `grid.cells` directly, which is a shape the game never loads.
  return [for (final c in cells) CardInstance.from(c)];
}

/// **The energy alert, and in Pro mode it is a different alert entirely.**
///
/// Casual: the pips refill on a clock, so the fire time is the wait for the next
/// one plus a full period for each one after it.
///
/// Pro: there are no pips — the squad's MATCH FITNESS is the gate, players
/// recover in parallel, and the slowest one is therefore the whole squad's
/// answer. A club with nobody tired has nothing to wait for.
ScheduledNotice? energyNotice(Map<String, dynamic> state, {required int now}) {
  if (!notificationsEnabled(state)) return null;
  final settings = state['settings'];
  final pro =
      settings is Map<String, dynamic> && settings['hardMode'] == true;

  if (pro) {
    var worst = 0.0;
    for (final card in _cells(state)) {
      if (card == null) continue;
      final info = fitnessRegenInfo(card, state, now);
      if (!info.full && info.msToFull.isFinite && info.msToFull > worst) {
        worst = info.msToFull;
      }
    }
    if (worst <= 0) return null;
    return (
      id: energyNoticeId,
      title: t('notif.squad_fit_title'),
      body: t('notif.squad_fit_body'),
      atMs: now + worst.round(),
    );
  }

  final max = getEnergyMax(state);
  final energy = state['energy'];
  final current = energy is Map<String, dynamic>
      ? (energy['current'] as num?)?.toInt() ?? 0
      : 0;
  if (current >= max) return null;
  final wait =
      msUntilNextPip(state) + (max - current - 1) * getEnergyRegenMs(state);
  return (
    id: energyNoticeId,
    title: t('notif.energy_full_title'),
    body: t('notif.energy_full_body'),
    atMs: now + wait,
  );
}

/// **Come back tomorrow, and what it says depends on what they have going.**
/// Three copies: a streak worth protecting, a streak just started, and no
/// streak at all — which is the only one that is a plain "you have not played".
ScheduledNotice? comebackNotice(Map<String, dynamic> state, {required int now}) {
  if (!notificationsEnabled(state)) return null;
  final daily = state['dailyReward'];
  final streak = daily is Map<String, dynamic>
      ? (daily['streak'] as num?)?.toInt() ?? 0
      : 0;
  final (title, body) = switch (streak) {
    >= 3 => (
      t('notif.comeback_streak_title', {'n': streak}),
      t('notif.comeback_streak_body'),
    ),
    > 0 => (
      t('notif.comeback_needs_title'),
      t('notif.comeback_needs_body', {'n': streak}),
    ),
    _ => (
      t('notif.comeback_misses_title'),
      t('notif.comeback_misses_body'),
    ),
  };
  return (
    id: comebackNoticeId,
    title: title,
    body: body,
    atMs: now + comebackDelayMs,
  );
}

/// **Only worth a nudge when there is a live streak to LOSE.** A broken streak,
/// or a player with none, is the comeback alert's job — and sending both is how
/// one absence turns into two notifications.
///
/// Already claimed today means tonight is safe, so the nudge moves to tomorrow
/// evening. Unclaimed and already past 8pm means it is too late to help: if the
/// streak dies at midnight the comeback alert handles the repair.
ScheduledNotice? streakNotice(Map<String, dynamic> state, {required int now}) {
  if (!notificationsEnabled(state)) return null;
  final status = getDailyRewardStatus(state, now);
  final daily = state['dailyReward'];
  final streak = daily is Map<String, dynamic>
      ? (daily['streak'] as num?)?.toInt() ?? 0
      : 0;
  if (streak < 1 || status.broken) return null;

  final today = DateTime.fromMillisecondsSinceEpoch(now);
  var at = DateTime(today.year, today.month, today.day, streakNoticeHour);
  if (status.claimedToday) {
    at = at.add(const Duration(days: 1));
  } else if (now >= at.millisecondsSinceEpoch) {
    return null;
  }
  return (
    id: streakNoticeId,
    title: t('notif.streak_title', {'n': streak}),
    body: t('notif.streak_body'),
    atMs: at.millisecondsSinceEpoch,
  );
}

/// **Deadline Day is an APPOINTMENT, not a nudge**: 6pm local, one hour, on
/// each day of the event. An appointment nobody is told about is a window that
/// quietly closes.
///
/// **One notification, for the next opening only**, which is a correction the JS
/// made after shipping: a batch of eight booked days ahead never arrived on
/// device while the single-notification energy alert on the identical code path
/// always did, and the batch was the only difference. What that costs, stated
/// plainly: someone who does not open the game at all between two openings gets
/// no alert for the second. Every lifecycle event re-arms it, so opening the app
/// once at any point in the day covers that evening.
///
/// **Strictly future, with NO slack.** Skipping anything inside the next minute
/// quietly threw tonight's alert away — this is re-laid on every foreground and
/// background transition, so backgrounding at 17:59:30 dropped the 18:00 opening
/// and re-armed from tomorrow. The one alert that mattered was the one the slack
/// removed.
ScheduledNotice? deadlineNotice(
  Map<String, dynamic> state, {
  required int now,
}) {
  if (!notificationsEnabled(state)) return null;
  final def = eventCatalogue
      .where((EventDef e) => e.mechanics.contains('deadlineDay'))
      .firstOrNull;
  final trigger = def?.trigger;
  if (trigger is! AnnualWindowTrigger) return null;
  final next = annualWindowOccurrences(
    trigger,
    now,
  ).where((o) => o.start > now).firstOrNull;
  if (next == null) return null;
  final mins = trigger.durationMinutes;
  return (
    id: deadlineNoticeId,
    title: t('notif.deadline_title'),
    body: t('notif.deadline_body', {'mins': mins}),
    atMs: next.start,
  );
}

/// Everything the phone should be holding while the app is away.
///
/// Order is the JS's call order and it is not arbitrary: the deadline
/// appointment goes last because it is the one that must not be dropped, and the
/// seam schedules in the order it is given.
List<ScheduledNotice> plannedNotices(
  Map<String, dynamic>? state, {
  required int now,
}) {
  if (state == null || !notificationsEnabled(state)) return const [];
  return [
    for (final notice in [
      energyNotice(state, now: now),
      comebackNotice(state, now: now),
      streakNotice(state, now: now),
      deadlineNotice(state, now: now),
    ])
      if (notice != null && notice.atMs > now) notice,
  ];
}

/// Every id this app has ever armed, so a withdrawal can be complete — the old
/// eight-wide deadline block included.
List<int> allNoticeIds() => [
  energyNoticeId,
  comebackNoticeId,
  streakNoticeId,
  for (var i = 0; i < deadlineNoticeCount; i++) deadlineNoticeId + i,
];
