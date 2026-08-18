/// Approximate coordinates for the player's part of the world, derived from the
/// device's IANA timezone — NOT from a location permission. Ported from
/// `../merge-empire-fc/src/data/geoZones.js`.
///
/// The weather backdrop needs to know roughly where the player is so it can ask
/// what the sky is doing there. Real geolocation would mean a runtime permission
/// prompt, a manifest entry, an iOS usage string and a "Precise Location"
/// declaration on both stores' privacy forms — a lot of friction, and a scary
/// prompt, for a decorative backdrop.
///
/// A timezone pins you to a city-sized region with no prompt and no permission,
/// which is all the accuracy "is it raining where I am" needs. The coordinates
/// below are the representative city each zone is named for, rounded to 2dp:
/// that is the MOST precision that ever leaves the device, and it identifies a
/// city, never a person.
///
/// Reading the timezone itself is a device concern and belongs to the services
/// layer — the JS `getDeviceTimeZone` uses `Intl`, which has no equivalent here
/// without a plugin. [resolveCoords] takes the zone as an argument instead, so
/// everything in this file stays pure.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

typedef Coords = ({double lat, double lon});

/// IANA timezone to the coordinates of the zone's reference city.
///
/// One entry per populous zone is enough, since only the rough position
/// matters; anything unlisted falls through to the country table and then to
/// London.
const Map<String, Coords> zoneCoords = {
  // ── Europe ────────────────────────────────────────────────────────────────
  'Europe/London': (lat: 51.51, lon: -0.13),
  'Europe/Dublin': (lat: 53.35, lon: -6.26),
  'Europe/Lisbon': (lat: 38.72, lon: -9.14),
  'Europe/Madrid': (lat: 40.42, lon: -3.7),
  'Europe/Paris': (lat: 48.86, lon: 2.35),
  'Europe/Brussels': (lat: 50.85, lon: 4.35),
  'Europe/Amsterdam': (lat: 52.37, lon: 4.9),
  'Europe/Luxembourg': (lat: 49.61, lon: 6.13),
  'Europe/Berlin': (lat: 52.52, lon: 13.4),
  'Europe/Zurich': (lat: 47.38, lon: 8.54),
  'Europe/Vienna': (lat: 48.21, lon: 16.37),
  'Europe/Prague': (lat: 50.08, lon: 14.44),
  'Europe/Rome': (lat: 41.9, lon: 12.5),
  'Europe/Malta': (lat: 35.9, lon: 14.51),
  'Europe/Copenhagen': (lat: 55.68, lon: 12.57),
  'Europe/Oslo': (lat: 59.91, lon: 10.75),
  'Europe/Stockholm': (lat: 59.33, lon: 18.07),
  'Europe/Helsinki': (lat: 60.17, lon: 24.94),
  'Europe/Tallinn': (lat: 59.44, lon: 24.75),
  'Europe/Riga': (lat: 56.95, lon: 24.11),
  'Europe/Vilnius': (lat: 54.69, lon: 25.28),
  'Europe/Warsaw': (lat: 52.23, lon: 21.01),
  'Europe/Budapest': (lat: 47.5, lon: 19.04),
  'Europe/Bratislava': (lat: 48.15, lon: 17.11),
  'Europe/Ljubljana': (lat: 46.06, lon: 14.51),
  'Europe/Zagreb': (lat: 45.81, lon: 15.98),
  'Europe/Belgrade': (lat: 44.79, lon: 20.45),
  'Europe/Sarajevo': (lat: 43.86, lon: 18.41),
  'Europe/Skopje': (lat: 41.99, lon: 21.43),
  'Europe/Tirane': (lat: 41.33, lon: 19.82),
  'Europe/Sofia': (lat: 42.7, lon: 23.32),
  'Europe/Bucharest': (lat: 44.43, lon: 26.11),
  'Europe/Chisinau': (lat: 47.01, lon: 28.86),
  'Europe/Athens': (lat: 37.98, lon: 23.73),
  'Europe/Istanbul': (lat: 41.01, lon: 28.98),
  'Europe/Kyiv': (lat: 50.45, lon: 30.52),
  'Europe/Kiev': (lat: 50.45, lon: 30.52),
  'Europe/Minsk': (lat: 53.9, lon: 27.57),
  'Europe/Moscow': (lat: 55.76, lon: 37.62),
  'Europe/Samara': (lat: 53.2, lon: 50.15),
  'Europe/Kaliningrad': (lat: 54.71, lon: 20.51),
  'Europe/Reykjavik': (lat: 64.15, lon: -21.94),
  'Atlantic/Canary': (lat: 28.1, lon: -15.41),
  'Atlantic/Reykjavik': (lat: 64.15, lon: -21.94),
  'Atlantic/Azores': (lat: 37.74, lon: -25.68),
  'Atlantic/Madeira': (lat: 32.65, lon: -16.91),

  // ── North America ─────────────────────────────────────────────────────────
  'America/New_York': (lat: 40.71, lon: -74.01),
  'America/Detroit': (lat: 42.33, lon: -83.05),
  'America/Toronto': (lat: 43.65, lon: -79.38),
  'America/Montreal': (lat: 45.5, lon: -73.57),
  'America/Halifax': (lat: 44.65, lon: -63.57),
  'America/St_Johns': (lat: 47.56, lon: -52.71),
  'America/Chicago': (lat: 41.88, lon: -87.63),
  'America/Winnipeg': (lat: 49.9, lon: -97.14),
  'America/Denver': (lat: 39.74, lon: -104.99),
  'America/Edmonton': (lat: 53.55, lon: -113.49),
  'America/Phoenix': (lat: 33.45, lon: -112.07),
  'America/Los_Angeles': (lat: 34.05, lon: -118.24),
  'America/Vancouver': (lat: 49.28, lon: -123.12),
  'America/Anchorage': (lat: 61.22, lon: -149.9),
  'Pacific/Honolulu': (lat: 21.31, lon: -157.86),
  'America/Indiana/Indianapolis': (lat: 39.77, lon: -86.16),
  'America/Mexico_City': (lat: 19.43, lon: -99.13),
  'America/Monterrey': (lat: 25.69, lon: -100.32),
  'America/Tijuana': (lat: 32.51, lon: -117.04),
  'America/Guatemala': (lat: 14.63, lon: -90.51),
  'America/Havana': (lat: 23.11, lon: -82.37),
  'America/Panama': (lat: 8.98, lon: -79.52),
  'America/Costa_Rica': (lat: 9.93, lon: -84.09),
  'America/Santo_Domingo': (lat: 18.49, lon: -69.93),
  'America/Puerto_Rico': (lat: 18.47, lon: -66.11),
  'America/Jamaica': (lat: 18.02, lon: -76.8),

  // ── South America ─────────────────────────────────────────────────────────
  'America/Sao_Paulo': (lat: -23.55, lon: -46.63),
  'America/Bahia': (lat: -12.97, lon: -38.5),
  'America/Fortaleza': (lat: -3.73, lon: -38.53),
  'America/Recife': (lat: -8.05, lon: -34.88),
  'America/Manaus': (lat: -3.12, lon: -60.02),
  'America/Belem': (lat: -1.46, lon: -48.5),
  'America/Argentina/Buenos_Aires': (lat: -34.6, lon: -58.38),
  'America/Argentina/Cordoba': (lat: -31.42, lon: -64.18),
  'America/Santiago': (lat: -33.45, lon: -70.67),
  'America/Montevideo': (lat: -34.9, lon: -56.16),
  'America/Asuncion': (lat: -25.26, lon: -57.58),
  'America/La_Paz': (lat: -16.5, lon: -68.15),
  'America/Lima': (lat: -12.05, lon: -77.04),
  'America/Bogota': (lat: 4.71, lon: -74.07),
  'America/Caracas': (lat: 10.49, lon: -66.88),
  'America/Guayaquil': (lat: -2.19, lon: -79.89),

  // ── Africa and the Middle East ────────────────────────────────────────────
  'Africa/Casablanca': (lat: 33.57, lon: -7.59),
  'Africa/Algiers': (lat: 36.75, lon: 3.06),
  'Africa/Tunis': (lat: 36.81, lon: 10.18),
  'Africa/Tripoli': (lat: 32.89, lon: 13.19),
  'Africa/Cairo': (lat: 30.04, lon: 31.24),
  'Africa/Khartoum': (lat: 15.5, lon: 32.56),
  'Africa/Lagos': (lat: 6.52, lon: 3.38),
  'Africa/Accra': (lat: 5.6, lon: -0.19),
  'Africa/Abidjan': (lat: 5.36, lon: -4.01),
  'Africa/Dakar': (lat: 14.72, lon: -17.47),
  'Africa/Nairobi': (lat: -1.29, lon: 36.82),
  'Africa/Kampala': (lat: 0.35, lon: 32.58),
  'Africa/Dar_es_Salaam': (lat: -6.79, lon: 39.21),
  'Africa/Addis_Ababa': (lat: 9.03, lon: 38.74),
  'Africa/Kinshasa': (lat: -4.44, lon: 15.27),
  'Africa/Luanda': (lat: -8.84, lon: 13.23),
  'Africa/Harare': (lat: -17.83, lon: 31.05),
  'Africa/Lusaka': (lat: -15.39, lon: 28.32),
  'Africa/Maputo': (lat: -25.97, lon: 32.57),
  'Africa/Johannesburg': (lat: -26.2, lon: 28.05),
  'Africa/Windhoek': (lat: -22.56, lon: 17.08),
  'Indian/Mauritius': (lat: -20.16, lon: 57.5),
  'Asia/Jerusalem': (lat: 31.77, lon: 35.21),
  'Asia/Beirut': (lat: 33.89, lon: 35.5),
  'Asia/Damascus': (lat: 33.51, lon: 36.29),
  'Asia/Amman': (lat: 31.95, lon: 35.93),
  'Asia/Baghdad': (lat: 33.31, lon: 44.37),
  'Asia/Riyadh': (lat: 24.71, lon: 46.68),
  'Asia/Kuwait': (lat: 29.38, lon: 47.98),
  'Asia/Qatar': (lat: 25.29, lon: 51.53),
  'Asia/Dubai': (lat: 25.2, lon: 55.27),
  'Asia/Muscat': (lat: 23.59, lon: 58.41),
  'Asia/Tehran': (lat: 35.69, lon: 51.39),
  'Asia/Baku': (lat: 40.41, lon: 49.87),
  'Asia/Tbilisi': (lat: 41.72, lon: 44.79),
  'Asia/Yerevan': (lat: 40.18, lon: 44.51),

  // ── Asia ──────────────────────────────────────────────────────────────────
  'Asia/Karachi': (lat: 24.86, lon: 67.01),
  'Asia/Kolkata': (lat: 22.57, lon: 88.36),
  'Asia/Calcutta': (lat: 22.57, lon: 88.36),
  'Asia/Colombo': (lat: 6.93, lon: 79.86),
  'Asia/Kathmandu': (lat: 27.72, lon: 85.32),
  'Asia/Dhaka': (lat: 23.81, lon: 90.41),
  'Asia/Yangon': (lat: 16.87, lon: 96.2),
  'Asia/Bangkok': (lat: 13.76, lon: 100.5),
  'Asia/Ho_Chi_Minh': (lat: 10.82, lon: 106.63),
  'Asia/Phnom_Penh': (lat: 11.56, lon: 104.92),
  'Asia/Vientiane': (lat: 17.97, lon: 102.63),
  'Asia/Kuala_Lumpur': (lat: 3.14, lon: 101.69),
  'Asia/Singapore': (lat: 1.35, lon: 103.82),
  'Asia/Jakarta': (lat: -6.21, lon: 106.85),
  'Asia/Makassar': (lat: -5.15, lon: 119.43),
  'Asia/Jayapura': (lat: -2.53, lon: 140.72),
  'Asia/Manila': (lat: 14.6, lon: 120.98),
  'Asia/Hong_Kong': (lat: 22.32, lon: 114.17),
  'Asia/Macau': (lat: 22.2, lon: 113.55),
  'Asia/Taipei': (lat: 25.03, lon: 121.57),
  'Asia/Shanghai': (lat: 31.23, lon: 121.47),
  'Asia/Chongqing': (lat: 29.56, lon: 106.55),
  'Asia/Urumqi': (lat: 43.83, lon: 87.62),
  'Asia/Seoul': (lat: 37.57, lon: 126.98),
  'Asia/Pyongyang': (lat: 39.04, lon: 125.76),
  'Asia/Tokyo': (lat: 35.68, lon: 139.69),
  'Asia/Ulaanbaatar': (lat: 47.89, lon: 106.91),
  'Asia/Almaty': (lat: 43.24, lon: 76.89),
  'Asia/Tashkent': (lat: 41.3, lon: 69.24),
  'Asia/Bishkek': (lat: 42.87, lon: 74.59),
  'Asia/Kabul': (lat: 34.53, lon: 69.17),
  'Asia/Novosibirsk': (lat: 55.01, lon: 82.94),
  'Asia/Yekaterinburg': (lat: 56.84, lon: 60.61),
  'Asia/Vladivostok': (lat: 43.12, lon: 131.89),

  // ── Oceania ───────────────────────────────────────────────────────────────
  'Australia/Sydney': (lat: -33.87, lon: 151.21),
  'Australia/Melbourne': (lat: -37.81, lon: 144.96),
  'Australia/Brisbane': (lat: -27.47, lon: 153.03),
  'Australia/Adelaide': (lat: -34.93, lon: 138.6),
  'Australia/Perth': (lat: -31.95, lon: 115.86),
  'Australia/Hobart': (lat: -42.88, lon: 147.33),
  'Australia/Darwin': (lat: -12.46, lon: 130.84),
  'Pacific/Auckland': (lat: -36.85, lon: 174.76),
  'Pacific/Fiji': (lat: -18.14, lon: 178.44),
  'Pacific/Port_Moresby': (lat: -9.44, lon: 147.18),
  'Pacific/Guam': (lat: 13.44, lon: 144.79),
  'Pacific/Tahiti': (lat: -17.54, lon: -149.57),
};

