/// VAR and the Physio Sponge, offered at the bench.
///
/// **The bench is the only door for the retrospective pair, and why is worth
/// keeping.** A red card and an injury both pause the match into a Coach Colin
/// card and then open the subs panel behind it — but the red-card card shows
/// only ONCE, ever (`hasSeenTip`), while `openSubs()` runs every time. A boost
/// on the card would have been invisible at every red after the first. The
/// panel also already carries the state both boosts need, and it is open in
/// front of the consequence with the clock stopped.
///
/// **Closing the panel is the decision.** Whoever was on offer and not taken is
/// not coming back; the tile then says so — "too late, play has restarted" —
/// rather than going silently dead. A greyed control with no explanation is
/// what generates "is this broken?" reports.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/data/boosts.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/screens/match/boost_bar_paint.dart' show flameDeep;
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';

/// One retrospective boost as the bench offers it right now.
///
/// [onUse] is null when it cannot be taken, and [reason] then says why — the
/// man it would be for has been passed on, nobody is down, or none is owned.
typedef BenchBoostOffer = ({
  String id,
  int count,
  String? targetName,
  String? reason,
  VoidCallback? onUse,
});

class BenchBoostRow extends StatelessWidget {
  const BenchBoostRow({super.key, required this.offers});

  final List<BenchBoostOffer> offers;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Padding(
      key: const ValueKey('bench-boosts'),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      // All three the same size, whatever their names wrap to.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < offers.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _OfferTile(offer: offers[i], kit: kit)),
            ],
          ],
        ),
      ),
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({required this.offer, required this.kit});

  final BenchBoostOffer offer;
  final KitTheme kit;

  @override
  Widget build(BuildContext context) {
    final boost = getBoost(offer.id);
    final live = offer.onUse != null;
    // **THE ICON IN THE CALENDAR'S RED, THE NAME UNDER IT, AND NOTHING
    // ELSE.** The tile carried a truncated name beside the icon and a line
    // of prose under it — "No sending-off to review" — which read as three
    // different tiles. It is one shape now, greyed whole when it cannot be
    // used; WHY it cannot is a long-press away. Asked for from the couch.
    final reason = offer.reason ??
        (offer.targetName == null
            ? ''
            : t('boost.bench.for', {'player': offer.targetName!}));
    return Tooltip(
      key: ValueKey('bench-boost-reason-${offer.id}'),
      message: reason,
      child: Semantics(
        button: live,
        label: '${t('boost.${offer.id}.name')}. $reason',
        child: GestureDetector(
          key: ValueKey('bench-boost-${offer.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: offer.onUse,
          child: Opacity(
            opacity: live ? 1 : 0.45,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: live ? kit.accent.withValues(alpha: 0.16) : kit.surface2,
                border: Border.all(
                  color: live ? kit.accent : kit.border,
                  width: live ? 1.6 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GameIcon(boost?.icon ?? '', size: 22, color: flameDeep),
                      const SizedBox(width: 5),
                      Text(
                        'x${offer.count}',
                        key: ValueKey('bench-boost-count-${offer.id}'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: live ? kit.accentBright : kit.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t('boost.${offer.id}.name'),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                      color: live ? kit.accentBright : kit.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
