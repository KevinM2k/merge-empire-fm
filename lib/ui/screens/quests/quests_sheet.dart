/// The quests sheet.
///
/// The toast layer says "Season quest complete — claim it in Quests!" and there
/// was no Quests anywhere in the app: shipped copy pointing at nothing, and a
/// completed quest that could never be claimed.
///
/// A bottom sheet, one of the three shapes. **Only the SEASON track is here.**
/// Match quests live on the next-match card, where the fixture they belong to
/// is: they pay themselves as the match runs, so there was never anything to
/// claim on them, and reading them after choosing to open a menu is reading them
/// too late.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/ui/popups/sheet_header.dart';
import 'package:merge_empire_fc/data/quests.dart' show getQuest;
import 'package:merge_empire_fc/engine/quest_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';

/// One quest, as a row.
typedef QuestRow = ({
  String id,
  String text,
  num progress,
  num target,
  bool completed,
  bool claimed,

  /// What claiming it pays, in coins, at THIS division.
  ///
  /// **A quest that does not say what it pays is a chore.** The reward is a
  /// percentage of one league win rather than a literal, so it is worth
  /// different money in every division — which is exactly why the row has to
  /// carry the resolved figure rather than the bank's number.
  int coins,
});

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num _num(Object? v) => v is num ? v : 0;

List<QuestRow> _rowsFrom(Map<String, dynamic>? state, List<dynamic> raw) {
  final out = <QuestRow>[];
  for (final entry in raw) {
    final inst = _map(entry);
    final id = inst?['id'];
    if (id is! String) continue;
    final target = _num(inst!['target']);
    out.add((
      id: id,
      // Quest text is a catalogue key built from the id, which is exactly why
      // the i18n guard checks every quest in the bank has one.
      text: t('quest.$id', {'n': target}),
      progress: _num(inst['progress']),
      target: target,
      completed: inst['completed'] == true,
      claimed: inst['claimedAt'] != null,
      coins: questRewardCoins(state, getQuest(id)?.reward.coins),
    ));
  }
  return out;
}

final seasonQuestsProvider = savePick<List<QuestRow>>((s) {
  final season = ensureQuests(s)['season'];
  return _rowsFrom(s, season is List ? season : const []);
});

final matchQuestsProvider = savePick<List<QuestRow>>((s) {
  final active = _map(ensureQuests(s)['match'])?['active'];
  return _rowsFrom(s, active is List ? active : const []);
});

/// How many season quests are sitting there completed and unclaimed.
final claimableQuestsProvider = savePick<int>((s) {
  final season = ensureQuests(s)['season'];
  return _rowsFrom(
    s,
    season is List ? season : const [],
  ).where((q) => q.completed && !q.claimed).length;
});

/// What the WHOLE track is worth, and how much of it is banked.
///
/// The gem is the division capstone: every season quest completed AND claimed
/// pays one, once ever, for that division. `quests.capstone_title` and
/// `quests.capstone_reward` were translated into all ten catalogues with
/// nothing able to reach either — a track whose prize nothing mentions.
final seasonQuestPrizeProvider =
    savePick<({int coins, int gems, int claimed, int total})>((s) {
      final season = ensureQuests(s)['season'];
      final rows = _rowsFrom(s, season is List ? season : const []);
      return (
        coins: rows.fold<int>(0, (sum, q) => sum + q.coins),
        gems: divisionCapstonePending(s) ? capstoneGems : 0,
        claimed: rows.where((q) => q.claimed).length,
        total: rows.length,
      );
    });

/// What a reroll would cost, and whether one is possible at all.
final questRerollProvider = savePick<({bool can, int cost, int free})>(
  (s) => (can: canReroll(s), cost: rerollCost(s), free: freeRerollsLeft(s)),
);

