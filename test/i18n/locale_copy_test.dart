/// **THE NINE TRANSLATED OVERLAYS, and the guards they need.**
///
/// `lib/i18n/copy/*_copy.dart` is hand-written translation laid over the
/// generated catalogues, so it gets the checks the generator used to give for
/// free — the same ones `en_copy_test.dart` gives English, plus two this file
/// needs and English does not: nine files have to carry the SAME keys as each
/// other, and none of them may quietly hold a key nothing can print.
///
/// **What no test here checks is whether the translations are any good.**
/// Placeholders, key drift and blank variants are mechanical. Grammar is not,
/// and `locale_copy.dart`'s header says plainly that these have not been read
/// by a native speaker.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/catalogs.g.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/i18n/locale_copy.dart';

void main() {
  tearDown(resetLocale);

  final placeholder = RegExp(r'\{[^}]+\}');
  Set<String> holders(String s) =>
      placeholder.allMatches(s).map((m) => m.group(0)!).toSet();

  test('every overlay locale is a catalogue this app ships', () {
    for (final id in localeCopy.keys) {
      expect(catalogs.containsKey(id), isTrue, reason: '$id is not shipped');
    }
    expect(
      localeCopy.containsKey('en'),
      isFalse,
      reason: 'English goes through en_copy.dart, not here',
    );
  });

  test('the nine carry the same NEW keys as each other', () {
    // Nine files edited by hand drift. A key added to Spanish and forgotten in
    // Korean is a Korean write-up with an English sentence in the middle of it,
    // which is the exact fault this whole mechanism exists to remove — and it
    // would show up in one locale out of ten, on somebody's phone.
    //
    // **New keys only, and the distinction is the whole rule.** A key the
    // locale did not have is a hole, and a hole has to be filled in all nine or
    // English shows through. A key it DID have is a replacement, and whether
    // one is wanted is a question about that language: the six with grammatical
    // number replace `report.table.*` to stop "1 places" and "1 puntos", and
    // Japanese, Korean and Chinese rightly do not, because their generated
    // lines were never wrong.
    Set<String> newKeys(String id) => localeCopy[id]!.keys
        .where((k) => !catalogs[id]!.containsKey(k))
        .toSet();
    final expected = newKeys('es');
    expect(expected, isNotEmpty, reason: 'the overlay fills no holes at all?');
    for (final id in localeCopy.keys) {
      expect(
        newKeys(id),
        expected,
        reason: '$id has drifted from the other overlays',
      );
    }
  });

  test('no overlay key is one nothing can print', () {
    // Every key here is a match-report pool, and English owns the full set —
    // either generated or through `en_copy.dart`. A key English does not have
    // is a typo, and a typo here is silent: the entry simply never resolves and
    // the locale falls back, which looks exactly like the bug being fixed.
    final offenders = <String>[];
    localeCopy.forEach((id, copy) {
      for (final key in copy.keys) {
        if (!englishCatalog.containsKey(key)) offenders.add('$id: $key');
      }
    });
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('no overlay line invents a placeholder nothing is known to pass', () {
    // The one that bites, and the reason `report.clean_sheet` once printed a
    // literal `{opp}` at a player.
    //
    // **The reference is English AND the generated entry together, not the
    // generated entry alone.** Written the strict way this failed on two dozen
    // honest lines: the generated Spanish headline says "{score}. Ni bonito ni
    // cómodo" and never names `{club}`, but the call site passes `club`,
    // `ours`, `theirs`, `total` and four more besides — a pool's variants are
    // evidence of what a caller passes and never the whole of it. That is
    // exactly why `en_copy_test` runs this over `enMore` and not over `enCopy`:
    // widening a pool has the old lines as its contract, REPLACING one does
    // not.
    //
    // So this catches the typo and the invention — a `{minutes}` or a
    // `{scorer}` that no catalogue anywhere uses for that key — and leaves the
    // real contract to `match_report_test`'s matrix, which expands every
    // variant of every beat against the parameters the engine actually passes.
    final offenders = <String>[];
    localeCopy.forEach((id, copy) {
      final generated = catalogs[id]!;
      copy.forEach((key, value) {
        final known = holders(generated[key] ?? '')
          ..addAll(holders(englishCatalog[key] ?? ''));
        for (final line in value.split('|')) {
          final unknown = holders(line).difference(known);
          if (unknown.isNotEmpty) offenders.add('$id $key: ${unknown.join(' ')}');
        }
      });
    });
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('no empty or blank variant anywhere', () {
    final bad = <String>[];
    localeCopy.forEach((id, copy) {
      copy.forEach((key, value) {
        for (final line in value.split('|')) {
          if (line.trim().isEmpty) bad.add('$id: $key');
        }
      });
    });
    expect(bad, isEmpty, reason: 'an empty variant prints as a blank line');
  });

  test('every pool offers more than one line', () {
    // The write-up is seeded off the fixture and picks one variant per beat. A
    // pool of one is legal and means every match reads identically at that
    // sentence, which is what the pools exist to avoid.
    //
    // **A KEY THAT IS NOT A POOL IN ENGLISH IS NOT ONE HERE EITHER.** These
    // files were written for the write-up, where every key is a pool, so the
    // rule used to be "every value must have two variants" — which fails the
    // moment a plain string needs the other nine locales, and plain strings are
    // exactly what these files are also for: a settings hint has one wording,
    // in every language. The invariant worth keeping is that a translation
    // never NARROWS a pool to a single line.
    final thin = <String>[];
    localeCopy.forEach((id, copy) {
      final generated = catalogs[id]!;
      copy.forEach((key, value) {
        final source = generated[key] ?? englishCatalog[key] ?? '';
        if (!source.contains('|')) return;
        if (value.split('|').length < 2) thin.add('$id: $key');
      });
    });
    expect(thin, isEmpty, reason: thin.join('\n'));
  });

  test('the overlay is what t() actually reads', () {
    // The merge happens once per locale in `catalogFor` and is cached. If it
    // ever stopped running, every one of these keys would silently fall back to
    // English and nothing else would fail.
    localeCopy.forEach((id, copy) {
      setLocale(id);
      final merged = catalogFor(id);
      copy.forEach((key, value) {
        expect(merged[key], value, reason: '$key did not survive the merge in $id');
      });
    });
  });

  test('and the generated entries around it are left alone', () {
    // The overlay replaces the keys it names and nothing else.
    localeCopy.forEach((id, copy) {
      final merged = catalogFor(id);
      catalogs[id]!.forEach((key, value) {
        if (copy.containsKey(key)) return;
        expect(merged[key], value, reason: '$key changed in $id');
      });
    });
  });
}