/// Country fallback for zones the table above does not name, keyed by the ISO
/// 3166-1 alpha-2 code the device locale gives.
///
/// A country centroid is coarser than a timezone, but it still lands in the
/// right hemisphere and climate band, which is what the seasonal model needs.
const Map<String, Coords> countryCoords = {
  'GB': (lat: 51.51, lon: -0.13),
  'IE': (lat: 53.35, lon: -6.26),
  'US': (lat: 39.83, lon: -98.58),
  'CA': (lat: 56.13, lon: -106.35),
  'MX': (lat: 23.63, lon: -102.55),
  'BR': (lat: -14.24, lon: -51.93),
  'AR': (lat: -38.42, lon: -63.62),
  'CL': (lat: -35.68, lon: -71.54),
  'CO': (lat: 4.57, lon: -74.3),
  'PE': (lat: -9.19, lon: -75.02),
  'VE': (lat: 6.42, lon: -66.59),
  'UY': (lat: -32.52, lon: -55.77),
  'ES': (lat: 40.46, lon: -3.75),
  'PT': (lat: 39.4, lon: -8.22),
  'FR': (lat: 46.23, lon: 2.21),
  'DE': (lat: 51.17, lon: 10.45),
  'IT': (lat: 41.87, lon: 12.57),
  'NL': (lat: 52.13, lon: 5.29),
  'BE': (lat: 50.5, lon: 4.47),
  'CH': (lat: 46.82, lon: 8.23),
  'AT': (lat: 47.52, lon: 14.55),
  'PL': (lat: 51.92, lon: 19.15),
  'CZ': (lat: 49.82, lon: 15.47),
  'SE': (lat: 60.13, lon: 18.64),
  'NO': (lat: 60.47, lon: 8.47),
  'DK': (lat: 56.26, lon: 9.5),
  'FI': (lat: 61.92, lon: 25.75),
  'IS': (lat: 64.96, lon: -19.02),
  'GR': (lat: 39.07, lon: 21.82),
  'TR': (lat: 38.96, lon: 35.24),
  'RU': (lat: 55.76, lon: 37.62),
  'UA': (lat: 48.38, lon: 31.17),
  'RO': (lat: 45.94, lon: 24.97),
  'HU': (lat: 47.16, lon: 19.5),
  'BG': (lat: 42.73, lon: 25.49),
  'RS': (lat: 44.02, lon: 21.01),
  'HR': (lat: 45.1, lon: 15.2),
  'ZA': (lat: -30.56, lon: 22.94),
  'NG': (lat: 9.08, lon: 8.68),
  'EG': (lat: 26.82, lon: 30.8),
  'KE': (lat: -0.02, lon: 37.91),
  'MA': (lat: 31.79, lon: -7.09),
  'DZ': (lat: 28.03, lon: 1.66),
  'GH': (lat: 7.95, lon: -1.02),
  'SA': (lat: 23.89, lon: 45.08),
  'AE': (lat: 23.42, lon: 53.85),
  'IL': (lat: 31.05, lon: 34.85),
  'IR': (lat: 32.43, lon: 53.69),
  'IN': (lat: 20.59, lon: 78.96),
  'PK': (lat: 30.38, lon: 69.35),
  'BD': (lat: 23.68, lon: 90.36),
  'LK': (lat: 7.87, lon: 80.77),
  'TH': (lat: 15.87, lon: 100.99),
  'VN': (lat: 14.06, lon: 108.28),
  'MY': (lat: 4.21, lon: 101.98),
  'SG': (lat: 1.35, lon: 103.82),
  'ID': (lat: -0.79, lon: 113.92),
  'PH': (lat: 12.88, lon: 121.77),
  'CN': (lat: 35.86, lon: 104.2),
  'TW': (lat: 23.7, lon: 120.96),
  'HK': (lat: 22.32, lon: 114.17),
  'JP': (lat: 36.2, lon: 138.25),
  'KR': (lat: 35.91, lon: 127.77),
  'AU': (lat: -25.27, lon: 133.78),
  'NZ': (lat: -40.9, lon: 174.89),
};

