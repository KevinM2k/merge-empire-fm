/// Negotiation — valuation, offers, counter-offers and the transfer list. Ported
/// from `../merge-empire-fc/src/engine/negotiationEngine.js`.
///
/// Deadline Day started as a one-tap feed: a rival names a number, you say yes or
/// no. This turns it into a conversation. Three things live here:
///
///   1. VALUATION — one canonical "what is this player worth", used by both sides
///      of every deal.
///   2. OFFERS — `{ cash, players: [instanceId] }`, the shape both we and the AI
///      speak. A swap is just an offer with players in it; a cash bid is one with
///      an empty players list. There is no separate swap-deal code path.
///   3. THE TRANSFER LIST — marking our own players as available. A listed player
///      cannot be picked (that is the cost) and attracts more, better bids (that
///      is the reward).
///
/// The symmetry in (2) is deliberate. The AI judges our player-plus-cash offer
/// with the same [offerValue] we use to judge theirs, so a deal that reads as
/// fair is fair. No hidden multiplier favouring either side.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/negotiation.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/engine/merge_engine.dart';
import 'package:merge_empire_fc/engine/sell_engine.dart';
import 'package:merge_empire_fc/engine/trait_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

/// The highest tier that can ever change hands in a deal. T9 is scout-only.
const int maxDealTier = 8;

/// One side's side of a deal.
///
/// A raw map, not a typed class, because an offer is STORED: it rides on a
/// Deadline Day listing, and that listing lives in the save. Keys are `cash`,
/// `players` (our instance ids) and `incoming` (their pre-rolled card maps).
typedef Offer = Map<String, dynamic>;

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

/// JS `Math.round` — halves go up, not to even.
int _jsRound(num v) => (v + 0.5).floor();

/// The outcome of asking or offering, and what it leaves on the table.
typedef DealGate = ({bool ok, String? reason, CardInstance? card});

// ── valuation ────────────────────────────────────────────────────────────────

/// What a player is worth, full stop.
///
/// Built on [baseSellPrice] — the same fair value the Squad sell sheet and
/// auto-sell use — so a card is worth the same number everywhere in the game and
/// a swap cannot be arbitraged against a sale.
num playerValue(Map<String, dynamic>? state, CardInstance? card) {
  final def = card == null ? null : getPlayerDef(card.definitionId);
  if (def == null) return 0;
  return math.max(1, roundCoins(baseSellPrice(def, card, state)));
}

/// One of our grid cards, by instance id.
CardInstance? findOurCard(Map<String, dynamic>? state, Object? instanceId) {
  final cells = _map(state?['grid'])?['cells'];
  if (cells is! List) return null;
  for (final raw in cells) {
    final card = CardInstance.from(raw);
    if (card != null && card.instanceId == instanceId) return card;
  }
  return null;
}

/// What an offer is worth.
///
/// `players` are OUR instance ids when we are the ones offering; `incoming` are
/// pre-rolled card maps when the AI is. Both add on the same scale as the cash,
/// which is the whole symmetry claim.
num offerValue(Map<String, dynamic>? state, Offer? offer) {
  if (offer == null) return 0;
  final cash = math.max(0, _num(offer['cash']) ?? 0);

  var ours = 0.0;
  final players = offer['players'];
  if (players is List) {
    for (final id in players) {
      ours += playerValue(state, findOurCard(state, id));
    }
  }

  var theirs = 0.0;
  final incoming = offer['incoming'];
  if (incoming is List) {
    for (final raw in incoming) {
      theirs += playerValue(state, CardInstance.from(raw));
    }
  }

  return cash + ours + theirs;
}

/// One line of an offer, for display.
class OfferPart {
  const OfferPart.cash(this.amount)
      : kind = 'cash',
        card = null,
        name = null,
        value = null;

  const OfferPart.player({
    required this.card,
    required this.name,
    required this.value,
  })  : kind = 'player',
        amount = null;

