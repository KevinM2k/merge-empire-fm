/// Signing a player — the "Add Player" action.
///
/// Lifted out of `ui/screens/GridScreen.js`, which is where `computeScoutCost`
/// and the whole signing sequence lived. Without it a save starts with an empty
/// grid and no way to fill one, so this is not an extraction for tidiness: it is
/// the action the game opens on.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/engine/merge_engine.dart';
import 'package:merge_empire_fc/engine/scout_engine.dart';
import 'package:merge_empire_fc/engine/scout_voucher_engine.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

List<dynamic> _cells(Map<String, dynamic>? state) {
  final cells = _map(state?['grid'])?['cells'];
  return cells is List ? cells : const [];
}

num _coins(Map<String, dynamic>? state) =>
    _num(_map(state?['resources'])?['fanCoins']) ?? 0;

bool _freeScoutReady(Map<String, dynamic>? state) =>
    _map(state?['shop'])?['freeScoutReady'] == true;

/// What a signing costs right now.
///
/// Either voucher covers the coin price outright: the plain free scout because
/// that IS its effect, and the Guaranteed Scout because it was already paid for
/// in gems. The Youth Academy discounts the rest — that is the Academy's single
/// stat, its squad slots being a milestone track rather than a second one.
int scoutCost(Map<String, dynamic>? state, {bool ignoreVoucher = false}) {
  if (!ignoreVoucher &&
      (_freeScoutReady(state) || heldVoucherTier(state) != null)) {
    return 0;
  }
  final divId = _map(state?['progression'])?['currentDivision'] as String?;
  final div = getDivision(divId ?? divisions.first.id);
  final base = Scout.baseCostByDiv[div.id] ?? Scout.baseCost;
  final academy = _map(_map(state?['clubAssets'])?[AssetCategory.academy]);
  final discount = academy?['owned'] == true
      ? academyScoutDiscount((_num(academy?['tier']) ?? 0).toInt())
      : 0.0;
  return math.max(1, (base * (1 - discount)).round());
}

/// Why a player cannot be signed, or null when one can.
///
/// One of: `grid_full`, `insufficient_coins`, `no_candidate`.
String? signBlocked(Map<String, dynamic>? state) {
  if (findFirstEmpty(_cells(state)) == -1) return 'grid_full';
  final free = _freeScoutReady(state) || heldVoucherTier(state) != null;
  if (!free && _coins(state) < scoutCost(state)) return 'insufficient_coins';
  if (pickScoutDefinition(state, minTier: heldVoucherTier(state)) == null) {
    return 'no_candidate';
  }
  return null;
}

typedef Signing = ({bool ok, String? reason, int? idx, int cost, bool wasFree});

Signing _fail(String reason) =>
    (ok: false, reason: reason, idx: null, cost: 0, wasFree: false);

/// Sign one player into the first empty slot.
///
/// The voucher is READ before the draw and only spent after the card lands. The
/// draw can still fail on a full grid, and burning a voucher somebody paid gems
/// for on a signing that never happened is the one bug this must not have.
Signing signPlayer(Map<String, dynamic> state) {
  final blocked = signBlocked(state);
  if (blocked != null) return _fail(blocked);

  final floor = heldVoucherTier(state);
  final free = floor != null || _freeScoutReady(state);
  final cost = free ? 0 : scoutCost(state);

  final defId = pickScoutDefinition(state, minTier: floor);
  if (defId == null) return _fail('no_candidate');

  final placed = placeCard(defId, _cells(state));
  if (!placed.ok) return _fail(placed.reason ?? 'grid_full');

  // Spend the voucher AHEAD of the plain free scout, so holding both never
  // burns the free one on a card the voucher was already paying for.
  if (floor != null) {
    consumeScoutVoucher(state);
  } else if (free) {
    final shop = _map(state['shop']);
    if (shop != null) shop['freeScoutReady'] = false;
  } else {
    final resources = _map(state['resources']);
    if (resources != null) {
      resources['fanCoins'] = (_coins(state) - cost).toInt();
    }
  }

  final stats = _map(state['stats']);
  if (stats != null) {
    stats['totalScouts'] = ((_num(stats['totalScouts']) ?? 0) + 1).toInt();
  }

  return (ok: true, reason: null, idx: placed.idx, cost: cost, wasFree: free);
}
