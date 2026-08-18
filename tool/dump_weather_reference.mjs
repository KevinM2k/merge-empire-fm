// Reference output from the JS weather engine and its geo tables.
//
// The engine is pure — `nowMs` and `rand` are always passed in — so every
// number here is reproducible, and the interesting risk is not randomness but
// ORDER. `rollSeasonalCondition` walks a weight map and subtracts as it goes,
// so the same weights visited in a different order hand back a different sky
// for the same roll. The sweep below asks every band and season for a condition
// at twenty points across the range, which pins the cumulative order as well as
// the weights.
//
// The geo tables are dumped whole. They are 170 timezones and 65 countries of
// hand-entered coordinates, and one transposed pair puts a player in the wrong
// hemisphere — which the seasonal model turns into snow in July.
//
// Timestamps are noon UTC on the 15th, so the local month is the same one in
// every timezone the two runtimes could be run in.
//
//   node tool/dump_weather_reference.mjs > test/fixtures/weather_reference.json

const geo = await import('../../merge-empire-fc/src/data/geoZones.js');
const we = await import('../../merge-empire-fc/src/engine/weatherEngine.js');

const out = {};

// ── The geo tables ──────────────────────────────────────────────────────────
const { ZONE_COORDS, COUNTRY_COORDS, DEFAULT_COORDS } = geo.__testing;
out.zoneCoords = ZONE_COORDS;
out.countryCoords = COUNTRY_COORDS;
out.defaultCoords = DEFAULT_COORDS;

out.resolveCoords = [];
for (const [timeZone, regionCode] of [
  ['Europe/London', 'GB'],
  ['Australia/Sydney', 'AU'],
  ['Asia/Singapore', 'SG'],
  ['America/Argentina/Buenos_Aires', 'AR'],
  // Unlisted zone, listed country — the middle rung.
  ['Europe/Nowhere', 'de'],
  ['Europe/Nowhere', 'DE'],
  // Neither, which is London.
  ['Europe/Nowhere', 'ZZ'],
  [null, null],
  [undefined, ''],
]) {
  out.resolveCoords.push({
    timeZone: timeZone ?? null, regionCode: regionCode ?? null,
    ...geo.resolveCoords(timeZone, regionCode),
  });
}

out.bands = [];
for (const lat of [0, 10, 23.4, 23.5, 23.6, -23.6, 40, 51.51, 55, 55.1, -55.1, 60, 64.15, -33.87, -90, 90, null]) {
  out.bands.push({ lat, band: geo.climateBand(lat), hemisphere: geo.hemisphere(lat) });
}

// ── Seasons ─────────────────────────────────────────────────────────────────
out.seasons = we.SEASONS;
out.conditions = we.CONDITIONS;
out.constants = {
  liveRefreshMs: we.LIVE_REFRESH_MS,
  liveStaleMs: we.LIVE_STALE_MS,
  windyKph: we.WINDY_KPH,
  sunnyC: we.SUNNY_C,
  coldC: we.COLD_C,
  hotC: we.HOT_C,
  underdressedAt: we.UNDERDRESSED_AT,
  overdressedAt: we.OVERDRESSED_AT,
  maxWindAccel: we.MAX_WIND_ACCEL,
  spellMs: we.__testing.SPELL_MS,
  gapMs: we.__testing.GAP_MS,
};

out.getSeason = [];
for (const monthIndex of [-13, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 5.9]) {
  for (const lat of [51.51, -33.87, 0, -0.0001]) {
    out.getSeason.push({ monthIndex, lat, season: we.getSeason(monthIndex, lat) });
  }
}
// The default latitude is London, so a caller with no location still gets
// northern-hemisphere seasons rather than nothing.
out.getSeasonDefaultLat = [0, 6].map((m) => we.getSeason(m));

// ── Seasonal weights and the roll ───────────────────────────────────────────
const BAND_LATS = { tropical: 1.35, temperate: 51.51, cold: 59.91 };
const SEASON_MONTHS = { winter: 0, spring: 3, summer: 6, autumn: 9 };

out.weightsFor = [];
for (const [band, lat] of Object.entries(BAND_LATS)) {
  for (const [season, monthIndex] of Object.entries(SEASON_MONTHS)) {
    out.weightsFor.push({ band, season, lat, monthIndex, weights: we.weightsFor(lat, monthIndex) });
  }
}

out.rollSeasonal = [];
for (const [band, lat] of Object.entries(BAND_LATS)) {
  for (const [season, monthIndex] of Object.entries(SEASON_MONTHS)) {
    for (let i = 0; i < 20; i++) {
      const roll = i / 20;
      out.rollSeasonal.push({
        band, season, lat, monthIndex, roll,
        condition: we.rollSeasonalCondition(lat, monthIndex, () => roll),
      });
    }
    // The very top of the range, where a naive `<=` walk falls off the end.
    out.rollSeasonal.push({
      band, season, lat, monthIndex, roll: 0.999999,
      condition: we.rollSeasonalCondition(lat, monthIndex, () => 0.999999),
    });
  }
}

// ── Live observations ───────────────────────────────────────────────────────
out.wmo = [];
const CODES = [...Object.keys(we.__testing.WMO_CONDITION).map(Number), 4, 7, 100, -1];
for (const code of CODES) {
  for (const [windKph, tempC] of [[0, null], [29.9, null], [30, null], [80, null],
    [0, 23.9], [0, 24], [0, 30], [35, 30], [0, -5]]) {
    out.wmo.push({ code, windKph, tempC, condition: we.conditionFromWmo(code, windKph, tempC) });
  }
}
// The defaults: no wind, no thermometer.
out.wmoDefaults = [0, 2, 61, 95].map((code) => ({ code, condition: we.conditionFromWmo(code) }));

