/// The sky changes, and it changes for the right reasons.
///
/// Two modes with nothing in common: a live reading is the player's real sky and
/// HOLDS until a fresher one lands, while the seasonal model runs a spell, goes
/// clear, and rolls again. Both are timers, so both are driven here rather than
/// waited on.
library;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/weather_engine.dart';
import 'package:merge_empire_fc/services/weather_cycle.dart';
import 'package:merge_empire_fc/util/time.dart';

void main() {
  /// Mid-July, so the seasonal model is on a known table: temperate, summer.
  /// The month comes off the LOCAL calendar, and midday keeps every zone on the
  /// same side of it.
  final july = DateTime(2026, 7, 15, 12).millisecondsSinceEpoch;

  setUp(() => setClock(() => july));
  tearDown(resetClock);

  /// A scripted RNG. The engine takes one draw for the roll, one for the spell
  /// and one for the gap, so a fixed value makes the whole schedule arithmetic.
  double Function() fixed(double v) =>
      () => v;

  Map<String, dynamic> saveWithLive({
    required String condition,
    required int fetchedAt,
    num windKph = 0,
  }) => {
    'weather': {
      'lat': 51.51,
      'lon': -0.13,
      'live': {
        'condition': condition,
        'fetchedAt': fetchedAt,
        'windKph': windKph,
      },
    },
  };

  group('a live reading', () {
    test('is shown, and is not rescheduled out from under itself', () {
      fakeAsync((async) {
        final seen = <String>[];
        WeatherCycle(
          saveState: () =>
              saveWithLive(condition: 'storm', fetchedAt: july, windKph: 42),
          onCondition: (v) => seen.add('${v.condition}/${v.source}'),
        ).start();

        expect(seen, ['storm/live'], reason: 'the real sky was not shown');

        // A spell would have expired inside this window. A live reading has no
        // spell: it is not our timer's to change.
        async.elapse(const Duration(minutes: 4, seconds: 59));
        expect(seen, ['storm/live']);

        // The recheck only looks again; the answer is the same until a fresher
        // reading lands.
        async.elapse(const Duration(seconds: 2));
        expect(seen, ['storm/live', 'storm/live']);
      });
    });

    test(
      'carries the measured wind speed, which the seasonal model cannot',
      () {
        fakeAsync((async) {
          WeatherView? view;
          final cycle = WeatherCycle(
            saveState: () =>
                saveWithLive(condition: 'wind', fetchedAt: july, windKph: 58),
            onCondition: (v) => view = v,
          )..start();
          expect(view?.windKph, 58);
          cycle.stop();
        });
      },
    );

    test('a stale one falls through to the model', () {
      fakeAsync((async) {
        WeatherView? view;
        final cycle = WeatherCycle(
          saveState: () => saveWithLive(
            condition: 'storm',
            // Older than `liveStaleMs`.
            fetchedAt: july - liveStaleMs - 1,
          ),
          onCondition: (v) => view = v,
          rand: fixed(0),
        )..start();
        expect(view?.source, 'seasonal');
        cycle.stop();
      });
    });
  });

  group('the seasonal model', () {
    test('runs a spell, goes clear, and rolls again', () {
      fakeAsync((async) {
        final seen = <String>[];
        final cycle = WeatherCycle(
          saveState: () => <String, dynamic>{
            'weather': <String, dynamic>{'lat': 51.51},
          },
          onCondition: (v) => seen.add(v.condition),
          // 0.5 of the temperate summer table is `cloudy`, whose spell is
          // 25–50s and whose gap is 30–70s — so 37.5s then 50s.
          rand: fixed(0.5),
        )..start();

        expect(seen, ['cloudy']);

        async.elapse(const Duration(milliseconds: 37499));
        expect(seen, ['cloudy'], reason: 'the spell ended early');

        async.elapse(const Duration(milliseconds: 2));
        expect(seen, ['cloudy', 'clear'], reason: 'the spell never ended');

        // The spell fired at 37500, so the gap runs to 87500 — not to 87501.
        async.elapse(const Duration(milliseconds: 49998));
        expect(seen.length, 2, reason: 'it re-rolled before the gap was up');

        async.elapse(const Duration(milliseconds: 2));
        expect(seen, ['cloudy', 'clear', 'cloudy']);
        cycle.stop();
      });
    });

    test('and `clear` has no spell of its own — it IS the gap', () {
      fakeAsync((async) {
        final seen = <String>[];
        final cycle = WeatherCycle(
          saveState: () => <String, dynamic>{
            'weather': <String, dynamic>{'lat': 51.51},
          },
          onCondition: (v) => seen.add(v.condition),
          rand: fixed(0),
        )..start();

        expect(seen, ['clear']);
        // Straight to the gap: 30s at the bottom of the range. A `clear` that
        // was also scheduled as a spell would sit there for twice as long.
        async.elapse(const Duration(milliseconds: 29999));
        expect(seen.length, 1);
        async.elapse(const Duration(milliseconds: 2));
        expect(seen, ['clear', 'clear']);
        cycle.stop();
      });
    });
  });

  group('starting and stopping', () {
    test('a stopped cycle schedules nothing more', () {
      fakeAsync((async) {
        final seen = <String>[];
        WeatherCycle(
            saveState: () => <String, dynamic>{
              'weather': <String, dynamic>{'lat': 51.51},
            },
            onCondition: (v) => seen.add(v.condition),
            rand: fixed(0.5),
          )
          ..start()
          ..stop();

        async.elapse(const Duration(minutes: 10));
        expect(seen, [
          'cloudy',
        ], reason: 'the first turn stands; nothing after it should fire');
      });
    });

    test('and starting twice does not run two of them', () {
      fakeAsync((async) {
        final seen = <String>[];
        final cycle =
            WeatherCycle(
                saveState: () => <String, dynamic>{
                  'weather': <String, dynamic>{'lat': 51.51},
                },
                onCondition: (v) => seen.add(v.condition),
                rand: fixed(0.5),
              )
              ..start()
              ..start();

        expect(seen.length, 1, reason: 'the second start emitted as well');
        async.elapse(const Duration(milliseconds: 37501));
        expect(
          seen.length,
          2,
          reason: 'two schedules would have ended two spells',
        );
        cycle.stop();
      });
    });

    test('asks for a fresh reading when the cached one is due', () {
      fakeAsync((async) {
        var asked = 0;
        final cycle = WeatherCycle(
          saveState: () => <String, dynamic>{
            'weather': <String, dynamic>{'lat': 51.51},
          },
          onCondition: (_) {},
          refreshLive: () => asked++,
          rand: fixed(0.5),
        )..start();
        expect(asked, 1, reason: 'a save with no reading at all is due one');
        cycle.stop();
      });
    });

    test('and does not, when it is not', () {
      fakeAsync((async) {
        var asked = 0;
        final cycle = WeatherCycle(
          saveState: () =>
              saveWithLive(condition: 'rain', fetchedAt: july - 1000),
          onCondition: (_) {},
          refreshLive: () => asked++,
        )..start();
        expect(asked, 0, reason: 'a reading a second old was refetched');
        cycle.stop();
      });
    });
  });
}
