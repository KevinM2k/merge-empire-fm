/// The catalogue and the Play Console list have to stay the same list.
///
/// `tool/pgs/build_import.py` turns the eighty-one achievements into the zip
/// Play imports, and every rule it has to satisfy is Google's rather than
/// ours: a points budget for the whole game, a length cap on a name, and a CSV
/// format with no quoting at all, so a comma anywhere in a name or description
/// is a column break. **None of that fails loudly at the Console.** An over-long
/// name is truncated, a stray comma shifts every later column, and a points
/// total over budget is refused for the whole file with no indication of which
/// row spent it. Cheaper to fail here.
///
/// The other half is the checklist: nine achievements had no row in
/// `pgs_achievements.dart` at all, which reads exactly like a null one at
/// runtime and is invisible until the Console list is built off the wrong file.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/achievements.dart';
import 'package:merge_empire_fc/data/pgs_achievements.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';

/// Play's own limits — https://developer.android.com/games/pgs/achievements
const int maxName = 100;
const int maxDescription = 500;
const int maxTotalPoints = 2000;
const int maxAchievements = 400;

/// The string as the CSV will carry it.
///
/// **Mirrors `sanitise` in `tool/pgs/build_import.py`** — the format has no
/// quoting, so a comma or a line break ends the column wherever it appears, and
/// both become a space. Two implementations of one rule is a drift risk worth
/// naming: if the Python one changes, this changes with it.
String consoleSafe(String text) => text
    .replaceAll(RegExp(r'[,\r\n\t]+'), ' ')
    .replaceAll(RegExp(r'\s{2,}'), ' ')
    .trim();

void main() {
  tearDown(resetLocale);

  test('every achievement has a Console row, and nothing else does', () {
    final ids = achievements.map((a) => a.id).toList();
    expect(pgsAchievementIds.keys, ids, reason: 'ids map, in catalogue order');
    expect(pgsAchievementPoints.keys, ids, reason: 'points map, in catalogue order');
  });

  test('the list fits in Play\'s achievement limit', () {
    expect(achievements.length, lessThanOrEqualTo(maxAchievements));
  });

  group('points', () {
    test('each is 5 to 200 and a multiple of five', () {
      for (final entry in pgsAchievementPoints.entries) {
        expect(
          entry.value,
          inInclusiveRange(5, 200),
          reason: '${entry.key} is outside Play\'s per-achievement range',
        );
        expect(entry.value % 5, 0, reason: '${entry.key} is not a multiple of five');
      }
    });

    test('the whole game stays inside the 2,000 point budget', () {
      final total = pgsAchievementPoints.values.fold(0, (sum, p) => sum + p);
      expect(
        total,
        lessThanOrEqualTo(maxTotalPoints),
        reason: 'Play refuses the import outright over budget',
      );
      // Google's own advice is to keep some back for achievements added later.
      // Not a hard rule, so this is a floor rather than an assertion of intent.
      expect(maxTotalPoints - total, greaterThanOrEqualTo(100));
    });
  });

  group('English copy', () {
    test('names survive the comma rule and stay unique', () {
      final seen = <String, String>{};
      for (final a in achievements) {
        final name = consoleSafe(a.title);
        expect(name, isNotEmpty, reason: a.id);
        expect(
          seen.containsKey(name),
          isFalse,
          reason: '$name is the Console name of both ${seen[name]} and ${a.id}, '
              'and the id sync matches on exactly that string',
        );
        seen[name] = a.id;
      }
    });

    test('names and descriptions are inside the length caps', () {
      for (final a in achievements) {
        expect(consoleSafe(a.title).length, lessThanOrEqualTo(maxName), reason: a.id);
        expect(
          consoleSafe(a.description).length,
          lessThanOrEqualTo(maxDescription),
          reason: a.id,
        );
      }
    });
  });

  test('every translation is inside the caps too', () {
    // The nine non-English catalogues, asked for their OWN entry: `t()` falls
    // back to English, so a blind ask would measure English nine times.
    for (final locale in localeIds) {
      if (locale == 'en') continue;
      final catalog = catalogFor(locale);
      setLocale(locale);
      for (final a in achievements) {
        final titleKey = 'ach.title.${a.id}';
        final descKey = 'ach.desc.${a.id}';
        if (catalog.containsKey(titleKey)) {
          final name = consoleSafe(t(titleKey));
          expect(name, isNotEmpty, reason: '$locale ${a.id}');
          expect(name.length, lessThanOrEqualTo(maxName), reason: '$locale ${a.id}');
        }
        if (catalog.containsKey(descKey)) {
          expect(
            consoleSafe(t(descKey)).length,
            lessThanOrEqualTo(maxDescription),
            reason: '$locale ${a.id}',
          );
        }
      }
    }
  });

  test('the comma rule only ever removes commas and whitespace', () {
    // The guard on the guard: `consoleSafe` must not be able to change a string
    // in any other way, or the Console would be showing copy nobody wrote.
    for (final a in achievements) {
      for (final text in [a.title, a.description]) {
        final cleaned = consoleSafe(text);
        expect(cleaned.contains(','), isFalse);
        expect(cleaned.contains('\n'), isFalse);
        expect(
          cleaned.replaceAll(' ', ''),
          text.replaceAll(RegExp(r'[,\s]'), ''),
          reason: 'the rule changed more than punctuation in ${a.id}',
        );
      }
    }
  });

  test('a mapped Console id is a plausible one', () {
    // The id belongs to this game — `pgs_app_id_test` decodes it and checks the
    // project number. Here: the shape, so a truncated paste is caught early.
    for (final entry in pgsAchievementIds.entries) {
      final id = entry.value;
      if (id == null) continue;
      expect(id, startsWith('Cgk'), reason: entry.key);
      expect(id.length, greaterThanOrEqualTo(16), reason: entry.key);
    }
  });
}
