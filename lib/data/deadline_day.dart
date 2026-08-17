/// Transfer Deadline Day tuning. Ported from
/// `../merge-empire-fc/src/data/deadlineDay.js`.
///
/// Deadline Day is the one part of the game that runs on a REAL clock. The window
/// opens at 6pm local and stays open an hour, and THE SESSION IS THE WINDOW —
/// open it at 6:45 and you get fifteen minutes, because the window shuts at 7
/// either way.
///
/// Listings drop on a fixed cadence, each carries its own fuse, and anything you
/// do not answer is gone. The pressure is the product — a leisurely deadline day
/// is just the shop.
///
/// Wall-clock, deliberately: the session ticks off elapsed time, so backgrounding
/// the app does NOT pause the window. Come back three minutes late and you missed
/// three minutes of business. That is the mechanic, not a bug.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

/// Fallback session length.
///
/// Normally the session ends when the WINDOW ends, so this is only used when a
/// caller supplies no window end — tests, and the dev-forced case outside the
/// real calendar. Kept equal to the window so the two cannot drift.
const int sessionMs = 60 * 60 * 1000;

/// Gap between listings dropping into the feed.
///
/// Ninety seconds across a full hour is about forty pieces of business — enough
/// that the window always has something coming, few enough that it is not a
/// firehose you could not read on a phone.
const int listingIntervalMs = 90 * 1000;

/// How long a listing stays answerable.
///
/// Five minutes against a ninety-second cadence keeps three or four live at once
/// — enough that the window is a set of choices rather than a queue, and long
/// enough that a deal survives being read properly: these carry a squad to
/// inspect and a price to negotiate, which is not a snap judgement. A fuse short
/// enough to demand unbroken attention would be fine for six minutes and cruel
/// for sixty. [maxLiveListings] still caps what is on screen, so a longer fuse
/// widens the choice without turning the feed into a wall.
const int listingTtlMs = 5 * 60 * 1000;

/// Hard cap on listings per session — the session length over the cadence.
const int maxSpawns = 40;

/// Never show more than this many live listings at once.
const int maxLiveListings = 4;

/// Listing mix. Bids are rivals coming for your players, loans are short-term
/// rentals, and whatever is left is a straight signing. Selling is the tax that
/// funds the buying, so bids lead; loans are the cheap way in for a player who
/// cannot afford the fantasy yet.
const double bidShare = 0.40;
const double loanShare = 0.22;

/// Rivals asking to take one of OUR players on loan. A small slice — it is the
/// quietest of the four kinds and should not crowd out the business you came for.
const double loanOutShare = 0.12;

/// Deadline-day bids pay over the odds against the 2x a routine rival offer pays.
/// Panic buying is the whole flavour, and it has to be worth breaking up a squad
/// you have spent seasons merging.
const double bidPremium = 2.6;

/// What you pay to sign someone. Higher than what rivals pay you, so churning
/// players through deadline day is a losing trade — the value is getting the exact
/// card you want instead of a scout roll, not arbitrage.
const double signingPremium = 3.2;

/// Marquee signings are one tier ABOVE the division's normal player ceiling — the
/// only route to a card your league cannot otherwise produce. Priced to hurt, and
/// capped at one per session, because a cheap way to skip a tier would flatten the
/// whole merge ladder.
const double marqueePremium = 6.0;
const int maxMarquee = 1;

/// Earliest listing index a marquee can appear at — never the opening listing.
const int marqueeMinIndex = 3;

/// How many listings a marquee stays possible for.
///
/// Without a ceiling the roll would land it near-certainly but often in the last
/// few minutes, which is the one time a player might not still be watching.
const int marqueeMaxIndex = 24;

/// Per-listing chance of rolling marquee, before the cap.
///
/// Across the twenty-odd eligible slots this makes one marquee near-certain,
/// which is intended: the window comes round on a handful of nights a year, and
/// opening your shot to find no marquee on the board would be a bad evening. The
/// COST is what gates it, not the roll — the roll only decides when it shows up.
const double marqueeChance = 0.10;

/// Rivals do not bid for rookies. Matches the routine transfer floor.
const int bidMinTier = 2;

/// Bids never strip the squad below this many healthy players — the same floor the
/// routine transfer system uses, so a deadline-day frenzy cannot leave you unable
/// to field a side.
const int minHealthyKeep = 3;

/// Event score per completed deal, by kind. Drives the challenge track.
const int scorePerSale = 1;
const int scorePerLoan = 2;
const int scorePerSigning = 2;
const int scorePerMarquee = 5;

/// How many finished sessions to keep for the recap.
const int historyLimit = 6;

/// Rolling headlines for the ticker.
///
/// `{team}` and `{player}` are substituted at render time; entries with no
/// placeholder are pure atmosphere.
const List<String> tickerLines = [
  '{team} are back in for {player} — talks going to the wire',
  'BREAKING: {team} table a fresh bid',
  '{player} spotted arriving for a medical',
  'Agents circling — {team} want business done',
  'Boardroom lights still on at {team}',
  'Clock ticking down on this window — business to be done',
  '{team} have a bid rejected. They will return',
  'Scenes outside the stadium as fans await news',
];
