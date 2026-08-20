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
import 'package:merge_empire_fc/ui/screens/club/asset_ladder_sheet.dart';
import 'package:merge_empire_fc/ui/screens/club/asset_tier_copy.dart';
import 'package:merge_empire_fc/ui/screens/club/club_stats_panel.dart';
import 'package:merge_empire_fc/ui/screens/club/kit_picker.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/svg_canvas.dart';
import 'package:merge_empire_fc/util/format.dart';

/// One facility, resolved — including WHAT IT GIVES, which the card had never
/// said. [perk] is what the club has at this tier and [next] is only what the
/// step up changes; both come off `club_asset_tiers.dart` through
/// `asset_tier_copy.dart`.
typedef AssetTile = ({
  String key,
  bool owned,
  int tier,
  bool maxed,
  double progress,
  int nextCost,
  String? blocked,
  String perk,
  String? next,

  /// How far short the club is, for the button that says so rather than just
  /// going grey.
  int shortBy,
});

final assetTilesProvider = savePick<List<AssetTile>>((s) {
  final coins = _coinsOf(s);
  return [
    for (final key in AssetCategory.all)
      () {
        final owned = isAssetOwned(s, key);
        final tier = assetTier(s, key);
        final cost = owned ? nextInvestCost(s, key) : buildCost;
        return (
          key: key,
          owned: owned,
          tier: tier,
          maxed: isAssetMaxed(s, key),
          progress: investProgress(s, key),
          nextCost: cost,
          blocked: owned ? investBlocked(s, key) : buildBlocked(s, key),
          perk: assetPerkLine(key, tier),
          next: owned
              ? assetNextLine(key, tier)
              : assetNextLine(key, 0) ?? assetPerkLine(key, 1),
          shortBy: (cost - coins).clamp(0, cost).toInt(),
        );
      }(),
  ];
});

int _coinsOf(Map<String, dynamic> s) {
  final resources = s['resources'];
  final coins = resources is Map<String, dynamic>
      ? resources['fanCoins']
      : null;
  return coins is num ? coins.toInt() : 0;
}

final ownedAssetCountProvider = savePick<int>(
  (s) => AssetCategory.all.where((k) => isAssetOwned(s, k)).length,
);

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
          // A GRID, as the JS lays it out — `minmax(165px, 1fr)`, so two across
          // on a phone and three on a tablet. Seven full-width rows was a
          // settings list; the facility a player is looking for is found by its
          // artwork, and artwork needs the width of a tile rather than a strip
          // beside three lines of text.
          _AssetGrid(tiles: tiles),
          const SizedBox(height: 14),
          const ClubStatsPanel(),
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

/// The seven facilities. Wrapped rather than a `GridView`: the screen is one
/// scroll view already, and the cards in a row have to be the same height as
/// each other — which is what `IntrinsicHeight` over a plain `Row` buys and a
/// grid delegate's fixed aspect ratio does not.
class _AssetGrid extends StatelessWidget {
  const _AssetGrid({required this.tiles});

  final List<AssetTile> tiles;