/// London — the club-football default, and where the game's tone is set.
const Coords defaultCoords = (lat: 51.51, lon: -0.13);

/// Best-effort coordinates for the player, in priority order: their timezone,
/// then their locale's country, then London.
///
/// `source` says which rung answered, so a caller can tell a real match from a
/// bare default.
({double lat, double lon, String source}) resolveCoords(
  String? timeZone,
  String? regionCode,
) {
  final zone = zoneCoords[timeZone];
  if (zone != null) {
    return (lat: zone.lat, lon: zone.lon, source: 'timezone');
  }

  final country = countryCoords[(regionCode ?? '').toUpperCase()];
  if (country != null) {
    return (lat: country.lat, lon: country.lon, source: 'region');
  }

  return (lat: defaultCoords.lat, lon: defaultCoords.lon, source: 'default');
}

/// Climate band from latitude.
///
/// The seasonal weather model needs this because "winter" means something
/// completely different in Singapore, Manchester and Oslo. Without it a tropical
/// player would get snow every December.
String climateBand(double? lat) {
  final abs = (lat ?? 0).abs();
  if (abs < 23.5) return 'tropical'; // no real winter, no snow: wet and dry
  if (abs > 55) return 'cold'; // long snowy winters, short summers
  return 'temperate';
}

/// The southern hemisphere runs the seasons six months out of phase.
String hemisphere(double? lat) => (lat ?? 0) < 0 ? 'S' : 'N';
