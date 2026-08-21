/// Transfer Deadline Day — a live, wall-clock trading session. Ported from
/// `../merge-empire-fc/src/engine/deadlineDayEngine.js`.
///
/// The rest of the game's transfer system is passive: the transfer engine rolls
/// the dice and interrupts you with one offer at a time. Deadline Day inverts it —
/// you open a window, listings pour in on a fixed cadence, each with its own
/// fuse, and you triage under a clock you cannot pause.
///
/// Everything derives from elapsed WALL TIME rather than from tick counts, so the
/// session behaves identically whether the UI is ticking at 60fps, the app was
/// backgrounded for two minutes, or a test jumps the clock forward by half the
/// window. [tickSession] is idempotent for a given instant: call it as often as
/// you like, it only ever catches the session up to that moment.
///
/// THE SCHEDULE IS ANCHORED TO THE WINDOW, NOT TO YOU. Listings are timetabled
/// from the moment the window opens, so business happens whether or not anyone is
/// watching. Join thirty minutes late and thirty minutes of offers have already
/// come and gone — you see what is still live and a count of what you missed.
/// Anchoring to the player's arrival instead would have made the world wait for
/// them, which is the opposite of a deadline.
///
/// WHERE THIS IS GOING: today the window is a one-hour nightly event; the
/// intention is for it to become permanent, and for the listings to be other
/// players' real transfers and loans rather than generated ones. The seam for
/// that is [_buildListing] and the four builders under it — they are the only
/// places a listing is invented, so a server feed would replace them and leave
/// the session, the fuses, the negotiation and the UI untouched.
///
/// EVERYTHING HERE IS SAVE STATE. A session and its listings live under
/// `state.deadlineDay`, so every listing is a plain map and nothing on one may be
/// a Dart record.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:merge_empire_fc/data/deadline_day.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/loans.dart';
import 'package:merge_empire_fc/data/negotiation.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/transfer_market.dart';
import 'package:merge_empire_fc/engine/event_engine.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/engine/loan_engine.dart';
import 'package:merge_empire_fc/engine/merge_engine.dart';
import 'package:merge_empire_fc/engine/negotiation_engine.dart';
import 'package:merge_empire_fc/engine/transfer_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/sorting.dart';
import 'package:merge_empire_fc/util/time.dart';

/// The highest tier Deadline Day will ever put on the market.
///
/// T9 is scout-only and uncraftable by design — a marquee signing must not become
/// a back door to it.
const int maxMarketTier = 8;

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;
bool _flag(Object? v) => v == true;

/// JS `Math.round` — halves go up, not to even.
int _jsRound(num v) => (v + 0.5).floor();

/// A listing, a session and a summary are all raw maps: they live in the save.
typedef Listing = Map<String, dynamic>;
typedef Session = Map<String, dynamic>;

/// The answer to "did that work", in the shape every caller here returns.
typedef DealResult = Map<String, dynamic>;

// ── state shape ──────────────────────────────────────────────────────────────

Session _blankSession() => {
  // Which window occurrence this session belongs to.
  'windowStart': 0,
  'startedAt': 0,
  'endsAt': 0,
  'listings': <Listing>[],
  // Listings created so far this session.
  'spawned': 0,
  // Marquee signings offered so far this session.
  'marquees': 0,
  'done': false,
  'summary': null,
};

/// The Deadline Day branch, created on first use.
Map<String, dynamic> ensureDeadlineDay(Map<String, dynamic> state) {
  var dd = _map(state['deadlineDay']);
  if (dd == null) {
    dd = <String, dynamic>{'session': _blankSession(), 'history': <Object?>[]};
    state['deadlineDay'] = dd;
  }
  if (_map(dd['session']) == null) dd['session'] = _blankSession();
  final session = _map(dd['session'])!;
  if (session['listings'] is! List) session['listings'] = <Listing>[];
  if (dd['history'] is! List) dd['history'] = <Object?>[];
  return dd;
}

Session _sessionOf(Map<String, dynamic> state) =>
    _map(ensureDeadlineDay(state)['session'])!;

List<Listing> _listingsOf(Session s) => (s['listings'] as List).cast<Listing>();

// ── pricing ──────────────────────────────────────────────────────────────────

/// Division price scalar.
///
/// The same power curve the transfer and sell engines use, so a deadline-day
/// number sits in the same economy as every other transfer price rather than
/// inventing its own currency scale.
double _divMult(Map<String, dynamic>? state) {
  final div = getDivision('${_map(state?['progression'])?['currentDivision']}');
  return math.pow(div.matchRevenueBase / 100, 0.35).toDouble();
}

/// How much the OFFERING club's league changes the money.
///
/// Rivals are drawn from the whole pyramid, but every price used to come off our
/// own division alone, so a Champions club and a pub team bid the same.
///
/// Deliberately a bounded per-rung step rather than the real revenue ratio: the
/// ladder spans a match income of 100 to 120,000, so pricing on the true ratio
/// would let one top-flight bid pay for the whole of Sunday League. Two rungs up
/// is about a third more money; the clamp stops the extremes either way.
const double _divGapStep = 1.28;
const double _divGapMin = 0.7;
const double _divGapMax = 2.2;

double divGapMult(num? gap) {
  if (gap == null || !gap.isFinite || gap == 0) return 1;
  return math.min(
    _divGapMax,
    math.max(_divGapMin, math.pow(_divGapStep, gap).toDouble()),
  );
}

/// Rungs between the offering club and us. Zero when the club is unknown.
int _gapFor(Map<String, dynamic> state, String? teamName) {
  final theirs = teamDivisionIndex(state, teamName);
  if (theirs == null) return 0;
  final ours = divisions.indexWhere(
    (d) => d.id == _map(state['progression'])?['currentDivision'],
  );
  if (ours < 0) return 0;
  return theirs - ours;
}

/// What a rival pays US for a card. Mirrors the routine transfer offer maths.
num _bidPrice(
  Map<String, dynamic> state,
  PlayerDef def,
  CardInstance? card, [
  int gap = 0,
]) {
  final tierMult = transferTierMultiplier[def.tier] ?? 4;
  var price =
      def.sellValue * tierMult * _divMult(state) * bidPremium * divGapMult(gap);
  if (_num(_map(card?.sponsor)?['multiplier']) != null) price *= 1.5;
  final aging = agingPenalty(card?.seasonsPlayed ?? 0);
  if (aging > 0 && def.rating > 0) {
    price *= math.max(0.2, (def.rating - aging) / def.rating);
  }
  return math.max(1, roundCoins(price));
}

