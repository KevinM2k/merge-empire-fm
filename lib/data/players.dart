/// Static player card definitions, ported from
/// `../merge-empire-fc/src/data/players.js`. Grid instances store only
/// `{ definitionId, instanceId }` and look the rest up here.
///
/// One deliberate departure from the JS: `getEffectiveRating` does NOT live
/// here. In the original this data file imports `traitEngine` and
/// `sponsorEngine`, which inverts the dependency — data reaching into engines.
/// The Dart port keeps this file pure and places the composed rating in the
/// engine layer, where its dependencies already are.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/util/random.dart' show WeightedEntry;

// Male player names — a recognisable male first name followed by a
// footballer-style nickname, so the name reads first-name-first the way a real
// name would. Varied first names so no single nationality dominates.
const List<String> _fwdNames = [
  'Rodrigo Flash', 'Hiro Blitz', 'Lucas Rocket', 'Emeka Turbo',
  'Antoine Swift', 'Kofi Bolt', 'Diego Ace', 'Ivan Strike',
  'Piotr Dash', 'Ibrahim Arrow',
];
const List<String> _midNames = [
  'Sung-ho Vision', 'Mateo Thread', 'Giacomo Maestro', 'Kenji Dynamo',
  'Lars Pulse', 'Chidi Engine', 'Klaus Ticker', 'Paulo Link',
  'Viktor Craft', 'Kwame Flow',
];
const List<String> _defNames = [
  'Imran Iron', 'Hans Stone', 'Obinna Fortress', 'Dmitri Shield',
  'Rafael Bulwark', 'Erik Rock', 'Tunde Titan', 'Pierre Bastion',
  'Hiroshi Wall', 'Jonas Slab',
];
const List<String> _gkNames = [
  'Miguel Hands', 'Peter Vault', 'Laurent Safe', 'Diego Block',
  'Akio Cat', 'Emeka Glove', 'Novak Wall', 'Anders Reach',
  'Rodrigo Stops', 'Femi Reflex',
];

// Female player names — same first-name-then-nickname style. Pulled when an
// instance is created with a female variant.
const List<String> _fwdFemaleNames = [
  'Sofia Lightning', 'Yuki Ember', 'Adaeze Bolt', 'Natalia Star',
  'Ingrid Blaze', 'Priya Dart', 'Layla Comet', 'Elena Rush',
  'Chioma Spark', 'Min-ji Zip',
];
const List<String> _midFemaleNames = [
  'Amara Vision', 'Giulia Pulse', 'Haruka Weaver', 'Beatriz Tempo',
  'Valentina Conductor', 'Freja Quill', 'Aissatou Rhythm', 'Camille Pivot',
  'Carmen Thread', 'Anya Keys',
];
const List<String> _defFemaleNames = [
  'Mei Ironheart', 'Milena Granite', 'Lucia Bastion', 'Abeni Shield',
  'Adèle Fortress', 'Sakura Anchor', 'Ngozi Keep', 'Astrid Gate',
  'Fatima Wall', 'Zara Rampart',
];
const List<String> _gkFemaleNames = [
  'Isabela Catlike', 'Freya Vault', 'Nomvula Safe', 'Hinata Reflex',
  'Chiara Saves', 'Folake Wall', 'Yuna Hands', 'Catalina Glove',
  'Svetlana Block', 'Amélie Reach',
];

const Map<String, List<String>> _namePools = {
  'FWD': _fwdNames,
  'MID': _midNames,
  'DEF': _defNames,
  'GK': _gkNames,
};

const Map<String, List<String>> _femaleNamePools = {
  'FWD': _fwdFemaleNames,
  'MID': _midFemaleNames,
  'DEF': _defFemaleNames,
  'GK': _gkFemaleNames,
};

String pickDisplayName(String position, int tierIdx, {required bool female}) {
  final pools = female ? _femaleNamePools : _namePools;
  final pool = pools[position] ?? pools['FWD']!;
  return pool[tierIdx % pool.length];
}

/// A tier's shared shape before position variance is applied.
class _Tier {
  const _Tier({
    required this.tier,
    required this.tierName,
    required this.idleIncomePerSec,
    required this.rating,
    required this.maxRating,
    required this.sellValue,
    required this.flavour,
  });

  final int tier;
  final String tierName;
  final double idleIncomePerSec;
  final int rating;
  final int maxRating;
  final int sellValue;

  /// Indexed by position x gender: FWD male 0, FWD female 1, MID male 2, ...
  final List<String> flavour;
}

