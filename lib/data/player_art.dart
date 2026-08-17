/// Portrait variant table, ported from
/// `../merge-empire-fc/src/assets/playerArt.js`.
///
/// The JS file is mostly inline SVG for the fallback portraits, which is UI
/// work for a later milestone. Only the variant catalogue is here, because the
/// merge engine and save migration both key off it: a variant index decides a
/// card's gender, which decides its name pool and which cards may merge.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

/// Randomised per card instance so two cards of the same definition do not look
/// identical. Each variant overrides skin tone, hair colour and hair style;
/// variants marked female get long hair and a name from the female pools.
class PlayerVariant {
  const PlayerVariant({
    required this.skin,
    required this.hair,
    required this.hairStyle,
    required this.female,
  });

  final String skin;
  final String hair;
  final String hairStyle;
  final bool female;
}

const List<PlayerVariant> variants = [
  PlayerVariant(skin: '#F4C27F', hair: '#1a1a1a', hairStyle: 'normal', female: false),
  PlayerVariant(skin: '#8D5524', hair: '#0a0a0a', hairStyle: 'normal', female: false),
  PlayerVariant(skin: '#FFDBAC', hair: '#D2691E', hairStyle: 'long', female: true),
  PlayerVariant(skin: '#E0AC69', hair: '#3C1414', hairStyle: 'normal', female: false),
  PlayerVariant(skin: '#C68642', hair: '#1a1a1a', hairStyle: 'bald', female: false),
  PlayerVariant(skin: '#FAE0C9', hair: '#F7E7B4', hairStyle: 'long', female: true),
];

/// Number of portrait variants per definition.
const int playerVariants = 6;

/// Wraps out of range, matching the JS modulo. A negative index would throw in
/// Dart where JS returns undefined, so it is normalised first.
bool isVariantFemale([int variantIdx = 0]) {
  if (variants.isEmpty) return false;
  final idx = variantIdx % variants.length;
  return variants[idx < 0 ? idx + variants.length : idx].female;
}
