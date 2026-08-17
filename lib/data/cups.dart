/// Knockout cup tournaments, ported from
/// `../merge-empire-fc/src/data/cups.js`.
///
/// Each runs alongside the league season as a parallel single-elimination
/// track: win a round to advance, lose and you are out for the season. Teams
/// get tougher each round and rewards scale with them.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

class Cup {
  const Cup({
    required this.id,
    required this.name,
    required this.shortName,
    required this.unlocksAtDivisionIdx,
    required this.rounds,
    required this.opponentRatingBump,
    required this.roundPrizeMult,
    required this.winnerPrizeMult,
    required this.color,
  });

  final String id;
  final String name;
  final String shortName;

  /// Index into the division ladder at which this cup becomes available.
  final int unlocksAtDivisionIdx;

  final List<String> rounds;

  /// Opponent rating bump per round. The final is a significant jump, so
  /// beating it demands a squad genuinely above the league's baseline.
  final List<int> opponentRatingBump;

  /// Round prize in league-match units. Kept close to a normal league win —
  /// the real cup reward is the sponsor drop, not the coin payout.
  final List<double> roundPrizeMult;

  final int winnerPrizeMult;
  final String color;
}

/// All cups run a QF -> SF -> F pyramid. Regional once had only semis and a
/// final, which felt thin for a real tournament.
const List<Cup> cups = [
  Cup(
    id: 'regional_cup',
    name: 'Regional Cup',
    shortName: 'RC',
    unlocksAtDivisionIdx: 2, // Regional League
    rounds: ['Quarter-Final', 'Semi-Final', 'Final'],
    opponentRatingBump: [4, 10, 18],
    roundPrizeMult: [1.0, 1.4, 2.0],
    winnerPrizeMult: 0,
    color: '#66bb6a',
  ),
  Cup(
    id: 'national_cup',
    name: 'National Cup',
    shortName: 'NC',
    unlocksAtDivisionIdx: 3, // National League
    rounds: ['Quarter-Final', 'Semi-Final', 'Final'],
    opponentRatingBump: [6, 12, 22],
    roundPrizeMult: [1.0, 1.6, 2.2],
    winnerPrizeMult: 0,
    color: '#42a5f5',
  ),
  Cup(
    id: 'continental_cup',
    name: 'Continental Cup',
    shortName: 'CC',
    unlocksAtDivisionIdx: 4, // Elite League
    rounds: ['Quarter-Final', 'Semi-Final', 'Final'],
    opponentRatingBump: [8, 14, 26],
    roundPrizeMult: [1.0, 1.6, 2.4],
    winnerPrizeMult: 0,
    color: '#ab47bc',
  ),
  Cup(
    id: 'world_club_cup',
    name: 'World Club Cup',
    shortName: 'WCC',
    unlocksAtDivisionIdx: 6, // Champions Cup
    rounds: ['Quarter-Final', 'Semi-Final', 'Final'],
    opponentRatingBump: [10, 18, 30],
    roundPrizeMult: [1.0, 1.8, 2.8],
    winnerPrizeMult: 0,
    color: '#ffd700',
  ),
];

Cup? getCupById(String? id) {
  for (final c in cups) {
    if (c.id == id) return c;
  }
  return null;
}

/// Flavour pool for cup opponents — a mix of elite-sounding club names.
const List<String> cupOpponentPool = [
  'FC Barrington', 'Atlético Royal', 'Sporting Vega', 'Real Castellón',
  'Dynamo Black', 'Club Arsenale', 'FC Monarch', 'Estrella Del Mar',
  'FC Ironwood', 'United Paragon', 'Olympique Apex', 'Club Aurora',
  'Inter Meridian', 'FC Valkyrie', 'Sporting Obsidian', 'Club Aegis',
];

/// Scout context lines, randomly assigned to cup opponents so the coach can
/// tell the manager who they are up against. `{team}` is the placeholder.
const List<String> cupOpponentContext = [
  '{team} are the reigning league champions — their striker led the division in goals.',
  '{team} finished runners-up three seasons in a row. They have a point to prove.',
  "{team} knocked out the title favourites last round. Don't underestimate them.",
  "{team} are a defensive outfit — they haven't conceded more than one goal in five matches.",
  '{team} are backed by heavy investment; half their squad are internationals.',
  '{team} survived relegation by a single point last season. They play like they have something to lose.',
  '{team} have the best away record in their division. They travel well.',
  "{team} are a cup-specialist side — they've won this competition twice in the last five years.",
  '{team} finished mid-table but their cup form is electric. Three clean sheets on the way here.',
  '{team} are a well-drilled pressing side. Expect a high-intensity, physical battle.',
  "{team} are this season's surprise package. Newly promoted but playing above their station.",
  '{team} have been built around a single world-class playmaker — shut him down and they struggle.',
];
