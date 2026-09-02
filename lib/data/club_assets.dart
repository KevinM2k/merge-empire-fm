/// Club asset definitions, ported from
/// `../merge-empire-fc/src/data/clubAssets.js`.
///
/// ONE STAT PER ASSET. Every asset owns exactly one number that scales with its
/// tier, plus optional milestone unlocks — content or cosmetics appearing at
/// specific tiers, carrying no stat of their own. Assets used to overlap
/// (Training and Media both multiplied the same mini-game payout; Stadium
/// carried revenue AND home advantage). The current split:
///
///     TRAINING  cooldown  — how OFTEN mini-games can be played (+ unlocks games)
///     MEDIA     payout    — how MUCH mini-games pay
///     MERCH     idle income
///     STADIUM   match revenue                        (+ unlocks kit colours)
///     SPONSOR   player condition (injury recovery + match fatigue)
///     ACADEMY   scout cost                           (+ unlocks squad slots)
///     FANZONE   home advantage             (+ unlocks manager customisations)
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

class AssetCategory {
  const AssetCategory._();

  static const String training = 'TRAINING';
  static const String merch = 'MERCH';
  static const String stadium = 'STADIUM';
  static const String media = 'MEDIA';
  static const String sponsor = 'SPONSOR';
  static const String academy = 'ACADEMY';
  static const String fanzone = 'FANZONE';

  /// Declaration order is the canonical order and matters: it is the order the
  /// default state writes its keys in, which the save round-trip preserves.
  static const List<String> all = [
    training,
    merch,
    stadium,
    media,
    sponsor,
    academy,
    fanzone,
  ];
}

/// Canonical fresh clubAssets state — EVERY category present and unowned.
///
/// Single source of truth for the default state, the save-migration back-fill
/// and the prestige wipe. A category missing from any of those surfaces as
/// undefined-vs-unowned drift, which ACADEMY historically did.
Map<String, dynamic> defaultClubAssets() => {
  for (final cat in AssetCategory.all)
    cat: <String, dynamic>{
      'owned': false,
      'tier': 0,
      'invested': 0,
      'tapCount': 0,
    },
};

class AssetMeta {
  const AssetMeta({required this.name, required this.hint, required this.icon});

  final String name;
  final String hint;
  final String icon;
}

const Map<String, AssetMeta> assetMeta = {
  AssetCategory.training: AssetMeta(
    name: 'Training Ground',
    hint:
        'Shortens mini-game cooldowns, and unlocks more mini-games as you upgrade.',
    icon: 'dumbbell',
  ),
  AssetCategory.merch: AssetMeta(
    name: 'Merch Store',
    hint: 'Boosts idle coin income.',
    icon: 'bag',
  ),
  AssetCategory.stadium: AssetMeta(
    name: 'Stadium',
    hint: 'Increases match revenue and unlocks kit colours.',
    icon: 'club',
  ),
  AssetCategory.media: AssetMeta(
    name: 'Media Centre',
    hint: 'Boosts all minigame coin payouts.',
    icon: 'tv',
  ),
  AssetCategory.sponsor: AssetMeta(
    name: 'Kit Sponsor',
    hint: 'Players recover faster — shorter injuries and less match fatigue.',
    icon: 'handshake',
  ),
  AssetCategory.academy: AssetMeta(
    name: 'Youth Academy',
    hint: 'Cuts scout costs, and unlocks an extra squad slot at every tier.',
    icon: 'userAdd',
  ),
  AssetCategory.fanzone: AssetMeta(
    name: 'Fan Zone',
    hint:
        'Louder home crowd — bigger home advantage — and unlocks manager customisations.',
    icon: 'megaphone',
  ),
};

/// Taps required to advance from tier N to N+1 (index 0 unused). Higher tiers
/// need more taps, reflecting longer-term investment.
const List<int> _tapsPerTier = [0, 10, 15, 20, 25, 30, 35, 40];

/// Cost of the FIRST tap advancing from tier N to N+1.
const List<int> _tierFirstTapCost = [0, 80, 240, 700, 2000, 6000, 18000, 55000];

