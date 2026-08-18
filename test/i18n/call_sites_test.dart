/// Ported from `../merge-empire-fc/src/i18n/i18n.test.js`.
///
/// The scan below is why the i18n layer landed before the screens did: it fails
/// the build the moment a screen names a key English does not have, rather than
/// letting `ach.title.foo` render across a card.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/data/quests.dart';
import 'package:merge_empire_fc/i18n/catalogs.g.dart';

void main() {
  final en = catalogs['en']!;

  List<File> dartFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .toList();

  // Literal first arguments only. A key containing $ is built at runtime and is
  // covered by the id-driven checks below instead. The lookbehind is what stops
  // `format(` and `expect(` matching the bare `t(`.
  final tCall = RegExp(r"(?<![\w.])t\(\s*'([^'$\\]+)'");
  final tNameCall = RegExp(r"(?<![\w.])tName\(\s*'([^'$\\]+)'");

  test('every literal t() key in lib/ exists in English', () {
    final used = <String, String>{};
    for (final file in dartFiles()) {
      for (final m in tCall.allMatches(file.readAsStringSync())) {
        used[m.group(1)!] = file.path;
      }
    }
    final missing = used.entries
        .where((e) => !en.containsKey(e.key))
        .map((e) => '${e.key}  (${e.value})')
        .toList();
    expect(
      missing,
      isEmpty,
      reason: 'These render as their own key:\n${missing.join('\n')}',
    );
  });

  test('every tName() prefix resolves at least one English key', () {
    final prefixes = <String, String>{};
    for (final file in dartFiles()) {
      for (final m in tNameCall.allMatches(file.readAsStringSync())) {
        prefixes[m.group(1)!] = file.path;
      }
    }
    final unresolved = prefixes.entries
        .where((e) => !en.keys.any((k) => k.startsWith('${e.key}.')))
        .map((e) => '${e.key}  (${e.value})')
        .toList();
    expect(unresolved, isEmpty);
  });

  test('the scan actually looked at something', () {
    // Guards the two above from passing vacuously before any screen exists.
    expect(dartFiles(), isNotEmpty);
  });

  group('keys built from ids at render time', () {
    test('every quest has an English string', () {
      final missing = questBank
          .where((q) => !en.containsKey('quest.${q.id}'))
          .map((q) => q.id)
          .toList();
      expect(missing, isEmpty);
    });

    // A quest whose target scales writes {n} into the row.
    //
    // The JS discriminates on `typeof q.target === 'function'`, which does not
    // port: `QuestDef.target` is `int Function(int divIdx)` for every quest, so
    // a literal target is a constant function rather than a number. Scaling is
    // asked about instead — a target that moves across divisions is one that
    // scales.
    test('a scaling quest interpolates its target', () {
      bool scales(QuestDef q) {
        final first = resolveTarget(q, 0);
        return List.generate(10, (i) => i)
            .any((i) => resolveTarget(q, i) != first);
      }

      final flat = questBank
          .where(scales)
          .where((q) => !(en['quest.${q.id}'] ?? '').contains('{n}'))
          .map((q) => q.id)
          .toList();
      expect(flat, isEmpty);
    });

    final customiser = <String, List<String>>{
      'hair': hairStyleIds,
      'beard': facialHairIds,
      'hat': hatIds,
      'face': faceIds,
      'color': hairColorIds,
    };

    customiser.forEach((kind, ids) {
      test('names every $kind option', () {
        final missing = ids
            .where((id) => !en.containsKey('customise.item.$kind.$id'))
            .toList();
        expect(missing, isEmpty);
      });
    });

    // Skin is the exception: one interpolated key for all eight tones, because
    // the swatch carries the information and inventing eight names for shades
    // of human skin is a worse label than a number.
    test('numbers the skin tones instead of naming them', () {
      expect(en['customise.item.skin.tone'], contains('{n}'));
      for (final tone in skinTones) {
        expect(en.containsKey('customise.item.skin.${tone.$1}'), isFalse);
      }
    });

    test('names every build, outfit and emote', () {
      for (final id in buildIds) {
        expect(en.containsKey('customise.build.$id'), isTrue, reason: id);
      }
      for (final id in outfitIds) {
        expect(en.containsKey('customise.outfit.$id'), isTrue, reason: id);
      }
      for (final id in gestureIds) {
        expect(en.containsKey('customise.emote.$id'), isTrue, reason: id);
      }
    });
  });

  // Every player has a gender and about half are women, so a string saying "he"
  // is wrong roughly half the time it renders. That is how "{wage} a second
  // while he's here" shipped on a loan offer for a female player, with eight
  // more like it. English only, deliberately: the gendered languages carry
  // gender in verb and adjective agreement rather than in a word this could
  // find, so the same scan there returns dozens of legitimate hits and would be
  // switched off inside a week. Those catalogues need a translation pass, which
  // no test stands in for.
  test('no English string assumes a player, or a manager, is male', () {
    final pronoun = RegExp(
      r'\b(he|him|his|she|her|hers|himself|herself)\b',
      caseSensitive: false,
    );
    const allowed = <String>{};
    final offenders = en.entries
        .where((e) => !allowed.contains(e.key) && pronoun.hasMatch(e.value))
        .map((e) => '${e.key}: ${e.value}')
        .toList();
    expect(offenders, isEmpty);
  });
}
