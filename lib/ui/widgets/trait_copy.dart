/// What a trait is CALLED, and what it says it does.
///
/// **The catalogue wins; the definition is the fallback** — the same rule and
/// the same reason as `shop_copy.dart`, and the same bug underneath it. The port
/// rendered `Trait.name` and `Trait.desc` straight, which are the English
/// literals on the record, so **every trait in the game was untranslatable** and
/// a French player's Finisher was still called "Finisher". All forty-two
/// `trait.name.*` and `trait.desc.*` strings sat generated in all ten catalogues
/// with nothing able to reach one.
///
/// **The engine's own `traitLabel` is deliberately left alone.** It is the JS's
/// function, its output is pinned against the JS's, and a fixture that starts
/// speaking German is not a fixture. This is the display layer's copy of the
/// same idea, which is exactly the split the shop already makes.
library;

import 'package:merge_empire_fc/data/traits.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';

/// A catalogue hit, or null when the key is missing — `t` hands back the key
/// itself, which is what the JS compares against.
String? _catalogue(String key) {
  final hit = t(key);
  return hit == key ? null : hit;
}

/// The localised name, falling back to the definition's own.
String traitName(Trait trait) =>
    _catalogue('trait.name.${trait.id}') ?? trait.name;

/// What it does, in a sentence.
String traitDesc(Trait trait) =>
    _catalogue('trait.desc.${trait.id}') ?? trait.desc;

/// `⚽ Finisher III`, localised — what `traitLabel` gives, in the player's own
/// language.
String traitTitle(Map<String, dynamic>? instance) {
  if (instance == null) return '';
  final trait = getTrait(instance['id'] as String?);
  if (trait == null) return '';
  final level = (instance['level'] as num?)?.toInt();
  final label = (level == null ? null : getTraitLevel(trait, level)?.label);
  final name = traitName(trait);
  return label == null || label.isEmpty
      ? '${trait.icon} $name'
      : '${trait.icon} $name $label';
}

/// The one-line description of the trait a card is actually carrying.
String traitInstanceDesc(Map<String, dynamic>? instance) {
  final trait = getTrait(instance?['id'] as String?);
  return trait == null ? '' : traitDesc(trait);
}
