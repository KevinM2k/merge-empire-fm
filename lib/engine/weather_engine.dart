/// What the sky is doing over the League diorama. Ported from
/// `../merge-empire-fc/src/engine/weatherEngine.js`.
///
/// Two sources, in priority order:
///
/// 1. LIVE — the actual weather where the player is, fetched from Open-Meteo by
///    the weather service and cached at `state.weather.live`. When it is raining
///    outside, it rains on the pitch. Live weather is STICKY: it holds until the
///    next fetch, because that is what real weather does — it does not flick on
///    and off every forty seconds.
/// 2. SEASONAL — a weighted roll from the player's month and climate band, used
///    whenever there is no usable live reading (offline, fetch failed, first
///    launch, or the reading has gone stale). Deliberately NOT a degraded mode:
///    it is the original "occasional shower" rhythm with the whole condition set
///    behind it, so the scene stays alive on a plane.
///
/// Pure by construction — no fetch, and no clock of its own: `nowMs` and `rand`
/// are always passed in, so every branch is testable.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/geo_zones.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

final math.Random _rng = math.Random();

/// Mirrors JS `Math.random()`, not the seeded gameplay stream: the weather is
/// decorative and nothing about a match depends on it.
double _defaultRand() => _rng.nextDouble();

/// Every condition the diorama can render.
///
/// `clear` and `sunny` are both dry cloudless skies and are deliberately NOT the
/// same thing: clear is a pleasant day, sunny is a HOT one. Only sunny puts a
/// sun in the sky, and only sunny guarantees a temperature at or above
/// [sunnyC] — which is what makes it the condition that catches a manager still
/// dressed for February. `clear` stays the neutral state, the gap between
/// spells.
const List<String> conditions = [
  'clear',
  'sunny',
  'cloudy',
  'wind',
  'fog',
  'rain',
  'storm',
  'snow',
];

/// Refetch the live reading once it is this old.
const int liveRefreshMs = 45 * 60 * 1000;

/// Stop trusting a live reading entirely at this age — the weather has moved on.
const int liveStaleMs = 3 * 60 * 60 * 1000;

// ── Seasons ─────────────────────────────────────────────────────────────────

const List<String> seasons = ['winter', 'spring', 'summer', 'autumn'];

/// Northern-hemisphere month to season.
///
/// The southern hemisphere reads the same table six months out of phase, so an
/// Australian player gets high summer at Christmas rather than the snow a naive
/// month check would hand them.
const List<String> _northernSeasonByMonth = [
  'winter',
  'winter',
  'spring',
  'spring',
  'spring',
  'summer',
  'summer',
  'summer',
  'autumn',
  'autumn',
  'autumn',
  'winter',
];

/// The season at a given month for a given latitude.
///
/// [monthIndex] is 0-based, matching JS `Date#getMonth`.
String getSeason(num monthIndex, [double lat = 51.51]) {
  final m = ((monthIndex.truncate() % 12) + 12) % 12;
  final shifted = hemisphere(lat) == 'S' ? (m + 6) % 12 : m;
  return _northernSeasonByMonth[shifted];
}

// ── Seasonal weights ────────────────────────────────────────────────────────

