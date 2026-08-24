/// What a look pack's Shop tile offers right now. Ported from
/// `../merge-empire-fc/src/engine/lookPackEngine.js`.
///
/// The Shop sells the same packs the customiser does, but as a grid of tiles
/// rather than a chip you tapped, so each tile has to state its own offer.
/// `owned` and `total` come back with it because partial progress is the normal
/// state now — a video buys ONE item, so most packs a player has touched are
/// part-owned.
///
/// A TILE SHOWS THE PACK'S PRICE: owned, or the gem cost. That is all.
///
/// It used to lead with "▶ FREE" whenever an ad slot was open, and fall back to
/// gems, then to a countdown. That ordering came from one-ad-per-pack, where the
/// pill was true. It is not any more: a video buys one item, so "FREE" over a
/// tile that sells a whole pack promised something the sheet then did not do —
/// and the countdown was worse, because it implied a pack you could only get by
/// waiting.
///
/// The video route has not gone anywhere; it moved to where it is honest. Every
/// item inside the sheet has its own ▶, and so does every locked chip in the
/// customiser. What this tile answers is "what does the pack cost".
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/engine/ad_gate_engine.dart';
import 'package:merge_empire_fc/engine/gem_engine.dart';

/// A pack tile: what it costs, and how much of it the player already has.
typedef LookTile = ({
  String status,
  int waitMs,
  int cost,
  int owned,
  int total,
});

/// The tile for [packId], or null when the pack is not in the catalogue — the
/// caller should render nothing rather than a tile for a pack that unlocks no
/// items.
///
/// `cost` is this pack's gem price. Flat across the catalogue today, but still
/// returned per pack so a caller never has to know that.
LookTile? lookTileState(Map<String, dynamic>? state, String? packId) {
  final pack = getLookPack(packId);
  if (pack == null) return null;

  final cost = packGemCost();
  final total = pack.items.length;
  final owned = packUnlockedCount(state, packId);

  if (isPackComplete(state, packId)) {
    return (status: 'owned', waitMs: 0, cost: cost, owned: owned, total: total);
  }

  // Priced, whether or not the player can afford it today. A price you have not
  // got yet is still the offer; hiding it behind a countdown told the player to
  // wait for something waiting never delivers.
  return (status: 'gems', waitMs: 0, cost: cost, owned: owned, total: total);
}

/// The outcome of buying a whole pack.
typedef LookPackPurchase = ({bool ok, String? reason});

/// Why a tap on a pack cannot go through, or null when it can.
///
/// One of `unknown_pack`, `already_owned`, `insufficient_gems` — the same
/// vocabulary `gemItemBlocked` uses, because the Shop's purchase flow reads a
/// refusal the same way whatever sold it.
String? lookPackBlocked(Map<String, dynamic>? state, String? packId) {
  if (getLookPack(packId) == null) return 'unknown_pack';
  if (isPackComplete(state, packId)) return 'already_owned';
  if (getGems(state) < packGemCost()) return 'insufficient_gems';
  return null;
}

/// Buy the pack outright: debit the gems, grant it.
///
/// **The tile was a price with nothing behind it.** `grantLookPack` was written
/// and never called from anywhere but a test, so a pack could only ever be
/// assembled item by item off videos — the five-gem price on every tile in the
/// Shop was a figure the player could read and not act on.
///
/// A pack the player has already COMPLETED item by item is not sold again: it
/// is already theirs by the only measure that matters, which is what
/// `isPackComplete` answers.
LookPackPurchase buyLookPack(Map<String, dynamic> state, String? packId) {
  final blocked = lookPackBlocked(state, packId);
  if (blocked != null) return (ok: false, reason: blocked);
  if (!spendGems(state, packGemCost(), 'look_pack:$packId')) {
    return (ok: false, reason: 'insufficient_gems');
  }
  grantLookPack(state, packId);
  return (ok: true, reason: null);
}

/// The AdMob placement a cosmetic unlock spends. A key from `ad_units.dart`.
///
/// Its own unit, not the energy one, because the cap is PER UNIT — see
/// `ad_gate_engine.dart`. Hats sharing energy's budget is the thing a separate
/// unit exists to prevent.
const String cosmeticPlacement = 'cosmetic_pack';

/// What ONE locked cosmetic offers right now.
///
/// `status` is one of:
///
/// - `owned` — already theirs, by any route. Nothing to offer.
/// - `video` — a rewarded video would unlock it, and the gate is open.
/// - `wait` — the video route is the right one but the cap is spent;
///   `waitMs` is how long until it reopens.
/// - `earned` — there is NO video route and there is not meant to be. Fan Zone
///   tiers and cup exclusives are earned, and the diamond crown in particular is
///   worthless the moment a video can buy it. The caller shows the requirement.
typedef LookItemOffer = ({String status, int waitMs});

/// The offer on `kind:id`.
///
/// **Eligibility is `grantLookItem`'s rule, read from the same place.** A thing
/// with no pack behind it is earned, and asking here rather than listing the
/// exceptions again is what stops the two answers drifting apart — the grant
/// refuses one of those keys whatever this says.
LookItemOffer lookItemOffer(
  Map<String, dynamic>? state,
  String kind,
  String id, [
  int? nowMs,
]) {
  if (isLookUnlocked(state, kind, id)) {
    return (status: 'owned', waitMs: 0);
  }
  if (lookRequirement(kind, id)?.packId == null) {
    return (status: 'earned', waitMs: 0);
  }
  final wait = msUntilPackAd(state, nowMs);
  if (wait > 0) return (status: 'wait', waitMs: wait);
  return (status: 'video', waitMs: 0);
}

/// Take the reward for a watched cosmetic video: grant the item AND spend the
/// slot, or neither.
///
/// **The two halves are one call because the port has been bitten by exactly
/// this shape before** — a pair where only one half has a caller. Granting
/// without recording leaves a cap that never bites, so the local mirror runs
/// behind AdMob's own and the UI offers videos the SDK then declines;
/// recording without granting takes the slot and pays nothing.
///
/// False when the key is not one a video may buy, or the player already has it.
/// Callers reach this only from the reward callback: a video that did not pay
/// out consumed nothing on AdMob's side either, and counting it would lock the
/// player out over a network blip.
bool claimLookItemAd(
  Map<String, dynamic>? state,
  String kind,
  String id, [
  int? nowMs,
]) {
  if (state == null) return false;
  if (!grantLookItem(state, '$kind:$id')) return false;
  recordPackAd(state, nowMs);
  return true;
}