  final String kind;
  final num? amount;
  final CardInstance? card;
  final String? name;
  final num? value;
}

/// A readable breakdown, so an offer is never a bare number on screen.
List<OfferPart> describeOffer(Map<String, dynamic>? state, Offer? offer) {
  final parts = <OfferPart>[];
  final cash = _num(offer?['cash']) ?? 0;
  if (cash > 0) parts.add(OfferPart.cash(cash));

  final players = offer?['players'];
  if (players is List) {
    for (final id in players) {
      final card = findOurCard(state, id);
      if (card == null) continue;
      parts.add(
        OfferPart.player(
          card: card,
          name: card.name('Player'),
          value: playerValue(state, card),
        ),
      );
    }
  }

  final incoming = offer?['incoming'];
  if (incoming is List) {
    for (final raw in incoming) {
      final card = CardInstance.from(raw);
      if (card == null) continue;
      parts.add(
        OfferPart.player(
          card: card,
          name: card.name('Player'),
          value: playerValue(state, card),
        ),
      );
    }
  }
  return parts;
}

// ── the transfer list ────────────────────────────────────────────────────────

bool isListed(CardInstance? card) => card?.listed ?? false;

List<CardInstance> listedCards(Map<String, dynamic>? state) => [
  for (final c in _cards(state))
    if (isListed(c)) c,
];

/// Puts a player on the transfer list.
///
/// They immediately stop being usable: pulled out of the XI, and every lineup
/// and rating path skips them. That unavailability is the whole price of
/// advertising — in exchange the player draws more bids, and better ones.
DealGate listPlayer(Map<String, dynamic> state, Object? instanceId) {
  final card = findOurCard(state, instanceId);
  if (card == null) return (ok: false, reason: 'unknown_card', card: null);
  if (card.raw['loanMatchesLeft'] != null) {
    return (ok: false, reason: 'loan_card', card: null);
  }
  if (isListed(card)) return (ok: true, reason: null, card: card);

  // Never list the last usable player — that would leave an unfieldable squad.
  if (usableCards(state).length <= 1) {
    return (ok: false, reason: 'last_player', card: null);
  }

  card.raw['listed'] = true;
  card.raw['listedAt'] = now();
  final lineup = _map(state['squad'])?['lineup'];
  if (lineup is List) {
    for (final raw in lineup) {
      final slot = _map(raw);
      if (slot?['cardInstanceId'] == instanceId) slot!['cardInstanceId'] = null;
    }
  }
  emit('transfer:listed', {'card': card.raw});
  return (ok: true, reason: null, card: card);
}

/// Takes a player back off the list.
///
/// The fields are REMOVED rather than set to null: a nulled field still
/// serialises, so it would leave `listed: null` in the save where the JS leaves
/// the key out entirely.
DealGate unlistPlayer(Map<String, dynamic> state, Object? instanceId) {
  final card = findOurCard(state, instanceId);
  if (card == null) return (ok: false, reason: 'unknown_card', card: null);
  card.raw.remove('listed');
  card.raw.remove('listedAt');
  emit('transfer:unlisted', {'card': card.raw});
  return (ok: true, reason: null, card: card);
}

/// Cards actually available to play: on the grid, not listed, not away on loan.
///
/// A loanee we have BORROWED is usable — that is what the wages buy. Callers that
/// also care about injuries filter those separately, as they always have.
List<CardInstance> usableCards(Map<String, dynamic>? state) => [
  for (final c in _cards(state))
    if (!c.isUnavailable) c,
];

// ── the AI's side ────────────────────────────────────────────────────────────

