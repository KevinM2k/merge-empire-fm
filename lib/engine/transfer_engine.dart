/// Rival transfer offers and grudges, ported from
/// `../merge-empire-fc/src/engine/transferEngine.js`.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/transfer_market.dart';
import 'package:merge_empire_fc/engine/lineup_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

int _agingPenalty(int seasonsPlayed) =>
    seasonsPlayed <= 10 ? 0 : (seasonsPlayed - 10) * 10;

Map<String, dynamic> ensureMarket(Map<String, dynamic> state) {
  var market = _map(state['transferMarket']);
  if (market == null) {
    market = <String, dynamic>{
      'pendingOffer': null,
      'grudges': <String, dynamic>{},
      'lastOfferAt': 0,
    };
    state['transferMarket'] = market;
  }
  if (_map(market['grudges']) == null) market['grudges'] = <String, dynamic>{};
  market['lastOfferAt'] ??= 0;
  return market;
}

List<CardInstance?> _cells(Map<String, dynamic> state) {
  final cells = _map(state['grid'])?['cells'];
  if (cells is! List) return const [];
  return [for (final c in cells) CardInstance.from(c)];
}

/// Which rung of the pyramid a club sits on, as an index into the ladder, or
/// null if we have never heard of them.
///
/// Walks the divisions rather than the pyramid's own keys: the pyramid is a
/// plain map and its key order is NOT the ladder's order.
int? teamDivisionIndex(Map<String, dynamic> state, String? name) {
  final pyramid = _map(_map(state['progression'])?['leaguePyramid']);
  if (pyramid == null || name == null) return null;

  for (var i = 0; i < divisions.length; i++) {
    final teams = pyramid[divisions[i].id];
    if (teams is! List) continue;
    for (final t in teams) {
      if (_map(t)?['name'] == name) return i;
    }
  }
  return null;
}

/// Picks a rival to bid.
///
/// ANY club across the pyramid is fair game, not just same-league opponents.
/// Clubs already nursing a grudge are skipped — they are cross with us, they
/// are not bidding — and bids bias toward higher-league clubs, who have bigger
/// budgets.
///
/// DEVIATION FROM THE JS, deliberate: the original derived each club's division
/// index from the pyramid's key ORDER, while the same file's
/// `teamDivisionIndex` documents that key order is not the ladder's order. The
/// weighting was therefore keyed on insertion order rather than league level,
/// so "higher divisions bid more" was not reliably true. This walks the ladder.
String pickOfferingRival(Map<String, dynamic> state) {
  // ensureMarket rather than a bare read: Deadline Day calls this on states
  // that may never have been through a transfer flow.
  final market = ensureMarket(state);
  final grudges = _map(market['grudges']) ?? const {};
  final progression = _map(state['progression']);
  final pyramid = _map(progression?['leaguePyramid']);

  final allTeams = <({String name, int weight})>[];
  if (pyramid != null) {
    for (var divIdx = 0; divIdx < divisions.length; divIdx++) {
      final teams = pyramid[divisions[divIdx].id];
      if (teams is! List) continue;
      for (final t in teams) {
        final name = _map(t)?['name'];
        if (name is! String || name.isEmpty) continue;
        if (grudges.containsKey(name)) continue;
        allTeams.add((name: name, weight: divIdx + 1));
      }
    }
  }

  // Fall back to current-season opponents if the pyramid is not built yet.
  if (allTeams.isEmpty) {
    final opponents = progression?['seasonOpponents'];
    final pool = <String>[
      if (opponents is List)
        for (final n in opponents)
          if (n is String && n.isNotEmpty && !grudges.containsKey(n)) n,
    ];
    if (pool.isEmpty) return 'Rival FC';
    return pool[seeded.randomInt(0, pool.length - 1)];
  }

  final total = allTeams.fold<int>(0, (s, t) => s + t.weight);
  var r = seeded.random() * total;
  for (final t in allTeams) {
    r -= t.weight;
    if (r <= 0) return t.name;
  }
  return allTeams.last.name;
}

