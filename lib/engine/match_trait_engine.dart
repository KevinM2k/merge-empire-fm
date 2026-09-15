/// The second trait slot: unlocking it, rolling into it, and turning what the
/// eleven carry into the multipliers the sim actually rolls with.
///
/// **THE ONE DOOR INTO THE SIM.** `computeSquadRatings` already takes a
/// `ratingMultipliers` map by instance id, applied as a scalar on
/// `effectiveRating` — `booking_engine.bookedRatingMultipliers` is its only
/// caller today. A match trait is another contributor to that same map, which
/// is why the rating engine does not change for this feature at all, and why
/// nothing here is stamped on the match result: `match_orchestration_parity_test`
/// compares that object field for field against a node dump.
///
/// The port's own, not the JS's. `../merge-empire-fc` has one trait per card.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/match_traits.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/trait_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

/// What is true about the match right now — everything a condition can ask.
///
/// Built by the screen at each re-simulation, because that is the only moment
/// a condition can take effect: the remainder is rolled as ONE Poisson draw, so
/// a trait that lights at minute 76 pays nothing until something re-rolls what
/// is left. The kickoff flags come off the result; the rest is the screen's.
typedef MatchContext = ({
  bool isHome,
  bool isCup,
  bool isDerby,
  bool inRelegationZone,
  bool oppStronger,

  /// We are a man short — a sending-off, or an injury nobody could cover.
  bool tenMen,
  int minute,

  /// Ninety plus stoppage, so "the last fifteen" runs to the whistle.
  int fullTime,

  /// Brought on with twenty or fewer to play — Super Sub's window.
  Set<String> subbedOnLate,

  /// Booked and still on — Ice Veins' whole reason to exist.
  Set<String> cautioned,
});

CardInstance? _cardIn(Map<String, dynamic> state, String? instanceId) {
  if (instanceId == null) return null;
  final grid = state['grid'];
  final cells = grid is Map<String, dynamic> ? grid['cells'] : null;
  if (cells is! List) return null;
  for (final raw in cells) {
    final c = CardInstance.from(raw);
    if (c != null && c.instanceId == instanceId) return c;
  }
  return null;
}

/// The `{id, level}` in the second slot, or null when it is empty.
///
/// **THE SLOT IS OPEN ON EVERY CARD.** It cost a gem for a round, once per
/// card — and a merge builds a fresh card, so the gem died with the old one.
/// Asked for from the couch: no gate. The rolls stay coin-priced, like the
/// first slot's, so the second is a coin sink rather than a gem one. A save
/// that carries the old `matchSlot` flag reads the same either way.
Map<String, dynamic>? matchTraitOf(CardInstance? card) {
  final ref = card?.raw['matchTrait'];
  return ref is Map<String, dynamic> ? ref : null;
}

/// The same I / II / III odds as the first slot — about one roll in thirty
/// lands a III.
const List<double> _levelWeights = [70, 26.2, 3.8];

/// Unseeded, like `trait_engine`'s, and for the same reason: a draw from the
/// shared seeded stream would shift every later gameplay draw and break parity
/// with the JS engines.
math.Random _rng = math.Random();

/// Test seam.
void setMatchTraitRandom(math.Random rng) => _rng = rng;

void resetMatchTraitRandom() => _rng = math.Random();

typedef MatchTraitRoll = ({String id, int level});

/// Roll a trait and a level from the WHOLE pool. No position gating: a match
/// trait is about the situation, and a keeper can be a Cup Fighter too.
MatchTraitRoll rollMatchTrait() {
  final trait = matchTraitList[_rng.nextInt(matchTraitList.length)];
  final totalWeight = _levelWeights.reduce((a, b) => a + b);
  var r = _rng.nextDouble() * totalWeight;
  var levelIdx = _levelWeights.length - 1;
  for (var i = 0; i < _levelWeights.length; i++) {
    r -= _levelWeights[i];
    if (r <= 0) {
      levelIdx = i;
      break;
    }
  }
  return (id: trait.id, level: levelIdx + 1);
}

typedef MatchTraitRollResult = ({
  bool ok,

  /// `unknown_card`, `unavailable`, `locked` or `insufficient_coins`.
  String? reason,
  MatchTraitRoll? roll,

  /// A trait was overwritten — worth saying, because a roll is a gamble on a
  /// slot that may already hold something the player likes.
  bool replaced,
  num cost,
});

MatchTraitRollResult _fail(String reason, {num cost = 0}) =>
    (ok: false, reason: reason, roll: null, replaced: false, cost: cost);

/// Pay for a roll into the second slot and apply what it lands on.
///
/// Coins, through the first slot's own tier-scaled [traitRollCost] — the gem
/// bought the slot, not the rolls. The gate, the debit and the write are one
/// step, the same rule `rollTraitForCard` states: a roll that charged and then
/// failed to apply would be the worst possible bug in a paid gamble.
MatchTraitRollResult rollMatchTraitForCard(
  Map<String, dynamic> state,
  String? instanceId,
) {
  final card = _cardIn(state, instanceId);
  if (card == null) return _fail('unknown_card');
  if (card.isUnavailable || card.raw['loanMatchesLeft'] != null) {
    return _fail('unavailable');
  }

  final def = getPlayerDef(card.definitionId);
  if (def == null) return _fail('unknown_card');
  final cost = traitRollCost(def);

  final resources = state['resources'];
  final coins = resources is Map<String, dynamic> ? resources['fanCoins'] : null;
  if (coins is! num || coins < cost) {
    return _fail('insufficient_coins', cost: cost);
  }

  final roll = rollMatchTrait();
  final replaced = card.raw['matchTrait'] != null;
  card.raw['matchTrait'] = <String, dynamic>{'id': roll.id, 'level': roll.level};
  // Whole, like every other coin write: coins are the most-written field in
  // the save and the JS holds them as integers.
  (resources as Map<String, dynamic>)['fanCoins'] = (coins - cost).toInt();

  emit('coins:updated', resources['fanCoins']);
  emit('match_trait:rolled', {
    'instanceId': card.instanceId,
    'id': roll.id,
    'level': roll.level,
    'replaced': replaced,
  });

  return (ok: true, reason: null, roll: roll, replaced: replaced, cost: cost);
}