/// Rolls a complete, real card for a deal — the actual instance that will change
/// hands, not a placeholder.
///
/// Players in the wild already have careers, so some arrive with a trait rather
/// than every trait having to be rolled by us afterwards. The chance rises with
/// tier: a bronze journeyman rarely has one, an elite card usually does. The
/// level comes from the same weighted roll the Trait Roulette uses, so a trait
/// that arrives on a signing is worth exactly what one you rolled would be.
///
/// Draws from BOTH streams, and the split is preserved: the gender roll and the
/// trait-chance roll are seeded gameplay, while the variant, the rating spread,
/// the ATK/DEF ratio and the trait itself come off `dart:math` inside
/// [createInstance] and [rollTrait].
CardInstance? rollDealCard(PlayerDef? def) {
  if (def == null) return null;
  final female = seeded.random() < 0.5;
  final card = createInstance(def.id, preferredFemale: female);
  card.raw['displayName'] = pickDisplayName(
    def.position,
    math.max(0, def.tier - 1),
    female: female,
  );
  if (seeded.random() < traitChanceForTier(def.tier)) {
    applyTrait(card, rollTrait(def.position));
  }
  return card;
}

/// Odds an offered card already carries a trait — about 12% at T1, 68% at T8.
double traitChanceForTier([int tier = 1]) =>
    math.min(0.68, 0.04 + 0.08 * math.max(0, tier - 1));

/// A pre-rolled card at [tier], for players the AI offers us.
CardInstance? _rollCard(int tier) {
  final t = math.max(1, math.min(maxDealTier, tier));
  final pool = getPlayersByTier(t);
  if (pool.isEmpty) return null;
  return rollDealCard(seeded.pickRandom(pool));
}

/// How many incoming players a swap can actually deliver: the empty grid cells,
/// plus the one the outgoing player vacates.
///
/// Counted against [getMaxPlayers] rather than the raw array, so a Youth Academy
/// tier is respected.
int _swapRoom(Map<String, dynamic>? state) {
  final occupied = _cards(state).length;
  final free = math.max(0, getMaxPlayers(state) - occupied);
  // The sold player's own cell is only usable if the array has somewhere to put
  // them — a fixed-length grid that is physically full still frees that one.
  return free + 1;
}

/// What a rival puts on the table for [target].
///
/// Sometimes pure cash, sometimes players plus cash. The mixed offer is
/// deliberately a slight discount for them ([mixedCashCover]), so "cash only"
/// reads as the cleaner deal and the two options have genuinely different
/// characters rather than being the same number wearing different clothes.
Offer buildRivalOffer(
  Map<String, dynamic>? state,
  CardInstance? target,
  num askingValue,
) {
  final targetDef = getPlayerDef(target?.definitionId);
  final wantsPlayers = seeded.random() < incomingPlayerChance;
  Offer cashOnly() => {
    'cash': math.max(1, roundCoins(askingValue)),
    'incoming': <Map<String, dynamic>>[],
  };
  if (targetDef == null || !wantsPlayers) return cashOnly();

  // How many of their players we could actually house. Selling the target frees
  // its own slot, so that is the empty cells plus one. Offering more than this
  // was a quiet robbery: the accept path drops any player it cannot place and
  // pays only the cash, so a two-player swap into a full squad handed over our
  // man and binned one of theirs.
  final room = _swapRoom(state);
  if (room <= 0) return cashOnly();

  final incoming = <CardInstance>[];
  void addOne() {
    if (incoming.length >= room) return;
    final offset = seeded.pickRandom(incomingTierOffset);
    final card = _rollCard(targetDef.tier + offset);
    if (card != null) incoming.add(card);
  }

  addOne();
  if (seeded.random() < incomingSecondChance) addOne();
  if (incoming.isEmpty) return cashOnly();

  var playerWorth = 0.0;
  for (final c in incoming) {
    playerWorth += playerValue(state, c);
  }
  final shortfall = math.max(0, askingValue - playerWorth);
  return {
    'cash': math.max(0, roundCoins(shortfall * mixedCashCover)),
    'incoming': [for (final c in incoming) c.raw],
  };
}

/// One of our players a rival has come in for.
typedef BidTarget = ({CardInstance card, PlayerDef def});

