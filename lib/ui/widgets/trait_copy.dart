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

import 'package:merge_empire_fc/data/match_traits.dart';
import 'package:merge_empire_fc/data/players.dart';
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

/// The second slot's copy, by the same rule. These keys live in
/// `en_copy.dart` and the nine `copy/*_copy.dart` overlays rather than the
/// generated catalogues — the JS has one trait per card and never named these.
String matchTraitName(MatchTrait trait) =>
    _catalogue('matchtrait.name.${trait.id}') ?? trait.name;

String matchTraitDesc(MatchTrait trait) =>
    _catalogue('matchtrait.desc.${trait.id}') ?? trait.desc;

/// `🔄 Super Sub III`, localised.
String matchTraitTitle(Map<String, dynamic>? instance) {
  if (instance == null) return '';
  final trait = getMatchTrait(instance['id'] as String?);
  if (trait == null) return '';
  final level = (instance['level'] as num?)?.toInt();
  final label = level == null ? null : getMatchTraitLevel(trait, level)?.label;
  final name = matchTraitName(trait);
  return label == null || label.isEmpty
      ? '${trait.icon} $name'
      : '${trait.icon} $name $label';
}

/// What a TIER is called — "Bronze", "Legend" — with the catalogue winning.
///
/// **The same rule and the same fallback as the trait names above.** It lived
/// as a private helper on the player index, which is the one screen that lists
/// every tier by name; the merge float needs the same words for the tier a
/// merge just produced, and two copies of "what is this tier called" is how one
/// screen ends up translated and the other does not.
String tierName(int tier) {
  final key = 'player.tier.$tier';
  final hit = t(key);
  if (hit != key) return hit;
  // The definition's English literal, which is what the catalogue is generated
  // FROM — so this only shows for a tier the catalogue has no key for.
  return players.firstWhere((p) => p.tier == tier).tierName;
}
