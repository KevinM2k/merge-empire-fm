/// **A KEY THAT RESOLVES IS NOT A KEY THAT IS TRANSLATED.**
///
/// `t()` falls back to English for a key a locale does not carry, which is the
/// right behaviour and is why `call_sites_test` can prove every call site
/// resolves. What nothing checked is the other shape of the same hole: a
/// catalogue that carries the key and holds the ENGLISH SENTENCE in it. The
/// generator copies whatever `en.js`'s siblings had, and a line added to
/// English and pasted into the other nine as a placeholder arrives here
/// looking exactly like a translation — same key, non-empty value, no
/// fallback, nothing to notice.
///
/// Reported from a live save in Italian: the subs panel, the difficulty
/// switch, the tutorial's loan spell, two coach tips, the champions card and
/// the Iron Lungs trait were all still in English, and forty-three keys were
/// English in all nine at once.
///
/// **The four non-Latin catalogues are the detector.** Italian left in English
/// and Italian translated are both Latin script, so equality with English is
/// the only signal there and it goes silent the moment English itself is
/// reworded — which is how `difficulty.switch.*` hid: the nine hold an OLDER
/// English than `en.g.dart` does. Arabic, Japanese, Korean and Chinese have no
/// such ambiguity. A value with a run of Latin letters in it and not one
/// character of the locale's own script has not been translated, and a key
/// that fails in three of the four was never translated for anybody.
///
/// So this is a work queue with an allowlist, not a grammar check. Every entry
/// in [_allowed] says why it is allowed to be Latin.
///
/// **AND THE LATIN FIVE GET THEIR OWN, NARROWER CHECK.** Italian left in
/// English and Italian translated are both Latin script, so the only signal
/// there is equality with the English string — which goes silent the moment
/// English itself is reworded, and says nothing about a bad translation. It is
/// worth having anyway: it is what catches a key added to `en.js` and pasted
/// into its siblings, which is how all forty-three of these arrived. See
/// [_allowedLatin] for the loanwords it has to be told about.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/catalogs.g.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';

/// The scripts each of the four writes in. A value carrying none of its own is
/// the tell.
const Map<String, String> _script = <String, String>{
  'ar': r'[؀-ۿ]',
  'ja': r'[぀-ヿ一-鿿]',
  'ko': r'[가-힯]',
  'zh': r'[一-鿿]',
};

/// Keys whose value is Latin in every language, and why.
const Map<String, String> _allowed = <String, String>{
  // Placeholders and glyphs with no words in them at all. The English "word"
  // the detector sees is a brace name or a unit the layout owns.
  'leaderboard.pill_division_regional': 'two placeholders and a separator',
  'toast.payout_suffix': 'a separator and a placeholder',
  'event.toast.reward_claimed': 'two emoji and a placeholder',
  'game.throughball.score': 'a tick and a fraction',
  'grid.merged_into': 'an emoji and the player\'s own name',
  'card.tier_locked': 'T{tier} MAX — a badge, and it has to fit a card corner',

  // A platform name, which is the same in every store.
  'leaderboard.platform_android': 'a proper noun',

  // And the nine nothing can print — see [_noCaller], which both allowlists
  // fold in, because the reason is the same in either script.
  ..._noCaller,
};

/// **NINE STRINGS NOTHING CAN PRINT.**
///
/// `coach.tactic_tip.*` has no caller anywhere in `lib/` — not a literal, not a
/// key built from a prefix — so these are shipped copy for a feature the port
/// has not built: the pre-match tactical read that names the tactic and the
/// opponent. Translating them would be translating dead text; see
/// `docs/REMAINING.md`.
///
/// Listed one by one rather than by prefix so that building the feature has to
/// come back through here, and held apart from the two allowlists so the reason
/// is written once rather than in both scripts.
const Map<String, String> _noCaller = <String, String>{
  'coach.tactic_tip.open_dominant': 'no caller in lib/',
  'coach.tactic_tip.open_favoured': 'no caller in lib/',
  'coach.tactic_tip.open_even': 'no caller in lib/',
  'coach.tactic_tip.open_underdog': 'no caller in lib/',
  'coach.tactic_tip.exploit_their_def': 'no caller in lib/',
  'coach.tactic_tip.counter_their_atk': 'no caller in lib/',
  'coach.tactic_tip.park_underdog': 'no caller in lib/',
  'coach.tactic_tip.tight_favoured': 'no caller in lib/',
  'coach.tactic_tip.tight_underdog': 'no caller in lib/',
};

/// The five Latin catalogues, where equality with English is the only tell.
const List<String> _latin = <String>['it', 'fr', 'de', 'es', 'pt'];

/// Keys that are legitimately the English word in four or more of the Latin
/// five. Mostly loanwords the languages have taken as they are.
const Map<String, String> _allowedLatin = <String, String>{
  'scene.dock.global': 'a loanword in all five',
  'leaderboard.platform_android': 'a proper noun',
  'settings.difficulty.easy': '"Casual" is the mode\'s name, not a word',
  'shop.section.premium': 'a loanword',
  'shop.section.premium_emoji': 'a loanword',
  'product.vip_pass.bonus': 'a loanword',
  'squad.formation.auto': 'a loanword, and it is a button 44pt wide',
  'asset.media_t3': 'a loanword',
  'settings.tab.audio': 'a loanword',
  'customise.item.hair.afro': 'a loanword',
  'cup.round_short.final': 'the word in es and pt; fr and de override it',
  ..._noCaller,
  // Placeholders and glyphs, the same as the list above.
  'leaderboard.pill_division_regional': 'two placeholders and a separator',
  'toast.payout_suffix': 'a separator and a placeholder',
  'event.toast.reward_claimed': 'two emoji and a placeholder',
  'game.throughball.score': 'a tick and a fraction',
  'card.tier_locked': 'T{tier} MAX — a badge that has to fit a card corner',
};