/// Which of our players a rival comes in for.
///
/// Listed players are weighted heavily — advertising works — and otherwise it is
/// the same "the better they are, the more they are wanted" curve the routine
/// transfer system uses.
BidTarget? pickBidTarget(
  Map<String, dynamic>? state, {
  Set<Object?> exclude = const {},
  int minTier = 2,
}) {
  final pool = <({CardInstance card, PlayerDef def, double weight})>[];
  for (final card in _cards(state)) {
    if (card.injured) continue;
    if (card.raw['loanMatchesLeft'] != null) continue; // not ours to sell
    if (exclude.contains(card.instanceId)) continue;
    final def = getPlayerDef(card.definitionId);
    if (def == null || def.tier < minTier) continue;
    final weight = math.pow(def.tier, 2).toDouble() +
        (card.sponsor != null ? 10 : 0) +
        (isListed(card) ? listedBidWeight * def.tier : 0);
    pool.add((card: card, def: def, weight: weight));
  }
  if (pool.isEmpty) return null;

  final total = pool.fold<double>(0, (s, p) => s + p.weight);
  var roll = seeded.random() * total;
  for (final p in pool) {
    roll -= p.weight;
    if (roll <= 0) return (card: p.card, def: p.def);
  }
  final last = pool.last;
  return (card: last.card, def: last.def);
}

/// Bids for a listed player come in higher — that is the reward for listing.
double listedPremium(CardInstance? card) => isListed(card) ? listedBidPremium : 1;

// ── evaluating counters ──────────────────────────────────────────────────────

/// What a buyer said, and what it leaves on the table.
typedef AskVerdict = ({String outcome, num price});

/// We hold a bid for one of our players and want more money.
///
/// Three outcomes, and one of them ends the deal:
///   * `accepted` — inside their ceiling, they pay.
///   * `counter` — over the ceiling but not insulting: they come back once,
///     meeting us partway, and that number is final.
///   * `withdrawn` — past [walkAwayMult], or still pushing after their counter.
///     The club pulls out and the offer is gone. There is no third round.
///
/// The withdraw branch is the point of the whole thing. Without it the worst case
/// of asking for the moon was the original price, so there was never a reason not
/// to. Now greed can cost you the sale.
AskVerdict evaluateAsk(
  Map<String, dynamic>? state,
  Map<String, dynamic>? listing,
  num? askPrice,
) {
  final opening = _num(listing?['price']) ?? 0;
  final ask = math.max(0, _jsRound(askPrice ?? 0));
  if (ask <= opening) return (outcome: 'accepted', price: opening);

  // Their limit is measured from the ORIGINAL bid, never from the figure we last
  // talked them up to. Anchoring on the live price — which asking overwrites
  // every time it succeeds — let the same 1.35x be applied again to the new,
  // higher number: 1.3x accepted, 1.3x again accepted, with no top at all.
  // `askCeilingMult` is this buyer's own limit, rolled when the bid was built and
  // never shown, so there is no single safe multiple to learn.
  final anchor = _num(listing?['askAnchor']) ?? opening;
  final ceilMult = _num(listing?['askCeilingMult']) ?? counterMaxMult;
  final ceiling = _jsRound(anchor * ceilMult);
  final walkAway = _jsRound(anchor * (ceilMult + (walkAwayMult - counterMaxMult)));

  if (ask <= ceiling) return (outcome: 'accepted', price: ask);
  if (ask >= walkAway) return (outcome: 'withdrawn', price: 0);

  // Second time of asking. Their counter was final, so anything above their
  // ceiling now makes them walk — there is no third round. Asking for LESS than
  // their standing price was already accepted at the top, so there is no
  // "they refuse but stay" case left to represent.
  if (listing?['haggled'] == true) return (outcome: 'withdrawn', price: 0);

  // Split the gap from where the money actually stands, not from the anchor — a
  // counter must never come back BELOW what they have already agreed to.
  final meet = _jsRound(opening + (ceiling - opening) * rebuttalSplit);
  return (outcome: 'counter', price: math.max(opening, meet));
}

