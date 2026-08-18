/// What Coach Colin makes of a Deadline Day listing. Ported from
/// `../merge-empire-fc/src/engine/dealAdviceEngine.js`.
///
/// The trading floor throws four cards at you on a five-minute fuse and every
/// one of them is a number the player has no baseline for. Colin's job is to
/// supply the baseline: is this over the odds or a lowball, is it an upgrade on
/// what we already field, can we even house him, and — when we are the ones
/// being asked — what to hold out for.
///
/// NO STRINGS IN HERE, the same rule the club-asset tiers follow: this returns
/// reason IDS and the UI maps them onto translation keys. That keeps the
/// judgements testable and stops copy decisions leaking into the arithmetic.
///
/// The verdict is deliberately coarse — buckets, not a score. A player deciding
/// in ninety seconds needs "yes", "no" or "your call", and a 0-100 rating would
/// invite them to read a precision that is not there.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/negotiation.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/deadline_day_engine.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/engine/negotiation_engine.dart';
import 'package:merge_empire_fc/engine/squad_rating.dart';
import 'package:merge_empire_fc/state/card_instance.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

/// How many mini-games count as "go and earn it" rather than a second job, and
/// a DELIBERATELY PESSIMISTIC estimate of what one pays.
///
/// Colin used to answer every unaffordable player he rated with "a few training
/// games would cover it", whatever the gap — which on a player ten times out of
/// reach is not encouragement, it is a wrong answer. He can see the balance and
/// he can see the price, so he should be able to tell the difference between a
/// shortfall worth grinding and one that is not.
///
/// The payout multiple sits under Goalkeeper Practice's 3.5 on purpose: the
/// seven games pay differently and this decides whether Colin makes a PROMISE,
/// so it should under-sell rather than over-sell. Being told a gap was grindable
/// and finding out it was not is worse than being told to walk away from one you
/// could have closed.
const int grindGames = 6;
const double grindPayoutMult = 2.5;

/// Over this share above fair value, a bid is generous.
const double overOdds = 1.2;

/// Under this share of fair value, a bid is an insult.
const double lowball = 0.85;

/// A position with this many bodies in it is well stocked.
const int glutAt = 4;

/// A stat gap that counts as a real difference either way.
const double meaningful = 0.05;

/// Fewer bodies than this in a position and there is nobody behind the man who
/// plays there — the one reason to sign someone who would never start.
const int coverAt = 2;

/// Colin's read on a listing.
enum DealVerdict {
  /// The engine will not let the deal happen at all.
  blocked,
  poor,
  fair,
  good,
  great,

  /// Sell side only: good money, but for the best player we have. The call is
  /// the manager's, and he says so.
  tempting,
}

/// Buy-side verdicts, worst first.
///
/// Used to CAP a verdict rather than nudge it a notch: "worth doing" printed
/// over "we're already well stocked" is two halves of one sentence arguing with
/// each other, and a single demotion from `great` left exactly that. A cap
/// cannot overshoot.
const List<DealVerdict> _buyRank = [
  DealVerdict.poor,
  DealVerdict.fair,
  DealVerdict.good,
  DealVerdict.great,
];

DealVerdict _capAt(DealVerdict verdict, DealVerdict cap) =>
    _buyRank.indexOf(verdict) > _buyRank.indexOf(cap) ? cap : verdict;

/// One thing Colin has to say, as an id the UI maps to words.
typedef AdviceReason = ({String id, Map<String, dynamic> params});

typedef DealAdvice = ({
  DealVerdict verdict,
  List<AdviceReason> reasons,
  int suggestedAsk,
  int suggestedOffer,
});

/// Our players in a position, loaned-out ones excluded — they are not
/// available.
List<({CardInstance card, PlayerDef def})> _ours(
  Map<String, dynamic>? state,
  String? position,
) {
  final cells = _map(state?['grid'])?['cells'];
  if (cells is! List) return const [];
  final out = <({CardInstance card, PlayerDef def})>[];
  for (final raw in cells) {
    final card = CardInstance.from(raw);
    if (card == null || card.raw['loanedOut'] == true) continue;
    final def = getPlayerDef(card.definitionId);
    if (def == null) continue;
    if (position != null && def.position != position) continue;
    out.add((card: card, def: def));
  }
  return out;
}

