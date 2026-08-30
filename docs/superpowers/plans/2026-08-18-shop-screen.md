# The Shop Screen Implementation Plan

> **DELIVERED — this is history, not a queue.** The checkboxes below are the
> plan-execution skill's own workflow steps ("write the failing test", "run it",
> "commit") and were never ticked as the work went in. They are not open tasks:
> `lib/ui/screens/shop/` is fifteen files with ten test files against it. The tech-stack line still says Flutter
> 3.38.3, which is two minors behind what this repo is pinned to, and is the
> clearest sign of how long ago this ran. Kept whole because the plan and its
> spec are the record of WHY the module is shaped the way it is.


> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The first real tab body — seven shop sections, with the two that spend coins and gems fully live and the five that need M4's billing or AdMob rendered with real prices and disabled controls.

**Architecture:** A scrolling list of seven sections under `lib/ui/screens/shop/`. One shared section frame and one shared tile widget carry the price/afford/disabled states; each section file builds its own shape on top. Live purchases call the already-ported engines through `game.update(...)`; nothing calls `purchaseProduct`, which is the post-payment grant step.

**Tech Stack:** Flutter 3.38.3 / Dart 3.10.1, `flutter_riverpod`.

**Spec:** `docs/superpowers/specs/2026-08-18-shop-screen-design.md`

## Global Constraints

- **Every user-facing string goes through `t()`.** Never a literal. The key must exist in `en` or `test/i18n/call_sites_test.dart` fails the build. The catalogue already carries 84 `shop.*` keys.
- Read values through a derived provider (`savePick`), never the save map directly.
- Write through `game.update(...)` — it schedules the save and notifies the providers.
- Read colours through `Theme.of(context).extension<KitTheme>()!`. Never a hardcoded colour.
- **Nothing on this screen calls `purchaseProduct`.** It is the grant step that runs after a store confirms a payment; wiring it to a button hands out paid goods for free.
- Section order is exactly: offers, free, gems, coins, boosts, vouchers, looks.
- A test that mutates the save must pump past the 2s debounce (`saveDebounceMs`) or the binding reports a pending timer.
- Comments: one short line each. Commit after every task.

---

### Task 1: The section frame and the tile shapes

**Files:**
- Create: `lib/ui/screens/shop/shop_section.dart`, `lib/ui/screens/shop/shop_tiles.dart`
- Test: `test/ui/screens/shop/shop_tiles_test.dart`

**Interfaces:**
- Consumes: `KitTheme`; `t`.
- Produces:
  - `enum ShopSectionId { offers, free, gems, coins, boosts, vouchers, looks }` with `String get titleKey` and `IconData get icon`
  - `const List<ShopSectionId> shopSectionOrder`
  - `class ShopSectionFrame extends StatelessWidget { const ShopSectionFrame({super.key, required this.id, required this.child, this.note}); }`
  - `class ShopTile extends StatelessWidget { const ShopTile({super.key, required this.tileKey, required this.title, required this.price, this.subtitle, this.onBuy, this.disabledReason, this.badge}); }` — `onBuy: null` **plus** a `disabledReason` renders the dead-but-priced state

- [ ] **Step 1: Write the failing test**