const List<_Tier> _tiers = [
  _Tier(
    tier: 1, tierName: 'Bronze Rookie', idleIncomePerSec: 0.05,
    rating: 18, maxRating: 26, sellValue: 10,
    flavour: [
      'Raw pace, zero fear.',
      'Nothing to lose, everything to prove.',
      'Still learning the shape.',
      'Every minute a lesson.',
      "Won't back down from anyone.",
      'First tackle, full commitment.',
      'Between the sticks, finding his feet.',
      'Big gloves, bigger ambitions.',
    ],
  ),
  _Tier(
    tier: 2, tierName: 'Bronze Pro', idleIncomePerSec: 0.15,
    rating: 27, maxRating: 35, sellValue: 25,
    flavour: [
      'Solid on the ball.',
      'Starting to turn heads.',
      'Reads the game early.',
      'Keeps it simple, keeps it tidy.',
      "Doesn't waste a tackle.",
      'Dependable in every game.',
      'Quiet work, steady hands.',
      'Sharp reflexes, sharper focus.',
    ],
  ),
  _Tier(
    tier: 3, tierName: 'Silver Rising', idleIncomePerSec: 0.40,
    rating: 36, maxRating: 44, sellValue: 60,
    flavour: [
      'The scouts are watching.',
      'A name to remember.',
      'Breaking into the first team.',
      'Turning potential into performance.',
      'On the radar of bigger clubs.',
      'Match after match, improving.',
      'The next step is coming.',
      'Hard to ignore now.',
    ],
  ),
  _Tier(
    tier: 4, tierName: 'Silver Star', idleIncomePerSec: 1.00,
    rating: 45, maxRating: 54, sellValue: 150,
    flavour: [
      'Crowd favourite.',
      'The fans sing the name.',
      'First pick every matchday.',
      'Gets the standing ovation.',
      'Built for the big stage.',
      'Never hides when it counts.',
      'The heartbeat of the side.',
      'Top of the team sheet.',
    ],
  ),
  _Tier(
    tier: 5, tierName: 'Gold Elite', idleIncomePerSec: 2.50,
    rating: 55, maxRating: 64, sellValue: 400,
    flavour: [
      'Worth every penny.',
      'Elite at every level.',
      'Raises the whole squad.',
      'Opponents plan around them.',
      'The benchmark for excellence.',
      'Consistent brilliance, no off days.',
      "A transfer you'll never regret.",
      'Difference-maker, every time.',
    ],
  ),
  _Tier(
    tier: 6, tierName: 'Gold Superstar', idleIncomePerSec: 6.00,
    rating: 65, maxRating: 75, sellValue: 1000,
    flavour: [
      'Highlights reel every match.',
      'Creates magic from nothing.',
      'A moment of brilliance, always.',
      'The stadium holds its breath.',
      'Players like this come once.',
      'Pure class, pure showtime.',
      'Football at its finest.',
      'Defenders dream of stopping them.',
    ],
  ),
  _Tier(
    tier: 7, tierName: 'Legendary Icon', idleIncomePerSec: 15.0,
    rating: 76, maxRating: 85, sellValue: 3000,
    flavour: [
      'A living legend.',
      'Defined an era.',
      'Children wear the shirt.',
      'The record books bend for them.',
      'A career written in gold.',
      'Every club wanted them.',
      'When they played, time slowed.',
      'One of the all-time greats.',
    ],
  ),
  _Tier(
    tier: 8, tierName: 'World Legend', idleIncomePerSec: 40.0,
    rating: 86, maxRating: 95, sellValue: 8000,
    flavour: [
      'Football immortal.',
      'The game is different because of them.',
      'Played on every continent, loved on all.',
      'A generation defined by this name.',
      'Statues have been raised.',
      'The records will never be broken.',
      'History bows to this career.',
      'The world stopped to watch.',
    ],
  ),
  // T9 is scout-only (1% weight in the Champions Cup odds) and cannot be merged.
  _Tier(
    tier: 9, tierName: 'Football Icon', idleIncomePerSec: 120.0,
    rating: 100, maxRating: 100, sellValue: 100000,
    flavour: [
      'Transcends the game itself.',
      'Not a player — a phenomenon.',
      'Beyond comparison. Beyond words.',
      'The sport changed the day they arrived.',
      'Once in a civilisation.',
      'The highest peak ever reached.',
      'Simply the greatest.',
      'When they touched the ball, history happened.',
    ],
  ),
];

const List<String> _positions = ['FWD', 'MID', 'DEF', 'GK'];

/// Position income/rating variance. Tight spread so the GK-to-FWD gap stays
/// within 5 points and every tier beats the tier below.
const Map<String, double> _posVariance = {
  'FWD': 1.025,
  'MID': 1.00,
  'DEF': 0.99,
  'GK': 0.975,
};

