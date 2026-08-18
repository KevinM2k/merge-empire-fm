/// The manager's mood on the League diorama, against the JS it was ported from
/// — plus the two small tables that ship alongside it.
///
/// The thresholds are the whole point. They are deliberately identical to the
/// ones the match popup uses to pick Coach Colin's post-match line, so a port
/// that is one goal out anywhere has the walker celebrating a result Colin has
/// just called unacceptable. The draw scoring is the fiddly half: an EDGE built
/// from the rating gap, the ground, and whether the game swung, with led and
/// trailed cancelling out on purpose.
///
/// See `tool/dump_manager_mood_reference.mjs`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/kit_palette.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/data/pgs_achievements.dart';

final Map<String, dynamic> _ref =
    jsonDecode(
          File('test/fixtures/manager_mood_reference.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

List<Map<String, dynamic>> _rows(String key) =>
    (_ref[key] as List).cast<Map<String, dynamic>>();

Map<String, dynamic> _section(String key) => _ref[key] as Map<String, dynamic>;

final int _now = _ref['now'] as int;

/// The JS reported a mood as a plain string.
Mood _mood(String name) => Mood.values.firstWhere((m) => m.name == name);

/// A roll that always returns the same number, matching the dump's closures.
double Function() _roll(num value) =>
    () => value.toDouble();

/// A stored result, matching the dump script's builder.
Map<String, dynamic> _result([Map<String, dynamic> over = const {}]) => {
  'won': false,
  'drawn': false,
  'isHome': true,
  'ourGoals': 1,
  'theirGoals': 1,
  'playedAt': _now,
  ...over,
};

/// The save each `derive` row was read from.
Map<String, dynamic>? _deriveState(String label) => switch (label) {
  'noState' => null,
  'noProgression' => <String, dynamic>{},
  'noResult' => {
    'progression': <String, dynamic>{
      'seasonWins': 0,
      'seasonDraws': 0,
      'seasonLosses': 0,
    },
  },
  'freshWin' => {
    'progression': <String, dynamic>{
      'lastMatchResult': _result({'won': true, 'ourGoals': 4, 'theirGoals': 0}),
    },
  },
  'freshNarrowLoss' => {
    'progression': <String, dynamic>{
      'lastMatchResult': _result({'ourGoals': 1, 'theirGoals': 2}),
    },
  },
  'freshHiding' => {
    'progression': <String, dynamic>{
      'lastMatchResult': _result({'ourGoals': 0, 'theirGoals': 4}),
    },
  },
  'freshDraw' => {
    'progression': <String, dynamic>{
      'lastMatchResult': _result({'drawn': true}),
    },
  },
  'justFresh' => {
    'progression': <String, dynamic>{
      'lastMatchResult': _result({'won': true}),
    },
  },
  'justStale' => {
    'progression': <String, dynamic>{
      'lastMatchResult': _result({'won': true}),
      'seasonWins': 9,
      'seasonDraws': 0,
      'seasonLosses': 1,
    },
  },
  'stampOnProgression' => {
    'progression': <String, dynamic>{
      'lastMatchAt': _now,
      // No stamp on the result itself, which is the older shape.
      'lastMatchResult': {
        'won': true,
        'drawn': false,
        'isHome': true,
        'ourGoals': 1,
        'theirGoals': 1,
      },
    },
  },
  'noStampAnywhere' => {
    'progression': <String, dynamic>{
      'lastMatchResult': _result({'won': true, 'playedAt': 0}),
      'seasonWins': 5,
      'seasonDraws': 1,
      'seasonLosses': 1,
    },
  },
  'titleForm' => {
    'progression': <String, dynamic>{
      'seasonWins': 8,
      'seasonDraws': 1,
      'seasonLosses': 1,
    },
  },
  'midTable' => {
    'progression': <String, dynamic>{
      'seasonWins': 4,
      'seasonDraws': 2,
      'seasonLosses': 4,
    },
  },
  'relegationForm' => {
    'progression': <String, dynamic>{
      'seasonWins': 0,
      'seasonDraws': 2,
      'seasonLosses': 8,
    },
  },
  'tooEarlyToTell' => {
    'progression': <String, dynamic>{
      'seasonWins': 0,
      'seasonDraws': 0,
      'seasonLosses': 2,
    },
  },
  'scoreStringHome' => {
    'progression': <String, dynamic>{
      'lastMatchResult': <String, dynamic>{
        'score': '3–0',
        'isHome': true,
        'won': true,
        'playedAt': _now,
      },
    },
  },
  'scoreStringAway' => {
    'progression': <String, dynamic>{
      'lastMatchResult': <String, dynamic>{
        'score': '0–3',
        'isHome': false,
        'won': true,
        'playedAt': _now,
      },
    },
  },
  'unreadableScore' => {
    'progression': <String, dynamic>{
      'lastMatchResult': <String, dynamic>{
        'score': 'nil-nil',
        'playedAt': _now,
      },
    },
  },
  _ => throw ArgumentError(label),
};

/// Every emote the look packs sell.
List<String> get _emoteIds => [
  for (final p in lookPacks)
    for (final item in p.items)
      if (item.startsWith('emote:')) item,
];

Map<String, dynamic>? _ownership(String label) => switch (label) {
  'noState' => null,
  'ownsNothing' => {
    'club': <String, dynamic>{'lookItems': <dynamic>[]},
  },
  'ownsEverything' => {
    'club': <String, dynamic>{'lookItems': _emoteIds},
  },
  _ => throw ArgumentError(label),
};

void main() {
  test('the moods, the window and the rota match the JS', () {
    expect([for (final m in Mood.values) m.name], _ref['moods']);
    expect(freshMs, _ref['freshMs']);
    expect(gestureIds, _ref['gestureIds']);
    expect(ballPlays, _ref['ballPlays']);

    final want = (_ref['gestures'] as List).cast<Map<String, dynamic>>();
    expect(gestures.length, want.length);
    for (var i = 0; i < gestures.length; i++) {
      final g = gestures[i];
      expect(g.id, want[i]['id'], reason: 'gesture $i id');
      expect(g.ms, want[i]['ms'], reason: '${g.id} ms');
      expect(
        {for (final e in g.weight.entries) e.key.name: e.value},
        want[i]['weight'],
        reason: '${g.id} weight',
      );
      expect(g.stops, want[i]['stops'], reason: '${g.id} stops');
      expect(g.fullTime, want[i]['fullTime'], reason: '${g.id} fullTime');
      expect(
        g.celebration,
        want[i]['celebration'],
        reason: '${g.id} celebration',
      );
    }

    final gaps = _section('gestureGapMs');
    for (final entry in gaps.entries) {
      final range = gestureGapMs[_mood(entry.key)]!;
      expect([range.$1, range.$2], entry.value, reason: entry.key);
    }
  });

  test('a celebration only ever carries a happy weight', () {
    // The rule the rota exists to enforce. The robot dance having a neutral
    // weight is what put three actions' worth of joy on the screen after a 2-2
    // the manager was sick about.
    for (final g in gestures.where((g) => g.celebration)) {
      expect(
        g.weight.keys,
        everyElement(anyOf(Mood.elated, Mood.pleased)),
        reason: g.id,
      );
    }
  });

  test('parity — how good a draw was', () {
    for (final row in _rows('moodForDraw')) {
      expect(
        moodForDraw(
          ratingGap: row['ratingGap'] as num,
          isHome: row['isHome'] as bool?,
          led: row['led'] as bool,
          trailed: row['trailed'] as bool,
        ).name,
        row['mood'],
        reason:
            'gap ${row['ratingGap']} home ${row['isHome']} '
            'led ${row['led']} trailed ${row['trailed']}',
      );
    }
    expect(moodForDraw().name, _ref['moodForDrawBare']);
    expect(moodForDraw(ratingGap: double.nan).name, _ref['moodForDrawNaN']);
  });

  test('leading and trailing cancel out', () {
    // A 3-3 that swung both ways is a night at the football, not a grievance.
    expect(moodForDraw(led: true, trailed: true), moodForDraw());
  });

  test('parity — the mood from a scoreline', () {
    for (final row in _rows('moodForScore')) {
      final opts = row['opts'] as Map<String, dynamic>;
      expect(
        moodForScore(
          row['margin'] as int?,
          won: opts['won'] == true,
          drawn: opts['drawn'] == true,
          trophiesEarned: (opts['trophiesEarned'] as num?) ?? 0,
          ratingGap: (opts['ratingGap'] as num?) ?? 0,
          isHome: opts['isHome'] as bool?,
          led: opts['led'] == true,
          trailed: opts['trailed'] == true,
        ).name,
        row['mood'],
        reason: '${row['label']} by ${row['margin']}',
      );
    }
    for (final row in _rows('moodForScoreBare')) {
      expect(
        moodForScore(row['margin'] as int?).name,
        row['mood'],
        reason: 'bare ${row['margin']}',
      );
    }
  });

  test('parity — the mood off a save', () {
    for (final row in _rows('derive')) {
      final label = row['label'] as String;
      final got = deriveMood(_deriveState(label), row['at'] as int);
      expect(got.mood.name, row['mood'], reason: '$label mood');
      expect(got.fresh, row['fresh'], reason: '$label fresh');
    }
  });

  test('parity — picking a gesture', () {
    for (final row in _rows('pickGesture')) {
      final got = pickGesture(
        _mood(row['mood'] as String),
        _roll(row['roll'] as num),
        _ownership(row['stateLabel'] as String),
        (fullTime: row['fullTime'] as bool, exclude: const []),
      );
      expect(
        got?.id,
        row['id'],
        reason:
            '${row['mood']} ${row['stateLabel']} '
            'fullTime ${row['fullTime']} at ${row['roll']}',
      );
    }
  });

  test('parity — the exclude list filters rather than rerolls', () {
    // A crushed manager's pool is mostly two gestures, and rerolling until one
    // of them is not picked lands back on them often enough to read as a loop.
    for (final row in _rows('pickGestureExcluded')) {
      final got = pickGesture(
        _mood(row['mood'] as String),
        _roll(row['roll'] as num),
        null,
        (fullTime: false, exclude: (row['exclude'] as List).cast<String>()),
      );
      expect(got?.id, row['id'], reason: '${row['label']} at ${row['roll']}');
    }
  });

  test('excluding everything is ignored rather than silencing him', () {
    // With two owned gestures and a memory of two, alternating is the only
    // thing left.
    expect(
      pickGesture(Mood.crushed, _roll(0.5), null, (
        fullTime: false,
        exclude: gestureIds,
      )),
      isNotNull,
    );
  });

  test('parity — looking a gesture up by id', () {
    for (final entry in _section('getGesture').entries) {
      expect(getGesture(entry.key)?.id, entry.value, reason: entry.key);
    }
    expect(getGesture(null)?.id, _ref['getGestureNull']);
  });

  test('parity — the gap before the next gesture', () {
    for (final row in _rows('nextGestureDelay')) {
      final name = row['mood'] as String;
      // An unknown mood falls back to the neutral range.
      final mood = name == 'not_a_mood' ? Mood.neutral : _mood(name);
      expect(
        nextGestureDelay(mood, _roll(row['roll'] as num)),
        row['ms'],
        reason: '$name at ${row['roll']}',
      );
    }
  });

  test('parity — what he does with an arriving ball', () {
    for (final row in _rows('pickBallPlay')) {
      final name = row['mood'] as String;
      final mood = name == 'not_a_mood' ? Mood.neutral : _mood(name);
      expect(
        pickBallPlay(mood, _roll(row['roll'] as num)),
        row['play'],
        reason: '$name at ${row['roll']}',
      );
    }
  });

  test('a happy manager never ignores the ball, and a beaten one might', () {
    // The tilt the weights exist for, stated as a property.
    final elated = {
      for (var i = 0; i < 100; i++) pickBallPlay(Mood.elated, _roll(i / 100)),
    };
    final crushed = {
      for (var i = 0; i < 100; i++) pickBallPlay(Mood.crushed, _roll(i / 100)),
    };
    expect(elated, isNot(contains('ignore')));
    expect(crushed, contains('ignore'));
  });

  test('without an injected roll it still picks something sensible', () {
    for (var i = 0; i < 50; i++) {
      for (final mood in Mood.values) {
        expect(gestureIds, contains(pickGesture(mood)!.id));
        expect(ballPlays, contains(pickBallPlay(mood)));
        final range = gestureGapMs[mood]!;
        expect(nextGestureDelay(mood), inInclusiveRange(range.$1, range.$2));
      }
    }
  });

  test('parity — the Play Games achievement map', () {
    final want = _section('pgsAchievementIds');
    expect(pgsAchievementIds.keys.toList(), want.keys.toList());
    for (final entry in want.entries) {
      expect(pgsAchievementIds[entry.key], entry.value, reason: entry.key);
      expect(pgsAchievementId(entry.key), entry.value, reason: entry.key);
    }
    expect(pgsAchievementId('not_an_achievement'), isNull);
    // An unmapped entry is silently skipped rather than reported as an id.
    expect(
      pgsAchievementIds.values.where((v) => v != null).length,
      want.values.where((v) => v != null).length,
    );
  });

  test('parity — the kit palette', () {
    final kit = _section('kit');
    expect(defaultKitColor, kit['defaultColor']);
    expect(kitPatterns.keys.toList(), (kit['patterns'] as Map).keys.toList());

    for (final row in (kit['rows'] as List).cast<Map<String, dynamic>>()) {
      final id = row['kit'];
      expect(kitSolidColor(id), row['solid'], reason: 'solid for $id');
      final stripes = kitStripes(id);
      expect(
        stripes == null ? null : [stripes.$1, stripes.$2],
        row['stripes'],
        reason: 'stripes for $id',
      );
      expect(kitSwatchCss(id), row['swatch'], reason: 'swatch for $id');
    }
  });

  test('a swatch and the shirt are built from the same bands', () {
    // They used to be two hand-written copies that had already drifted apart.
    for (final entry in kitPatterns.entries) {
      final stripes = entry.value.stripes;
      if (stripes == null) continue;
      expect(kitSwatchCss(entry.key), contains(stripes.$1));
      expect(kitSwatchCss(entry.key), contains(stripes.$2));
    }
  });
}
