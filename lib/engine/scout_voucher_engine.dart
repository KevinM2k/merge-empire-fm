/// The Guaranteed Scout — a voucher promising a FLOOR tier. Ported from
/// `../merge-empire-fc/src/engine/scoutVoucherEngine.js`.
///
/// ## Why a floor and not an exact tier
///
/// The obvious shape is "a Tier 5 voucher gives you a Tier 5". It was rejected,
/// and the reasoning is worth keeping because the rejected design looks simpler:
///
/// - An exact-tier voucher ROTS. Buy a Silver Star voucher at Regional, climb
///   two divisions, and spending it hands you a card worse than the free coin
///   scout sitting next to it. An item that gets worse the longer you own it is
///   an item players learn not to buy — and it was bought with real money.
/// - A floor answers the complaint the item exists for. Nobody has ever wanted
///   "exactly a Gold"; they want "stop giving me bronze". The roll ABOVE the
///   floor still uses the division's own odds, so the voucher quietly improves
///   as the player climbs.
/// - It composes. A floor is one filter on the existing weighted pool, so
///   position bias, discovery, auto-sell and the batch loop all keep working
///   untouched. An exact-tier draw needs its own pool and its own edge cases.
///
/// ## Why this does not break "never sell raw rating"
///
/// The gem catalogue forbids selling ★, because the division bands are tuned
/// against a maxed no-trait squad with a shrinking edge per division. A
/// guaranteed card looks exactly like a violation, so the line has to be
/// explicit:
///
/// > A voucher may NEVER guarantee a tier the player's own division cannot
/// > already scout for coins.
///
/// [voucherTiersFor] is derived from the scout odds for precisely this reason —
/// the offer is a slice of what the division already hands out, so a voucher
/// compresses TIME and never raises the ceiling. A Sunday League manager cannot
/// buy their way to a Gold at any price, which is the property that keeps the
/// curve intact.
///
/// ## Tier 9 is never sold
///
/// Football Icon is scout-only, uncraftable, globally unique and a 1% draw at
/// Champions — the one genuine chase in the game. It is excluded from the
/// voucher pool outright rather than left to fall out of a Tier 8 floor, where
/// it would have been 40% of that voucher's draws. A chase item you can buy is
/// not a chase item.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/gem_engine.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

/// The dearest floor a voucher will ever guarantee. Tier 9 is the chase.
const int maxVoucherTier = 8;

/// The lowest. Tier 1 is every card in the game — that is the plain Scout
/// Voucher.
const int _minVoucherTier = 2;

/// Gems per floor tier: ONE GEM PER RUNG, flat, all the way up.
///
/// FIXED against the absolute tier, so a voucher is the same price forever.
/// Pricing it off the live odds instead would make the same item cost 12 gems at
/// Elite and 2 at Champions, which reads as a bug and rewards sitting on your
/// hands.
///
/// Linear rather than geometric, and the reason is the 20p anchor. At the entry
/// bundle a gem is about 20p, so the top rung is a guaranteed World Class card
/// for 8 gems — about £1.60, a price someone actually pays for a player. A
/// geometric ladder (this ran as 2/3/5/8/11/15/20) put the same card at £4 and
/// made the best thing in the shop read as a rip-off, which sells nothing.
///
/// It also tracks rarity BETTER, which is the part that looks wrong and is not.
/// Measured as gems per ordinary scout saved, at the division where each rung is
/// the top of its window, linear runs 0.30 to 0.14 and geometric ran 0.30 to
/// 0.50 — the geometric ladder got DEARER per unit of value as the player
/// climbed, because the odds curve has a kink Champions' fat top end does not
/// punish.
///
/// The known consequence, accepted: within a division's window the dearest rung
/// is always the best value, so the cheaper rungs are AFFORDABILITY steps rather
/// than choices. That is the correct shape for a price ladder; it is only wrong
/// if the rungs pretend to be a trade-off.
const Map<int, int> voucherGemCost = {2: 2, 3: 3, 4: 4, 5: 5, 6: 6, 7: 7, 8: 8};

/// Every tier this division's scout pool can actually produce, tier 9 aside.
List<int> _poolTiers(String? divisionId) {
  final odds =
      divisionScoutOdds[divisionId] ?? divisionScoutOdds['sunday_league']!;
  final tiers = [
    for (final (tier, weight) in odds)
      if (weight > 0 && tier <= maxVoucherTier) tier,
  ];
  tiers.sort();
  return tiers;
}

