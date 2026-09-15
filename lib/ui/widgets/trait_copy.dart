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
import 'package:merge_empire_fc/engine/squad_rating.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
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
  // No emoji in front: wherever this is printed, the trait's mark is drawn
  // beside it as an icon — see `TraitGlyph`.
  return label == null || label.isEmpty ? name : '$name $label';
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

/// What a first-slot trait is worth on THIS card, at [trait]'s level — by
/// DIFFERENCE, because `getCardStats` is the single source of truth and
/// recomposing the bonus fields here is how the sheet and the sim come to
/// disagree. ATK and DEF in points; the other seven axes are the shipped
/// `feature.effect.*` labels.
List<String> traitEffectsOn(
  CardInstance? card,
  Map<String, dynamic>? trait,
  Map<String, dynamic> ratios,
) {
  if (card == null || trait == null) return const [];
  final def = getTrait(trait['id'] as String?);
  final level = (trait['level'] as num?)?.toInt();
  final lvl = level == null ? null : getTraitLevel(def, level);
  if (lvl == null) return const [];

  final bare = CardInstance(<String, dynamic>{...card.raw}..remove('trait'));
  final shown = CardInstance(<String, dynamic>{...card.raw, 'trait': trait});
  final with_ = getCardStats(shown, definitionRatios: ratios);
  final without = getCardStats(bare, definitionRatios: ratios);

  int pct(double v) => (v * 100).round();
  final rows = <String>[];
  void add(String key, int n) {
    if (n <= 0) return;
    rows.add(t('feature.effect.$key', {'n': '$n'}));
  }

  add('atk', with_.attack - without.attack);
  add('def', with_.defence - without.defence);
  add('income', pct(lvl.incomeBonus));
  add('matchrev', pct(lvl.matchRevBonus));
  add('injury', pct(lvl.injuryReduction));
  add('teaminjury', pct(lvl.teamInjuryReduction));
  add('recovery', pct(lvl.recoveryBonus));
  add('aging', lvl.agingReduction);
  add('stamina', pct(1 - (lvl.staminaMult ?? 1)));
  return rows;
}

/// The three levels' worth on THIS card, `I +2 ATK` style, for a first-slot
/// trait nobody holds yet — the catalogue's answer to "what does it do".
List<String> traitLadderOn(
  CardInstance? card,
  Trait trait,
  Map<String, dynamic> ratios,
) => [
  for (final level in trait.levels)
    '${level.label} ${traitEffectsOn(card, {'id': trait.id, 'level': level.level}, ratios).join(' ')}',
];

/// When it fires — the condition, in words. A description says what the
/// trait is; this says the circumstance, which is the thing to plan round.
String matchTraitWhen(MatchTrait trait) =>
    t('matchtrait.when.${trait.condition.name}');

/// What one level is worth, as a figure a manager can weigh: the rating lift
/// as a percentage, or for the two that are not a lift, what they are.
/// Asked for from the couch — "fights hardest when the drop is real" said
/// nothing about how hard.
String matchTraitEffect(MatchTrait trait, MatchTraitLevel level) {
  final pct = ((level.mult - 1) * 100).round();
  return switch (trait.condition) {
    MatchTraitCondition.tenMen => t('matchtrait.effect.squad', {'n': '$pct'}),
    MatchTraitCondition.booked => t('matchtrait.effect.booked', {
        'n': '${((1 - level.mult) * 100).round()}',
      }),
    MatchTraitCondition.injuryShrug => t('matchtrait.effect.shrug', {
        'n': '${(level.mult * 100).round()}',
      }),
    _ => t('matchtrait.effect.rating', {'n': '$pct'}),
  };
}

/// The three levels' worth, `I +4%` style, for a trait nobody holds yet.
List<String> matchTraitLadder(MatchTrait trait) => [
  for (final level in trait.levels)
    '${level.label} ${matchTraitEffect(trait, level)}',
];

/// `🔄 Super Sub III`, localised.
String matchTraitTitle(Map<String, dynamic>? instance) {
  if (instance == null) return '';
  final trait = getMatchTrait(instance['id'] as String?);
  if (trait == null) return '';
  final level = (instance['level'] as num?)?.toInt();
  final label = level == null ? null : getMatchTraitLevel(trait, level)?.label;
  final name = matchTraitName(trait);
  // No emoji in front: wherever this is printed, the trait's mark is drawn
  // beside it as an icon — see `TraitGlyph`.
  return label == null || label.isEmpty ? name : '$name $label';
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
