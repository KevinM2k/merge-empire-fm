/// The active-boost pills in the middle of the HUD — `.hud-boosts`.
///
/// **Only the boosts that affect IDLE INCOME**, which is the JS's own rule and
/// its own reason: the pills sit next to the income rate, so what belongs
/// beside it is what changes it. Match-only boosts — the TV deal, a per-match
/// kit sponsor — are surfaced in the pre-match prize card and the income
/// breakdown instead, which keeps the bar readable.
///
/// **They need no copy at all**, which is why they could be ported: the JS
/// writes "×2" and "🌟 VIP" with a unit letter after a number, and there is not
/// a `t()` in the whole function. A player with VIP running had nothing on the
/// bar saying so.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/time.dart';

/// Gold for both, which is the JS's colour for each of them: they are the two
/// things making money arrive faster.
const Color hudBoostInk = Color(0xFFFFD700);

/// One pill's worth.
typedef HudBoost = ({String label, String sub});

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
int _int(Object? v) => v is num ? v.toInt() : 0;

/// What is running, in the JS's own order: the temporary one first.
///
/// **Both round UP and floor at one.** A boost with forty seconds left is not
/// "0m" — that reads as expired — and the JS clamps both for the same reason.
List<HudBoost> hudBoostsFor(Map<String, dynamic>? state, {required int nowMs}) {
  final boosts = _map(state?['boosts']);
  if (boosts == null) return const [];
  final out = <HudBoost>[];

  final boostEnds = _int(boosts['incomeBoostEndsAt']);
  if (boosts['incomeBoostActive'] == true && boostEnds > nowMs) {
    final mins = ((boostEnds - nowMs) / 60000).ceil();
    out.add((label: '×2', sub: '${mins < 1 ? 1 : mins}m'));
  }

  final vipEnds = _int(boosts['vipExpiresAt']);
  if (boosts['vipActive'] == true && vipEnds > nowMs) {
    final days = ((vipEnds - nowMs) / 86400000).ceil();
    out.add((label: '🌟 VIP', sub: '${days < 1 ? 1 : days}d'));
  }

  // **THE TROPHY POLISH BELONGS HERE, and it could not before.** It is a ×2 on
  // idle income, which is this row's whole rule — but a pill's sub is a
  // countdown, and while the polish was a SEASON buff there were no minutes to
  // put on it. It runs for half an hour now, so eight gems buys something the
  // player can watch running and watch go. The glyph is the catalogue's own
  // 🏆, so this needs no copy, which is the other reason the row exists.
  final polishEnds = _int(boosts['trophyPolishUntil']);
  if (polishEnds > nowMs) {
    final mins = ((polishEnds - nowMs) / 60000).ceil();
    out.add((label: '🏆 ×2', sub: '${mins < 1 ? 1 : mins}m'));
  }
  return out;
}

/// Whatever is running, or nothing at all.
class HudBoosts extends ConsumerWidget {
  const HudBoosts({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boosts = ref.watch(hudBoostsProvider);
    if (boosts.isEmpty) return const SizedBox.shrink();
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Flexible(
      child: Row(
        key: const ValueKey('hud-boosts'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final boost in boosts)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Container(
                key: ValueKey('hud-boost-${boost.label}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: hudBoostInk.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hudBoostInk.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      boost.label,
                      style: const TextStyle(
                        color: hudBoostInk,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(width: 3),
                    // The remaining time is the small half: what it IS matters
                    // more than how long is left, and a clock the same weight
                    // as the label reads as two facts rather than one.
                    Text(
                      boost.sub,
                      style: TextStyle(
                        color: kit.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// **Re-read on the save's own beat, not on a clock of its own.** The counts
/// are minutes and days, and the idle loop already announces every second — a
/// second ticker to watch a number that changes once a minute is a frame budget
/// spent on nothing.
final hudBoostsProvider = savePick<List<HudBoost>>(
  (s) => hudBoostsFor(s, nowMs: now()),
);
