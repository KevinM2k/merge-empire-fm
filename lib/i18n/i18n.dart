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

import 'dart:math' as math;

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
/// `<br>` in the catalogue, as a line break.
///
/// **The copy was written for a DOM and three strings still say so**, so the
/// port printed a literal `<br>` in the middle of a sentence. It is fixed here
/// rather than in the ten catalogues because the catalogues are GENERATED from
/// the JS — patching the output would be undone by the next `gen_i18n.mjs` run —
/// and because doing it at the boundary covers every locale and any string that
/// grows one later.
final RegExp _htmlBreak = RegExp(r'<br\s*/?>', caseSensitive: false);

String t(String key, [Map<String, Object?> params = const {}]) {
  final raw = _catalog[key] ?? _fallbackCatalog[key] ?? key;
  final template = raw.contains('<') ? raw.replaceAll(_htmlBreak, '\n') : raw;
  if (params.isEmpty) return template;
  // Literal replace, matching the JS split/join: a param with no placeholder is
  // ignored, and a placeholder with no param is left standing. Neither is an
  // error — 57 catalogue entries drop English's {s} and rely on the first.
  var out = template;
  params.forEach((k, v) => out = out.replaceAll('{$k}', '$v'));
  return out;
}

/// Pooled copy — one line out of several, separated by `|`.
///
/// Dozens of catalogue entries are written this way: the coach's read on a
/// squad, a rival's reaction to a lost bid. The pool IS the copy, so a caller
/// that rendered `t()` straight would print all of them separated by pipes.
///
/// `dart:math` rather than the seeded generator, deliberately: this mirrors the
/// JS's own `Math.random()` and nothing about which sentence a player reads may
/// perturb the draw order that gameplay depends on.
String tPool(String key, [Map<String, Object?> params = const {}]) {
  final lines = t(key, params).split('|');
  if (lines.length == 1) return lines.first;
  return lines[math.Random().nextInt(lines.length)];
}

/// Pooled copy, but the SAME line every time for the same [seed].
///
/// The JS's `_pickStableT`, and the seed is the whole point of it. Coach Colin's
/// read on the squad is a pool of a dozen phrasings, and picking at random meant
/// a different sentence on every rebuild — which on the Shop tab, where the seed
/// was once tied to the coin balance, reshuffled on every idle tick and made the
/// coach's head flash. Seeded on the thing the tip is ABOUT (the season, the
/// division, the squad size), it changes when the situation does and not before.
///
/// The hash is the JS's, `h * 31 + charCode` truncated to 32 signed bits, so the
/// two runtimes pick the same line out of the same pool.
String tPoolStable(
  String key,
  String seed, [
  Map<String, Object?> params = const {},
]) {
  final raw = t(key, params);
  if (raw == key) return raw;
  final lines = raw.split('|');
  if (lines.length == 1) return lines.first;
  var h = 0;
  for (final unit in seed.codeUnits) {
    h = (h * 31 + unit).toSigned(32);
  }
  return lines[h.abs() % lines.length];
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