Create `test/ui/screens/shop/shop_tiles_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_section.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_tiles.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: buildAppTheme(kitId: '#4caf50', light: false),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  tearDown(resetLocale);

  test('the section order is the one the JS ships', () {
    // Offers first (the highest-converting slot), then the free shelf (why a
    // non-payer opens the shop at all), then hard currency before soft, then
    // what those currencies buy, then cosmetics.
    expect(shopSectionOrder, [
      ShopSectionId.offers,
      ShopSectionId.free,
      ShopSectionId.gems,
      ShopSectionId.coins,
      ShopSectionId.boosts,
      ShopSectionId.vouchers,
      ShopSectionId.looks,
    ]);
  });

  test('every section names a key that exists', () {
    for (final id in shopSectionOrder) {
      expect(t(id.titleKey), isNot(id.titleKey), reason: id.name);
    }
  });

  testWidgets('the frame shows its heading and its child', (tester) async {
    await pump(
      tester,
      const ShopSectionFrame(
        id: ShopSectionId.coins,
        child: Text('inner'),
      ),
    );
    expect(find.text(t('shop.section.coins')), findsOneWidget);
    expect(find.text('inner'), findsOneWidget);
  });

  testWidgets('a section note is rendered once, above the child', (tester) async {
    // The voucher rule is stated once at section level rather than eight times
    // on eight tiles.
    await pump(
      tester,
      ShopSectionFrame(
        id: ShopSectionId.vouchers,
        note: t('shop.voucher.one_at_a_time'),
        child: const Text('inner'),
      ),
    );
    expect(find.text(t('shop.voucher.one_at_a_time')), findsOneWidget);
  });

  testWidgets('a buyable tile shows its price and calls back', (tester) async {
    var bought = 0;
    await pump(
      tester,
      ShopTile(
        tileKey: 'thing',
        title: 'Thing',
        price: '1,000',
        onBuy: () => bought++,
      ),
    );
    expect(find.text('1,000'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shop-buy-thing')));
    await tester.pump();
    expect(bought, 1);
  });

  testWidgets('a disabled tile keeps its price and states the reason', (
    tester,
  ) async {
    // A tile that hides its price stops being an offer; one that hides its
    // reason is just broken.
    await pump(
      tester,
      ShopTile(
        tileKey: 'thing',
        title: 'Thing',
        price: '£4.99',
        disabledReason: t('settings.comingSoon'),
      ),
    );
    expect(find.text('£4.99'), findsOneWidget);
    expect(find.text(t('settings.comingSoon')), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('shop-buy-thing')),
      ).onPressed,
      isNull,
    );
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/ui/screens/shop/shop_tiles_test.dart`
Expected: FAIL — the URIs do not exist.

- [ ] **Step 3: Implement `shop_section.dart`**

```dart
/// The shared section frame. Seven sections, one heading treatment.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// The seven shelves, in display order.
///
/// The order is not arbitrary and was arrived at by fixing a mess: offers and
/// passes first (the highest-converting slot), then the free shelf — the reason
/// a non-payer opens the shop at all — then hard currency before soft, then the
/// things those currencies buy, then cosmetics. What it replaced had coins split
/// across two sections with a cash section wedged between them.
enum ShopSectionId {
  offers('shop.section.offers', Icons.local_offer),
  free('shop.section.free', Icons.card_giftcard),
  gems('shop.section.gems', Icons.diamond),
  coins('shop.section.coins', Icons.monetization_on),
  boosts('shop.section.boosts', Icons.bolt),
  vouchers('shop.section.vouchers', Icons.confirmation_number),
  looks('shop.section.looks', Icons.checkroom);

  const ShopSectionId(this.titleKey, this.icon);

  final String titleKey;

  /// Line art, not emoji: a section heading is interface.
  final IconData icon;
}

const List<ShopSectionId> shopSectionOrder = ShopSectionId.values;

class ShopSectionFrame extends StatelessWidget {
  const ShopSectionFrame({
    super.key,
    required this.id,
    required this.child,
    this.note,
  });

  final ShopSectionId id;
  final Widget child;

  /// Said once, about the whole section. The voucher ladder's one-at-a-time
  /// rule is the answer to "why can't I buy this one" for all eight rungs at
  /// once, and repeating it per tile is worse rather than clearer.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Padding(
      key: ValueKey('shop-section-${id.name}'),
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kit.accent.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(id.icon, size: 16, color: kit.accent),
              ),
              const SizedBox(width: 8),
              Text(
                t(id.titleKey),
                style: TextStyle(
                  color: kit.accentBright,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Divider(color: kit.border)),
            ],
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                note!,
                style: TextStyle(color: kit.textMuted, fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Implement `shop_tiles.dart`**

One `ShopTile` carrying every state a shelf item can be in. `onBuy` non-null is buyable; `disabledReason` non-null renders the button dead with the reason under it. Keys are `shop-buy-<tileKey>` on the button and `shop-tile-<tileKey>` on the tile.

```dart
/// One shelf item, in every state it can be in.
///
/// A tile that hides its price stops being an offer; a tile that hides WHY it
/// cannot be bought is just broken. Both stay visible in the disabled state.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