/// The chance an ORDINARY scout at this division clears [floor] — what the
/// voucher is replacing, and the only honest way to show its worth. A fraction;
/// the sheet renders it as a percentage.
///
/// Tier 9's weight counts here even though a voucher cannot draw one: this is a
/// statement about the ordinary scout the player is comparing against, not about
/// the voucher's own pool.
double voucherOdds(String? divisionId, int floor) {
  final odds =
      divisionScoutOdds[divisionId] ?? divisionScoutOdds['sunday_league']!;
  final total = odds.fold<double>(0, (n, e) => n + e.$2);
  if (total <= 0) return 0;
  final hit = odds.fold<double>(0, (n, e) => e.$1 >= floor ? n + e.$2 : n);
  return hit / total;
}

/// Every rung the ladder has, ascending — the whole Shop section, locked or not.
final List<int> voucherTiers = voucherGemCost.keys.toList()..sort();

/// The floors this save can actually BUY: every tier its division scouts, tier 1
/// and the Icon aside. Ascending.
List<int> voucherTiersFor(String? divisionId) => [
  for (final tier in _poolTiers(divisionId))
    if (tier >= _minVoucherTier) tier,
];

/// Is this floor buyable at this division?
bool voucherOffered(String? divisionId, int floor) =>
    voucherTiersFor(divisionId).contains(floor);

/// The first division that can buy this rung — what a locked tile names.
///
/// Walked rather than tabulated, so it cannot fall out of step with the odds
/// table. Falls back to the top flight for a tier no division reaches, which is
/// the honest answer to "when?" for an unreachable rung.
String voucherUnlockDivision(int floor) {
  for (final d in divisions) {
    if (voucherOffered(d.id, floor)) return d.id;
  }
  return divisions.last.id;
}

/// What this floor costs. Null for a tier that has no price — never guess one.
int? voucherCost(int floor) => voucherGemCost[floor];

/// The floor currently armed on this save, or null.
int? heldVoucherTier(Map<String, dynamic>? state) {
  final n = _num(_map(state?['shop'])?['scoutVoucherTier']);
  return n != null && n.isFinite && n > 1 ? n.floor() : null;
}

/// Is ANY scout voucher armed — a floor, or the plain one's free scout?
///
/// **HISTORICAL, and kept for the JS fixture.** Both keys it reads are drained
/// into the inventory by `migrate` and never written again, so on a live save
/// this is always false and the one-at-a-time rule it enforces cannot fire. The
/// rest of this comment is why that rule existed, which is worth keeping because
/// it explains what the inventory had to solve:
///
/// ONE voucher at a time, across the whole ladder. Two different reasons meet
/// here and both matter:
///
/// - `scoutVoucherTier` is a scalar, so a second floor would overwrite the first
///   and take the gems for nothing. That alone forces the rule within the
///   guarantees, dearer ones included — upgrading in place bins what you paid
///   for.
/// - The plain Scout Voucher sets `freeScoutReady` instead, so it is technically
///   stackable with a floor and the scout path spends the floor first. It is
///   still blocked, because the Shop presents all eight as ONE family: two tiles
///   reading ACTIVE at once is two active vouchers as far as the player is
///   concerned, whatever the flags say.
///
/// `freeScoutReady` is also what the rewarded-video free scout and the Lucky
/// Boot set, so an unspent free scout blocks a voucher sale too. Deliberate: it
/// is one tap on the Players tab to clear, and the alternative is a shop that
/// contradicts itself.
///
/// **That last paragraph is the JS's, and neither half of it is true in this
/// port** — noted rather than deleted, because it is the kind of claim a reader
/// checks a design against. There is no rewarded-video scout path here at all,
/// and the Lucky Boot writes its own `shop.luckyBootReady`
/// (`match_orchestration.dart`), not this. In the port `freeScoutReady` was set
/// only by the 🎲 gem rung, the daily calendar and a live event reward — all
/// three of which now grant into the inventory instead.
bool anyVoucherArmed(Map<String, dynamic>? state) =>
    heldVoucherTier(state) != null ||
    _map(state?['shop'])?['freeScoutReady'] == true;

/// Why a voucher cannot be bought right now.
enum VoucherBlock { notOffered, noPrice, alreadyHeld, insufficientGems }

/// Why this voucher cannot be bought right now, or null when it can.
VoucherBlock? voucherBlocked(Map<String, dynamic>? state, int floor) {
  final divisionId = _map(state?['progression'])?['currentDivision'] as String?;
  if (!voucherOffered(divisionId, floor)) return VoucherBlock.notOffered;
  final cost = voucherCost(floor);
  if (cost == null) return VoucherBlock.noPrice;
  if (anyVoucherArmed(state)) return VoucherBlock.alreadyHeld;
  if (getGems(state) < cost) return VoucherBlock.insufficientGems;
  return null;
}

