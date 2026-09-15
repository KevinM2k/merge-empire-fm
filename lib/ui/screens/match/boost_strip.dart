/// The in-game boosts: three buttons in the corner of the pitch.
///
/// **NOT A ROW OF THEIR OWN, AND NOT A SHEET.** They were a second strip
/// under the tactics — 34 points, permanently, on a screen with none to spare
/// — then a sixth tile on the tactic strip, then a button that opened a
/// sheet. Asked for from the couch each time: the pitch is the thing a boost
/// acts on and the one band with room in its corners, and a boost is one tap,
/// not a menu. So the three sit on the grass, and a tap on one calls it.
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
import 'package:merge_empire_fc/ui/screens/match/boost_bar_paint.dart'
    show liveBoostColour;
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';

/// The three a manager can call from the touchline.
List<Boost> get proactiveBoosts => [
  for (final b in boostList)
    if (b.kind == BoostKind.proactive) b,
];

/// The three on the pitch, in a row in the corner: each its icon and how
/// many are in the bag, in its window's colour while that window burns.
class BoostPitchButtons extends ConsumerWidget {
  const BoostPitchButtons({
    super.key,
    required this.endOf,
    required this.enabled,
    required this.onUse,
  });

  /// The minute a live window of this boost runs to, or null when none is.
  final int? Function(String id) endOf;
  final bool enabled;
  final void Function(String id) onUse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider).state;
    return Row(
      key: const ValueKey('match-boosts'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final boost in proactiveBoosts) ...[
          _PitchChip(
            boost: boost,
            count: boostCount(state, boost.id),
            until: endOf(boost.id),
            enabled: enabled,
            onUse: () => onUse(boost.id),
          ),
          if (boost != proactiveBoosts.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _PitchChip extends StatelessWidget {
  const _PitchChip({
    required this.boost,
    required this.count,
    required this.until,
    required this.enabled,
    required this.onUse,
  });

  final Boost boost;
  final int count;
  final int? until;
  final bool enabled;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final live = until != null;
    final owned = count > 0;
    final hue = live ? liveBoostColour(boost.id) : null;
    final ink = live || owned ? Colors.white : Colors.white54;
    return Semantics(
      button: owned,
      child: GestureDetector(
        key: ValueKey('match-boost-${boost.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: owned && enabled ? onUse : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
        Container(
          height: 32,
          padding: const EdgeInsets.fromLTRB(7, 0, 8, 0),
          decoration: BoxDecoration(
            // Over grass, so it wears the glass the HUD wears rather than a
            // card: dark enough to read on the turf, the window's colour
            // while it burns.
            color: hue ?? Color(owned ? 0xCC12261A : 0x8812261A),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: hue != null ? Colors.white.withValues(alpha: 0.7) : Colors.white24,
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameIcon(boost.icon, size: 15, color: ink),
              const SizedBox(width: 4),
              if (live)
                // Where the window ends, in match minutes — the same unit
                // the bar burns in.
                Text(
                  "$until'",
                  key: ValueKey('match-boost-until-${boost.id}'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: ink),
                )
              else
                Text(
                  'x$count',
                  key: ValueKey('match-boost-count-${boost.id}'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: ink),
                ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        // Its name, in caps, on the grass: an icon alone is a guess for a
        // player who has not learned the three yet. Asked for from the couch.
        Text(
          t('boost.${boost.id}.name').toUpperCase(),
          maxLines: 1,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
            color: hue ?? Colors.white,
            shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 3)],
          ),
        ),
          ],
        ),
      ),
    );
  }
}
