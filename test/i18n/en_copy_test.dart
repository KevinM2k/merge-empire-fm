/// **THE COPY THIS REPO OWNS, and the guards it needs because nothing
/// generates it.**
///
/// The ten catalogues come out of a JS repo that is being retired, and
/// `lib/i18n/en_copy.dart` is where English copy is written from now on. It is
/// hand-edited, so it gets the checks the generator used to give for free: no
/// key drift, no placeholder a call site does not pass, no empty variant.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/catalogs.g.dart';
import 'package:merge_empire_fc/i18n/en_copy.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';

void main() {
  tearDown(resetLocale);

  final generated = catalogs['en']!;
  final placeholder = RegExp(r'\{[^}]+\}');
  Set<String> holders(String s) =>
      placeholder.allMatches(s).map((m) => m.group(0)!).toSet();

  test('every [enMore] key widens a pool that already exists', () {
    // A key here that English does not have means the extra lines are the WHOLE
    // pool, which is legal and is almost always a typo in the key. A genuinely
    // new key belongs in [enCopy], where it reads as one.
    final orphans = enMore.keys.where((k) => !generated.containsKey(k)).toList();
    expect(
      orphans,
      isEmpty,
      reason: 'these widen nothing — did you mean enCopy?\n${orphans.join('\n')}',
    );
  });

  test('extra lines introduce no placeholder the generated pool lacks', () {
    // **This is the one that bites.** A pool's variants do not all have to use
    // the same placeholders, but a variant may only use ones the CALL SITE
    // passes — and the only evidence of what a call site passes is what the
    // shipped variants already use. `report.clean_sheet` shipped a line naming
    // `{opp}` when its caller passed `{club}` alone, and one write-up in three
    // printed the brace at the player.
    final offenders = <String>[];
    enMore.forEach((key, extra) {
      final known = holders(generated[key] ?? '');
      for (final line in extra.split('|')) {
        final unknown = holders(line).difference(known);
        if (unknown.isNotEmpty) offenders.add('$key: ${unknown.join(' ')}');
      }
    });
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('no empty or blank variant anywhere', () {
    final bad = <String>[];
    void check(String key, String value) {
      for (final line in value.split('|')) {
        if (line.trim().isEmpty) bad.add(key);
      }
    }

    enMore.forEach(check);
    enCopy.forEach(check);
    expect(bad, isEmpty, reason: 'an empty variant prints as a blank line');
  });

  test('the overlay is what t() actually reads', () {
    setLocale('en');
    // Every extra line is reachable through the merged catalogue, which is the
    // whole point of the file.
    enMore.forEach((key, extra) {
      final whole = englishCatalog[key]!;
      for (final line in extra.split('|')) {
        expect(
          whole.split('|'),
          contains(line),
          reason: '$key lost a line somewhere in the merge',
        );
      }
    });
  });

  test('a widened pool is longer than the generated one it came from', () {
    for (final key in enMore.keys) {
      expect(
        englishCatalog[key]!.split('|').length,
        greaterThan(generated[key]!.split('|').length),
        reason: '$key did not actually grow',
      );
    }
  });

  test('the other nine catalogues are untouched by it', () {
    // The overlay is English only. A translation keeps its own pool, and a key
    // only English has resolves through `t()`'s existing fallback.
    for (final id in catalogs.keys.where((k) => k != 'en')) {
      expect(catalogFor(id), same(catalogs[id]));
    }
  });

  test('an English-only key still resolves in every locale', () {
    // The fallback chain is what makes [enCopy] safe to add a key to without
    // ten translations for it.
    final key = enMore.keys.first;
    for (final id in catalogs.keys) {
      setLocale(id);
      expect(t(key), isNot(key), reason: '$key renders as its own key in $id');
    }
  });
}
