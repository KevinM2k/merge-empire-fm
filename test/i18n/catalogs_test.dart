/// Ported from `../merge-empire-fc/src/i18n/i18n.test.js`.
///
/// English is the single source of truth. These stop a translation drifting
/// away from it silently — a missing key renders as its own key, and an invented
/// placeholder renders as `{x}` across the screen.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/catalogs.g.dart';
import 'package:merge_empire_fc/i18n/detect.dart';

void main() {
  final en = catalogs['en']!;

  final placeholder = RegExp(r'\{[^}]+\}');
  Set<String> placeholders(String s) =>
      placeholder.allMatches(s).map((m) => m.group(0)!).toSet();

  test('ten catalogues, 2721 keys each', () {
    expect(catalogs.length, 10);
    // `report.next.*_both` are the newest: the write-up closes on BOTH clubs'
    // next fixtures, because it is a summary for anyone reading it rather than
    // for one set of supporters. Bump this WITH the generator run, never
    // instead of it.
    expect(en.length, 2721);
  });

  test('the shipped catalogues match the list the detector narrows to', () {
    expect(catalogs.keys.toList()..sort(), supportedLocales.toList()..sort());
    expect(supportedLocales, contains(fallbackLocale));
  });

  for (final id in catalogs.keys.where((k) => k != 'en')) {
    final cat = catalogs[id]!;

    test('$id has the same key set as en', () {
      expect(en.keys.where((k) => !cat.containsKey(k)), isEmpty);
      expect(cat.keys.where((k) => !en.containsKey(k)), isEmpty);
    });

    // A translation may DROP one of English's placeholders — 57 do, all of them
    // {s}, English's plural suffix, which an inflecting language has no use for.
    test('$id introduces no unknown placeholders', () {
      final offenders = <String>[];
      for (final k in en.keys) {
        final extra = placeholders(cat[k]!).difference(placeholders(en[k]!));
        if (extra.isNotEmpty) offenders.add('$k: ${extra.join(' ')}');
      }
      expect(offenders, isEmpty);
    });
  }
}