/// Buy one: debits the gems and arms the floor for the next scout.
({bool ok, int? floor, int? cost, VoucherBlock? reason}) buyScoutVoucher(
  Map<String, dynamic> state,
  int floor,
) {
  final blocked = voucherBlocked(state, floor);
  if (blocked != null) {
    return (ok: false, floor: null, cost: null, reason: blocked);
  }

  final cost = voucherCost(floor)!;
  if (!spendGems(state, cost, 'scout_voucher_t$floor')) {
    return (
      ok: false,
      floor: null,
      cost: null,
      reason: VoucherBlock.insufficientGems,
    );
  }

  final shop =
      _map(state['shop']) ??
      (() {
        final fresh = <String, dynamic>{};
        state['shop'] = fresh;
        return fresh;
      })();
  shop['scoutVoucherTier'] = floor;
  return (ok: true, floor: floor, cost: cost, reason: null);
}

// ── The inventory, and why it sits BESIDE the parity surface ────────────────
//
// **Everything above this line is frozen against the JS**, and the reason is
// mechanical rather than a preference. `scout_voucher_reference.json` is dumped
// from `../merge-empire-fc` by `tool/dump_scout_voucher_reference.mjs`, that
// repo is not cloned in a cloud container, and the fixture compares whole
// objects: `parity — buying one` asserts `state['shop']` field for field after
// [buyScoutVoucher], so a version that pushed onto a list would fail on the
// extra key, and the fixture cannot be regenerated to say otherwise.
//
// So the port's own mechanic — vouchers are COLLECTABLE, held many at a time,
// of mixed tiers, and assigned to individual cards of a batch — is built here as
// a second layer rather than by rewriting the first. CLAUDE.md's rule for a
// deliberate divergence is that it belongs on the screen, and this is that rule
// applied one level down: the JS's answer stays callable and asserted, and the
// game calls these.
//
// **The one-at-a-time rule dissolves rather than being switched off.**
// [anyVoucherArmed] reads `scoutVoucherTier` and `freeScoutReady`; `migrate`
// drains both into the inventory on load and nothing in the game writes them
// again, so on a live save they are permanently empty and
// [VoucherBlock.alreadyHeld] simply never occurs. No flag, no gate, no branch —
// and the fixture's hand-made shop maps, which DO set those keys, still get the
// JS's answer.
//
// The cost, stated plainly and checked rather than assumed. [consumeScoutVoucher]
// still has a live caller — `signPlayer`'s legacy branch, for a save carrying the
// old scalar. **[buyScoutVoucher] has none**, and `tool/unreached.sh` does NOT
// report it: the sweep is a `grep -w` on the bare name, and the `[buyScoutVoucher]`
// references in the doc comments here and in `shop_spend.dart` read as callers.
// So the one function this change orphaned is invisible to the check that exists
// to find orphans, and this paragraph is the only thing standing in for it.
//
// It is kept deliberately, not overlooked: `parity — buying one` and
// `parity — buy, spend, buy again` are what hold the port to the JS's answer, and
// they cannot run without it.

/// **`1` IS THE "ANY CARD" TOKEN, NOT A TIER-1 FLOOR**, and the difference is
/// the Football Icon.
///
/// `buildScoutDrawPool` filters `def.tier >= minTier && def.tier <= 8`, so ANY
/// non-null `minTier` strips tier 9 — including a floor of 1, which otherwise
/// looks like a harmless "every card in the game". The 🎲 RANDOM rung is the one
/// voucher that can hand over an Icon (`shop.voucher.random_sub` is "Any tier —
/// Icons included", and it is the cheapest thing on the shelf precisely because
/// that is what it sells), so it has to reach the draw as `minTier: null`.
///
/// [drawFloorFor] is that translation and is the only place it is made.
const int anyCardVoucher = 1;

/// What to pass as `minTier` for a held voucher: the floor itself, or null for
/// the token. Never inline this — see [anyCardVoucher].
int? drawFloorFor(int voucher) => voucher == anyCardVoucher ? null : voucher;

