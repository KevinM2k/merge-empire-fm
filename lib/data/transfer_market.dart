/// Rival transfer offer tuning, ported from
/// `../merge-empire-fc/src/data/transferMarket.js`.
///
/// Offers arrive at random — any rival in the league can bid, not just the team
/// just faced.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/players.dart';

/// **AFTER A MATCH, and nowhere else.** There used to be an idle roll on the
/// main tick as well, behind a fifteen-minute gate, so a player who left the
/// game sitting on the Play screen collected a bid roughly every fifty minutes
/// for as long as they left it there — and a season could carry any number of
/// them depending on how long the app had been open. Reported directly.
///
/// A bid is a thing a rival does because of something they saw, so a FIXTURE is
/// the right clock for it and idle time is not. This is the whole budget now:
/// across a 14-match season it lands about two, which is what the file has
/// always said it was aiming at — it just used to spend half of it on the
/// wrong trigger.
const double transferMatchTriggerChance = 0.14;

/// A sponsored player still nudges the per-match trigger chance up.
const double transferSponsorTriggerBonus = 0.06;

/// Tier to multiplier on sellValue. Tuned so a rival's bid for a high-tier
/// player is tempting enough to actually consider — roughly the cost of
/// scouting three or four replacements at that division.
const Map<int, int> transferTierMultiplier = {
  1: 4,
  2: 6,
  3: 10,
  4: 16,
  5: 24,
  6: 36,
  7: 52,
  8: 80,
};

/// **WHAT A CARD IS WORTH ON THE MARKET, before any division or premium.**
///
/// `sellValue * tierMultiplier` of the tier the card is WEARING — so a World
/// Legend who has declined to Gold Elite fetches Gold Elite money — TAPERED
/// across the rung he is standing on, so the figure slides rather than falling
/// off a cliff the day his border changes colour.
///
/// Without the taper this is a step function, and the step is a fourfold drop:
/// 3.83M the season he turns 34 and 932k the season he turns 35. The tier is
/// still what sets the two ends; `tierFall.progress` is how far between them he
/// has actually got. It is continuous across a demotion — a card a hair short
/// of dropping is a hair short of the tier below's value, and one that has just
/// dropped is exactly at it — so there is no discontinuity left anywhere on the
/// curve.
///
/// **AND IT NEVER RISES.** The multiplier table has no entry for T9, which
/// falls back to a four and leaves the unique Football Icon nominally cheaper
/// than a World Legend — so a declining Icon would have gained value on the way
/// down. Clamped to what the card's own tier is worth rather than papered over
/// by inventing a ninth multiplier, which would be an economy change nobody
/// asked for.
double marketValueBasis(PlayerDef def, int age) {
  double basisAt(int tier) =>
      tierSellValue(tier) * (transferTierMultiplier[tier] ?? 4).toDouble();

  final own = basisAt(def.tier);
  final fall = tierFall(def, age);
  final here = basisAt(fall.tier);
  if (fall.progress <= 0 || fall.tier <= 1) return math.min(own, here);
  final below = basisAt(fall.tier - 1);
  return math.min(own, here + (below - here) * fall.progress);
}

/// Sponsored players are more attractive to rivals: +50% of the base offer.
const double transferSponsorBonus = 0.5;

/// A small grit bonus a jilted rival carries into their very next match against
/// us. Deliberately modest — they have not actually got better, they are just
/// fired up — and it lasts one match.
const int grudgeRatingBoost = 2;

/// Grudge matches are more physical, so our players are likelier to pick up an
/// injury. Multiplied against the per-player injury probability.
const double grudgeInjuryMultiplier = 2.0;

/// How many matches a grudge lasts after a decline.
const int grudgeMatchDuration = 1;

/// Minimum player tier that generates offers — bronze rookies are not targeted.
const int transferMinTier = 2;

/// Floor so early-game offers never look trivial.
const int transferMinOffer = 120;
