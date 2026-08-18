/// The club-asset tier cards, against the JS they were ported from.
///
/// Every line is DERIVED from the function the game actually gates on, with the
/// milestone unlocks computed as a diff across the tier boundary — so the whole
/// ladder is compared, for all seven assets at all eight tiers, plus the delta
/// into each one. A port that reimplemented any of those curves would agree on
/// most rows and disagree on exactly the rows the original was written to fix:
/// Fan Zone's home advantage, which does NOT step at every tier, and the
/// Academy's slot, which does.
///
/// See `tool/dump_club_asset_tiers_reference.mjs`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/engine/club_asset_tiers.dart';

final Map<String, dynamic> _ref =
    jsonDecode(
          File(
            'test/fixtures/club_asset_tiers_reference.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

Map<String, dynamic> _section(String key) => _ref[key] as Map<String, dynamic>;

List<String> get _keys => (_ref['keys'] as List).cast<String>();

List<Map<String, dynamic>> _linesAsJson(List<TierLine> lines) => [
  for (final l in lines) {'id': l.id, 'params': l.params},
];

Map<String, dynamic>? _entryAsJson(TierEntry? e) => e == null
    ? null
    : {
        'tier': e.tier,
        'stats': _linesAsJson(e.stats),
        'unlocks': _linesAsJson(e.unlocks),
      };

void main() {
  test('the asset list and the tier cap match the JS', () {
    expect(_keys, AssetCategory.all);
    expect(maxAssetTier, _ref['maxAssetTier']);
  });

  test('parity — the cumulative stats at every tier', () {
    for (final key in _keys) {
      final want = _section('statsAt')[key] as Map<String, dynamic>;
      for (final entry in want.entries) {
        expect(
          _linesAsJson(assetStatsAt(key, int.parse(entry.key))),
          entry.value,
          reason: '$key tier ${entry.key}',
        );
      }
    }
  });

  test('parity — the milestone unlocks at every tier', () {
    for (final key in _keys) {
      final want = _section('unlocksAt')[key] as Map<String, dynamic>;
      for (final entry in want.entries) {
        expect(
          _linesAsJson(assetUnlocksAt(key, int.parse(entry.key))),
          entry.value,
          reason: '$key tier ${entry.key}',
        );
      }
    }
  });

  test('parity — what the next tier actually changes', () {
    for (final key in _keys) {
      final want = _section('delta')[key] as Map<String, dynamic>;
      for (final entry in want.entries) {
        expect(
          _entryAsJson(assetTierDelta(key, int.parse(entry.key))),
          entry.value,
          reason: '$key from tier ${entry.key}',
        );
      }
    }
  });

  test('parity — the whole ladder', () {
    for (final key in _keys) {
      expect(
        [for (final e in assetLadder(key)) _entryAsJson(e)],
        _section('ladder')[key],
        reason: key,
      );
    }
  });

  test('parity — an asset the catalogue does not know', () {
    final want = _section('unknownKey');
    expect(_linesAsJson(assetStatsAt('NOT_AN_ASSET', 3)), want['stats']);
    expect(_linesAsJson(assetUnlocksAt('NOT_AN_ASSET', 3)), want['unlocks']);
    expect(_entryAsJson(assetTierDelta('NOT_AN_ASSET', 3)), want['delta']);
    expect([
      for (final e in assetLadder('NOT_AN_ASSET')) _entryAsJson(e),
    ], want['ladder']);
  });

  group('the reason the file exists', () {
    test('a card never reprints a stat that did not move', () {
      // Fan Zone's home advantage steps at three tiers only. Reprinting it at
      // the other five is what made a working perk look broken.
      final steady = <int>[];
      for (var tier = 0; tier < maxAssetTier; tier++) {
        final delta = assetTierDelta(AssetCategory.fanzone, tier)!;
        if (delta.stats.isEmpty) steady.add(delta.tier);
      }
      expect(steady, isNotEmpty);
      for (final tier in steady) {
        // Reported as no change, so the number itself had better not have moved.
        expect(
          homeAdvantageAt(tier),
          homeAdvantageAt(tier - 1),
          reason: 'tier $tier',
        );
      }
      // And where the delta DOES report a stat, the number moved.
      for (var tier = 1; tier < maxAssetTier; tier++) {
        final delta = assetTierDelta(AssetCategory.fanzone, tier)!;
        if (delta.stats.isEmpty) continue;
        expect(
          homeAdvantageAt(delta.tier),
          isNot(homeAdvantageAt(tier)),
          reason: 'tier ${delta.tier}',
        );
      }
    });

    test('every milestone the gates grant is advertised, and no others', () {
      // Both directions, which is the whole claim: the unlock lines are a diff
      // of the live gate function rather than a hand-written list.
      for (var tier = 1; tier <= maxAssetTier; tier++) {
        final advertised = [
          for (final l in assetUnlocksAt(AssetCategory.training, tier))
            l.params['game'],
        ];
        final before = getUnlockedMinigames(
          _assets(AssetCategory.training, tier - 1),
        ).toSet();
        final after = getUnlockedMinigames(
          _assets(AssetCategory.training, tier),
        );
        expect(advertised, [
          for (final g in after)
            if (!before.contains(g)) g,
        ], reason: 'training tier $tier');
      }
    });

    test('the Academy advertises its slot at every tier, because it lands', () {
      for (var tier = 1; tier <= maxAssetTier; tier++) {
        expect(
          assetUnlocksAt(AssetCategory.academy, tier).single.params['n'],
          1,
          reason: 'academy tier $tier',
        );
      }
    });
  });
}

/// The home-advantage figure a Fan Zone tier carries, read back off the card.
Object? homeAdvantageAt(int tier) =>
    assetStatsAt(AssetCategory.fanzone, tier).single.params['n'];

Map<String, dynamic> _assets(String key, int tier) => {
  key: <String, dynamic>{'owned': tier > 0, 'tier': tier < 0 ? 0 : tier},
};