/// Relative likelihood of each condition, by climate band and season.
///
/// These are weights, not percentages — they need not total 100, and the roll
/// normalises them. `clear` carries most of the weight in summer, which is what
/// makes a shower feel like an event rather than the default.
///
/// The band matters as much as the season: 11% snow in "winter" is right for
/// Manchester, absurd for Singapore and far too low for Oslo.
const Map<String, Map<String, Map<String, int>>> _seasonWeights = {
  'temperate': {
    'spring': {
      'clear': 24,
      'sunny': 4,
      'cloudy': 24,
      'wind': 20,
      'fog': 4,
      'rain': 21,
      'storm': 3,
      'snow': 0,
    },
    'summer': {
      'clear': 22,
      'sunny': 24,
      'cloudy': 22,
      'wind': 9,
      'fog': 2,
      'rain': 15,
      'storm': 6,
      'snow': 0,
    },
    'autumn': {
      'clear': 19,
      'sunny': 1,
      'cloudy': 27,
      'wind': 19,
      'fog': 10,
      'rain': 22,
      'storm': 2,
      'snow': 0,
    },
    'winter': {
      'clear': 16,
      'sunny': 0,
      'cloudy': 27,
      'wind': 15,
      'fog': 13,
      'rain': 24,
      'storm': 1,
      'snow': 4,
    },
  },
  'cold': {
    'spring': {
      'clear': 21,
      'sunny': 1,
      'cloudy': 26,
      'wind': 20,
      'fog': 6,
      'rain': 20,
      'storm': 1,
      'snow': 5,
    },
    'summer': {
      'clear': 30,
      'sunny': 10,
      'cloudy': 25,
      'wind': 12,
      'fog': 4,
      'rain': 17,
      'storm': 2,
      'snow': 0,
    },
    'autumn': {
      'clear': 16,
      'sunny': 0,
      'cloudy': 28,
      'wind': 20,
      'fog': 10,
      'rain': 18,
      'storm': 1,
      'snow': 7,
    },
    'winter': {
      'clear': 10,
      'sunny': 0,
      'cloudy': 24,
      'wind': 14,
      'fog': 8,
      'rain': 10,
      'storm': 0,
      'snow': 34,
    },
  },
  // Near the equator the calendar seasons barely register — it is wet or it is
  // dry, and it is never, ever snowing. One table for the whole year. Sunny
  // carries most of the dry weight here, since "dry" near the equator means hot
  // by definition: a clear 18° day is a temperate thing.
  'tropical': {
    'spring': {
      'clear': 12,
      'sunny': 28,
      'cloudy': 24,
      'wind': 6,
      'fog': 3,
      'rain': 20,
      'storm': 7,
      'snow': 0,
    },
    'summer': {
      'clear': 12,
      'sunny': 28,
      'cloudy': 24,
      'wind': 6,
      'fog': 3,
      'rain': 20,
      'storm': 7,
      'snow': 0,
    },
    'autumn': {
      'clear': 12,
      'sunny': 28,
      'cloudy': 24,
      'wind': 6,
      'fog': 3,
      'rain': 20,
      'storm': 7,
      'snow': 0,
    },
    'winter': {
      'clear': 12,
      'sunny': 28,
      'cloudy': 24,
      'wind': 6,
      'fog': 3,
      'rain': 20,
      'storm': 7,
      'snow': 0,
    },
  },
};

/// The weight table in force for a latitude and month.
Map<String, int> weightsFor(double lat, num monthIndex) =>
    _seasonWeights[climateBand(lat)]![getSeason(monthIndex, lat)]!;

/// Weighted pick over a condition-to-weight map.
String _pickWeighted(Map<String, int> weights, double roll) {
  final total = weights.values.fold<int>(0, (a, b) => a + b);
  if (total <= 0) return 'clear';
  var n = roll * total;
  for (final entry in weights.entries) {
    n -= entry.value;
    if (n < 0) return entry.key;
  }
  return 'clear';
}

/// Roll one condition from the seasonal model.
///
/// [rand] is injected so a test can drive an exact outcome.
String rollSeasonalCondition(
  double lat,
  num monthIndex, [
  double Function()? rand,
]) => _pickWeighted(weightsFor(lat, monthIndex), (rand ?? _defaultRand)());

// ── Live observations ───────────────────────────────────────────────────────

/// WMO weather-interpretation codes, as returned by Open-Meteo's
/// `weather_code`.
///
/// Grouped down to the conditions the diorama can actually draw: the scene has
/// no way to tell light drizzle from moderate drizzle, and pretending otherwise
/// would just be data thrown away.
const Map<int, String> _wmoCondition = {
  0: 'clear', // clear sky
  1: 'clear', // mainly clear
  2: 'cloudy', 3: 'cloudy', // partly cloudy / overcast
  45: 'fog', 48: 'fog', // fog / depositing rime fog
  51: 'rain', 53: 'rain', 55: 'rain', // drizzle
  56: 'rain', 57: 'rain', // freezing drizzle
  61: 'rain', 63: 'rain', 65: 'rain', // rain
  66: 'rain', 67: 'rain', // freezing rain
  71: 'snow', 73: 'snow', 75: 'snow', // snowfall
  77: 'snow', // snow grains
  80: 'rain', 81: 'rain', 82: 'rain', // rain showers
  85: 'snow', 86: 'snow', // snow showers
  95: 'storm', // thunderstorm
  96: 'storm', 99: 'storm', // thunderstorm with hail
};

/// Above this sustained wind, a plain sky reads as windy rather than calm.
const double windyKph = 30;

