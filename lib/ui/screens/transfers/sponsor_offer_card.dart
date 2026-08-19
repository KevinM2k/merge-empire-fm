/// A company wanting to sponsor one of your players. Ported from
/// `ui/components/SponsorshipOfferModal.js`.
///
/// Colin's card again, and for the same reason as the transfer bid: it is one
/// yes/no question with a read attached.
///
/// **Every drawback is named.** A sponsor pays income and most of them cost
/// something — rating, injury risk, form — and a card that showed only the
/// boost would be selling the deal rather than presenting it. `SponsorDrawback`
/// carries all three, so all three are drawn, and a clean deal says so rather
/// than leaving an empty space that reads as an omission.
///
/// Unlike the transfer bid this one cannot be parked. There is nothing pending
/// to come back to: a declined roll is simply not re-offered this match, and a
/// dismissal that recorded no answer would swallow the offer entirely.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/art_paths.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/sponsors.dart';
import 'package:merge_empire_fc/engine/sponsor_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/ui/widgets/player_portrait.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

num _num(Object? v) => v is num ? v : 0;

/// Offer the deal and settle it. Returns true when it was signed.
Future<bool> showSponsorOffer(
  BuildContext context,
  WidgetRef ref, {
  required CardInstance player,
  required Company company,
}) async {
  final accepted = await showDialog<bool>(
    context: context,
    // No parking, and no accidental dismissal: both answers have consequences
    // and neither of them is "nothing happened".
    barrierDismissible: false,
    builder: (_) => _SponsorOfferCard(player: player, company: company),
  );

  final game = ref.read(gameProvider);
  if (accepted == true) {
    game.update((s) => applySponsorship(s, player, company));
    return true;
  }
  game.update((s) {
    final stats = s.putIfAbsent('stats', () => <String, dynamic>{});
    if (stats is Map) {
      stats['sponsorsDeclined'] = _num(stats['sponsorsDeclined']).toInt() + 1;
    }
  });
  // The achievement sweep listens for this; declining sponsors is its own
  // small achievement track.
  emit('sponsor:declined');
  return false;
}

class _SponsorOfferCard extends StatelessWidget {
  const _SponsorOfferCard({required this.player, required this.company});

  final CardInstance player;
  final Company company;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final def = getPlayerDef(player.definitionId);
    final drawback = company.drawback;
    final boostPct = ((company.mult - 1) * 100).round();

    return AlertDialog(
      key: const ValueKey('sponsor-offer'),
      backgroundColor: kit.surface,
      title: Column(
        children: [
          Text(company.icon, style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 6),
          Text(
            t('sponsor.title', {'company': company.name}),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (def != null)
              SizedBox(
                height: 100,
                child: ArtImage(
                  path: playerImagePath(def.position, def.tier, player.variant),
                  fit: BoxFit.contain,
                  fallback: PlayerPortrait(
                    variantIndex: player.variant,
                    kitColor: kit.accent,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              t('sponsor.want_to_sponsor', {
                'player': player.name(def?.name ?? ''),
              }),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            _Term(
              label: t('sponsor.income_boost', {'n': boostPct}),
              good: true,
            ),
            if (drawback.isClean)
              _Term(label: t('sponsor.no_catch'), good: true)
            else ...[
              if (drawback.ratingPenalty > 0)
                _Term(
                  label: t('sponsor.cost_rating', {
                    'n': drawback.ratingPenalty,
                  }),
                  good: false,
                ),
              if (drawback.injuryPenalty > 0)
                _Term(
                  label: t('sponsor.cost_injury', {
                    'n': (drawback.injuryPenalty * 100).round(),
                  }),
                  good: false,
                ),
              if (drawback.formPenalty > 0)
                _Term(
                  label: t('sponsor.cost_form', {'n': drawback.formPenalty}),
                  good: false,
                ),
            ],
            const SizedBox(height: 10),
            Text(
              drawback.msg,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 1.5, color: kit.textMuted),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          key: const ValueKey('sponsor-decline'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t('common.decline')),
        ),
        ElevatedButton(
          key: const ValueKey('sponsor-accept'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(t('common.accept')),
        ),
      ],
    );
  }
}

class _Term extends StatelessWidget {
  const _Term({required this.label, required this.good});

  final String label;
  final bool good;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        color: good ? const Color(0xFF66BB6A) : const Color(0xFFEF5350),
      ),
    ),
  );
}
