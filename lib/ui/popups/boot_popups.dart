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
      // **ONCE A DAY, which is the engine's own rule and was being bypassed.**
      // `!claimedToday` offers the sheet on EVERY boot until the reward is
      // taken, so a player who opens the app, looks at the cycle and closes it
      // without claiming is shown it again the next time they open the app,
      // and the time after that. `shouldAutoShowPopup` is the gate the JS
      // wrote for exactly this — it subsumes the claimed check and stamps
      // `lastAutoPopupDayKey` on its way through, so the auto-open happens once
      // per day and the day rolls over on its own.
      //
      // It MUTATES, which is why it belongs here rather than in `bootHasWork`:
      // `canShow` runs at show time and runs once, because the entry leaves the
      // queue whichever answer it gives. Asking it twice would consume the day
      // and then show nothing.
      //
      // The manual route — the burger's Daily tile — calls the sheet directly
      // and is untouched by this, which is the JS's rule stated in as many
      // words: "a manual open bypasses this entirely".
      canShow: () => shouldAutoShowPopup(game.state ?? {}),
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
