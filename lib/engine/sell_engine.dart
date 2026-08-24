/// Sell pricing, shared by the manual sell sheet and the auto-sell rules.
/// Ported from `../merge-empire-fc/src/engine/sellEngine.js`.
///
/// [baseSellPrice] is the fair, deterministic value of a card — what it is
/// worth before any market roll. The Squad sheet multiplies it by a random
/// market multiplier; auto-sell takes it flat, so hands-off selling is
/// predictable and manual selling keeps its upside.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/transfer_market.dart';
import 'package:merge_empire_fc/state/card_instance.dart';

/// The haircut between a card's sell value and what it fetches. Selling is
/// meant to recover something, not to be a second income stream.
const double sellMarketFactor = 0.5;

/// A card's fair value, before any market roll.
double baseSellPrice(
  PlayerDef? def,
  CardInstance? card,
  Map<String, dynamic>? state,
) {
  if (def == null) return 0;
  final tierMult = transferTierMultiplier[def.tier] ?? 4;
  final divId = (state?['progression'] as Map<String, dynamic>?)?['currentDivision'];
  final div = getDivision('$divId');

  // A POWER-scaled division multiplier, so late-game sell prices don't balloon
  // with matchRevenueBase — which reaches 200× by Continental.
  final divMult = math.pow(div.matchRevenueBase / 100, 0.35).toDouble();
  final base = def.sellValue * tierMult * divMult * sellMarketFactor;

  final aging = agingPenalty(card?.seasonsPlayed ?? 0);
  if (aging > 0 && def.rating > 0) {
    return base * math.max(0.2, (def.rating - aging) / def.rating);
  }
  return base;
}

/// One rung of the sell market.
class MarketTier {
  const MarketTier({required this.labelKey, required this.mult});

  final String labelKey;

  /// The floor of this rung; a roll lands at or above it.
  final double mult;
}

/// Five rungs, cheapest first. A roll lands on one and adds a little on top.
const List<MarketTier> marketTiers = [
  MarketTier(labelKey: 'sell.market_lowball', mult: 0.5),
  MarketTier(labelKey: 'sell.market_modest', mult: 0.9),
  MarketTier(labelKey: 'sell.market_fair', mult: 1.3),
  MarketTier(labelKey: 'sell.market_great', mult: 1.8),
  MarketTier(labelKey: 'sell.market_jackpot', mult: 2.8),
];

/// Which rung a multiplier sits on.
/// Where a multiplier sits along the market's own range, 0 to 1.
///
/// **The top of the scale is the best rung PLUS a half**, which is the JS's own
/// `MARKET_TIERS[4].mult + 0.5` and is not arbitrary: a roll lands on a rung and
/// adds a little on top, so the jackpot's own 2.8 is the FLOOR of the best band
/// rather than the ceiling of the scale. Ending the bar at 2.8 would peg every
/// jackpot at the far end and make the best outcome in the game look identical
/// to the second-best.
double marketPosition(double mult) {
  final low = marketTiers.first.mult;
  final high = marketTiers.last.mult + 0.5;
  return ((mult - low) / (high - low)).clamp(0.0, 1.0);
}

MarketTier marketTierFor(double mult) {
  for (var i = marketTiers.length - 1; i >= 0; i--) {
    if (mult >= marketTiers[i].mult) return marketTiers[i];
  }
  return marketTiers.first;
}

/// Mirrors JS `Math.random()`, so this is `dart:math` rather than the seeded
/// generator — the sell roll is not part of the deterministic gameplay stream.
math.Random _sellRng = math.Random();

void setSellRandom(math.Random rng) => _sellRng = rng;

void resetSellRandom() => _sellRng = math.Random();

/// Roll a market multiplier for [card].
///
/// In-form and sponsored players attract better bids: `luck` shifts the roll
/// toward the low-`r` branches, which are the valuable ones. Capped so it
/// improves the odds without ever guaranteeing a jackpot.
double rollMarketMult(CardInstance? card) {
  final form = (card?.raw['form'] as num?)?.toDouble() ?? 0;
  final sponsored = card?.raw['sponsor'] != null;
  final luck = math.min(0.35, math.max(0.0, form * 0.04 + (sponsored ? 0.12 : 0)));
  final r = math.max(0.0, _sellRng.nextDouble() - luck);
  if (r < 0.10) return marketTiers[4].mult + _sellRng.nextDouble() * 0.5;
  if (r < 0.30) return marketTiers[3].mult + _sellRng.nextDouble() * 0.4;
  if (r < 0.60) return marketTiers[2].mult + _sellRng.nextDouble() * 0.3;
  if (r < 0.85) return marketTiers[1].mult + _sellRng.nextDouble() * 0.3;
  return marketTiers[0].mult + _sellRng.nextDouble() * 0.3;
}
