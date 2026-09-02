/// An event's challenges. Ported from `_renderChallenges` in
/// `ui/screens/EventScreen.js`.
///
/// One card, one row per challenge, and the reward resolved AT RENDER TIME from
/// the player's current division — so the figure on screen is what they would
/// actually be paid if they claimed right now, rather than what it was worth
/// when the event opened.
///
/// **The reward TRACK is not here**, though `claimRewardTier` is ported and
/// works. No shipped event defines one — `rewardTrack` is left at its empty
/// default by both — so a track would be an empty section, and the copy for its
/// rungs does not exist in any of the ten catalogues. It goes in with the event
/// that needs it, along with its keys.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/events.dart';
import 'package:merge_empire_fc/engine/event_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/format.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// One challenge, resolved against the save and the player's division.
typedef ChallengeRow = ({
  String id,
  String text,
  String icon,
  bool completed,
  bool claimed,
  int reward,
});

/// The challenge copy.
///
/// The key drops a leading `wc_` from the id, so `wc_first_win` reads
/// `event.challenge.text.first_win`. Falls back to the definition's own English
/// where no key exists yet, which is what lets a new challenge ship before its
/// translations land.
String challengeText(EventChallenge challenge) {
  final key =
      'event.challenge.text.${challenge.id.replaceFirst(RegExp(r'^wc_'), '')}';
  final hit = t(key);
  return hit == key ? challenge.text : hit;
}

List<ChallengeRow> challengeRowsOf(Map<String, dynamic> state, EventDef event) {
  final challengeState =
      _map(eventProgress(state, event.id)?['challenges']) ?? const {};
  final base = getDivision(
    '${_map(state['progression'])?['currentDivision']}',
  ).matchRevenueBase;

  return [
    for (final c in event.challengeConfig)
      (
        id: c.id,
        text: challengeText(c),
        icon: c.icon,
        completed: _map(challengeState[c.id])?['completed'] == true,
        claimed: _map(challengeState[c.id])?['claimed'] == true,
        // `Math.round`, not `roundCoins` — the JS quotes the exact figure here
        // and the engine does its own rounding when it pays.
        reward: (base * c.rewardMult + 0.5).floor(),
      ),
  ];
}

class EventChallengesView extends ConsumerWidget {
  const EventChallengesView({required this.event, super.key});

  final EventDef event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    ref.watch(saveRevisionProvider);
    final game = ref.read(gameProvider);
    final state = game.state;
    if (state == null) return const SizedBox.shrink();
    final rows = challengeRowsOf(state, event);

    return Container(
      key: const ValueKey('event-challenges'),
      decoration: BoxDecoration(
        color: kit.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kit.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            _ChallengeRow(
              row: rows[i],
              first: i == 0,
              onClaim:
                  rows[i].completed && !rows[i].claimed && rows[i].reward > 0
                  ? () => game.update(
                      (s) => claimEventChallenge(s, event.id, rows[i].id),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

class _ChallengeRow extends StatelessWidget {
  const _ChallengeRow({required this.row, required this.first, this.onClaim});

  final ChallengeRow row;
  final bool first;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final claimable = onClaim != null;
    final locked = !row.completed;

    return Opacity(
      // Locked rows are knocked back rather than hidden: what is left to do is
      // the reason to keep playing the event.
      opacity: locked ? 0.6 : 1,
      child: Container(
        key: ValueKey('event-challenge-${row.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: claimable
              ? kit.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border(
            top: first ? BorderSide.none : BorderSide(color: kit.border),
            // A claimable row gets a left stripe rather than its own border,
            // so the card still reads as one list.
            left: BorderSide(
              color: claimable ? kit.accent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${row.icon} ${row.text}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      color: locked ? kit.textMuted : kit.accentBright,
                    ),
                  ),
                  if (row.reward > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        t('event.challenge.reward', {
                          'coins': formatCoins(row.reward),
                        }),
                        style: TextStyle(fontSize: 12, color: kit.textMuted),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (claimable)
              ElevatedButton(
                key: ValueKey('event-challenge-claim-${row.id}'),
                onPressed: onClaim,
                child: Text(t('event.challenge.claim')),
              )
            else if (row.claimed)
              Text(
                t('event.challenge.claimed'),
                key: ValueKey('event-challenge-claimed-${row.id}'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kit.textMuted,
                ),
              )
            else
              const Opacity(
                opacity: 0.6,
                child: Text('🔒', style: TextStyle(fontSize: 18)),
              ),
          ],
        ),
      ),
    );
  }
}