/// The best rating we field in a position, or null if we field nobody.
///
/// [exceptId] leaves one player out, which is what the sell side needs: the
/// question is never "is he as good as the best we have" — he IS one of the ones
/// we have — but "is he better than what we would be left with". Counting him
/// against himself made every one of three identical forwards read as
/// irreplaceable, so no ordinary squad player could be sold without a warning.
num? _bestRating(
  Map<String, dynamic>? state,
  String? position, [
  String? exceptId,
]) {
  final ratios = _map(state?['definitionRatios']) ?? const {};
  num? best;
  for (final entry in _ours(state, position)) {
    if (exceptId != null && entry.card.instanceId == exceptId) continue;
    final r = getCardStats(entry.card, definitionRatios: ratios).rating;
    if (best == null || r > best) best = r;
  }
  return best;
}

int _freeSlots(Map<String, dynamic>? state) {
  final cells = _map(state?['grid'])?['cells'];
  final filled = cells is List ? cells.where((c) => c != null).length : 0;
  return math.max(0, getMaxPlayers(state) - filled);
}

/// Would this signing actually make us better?
///
/// True when we field nobody in the position at all, or when they beat the best
/// we have there by a real margin. Only asked of incoming players — nobody
/// improves us by leaving.
bool _wouldImproveUs(Map<String, dynamic>? state, Listing listing) {
  final theirCard = CardInstance.from(listing['card']);
  if (theirCard == null) return false;
  final def = getPlayerDef(listing['definitionId'] as String?);
  final position = def?.position ?? listing['position'] as String?;
  if (position == null) return false;
  final best = _bestRating(state, position);
  if (best == null) return true; // a hole in the squad
  final theirs = getCardStats(
    theirCard,
    definitionRatios: _map(state?['definitionRatios']) ?? const {},
  ).rating;
  return theirs >= best * (1 + meaningful);
}

/// What we should ask a buyer for.
///
/// Deliberately short of their real ceiling — the ceiling is per-buyer and
/// hidden, so advice aimed at it would get the player withdrawn from about half
/// of all offers. This aims at the bottom of the ceiling band, which is safe
/// against every buyer.
int suggestedAskFor(Listing? listing) {
  final opening = _num(listing?['askAnchor']) ?? _num(listing?['price']) ?? 0;
  if (opening <= 0) return 0;
  return (opening * 1.15).round();
}

/// What we should offer for something we are buying.
///
/// A RULE OF THUMB, and deliberately not more than that. Colin must NOT read
/// the seller's floor: it is hidden from the player, and advice derived from it
/// would be an oracle that always lands, which kills the whole point of
/// haggling. This is a flat 10% under the asking price — often accepted,
/// sometimes countered, sometimes refused. He is guessing, same as you.
///
/// It is a cheap guess to make, mind: below the floor but above
/// [counterFloorMult] the seller counters rather than walking, so a low offer
/// usually costs a round of conversation rather than the deal.
int suggestedOfferFor(Listing? listing) {
  final asking = _num(listing?['offerAnchor']) ?? _num(listing?['price']) ?? 0;
  if (asking <= 0) return 0;
  return (asking * 0.9).round();
}

