/// Building and upgrading club assets.
///
/// Lifted out of `ui/screens/ClubScreen.js`, where the flow lived even though
/// its arithmetic did not: `buildCost`, `tapCost` and `tierThreshold` are all in
/// `data/club_assets.dart` and already pinned. What was missing was the rule
/// about WHEN a tap is allowed and what one does.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/club_assets.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

Map<String, dynamic> _branch(Map<String, dynamic> owner, String key) {
  final existing = owner[key];
  if (existing is Map<String, dynamic>) return existing;
  final fresh = <String, dynamic>{};
  owner[key] = fresh;
  return fresh;
}

num _coins(Map<String, dynamic>? state) =>
    _num(_map(state?['resources'])?['fanCoins']) ?? 0;

Map<String, dynamic> _asset(Map<String, dynamic>? state, String key) =>
    _map(_map(state?['clubAssets'])?[key]) ??
    <String, dynamic>{'owned': false, 'tier': 0, 'invested': 0, 'tapCount': 0};

bool isAssetOwned(Map<String, dynamic>? state, String key) =>
    _asset(state, key)['owned'] == true;

int assetTier(Map<String, dynamic>? state, String key) =>
    (_num(_asset(state, key)['tier']) ?? 0).toInt();

int assetInvested(Map<String, dynamic>? state, String key) =>
    (_num(_asset(state, key)['invested']) ?? 0).toInt();

int assetTapCount(Map<String, dynamic>? state, String key) =>
    (_num(_asset(state, key)['tapCount']) ?? 0).toInt();

bool isAssetMaxed(Map<String, dynamic>? state, String key) =>
    assetTier(state, key) >= maxAssetTier;

/// What the next tap costs. Zero at the ceiling, where there is nothing to buy.
int nextInvestCost(Map<String, dynamic>? state, String key) =>
    isAssetMaxed(state, key)
    ? 0
    : tapCost(assetTier(state, key), assetTapCount(state, key));

/// How far this tier has been funded, 0..1.
double investProgress(Map<String, dynamic>? state, String key) {
  if (isAssetMaxed(state, key)) return 1;
  final threshold = tierThreshold(assetTier(state, key));
  if (threshold <= 0) return 0;
  return (assetInvested(state, key) / threshold).clamp(0.0, 1.0);
}

int _playersOnGrid(Map<String, dynamic>? state) {
  final cells = _map(state?['grid'])?['cells'];
  if (cells is! List) return 0;
  return cells.where((c) => c != null).length;
}

/// Why a category cannot be built, or null when it can.
///
/// One of: `unknown_category`, `already_owned`, `needs_player`,
/// `insufficient_coins`.
String? buildBlocked(Map<String, dynamic>? state, String key) {
  if (!AssetCategory.all.contains(key)) return 'unknown_category';
  if (isAssetOwned(state, key)) return 'already_owned';
  // A club with no players is a club with nothing to put in a facility, and the
  // JS refuses the first build for exactly that reason.
  if (_playersOnGrid(state) < 1) return 'needs_player';
  if (_coins(state) < buildCost) return 'insufficient_coins';
  return null;
}

/// Why a category cannot be invested in, or null when it can.
///
/// One of: `unknown_category`, `not_owned`, `max_tier`, `insufficient_coins`.
String? investBlocked(Map<String, dynamic>? state, String key) {
  if (!AssetCategory.all.contains(key)) return 'unknown_category';
  if (!isAssetOwned(state, key)) return 'not_owned';
  if (isAssetMaxed(state, key)) return 'max_tier';
  if (_coins(state) < nextInvestCost(state, key)) return 'insufficient_coins';
  return null;
}

typedef AssetPurchase = ({
  bool ok,
  String? reason,
  int cost,
  int tier,
  bool tieredUp,
});

AssetPurchase _fail(String reason) =>
    (ok: false, reason: reason, cost: 0, tier: 0, tieredUp: false);

/// Build a category at tier one.
AssetPurchase buildAsset(Map<String, dynamic> state, String key) {
  final blocked = buildBlocked(state, key);
  if (blocked != null) return _fail(blocked);

  final resources = _branch(state, 'resources');
  resources['fanCoins'] = (_coins(state) - buildCost).toInt();
  _branch(state, 'clubAssets')[key] = <String, dynamic>{
    'owned': true,
    'tier': 1,
    'invested': 0,
    'tapCount': 0,
  };
  return (ok: true, reason: null, cost: buildCost, tier: 1, tieredUp: true);
}

/// One tap of investment. Tiers the asset up once the threshold is met.
///
/// The counters RESET on a tier-up rather than carrying the overspend forward:
/// each tier is priced as its own ladder, so carrying a remainder would make the
/// first tap of the next tier cheaper than the table says.
AssetPurchase investInAsset(Map<String, dynamic> state, String key) {
  final blocked = investBlocked(state, key);
  if (blocked != null) return _fail(blocked);

  final cost = nextInvestCost(state, key);
  final resources = _branch(state, 'resources');
  resources['fanCoins'] = (_coins(state) - cost).toInt();

  final asset = _branch(_branch(state, 'clubAssets'), key);
  final tier = assetTier(state, key);
  asset['invested'] = assetInvested(state, key) + cost;
  asset['tapCount'] = assetTapCount(state, key) + 1;

  var tieredUp = false;
  var newTier = tier;
  if ((_num(asset['invested']) ?? 0) >= tierThreshold(tier) &&
      tier < maxAssetTier) {
    newTier = tier + 1;
    asset['tier'] = newTier;
    asset['invested'] = 0;
    asset['tapCount'] = 0;
    tieredUp = true;
  }

  return (
    ok: true,
    reason: null,
    cost: cost,
    tier: newTier,
    tieredUp: tieredUp,
  );
}
