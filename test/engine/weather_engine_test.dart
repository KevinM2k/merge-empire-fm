/// The weather engine, against the JS it was ported from.
///
/// The engine takes its clock and its randomness as arguments, so nothing here
/// needs a seam or a seed — every number is reproducible from the inputs. The
/// risk it actually carries is ORDER: `rollSeasonalCondition` walks a weight map
/// subtracting as it goes, so the same weights visited in a different order hand
/// back a different sky for the same roll. The sweep below asks every band and
/// season at twenty points across the range, which pins the walk as well as the
/// weights.
///
/// Timestamps are noon UTC on the 15th, so the local month is the same one in
/// whatever timezone the suite runs in.
///
/// See `tool/dump_weather_reference.mjs`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/weather_engine.dart';

final Map<String, dynamic> _ref =
    jsonDecode(File('test/fixtures/weather_reference.json').readAsStringSync())
        as Map<String, dynamic>;

List<Map<String, dynamic>> _rows(String key) =>
    (_ref[key] as List).cast<Map<String, dynamic>>();

/// A roll that always returns [value] — the JS passed the same closure.
double Function() _roll(double value) =>
    () => value;

final int _now = DateTime.utc(2026, 6, 15, 12).millisecondsSinceEpoch;

int _at(int month) =>
    DateTime.utc(2026, month + 1, 15, 12).millisecondsSinceEpoch;

/// The live readings the reference built its cases from, by label.
Map<String, dynamic>? _live(String label) => switch (label) {
  'null' => null,
  'noFetchedAt' => {'condition': 'rain'},
  'fetchedAtNotANumber' => {'condition': 'rain', 'fetchedAt': 'soon'},
  'unknownCondition' => {'condition': 'hail', 'fetchedAt': _now},
  'fresh' => {'condition': 'rain', 'fetchedAt': _now},
  'justInsideStale' => {
    'condition': 'rain',
    'fetchedAt': _now - liveStaleMs + 1,
  },
  'exactlyStale' => {'condition': 'rain', 'fetchedAt': _now - liveStaleMs},
  'fromTheFuture' => {'condition': 'rain', 'fetchedAt': _now + 60000},
  _ => throw ArgumentError(label),
};

Map<String, dynamic>? _refreshState(String label) => switch (label) {
  'noState' => null,
  'noWeather' => <String, dynamic>{},
  'noLive' => {'weather': <String, dynamic>{}},
  'noFetchedAt' => {
    'weather': {'live': <String, dynamic>{}},
  },
  'justFetched' => {
    'weather': {
      'live': {'fetchedAt': _now},
    },
  },
  'justInside' => {
    'weather': {
      'live': {'fetchedAt': _now - liveRefreshMs + 1},
    },
  },
  'exactlyDue' => {
    'weather': {
      'live': {'fetchedAt': _now - liveRefreshMs},
    },
  },
  _ => throw ArgumentError(label),
};

Map<String, dynamic>? _resolveState(String label) => switch (label) {
  'live' => {
    'weather': {
      'live': {'condition': 'storm', 'fetchedAt': _now, 'windKph': 44},
    },
  },
  'liveNoWind' => {
    'weather': {
      'live': {'condition': 'fog', 'fetchedAt': _now},
    },
  },
  'stale' => {
    'weather': {
      'lat': 51.51,
      'live': {'condition': 'storm', 'fetchedAt': _now - liveStaleMs},
    },
  },
  'noLiveTemperate' => {
    'weather': {'lat': 51.51},
  },
  'noLiveTropical' => {
    'weather': {'lat': 1.35},
  },
  'noLiveSouthern' => {
    'weather': {'lat': -33.87},
  },
  'noWeatherBranch' => <String, dynamic>{},
  'nullState' => null,
  _ => throw ArgumentError(label),
};

Map<String, dynamic>? _tempState(String label) => switch (label) {
  'liveWarm' => {
    'weather': {
      'lat': 51.51,
      'live': {'condition': 'clear', 'fetchedAt': _now, 'tempC': 26.5},
    },
  },
  'liveFreezing' => {
    'weather': {
      'lat': 51.51,
      'live': {'condition': 'snow', 'fetchedAt': _now, 'tempC': -4},
    },
  },
  'liveNoTemp' => {
    'weather': {
      'lat': 51.51,
      'live': {'condition': 'rain', 'fetchedAt': _now},
    },
  },
  'staleLive' => {
    'weather': {
      'lat': 51.51,
      'live': {
        'condition': 'clear',
        'fetchedAt': _now - liveStaleMs,
        'tempC': 26.5,
      },
    },
  },
  'seasonalTemperate' => {
    'weather': {'lat': 51.51},
  },
  'seasonalTropical' => {
    'weather': {'lat': 1.35},
  },
  'seasonalCold' => {
    'weather': {'lat': 59.91},
  },
  'seasonalSouthern' => {
    'weather': {'lat': -33.87},
  },
  'noWeather' => <String, dynamic>{},
  _ => throw ArgumentError(label),
};

