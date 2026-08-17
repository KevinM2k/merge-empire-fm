/// Squad and card rating computation, ported from the ratings section of
/// `../merge-empire-fc/src/engine/matchEngine.js`.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/player_energy_engine.dart';
import 'package:merge_empire_fc/engine/player_rating.dart';
import 'package:merge_empire_fc/engine/trait_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';

int _jsRound(num v) => (v + 0.5).floor();

/// How much a player loses playing out of position. Mirrors the lineup engine's
/// penalty — the two must agree or the auto-picker and the sim disagree about
/// who is better.
double computePositionPenalty(String playerPos, String slotPos) {
  if (playerPos == slotPos) return 0;
  if (playerPos == 'GK' || slotPos == 'GK') return 0.50;
  if ((playerPos == 'FWD' && slotPos == 'DEF') ||
      (playerPos == 'DEF' && slotPos == 'FWD')) {
    return 0.35;
  }
  return 0.20;
}

/// A card's effective attack, defence and overall.
class CardStats {
  const CardStats({
    required this.attack,
    required this.defence,
    required this.rating,
    required this.baseAttack,
    required this.baseDefence,
    required this.baseRating,
  });

  static const CardStats zero = CardStats(
    attack: 0, defence: 0, rating: 0,
    baseAttack: 0, baseDefence: 0, baseRating: 0,
  );

  final int attack;
  final int defence;
  final int rating;
  final int baseAttack;
  final int baseDefence;
  final int baseRating;
}

/// Team overall from the team's own ATK/DEF: a FIFA-style blend favouring the
/// stronger department.
///
/// KNOW WHAT THIS HIDES. Weighting the max at 0.7 means a lopsided side reads
/// ABOVE its mean, not below: ATK 85 / DEF 35 and ATK 70 / DEF 70 both read 70,
/// and the sim runs on the split, not on the star. The badge therefore
/// under-reports exactly the damage a manager most wants warning about — lose
/// your striker and team ATK can fall 14 points while the star drops 4, because
/// DEF simply takes over as the headline.
///
/// Anything deciding what the player should DO — the coach, a hint, a warning —
/// must read the ATK/DEF split, never the star. An earlier comment claimed an
/// unbalanced side "reads lower"; it says the opposite of what the arithmetic
/// does, and that error is what let the tactic coach ship inverted.
int teamRatingFromSplit(num attack, num defence) =>
    _jsRound(0.7 * math.max(attack, defence) + 0.3 * math.min(attack, defence));

/// The single source of truth for a card's effective ATK, DEF and rating.
///
/// FIFA model: the rating is the identity and ATK/DEF sit AROUND it. The rating
/// is scaled by aging, sponsor and form, then split by the card's attack ratio,
/// and the trait's directional bonuses are added on top of the split.
///
/// Because the bonuses land on the split, they are folded BACK into the overall
/// or the card would read "+13 ATK" next to an unchanged rating. That fold uses
/// the same blend the team star uses, so a bonus on the player's headline stat
/// is worth the most and a card's overall moves in step with the squad star it
/// feeds.
CardStats getCardStats(
  CardInstance? card, {
  String? slotPosition,
  Map<String, dynamic> definitionRatios = const {},
  bool fatigue = false,
}) {
  if (card == null) return CardStats.zero;
  final def = getPlayerDef(card.definitionId);
  if (def == null) return CardStats.zero;

  final tb = getTraitBonus(card, def.position);

  // The rating basis that gets split — no directional trait bonus yet.
  var basis = getEffectiveRating(card).toDouble();
  if (slotPosition != null) {
    basis *= 1 - computePositionPenalty(def.position, slotPosition);
  }
  // Pro-mode fatigue for DISPLAY: a tired player is weaker, and ATK/DEF hang
  // off the rating so they scale with it. The match sim does NOT pass this — it
  // applies live in-match energy itself.
  if (fatigue) basis *= fatigueRatingFactor(energyPct(card));

  final ratio = card.attackRatio ??
      (definitionRatios[card.definitionId] as num?)?.toDouble() ??
      def.attackRatio;

  final eff = getCardAtkDefSplit(
    ratio,
    basis,
    atkBonus: tb.atkBonus,
    defBonus: tb.defBonus,
  );
  final noTrait = getCardAtkDefSplit(ratio, basis);
  final base = getCardAtkDefSplit(ratio, def.rating);

  // Rating-equivalent of the trait's directional bonus, computed off the
  // CLAMPED splits so a stat already pinned at 100 stops paying.
  final traitRatingGain = (tb.atkBonus != 0 || tb.defBonus != 0)
      ? teamRatingFromSplit(eff.attack, eff.defence) -
            teamRatingFromSplit(noTrait.attack, noTrait.defence)
      : 0;

  // The overall is capped by the card's TIER ceiling, not a bare 100. The
  // effective rating already clamps the basis, but the trait gain is folded in
  // afterwards — without this cap a trait could push a T8 card to a flat 100
  // and break the rule that only a T9 Football Icon ever reads 100.
  final ratingCap = def.maxRating;

  return CardStats(
    attack: eff.attack,
    defence: eff.defence,
    rating: math.max(0, math.min(ratingCap, _jsRound(basis) + traitRatingGain)),
    baseAttack: base.attack,
    baseDefence: base.defence,
    baseRating: def.rating,
  );
}

