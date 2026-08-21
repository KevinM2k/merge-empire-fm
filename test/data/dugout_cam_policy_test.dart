/// The dugout cam's policy, against the JS it was ported from.
///
/// Two halves, and they fail differently. `shouldCutIn` is a chain of refusals
/// in a fixed ORDER — reduced motion beats the settings, the settings beat the
/// full-time exemption, the budget beats the gap — so a port with every rule
/// right and the order wrong agrees on most inputs and then drops the one shot
/// the whole feature exists for. `camMood` is arithmetic over a scoreline with
/// a late-winner override on top, and hands a DRAW straight to `moodForScore`,
/// which is pinned in its own fixture: what matters here is that the four
/// context fields reach it unmangled.
///
/// See `tool/dump_dugout_cam_reference.mjs`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/dugout_cam_policy.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';

final Map<String, dynamic> _ref =
    jsonDecode(
          File('test/fixtures/dugout_cam_reference.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

List<Map<String, dynamic>> _rows(String key) =>
    (_ref[key] as List).cast<Map<String, dynamic>>();

/// The JS reported a mood as a plain string.
Mood _mood(String name) => Mood.values.firstWhere((m) => m.name == name);

/// A roll that always returns the same number, matching the dump's closures.
double Function() _roll(num value) => () => value.toDouble();

/// The JS named its triggers with strings, and two of the dump's rows name
/// things that are not triggers at all — see the guard test below.
CamTrigger? _trigger(String id) {
  for (final t in CamTrigger.values) {
    if (t.id == id) return t;
  }
  return null;
}

/// The settings maps the dump rolled through, by its own label.
Map<String, dynamic> _settings(String label) => switch (label) {
  'both on' => {'cutawayOurTeam': true, 'cutawayOpponent': true},
  'ours off' => {'cutawayOurTeam': false, 'cutawayOpponent': true},
  'theirs off' => {'cutawayOurTeam': true, 'cutawayOpponent': false},
  'both off' => {'cutawayOurTeam': false, 'cutawayOpponent': false},
  'unset' => <String, dynamic>{},
  _ => fail('unknown settings label $label'),
};

/// The draw context each `camMood` row carried.
({num ratingGap, bool? isHome, bool led, bool trailed}) _context(String label) =>
    switch (label) {
      'none' => (ratingGap: 0, isHome: null, led: false, trailed: false),
      'away to a better side' => (
        ratingGap: 10,
        isHome: false,
        led: false,
        trailed: false,
      ),
      'pegged back at home' => (
        ratingGap: -10,
        isHome: true,
        led: true,
        trailed: false,
      ),
      'came back' => (ratingGap: 0, isHome: true, led: false, trailed: true),
      'swung both ways' => (
        ratingGap: 0,
        isHome: null,
        led: true,
        trailed: true,
      ),
      _ => fail('unknown context label $label'),
    };

/// What each `camRotaBeat` row handed in as `recent`. The JS accepted a bare
/// string and a list with holes in it; Dart's type says a list of strings, so
/// those rows are checked as the list the JS would have made of them.
List<String> _recent(String label) => switch (label) {
  'nothing' => const [],
  'one' => const ['armsfolded'],
  'two' => const ['armsfolded', 'handsonhips'],
  'three' => const ['armsfolded', 'handsonhips', 'handsonhead'],
  'a bare string rather than a list' => const ['armsfolded'],
  'nulls' => const ['armsfolded'],
  _ => fail('unknown recent label $label'),
};

void main() {
  group('the numbers the window is built from', () {
    test('match the JS', () {
      expect(camGapMinutes, _ref['gapMins']);
      expect(camMaxGoalCuts, _ref['maxGoalCuts']);
      expect(camIn.inMilliseconds, _ref['inMs']);
      expect(camHold.inMilliseconds, _ref['holdMs']);
      expect(camOut.inMilliseconds, _ref['outMs']);
      expect(lateWinnerMinutes, _ref['lateWinnerMins']);
      expect(camRotaMemory, _ref['rotaMemory']);
    });

    test('and so do the rota bands, mood by mood', () {
      final bands = _ref['rotaGapMs'] as Map<String, dynamic>;
      expect(bands.length, camRotaGapMs.length);
      for (final entry in bands.entries) {
        final (lo, hi) = camRotaGapMs[_mood(entry.key)]!;
        expect([lo, hi], entry.value, reason: entry.key);
      }
    });

    test('the triggers are the three the enum carries', () {
      expect(
        (_ref['triggers'] as List).cast<String>(),
        CamTrigger.values.map((t) => t.id),
      );
    });
  });

  group('the window', () {
    test('is the entry, the gesture, the hold and the exit', () {
      for (final row in _rows('camWindowMs')) {
        expect(
          camWindow(Duration(milliseconds: row['gestureMs'] as int))
              .inMilliseconds,
          row['ms'],
          reason: '${row['gestureMs']}ms gesture',
        );
      }
    });

    test('and a late goal gives up the camera rather than sharing it', () {
      for (final row in _rows('camFitsBeforeFullTime')) {
        final left = row['msToFullTime'] as int?;
        expect(
          camFitsBeforeFullTime(
            Duration(milliseconds: row['gestureMs'] as int),
            left == null ? null : Duration(milliseconds: left),
          ),
          row['fits'],
          reason: '${row['gestureMs']}ms gesture, ${left}ms left',
        );
      }
    });
  });

  group('which switch governs which trigger', () {
    test('matches the JS, and full time answers to none of them', () {
      for (final row in _rows('camSettingKey')) {
        final trigger = _trigger(row['trigger'] as String);
        if (trigger == null) continue;
        expect(camSettingKey(trigger), row['key'], reason: '${row['trigger']}');
      }
      expect(camSettingKey(CamTrigger.fullTime), isNull);
    });
  });

  group('should it cut in', () {
    test('every row of the grid, in the order the refusals run', () {
      var checked = 0;
      for (final row in _rows('shouldCutIn')) {
        final trigger = _trigger(row['trigger'] as String);
        if (trigger == null) continue;
        checked++;
        expect(
          shouldCutIn(
            trigger: trigger,
            minute: row['minute'] as int,
            lastCutMinute: row['lastCutMin'] as int?,
            goalCuts: row['goalCuts'] as int,
            settings: _settings(row['settingsLabel'] as String),
            reducedFx: row['reducedFx'] as bool,
          ),
          row['cut'],
          reason:
              '${row['trigger']} at ${row['minute']}, last ${row['lastCutMin']}, '
              '${row['goalCuts']} spent, ${row['settingsLabel']}, '
              'reducedFx ${row['reducedFx']}',
        );
      }
      expect(checked, greaterThan(500), reason: 'the grid should be thorough');
    });

    test('a trigger the camera does not answer to is refused in the JS, and '
        'cannot be spelled here at all', () {
      final strays = _rows('shouldCutIn')
          .where((r) => _trigger(r['trigger'] as String) == null)
          .toList();
      expect(strays, isNotEmpty);
      // The JS guarded this with a list membership check. Dart's enum is the
      // same guard moved to compile time, so the only thing left to hold is
      // that the JS really did refuse them — otherwise the enum would be
      // dropping a shot rather than a typo.
      expect(strays.every((r) => r['cut'] == false), isTrue);
    });

    test('a call with nothing passed at all does not cut in', () {
      // `shouldCutIn()` in the JS, whose trigger is undefined. The port asks
      // for a trigger, so the nearest thing is the default of every other
      // argument — and those defaults must not, between them, be a refusal.
      expect(_ref['shouldCutInBare'], isFalse);
      expect(shouldCutIn(trigger: CamTrigger.goalFor), isTrue);
    });
  });

  group('a late winner', () {
    test('is ours, inside the last few minutes, and from level', () {
      for (final row in _rows('isLateWinner')) {
        expect(
          isLateWinner(
            minute: row['minute'] as int,
            duration: row['duration'] as int,
            ourGoals: row['ourGoals'] as int,
            theirGoals: row['theirGoals'] as int,
          ),
          row['late'],
          reason:
              "${row['ourGoals']}-${row['theirGoals']} at ${row['minute']} "
              "of ${row['duration']}",
        );
      }
    });

    test('and nothing passed at all is not one', () {
      expect(_ref['isLateWinnerBare'], isFalse);
      expect(isLateWinner(), isFalse);
    });
  });

  group('how he is feeling', () {
    test('at every moment the dump rolled through', () {
      for (final row in _rows('camMood')) {
        final trigger = _trigger(row['trigger'] as String);
        if (trigger == null) continue;
        final ctx = _context(row['ctxLabel'] as String);
        expect(
          camMood(
            trigger: trigger,
            ourGoals: row['ourGoals'] as int,
            theirGoals: row['theirGoals'] as int,
            trophiesEarned: row['trophiesEarned'] as int,
            lateWinner: row['lateWinner'] as bool,
            ratingGap: ctx.ratingGap,
            isHome: ctx.isHome,
            led: ctx.led,
            trailed: ctx.trailed,
          ),
          _mood(row['mood'] as String),
          reason:
              "${row['trigger']} at ${row['ourGoals']}-${row['theirGoals']}, "
              "late ${row['lateWinner']}, ${row['trophiesEarned']} trophies, "
              "${row['ctxLabel']}",
        );
      }
    });

    test('and a late winner is elated at the whistle too, not just at the '
        'goal', () {
      // The scoreline alone cannot see it: by full time 1-0 is just 1-0.
      expect(
        camMood(trigger: CamTrigger.fullTime, ourGoals: 1, lateWinner: true),
        Mood.elated,
      );
      expect(
        camMood(trigger: CamTrigger.fullTime, ourGoals: 1),
        Mood.pleased,
      );
    });

    test('and a late equaliser is not a late winner', () {
      // margin 0, so the override cannot fire whatever the flag says.
      expect(
        camMood(
          trigger: CamTrigger.goalFor,
          ourGoals: 1,
          theirGoals: 1,
          lateWinner: true,
        ),
        Mood.pleased,
      );
    });
  });

  group('the gesture he plays into the lens', () {
    test('is pickGesture, with the full-time flag carried through', () {
      for (final row in _rows('camGesture')) {
        expect(
          camGesture(
            _mood(row['mood'] as String),
            _roll(row['roll'] as num),
            null,
            row['fullTime'] as bool,
          )?.id,
          row['id'],
          reason:
              "${row['mood']}, fullTime ${row['fullTime']}, roll ${row['roll']}",
        );
      }
    });

    test('and checking your watch never survives the whistle', () {
      for (final mood in Mood.values) {
        for (var i = 0; i <= 20; i++) {
          expect(
            camGesture(mood, _roll(i / 20), null, true)?.id,
            isNot('checkwatch'),
            reason: '$mood at ${i / 20}',
          );
        }
      }
    });
  });

  group('the rota', () {
    test('picks and paces every beat the dump rolled', () {
      for (final row in _rows('camRotaBeat')) {
        final name = row['mood'] as String;
        // The dump rolled a mood that is not one, to pin the neutral fallback.
        // The enum cannot spell it, so the fallback is checked below instead.
        if (!Mood.values.any((m) => m.name == name)) continue;
        final beat = camRotaBeat(
          _mood(name),
          _roll(row['roll'] as num),
          null,
          _recent(row['excludeLabel'] as String),
        );
        final reason =
            "$name, excluding ${row['excludeLabel']}, roll ${row['roll']}";
        expect(beat.gesture?.id, row['id'], reason: reason);
        expect(
          beat.gap.inMicroseconds,
          ((row['gapMs'] as num) * 1000).round(),
          reason: reason,
        );
      }
    });

    test('a mood outside the table paces like neutral', () {
      // The JS guarded `CAM_ROTA_GAP_MS[MOODS.includes(mood) ? mood : 'neutral']`
      // against a string that was not a mood. Dart's enum makes that
      // unreachable, so what is left to hold is that the lookup the port does
      // instead covers every mood there is — a missing entry would silently
      // pace a real mood as neutral.
      for (final mood in Mood.values) {
        expect(camRotaGapMs[mood], isNotNull, reason: mood.name);
      }
      final neutral = _rows('camRotaBeat')
          .where((r) => r['mood'] == 'nonsense')
          .toList();
      expect(neutral, isNotEmpty);
      for (final row in neutral) {
        expect(
          camRotaBeat(
            Mood.neutral,
            _roll(row['roll'] as num),
            null,
            _recent(row['excludeLabel'] as String),
          ).gap.inMicroseconds,
          ((row['gapMs'] as num) * 1000).round(),
        );
      }
    });

    test('never repeats either of his last two while the mood has anything '
        'else', () {
      // The reason the memory is TWO: avoiding only the previous gesture
      // leaves A-B-A-B, and the moods this matters most for have a pool
      // dominated by exactly two poses, so that is what it produced.
      for (final mood in Mood.values) {
        final pool = <String>{};
        for (var i = 0; i <= 20; i++) {
          final id = camRotaBeat(mood, _roll(i / 20)).gesture?.id;
          if (id != null) pool.add(id);
        }
        if (pool.length < 3) continue;
        final recent = <String>[];
        for (var i = 0; i < 12; i++) {
          final id = camRotaBeat(
            mood,
            _roll((i * 7 % 20) / 20),
            null,
            recent,
          ).gesture?.id;
          expect(id, isNotNull, reason: mood.name);
          expect(
            recent.take(camRotaMemory),
            isNot(contains(id)),
            reason: '$mood repeated $id inside the memory',
          );
          recent.insert(0, id!);
        }
      }
    });

    test('draws the gesture BEFORE the gap', () {
      // Two draws off one source, and the order is the JS's. Reading the gap
      // first would give a different rota from the same seed — which is the
      // kind of drift a fixture taken with a constant roll cannot see.
      final rolls = <double>[0.99, 0.0];
      var i = 0;
      double next() => rolls[i++];
      final beat = camRotaBeat(Mood.crushed, next);
      expect(i, 2, reason: 'exactly two draws');
      // The gap took the SECOND roll: 0 puts it at the bottom of the band.
      expect(beat.gap.inMilliseconds, camRotaGapMs[Mood.crushed]!.$1);
    });
  });
}
