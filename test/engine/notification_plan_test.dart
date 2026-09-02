/// What the phone gets told while nobody is looking.
///
/// **Fourteen `notif.*` strings were translated into ten languages and nothing
/// could print one.** The whole feature was left out of the port, so these tests
/// are as much about REACHABILITY as arithmetic — every one of them goes through
/// the same planner the lifecycle handler calls.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/energy_engine.dart';
import 'package:merge_empire_fc/engine/notification_plan.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/util/time.dart';

/// A Tuesday in April, well clear of both deadline windows (January and
/// August), so a test about one alert is never answered by another.
final int _now = DateTime(2026, 4, 14, 10).millisecondsSinceEpoch;

Map<String, dynamic> _save({
  bool notifications = true,
  bool pro = false,
  int? energy,
  int streak = 0,
}) {
  final s = createDefaultState();
  final settings = s['settings'] as Map<String, dynamic>;
  settings['notificationsEnabled'] = notifications;
  settings['hardMode'] = pro;
  if (energy != null) {
    (s['energy'] as Map<String, dynamic>)
      ..['current'] = energy
      ..['lastRegenAt'] = _now;
  }
  // A lazy block: `dailyReward` is created on first read rather than shipped by
  // the schema.
  s['dailyReward'] = <String, dynamic>{
    'cycleDay': 0,
    'lastClaimDayKey': null,
    'streak': streak,
    'longestStreak': streak,
    'totalClaims': streak,
    'lastAutoPopupDayKey': null,
  };
  return s;
}

