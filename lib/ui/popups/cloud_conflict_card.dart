/// "Your saves are out of sync — pick one" — ported from
/// `../merge-empire-fc/src/ui/components/CloudSaveConflictModal.js`.
///
/// **Sixteen `cloud.*` and `cloudsave.*` strings shipped in ten languages with
/// no caller**, because `evaluateCloudSave` answers [CloudSaveAction.choose]
/// and stops: the engine may not draw, so the decision had nowhere to go and
/// the whole cloud subsystem was unreachable.
///
/// **TWO CARDS, NOT A DIALOG WITH TWO BUTTONS.** Which save to keep is a
/// question about two THINGS — a club, a division, a season, a match count and
/// when each was last played — and a player cannot answer it from the words
/// "Cloud" and "Device". The JS lays them side by side for exactly that reason
/// and so does this.
///
/// **It cannot be dismissed by accident.** The JS treats a backdrop tap as
/// "keep device", which is the safe half of the choice; here the route is
/// barrier-proof and the same answer is what a system back gives, so there is
/// no path out of it that silently replaces the save in front of the player.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/engine/cloud_save_policy.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/services/cloud_sync.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
import 'package:merge_empire_fc/util/time.dart';

/// How long ago a save was last played, in the JS's own four bands.
///
/// **Minutes, hours, days — and "just now" under one minute.** A timestamp
/// would be precise and useless: what the player is deciding is which of these
/// two is the one they remember playing.
String cloudRelativeTime(int lastSeenMs, {int? nowMs}) {
  if (lastSeenMs <= 0) return '';
  final minutes = ((nowMs ?? now()) - lastSeenMs) ~/ 60000;
  if (minutes < 1) return t('cloudsave.just_now');
  if (minutes < 60) return t('cloudsave.minutes_ago', {'n': minutes});
  final hours = minutes ~/ 60;
  if (hours < 24) return t('cloudsave.hours_ago', {'n': hours});
  return t('cloudsave.days_ago', {'n': hours ~/ 24});
}

/// Ask, and hand back what they chose.
///
/// Wire it into [conflictPrompt] once, at boot — the sync service holds the
/// seam so that nothing below the UI has to know a card exists.
Future<CloudSaveAction> showCloudConflictCard(
  BuildContext context,
  SaveSummary cloud,
  SaveSummary local,
) async {
  final choice = await showDialog<CloudSaveAction>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ConflictCard(cloud: cloud, local: local),
  );
  // A back gesture is the same answer as the JS's backdrop tap: keep what the
  // player is looking at.
  return choice ?? CloudSaveAction.upload;
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({required this.cloud, required this.local});

  final SaveSummary cloud;
  final SaveSummary local;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return AlertDialog(
      key: const ValueKey('cloud-conflict-card'),
      backgroundColor: kit.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: kit.border),
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t('cloud.conflict.title'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              t('cloud.conflict.subtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(color: kit.textMuted, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 16),
            // Stacked rather than side by side: two cards carrying five lines
            // each do not fit across a phone, and the JS's own row wraps.
            _SaveCard(
              cardKey: const ValueKey('cloud-conflict-cloud'),
              summary: cloud,
              badge: t('cloud.conflict.cloud_badge'),
              cta: t('cloud.conflict.restore'),
              tone: StoreTone.neutral,
              highlighted: true,
              choice: CloudSaveAction.restore,
            ),
            const SizedBox(height: 10),
            _SaveCard(
              cardKey: const ValueKey('cloud-conflict-device'),
              summary: local,
              badge: t('cloud.conflict.device_badge'),
              cta: t('cloud.conflict.overwrite'),
              tone: StoreTone.coin,
              highlighted: false,
              choice: CloudSaveAction.upload,
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveCard extends StatelessWidget {
  const _SaveCard({
    required this.cardKey,
    required this.summary,
    required this.badge,
    required this.cta,
    required this.tone,
    required this.highlighted,
    required this.choice,
  });

  final Key cardKey;
  final SaveSummary summary;
  final String badge;
  final String cta;
  final StoreTone tone;
  final bool highlighted;
  final CloudSaveAction choice;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final division = getDivision(summary.divisionId);
    final time = cloudRelativeTime(summary.lastSeen);
    return Container(
      key: cardKey,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: kit.surface,
        borderRadius: BorderRadius.circular(12),
        // The cloud card is the one the JS marks; it is the copy the player
        // has NOT been looking at, so it is the one that needs pointing out.
        border: Border.all(
          color: highlighted ? kit.accentBright : kit.border,
          width: highlighted ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            badge,
            style: TextStyle(
              color: kit.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            summary.clubName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          Text(
            tName('division', {'id': division.id, 'name': division.name}),
            style: TextStyle(color: kit.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            '${t('cloud.conflict.season', {'n': summary.seasonCount})} · '
            '${t('cloud.conflict.matches', {'n': summary.matchesPlayed})}',
            style: TextStyle(color: kit.textMuted, fontSize: 12),
          ),
          if (time.isNotEmpty)
            Text(
              time,
              style: TextStyle(color: kit.textMuted, fontSize: 12),
            ),
          const SizedBox(height: 10),
          StoreButton(
            tone: tone,
            label: cta,
            onTap: () => Navigator.of(context).pop(choice),
          ),
        ],
      ),
    );
  }
}
