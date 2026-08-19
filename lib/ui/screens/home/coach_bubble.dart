/// Coach Colin's read on the next fixture. Ported from `_computeManagerTips`
/// and `_openCoachPanel` in `ui/screens/LeagueScreen.js`.
///
/// A bubble anchored to his orb rather than a centred modal, because the tip
/// should read as coming out of Colin rather than as the app interrupting. He
/// is the one thing on the home screen that talks to you, which is exactly why
/// he kept an orb when the other nine moved into the menu.
///
/// **The dot is the point.** It lights when the pool CHANGES — a new fixture, a
/// different tactic call — and clears when the bubble is opened. A coach whose
/// badge never moves is a button nobody presses twice.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/fixture_preview.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/tactic_coach.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num _num(Object? v) => v is num ? v : 0;

/// One thing Colin has to say.
typedef CoachTip = ({String id, String text});

/// The tips for the fixture in front of us, best first.
///
/// Deliberately a SHORT pool. He is standing on the touchline before a match,
/// not writing a report, and a list of nine observations is one nobody reads to
/// the end of.
final coachTipsProvider = savePick<List<CoachTip>>((s) {
  final preview = previewFixture(s);
  final tips = <CoachTip>[];

  if (preview != null) {
    final opponent = preview.opponentName;
    final ourRating = preview.effectiveSquadRating;
    final theirRating = preview.effectiveOppRating;

    // A grudge is the one thing that makes a weaker side dangerous, so it
    // outranks the rating comparison rather than sitting under it.
    if (preview.grudgeBoost > 0) {
      tips.add((id: 'grudge', text: t('manager.grudge', {'opp': opponent})));
    }

    if (theirRating != null) {
      final gap = ourRating - theirRating;
      if (gap <= -5) {
        tips.add((
          id: 'gap_higher',
          text: t('manager.rating_gap_higher', {'opp': opponent}),
        ));
      } else if (gap >= 12) {
        // Far enough ahead that the useful advice is about FITNESS rather than
        // about winning — the result is not in doubt, so the cost is.
        tips.add((
          id: 'rotate',
          text: t('manager.rotate_hard', {'opp': opponent}),
        ));
      } else if (gap >= 5) {
        tips.add((
          id: 'gap_lower',
          text: t('manager.rating_gap_lower', {'opp': opponent}),
        ));
      }
    }

    // What he would actually play. The engine scores every strategy on expected
    // points MINUS what its injury exposure is worth to this squad, which is
    // the whole reason he is worth listening to over a rating comparison.
    final suggestion = suggestTactic(
      preview.effAttack,
      preview.effDefence,
      preview.effOppAttackRating ?? preview.effAttack,
      preview.effOppDefenceRating ?? preview.effDefence,
      oppAttackRatio: preview.oppAttackRatio,
    );
    final current = '${_map(s['squad'])?['strategy'] ?? ''}';
    if (suggestion.id != current) {
      tips.add((
        id: 'tactic_${suggestion.id}',
        text: t('coach.tactic_suggest', {
          'tactic': strategies[suggestion.id]?.name ?? suggestion.id,
        }),
      ));
    }
  }

  if (tips.isEmpty) {
    tips.add((id: 'default', text: t('manager.default_tip')));
  }
  return tips;
});

/// What the pool currently is, as one string.
///
/// The dot compares this against what was last read. Keyed on the TEXT rather
/// than on the fixture, because the same opponent with a rebuilt squad is a
/// different piece of advice.
final coachTipKeyProvider = savePick<String>((s) {
  final preview = previewFixture(s);
  final opponent = preview?.opponentName ?? '';
  final rating = preview?.effectiveSquadRating.round() ?? 0;
  final matches = _num(_map(s['progression'])?['matchesPlayed']).toInt();
  return '$opponent|$rating|$matches';
});

/// The last pool the player actually opened. Not on the save: an unread badge
/// is a property of this sitting, and a fresh boot showing his newest read is
/// the right behaviour rather than a bug.
final coachSeenKeyProvider = StateProvider<String?>((_) => null);

final coachHasUnreadProvider = Provider<bool>((ref) {
  final current = ref.watch(coachTipKeyProvider);
  return ref.watch(coachSeenKeyProvider) != current;
});

Future<void> showCoachBubble(BuildContext context, WidgetRef ref) {
  ref.read(coachSeenKeyProvider.notifier).state = ref.read(coachTipKeyProvider);
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black26,
    builder: (_) => const _CoachBubble(),
  );
}

class _CoachBubble extends ConsumerStatefulWidget {
  const _CoachBubble();

  @override
  ConsumerState<_CoachBubble> createState() => _CoachBubbleState();
}

class _CoachBubbleState extends ConsumerState<_CoachBubble> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final tips = ref.watch(coachTipsProvider);
    if (tips.isEmpty) return const SizedBox.shrink();
    final tip = tips[_index % tips.length];

    // Bottom-left, tail pointing down at the orb he came out of.
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 0, 15, 96),
        child: Material(
          color: Colors.transparent,
          child: Container(
            key: const ValueKey('coach-bubble'),
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              color: kit.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kit.accent),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 34,
                      height: 34,
                      child: ArtImage(
                        path: 'assets/ui/manager_hint.png',
                        fallback: Center(
                          child: Text('🧢', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tip.text,
                        key: ValueKey('coach-tip-${tip.id}'),
                        style: const TextStyle(fontSize: 12.5, height: 1.45),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('coach-bubble-close'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: t('common.close'),
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                // More than one thing to say gets a way through them rather
                // than a timer: a line that changes while you are reading it is
                // a line you have to wait for again.
                if (tips.length > 1)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const ValueKey('coach-bubble-next'),
                      onPressed: () => setState(() => _index++),
                      child: Text(
                        '${(_index % tips.length) + 1} / ${tips.length}',
                        style: TextStyle(fontSize: 11, color: kit.textMuted),
                      ),
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
