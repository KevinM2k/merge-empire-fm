/// Coin sinks — the things a full wallet can be spent on. Ported from
/// `../merge-empire-fc/src/engine/coinSinkEngine.js`.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/coin_sinks.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/lineup_engine.dart';
import 'package:merge_empire_fc/engine/merge_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

Map<String, dynamic> _branch(Map<String, dynamic> owner, String key) {
  final existing = _map(owner[key]);
  if (existing != null) return existing;
  final fresh = <String, dynamic>{};
  owner[key] = fresh;
  return fresh;
}

/// What an active Trophy Polish is worth. Doubling, so the season's coin income
/// is doubled outright — the same multiplier is applied to match revenue.
const double _trophyPolishBonus = 1.0;

/// The polish multiplier for a `boosts` branch read against one season.
///
/// The polish is a ONE-SEASON buff stamped with the season it was bought in, so
/// it expires at the next season end. An old save's permanent `polishLevel` is
/// ignored: the permanent form was retired to take out a
/// pay-for-permanent-advantage.
///
/// **Takes the two branches loose rather than the save**, because the two
/// functions that actually pay the buff out — `computeMultiplier` and
/// `computeMatchRevenueMultiplier` — are handed `boosts` and a season number,
/// not the state they came from. Without this shape they cannot call the rule
/// and end up restating it, which is how there came to be five copies of it:
/// twice in `idle_engine`, once in `income_breakdown`, once in `gem_engine`'s
/// shop guard, and here — where the only copy with a NAME was the one nothing
/// called.
///
/// They had already drifted. Four read a missing `seasonCount` as no match and
/// the fifth read it as season one, so a save with no progression branch could
/// have the shop refusing to sell a polish that nothing was paying out. The
/// paying engines' reading wins: the shop must never say "already active" about
/// a buff no multiplier is applying.
double trophyPolishMultiplierFor(
  Map<String, dynamic>? boosts,
  int? seasonCount,
) {
  final polishSeason = _num(boosts?['trophyPolishSeason']);
  if (polishSeason != null &&
      seasonCount != null &&
      polishSeason == seasonCount) {
    return 1 + _trophyPolishBonus;
  }
  return 1;
}

/// The polish multiplier for this save right now.
double trophyPolishMultiplier(Map<String, dynamic>? state) =>
    trophyPolishMultiplierFor(
      _map(state?['boosts']),
      _num(_map(state?['progression'])?['seasonCount'])?.toInt(),
    );

bool isTrophyPolishActive(Map<String, dynamic>? state) =>
    trophyPolishMultiplier(state) > 1;

int _divisionIndex(Map<String, dynamic>? state) {
  final id = _map(state?['progression'])?['currentDivision'] ?? divisions.first.id;
  final idx = divisions.indexWhere((d) => d.id == id);
  return idx < 0 ? 0 : idx;
}

Division _currentDivision(Map<String, dynamic>? state) =>
    getDivision('${_map(state?['progression'])?['currentDivision']}');

List<dynamic> _cells(Map<String, dynamic>? state) {
  final cells = _map(state?['grid'])?['cells'];
  return cells is List ? cells : const [];
}

int _findCardById(List<dynamic> cells, String? instanceId) {
  if (instanceId == null) return -1;
  for (var i = 0; i < cells.length; i++) {
    if (_map(cells[i])?['instanceId'] == instanceId) return i;
  }
  return -1;
}

int _findMaxSeasonsCard(List<dynamic> cells) {
  var best = -1;
  var bestSeasons = -1;
  for (var i = 0; i < cells.length; i++) {
    final card = _map(cells[i]);
    if (card == null) continue;
    final s = _num(card['seasonsPlayed'])?.toInt() ?? 0;
    if (s > bestSeasons) {
      bestSeasons = s;
      best = i;
    }
  }
  return best;
}

/// The Youth Academy's draw pool, scoped to a division.
///
/// The floor rises with the ladder, so a promotion is felt here too. Exported
/// because the discovery reachability check reads the LIVE pool rather than a
/// copy of this arithmetic — a change here can't leave a quest advertising
/// faces the game won't hand over.
List<seeded.WeightedEntry<String>> youthAcademyPool(int divIdx) {
  final minTier = 3 + math.min(2, divIdx ~/ 3);
  final maxTier = math.min(8, minTier + 2);
  final entries = [
    for (final p in players)
      if (p.tier >= minTier && p.tier <= maxTier && 10 - (p.tier - minTier) * 3 > 0)
        seeded.WeightedEntry(p.id, (10 - (p.tier - minTier) * 3).toDouble()),
  ];
  return entries.isNotEmpty ? entries : silverPool;
}

/// The Lucky Pack's pool: bronze in the bottom two divisions, silver above.
List<seeded.WeightedEntry<String>> luckyPackPool(int divIdx) =>
    divIdx <= 1 ? bronzePool : silverPool;

