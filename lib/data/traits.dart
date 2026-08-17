/// Player trait definitions, ported from
/// `../merge-empire-fc/src/data/traits.js`. Each card instance holds one trait
/// as `{ id, level }`.
///
/// Position-specific traits apply only when the card matches that position;
/// universal traits (a null [Trait.positions]) apply to any card.
///
/// ── Effect axes ────────────────────────────────────────────────────────────
///   atkBonus            flat points added to the card's ATK stat
///   defBonus            flat points added to the card's DEF stat
///   incomeBonus         % multiplier on THIS card's idle coin income
///   matchRevBonus       % added to MATCH revenue (squad-wide, summed over XI)
///   injuryReduction     absolute cut to THIS card's own injury chance
///   teamInjuryReduction absolute cut to EVERY injury roll (squad-wide, summed)
///   agingReduction      rating points clawed back from the post-S10 penalty
///   recoveryBonus       % faster injury recovery for this card
///   staminaMult         below 1 tires slower in-match (Pro mode only)
///
/// ── Balance model ──────────────────────────────────────────────────────────
/// Squad ATK/DEF are position-weighted averages over 11 slots, and the
/// denominators differ wildly (4-3-3: atkDen ~4.65, defDen ~6.35). The same +6
/// was worth +0.94 team DEF on a keeper but only +0.19 team ATK on a defender.
/// The numbers here are chosen so a level III lands in a comparable band
/// (~+1.0-1.3 squad rating) regardless of position, by pre-dividing by that
/// position's weight. A trait sitting on a stat its position barely weights
/// (Ball-Playing's ATK on a defender) carries a deliberately large raw number.
///
/// The other half of the rule: NO TWO TRAITS SHARE AN EFFECT VECTOR. Ids and
/// names are stable — an existing save keeps its trait, it just does a new job.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

class TraitLevel {
  const TraitLevel({
    required this.level,
    required this.label,
    this.atkBonus = 0,
    this.defBonus = 0,
    this.incomeBonus = 0,
    this.matchRevBonus = 0,
    this.injuryReduction = 0,
    this.teamInjuryReduction = 0,
    this.agingReduction = 0,
    this.recoveryBonus = 0,
    this.staminaMult,
  });

  final int level;
  final String label;

  /// Authored value. What a card receives is this times [traitStatScale].
  final int atkBonus;

  /// Authored value. What a card receives is this times [traitStatScale].
  final int defBonus;

  final double incomeBonus;
  final double matchRevBonus;
  final double injuryReduction;
  final double teamInjuryReduction;
  final int agingReduction;
  final double recoveryBonus;

  /// Below 1 means the player tires more slowly. Null when the trait does not
  /// touch stamina.
  final double? staminaMult;
}

class Trait {
  const Trait({
    required this.id,
    required this.name,
    required this.icon,
    required this.positions,
    required this.type,
    required this.desc,
    required this.levels,
  });

  final String id;
  final String name;
  final String icon;

  /// Null means universal — rollable on any position.
  final List<String>? positions;

  final String type;
  final String desc;
  final List<TraitLevel> levels;
}

