/// What a product is CALLED, and what it says it gives you. Ported from
/// `pName`, `pDesc` and `pBonus` in `ui/screens/ShopScreen.js`.
///
/// **The catalogue wins; the product definition is the fallback.** The port was
/// rendering `IapProduct.name` and `IapProduct.desc` straight, which are the
/// English literals on the definition — so the whole shop was untranslatable,
/// and it was showing the wrong names even in English: `coins_small` is "Pocket
/// Change" in the catalogue and "Bag of Coins" on the record.
///
/// **And `{coins}` was reaching the player.** Every coin bundle's description is
/// literally `'{coins} coins'` and every gem bundle's is `'{gems} gems'`, so a
/// tile that printed the template printed the braces. Worse for `{coins}`, where
/// the number is not on the product at all: a bundle's payout scales with the
/// division, and `getProductGrantCoins` is the only thing that knows what this
/// save would actually be paid.
library;

import 'package:merge_empire_fc/engine/iap_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/util/format.dart';

/// A catalogue hit, or null when the key is missing — `t` hands back the key
/// itself, which is what the JS compares against.
String? _catalogue(String key) {
  final hit = t(key);
  return hit == key ? null : hit;
}

/// The localised name, falling back to the definition's own.
String productName(IapProduct product) =>
    _catalogue('product.${product.id}.name') ?? product.name;

/// The localised description, with the figures filled in.
///
/// [hardMode] takes the Hard-mode wording where the two differ — the Energy
/// Director refreshes squad fitness in Pro mode rather than topping up a pip
/// pool it does not have.
String productDesc(
  IapProduct product, {
  Map<String, dynamic>? state,
  bool hardMode = false,
}) {
  String fill(String s) => s
      .replaceAll('{coins}', formatCoins(getProductGrantCoins(state, product)))
      .replaceAll('{gems}', '${product.gems ?? ''}');

  if (hardMode && product.descHard != null) {
    return fill(
      _catalogue('product.${product.id}.descHard') ?? product.descHard!,
    );
  }
  return fill(_catalogue('product.${product.id}.desc') ?? product.desc ?? '');
}

/// The ribbon, or null when the product does not wear one.
String? productBonus(IapProduct product) {
  final bonus = product.bonus;
  if (bonus == null) return null;
  return _catalogue('product.${product.id}.bonus') ?? bonus;
}
