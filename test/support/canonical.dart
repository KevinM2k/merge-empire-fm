/// A canonical text form for a save, and a hash of it — the Dart half of
/// `tool/difftest/canonical.mjs`.
///
/// Two runtimes that agree on every value still disagree on how to print one:
/// `JSON.stringify(1.0)` is `1` in JS and `jsonEncode(1.0)` is `1.0` here. A
/// harness that hashed the raw JSON would report every save as different for a
/// reason that is not a difference, so integral numbers are written as integers
/// on both sides.
///
/// Key ORDER is deliberately NOT normalised. The save's key order is part of the
/// format — the schema pins it and the codec round trip preserves it — so a
/// reordering is a real difference and the hash should catch it.
///
/// The int-versus-double rule this hides is checked separately, against the
/// whole saves the harness keeps at the season boundaries.
library;

import 'dart:convert';

/// The canonical text for one value.
String canonical(Object? v) {
  if (v == null) return 'null';
  if (v is bool) return v ? 'true' : 'false';
  if (v is num) return canonicalNumber(v);
  if (v is String) return jsonEncode(v);
  if (v is List) return '[${v.map(canonical).join(',')}]';
  if (v is Map) {
    return '{${v.entries.map((e) => '${jsonEncode('${e.key}')}:${canonical(e.value)}').join(',')}}';
  }
  throw ArgumentError('not a save value: ${v.runtimeType}');
}

/// Integral values print as integers; everything else takes its shortest form,
/// which both runtimes derive the same way from the same IEEE754 double.
String canonicalNumber(num n) {
  // JSON has no NaN or Infinity, and neither runtime can store one.
  if (n is double && !n.isFinite) return 'null';
  if (n is int) return '$n';
  final d = n.toDouble();
  return d == d.roundToDouble() && d.abs() < 9007199254740992.0
      ? '${d.toInt()}'
      : '$d';
}

/// FNV-1a over the canonical text. Small, stable, and trivial to reproduce.
int hashOf(Object? v) {
  final s = canonical(v);
  var h = 2166136261;
  for (var i = 0; i < s.length; i++) {
    h = (h ^ s.codeUnitAt(i)).toSigned(32);
    h = (h * 16777619).toSigned(32);
  }
  return h.toUnsigned(32);
}

/// Fields that are FRACTIONS by nature, and so may legitimately land on a whole
/// number without that meaning the port picked the wrong type.
///
/// Pro-mode fitness is the only one: it runs 0 to 1 and spends most of a season
/// somewhere in between, but a squad rested to full or ground to nothing writes
/// an exact 0 or 1. Everything else in the save that is whole is whole ALWAYS —
/// coins, counters, positions — and one of those arriving as a double is the
/// bug this is looking for.
const Set<String> fractionalPaths = {'.grid.cells[].energy'};

String _shape(String path) => path.replaceAll(RegExp(r'\[[0-9]+\]'), '[]');

/// Every path in [save] whose value is a double where JS would have written an
/// integer, the genuinely fractional ones aside.
///
/// The canonical form hides these on purpose, so the hash tracks values rather
/// than types — but they are real: coins are the most-written field in the save,
/// and one landing as `75.0` where the JS writes `75` is equal as a number and
/// different as JSON.
List<String> integralDoubles(Object? value, [String path = '']) {
  final out = <String>[];
  if (value is double &&
      value == value.roundToDouble() &&
      value.isFinite &&
      !fractionalPaths.contains(_shape(path))) {
    out.add('$path = $value');
  } else if (value is Map) {
    for (final e in value.entries) {
      out.addAll(integralDoubles(e.value, '$path.${e.key}'));
    }
  } else if (value is List) {
    for (var i = 0; i < value.length; i++) {
      out.addAll(integralDoubles(value[i], '$path[$i]'));
    }
  }
  return out;
}
