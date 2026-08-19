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

// ── Scouting in batches ─────────────────────────────────────────────────────

/// The batch sizes the Scout button offers.
const List<int> scoutBatchSizes = [1, 2, 4];

int get maxScoutBatch => scoutBatchSizes.last;

/// The player's stored preference, clamped to a size that exists.
int scoutBatch(Map<String, dynamic>? state) {
  final n = _num(_map(state?['settings'])?['scoutBatch'])?.toInt() ?? 1;
  return scoutBatchSizes.contains(n) ? n : 1;
}

void setScoutBatch(Map<String, dynamic> state, int n) {
  if (!scoutBatchSizes.contains(n)) return;
  final settings = state.putIfAbsent('settings', () => <String, dynamic>{});
  if (settings is Map<String, dynamic>) settings['scoutBatch'] = n;
}

/// Which batch sizes this save can actually pay for and house.
///
/// **The button never offers a batch it cannot deliver.** Showing a ×4 that
/// runs out of coins on the third card is the trap this avoids — the player has
/// already tapped by the time they find out.
///
/// A voucher or a free scout covers the FIRST card only, so the rest are priced
/// at the normal rate.
List<int> availableScoutBatchSizes(Map<String, dynamic>? state) {
  final free = _freeScoutReady(state) || heldVoucherTier(state) != null;
  final unit = scoutCost(state, ignoreVoucher: true);
  final byCoins = (free ? 1 : 0) + (unit <= 0 ? 0 : _coins(state) ~/ unit);
  final bySlots = _cells(state).where((c) => c == null).length;
  final max = math.min(byCoins, bySlots);
  final sizes = [
    for (final n in scoutBatchSizes)
      if (n <= max) n,
  ];
  return sizes.isEmpty ? const [1] : sizes;
}

/// What a Scout tap will actually buy: the stored choice, clamped down to what
/// is available.
int effectiveScoutBatch(Map<String, dynamic>? state) {
  final sizes = availableScoutBatchSizes(state);
  final want = scoutBatch(state);
  final affordable = [
    for (final n in sizes)
      if (n <= want) n,
  ];
  return affordable.isEmpty ? sizes.first : affordable.last;
}

/// What a batch actually delivered.
typedef ScoutBatch = ({
  List<int> placed,
  int spent,

  /// Why it fell short of what was asked for, or null when it did not.
  /// One of `insufficient_coins`, `grid_full`, `no_candidate`.
  String? stoppedBy,
});

/// Sign up to [count] players in one go.
///
/// Each card is drawn, priced and placed INDEPENDENTLY, which is what makes a
/// short batch honest: the position bias and the tier-nine uniqueness filter
/// both re-read the grid, so they see the cards this batch has already placed;
/// coins come off per card as it lands, so a run that hits the buffers has
/// charged only for what it delivered; and the voucher is consumed by the first
/// card alone.
ScoutBatch signPlayers(Map<String, dynamic> state, int count) {
  final placed = <int>[];
  var spent = 0;
  String? stoppedBy;

  for (var i = 0; i < math.max(1, count); i++) {
    final result = signPlayer(state);
    if (!result.ok) {
      stoppedBy = result.reason;
      break;
    }
    if (result.idx != null) placed.add(result.idx!);
    spent += result.cost;
  }

  return (placed: placed, spent: spent, stoppedBy: stoppedBy);
}
