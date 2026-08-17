/// Coin sinks, ported from `../merge-empire-fc/src/data/coinSinks.js`.
///
/// [CoinSink.unlockDiv] indexes into the division ladder (0 = sunday_league).
///
/// Trophy Polish used to be a coin sink (+2% permanent idle income per level,
/// capped at +40%). It is a one-season IAP buff now, so nobody can grind their
/// way to a permanent economy advantage.
///
/// [CoinSink.baseCost] is pre-scaling; the shop multiplies it by the current
/// division's `matchRevenueBase / 100`, and the engine helpers apply the same
/// scale.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/util/format.dart';

class CoinSink {
  const CoinSink({
    required this.id,
    required this.name,
    required this.icon,
    required this.unlockDiv,
    this.baseCost,
    this.costPerTier,
  });

  final String id;
  final String name;
  final String icon;

  /// Index into the division ladder at which this becomes buyable.
  final int unlockDiv;

  /// Scaled by division. Null when the sink prices off [costPerTier] instead.
  final int? baseCost;

  /// Multiplied by the target card's tier, with NO division scaling.
  final int? costPerTier;
}

const List<CoinSink> coinSinks = [
  CoinSink(
    id: 'loyalty_bonus',
    name: 'Loyalty Bonus',
    icon: '🎖️',
    unlockDiv: 2, // regional_league+
    costPerTier: 5000,
  ),
  CoinSink(
    id: 'kit_redesign',
    name: 'Kit Redesign',
    icon: '🎨',
    unlockDiv: 0,
    baseCost: 2000,
  ),
  CoinSink(
    id: 'youth_academy',
    name: 'Youth Academy',
    icon: '🌱',
    unlockDiv: 1, // amateur_cup+
    baseCost: 8000,
  ),
  CoinSink(
    id: 'lucky_pack',
    name: 'Lucky Pack',
    icon: '🎁',
    unlockDiv: 0,
    baseCost: 3000,
  ),
];

final Map<String, CoinSink> _byId = {for (final s in coinSinks) s.id: s};

CoinSink? getCoinSink(String? id) => id == null ? null : _byId[id];

/// Mirrors the shop's scaling: base times `matchRevenueBase / 100`.
double divisionCostMultiplier(Division? division) =>
    division == null ? 1 : division.matchRevenueBase / 100;

/// Current price for [sink] at a division, optionally against a target card.
num sinkCost(CoinSink? sink, {Division? division, int targetCardTier = 1}) {
  if (sink == null) return 0;
  if (sink.id == 'loyalty_bonus') {
    return roundCoins(sink.costPerTier! * math.max(1, targetCardTier));
  }
  return roundCoins((sink.baseCost ?? 0) * divisionCostMultiplier(division));
}
