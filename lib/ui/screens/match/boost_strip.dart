/// The two proactive boosts, under the tactic strip.
///
/// **Only the proactive pair.** VAR and the sponge undo something already
/// written and are taken at the bench, in front of the consequence; a tile for
/// them here would sit dead for most of a match and be covered by a coach card
/// at the one moment it mattered. Two tiles instead of four is also half the
/// height this screen has to give up — and it has none to spare.
///
/// **The strip is the shelf.** An owned boost shows its count and is tapped
/// here; one you have none of shows its gem price and takes you to the shop.
/// A greyed tile with no explanation is what generates "is this broken?"
/// reports, so a tile is never dead without a reason on it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/boosts.dart';
import 'package:merge_empire_fc/engine/boost_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/theme/glass.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart' show storeGemFace;
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';

/// Shorter than the tactic strip's 46 — this row is two tiles reading
/// horizontally, not five stacked glyph-and-word buttons.
const double boostStripHeight = 34;

class BoostStrip extends ConsumerWidget {
  const BoostStrip({
    super.key,
    required this.onUse,
    required this.endOf,
    required this.inset,
    required this.gap,
  });

  /// Tap an owned boost.
  final void Function(String id) onUse;

  /// The minute a live window of this boost runs to, or null when none is.
  final int? Function(String id) endOf;

  /// The page's own inset and band gap, handed in so this band sits in the
  /// same air as every other — the screen owns those numbers and imports this
  /// file, so they cannot be imported back.
  final double inset;
  final double gap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider).state;
    final proactive = [
      for (final b in boostList)
        if (b.kind == BoostKind.proactive) b,
    ];
    return Padding(
      // The page's own inset, and the same gap under it every band keeps —
      // `match_screen_test` measures the air above and below each one.
      padding: EdgeInsets.fromLTRB(inset, 0, inset, gap),
      child: SizedBox(
        key: const ValueKey('match-boosts'),
        height: boostStripHeight,
        child: GlassPanel(
          radius: 10,
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              for (var i = 0; i < proactive.length; i++)
                Expanded(
                  child: _BoostTile(
                    boost: proactive[i],
                    count: boostCount(state, proactive[i].id),
                    until: endOf(proactive[i].id),
                    last: i == proactive.length - 1,
                    onUse: () => onUse(proactive[i].id),
                    onShop: () => ref
                        .read(shellControllerProvider.notifier)
                        .deepLinkShop(ShopSection.boosts),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoostTile extends StatelessWidget {
  const _BoostTile({
    required this.boost,
    required this.count,
    required this.until,
    required this.last,
    required this.onUse,
    required this.onShop,
  });

  final Boost boost;
  final int count;
  final int? until;
  final bool last;
  final VoidCallback onUse;
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final live = until != null;
    final owned = count > 0;
    final ink = live
        ? glassAccent(context, kit.accentBright)
        : owned
            ? Theme.of(context).colorScheme.onSurface
            : kit.textMuted;
    return GestureDetector(
      key: ValueKey('match-boost-${boost.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: owned ? onUse : onShop,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: live ? kit.accent.withValues(alpha: 0.18) : Colors.transparent,
          border: last ? null : Border(right: BorderSide(color: kit.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GameIcon(boost.icon, size: 15, color: ink),
                const SizedBox(width: 6),
                Text(
                  t('boost.${boost.id}.name'),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(width: 6),
                if (live)
                  // Where the window ends, in match minutes — the same unit the
                  // bar burns in.
                  Text(
                    "→ $until'",
                    key: ValueKey('match-boost-until-${boost.id}'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                  )
                else if (owned)
                  Text(
                    'x$count',
                    key: ValueKey('match-boost-count-${boost.id}'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                  )
                else
                  Row(
                    key: ValueKey('match-boost-price-${boost.id}'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const GameIcon('gem', size: 11, color: storeGemFace),
                      const SizedBox(width: 2),
                      Text(
                        '${boost.gemCost}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
