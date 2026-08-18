/// What every club asset gives at every tier, as structured data. Ported from
/// `../merge-empire-fc/src/engine/clubAssetTiers.js`.
///
/// The Club screen used to build these lines inline, which produced two things a
/// player could see and neither was right:
///
/// 1. The "Next" line repeated whatever the current line already said. Fan Zone
///    tier 5 to 6 read "+3 home advantage" twice, because the home-advantage
///    curve genuinely does NOT step there — it moves at tiers 2, 4 and 7 only.
///    The perk was fine; the card made it look broken.
/// 2. Milestone unlocks were hand-written per asset, so Stadium's kit colours
///    were never advertised anywhere on the card, while the Academy repeated the
///    constant "+1 player slot" on both the current AND the next line.
///
/// Everything here is DERIVED from the same functions the game actually gates
/// on, with unlocks computed as a DIFF between tier N-1 and tier N. A card
/// therefore cannot claim a perk the engine does not grant, and cannot miss one
/// it does — the tests pin both directions.
///
/// Output is UI-free: id and params pairs the Club screen maps onto translation
/// keys, the same shape the quests use for their icons.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:convert';

import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';

/// One line on a card: an id the UI maps to words, and its numbers.
typedef TierLine = ({String id, Map<String, dynamic> params});

/// A throwaway save with exactly one asset at one tier, so the real gate
/// functions can be asked what a tier WOULD give without a live state.
Map<String, dynamic> _at(String key, int tier) => {
  'clubAssets': <String, dynamic>{
    key: <String, dynamic>{'owned': tier > 0, 'tier': tier < 0 ? 0 : tier},
  },
};

Map<String, dynamic> _assets(String key, int tier) =>
    _at(key, tier)['clubAssets'] as Map<String, dynamic>;

/// A percentage to one decimal place, with a trailing `.0` dropped so the card
/// reads "-15%" rather than "-15.0%".
///
/// Training's -7.5% cooldown is why the decimal is kept at all.
num _pct(double fraction) {
  final rounded = double.parse((fraction * 100).toStringAsFixed(1));
  return rounded == rounded.roundToDouble() ? rounded.toInt() : rounded;
}

// ── Cumulative stats ────────────────────────────────────────────────────────
//
// The ONE number each asset owns — the Kit Sponsor's two halves of "condition"
// being the documented exception. Cumulative: this is what you HAVE at that
// tier, not what that tier added.

final Map<String, List<TierLine> Function(int)> _statBuilders = {
  AssetCategory.training: (tier) => [
    (id: 'cooldown', params: {'pct': _pct(1 - trainingCooldownMult(tier))}),
  ],
  AssetCategory.merch: (tier) => [
    (id: 'idle_income', params: {'pct': _pct(merchIncomeMultiplier(tier) - 1)}),
  ],
  AssetCategory.stadium: (tier) => [
    (
      id: 'match_revenue',
      params: {
        'mult': computeMatchRevenueMultiplier(
          _assets(AssetCategory.stadium, tier),
          null,
          null,
        ).toStringAsFixed(2),
      },
    ),
  ],
  AssetCategory.media: (tier) => [
    (id: 'minigame_coins', params: {'pct': _pct(mediaPayoutMult(tier) - 1)}),
  ],
  AssetCategory.sponsor: (tier) => [
    (
      id: 'injury_time',
      params: {
        'pct': _pct(
          1 - getInjuryRecoveryMult(_at(AssetCategory.sponsor, tier)),
        ),
      },
    ),
    (
      id: 'fatigue',
      params: {
        'pct': _pct(
          1 - sponsorStaminaMult(_assets(AssetCategory.sponsor, tier)),
        ),
      },
    ),
  ],
  AssetCategory.academy: (tier) => [
    (id: 'scout_cost', params: {'pct': _pct(academyScoutDiscount(tier))}),
  ],
  AssetCategory.fanzone: (tier) => [
    (id: 'home_adv', params: {'n': homeAdvantageDisplayFor(tier)}),
  ],
};