const Map<String, Trait> traits = {
  // ── FWD ───────────────────────────────────────────────────────────────────
  'finisher': Trait(
    id: 'finisher', name: 'Finisher', icon: '⚽',
    positions: ['FWD'], type: 'attack',
    desc: 'Clinical in front of goal — a big, pure boost to attack',
    levels: [
      TraitLevel(level: 1, label: 'I', atkBonus: 4),
      TraitLevel(level: 2, label: 'II', atkBonus: 8),
      TraitLevel(level: 3, label: 'III', atkBonus: 13),
    ],
  ),
  'pressing': Trait(
    id: 'pressing', name: 'Pressing', icon: '🏃',
    positions: ['FWD'], type: 'hybrid',
    desc: 'Presses high and tracks back — attack, plus real defensive work',
    levels: [
      TraitLevel(level: 1, label: 'I', atkBonus: 3, defBonus: 4),
      TraitLevel(level: 2, label: 'II', atkBonus: 6, defBonus: 8),
      TraitLevel(level: 3, label: 'III', atkBonus: 10, defBonus: 13),
    ],
  ),
  'poacher': Trait(
    id: 'poacher', name: 'Poacher', icon: '🎯',
    positions: ['FWD'], type: 'matchrev',
    desc: 'Goals sell tickets — attack, plus a cut of every matchday gate',
    levels: [
      TraitLevel(level: 1, label: 'I', atkBonus: 2, matchRevBonus: 0.04),
      TraitLevel(level: 2, label: 'II', atkBonus: 4, matchRevBonus: 0.08),
      TraitLevel(level: 3, label: 'III', atkBonus: 6, matchRevBonus: 0.13),
    ],
  ),
  'speedster': Trait(
    id: 'speedster', name: 'Speedster', icon: '⚡',
    positions: ['FWD'], type: 'recovery',
    desc: 'Quick to burn past a challenge — and quick to shake off a knock',
    levels: [
      TraitLevel(level: 1, label: 'I', atkBonus: 2, recoveryBonus: 0.12),
      TraitLevel(level: 2, label: 'II', atkBonus: 4, recoveryBonus: 0.24),
      TraitLevel(level: 3, label: 'III', atkBonus: 6, recoveryBonus: 0.40),
    ],
  ),

  // ── MID ───────────────────────────────────────────────────────────────────
  'engine': Trait(
    id: 'engine', name: 'Engine Room', icon: '⚙️',
    positions: ['MID'], type: 'hybrid',
    desc: 'Tireless box-to-box motor — strong in both attack and defence',
    levels: [
      TraitLevel(level: 1, label: 'I', atkBonus: 4, defBonus: 5),
      TraitLevel(level: 2, label: 'II', atkBonus: 8, defBonus: 10),
      TraitLevel(level: 3, label: 'III', atkBonus: 13, defBonus: 16),
    ],
  ),
  'anchor': Trait(
    id: 'anchor', name: 'Anchor', icon: '⚓',
    positions: ['MID'], type: 'defence',
    desc: 'Pure holding mid — shields the defence and reads the game',
    levels: [
      TraitLevel(level: 1, label: 'I', defBonus: 6),
      TraitLevel(level: 2, label: 'II', defBonus: 12),
      TraitLevel(level: 3, label: 'III', defBonus: 20),
    ],
  ),
  'playmaker': Trait(
    id: 'playmaker', name: 'Playmaker', icon: '🎪',
    positions: ['MID'], type: 'income',
    desc: 'Creative genius — the biggest idle income boost in the game',
    levels: [
      TraitLevel(level: 1, label: 'I', incomeBonus: 0.25),
      TraitLevel(level: 2, label: 'II', incomeBonus: 0.50),
      TraitLevel(level: 3, label: 'III', incomeBonus: 0.85),
    ],
  ),
  'enforcer': Trait(
    id: 'enforcer', name: 'Enforcer', icon: '💪',
    positions: ['MID'], type: 'toughness',
    desc: 'Wins the ball and takes the hit — defence, plus a lower injury risk',
    levels: [
      TraitLevel(level: 1, label: 'I', defBonus: 4, injuryReduction: 0.03),
      TraitLevel(level: 2, label: 'II', defBonus: 8, injuryReduction: 0.06),
      TraitLevel(level: 3, label: 'III', defBonus: 13, injuryReduction: 0.10),
    ],
  ),

  // ── DEF ───────────────────────────────────────────────────────────────────
  'ironwall': Trait(
    id: 'ironwall', name: 'Iron Wall', icon: '🛡️',
    positions: ['DEF'], type: 'defence',
    desc: 'Brick wall at the back — a big, pure boost to defence',
    levels: [
      TraitLevel(level: 1, label: 'I', defBonus: 5),
      TraitLevel(level: 2, label: 'II', defBonus: 10),
      TraitLevel(level: 3, label: 'III', defBonus: 16),
    ],
  ),
  'ball_playing': Trait(
    id: 'ball_playing', name: 'Ball-Playing', icon: '🎶',
    positions: ['DEF'], type: 'hybrid',
    desc:
        'Overlapping wing-back — turns a defender into a real attacking threat',
    levels: [
      TraitLevel(level: 1, label: 'I', atkBonus: 6, defBonus: 2),
      TraitLevel(level: 2, label: 'II', atkBonus: 12, defBonus: 4),
      TraitLevel(level: 3, label: 'III', atkBonus: 20, defBonus: 6),
    ],
  ),
  'rock': Trait(
    id: 'rock', name: 'Rock', icon: '🪨',
    positions: ['DEF'], type: 'veteran',
    desc: 'Ages like granite — the strongest defence against career decline',
    levels: [
      TraitLevel(level: 1, label: 'I', agingReduction: 4),
      TraitLevel(level: 2, label: 'II', agingReduction: 8),
      TraitLevel(level: 3, label: 'III', agingReduction: 14),
    ],
  ),
  'sweeper': Trait(
    id: 'sweeper', name: 'Sweeper', icon: '🧹',
    positions: ['DEF'], type: 'teamtoughness',
    desc: 'Snuffs out danger early — cuts the injury risk for the WHOLE squad',
    levels: [
      TraitLevel(level: 1, label: 'I', teamInjuryReduction: 0.02),
      TraitLevel(level: 2, label: 'II', teamInjuryReduction: 0.04),
      TraitLevel(level: 3, label: 'III', teamInjuryReduction: 0.06),
    ],
  ),

  // ── GK ────────────────────────────────────────────────────────────────────
  'stopper': Trait(
    id: 'stopper', name: 'Shot Stopper', icon: '🧤',
    positions: ['GK'], type: 'defence',
    desc: "Exceptional reflexes — a big, pure boost to the keeper's defence",
    levels: [
      TraitLevel(level: 1, label: 'I', defBonus: 4),
      TraitLevel(level: 2, label: 'II', defBonus: 8),
      TraitLevel(level: 3, label: 'III', defBonus: 13),
    ],
  ),
  'commanding': Trait(
    id: 'commanding', name: 'Commanding', icon: '📢',
    positions: ['GK'], type: 'matchrev',
    desc:
        'Organises the ground and inspires the stands — the biggest matchday earner',
    levels: [
      TraitLevel(level: 1, label: 'I', matchRevBonus: 0.06),
      TraitLevel(level: 2, label: 'II', matchRevBonus: 0.12),
      TraitLevel(level: 3, label: 'III', matchRevBonus: 0.20),
    ],
  ),
  'reflexes': Trait(
    id: 'reflexes', name: 'Reflexes', icon: '🐱',
    positions: ['GK'], type: 'veteran',
    desc: 'Stays sharp well into their career — keeps shot-stopping as the legs go',
    levels: [
      TraitLevel(level: 1, label: 'I', defBonus: 2, agingReduction: 2),
      TraitLevel(level: 2, label: 'II', defBonus: 4, agingReduction: 4),
      TraitLevel(level: 3, label: 'III', defBonus: 6, agingReduction: 7),
    ],
  ),

  // ── None (clears trait) ───────────────────────────────────────────────────
  'none': Trait(
    id: 'none', name: 'None', icon: '✕',
    positions: null, type: 'none',
    desc: 'No trait — clears any existing trait',
    levels: [
      TraitLevel(level: 1, label: ''),
      TraitLevel(level: 2, label: ''),
      TraitLevel(level: 3, label: ''),
    ],
  ),

  // ── Universal ─────────────────────────────────────────────────────────────
  // Rollable on any position, so these are never wasted. They trade peak power
  // for that flexibility — a universal never beats the best position trait at
  // its own job.
  'allrounder': Trait(
    id: 'allrounder', name: 'All Rounder', icon: '⭐',
    positions: null, type: 'hybrid',
    desc:
        'Equally good everywhere — a solid boost to attack AND defence, on any player',
    levels: [
      TraitLevel(level: 1, label: 'I', atkBonus: 3, defBonus: 3),
      TraitLevel(level: 2, label: 'II', atkBonus: 6, defBonus: 6),
      TraitLevel(level: 3, label: 'III', atkBonus: 10, defBonus: 10),
    ],
  ),
  'crowdpleaser': Trait(
    id: 'crowdpleaser', name: 'Crowd Pleaser', icon: '📣',
    positions: null, type: 'income',
    desc:
        'Sells shirts and fills seats — the only trait boosting idle AND matchday income',
    levels: [
      TraitLevel(level: 1, label: 'I', incomeBonus: 0.12, matchRevBonus: 0.02),
      TraitLevel(level: 2, label: 'II', incomeBonus: 0.25, matchRevBonus: 0.04),
      TraitLevel(level: 3, label: 'III', incomeBonus: 0.40, matchRevBonus: 0.07),
    ],
  ),
  'tough': Trait(
    id: 'tough', name: 'Tough', icon: '🦾',
    positions: null, type: 'toughness',
    desc: "Built to last — by far the biggest cut to this player's injury chance",
    levels: [
      TraitLevel(level: 1, label: 'I', injuryReduction: 0.05),
      TraitLevel(level: 2, label: 'II', injuryReduction: 0.10),
      TraitLevel(level: 3, label: 'III', injuryReduction: 0.18),
    ],
  ),
  'veteran': Trait(
    id: 'veteran', name: 'Veteran', icon: '🦅',
    positions: null, type: 'veteran',
    desc: 'Old head — softens the aging penalty and shrugs off knocks faster',
    levels: [
      TraitLevel(level: 1, label: 'I', agingReduction: 3, recoveryBonus: 0.10),
      TraitLevel(level: 2, label: 'II', agingReduction: 6, recoveryBonus: 0.20),
      TraitLevel(level: 3, label: 'III', agingReduction: 10, recoveryBonus: 0.35),
    ],
  ),
  // Pro mode only. Recovery scales by the same factor, so it buys in-match
  // endurance and back-to-back use, never more total matches before a rest.
  'iron_lungs': Trait(
    id: 'iron_lungs', name: 'Iron Lungs', icon: '🫁',
    positions: null, type: 'stamina',
    desc: 'Tireless engine — drains energy slower during matches (Pro mode)',
    levels: [
      TraitLevel(level: 1, label: 'I', staminaMult: 0.85),
      TraitLevel(level: 2, label: 'II', staminaMult: 0.72),
      TraitLevel(level: 3, label: 'III', staminaMult: 0.60),
    ],
  ),
};