/// Builds an offer and writes it to state, or returns null when no valid target
/// exists. Does NOT check the trigger chance — callers decide when to fire.
Map<String, dynamic>? buildOffer(
  Map<String, dynamic> state, {
  num opponentRating = 55,
  String? fromTeam,
}) {
  final market = ensureMarket(state);
  if (market['pendingOffer'] != null) return null; // one at a time

  final cells = _cells(state);

  final eligible = <({CardInstance card, PlayerDef def})>[];
  for (final c in cells) {
    if (c == null || c.injured) continue;
    // Loanees are not ours to sell — a rival bidding for someone else's player
    // would be nonsense, and accepting would pay us for a card we do not own.
    if (c.raw['loanMatchesLeft'] != null) continue;
    final def = getPlayerDef(c.definitionId);
    if (def == null || def.tier < transferMinTier) continue;
    eligible.add((card: c, def: def));
  }
  if (eligible.isEmpty) return null;

  // Never leave the player unable to field a side.
  final healthy = cells.where((c) => c != null && !c.injured).length;
  if (healthy <= 3) return null;

  // Higher tier and sponsored make a likelier target.
  final weighted = [
    for (final e in eligible)
      (
        card: e.card,
        def: e.def,
        weight: math.pow(e.def.tier, 2).toDouble() +
            (e.card.sponsor != null ? 10 : 0),
      ),
  ];
  final totalWeight = weighted.fold<double>(0, (s, w) => s + w.weight);
  var roll = seeded.random() * totalWeight;
  var target = weighted.first;
  for (final w in weighted) {
    roll -= w.weight;
    if (roll <= 0) {
      target = w;
      break;
    }
  }

  final card = target.card;
  final def = target.def;

  // The price scales with division so it always feels meaningful against the
  // current economy, using the same power-scaled multiplier as the manual sell
  // screen so late-game offers do not reach absurd values.
  final tierMult = transferTierMultiplier[def.tier] ?? 4;
  final div = getDivision(_map(state['progression'])?['currentDivision'] as String? ?? '');
  final scaledDivMult = math.pow(div.matchRevenueBase / 100, 0.35).toDouble();

  // What a fair market sale would fetch.
  final marketBasePrice =
      roundCoins(def.sellValue * tierMult * scaledDivMult * 0.5);

  // A rival pays twice the self-sell base — always better than an average roll.
  var price = def.sellValue * tierMult * scaledDivMult * 2;

  if (_num(_map(card.sponsor)?['multiplier']) != null) {
    price *= 1 + transferSponsorBonus;
  }

  // Ageing players fetch less: their remaining seasons reduce value.
  final aging = _agingPenalty(card.seasonsPlayed);
  if (aging > 0 && def.rating > 0) {
    price *= math.max(0.2, (def.rating - aging) / def.rating);
  }

  // Stronger opponents pay a little more.
  price *= 0.9 + (opponentRating / 90) * 0.40;

  final minOffer = math.max(
    transferMinOffer,
    roundCoins(transferMinOffer * scaledDivMult),
  );
  final finalPrice = math.max(minOffer, roundCoins(price));

  final offer = <String, dynamic>{
    'offerId': 'offer_${now()}_${seeded.randomInt(0, 9999)}',
    'fromTeam': fromTeam ?? pickOfferingRival(state),
    'cardInstanceId': card.instanceId,
    'definitionId': card.definitionId,
    'playerName': card.name(),
    'tier': def.tier,
    'tierName': def.tierName,
    'sellValue': marketBasePrice,
    'marketBasePrice': marketBasePrice,
    'price': finalPrice,
    'sponsored': card.sponsor != null,
    'sponsorName': _map(card.sponsor)?['name'],
    'variant': (_num(card.raw['variant']) ?? 0).toInt(),
    'createdAt': now(),
  };

  market['pendingOffer'] = offer;
  market['lastOfferAt'] = now();
  return offer;
}

/// Holds off any new offer until the player has completed the first match of
/// the new season.
void holdOffersForNewSeason(Map<String, dynamic> state) {
  ensureMarket(state)['holdUntilNextMatch'] = true;
}

/// Post-match trigger. The offering rival is random — any club in the pyramid —
/// NOT the opponent just faced.
Map<String, dynamic>? maybeGenerateOffer(
  Map<String, dynamic> state, {
  num? opponentRating,
}) {
  // Nothing lands during the tutorial: it has the player play a match, and a
  // post-match bid must not arrive in the middle of it.
  if (_map(state['tutorial'])?['done'] != true) return null;

  final market = ensureMarket(state);

  // First match of a new season: clear the hold and skip this one game, so a
  // bid cannot land before the player has played into the new campaign.
  if (market['holdUntilNextMatch'] == true) {
    market['holdUntilNextMatch'] = false;
    return null;
  }
  if (market['pendingOffer'] != null) return null;

  final hasSponsored = _cells(state).any((c) => c?.sponsor != null);
  final chance = transferMatchTriggerChance +
      (hasSponsored ? transferSponsorTriggerBonus : 0);
  if (seeded.random() >= chance) return null;

  return buildOffer(state, opponentRating: opponentRating ?? 55);
}