void main() {
  // **The engines read the clock, and the planner is handed one.** `msUntilNextPip`
  // works off `now()` internally, so a test that passes one instant and lets the
  // engine read another is off by however long the two lines took.
  setUp(() => setClock(() => _now));
  tearDown(() {
    resetClock();
    resetLocale();
  });

  group('the switch in Settings turns ALL of it off', () {
    test('and off means nothing is planned at all', () {
      final off = _save(notifications: false, energy: 0);
      expect(plannedNotices(off, now: _now), isEmpty);
      expect(energyNotice(off, now: _now), isNull);
      expect(comebackNotice(off, now: _now), isNull);
      expect(streakNotice(off, now: _now), isNull);
      expect(deadlineNotice(off, now: _now), isNull);
    });

    test('and a save with no settings at all is off, not on', () {
      expect(notificationsEnabled(null), isFalse);
      expect(notificationsEnabled(<String, dynamic>{}), isFalse);
      // Present and unset is ON — the default the schema ships.
      expect(notificationsEnabled(_save()), isTrue);
    });
  });

  group('the energy alert', () {
    test('fires when the LAST pip lands, not the next one', () {
      final s = _save(energy: 0);
      final max = getEnergyMax(s);
      final notice = energyNotice(s, now: _now)!;
      expect(notice.id, energyNoticeId);
      expect(notice.title, t('notif.energy_full_title'));
      // The wait for the next pip, plus a full period for each one after it.
      final expected =
          _now + msUntilNextPip(s) + (max - 1) * getEnergyRegenMs(s);
      expect(notice.atMs, expected);
    });

    test('and a full tank has nothing to wait for', () {
      expect(energyNotice(_save(energy: getEnergyMax(_save())), now: _now),
          isNull);
    });

    test('PRO MODE IS A DIFFERENT ALERT, off the squad rather than the pips', () {
      // There are no pips in Pro — match fitness is the gate, players recover
      // in parallel, so the slowest one is the whole squad's answer.
      final s = _save(pro: true);
      // **A MAP, because that is what a save holds.** This test used to put a
      // `CardInstance` straight into `grid.cells` and the plan used to accept
      // one — so it passed against a shape the game never loads, while every
      // real Pro save read as eleven empty squares and the alert never fired.
      (s['grid'] as Map<String, dynamic>)['cells'] = <Object?>[
        <String, dynamic>{
          'instanceId': 'c1',
          'definitionId': 'player_t5_fwd',
          'energy': 1,
          'energyUpdatedAt': _now,
        },
      ];
      final notice = energyNotice(s, now: _now);
      expect(notice, isNotNull);
      expect(notice!.title, t('notif.squad_fit_title'));
      expect(notice.atMs, greaterThan(_now));
    });

    test('and a fully fit squad in Pro says nothing', () {
      final s = _save(pro: true);
      (s['grid'] as Map<String, dynamic>)['cells'] = <Object?>[null];
      expect(energyNotice(s, now: _now), isNull);
    });
  });

  group('the comeback alert says a DIFFERENT thing at each streak', () {
    // Three copies, and only the last is a plain "you have not played".
    test('a streak worth protecting, one just started, and none at all', () {
      expect(
        comebackNotice(_save(streak: 5), now: _now)!.title,
        t('notif.comeback_streak_title', {'n': 5}),
      );
      expect(
        comebackNotice(_save(streak: 1), now: _now)!.title,
        t('notif.comeback_needs_title'),
      );
      expect(
        comebackNotice(_save(), now: _now)!.title,
        t('notif.comeback_misses_title'),
      );
    });

    test('and it is twenty hours out — the following day, same habit', () {
      final notice = comebackNotice(_save(), now: _now)!;
      expect(notice.atMs, _now + comebackDelayMs);
      expect(comebackDelayMs, 20 * 60 * 60 * 1000);
    });
  });

  group('the streak nudge is 8pm LOCAL, and only with a streak to LOSE', () {
    test('no streak is the comeback alert\'s job, not this one', () {
      // Sending both is how one absence turns into two notifications.
      expect(streakNotice(_save(), now: _now), isNull);
    });

    test('unclaimed today, before 8pm: tonight', () {
      final notice = streakNotice(_save(streak: 4), now: _now)!;
      final at = DateTime.fromMillisecondsSinceEpoch(notice.atMs);
      expect(at.hour, streakNoticeHour);
      expect(at.day, DateTime.fromMillisecondsSinceEpoch(_now).day);
      expect(notice.title, t('notif.streak_title', {'n': 4}));
    });

    test('AND UNCLAIMED PAST 8PM IS TOO LATE TO HELP', () {
      // If the streak dies at midnight the comeback alert handles the repair.
      final late = DateTime(2026, 4, 14, 21).millisecondsSinceEpoch;
      setClock(() => late);
      expect(streakNotice(_save(streak: 4), now: late), isNull);
    });
  });

  group('Deadline Day is an APPOINTMENT', () {
    test('and it is the NEXT opening, strictly in the future', () {
      // 6pm local on a day inside the window. Asked from inside January, the
      // answer has to be later today or tomorrow — never the one just gone.
      final inWindow = DateTime(2026, 1, 10, 9).millisecondsSinceEpoch;
      setClock(() => inWindow);
      final notice = deadlineNotice(_save(), now: inWindow)!;
      expect(notice.id, deadlineNoticeId);
      expect(notice.atMs, greaterThan(inWindow));
      expect(DateTime.fromMillisecondsSinceEpoch(notice.atMs).hour, 18);
    });

    test('WITH NO SLACK — 17:59:30 still gets tonight', () {
      // Skipping anything inside the next minute quietly threw tonight's alert
      // away: this is re-laid on every background transition, so backgrounding
      // at 17:59:30 dropped the 18:00 opening and re-armed from tomorrow.
      final almost = DateTime(2026, 1, 10, 17, 59, 30);
      setClock(() => almost.millisecondsSinceEpoch);
      final notice = deadlineNotice(
        _save(),
        now: almost.millisecondsSinceEpoch,
      )!;
      final at = DateTime.fromMillisecondsSinceEpoch(notice.atMs);
      expect(at.day, 10, reason: 'tonight was thrown away');
      expect(at.hour, 18);
    });
  });

  group('the plan, and the ids it can withdraw', () {
    test('drops anything already in the past', () {
      final notices = plannedNotices(_save(energy: 0, streak: 2), now: _now);
      expect(notices, isNotEmpty);
      for (final n in notices) {
        expect(n.atMs, greaterThan(_now), reason: n.title);
      }
    });

    test('THE OLD EIGHT-WIDE DEADLINE BLOCK IS STILL WITHDRAWABLE', () {
      // That slot used to book a contiguous batch days ahead. A device updating
      // from such a release has up to eight alarms already armed, and they fire
      // on top of the one that replaced them unless they can be cancelled.
      final ids = allNoticeIds();
      for (var i = 0; i < deadlineNoticeCount; i++) {
        expect(ids, contains(deadlineNoticeId + i));
      }
      expect(ids, containsAll([energyNoticeId, comebackNoticeId,
          streakNoticeId]));
      expect(ids.toSet(), hasLength(ids.length), reason: 'a duplicate id');
    });

    test('and the ids are the JS\'s own, because they address a DEVICE', () {
      // An alarm already out there is addressed by its id, so changing one
      // orphans whatever a previous release armed.
      expect(energyNoticeId, 9001);
      expect(comebackNoticeId, 9002);
      expect(streakNoticeId, 9003);
      expect(deadlineNoticeId, 9010);
    });
  });
}