Future<void> showQuestsSheet(BuildContext context, WidgetRef ref) {
  // The track for the next match, rolled on the way in. Guarded on the fixture
  // key, so opening the sheet twice shows the same three quests rather than
  // redrawing the set the player has just read.
  ref.read(gameProvider).update(ensureMatchQuests);
  return showBottomSheetPopup<void>(
    context,
    heightFraction: 0.8,
    child: Consumer(
      builder: (sheetContext, sheetRef, _) {
        final kit = Theme.of(sheetContext).extension<KitTheme>()!;
        final season = sheetRef.watch(seasonQuestsProvider);
        final game = sheetRef.read(gameProvider);

        return ListView(
          key: const ValueKey('quests-sheet'),
          padding: const EdgeInsets.all(16),
          children: [
            SheetHeader(title: t('quests.title'), padding: EdgeInsets.zero),
            const SizedBox(height: 12),
            Text(
              t('quests.season'),
              style: TextStyle(color: kit.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 4),
            if (season.isEmpty)
              Text(
                t('quests.none_season'),
                key: const ValueKey('quests-none-season'),
                style: TextStyle(color: kit.textMuted, fontSize: 12),
              ),
            for (final quest in season)
              _QuestTile(
                quest: quest,
                track: 'season',
                onClaim: quest.completed && !quest.claimed
                    ? () => game.update((s) => claimQuest(s, quest.id))
                    : null,
              ),
            // **WHAT THE WHOLE TRACK IS WORTH.** The sheet listed the work and
            // never the pay — not for one quest and not for the set — so a
            // season's quests read as a chore list rather than as a prize with
            // a number on it.
            if (season.isNotEmpty) const _TrackPrize(),
            if (season.isNotEmpty) _RerollRow(),
            // The MATCH track is not here. It belongs on the next-match card —
            // a match quest is an instruction for the game you are about to
            // press Play on, and behind the burger with the season track it was
            // filed in the one place it is no use. See `MatchQuestsBlock`.
            // The line that used to head it stays worth saying, so the card
            // carries the fact that these pay themselves instead.
          ],
        );
      },
    ),
  );
}

/// The prize for the whole track: the coins it pays, and the division's gem.
///
/// The gem is `checkDivisionCapstone` — every season quest completed AND
/// claimed pays one, once ever, for that division. It is the only gem route in
/// the game that is not a purchase, and nothing on screen mentioned it:
/// `quests.capstone_title` and `quests.capstone_reward` sat translated in all
/// ten catalogues with no caller.
class _TrackPrize extends ConsumerWidget {
  const _TrackPrize();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final prize = ref.watch(seasonQuestPrizeProvider);
    if (prize.total == 0) return const SizedBox.shrink();
    final done = prize.claimed >= prize.total;

    return Container(
      key: const ValueKey('quests-track-prize'),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: kit.accent.withValues(alpha: done ? 0.18 : 0.08),
        border: Border.all(
          color: kit.accent.withValues(alpha: done ? 0.7 : 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('quests.capstone_title').toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: kit.textMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${prize.claimed} / ${prize.total}',
                  key: const ValueKey('quests-track-progress'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: done ? kit.accentBright : null,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          if (prize.coins > 0)
            _RewardChip(
              key: const ValueKey('quests-track-coins'),
              icon: 'coin',
              ink: coinFigureInk(context),
              label: t('quests.reward_coins', {'n': prize.coins}),
            ),
          // The gem only while it is still there to be earned: a division that
          // has already paid it would be advertising a prize that cannot come
          // twice.
          if (prize.gems > 0) ...[
            const SizedBox(width: 6),
            _RewardChip(
              key: const ValueKey('quests-track-gem'),
              icon: 'gem',
              ink: const Color(0xFF7FD4FF),
              label: t('quests.capstone_reward', {'n': prize.gems}),
            ),
          ],
        ],
      ),
    );
  }
}

/// A figure with the currency's own glyph on it.
class _RewardChip extends StatelessWidget {
  const _RewardChip({
    required this.icon,
    required this.ink,
    required this.label,
    super.key,
  });

  final String icon;
  final Color ink;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      color: ink.withValues(alpha: 0.14),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameIcon(icon, size: 13, color: ink),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: ink,
          ),
        ),
      ],
    ),
  );
}

/// Swap the unfinished season quests for different ones.
///
/// Two free a season, then gems. It refuses when every quest is already done —
/// there would be nothing to swap, and charging for that would be theft.
class _RerollRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final reroll = ref.watch(questRerollProvider);
    final game = ref.read(gameProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            key: const ValueKey('quests-reroll'),
            onPressed: reroll.can
                ? () => game.update((s) => rerollQuests(s))
                : null,
            child: Text(
              '${t('quests.reroll_all')} · '
              '${reroll.cost == 0 ? t('quests.reroll_free') : t('quests.reroll_cost', {'n': reroll.cost})}',
            ),
          ),
          if (reroll.free > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                t('quests.reroll_note_free', {'n': reroll.free}),
                key: const ValueKey('quests-reroll-free'),
                textAlign: TextAlign.center,
                style: TextStyle(color: kit.textMuted, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuestTile extends StatelessWidget {
  const _QuestTile({required this.quest, required this.track, this.onClaim});

  final QuestRow quest;

  /// `season` or `match`. In the key, because the two tracks are drawn in the
  /// same tree and a duplicate `ValueKey` is a widget-test trap waiting to be
  /// stepped in.
  final String track;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final pct = quest.target <= 0
        ? 0.0
        : (quest.progress / quest.target).clamp(0.0, 1.0);

    return Card(
      key: ValueKey('quest-$track-${quest.id}'),
      color: kit.surface,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(quest.text, style: const TextStyle(fontSize: 13)),
                ),
                if (quest.coins > 0) ...[
                  const SizedBox(width: 8),
                  // **WHAT IT PAYS, on the row that asks for the work.** The
                  // figure is a percentage of one league win rather than a
                  // literal, so it is worth different money in every division
                  // — which is the other half of why it has to be shown.
                  Opacity(
                    opacity: quest.claimed ? 0.5 : 1,
                    child: _RewardChip(
                      key: ValueKey('quest-reward-$track-${quest.id}'),
                      icon: 'coin',
                      ink: coinFigureInk(context),
                      label: t('quests.reward_coins', {'n': quest.coins}),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 5,
                backgroundColor: kit.surface2,
                valueColor: AlwaysStoppedAnimation(
                  quest.completed ? kit.accentBright : kit.accent,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${quest.progress.toInt()} / ${quest.target.toInt()}',
                    style: TextStyle(color: kit.textMuted, fontSize: 11),
                  ),
                ),
                if (quest.claimed)
                  Text(
                    t('quests.done'),
                    key: ValueKey('quest-done-$track-${quest.id}'),
                    style: TextStyle(color: kit.textMuted, fontSize: 11),
                  )
                else if (onClaim != null)
                  ElevatedButton(
                    key: ValueKey('quest-claim-$track-${quest.id}'),
                    onPressed: onClaim,
                    child: Text(t('quests.claim')),
                  )
                else
                  Text(
                    quest.completed ? t('quests.done') : t('quests.live'),
                    style: TextStyle(color: kit.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