/// Cost of the LAST tap advancing from tier N to N+1 — always twice the first.
/// Constraint held: first(N+1) > last(N) for all N, so the next tier's opening
/// tap always costs more than the current tier's closing one.
const List<int> _tierLastTapCost = [0, 160, 480, 1400, 4000, 12000, 36000, 110000];

int _tapCostRaw(int tier, int tapIndex) {
  final first = tier < _tierFirstTapCost.length ? _tierFirstTapCost[tier] : 0;
  final last = tier < _tierLastTapCost.length ? _tierLastTapCost[tier] : first;
  final n = tier < _tapsPerTier.length ? _tapsPerTier[tier] : 1;
  if (n <= 1) return first;
  // JS Math.round; every value here is positive so half-up and half-away agree.
  return (first + tapIndex * (last - first) / (n - 1) + 0.5).floor();
}

/// Total coins to complete each tier, derived from the arithmetic tap-cost
/// sequence rather than tabulated: 1,200 / 5,400 / 21,000 / 75,000 / 270,000 /
/// 945,000 / 3,300,000.
final List<int> tierCosts = List.unmodifiable([
  for (var i = 0; i < _tierFirstTapCost.length; i++)
    if (i == 0)
      0
    else
      List.generate(_tapsPerTier[i], (j) => _tapCostRaw(i, j))
          .fold<int>(0, (a, b) => a + b),
]);

/// Taps needed to advance from [tier] to the next.
int tapsForTier(int tier) =>
    tier >= 0 && tier < _tapsPerTier.length ? _tapsPerTier[tier] : 0;

/// Cost of the next tap given the current tier and how many taps have already
/// been made in it. Costs rise linearly within a tier from first to last.
int tapCost(int tier, [int tapIndex = 0]) => _tapCostRaw(tier, tapIndex);

/// Total coins needed to fill the bar at [tier].
int tierThreshold(int tier) =>
    tier >= 0 && tier < tierCosts.length ? tierCosts[tier] : 0;

/// One-time build cost — flat regardless of division.
const int buildCost = 500;

const int maxAssetTier = 8;

// ── Effect helpers (pure, no state) ─────────────────────────────────────────

/// The tier PLUS how far into the next one the investment has got.
///
/// **EVERY TAP HAS TO BE WORTH SOMETHING.** The whole reward used to land at the
/// tier-up, so nineteen of twenty presses bought nothing a player could see and
/// the twentieth bought all of it. Asked for directly: twenty clicks for ten per
/// cent should be half a per cent a click.
///
/// **Only the CONTINUOUS benefits read this.** A percentage can be paid out in
/// twentieths; a squad slot, a mini-game, a kit colour and a home-advantage
/// rating point cannot — half an unlock is not a thing — so those keep the
/// integer tier and still arrive on the tier-up. That split is the whole design:
/// this is not a fractional tier, it is a fractional PAYMENT against one.
///
/// **It lives here rather than in `idle_engine.dart` because the effect helpers
/// under it need it.** Two of them were still stepping — the Kit Sponsor's
/// fatigue half and the Academy's scout discount — while the Sponsor's OTHER
/// half paid continuously, so one facility's two lines disagreed about whether a
/// tap was worth anything. `assetTierProgress` is the same function under the
/// name the rest of the app already calls it by.
double fractionalAssetTier(Map<String, dynamic>? clubAssets, String key) {
  final a = clubAssets?[key];
  if (a is! Map || a['owned'] != true) return 0;
  final raw = a['tier'];
  final tier = raw is num ? raw.toInt() : 0;
  if (tier >= maxAssetTier) return tier.toDouble();
  final threshold = tierThreshold(tier);
  if (threshold <= 0) return tier.toDouble();
  final invested = a['invested'];
  return tier +
      ((invested is num ? invested.toDouble() : 0.0) / threshold).clamp(
        0.0,
        1.0,
      );
}

/// Training Ground's one stat: how often mini-games come off cooldown.
///
/// It used to ALSO multiply mini-game payouts, double-dipping with Media Centre
/// on the same number. Payout is Media's job now; Training owns frequency.
/// **`num`, because the tier it is handed is FRACTIONAL** — see
/// `assetTierProgress`. Every tap of investment buys its own share of the
/// benefit rather than nineteen buying nothing and the twentieth buying it all.
double trainingCooldownMult(num tier) => 1 - math.min(0.40, 0.05 * tier);