/// Every voucher this save holds, descending, so the dearest reads first.
///
/// A missing key is an empty inventory rather than an error: `createDefaultState`
/// cannot declare `scoutVouchers` without breaking the JS shape parity, so a
/// fresh save genuinely has no such key until the first grant.
List<int> voucherInventory(Map<String, dynamic>? state) {
  final raw = _map(state?['shop'])?['scoutVouchers'];
  if (raw is! List) return const [];
  final out = <int>[
    for (final v in raw)
      if (v is num && v.isFinite && v >= anyCardVoucher && v <= maxVoucherTier)
        v.floor(),
  ];
  out.sort((a, b) => b.compareTo(a));
  return out;
}

/// Is there anything to spend? What decides whether the assignment sheet opens
/// at all — with nothing held, scouting is exactly what it was before.
bool hasVouchers(Map<String, dynamic>? state) =>
    voucherInventory(state).isNotEmpty;

/// How many of this exact floor are held. The Shop's owned-count badge.
int voucherCount(Map<String, dynamic>? state, int floor) =>
    voucherInventory(state).where((v) => v == floor).length;

/// Add one to the inventory. The single write path — the Shop ladder, the 🎲 gem
/// item, the daily reward and a live event all come through here.
///
/// Creates the list lazily, the same way [buyScoutVoucher] creates a missing
/// `shop` branch, because a fresh save has no key to write into.
void grantVoucher(Map<String, dynamic> state, int floor) {
  if (floor < anyCardVoucher || floor > maxVoucherTier) return;
  final shop =
      _map(state['shop']) ??
      (() {
        final fresh = <String, dynamic>{};
        state['shop'] = fresh;
        return fresh;
      })();
  final existing = shop['scoutVouchers'];
  final list = existing is List ? existing : <dynamic>[];
  if (existing is! List) shop['scoutVouchers'] = list;
  list.add(floor);
}

/// Remove one of [floor] and report it, or null when none is held.
///
/// Mutating and single-use, and called AFTER the card has landed for the same
/// reason [signPlayer] reads its floor before the draw and spends it after:
/// burning a voucher somebody paid gems for on a signing that never happened is
/// the one bug this must not have.
int? takeVoucher(Map<String, dynamic> state, int floor) {
  final raw = _map(state['shop'])?['scoutVouchers'];
  if (raw is! List) return null;
  for (var i = 0; i < raw.length; i++) {
    final v = raw[i];
    if (v is num && v.isFinite && v.floor() == floor) {
      raw.removeAt(i);
      return floor;
    }
  }
  return null;
}

/// Why this voucher cannot be BOUGHT, for a shop that sells them by the
/// handful — [voucherBlocked] without the one-at-a-time clause.
///
/// Split from it rather than replacing it because that function is pinned to the
/// JS; this is the question the live shelf actually asks, and it can never
/// answer [VoucherBlock.alreadyHeld].
VoucherBlock? voucherPurchaseBlocked(Map<String, dynamic>? state, int floor) {
  final divisionId = _map(state?['progression'])?['currentDivision'] as String?;
  if (!voucherOffered(divisionId, floor)) return VoucherBlock.notOffered;
  final cost = voucherCost(floor);
  if (cost == null) return VoucherBlock.noPrice;
  if (getGems(state) < cost) return VoucherBlock.insufficientGems;
  return null;
}

/// Buy one into the inventory: debits the gems and adds the floor.
///
/// The live counterpart to [buyScoutVoucher], which arms the legacy scalar and
/// exists now only to answer the frozen fixture.
({bool ok, int? floor, int? cost, VoucherBlock? reason}) purchaseScoutVoucher(
  Map<String, dynamic> state,
  int floor,
) {
  final blocked = voucherPurchaseBlocked(state, floor);
  if (blocked != null) {
    return (ok: false, floor: null, cost: null, reason: blocked);
  }

  final cost = voucherCost(floor)!;
  if (!spendGems(state, cost, 'scout_voucher_t$floor')) {
    return (
      ok: false,
      floor: null,
      cost: null,
      reason: VoucherBlock.insufficientGems,
    );
  }

  grantVoucher(state, floor);
  return (ok: true, floor: floor, cost: cost, reason: null);
}

/// Spend the armed voucher and report the floor it guarantees, or null if none
/// was held.
///
/// Mutating and single-use — call it once per scouted card, inside the same
/// state update the draw happens in.
///
/// A voucher covers the scout OUTRIGHT: the caller charges no coins for a card
/// drawn under one. You paid gems, and paying the coin price on top would be
/// charging twice for one signing.
int? consumeScoutVoucher(Map<String, dynamic> state) {
  final floor = heldVoucherTier(state);
  if (floor == null) return null;
  _map(state['shop'])!['scoutVoucherTier'] = null;
  return floor;
}
