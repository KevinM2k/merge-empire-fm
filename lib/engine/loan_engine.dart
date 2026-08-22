/// Loans — temporary players, priced in matches. Ported from
/// `../merge-empire-fc/src/engine/loanEngine.js`.
///
/// A loanee is an ordinary grid instance carrying three extra fields:
///
///   borrowed          the badge flag the tutorial already uses
///   loanMatchesLeft   games remaining; THIS is what makes it a real loan
///   loanWage          coins, charged out of the income rate
///
/// `loanMatchesLeft` is deliberately the discriminator rather than `borrowed`.
/// The tutorial drops `borrowed` cards on the grid and removes them in its own
/// step, and those must not be touched by any of this — no wages, no countdown,
/// no early departure. Anything with `loanMatchesLeft` is a real loan; anything
/// with only `borrowed` is the tutorial's business.
///
/// Loanees are excluded from merging, selling, ageing, transfer offers and
/// auto-sell. They are not yours: you can play them, and that is all.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/loans.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/transfer_market.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/engine/merge_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;

/// Mirrors the Deadline Day ceiling — T9 stays scout-only and uncraftable, so
/// no amount of tier lift may reach it.
const int maxLoanTier = 8;

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

List<CardInstance?> _cells(Map<String, dynamic>? state) {
  final cells = _map(state?['grid'])?['cells'];
  if (cells is! List) return const [];
  return [for (final c in cells) CardInstance.from(c)];
}

/// Is this a real loan? Tutorial `borrowed` cards deliberately answer false.
bool isLoan(CardInstance? card) => card?.raw['loanMatchesLeft'] != null;

/// Live loans on the grid, with their cell index.
List<({CardInstance card, int idx})> activeLoans(Map<String, dynamic>? state) {
  final cells = _cells(state);
  return [
    for (var i = 0; i < cells.length; i++)
      if (isLoan(cells[i])) (card: cells[i]!, idx: i),
  ];
}

/// What a loanee of this definition would cost per second.
///
/// **Priced off the DEFINITION**, so a listing can be quoted before the card
/// exists — see `loanWagePerSec` for why the card's own income is the wrong
/// number. Both the Deadline Day card and its end-of-night summary need exactly
/// this, and each was building the throwaway instance itself.
///
/// A per-MATCH total used to live here instead, summing the `loanWage` stamped
/// on each card. Nothing has charged that field since wages became a drain on
/// the income rate: it is the terms, not the bill.
double loanWageRateFor(Map<String, dynamic>? state, Object? definitionId) =>
    loanWagePerSec(
      state,
      CardInstance(<String, dynamic>{
        'loanMatchesLeft': 1,
        'definitionId': definitionId,
      }),
    );

num _matchIncome(Map<String, dynamic>? state) =>
    getDivision(_map(state?['progression'])?['currentDivision'] as String? ?? '')
        .matchRevenueBase;

/// Loans price against MATCH INCOME, not card value.
num loanFee(Map<String, dynamic>? state) =>
    math.max(1, roundCoins(_matchIncome(state) * loanFeeRate));

num loanWage(Map<String, dynamic>? state) =>
    math.max(1, roundCoins(_matchIncome(state) * loanWageRate));

/// The tier a loanee is drawn from — one above the division's own ceiling.
int loanTierFor(Map<String, dynamic>? state) {
  final div = getDivision(
    _map(state?['progression'])?['currentDivision'] as String? ?? '',
  );
  return math.max(1, math.min(maxLoanTier, div.maxPlayerTier + loanTierLift));
}

/// A random definition at the loan tier, or null if that tier is empty.
PlayerDef? pickLoanee(Map<String, dynamic>? state) {
  final pool = getPlayersByTier(loanTierFor(state));
  return pool.isEmpty ? null : seeded.pickRandom(pool);
}

typedef Gate = ({bool ok, String? reason});