/// At or above this (°C) a cloudless sky is `sunny` rather than `clear`.
///
/// Deliberately the same number as [hotC], and asserted to be in the tests:
/// sunny exists to mean "hot enough that a coat is a mistake", so if the two
/// ever drifted apart the scene would show a blazing sun over a manager
/// perfectly comfortable in his overcoat. Declared here rather than derived from
/// [hotC] only because that one belongs to the comfort section below.
const double sunnyC = 24;

/// Map one Open-Meteo reading onto a diorama condition.
///
/// Wind and heat are layered on top rather than being conditions of their own,
/// because the API reports them as numbers:
///
/// - A gale is only the HEADLINE when nothing more dramatic is happening. Rain
///   in a gale is still rain, it just leans further. Wind is checked first, so a
///   hot blustery day reads as blustery: it is the one you can actually see.
/// - There is no WMO code for "sunny". A cloudless sky is `sunny` when it is hot
///   (see [sunnyC]) and `clear` when it is merely nice. With no thermometer
///   reading it stays `clear` — inventing a hot day from a code alone would put
///   a blazing sun over a January afternoon.
String conditionFromWmo(int? code, [num windKph = 0, num? tempC]) {
  final base = _wmoCondition[code] ?? 'cloudy';
  if (windKph >= windyKph && (base == 'clear' || base == 'cloudy')) {
    return 'wind';
  }
  if (base == 'clear' && tempC != null && tempC >= sunnyC) return 'sunny';
  return base;
}

/// A live reading is usable until it goes stale.
bool isLiveUsable(Map<String, dynamic>? live, int nowMs) {
  if (live == null) return false;
  final fetchedAt = _num(live['fetchedAt']);
  if (fetchedAt == null) return false;
  if (!conditions.contains(live['condition'])) return false;
  return nowMs - fetchedAt < liveStaleMs;
}

/// True once the cached reading is old enough to be worth refetching.
bool shouldRefreshLive(Map<String, dynamic>? state, int nowMs) {
  final live = _map(_map(state?['weather'])?['live']);
  final fetchedAt = live == null ? null : _num(live['fetchedAt']);
  if (fetchedAt == null) return true;
  return nowMs - fetchedAt >= liveRefreshMs;
}

// ── Resolution ──────────────────────────────────────────────────────────────

/// What the scene should show right now.
///
/// `source` is `live` when it reflects the player's real sky and `seasonal` when
/// it came from the model. The caller needs the difference, because live weather
/// holds steady while seasonal weather cycles through spells.
({String condition, String source, num windKph}) resolveCondition(
  Map<String, dynamic>? state,
  int nowMs, [
  double Function()? rand,
]) {
  final weather = _map(state?['weather']);
  final live = _map(weather?['live']);
  if (isLiveUsable(live, nowMs)) {
    return (
      condition: live!['condition'] as String,
      source: 'live',
      windKph: _num(live['windKph']) ?? 0,
    );
  }
  final lat = _num(weather?['lat'])?.toDouble() ?? 51.51;
  final monthIndex = DateTime.fromMillisecondsSinceEpoch(nowMs).month - 1;
  return (
    condition: rollSeasonalCondition(lat, monthIndex, rand),
    source: 'seasonal',
    windKph: 0,
  );
}

// ── Spell timing (seasonal mode only) ───────────────────────────────────────

/// How long each condition hangs around once it starts.
///
/// Fog and snow settle in; a thunderstorm blows through. `clear` has no entry
/// because it IS the gap between spells.
const Map<String, (int, int)> _spellMs = {
  // The sun stays out longer than anything else: a spell of sunshine as short
  // as a shower would read as a cloud passing, not as a hot day.
  'sunny': (50000, 95000),
  'cloudy': (25000, 50000),
  'wind': (25000, 50000),
  'fog': (30000, 60000),
  'rain': (25000, 55000),
  'storm': (15000, 30000),
  'snow': (30000, 70000),
};

const (int, int) _gapMs = (30000, 70000);

double _between((int, int) range, double Function() rand) =>
    range.$1 + rand() * (range.$2 - range.$1);

/// How long a seasonal spell of [condition] should last, in ms. Zero for
/// anything with no spell of its own.
double spellDurationMs(String condition, [double Function()? rand]) {
  final range = _spellMs[condition];
  return range == null ? 0 : _between(range, rand ?? _defaultRand);
}

/// How long to stay clear before rolling the next spell, in ms.
double gapDurationMs([double Function()? rand]) =>
    _between(_gapMs, rand ?? _defaultRand);

