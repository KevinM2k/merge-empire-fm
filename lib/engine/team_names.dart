/// Procedural team-name generation, ported from the name-bank half of
/// `../merge-empire-fc/src/engine/progressionEngine.js`.
///
/// The banks combine so the pool is effectively infinite and the old
/// "FC Reserve" placeholder fallbacks never occur.
///
/// Split into its own file because the save migration needs it to scrub stale
/// and blocked names, and pulling in the whole progression engine for that
/// would be a much bigger dependency than the job warrants.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/util/random.dart';

/// **EVERY ENTRY IS ONE WORD.** A name is `<first> <suffix>`, so a two-word
/// first name makes a three-word club: "Three Horseshoes Rangers" is 23
/// characters and wrapped to two lines in the league table, the fixture card,
/// the pyramid editor and the ticker. Reported from the couch. Ten of these,
/// one in [_semiproFirst] and one in [_proPrefix] were pub and street names,
/// and they are single words now.
///
/// **The bank LENGTHS are load-bearing** — the draw is `randomInt(0, length -
/// 1)` — so nothing was added or removed, only rewritten. And the STRINGS are
/// pinned: `progression_parity` and the season difftest are dumped from the
/// JS's own banks and compare club for club, so the same twelve changed in
/// `../merge-empire-fc/src/engine/progressionEngine.js` and both fixtures were
/// re-dumped.
const List<String> _grassrootsFirst = [
  'Redlands', 'Crown', 'Anchor', 'Ploughfield', 'Elmgrove', 'Millbrook',
  'Park', 'Valley', 'Borough', 'County', 'Riverside', 'Marketgate',
  'Heathside', 'Hollowbrook', 'Brambleside', 'Horseshoe', 'Wheatsheaf',
  'Railway', 'Gasworks', 'Churchyard', 'Crossroads', 'Bluebell', 'Taproom',
  'Hillside', 'Meadow', 'Cobblegate', 'Brickfield', 'Quarryside',
  'Greenfield', 'Lakewood', 'Birchwood', 'Coppice', 'Fernhill', 'Oakdale',
];

const List<String> _semiproFirst = [
  'Northgate', 'Lakeside', 'Millfield', 'Westbrook', 'Eastgate', 'Southside',
  'Northbank', 'Riverbend', 'Clearwater', 'Highfield', 'Coalport', 'Ferndale',
  'Briarwood', 'Moorland', 'Hillcrest', 'Stonegate', 'Ashwick', 'Broadfield',
  'Clifton', 'Dunesbury', 'Eastvale', 'Fairmont', 'Greendale', 'Kingsmere',
  'Lockwood', 'Mapleton', 'Penwick', 'Harrowgate', 'Bridgetown', 'Ironbridge',
  'Westport', 'Redfield', 'Thornbury', 'Aldermoor', 'Colston', 'Havenwick',
];

const List<String> _proPrefix = [
  'Real', 'Dynamo', 'Athletic', 'Sporting', 'Club', 'FC', 'Inter',
  'Rapid', 'Atlético', 'Olympique', 'Estrella', 'Union',
];

const List<String> _proNoun = [
  'Metropolis', 'Mondiale', 'Apex', 'Imperio', 'Elite', 'Internacional',
  'Stellaris', 'Zenith', 'Titan', 'Vanguard', 'Dominion', 'Royale',
  'Imperiale', 'Colossus', 'Grandeur', 'Phoenix', 'Supremo', 'Immortale',
  'Eternus', 'Celestial', 'Aurora', 'Meridian', 'Nova', 'Astra', 'Regnum',
  'Orion', 'Solstice', 'Maximus', 'Invictus', 'Apogee', 'Pantheon',
  'Prestigio', 'Monarchia', 'Veritas', 'Paragon', 'Monumental', 'Imperium',
  'Ascendant', 'Sovereign', 'Majestic', 'Triumphant', 'Luminar', 'Fortis',
  'Nobilis', 'Gloriosa', 'Magnifica', 'Caelestis', 'Invincta', 'Altus',
];

const List<String> _suffix = [
  'FC', 'City', 'United', 'Athletic', 'Rovers', 'Rangers',
  'Town', 'Wanderers', 'Villa', 'Albion', 'County', 'Park', 'Return',
];

/// Which name bank a division draws from.
String divTier(String? divId) {
  if (divId == 'sunday_league' || divId == 'amateur_cup') return 'grassroots';
  if (divId == 'regional_league' || divId == 'national_league') return 'semipro';
  return 'pro';
}

/// A unique team name for a division tier, not already in [used].
///
/// Draws from the SEEDED stream, matching the JS — this is gameplay
/// randomness, so it must advance the shared sequence.
String generateTeamName(String tier, Set<String> used) {
  String rnd(List<String> arr) => arr[randomInt(0, arr.length - 1)];

  for (var i = 0; i < 200; i++) {
    final String name;
    if (tier == 'pro') {
      name = '${rnd(_proPrefix)} ${rnd(_proNoun)}';
    } else {
      final first = rnd(tier == 'semipro' ? _semiproFirst : _grassrootsFirst);
      name = '$first ${rnd(_suffix)}';
    }
    if (!used.contains(name)) return name;
  }

  // Absolute last resort — statistically unreachable with these bank sizes.
  var n = 1;
  while (used.contains('Valley United $n')) {
    n++;
  }
  return 'Valley United $n';
}


/// A stable set of [count] names for a tier, derived from [seed] alone.
///
/// **This must not touch the seeded RNG.** [generateTeamName] draws from the
/// shared gameplay stream and ADVANCES it, which is correct when a season is
/// being rolled and catastrophic from a display path: the league table is built
/// on every save revision, so calling it there both handed back different teams
/// every rebuild — the table visibly reshuffling its clubs — and pulled the
/// sequence out from under the save's own determinism.
///
/// Deterministic and pure, so the same division and season always produce the
/// same league. Only ever a FALLBACK: a save with `seasonOpponents` stored uses
/// those, and every save made since the schedule landed has them.
List<String> stableTeamNames(String tier, int seed, int count) {
  // A small LCG rather than `Random(seed)`, so the sequence is fixed by this
  // code and cannot move under a Dart upgrade.
  var x = (seed & 0x7fffffff) | 1;
  int next() {
    x = (x * 1103515245 + 12345) & 0x7fffffff;
    return x;
  }

  final used = <String>{};
  final out = <String>[];
  // Bounded: the banks are large enough that this fills long before the cap, and
  // an unbounded loop on a pathological seed would hang the table.
  for (var i = 0; out.length < count && i < count * 200; i++) {
    final String name;
    if (tier == 'pro') {
      name =
          '${_proPrefix[next() % _proPrefix.length]} '
          '${_proNoun[next() % _proNoun.length]}';
    } else {
      final bank = tier == 'semipro' ? _semiproFirst : _grassrootsFirst;
      name = '${bank[next() % bank.length]} ${_suffix[next() % _suffix.length]}';
    }
    if (used.add(name)) out.add(name);
  }
  // Only reachable if the bank is smaller than `count`.
  while (out.length < count) {
    out.add('Valley United ${out.length + 1}');
  }
  return out;
}
