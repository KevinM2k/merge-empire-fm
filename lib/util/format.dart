/// Number formatting, ported from `../merge-empire-fc/src/utils/format.js`.
///
/// The JS reaches into i18n for the active locale; here the locale is injected
/// via [setFormatLocale] so this file stays independent of the i18n layer — and
/// Flutter-free, so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:intl/intl.dart';

String _locale = 'en';

/// Called by the i18n layer whenever the active locale changes.
void setFormatLocale(String locale) => _locale = locale;

String getFormatLocale() => _locale;

void resetFormatLocale() => _locale = 'en';

/// Mirrors JS `toLocaleString(locale, {min/maxFractionDigits: digits})` —
/// locale-aware grouping with a fixed number of decimals.
String _fmt(num v, [int digits = 0]) {
  final pattern = digits == 0
      ? '#,##0'
      : '#,##0.${'0' * digits}';
  return NumberFormat(pattern, _locale).format(v);
}

/// Full number with locale-aware grouping under 10k, then 10.2k, then 1.23M.
String formatCoins(num n) {
  final v = n.floor();
  if (v >= 1000000000) return '${_fmt(v / 1000000000, 2)}B';
  if (v >= 1000000) return '${_fmt(v / 1000000, 2)}M';
  if (v >= 10000) return '${_fmt(v / 1000, 1)}k';
  return _fmt(v);
}

/// Compact coin format for the HUD badge. Shows the full figure with a
/// thousands separator up to 5 digits, then abbreviates: 100k+, 1.2M, 3.4B,
/// 1.0T. One decimal only under 10 of a unit; a plain integer at or above 10.
///
/// Uses floor, not round, so a value never rounds up across a unit boundary —
/// 999,999,999 reads 999M, never 1000M.
String formatCoinsCompact(num n) {
  final neg = n < 0;
  final v = n.abs().floor();

  String short(int div, String suffix) {
    final x = v / div;
    final s = x < 10
        ? ((x * 10).floor() / 10).toStringAsFixed(1)
        : x.floor().toString();
    return '$s$suffix';
  }

  final String out;
  if (v >= 1000000000000) {
    out = short(1000000000000, 'T');
  } else if (v >= 1000000000) {
    out = short(1000000000, 'B');
  } else if (v >= 1000000) {
    out = short(1000000, 'M');
  } else if (v >= 100000) {
    out = short(1000, 'k');
  } else {
    out = _fmt(v);
  }
  return neg ? '-$out' : out;
}

/// Percentages, abbreviating large values: 1500 -> "+1.5k%", 200 -> "+200%".
String formatPct(num pct) {
  final abs = pct.abs();
  final sign = pct >= 0 ? '+' : '-';
  if (abs >= 1000000) return '$sign${_fmt(abs / 1000000, 1)}M%';
  if (abs >= 10000) return '$sign${_fmt(abs / 1000, 0)}k%';
  if (abs >= 1000) return '$sign${_fmt(abs / 1000, 1)}k%';
  return '$sign${_jsRound(abs.toDouble())}%';
}

/// A per-second rate with locale-aware grouping.
String formatRate(num n) {
  if (n >= 1000) return '${_fmt(n / 1000, 1)}k/s';
  if (n >= 10) return '${_fmt(n, 1)}/s';
  return '${_fmt(n, 2)}/s';
}

/// JS `Math.round` — half rounds toward positive infinity, which differs from
/// Dart's round-half-away-from-zero on negative halves.
int _jsRound(double v) => (v + 0.5).floor();

/// Rounds coin amounts to the nearest "nice" step that scales with magnitude:
/// nearest 5 for hundreds, 50 for thousands, 5000 for hundred-thousands.
/// Values under 10 keep their exact value.
///
/// Returns an `int`, always. The step is a whole number by construction, so the
/// result is one too — and it has to arrive as an int rather than a double that
/// happens to be whole. Coin amounts go straight into the save, a save is
/// compared byte for byte after a cloud round trip, and `75.0` encodes
/// differently from `75` while comparing equal in Dart. JS has only one number
/// type and writes the integral value, so this is what matches it.
int roundCoins(num? n) {
  if (n == null) return 0;
  final abs = n.abs();
  if (abs < 10) return _jsRound(n.toDouble());
  final factor = math.max(
    5,
    5 * math.pow(10, (math.log(abs) / math.ln10).floor() - 2).toInt(),
  );
  return _jsRound(n / factor) * factor;
}