void main() {
  tearDown(resetLocale);

  // Four letters in a row, which skips "OK", "XI", "vs" and every unit.
  final latin = RegExp(r'[A-Za-z]{4}');

  test('no key is shipped as raw English in ar, ja, ko and zh at once', () {
    final offenders = <String>[];
    for (final entry in catalogs['en']!.entries) {
      if (_allowed.containsKey(entry.key)) continue;
      if (!latin.hasMatch(entry.value)) continue;
      final untranslated = <String>[];
      for (final id in _script.keys) {
        // **THE MERGED CATALOGUE, not the generated one.** `locale_copy.dart`
        // is where a translation the port owns lives, and a key fixed there is
        // fixed — reading `catalogs[id]` alone would report every one of them
        // as still broken.
        final value = catalogFor(id)[entry.key];
        if (value == null) continue;
        if (!latin.hasMatch(value)) continue;
        if (RegExp(_script[id]!).hasMatch(value)) continue;
        untranslated.add(id);
      }
      if (untranslated.length >= 3) {
        offenders.add('${entry.key}  (${untranslated.join(', ')})');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'these render in English on a phone set to ar/ja/ko/zh — translate '
          'them in lib/i18n/copy/, or say in _allowed why they are Latin:\n'
          '${offenders.join('\n')}',
    );
  });

  test('nor in it, fr, de, es and pt at once', () {
    // The Latin half. Weaker than the check above — it cannot tell a bad
    // translation from a good one, and it stops seeing a key the moment
    // English is reworded around it — but it is the half that would have
    // caught the subs panel, and it costs an allowlist of loanwords.
    final offenders = <String>[];
    for (final entry in catalogs['en']!.entries) {
      if (_allowedLatin.containsKey(entry.key)) continue;
      if (!latin.hasMatch(entry.value)) continue;
      final same = _latin
          .where((id) => catalogFor(id)[entry.key] == entry.value)
          .toList();
      if (same.length >= 4) {
        offenders.add('${entry.key}  (${same.join(', ')})');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'these are the English sentence in four or more of the Latin five — '
          'translate them in lib/i18n/copy/, or say in _allowedLatin why they '
          'are the English word:\n${offenders.join('\n')}',
    );
  });

  test('and the Latin allowlist has no stale entry either', () {
    final stale = <String>[];
    for (final key in _allowedLatin.keys) {
      if (!catalogs['en']!.containsKey(key)) {
        stale.add('$key: not in the English catalogue any more');
        continue;
      }
      final english = catalogs['en']![key];
      final translated =
          _latin.where((id) => catalogFor(id)[key] != english).toList();
      if (translated.length >= 4) stale.add('$key: translated in $translated');
    }
    expect(stale, isEmpty, reason: stale.join('\n'));
  });

  test('the allowlist has no stale entry', () {
    // An allowed key that has since been translated, or removed from the
    // catalogue, is a line that will outlive what it excuses.
    final stale = <String>[];
    for (final key in _allowed.keys) {
      if (!catalogs['en']!.containsKey(key)) {
        stale.add('$key: not in the English catalogue any more');
        continue;
      }
      final translated = _script.keys.where((id) {
        final value = catalogFor(id)[key];
        return value != null && RegExp(_script[id]!).hasMatch(value);
      }).toList();
      if (translated.length >= 3) stale.add('$key: translated in $translated');
    }
    expect(stale, isEmpty, reason: stale.join('\n'));
  });

  test('and the nine the report was made about are translated', () {
    // The Italian save's own list, pinned by name. The test above is the
    // general guard; this is the report it came from, so that a regeneration
    // that reverted the overlay fails as the bug rather than as a count.
    const reported = <String>[
      'match.subs',
      'match.subs.done',
      'match.subs.bench',
      'match.subs.pick_on',
      'match.subs.none_left',
      'difficulty.switch.toHard',
      'coachtip.subs_bench.body',
      'champ.body',
      'trait.desc.iron_lungs',
      // The ball the Italian player said we were calling a bubble.
      'game.training.intro',
    ];
    for (final id in catalogs.keys) {
      if (id == 'en') continue;
      final merged = catalogFor(id);
      for (final key in reported) {
        expect(
          merged[key],
          isNot(catalogs['en']![key]),
          reason: '$key is still the generated English in $id',
        );
        expect(
          merged[key],
          isNot(englishCatalog[key]),
          reason: '$key is still English in $id',
        );
      }
    }
  });

  test('and English itself no longer calls the ball a bubble', () {
    // `keeper_view.dart` draws a football. The nine translated "bubble"
    // faithfully, so the mistranslation was in the source.
    setLocale('en');
    expect(t('game.training.intro', {'n': '6', 'secs': '2'}), isNot(contains('bubble')));
    for (final id in catalogs.keys) {
      setLocale(id);
      final line = t('game.training.intro', {'n': '6', 'secs': '2'});
      expect(line, isNot(contains('bubble')));
      expect(line, isNot(contains('bolle')));
      expect(line, isNot(contains('burbuja')));
      expect(line, isNot(contains('bulles')));
      expect(line, isNot(contains('Blasen')));
      expect(line, isNot(contains('bolhas')));
      expect(line, isNot(contains('バブル')));
      expect(line, isNot(contains('거품')));
      expect(line, isNot(contains('气泡')));
      expect(line, isNot(contains('فقاعات')));
    }
  });
}
