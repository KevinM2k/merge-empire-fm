/// The quests sheet.
///
/// The toast layer says "Season quest complete — claim it in Quests!" and there
/// was no Quests anywhere in the app: shipped copy pointing at nothing, and a
/// completed quest that could never be claimed.
///
/// A bottom sheet, one of the three shapes. Match quests are read-only — they
/// pay themselves as the match runs — and only the season track has anything to
/// claim.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/quest_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// One quest, as a row.
typedef QuestRow = ({
  String id,
  String text,
  num progress,
  num target,
  bool completed,
  bool claimed,
});

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num _num(Object? v) => v is num ? v : 0;

List<QuestRow> _rowsFrom(List<dynamic> raw) {
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
    ));
  }
  return out;
}

final seasonQuestsProvider = savePick<List<QuestRow>>((s) {
  final season = ensureQuests(s)['season'];
  return _rowsFrom(season is List ? season : const []);
});

final matchQuestsProvider = savePick<List<QuestRow>>((s) {
  final active = _map(ensureQuests(s)['match'])?['active'];
  return _rowsFrom(active is List ? active : const []);
});

/// How many season quests are sitting there completed and unclaimed.
final claimableQuestsProvider = savePick<int>((s) {
  final season = ensureQuests(s)['season'];
  return _rowsFrom(season is List ? season : const [])
      .where((q) => q.completed && !q.claimed)
      .length;
});

Future<void> showQuestsSheet(BuildContext context, WidgetRef ref) {
  return showBottomSheetPopup<void>(
    context,
    heightFraction: 0.8,
    child: Consumer(
      builder: (sheetContext, sheetRef, _) {
        final kit = Theme.of(sheetContext).extension<KitTheme>()!;
        final season = sheetRef.watch(seasonQuestsProvider);
        final match = sheetRef.watch(matchQuestsProvider);
        final game = sheetRef.read(gameProvider);

        return ListView(
          key: const ValueKey('quests-sheet'),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              t('quests.title'),
              style: TextStyle(
                color: kit.accentBright,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
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
                onClaim: quest.completed && !quest.claimed
                    ? () => game.update((s) => claimQuest(s, quest.id))
                    : null,
              ),
            if (match.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                t('quests.match'),
                style: TextStyle(color: kit.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 4),
              for (final quest in match) _QuestTile(quest: quest),
            ],
          ],
        );
      },
    ),
  );
}

class _QuestTile extends StatelessWidget {
  const _QuestTile({required this.quest, this.onClaim});

  final QuestRow quest;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final pct = quest.target <= 0
        ? 0.0
        : (quest.progress / quest.target).clamp(0.0, 1.0);

    return Card(
      key: ValueKey('quest-${quest.id}'),
      color: kit.surface,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(quest.text, style: const TextStyle(fontSize: 13)),
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
                    key: ValueKey('quest-done-${quest.id}'),
                    style: TextStyle(color: kit.textMuted, fontSize: 11),
                  )
                else if (onClaim != null)
                  ElevatedButton(
                    key: ValueKey('quest-claim-${quest.id}'),
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