/// Media Centre's one stat: mini-game coin payout. Raised from +10% to +19% per
/// tier when it absorbed Training's old +5%/tier reward multiplier, so a maxed
/// pair lands at x2.52 — the ceiling the two stacked multipliers used to reach.
double mediaPayoutMult(num tier) => 1 + 0.19 * tier;

/// Kit Sponsor's one stat: player condition. Sports science covers both halves
/// of "recovers faster" — injuries heal sooner and the squad tires more slowly
/// in Pro mode. Multiplicative (below 1 means slower drain), capped so it
/// cannot trivialise rotation. Recovery scales by the same factor, so a higher
/// Kit Sponsor means stronger players late in games, not more games.
double sponsorStaminaMult(Map<String, dynamic>? clubAssets) {
  // **The FRACTIONAL tier, like the recovery half beside it.** This read the
  // integer, so one facility paid one of its two stats per tap and the other
  // only on the tier-up — and the card printed both as though they moved
  // together. See [fractionalAssetTier].
  final tier = fractionalAssetTier(clubAssets, AssetCategory.sponsor);
  return 1 - math.min(0.30, 0.04 * tier); // up to -30% drain at tier 8
}

/// Youth Academy's one stat: what a scout costs. The +1 squad slot per tier is
/// not a second stat — it is this asset's milestone-unlock track, the same shape
/// as Stadium's kit colours and Training's mini-games.
/// **`num`, because the tier it is handed is FRACTIONAL** — a discount is a
/// percentage and a percentage can be paid in twentieths. See
/// [fractionalAssetTier].
double academyScoutDiscount(num tier) => math.min(0.20, 0.025 * tier);

int _tierOf(Map<String, dynamic>? clubAssets, String category) {
  final a = clubAssets?[category];
  if (a is! Map) return 0;
  if (a['owned'] != true) return 0;
  final tier = a['tier'];
  return tier is num ? tier.toInt() : 0;
}

/// Mini-games unlocked by Training Ground tier.
///
/// One game a rung, 0 through 6 — no dead tier. Penalty Training stays free
/// from the start so a save with no Training Ground still has somewhere to tap,
/// which is what teaches the panel exists. The ORDER is the ladder: the
/// mini-games panel renders in it.
/// Which Training Ground tier each drill arrives at.
///
/// The LADDER as data rather than as a stack of ifs, because two callers need it
/// now: the list of what is unlocked, and the locked row that has to say WHICH
/// tier unlocks it. A player who tiers up and finds a drill still greyed out has
/// no way of telling a missing screen from an unlock that did not fire, and the
/// tier number is the difference.
const Map<String, int> minigameUnlockTier = {
  'penalty': 0,
  'training': 1,
  'keepy_uppys': 2,
  'through_ball': 3,
  'whack': 4,
  'pairs': 5,
  'boot_room': 6,
};

List<String> getUnlockedMinigames(Map<String, dynamic>? clubAssets) {
  final tier = _tierOf(clubAssets, AssetCategory.training);
  return [
    for (final entry in minigameUnlockTier.entries)
      if (tier >= entry.value) entry.key,
  ];
}

/// Kit colours unlocked by Stadium tier. Stacks — every tier up to the current
/// one unlocks.
const Map<int, List<String>> stadiumColourUnlocks = {
  1: ['#33691e', '#0d47a1', '#006064', '#d35400'],
  // #00acc1 and #7f8c8d retired; existing saves migrate to the nearest kept hue.
  3: ['#880e4f', '#e91e63'],
  // #bdc3c7 / #e8e8e8 retired — near-white greys gave an almost colourless
  // accent on the neutral light surfaces.
  5: ['#795548', '#37474f'],
  7: ['sunset', 'midnight'],
  8: ['empire', 'void'],
};

List<String> getUnlockedColours(int stadiumTier) => [
  for (final entry in stadiumColourUnlocks.entries)
    if (entry.key <= stadiumTier) ...entry.value,
];

/// Home advantage lives on Fan Zone rather than Stadium, so Stadium owns match
/// revenue alone. The crowd is the twelfth man; the seats are just the takings.
int fanZoneTier(Map<String, dynamic>? clubAssets) =>
    _tierOf(clubAssets, AssetCategory.fanzone);
