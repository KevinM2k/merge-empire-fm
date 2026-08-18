/// The shelves, derived from the save.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/engine/gem_engine.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_providers.dart';

import 'shop_helpers.dart';

void main() {
  test('the product list hides event-gated bundles', () {
    final container = shopContainer((_) {});
    final products = container.read(shopProductsProvider);
    expect(products, isNotEmpty);
    expect(products.every((p) => p.eventGated == null), isTrue);
  });

  test('gem tiles carry the engine s own blocked reason', () {
    final container = shopContainer((_) {});
    final tiles = container.read(gemItemTilesProvider);
    expect(tiles.length, gemItems.length);
    expect(tiles.where((t) => t.blocked == 'insufficient_gems'), isNotEmpty);
  });

  test('gems unblock the live items and never the dormant ones', () {
    // `live` is a ship gate: an item whose effect is not wired yet must not be
    // sellable, however many gems the player has.
    final container = shopContainer((s) {
      (s['resources'] as Map<String, dynamic>)['gems'] = 5000;
    });
    final tiles = container.read(gemItemTilesProvider);
    expect(tiles.where((t) => t.blocked == null), isNotEmpty);
    for (final tile in tiles.where((t) => !t.item.live)) {
      expect(tile.blocked, 'not_live', reason: tile.item.id);
    }
  });

  test('voucher tiles are the ladder for this division', () {
    final container = shopContainer((_) {});
    final tiles = container.read(voucherTilesProvider);
    expect(tiles, isNotEmpty);
    expect(tiles.every((t) => t.blocked != null), isTrue, reason: 'no gems');
    expect(tiles.every((t) => t.cost != null), isTrue, reason: 'all priced');
  });

  test('look tiles report owned of total and buy nothing', () {
    final container = shopContainer((_) {});
    final tiles = container.read(lookTilesProvider);
    expect(tiles.length, lookPacks.length);
    expect(tiles.every((t) => t.tile.total > 0), isTrue);
  });
}
