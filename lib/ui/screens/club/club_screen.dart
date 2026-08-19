/// The Club tab — the seven facilities, and what it costs to grow them.
///
/// Every rule is `club_asset_engine`'s: what a build costs, what the next tap
/// costs, when a tier turns over and why a button is dead. The screen asks and
/// paints.
///
/// The tiles are PNG-first, like the JS: the generated art per (category, tier)
/// with `club_art.g.dart`'s composed SVG as the fallback underneath. Both are
/// wanted — the artwork is generated per tier and a newly added facility can
/// legitimately have none yet, in which case a drawing beats a hole.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/art_paths.dart';
import 'package:merge_empire_fc/data/club_art.g.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/engine/club_asset_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/ui/widgets/svg_canvas.dart';
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

/// Which stadium photo hangs over the screen.
///
/// An unbuilt Stadium still shows tier one rather than nothing — the ground is
/// where the club plays whether or not it has been invested in, and an empty
/// band at the top of the screen says the screen is broken.
final stadiumTierProvider = savePick<int>(
  (s) => math.max(1, assetTier(s, AssetCategory.stadium)),
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
          _StadiumHero(tier: ref.watch(stadiumTierProvider)),
          const SizedBox(height: 10),
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

/// The photo across the top of the Club screen, one per Stadium tier.
///
/// `docs/REMAINING.md` had this blocked on teaching `svg_canvas` about
/// `linearGradient`, `radialGradient` and `<defs>`, because the JS's fallback
/// draws the six grounds as gradient-filled SVG. It is only the FALLBACK: the
/// hero a player actually sees is a photograph, and all eight are bundled. The
/// gradient work was never on the path to this screen.
///
/// What stands in when a photo is missing is a plain two-stop gradient rather
/// than a port of that SVG. Flutter draws gradients natively, nothing else in
/// the game wants the SVG machinery, and every tier's photo exists — a test in
/// `test/data/art_paths_test.dart` keeps it that way.
class _StadiumHero extends StatelessWidget {
  const _StadiumHero({required this.tier});

  final int tier;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        // `clamp(140px, 35vw, 200px)`.
        height: (MediaQuery.sizeOf(context).width * 0.35).clamp(140.0, 200.0),
        width: double.infinity,
        child: Semantics(
          label: t('club.stadium_alt'),
          image: true,
          child: ArtImage(
            key: ValueKey('club-stadium-hero-$tier'),
            path: stadiumBackgroundPath(tier),
            fallback: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [kit.surface2, kit.surface],
                ),
              ),
            ),
          ),
        ),
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
                // The generated artwork, with the composed SVG behind it as the
                // fallback — the same order the JS uses, and the reason both
                // exist. An unbuilt facility shows its tier-one art dimmed:
                // what it will look like is a better prompt than an empty
                // square.
                Container(
                  width: 52,
                  height: 52,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: kit.surface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kit.border),
                  ),
                  child: ArtImage(
                    key: ValueKey('club-art-${tile.key}'),
                    path: clubAssetImagePath(
                      tile.key,
                      tile.owned ? tile.tier : 1,
                    ),
                    dimmed: !tile.owned,
                    dimBrightness: 0.45,
                    fallback: SvgArt(
                      svg: clubArtFor(tile.key, tile.owned ? tile.tier : 1),
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