// ── Temperature and comfort ─────────────────────────────────────────────────
//
// Nothing here dresses the manager — that is the player's call and stays that
// way. This only decides whether what they have PUT him in suits the weather,
// so the scene can show him suffering in it: shivering in shorts in February,
// sweating in a coat and scarf in August.

/// At or below this (°C) he can be caught cold if he is underdressed.
const double coldC = 8;

/// At or above this (°C) he can overheat if he is wrapped up.
const double hotC = 24;

/// Warmth (see the manager avatar's garment warmth) at or below which he is
/// exposed.
const int underdressedAt = 1;

/// Warmth at or above which he is wrapped up.
const int overdressedAt = 4;

/// Rough typical temperature per climate band and season, for when there is no
/// live reading.
///
/// Coarse on purpose — it only has to land on the right side of "shorts weather"
/// or "coat weather", and it keeps the effect alive offline rather than making
/// it a privilege of being connected.
const Map<String, Map<String, int>> _seasonalTempC = {
  'tropical': {'winter': 27, 'spring': 28, 'summer': 29, 'autumn': 28},
  'temperate': {'winter': 5, 'spring': 13, 'summer': 22, 'autumn': 12},
  'cold': {'winter': -3, 'spring': 6, 'summer': 16, 'autumn': 5},
};

/// Best estimate of the temperature where the player is, in °C: the real reading
/// when there is a live one, the seasonal table otherwise.
///
/// What the sky is DOING overrides the estimate at both ends, because the player
/// can see the sky and cannot see the thermometer:
///
/// - Snow caps it at freezing. A seasonal guess of 13° for a temperate spring is
///   fine right up until it is visibly snowing, at which point it is plainly
///   wrong.
/// - Sun floors it at [sunnyC]. Sunny means hot — that is the whole reason it is
///   a separate condition from clear — so a manager in a winter coat under a
///   blazing sun has to be sweating even when the estimate came from a table.
num estimatedTempC(
  Map<String, dynamic>? state,
  int nowMs, [
  String? condition,
]) {
  final weather = _map(state?['weather']);
  final live = _map(weather?['live']);
  final lat = _num(weather?['lat'])?.toDouble() ?? 51.51;
  final measured = isLiveUsable(live, nowMs) ? _num(live!['tempC']) : null;
  final t =
      measured ??
      _seasonalTempC[climateBand(lat)]![getSeason(
        DateTime.fromMillisecondsSinceEpoch(nowMs).month - 1,
        lat,
      )]!;
  if (condition == 'snow') return math.min(t, 0);
  if (condition == 'sunny') return math.max(t, sunnyC);
  return t;
}

/// How the manager is coping: `cold` when he is underdressed in the cold, `hot`
/// when he is wrapped up in the heat, `ok` the rest of the time.
///
/// Both ends need BOTH halves to be true. Being cold is not enough on its own —
/// a manager in a coat in February is perfectly comfortable, and making him
/// shiver anyway would punish the player for dressing him sensibly. The whole
/// point is that it reacts to their choice.
String comfortFor(num tempC, num warmth) {
  if (tempC <= coldC && warmth <= underdressedAt) return 'cold';
  if (tempC >= hotC && warmth >= overdressedAt) return 'hot';
  return 'ok';
}

// ── Wind on the ball ────────────────────────────────────────────────────────

/// Strongest horizontal push the wind may put on the stray ball, px/s².
const double maxWindAccel = 150;

/// Wind speed at which that maximum is reached.
const double _windAccelFullKph = 65;

/// Only these conditions move the ball.
///
/// A shower does not visibly bend a pass, and pretending it does would mean the
/// ball behaving differently in weather the player can barely see.
const Map<String, double> _windAccelScale = {'wind': 1, 'storm': 0.75};

/// Horizontal acceleration the wind applies to a ball in flight, px/s².
///
/// Live weather scales it by the real wind speed, so a blustery day nudges and a
/// gale genuinely carries. In seasonal mode there is no measured speed, so a
/// `wind` spell uses a solid default — better than pretending to a precision the
/// model does not have.
int windAccelFor(String condition, [num windKph = 0]) {
  final scale = _windAccelScale[condition];
  if (scale == null) return 0;
  final strength = windKph > 0 ? math.min(1, windKph / _windAccelFullKph) : 0.7;
  return (maxWindAccel * scale * strength).round();
}
