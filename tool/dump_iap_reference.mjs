/**
 * The IAP catalogue, as the SHIPPED app defines it.
 *
 *   node tool/dump_iap_reference.mjs > test/fixtures/iap_catalogue_reference.json
 *
 * **Why this one matters more than most.** These SKUs are the primary keys of
 * products already created in Play Console and App Store Connect. A port that
 * renames one, retypes one, or reprices one does not fail a build — it fails a
 * PURCHASE, on a device, for a paying customer, and `getProductPrice(sku)`
 * prefers whatever the store reports, so the app would happily show the store's
 * price against a SKU it cannot fulfil.
 */
import { PRODUCTS } from '../../merge-empire-fc/src/engine/iapEngine.js';

const out = PRODUCTS.map((p) => ({
  id: p.id,
  sku: p.sku,
  type: p.type,
  price: p.price,
  priceValue: p.priceValue,
  category: p.category,
  coins: p.coins ?? null,
  gems: p.gems ?? null,
}));
process.stdout.write(`${JSON.stringify(out, null, 2)}\n`);