/// Can another loan be taken? Checked before offering one and again on accept,
/// because a Deadline Day feed can go stale between the two.
Gate canLoan(Map<String, dynamic> state) {
  if (activeLoans(state).length >= maxActiveLoans) {
    return (ok: false, reason: 'max_loans');
  }

  final cells = _map(state['grid'])?['cells'];
  final occupied = _cells(state).where((c) => c != null).length;
  if (occupied >= getMaxPlayers(state)) return (ok: false, reason: 'squad_full');
  if (cells is! List || findFirstEmpty(cells) == -1) {
    return (ok: false, reason: 'squad_full');
  }
  return (ok: true, reason: null);
}

/// Puts a loanee on the grid. The fee is charged here; wages come out of the
/// income rate from then on.
({bool ok, String? reason, CardInstance? card, int? idx, num? fee, num? wage})
grantLoan(
  Map<String, dynamic> state,
  String definitionId, {
  num? fee,
  num? wage,
  int matches = loanMatches,
  String? fromTeam,
}) {
  final def = getPlayerDef(definitionId);
  if (def == null) {
    return (ok: false, reason: 'unknown_definition', card: null, idx: null, fee: null, wage: null);
  }

  final gate = canLoan(state);
  if (!gate.ok) {
    return (ok: false, reason: gate.reason, card: null, idx: null, fee: null, wage: null);
  }

  final cost = fee ?? loanFee(state);
  final resources = _map(state['resources']) ?? <String, dynamic>{};
  if ((_num(resources['fanCoins']) ?? 0) < cost) {
    return (ok: false, reason: 'not_enough_coins', card: null, idx: null, fee: null, wage: null);
  }

  final cells = _map(state['grid'])!['cells'] as List;
  final idx = findFirstEmpty(cells);
  final card = createInstance(definitionId);

  card.raw['borrowed'] = true;
  card.raw['loanMatchesLeft'] = matches;
  card.raw['loanTotalMatches'] = matches; // for the "3 of 10" badge
  card.raw['loanWage'] = wage ?? loanWage(state);
  card.raw['loanFrom'] = fromTeam;

  cells[idx] = card.raw;
  resources['fanCoins'] = (_num(resources['fanCoins']) ?? 0) - cost;

  emit('loan:granted', {
    'card': card,
    'idx': idx,
    'fee': cost,
    'wage': card.raw['loanWage'],
    'matches': matches,
  });
  emit('coins:updated', resources['fanCoins']);

  return (
    ok: true,
    reason: null,
    card: card,
    idx: idx,
    fee: cost,
    wage: _num(card.raw['loanWage']),
  );
}

/// Pulls a loanee off the grid and out of the lineup.
CardInstance? _removeLoan(Map<String, dynamic> state, int idx) {
  final cells = _map(state['grid'])?['cells'];
  if (cells is! List || idx >= cells.length) return null;

  final card = CardInstance.from(cells[idx]);
  if (card == null) return null;
  cells[idx] = null;

  final lineup = _map(state['squad'])?['lineup'];
  if (lineup is List) {
    for (final slot in lineup) {
      final s = _map(slot);
      if (s != null && s['cardInstanceId'] == card.instanceId) {
        s['cardInstanceId'] = null;
      }
    }
  }
  return card;
}

/// What a settled match did to the loan book.
typedef LoanReport = ({
  num wagesPaid,
  List<({String name, String reason, CardInstance card})> departed,
  num feesEarned,
  List<({String name, String? toTeam, CardInstance card})> returned,
});

/// Settles every live loan against one played match: burn a game off the
/// counter and send home anyone whose spell is up.
///
/// Every match burns a game off every loan, whether or not the loanee started.
/// Counting only appearances would mean benching a loanee freezes the spell,
/// which turns a rental into a hoard.
///
/// NO WAGE IS CHARGED HERE. Wages come out of the income rate every second, so
/// taking them again at full time would bill the same player twice.
/// Affordability is enforced continuously by [enforceLoanWages] instead.
LoanReport settleLoanMatch(Map<String, dynamic> state) {
  // Loans out settle on the same match, first, so a fee is banked before any
  // wage pressure is judged.
  final out = settleLoanOutMatch(state);

  final departed = <({String name, String reason, CardInstance card})>[];
  final loans = activeLoans(state);

  for (final l in loans) {
    final left = (_num(l.card.raw['loanMatchesLeft']) ?? 0) - 1;
    l.card.raw['loanMatchesLeft'] = left;
    if (left <= 0) {
      final gone = _removeLoan(state, l.idx);
      if (gone != null) {
        departed.add((name: gone.name('Loanee'), reason: 'expired', card: gone));
        emit('loan:expired', {'card': gone});
      }
    }
  }

  final report = (
    wagesPaid: 0 as num,
    departed: departed,
    feesEarned: out.feesEarned,
    returned: out.returned,
  );

  if (departed.isNotEmpty) emit('loan:departed', report);
  return report;
}

