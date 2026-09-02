/// "Banked while you were away." Ported from
/// `ui/components/WelcomeBackPopup.js`.
///
/// **It was the same line twice.** The port opened a generic coach card with
/// `welcome.earned_label` as BOTH its title and its body, so the one popup a
/// player sees on every single launch read "Banked while you were away / Banked
/// while you were away" and never said the number. Two thirds of the copy
/// written for it was unreachable: `welcome.line` — Colin's own five-line pool,
/// which is where the duration is actually mentioned — and
/// `welcome.note_capped`.
///
/// **The cap matters.** `processOfflineEarnings` clamps the window to
/// `Idle.maxOfflineMs`, so a three-day absence arrives as eight hours with
/// nothing saying the books had stopped counting long before. The JS flags it;
/// that is what the note is for.
///
/// The shape is the JS's: Colin, his line, then the label over a hero figure,
/// then the note, then Collect. Nothing is boxed inside anything — the card is
/// already Colin talking, and a panel around his line is one bordered box inside
/// another.
///
/// **And it is his own chrome now, not a second one that looked like it.** This
/// was an `AlertDialog` with its own disc, its own name plate and its own type
/// sizes, which made the one card every single launch opens with the one card
/// where Colin arrives through a different window. It stands on [CoachStage] —
/// the bottom-anchored box he stands over — and his line is typed like every
/// other line of his.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/util/time.dart';

/// The ceiling, in whole hours, for the note that mentions it.
int get offlineCapHours => (Idle.maxOfflineMs / 3600000).round();

/// `formatDuration` for PROSE.
///
/// It always emits both units — "8h 0m" — which is right in a stat row and
/// clumsy inside a sentence, and the offline cap makes "8h 0m" the single most
/// common thing this card ever says. The trailing zero part goes; everything
/// else is left exactly as formatted.
String proseDuration(int ms) =>
    formatDuration(ms).replaceFirst(RegExp(r' 0[ms]$'), '');

/// Whether this window hit the ceiling, so the note is owed.
bool offlineWasCapped(int offlineMs) => offlineMs >= Idle.maxOfflineMs;

/// Pay the offline coins into the wallet.
///
/// **Lifted out of the card, because the card is not the only thing that pays
/// them.** They exist nowhere else — `lastSeen` is stamped the moment the
/// window is measured, so a window that closes without paying has burned it —
/// and a short absence now pays without a card at all. See
/// [welcomeBackFloorMs].
void collectOfflineEarnings(GameState game, int earned) {
  if (earned <= 0) return;
  game.update((s) {
    final resources = s['resources'];
    if (resources is Map<String, dynamic>) {
      final coins = resources['fanCoins'];
      resources['fanCoins'] = (coins is num ? coins : 0) + earned;
    }
  });
  // **AND THE COINS FLY.** The write alone is silent: `CoinFlight` launches off
  // `coins:updated` and nothing announced this one, so the biggest single
  // payment in the game — a night's worth of income — landed with the counter
  // simply reading a bigger number. Reported from the couch. Every other reward
  // in the app announces itself the same way.
  final resources = game.state?['resources'];
  emit(
    'coins:updated',
    resources is Map<String, dynamic> ? resources['fanCoins'] : null,
  );
}

/// How long the app has to have been away before the card is worth showing.
///
/// **Reported from the couch: it comes up after watching an ad.** It does —
/// the only gate was "did this earn anything", and thirty seconds of a rewarded
/// video earns something as soon as the squad has any income at all. So the
/// player gets "welcome back, you were away for 30 seconds" for a video the
/// game itself put in front of them.
///
/// **Five minutes, not thirty**, and the question was asked directly. Thirty is
/// longer than this genre uses: in idle and merge games the offline-earnings
/// modal is the payoff for the idle loop — it is how a player learns the game
/// earns while they are gone — and it usually lands after a couple of minutes.
/// What the threshold is really for is filtering out the absences that are not
/// absences: an ad break, a text message, the notification shade, a phone call.
/// Five minutes covers every one of those and keeps the payoff for a real
/// return. Nothing is lost below the line either — the coins are paid straight
/// in by [collectOfflineEarnings], because they exist nowhere else.
///
/// One number to move if that judgement turns out to be wrong.
const int welcomeBackFloorMs = 5 * 60 * 1000;

/// Show it, and complete once it is gone. The coins are paid on COLLECT, not at
/// boot, so the HUD's counter moves when the player asks it to.
Future<void> showWelcomeBack(
  BuildContext context, {
  required GameState game,
  required OfflineEarnings offline,
}) {
  final earned = offline.earned.floor();
  void collect() => collectOfflineEarnings(game, earned);

  return showDialog<void>(
    context: context,
    barrierColor: coachCardScrim,
    // Tapping the blank backdrop collects, as the JS's does: the money is
    // already earned, so there is nothing here to throw away by accident.
    barrierDismissible: true,
    builder: (_) => WelcomeBackCard(offline: offline),
  ).then((_) {
    // Whichever way it closed — the button, the backdrop, a back press — the
    // coins are paid. They exist nowhere else: boot has already stamped
    // `lastSeen`, so a card that closes without paying has burned them.
    collect();
  });
}

class WelcomeBackCard extends StatefulWidget {
  const WelcomeBackCard({super.key, required this.offline});

  final OfflineEarnings offline;

  @override
  State<WelcomeBackCard> createState() => WelcomeBackCardState();
}

class WelcomeBackCardState extends State<WelcomeBackCard> {
  /// Picked ONCE and kept. Re-rolling Colin's words underneath the player while
  /// they are reading them is worse than repeating one.
  late final String line = tPool('welcome.line', {
    'duration': proseDuration(widget.offline.offlineMs),
  });

  /// Test seam.
  bool get capped => offlineWasCapped(widget.offline.offlineMs);

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final earned = widget.offline.earned.floor();

    return CoachStage(
      dialogKey: const ValueKey('welcome-back'),
      // The same division of labour the coach card makes: what there is to read
      // scrolls, and the one control does not go under the fold with it.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // His name is on the SCENE, above the box and off to the
                  // right, and [CoachStage] draws it for every card that opens
                  // on this chrome — a second copy here was the same words
                  // twice, one of them inside the box he is standing behind.
                  Text(
                    t('app.offline_title'),
                    key: const ValueKey('welcome-back-title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CoachTypewriter(
                    text: line,
                    textKey: const ValueKey('welcome-back-line'),
                    style: TextStyle(
                      color: kit.textMuted,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    t('welcome.earned_label'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: kit.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // The number is the point of the card, and the old one never
                  // said it.
                  // **THE COIN ICON, not the money-bag emoji.** Every priced
                  // control in the app draws the game's own coin; a 💰 renders
                  // as whatever the platform's font decides and is the one
                  // thing on this card that does not belong to the game.
                  // Reported from the couch, here and on the club assets.
                  Row(
                    key: const ValueKey('welcome-back-amount'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+${formatCoins(earned)}',
                        style: TextStyle(
                          color: kit.accentBright,
                          fontSize: 26,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GameIcon('coin', size: 22, color: kit.accentBright),
                    ],
                  ),
                  if (capped) ...[
                    const SizedBox(height: 12),
                    Row(
                      key: const ValueKey('welcome-back-capped'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: kit.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            t('welcome.note_capped', {'hours': offlineCapHours}),
                            style: TextStyle(
                              color: kit.textMuted,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            key: const ValueKey('welcome-back-collect'),
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(t('app.offline_collect')),
          ),
        ],
      ),
    );
  }
}