  /// The JS's `minmax(165px, 1fr)`.
  static const double _minTile = 165;
  static const double _gap = 10;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = ((constraints.maxWidth + _gap) / (_minTile + _gap))
          .floor()
          .clamp(1, 4);
      final rows = <List<AssetTile>>[];
      for (var i = 0; i < tiles.length; i += columns) {
        rows.add(tiles.sublist(i, math.min(i + columns, tiles.length)));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) const SizedBox(height: _gap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < columns; c++) ...[
                    if (c > 0) const SizedBox(width: _gap),
                    // The short last row keeps its columns empty rather than
                    // stretching the cards that ARE there across the screen.
                    Expanded(
                      child: c < rows[r].length
                          ? _AssetPanel(tile: rows[r][c])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
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
  Future<void> _buy(BuildContext context, WidgetRef ref, GameState game) async {
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
      bonus:
          tile.key == AssetCategory.stadium &&
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
    final buildable = tile.blocked == null;
    final ink = assetTierColour(tile.owned ? tile.tier : 0);

    return InkWell(
      key: ValueKey('club-asset-${tile.key}'),
      borderRadius: BorderRadius.circular(12),
      // **The WHOLE card.** Tapping a facility to see what it has unlocked and
      // what it has not is the obvious thing to try, and only the artwork
      // answered — so the sheet that holds every tier was effectively hidden
      // behind a 64px-tall strip.
      onTap: tile.owned ? () => _openLadder(context) : null,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: kit.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kit.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Art(tile: tile, ink: ink, onTap: () => _openLadder(context)),
            const SizedBox(height: 7),
            // The name, with the facility's own glyph tinted by its tier — so a
            // gold Stadium reads as gold before a word of it is read.
            InkWell(
              onTap: tile.owned ? () => _openLadder(context) : null,
              child: Row(
                children: [
                  GameIcon(
                    assetCategoryIcon[tile.key] ?? 'club',
                    size: 15,
                    color: tile.owned ? ink : kit.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      t('asset.${tile.key}.name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // **What it GIVES.** The card used to show the flavour hint here and
            // nothing else, so a player investing had no idea what they were
            // buying — and `club_asset_tiers.dart`, which computes exactly this,
            // had no caller at all. An unbuilt facility shows its hint instead:
            // there is no perk yet to state.
            SizedBox(
              height: 29,
              child: Text(
                tile.owned ? tile.perk : t('asset.${tile.key}.hint'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: tile.owned ? null : kit.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 5),
            if (tile.owned) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  key: ValueKey('club-progress-${tile.key}'),
                  value: tile.progress,
                  minHeight: 7,
                  backgroundColor: Colors.black.withValues(alpha: 0.25),
                  valueColor: AlwaysStoppedAnimation(
                    tile.maxed ? const Color(0xFF00C8FF) : kit.accent,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              // Only what the NEXT tier changes — and at the top of the ladder,
              // where it goes, because leaving the row blank punched a hole
              // between the full bar and the button.
              SizedBox(
                height: 27,
                child: Text(
                  tile.maxed
                      ? '${t('club.tier_n', {'n': maxAssetTier})} · ${t('club.maxed')}'
                      : tile.next ?? '',
                  key: ValueKey('club-next-${tile.key}'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.35,
                    color: kit.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 7),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: ValueKey('club-action-${tile.key}'),
                onPressed: !buildable ? null : () => _buy(context, ref, game),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  textStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: Text(
                  _actionLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openLadder(BuildContext context) =>
      showAssetLadderSheet(context, tile.key);

  /// What the button says.
  ///
  /// A dead button that only greys out tells the player nothing; the JS names
  /// the shortfall instead, which is the difference between "you cannot" and
  /// "you need this much more". The other two refusals — no players yet, top of
  /// the ladder — are their own copy.
  String _actionLabel() => switch (tile.blocked) {
    _ when tile.maxed => '★ ${t('club.maxed')}',
    'needs_player' => t('club.sign_player_first'),
    'insufficient_coins' when tile.shortBy > 0 => t('club.need_more', {
      'coin': '💰',
      'amount': formatCoins(tile.shortBy),
    }),
    // A refusal the engine has but this screen has no words for. It should not
    // happen; a dead button with a price on it and no reason should not either.
    null || 'insufficient_coins' =>
      '${tile.owned ? t('club.invest') : t('club.build')} '
          '💰 ${formatCoins(tile.nextCost)}',
    _ => t('settings.comingSoon'),
  };
}

/// The facility's artwork, and the two badges on it: what tier it is at, and
/// that there is a ladder behind it.
class _Art extends StatelessWidget {
  const _Art({required this.tile, required this.ink, required this.onTap});

  final AssetTile tile;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return GestureDetector(
      onTap: tile.owned ? onTap : null,
      child: Stack(
        children: [
          // Full width, as tall as the JS's `TILE_H`. It had been a 52px square
          // beside the text, which is a list icon — the artwork is generated per
          // tier and is how a facility is recognised.
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 64,
              width: double.infinity,
              child: ArtImage(
                key: ValueKey('club-art-${tile.key}'),
                path: clubAssetImagePath(tile.key, tile.owned ? tile.tier : 1),
                // An unbuilt facility shows its tier-one art, drained: what it
                // will look like is a better prompt than an empty square.
                dimmed: !tile.owned,
                dimBrightness: 0.45,
                fallback: SvgArt(
                  svg: clubArtFor(tile.key, tile.owned ? tile.tier : 1),
                ),
              ),
            ),
          ),
          Positioned(
            top: 5,
            right: 5,
            child: tile.owned
                ? Container(
                    key: ValueKey('club-tier-badge-${tile.key}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: tile.maxed ? const Color(0xFF00C8FF) : ink,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tile.maxed ? '★ MAX' : t('club.tier_n', {'n': tile.tier}),
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.4,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Color(0x66000000), blurRadius: 2),
                        ],
                      ),
                    ),
                  )
                : Container(
                    key: ValueKey('club-locked-${tile.key}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      size: 10,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
          ),
          // The ladder is one tap away, and this is what says so.
          if (tile.owned)
            Positioned(
              bottom: 5,
              right: 5,
              child: Container(
                width: 17,
                height: 17,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.6),
                ),
                child: Icon(
                  Icons.info_outline,
                  size: 11,
                  color: kit.textMuted.withValues(alpha: 0.95),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
