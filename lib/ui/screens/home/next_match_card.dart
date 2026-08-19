/// The fixture in front of you. Ported from `_nextMatchHtml` in
/// `ui/screens/LeagueScreen.js`.
///
/// The one thing on the home screen that says what the Play button is going to
/// do: who, where, and how the two sides compare.
///
/// **The comparison is NUMBERS, and only numbers.** It has been five stars —
/// which banded a 0–100 figure into five buckets, so 61 and 79 drew an identical
/// row — and then a proportional bar beside the figure, which is the same
/// comparison drawn a second time and less precisely. Two big numbers either
/// side of the VS say "74 against 65" outright; a track that reads 74% full says
/// roughly that at best. On a card this crowded a duplicate of a stat is worth
/// less than the room it takes.
///
/// Everything here comes from `previewFixture`, which is the same call the match
/// itself uses — so the card cannot promise a fixture the sim then disagrees
/// with.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/fixture_preview.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// Everything the card draws.
typedef NextMatch = ({
  String us,
  String them,
  bool isHome,
  int ourRating,
  int? theirRating,
  int ourAttack,
  int ourDefence,
  int? theirAttack,
  int? theirDefence,
});

final nextMatchProvider = savePick<NextMatch?>((s) {
  final preview = previewFixture(s);
  if (preview == null) return null;
  return (
    us: s['clubName'] is String && (s['clubName'] as String).isNotEmpty
        ? s['clubName'] as String
        : t('common.your_club'),
    them: preview.opponentName,
    isHome: preview.isHome,
    ourRating: preview.effectiveSquadRating.round(),
    theirRating: preview.effectiveOppRating?.round(),
    ourAttack: preview.effAttack.round(),
    ourDefence: preview.effDefence.round(),
    theirAttack: preview.effOppAttackRating?.round(),
    theirDefence: preview.effOppDefenceRating?.round(),
  );
});

class NextMatchCard extends ConsumerWidget {
  const NextMatchCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final match = ref.watch(nextMatchProvider);
    // No fixture is a real state — a finished season, or a save that has not
    // drawn one yet — and an empty card would be worse than none.
    if (match == null) return const SizedBox.shrink();

    return Container(
      key: const ValueKey('next-match-card'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        // Translucent, so the scene behind reads through it.
        color: kit.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kit.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t('play.nextMatch').toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: kit.textMuted,
                  ),
                ),
              ),
              Text(
                t(match.isHome ? 'play.home' : 'play.away'),
                key: const ValueKey('next-match-venue'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                  color: kit.accentBright,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Side(
                  name: match.us,
                  rating: match.ourRating,
                  attack: match.ourAttack,
                  defence: match.ourDefence,
                  ours: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  t('common.vs').toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: kit.textMuted,
                  ),
                ),
              ),
              Expanded(
                child: _Side(
                  name: match.them,
                  rating: match.theirRating,
                  attack: match.theirAttack,
                  defence: match.theirDefence,
                  ours: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.name,
    required this.rating,
    required this.attack,
    required this.defence,
    required this.ours,
  });

  final String name;
  final int? rating;
  final int? attack;
  final int? defence;
  final bool ours;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Column(
      crossAxisAlignment: ours
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: ours ? TextAlign.left : TextAlign.right,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: ours ? kit.accentBright : null,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${rating ?? '?'}',
          key: ValueKey('next-match-${ours ? 'ours' : 'theirs'}-rating'),
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        if (attack != null && defence != null)
          Text(
            'ATK $attack · DEF $defence',
            style: TextStyle(fontSize: 10, color: kit.textMuted),
          ),
      ],
    );
  }
}