/// One slot's contribution to the team split.
class SplitEntry {
  const SplitEntry({
    required this.slotPosition,
    this.attack = 0,
    this.defence = 0,
    this.weight = 1,
  });

  final String slotPosition;
  final num attack;
  final num defence;

  /// Fractional participation, NOT importance — Pro mode prorates a player who
  /// limps off mid-segment.
  final double weight;
}

/// Team ATK/DEF from eleven per-slot splits, position-weighted.
///
/// [entries] is ALWAYS the full XI, one per formation slot in slot order. An
/// empty or unavailable slot still carries its position weight into the
/// denominator with a zero weight, which is what makes a short-handed side
/// genuinely weaker rather than merely differently shaped.
///
/// This exists as ONE function because it used to be two: the squad ratings
/// weighted by position while the Pro-mode sim averaged the same eleven splits
/// over a flat divide-by-eleven. The two disagreed by about 15 rating points on
/// the same XI, in the player's disfavour, and only in Pro.
TeamSplit weightedTeamSplit(List<SplitEntry> entries) {
  var atkNum = 0.0;
  var atkDen = 0.0;
  var defNum = 0.0;
  var defDen = 0.0;

  for (final e in entries) {
    final aw = attackWeights[e.slotPosition] ?? 0.5;
    final dw = defenceWeights[e.slotPosition] ?? 0.5;
    atkDen += aw;
    defDen += dw;
    if (e.weight <= 0) continue;
    atkNum += e.attack * aw * e.weight;
    defNum += e.defence * dw * e.weight;
  }

  return (
    attack: math.min(100, _jsRound(atkDen > 0 ? atkNum / atkDen : 0)),
    defence: math.min(100, _jsRound(defDen > 0 ? defNum / defDen : 0)),
  );
}

class _Slot {
  _Slot({
    required this.effectiveRating,
    required this.slotPosition,
    this.attackRatio,
    this.atkBonus = 0,
    this.defBonus = 0,
  });

  final double effectiveRating;
  final String slotPosition;
  final double? attackRatio;
  final double atkBonus;
  final double defBonus;
}

/// Team ATK and DEF for the dual simulation.
///
/// Both are POSITION-WEIGHTED averages of the players' FIFA stats: forwards
/// count most toward team ATK, defenders and the keeper most toward team DEF.
/// Weighting is what keeps the team number sensible — without it, averaging
/// eleven lopsided specialists drags both stats well below the rating (a 68
/// squad would read ATK 51 / DEF 57). Weighted, a balanced squad reads about
/// its rating on both, and formation tilts it modestly.
TeamSplit computeSquadRatings(
  List<CardInstance?> gridCells, {
  List<Map<String, dynamic>>? lineup,
  Map<String, dynamic> definitionRatios = const {},
  bool fatigue = false,
}) {
  final cards = gridCells.whereType<CardInstance>().toList();
  if (cards.isEmpty) return (attack: 0, defence: 0);

  List<_Slot> slots;

  if (lineup != null && lineup.length == 11) {
    final byId = {for (final c in cards) c.instanceId: c};
    slots = [
      for (final slot in lineup)
        () {
          final slotPos = slot['slotPosition'] as String? ?? 'MID';
          final id = slot['cardInstanceId'];
          final c = id is String ? byId[id] : null;
          if (c == null || c.injured || c.isUnavailable) {
            return _Slot(effectiveRating: 0, slotPosition: slotPos);
          }
          final def = getPlayerDef(c.definitionId);
          if (def == null) {
            return _Slot(effectiveRating: 0, slotPosition: slotPos);
          }
          final trait = getTraitBonus(c, def.position);
          final raw = getEffectiveRating(c).toDouble();
          final penalty = computePositionPenalty(def.position, slotPos);
          final fat = fatigue ? fatigueRatingFactor(energyPct(c)) : 1.0;
          return _Slot(
            effectiveRating: raw * (1 - penalty) * fat,
            slotPosition: slotPos,
            attackRatio: c.attackRatio ??
                (definitionRatios[c.definitionId] as num?)?.toDouble() ??
                def.attackRatio,
            atkBonus: trait.atkBonus,
            defBonus: trait.defBonus,
          );
        }(),
    ];
  } else {
    // Fallback with no lineup: the position-tagged top eleven.
    final healthy = cards.where((c) => !c.injured && !c.isUnavailable).toList();
    if (healthy.isEmpty) return (attack: 0, defence: 0);

    final rated = <_Slot>[];
    for (final c in healthy) {
      final def = getPlayerDef(c.definitionId);
      if (def == null) continue;
      final trait = getTraitBonus(c, def.position);
      rated.add(
        _Slot(
          effectiveRating: getEffectiveRating(c) *
              (fatigue ? fatigueRatingFactor(energyPct(c)) : 1.0),
          slotPosition: def.position,
          attackRatio: c.attackRatio ??
              (definitionRatios[c.definitionId] as num?)?.toDouble() ??
              def.attackRatio,
          atkBonus: trait.atkBonus,
          defBonus: trait.defBonus,
        ),
      );
    }
    rated.sort((a, b) => b.effectiveRating.compareTo(a.effectiveRating));
    if (rated.length > 11) rated.removeRange(11, rated.length);
    while (rated.length < 11) {
      rated.add(_Slot(effectiveRating: 0, slotPosition: 'MID'));
    }
    slots = rated;
  }

  return weightedTeamSplit([
    for (final s in slots)
      if (s.effectiveRating <= 0)
        // An empty slot still counts in the denominator.
        SplitEntry(slotPosition: s.slotPosition, weight: 0)
      else
        () {
          final split = getCardAtkDefSplit(
            s.attackRatio,
            s.effectiveRating,
            atkBonus: s.atkBonus,
            defBonus: s.defBonus,
          );
          return SplitEntry(
            slotPosition: s.slotPosition,
            attack: split.attack,
            defence: split.defence,
          );
        }(),
  ]);
}

