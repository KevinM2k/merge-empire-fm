/// The Players tab action bar: Add Player, the batch it signs, and Merge.
///
/// The action the game opens on: a fresh save has an empty grid, and without
/// this there is nothing to merge, nobody to field and no way to start.
///
/// **Add Player and ×N are ONE segmented control.** The multiplier is not its
/// own action — it only says what a Scout tap buys — so the two share a border
/// and sit flush with no gap. That is also what makes room for Merge beside
/// them: three equal buttons in the bar left every label wrapping on a narrow
/// phone, which is why Sort left the bar to become a floating action.
///
/// **×N is one segment that CYCLES**, ×1 → ×2 → ×4, and it cycles only through
/// sizes this save can pay for and house. Showing a ×4 that runs out of coins on
/// the third card is the trap that avoids — by the time the player finds out,
/// they have already tapped.
///
/// **The signing is not over when the coins leave.** A batch is drawn, revealed
/// and only then settled: the tier rules cash their cards in after the player
/// has seen them, and the button stays dead for the whole sequence — a second
/// tap mid-reveal would draw over the batch being turned over.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/merge_flow_engine.dart';
import 'package:merge_empire_fc/engine/scout_signing_engine.dart';
import 'package:merge_empire_fc/engine/scout_voucher_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/ui/screens/grid/auto_tier_sheet.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart';
import 'package:merge_empire_fc/ui/screens/grid/scout_reveal.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/util/format.dart';

final signBlockedProvider = savePick<String?>(signBlocked);
final signCostProvider = savePick<int>(scoutCost);
final signIsFreeProvider = savePick<bool>((s) => scoutCost(s) == 0);

/// The unit price with any voucher IGNORED. A voucher covers the FIRST card
/// only, so a batch's remaining cards are charged at this rate — and a discount
/// the player cannot see is not a reward.
final signFullCostProvider = savePick<int>(
  (s) => scoutCost(s, ignoreVoucher: true),
);

/// The tier floor a Guaranteed Scout has armed, if one is held. The button wears
/// that tier's colour: before this, an armed Bronze+ voucher and a plain free
/// scout were the same green button with the same chip, so the one thing bought
/// with gems was invisible at the moment of spending it.
final scoutVoucherTierProvider = savePick<int?>(heldVoucherTier);

/// What a tap will buy, and what the player could pick instead.
final scoutBatchProvider = savePick<int>(effectiveScoutBatch);
final scoutBatchSizesProvider = savePick<String>(
  // A String, not a List: `savePick` compares with `==` and a fresh list every
  // rebuild would never match itself.
  (s) => availableScoutBatchSizes(s).join(','),
);

/// The card palette, by tier — `data-tier-theme` in `Card.js`. A voucher paints
/// the button its own tier's colour so the button, the shop tile and the card
/// that turns up are the same colour by construction.
const _tierAccent = <int, (Color, Color)>{
  1: (Color(0xFF8D6E63), Color(0xFFA1887F)),
  2: (Color(0xFF78909C), Color(0xFF90A4AE)),
  3: (Color(0xFF43A047), Color(0xFF66BB6A)),
  4: (Color(0xFF1E88E5), Color(0xFF42A5F5)),
  5: (Color(0xFF8E24AA), Color(0xFFAB47BC)),
  6: (Color(0xFFF9A825), Color(0xFFFFCA28)),
  7: (Color(0xFFE53935), Color(0xFFEF5350)),
  8: (Color(0xFF00ACC1), Color(0xFF26C6DA)),
  9: (Color(0xFF7E57C2), Color(0xFF9575CD)),
};

/// Why the button is dead, in copy that already ships.
String signBlockedCopy(String reason) => switch (reason) {
  'insufficient_coins' => t('toast.not_enough_coins'),
  'grid_full' => t('grid.player_count'),
  _ => t('settings.comingSoon'),
};

