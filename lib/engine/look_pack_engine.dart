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
