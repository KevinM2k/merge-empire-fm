# The Shop screen — design

**Status:** approved, ready for a plan.
**Builds on:** `2026-08-18-shell-design.md` (the shell, theme, HUD and popup
shapes it plugs into) and `2026-08-18-i18n-layer-design.md` (every string goes
through `t()`).

## Purpose

The first real tab body. The shell put a frame around the game and the HUD reads
its numbers, but no screen yet lets a player DO anything — this one does, and it
is also the last UI piece M4's billing work needs before a SKU can be bought.

Two of its seven sections spend coins and gems, whose engines are all ported.
Those go live. Four spend real money or watch an advert, and both of those
bridges are M4, so they render fully and their buy controls ship disabled with a
visible reason — the pattern `settings_screen.dart` set. The seventh, Manager
Looks, turns out to buy nothing here at all: see below.

## What is already there

Every engine this screen drives is ported and tested. Nothing here is new logic;
it is the first caller for a lot of it.

| Section | Spends | Engine | State |
|---|---|---|---|
| 1 Offers | real money | `iap_engine` | grant step done, **billing bridge is M4** |
| 2 Free | rewarded ad | `ad_gate_engine`, `energy_engine` | gating done, **AdMob is M4** |
| 3 Gems | real money | `iap_engine` | as above |
| 4 Coins | real money | `iap_engine` | as above |
| 5 Boosts & Consumables | coins, gems | `coin_sink_engine`, `gem_engine` | **live** |
| 6 Scout Vouchers | gems | `scout_voucher_engine` | **live** |
| 7 Manager Looks | real money (the Vault only) | `look_pack_engine`, `iap_engine` | **display + M4** |

The last row is not what it looks like from the section's name, and it was worth
checking rather than assuming. **Nothing in Manager Looks is bought with gems.**
The section is the Style Vault — an `IapProduct` carrying `styleVault: true`, so
real money and therefore M4 — sitting over a grid of pack tiles that are pure
PROGRESS: `lookTileState` reports owned-of-total per pack, and an individual pack
is unlocked one rewarded video at a time in the customiser, not here. The tiles
are shown under the Vault so its value is visible rather than asserted.

The catalogue already carries 84 `shop.*` keys, including every section heading,
every toast and `shop.voucher.one_at_a_time`. No new copy is expected; anything
missing is added to all ten catalogues and regenerated, as in the i18n module.

`ShellController` already carries `ShopSection` and `pendingShopSection`, put
there by the shell module for exactly this screen.

## Architecture

Seven files under `lib/ui/screens/shop/`, split by what changes together rather
than one per section:

| File | Responsibility |
|---|---|
| `shop_screen.dart` | the scroll, the section order, the deep-link handoff |
| `shop_section.dart` | the shared section frame — icon disc, title, rule to the edge |
| `shop_tiles.dart` | the five shapes, and the price/afford/disabled states |
| `shop_paid.dart` | Offers, Gems, Coins — real money, disabled |
| `shop_free.dart` | the rewarded-video shelf — disabled |
| `shop_spend.dart` | Boosts & Consumables, Vouchers, Looks — live |
| `shop_providers.dart` | the derived providers each section reads |

## What the JS encodes, and must survive

Four things in `ShopScreen.js` are decisions with reasoning attached rather than
layout, and each is recorded in a comment there because it was arrived at by
fixing something.

- **The section order is not arbitrary.** Offers and passes first — the
  highest-converting slot; then the free shelf, which is the reason a non-payer
  opens the shop at all; then hard currency before soft; then the things those
  currencies buy; then cosmetics. The comment records what it replaced: coins
  split across two sections with a cash section wedged between them, real money
  in four separate places, gems in two, and the ad rows hidden inside
  Consumables with no identity of their own.
- **Each section has its own SHAPE** — hero cards, free strip, gem tiles, coin
  tiles, rows, cosmetic tiles — so the eye can tell where it is without reading
  the headings. "A shop that is one long list of identical rows reads as a
  settings screen."
- **The Gems section stays visible once the Style Vault is owned.** A section
  that deletes itself takes the player's balance off screen with it.
- **The voucher one-at-a-time rule is stated once, at section level.** It is the
  answer to "why can't I buy this one" for all eight rungs at once; saying it
  eight times on eight tiles is worse, not clearer.

Section headings use line-art icons rather than emoji, because a heading is
interface. The port uses `Icons` for now — the JS's hand-drawn `ICON` set is its
own module — but keeps one glyph per section, chosen in one place.

## The live half

Boosts & Consumables and Scout Vouchers call the ported engines for real,
through `game.update(...)`:

- **Coin sinks** — `purchaseCoinSink(state, id)`, whose `SinkPurchase` record
  reports what happened; `peekCost` prices a tile and `isUnlocked` gates it.
- **Gem items** — `spendGems` plus the item's own grant.
- **Vouchers** — `voucherTiersFor` builds the ladder, `voucherCost` prices a
  rung, and `voucherBlocked` is what greys one out and says why.
`gemItemBlocked` already exists specifically for this screen — its own doc says
it was split out "so the Shop can grey a row with a reason instead of failing on
tap", and it returns one of six reasons. `voucherBlocked` does the same job with
a `VoucherBlock` enum. Neither needs a wrapper here.

`lookTileState` is read-only: it prices and counts a pack for display.

**This is the first screen on which a player can change the save**, so the tests
assert the balance moved and the item landed, not that a button existed.

## The disabled half

Offers, Gems packs, Coin packs, the Style Vault, the free shelf and Restore
Purchases all render their real tiles at their real prices, read off
`IapProduct.price`, with the buy control disabled and a visible reason beneath
it.

`purchaseProduct` in `iap_engine` is the GRANT step — what runs once a store has
confirmed a payment — so nothing on this screen calls it until M4's bridge
exists. Wiring it to a button now would hand out paid goods for free.

## The deep link

The HUD's coin `+` and gem chip both set `pendingShopSection`. The screen scrolls
to that section on open and calls `consumePendingShopSection()` immediately, so a
later rebuild does not scroll again.

This pairs with the no-slide transition the shell already implements: the JS is
explicit that a screen sliding in from the side while its contents jump to an
anchor is two movements fighting, and reads as a glitch.

## Testing

- Section order, and all seven present.
- Each live purchase deducting the right currency and granting the right thing,
  through the real engine rather than a stub.
- The Looks pack tiles showing owned-of-total and offering no purchase, and the
  Vault above them disabled like every other real-money control.
- An unaffordable tile disabled, with the reason visible.
- A blocked voucher greyed with its own reason, and the section-level note
  present exactly once.
- The Gems section still rendered when the Style Vault is owned.
- The deep link scrolling to Coins and to Gems, and consuming the pending flag
  once.
- Every paid tile showing a real price with a disabled control, and no path
  reaching `purchaseProduct`.
- Every string resolved through `t()` — `test/i18n/call_sites_test.dart` fails
  the build otherwise.

## Scope

In: all seven sections, the shared frame and tile shapes, the two live buy flows,
the disabled paid flows, the Looks progress tiles, and the deep-link handoff.

Out: the billing bridge, AdMob, and Restore's actual behaviour — all M4. Out too:
the JS's hand-drawn icon set, the other four tab bodies, and any toast system
beyond what the popup shapes already provide.
