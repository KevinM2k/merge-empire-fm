/// The Club tab — the seven facilities, and what it costs to grow them.
///
/// Every rule is `club_asset_engine`'s: what a build costs, what the next tap
/// costs, when a tier turns over and why a button is dead. The screen asks and
/// paints.
///
/// The tiles carry no ARTWORK yet. `assets/clubArt.js` is 430 lines of
/// hand-built SVG — 116 rects, 24 circles, 11 ellipses and fifteen simple
/// quadratics — which is a `CustomPainter` and needs no new dependency, but it
/// is its own module. A tier badge stands in until then, so the screen is
/// usable rather than blocked on illustration.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/engine/club_asset_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/format.dart';

/// One facility, resolved.
typedef AssetTile = ({
  String key,
  bool owned,
  int tier,
  bool maxed,
  double progress,
  int nextCost,
  String? blocked,
});

final assetTilesProvider = savePick<List<AssetTile>>(
  (s) => [
    for (final key in AssetCategory.all)
      (
        key: key,
        owned: isAssetOwned(s, key),
        tier: assetTier(s, key),
        maxed: isAssetMaxed(s, key),
        progress: investProgress(s, key),
        nextCost: isAssetOwned(s, key) ? nextInvestCost(s, key) : buildCost,
        blocked: isAssetOwned(s, key)
            ? investBlocked(s, key)
            : buildBlocked(s, key),
      ),
  ],
);

final ownedAssetCountProvider = savePick<int>(
  (s) => AssetCategory.all.where((k) => isAssetOwned(s, k)).length,
);

/// Why a button is dead, in copy that already ships.
String? assetBlockedCopy(String? reason) => switch (reason) {
  null => null,
  'insufficient_coins' => t('toast.not_enough_coins'),
  'needs_player' => t('club.build_needs_player'),
  'max_tier' => t('shop.owned'),
  _ => t('settings.comingSoon'),
};

class ClubScreen extends ConsumerWidget {
  const ClubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final tiles = ref.watch(assetTilesProvider);
    final owned = ref.watch(ownedAssetCountProvider);

    // Eager rather than a lazy ListView: seven panels is nothing, and a lazy
    // list leaves the ones below the fold unbuilt — which makes them invisible
    // to anything that wants to reach one.
    return SingleChildScrollView(
      key: const ValueKey('club-screen'),
      padding: const EdgeInsets.fromLTRB(12, 64, 12, 12),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              t('club.asset_count', {
                'n': owned,
                'max': AssetCategory.all.length,
              }),
              key: const ValueKey('club-asset-count'),
              style: TextStyle(color: kit.textMuted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          for (final tile in tiles) _AssetPanel(tile: tile),
        ],
      ),
    );
  }
}

class _AssetPanel extends ConsumerWidget {
  const _AssetPanel({required this.tile});

  final AssetTile tile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final game = ref.read(gameProvider);
    final reason = assetBlockedCopy(tile.blocked);
    final buildable = tile.blocked == null;

    return Card(
      key: ValueKey('club-asset-${tile.key}'),
      color: kit.surface,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Stands in for the artwork until clubArt lands.
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: kit.surface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kit.border),
                  ),
                  child: Text(
                    tile.owned ? '${tile.tier}' : '—',
                    style: TextStyle(
                      color: kit.accentBright,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('asset.${tile.key}.name'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        t('asset.${tile.key}.hint'),
                        style: TextStyle(color: kit.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (tile.owned) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  key: ValueKey('club-progress-${tile.key}'),
                  value: tile.progress,
                  minHeight: 6,
                  backgroundColor: kit.surface2,
                  valueColor: AlwaysStoppedAnimation(kit.accent),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tile.owned
                        ? t('club.tier_n', {'n': tile.tier})
                        : t('club.build'),
                    style: TextStyle(color: kit.textMuted, fontSize: 12),
                  ),
                ),
                if (reason != null)
                  Flexible(
                    child: Text(
                      reason,
                      textAlign: TextAlign.right,
                      style: TextStyle(color: kit.textMuted, fontSize: 11),
                    ),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  key: ValueKey('club-action-${tile.key}'),
                  onPressed: !buildable
                      ? null
                      : () => game.update(
                          (s) => tile.owned
                              ? investInAsset(s, tile.key)
                              : buildAsset(s, tile.key),
                        ),
                  child: Text(
                    tile.maxed
                        ? t('shop.owned')
                        : '${tile.owned ? t('club.invest') : t('club.build')}'
                              ' ${formatCoins(tile.nextCost)}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