/// FNV-1a. Short, no dependencies, and spreads a string evenly enough for this.
int _hash(String str, [int salt = 0]) {
  var h = (2166136261 ^ salt).toUnsigned(32);
  for (var i = 0; i < str.length; i++) {
    h ^= str.codeUnitAt(i);
    h = (h * 16777619).toUnsigned(32);
  }
  return h;
}

/// This seller's own floor: the least they would take, as a share of what they
/// are asking. Never surfaced.
///
/// DERIVED from the listing id rather than drawn from the RNG. The id already
/// carries a random component, so this is just as unpredictable to a player — and
/// it consumes no draw, which matters because the spawn sequence is seeded and an
/// extra draw here would silently change which listings appear.
double _offerFloorFor(String listingId, [int tier = 4]) {
  final frac = (_hash(listingId) % 10000) / 10000;
  // A good player is a seller's market. The band tightens towards the full asking
  // price as the tier climbs, so 20% off is something you get on squad filler —
  // nobody discounts a superstar because you asked nicely. Tier 1 spans the whole
  // band; tier 8 sits in the top third of it.
  final quality = math.min(
    1.0,
    math.max(0.0, (tier - 1) / (maxMarketTier - 1)),
  );
  final floor = offerMinFloor + (offerMinCeil - offerMinFloor) * 0.6 * quality;
  return floor + frac * (offerMinCeil - floor);
}

/// How many times this club will come back at us before it gives up.
///
/// Derived from the id for the same reason the floor is — no draw, so it cannot
/// move the seeded spawn order. Weighted towards the short end: 30% will not
/// counter AT ALL, which is the whole point of the mechanic. If every club
/// haggled, haggling would just be a tax on clicks rather than a read on who you
/// are dealing with.
int _haggleRoundsFor(String listingId) {
  final r = _hash(listingId, 0x9e37) % 10;
  if (r < 3) return 0; // point blank
  if (r < 7) return 1;
  if (r < 9) return 2;
  return haggleRoundsMax;
}

/// What WE pay to sign a definition. Marquee cards carry the steeper multiplier.
num _signingPrice(
  Map<String, dynamic> state,
  PlayerDef def,
  bool marquee, [
  int gap = 0,
]) {
  final tierMult = transferTierMultiplier[def.tier] ?? 4;
  final premium = marquee ? marqueePremium : signingPremium;
  // A club above us knows what it has and prices accordingly; one below is glad
  // of the sale. Same bounded step the bid side uses.
  return math.max(
    1,
    roundCoins(
      def.sellValue * tierMult * _divMult(state) * premium * divGapMult(gap),
    ),
  );
}

// ── listing construction ─────────────────────────────────────────────────────

Set<Object?> _spokenFor(Session s, String kind) => {
  for (final l in _listingsOf(s))
    if (l['status'] == 'live' && l['kind'] == kind) l['cardInstanceId'],
};

Listing? _buildBid(Session s, Map<String, dynamic> state, int spawnAt) {
  // Never let the frenzy strip the squad below a fieldable core.
  final healthy = _cards(state).where((c) => !c.injured).length;
  if (healthy <= minHealthyKeep) return null;

  final pick = pickBidTarget(
    state,
    exclude: _spokenFor(s, 'bid'),
    minTier: bidMinTier,
  );
  if (pick == null) return null;
  final card = pick.card;
  final def = pick.def;

  // Pick the buyer BEFORE pricing — how much they can pay depends on which league
  // they are in, so the name cannot be an afterthought on the way out. A listed
  // player is advertised, so they draw a better price; that premium is the reward
  // for having made them unpickable.
  final fromTeam = pickOfferingRival(state);
  final gap = _gapFor(state, fromTeam);
  final headline = math.max(
    1,
    roundCoins(_bidPrice(state, def, card, gap) * listedPremium(card)),
  );
  final offer = buildRivalOffer(state, card, headline);
  final opening = math.max(1, roundCoins(offerValue(state, offer)));

  return {
    'listingId': 'dd_bid_${spawnAt}_${seeded.randomInt(0, 9999)}',
    'kind': 'bid',
    'status': 'live',
    'spawnAt': spawnAt,
    'expiresAt': spawnAt + listingTtlMs,
    'fromTeam': fromTeam,
    'fromDivGap': gap,
    // This buyer's own patience, rolled once and never shown. `askAnchor` is
    // frozen at the opening number so talking them up cannot raise the bar they
    // are measured against.
    'askCeilingMult':
        counterMaxMult + (seeded.random() * 2 - 1) * ceilingJitter,
    'askAnchor': opening,
    'cardInstanceId': card.instanceId,
    'definitionId': card.definitionId,
    'playerName': card.name(def.tierName),
    'position': def.position,
    'tier': def.tier,
    'tierName': def.tierName,
    'variant': _num(card.raw['variant']) ?? 0,
    'listedTarget': card.listed,
    'offer': offer,
    // `price` stays the single headline number every other path reads — for a
    // mixed offer it is the whole package's worth, not just the cash.
    'price': opening,
  };
}

/// A rival asking to take one of OUR players on loan.
///
/// Pays a fee every match and gives them back afterwards — the natural home for
/// squad depth you are not picking.
Listing? _buildLoanOut(Session s, Map<String, dynamic> state, int spawnAt) {
  final pick = pickBidTarget(
    state,
    exclude: _spokenFor(s, 'loanOut'),
    minTier: 1,
  );
  if (pick == null) return null;
  final card = pick.card;
  final def = pick.def;
  if (!canLoanOut(state, card).ok) return null;

  return {
    'listingId': 'dd_lout_${spawnAt}_${seeded.randomInt(0, 9999)}',
    'kind': 'loanOut',
    'status': 'live',
    'spawnAt': spawnAt,
    'expiresAt': spawnAt + listingTtlMs,
    'fromTeam': pickOfferingRival(state),
    'cardInstanceId': card.instanceId,
    'definitionId': card.definitionId,
    'playerName': card.name(def.tierName),
    'position': def.position,
    'tier': def.tier,
    'tierName': def.tierName,
    'variant': _num(card.raw['variant']) ?? 0,
    'feePerMatch': loanOutFee(state, card),
    'matches': loanOutMatches,
    'price': 0,
  };
}

