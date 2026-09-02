/// Game constants, ported from `../merge-empire-fc/src/data/config.js`.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

/// Bump when the save schema gains fields needing a back-fill in the migration
/// chain. v2 added top-level `events`; v4 re-rolled pyramid attackBias; v5 reset
/// over-depleted fitness bars; v6 was claimed independently by both the quest
/// tracks and `deadlineDay`, so the merged schema is v7.
const int saveVersion = 7;

/// What this build is, for the one place in the game that says so — the footer
/// on every Settings tab.
///
/// The JS reads `package.json` at build time. There is no runtime equivalent of
/// that here without a plugin, so it is a constant — and a test asserts it
/// against `pubspec.yaml`, because a version string that has quietly drifted is
/// worse than none: it is the first thing a support message needs and the one
/// thing a screenshot cannot tell you.
const String appVersion = '1.2.0';

/// Coins a brand-new player starts with. Single source of truth — used by
/// `createDefaultState` and surfaced in the welcome tutorial copy.
const int startingCoins = 1500;

class Grid {
  const Grid._();

  static const int cols = 3;
  static const int rows = 13;
  static const int totalCells = 39;

  /// Base roster. Only Youth Academy grows it, +1 per tier to a max of 8, so 39
  /// cells covers 30 + 8 with one spare. Anything that sells roster slots has to
  /// check this number first: a slot the grid cannot hold is a slot the player
  /// cannot use.
  static const int maxPlayers = 30;

  /// **HOW MANY SQUARES ARE WORTH DRAWING**, which is not [totalCells].
  ///
  /// The save carries 39 cells and always has — that array's length is compared
  /// field for field against the JS's default state, so it does not move. But
  /// the roster tops out at [maxPlayers] plus the Academy's eight tiers, so the
  /// thirty-ninth is a padlock nothing in the game can ever open. Reported from
  /// the couch: it just stays locked forever, so get rid of it.
  ///
  /// The cell is still THERE — nothing about the save changes, and a hypothetical
  /// future ladder that raised the cap would only have to raise this — it is
  /// simply not drawn.
  static const int shownCells = maxPlayers + maxAcademyTiers;

  /// The Academy's ceiling, which is `maxAssetTier` in `club_assets.dart`. Named
  /// here as well because [shownCells] is a `const` and cannot reach across to
  /// a file that imports this one.
  static const int maxAcademyTiers = 8;
}

class ClubGrid {
  const ClubGrid._();

  static const int cols = 4;
  static const int rows = 3;
  static const int totalCells = 12;
  static const int maxAssets = 12;
}

class Energy {
  const Energy._();

  static const int max = 10;
  static const int maxUpgraded = 15;
  static const int regenMs = 10 * 60 * 1000;
  static const int regenMsUpgraded = 450000; // 7.5 minutes

  /// Pips a rewarded video pays. Three, not five: five was half a tank for 30
  /// seconds, which made the regen timer — and everything priced against it —
  /// close to irrelevant.
  static const int adReward = 3;
  static const int matchCost = 1;

  /// Don't preload the energy rewarded ad above this. AdMob caches exactly one
  /// rewarded ad globally, so an untapped prefetch evicts the placement the
  /// player was actually about to use.
  static const int adPrefetchMax = 5;
}

/// Pro-mode per-player fatigue, in two layers. Only used when
/// `settings.hardMode` is true; Casual keeps the [Energy] pip pool.
///
/// Layer 1 — persistent fitness: each match permanently costs a proportional
/// amount, recovering slowly in real time. Layer 2 — in-match dip: a further
/// temporary weakening across the 90 that fully recovers at full time and is
/// never persisted.
///
/// Balance invariant (layer 1 only): games-per-hour is governed by recovery,
/// not drain. Fatigue perks scale cost AND recovery by the same factor, so they
/// help in-match strength only — never total matches before a refill. Keep the
/// perk out of the dip.
class PlayerEnergy {
  const PlayerEnergy._();

  /// Persistent fitness lost per full 90, as a fraction of max.
  static const double matchFitnessCostPct = 0.09;

  /// Temporary within-match weakening, kickoff to full time.
  static const double inMatchDipPct = 0.16;