void _addGrudge(Map<String, dynamic> state, String team, String reason) {
  var market = _map(state['transferMarket']);
  if (market == null) {
    market = <String, dynamic>{'pendingOffer': null, 'grudges': <String, dynamic>{}};
    state['transferMarket'] = market;
  }
  var grudges = _map(market['grudges']);
  if (grudges == null) {
    grudges = <String, dynamic>{};
    market['grudges'] = grudges;
  }
  grudges[team] = <String, dynamic>{
    'matchesLeft': grudgeMatchDuration,
    'boost': grudgeRatingBoost,
    'reason': reason,
  };
}

/// Sends loanees home while the squad cannot cover their wages.
///
/// Wages are a per-second drain and the net rate floors at zero rather than
/// eating the balance — so "cannot pay" is not an empty wallet, it is wages
/// that outrun what the squad earns. A player who never opens the game cannot
/// be quietly bankrupted; they just stop earning, and the lender takes its
/// player back.
///
/// The most expensive goes first and the check repeats, so a squad holding two
/// loans gives up the one that fixes the problem rather than both.
List<({CardInstance card, String name, String? from})> enforceLoanWages(
  Map<String, dynamic> state,
) {
  final departed = <({CardInstance card, String name, String? from})>[];

  // Bounded: one loan leaves per pass and the cap is small, but the guard means
  // a non-finite rate can never spin this forever.
  for (var guard = 0; guard < 8; guard++) {
    if (totalLoanWagePerSec(state) <= grossIncomePerSec(state)) break;

    final loans = activeLoans(state);
    if (loans.isEmpty) break;

    var worst = loans.first;
    for (final l in loans) {
      if (loanWagePerSec(state, l.card) > loanWagePerSec(state, worst.card)) {
        worst = l;
      }
    }

    final from = worst.card.raw['loanFrom'] as String?;
    final gone = _removeLoan(state, worst.idx);
    if (gone == null) break;

    if (from != null) {
      _addGrudge(state, from, "Could not pay ${gone.name('a loanee')}'s wages");
    }
    departed.add((card: gone, name: gone.name('Loanee'), from: from));
    emit('loan:recalled', {'card': gone, 'reason': 'unpaid', 'fromTeam': from});
  }
  return departed;
}

// ── Loaning players OUT ─────────────────────────────────────────────────────

/// Is this player currently away at another club?
bool isLoanedOut(CardInstance? card) => card?.loanedOut != null;

List<({CardInstance card, int idx})> loansOut(Map<String, dynamic>? state) {
  final cells = _cells(state);
  return [
    for (var i = 0; i < cells.length; i++)
      if (isLoanedOut(cells[i])) (card: cells[i]!, idx: i),
  ];
}

/// A card's fair value before any premium — the same anchor the sell screen and
/// Deadline Day price off, so a loan sits in one economy.
num _fairValue(Map<String, dynamic>? state, PlayerDef def, CardInstance card) {
  final tierMult = transferTierMultiplier[def.tier] ?? 4;
  final div = getDivision(
    _map(state?['progression'])?['currentDivision'] as String? ?? '',
  );
  final divMult = math.pow(div.matchRevenueBase / 100, 0.35).toDouble();
  final base = def.sellValue * tierMult * divMult;

  final aging = agingPenalty(card.seasonsPlayed);
  // A veteran is worth less to borrow for the same reason he sells for less.
  if (aging > 0 && def.rating > 0) {
    return base * math.max(0.2, (def.rating - aging) / def.rating);
  }
  return base;
}