/// Per-archetype attack ratio — the share of a player's rating contributing to
/// team attack rather than defence. Tiers alternate archetypes within a
/// position, so a T5 MID (holding) is more defensive than a T6 MID (playmaker)
/// despite the lower overall rating. Male and female variants share the ratio.
const Map<String, double> _attackRatio = {
  'FWD_1': 0.75, 'FWD_2': 0.88, 'FWD_3': 0.80, 'FWD_4': 0.92,
  'FWD_5': 0.72, 'FWD_6': 0.90, 'FWD_7': 0.85, 'FWD_8': 0.95, 'FWD_9': 0.90,
  'MID_1': 0.30, 'MID_2': 0.65, 'MID_3': 0.35, 'MID_4': 0.60,
  'MID_5': 0.28, 'MID_6': 0.70, 'MID_7': 0.45, 'MID_8': 0.55,
  'DEF_1': 0.10, 'DEF_2': 0.20, 'DEF_3': 0.12, 'DEF_4': 0.22,
  'DEF_5': 0.14, 'DEF_6': 0.18, 'DEF_7': 0.20, 'DEF_8': 0.15,
  'GK_1': 0.00, 'GK_2': 0.00, 'GK_3': 0.00, 'GK_4': 0.00,
  'GK_5': 0.00, 'GK_6': 0.00, 'GK_7': 0.00, 'GK_8': 0.00,
};

/// A static player card definition.
class PlayerDef {
  const PlayerDef({
    required this.id,
    required this.tier,
    required this.tierName,
    required this.position,
    required this.name,
    required this.rating,
    required this.maxRating,
    required this.idleIncomePerSec,
    required this.art,
    required this.mergesInto,
    required this.sellValue,
    required this.flavourTexts,
    required this.attackRatio,
  });

  final String id;
  final int tier;
  final String tierName;
  final String position;
  final String name;

  /// Base rating for a fresh card of this definition.
  final int rating;

  /// Flat per-tier ceiling the card can never exceed.
  final int maxRating;

  final double idleIncomePerSec;
  final String art;

  /// The definition two of these merge into, or null at the ceiling.
  final String? mergesInto;

  final int sellValue;
  final List<String> flavourTexts;
  final double attackRatio;
}

String _buildId(int tier, String pos) => 'player_t${tier}_${pos.toLowerCase()}';

String? _buildMergesInto(int tier, String pos) =>
    tier < 8 ? _buildId(tier + 1, pos) : null;

/// JS `Math.round` rounds half toward positive infinity; Dart's `round()`
/// rounds half away from zero. Every value here is positive, so they agree —
/// but the helper keeps the intent explicit.
int _jsRound(double v) => (v + 0.5).floor();

List<PlayerDef> _buildPlayers() {
  final out = <PlayerDef>[];
  for (final pos in _positions) {
    // T9 is globally unique — only a forward definition exists.
    final tiers = _tiers.where((t) => t.tier != 9 || pos == 'FWD').toList();
    for (var idx = 0; idx < tiers.length; idx++) {
      final t = tiers[idx];
      final variance = _posVariance[pos]!;
      final pool = _namePools[pos]!;

      out.add(
        PlayerDef(
          id: _buildId(t.tier, pos),
          tier: t.tier,
          tierName: t.tierName,
          position: pos,
          name: pool[idx % pool.length],
          // T9 is always exactly 100 regardless of position variance.
          rating: t.tier == 9
              ? 100
              : math.min(t.maxRating, _jsRound(t.rating * variance)),
          maxRating: t.tier == 9 ? 100 : t.maxRating,
          idleIncomePerSec:
              _jsRound(t.idleIncomePerSec * variance * 100) / 100,
          art: 'cards/${pos.toLowerCase()}_t${t.tier}',
          mergesInto: _buildMergesInto(t.tier, pos),
          sellValue: t.sellValue,
          flavourTexts: t.flavour,
          attackRatio: _attackRatio['${pos}_${t.tier}'] ?? 0.50,
        ),
      );
    }
  }
  return List.unmodifiable(out);
}

final List<PlayerDef> players = _buildPlayers();

final Map<String, PlayerDef> _byId = {for (final p in players) p.id: p};

PlayerDef? getPlayerDef(String? id) => id == null ? null : _byId[id];

List<PlayerDef> getPlayersByTier(int tier) =>
    players.where((p) => p.tier == tier).toList();

/// Per-position random range for attackRatio. At game start — and on prestige
/// or a new team — one ratio per definition is rolled and stored in
/// `state.definitionRatios`, so every instance of the same card shows the same
/// ATK/DEF split within a save.
const Map<String, (double, double)> ratioRange = {
  'GK': (0.00, 0.05),
  'DEF': (0.10, 0.30),
  'MID': (0.35, 0.65),
  'FWD': (0.68, 0.92),
};

