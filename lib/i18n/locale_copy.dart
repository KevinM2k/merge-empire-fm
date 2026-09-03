/// **THE OTHER NINE LOCALES' OWN COPY, on the same footing as `en_copy.dart`.**
///
/// `en_copy.dart` exists because the JS repo the catalogues are generated from
/// is being retired, which takes `tool/gen_i18n.mjs` with it — so English copy
/// is written there and laid over the generated map at load. Its header then
/// says the other nine are translations and nothing in this repo can write
/// them. That was true right up until the write-up stopped being a translation
/// problem and became a HOLE: thirty of the sixty-five keys the match report
/// can emit existed only in English, so a French player read a French headline,
/// a French shape line, and then four English sentences in the middle of the
/// same paragraph before the French table line at the end.
///
/// The English fallback in `t()` is the right behaviour for a missing string —
/// it is how a catalogue that has not caught up still renders. It is the wrong
/// behaviour for a paragraph that is being COMPOSED out of pools, because the
/// reader gets both languages in one block of prose rather than one language
/// that is behind.
///
/// So this is the same overlay, per locale. Nothing generated is edited by
/// hand; `catalogFor` merges these over the generated catalogue the way
/// `englishCatalog` merges `enCopy`.
///
/// **REPLACE ONLY, deliberately.** English has two maps because widening an
/// existing pool is the commonest thing anybody wants to do to it. Nothing here
/// widens anything: every entry is either a key the locale did not have, or a
/// pool whose generated wording the port has deliberately moved away from — the
/// three tactics pools that name the minute, and the headline pools that open
/// on the score. An append map would have no callers.
///
/// **HOT RESTART, NOT HOT RELOAD, after editing one of these**, for exactly the
/// reason `en_copy.dart` gives: the merge is cached per locale on first lookup,
/// and hot reload keeps the map it already built.
///
/// **These are the port's translations, not the spec repo's.** Everything in
/// `locales/*.g.dart` came out of `../merge-empire-fc/src/i18n/locales/`, which
/// is not in a cloud container and could not be consulted. Each file matches
/// the voice and the conventions of its own generated catalogue — whether the
/// club takes an article, whether a team takes a singular or a plural verb —
/// but they have not been read by a native speaker, and `report_locale_test`
/// checks placeholders rather than grammar. A correction from a player is worth
/// more than any of them.
library;

import 'package:merge_empire_fc/i18n/copy/ar_copy.dart';
import 'package:merge_empire_fc/i18n/copy/de_copy.dart';
import 'package:merge_empire_fc/i18n/copy/es_copy.dart';
import 'package:merge_empire_fc/i18n/copy/fr_copy.dart';
import 'package:merge_empire_fc/i18n/copy/it_copy.dart';
import 'package:merge_empire_fc/i18n/copy/ja_copy.dart';
import 'package:merge_empire_fc/i18n/copy/ko_copy.dart';
import 'package:merge_empire_fc/i18n/copy/pt_copy.dart';
import 'package:merge_empire_fc/i18n/copy/zh_copy.dart';

/// Per-locale overlays, by the id `catalogs` uses. English is not in here: it
/// has `enCopy` and `enMore`, and `catalogFor` sends it down the other path.
const Map<String, Map<String, String>> localeCopy = <String, Map<String, String>>{
  'es': esCopy,
  'pt': ptCopy,
  'fr': frCopy,
  'de': deCopy,
  'it': itCopy,
  'ja': jaCopy,
  'ko': koCopy,
  'zh': zhCopy,
  'ar': arCopy,
};
