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
import 'package:merge_empire_fc/providers/game_providers.dart';

typedef GemItemTile = ({GemItem item, String? blocked});

typedef VoucherTile = ({int floor, int? cost, VoucherBlock? blocked});

typedef LookPackTile = ({String packId, LookTile tile});

/// The catalogue, minus anything gated to an event that is not running.
final shopProductsProvider = Provider<List<IapProduct>>(
  (ref) => getShopProducts(),
);

final gemItemTilesProvider = savePick<List<GemItemTile>>(
  (s) => [
    for (final item in gemItems) (item: item, blocked: gemItemBlocked(s, item.id)),
  ],
);

final voucherTilesProvider = savePick<List<VoucherTile>>((s) {
  final progression = s['progression'];
  final division = progression is Map<String, dynamic>
      ? progression['currentDivision'] as String?
      : null;
  return [
    for (final floor in voucherTiersFor(division))
      (floor: floor, cost: voucherCost(floor), blocked: voucherBlocked(s, floor)),
  ];
});

final lookTilesProvider = savePick<List<LookPackTile>>((s) {
  final out = <LookPackTile>[];
  for (final pack in lookPacks) {
    final tile = lookTileState(s, pack.id);
    if (tile != null) out.add((packId: pack.id, tile: tile));
  }
  return out;
});
