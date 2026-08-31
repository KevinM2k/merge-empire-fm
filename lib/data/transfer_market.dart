/// Rival transfer offer tuning, ported from
/// `../merge-empire-fc/src/data/transferMarket.js`.
///
/// Offers arrive at random — any rival in the league can bid, not just the team
/// just faced.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

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