final List<Trait> traitList = List.unmodifiable(traits.values);

Trait? getTrait(String? id) => id == null ? null : traits[id];

TraitLevel? getTraitLevel(Trait? trait, int level) {
  if (trait == null) return null;
  for (final l in trait.levels) {
    if (l.level == level) return l;
  }
  return null;
}

/// Tier scaling of directional (ATK/DEF) trait bonuses.
///
/// The problem this solves: the bonuses are FLAT points added to a card's
/// ATK/DEF split, and that split is hard-clamped to 100. A card's strong stat
/// is already `rating * (1 + spec * peakLift)` before any trait, so at the top
/// of the ladder there is almost nothing left to add into — a T7 forward takes
/// the full +13 from Finisher III, a T8 forward takes +2 and bins 85% of it.
///
/// That gave traits an INVERTED power curve, worth most in the middle divisions
/// and least in Champions League — the opposite of how the rest of the game
/// scales. Measured over full seasons, an XI all carrying their best level III
/// gained ~+13 squad star at Elite and Continental but only ~+7 at Champions,
/// trivialising the two divisions below the top.
///
/// The fix is one multiplier, not a per-tier table: the clamp only inverts the
/// curve while the bonuses are big enough to reach it, so shrinking them stops
/// the ceiling binding at every tier at once. Solving numerically for the scale
/// that makes a full XI of best-in-slot level IIIs worth
/// [traitXiStarTarget] squad star gives 0.39 / 0.38 / 0.37 / 0.37 / 0.38 /
/// 0.38 / 0.37 / 0.39 across T1-T8 — flat to within sampling noise.
const double traitStatScale = 0.38;

/// Squad star a full XI of best-in-slot level III traits is worth.
///
/// Deliberately well under the ~+13 the unscaled numbers produced: the division
/// bands are tuned against a maxed squad's NO-TRAIT star (the Champions ceiling
/// sits ~1 point under it), so anything much larger erases the "edge shrinks as
/// you climb" curve those bands exist to create.
const int traitXiStarTarget = 5;

/// Traits available to a position: position-specific ones followed by
/// universals. Stamina traits are Pro-mode-only fatigue perks, excluded unless
/// [hardMode], so a Casual player never rolls a trait that does nothing.
List<Trait> getTraitPoolForPosition(String? position, {bool hardMode = false}) {
  final usable = traitList.where((t) => hardMode || t.type != 'stamina');
  if (position == null) return usable.toList();
  return [
    ...usable.where((t) => t.positions?.contains(position) ?? false),
    ...usable.where((t) => t.positions == null),
  ];
}
