import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/events.dart';

int _at(String iso) => DateTime.parse(iso).millisecondsSinceEpoch;

EventDef get _wc => getEventById('wc2026')!;
EventDef get _ddl => getEventById('deadline_day')!;

/// The reference numbers were produced under UTC, and the annual window
/// resolves LOCAL wall-clock time. Everywhere else the tests assert behaviour,
/// which holds in any zone; the parity group only runs where it can mean
/// something.
bool get _runningInUtc => DateTime.now().timeZoneOffset == Duration.zero;

void main() {
  setUp(clearAnnualWindowCache);

  group('the catalogue', () {
    test('ids are unique', () {
      final ids = events.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('lookup answers for a known id and null otherwise', () {
      expect(getEventById('wc2026')?.shortName, 'WC');
      expect(getEventById('nonsense'), isNull);
      expect(getEventById(null), isNull);
    });

    test('every event names a translation key beside its English fallback', () {
      for (final e in events) {
        expect(e.nameKey, isNotEmpty, reason: e.id);
        expect(e.flavourKey, isNotEmpty, reason: e.id);
        expect(e.name, isNotEmpty, reason: e.id);
      }
    });

    test('every challenge id is unique within its event', () {
      for (final e in events) {
        final ids = e.challengeConfig.map((c) => c.id).toList();
        expect(ids.toSet().length, ids.length, reason: e.id);
      }
    });

    test('a challenge asks for at least one of something', () {
      for (final e in events) {
        for (final c in e.challengeConfig) {
          expect(c.target, greaterThan(0), reason: c.id);
        }
      }
    });

    test('a harder challenge pays better', () {
      final wins = _wc.challengeConfig
          .where((c) => c.type == 'event_cup_won')
          .toList();
      wins.sort((a, b) => a.target - b.target);
      for (var i = 1; i < wins.length; i++) {
        expect(
          wins[i].rewardMult,
          greaterThan(wins[i - 1].rewardMult),
          reason: wins[i].id,
        );
      }
    });

    test('the underdog run pays more than the favourite run', () {
      // Picking the worst-rated nation is the hardest thing in the game; the
      // top seed is the easiest.
      final byId = {for (final c in _wc.challengeConfig) c.id: c};
      expect(
        byId['wc_won_underdog']!.rewardMult,
        greaterThan(byId['wc_won_favourite']!.rewardMult),
      );
    });
  });

  group('the International Cup field', () {
    test('every nation in the pool has a rating, a flag and a colour', () {
      final cup = _wc.cupConfig!;
      for (final nation in cup.opponentPool) {
        expect(cup.nationRatings[nation], isNotNull, reason: nation);
        expect(cup.flags[nation], isNotNull, reason: nation);
        expect(cup.nationColors[nation], isNotNull, reason: nation);
      }
    });

    test('and nothing is rated, flagged or coloured that is not in the pool', () {
      final cup = _wc.cupConfig!;
      final pool = cup.opponentPool.toSet();
      expect(cup.nationRatings.keys.toSet().difference(pool), isEmpty);
      expect(cup.flags.keys.toSet().difference(pool), isEmpty);
      expect(cup.nationColors.keys.toSet().difference(pool), isEmpty);
    });

    test('the pool has no duplicates', () {
      final pool = _wc.cupConfig!.opponentPool;
      expect(pool.toSet().length, pool.length);
    });

    test('the underdog and favourite challenges name the real extremes', () {
      // Both challenge texts hardcode a nation, so a rating change would make
      // them lie.
      final ratings = _wc.cupConfig!.nationRatings;
      final sorted = ratings.entries.toList()
        ..sort((a, b) => b.value - a.value);
      expect(sorted.first.key, 'Argentina');
      expect(sorted.last.key, 'Haiti');
    });

    test('every colour is a six-digit hex', () {
      // The palette gets alpha suffixes appended in places, and a shorthand
      // silently voids the declaration.
      final hex = RegExp(r'^#[0-9a-fA-F]{6}$');
      for (final entry in _wc.cupConfig!.nationColors.entries) {
        expect(hex.hasMatch(entry.value), isTrue, reason: entry.key);
      }
    });

    test('no nation wears pitch green', () {
      // Pitch camouflage — a green dot vanishes against the grass. Mexico is
      // the one deliberate exception, bright enough to read.
      for (final entry in _wc.cupConfig!.nationColors.entries) {
        if (entry.key == 'Mexico') continue;
        final r = int.parse(entry.value.substring(1, 3), radix: 16);
        final g = int.parse(entry.value.substring(3, 5), radix: 16);
        final b = int.parse(entry.value.substring(5, 7), radix: 16);
        final greenDominant = g > r + 40 && g > b + 40;
        expect(greenDominant, isFalse, reason: '${entry.key} ${entry.value}');
      }
    });

    test('the bracket is four rounds with a bump for each', () {
      final cup = _wc.cupConfig!;
      expect(cup.rounds.length, 4);
      expect(cup.opponentRatingBump.length, cup.rounds.length);
    });

    test('the rounds get harder', () {
      final bumps = _wc.cupConfig!.opponentRatingBump;
      for (var i = 1; i < bumps.length; i++) {
        expect(bumps[i], greaterThan(bumps[i - 1]));
      }
    });
  });

  group('isInDateWindow', () {
    test('is true inside the window and false either side of it', () {
      final t = _wc.trigger;
      expect(isInDateWindow(t, _at('2026-06-10T23:59:59Z')), isFalse);
      expect(isInDateWindow(t, _at('2026-06-11T00:00:00Z')), isTrue);
      expect(isInDateWindow(t, _at('2026-07-19T23:59:59Z')), isTrue);
      expect(isInDateWindow(t, _at('2026-07-20T00:00:00Z')), isFalse);
    });

    test('a recurring trigger is not a date window', () {
      expect(isInDateWindow(_ddl.trigger, _at('2026-01-01T18:30:00Z')), isFalse);
    });

    test('a null trigger is false, not a crash', () {
      expect(isInDateWindow(null, _at('2026-06-15T00:00:00Z')), isFalse);
    });

    test('an unparseable window is inactive rather than always-on', () {
      const broken = DateWindowTrigger(start: 'not a date', end: 'nor this');
      expect(isInDateWindow(broken, _at('2026-06-15T00:00:00Z')), isFalse);
    });
  });

  group('annual windows', () {
    test('two slots over three years of 31 days is 186 occurrences', () {
      final occ = annualWindowOccurrences(_ddl.trigger, _at('2026-06-01T00:00:00Z'));
      expect(occ.length, 2 * 3 * 31);
    });

    test('they come out sorted by start', () {
      final occ = annualWindowOccurrences(_ddl.trigger, _at('2026-06-01T00:00:00Z'));
      for (var i = 1; i < occ.length; i++) {
        expect(occ[i].start, greaterThanOrEqualTo(occ[i - 1].start));
      }
    });

    test('each one opens at six in the evening, LOCAL', () {
      // A UTC window would open at breakfast for half the world.
      final occ = annualWindowOccurrences(_ddl.trigger, _at('2026-06-01T00:00:00Z'));
      for (final o in occ) {
        final start = DateTime.fromMillisecondsSinceEpoch(o.start);
        expect(start.hour, 18, reason: '$start');
        expect(start.minute, 0);
      }
    });

    test('and runs for exactly an hour', () {
      for (final o in annualWindowOccurrences(_ddl.trigger, _at('2026-06-01T00:00:00Z'))) {
        expect(o.end - o.start, 60 * 60 * 1000);
      }
    });

    test('a 31-day month rolls its tail into the next one rather than stopping', () {
      // Both windows are 31-day months on purpose. February would roll over —
      // which is the behaviour, not a bug, and the reason the slots are January
      // and August.
      final occ = annualWindowOccurrences(_ddl.trigger, _at('2026-06-01T00:00:00Z'));
      final january = occ
          .map((o) => DateTime.fromMillisecondsSinceEpoch(o.start))
          .where((d) => d.year == 2026 && d.month == 1)
          .toList();
      expect(january.length, 31);
      expect(january.map((d) => d.day).toSet().length, 31);
    });

    test('the list is unmodifiable, because it is shared', () {
      // A caller that sorted or spliced it would poison every later reader.
      final occ = annualWindowOccurrences(_ddl.trigger, _at('2026-06-01T00:00:00Z'));
      expect(() => occ.add((start: 0, end: 0)), throwsUnsupportedError);
    });

    test('the same question twice gives the identical list', () {
      final a = annualWindowOccurrences(_ddl.trigger, _at('2026-06-01T00:00:00Z'));
      final b = annualWindowOccurrences(_ddl.trigger, _at('2026-06-02T00:00:00Z'));
      expect(identical(a, b), isTrue);
    });

    test('a different year recomputes', () {
      final a = annualWindowOccurrences(_ddl.trigger, _at('2026-06-01T00:00:00Z'));
      final b = annualWindowOccurrences(_ddl.trigger, _at('2027-06-01T00:00:00Z'));
      expect(identical(a, b), isFalse);
      expect(a.first.start, isNot(b.first.start));
    });

    test('a fixed-date trigger has no occurrences', () {
      expect(annualWindowOccurrences(_wc.trigger, _at('2026-06-15T00:00:00Z')), isEmpty);
      expect(annualWindowOccurrences(null, 0), isEmpty);
    });

    test('the whole-day form is honoured when no start hour is given', () {
      const wholeDay = AnnualWindowTrigger(
        slots: [(month: 3, day: 5, hour: 9)],
        days: 2,
        durationHours: 24,
      );
      final occ = annualWindowOccurrences(wholeDay, _at('2026-06-01T00:00:00Z'));
      expect(occ.length, 3 * 2);
      expect(occ.first.end - occ.first.start, 24 * 60 * 60 * 1000);
      expect(DateTime.fromMillisecondsSinceEpoch(occ.first.start).hour, 9);
    });
  });

  group('currentAnnualWindow and nextAnnualWindow', () {
    test('nothing is current outside the hour', () {
      // Local noon on a January day is between appointments.
      final noon = DateTime(2026, 1, 15, 12).millisecondsSinceEpoch;
      expect(currentAnnualWindow(_ddl.trigger, noon), isNull);
      expect(isInAnnualWindow(_ddl.trigger, noon), isFalse);
    });

    test('the appointment is live at half past six', () {
      final live = DateTime(2026, 1, 15, 18, 30).millisecondsSinceEpoch;
      expect(currentAnnualWindow(_ddl.trigger, live), isNotNull);
      expect(isInAnnualWindow(_ddl.trigger, live), isTrue);
    });

    test('and shut again by half past seven', () {
      final shut = DateTime(2026, 1, 15, 19, 30).millisecondsSinceEpoch;
      expect(isInAnnualWindow(_ddl.trigger, shut), isFalse);
    });

    test('the next one is tonight when it is still morning', () {
      final morning = DateTime(2026, 1, 15, 9).millisecondsSinceEpoch;
      final next = nextAnnualWindow(_ddl.trigger, morning)!;
      final start = DateTime.fromMillisecondsSinceEpoch(next.start);
      expect(start.day, 15);
      expect(start.hour, 18);
    });

    test('and tomorrow when tonight is over', () {
      final late = DateTime(2026, 1, 15, 21).millisecondsSinceEpoch;
      final start = DateTime.fromMillisecondsSinceEpoch(
        nextAnnualWindow(_ddl.trigger, late)!.start,
      );
      expect(start.day, 16);
    });

    test('December looks forward into NEXT January', () {
      // This is what the plus-or-minus-one-year span exists for: on 20 December
      // the next occurrence lives in a year the current one does not contain.
      final december = DateTime(2026, 12, 20, 12).millisecondsSinceEpoch;
      final next = nextAnnualWindow(_ddl.trigger, december);
      expect(next, isNotNull);
      final start = DateTime.fromMillisecondsSinceEpoch(next!.start);
      expect(start.year, 2027);
      expect(start.month, 1);
      expect(start.day, 1);
    });
  });

  group('parity with the JS', () {
    test('reproduces every reference window instant', () {
      if (!_runningInUtc) {
        markTestSkipped('needs TZ=UTC — the reference was generated there');
        return;
      }
      final data =
          jsonDecode(
                File('test/fixtures/event_window_reference.json').readAsStringSync(),
              )
              as Map<String, dynamic>;

      for (final iso in (data['probes'] as List).cast<String>()) {
        final at = _at(iso);
        expect(
          isInDateWindow(_wc.trigger, at),
          data['dateWindow'][iso],
          reason: iso,
        );

        final annual = data['annual'][iso] as Map<String, dynamic>;
        expect(
          annualWindowOccurrences(_ddl.trigger, at).length,
          annual['occurrences'],
          reason: iso,
        );

        final current = currentAnnualWindow(_ddl.trigger, at);
        final expectedCurrent = annual['current'] as Map<String, dynamic>?;
        expect(current?.start, expectedCurrent?['start'], reason: iso);
        expect(current?.end, expectedCurrent?['end'], reason: iso);

        final next = nextAnnualWindow(_ddl.trigger, at);
        final expectedNext = annual['next'] as Map<String, dynamic>?;
        expect(next?.start, expectedNext?['start'], reason: iso);
        expect(next?.end, expectedNext?['end'], reason: iso);
      }

      final sample = data['occurrenceSample'] as Map<String, dynamic>;
      final occ = annualWindowOccurrences(_ddl.trigger, _at('2026-06-01T00:00:00Z'));
      expect(occ.length, sample['total']);
      expect(occ.first.start, (sample['first'] as Map)['start']);
      expect(occ.last.end, (sample['last'] as Map)['end']);
    });
  });
}
