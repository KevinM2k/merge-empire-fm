/// Signing a player — the "Add Player" action.
///
/// Lifted out of `ui/screens/GridScreen.js`, which is where `computeScoutCost`
/// and the whole signing sequence lived. Without it a save starts with an empty
/// grid and no way to fill one, so this is not an extraction for tidiness: it is
/// the action the game opens on.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/player_art.dart' show isVariantFemale;
import 'package:merge_empire_fc/engine/tutorial_engine.dart';
import 'dart:math' as math;

import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/quests.dart';
import 'package:merge_empire_fc/engine/auto_tier_engine.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart' show getMaxPlayers;
import 'package:merge_empire_fc/engine/merge_engine.dart';
import 'package:merge_empire_fc/engine/scout_engine.dart';
import 'package:merge_empire_fc/engine/scout_voucher_engine.dart';
import 'package:merge_empire_fc/engine/season_end.dart' show trackEvent;
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/analytics.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

List<dynamic> _cells(Map<String, dynamic>? state) {
  final cells = _map(state?['grid'])?['cells'];
  return cells is List ? cells : const [];
}

int _occupied(Map<String, dynamic>? state) =>
    _cells(state).where((c) => c != null).length;

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
///
/// **THIS DOES NOT CONSULT THE INVENTORY, and the distinction is the whole
/// feature.** "A voucher is held" and "this card is free" used to be one fact,
/// because only one voucher could exist and it was applied automatically. With
/// a stack they are two: a card is free because a voucher was ASSIGNED to it,
/// on the sheet, by the player. So this is the full unit price for anyone
/// holding a collection, and the batch's real total is the sum over the
/// assignment — see [signPlayers].
///
/// The two legacy reads stay because they cost nothing: `migrate` drains both
/// keys, so on a live save they are always empty and this always returns the
/// full price. What they still answer for is the JS fixture's hand-made states.
int scoutCost(Map<String, dynamic>? state, {bool ignoreVoucher = false}) {
  if (!ignoreVoucher &&
      (_freeScoutReady(state) || heldVoucherTier(state) != null)) {
    return 0;
  }
  final divId = _map(state?['progression'])?['currentDivision'] as String?;
  final div = getDivision(divId ?? divisions.first.id);
  final base = Scout.baseCostByDiv[div.id] ?? Scout.baseCost;
  // The FRACTIONAL tier: every tap buys its share of the discount rather than
  // the last one buying all of it. See [fractionalAssetTier].
  final discount = academyScoutDiscount(
    fractionalAssetTier(_map(state?['clubAssets']), AssetCategory.academy),
  );
  return math.max(1, (base * (1 - discount)).round());
}

/// Why a player cannot be signed, or null when one can.
///
/// One of: `grid_full`, `insufficient_coins`, `no_candidate`.
String? signBlocked(Map<String, dynamic>? state, {int? voucher}) {
  // **THE ROSTER CAP, not the array's length.** `grid.cells` is 39 long because
  // 30 plus a maxed Youth Academy's 8 needs 39 with one spare — it is a
  // fixed-length array so index-based drag targets stay stable, and it is NOT
  // the squad limit. Checking only `findFirstEmpty` let a save reach 39 players
  // on a cap of 30, which is how it was reported: "I'm locked at 30 and I have
  // 39".
  //
  // **In `signBlocked` rather than at the button**, which is where the JS puts
  // it — its `_scout` checks the count once before the batch and then trusts
  // `placeCard`, so a batch of four starting at 29 still lands four. Every
  // signing here goes through this, batch included, so the port cannot.
  if (_occupied(state) >= getMaxPlayers(state)) return 'grid_full';
  if (findFirstEmpty(_cells(state)) == -1) return 'grid_full';
  // **Per card, and [voucher] is what makes it exact.** In a batch the slots
  // are priced separately: with three vouchers held and one assigned, the
  // unassigned slots are still full price, so "does the player hold anything"
  // is the wrong question here — it would wave through a card the coins cannot
  // cover and drive the balance negative. [scoutBlocked] asks the looser
  // question, for the button.
  final free = voucher != null ||
      _freeScoutReady(state) ||
      heldVoucherTier(state) != null;
  if (!free && _coins(state) < scoutCost(state, ignoreVoucher: true)) {
    return 'insufficient_coins';
  }
  final floor = voucher != null ? drawFloorFor(voucher) : heldVoucherTier(state);
  if (pickScoutDefinition(state, minTier: floor) == null) {
    return 'no_candidate';
  }
  return null;
}