/// Which tier a signing is drawn from.
///
/// A normal listing sits at the SELLING club's own ceiling, not ours: a Champions
/// side can dangle a genuinely elite player at a Sunday League manager — and
/// between the tier multiplier and the gap premium it will cost what an elite
/// player costs, so most of the time it is a window to press your nose against
/// rather than a deal. That is the intent, not a bug. A club below us sells from
/// its own lower shelf and is glad of the money.
///
/// Capped at three rungs above our own shelf: far enough that a top club's offer
/// is genuinely out of reach, close enough that it stays a plausible temptation
/// rather than a tier-8 advert every Sunday League manager scrolls past. Two
/// below is as far down as it goes the other way. A marquee sits one ABOVE our
/// ceiling — the only way to hold a card your league cannot otherwise produce.
int _signingTier(Map<String, dynamic> state, bool marquee, [int gap = 0]) {
  final div = getDivision('${_map(state['progression'])?['currentDivision']}');
  final cap = div.maxPlayerTier;
  if (marquee) return math.min(maxMarketTier, cap + 1);

  final theirCap = math.max(
    1,
    math.min(maxMarketTier, cap + math.max(-2, math.min(3, gap))),
  );
  final tier = (seeded.random() < 0.35 ? theirCap - 1 : theirCap).toInt();
  return math.max(1, math.min(maxMarketTier, tier));
}

Listing? _buildSigning(
  Session s,
  Map<String, dynamic> state,
  int spawnAt, {
  bool marquee = false,
}) {
  // Seller first: which league they are in decides both the calibre of player
  // they have to offer and what they will want for him.
  final fromTeam = pickOfferingRival(state);
  final gap = _gapFor(state, fromTeam);
  final tier = _signingTier(state, marquee, gap);
  final pool = getPlayersByTier(tier);
  if (pool.isEmpty) return null;
  final def = seeded.pickRandom(pool);
  final card = rollDealCard(def);
  if (card == null) return null;
  final askingPrice = _signingPrice(state, def, marquee, gap);
  final listingId = 'dd_sign_${spawnAt}_${seeded.randomInt(0, 9999)}';

  return {
    'listingId': listingId,
    'kind': 'signing',
    'status': 'live',
    'spawnAt': spawnAt,
    'expiresAt': spawnAt + listingTtlMs,
    'fromTeam': fromTeam,
    'fromDivGap': gap,
    'definitionId': def.id,
    // The ACTUAL card on offer, rolled up front. Signings used to be a
    // definition id plus a name, so the feed had no artwork to show and no real
    // ATK/DEF for a detail sheet — you were buying a rarity label.
    'card': card.raw,
    'playerName': card.raw['displayName'],
    'position': def.position,
    'tier': def.tier,
    'tierName': def.tierName,
    'marquee': marquee,
    'price': askingPrice,
    // What they would settle for, and the figure it is measured against. Both
    // frozen here so nothing downstream can move the goalposts mid-haggle.
    'offerMinMult': _offerFloorFor(listingId, def.tier),
    'offerAnchor': askingPrice,
    'haggleRounds': _haggleRoundsFor(listingId),
  };
}

/// A short-term rental, a tier above the division's ceiling — so the pitch is
/// "better than you can buy, for ten games".
///
/// Priced as a fee now plus a wage every match. The wage is on the card because
/// it, not the fee, is what the player actually feels.
Listing? _buildLoan(Session s, Map<String, dynamic> state, int spawnAt) {
  // No point offering one that cannot be taken — the squad is full or both loan
  // slots are already running.
  if (!canLoan(state).ok) return null;
  final def = pickLoanee(state);
  if (def == null) return null;
  final card = rollDealCard(def);
  if (card == null) return null;

  final listingId = 'dd_loan_${spawnAt}_${seeded.randomInt(0, 9999)}';
  final fee = loanFee(state);

  return {
    'listingId': listingId,
    'kind': 'loan',
    'status': 'live',
    'spawnAt': spawnAt,
    'expiresAt': spawnAt + listingTtlMs,
    'fromTeam': pickOfferingRival(state),
    'definitionId': def.id,
    'card': card.raw,
    'playerName': card.raw['displayName'],
    'position': def.position,
    'tier': def.tier,
    'tierName': def.tierName,
    'price': fee,
    'wage': loanWage(state),
    'matches': loanMatches,
    'offerMinMult': _offerFloorFor(listingId, def.tier),
    'offerAnchor': fee,
    'haggleRounds': _haggleRoundsFor(listingId),
  };
}

/// Builds listing number [index] for this session.
///
/// Falls back across kinds rather than returning null — a silent gap in the feed
/// reads as the event being broken, so if one kind cannot be built we try the
/// others.
Listing? _buildListing(
  Session s,
  Map<String, dynamic> state,
  int index,
  int spawnAt,
) {
  final wantMarquee = index >= marqueeMinIndex &&
      index <= marqueeMaxIndex &&
      (_num(s['marquees']) ?? 0) < maxMarquee &&
      seeded.random() < marqueeChance;

  if (wantMarquee) {
    final marquee = _buildSigning(s, state, spawnAt, marquee: true);
    if (marquee != null) {
      s['marquees'] = (_num(s['marquees']) ?? 0) + 1;
      return marquee;
    }
  }

  final roll = seeded.random();
  // A small slice of the window is rivals asking to BORROW one of ours.
  if (roll < loanOutShare) {
    final out = _buildLoanOut(s, state, spawnAt);
    if (out != null) return out;
  }
  if (roll < bidShare) {
    return _buildBid(s, state, spawnAt) ??
        _buildLoan(s, state, spawnAt) ??
        _buildSigning(s, state, spawnAt);
  }
  if (roll < bidShare + loanShare) {
    return _buildLoan(s, state, spawnAt) ??
        _buildSigning(s, state, spawnAt) ??
        _buildBid(s, state, spawnAt);
  }
  return _buildSigning(s, state, spawnAt) ?? _buildBid(s, state, spawnAt);
}

// ── session lifecycle ────────────────────────────────────────────────────────

/// Has this player already used their session for this window occurrence?
///
/// One session per window — the whole point is that you get one shot at it, so
/// re-entering to farm a better feed is not on the table.
bool hasUsedSession(Map<String, dynamic> state, num windowStart) {
  final dd = ensureDeadlineDay(state);
  final s = _map(dd['session'])!;
  if (s['windowStart'] == windowStart && (_num(s['startedAt']) ?? 0) > 0) {
    return true;
  }
  final history = dd['history'];
  if (history is! List) return false;
  return history.any((h) => _map(h)?['windowStart'] == windowStart);
}