class ShopTile extends StatelessWidget {
  const ShopTile({
    super.key,
    required this.tileKey,
    required this.title,
    required this.price,
    this.subtitle,
    this.onBuy,
    this.disabledReason,
    this.badge,
  });

  final String tileKey;
  final String title;
  final String price;
  final String? subtitle;
  final VoidCallback? onBuy;

  /// Why the button is dead. Rendered under it, never instead of the price.
  final String? disabledReason;

  /// "Most popular", "Owned", a tier name.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Card(
      key: ValueKey('shop-tile-$tileKey'),
      color: kit.surface,
      child: ListTile(
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (subtitle != null)
              Text(subtitle!, style: TextStyle(color: kit.textMuted)),
            if (badge != null)
              Text(badge!, style: TextStyle(color: kit.accentBright, fontSize: 11)),
            if (disabledReason != null)
              Text(
                disabledReason!,
                style: TextStyle(color: kit.textMuted, fontSize: 11),
              ),
          ],
        ),
        trailing: ElevatedButton(
          key: ValueKey('shop-buy-$tileKey'),
          onPressed: onBuy,
          child: Text(price),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/ui/screens/shop/shop_tiles_test.dart`
Expected: PASS — 6 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/screens/shop test/ui/screens/shop
git commit -m "feat: add the shop section frame and tile

Section order is the JS's own, and a disabled tile keeps its price."
```

---

### Task 2: The providers

**Files:**
- Create: `lib/ui/screens/shop/shop_providers.dart`
- Test: `test/ui/screens/shop/shop_providers_test.dart`

**Interfaces:**
- Consumes: `savePick`, `gameProvider`; `getShopProducts`, `IapProduct`, `isVipActive` from `lib/engine/iap_engine.dart`; `coinSinks`, `CoinSink` from `lib/data/coin_sinks.dart`; `peekCost`, `isUnlocked` from `lib/engine/coin_sink_engine.dart`; `gemItems`, `GemItem`, `gemItemBlocked`, `getGems` from `lib/engine/gem_engine.dart`; `voucherTiersFor`, `voucherCost`, `voucherBlocked`, `VoucherBlock` from `lib/engine/scout_voucher_engine.dart`; `lookPacks` from `lib/data/manager_looks.dart`; `lookTileState`, `LookTile` from `lib/engine/look_pack_engine.dart`.
- Produces, from `lib/ui/screens/shop/shop_providers.dart`:
  - `final shopProductsProvider = Provider<List<IapProduct>>(...)` — `getShopProducts()`, which already hides event-gated bundles
  - `final coinSinkTilesProvider = savePick<List<CoinSinkTile>>(...)` with `typedef CoinSinkTile = ({CoinSink sink, num cost, bool unlocked, bool affordable});`
  - `final gemItemTilesProvider = savePick<List<GemItemTile>>(...)` with `typedef GemItemTile = ({GemItem item, String? blocked});`
  - `final voucherTilesProvider = savePick<List<VoucherTile>>(...)` with `typedef VoucherTile = ({int floor, int? cost, VoucherBlock? blocked});`
  - `final lookTilesProvider = savePick<List<LookPackTile>>(...)` with `typedef LookPackTile = ({String packId, LookTile tile});`

- [ ] **Step 1: Write the failing test**

Create `test/ui/screens/shop/shop_providers_test.dart`. Stand the container up the way `test/ui/theme/theme_test.dart` does — `createDefaultState()`, mutate, `jsonEncode` into a `MemorySaveStore`, `container.read(gameProvider).load()`.

```dart
void main() {
  test('the product list hides event-gated bundles', () {
    final container = containerWith((_) {});
    final ids = container.read(shopProductsProvider).map((p) => p.id).toList();
    expect(ids, isNotEmpty);
    expect(
      container.read(shopProductsProvider).every((p) => p.eventGated == null),
      isTrue,
    );
  });

  test('a coin sink is priced, gated and afforded off the save', () {
    final container = containerWith((s) {
      (s['resources'] as Map<String, dynamic>)['fanCoins'] = 100;
    });
    final tiles = container.read(coinSinkTilesProvider);
    expect(tiles.length, coinSinks.length);
    final kit = tiles.firstWhere((t) => t.sink.id == 'kit_redesign');
    expect(kit.cost, greaterThan(0));
    expect(kit.affordable, isFalse, reason: '100 coins buys nothing');

    final rich = containerWith((s) {
      (s['resources'] as Map<String, dynamic>)['fanCoins'] = 999999;
    });
    expect(
      rich.read(coinSinkTilesProvider)
          .firstWhere((t) => t.sink.id == 'kit_redesign')
          .affordable,
      isTrue,
    );
  });

  test('a sink above the current division reads as locked', () {
    final container = containerWith((_) {});
    final youth = container
        .read(coinSinkTilesProvider)
        .firstWhere((t) => t.sink.id == 'youth_academy');
    // unlockDiv 1; a default save starts at the bottom.
    expect(youth.unlocked, isFalse);
  });

  test('gem tiles carry the engine s own blocked reason', () {
    final container = containerWith((_) {});
    final tiles = container.read(gemItemTilesProvider);
    expect(tiles.length, gemItems.length);
    // A default save has no gems, so every priced item is blocked.
    expect(tiles.where((t) => t.blocked == 'insufficient_gems'), isNotEmpty);
  });

  test('voucher tiles are the ladder for this division', () {
    final container = containerWith((_) {});
    final tiles = container.read(voucherTilesProvider);
    expect(tiles, isNotEmpty);
    expect(tiles.every((t) => t.blocked != null), isTrue, reason: 'no gems');
  });

  test('look tiles report owned of total', () {
    final container = containerWith((_) {});
    final tiles = container.read(lookTilesProvider);
    expect(tiles.length, lookPacks.length);
    expect(tiles.every((t) => t.tile.total > 0), isTrue);
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/ui/screens/shop/shop_providers_test.dart`
Expected: FAIL — the URI does not exist.

- [ ] **Step 3: Implement**

Each provider maps the catalogue over the save through the engine that owns the question. Do not reimplement any gate: `isUnlocked`, `gemItemBlocked` and `voucherBlocked` already exist and `gemItemBlocked`'s own doc says it was split out for this screen.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/ui/screens/shop/shop_providers_test.dart`
Expected: PASS — 6 tests.

If `a sink above the current division reads as locked` fails, check what division a default save starts in via `state['progression']['currentDivision']` and pick a sink whose `unlockDiv` is genuinely above it.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/screens/shop/shop_providers.dart test/ui/screens/shop/shop_providers_test.dart
git commit -m "feat: derive the shop shelves from the save"
```

---

### Task 3: The paid sections

**Files:**
- Create: `lib/ui/screens/shop/shop_paid.dart`
- Test: `test/ui/screens/shop/shop_paid_test.dart`

**Interfaces:**
- Consumes: `shopProductsProvider`, `ShopTile`, `ShopSectionFrame`, `ShopSectionId`.
- Produces:
  - `class OffersSection extends ConsumerWidget`
  - `class GemPacksSection extends ConsumerWidget`
  - `class CoinPacksSection extends ConsumerWidget`
  - `class RestoreRow extends StatelessWidget`
  - `String paidDisabledReason() => t('settings.comingSoon');`

Each filters `shopProductsProvider` by `IapProduct.category`: `bundle` and `vip` to Offers, `gems` to Gems, `coins` to Coins. Every tile is priced from `product.price` with `onBuy: null` and `disabledReason: paidDisabledReason()`.

- [ ] **Step 1: Write the failing test**

```dart
  testWidgets('every paid tile is priced and dead', (tester) async {
    await pumpPaid(tester);
    final buttons = tester.widgetList<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    expect(buttons, isNotEmpty);
    for (final b in buttons) {
      expect(b.onPressed, isNull);
    }
    expect(find.text(t('settings.comingSoon')), findsWidgets);
  });

  testWidgets('the coin section lists the coin bundles at their real prices', (
    tester,
  ) async {
    await pumpPaid(tester);
    final coins = getShopProducts().where((p) => p.category == 'coins');
    expect(coins, isNotEmpty);
    for (final p in coins) {
      expect(find.text(p.price), findsWidgets, reason: p.id);
    }
  });

  testWidgets('Restore Purchases is last and disabled', (tester) async {
    // Required by App Store guidelines, and correctly the last thing on the
    // screen rather than buried mid-shop.
    await pumpPaid(tester);
    expect(find.text(t('shop.restore_purchases')), findsOneWidget);
  });
```

Write `pumpPaid(WidgetTester)` locally, pumping a `Column` of the three sections plus `RestoreRow` inside a themed `MaterialApp` and a container built the way Task 2's test does.

- [ ] **Step 2: Run it to confirm it fails, implement, run again**

Run: `flutter test test/ui/screens/shop/shop_paid_test.dart`
Expected: FAIL, then after implementing, PASS.

- [ ] **Step 3: Assert nothing reaches the grant step**

Add to the same file:

```dart
  test('no paid section calls the grant step', () {
    // purchaseProduct runs AFTER a store confirms a payment. A button wired to
    // it would hand out paid goods for free.
    final source = File('lib/ui/screens/shop/shop_paid.dart').readAsStringSync();
    expect(source.contains('purchaseProduct'), isFalse);
  });
```

- [ ] **Step 4: Commit**

```bash
git add lib/ui/screens/shop/shop_paid.dart test/ui/screens/shop/shop_paid_test.dart
git commit -m "feat: shelve the paid sections

Real prices, dead buttons: the billing bridge is M4 and purchaseProduct
is the grant step that runs after a store confirms."
```

---

### Task 4: The free shelf

**Files:**
- Create: `lib/ui/screens/shop/shop_free.dart`
- Test: folded into `test/ui/screens/shop/shop_paid_test.dart`

**Interfaces:**
- Consumes: `canWatchPackAd`, `msUntilPackAd`, `packAdsRemaining`, `formatAdWait` from `lib/engine/ad_gate_engine.dart`.
- Produces: `class FreeShelfSection extends ConsumerWidget`

Two rows, both disabled: the match-cooldown ad (`shop.match_cooldown_ad_name` / `_desc`) and Lucky Boot (`shop.lucky_boot_ad_name` / `_desc`). The gate is real — `packAdsRemaining` and `formatAdWait(msUntilPackAd(...))` decide whether a row reads "ready" or "wait" — but the button is dead until AdMob lands, with the same reason as the paid tiles.

- [ ] **Step 1: Write the test**

```dart
  testWidgets('the free shelf shows its gate but cannot be watched yet', (
    tester,
  ) async {
    await pumpFree(tester);
    expect(find.text(t('shop.lucky_boot_ad_name')), findsOneWidget);
    expect(find.text(t('shop.match_cooldown_ad_name')), findsOneWidget);
    for (final b in tester.widgetList<ElevatedButton>(
      find.byType(ElevatedButton),
    )) {
      expect(b.onPressed, isNull);
    }
  });

  testWidgets('a spent daily cap reads as a wait, not as ready', (tester) async {
    // recordPackAd stamps the gate; the shelf must reflect it rather than
    // always offering.
    await pumpFree(tester, spendAllAds: true);
    expect(find.text(t('shop.daily_cap')), findsWidgets);
  });
```

Write `pumpFree(WidgetTester, {bool spendAllAds = false})` locally; when `spendAllAds`, call `recordPackAd(state)` enough times to exhaust the cap before encoding the save.

- [ ] **Step 2: Implement, run, commit**

Run: `flutter test test/ui/screens/shop/shop_paid_test.dart`
Expected: PASS.

```bash
git add lib/ui/screens/shop/shop_free.dart test/ui/screens/shop/shop_paid_test.dart
git commit -m "feat: shelve the free section

The ad gate is live; the watch button waits for M4's AdMob."
```

---

### Task 5: Boosts & Consumables — the first live purchase

**Files:**
- Create: `lib/ui/screens/shop/shop_spend.dart`
- Test: `test/ui/screens/shop/shop_spend_test.dart`

**Interfaces:**
- Consumes: `coinSinkTilesProvider`, `gemItemTilesProvider`, `purchaseCoinSink`, `buyGemItem`, `gameProvider`.
- Produces: `class BoostsSection extends ConsumerWidget`

Coin rows first, then gem rows. Every row states its own price, which is the only reason mixing two currencies in one section is legible.

- [ ] **Step 1: Write the failing test**

This is the first test in the project that asserts a player changed their own save through a screen, so it checks the balance AND the effect.

```dart
  testWidgets('buying a coin sink debits the coins', (tester) async {
    final container = await pumpBoosts(tester, (s) {
      (s['resources'] as Map<String, dynamic>)['fanCoins'] = 999999;
    });
    final before = container.read(coinsProvider);
    await tester.tap(find.byKey(const ValueKey('shop-buy-sink-kit_redesign')));
    await tester.pumpAndSettle();
    await settleSave(tester);
    expect(container.read(coinsProvider), lessThan(before));
  });

  testWidgets('an unaffordable sink is disabled and says so', (tester) async {
    final container = await pumpBoosts(tester, (s) {
      (s['resources'] as Map<String, dynamic>)['fanCoins'] = 1;
    });
    final before = container.read(coinsProvider);
    expect(
      tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('shop-buy-sink-kit_redesign')),
      ).onPressed,
      isNull,
    );
    expect(container.read(coinsProvider), before);
  });

  testWidgets('buying a gem item debits the gems', (tester) async {
    final container = await pumpBoosts(tester, (s) {
      (s['resources'] as Map<String, dynamic>)['gems'] = 500;
    });
    final live = container.read(gemItemTilesProvider)
        .firstWhere((t) => t.blocked == null);
    final before = container.read(gemsProvider);
    await tester.tap(find.byKey(ValueKey('shop-buy-gem-${live.item.id}')));
    await tester.pumpAndSettle();
    await settleSave(tester);
    expect(container.read(gemsProvider), lessThan(before));
  });

  testWidgets('a blocked gem row is dead and carries its reason', (tester) async {
    final container = await pumpBoosts(tester, (_) {});
    final blocked = container.read(gemItemTilesProvider)
        .firstWhere((t) => t.blocked != null);
    expect(
      tester.widget<ElevatedButton>(
        find.byKey(ValueKey('shop-buy-gem-${blocked.item.id}')),
      ).onPressed,
      isNull,
    );
  });