/// The eleven a trait can act through: the lineup's healthy men, in order.
///
/// **A lineup, not the grid.** A Cup Fighter sat on the bench does not fight,
/// which is the same convention `computeSquadTraitTotals` applies to the first
/// slot's squad-wide effects. Falls back to the healthy top of the grid only
/// when there is no lineup at all, as the squad ratings do.
List<CardInstance> _fielded(
  List<CardInstance?> cells,
  List<Map<String, dynamic>>? lineup,
) {
  final cards = cells.whereType<CardInstance>().toList();
  if (lineup != null && lineup.isNotEmpty) {
    final byId = {for (final c in cards) c.instanceId: c};
    return [
      for (final slot in lineup)
        if (slot['cardInstanceId'] case final String id)
          if (byId[id] case final card?)
            if (!card.injured && !card.isUnavailable) card,
    ];
  }
  return cards.where((c) => !c.injured && !c.isUnavailable).take(11).toList();
}

/// Resolve one man's slot to the level that would pay, or null.
MatchTraitLevel? _levelOf(CardInstance card) {
  final ref = matchTraitOf(card);
  if (ref == null) return null;
  final trait = getMatchTrait(ref['id'] as String?);
  return getMatchTraitLevel(trait, (ref['level'] as num?)?.toInt() ?? 0);
}

/// Does this man's condition hold right now? Squad-wide and non-rating
/// conditions answer false here — they are not "his" lift.
bool _lit(MatchTraitCondition c, CardInstance card, MatchContext ctx) =>
    switch (c) {
      MatchTraitCondition.home => ctx.isHome,
      MatchTraitCondition.away => !ctx.isHome,
      MatchTraitCondition.cupTie => ctx.isCup,
      MatchTraitCondition.derby => ctx.isDerby,
      MatchTraitCondition.relegationZone => ctx.inRelegationZone,
      MatchTraitCondition.strongerOpponent => ctx.oppStronger,
      MatchTraitCondition.firstTwenty => ctx.minute <= 20,
      MatchTraitCondition.lastFifteen => ctx.minute >= 76,
      MatchTraitCondition.superSub => ctx.subbedOnLate.contains(card.instanceId),
      MatchTraitCondition.booked => ctx.cautioned.contains(card.instanceId),
      MatchTraitCondition.tenMen => false,
      MatchTraitCondition.injuryShrug => false,
    };

/// Turn the fielded eleven and the state of the match into rating multipliers.
///
/// Only players it CHANGES appear in the result, so merging over the booking
/// map is an `addAll` on a copy — except `ice_veins`, whose value is the
/// booking multiplier it REPLACES. The screen composes the two; this function
/// does not know what the referee has done beyond who is cautioned.
///
/// Ten Man Wall is summed over its carriers and capped BEFORE anything is
/// written, then multiplied onto every man in the lineup — a Fortress who is
/// also one of the ten keeps both.
Map<String, double> matchTraitMultipliers(
  List<CardInstance?> cells,
  List<Map<String, dynamic>>? lineup,
  MatchContext ctx,
) {
  final out = <String, double>{};
  final fielded = _fielded(cells, lineup);
  if (fielded.isEmpty) return out;

  var wall = 0.0;
  for (final card in fielded) {
    final ref = matchTraitOf(card);
    if (ref == null) continue;
    final trait = getMatchTrait(ref['id'] as String?);
    final level = _levelOf(card);
    if (trait == null || level == null) continue;

    if (trait.condition == MatchTraitCondition.tenMen) {
      if (ctx.tenMen) wall += level.mult - 1;
      continue;
    }
    if (_lit(trait.condition, card, ctx)) out[card.instanceId] = level.mult;
  }

  if (wall > 0) {
    final lift = 1 + math.min(matchTraitSquadCap, wall);
    for (final card in fielded) {
      out[card.instanceId] = (out[card.instanceId] ?? 1) * lift;
    }
  }

  return out;
}

/// Is [instanceId]'s own match trait paying right now? The bench lights his
/// badge off this. Ten Man Wall counts as lit for its carrier when the side is
/// down to ten, because that is when he is doing his job.
bool isMatchTraitLit(
  List<CardInstance?> cells,
  List<Map<String, dynamic>>? lineup,
  MatchContext ctx,
  String instanceId,
) {
  for (final card in _fielded(cells, lineup)) {
    if (card.instanceId != instanceId) continue;
    final ref = matchTraitOf(card);
    final trait = getMatchTrait(ref?['id'] as String?);
    if (trait == null || _levelOf(card) == null) return false;
    if (trait.condition == MatchTraitCondition.tenMen) return ctx.tenMen;
    return _lit(trait.condition, card, ctx);
  }
  return false;
}

/// The chance this man waves the physio away, or 0 without a Warrior in an
/// open slot. Not a rating: it hooks the injury roll, not the multiplier map.
double warriorShrugChance(CardInstance? card) {
  if (card == null) return 0;
  final ref = matchTraitOf(card);
  if (ref == null) return 0;
  final trait = getMatchTrait(ref['id'] as String?);
  if (trait?.condition != MatchTraitCondition.injuryShrug) return 0;
  return _levelOf(card)?.mult ?? 0;
}