/// `idle` (never opened), `live` (clock running) or `done` (used up).
String sessionStatus(
  Map<String, dynamic> state,
  num windowStart, [
  int? nowMs,
]) {
  final at = nowMs ?? now();
  final s = _sessionOf(state);
  if (s['windowStart'] != windowStart || (_num(s['startedAt']) ?? 0) == 0) {
    return hasUsedSession(state, windowStart) ? 'done' : 'idle';
  }
  if (_flag(s['done'])) return 'done';
  return at < (_num(s['endsAt']) ?? 0) ? 'live' : 'done';
}

int sessionRemainingMs(Map<String, dynamic> state, [int? nowMs]) {
  final at = nowMs ?? now();
  final s = _sessionOf(state);
  if ((_num(s['startedAt']) ?? 0) == 0 || _flag(s['done'])) return 0;
  return math.max(0, (_num(s['endsAt']) ?? 0) - at).toInt();
}

/// Opens the window.
///
/// THE SESSION IS THE WINDOW. [windowEnd] is when the event itself shuts, so
/// opening at 6:45 gives you fifteen minutes, not a fresh full-length session — a
/// countdown that outlived the event it belongs to would be a lie, and it would
/// let a late opener trade past closing time. [sessionMs] is only the fallback for
/// callers with no window to hand.
({bool ok, String? reason, num? endsAt}) startSession(
  Map<String, dynamic> state,
  num windowStart, {
  int? nowMs,
  num? windowEnd,
}) {
  final at = nowMs ?? now();
  final dd = ensureDeadlineDay(state);
  if (hasUsedSession(state, windowStart)) {
    return (ok: false, reason: 'already_used', endsAt: null);
  }

  final endsAt = windowEnd ?? (at + sessionMs);
  if (endsAt <= at) return (ok: false, reason: 'window_closed', endsAt: null);

  dd['session'] = _blankSession()
    ..addAll({
      'windowStart': windowStart,
      // Anchored to when the WINDOW opened, not to now. This is what makes the
      // schedule the world's rather than the player's: the catch-up below then
      // plays out every listing that was due while they were elsewhere, most of
      // which will already have expired.
      'startedAt': windowStart,
      'endsAt': endsAt,
    });

  // Catch up to the present. On a punctual arrival that is one listing; joining
  // half an hour late it is twenty, nearly all of them already gone.
  tickSession(state, at);

  final session = _sessionOf(state);
  emit('deadline:session-started', {
    'windowStart': windowStart,
    'endsAt': session['endsAt'],
  });
  return (ok: true, reason: null, endsAt: _num(session['endsAt']));
}

/// Catches the session up: spawn every listing whose slot has come due, expire
/// every live listing past its fuse, and close the session when the clock runs
/// out. Safe to call at any frequency.
Session tickSession(Map<String, dynamic> state, [int? nowMs]) {
  final at = nowMs ?? now();
  final s = _sessionOf(state);
  final startedAt = _num(s['startedAt']) ?? 0;
  if (startedAt == 0 || _flag(s['done'])) return s;

  final endsAt = _num(s['endsAt']) ?? 0;
  // Spawn any listing whose scheduled moment has passed. Backgrounding the app
  // does not skip listings — they arrive, and then expire, exactly on schedule,
  // so a player who walks away comes back to a feed of missed business.
  while ((_num(s['spawned']) ?? 0) < maxSpawns) {
    final spawned = (_num(s['spawned']) ?? 0).toInt();
    final spawnAt = (startedAt + spawned * listingIntervalMs).toInt();
    if (spawnAt > at) break;
    if (spawnAt >= endsAt) break;

    s['spawned'] = spawned + 1;
    final listing = _buildListing(s, state, spawned, spawnAt);
    if (listing != null) _listingsOf(s).add(listing);
  }

  // Expire anything past its fuse, plus any bid whose player has since left the
  // grid by another route — merged, or sold on the Squad screen.
  for (final l in _listingsOf(s)) {
    if (l['status'] != 'live') continue;
    final gone = l['kind'] == 'bid' &&
        !_cards(state).any((c) => c.instanceId == l['cardInstanceId']);
    if (gone) {
      l['status'] = 'void';
      continue;
    }
    if (listingExpired(l, at)) {
      l['status'] = 'expired';
      emit('deadline:listing-expired', {
        'listingId': l['listingId'],
        'kind': l['kind'],
      });
    }
  }

  if (at >= endsAt) endSession(state, at);
  return s;
}

/// A conversation you are still in the middle of: the sheet is open, or they have
/// come back with a number the engine promises will stay on the table for the rest
/// of the fuse.
///
/// A plain REJECTION is deliberately not engaged. That conversation is finished
/// even when rounds remain, and pinning every listing you ever spoke to would fill
/// all four slots with dead ends and starve the feed of new business.
bool _engaged(Listing? l) => isPaused(l) || l?['sellerCounter'] != null;

/// Live listings. Engaged ones first, then newest, capped at [maxLiveListings].
///
/// The cap is a display decision: on a busy feed the oldest items are the ones
/// closest to expiring anyway, and a phone screen cannot hold more than about four
/// cards. A listing you are negotiating jumps the queue regardless of age — having
/// a deal you are mid-conversation on pushed off the screen by a newer one would
/// be worse than any amount of clutter.
///
/// Priority used to be the pause alone, which held only WHILE the sheet was open.
/// Closing it resumed the fuse and dropped the listing back into a newest-first
/// sort it could no longer win — so the reward for negotiating was watching the
/// deal vanish from the feed with no explanation.
List<Listing> liveListings(Map<String, dynamic> state, [int? nowMs]) {
  final at = nowMs ?? now();
  final s = _sessionOf(state);
  final live = [
    for (final l in _listingsOf(s))
      if (l['status'] == 'live' && !listingExpired(l, at)) l,
  ];
  final sorted = stableSorted(live, (a, b) {
    final byEngaged = (_engaged(b) ? 1 : 0) - (_engaged(a) ? 1 : 0);
    if (byEngaged != 0) return byEngaged;
    return ((_num(b['spawnAt']) ?? 0) - (_num(a['spawnAt']) ?? 0)).sign.toInt();
  });
  return sorted.take(maxLiveListings).toList();
}