/// Rolls one attack ratio per definition.
///
/// Uses its OWN generator, not the shared seeded stream. The JS calls
/// `Math.random()` here rather than its seeded PRNG, and matching that matters:
/// drawing from the shared stream would shift every subsequent gameplay draw
/// and break parity with the JS engines. [seed] is for tests only.
Map<String, double> generateDefinitionRatios({int? seed}) {
  final rng = math.Random(seed);
  final ratios = <String, double>{};
  for (final p in players) {
    final (lo, hi) = ratioRange[p.position] ?? (0.35, 0.65);
    ratios[p.id] = _jsRound((lo + rng.nextDouble() * (hi - lo)) * 100) / 100;
  }
  return ratios;
}

/// The effective rating of an instance, applying its per-instance rating bonus.
/// T9 is always 100; everything else is clamped to `[1, maxRating]`.
int getCardRating(PlayerDef? def, {num ratingBonus = 0}) {
  if (def == null) return 0;
  if (def.tier == 9) return 100;
  final raw = def.rating + ratingBonus;
  return math.max(1, math.min(def.maxRating, raw)).round();
}

/// Veterans decline past ten seasons of service — 10 rating points per season
/// beyond.
int agingPenalty([int seasonsPlayed = 0]) =>
    seasonsPlayed <= 10 ? 0 : (seasonsPlayed - 10) * 10;

/// The headline stat floats up to ~9% above the rating.
const double peakLift = 0.09;

/// The off-stat drops up to ~90% for a pure specialist.
const double offStatDrop = 0.90;

/// A player's ATK and DEF, FIFA-style.
class AtkDefSplit {
  const AtkDefSplit({required this.attack, required this.defence});

  final int attack;
  final int defence;

  @override
  String toString() => 'AtkDefSplit(attack: $attack, defence: $defence)';
}

/// The overall rating is the identity; ATK and DEF sit around it and do NOT sum
/// to it. The role's stronger stat floats just above the rating, the weaker one
/// drops well below — how far is set by how specialised the player is. These
/// are the same numbers the match sim runs on and the card shows: one source of
/// truth, no display-only rescale.
///
/// [effectiveRating] should already include aging, form and sponsor penalties.
AtkDefSplit getCardAtkDefSplit(
  double? attackRatio,
  num effectiveRating, {
  num atkBonus = 0,
  num defBonus = 0,
}) {
  final r = math.max(0, effectiveRating).toDouble();
  final ratio = attackRatio ?? 0.50;
  final spec = math.min(1.0, (ratio - 0.5).abs() * 2);
  final strong = r * (1 + spec * peakLift);
  final weak = r * (1 - spec * offStatDrop);
  int clamp(num v) => math.max(0, math.min(100, _jsRound(v.toDouble())));
  final atkIsStrong = ratio >= 0.5;
  return AtkDefSplit(
    attack: clamp((atkIsStrong ? strong : weak) + atkBonus),
    defence: clamp((atkIsStrong ? weak : strong) + defBonus),
  );
}

/// T1 bronze drops steeply per division so late-game scouts feel rewarding.
/// Sunday League stays very bronze-heavy (it is the tutorial league); each step
/// up shifts weight toward the tiers competitive for that division.
///
/// Entries are `(tier, weight)` and each table sums to 100.
const Map<String, List<(int, double)>> divisionScoutOdds = {
  'sunday_league': [(1, 85), (2, 15)],
  'amateur_cup': [(1, 70), (2, 22), (3, 8)],
  'regional_league': [(1, 55), (2, 27), (3, 13), (4, 5)],
  'national_league': [(1, 40), (2, 30), (3, 17), (4, 9), (5, 4)],
  'elite_league': [(1, 28), (2, 30), (3, 20), (4, 12), (5, 7), (6, 3)],
  'continental': [(1, 20), (2, 28), (3, 22), (4, 15), (5, 9), (6, 4), (7, 2)],
  'champions_cup': [
    (1, 15), (2, 22), (3, 20), (4, 16), (5, 12),
    (6, 8), (7, 4.5), (8, 1.5), (9, 1),
  ],
};

List<WeightedEntry<String>> buildScoutPool(String divisionId) {
  final odds =
      divisionScoutOdds[divisionId] ?? divisionScoutOdds['sunday_league']!;
  return [
    for (final (tier, weight) in odds)
      for (final p in players.where((p) => p.tier == tier))
        WeightedEntry(p.id, weight),
  ];
}

/// Named pools used by the coin-sinks engine for Lucky Pack and Youth Academy.
final List<WeightedEntry<String>> bronzePool = List.unmodifiable([
  for (final p in players.where((p) => p.tier == 1)) WeightedEntry(p.id, 10),
]);

final List<WeightedEntry<String>> silverPool = List.unmodifiable([
  for (final p in players.where((p) => p.tier == 3)) WeightedEntry(p.id, 10),
]);