void main() {
  test('the condition set and the constants match the JS', () {
    expect(conditions, _ref['conditions']);
    expect(seasons, _ref['seasons']);
    final want = _ref['constants'] as Map<String, dynamic>;
    expect(liveRefreshMs, want['liveRefreshMs']);
    expect(liveStaleMs, want['liveStaleMs']);
    expect(windyKph, want['windyKph']);
    expect(sunnyC, want['sunnyC']);
    expect(coldC, want['coldC']);
    expect(hotC, want['hotC']);
    expect(underdressedAt, want['underdressedAt']);
    expect(overdressedAt, want['overdressedAt']);
    expect(maxWindAccel, want['maxWindAccel']);
  });

  test('sunny and hot are the same temperature', () {
    // Sunny exists to mean "hot enough that a coat is a mistake". If the two
    // ever drifted apart the scene would put a blazing sun over a manager
    // perfectly comfortable in his overcoat.
    expect(sunnyC, hotC);
  });

  test('parity — the season at every month, in both hemispheres', () {
    for (final row in _rows('getSeason')) {
      expect(
        getSeason(row['monthIndex'] as num, (row['lat'] as num).toDouble()),
        row['season'],
        reason: 'month ${row['monthIndex']} at ${row['lat']}',
      );
    }
    // A caller with no location still gets northern seasons rather than
    // nothing: the default latitude is London.
    expect([getSeason(0), getSeason(6)], _ref['getSeasonDefaultLat']);
  });

  test('parity — the weight table in force for each band and season', () {
    for (final row in _rows('weightsFor')) {
      expect(
        weightsFor((row['lat'] as num).toDouble(), row['monthIndex'] as num),
        row['weights'],
        reason: '${row['band']} ${row['season']}',
      );
    }
  });

  test('parity — the seasonal roll, twenty points across every table', () {
    for (final row in _rows('rollSeasonal')) {
      expect(
        rollSeasonalCondition(
          (row['lat'] as num).toDouble(),
          row['monthIndex'] as num,
          _roll((row['roll'] as num).toDouble()),
        ),
        row['condition'],
        reason: '${row['band']} ${row['season']} at ${row['roll']}',
      );
    }
  });

  test('a zero-weight condition is never rolled', () {
    // Snow has a weight of zero everywhere tropical, and the walk subtracts
    // before it compares — so an off-by-one in the comparison would hand a
    // Singapore player a blizzard at exactly one roll in the range.
    for (var i = 0; i <= 1000; i++) {
      final condition = rollSeasonalCondition(1.35, 6, _roll(i / 1000));
      expect(condition, isNot('snow'), reason: 'roll ${i / 1000}');
    }
  });

  test('with no roll injected it uses the platform random', () {
    // The default path is the one the app actually runs on, and it is the only
    // thing here that cannot be pinned to a value — only to the range it has to
    // stay inside.
    for (var i = 0; i < 50; i++) {
      expect(conditions, contains(rollSeasonalCondition(51.51, 6)));
      expect(spellDurationMs('rain'), inInclusiveRange(25000, 55000));
      expect(gapDurationMs(), inInclusiveRange(30000, 70000));
      final resolved = resolveCondition({
        'weather': {'lat': 51.51},
      }, _now);
      expect(conditions, contains(resolved.condition));
      expect(resolved.source, 'seasonal');
    }
  });

  test('parity — WMO codes, with wind and heat layered on top', () {
    for (final row in _rows('wmo')) {
      expect(
        conditionFromWmo(
          row['code'] as int,
          row['windKph'] as num,
          row['tempC'] as num?,
        ),
        row['condition'],
        reason:
            'code ${row['code']} wind ${row['windKph']} '
            'temp ${row['tempC']}',
      );
    }
    for (final row in _rows('wmoDefaults')) {
      expect(
        conditionFromWmo(row['code'] as int),
        row['condition'],
        reason: 'code ${row['code']} bare',
      );
    }
  });

  test('parity — when a live reading can still be trusted', () {
    for (final row in _rows('isLiveUsable')) {
      expect(
        isLiveUsable(_live(row['label'] as String), _now),
        row['usable'],
        reason: '${row['label']}',
      );
    }
  });

  test('parity — when it is worth refetching', () {
    for (final row in _rows('shouldRefreshLive')) {
      expect(
        shouldRefreshLive(_refreshState(row['label'] as String), _now),
        row['refresh'],
        reason: '${row['label']}',
      );
    }
  });

  test('parity — what the scene shows, live or seasonal', () {
    for (final row in _rows('resolveCondition')) {
      final got = resolveCondition(
        _resolveState(row['label'] as String),
        _now,
        _roll((row['roll'] as num).toDouble()),
      );
      final reason = '${row['label']} at ${row['roll']}';
      expect(got.condition, row['condition'], reason: '$reason condition');
      expect(got.source, row['source'], reason: '$reason source');
      expect(got.windKph, row['windKph'], reason: '$reason windKph');
    }
  });

  test('parity — the same save reads differently month by month', () {
    for (final row in _rows('resolveConditionByMonth')) {
      final month = row['month'] as int;
      final got = resolveCondition(
        {
          'weather': {'lat': 59.91},
        },
        _at(month),
        _roll(0.97),
      );
      expect(got.condition, row['condition'], reason: 'month $month');
      expect(got.source, row['source'], reason: 'month $month');
    }
  });

  test('parity — how long a spell and a gap last', () {
    for (final row in _rows('spells')) {
      expect(
        spellDurationMs(
          row['condition'] as String,
          _roll((row['roll'] as num).toDouble()),
        ),
        row['ms'],
        reason: '${row['condition']} at ${row['roll']}',
      );
    }
    for (final row in _rows('gaps')) {
      expect(
        gapDurationMs(_roll((row['roll'] as num).toDouble())),
        row['ms'],
        reason: 'gap at ${row['roll']}',
      );
    }
  });

  test('clear has no spell of its own — it IS the gap', () {
    expect(spellDurationMs('clear', _roll(0.5)), 0);
    expect(gapDurationMs(_roll(0.5)), greaterThan(0));
  });

  test('parity — the temperature estimate', () {
    for (final row in _rows('estimatedTempC')) {
      expect(
        estimatedTempC(
          _tempState(row['label'] as String),
          _at(row['month'] as int),
          row['condition'] as String?,
        ),
        row['tempC'],
        reason: '${row['label']} ${row['condition']} month ${row['month']}',
      );
    }
  });

  test('what the sky is doing overrides the estimate at both ends', () {
    // The player can see the sky and cannot see the thermometer, so a visible
    // blizzard cannot be reported at 13° and a blazing sun cannot be reported
    // at 5°.
    final spring = {
      'weather': {'lat': 51.51},
    };
    expect(estimatedTempC(spring, _at(3)), 13);
    expect(estimatedTempC(spring, _at(3), 'snow'), 0);
    expect(estimatedTempC(spring, _at(3), 'sunny'), sunnyC);
  });

  test('parity — how the manager is coping', () {
    for (final row in _rows('comfort')) {
      expect(
        comfortFor(row['tempC'] as num, row['warmth'] as num),
        row['comfort'],
        reason: '${row['tempC']}° warmth ${row['warmth']}',
      );
    }
  });

  test('both halves have to be true to be uncomfortable', () {
    // A manager in a coat in February is perfectly comfortable, and making him
    // shiver anyway would punish the player for dressing him sensibly.
    expect(comfortFor(-5, overdressedAt), 'ok');
    expect(comfortFor(30, underdressedAt), 'ok');
    expect(comfortFor(-5, underdressedAt), 'cold');
    expect(comfortFor(30, overdressedAt), 'hot');
  });

  test('parity — what the wind does to the ball', () {
    for (final row in _rows('windAccel')) {
      final windKph = row['windKph'] as num?;
      expect(
        windKph == null
            ? windAccelFor(row['condition'] as String)
            : windAccelFor(row['condition'] as String, windKph),
        row['accel'],
        reason: '${row['condition']} at $windKph',
      );
    }
  });

  test('only wind and storms move the ball at all', () {
    for (final condition in conditions) {
      final moves = windAccelFor(condition, 80) > 0;
      expect(
        moves,
        condition == 'wind' || condition == 'storm',
        reason: condition,
      );
    }
  });
}