/// ── The clock stops while you are talking ────────────────────────────────────
///
/// Making an offer pauses the listing's fuse. A rival who has just asked you for
/// another 20k does not then sell the player to someone else while you are
/// deciding — that is not pressure, it is a punishment for engaging, and it would
/// teach players to only ever take the sticker price.
///
/// The pause is the NEGOTIATION, not the reading: tapping a card for details
/// leaves the clock running. It lifts the moment you stop offering, and the fuse
/// picks up exactly where it left off rather than restarting, so a long haggle
/// cannot be used to farm time.
///
/// The WINDOW does not pause. [endSession] still closes everything out when the
/// hour is up, mid-negotiation or not.
bool isPaused(Listing? l) => l?['pausedAt'] != null;

/// True once the fuse has burned through. Always false while paused.
bool listingExpired(Listing? l, [int? nowMs]) =>
    !isPaused(l) && (nowMs ?? now()) >= (_num(l?['expiresAt']) ?? 0);

/// Fuse left, frozen at whatever it read when the talking began.
int listingRemainingMs(Listing? l, [int? nowMs]) => math.max(
  0,
  (_num(l?['expiresAt']) ?? 0) -
      (isPaused(l) ? _num(l!['pausedAt'])! : (nowMs ?? now())),
).toInt();

/// Stops the clock. Idempotent — a second offer does not re-bank the time.
bool pauseListing(Map<String, dynamic> state, String listingId, [int? nowMs]) {
  final l = _find(state, listingId);
  if (l == null || l['status'] != 'live' || isPaused(l)) return false;
  l['pausedAt'] = nowMs ?? now();
  return true;
}

/// Starts it again, giving back exactly the time the conversation took.
bool resumeListing(Map<String, dynamic> state, String listingId, [int? nowMs]) {
  final at = nowMs ?? now();
  final s = _sessionOf(state);
  final l = _find(state, listingId);
  if (l == null || !isPaused(l)) return false;
  l['expiresAt'] =
      (_num(l['expiresAt']) ?? 0) + math.max(0, at - _num(l['pausedAt'])!);
  l['pausedAt'] = null;
  // The window is still the window. A negotiation that ran past closing time
  // gives back time that no longer exists, so clamp to the end of the session.
  final endsAt = _num(s['endsAt']) ?? 0;
  if ((_num(l['expiresAt']) ?? 0) > endsAt) l['expiresAt'] = endsAt;
  return true;
}

/// Which side of the desk a listing sits on.
///
/// The question a manager is actually asking is "am I losing a player or gaining
/// one", not "is this a transfer or a loan" — so a rival bidding for our man and a
/// rival asking to borrow him are the same side, and signing someone is the same
/// side as taking someone on loan. Money does not decide it: a loan IN costs us
/// and still counts as buying.
String listingSide(Listing? l) =>
    (l?['kind'] == 'bid' || l?['kind'] == 'loanOut') ? 'sell' : 'buy';

/// Live listings on one side. Same order and cap as [liveListings].
List<Listing> liveListingsBySide(
  Map<String, dynamic> state,
  String side, [
  int? nowMs,
]) => [
  for (final l in liveListings(state, nowMs))
    if (listingSide(l) == side) l,
];

Listing? _find(Map<String, dynamic> state, String listingId) {
  for (final l in _listingsOf(_sessionOf(state))) {
    if (l['listingId'] == listingId) return l;
  }
  return null;
}

({Listing? l, String? err}) _findLive(
  Map<String, dynamic> state,
  String listingId,
) {
  final l = _find(state, listingId);
  if (l == null) return (l: null, err: 'unknown_listing');
  if (l['status'] != 'live') return (l: l, err: 'not_live');
  return (l: l, err: null);
}

/// Why a listing cannot be taken right now, or null if it can.
///
/// One entry point, so the feed can grey a button and say why without branching on
/// kind itself.
String? listingBlockedReason(Map<String, dynamic> state, Listing? listing) {
  if (listing == null) return 'unknown_listing';
  if (listing['kind'] == 'bid') return null; // selling is never blocked

  // Lending one of ours OUT has its own gate. This used to fall through to the
  // signing gate, which rejects anything that is not a signing — so every loanOut
  // card carried a permanent `not_signing`, a reason with no string behind it.
  // The gate is not cosmetic: the player can have been injured, sold or loaned
  // elsewhere in the minutes since the offer landed.
  if (listing['kind'] == 'loanOut') {
    CardInstance? card;
    for (final c in _cards(state)) {
      if (c.instanceId == listing['cardInstanceId']) card = c;
    }
    final out = canLoanOut(state, card);
    return out.ok ? null : out.reason;
  }

  final gate = listing['kind'] == 'loan'
      ? canLoan(state)
      : canSign(state, listing);
  if (gate.ok &&
      listing['kind'] == 'loan' &&
      (_num(_map(state['resources'])?['fanCoins']) ?? 0) <
          (_num(listing['price']) ?? 0)) {
    return 'not_enough_coins';
  }
  return gate.ok ? null : gate.reason;
}

/// Can this signing be taken right now? Split out so the UI can grey the button.
({bool ok, String? reason}) canSign(
  Map<String, dynamic> state,
  Listing? listing,
) {
  if (listing == null || listing['kind'] != 'signing') {
    return (ok: false, reason: 'not_signing');
  }
  if ((_num(_map(state['resources'])?['fanCoins']) ?? 0) <
      (_num(listing['price']) ?? 0)) {
    return (ok: false, reason: 'not_enough_coins');
  }
  final cells = _map(state['grid'])?['cells'];
  final occupied = _cards(state).length;
  if (occupied >= getMaxPlayers(state)) return (ok: false, reason: 'squad_full');
  if (cells is! List || findFirstEmpty(cells) == -1) {
    return (ok: false, reason: 'squad_full');
  }
  return (ok: true, reason: null);
}

/// Takes a listing. Sells the player for a bid, buys them for a signing.
DealResult acceptListing(
  Map<String, dynamic> state,
  String listingId, [
  int? nowMs,
]) {
  final at = nowMs ?? now();
  final found = _findLive(state, listingId);
  if (found.err != null) return {'ok': false, 'reason': found.err};
  final l = found.l!;
  if (listingExpired(l, at)) {
    l['status'] = 'expired';
    return {'ok': false, 'reason': 'expired'};
  }

  return switch (l['kind']) {
    'bid' => _acceptBid(state, l, at),
    'loan' => _acceptLoan(state, l, at),
    'loanOut' => _acceptLoanOut(state, l, at),
    _ => _acceptSigning(state, l, at),
  };
}