/// What this sink would cost right now, without buying it.
num peekCost(
  Map<String, dynamic>? state,
  String sinkId, {
  String? cardInstanceId,
}) {
  final sink = getCoinSink(sinkId);
  if (sink == null) return 0;

  var targetCardTier = 1;
  if (sink.id == 'loyalty_bonus' && cardInstanceId != null) {
    final cells = _cells(state);
    final idx = _findCardById(cells, cardInstanceId);
    if (idx >= 0) {
      final def = getPlayerDef(_map(cells[idx])?['definitionId'] as String?);
      if (def != null) targetCardTier = def.tier;
    }
  }

  return sinkCost(
    sink,
    division: _currentDivision(state),
    targetCardTier: targetCardTier,
  );
}

/// Has the player climbed far enough to be offered this sink?
bool isUnlocked(Map<String, dynamic>? state, String sinkId) {
  final sink = getCoinSink(sinkId);
  if (sink == null) return false;
  return _divisionIndex(state) >= sink.unlockDiv;
}

/// The outcome of a purchase.
typedef SinkPurchase = ({
  bool ok,
  String? reason,
  String? sinkId,
  num cost,
  int? cardIdx,
  int? seasonsReduced,
});

SinkPurchase _fail(String reason, [num cost = 0]) => (
  ok: false,
  reason: reason,
  sinkId: null,
  cost: cost,
  cardIdx: null,
  seasonsReduced: null,
);

/// Buy a coin sink, debiting the wallet and applying the effect.
///
/// Every failure path leaves the balance exactly where it found it — the two
/// card-placing sinks refund before returning, because a full grid is a
/// condition only discovered after the charge.
SinkPurchase purchaseCoinSink(
  Map<String, dynamic> state,
  String sinkId, {
  String? cardInstanceId,
  String? color,
}) {
  final sink = getCoinSink(sinkId);
  if (sink == null) return _fail('unknown_sink');
  if (!isUnlocked(state, sinkId)) return _fail('locked');

  final cells = _cells(state);
  var targetIdx = -1;
  if (sink.id == 'loyalty_bonus') {
    targetIdx = cardInstanceId != null
        ? _findCardById(cells, cardInstanceId)
        : _findMaxSeasonsCard(cells);
    if (targetIdx < 0) return _fail('no_target');
  }

  if (sink.id == 'kit_redesign' && color == null) return _fail('no_color');

  final cost = peekCost(state, sinkId, cardInstanceId: cardInstanceId);
  final resources = _branch(state, 'resources');
  if ((_num(resources['fanCoins']) ?? 0) < cost) {
    return _fail('insufficient_coins', cost);
  }

  resources['fanCoins'] = roundCoins((_num(resources['fanCoins']) ?? 0) - cost);
  final divIdx = _divisionIndex(state);

  int? cardIdx;
  int? seasonsReduced;

  switch (sink.id) {
    case 'loyalty_bonus':
      final card = _map(cells[targetIdx])!;
      final prev = _num(card['seasonsPlayed'])?.toInt() ?? 0;
      card['seasonsPlayed'] = math.max(0, prev - 2);
      seasonsReduced = prev - (card['seasonsPlayed'] as int);

    case 'kit_redesign':
      _branch(state, 'club')['kitPrimaryColor'] = color;

    case 'youth_academy':
    case 'lucky_pack':
      final pool = sink.id == 'youth_academy'
          ? youthAcademyPool(divIdx)
          : luckyPackPool(divIdx);
      final defId = seeded.weightedPick(pool);
      final placed = placeCard(defId, cells);
      if (!placed.ok) {
        resources['fanCoins'] =
            roundCoins((_num(resources['fanCoins']) ?? 0) + cost);
        return _fail('grid_full');
      }
      cardIdx = placed.idx;
      _refillLineup(state, cells);

    default:
      resources['fanCoins'] =
          roundCoins((_num(resources['fanCoins']) ?? 0) + cost);
      return _fail('unknown_action');
  }

  final result = (
    ok: true,
    reason: null,
    sinkId: sinkId,
    cost: cost,
    cardIdx: cardIdx,
    seasonsReduced: seasonsReduced,
  );
  emit('coins:updated', resources['fanCoins']);
  emit('coinSink:purchased', result);
  return result;
}

/// A new card goes straight into any empty slot in the XI.
void _refillLineup(Map<String, dynamic> state, List<dynamic> cells) {
  final squad = _map(state['squad']);
  final lineup = squad?['lineup'];
  if (squad == null || lineup is! List) return;

  final slots = <LineupSlot>[
    for (final s in lineup)
      if (s is Map)
        LineupSlot(
          slotId: s['slotId'] as String? ?? '',
          slotPosition: s['slotPosition'] as String? ?? '',
          cardInstanceId: s['cardInstanceId'] as String?,
        ),
  ];

  final filled = fillLineupGaps(
    slots,
    squad['formation'] as String? ?? defaultFormation,
    [for (final c in cells) CardInstance.from(c)],
  );

  squad['lineup'] = [
    for (final s in filled)
      <String, dynamic>{
        'slotId': s.slotId,
        'slotPosition': s.slotPosition,
        'cardInstanceId': s.cardInstanceId,
      },
  ];
}