/// Why the Scout button is dead, or null when it is live.
///
/// [signBlocked] asks about ONE card at its own price. This asks whether a scout
/// is possible at all, and the difference is a player holding vouchers and no
/// coins: every held voucher is a card they can take, so the button is live and
/// the assignment sheet is where it gets spent. Without this the whole control
/// greyed out with a full tray, which is the opposite of what the feature is.
///
/// It does not need to know WHICH vouchers cover which slots — that is the
/// sheet's answer, and `availableScoutBatchSizes` has already capped the batch
/// to what the two purses can deliver between them.
String? scoutBlocked(Map<String, dynamic>? state) {
  final blocked = signBlocked(state);
  if (blocked == 'insufficient_coins' && hasVouchers(state)) return null;
  return blocked;
}

/// One signing, and everything the reveal needs to caption it.
///
/// The reveal facts are decided HERE and applied nowhere: a card the tier rules
/// have marked is still drawn, still placed and still turned over, and only
/// cashed in once the player has seen it ([settleAutoSales]). Selling it out
/// from under the reveal made Add Player look like it had done nothing at all.
typedef Signing = ({
  bool ok,
  String? reason,
  int? idx,
  int cost,
  bool wasFree,

  /// First time this player has ever been seen, gender included.
  bool isNewDiscovery,

  /// The tier rules will cash this one in once the reveal is over.
  bool autoSell,

  /// What it will fetch. Priced now so the badge quotes the figure the sale
  /// pays — [autoSellPrice] has no market roll, so it is stable.
  num sellCoins,

  /// The Guaranteed Scout's tier floor, when one paid for this card.
  int? voucherFloor,

  /// A plain free scout paid for it instead.
  bool voucherRandom,
});

Signing _fail(String reason) => (
  ok: false,
  reason: reason,
  idx: null,
  cost: 0,
  wasFree: false,
  isNewDiscovery: false,
  autoSell: false,
  sellCoins: 0,
  voucherFloor: null,
  voucherRandom: false,
);

