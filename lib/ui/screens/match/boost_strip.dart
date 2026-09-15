/// The in-game boosts: a tile on the end of the tactic strip, and the sheet
/// it opens.
///
/// **NOT A ROW OF THEIR OWN.** They were a second strip under the tactics —
/// 34 points, permanently, on a screen with none to spare — and a tactic and
/// a boost are the same kind of decision: a change to how the side plays for
/// a while. Asked for from the couch. So they are the sixth tile on the
/// tactic strip, and the sheet under it is where the three are picked.
///
/// **The sheet holds the match**, the way the bench does: picking a boost is
/// a decision about what happens next, and the clock waiting for it is what
/// makes "when" the decision it is meant to be.
///
/// **Only the proactive three.** VAR, the sponge and the quiet word undo
/// something already written and are taken at the bench, in front of the
/// consequence.
///
/// **Nothing is for sale here.** A boost you have none of reads x0 and is
/// dead; the shop is where a gem is spent.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/boosts.dart';
import 'package:merge_empire_fc/engine/boost_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/popups/sheet_header.dart';
import 'package:merge_empire_fc/ui/screens/match/boost_bar_paint.dart'
    show liveBoostColour;
import 'package:merge_empire_fc/ui/theme/glass.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';

/// The three a manager can call from the touchline.
List<Boost> get proactiveBoosts => [
  for (final b in boostList)
    if (b.kind == BoostKind.proactive) b,
];

/// The sixth tile on the tactic strip: the bolt, how many are in the bag,
/// and the colour of whatever window is burning.
class BoostTacticTile extends ConsumerWidget {
  const BoostTacticTile({
    super.key,
    required this.liveId,
    required this.enabled,
    required this.onTap,
  });

  /// The window burning the bar, or null. See `barBurn`.
  final String? liveId;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final state = ref.watch(gameProvider).state;
    var owned = 0;
    for (final b in proactiveBoosts) {
      owned += boostCount(state, b.id);
    }
    final live = liveId != null;
    final hue = live ? liveBoostColour(liveId!) : null;
    final ink = live
        ? Colors.white
        : owned > 0
            ? glassAccent(context, kit.accentBright)
            : kit.textMuted;
    return GestureDetector(
      key: const ValueKey('match-boosts'),
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: DecoratedBox(
        decoration: BoxDecoration(color: hue ?? kit.surface2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GameIcon('bolt', size: 17, color: ink),
                const SizedBox(height: 1),
                Text(
                  // The count is the label: what a manager wants to know at
                  // a glance is whether there is anything to call.
                  live ? t('boost.feed.action') : 'x$owned',
                  key: const ValueKey('match-boosts-count'),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Open the sheet; completes with the boost the manager called, or null.
Future<String?> showBoostSheet(
  BuildContext context, {
  required int? Function(String id) endOf,
}) => showBottomSheetPopup<String>(
  context,
  heightFraction: 0.6,
  child: BoostSheet(endOf: endOf),
);

class BoostSheet extends ConsumerWidget {
  const BoostSheet({super.key, required this.endOf});

  /// The minute a live window of this boost runs to, or null when none is.
  final int? Function(String id) endOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final state = ref.watch(gameProvider).state;
    return Column(
      key: const ValueKey('match-boost-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: t('boost.sheet.title'),
          subtitle: t('boost.sheet.sub'),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              for (final boost in proactiveBoosts)
                _BoostRow(
                  boost: boost,
                  count: boostCount(state, boost.id),
                  until: endOf(boost.id),
                  kit: kit,
                  onUse: () => Navigator.of(context).pop(boost.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BoostRow extends StatelessWidget {
  const _BoostRow({
    required this.boost,
    required this.count,
    required this.until,
    required this.kit,
    required this.onUse,
  });

  final Boost boost;
  final int count;
  final int? until;
  final KitTheme kit;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final live = until != null;
    final owned = count > 0;
    final hue = live ? liveBoostColour(boost.id) : null;
    final ink = owned || live ? kit.accentBright : kit.textMuted;
    return Semantics(
      button: owned,
      child: GestureDetector(
        key: ValueKey('match-boost-${boost.id}'),
        behavior: HitTestBehavior.opaque,
        // A dead row still swallows its tap: with no handler the tap falls
        // through to the barrier and closes the sheet under the thumb.
        onTap: owned ? onUse : () {},
        child: Opacity(
          opacity: owned || live ? 1 : 0.5,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: hue?.withValues(alpha: 0.18) ?? kit.surface2,
              border: Border.all(
                color: hue ?? (owned ? kit.accent : kit.border),
                width: live || owned ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                GameIcon(boost.icon, size: 24, color: hue ?? ink),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('boost.${boost.id}.name'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t('boost.${boost.id}.desc'),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: kit.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (live)
                  // Where the window ends, in match minutes — the same unit
                  // the bar burns in.
                  Text(
                    "→ $until'",
                    key: ValueKey('match-boost-until-${boost.id}'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: hue,
                    ),
                  )
                else
                  Text(
                    'x$count',
                    key: ValueKey('match-boost-count-${boost.id}'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
