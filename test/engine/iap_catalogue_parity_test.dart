/// The IAP catalogue, against the shipped app's.
///
/// **These SKUs are primary keys in Play Console and App Store Connect.** A
/// port that renames one, retypes one or reprices one does not fail a build —
/// it fails a PURCHASE, on a device, for a paying customer. And the failure is
/// quiet in the worst way: `priceFor` prefers whatever the store reports, so
/// the app would show the store's price against a SKU it cannot fulfil.
///
/// The type matters as much as the id. A consumable can be bought again; a
/// non-consumable is owned once and is what a restore brings back on a fresh
/// install. Registering one as the other in a console is not something the app
/// can correct for.
///
/// Dumped by `tool/dump_iap_reference.mjs` from `src/engine/iapEngine.js`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/iap_engine.dart';

void main() {
  final rows =
      (jsonDecode(
                File(
                  'test/fixtures/iap_catalogue_reference.json',
                ).readAsStringSync(),
              )
              as List)
          .cast<Map<String, dynamic>>();

  test('EVERY PRODUCT THE SHIPPED APP SELLS IS HERE, and nothing else', () {
    expect(
      getShopProducts().map((p) => p.id).toSet(),
      rows.map((r) => r['id']).toSet(),
    );
  });

  test('AND EVERY SKU IS BYTE-EXACT', () {
    // The store holds the product under this string. It is not ours to tidy.
    for (final row in rows) {
      final product = getShopProducts().firstWhere((p) => p.id == row['id']);
      expect(product.sku, row['sku'], reason: '${row['id']}');
      expect(product.sku, startsWith('com.mergeempirefc.'));
    }
  });

  test('the TYPE matches — a restore only brings back non-consumables', () {
    for (final row in rows) {
      final product = getShopProducts().firstWhere((p) => p.id == row['id']);
      expect(product.type, row['type'], reason: '${row['id']}');
    }
  });

  test('and the fallback price and what it buys match', () {
    // The store wins on device; this is what the tile shows until it answers,
    // and a figure that disagrees with the listing is a figure that misleads.
    for (final row in rows) {
      final product = getShopProducts().firstWhere((p) => p.id == row['id']);
      expect(product.price, row['price'], reason: '${row['id']} price');
      expect(
        product.priceValue,
        row['priceValue'],
        reason: '${row['id']} priceValue',
      );
      expect(product.category, row['category'], reason: '${row['id']} category');
      expect(product.coins, row['coins'], reason: '${row['id']} coins');
      expect(product.gems, row['gems'], reason: '${row['id']} gems');
    }
  });

  test('ELEVEN OF THEM, which is the number the consoles were set up from', () {
    expect(rows, hasLength(11));
  });
}