/// Sign one player into the first empty slot.
///
/// The voucher is READ before the draw and only spent after the card lands. The
/// draw can still fail on a full grid, and burning a voucher somebody paid gems
/// for on a signing that never happened is the one bug this must not have.
///
/// [voucher] is the inventory entry the player put on THIS card — a floor of
/// 2..8, or [anyCardVoucher] for the token. Null means they left the slot to the
/// coins. It arrives as an argument rather than being read off the save because
/// with a stack the save cannot say which card a voucher was meant for; that is
/// the assignment sheet's answer and only the caller has it.
///
/// With no argument the legacy read still runs, so a save carrying the old
/// scalar behaves exactly as it did.
Signing signPlayer(
  Map<String, dynamic> state, {
  int batchSize = 1,
  int? voucher,
}) {
  final blocked = signBlocked(state, voucher: voucher);
  if (blocked != null) return _fail(blocked);

  // An assigned token is free but has NO floor — see [drawFloorFor]. Reading
  // `floor` where the caller meant "any card" would cut tier 9 from the pool.
  final floor = voucher != null ? drawFloorFor(voucher) : heldVoucherTier(state);
  final free = voucher != null || floor != null || _freeScoutReady(state);
  final cost = free ? 0 : scoutCost(state, ignoreVoucher: true);

  final defId = pickScoutDefinition(
    state,
    minTier: floor,
    // **THE TUTORIAL SCOUTS TIER ONE.** Sunday League draws the bottom two
    // tiers and caps merges at tier 2, so a pair of tier-2 cards is a pair that
    // cannot merge — and the step after this asks the player to merge. A
    // voucher's floor still wins, because a floor is something somebody paid
    // for; nothing holds one this early.
    maxTier: floor == null ? tutorialScoutMaxTier(state) : null,
  );
  if (defId == null) return _fail('no_candidate');

  // **THE TUTORIAL'S THIRD CARD IS A TWIN**, because the step after it asks the
  // player to merge two. The draw above still happens and is still consumed, so
  // the seeded sequence every later roll in the game depends on is untouched;
  // what changes is which definition lands. Null for everybody else, which is
  // every scout after the third. See `tutorialPairTwin`.
  final twin = tutorialPairTwin(state);
  final placed = placeCard(
    twin?.definitionId ?? defId,
    _cells(state),
    preferredFemale: twin == null
        ? null
        : isVariantFemale((twin.raw['variant'] as num?)?.toInt() ?? 0),
  );
  if (!placed.ok) return _fail(placed.reason ?? 'grid_full');

  // Spend the voucher AHEAD of the plain free scout, so holding both never
  // burns the free one on a card the voucher was already paying for.
  //
  // An assigned voucher comes out of the inventory here, AFTER the card has
  // landed, for the reason in this function's header: the draw can still fail
  // on a full grid, and a voucher burned on a signing that never happened is
  // the one bug this must not have.
  if (voucher != null) {
    takeVoucher(state, voucher);
  } else if (floor != null) {
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
  // The action funnel, which the season quest track and any live event's reward
  // track both read. `season_scout` could not advance without it.
  trackEvent(state, QuestAction.scoutCount);

  // **ONE EVENT PER CARD, which is the JS's arrangement and worth keeping.**
  // A batch of four reports four scouts, so the count stays comparable with
  // every scout recorded before batching existed; `batch_size` is additive for
  // anyone who wants to split them apart later. The cost is BANDED as well as
  // raw — it scales with the division, so the raw figure is nearly unique per
  // player and useless as a dimension.
  logAppEvent('scout', {
    'cost': cost,
    'cost_bucket': bucketCoins(cost),
    'is_free': free,
    // 0 rather than null for a scout with no voucher on it: the JS sends 0 and
    // a missing param and a zero are different rows on a dashboard.
    //
    // The ASSIGNED entry rather than the draw floor, so the 🎲 token reports as
    // 1 instead of sharing 0 with an ordinary coin scout — with a batch able to
    // carry four different vouchers, telling those apart is the whole value of
    // this row.
    'voucher_tier': voucher ?? floor ?? 0,
    'batch_size': batchSize,
    'division': '${_map(state['progression'])?['currentDivision'] ?? 'unknown'}',
  });

  final idx = placed.idx!;
  final cells = _cells(state);
  final raw = idx < cells.length ? cells[idx] : null;
  final autoSell = willAutoSell(state, cells, idx);

  return (
    ok: true,
    reason: null,
    idx: idx,
    cost: cost,
    wasFree: free,
    isNewDiscovery: isFirstSighting(state, raw),
    autoSell: autoSell,
    sellCoins: autoSell
        ? autoSellPrice(
            state,
            getPlayerDef(CardInstance.from(raw)?.definitionId ?? ''),
            CardInstance.from(raw),
          )
        : 0,
    // **Any number of a batch's cards can be on a voucher now**, each with its
    // own floor, which is what the assignment sheet is for. The caption is what
    // tells them apart on the reveal; it used to mark the first card only,
    // because the first card was the only one that could ever carry one.
    voucherFloor: floor,
    voucherRandom: floor == null && free,
  );
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
/// **Voucher capacity is ADDITIVE**: every voucher held is one more card the
/// player can take beyond what the coins buy. The rule is the one that was
/// always here — the line used to read `(free ? 1 : 0)`, a bool, because one
/// voucher was the most anyone could have. It is a count now.
///
/// So two vouchers plus coins for four offers ×4 (capacity six, and the ladder
/// stops at four); two vouchers and no coins offers ×2; no vouchers and coins
/// for four offers ×4, exactly as before.
///
/// **What this cannot promise on its own**: capacity assumes the vouchers get
/// assigned, and the player may decline on the sheet — two vouchers plus coins
/// for two gives a ×4 that only pays for two. The sheet closes that by refusing
/// Continue while the unassigned slots cost more than the wallet, which is where
/// the answer is actually known; [signPlayers] keeps its short-batch handling as
/// the backstop either way.
List<int> availableScoutBatchSizes(Map<String, dynamic>? state) {
  final legacy = _freeScoutReady(state) || heldVoucherTier(state) != null;
  final vouchers = voucherInventory(state).length + (legacy ? 1 : 0);
  final unit = scoutCost(state, ignoreVoucher: true);
  final byCoins = vouchers + (unit <= 0 ? 0 : _coins(state) ~/ unit);
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
  // **ONE AT A TIME WHILE THE TUTORIAL IS RUNNING.** The batch control is
  // already hidden until the script finishes, but the SIZE it would have used
  // is stored on the save — so a player part-way through the tutorial on a
  // save that had picked ×3 would spend three times the coins on a step that
  // asks for one card, and be taught the wrong lesson at the same time. The
  // step counts cards, not presses; the ×N control is the reward for finishing.
  if (!tutorialFinished(state)) return 1;
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
  /// One entry per card that landed, in the order they landed.
  List<Signing> placed,
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
/// charged only for what it delivered; and a voucher is consumed only by the
/// card it was put on.
///
/// [vouchers] is the assignment, one entry per slot in the same order — a floor,
/// [anyCardVoucher], or null for a slot left to the coins. A short list is fine
/// and so is none at all; anything past the end is simply unassigned.
///
/// **The draw sequence does not depend on WHERE the vouchers went**, which
/// matters because a save's whole future is seeded off it. `weightedPick` takes
/// exactly one `random()` whatever the pool holds, so four cards are four draws
/// either way; a floor changes which pool a draw filters against, never how many
/// values come off the sequence or in what order.
ScoutBatch signPlayers(
  Map<String, dynamic> state,
  int count, {
  List<int?>? vouchers,
}) {
  final want = math.max(1, math.min(maxScoutBatch, count));
  final placed = <Signing>[];
  var spent = 0;
  String? stoppedBy;

  for (var i = 0; i < want; i++) {
    final result = signPlayer(
      state,
      batchSize: want,
      voucher: vouchers != null && i < vouchers.length ? vouchers[i] : null,
    );
    if (!result.ok) {
      stoppedBy = result.reason;
      break;
    }
    placed.add(result);
    spent += result.cost;
  }

  if (placed.isNotEmpty) {
    emit('coins:updated', _coins(state));
    // Fell short of what was asked for — say so, rather than quietly delivering
    // fewer cards than the player was paying attention to.
    if (placed.length < want) {
      emit('scout:short', {'got': placed.length, 'want': want});
    }
  }

  return (placed: placed, spent: spent, stoppedBy: stoppedBy);
}

/// What the tier rules cashed in once the reveal was over.
typedef AutoSales = ({int sold, num coins, PlayerDef? topSoldDef});

/// Cash in the cards the tier rules marked, now that the reveal has finished.
///
/// Deliberately after the reveal rather than during the draw: the player sees
/// every card they paid for, then watches the marked ones turn into coins. The
/// guards are re-checked inside [applyTierAction] against live state, so a rule
/// switched off mid-reveal — or a squad down to its last player — still wins.
AutoSales settleAutoSales(Map<String, dynamic> state, List<Signing> placed) {
  var sold = 0;
  num coins = 0;
  PlayerDef? topSoldDef;

  for (final signing in placed) {
    final idx = signing.idx;
    if (!signing.autoSell || idx == null) continue;
    final ruled = applyTierAction(state, _cells(state), idx);
    if (ruled.action != TierAction.sell) continue;
    sold++;
    coins += ruled.coins;
    if ((ruled.def?.tier ?? 0) > (topSoldDef?.tier ?? 0)) {
      topSoldDef = ruled.def;
    }
  }

  if (sold > 0) {
    emit('coins:updated', _coins(state));
    emit('scout:auto_sold', {'sold': sold, 'coins': coins});
    // The sell SFX and the achievement sweep both fire once for the batch, keyed
    // on the best card that went — an auto-sold Gold is still a big-money move.
    emit('player:sold', {'def': topSoldDef, 'definitionId': topSoldDef?.id});
  }

  return (sold: sold, coins: coins, topSoldDef: topSoldDef);
}