  /// Wall-clock to recover an empty bar 0->100%.
  static const int fitnessFullRegenMs = 110 * 60 * 1000;

  /// Energy Director: ~33% faster.
  static const int fitnessFullRegenMsUpgraded = 75 * 60 * 1000;

  /// Players above the fit threshold needed to field a side.
  static const int minFitToField = 11;

  /// A player is match-fit while fitness/max exceeds this.
  static const double fitThresholdPct = 0.10;

  /// No rating penalty above this fraction — mild tiredness should not show in
  /// ATK/DEF. Below it the remaining range is rescaled so the curve stays
  /// continuous and still reaches zero at empty. Display-only fitness is
  /// unaffected; this shapes the rating multiplier alone.
  static const double fatigueDeadZonePct = 0.85;

  /// Match split into this many equal segments for the fatigue sim.
  static const int segments = 6;

  static const int maxSubs = 5;

  /// Rewarded-ad refill tops up each player by this, capped at 100%.
  static const double adRefillPct = 0.25;

  /// Paid packs can bank fitness to 200% — a buffer holding a player at full
  /// rating until it drains back below 100%.
  static const int overfillMult = 2;

  static const Map<String, double> strategyDrainMult = {
    'balanced': 1.0,
    'allOutAttack': 1.3,
    'parkTheBus': 0.85,
    'counterAttack': 0.9,
    'highPress': 1.6,
  };

  /// Older players tire faster: +4% drain per season played.
  static const double ageDrainPerSeason = 0.04;
}

class Scout {
  const Scout._();

  /// sunday_league fallback.
  static const int baseCost = 200;

  static const Map<String, int> baseCostByDiv = {
    'sunday_league': 200, // 2x match win
    'amateur_cup': 1000, // 4x match win
    'regional_league': 3000, // 5x match win
    'national_league': 10000, // 6.7x match win
    'elite_league': 30000, // 7.5x match win
    'continental': 120000, // 6x match win
    'champions_cup': 960000, // 8x match win
  };
}

class Asset {
  const Asset._();

  static const int baseCost = 1500;

  static const Map<String, int> baseCostByDiv = {
    'sunday_league': 1500, // ~15x match win
    'amateur_cup': 7000, // ~28x match win
    'regional_league': 25000, // ~42x match win
    'national_league': 80000, // ~53x match win
    'elite_league': 250000, // ~62x match win
    'continental': 1500000, // ~75x match win
    'champions_cup': 15000000, // ~125x match win
  };
}

/// Mini-game coin rewards taper in the lower divisions so early mini-games do
/// not overshadow match income, then hold at ~37.5% of match revenue from Elite
/// upward. Kept separate from match rewards so it can be tuned without touching
/// match income or IAP maths.
class Minigame {
  const Minigame._();

  static const Map<String, int> baseByDiv = {
    'sunday_league': 100, // 1.00x match base
    'amateur_cup': 200, // 0.80x match
    'regional_league': 400, // 0.67x match
    'national_league': 800, // 0.53x match
    'elite_league': 1500, // 0.375x match — taper plateaus here
    'continental': 7500, // 0.375x match
    'champions_cup': 45000, // 0.375x match
  };

  /// Free "skip every cooldown" videos a day. Past them the button reprices to
  /// gems rather than dying, so this ends the free ride, not the feature.
  static const int skipCapPerDay = 3;
  static const int skipGemCost = 1;
}

class Idle {
  const Idle._();

  static const int tickMs = 1000;
  static const int maxOfflineMs = 8 * 60 * 60 * 1000;
  static const double boostMultiplier = 2.0;
  static const int boostDurationMs = 2 * 60 * 60 * 1000;

  /// Show the welcome-back modal only past this much time away.
  static const int offlineNotifyThresholdMs = 5 * 60 * 1000;
}

class Merge {
  const Merge._();

  /// Drag two matching cards to merge — simpler UX than three.
  static const int requiredCount = 2;
}

class Form {
  const Form._();

  static const int min = -1;
  static const int max = 1;

  /// +/-5% per level on squad-rating contribution.
  static const double ratingPctPerLevel = 0.05;
}