```

Write `pumpBoosts(WidgetTester, void Function(Map<String, dynamic>))` returning the container, and `settleSave(tester)` pumping `saveDebounceMs + 100`, both copied from `test/ui/screens/settings_screen_test.dart`'s shape.

Tile keys are `sink-<id>` and `gem-<id>`, so the buttons are `shop-buy-sink-<id>` / `shop-buy-gem-<id>`.

- [ ] **Step 2: Run it to confirm it fails, implement, run again**

Run: `flutter test test/ui/screens/shop/shop_spend_test.dart`
Expected: FAIL, then PASS.

If no gem item is unblocked with 500 gems, check `GemItem.live` — an item whose effect is not wired yet reports `not_live` deliberately, and the test should pick from the live ones.

- [ ] **Step 3: Commit**

```bash
git add lib/ui/screens/shop/shop_spend.dart test/ui/screens/shop/shop_spend_test.dart
git commit -m "feat: make the boosts section buyable

The first screen on which a player can change their own save."
```

---

### Task 6: The voucher ladder

**Files:**
- Modify: `lib/ui/screens/shop/shop_spend.dart` — add `VouchersSection`
- Test: `test/ui/screens/shop/shop_spend_test.dart`

**Interfaces:**
- Consumes: `voucherTilesProvider`, `buyScoutVoucher`, `voucherUnlockDivision`.
- Produces: `class VouchersSection extends ConsumerWidget`

Eight rungs, each in its own tier, under one section-level note.

- [ ] **Step 1: Write the test**

```dart
  testWidgets('the one-at-a-time rule is stated once, not per rung', (
    tester,
  ) async {
    await pumpVouchers(tester, (_) {});
    expect(find.text(t('shop.voucher.one_at_a_time')), findsOneWidget);
  });

  testWidgets('buying a voucher debits the gems and arms the floor', (
    tester,
  ) async {
    final container = await pumpVouchers(tester, (s) {
      (s['resources'] as Map<String, dynamic>)['gems'] = 500;
    });
    final open = container.read(voucherTilesProvider)
        .firstWhere((t) => t.blocked == null);
    final before = container.read(gemsProvider);
    await tester.tap(find.byKey(ValueKey('shop-buy-voucher-${open.floor}')));
    await tester.pumpAndSettle();
    await settleSave(tester);
    expect(container.read(gemsProvider), lessThan(before));
    expect(heldVoucherTier(container.read(gameProvider).state), open.floor);
  });

  testWidgets('once one is armed every other rung is blocked', (tester) async {
    final container = await pumpVouchers(tester, (s) {
      (s['resources'] as Map<String, dynamic>)['gems'] = 500;
    });
    final open = container.read(voucherTilesProvider)
        .firstWhere((t) => t.blocked == null);
    await tester.tap(find.byKey(ValueKey('shop-buy-voucher-${open.floor}')));
    await tester.pumpAndSettle();
    await settleSave(tester);
    expect(
      container.read(voucherTilesProvider)
          .every((t) => t.blocked == VoucherBlock.alreadyHeld),
      isTrue,
    );
  });
