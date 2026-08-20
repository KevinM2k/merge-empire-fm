/// Live weather, and the rules around asking for it.
///
/// **The engine has had a live tier since M1 and nothing ever wrote to it**, so
/// the weather over the pitch has never had anything to do with the weather
/// outside. What is worth testing about the writer is not the HTTP — it is the
/// restraint: that no location is asked for, that a city is all that is sent,
/// that a failure is silent, and that a downed API is not hammered.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/services/weather_service.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic> _weather(Map<String, dynamic> state) =>
    state['weather'] as Map<String, dynamic>;

/// A fetch that answers with one reading, and counts the calls.
({WeatherFetch fetch, List<Uri> calls}) answering(
  Map<String, dynamic>? current,
) {
  final calls = <Uri>[];
  return (
    calls: calls,
    fetch: (url) async {
      calls.add(url);
      return current == null ? null : {'current': current};
    },
  );
}

void main() {
  group('where the player is', () {
    test('comes from the TIMEZONE, and no permission is asked for', () {
      // The whole point: a decorative sky cannot justify a location prompt.
      final state = createDefaultState();
      ensureWeatherLocation(state, timeZone: 'Europe/London');
      expect(_weather(state)['lat'], isA<num>());
      expect(_weather(state)['lon'], isA<num>());
      expect(_weather(state)['timeZone'], 'Europe/London');
    });

    test('and it is stored once rather than resolved every time', () {
      final state = createDefaultState();
      ensureWeatherLocation(state, timeZone: 'Europe/London');
      _weather(state)['lat'] = 51.99;
      ensureWeatherLocation(state, timeZone: 'Europe/London');
      expect(_weather(state)['lat'], 51.99, reason: 'it was re-resolved');
    });

    test('a zone CHANGE drops the cached sky — it is somebody else\'s', () {
      final state = createDefaultState();
      ensureWeatherLocation(state, timeZone: 'Europe/London');
      _weather(state)['live'] = {'condition': 'rain'};
      ensureWeatherLocation(state, timeZone: 'Australia/Sydney');
      expect(_weather(state)['live'], isNull);
      expect(_weather(state)['timeZone'], 'Australia/Sydney');
    });

    test('and an unknown zone still resolves to somewhere', () {
      // A wrong guess costs a slightly wrong sky and nothing else, so there is
      // no failure path here at all.
      final state = createDefaultState();
      ensureWeatherLocation(state, timeZone: 'Nowhere/Atlantis', region: 'GB');
      expect(_weather(state)['lat'], isA<num>());
    });
  });

  group('what is sent', () {
    test('a CITY, not a person — two decimal places and nothing else', () async {
      final state = createDefaultState();
      final http = answering({'weather_code': 61, 'wind_speed_10m': 12.0});
      await refreshLiveWeather(
        state,
        timeZone: 'Europe/London',
        fetch: http.fetch,
      );
      final url = http.calls.single;
      expect(url.host, 'api.open-meteo.com');
      // Two decimals is about a kilometre.
      for (final key in ['latitude', 'longitude']) {
        final value = url.queryParameters[key]!;
        expect(value.split('.').last.length, 2, reason: key);
      }
      // And nothing that identifies anyone.
      expect(
        url.queryParameters.keys.toSet(),
        {
          'latitude',
          'longitude',
          'current',
          'wind_speed_unit',
          'temperature_unit',
          'timezone',
        },
      );
    });
  });

  group('the reading', () {
    test('is stored as a condition the engine can use', () async {
      final state = createDefaultState();
      final http = answering({
        'weather_code': 61,
        'wind_speed_10m': 9.0,
        'temperature_2m': 11.0,
      });
      final live = await refreshLiveWeather(
        state,
        timeZone: 'Europe/London',
        fetch: http.fetch,
      );
      expect(live, isNotNull);
      expect(live!['condition'], isA<String>());
      expect(live['code'], 61);
      expect(_weather(state)['live'], live);
    });

    test('a missing thermometer is NULL, not zero', () async {
      // 0°C is a perfectly plausible reading, so a missing one must not read as
      // a freezing one — `conditionFromWmo` falls back to the season instead of
      // promoting a cloudless sky to `sunny` on a temperature it never got.
      final state = createDefaultState();
      final http = answering({'weather_code': 0, 'wind_speed_10m': 4.0});
      final live = await refreshLiveWeather(
        state,
        timeZone: 'Europe/London',
        fetch: http.fetch,
      );
      expect(live!['tempC'], isNull);
    });
  });

  group('failure is silent', () {
    test('an unreachable sky returns null and never throws', () async {
      final state = createDefaultState();
      final live = await refreshLiveWeather(
        state,
        timeZone: 'Europe/London',
        fetch: (_) async => throw Exception('captive portal'),
      );
      expect(live, isNull);
      expect(_weather(state)['failedAt'], isA<num>());
    });

    test('malformed JSON is the same outcome', () async {
      final state = createDefaultState();
      final live = await refreshLiveWeather(
        state,
        timeZone: 'Europe/London',
        fetch: (_) async => {'current': {'weather_code': 'sunny-ish'}},
      );
      expect(live, isNull);
      expect(_weather(state)['failedAt'], isA<num>());
    });

    test('and a downed API is NOT hammered', () async {
      // A captive portal or an outage must not be retried every time the Play
      // tab is opened.
      final state = createDefaultState();
      final http = answering(null);
      await refreshLiveWeather(
        state,
        timeZone: 'Europe/London',
        fetch: http.fetch,
      );
      expect(http.calls, hasLength(1));
      await refreshLiveWeather(
        state,
        timeZone: 'Europe/London',
        fetch: http.fetch,
      );
      expect(http.calls, hasLength(1), reason: 'it retried inside the backoff');

      // Past the backoff, it tries again.
      _weather(state)['failedAt'] = now() - weatherFailureBackoffMs - 1;
      await refreshLiveWeather(
        state,
        timeZone: 'Europe/London',
        fetch: http.fetch,
      );
      expect(http.calls, hasLength(2));
    });

    test('and a fresh reading is not re-fetched', () async {
      final state = createDefaultState();
      final http = answering({'weather_code': 3, 'wind_speed_10m': 5.0});
      await refreshLiveWeather(
        state,
        timeZone: 'Europe/London',
        fetch: http.fetch,
      );
      await refreshLiveWeather(
        state,
        timeZone: 'Europe/London',
        fetch: http.fetch,
      );
      expect(http.calls, hasLength(1));
      // Unless it is asked for outright.
      await refreshLiveWeather(
        state,
        timeZone: 'Europe/London',
        fetch: http.fetch,
        force: true,
      );
      expect(http.calls, hasLength(2));
    });
  });

  test('the save is scheduled rather than written from here', () async {
    // This file mutates the map it was handed rather than reaching for the
    // gameState singleton — "reads the argument, writes a global" is not a
    // contract worth keeping.
    final state = createDefaultState();
    var scheduled = 0;
    await refreshLiveWeather(
      state,
      timeZone: 'Europe/London',
      fetch: answering({'weather_code': 61, 'wind_speed_10m': 8.0}).fetch,
      onStored: () => scheduled++,
    );
    expect(scheduled, greaterThan(0));
  });
}