/// Sends one of ours out on loan at the rival's terms.
DealResult _acceptLoanOut(Map<String, dynamic> state, Listing l, int nowMs) {
  final res = loanOutPlayer(
    state,
    '${l['cardInstanceId']}',
    toTeam: l['fromTeam'] as String?,
    matches: (_num(l['matches']) ?? loanOutMatches).toInt(),
    feePerMatch: _num(l['feePerMatch']),
  );
  if (!res.ok) return {'ok': false, 'reason': res.reason};

  l['status'] = 'accepted';
  l['resolvedAt'] = nowMs;
  trackEventAction(state, 'deadline_deal');
  trackEventAction(state, 'deadline_loan_out');

  emit('deadline:deal', {'kind': 'loanOut', 'listing': l, 'price': 0});
  return {
    'ok': true,
    'kind': 'loanOut',
    'playerName': l['playerName'],
    'feePerMatch': res.feePerMatch,
    'matches': res.matches,
    'toTeam': l['fromTeam'],
  };
}

/// Pushes a rival for more money on a bid they have made.
///
/// Three outcomes, and one of them is the deal dying: accepted (they pay the ask),
/// counter (they meet us partway and that number is final), withdrawn (the club
/// pulls out). Losing the player entirely for asking is what makes pushing a real
/// risk rather than a free roll.
DealResult askForMore(
  Map<String, dynamic> state,
  String listingId,
  num? askPrice, [
  int? nowMs,
]) {
  final at = nowMs ?? now();
  final found = _findLive(state, listingId);
  if (found.err != null) return {'ok': false, 'reason': found.err};
  final l = found.l!;
  if (l['kind'] != 'bid') return {'ok': false, 'reason': 'not_negotiable'};
  if (listingExpired(l, at)) {
    l['status'] = 'expired';
    return {'ok': false, 'reason': 'expired'};
  }

  final res = evaluateAsk(state, l, askPrice);
  final before = _num(l['price']) ?? 0;

  if (res.outcome == 'withdrawn') {
    // They are gone. Not "refused" — the listing dies.
    l['status'] = 'withdrawn';
    l['resolvedAt'] = at;
    emit('deadline:withdrawn', {
      'listingId': listingId,
      'fromTeam': l['fromTeam'],
      'playerName': l['playerName'],
    });
    return {'ok': true, 'outcome': 'withdrawn', 'price': 0, 'was': before};
  }

  if (res.outcome == 'accepted' || res.outcome == 'counter') {
    // The uplift is always cash — a rival does not find another player down the
    // back of the sofa mid-negotiation.
    final uplift = math.max(0, res.price - before);
    final offer = _map(l['offer']);
    if (offer != null) offer['cash'] = (_num(offer['cash']) ?? 0) + uplift;
    l['price'] = res.price;
  }
  if (res.outcome == 'counter') {
    l['haggled'] = true;
    // They have come back with a number and it is our move. Freeze the fuse here
    // as well as in the UI, so the rule holds for any caller.
    if (!isPaused(l)) l['pausedAt'] = at;
  }

  emit('deadline:haggled', {
    'listingId': listingId,
    'outcome': res.outcome,
    'from': before,
    'to': l['price'],
  });
  return {
    'ok': true,
    'outcome': res.outcome,
    'price': l['price'],
    'was': before,
  };
}

/// Offers something other than the asking price for a listing we want to buy —
/// less cash, our own players, or both.
///
/// One shot: accepted or not, with the shortfall reported so a rejection teaches
/// you the number.
DealResult submitOffer(
  Map<String, dynamic> state,
  String listingId,
  Offer? offer, [
  int? nowMs,
]) {
  final at = nowMs ?? now();
  final found = _findLive(state, listingId);
  if (found.err != null) return {'ok': false, 'reason': found.err};
  final l = found.l!;
  if (l['kind'] != 'signing' && l['kind'] != 'loan') {
    return {'ok': false, 'reason': 'not_negotiable'};
  }
  if (listingExpired(l, at)) {
    l['status'] = 'expired';
    return {'ok': false, 'reason': 'expired'};
  }
  if ((_num(_map(state['resources'])?['fanCoins']) ?? 0) <
      (_num(offer?['cash']) ?? 0)) {
    return {'ok': false, 'reason': 'not_enough_coins'};
  }

  final verdict = evaluateOurOffer(state, l, offer);
  final asDetail = {
    'value': verdict.value,
    'needed': verdict.needed,
    'shortfall': verdict.shortfall,
    'counterPrice': verdict.counterPrice,
    'outcome': verdict.outcome,
  };

  // Every offer that is not taken costs a round of their patience.
  if (verdict.outcome != 'accepted') {
    l['haggleUsed'] = (_num(l['haggleUsed']) ?? 0) + 1;
  }

  if (verdict.outcome == 'withdrawn') {
    // Insulted. The player is off the market — not merely refused.
    l['status'] = 'withdrawn';
    l['resolvedAt'] = at;
    emit('deadline:withdrawn', {
      'listingId': listingId,
      'fromTeam': l['fromTeam'],
      'playerName': l['playerName'],
    });
    return {'ok': false, 'reason': 'withdrawn', ...asDetail};
  }

  if (verdict.outcome == 'counter') {
    // They have named a figure and it STAYS on the table for the rest of the
    // fuse. The clock deliberately keeps running: closing the sheet is going away
    // to think, not refusing, and freezing the window while you think was letting
    // a player park a deal indefinitely.
    l['sellerCounter'] = {
      'price': verdict.counterPrice,
      'offer': {...?offer},
    };
    emit('deadline:seller-counter', {'listingId': listingId, ...asDetail});
    return {'ok': false, 'reason': 'counter', ...asDetail};
  }
  if (verdict.outcome != 'accepted') {
    emit('deadline:offer-rejected', {'listingId': listingId, ...asDetail});
    return {'ok': false, 'reason': 'rejected', ...asDetail};
  }

  // Players we put in leave first, freeing grid slots for the arrival.
  final gave = surrenderPlayers(state, offer);
  final priced = {...l, 'price': _num(offer?['cash']) ?? 0};
  final res = l['kind'] == 'loan'
      ? _acceptLoan(state, priced, at)
      : _acceptSigning(state, priced, at);
  if (!_flag(res['ok'])) return res;

  l['status'] = 'accepted';
  l['resolvedAt'] = at;
  return {
    ...res,
    'gave': [for (final c in gave) c.raw],
    'offered': verdict.value,
  };
}

