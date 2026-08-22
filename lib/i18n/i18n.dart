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
/// `<br>` in the catalogue, as a line break, and every inline emphasis tag as
/// nothing at all.
///
/// **The copy was written for a DOM and it still says so**, so the port printed
/// the markup in the middle of a sentence. It is fixed here rather than in the
/// ten catalogues because the catalogues are GENERATED from the JS — patching
/// the output would be undone by the next `gen_i18n.mjs` run — and because
/// doing it at the boundary covers every locale and any string that grows one
/// later.
///
/// **Emphasis is STRIPPED rather than honoured, and that is the whole of the
/// decision.** Twenty-three entries carry `<strong>` and one of them was on
/// screen: `cup.win_reward.body` is the cup sponsor offer's line, and it read
/// `<strong>Nike</strong> wants to sponsor <strong>Smith</strong>.` to the
/// player. Emphasis inside a run of text is a DOM affordance — a Dart `String`
/// cannot carry it, so honouring the tag would mean every one of those call
/// sites taking spans instead of a string, which is a different signature for
/// twenty-three strings to buy bold on two of them. The port's cards get their
/// emphasis from their own typography instead: `CoachLine.strong` is a whole
/// LINE at 15px and w800, which is the same reading with none of the markup.
///
/// **AND `<strong>` WAS NOT THE ONLY TAG IN THERE.** Nine more entries carry
/// `<b>` — seven of them `offseason.*`, whose whole report is `<b>{n}</b>`
/// players recovered — and `squad.subtext` carries a `<span style="color:…">`
/// around the form arrows. None of the nine has a caller TODAY, which is
/// exactly the position `cup.win_reward.body` was in until a screen reached for
/// it. Handling one tag and not its synonym is a boundary that only works for
/// the strings somebody has already looked at.
///
/// So the rule is the tag class, not the tag list: a `<b>`, an `<i>`, an `<em>`
/// or a `<span …>` all mean emphasis, all cannot survive as a `String`, and all
/// come off here. `<br>` stays the one tag that MEANS something a string can
/// hold, and it becomes the newline it stood for.
///
/// Stripping the span leaves `▲▲` behind, which is the right answer twice over:
/// it is what the sentence is about, and a glyph is what this port reaches for
/// where the DOM reached for a colour.
final RegExp _htmlBreak = RegExp(r'<br\s*/?>', caseSensitive: false);

/// Every inline tag that carried presentation the DOM could and a `String`
/// cannot. Attributes included, so `<span style="…">` goes with the bare form.
final RegExp _htmlInline = RegExp(
  r'</?(strong|b|i|em|span|u|small)(\s[^<>]*)?>',
  caseSensitive: false,
);

String t(String key, [Map<String, Object?> params = const {}]) {
  final raw = _catalog[key] ?? _fallbackCatalog[key] ?? key;
  // The `contains('<')` guard means the common case — a string with no markup
  // in it at all — does no work for either pattern.
  final template = raw.contains('<')
      ? raw.replaceAll(_htmlBreak, '\n').replaceAll(_htmlInline, '')
      : raw;
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
]) => tPoolStableOf([key], seed, params);

/// The same pick, over the pools of SEVERAL keys at once.
///
/// The JS builds one array and concatenates onto it — `_opponentHistoryTip`
/// widens the fixture's pool with the all-time record's variants — so the two
/// keys' sentences compete rather than one replacing the other. A caller that
/// picked a key first and a line second would give a two-variant key the same
/// weight as a four-variant one.
///
/// A key the catalogue does not carry contributes nothing, which is what lets a
/// caller offer an optional second key without checking for it; if none of them
/// resolve the first key is returned, matching [t]'s own fallback.
String tPoolStableOf(
  List<String> keys,
  String seed, [
  Map<String, Object?> params = const {},
]) {
  final lines = <String>[];
  for (final key in keys) {
    final raw = t(key, params);
    if (raw != key) lines.addAll(raw.split('|'));
  }
  if (lines.isEmpty) return keys.isEmpty ? '' : keys.first;
  if (lines.length == 1) return lines.first;
  return lines[stableIndex(seed, lines.length)];
}

/// The JS's `_pickStable` index — `h * 31 + charCode` truncated to 32 signed
/// bits — so the two runtimes pick the same entry out of the same list.
///
/// Public because the choice is not always a sentence: `manager_hint_engine`
/// rolls the JS's one-in-three on whether the all-time record joins the pool at
/// all, and a second hash would be a second answer to "which one is stable".
int stableIndex(String seed, int length) {
  if (length <= 1) return 0;
  var h = 0;
  for (final unit in seed.codeUnits) {
    h = (h * 31 + unit).toSigned(32);
  }
  return h.abs() % length;
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