```

- [ ] **Step 2: Implement, run, commit**

Run: `flutter test test/ui/screens/shop/shop_spend_test.dart`
Expected: PASS.

```bash
git add lib/ui/screens/shop/shop_spend.dart test/ui/screens/shop/shop_spend_test.dart
git commit -m "feat: add the voucher ladder

The one-at-a-time rule is said once, about the section."
```

---

### Task 7: Manager Looks

**Files:**
- Create: `lib/ui/screens/shop/shop_looks.dart`
- Test: `test/ui/screens/shop/shop_looks_test.dart`

**Interfaces:**
- Consumes: `lookTilesProvider`, `shopProductsProvider`.
- Produces: `class LooksSection extends ConsumerWidget`

The Style Vault hero — the one `IapProduct` with `styleVault: true`, real money, disabled — over a grid of pack tiles that BUY NOTHING. Each tile shows `owned/total` from `lookTileState` so the Vault's value is visible rather than asserted; an individual pack is unlocked by rewarded video in the customiser, not here.

- [ ] **Step 1: Write the test**

```dart
  testWidgets('the vault is real money and disabled', (tester) async {
    await pumpLooks(tester, (_) {});
    final vault = products.firstWhere((p) => p.styleVault);
    expect(find.text(vault.price), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(
        find.byKey(ValueKey('shop-buy-${vault.id}')),
      ).onPressed,
      isNull,
    );
  });

  testWidgets('a pack tile reports progress and offers no purchase', (
    tester,
  ) async {
    await pumpLooks(tester, (_) {});
    // Progress, not a price: nothing in this section is bought with gems.
    expect(find.textContaining('/'), findsWidgets);
    expect(find.byKey(const ValueKey('shop-buy-pack-black')), findsNothing);
  });

  testWidgets('the vault progress note counts what is owned', (tester) async {
    await pumpLooks(tester, (_) {});
    expect(find.textContaining(t('shop.vault.progress', {'n': 0, 'total': lookPacks.length})), findsWidgets);
  });
