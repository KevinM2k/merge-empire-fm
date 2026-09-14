/// The MATCH trait pool — the second, gem-gated slot.
///
/// **EVERY TRAIT HERE IS CONDITIONAL, and that is not a theme.** `gem_engine`
/// states the catalogue's law: "NEVER RAW RATING. The division bands are tuned
/// against a no-trait maxed squad with a shrinking edge per division; anything
/// that adds ★ punches straight through the curve." A slot bought with a gem
/// that handed out flat stat would break it outright. A trait that is dark in
/// most matches does not move the baseline the bands are tuned against — so
/// the condition IS the licence, and a later trait that fires always would
/// invalidate the whole argument.
///
/// **Rarer condition, bigger number**, asserted in `match_traits_test.dart`
/// rather than left as a comment. That ladder is what stops the common traits
/// dominating the rare ones — Fortress fires in half of all fixtures and Derby
/// Devil in perhaps one in ten, so Derby Devil carries nearly three times the
/// lift.
///
/// Values are multipliers on the player's contribution to the squad rating —
/// the same channel and the same units as `yellowCardRatingMult = 0.9`, which
/// the couch reported as clearly noticeable at ten per cent. They are not
/// directional: `computeSquadRatings` applies its multiplier map to the whole
/// `effectiveRating`, so a match trait's identity is WHEN it fires rather than
/// which stat it touches. That is the trade taken for leaving the rating
/// engine untouched.
///
/// Unlike the first slot's pool there is no position gating. A match trait is
/// about the situation, and a keeper can be a Cup Fighter as well as a striker.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

/// What has to be true for a trait to pay.
enum MatchTraitCondition {
  home,
  away,
  strongerOpponent,
  firstTwenty,
  relegationZone,
  lastFifteen,
  cupTie,
  superSub,
  derby,

  /// Squad-wide while we are down to ten. Capped by [matchTraitSquadCap].
  tenMen,

  /// Replaces the yellow-card rating multiplier rather than adding to it.
  booked,

  /// A probability, not a multiplier: the chance of shrugging off an injury.
  injuryShrug,
}

class MatchTraitLevel {
  const MatchTraitLevel({
    required this.level,
    required this.label,
    required this.mult,
  });

  final int level;
  final String label;

  /// A rating multiplier for most conditions. For `booked` it is the
  /// REPLACEMENT yellow-card multiplier, and for `injuryShrug` a probability.
  /// The condition says which.
  final double mult;
}

class MatchTrait {
  const MatchTrait({
    required this.id,
    required this.name,
    required this.icon,
    required this.desc,
    required this.condition,
    required this.levels,
  });

  final String id;
  final String name;
  final String icon;
  final String desc;
  final MatchTraitCondition condition;
  final List<MatchTraitLevel> levels;
}

/// The most Ten Man Wall may add across the whole side, however many carry it.
/// The same shape as `maxSquadInjuryReduction` in `trait_engine.dart`, and for
/// the same reason: a grid stuffed with one trait must not make a side that is
/// better with ten men than with eleven.
const double matchTraitSquadCap = 0.12;