/// Idle trigger, called by the main tick.
///
/// The interval gate is the primary throttle; the chance check adds jitter so
/// offers do not arrive at perfectly predictable times.
Map<String, dynamic>? maybeGenerateIdleOffer(Map<String, dynamic> state) {
  if (_map(state['tutorial'])?['done'] != true) return null;

  final market = ensureMarket(state);
  if (market['holdUntilNextMatch'] == true) return null;

  // Clear a stale pending offer. Five minutes without a response is a timeout,
  // treated as a decline so ignoring one has stakes.
  final pending = _map(market['pendingOffer']);
  if (pending != null) {
    final cardId = pending['cardInstanceId'];
    final cardGone = !_cells(state).any((c) => c?.instanceId == cardId);
    final age = now() - (_num(pending['createdAt']) ?? 0);

    if (cardGone) {
      market['pendingOffer'] = null;
    } else if (age > 5 * 60 * 1000) {
      final fromTeam = pending['fromTeam'] as String;
      (_map(market['grudges']) ?? {})[fromTeam] = <String, dynamic>{
        'matchesLeft': grudgeMatchDuration,
        'boost': grudgeRatingBoost,
        'reason': 'Ignored ${pending['playerName']} transfer',
      };
      market['pendingOffer'] = null;
      emit('transfer:offer-expired', {'fromTeam': fromTeam});
    } else {
      return null;
    }
  }

  if (now() - (_num(market['lastOfferAt']) ?? 0) < transferIdleMinIntervalMs) {
    return null;
  }
  if (seeded.random() >= transferIdleTriggerChance) return null;

  return buildOffer(state, opponentRating: 60);
}

/// When a rival buys one of our players they slot the signing into their
/// weakest key position and get STRONGER, for good — modelling one of five key
/// slots being filled.
///
/// A 50-rated side buying a 90-rated star jumps to about 58; a strong side
/// buying a near-equal player barely moves. Never negative, so a rival cannot
/// get worse from a signing.
int _blendUp(num current, num playerRating) =>
    math.max(current, (current * 4 + playerRating) / 5).round();

/// Raises the buyer's rating persistently in the pyramid — so it carries across
/// seasons and applies even to a cross-division buyer — and mirrors it onto the
/// current season when the buyer is a league rival, so it is felt immediately
/// in the fixtures still to come.
({num? before, num? after}) applyRivalPlayerBoost(
  Map<String, dynamic> state,
  String fromTeam,
  num playerRating,
) {
  num? before;
  num? after;

  final progression = _map(state['progression']);
  final pyramid = _map(progression?['leaguePyramid']);

  if (pyramid != null) {
    for (final teams in pyramid.values) {
      if (teams is! List) continue;
      Map<String, dynamic>? found;
      for (final t in teams) {
        if (_map(t)?['name'] == fromTeam) {
          found = _map(t);
          break;
        }
      }
      if (found != null) {
        before = _num(found['rating']) ?? 50;
        after = math.min(100, _blendUp(before, playerRating));
        found['rating'] = after;
        break;
      }
    }
  }

  final opponents = progression?['seasonOpponents'];
  final oppIdx = opponents is List ? opponents.indexOf(fromTeam) : -1;
  if (oppIdx >= 0 && progression != null) {
    final season = _num(progression['seasonCount'])?.toInt() ?? 1;
    final ratings = _map(progression['seasonOpponentRatings']) ??
        (progression['seasonOpponentRatings'] = <String, dynamic>{})
            as Map<String, dynamic>;
    final key = 's${season}_o$oppIdx';
    final cur = _num(ratings[key]) ?? before ?? 50;
    final newRating = _blendUp(cur, playerRating);
    ratings[key] = newRating;
    if (before == null) {
      before = cur;
      after = newRating;
    }
  }

  return (before: before, after: after);
}

