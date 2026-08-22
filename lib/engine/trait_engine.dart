/// Trait rolling and aggregation, ported from
/// `../merge-empire-fc/src/engine/traitEngine.js`.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/traits.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/format.dart';

/// Fallback when a tier has no entry in the cost table.
const int traitRollBaseCost = 30;

/// Roll cost scales with player tier. Each rung is roughly 15% of that
/// division's scout cost, so rolling a trait reads as a fraction of replacing
/// the card.
const Map<int, int> _traitCostByTier = {
  1: 50, // Bronze Rookie
  2: 50, // Bronze Pro
  3: 200, // Silver Rising  — ~15% of amateur_cup scout cost
  4: 500, // Silver Star    — ~15% of regional_league
  5: 2000, // Gold Elite     — ~15% of national_league
  6: 5000, // Gold Superstar — ~15% of elite_league
  7: 20000, // Legendary Icon — ~15% of continental
  8: 150000, // World Legend   — ~15% of champions_cup
  9: 400000, // Football Icon  — special tier, ~2.5x T8
};

/// Cost to roll a trait for a player.
num traitRollCost(PlayerDef? def) =>
    roundCoins(_traitCostByTier[def?.tier] ?? traitRollBaseCost);

/// Level probability weights: I = 70%, II = 26.2%, III = 3.8% — about one in
/// thirty rolls lands a III.
const List<double> _levelWeights = [70, 26.2, 3.8];

/// Trait rolls use unseeded randomness, matching the JS `Math.random()`.
/// Drawing from the shared seeded stream would shift every subsequent gameplay
/// draw and break parity with the JS engines.
math.Random _rng = math.Random();

/// Test seam. Pass a seeded generator for deterministic rolls.
void setTraitRandom(math.Random rng) => _rng = rng;

void resetTraitRandom() => _rng = math.Random();

/// A rolled trait: which one, and at what level.
typedef TraitRoll = ({String id, int level});

