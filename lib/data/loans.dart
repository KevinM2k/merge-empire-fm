/// Loan tuning, ported from `../merge-empire-fc/src/data/loans.js`.
///
/// A loan is the one way to hold a player BETTER than your division can produce
/// without paying to own them: the loanee is drawn a tier above the league's
/// normal player ceiling, costs a modest fee up front, then charges a wage out
/// of every match payout until it runs out.
///
/// The unit is MATCHES, not seasons. A season-length loan would make a deal
/// signed late in a campaign near-worthless, and "10 games" is a promise the
/// player can count down. It also means the cost is felt on the same cadence as
/// the benefit.
///
/// Loans are priced against MATCH INCOME, not card value, and that distinction
/// is why the numbers work. Every other transfer price in the game is a multiple
/// of a card's value — savings-scale numbers you bank many matches' winnings to
/// afford. A wage on that scale would exceed a match payout by 10-40x at every
/// division above Sunday League, so the first settlement would recall the player
/// and the mechanic would never function.
///
/// A wage is income-scale, coming out of the payout that just landed:
///
///     win .............. 1.00 x matchRevenueBase
///     draw ............. 0.40 x
///     loss ............. 0.10 x
///     loan wage ........ 0.45 x   <- charged every match, win or lose
///
/// So a loan is comfortably covered by wins, roughly breaks even on draws, and
/// actively bleeds you on losses. A loanee you can't win with is a loanee you
/// can't afford, which is the pressure the mechanic exists for.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

/// Matches a loan lasts. Every match played burns one, XI or not.
const int loanMatches = 10;

/// Up-front fee, as a multiple of the division's per-win match revenue.
const double loanFeeRate = 5.0;

/// Per-match wage, as a multiple of the division's per-win match revenue.
const double loanWageRate = 0.45;

/// How many loans can run at once. Two is enough to patch a defence and an
/// attack; more and the wage bill stops being a decision and starts being a
/// spreadsheet.
const int maxActiveLoans = 2;

/// Tiers above the division's normal player ceiling a loanee is drawn from.
/// This is the appeal — a loan is the only way to field a card your league
/// cannot otherwise produce.
///
/// Capped at T8 in the engine: T9 is scout-only and uncraftable, and a borrowed
/// one would be a back door to it. The consequence is that at Champions League
/// a loan is no longer a tier jump but an instant T8 skipping the merge grind —
/// weaker, but still real.
const int loanTierLift = 1;

/// When a match payout cannot cover the wage, the parent club pulls the player
/// immediately. A missed wage is not a debt carried forward — it ends the loan,
/// which keeps the drain self-limiting and gives the mechanic teeth without ever
/// pushing the player's balance negative.
const bool recallOnUnpaid = true;

// ── Loaning players OUT ─────────────────────────────────────────────────────
//
// The other direction: a rival takes one of OUR players and pays a fee for the
// spell. It is the natural home for squad depth you aren't picking — a bench
// player earns nothing sitting on the grid and something while he is away.
//
// The cost is availability: a player out on loan cannot be selected, so loaning
// out a third-choice striker is free money and loaning out a starter is a bet
// that you can cover the gap.
//
// Priced below what we PAY to borrow — the borrowing club sets the terms, and a
// loan-out paying better than a loan-in costs would make renting squads back and
// forth a money printer.
//
// The fee is paid UP FRONT as a lump, so unlike a loan-in wage it is NOT
// income-scale — it is priced off the card's fair value, the same anchor the
// sell and deadline-day paths use. Income-scale pricing made the fee near-flat:
// at Elite a Bronze Rookie fetched 6.6k and a World Legend 16k, two cards whose
// market values differ by ~16,000x. The old rate survives as a floor so
// early-game numbers never look trivial.

/// Share of a card's fair market value the whole spell pays.
const double loanOutValueShare = 0.25;

/// Floor only: per-match fee as a multiple of the division's per-win revenue.
const double loanOutFeeRate = 0.30;

/// Matches a loan-out runs for. Same unit as loans in — games, not seasons.
const int loanOutMatches = 10;

/// Fee scaling by how good the player is relative to the division's own ceiling.
/// A player above the league's level earns a premium; squad filler earns less.
/// Clamped so neither end runs away.
const double loanOutTierMin = 0.55;
const double loanOutTierMax = 1.70;

/// Most players we can have out on loan at once.
const int maxLoansOut = 3;