/// Accepts the pending offer: removes the card, pays us, and strengthens the
/// buyer.
({bool ok, String? reason, num? price, String? playerName, String? fromTeam})
acceptOffer(Map<String, dynamic> state) {
  final market = ensureMarket(state);
  final offer = _map(market['pendingOffer']);
  if (offer == null) {
    return (ok: false, reason: 'no_offer', price: null, playerName: null, fromTeam: null);
  }

  final cells = _map(state['grid'])?['cells'];
  if (cells is! List) {
    return (ok: false, reason: 'card_gone', price: null, playerName: null, fromTeam: null);
  }

  final idx = cells.indexWhere(
    (c) => CardInstance.from(c)?.instanceId == offer['cardInstanceId'],
  );
  if (idx == -1) {
    // Sold or merged away before the offer resolved — scrap it.
    market['pendingOffer'] = null;
    return (ok: false, reason: 'card_gone', price: null, playerName: null, fromTeam: null);
  }

  final playerRating = getPlayerDef(offer['definitionId'] as String?)?.rating ?? 50;
  cells[idx] = null;

  final squad = _map(state['squad']);
  final lineup = squad?['lineup'];
  if (lineup is List) {
    for (final slot in lineup) {
      final s = _map(slot);
      if (s != null && s['cardInstanceId'] == offer['cardInstanceId']) {
        s['cardInstanceId'] = null;
      }
    }
    // Selling a starter must not leave the XI a man short — promote his cover.
    refillLineupFromBench(state);
  }

  final resources = _map(state['resources']);
  if (resources != null) {
    resources['fanCoins'] =
        (_num(resources['fanCoins']) ?? 0) + (_num(offer['price']) ?? 0);
  }

  final boost = applyRivalPlayerBoost(
    state,
    offer['fromTeam'] as String,
    playerRating,
  );
  market['pendingOffer'] = null;

  final stats = _map(state['stats']);
  if (stats != null) {
    stats['transfersAccepted'] = (_num(stats['transfersAccepted']) ?? 0) + 1;
  }

  emit('player:sold', {
    'definitionId': offer['definitionId'],
    'tier': offer['tier'],
    'price': offer['price'],
  });
  emit('transfer:accepted', {...offer, 'ratingBoost': boost});

  return (
    ok: true,
    reason: null,
    price: _num(offer['price']),
    playerName: offer['playerName'] as String?,
    fromTeam: offer['fromTeam'] as String?,
  );
}

/// Declines the pending offer, adding a grudge — the match engine gives that
/// rival a rating boost the next time we face them.
({bool ok, String? reason, String? fromTeam, num? boost}) declineOffer(
  Map<String, dynamic> state,
) {
  final market = ensureMarket(state);
  final offer = _map(market['pendingOffer']);
  if (offer == null) {
    return (ok: false, reason: 'no_offer', fromTeam: null, boost: null);
  }

  (_map(market['grudges']) ?? {})[offer['fromTeam'] as String] =
      <String, dynamic>{
        'matchesLeft': grudgeMatchDuration,
        'boost': grudgeRatingBoost,
        'reason': 'Snubbed ${offer['playerName']} transfer',
      };
  market['pendingOffer'] = null;

  final stats = _map(state['stats']);
  if (stats != null) {
    stats['transfersDeclined'] = (_num(stats['transfersDeclined']) ?? 0) + 1;
  }

  emit('transfer:declined', offer);
  return (
    ok: true,
    reason: null,
    fromTeam: offer['fromTeam'] as String?,
    boost: grudgeRatingBoost,
  );
}

/// Called by the match engine at kickoff. Returns the rating boost a nursed
/// grudge grants and decrements its remaining matches, removing it when spent.
num consumeGrudge(Map<String, dynamic> state, String? opponentName) {
  final grudges = _map(_map(state['transferMarket'])?['grudges']);
  if (grudges == null || opponentName == null) return 0;

  final g = _map(grudges[opponentName]);
  if (g == null) return 0;

  final boost = _num(g['boost']) ?? 0;
  final left = (_num(g['matchesLeft']) ?? 1) - 1;
  g['matchesLeft'] = left;
  if (left <= 0) grudges.remove(opponentName);
  return boost;
}

/// Call when a card leaves the grid by any means other than accepting the
/// offer. If it had a pending bid, the offering club is furious — the same
/// grudge as a decline. Returns the club's name, or null.
String? notifyCardRemoved(Map<String, dynamic> state, String instanceId) {
  final market = _map(state['transferMarket']);
  final pending = _map(market?['pendingOffer']);
  if (market == null || pending == null) return null;
  if (pending['cardInstanceId'] != instanceId) return null;

  final fromTeam = pending['fromTeam'] as String;
  final grudges = _map(market['grudges']) ??
      (market['grudges'] = <String, dynamic>{}) as Map<String, dynamic>;

  grudges[fromTeam] = <String, dynamic>{
    'matchesLeft': grudgeMatchDuration,
    'boost': grudgeRatingBoost,
    'reason': 'Snubbed ${pending['playerName']} transfer',
  };
  market['pendingOffer'] = null;

  final stats = _map(state['stats']);
  if (stats != null) {
    stats['transfersDeclined'] = (_num(stats['transfersDeclined']) ?? 0) + 1;
  }

  emit('transfer:declined', {
    'fromTeam': fromTeam,
    'playerName': pending['playerName'],
  });
  return fromTeam;
}

/// Peeks at a grudge without consuming it, for the next-match preview.
num peekGrudge(Map<String, dynamic> state, String? opponentName) {
  final grudges = _map(_map(state['transferMarket'])?['grudges']);
  if (grudges == null || opponentName == null) return 0;
  return _num(_map(grudges[opponentName])?['boost']) ?? 0;
}