/// Rolls a random trait and level from the pool for [position]. Pure apart from
/// consuming the generator.
TraitRoll rollTrait(String? position, {bool hardMode = false}) {
  final pool = getTraitPoolForPosition(position, hardMode: hardMode);
  final trait = pool[_rng.nextInt(pool.length)];

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

/// Every numeric effect a card's trait provides.
class TraitBonus {
  const TraitBonus({
    this.ratingBonus = 0,
    this.atkBonus = 0,
    this.defBonus = 0,
    this.incomeBonus = 0,
    this.matchRevBonus = 0,
    this.injuryReduction = 0,
    this.teamInjuryReduction = 0,
    this.agingReduction = 0,
    this.recoveryBonus = 0,
    this.staminaMult = 1,
  });

  /// No trait, or a trait that resolves to nothing.
  static const TraitBonus zero = TraitBonus();

  /// Always zero today — no trait level authors a rating bonus — but kept so
  /// the composed rating has one place to add it if one ever does.
  final double ratingBonus;

  /// Already multiplied by [traitStatScale], and left fractional on purpose:
  /// the ATK/DEF split rounds once at the end, so a scaled bonus does not lose
  /// a point to double rounding.
  final double atkBonus;
  final double defBonus;

  final double incomeBonus;
  final double matchRevBonus;
  final double injuryReduction;
  final double teamInjuryReduction;
  final int agingReduction;
  final double recoveryBonus;

  /// Below 1 tires slower. Universal trait, so never position-gated.
  final double staminaMult;
}

/// All numeric bonuses a card's trait provides.
///
/// Position-gated traits return zero for the directional ATK/DEF bonuses when
/// the position does not match; economy, injury and aging effects always apply.
///
/// The directional bonuses come back already multiplied by [traitStatScale] —
/// anything reading them gets the real, applied number, while the authored
/// values live only in the traits table. The economy, injury, aging and stamina
/// axes are not scaled.
TraitBonus getTraitBonus(CardInstance? card, String? position) {
  final traitRef = card?.raw['trait'];
  if (traitRef is! Map) return TraitBonus.zero;

  final trait = getTrait(traitRef['id'] as String?);
  if (trait == null) return TraitBonus.zero;

  final level = (traitRef['level'] as num?)?.toInt();
  final levelDef = level == null ? null : getTraitLevel(trait, level);
  if (levelDef == null) return TraitBonus.zero;

  final posMatch =
      trait.positions == null || trait.positions!.contains(position);

  return TraitBonus(
    atkBonus: posMatch ? levelDef.atkBonus * traitStatScale : 0,
    defBonus: posMatch ? levelDef.defBonus * traitStatScale : 0,
    incomeBonus: levelDef.incomeBonus,
    matchRevBonus: levelDef.matchRevBonus,
    injuryReduction: levelDef.injuryReduction,
    teamInjuryReduction: levelDef.teamInjuryReduction,
    agingReduction: levelDef.agingReduction,
    recoveryBonus: levelDef.recoveryBonus,
    staminaMult: levelDef.staminaMult ?? 1,
  );
}

/// Squad-wide trait effects stack ADDITIVELY across the fielded XI and are then
/// capped, so a grid stuffed with one trait cannot trivialise an economy or
/// make the squad injury-proof. The caps are deliberately generous — reaching
/// them means eleven good rolls.
const double maxSquadMatchRevBonus = 0.50; // +50% match revenue
const double maxSquadInjuryReduction = 0.10; // -10 percentage points

/// The XI a trait actually acts through, or the healthy top of the grid.
List<CardInstance> _fieldedEleven(
  List<CardInstance?> gridCells,
  List<Map<String, dynamic>>? lineup, {
  bool dropInjured = false,
}) {
  final cards = gridCells.whereType<CardInstance>().toList();

  if (lineup != null && lineup.length == 11) {
    final byId = {for (final c in cards) c.instanceId: c};
    return [
      for (final slot in lineup)
        if (slot['cardInstanceId'] case final String id)
          if (byId[id] case final card?)
            if (!dropInjured || !card.injured) card,
    ];
  }

  return cards.where((c) => !c.injured).take(11).toList();
}

/// Does this card carry a real trait? `none` is the empty slot, not a trait.
bool hasTrait(CardInstance? card) {
  final trait = card?.raw['trait'];
  return trait is Map && trait['id'] != 'none';
}

/// How much of the team that actually PLAYS carries a trait.
///
/// The coach's "most of your squad is traitless" nudge used to count every card
/// in the grid, bench included, and so kept telling managers with a fully-kitted
/// XI to roll more traits. Traits only do anything for players on the pitch, so
/// the advice has to be measured over the eleven too.
({int counted, int withTrait, double ratio}) traitCoverage(
  List<CardInstance?> gridCells, [
  List<Map<String, dynamic>>? lineup,
]) {
  final fielded = _fieldedEleven(gridCells, lineup);
  final withTrait = fielded.where(hasTrait).length;
  return (
    counted: fielded.length,
    withTrait: withTrait,
    ratio: fielded.isEmpty ? 0 : withTrait / fielded.length,
  );
}

/// Aggregates the squad-wide trait effects over the players actually fielded.
///
/// Only the starting XI counts — a Commanding keeper sat on the bench does not
/// sell tickets. Falls back to the healthy top of the grid when no lineup is
/// set, the same convention the squad ratings use.
({double matchRevBonus, double teamInjuryReduction}) computeSquadTraitTotals(
  List<CardInstance?> gridCells, [
  List<Map<String, dynamic>>? lineup,
]) {
  final cards = gridCells.whereType<CardInstance>().toList();
  if (cards.isEmpty) return (matchRevBonus: 0.0, teamInjuryReduction: 0.0);

  final fielded = _fieldedEleven(gridCells, lineup, dropInjured: true);

  var matchRevBonus = 0.0;
  var teamInjuryReduction = 0.0;
  for (final card in fielded) {
    // Squad-wide effects are never position-gated, so pass the trait's own
    // first position and a position-locked trait still resolves. Null would
    // zero the directional bonuses, which are not read here anyway.
    final traitRef = card.raw['trait'];
    final traitId = traitRef is Map ? traitRef['id'] as String? : null;
    final tb = getTraitBonus(card, getTrait(traitId)?.positions?.first);
    matchRevBonus += tb.matchRevBonus;
    teamInjuryReduction += tb.teamInjuryReduction;
  }

  return (
    matchRevBonus: math.min(maxSquadMatchRevBonus, matchRevBonus),
    teamInjuryReduction: math.min(maxSquadInjuryReduction, teamInjuryReduction),
  );
}

/// `⚽ Finisher III` — the JS's own label, in the JS's own English.
///
/// **It has no caller in `lib/` and that is correct**: it is a parity function,
/// its output is pinned against the JS's, and a fixture that starts speaking
/// German is not a fixture. `ui/widgets/trait_copy.dart` is what the screens go
/// through — `traitTitle` is this, localised.
///
/// Its plain-text sibling was NOT that. `traitLabelPlain` was the port's own
/// addition, written so a caller supplying its own glyph would not render two;
/// the caller that wanted it arrived as `TraitBadge` plus `traitName`, through
/// the catalogue, and the untranslated helper sat unreachable behind it. Gone.
String traitLabel(Map<String, dynamic>? traitInstance) {
  if (traitInstance == null) return '';
  final trait = getTrait(traitInstance['id'] as String?);
  if (trait == null) return '';
  final level = (traitInstance['level'] as num?)?.toInt();
  final lvl = (level == null ? null : getTraitLevel(trait, level)?.label) ?? '';
  return lvl.isNotEmpty
      ? '${trait.icon} ${trait.name} $lvl'
      : '${trait.icon} ${trait.name}';
}

/// What a paid roll did.
typedef TraitRollResult = ({
  bool ok,

  /// `unknown_card`, `unavailable` or `insufficient_coins`.
  String? reason,
  TraitRoll? roll,

  /// A trait was overwritten. Worth saying: a roll is a gamble on a card that
  /// may already have something the player likes.
  bool replaced,
  num cost,
});

TraitRollResult _rollFail(String reason, {num cost = 0}) =>
    (ok: false, reason: reason, roll: null, replaced: false, cost: cost);

/// Pay for a roll and apply what it lands on.
///
/// The JS charges inside its roulette component, which is why the port had the
/// roll, the cost and the pool ported and nothing that could spend a coin on
/// them. The gate, the debit and the write belong together: a roll that charged
/// and then failed to apply would be the worst possible bug in a paid gamble.
///
/// A player who is not available is refused outright — a loanee is not ours to
/// improve, and one out on loan cannot take the field, so the coins would buy
/// nothing either way.
TraitRollResult rollTraitForCard(
  Map<String, dynamic> state,
  String? instanceId,
) {
  final cells = state['grid'] is Map<String, dynamic>
      ? (state['grid'] as Map<String, dynamic>)['cells']
      : null;
  CardInstance? card;
  if (cells is List) {
    for (final raw in cells) {
      final c = CardInstance.from(raw);
      if (c != null && c.instanceId == instanceId) {
        card = c;
        break;
      }
    }
  }
  if (card == null) return _rollFail('unknown_card');
  if (card.isUnavailable || card.raw['loanMatchesLeft'] != null) {
    return _rollFail('unavailable');
  }

  final def = getPlayerDef(card.definitionId);
  if (def == null) return _rollFail('unknown_card');
  final cost = traitRollCost(def);

  final resources = state['resources'];
  final coins = resources is Map<String, dynamic>
      ? resources['fanCoins']
      : null;
  if (coins is! num || coins < cost) {
    return _rollFail('insufficient_coins', cost: cost);
  }

  final hardMode =
      state['settings'] is Map<String, dynamic> &&
      (state['settings'] as Map<String, dynamic>)['hardMode'] == true;
  final roll = rollTrait(def.position, hardMode: hardMode);
  final replaced = applyTrait(card, roll);
  // The debit lands as an int: coins are the most-written field in the save and
  // the JS holds them whole.
  (resources as Map<String, dynamic>)['fanCoins'] = (coins - cost).toInt();

  emit('coins:updated', (resources)['fanCoins']);
  emit('trait:rolled', {
    'instanceId': card.instanceId,
    'id': roll.id,
    'level': roll.level,
    'replaced': replaced,
  });

  return (ok: true, reason: null, roll: roll, replaced: replaced, cost: cost);
}

/// Assigns a rolled trait to a card, mutating it. `none` normalises to level 1,
/// since a level is meaningless for it.
///
/// Returns true when a previous trait was overwritten.
bool applyTrait(CardInstance card, TraitRoll roll) {
  final hadTrait = card.raw['trait'] != null;
  card.raw['trait'] = roll.id == 'none'
      ? <String, dynamic>{'id': 'none', 'level': 1}
      : <String, dynamic>{'id': roll.id, 'level': roll.level};
  return hadTrait;
}
