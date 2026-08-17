/// Negotiation tuning — counter-offers, swap deals and the transfer list.
/// Ported from `../merge-empire-fc/src/data/negotiation.js`.
///
/// Both sides of a deal are described by the same shape, an "offer":
///
///     { cash: <coins>, players: [<instanceId>, ...] }
///
/// and both are judged the same way: total value is cash plus the fair value of
/// every player in it. That symmetry is the point — a rival evaluating our
/// player-plus-cash bid uses exactly the maths we use to evaluate theirs, so a
/// deal that looks fair to the player IS fair, and there is no hidden thumb on
/// the scale in either direction.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

/// How far above their opening bid a rival will go when we ask for more.
///
/// 1.35 means a 100k bid can be pushed to about 135k — enough that haggling is
/// worth doing every time, not so much that accepting the opening number is
/// always a mistake.
const double counterMaxMult = 1.35;

/// How far each individual offer's ceiling strays from [counterMaxMult].
///
/// A single fixed ceiling made haggling a solved problem: 1.35x was accepted on
/// every bid in the game, so once you knew the number you pushed to it every time
/// and never lost. Each offer now rolls its own limit, and the club never tells
/// you which — so asking for more is a read on this buyer, not a lever with a
/// known safe setting.
const double ceilingJitter = 0.18;

/// How far below the asking price a seller will accept.
///
/// Tighter than the buy-side tolerance because the seller holds the card and we
/// are the ones who want it.
const double offerMinMult = 0.88;

/// Each seller's own patience, rolled when the listing is built and never shown.
///
/// A single [offerMinMult] meant 88% of the asking price was accepted on every
/// listing in the game — learn the number once and buying is a solved button.
/// Now a seller will go anywhere from the full asking price down to 20% off, and
/// you have to read them. Measured against the ORIGINAL asking price, never a
/// figure already talked down, so no run of small discounts can compound.
const double offerMinFloor = 0.80; // most generous: 20% off
const double offerMinCeil = 1.00; // stubbornest: not a penny under

/// A rival who will not meet our ask comes back once at this share of the gap
/// between their bid and their ceiling. Deals should feel like a conversation,
/// not a single yes or no.
const double rebuttalSplit = 0.5;

/// How many times a club will come back at us before it gives up.
///
/// Derived from the listing id, never shown, and different for every club: none
/// at all is take-it-or-leave-it, one is a single return, two or three is a
/// proper haggle. Their counter STAYS ON THE TABLE for the rest of the listing's
/// fuse — closing the sheet is thinking it over, not refusing.
const int haggleRoundsMax = 3;

/// Push past this multiple of their opening bid and the club WITHDRAWS — the
/// offer is off the table for good, not merely refused.
///
/// This is what gives haggling a real downside. With only "accept" and "meet you
/// partway" there was no reason not to slam the slider to maximum every time:
/// the worst case was the original price. Now greed can cost you the sale. Sits
/// well above [counterMaxMult] so a sensible push is safe and only a genuinely
/// absurd demand ends it.
const double walkAwayMult = 1.9;

/// Below this share of the asking price a seller stops negotiating and simply
/// says no. Between it and [offerMinMult] they come back with a number of their
/// own instead — the buy side gets the same conversation the sell side has.
const double counterFloorMult = 0.62;

/// Where a seller's counter lands between what we offered and what they asked.
/// Above half, so they keep the upper hand — they hold the player.
const double sellerCounterSplit = 0.62;

/// Chance an incoming bid includes a player as part of the payment.
const double incomingPlayerChance = 0.34;

/// Chance a bid that includes a player includes a SECOND one.
const double incomingSecondChance = 0.18;

/// Tier spread for players a rival offers us as part of a deal, relative to the
/// tier of the player they are chasing: they part with squad filler, not equals.
const List<int> incomingTierOffset = [-2, -1, -1, 0];

/// Players we put on the transfer list attract this premium — a listed player is
/// advertised, so more clubs come in and they bid harder. This is the reward for
/// accepting that a listed player cannot be picked.
const double listedBidPremium = 1.25;

/// How much more likely a listed player is to be the target of a bid, as extra
/// selection weight per tier on top of the normal quality curve.
///
/// Calibrated, not guessed: with ten equal squad players and one of them listed,
/// a weight of 6 drew the listed player about 22% of the time — only 2.2x the 10%
/// he would get by chance, which is a thin return for a player you can no longer
/// pick. At 14 it is about a third, so listing visibly works while still leaving
/// room for a rival to want somebody else.
const int listedBidWeight = 14;

/// Cash a rival will add on top of players in a mixed offer, as a share of the
/// shortfall. Below 1.0 so a player-inclusive offer is usually a slight discount
/// for them — which is what makes "cash only" the cleaner deal for us and gives
/// the two options genuinely different characters.
const double mixedCashCover = 0.92;
