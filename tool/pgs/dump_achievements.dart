/// Dumps the achievement catalogue as JSON for the Play Console import that
/// `build_import.py` assembles. Run it from the repo root:
///
/// ```bash
/// dart run tool/pgs/dump_achievements.dart > build/pgs/achievements.json
/// ```
///
/// **Dart rather than a script that reads the .dart files**, because the
/// catalogue is Dart and only Dart parses it: `achievements.dart` quotes three
/// of its eighty-one entries with `"` instead of `'` — `Gaffer's Call` and the
/// two beside it carry an apostrophe — and a regex sweep silently returned
/// seventy-eight rows for a list of eighty-one. The three it dropped were real
/// achievements that would simply not have appeared in the Console.
///
/// The other half of the reason is the copy. A locale's title is only worth
/// exporting when that locale's OWN catalogue has the key: `t()` falls back to
/// English, so asking it blind would fill the French column with English and
/// Play would then show that English happily, believing it was a translation.
/// `catalogFor(locale)` is asked whether the key is there BEFORE `t()` is asked
/// what it says — the same rule `match_report_test` enforces on the report.
///
/// Nothing here is Flutter, so it runs under plain `dart run` with no engine.
library;

import 'dart:convert';
import 'dart:io';

import 'package:merge_empire_fc/data/achievements.dart';
import 'package:merge_empire_fc/data/pgs_achievements.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';

/// The four achievements whose icon the JS embedded as markup rather than an
/// emoji, and what the Console icon should draw instead.
///
/// **In game these four currently draw the `🏅` fallback**, because
/// `Achievement.iconAsset` is read by nothing in `lib/ui` — `trophy_room_sheet`
/// and `achievement_unlock` both reach for `icon` and fall back. That is a
/// separate bug in the port and it is not fixed here; the Console list should
/// carry the icon the achievement is ABOUT rather than inherit the fallback,
/// so a coin achievement gets a coin.
const Map<String, String> assetGlyphs = {'coin': '🪙', 'wcTrophy': '🏆'};

/// The last-resort glyph, matching what the trophy room draws today.
const String fallbackGlyph = '🏅';

void main() {
  final out = <Map<String, dynamic>>[];
  for (var i = 0; i < achievements.length; i++) {
    final a = achievements[i];
    final locales = <String, Map<String, String>>{};
    for (final id in localeIds) {
      final catalog = catalogFor(id);
      final titleKey = 'ach.title.${a.id}';
      final descKey = 'ach.desc.${a.id}';
      // The locale's own entry, not English wearing its flag.
      final hasTitle = catalog.containsKey(titleKey);
      final hasDesc = catalog.containsKey(descKey);
      if (!hasTitle && !hasDesc) continue;
      setLocale(id);
      locales[id] = {
        // `t()` for the value, so the Console gets the string with the DOM
        // markup stripped exactly as a player sees it.
        if (hasTitle) 'title': t(titleKey),
        if (hasDesc) 'description': t(descKey),
      };
    }
    resetLocale();
    out.add({
      'id': a.id,
      'order': i + 1,
      'category': a.category,
      'glyph': a.icon ?? assetGlyphs[a.iconAsset] ?? fallbackGlyph,
      'points': pgsAchievementPoints[a.id],
      // The literal in the catalogue is the fallback for the twenty ids with no
      // `ach.title` key, and identical to the catalogue entry for the sixty-one
      // that have one.
      'title': locales['en']?['title'] ?? a.title,
      'description': locales['en']?['description'] ?? a.description,
      'availability': a.availability,
      'locales': locales,
    });
  }
  // ASCII off, so the emoji and the nine non-English catalogues survive the
  // round trip as themselves rather than as `\uXXXX`. `stdout` rather than
  // `print`, which the analyzer bans and which would also mangle the encoding
  // on a terminal that is not UTF-8.
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(out));
}
