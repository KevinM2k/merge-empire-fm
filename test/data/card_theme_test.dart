/// The card's per-tier palette, pinned against Card.js.
///
/// These are literal tables in the JS, so this is a transcription and
/// regression guard rather than a derivation check — said plainly because a
/// wrong hex is a silent rarity change nothing else in the suite would notice.
///
/// Regenerate with tool/dump_card_theme_reference.mjs.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/card_theme.dart';

void main() {
  final reference =
      jsonDecode(
            File('test/fixtures/card_theme_reference.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  String css(TierGradient g) =>
      'linear-gradient(${g.angleDeg}deg,'
      '${g.stops.map((s) => '${s.$1} ${_pct(s.$2)}%').join(',')})';

  test('nine tiers, no more and no fewer', () {
    expect(tierThemes.length, 9);
    expect(tierLabel.length, 9);
    expect(tierEmoji.length, 9);
    expect(tierThemes.keys.toList(), [1, 2, 3, 4, 5, 6, 7, 8, 9]);
  });

  test('the labels and glyphs match the JS', () {
    (reference['label'] as Map<String, dynamic>).forEach((k, v) {
      expect(tierLabel[int.parse(k)], v, reason: 'label $k');
    });
    (reference['emoji'] as Map<String, dynamic>).forEach((k, v) {
      expect(tierEmoji[int.parse(k)], v, reason: 'emoji $k');
    });
  });

  test('every accent matches the JS', () {
    (reference['theme'] as Map<String, dynamic>).forEach((k, v) {
      final theme = tierThemes[int.parse(k)]!;
      final expected = v as Map<String, dynamic>;
      expect(theme.accent, expected['accent'], reason: 'accent $k');
      expect(theme.accentLight, expected['accentLight'], reason: 'light $k');
      expect(theme.labelBg, expected['labelBg'], reason: 'labelBg $k');
    });
  });

  test('every gradient rebuilds the JS string exactly', () {
    (reference['theme'] as Map<String, dynamic>).forEach((k, v) {
      expect(
        css(tierThemes[int.parse(k)]!.bg),
        (v as Map<String, dynamic>)['bg'],
        reason: 'dark $k',
      );
    });
    (reference['bgLight'] as Map<String, dynamic>).forEach((k, v) {
      expect(css(tierThemes[int.parse(k)]!.bgLight), v, reason: 'light $k');
    });
  });

  test('every ALPHA-SUFFIXED colour is six-digit hex', () {
    // Two-character alpha suffixes are concatenated onto these three. A
    // shorthand makes that five-digit nonsense and the style silently vanishes.
    final six = RegExp(r'^#[0-9a-fA-F]{6}$');
    for (final entry in tierThemes.entries) {
      for (final hex in [
        entry.value.accent,
        entry.value.accentLight,
        entry.value.labelBg,
      ]) {
        expect(six.hasMatch(hex), isTrue, reason: 'tier ${entry.key}: $hex');
      }
    }
  });

  test('a gradient stop may be shorthand, and tier 3 is', () {
    // Nothing concatenates alpha onto a stop, so the source's own `#111` is
    // carried verbatim rather than tidied into a diff for no behaviour.
    expect(tierThemes[3]!.bg.stops.last.$1, '#111');
  });

  test('a gradient always runs from 0% to 100%', () {
    for (final entry in tierThemes.entries) {
      for (final g in [entry.value.bg, entry.value.bgLight]) {
        expect(g.stops.first.$2, 0, reason: 'tier ${entry.key}');
        expect(g.stops.last.$2, 100, reason: 'tier ${entry.key}');
      }
    }
  });

  test('the position labels rename FWD to ATK and nothing else', () {
    expect(positionLabel['FWD'], 'ATK');
    expect(positionLabel['MID'], 'MID');
    expect(positionLabel['DEF'], 'DEF');
    expect(positionLabel['GK'], 'GK');
  });
}

/// The JS writes whole percentages without a trailing `.0`.
String _pct(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