/// Takes the seller's counter.
///
/// Their number is a TOTAL — the players we already put on the table stay in the
/// deal and we make up the rest in cash, so accepting does not quietly re-price
/// the swap we had agreed to.
DealResult acceptSellerCounter(
  Map<String, dynamic> state,
  String listingId, [
  int? nowMs,
]) {
  final at = nowMs ?? now();
  final found = _findLive(state, listingId);
  if (found.err != null) return {'ok': false, 'reason': found.err};
  final l = found.l!;
  final counter = _map(l['sellerCounter']);
  if (counter == null) return {'ok': false, 'reason': 'no_counter'};
  if (listingExpired(l, at)) {
    l['status'] = 'expired';
    return {'ok': false, 'reason': 'expired'};
  }

  final price = _num(counter['price']) ?? 0;
  final offer = _map(counter['offer']) ?? <String, dynamic>{};
  final playersWorth =
      offerValue(state, {'players': offer['players'] ?? <Object?>[]});
  final cashNeeded = math.max(0, _jsRound(price - playersWorth));
  if ((_num(_map(state['resources'])?['fanCoins']) ?? 0) < cashNeeded) {
    return {
      'ok': false,
      'reason': 'not_enough_coins',
      'cashNeeded': cashNeeded,
    };
  }

  final gave = surrenderPlayers(state, offer);
  final priced = {...l, 'price': cashNeeded};
  final res = l['kind'] == 'loan'
      ? _acceptLoan(state, priced, at)
      : _acceptSigning(state, priced, at);
  if (!_flag(res['ok'])) return res;

  l['status'] = 'accepted';
  l['resolvedAt'] = at;
  return {
    ...res,
    'gave': [for (final c in gave) c.raw],
    'paid': cashNeeded,
    'agreed': price,
  };
}

DealResult _acceptLoan(Map<String, dynamic> state, Listing l, int nowMs) {
  final res = grantLoan(
    state,
    '${l['definitionId']}',
    fee: _num(l['price']),
    wage: _num(l['wage']),
    matches: (_num(l['matches']) ?? loanMatches).toInt(),
    fromTeam: l['fromTeam'] as String?,
  );
  if (!res.ok) return {'ok': false, 'reason': res.reason};

  l['status'] = 'accepted';
  l['resolvedAt'] = nowMs;
  l['signedInstanceId'] = res.card!.instanceId;

  trackEventAction(state, 'deadline_deal');
  trackEventAction(state, 'deadline_loan');

  emit('deadline:deal', {
    'kind': 'loan',
    'listing': l,
    'price': l['price'],
    'card': res.card!.raw,
  });
  return {
    'ok': true,
    'kind': 'loan',
    'price': l['price'],
    'wage': res.wage,
    'matches': _num(l['matches']) ?? loanMatches,
    'card': res.card!.raw,
    'playerName': res.card!.name('${l['playerName'] ?? ''}'),
  };
}

DealResult _acceptBid(Map<String, dynamic> state, Listing l, int nowMs) {
  final cells = _map(state['grid'])?['cells'];
  if (cells is! List) return {'ok': false, 'reason': 'card_gone'};
  final idx = cells.indexWhere(
    (c) => _map(c)?['instanceId'] == l['cardInstanceId'],
  );
  if (idx == -1) {
    l['status'] = 'void';
    return {'ok': false, 'reason': 'card_gone'};
  }

  final rating = getPlayerDef('${l['definitionId']}')?.rating ?? 50;
  cells[idx] = null;

  // Players included in their offer arrive on our grid. Done AFTER freeing the
  // sold player's cell, so a swap never fails for want of a slot.
  final arrived = <Map<String, dynamic>>[];
  final incoming = _map(l['offer'])?['incoming'];
  if (incoming is List) {
    for (final card in incoming) {
      final slot = findFirstEmpty(cells);
      if (slot == -1) break; // genuinely no room — the cash still lands
      cells[slot] = card;
      if (_map(card) case final m?) arrived.add(m);
    }
  }
  final lineup = _map(state['squad'])?['lineup'];
  if (lineup is List) {
    for (final raw in lineup) {
      final slot = _map(raw);
      if (slot?['cardInstanceId'] == l['cardInstanceId']) {
        slot!['cardInstanceId'] = null;
      }
    }
  }

  // Only the CASH part of the offer is money; the players arrived above.
  final offer = _map(l['offer']);
  final cash = offer != null
      ? (_num(offer['cash']) ?? 0)
      : (_num(l['price']) ?? 0);
  final resources = state['resources'] as Map<String, dynamic>;
  resources['fanCoins'] = (_num(resources['fanCoins']) ?? 0) + cash;

  // The same permanent buyer bump a routine transfer applies — selling into
  // deadline day still arms a rival for the seasons to come.
  final boost = applyRivalPlayerBoost(state, '${l['fromTeam']}', rating);

  l['status'] = 'accepted';
  l['resolvedAt'] = nowMs;
  final stats = _map(state['stats']);
  if (stats != null) {
    stats['transfersAccepted'] = (_num(stats['transfersAccepted']) ?? 0) + 1;
  }

  trackEventAction(state, 'deadline_deal');
  trackEventAction(state, 'deadline_sale');

  emit('player:sold', {
    'definitionId': l['definitionId'],
    'tier': l['tier'],
    'price': l['price'],
  });
  emit('coins:updated', resources['fanCoins']);
  emit('deadline:deal', {'kind': 'sale', 'listing': l, 'price': l['price']});
  return {
    'ok': true,
    'kind': 'sale',
    'price': l['price'],
    'cash': cash,
    'arrived': arrived,
    'playerName': l['playerName'],
    'ratingBoost': {'before': boost.before, 'after': boost.after},
  };
}

