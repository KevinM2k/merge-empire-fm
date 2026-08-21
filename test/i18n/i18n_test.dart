/// The lookup layer, pinned against the live JS runtime.
///
/// The cases that matter are the failures: a key missing from the active
/// catalogue, a key missing everywhere, a param with nowhere to go and a
/// placeholder with no param. A screen hits all four, and none of them throw.
///
/// Regenerate with tool/dump_i18n_reference.mjs.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/util/format.dart';

void main() {
  final reference =
      jsonDecode(File('test/fixtures/i18n_reference.json').readAsStringSync())
          as Map<String, dynamic>;

  tearDown(() {
    resetLocale();
    resetFormatLocale();
  });

  group('t() matches the JS', () {
    for (final row
        in (reference['resolve'] as List).cast<Map<String, dynamic>>()) {
      test('${row['label']} (${row['locale']})', () {
        setLocale(row['locale'] as String);
        final params = (row['params'] as Map<String, dynamic>?) ?? const {};
        expect(t(row['key'] as String, params), row['value']);
      });
    }
  });

  group('tPool()', () {
    setUp(() => setLocale('en'));

    test('picks ONE line out of a pooled key', () {
      // The pool is the copy: rendered straight, the player would read all of
      // it with pipes in between.
      final whole = t('transfer.declined_grudge', {'team': 'Real Somewhere'});
      expect(whole, contains('|'), reason: 'this key really is a pool');

      final lines = whole.split('|');
      for (var i = 0; i < 40; i++) {
        expect(
          lines,
          contains(
            tPool('transfer.declined_grudge', {'team': 'Real Somewhere'}),
          ),
        );
      }
    });

    test('a key with no pipes comes back whole', () {
      expect(tPool('nav.squad'), t('nav.squad'));
    });

    test('fills its params, the same as t()', () {
      expect(
        tPool('transfer.declined_grudge', {'team': 'Athletic'}),
        contains('Athletic'),
      );
    });
  });

  group('tName() matches the JS', () {
    setUp(() => setLocale('en'));

    // Rebuilt rather than read off the fixture: a Dart map literal cannot come
    // out of JSON typed as the mixed (String | Map) argument tName takes.
    final cases = <String, String Function()>{
      'by id': () => tName('nav', 'squad'),
      'by object': () => tName('nav', {'id': 'squad', 'name': 'Fallback'}),
      'unknown id falls back to name': () =>
          tName('nav', {'id': 'nope', 'name': 'Fallback'}),
      'unknown id, no name, falls back to id': () => tName('nav', 'nope'),
      'unknown id, object with no name': () => tName('nav', {'id': 'nope'}),
    };

    for (final row
        in (reference['tName'] as List).cast<Map<String, dynamic>>()) {
      final label = row['label'] as String;
      test(label, () => expect(cases[label]!(), row['value']));
    }

    test('every JS case is covered', () {
      expect(cases.length, (reference['tName'] as List).length);
    });
  });

  test('setLocale narrows to a shipped catalogue', () {
    for (final row
        in (reference['locale'] as List).cast<Map<String, dynamic>>()) {
      setLocale(row['set'] as String);
      expect(getLocale(), row['got'], reason: 'set ${row['set']}');
    }
  });

  test('the shipped ids match the JS', () {
    expect(localeIds, (reference['locales'] as List).cast<String>());
  });

  test('setLocale drives the number formatter too', () {
    // format.dart has carried a setFormatLocale seam since M1 waiting for this.
    setLocale('fr');
    expect(getFormatLocale(), 'fr');
    setLocale('xx');
    expect(getFormatLocale(), 'en');
  });

  test('resetLocale returns to English', () {
    setLocale('ja');
    resetLocale();
    expect(getLocale(), 'en');
  });

  test('a null id is tolerated by tName', () {
    setLocale('en');
    expect(tName('nav', null), '');
  });

  test('a null id is tolerated by setLocale', () {
    setLocale('ja');
    setLocale(null);
    expect(getLocale(), 'en');
  });

  group('copy written for a DOM', () {
    test('A <br> IS A LINE BREAK, not three characters of markup', () {
      // Three catalogue entries still carry it, and the port printed it
      // literally in the middle of a sentence. Fixed at the boundary rather than
      // in the catalogues: those are GENERATED from the JS, so patching the
      // output would be undone by the next `gen_i18n.mjs` run — and this covers
      // every locale and any string that grows one later.
      final out = t('sell.market_note');
      expect(out, isNot(contains('<br')));
      expect(out, contains('\n'));
    });

    test('and every locale is clean of it', () {
      for (final id in localeIds) {
        setLocale(id);
        for (final key in ['sell.market_note', 'common.market_fluctuates']) {
          expect(
            t(key),
            isNot(contains('<br')),
            reason: '\$id/\$key still carries markup',
          );
        }
      }
      resetLocale();
    });

    test('a string with no markup is handed back untouched', () {
      // The guard is a `contains('<')` so the common case does no work at all.
      expect(t('common.cancel'), isNot(contains('\n')));
    });
  });
}
