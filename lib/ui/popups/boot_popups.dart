/// What the game shows the moment it opens.
///
/// The queue existed and nothing ever queued into it, so the welcome-back card
/// and the daily reward were both unreachable — and the welcome-back card holds
/// coins that exist nowhere else. Boot stamps `lastSeen`, so by the time the
/// card would be queued the offline window has already been consumed: if it
/// never shows, those earnings are simply gone.
///
/// The two priorities are the queue's own: the coins first, the streak second.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/engine/daily_reward_engine.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/ui/popups/daily_reward_sheet.dart';
import 'package:merge_empire_fc/ui/popups/welcome_back_card.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';

/// Queue whatever this boot owes the player.
///
/// [offline] is read once, at boot, because `processOfflineEarnings` measures
/// against `lastSeen` and the save stamps that as it loads — asking twice gives
/// nothing the second time.
void queueBootPopups({
  required BuildContext Function() context,
  required GameState game,
  required OfflineEarnings offline,
}) {
  // No save loaded means this is not a boot that owes anything — and treating
  // an absent save as "today's reward is unclaimed" would offer it twice.
  if (game.state == null) return;

  if (offline.earned > 0) {
    enqueuePopup(
      PopupEntry(
        id: 'welcome-back',
        priority: PopupPriority.welcomeBack,
        show: (done) => showWelcomeBack(
          context(),
          game: game,
          offline: offline,
        ).then((_) => done()),
      ),
    );
  }

  enqueuePopup(
    PopupEntry(
      id: 'daily-reward',
      priority: PopupPriority.dailyReward,
      // Re-checked at show time: the welcome-back card can sit on screen across
      // midnight, and a reward claimed in between must not be offered again.
      canShow: () => !getDailyRewardStatus(game.state ?? {}).claimedToday,
      show: (done) =>
          _showDailyReward(context(), game: game).then((_) => done()),
    ),
  );
}

/// The daily reward. A SHEET rather than a coach card, because the cycle is the
/// thing worth showing — see `daily_reward_sheet.dart`.
Future<void> _showDailyReward(
  BuildContext context, {
  required GameState game,
}) => showDailyRewardSheet(context, game: game);

/// Whether this boot owes the player anything at all.
bool bootHasWork(Map<String, dynamic>? state, OfflineEarnings offline) =>
    offline.earned > 0 || !getDailyRewardStatus(state ?? {}).claimedToday;

/// Kept so the caller does not have to know the label key.
String welcomeLine(OfflineEarnings offline) =>
    t('welcome.earned_label', {'duration': proseDuration(offline.offlineMs)});
