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

const List<String> _grassrootsFirst = [
  'Red Lion', 'Crown', 'Anchor', 'Plough Lane', 'Old Oak', 'Mill Street',
  'Park', 'Valley', 'Borough', 'County', 'Riverside', 'Market Square',
  'Heath End', 'Hollow Lane', 'Brambleside', 'Three Horseshoes', 'Wheatsheaf',
  'Railway', 'Gasworks', 'Churchyard', 'Crossroads', 'Bluebell', 'Taproom',
  'Hillside', 'Meadow', 'Cobble Street', 'Brickfield', 'Quarry Lane',
  'Greenfield', 'Lakewood', 'Birchwood', 'Coppice', 'Fernhill', 'Oakdale',
];

const List<String> _semiproFirst = [
  'Northgate', 'Lakeside', 'Millfield', 'Westbrook', 'Eastgate', 'Southside',
  'Northbank', 'Riverbend', 'Clearwater', 'Highfield', 'Coalport', 'Ferndale',
  'Briarwood', 'Moorland', 'Hillcrest', 'Stonegate', 'Ashwick', 'Broadfield',
  'Clifton', 'Dunesbury', 'Eastvale', 'Fairmont', 'Greendale', 'Kingsmere',
  'Lockwood', 'Mapleton', 'Penwick', 'Harrowgate', 'Bridgetown', 'Iron Bridge',
  'Westport', 'Redfield', 'Thornbury', 'Aldermoor', 'Colston', 'Havenwick',
];

const List<String> _proPrefix = [
  'Real', 'Dynamo', 'Athletic', 'Sporting', 'Club', 'FC', 'Inter',
  'Red Star', 'Atlético', 'Olympique', 'Estrella', 'Union',
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
