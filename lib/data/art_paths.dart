/// Where the shipped artwork lives. Ported from
/// `../merge-empire-fc/src/assets/svgCache.js`.
///
/// The JS file is two halves and only one of them is here. Its SVG half
/// pre-rendered `playerArt` and `clubArt` into data URLs so a card render did
/// not re-run the generator every frame; Flutter's painters and
/// `club_art.g.dart` already are that half, and a `CustomPainter` behind a
/// `RepaintBoundary` needs no cache of its own.
///
/// What was missing is this half: **the real game is PNG-first.** Every card,
/// every club tile and the stadium behind them are AI-generated artwork, and
/// the hand-drawn SVG is the `onerror` fallback — a newly added asset whose art
/// has not been generated yet, or a fetch that failed. The port had shipped the
/// fallback as if it were the artwork. [ArtImage] is the other side of this.
///
/// Deliberately Flutter-free: these are strings, and the architecture test
/// keeps `lib/data/` that way.
library;

import 'package:merge_empire_fc/data/player_art.dart';

/// Tiers the club artwork was generated for. A tier past the top reuses the
/// top one rather than showing nothing, which is what the JS's `Math.min` did.
const int maxClubArtTier = 8;

/// One PNG per (position, tier, gender): `_m` for male, `_f` for female.
///
/// Two of the portrait variants are female and the rest share the male art, so
/// sixteen positions-and-tiers become thirty-two files rather than one per
/// variant. [isVariantFemale] is the same predicate the names are drawn from,
/// so a card's art and its name never disagree about who it is.
String playerImagePath(String position, int tier, [int variantIdx = 0]) =>
    'assets/players/${position}_t$tier${isVariantFemale(variantIdx) ? '_f' : '_m'}.png';

/// One PNG per (category, tier), clamped to what exists.
String clubAssetImagePath(String category, int tier) =>
    'assets/club/${category}_t${tier.clamp(1, maxClubArtTier)}.png';

/// The stadium hero behind the Club screen, one per Stadium tier.
String stadiumBackgroundPath(int tier) =>
    'assets/bg/stadium_bg_t${tier.clamp(1, maxClubArtTier)}.jpeg';

/// The four Kenney backdrops, by mood.
///
/// **Only four of the pack are bundled**, at 92KB, rather than the 1.6MB it
/// ships: the rest is vectors, spritesheets, a preview and the element layers,
/// and a pubspec pointed at the raw folder would put all of it in the app. Same
/// rule the modular characters went in under.
///
/// They are cartoon skies with a treeline on them, 1024 square, and what they
/// are for is giving something a HORIZON — a penalty goal standing against a
/// wash of flat colour has nothing behind it, which is why its net had to be a
/// sheet to read as a hole at all.
enum Backdrop { grass, forest, fall, desert }

String backdropPath(Backdrop which) => switch (which) {
  Backdrop.grass => 'assets/bg/kenney/backgroundColorGrass.png',
  Backdrop.forest => 'assets/bg/kenney/backgroundColorForest.png',
  Backdrop.fall => 'assets/bg/kenney/backgroundColorFall.png',
  Backdrop.desert => 'assets/bg/kenney/backgroundColorDesert.png',
};

/// Trophy-room art. Two shapes, for the two things the room draws.
///
/// There is a third file on disk — `event_wc2026.png` — and nothing resolves
/// it. An event win became an achievement rather than a trophy card, so the art
/// is a leftover of the older arrangement; see the Trophy Room's header.
String divisionTrophyPath(String division) => 'assets/trophies/$division.png';

String cupTrophyPath(String cupId) => 'assets/trophies/cup_$cupId.png';

String achievementArtPath(String achievementId) =>
    'assets/trophies/achievement_$achievementId.png';