/// The cumulative stats an asset carries at [tier]. Tier 0 — unbuilt — has none.
List<TierLine> assetStatsAt(String key, int tier) =>
    tier > 0 ? (_statBuilders[key]?.call(tier) ?? const []) : const [];

// ── Milestone unlocks ───────────────────────────────────────────────────────
//
// Content that ARRIVES at one exact tier and carries no stat of its own. Each is
// a diff of the live gate function across the tier boundary, so nothing is
// hand-listed and nothing can drift.

List<String> _minigamesAt(int tier) =>
    getUnlockedMinigames(_assets(AssetCategory.training, tier));

List<String> _coloursAt(int tier) => getUnlockedColours(tier < 0 ? 0 : tier);

int _squadSlotsAt(int tier) => getMaxPlayers(_at(AssetCategory.academy, tier));

final Map<String, List<TierLine> Function(int)> _unlockBuilders = {
  AssetCategory.training: (tier) {
    final had = _minigamesAt(tier - 1).toSet();
    return [
      for (final game in _minigamesAt(tier))
        if (!had.contains(game)) (id: 'minigame', params: {'game': game}),
    ];
  },
  AssetCategory.stadium: (tier) {
    final had = _coloursAt(tier - 1).toSet();
    final gained = _coloursAt(tier).where((c) => !had.contains(c)).length;
    return gained > 0
        ? [
            (id: 'colours', params: {'n': gained}),
          ]
        : const <TierLine>[];
  },
  AssetCategory.academy: (tier) {
    final gained = _squadSlotsAt(tier) - _squadSlotsAt(tier - 1);
    return gained > 0
        ? [
            (id: 'slots', params: {'n': gained}),
          ]
        : const <TierLine>[];
  },
  // The Fan Zone hands over a DIFFERENT set of manager customisations at every
  // tier — the items, not a count. Counting them was what made eight tiers read
  // as one repeated reward when the ladder underneath was already varied. Home
  // advantage is deliberately the only number this asset moves, so the cosmetics
  // have to carry the variety.
  AssetCategory.fanzone: (tier) {
    final items = looksUnlockedAtTier(tier);
    return items.isNotEmpty
        ? [
            (id: 'looks', params: {'n': items.length, 'items': items}),
          ]
        : const <TierLine>[];
  },
};

/// Milestone content that arrives at exactly [tier]. Empty at most tiers.
List<TierLine> assetUnlocksAt(String key, int tier) =>
    tier > 0 ? (_unlockBuilders[key]?.call(tier) ?? const []) : const [];

// ── Deltas ──────────────────────────────────────────────────────────────────

bool _sameLine(TierLine a, TierLine b) =>
    a.id == b.id && jsonEncode(a.params) == jsonEncode(b.params);

/// What one tier of an asset is, for the ladder sheet.
typedef TierEntry = ({int tier, List<TierLine> stats, List<TierLine> unlocks});

/// What actually CHANGES stepping from [tier] to the next one — the only thing
/// the "Next" line on a card should ever show.
///
/// Stats that hold steady across the step are dropped rather than reprinted,
/// which is the whole Fan Zone fix. Null at max tier.
TierEntry? assetTierDelta(String key, int tier) {
  if (tier >= maxAssetTier) return null;
  final next = tier + 1;
  final before = assetStatsAt(key, tier);
  return (
    tier: next,
    stats: [
      for (final s in assetStatsAt(key, next))
        if (!before.any((b) => _sameLine(b, s))) s,
    ],
    unlocks: assetUnlocksAt(key, next),
  );
}

/// Every tier of an asset, for the upgrade-path sheet.
List<TierEntry> assetLadder(String key) => [
  for (var tier = 1; tier <= maxAssetTier; tier++)
    (
      tier: tier,
      stats: assetStatsAt(key, tier),
      unlocks: assetUnlocksAt(key, tier),
    ),
];
