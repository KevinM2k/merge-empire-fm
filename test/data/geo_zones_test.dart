/// The geo tables, against the JS they were ported from.
///
/// 170 timezones and 65 countries of hand-entered coordinates, so they are
/// compared entry by entry rather than spot-checked: one transposed pair puts a
/// player in the wrong hemisphere, and the seasonal weather model turns that
/// into snow in July.
///
/// See `tool/dump_weather_reference.mjs`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/geo_zones.dart';

final Map<String, dynamic> _ref =
    jsonDecode(File('test/fixtures/weather_reference.json').readAsStringSync())
        as Map<String, dynamic>;

void _expectTable(Map<String, Coords> got, String key) {
  final want = _ref[key] as Map<String, dynamic>;
  expect(got.keys.toSet(), want.keys.toSet(), reason: '$key keys');
  for (final entry in want.entries) {
    final pair = entry.value as List;
    expect(got[entry.key]!.lat, pair[0], reason: '${entry.key} lat');
    expect(got[entry.key]!.lon, pair[1], reason: '${entry.key} lon');
  }
}

void main() {
  test('every timezone lands where the JS put it', () {
    _expectTable(zoneCoords, 'zoneCoords');
    expect(zoneCoords.length, 170);
  });

  test('every country centroid does too', () {
    _expectTable(countryCoords, 'countryCoords');
    expect(countryCoords.length, 65);
  });

  test('the default is London', () {
    final want = _ref['defaultCoords'] as List;
    expect(defaultCoords.lat, want[0]);
    expect(defaultCoords.lon, want[1]);
  });

  test('parity — resolveCoords walks timezone, then country, then London', () {
    for (final row
        in (_ref['resolveCoords'] as List).cast<Map<String, dynamic>>()) {
      final got = resolveCoords(
        row['timeZone'] as String?,
        row['regionCode'] as String?,
      );
      final reason = '${row['timeZone']} / ${row['regionCode']}';
      expect(got.lat, row['lat'], reason: '$reason lat');
      expect(got.lon, row['lon'], reason: '$reason lon');
      expect(got.source, row['source'], reason: '$reason source');
    }
  });

  test('parity — the climate bands and hemispheres', () {
    for (final row in (_ref['bands'] as List).cast<Map<String, dynamic>>()) {
      final lat = (row['lat'] as num?)?.toDouble();
      expect(climateBand(lat), row['band'], reason: 'band at $lat');
      expect(hemisphere(lat), row['hemisphere'], reason: 'hemisphere at $lat');
    }
  });

  test('every zone and country resolves inside a real band', () {
    // A typo that survives the entry-by-entry comparison would have to be in
    // both runtimes, so this asks a different question: are the coordinates
    // coordinates at all.
    for (final entry in {...zoneCoords, ...countryCoords}.entries) {
      expect(entry.value.lat, inInclusiveRange(-90, 90), reason: entry.key);
      expect(entry.value.lon, inInclusiveRange(-180, 180), reason: entry.key);
      expect(
        climateBand(entry.value.lat),
        anyOf('tropical', 'temperate', 'cold'),
        reason: entry.key,
      );
    }
  });

  test('a country code is matched case-insensitively', () {
    // It arrives from the device locale, which is not consistent about case.
    expect(resolveCoords('nowhere', 'de').source, 'region');
    expect(resolveCoords('nowhere', 'DE'), resolveCoords('nowhere', 'de'));
  });
}