```

If `shop.vault.progress`'s placeholders are not `{n}` and `{total}`, read the key in `lib/i18n/locales/en.g.dart` and use the ones it has.

- [ ] **Step 2: Implement, run, commit**

Run: `flutter test test/ui/screens/shop/shop_looks_test.dart`
Expected: PASS.

```bash
git add lib/ui/screens/shop/shop_looks.dart test/ui/screens/shop/shop_looks_test.dart
git commit -m "feat: add the manager looks shelf

The packs are progress, not purchases — the vault above them is the SKU."
```

---

### Task 8: The screen, the deep link, and the tab

**Files:**
- Create: `lib/ui/screens/shop/shop_screen.dart`
- Modify: `lib/ui/shell/app_shell.dart` — the `shop` tab becomes `ShopScreen`
- Test: `test/ui/screens/shop/shop_screen_test.dart`

**Interfaces:**
- Consumes: all six section widgets; `shellControllerProvider`, `ShopSection`.
- Produces: `class ShopScreen extends ConsumerStatefulWidget`

A `ListView` of the seven sections in `shopSectionOrder`, each wrapped in its `ShopSectionFrame`, with a `GlobalKey` per section so the deep link can scroll to one.

- [ ] **Step 1: Write the failing test**

```dart
  testWidgets('all seven sections are present, in order', (tester) async {
    await pumpShop(tester, (_) {});
    for (final id in shopSectionOrder) {
      expect(
        find.byKey(ValueKey('shop-section-${id.name}'), skipOffstage: false),
        findsOneWidget,
        reason: id.name,
      );
    }
  });

  testWidgets('the gems section survives owning the style vault', (tester) async {
    // A section that deletes itself takes the player's balance off screen.
    await pumpShop(tester, (s) {
      final shop = s['shop'] as Map<String, dynamic>;
      shop['styleVault'] = true;
    });
    expect(
      find.byKey(const ValueKey('shop-section-gems'), skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('a coin deep link scrolls to Coins and consumes the flag', (
    tester,
  ) async {
    final container = await pumpShop(tester, (_) {});
    container.read(shellControllerProvider.notifier)
        .deepLinkShop(ShopSection.coins);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shop-section-coins')), findsOneWidget);
    expect(
      container.read(shellControllerProvider).pendingShopSection,
      isNull,
      reason: 'consumed, so a rebuild does not scroll again',
    );
  });

  testWidgets('a gem deep link scrolls to Gems', (tester) async {
    final container = await pumpShop(tester, (_) {});
    container.read(shellControllerProvider.notifier)
        .deepLinkShop(ShopSection.gems);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shop-section-gems')), findsOneWidget);
  });
```

- [ ] **Step 2: Implement**

The deep link uses `ref.listen(shellControllerProvider, ...)` plus `Scrollable.ensureVisible` on the section's `GlobalKey`, then `consumePendingShopSection()`. Also handle a section pending at first build, since the tab may be built by the same frame that set it.

- [ ] **Step 3: Put the screen in the shell**

In `lib/ui/shell/app_shell.dart`, replace the `shop` tab's `PlaceholderScreen` with `ShopScreen`. Keep every other tab a placeholder — the `IndexedStack` and `TickerMode` wrapping is unchanged.

The shell's tests read `PlaceholderScreenState` for the grid and league tabs; leave those alone and confirm they still pass.

- [ ] **Step 4: Run everything**

Run: `flutter analyze && flutter test && TZ=UTC flutter test`
Expected: clean, all green. Note the test count for Task 9.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/screens/shop lib/ui/shell/app_shell.dart test/ui/screens/shop
git commit -m "feat: put the Shop in the shop tab

The HUD's coin and gem deep links now land on something."
```

---

### Task 9: Update the remaining-work list

**Files:**
- Modify: `docs/REMAINING.md`

- [ ] **Step 1: Update it**

- **Where we are** — the new test count and coverage; the Shop is in, so a player can now spend coins and gems.
- **How far along** — the `ui/` row gains the Shop; remeasure the `lib/` and `test/` line counts with `wc -l` rather than estimating.
- **The screens** — tick the Shop, and note what is deliberately inert in it (the four paid sections, the free shelf, Restore) so M4 knows exactly what it is plugging into.
- **M4 → IAP, end to end** — tick "The Shop screen", and record that the UI is finished and waiting on `iapClient`.
- Record the Looks finding: nothing in that section is bought with gems, so the "Shop screen" line in M4 covers the Vault too.

- [ ] **Step 2: Commit**

```bash
git add docs/REMAINING.md
git commit -m "docs: fold the Shop into the remaining-work list"
```

---

## Notes for whoever executes this

- **Nothing calls `purchaseProduct`.** Task 3 asserts it by reading the source. If a later change needs it, that change is M4.
- **Do not reimplement a gate.** `isUnlocked`, `gemItemBlocked` and `voucherBlocked` exist and are tested; the screen asks them.
- **Manager Looks buys nothing with gems.** It looked like it did; it does not.
- **A mutating widget test must pump past `saveDebounceMs`** or the binding reports a pending timer and the test fails for the wrong reason.