DealResult _acceptSigning(Map<String, dynamic> state, Listing l, int nowMs) {
  final gate = canSign(state, l);
  if (!gate.ok) return {'ok': false, 'reason': gate.reason};

  final cells = (_map(state['grid'])!['cells'] as List);
  final slot = findFirstEmpty(cells);

  // **THE CARD THE FEED SHOWED IS THE CARD THAT ARRIVES.**
  //
  // This used to roll a FRESH instance and carry only the name across, so the
  // variant, the trait and the ATK/DEF split on the offer were not the ones
  // delivered — which contradicts the reason the card is pre-rolled at listing
  // time in the first place: "the portrait, the rating and the stat split on
  // the offer are exactly what lands on your grid". It is a bug in the JS,
  // reproduced faithfully through the port and fixed here deliberately.
  //
  // **THE ROLL STILL HAPPENS.** Its result is thrown away, and that is the
  // point: the JS's position in the merge RNG stream is part of the spec, and
  // every card the rest of the session rolls depends on it. Skipping the draw
  // would silently change the whole remainder of the feed, turning a fix to one
  // signing into a divergence from the source everywhere after it. So the draw
  // is spent exactly as before and only the card handed over changes — which
  // keeps this a one-line behaviour difference rather than a fork.
  //
  // The grid gets a COPY. The listing keeps its own record of what was offered,
  // and a shared map would let the grid rewrite the history of the deal — the
  // signed player levelling up would retro-edit the offer that was made.
  //
  // The discarded roll is also the FALLBACK, for a listing with no pre-rolled
  // card: that is what a save written before signings carried one looks like.
  final rolled = createInstance(
    '${l['definitionId']}',
    preferredFemale: l['female'] as bool?,
  );
  final offered = _map(l['card']);
  final card = offered == null
      ? rolled
      : CardInstance(jsonDecode(jsonEncode(offered)) as Map<String, dynamic>);
  if (l['playerName'] != null) card.raw['displayName'] = l['playerName'];
  cells[slot] = card.raw;
  final resources = state['resources'] as Map<String, dynamic>;
  resources['fanCoins'] =
      (_num(resources['fanCoins']) ?? 0) - (_num(l['price']) ?? 0);

  l['status'] = 'accepted';
  l['resolvedAt'] = nowMs;
  l['signedInstanceId'] = card.instanceId;

  trackEventAction(state, 'deadline_deal');
  trackEventAction(state, 'deadline_signing');
  if (_flag(l['marquee'])) trackEventAction(state, 'deadline_marquee');

  emit('coins:updated', resources['fanCoins']);
  emit('deadline:deal', {
    'kind': 'signing',
    'listing': l,
    'price': l['price'],
    'card': card.raw,
  });
  return {
    'ok': true,
    'kind': 'signing',
    'price': l['price'],
    'card': card.raw,
    'slot': slot,
    'marquee': _flag(l['marquee']),
    'playerName': card.name('${l['playerName'] ?? ''}'),
  };
}

/// Waves a listing away. No grudge — deadline day is too fast to hold one.
DealResult dismissListing(Map<String, dynamic> state, String listingId) {
  final found = _findLive(state, listingId);
  if (found.err != null) return {'ok': false, 'reason': found.err};
  final l = found.l!;
  l['status'] = 'declined';
  emit('deadline:listing-dismissed', {
    'listingId': listingId,
    'kind': l['kind'],
  });
  return {'ok': true};
}

/// Closes the window and banks a summary.
///
/// Idempotent, and only ever reached by the clock running out — there is no manual
/// close. A button to leave early on a window that is going to shut by itself was
/// a control for nothing: the honest exit is to walk away, and the feed keeps
/// running either way.
Map<String, dynamic>? endSession(Map<String, dynamic> state, [int? nowMs]) {
  final at = nowMs ?? now();
  final dd = ensureDeadlineDay(state);
  final s = _map(dd['session'])!;
  if ((_num(s['startedAt']) ?? 0) == 0 || _flag(s['done'])) {
    return _map(s['summary']);
  }

  // Close out anything still on the table BEFORE counting, or a deal you never
  // answered would slip through uncounted just because the window shut before its
  // fuse did. With a five-minute fuse that is most of the last five minutes of
  // every window.
  final listings = _listingsOf(s);
  for (final l in listings) {
    if (l['status'] == 'live') l['status'] = 'expired';
  }

  List<Listing> acceptedOf(String kind) => [
    for (final l in listings)
      if (l['status'] == 'accepted' && l['kind'] == kind) l,
  ];
  final sales = acceptedOf('bid');
  final signings = acceptedOf('signing');
  final loans = acceptedOf('loan');
  final loanOuts = acceptedOf('loanOut');
  final marquees = [
    for (final l in signings)
      if (_flag(l['marquee'])) l,
  ];

  // What came ACROSS the desk, not just what was signed. A window where forty
  // offers arrived and you took two is a different evening from one where two
  // arrived and you took both, and the deals-done rows cannot tell them apart.
  int offeredOf(String kind) =>
      listings.where((l) => l['kind'] == kind).length;

  num sumPrice(Iterable<Listing> ls) =>
      ls.fold<num>(0, (sum, l) => sum + (_num(l['price']) ?? 0));

  final income = sumPrice(sales);
  // Loan fees are spend too — the wages that follow are charged per match and
  // belong to those matches, not to this window's ledger.
  final spend = sumPrice([...signings, ...loans]);

  final summary = <String, dynamic>{
    'windowStart': s['windowStart'],
    'endedAt': at,
    'sales': sales.length,
    'signings': signings.length,
    'loans': loans.length,
    'loanOuts': loanOuts.length,
    'marquees': marquees.length,
    'offers': {
      'signing': offeredOf('signing'),
      'bid': offeredOf('bid'),
      'loan': offeredOf('loan'),
      'loanOut': offeredOf('loanOut'),
    },
    'income': income,
    'spend': spend,
    'wageBill': loans.fold<num>(0, (sum, l) => sum + (_num(l['wage']) ?? 0)),
    'missed': listings.where((l) => l['status'] == 'expired').length,
    'score': sales.length * scorePerSale +
        loans.length * scorePerLoan +
        signings.length * scorePerSigning +
        marquees.length * scorePerMarquee,
  };
  summary['net'] = income - spend;

  s['done'] = true;
  s['summary'] = summary;

  final history = dd['history'] as List;
  history.insert(0, summary);
  if (history.length > historyLimit) history.length = historyLimit;

  emit('deadline:session-ended', summary);
  return summary;
}

List<CardInstance> _cards(Map<String, dynamic>? state) {
  final cells = _map(state?['grid'])?['cells'];
  if (cells is! List) return const [];
  return [
    for (final c in cells)
      if (c is Map<String, dynamic>) CardInstance(c),
  ];
}