/// What a rival pays us per match: a share of market value spread across the
/// spell, so lending a star is a real trade and lending filler is not free
/// money. The old income-scale rate survives as a floor for the early game.
num loanOutFee(Map<String, dynamic>? state, CardInstance? card) {
  final def = getPlayerDef(card?.definitionId);
  if (def == null || card == null) return 0;

  final div = getDivision(
    _map(state?['progression'])?['currentDivision'] as String? ?? '',
  );
  final ratio = math.max(
    loanOutTierMin,
    math.min(loanOutTierMax, def.tier / div.maxPlayerTier),
  );
  final floor = div.matchRevenueBase * loanOutFeeRate * ratio;
  final value = _fairValue(state, def, card) * loanOutValueShare / loanOutMatches;

  return math.max(1, roundCoins(math.max(floor, value)));
}

/// Can this player be sent out right now?
Gate canLoanOut(Map<String, dynamic> state, CardInstance? card) {
  if (card == null) return (ok: false, reason: 'unknown_card');
  if (isLoanedOut(card)) return (ok: false, reason: 'already_out');
  // Not ours to lend on.
  if (card.raw['loanMatchesLeft'] != null) return (ok: false, reason: 'loan_card');
  if (card.injured) return (ok: false, reason: 'injured');
  if (loansOut(state).length >= maxLoansOut) {
    return (ok: false, reason: 'max_loans_out');
  }

  // Never lend away the last player who could actually take the field.
  final available = _cells(state)
      .where((c) => c != null && !isLoanedOut(c) && !c.listed)
      .length;
  if (available <= 1) return (ok: false, reason: 'last_player');

  return (ok: true, reason: null);
}

/// Sends a player out on loan. They leave the XI immediately.
///
/// PAID UP FRONT: the borrowing club settles the whole spell the moment the
/// player walks, rather than dripping a fee in per match. A lump is a decision
/// you can feel at the point you make it, where a trickle was money arriving
/// with no connection to anything — and we keep earning the player's idle
/// income while they are away, so a per-match drip on top made lending out a
/// slow, invisible yes rather than a trade.
({bool ok, String? reason, CardInstance? card, num? feePerMatch, int? matches, num? upFront})
loanOutPlayer(
  Map<String, dynamic> state,
  String instanceId, {
  String? toTeam,
  int matches = loanOutMatches,
  num? feePerMatch,
}) {
  CardInstance? card;
  for (final c in _cells(state)) {
    if (c?.instanceId == instanceId) {
      card = c;
      break;
    }
  }

  final gate = canLoanOut(state, card);
  if (!gate.ok) {
    return (ok: false, reason: gate.reason, card: null, feePerMatch: null, matches: null, upFront: null);
  }

  final perMatch = feePerMatch ?? loanOutFee(state, card);
  final upFront = math.max(1, roundCoins(perMatch * matches));

  card!.raw['loanedOut'] = <String, dynamic>{
    'toTeam': toTeam ?? 'Rival FC',
    'matchesLeft': matches,
    'totalMatches': matches,
    // Display only — what they paid, expressed per game.
    'feePerMatch': perMatch,
    'paidUpFront': upFront,
  };

  final resources = _map(state['resources']);
  if (resources != null) {
    resources['fanCoins'] = (_num(resources['fanCoins']) ?? 0) + upFront;
    emit('coins:updated', resources['fanCoins']);
  }

  // Out of the side the moment they leave — they are not available to pick.
  final lineup = _map(state['squad'])?['lineup'];
  if (lineup is List) {
    for (final slot in lineup) {
      final s = _map(slot);
      if (s != null && s['cardInstanceId'] == instanceId) {
        s['cardInstanceId'] = null;
      }
    }
  }

  emit('loanout:started', {
    'card': card,
    'toTeam': _map(card.loanedOut)?['toTeam'],
    'feePerMatch': perMatch,
    'matches': matches,
    'upFront': upFront,
  });

  return (
    ok: true,
    reason: null,
    card: card,
    feePerMatch: perMatch,
    matches: matches,
    upFront: upFront,
  );
}