/// What a seller said about our offer.
typedef OfferVerdict = ({
  String outcome,
  num value,
  num needed,
  num shortfall,
  num counterPrice,
});

/// We want to buy, and we are offering something other than the asking price —
/// less cash, or players, or both.
///
/// The seller answers the same three ways a buyer does:
///   * `accepted` — worth at least their own floor times the asking price.
///   * `counter` — short, but not insultingly: they name their own number, which
///     we can take or walk from.
///   * `rejected` — they will not name a number. Either they never haggle, or
///     their rounds are used up, or they have already countered once.
///   * `withdrawn` — under [counterFloorMult]. A lowball does not start a
///     conversation; they pull the player.
OfferVerdict evaluateOurOffer(
  Map<String, dynamic>? state,
  Map<String, dynamic>? listing,
  Offer? offer,
) {
  // Anchored to what they FIRST asked, not to anything already negotiated down,
  // so a run of small discounts can never compound. `offerMinMult` on the listing
  // is this seller's own floor, rolled when it was built and never shown — a
  // fixed one meant the same percentage worked on every listing in the game.
  final asking = _num(listing?['offerAnchor']) ?? _num(listing?['price']) ?? 0;
  final minMult = _num(listing?['offerMinMult']) ?? offerMinMult;
  final needed = _jsRound(asking * minMult);
  final floor = _jsRound(asking * counterFloorMult);
  final value = offerValue(state, offer);
  final shortfall = math.max(0, needed - value);

  if (value >= needed) {
    return (
      outcome: 'accepted',
      value: value,
      needed: needed,
      shortfall: shortfall,
      counterPrice: 0,
    );
  }

  // Insulting. They pull the player rather than dignify it with a number, and no
  // amount of patience saves it — this is the buy-side walk-away.
  if (value < floor) {
    return (
      outcome: 'withdrawn',
      value: value,
      needed: needed,
      shortfall: shortfall,
      counterPrice: 0,
    );
  }

  // Already been countered once — their number was their number.
  //
  // Not every club haggles either. Their patience is fixed when the listing is
  // built and about a third of them have none at all: those say no flat, with no
  // figure of their own. Out of rounds is the same answer.
  final rounds = _num(listing?['haggleRounds'])?.toInt() ?? 1;
  final used = _num(listing?['haggleUsed'])?.toInt() ?? 0;
  if (listing?['sellerCounter'] != null || used >= rounds) {
    return (
      outcome: 'rejected',
      value: value,
      needed: needed,
      shortfall: shortfall,
      counterPrice: 0,
    );
  }

  final counterPrice = _jsRound(value + (asking - value) * sellerCounterSplit);
  return (
    outcome: 'counter',
    value: value,
    needed: needed,
    shortfall: shortfall,
    counterPrice: math.max(value + 1, counterPrice),
  );
}

/// Hands over every player in the offer — used when one of our swap offers is
/// accepted. Returns the removed cards so the caller can report them.
List<CardInstance> surrenderPlayers(Map<String, dynamic> state, Offer? offer) {
  final gone = <CardInstance>[];
  final ids = offer?['players'];
  if (ids is! List) return gone;

  final cells = _map(state['grid'])?['cells'];
  if (cells is! List) return gone;

  for (final id in ids) {
    final idx = cells.indexWhere((c) => _map(c)?['instanceId'] == id);
    if (idx == -1) continue;
    gone.add(CardInstance.from(cells[idx])!);
    cells[idx] = null;
    final lineup = _map(state['squad'])?['lineup'];
    if (lineup is List) {
      for (final raw in lineup) {
        final slot = _map(raw);
        if (slot?['cardInstanceId'] == id) slot!['cardInstanceId'] = null;
      }
    }
  }
  return gone;
}

List<CardInstance> _cards(Map<String, dynamic>? state) {
  final cells = _map(state?['grid'])?['cells'];
  if (cells is! List) return const [];
  return [
    for (final c in cells)
      if (c is Map<String, dynamic>) CardInstance(c),
  ];
}