/// The bar: `[Add Player | ×N]  [Merge]`.
class ScoutActionBar extends StatelessWidget {
  const ScoutActionBar({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: AddPlayerButton()),
        SizedBox(width: 8),
        _MergeAllButton(),
      ],
    ),
  );
}

class AddPlayerButton extends ConsumerStatefulWidget {
  const AddPlayerButton({super.key});

  @override
  ConsumerState<AddPlayerButton> createState() => AddPlayerButtonState();
}

class AddPlayerButtonState extends ConsumerState<AddPlayerButton> {
  /// Dead while a batch is being turned over. The JS calls this `_revealing` and
  /// sets it before the draw for the same reason: the draw announces new coins,
  /// and anything that re-reads the state would otherwise re-enable the button
  /// under a reveal that is still running.
  bool _revealing = false;

  /// Test seam.
  bool get isRevealing => _revealing;

  Future<void> _scout(GameState game, int batch) async {
    if (_revealing) return;
    setState(() => _revealing = true);
    try {
      final result = game.update((s) => signPlayers(s, batch));
      if (result.placed.isEmpty) return;

      // Read the cards AFTER the draw and BEFORE the settle: they are all really
      // in the grid at this point, which is what lets an auto-sold one be shown
      // at full size before it is cashed in.
      final reveal = scoutRevealFor(game.state, result.placed);

      // And HELD BACK from the grid until the reveal has finished. The engine
      // has to place a signing to allocate its square, so without this the card
      // is already sitting in the cell it is about to be flown into and the
      // flight lands on top of itself.
      final pending = pendingInstanceIds(game.state, result.placed);
      if (pending.isNotEmpty) {
        ref.read(gridPendingProvider.notifier).state = pending;
      }

      try {
        if (reveal != null && mounted) {
          // The grid lends the way home, and is null when there is no grid to
          // fly into — the button is on the Players tab, but a test pumps it
          // alone.
          await showScoutReveal(
            context,
            reveal,
            landing: ref.read(scoutLandingProvider),
          );
        }
      } finally {
        if (pending.isNotEmpty && ref.exists(gridPendingProvider)) {
          ref.read(gridPendingProvider.notifier).state = const {};
        }
      }

      game.update((s) => settleAutoSales(s, result.placed));
    } finally {
      if (mounted) setState(() => _revealing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final blocked = ref.watch(signBlockedProvider);
    final free = ref.watch(signIsFreeProvider);
    final voucher = ref.watch(scoutVoucherTierProvider);
    final counted = ref.watch(gridCountProvider);
    final game = ref.read(gameProvider);

    final batch = ref.watch(scoutBatchProvider);
    final sizes = [
      for (final n in ref.watch(scoutBatchSizesProvider).split(','))
        int.tryParse(n) ?? 1,
    ];
    final tutorialDone = ref.watch(tutorialDoneProvider);
    final atMax = counted.filled >= counted.max;
    final dead = blocked != null || _revealing;

    // The free scout covers the FIRST card only, so the rest are charged at the
    // normal rate — hence the two costs.
    final int total = free
        ? (batch - 1).clamp(0, batch).toInt() * ref.watch(signFullCostProvider)
        : ref.watch(signCostProvider) * batch;

    // Both halves dead greys the whole group out together, matching Merge. A
    // literal grey on the ×N alone left a grey stub hanging off a green button
    // and broke the group in two.
    final tier = voucher == null ? null : _tierAccent[voucher];
    final fill = dead ? kit.surface2 : tier?.$2 ?? kit.accent;
    final ink = dead
        ? kit.textMuted
        : (tier != null ? Colors.white : kit.accentInk);
    final edge = dead ? kit.border : fill;

    return Semantics(
      label: t('players.batch_aria'),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: edge),
        ),
        child: ClipRRect(
          // 9 not 10: the border sits outside, so an equal radius leaves a
          // hairline of fill outside the stroke on the corners.
          borderRadius: BorderRadius.circular(9),
          child: Row(
            children: [
              Expanded(
                child: _Segment(
                  segKey: 'add-player',
                  // A voucher is a gradient rather than a flat fill, so it reads
                  // as the thing that was paid for in gems.
                  gradient: tier == null
                      ? null
                      : LinearGradient(
                          begin: const Alignment(-0.7, -1),
                          end: const Alignment(0.7, 1),
                          colors: [tier.$2, tier.$1],
                        ),
                  fill: fill,
                  ink: ink,
                  onTap: dead ? null : () => _scout(game, batch),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GameIcon('userAdd', size: 16, color: ink),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          t('players.addPlayer'),
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: TextStyle(
                            color: ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // The price rides on the button rather than a tooltip: it
                      // changes with the division and the Academy, and a player
                      // deciding whether to sign is deciding whether to spend. A
                      // batch quotes the WHOLE spend, not the unit.
                      if (atMax)
                        Text(
                          '${counted.filled}/${counted.max}',
                          style: TextStyle(
                            color: ink.withValues(alpha: 0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      else if (free)
                        _FreeChip(
                          // A ticket, not a clover, once gems have been spent —
                          // the colour says WHICH voucher, so the chip only has
                          // to say that this scout costs no coins.
                          icon: voucher == null ? 'clover' : 'ticket',
                          extra: batch > 1 ? total : null,
                        )
                      else
                        _Price(value: total, ink: ink),
                    ],
                  ),
                ),
              ),
              // Always shown once the tutorial is done — it just goes disabled at
              // ×1 when there is nothing to cycle to. Hiding it would reflow the
              // bar and keep the feature a secret from anyone who happens to be
              // short at the moment they look.
              if (tutorialDone)
                _BatchSegment(
                  batch: batch,
                  sizes: sizes,
                  bothDead: dead,
                  onCycle: _revealing
                      ? null
                      : () => game.update(
                          (s) => setScoutBatch(
                            s,
                            sizes[(sizes.indexOf(batch) + 1) % sizes.length],
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The ×N chip.
///
/// Both states stay in the accent family so the segment always reads as part of
/// the Add Player control it modifies; what changes is which half of the group
/// looks selected. ×1 is the accent fill knocked back with a black wash so it
/// recedes behind the primary action; ×2/×4 inverts to a solid ink chip with
/// accent text, the unmistakable "selected tab" of the pair.
class _BatchSegment extends StatelessWidget {
  const _BatchSegment({
    required this.batch,
    required this.sizes,
    required this.bothDead,
    required this.onCycle,
  });

  final int batch;
  final List<int> sizes;
  final bool bothDead;
  final VoidCallback? onCycle;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    // Stuck at ×1 — cannot afford a second, or one slot left — while Add Player
    // itself is still live.
    final stuck = sizes.length < 2;
    final multi = batch > 1;

    final Color fill;
    final Color ink;
    // **THE SELECTED CHIP NEEDS AN EDGE IN LIGHT MODE.** Inverting to an
    // accent-ink fill is what makes ×2/×4 read as the selected half of the pair
    // — but `accentInk` IS near-white on a light theme, and the page behind the
    // bar is near-white too, so the chip disappeared and the ×4 floated on
    // nothing. The edge is the ACCENT, which is the colour the chip inverted
    // away from, so the pair still reads as one control.
    Color? outline;
    if (bothDead) {
      fill = kit.surface2;
      ink = kit.textMuted;
    } else if (multi) {
      fill = kit.accentInk;
      ink = kit.accent;
      outline = kit.accent;
    } else {
      // The wash is a translucent black over the accent rather than a pre-mixed
      // colour, so it works on any kit accent.
      fill = Color.alphaBlend(
        Colors.black.withValues(alpha: stuck ? 0.5 : 0.26),
        kit.accent,
      );
      ink = kit.accentInk;
    }

    return Opacity(
      opacity: stuck && !bothDead ? 0.6 : 1,
      child: _Segment(
        segKey: 'scout-batch',
        fill: fill,
        ink: ink,
        outline: outline,
        onTap: stuck ? null : onCycle,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        child: Text(
          '×$batch',
          key: ValueKey('scout-batch-$batch'),
          style: TextStyle(
            color: ink,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            // ×1 → ×4 must not shift the bar.
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Merge, priced.
///
/// Dead rather than hidden when there is nothing to sweep or no money to pay
/// for it: the button carries its price, so a player who cannot pay can still
/// see what it would cost, and a button that vanishes reflows the bar.
class _MergeAllButton extends ConsumerWidget {
  const _MergeAllButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final pairs = ref.watch(mergeablePairsProvider);
    final cost = ref.watch(mergeAllCostProvider);
    final maxTier = ref.watch(maxMergeTierProvider);
    final canAfford = ref.watch(coinsProvider) >= cost;
    final game = ref.read(gameProvider);
    final dead = pairs == 0 || !canAfford;
    final ink = dead ? kit.textMuted : Theme.of(context).colorScheme.onSurface;

    return ConstrainedBox(
      // Capped so a long localised label cannot starve Add Player beside it.
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.34,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kit.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: _Segment(
            segKey: 'merge-all',
            fill: kit.surface2,
            ink: ink,
            onTap: dead
                ? null
                : () => game.update((s) => runMergeAll(s, maxTier: maxTier)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GameIcon('merge', size: 16, color: ink),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    t('players.merge'),
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(
                      color: ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (pairs > 0) ...[
                  const SizedBox(width: 6),
                  _Price(value: cost, ink: ink),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One half of the group: a flat fill with an ink press state, no border of its
/// own. The change in fill between the two halves IS the division — a seam line
/// against Add Player broke the group apart into two unrelated buttons.
class _Segment extends StatelessWidget {
  const _Segment({
    required this.segKey,
    required this.fill,
    required this.ink,
    required this.child,
    this.onTap,
    this.gradient,
    this.outline,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
  });

  final String segKey;
  final Color fill;
  final Color ink;
  final Widget child;
  final VoidCallback? onTap;
  final Gradient? gradient;

  /// A hairline round the segment, for the one case where the FILL is the page's
  /// own colour — see [_BatchSegment].
  final Color? outline;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final body = Material(
      color: gradient == null ? fill : Colors.transparent,
      child: Ink(
        decoration: gradient == null ? null : BoxDecoration(gradient: gradient),
        child: InkWell(
          key: ValueKey(segKey),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    if (outline == null) return body;
    return DecoratedBox(
      // Inside the segment rather than round the group: the group already has a
      // border, and this one has to separate ONE segment from the page.
      decoration: BoxDecoration(border: Border.all(color: outline!)),
      child: body,
    );
  }
}

/// A coin figure with the game's own coin glyph in front of it.
class _Price extends StatelessWidget {
  const _Price({required this.value, required this.ink});

  final int value;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // On an accent fill the light theme's bronze gold vanishes, so the coin
        // takes the button's ink there. `--color-gold: var(--color-accent-ink)`
        // in the JS, on this exact button.
        CoinIcon(size: 11, color: ink),
        const SizedBox(width: 2),
        Text(
          formatCoins(value),
          style: TextStyle(
            color: ink,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// "🍀 Free", and at ×2+ the rest of the batch's price beside it.
///
/// A dark pill, not accent text: the button itself is accent-coloured, so accent
/// on accent was the word disappearing into its own background. Same idiom as
/// the AD chip on rewarded-video buttons — it reads on any button colour.
class _FreeChip extends StatelessWidget {
  const _FreeChip({required this.icon, this.extra});

  final String icon;
  final int? extra;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameIcon(icon, size: 11, color: Colors.white),
              const SizedBox(width: 3),
              Text(
                t('players.free'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (extra != null && extra! > 0) ...[
          const SizedBox(width: 4),
          Opacity(
            opacity: 0.9,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '+ ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                _Price(value: extra!, ink: Colors.white),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
