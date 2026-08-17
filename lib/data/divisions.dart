/// The division ladder, ported from
/// `../merge-empire-fc/src/data/divisions.js`.
///
/// Opponent rating ranges are tuned against the sum/11 squad-rating formula and
/// the per-tier rating bands in `players.dart`:
///
///     Tier  base  max     Tier  base  max
///     T1    18    26      T5    55    64
///     T2    27    35      T6    65    75
///     T3    36    44      T7    76    85
///     T4    45    54      T8    86    95   (T9 = 100, scout-only, uncraftable)
///
/// A squad rating is the mean of the starting XI's effective ratings, each
/// clamped to its tier's [base, max], so a fully-merged squad of the league's
/// cap tier approaches that tier's max.
///
/// Difficulty curve — the edge shrinks as you climb. The ceiling is the maxed
/// team star minus an EDGE that decreases up the ladder (~+7 at Sunday League
/// down to ~+1 at Champions), so a maxed squad steamrolls the bottom and only
/// just tops the table at the summit. The floor stays low enough that a
/// just-promoted squad usually survives rather than bouncing straight back.
/// Measured: maxed promotion ~97% (SL) to ~57% (ChL).
///
/// These bands are tuned against a maxed squad's NO-TRAIT star, so the trait
/// system's total power must stay small relative to the edge or it erases the
/// curve — that is what `TRAIT_STAT_SCALE` in `traits.dart` bounds.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

class Division {
  const Division({
    required this.id,
    required this.name,
    required this.shortName,
    required this.matchRevenueBase,
    required this.matchCooldownMs,
    required this.opponentRatingRange,
    required this.color,
    required this.maxAssetTier,
    required this.maxPlayerTier,
  });

  final String id;
  final String name;
  final String shortName;
  final int matchRevenueBase;
  final int matchCooldownMs;

  /// (low, high) inclusive bounds for generated opponent ratings.
  final (int, int) opponentRatingRange;

  final String color;
  final int maxAssetTier;
  final int maxPlayerTier;
}

const List<Division> divisions = [
  Division(
    id: 'sunday_league',
    name: 'Sunday League',
    shortName: 'SL',
    matchRevenueBase: 100,
    matchCooldownMs: 30 * 1000,
    // maxed T2 star 31 is ~+7 over the best team here — steamroll.
    opponentRatingRange: (12, 24),
    color: '#8d6e63',
    maxAssetTier: 2,
    maxPlayerTier: 2,
  ),
  Division(
    id: 'amateur_cup',
    name: 'Amateur League',
    shortName: 'AL',
    matchRevenueBase: 250,
    matchCooldownMs: 30 * 1000,
    // maxed T3 star 40, ~+6 over the best.
    opponentRatingRange: (25, 34),
    color: '#78909c',
    maxAssetTier: 3,
    maxPlayerTier: 3,
  ),
  Division(
    id: 'regional_league',
    name: 'Regional League',
    shortName: 'RL',
    matchRevenueBase: 600,
    matchCooldownMs: 30 * 1000,
    // maxed T4 star 48, ~+6 over the best.
    opponentRatingRange: (34, 42),
    color: '#66bb6a',
    maxAssetTier: 4,
    maxPlayerTier: 4,
  ),
  Division(
    id: 'national_league',
    name: 'National League',
    shortName: 'NL',
    matchRevenueBase: 1500,
    matchCooldownMs: 30 * 1000,
    // maxed T5 star 57, ~+5 over the best.
    opponentRatingRange: (40, 52),
    color: '#42a5f5',
    maxAssetTier: 5,
    maxPlayerTier: 5,
  ),
  Division(
    id: 'elite_league',
    name: 'Elite League',
    shortName: 'EL',
    matchRevenueBase: 4000,
    matchCooldownMs: 30 * 1000,
    // maxed T6 star 68, ~+3 over the best.
    opponentRatingRange: (48, 65),
    color: '#ab47bc',
    maxAssetTier: 6,
    maxPlayerTier: 6,
  ),
  Division(
    id: 'continental',
    name: 'Continental League',
    shortName: 'CL',
    matchRevenueBase: 20000,
    matchCooldownMs: 30 * 1000,
    // maxed T7 star 79, ~+3 over the best.
    opponentRatingRange: (58, 76),
    color: '#ff7043',
    maxAssetTier: 7,
    maxPlayerTier: 7,
  ),
  Division(
    id: 'champions_cup',
    name: 'Champions League',
    shortName: 'ChL',
    matchRevenueBase: 120000,
    matchCooldownMs: 30 * 1000,
    // maxed T8 star 89, only ~+1 over the best — a real title race even maxed.
    opponentRatingRange: (68, 88),
    color: '#ffd700',
    maxAssetTier: 8,
    maxPlayerTier: 8,
  ),
];

final Map<String, Division> _byId = {for (final d in divisions) d.id: d};

/// Falls back to the first division for an unknown id, matching the JS.
Division getDivision(String id) => _byId[id] ?? divisions.first;

/// The division above [currentId], or null at the top or for an unknown id.
Division? getNextDivision(String currentId) {
  final idx = divisions.indexWhere((d) => d.id == currentId);
  return idx >= 0 && idx < divisions.length - 1 ? divisions[idx + 1] : null;
}