/// The squad's overall star.
int computeSquadRating(
  List<CardInstance?> gridCells, {
  List<Map<String, dynamic>>? lineup,
  Map<String, dynamic> definitionRatios = const {},
  bool fatigue = false,
}) {
  final split = computeSquadRatings(
    gridCells,
    lineup: lineup,
    definitionRatios: definitionRatios,
    fatigue: fatigue,
  );
  return math.min(100, teamRatingFromSplit(split.attack, split.defence));
}

/// The squad rating's components, for display.
typedef SquadBreakdown = ({int playerBase, int matchBonus, int total});

SquadBreakdown computeSquadRatingBreakdown(
  List<CardInstance?> gridCells, {
  List<Map<String, dynamic>>? lineup,
  bool fatigue = false,
}) {
  final cards = gridCells.whereType<CardInstance>().toList();
  if (cards.isEmpty) return (playerBase: 0, matchBonus: 0, total: 0);

  List<double> ratings;

  if (lineup != null && lineup.length == 11) {
    final byId = {for (final c in cards) c.instanceId: c};
    ratings = [
      for (final slot in lineup)
        () {
          final id = slot['cardInstanceId'];
          final c = id is String ? byId[id] : null;
          if (c == null || c.injured) return 0.0;
          final def = getPlayerDef(c.definitionId);
          if (def == null) return 0.0;
          final raw = getEffectiveRating(c).toDouble();
          final slotPos = slot['slotPosition'] as String? ?? 'MID';
          return raw *
              (1 - computePositionPenalty(def.position, slotPos)) *
              (fatigue ? fatigueRatingFactor(energyPct(c)) : 1.0);
        }(),
    ];
  } else {
    final healthy = cards.where((c) => !c.injured && !c.isUnavailable).toList();
    if (healthy.isEmpty) return (playerBase: 0, matchBonus: 0, total: 0);

    ratings = [
      for (final c in healthy)
        if (getPlayerDef(c.definitionId) != null)
          getEffectiveRating(c) * (fatigue ? fatigueRatingFactor(energyPct(c)) : 1.0)
        else
          0.0,
    ]..sort((a, b) => b.compareTo(a));
    if (ratings.length > 11) ratings = ratings.sublist(0, 11);
  }

  // Always over eleven, so a short-handed side is genuinely weaker.
  final playerBase = ratings.fold<double>(0, (s, r) => s + r) / 11;

  return (
    playerBase: _jsRound(playerBase),
    matchBonus: 0,
    total: math.min(100, _jsRound(playerBase)),
  );
}

/// The rating used to sample a match outcome, with the layered modifiers.
///
/// Per-player form is already baked into the base rating, so there is no
/// team-level form modifier — that would double-count it.
///
/// The relegation boost is added at face value, matching the flat boost the sim
/// adds to BOTH ATK and DEF. A composite star is a blend of the split, not a
/// sum of it, so adding +N to each stat lifts the star by +N — doubling it here
/// made the badge advertise a bonus the sim never gave.
double effectiveMatchRating(
  num baseRating, {
  bool isHome = false,
  bool relegationZone = false,
  int homeAdvDisplay = homeAdvantageDisplay,
}) {
  var r = baseRating.toDouble();
  if (isHome) r += homeAdvDisplay;
  r = math.min(r, 100);
  if (relegationZone) r += relegationBoost;
  return r;
}

/// Bradley-Terry exponent: a rating advantage translates decisively into wins
/// without eliminating upsets.
const double winProbExponent = 4.0;
