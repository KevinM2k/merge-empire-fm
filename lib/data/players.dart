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

import 'package:merge_empire_fc/i18n/i18n.dart' show stableIndex;

import 'package:merge_empire_fc/util/random.dart' show WeightedEntry;

// Male player names — a recognisable male first name followed by a
// footballer-style nickname, so the name reads first-name-first the way a real
// name would. Varied first names so no single nationality dominates.
const List<String> _fwdNames = [
  'Rodrigo Flash',
  'Hiro Blitz',
  'Lucas Rocket',
  'Emeka Turbo',
  'Antoine Swift',
  'Kofi Bolt',
  'Diego Ace',
  'Ivan Strike',
  'Piotr Dash',
  'Ibrahim Arrow',
];
const List<String> _midNames = [
  'Sung-ho Vision',
  'Mateo Thread',
  'Giacomo Maestro',
  'Kenji Dynamo',
  'Lars Pulse',
  'Chidi Engine',
  'Klaus Ticker',
  'Paulo Link',
  'Viktor Craft',
  'Kwame Flow',
];
const List<String> _defNames = [
  'Imran Iron',
  'Hans Stone',
  'Obinna Fortress',
  'Dmitri Shield',
  'Rafael Bulwark',
  'Erik Rock',
  'Tunde Titan',
  'Pierre Bastion',
  'Hiroshi Wall',
  'Jonas Slab',
];
const List<String> _gkNames = [
  'Miguel Hands',
  'Peter Vault',
  'Laurent Safe',
  'Diego Block',
  'Akio Cat',
  'Emeka Glove',
  'Novak Wall',
  'Anders Reach',
  'Rodrigo Stops',
  'Femi Reflex',
];

