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
import 'package:merge_empire_fc/i18n/catalogs.g.dart';
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

    test(
      'A <strong> IS NOTHING AT ALL, and one of them is on screen today',
      () {
        // `cup.win_reward.body` is the cup sponsor offer's line and it is
        // RENDERED — the player was reading `<strong>Nike</strong> wants to
        // sponsor <strong>Smith</strong>.` off a Coach Colin card. Twenty-three
        // entries carry the tag; this is the one that had a caller.
        final out = t('cup.win_reward.body', {
          'sponsor': 'Nike',
          'player': 'Smith',
        });
        expect(out, isNot(contains('<strong')));
        expect(out, isNot(contains('</strong')));
        expect(out, 'Nike wants to sponsor Smith.');
      },
    );

    test('and every locale is clean of THAT too', () {
      for (final id in localeIds) {
        setLocale(id);
        for (final key in [
          'cup.win_reward.body',
          'prestige.body',
          'merge.warn.lose_sponsor',
        ]) {
          expect(
            t(key),
            isNot(contains('strong>')),
            reason: '$id/$key still carries markup',
          );
        }
      }
      resetLocale();
    });

    test('AND `<strong>` WAS NOT THE ONLY TAG IN THERE', () {
      // Nine entries carry markup `<strong>` never covered — seven
      // `offseason.*` built on `<b>{n}</b>`, `tut.welcome.body`, and
      // `squad.subtext` with a `<span style="color:…">` around the form arrows.
      // None of the nine has a caller today, which is exactly the position
      // `cup.win_reward.body` was in until a screen reached for it.
      for (final key in [
        'offseason.injuries_recovered_n',
        'offseason.injuries_shortened_one',
        'offseason.sponsors_expired_n',
        'tut.welcome.body',
        'squad.subtext',
      ]) {
        final out = t(key, {'n': 3});
        expect(out, isNot(contains('<')), reason: key);
        expect(out, isNot(contains('>')), reason: key);
      }
    });

    test('and the span leaves its GLYPHS behind, which is the sentence', () {
      // `squad.subtext` explains the form arrows, and the arrows were inside
      // the span the DOM coloured. Stripping the tag has to keep what it wrapped
      // or the line stops making sense.
      final out = t('squad.subtext');
      expect(out, contains('▲▲'));
      expect(out, contains('▼▼'));
      expect(out, isNot(contains('span')));
      expect(out, isNot(contains('color')));
    });

    test('every locale is clean of the whole class, not one tag', () {
      // The strip is by tag CLASS now rather than by a list somebody maintains:
      // a `<b>`, an `<i>`, an `<em>` and a `<span …>` all mean emphasis, all
      // cannot survive as a `String`, and all come off at this boundary.
      final tag = RegExp(
        r'</?(strong|b|i|em|span|u|small)(\s[^<>]*)?>',
        caseSensitive: false,
      );
      for (final id in localeIds) {
        setLocale(id);
        for (final key in catalogs[id]!.keys) {
          expect(
            tag.hasMatch(t(key)),
            isFalse,
            reason: '$id/$key still renders its own markup',
          );
        }
      }
      resetLocale();
    });

    test('a string carrying BOTH loses both', () {
      // The two replacements run over the same template, so a string that grows
      // a line break inside an emphasised run cannot come out half-done.
      expect(t('tut.merge.body'), isNot(contains('<')));
    });

    test('a string with no markup is handed back untouched', () {
      // The guard is a `contains('<')` so the common case does no work at all.
      expect(t('common.cancel'), isNot(contains('\n')));
    });
  });
}
