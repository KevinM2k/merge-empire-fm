/// Rival transfer offer tuning, ported from
/// `../merge-empire-fc/src/data/transferMarket.js`.
///
/// Offers arrive at random — any rival in the league can bid, not just the team
/// just faced. The targets combine to roughly two offers per 14-match season
/// across the post-match and idle triggers.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

/// Post-match: a small chance per match. Across 14 matches this alone is about
/// one offer a season.
const double transferMatchTriggerChance = 0.07;

/// Idle: rolled by the main tick. The check itself is gated by
/// [transferIdleMinIntervalMs] so offers cannot spam.
const double transferIdleTriggerChance = 0.30;

/// Earliest another idle offer-roll is allowed after any offer activity. At
/// ~0.30 per check this averages one offer per ~50 minutes of active play.
const int transferIdleMinIntervalMs = 15 * 60 * 1000;

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
