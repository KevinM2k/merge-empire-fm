/// Device-language detection with a hard English fallback, ported from
/// `../merge-empire-fc/src/i18n/detect.js`.
///
/// Kept free of catalogue imports so the state schema and migration can pull it
/// in without dragging all ten locale files along.
///
/// Deliberately Flutter-free so it runs under plain `dart test`. The platform
/// locale is injected via [setDeviceLocales] rather than read from
/// `PlatformDispatcher`, which keeps this testable and off the Flutter binding.
library;

const String fallbackLocale = 'en';

/// Must stay in sync with the shipped catalogues.
const List<String> supportedLocales = [
  'en',
  'es',
  'pt',
  'fr',
  'de',
  'it',
  'ja',
  'ko',
  'zh',
  'ar',
];

/// Macro and legacy language subtags some devices still emit, mapped onto the
/// catalogue we actually ship. Regional variants (pt-BR, zh-Hant, es-419) need
/// no entry — only the primary subtag is matched.
const Map<String, String> _aliases = {
  'cmn': 'zh', // Mandarin
  'yue': 'zh', // Cantonese
  'wuu': 'zh', // Wu
  'nan': 'zh', // Min Nan
};

final RegExp _langPattern = RegExp(r'^[a-z]{2,3}$');

/// Primary language subtag of a BCP-47 tag, lowercased and de-aliased.
String _baseLang(String? tag) {
  if (tag == null) return '';
  final base = tag.trim().toLowerCase().replaceAll('_', '-').split('-').first;
  if (!_langPattern.hasMatch(base)) return '';
  return _aliases[base] ?? base;
}

/// First supported locale among [tags], highest preference first. Returns
/// English when nothing matches — the app is never left without a catalogue.
String resolveLocale(List<String?> tags) {
  for (final tag in tags) {
    final lang = _baseLang(tag);
    if (lang.isNotEmpty && supportedLocales.contains(lang)) return lang;
  }
  return fallbackLocale;
}

List<String> _deviceLocales = const [];

/// Injected at boot from the platform's preferred locales. Left empty in tests
/// and pure-Dart contexts, where detection falls back to English.
void setDeviceLocales(List<String> locales) => _deviceLocales = locales;

void resetDeviceLocales() => _deviceLocales = const [];

/// Device language, narrowed to a supported locale.
String detectLocale() => resolveLocale(_deviceLocales);