// Female player names — same first-name-then-nickname style. Pulled when an
// instance is created with a female variant.
const List<String> _fwdFemaleNames = [
  'Sofia Lightning',
  'Yuki Ember',
  'Adaeze Bolt',
  'Natalia Star',
  'Ingrid Blaze',
  'Priya Dart',
  'Layla Comet',
  'Elena Rush',
  'Chioma Spark',
  'Min-ji Zip',
];
const List<String> _midFemaleNames = [
  'Amara Vision',
  'Giulia Pulse',
  'Haruka Weaver',
  'Beatriz Tempo',
  'Valentina Conductor',
  'Freja Quill',
  'Aissatou Rhythm',
  'Camille Pivot',
  'Carmen Thread',
  'Anya Keys',
];
const List<String> _defFemaleNames = [
  'Mei Ironheart',
  'Milena Granite',
  'Lucia Bastion',
  'Abeni Shield',
  'Adèle Fortress',
  'Sakura Anchor',
  'Ngozi Keep',
  'Astrid Gate',
  'Fatima Wall',
  'Zara Rampart',
];
const List<String> _gkFemaleNames = [
  'Isabela Catlike',
  'Freya Vault',
  'Nomvula Safe',
  'Hinata Reflex',
  'Chiara Saves',
  'Folake Wall',
  'Yuna Hands',
  'Catalina Glove',
  'Svetlana Block',
  'Amélie Reach',
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

/// The nickname half of every name in a pool — the BANK for that position.
///
/// **Derived rather than written out again.** Every entry is "First Nickname"
/// and the nickname is what carries the position: Wall, Reflex and Glove are
/// keepers, Bolt and Blaze are forwards. Splitting the pool that already exists
/// is what keeps the bank and the names from ever disagreeing.
List<String> _bankOf(List<String> pool) => [
  for (final full in pool)
    if (full.contains(' ')) full.substring(full.indexOf(' ') + 1),
];

final Map<String, List<String>> _surnameBank = {
  for (final entry in _namePools.entries) entry.key: _bankOf(entry.value),
};
final Map<String, List<String>> _femaleSurnameBank = {
  for (final entry in _femaleNamePools.entries)
    entry.key: _bankOf(entry.value),
};

/// The nicknames a player in this position can be given.
List<String> surnameBank(String position, {required bool female}) {
  final banks = female ? _femaleSurnameBank : _surnameBank;
  return banks[position] ?? banks['FWD']!;
}

/// The name a card is born with.
///
/// **THE FIRST NAME IS THE TIER'S; THE SECOND IS THE CARD'S.** It used to be
/// both — `pool[tierIdx % 10]` for the whole string — so every card of one
/// position, tier and gender was born the same man, and a squad filled up with
/// copies of Diego Block. Reported directly, with the fix named: keep the first
/// name, randomise the second from a bank per position.
///
/// [seed] is what varies it. A card passes its instance id; anything with no
/// per-card identity to offer passes null and gets the tier's own pairing,
/// which is what the Player Index wants — the index describes a DEFINITION, and
/// a definition that renamed itself on every rebuild would be unreadable.
///
/// **Hashed rather than rolled**, and that is not a preference: `createInstance`
/// draws the variant and the rating spread from a shared generator whose ORDER
/// the parity fixtures were taken in, so a new `nextInt` here would shift every
/// later draw in the file. A hash of the id costs nothing and moves nothing.
String pickDisplayName(
  String position,
  int tierIdx, {
  required bool female,
  String? seed,
}) {
  final pools = female ? _femaleNamePools : _namePools;
  final pool = pools[position] ?? pools['FWD']!;
  final full = pool[tierIdx % pool.length];
  if (seed == null || !full.contains(' ')) return full;
  final first = full.substring(0, full.indexOf(' '));
  final bank = surnameBank(position, female: female);
  if (bank.isEmpty) return full;
  return '$first ${bank[stableIndex(seed, bank.length)]}';
}

/// ANOTHER name from the same pool, for the Randomise button on the rename
/// card.
///
/// [pickDisplayName] is `pool[tier % 10]`, which is deterministic on purpose —
/// and which is also why a squad ends up with two of the same man: every card of
/// one position, tier and gender is born with the same name. Renaming is the way
/// out and typing is the annoying part.
///
/// [notThis] is what he is called now, so the roll always changes something. A
/// pool of one would loop forever, so it is a filtered pick rather than a retry.
///
/// `dart:math`, not the seeded generator: this is a player pressing a button,
/// not part of the deterministic gameplay stream.
String randomDisplayName(
  String position, {
  required bool female,
  String? notThis,
}) {
  final pools = female ? _femaleNamePools : _namePools;
  final pool = pools[position] ?? pools['FWD']!;
  final options = [
    for (final name in pool)
      if (name != notThis) name,
  ];
  if (options.isEmpty) return pool.first;
  return options[math.Random().nextInt(options.length)];
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
    tier: 1,
    tierName: 'Bronze Rookie',
    idleIncomePerSec: 0.05,
    rating: 18,
    maxRating: 26,
    sellValue: 10,
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
    tier: 2,
    tierName: 'Bronze Pro',
    idleIncomePerSec: 0.15,
    rating: 27,
    maxRating: 35,
    sellValue: 25,
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
    tier: 3,
    tierName: 'Silver Rising',
    idleIncomePerSec: 0.40,
    rating: 36,
    maxRating: 44,
    sellValue: 60,
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
    tier: 4,
    tierName: 'Silver Star',
    idleIncomePerSec: 1.00,
    rating: 45,
    maxRating: 54,
    sellValue: 150,
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
    tier: 5,
    tierName: 'Gold Elite',
    idleIncomePerSec: 2.50,
    rating: 55,
    maxRating: 64,
    sellValue: 400,
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
    tier: 6,
    tierName: 'Gold Superstar',
    idleIncomePerSec: 6.00,
    rating: 65,
    maxRating: 75,
    sellValue: 1000,
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
    tier: 7,
    tierName: 'Legendary Icon',
    idleIncomePerSec: 15.0,
    rating: 76,
    maxRating: 85,
    sellValue: 3000,
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
    tier: 8,
    tierName: 'World Legend',
    idleIncomePerSec: 40.0,
    rating: 86,
    maxRating: 95,
    sellValue: 8000,
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
    tier: 9,
    tierName: 'Football Icon',
    idleIncomePerSec: 120.0,
    rating: 100,
    maxRating: 100,
    sellValue: 100000,
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
  'FWD_1': 0.75,
  'FWD_2': 0.88,
  'FWD_3': 0.80,
  'FWD_4': 0.92,
  'FWD_5': 0.72,
  'FWD_6': 0.90,
  'FWD_7': 0.85,
  'FWD_8': 0.95,
  'FWD_9': 0.90,
  'MID_1': 0.30,
  'MID_2': 0.65,
  'MID_3': 0.35,
  'MID_4': 0.60,
  'MID_5': 0.28,
  'MID_6': 0.70,
  'MID_7': 0.45,
  'MID_8': 0.55,
  'DEF_1': 0.10,
  'DEF_2': 0.20,
  'DEF_3': 0.12,
  'DEF_4': 0.22,
  'DEF_5': 0.14,
  'DEF_6': 0.18,
  'DEF_7': 0.20,
  'DEF_8': 0.15,
  'GK_1': 0.00,
  'GK_2': 0.00,
  'GK_3': 0.00,
  'GK_4': 0.00,
  'GK_5': 0.00,
  'GK_6': 0.00,
  'GK_7': 0.00,
  'GK_8': 0.00,
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
          idleIncomePerSec: _jsRound(t.idleIncomePerSec * variance * 100) / 100,
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

// ── Age ─────────────────────────────────────────────────────────────────────

// **A CARD HAS AN AGE NOW, and it replaces "ten seasons then a cliff".**
//
// The old model counted SERVICE: a card arrived at zero, was untouched for ten
// seasons, then lost ten rating points a season and vanished at fifteen. Every
// card aged at the same rate from the same start, so a World Legend and a
// Bronze Rookie scouted on the same day retired on the same day — and a merge
// reset the counter to zero, which meant the way to keep a squad young was to
// merge, not to buy young.
//
// This is a divergence the JS does not have: **a player is a person with a
// birthday.** He is scouted at an age that rises with his tier — 18 for a
// Bronze Rookie up to 25 for a World Legend, because a world-class player got
// there by playing — he peaks through his twenties, declines from 31 at an
// accelerating rate, and retires at 40. A veteran is therefore YOURS for far
// longer than fifteen seasons if you want him; he is simply worse every year
// you keep him.
//
// `seasonsPlayed` survives untouched and still means what it always did:
// seasons of SERVICE at this club, which is what loyalty, the achievements and
// the quests are counted in. Age drives everything that is about WEAR —
// decline, demotion, the injury curve, stamina, retirement. They are different
// facts about a player and this is the first build where they can disagree,
// because a merged card carries its parents' years and starts service again at
// zero.
//
// Deliberately a small pure table with no engine imports: the merge engine, the
// season-end sweep, the card themes and the coach all read the same numbers, so
// nothing can hold a second opinion about when a player is old.

/// The youngest a card can be: a Bronze Rookie's scout age, and the anchor
/// every age curve in the game is measured from.
const int youngestAge = 18;

/// The age a freshly scouted card of each tier arrives at.
///
/// **It rises with the tier because the tier is a career.** A Bronze Rookie is
/// eighteen and has played nobody; a World Legend is twenty-five and has. The
/// gap is also what makes [mergedAge] mean something — merging two teenagers
/// into a Silver Rising lands on a player who is still young for his tier,
/// while merging two thirty-year-olds into one does not.
const Map<int, int> tierScoutAge = <int, int>{
  1: youngestAge,
  2: 19,
  3: 20,
  4: 21,
  5: 22,
  6: 23,
  7: 24,
  8: 25,
  9: 26,
};

/// The age a card of [tier] is scouted at, and the floor a merge into that tier
/// lands on.
int scoutAgeForTier(int tier) => tierScoutAge[tier] ?? tierScoutAge[1]!;

/// The prime, inclusive: nothing is taken off a rating between these.
///
/// [peakAgeStart] is deliberately the same 25 a World Legend is scouted at, so
/// the top of the merge ladder arrives already in its prime rather than with
/// years of growing still to do.
const int peakAgeStart = 25;
const int peakAgeEnd = 30;

/// The first age that costs rating.
const int declineStartAge = peakAgeEnd + 1;

/// He leaves the club the season he turns forty.
const int retirementAge = 40;

/// **QUADRATIC, so the fall starts as a rumour and ends as a collapse.**
///
/// `(age - 30)² ~/ 2`, floored at a point so the first year past the prime
/// always costs something: 1 at 31, 4 at 33, 12 at 35, 24 at 37, 40 in a
/// player's last season. A World Legend built at 88 is still a Legendary Icon
/// at 35 and a Silver Star at 39, which is the shape asked for — you can hold
/// on to him, and holding on to him costs you.
///
/// Linear would have been the easy port of the old ten-a-season rule and it is
/// the wrong curve: a flat drop makes the decision to sell obvious on the first
/// season it lands, and then every season after it is the same decision again.
///
/// **It TRUNCATES rather than rounding, and that is load-bearing.** Rounding
/// half up puts the final season at 41, and 41 is one point past what the JS
/// takes off its own fourteen-season veteran — which `match_orchestration_
/// parity_test` dresses a whole squad with. One rating point there is not
/// cosmetic: it flips a goal from one side to the other twenty-five events
/// deep. Truncating lands the last playable age on exactly the reference's 40,
/// so the two runtimes still play the same match out of the same decrepit
/// squad. The `max` is what keeps 31 from rounding away to nothing.
int ageDeclinePenalty(int age) {
  final past = age - peakAgeEnd;
  if (past <= 0) return 0;
  return math.max(1, past * past ~/ 2);
}

/// **WHAT A VETERAN IS DISCOUNTED BY IN THE MARKET, and it is not what he is
/// declining by.**
///
/// The JS's own rule — nothing for ten years, then ten rating points a year —
/// and it stays the JS's, because every price in this game is pinned against a
/// node fixture: the sell shelf, the loan fee, a rival's bid, Deadline Day. A
/// curve here would have been a rewrite of the whole economy hiding inside a
/// feature about birthdays, and the harnesses would have been right to fail it.
///
/// **It takes [wearYears], not seasons of service.** Identical for a card
/// nobody merged, so the references still reproduce to the last digit — and the
/// right figure for a merged thirty-four-year-old, who used to reset to zero
/// and sell as a debutant.
///
/// [ageDeclinePenalty] is the other one and they are not interchangeable: that
/// is what comes off a RATING, on a curve, against a birthday. This is what
/// comes off a PRICE.
int agingPenalty([int wearYears = 0]) =>
    wearYears <= 10 ? 0 : (wearYears - 10) * 10;

/// The age a merge produces.
///
/// **The older parent's age, never younger than the new tier's own scout age.**
/// Two eighteen-year-old Bronze Rookies make a nineteen-year-old Bronze Pro —
/// the "slight bump" — because nineteen is where a Bronze Pro starts. A
/// twenty-two-year-old merged with an eighteen-year-old makes a
/// twenty-two-year-old: the older man is in there, and a merge is not a way to
/// launder a veteran into a youngster.
///
/// That single `max` is both rules at once, which is why there is no separate
/// "+1 if they matched" term: the bump falls out of the tier floor, so it
/// applies exactly when both parents are young for what they became.
int mergedAge(int ageA, int ageB, int intoTier) =>
    math.max(math.max(ageA, ageB), scoutAgeForTier(intoTier));

/// **Years of WEAR: how long this card has been playing at this level.**
///
/// `age` minus the age his tier is scouted at. For a card nobody merged that is
/// exactly his `seasonsPlayed`, which is the point — the injury curve and the
/// stamina drain were tuned against a service count and keep every number they
/// had, down to the last digit of the JS reference.
///
/// What it fixes is the MERGED veteran. Service resets to zero on a merge and
/// an age does not, so a thirty-four-year-old freshly merged into a World
/// Legend read as a debutant to both curves: never injured, never tired. He is
/// nine years past what a World Legend is scouted at, and this is the figure
/// that says so.
int wearYears(int tier, int age) => math.max(0, age - scoutAgeForTier(tier));

/// The age a card written before ages existed reads as.
///
/// Its tier says where it started and its service says how long ago that was,
/// which is the closest thing to a birthday the old save holds. A ten-season
/// Bronze Rookie comes back twenty-eight and still has his prime in front of
/// him; a ten-season World Legend comes back thirty-five and is on the way
/// down, which is roughly where the old model had both of them.
int derivedAge(int tier, int seasonsPlayed) =>
    scoutAgeForTier(tier) + math.max(0, seasonsPlayed);

/// **What a card has to LOSE to stop being this tier** — nine points for a
/// World Legend, who runs 86 to 95.
///
/// Usually the band's own height, because the bands are contiguous: drop nine
/// from the bottom of 86-95 and you are into 76-85. **T9 is the exception and
/// it is why this is not just `maxRating - rating`.** The Football Icon is a
/// flat 100, floor and ceiling alike, so its height is nought — and a walk that
/// subtracts nought takes a free rung, which drew every Icon as a World Legend
/// on the day it was scouted. What leaving T9 actually costs is the gap down to
/// the best World Legend there is: 100 to 95, five points. The `max` is both
/// readings at once.
///
/// The BAND, not a definition's own spread: `PlayerDef.rating` is the band
/// floor times `_posVariance`, so it answers a different question for each of
/// the four positions. [effectiveTierFor] wants the LADDER, and the ladder is
/// the same ladder for a keeper and a striker.
int tierDropCost(int tier) {
  _Tier? here;
  _Tier? below;
  for (final t in _tiers) {
    if (t.tier == tier) here = t;
    if (t.tier == tier - 1) below = t;
  }
  here ??= _tiers.first;
  final height = here.maxRating - here.rating;
  final gap = below == null ? height : here.rating - below.maxRating;
  return math.max(1, math.max(height, gap));
}

/// **THE TIER THE CARD PRESENTS AS once age has eaten into it.**
///
/// A World Legend who has declined past what a World Legend is worth stops
/// LOOKING like one: the border, the gradient and the tier chip drop to
/// Legendary Icon, then Gold Superstar, and so on down. Nothing else about him
/// changes — same portrait, same name, same age, same `definitionId`, so he
/// still merges, sells and scouts as what he is. The colour is the warning, and
/// for a T8 forward it comes at 35, 37, 38 and 39: Legend, Gold Superstar, Gold
/// Elite, and silver in his final season.
///
/// **A RUNG PER BAND LOST, walked down the ladder's own steps**, rather than
/// asking which band the declined rating lands in. That looks like the obvious
/// implementation and it is wrong for three positions out of four: a fresh card
/// sits exactly ON its tier's floor (a T7 midfielder is a 76 and the band
/// starts at 76), so an absolute test demotes him the first year he loses a
/// single point — a colour change for one rating point, which reads as a bug
/// rather than as a decline. Only forwards have headroom, because only their
/// variance is above 1.
///
/// Measuring the LOSS against the heights instead gives every position the same
/// grace and the same cadence, and means two World Legends of an age wear the
/// same colour whatever spread they rolled. A tier is nine or ten points tall;
/// lose that much and you have lost a tier's worth of quality.
///
/// Deliberately measured off the age alone — not off `getEffectiveRating`.
/// Form, sponsor drawback and the trait bonus all move week to week, and a card
/// that changes colour because a striker had a bad run is a card that means
/// nothing. Age only goes one way, so this only goes one way.
int effectiveTierFor(PlayerDef? def, int age) {
  if (def == null) return 1;
  var remaining = ageDeclinePenalty(age);
  var tier = def.tier;
  while (tier > 1) {
    final band = tierDropCost(tier);
    if (remaining < band) break;
    remaining -= band;
    tier--;
  }
  return tier;
}

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
    (1, 15),
    (2, 22),
    (3, 20),
    (4, 16),
    (5, 12),
    (6, 8),
    (7, 4.5),
    (8, 1.5),
    (9, 1),
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

/// A card's name for display: whatever the player renamed it to, the name it
/// was generated with, or its definition's.
String getCardName(Map<String, dynamic>? card, [String fallback = '']) {
  final custom = card?['customName'];
  if (custom is String && custom.isNotEmpty) return custom;
  final display = card?['displayName'];
  if (display is String && display.isNotEmpty) return display;
  return getPlayerDef(card?['definitionId'] as String?)?.name ?? fallback;
}
