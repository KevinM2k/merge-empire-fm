/// The boost inventory: owning, granting, spending, buying.
///
/// **Knows nothing about a match.** What a boost DOES lives on the match
/// screen and in `match_boost_state.dart`; this is the shelf and the wallet.
///
/// The inventory sits at `state['matchBoosts']` as `{id: count}` —
/// **deliberately not `state['boosts']`**, which is already the season flags:
/// the kit sponsor, the TV deal, trophy polish. Two unrelated things under one
/// key is how a reset that clears one takes the other with it.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/boosts.dart';
import 'package:merge_empire_fc/engine/gem_engine.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

Map<String, dynamic> _inventory(Map<String, dynamic> state) {
  final existing = _map(state['matchBoosts']);
  if (existing != null) return existing;
  final fresh = <String, dynamic>{};
  state['matchBoosts'] = fresh;
  return fresh;
}

/// How many of [id] the player holds. Zero for a missing inventory.
int boostCount(Map<String, dynamic>? state, String id) {
  final n = _num(_map(state?['matchBoosts'])?[id]);
  if (n == null || !n.isFinite || n <= 0) return 0;
  return n.floor();
}

/// Put [n] of [id] in the bag. A grant of nothing, or of a boost the
/// catalogue has never heard of, writes nothing — a daily reward pointing at a
/// retired id must not create a key.
void grantBoost(Map<String, dynamic> state, String id, int n) {
  if (n <= 0 || getBoost(id) == null) return;
  final bag = _inventory(state);
  bag[id] = boostCount(state, id) + n;
  emit('boosts:changed');
}

/// Take one, or refuse and change nothing. Never goes below zero.
///
/// **Debited on tap, before any animation** — the same rule the trait reel
/// plays by. An effect that charged and then failed to apply would be the
/// worst possible bug in a paid feature, and the way to make it impossible is
/// to have the debit and the apply be one decision.
bool spendBoost(Map<String, dynamic> state, String id) {
  final have = boostCount(state, id);
  if (have <= 0) return false;
  _inventory(state)[id] = have - 1;
  emit('boosts:changed');
  return true;
}

/// Why a pack can't be bought right now, or null when it can. Split out so
/// the shop can grey a tile with a reason rather than failing on tap — the
/// same shape as `gemItemBlocked`.
String? boostPackBlocked(Map<String, dynamic>? state, String id) {
  final boost = getBoost(id);
  if (boost == null) return 'unknown_boost';
  if (getGems(state) < boost.gemCost) return 'insufficient_gems';
  return null;
}

/// Buy a pack: debit the gems through the gem ledger, deliver the three.
({bool ok, String? reason}) buyBoostPack(Map<String, dynamic> state, String id) {
  final blocked = boostPackBlocked(state, id);
  if (blocked != null) return (ok: false, reason: blocked);
  final boost = getBoost(id)!;
  if (!spendGems(state, boost.gemCost, 'boost:$id')) {
    return (ok: false, reason: 'insufficient_gems');
  }
  grantBoost(state, id, boost.packSize);
  return (ok: true, reason: null);
}