/// Brings a player home.
///
/// Running the spell to its end is clean; pulling them back early is not — the
/// borrowing club planned around that player and carries a grudge into the next
/// match, the same one a snubbed transfer bid applies. A recall costs exactly
/// what breaking any other promise costs.
/// Send a borrowed player back to the club that lent them, before the spell is
/// up.
///
/// The mirror of [recallLoan] and the same question from the other end. The JS
/// does this inline in its Squad screen — pull the card out of the grid and
/// clear whatever slot it was in — which is a state change with a rule in it
/// (the lineup must not keep a hole), and that belongs here with the rest of
/// the loan bookkeeping.
///
/// The lineup is left to `syncLineupWithGrid`, which the `player:sold`
/// announcement below already drives.
({bool ok, String? reason, String? toTeam}) sendLoaneeBack(
  Map<String, dynamic> state,
  String instanceId,
) {
  final cells = _map(state['grid'])?['cells'];
  if (cells is! List) return (ok: false, reason: 'no_grid', toTeam: null);

  for (var i = 0; i < cells.length; i++) {
    final card = CardInstance.from(cells[i]);
    if (card == null || card.instanceId != instanceId) continue;
    if (!isLoan(card)) return (ok: false, reason: 'not_a_loanee', toTeam: null);

    final from = card.raw['loanFrom'] as String?;
    cells[i] = null;
    // The same announcement a sale makes: a player has left the grid, and
    // everything that keeps up with the grid needs to hear it.
    emit('player:sold', {'instanceId': instanceId, 'loanReturn': true});
    return (ok: true, reason: null, toTeam: from);
  }
  return (ok: false, reason: 'not_found', toTeam: null);
}

({bool ok, String? reason, bool early, String? toTeam, num? matchesLeft})
recallLoan(Map<String, dynamic> state, String instanceId) {
  CardInstance? card;
  for (final c in _cells(state)) {
    if (c?.instanceId == instanceId) {
      card = c;
      break;
    }
  }
  if (card == null || !isLoanedOut(card)) {
    return (ok: false, reason: 'not_loaned_out', early: false, toTeam: null, matchesLeft: null);
  }

  final lo = _map(card.loanedOut)!;
  final toTeam = lo['toTeam'] as String?;
  final matchesLeft = _num(lo['matchesLeft']) ?? 0;
  final early = matchesLeft > 0;

  card.raw.remove('loanedOut');

  if (early && toTeam != null) {
    _addGrudge(state, toTeam, "Recalled ${card.name('a player')} early");
    emit('loanout:recalled', {
      'card': card,
      'toTeam': toTeam,
      'matchesLeft': matchesLeft,
    });
  } else {
    emit('loanout:returned', {'card': card, 'toTeam': toTeam});
  }

  return (ok: true, reason: null, early: early, toTeam: toTeam, matchesLeft: matchesLeft);
}

/// Settles every loan-out against one played match: burn a game off it and
/// bring anyone home whose spell is up.
///
/// NO FEE IS BANKED HERE — the whole spell was paid up front. Saves written
/// before that shipped carry no `paidUpFront`, so they simply stop earning the
/// drip rather than being paid twice.
({num feesEarned, List<({String name, String? toTeam, CardInstance card})> returned})
settleLoanOutMatch(Map<String, dynamic> state) {
  final returned = <({String name, String? toTeam, CardInstance card})>[];

  for (final l in loansOut(state)) {
    final lo = _map(l.card.loanedOut);
    if (lo == null) continue;

    final left = (_num(lo['matchesLeft']) ?? 0) - 1;
    lo['matchesLeft'] = left;

    if (left <= 0) {
      final toTeam = lo['toTeam'] as String?;
      l.card.raw.remove('loanedOut');
      returned.add((name: l.card.name('Player'), toTeam: toTeam, card: l.card));
      emit('loanout:returned', {'card': l.card, 'toTeam': toTeam});
    }
  }

  return (feesEarned: 0 as num, returned: returned);
}
