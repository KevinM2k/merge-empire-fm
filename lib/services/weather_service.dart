/// Live weather for the diorama, from Open-Meteo. Ported from
/// `services/weatherService.js`.
///
/// **THE ENGINE HAS BEEN WAITING FOR THIS.** `engine/weather_engine.dart` has
/// carried a three-tier model since M1 — live, then seasonal, then a seeded roll
/// — and its first tier reads `state.weather.live`, which nothing has ever
/// written. So the game has always fallen through to the seasonal model, and the
/// weather over the pitch has never had anything to do with the weather outside.
/// This is the missing writer.
///
/// **NO LOCATION PERMISSION IS ASKED FOR ANYWHERE IN THIS FILE.** The
/// coordinates come from the DEVICE TIMEZONE via `data/geo_zones.dart`, rounded
/// to two decimal places — which is a city, not a person, and all the precision a
/// backdrop could use. Nothing that identifies the player is sent, and there is
/// no account, no key and no signup: a decorative sky cannot justify a credential
/// to rotate or a bill to watch, which is exactly why Open-Meteo is the one that
/// fits.
///
/// **EVERYTHING HERE IS BEST-EFFORT AND NOTHING HERE THROWS.** Offline, DNS
/// failure, a captive portal, a timeout, malformed JSON — all the same outcome as
/// far as the scene is concerned: the seasonal model is already showing something
/// perfectly good. A failed sky is not an error worth surfacing and must never
/// block boot.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:merge_empire_fc/data/geo_zones.dart';
import 'package:merge_empire_fc/engine/weather_engine.dart';
import 'package:merge_empire_fc/util/time.dart';

/// Five seconds. Short on purpose: if the sky cannot be reached in five, waiting
/// longer buys nothing and holds a request open on a phone radio.
const Duration weatherTimeout = Duration(seconds: 5);

/// How long to leave it after a failure, so a downed API or a captive portal is
/// not retried every time the Play tab is opened.
const int weatherFailureBackoffMs = 15 * 60 * 1000;

const String _endpoint = 'https://api.open-meteo.com/v1/forecast';

/// A JSON GET. Injected so every rule in this file is testable without a socket.
typedef WeatherFetch = Future<Map<String, dynamic>?> Function(Uri url);

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

Map<String, dynamic> _branch(Map<String, dynamic> owner, String key) {
  final existing = _map(owner[key]);
  if (existing != null) return existing;
  final made = <String, dynamic>{};
  owner[key] = made;
  return made;
}

/// The default fetch: `dart:io`, because a decorative call does not justify a
/// dependency either.
Future<Map<String, dynamic>?> httpGetJson(Uri url) async {
  final client = HttpClient()..connectionTimeout = weatherTimeout;
  try {
    final request = await client.getUrl(url).timeout(weatherTimeout);
    final response = await request.close().timeout(weatherTimeout);
    if (response.statusCode != 200) return null;
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(weatherTimeout);
    return _map(jsonDecode(body));
  } on Object {
    // Every failure mode is the same failure mode here — see the note at the top.
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Make sure the save knows ROUGHLY where the player is.
///
/// Derived from the timezone, stored once, and refreshed if the zone changes
/// because the player has travelled — at which point any cached reading is for
/// the wrong place and is dropped.
Map<String, dynamic> ensureWeatherLocation(
  Map<String, dynamic> state, {
  required String? timeZone,
  String? region,
}) {
  final weather = _branch(state, 'weather');
  if (weather['timeZone'] == timeZone && weather['lat'] is num) {
    return weather;
  }
  final coords = resolveCoords(timeZone, region);
  weather['timeZone'] = timeZone;
  weather['lat'] = coords.lat;
  weather['lon'] = coords.lon;
  weather['locationSource'] = coords.source;
  // The coordinates moved, so the cached sky is somebody else's.
  if (weather['live'] != null) weather['live'] = null;
  return weather;
}

/// Two decimal places is a city. See the note at the top of the file.
Uri weatherUrl(double lat, double lon) => Uri.parse(
  '$_endpoint?latitude=${lat.toStringAsFixed(2)}'
  '&longitude=${lon.toStringAsFixed(2)}'
  '&current=weather_code,wind_speed_10m,temperature_2m'
  '&wind_speed_unit=kmh&temperature_unit=celsius&timezone=UTC',
);

/// Fetch the current conditions and cache them on `state.weather.live`.
///
/// Resolves to the stored reading, or null when the sky could not be reached —
/// callers treat null as "carry on with the seasonal model", never as an error.
///
/// [onStored] is how the save gets scheduled: this file mutates the map it was
/// handed rather than reaching for a global, because "reads the argument, writes
/// a singleton" is not a contract worth keeping.
Future<Map<String, dynamic>?> refreshLiveWeather(
  Map<String, dynamic> state, {
  required String? timeZone,
  String? region,
  WeatherFetch fetch = httpGetJson,
  void Function()? onStored,
  bool force = false,
}) async {
  final weather = ensureWeatherLocation(
    state,
    timeZone: timeZone,
    region: region,
  );
  onStored?.call();
  final at = now();

  if (!force) {
    if (!shouldRefreshLive(state, at)) return _map(weather['live']);
    final failedAt = weather['failedAt'];
    if (failedAt is num && at - failedAt < weatherFailureBackoffMs) {
      return _map(weather['live']);
    }
  }

  final lat = (weather['lat'] as num?)?.toDouble();
  final lon = (weather['lon'] as num?)?.toDouble();
  if (lat == null || lon == null) return null;

  Map<String, dynamic>? json;
  try {
    json = await fetch(weatherUrl(lat, lon));
  } on Object {
    json = null;
  }
  final current = _map(json?['current']);
  final code = current?['weather_code'];
  if (code is! num) {
    weather['failedAt'] = at;
    onStored?.call();
    return null;
  }

  final wind = current?['wind_speed_10m'];
  final windKph = wind is num ? wind : 0;
  // **NULL rather than zero when the API leaves it out.** 0°C is a perfectly
  // plausible reading, so a missing thermometer must not read as a freezing one:
  // `conditionFromWmo` keeps a cloudless sky at `clear` rather than promoting it
  // to `sunny` on a temperature it never got.
  final temp = current?['temperature_2m'];
  final tempC = temp is num ? temp : null;

  final live = <String, dynamic>{
    'condition': conditionFromWmo(code.toInt(), windKph, tempC),
    'code': code.toInt(),
    'windKph': windKph,
    'tempC': tempC,
    'fetchedAt': at,
  };
  weather['live'] = live;
  weather['failedAt'] = null;
  onStored?.call();
  return live;
}
