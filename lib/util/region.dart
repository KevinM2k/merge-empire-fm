/// The player's ISO 3166-1 alpha-2 region, for the regional leaderboards.
/// Ported from `../merge-empire-fc/src/utils/region.js`.
///
/// The JS reads the device locale from `Intl` and schedules a save on first
/// detection. Both of those are somebody else's job here: the locale is a
/// platform read (M4, alongside the timezone the weather needs) and the save
/// scheduling is M2, so [ensurePlayerRegion] takes the locale tag as an argument
/// and reports whether it wrote anything, leaving the caller to persist.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// Where a language lands when the locale tag carries no region of its own.
///
/// A guess, but a defensible one per language, and better than putting every
/// Spanish speaker in the same bucket as every English one.
const Map<String, String> langDefaultRegion = {
  'en': 'GB',
  'es': 'ES',
  'pt': 'BR',
  'fr': 'FR',
  'de': 'DE',
  'it': 'IT',
  'ja': 'JP',
  'ko': 'KR',
  'zh': 'CN',
  'ar': 'SA',
};

/// The fallback when the tag says nothing useful at all.
const String defaultRegion = 'GB';

final RegExp _regionPattern = RegExp(r'^[A-Z]{2}$');

/// The region a BCP-47 locale tag implies.
///
/// The LAST subtag wins when it is two letters — `en-GB`, `zh-Hans-CN` — and
/// otherwise the language's default stands in.
String regionFromLocaleTag(Object? tag) {
  final parts = '${tag ?? ''}'.split('-');
  if (parts.length >= 2) {
    final region = parts.last.toUpperCase();
    if (_regionPattern.hasMatch(region)) return region;
  }
  final lang = parts.isEmpty ? 'en' : parts.first.toLowerCase();
  return langDefaultRegion[lang] ?? defaultRegion;
}

/// The region for this save, detected from [deviceLocale] when the save has not
/// recorded one yet.
///
/// The save's own locale setting is the fallback, so a player who has switched
/// the game's language without the device following still lands somewhere
/// sensible.
String detectRegionCode(Map<String, dynamic>? state, [String? deviceLocale]) {
  final saved = _map(state?['settings'])?['locale'];
  final tag =
      deviceLocale ?? (saved is String && saved.isNotEmpty ? saved : 'en');
  return regionFromLocaleTag(tag);
}

/// Detect the region once and keep it, so it survives a later locale change.
///
/// Returns the code and whether this call wrote it — the caller schedules the
/// save, because nothing down here knows how.
({String code, bool stored}) ensurePlayerRegion(
  Map<String, dynamic> state, [
  String? deviceLocale,
]) {
  final settings =
      _map(state['settings']) ??
      (() {
        final fresh = <String, dynamic>{'locale': 'en'};
        state['settings'] = fresh;
        return fresh;
      })();
  final existing = settings['regionCode'];
  if (existing is String && existing.isNotEmpty) {
    return (code: existing, stored: false);
  }
  final code = detectRegionCode(state, deviceLocale);
  settings['regionCode'] = code;
  return (code: code, stored: true);
}

/// The region on this save, or the one the locale implies when it has none.
String getPlayerRegionCode(
  Map<String, dynamic>? state, [
  String? deviceLocale,
]) {
  final saved = _map(state?['settings'])?['regionCode'];
  if (saved is String && saved.isNotEmpty) return saved;
  return detectRegionCode(state, deviceLocale);
}