const NOW = Date.UTC(2026, 5, 15, 12);

out.isLiveUsable = [];
for (const [label, live] of [
  ['null', null],
  ['noFetchedAt', { condition: 'rain' }],
  ['fetchedAtNotANumber', { condition: 'rain', fetchedAt: 'soon' }],
  ['unknownCondition', { condition: 'hail', fetchedAt: NOW }],
  ['fresh', { condition: 'rain', fetchedAt: NOW }],
  ['justInsideStale', { condition: 'rain', fetchedAt: NOW - we.LIVE_STALE_MS + 1 }],
  ['exactlyStale', { condition: 'rain', fetchedAt: NOW - we.LIVE_STALE_MS }],
  ['fromTheFuture', { condition: 'rain', fetchedAt: NOW + 60_000 }],
]) {
  out.isLiveUsable.push({ label, usable: we.isLiveUsable(live, NOW) });
}

out.shouldRefreshLive = [];
for (const [label, state] of [
  ['noState', null],
  ['noWeather', {}],
  ['noLive', { weather: {} }],
  ['noFetchedAt', { weather: { live: {} } }],
  ['justFetched', { weather: { live: { fetchedAt: NOW } } }],
  ['justInside', { weather: { live: { fetchedAt: NOW - we.LIVE_REFRESH_MS + 1 } } }],
  ['exactlyDue', { weather: { live: { fetchedAt: NOW - we.LIVE_REFRESH_MS } } }],
]) {
  out.shouldRefreshLive.push({ label, refresh: we.shouldRefreshLive(state, NOW) });
}

// ── Resolution ──────────────────────────────────────────────────────────────
out.resolveCondition = [];
for (const [label, state] of [
  ['live', { weather: { live: { condition: 'storm', fetchedAt: NOW, windKph: 44 } } }],
  ['liveNoWind', { weather: { live: { condition: 'fog', fetchedAt: NOW } } }],
  ['stale', { weather: { lat: 51.51, live: { condition: 'storm', fetchedAt: NOW - we.LIVE_STALE_MS } } }],
  ['noLiveTemperate', { weather: { lat: 51.51 } }],
  ['noLiveTropical', { weather: { lat: 1.35 } }],
  ['noLiveSouthern', { weather: { lat: -33.87 } }],
  ['noWeatherBranch', {}],
  ['nullState', null],
]) {
  for (const roll of [0.05, 0.5, 0.95]) {
    out.resolveCondition.push({ label, roll, ...we.resolveCondition(state, NOW, () => roll) });
  }
}
// The month comes off `nowMs`, so the same save reads differently in January.
out.resolveConditionByMonth = [];
for (let month = 0; month < 12; month++) {
  const at = Date.UTC(2026, month, 15, 12);
  out.resolveConditionByMonth.push({
    month,
    ...we.resolveCondition({ weather: { lat: 59.91 } }, at, () => 0.97),
  });
}

// ── Spells ──────────────────────────────────────────────────────────────────
out.spells = [];
for (const condition of [...we.CONDITIONS, 'not_a_condition']) {
  for (const roll of [0, 0.5, 1]) {
    out.spells.push({ condition, roll, ms: we.spellDurationMs(condition, () => roll) });
  }
}
out.gaps = [0, 0.25, 1].map((roll) => ({ roll, ms: we.gapDurationMs(() => roll) }));

// ── Temperature and comfort ─────────────────────────────────────────────────
out.estimatedTempC = [];
for (const [label, state] of [
  ['liveWarm', { weather: { lat: 51.51, live: { condition: 'clear', fetchedAt: NOW, tempC: 26.5 } } }],
  ['liveFreezing', { weather: { lat: 51.51, live: { condition: 'snow', fetchedAt: NOW, tempC: -4 } } }],
  ['liveNoTemp', { weather: { lat: 51.51, live: { condition: 'rain', fetchedAt: NOW } } }],
  ['staleLive', { weather: { lat: 51.51, live: { condition: 'clear', fetchedAt: NOW - we.LIVE_STALE_MS, tempC: 26.5 } } }],
  ['seasonalTemperate', { weather: { lat: 51.51 } }],
  ['seasonalTropical', { weather: { lat: 1.35 } }],
  ['seasonalCold', { weather: { lat: 59.91 } }],
  ['seasonalSouthern', { weather: { lat: -33.87 } }],
  ['noWeather', {}],
]) {
  for (const condition of [null, 'snow', 'sunny', 'rain']) {
    for (const month of [0, 6]) {
      out.estimatedTempC.push({
        label, condition, month,
        tempC: we.estimatedTempC(state, Date.UTC(2026, month, 15, 12), condition),
      });
    }
  }
}

out.comfort = [];
for (const tempC of [-10, 7.9, 8, 8.1, 20, 23.9, 24, 30]) {
  for (const warmth of [0, 1, 2, 3, 4, 5]) {
    out.comfort.push({ tempC, warmth, comfort: we.comfortFor(tempC, warmth) });
  }
}

out.windAccel = [];
for (const condition of [...we.CONDITIONS, 'not_a_condition']) {
  for (const windKph of [0, 1, 20, 45, 65, 120]) {
    out.windAccel.push({ condition, windKph, accel: we.windAccelFor(condition, windKph) });
  }
  out.windAccel.push({ condition, windKph: null, accel: we.windAccelFor(condition) });
}

process.stdout.write(JSON.stringify(out));
