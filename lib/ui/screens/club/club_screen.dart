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
import 'package:merge_empire_fc/ui/hud/hud.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/art_paths.dart';
import 'package:merge_empire_fc/data/club_art.g.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/engine/club_asset_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/ui/popups/feature_unlock.dart';
import 'package:merge_empire_fc/ui/screens/club/kit_picker.dart';
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
      padding: EdgeInsets.fromLTRB(12, hudClearanceOf(context), 12, 12),
      child: Column(
        children: [
          _StadiumHero(tier: ref.watch(stadiumTierProvider)),
          const SizedBox(height: 10),
          // The club's COLOURS, which theme the whole app. Directly under the
          // hero, because the hero is the other thing on this screen that is
          // about how the club looks rather than what it earns.
          const KitRedesignRow(),
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
/// The hero a player actually sees is a photograph, and all eight are bundled —
/// a test in `test/data/art_paths_test.dart` keeps it that way. What stands in
/// when one is missing is the JS's OWN fallback art: six grounds drawn as
/// gradient-filled SVG, which `svg_canvas` can draw now that it understands
/// `<defs>` and `url(#id)`.
///
/// It was a flat two-stop kit gradient while the painter could not, which was a
/// stand-in for a stand-in.
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
            fallback: _fallbackArt(kit),
          ),
        ),
      ),
    );
  }

  /// The JS's own fallback ground for this tier, or the kit gradient when the
  /// tier is past the six it draws.
  Widget _fallbackArt(KitTheme kit) {
    final index = tier - 1;
    if (index >= 0 && index < stadiumBackgrounds.length) {
      return SvgArt(svg: stadiumBackgrounds[index]);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kit.surface2, kit.surface],
        ),
      ),
    );
  }
}

class _AssetPanel extends ConsumerWidget {
  const _AssetPanel({required this.tile});

  final AssetTile tile;

  /// Build it or invest in it, and then SAY SO.
  ///
  /// The port took the coins, ticked the bar up and said nothing — so the one
  /// moment on this screen a player is paying for looked exactly like a number
  /// changing. `showFeatureUnlock` is the JS's payoff beat, and a tier-up gets it
  /// as well as a first build: the two are the same kind of event.
  Future<void> _buy(
    BuildContext context,
    WidgetRef ref,
    GameState game,
  ) async {
    final wasOwned = tile.owned;
    game.update(
      (s) => wasOwned ? investInAsset(s, tile.key) : buildAsset(s, tile.key),
    );
    if (!context.mounted) return;

    // Read the tier AFTER the purchase — the splash names what the club has now,
    // not what it had a moment ago.
    final tier = assetTier(game.state, tile.key);
    await showFeatureUnlock(
      context,
      title: t('asset.${tile.key}.name'),
      subtitle: t('asset.${tile.key}.hint'),
      isTierUp: wasOwned,
      // Bronze, silver then gold, the same ladder the JS tints its card by, so
      // the card gets brighter as the facility does.
      accent: tier >= 5
          ? const Color(0xFFFFD700)
          : tier >= 3
          ? const Color(0xFFAAAAAA)
          : const Color(0xFFCD7F32),
      starCount: tier.clamp(1, 3),
      // The Stadium is the one facility that unlocks something ELSE — a tier of
      // it opens new kit colours — and it rides on the same card rather than
      // arriving as a second popup behind this one.
      bonus: tile.key == AssetCategory.stadium &&
              stadiumColourUnlocks.containsKey(tier)
          ? t('club.kit_design')
          : null,
      icon: SizedBox(
        width: 54,
        height: 54,
        child: ArtImage(
          path: clubAssetImagePath(tile.key, tier < 1 ? 1 : tier),
          fallback: const Center(
            child: Text('🏟', style: TextStyle(fontSize: 30)),
          ),
        ),
      ),
    );
  }

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
                      : () => _buy(context, ref, game),
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
