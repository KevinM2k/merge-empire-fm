/// This fixture's three objectives, ON the next-match card. Ported from
/// `_matchQuestsHtml` in `ui/screens/LeagueScreen.js`.
///
/// **They belong here, not in the Quests sheet.** The port had them filed under
/// the season track behind the burger, which is the one place they are no use:
/// a match quest is an instruction for the game you are about to press Play on,
/// and it has to be readable at the moment of pressing it. They were a sibling
/// UNDER the card for a while in the JS too — that read as two unrelated things
/// stacked, when they are three objectives for the very game the card announces.
///
/// **Nothing here is claimable.** A match quest pays itself at full time, so a
/// row with a button on it would be a lie. What the rows carry instead is the
/// price: one figure each, and the track's total beside the heading — which is
/// the answer to the question the three rows do not between them answer, whether
/// the block is worth reading before kick-off at all.
///
/// **It collapses**, and the heading keeps the total when it does. "Worth 3,600"
/// is a reason to open it; a bare "MATCH QUESTS" with a chevron is not.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/quests.dart';
import 'package:merge_empire_fc/engine/quest_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/util/format.dart';

/// One row: what is asked, and what it pays.
typedef MatchQuestRow = ({
  String id,
  String icon,
  String text,
  int reward,
  num progress,
  num target,
  bool completed,
});

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num _num(Object? v) => v is num ? v : 0;

final matchQuestRowsProvider = savePick<List<MatchQuestRow>>((s) {
  final active = _map(ensureQuests(s)['match'])?['active'];
  if (active is! List) return const [];
  final out = <MatchQuestRow>[];
  for (final entry in active) {
    final inst = _map(entry);
    final id = inst?['id'];
    if (id is! String) continue;
    final def = getQuest(id);
    final target = _num(inst!['target']);
    out.add((
      id: id,
      // The data file stays UI-free and names an icon key; this resolves it.
      icon: def?.icon ?? 'target',
      text: t('quest.$id', {'n': target}),
      reward: def == null ? 0 : questRewardCoins(s, def.reward.coins),
      progress: _num(inst['progress']),
      target: target,
      completed: inst['completed'] == true,
    ));
  }
  return out;
});

/// What the whole track is worth. Summed from the same figures the rows print,
/// so the heading can never disagree with the lines under it.
final matchQuestTotalProvider = savePick<int>((s) {
  var total = 0;
  final active = _map(ensureQuests(s)['match'])?['active'];
  if (active is! List) return 0;
  for (final entry in active) {
    final id = _map(entry)?['id'];
    if (id is! String) continue;
    final def = getQuest(id);
    if (def != null) total += questRewardCoins(s, def.reward.coins);
  }
  return total;
});

/// **This block only READS.** The track is rolled where the fixture actually
/// advances — at boot, at `settleMatch`, and on the way into a match — and never
/// from here. Rolling on mount went through `update`, `update` queues a debounced
/// save, and the card rebuilds on every save revision: so merely looking at the
/// home screen wrote the whole game state to disk. The JS carries the same
/// warning about the same call.
class MatchQuestsBlock extends ConsumerStatefulWidget {
  const MatchQuestsBlock({super.key});

  @override
  ConsumerState<MatchQuestsBlock> createState() => _MatchQuestsBlockState();
}

class _MatchQuestsBlockState extends ConsumerState<MatchQuestsBlock> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final rows = ref.watch(matchQuestRowsProvider);
    final total = ref.watch(matchQuestTotalProvider);
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      key: const ValueKey('match-quests'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            key: const ValueKey('match-quests-toggle'),
            onTap: () => setState(() => _collapsed = !_collapsed),
            child: Row(
              children: [
                GameIcon('target', size: 11, color: kit.accentBright),
                const SizedBox(width: 5),
                // The heading FLEXES and the figure does not. On a 320px phone
                // "MATCH QUESTS" plus "TOTAL REWARD" plus the coins overflowed
                // the row by 34px — and the half worth keeping when there is no
                // room is the money, which is the reason to open the block at all.
                Flexible(
                  child: Text(
                    t('quests.match').toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: kit.textMuted,
                    ),
                  ),
                ),
                const Spacer(),
                if (total > 0) ...[
                  Flexible(
                    child: Text(
                      t('quests.total_reward'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: kit.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const CoinIcon(size: 11),
                  const SizedBox(width: 2),
                  Text(
                    '+${formatCoins(total)}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: kit.accentBright,
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                // Down when there is more to see, right when it is shut — the
                // chevron is the same glyph rotated, so the two states cannot
                // drift apart as shapes.
                AnimatedRotation(
                  turns: _collapsed ? 0 : 0.25,
                  duration: const Duration(milliseconds: 160),
                  child: GameIcon('chevron', size: 12, color: kit.textMuted),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _collapsed
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                for (final row in rows) _QuestTile(row: row),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One quest per row: glyph → ask → reward, matching the season panel.
class _QuestTile extends StatelessWidget {
  const _QuestTile({required this.row});

  final MatchQuestRow row;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final ink = Theme.of(context).colorScheme.onSurface;
    final done = row.completed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        key: ValueKey('match-quest-${row.id}'),
        children: [
          // A completed quest wears the tick rather than its own glyph — it has
          // already paid, and the ask no longer matters.
          GameIcon(
            done ? 'check' : row.icon,
            size: 15,
            color: done ? kit.accentBright : kit.textMuted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              row.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: done ? kit.accentBright : ink,
              ),
            ),
          ),
          // Progress, when there is any to show. A quest at 1 of 3 is a
          // different thing to read than one at 0.
          if (row.target > 1 && !done) ...[
            const SizedBox(width: 5),
            Text(
              '${row.progress.toInt()}/${row.target.toInt()}',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: kit.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
          if (row.reward > 0) ...[
            const SizedBox(width: 6),
            const CoinIcon(size: 10),
            const SizedBox(width: 2),
            Text(
              formatCoins(row.reward),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: kit.accentBright,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
