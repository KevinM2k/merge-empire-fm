/// The shelves, derived from the save.
///
/// Every gate here is asked of the engine that owns it — `isUnlocked`,
/// `gemItemBlocked`, `voucherBlocked` — rather than reimplemented. `gemItemBlocked`
/// says so in its own doc: it was split out so the Shop can grey a row with a
/// reason instead of failing on tap.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/engine/gem_engine.dart';
import 'package:merge_empire_fc/engine/iap_engine.dart';
import 'package:merge_empire_fc/engine/look_pack_engine.dart';
import 'package:merge_empire_fc/engine/scout_voucher_engine.dart';
import 'package:merge_empire_fc/engine/shop_consumables_engine.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_copy.dart';

/// The coin-priced consumables: the sponge and the two season boosts.
typedef ConsumableTile = ({
  String id,
  String nameKey,
  String descKey,
  int cost,
  String? blocked,
});

const List<({String id, String nameKey, String descKey})> shopConsumables = [
  (
    id: 'magic_sponge',
    nameKey: 'shop.sponge_name',
    descKey: 'shop.sponge_desc',
  ),
  (
    id: 'kit_sponsor',
    nameKey: 'shop.kit_sponsor_name',
    descKey: 'shop.kit_sponsor_desc',
  ),
  (id: 'match_rev', nameKey: 'shop.tv_deal_name', descKey: 'shop.tv_deal_desc'),
];

final consumableTilesProvider = savePick<List<ConsumableTile>>(
  (s) => [
    for (final row in shopConsumables)
      (
        id: row.id,
        nameKey: row.nameKey,
        descKey: row.descKey,
        cost: consumableCost(s, row.id),
        blocked: consumableBlocked(s, row.id),
      ),
  ],
);

typedef GemItemTile = ({GemItem item, String? blocked});

typedef VoucherTile = ({int floor, int? cost, VoucherBlock? blocked});

typedef LookPackTile = ({String packId, LookTile tile});

/// The catalogue, minus anything gated to an event that is not running.
final shopProductsProvider = Provider<List<IapProduct>>(
  (ref) => getShopProducts(),
);

/// A real-money product with its copy already resolved: the catalogue's name and
/// description rather than the definition's English literals, and the figures
/// filled in from THIS save.
///
/// Resolved here rather than in the tile because it needs the save — a bundle's
/// `{coins}` is what the current division would actually pay, not the base on
/// the record.
typedef PaidTile = ({
  IapProduct product,
  String name,
  String desc,
  String? bonus,
});

final paidTilesProvider = savePick<List<PaidTile>>((s) {
  final hard = _map(s['settings'])['hardMode'] == true;
  return [
    for (final product in getShopProducts())
      (
        product: product,
        name: productName(product),
        desc: productDesc(product, state: s, hardMode: hard),
        bonus: productBonus(product),
      ),
  ];
});

/// What a coin bundle is multiplied by at this division. The tile shows what it
/// would pay HERE, which past Sunday League is not the figure on the product.
final coinMultProvider = savePick<int>(getDivisionCoinMult);

Map<String, dynamic> _map(Object? v) =>
    v is Map<String, dynamic> ? v : const <String, dynamic>{};

final gemItemTilesProvider = savePick<List<GemItemTile>>(
  (s) => [
    for (final item in gemItems)
      (item: item, blocked: gemItemBlocked(s, item.id)),
  ],
);

final voucherTilesProvider = savePick<List<VoucherTile>>((s) {
  final progression = s['progression'];
  final division = progression is Map<String, dynamic>
      ? progression['currentDivision'] as String?
      : null;
  return [
    for (final floor in voucherTiersFor(division))
      (
        floor: floor,
        cost: voucherCost(floor),
        blocked: voucherBlocked(s, floor),
      ),
  ];
});

/// Whether the Style Vault has been bought, so its case can read as open rather
/// than as an offer.
final styleVaultOwnedProvider = savePick<bool>(hasStyleVault);

final lookTilesProvider = savePick<List<LookPackTile>>((s) {
  final out = <LookPackTile>[];
  for (final pack in lookPacks) {
    final tile = lookTileState(s, pack.id);
    if (tile != null) out.add((packId: pack.id, tile: tile));
  }
  return out;
});
