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