const Map<String, MatchTrait> matchTraits = {
  // ── Where you are playing: half of all fixtures, so the smallest ─────────
  'fortress': MatchTrait(
    id: 'fortress', name: 'Fortress', icon: '🏰',
    desc: 'Immovable at home — but only at home',
    condition: MatchTraitCondition.home,
    levels: [
      MatchTraitLevel(level: 1, label: 'I', mult: 1.04),
      MatchTraitLevel(level: 2, label: 'II', mult: 1.07),
      MatchTraitLevel(level: 3, label: 'III', mult: 1.11),
    ],
  ),
  'away_day': MatchTrait(
    id: 'away_day', name: 'Away Day Hero', icon: '✈️',
    desc: 'Loves a hostile ground — thrives on the road',
    condition: MatchTraitCondition.away,
    levels: [
      MatchTraitLevel(level: 1, label: 'I', mult: 1.04),
      MatchTraitLevel(level: 2, label: 'II', mult: 1.07),
      MatchTraitLevel(level: 3, label: 'III', mult: 1.11),
    ],
  ),

  // ── Who you are playing: rarer, so bigger ────────────────────────────────
  'big_game': MatchTrait(
    id: 'big_game', name: 'Big Game Player', icon: '🎩',
    desc: 'Turns up against the better side',
    condition: MatchTraitCondition.strongerOpponent,
    levels: [
      MatchTraitLevel(level: 1, label: 'I', mult: 1.05),
      MatchTraitLevel(level: 2, label: 'II', mult: 1.09),
      MatchTraitLevel(level: 3, label: 'III', mult: 1.14),
    ],
  ),

  // ── When in the match: these switch on and off during a game ─────────────
  'fast_starter': MatchTrait(
    id: 'fast_starter', name: 'Fast Starter', icon: '🚀',
    desc: 'Out of the blocks — huge for the opening twenty',
    condition: MatchTraitCondition.firstTwenty,
    levels: [
      MatchTraitLevel(level: 1, label: 'I', mult: 1.07),
      MatchTraitLevel(level: 2, label: 'II', mult: 1.13),
      MatchTraitLevel(level: 3, label: 'III', mult: 1.20),
    ],
  ),
  'relegation_scrapper': MatchTrait(
    id: 'relegation_scrapper', name: 'Relegation Scrapper', icon: '🛟',
    desc: 'Fights hardest when the drop is real',
    condition: MatchTraitCondition.relegationZone,
    levels: [
      MatchTraitLevel(level: 1, label: 'I', mult: 1.07),
      MatchTraitLevel(level: 2, label: 'II', mult: 1.13),
      MatchTraitLevel(level: 3, label: 'III', mult: 1.20),
    ],
  ),
  'last_gasp': MatchTrait(
    id: 'last_gasp', name: 'Last Gasp', icon: '⏱',
    desc: 'Finds something in the closing minutes',
    condition: MatchTraitCondition.lastFifteen,
    levels: [
      MatchTraitLevel(level: 1, label: 'I', mult: 1.08),
      MatchTraitLevel(level: 2, label: 'II', mult: 1.15),
      MatchTraitLevel(level: 3, label: 'III', mult: 1.23),
    ],
  ),
  'cup_fighter': MatchTrait(
    id: 'cup_fighter', name: 'Cup Fighter', icon: '🏆',
    desc: 'Made for the cup — nothing else brings it out of him',
    condition: MatchTraitCondition.cupTie,
    levels: [
      MatchTraitLevel(level: 1, label: 'I', mult: 1.08),
      MatchTraitLevel(level: 2, label: 'II', mult: 1.15),
      MatchTraitLevel(level: 3, label: 'III', mult: 1.23),
    ],
  ),
  // The biggest plain number in the pool, because it is the only condition the
  // MANAGER triggers: he does nothing on the bench and nothing if he starts.
  'super_sub': MatchTrait(
    id: 'super_sub', name: 'Super Sub', icon: '🔄',
    desc: 'Devastating off the bench in the closing twenty',
    condition: MatchTraitCondition.superSub,
    levels: [
      MatchTraitLevel(level: 1, label: 'I', mult: 1.12),
      MatchTraitLevel(level: 2, label: 'II', mult: 1.20),
      MatchTraitLevel(level: 3, label: 'III', mult: 1.30),
    ],
  ),
  'derby_devil': MatchTrait(
    id: 'derby_devil', name: 'Derby Devil', icon: '😈',
    desc: 'Lives for the grudge match',
    condition: MatchTraitCondition.derby,
    levels: [
      MatchTraitLevel(level: 1, label: 'I', mult: 1.10),
      MatchTraitLevel(level: 2, label: 'II', mult: 1.18),
      MatchTraitLevel(level: 3, label: 'III', mult: 1.28),
    ],
  ),

  // ── When it has gone wrong: three that own an axis outright ──────────────
  'ten_man_wall': MatchTrait(
    id: 'ten_man_wall', name: 'Ten Man Wall', icon: '🧱',
    desc: 'Rallies the ten — lifts EVERY man left on the pitch',
    condition: MatchTraitCondition.tenMen,
    levels: [
      MatchTraitLevel(level: 1, label: 'I', mult: 1.03),
      MatchTraitLevel(level: 2, label: 'II', mult: 1.05),
      MatchTraitLevel(level: 3, label: 'III', mult: 1.08),
    ],
  ),
  // Runs UP toward 1.0: level III is a man who plays exactly the same booked.
  'ice_veins': MatchTrait(
    id: 'ice_veins', name: 'Ice Veins', icon: '🧊',
    desc: 'Plays the same booked — the coolest head in the game',
    condition: MatchTraitCondition.booked,
    levels: [
      MatchTraitLevel(level: 1, label: 'I', mult: 0.94),
      MatchTraitLevel(level: 2, label: 'II', mult: 0.97),
      MatchTraitLevel(level: 3, label: 'III', mult: 1.00),
    ],
  ),
  // Distinct from `tough` in the first pool, which lowers the CHANCE of an
  // injury: this is what happens after one has already landed.
  'warrior': MatchTrait(
    id: 'warrior', name: 'Warrior', icon: '🦿',
    desc: 'Plays through it — may shrug off a knock and carry on',
    condition: MatchTraitCondition.injuryShrug,
    levels: [
      MatchTraitLevel(level: 1, label: 'I', mult: 0.25),
      MatchTraitLevel(level: 2, label: 'II', mult: 0.45),
      MatchTraitLevel(level: 3, label: 'III', mult: 0.70),
    ],
  ),
};

final List<MatchTrait> matchTraitList = List.unmodifiable(matchTraits.values);

MatchTrait? getMatchTrait(String? id) => id == null ? null : matchTraits[id];

MatchTraitLevel? getMatchTraitLevel(MatchTrait? trait, int level) {
  if (trait == null) return null;
  for (final l in trait.levels) {
    if (l.level == level) return l;
  }
  return null;
}