/// Colin's read on one listing.
///
/// [DealVerdict.blocked] always wins and always comes with the engine's own
/// reason, so the advice can never contradict the button being disabled.
DealAdvice adviseOnListing(Map<String, dynamic>? state, Listing? listing) {
  if (state == null || listing == null) {
    return (
      verdict: DealVerdict.fair,
      reasons: const <AdviceReason>[],
      suggestedAsk: 0,
      suggestedOffer: 0,
    );
  }

  final reasons = <AdviceReason>[];
  final blocked = listingBlockedReason(state, listing);
  if (blocked != null) {
    final out = <AdviceReason>[
      (id: 'blocked_$blocked', params: <String, dynamic>{}),
    ];
    if (blocked == 'not_enough_coins') {
      // Not being able to meet the asking price is NOT the end of it. Anything
      // above the seller's counter floor draws a counter rather than a flat no,
      // so the money we do have is worth putting on the table — "we can't afford
      // him" and then silence is the least useful thing a coach could say.
      final haggleable =
          listing['kind'] == 'signing' || listing['kind'] == 'loan';
      final asking =
          _num(listing['offerAnchor']) ?? _num(listing['price']) ?? 0;
      final coins = _num(_map(state['resources'])?['fanCoins']) ?? 0;
      final cheeky = math.min(coins, suggestedOfferFor(listing));
      if (haggleable &&
          cheeky > 0 &&
          cheeky >= (asking * counterFloorMult).round()) {
        out.add((id: 'try_cheeky', params: <String, dynamic>{}));
        return (
          verdict: DealVerdict.blocked,
          reasons: out,
          suggestedAsk: 0,
          suggestedOffer: cheeky.toInt(),
        );
      }
      // Out of haggling range. If they would genuinely improve us the money
      // might be worth going and earning — but only if the gap is actually
      // earnable. Beyond that Colin says plainly that we cannot afford them,
      // which is a useful answer where a cheerful lie is not. He stops at "no":
      // the only route left is the shop, and steering a player towards real
      // money at the moment they are told they are broke is not advice.
      //
      // A player who would not improve us needs no second line: "not enough
      // funds" is the whole story and walking past is the obvious move.
      if (_wouldImproveUs(state, listing)) {
        final shortfall = math.max(0, (_num(listing['price']) ?? 0) - coins);
        final earnable =
            miniGameRewardBase(state) * grindPayoutMult * grindGames;
        out.add((
          id: shortfall <= earnable ? 'find_money' : 'cannot_afford',
          params: <String, dynamic>{},
        ));
      }
    }
    return (
      verdict: DealVerdict.blocked,
      reasons: out,
      suggestedAsk: 0,
      suggestedOffer: 0,
    );
  }

  final def = getPlayerDef(listing['definitionId'] as String?);
  final position = def?.position ?? listing['position'] as String?;
  final selling = listingSide(listing) == 'sell';
  final ratios = _map(state['definitionRatios']) ?? const {};

  // ── Selling: they want one of ours ────────────────────────────────────────
  if (selling) {
    final cells = _map(state['grid'])?['cells'];
    CardInstance? card;
    if (cells is List) {
      for (final raw in cells) {
        final c = CardInstance.from(raw);
        if (c != null && c.instanceId == listing['cardInstanceId']) card = c;
      }
    }
    final fair = card != null ? playerValue(state, card) : 0;
    final cash =
        _num(_map(listing['offer'])?['cash']) ?? _num(listing['price']) ?? 0;
    final packageWorth = _num(listing['price']) ?? cash;
    final ratio = fair > 0 ? packageWorth / fair : 1;

    DealVerdict verdict;
    if (ratio >= overOdds) {
      verdict = DealVerdict.great;
      reasons.add((
        id: 'over_odds',
        params: {'pct': ((ratio - 1) * 100).round()},
      ));
    } else if (ratio <= lowball) {
      verdict = DealVerdict.poor;
      reasons.add((
        id: 'lowball',
        params: {'pct': ((1 - ratio) * 100).round()},
      ));
    } else {
      verdict = DealVerdict.fair;
      reasons.add((id: 'about_right', params: <String, dynamic>{}));
    }

    // Squad consequences can override a good price — money is no use if it
    // leaves us unable to field a side.
    final mine = _ours(state, position);
    final theirRating = card != null
        ? getCardStats(card, definitionRatios: ratios).rating
        : 0;
    // The best of who we would have LEFT. Strictly greater, so a player with an
    // equal twin still on the books is not irreplaceable.
    final best = _bestRating(
      state,
      position,
      listing['cardInstanceId'] as String?,
    );

    if (mine.length <= 1 && position != null) {
      reasons.add((id: 'only_one', params: {'position': position}));
      verdict = DealVerdict.poor;
    } else if (best != null && theirRating > best) {
      reasons.add((id: 'best_in_position', params: {'position': position}));
      // Selling the best player we have is never an unqualified "take it",
      // however good the money — he used to say "strong deal, I'd take it" and
      // "he's the best we've got" in the same breath, which is not advice, it is
      // two facts contradicting each other.
      if (verdict == DealVerdict.great || verdict == DealVerdict.good) {
        verdict = DealVerdict.tempting;
      } else if (verdict == DealVerdict.fair) {
        verdict = DealVerdict.poor;
      }
    } else if (mine.length >= glutAt) {
      reasons.add((
        id: 'glut_sell',
        params: {'position': position, 'n': mine.length},
      ));
      if (verdict == DealVerdict.fair) verdict = DealVerdict.good;
    }

    return (
      verdict: verdict,
      reasons: reasons,
      suggestedAsk: suggestedAskFor(listing),
      suggestedOffer: 0,
    );
  }

  // ── Buying: they are offering us someone ──────────────────────────────────
  final price = _num(listing['price']) ?? 0;
  final coins = _num(_map(state['resources'])?['fanCoins']) ?? 0;
  final theirCard = CardInstance.from(listing['card']);
  final fair = theirCard != null ? playerValue(state, theirCard) : 0;
  final ratio = fair > 0 ? price / fair : 1;

  DealVerdict verdict;
  if (ratio <= 1 / overOdds) {
    verdict = DealVerdict.great;
    reasons.add((id: 'bargain', params: {'pct': ((1 - ratio) * 100).round()}));
  } else if (ratio >= 1 / lowball) {
    verdict = DealVerdict.poor;
    reasons.add((
      id: 'overpriced',
      params: {'pct': ((ratio - 1) * 100).round()},
    ));
  } else {
    verdict = DealVerdict.fair;
    reasons.add((id: 'about_right', params: <String, dynamic>{}));
  }

  // Can we afford it at all? Not blocked — that is the engine's call — but worth
  // saying before he talks about whether the player is any good.
  //
  // UNREACHABLE, and ported anyway: both buy-side kinds gate on the same
  // comparison, so a price above the balance has already come back blocked. See
  // the dead branches in docs/REMAINING.md.
  if (price > coins) {
    reasons.insert(0, (id: 'too_dear', params: {'short': price - coins}));
    verdict = DealVerdict.poor;
  }

  final theirRating = theirCard != null
      ? getCardStats(theirCard, definitionRatios: ratios).rating
      : 0;
  final best = _bestRating(state, position);
  final mine = _ours(state, position);
  // Would he get in the side? Nobody there at all counts — anyone beats nobody.
  final improves = best == null || theirRating >= best * (1 + meaningful);

  if (best == null && position != null) {
    // Nobody at all in that slot — a genuine hole in the squad.
    reasons.add((id: 'position_gap', params: {'position': position}));
    if (verdict == DealVerdict.fair) verdict = DealVerdict.good;
  } else if (improves) {
    reasons.add((id: 'upgrade', params: {'position': position}));
    if (verdict == DealVerdict.fair) verdict = DealVerdict.good;
  } else if (mine.length < coverAt && position != null) {
    // He would not start, but there is nobody behind the man who does, and an
    // injury there leaves a hole. Cover is a real job, so this is "your call"
    // rather than a no — it is NOT an endorsement, hence the cap.
    reasons.add((id: 'needs_cover', params: {'position': position}));
    verdict = _capAt(verdict, DealVerdict.fair);
  } else if (position != null) {
    // Does not improve the eleven and we already have cover there. The PRICE is
    // beside the point: a bargain on someone who cannot get in the side is not a
    // bargain, which is how a silver read as a deal worth doing to a squad of
    // legends. Colin's job here is to say he is not our standard, and stop.
    reasons.add((id: 'below_standard', params: {'position': position}));
    verdict = DealVerdict.poor;
  }

  // A fourth centre-half is not what we need, however good the price.
  if (mine.length >= glutAt && position != null) {
    reasons.add((
      id: 'glut_buy',
      params: {'position': position, 'n': mine.length},
    ));
    verdict = _capAt(verdict, DealVerdict.fair);
  }

  // Room is a hard fact and belongs near the top when it bites.
  //
  // Also unreachable: the squad cap is thirty and the grid is fifteen cells, so
  // free slots cannot reach zero while a signing is still allowed — a full grid
  // comes back blocked instead.
  if (_freeSlots(state) == 0) {
    reasons.insert(0, (id: 'no_room', params: <String, dynamic>{}));
  }

  // Naming a price is only useful where we can actually name one. Saying "too
  // dear" and stopping there tells the player the problem and withholds the
  // move, which is the one thing a coach is for.
  final haggleable = listing['kind'] == 'signing' || listing['kind'] == 'loan';
  final wantsANumber =
      haggleable &&
      reasons.any((r) => r.id == 'overpriced' || r.id == 'too_dear');
  return (
    verdict: verdict,
    reasons: reasons,
    suggestedAsk: 0,
    suggestedOffer: wantsANumber ? suggestedOfferFor(listing) : 0,
  );
}
