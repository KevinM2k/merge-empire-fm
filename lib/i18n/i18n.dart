/// The translation lookup, ported from `../merge-empire-fc/src/i18n/index.js`.
///
/// Deliberately Flutter-free and synchronous. `t()` is called from build methods
/// and from the formatters sitting next to the engines, so an async lookup would
/// poison every call site — which is why all ten catalogues are compiled in
/// rather than loaded on demand.
///
/// Reactivity lives in `providers/i18n_providers.dart`, not here. The JS also
/// set `document.documentElement.dir`; that half is `MaterialApp.locale` now.
library;

import 'package:merge_empire_fc/i18n/catalogs.g.dart';
import 'package:merge_empire_fc/i18n/detect.dart';
import 'package:merge_empire_fc/util/format.dart';

final Map<String, String> _fallbackCatalog = catalogs[fallbackLocale]!;

String _locale = fallbackLocale;
Map<String, String> _catalog = _fallbackCatalog;

/// The ten shipped catalogues, in the order the JS declares them.
List<String> get localeIds => catalogs.keys.toList();

/// An unknown or retired id lands on English: a corrupt save, or a catalogue we
/// stopped shipping, must not leave the app with no strings at all.
void setLocale(String? id) {
  final resolved = (id != null && catalogs.containsKey(id))
      ? id
      : fallbackLocale;
  _locale = resolved;
  _catalog = catalogs[resolved]!;
  setFormatLocale(resolved);
}

String getLocale() => _locale;

void resetLocale() => setLocale(fallbackLocale);

/// Active catalogue, then English, then the key itself — a missing translation
/// shows `ach.title.foo`, never blank UI.
String t(String key, [Map<String, Object?> params = const {}]) {
  final template = _catalog[key] ?? _fallbackCatalog[key] ?? key;
  if (params.isEmpty) return template;
  // Literal replace, matching the JS split/join: a param with no placeholder is
  // ignored, and a placeholder with no param is left standing. Neither is an
  // error — 57 catalogue entries drop English's {s} and rely on the first.
  var out = template;
  params.forEach((k, v) => out = out.replaceAll('{$k}', '$v'));
  return out;
}

/// Resolve a division, cup or tier by its data-file id, falling back to the
/// object's English `name` and then to the id.
String tName(String prefix, Object? idOrObj) {
  final String id;
  final String fallback;
  if (idOrObj is Map) {
    id = idOrObj['id'] as String? ?? '';
    fallback = idOrObj['name'] as String? ?? id;
  } else {
    id = idOrObj as String? ?? '';
    fallback = id;
  }
  final key = '$prefix.$id';
  return _catalog[key] ?? _fallbackCatalog[key] ?? fallback;
}
