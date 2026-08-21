/// The mini-games, derived from the save.
///
/// The Club's Training Ground unlocks them one tier at a time and the League's
/// Training tab pointed at them; neither had anywhere to point. This is the
/// list both were talking about.
library;

import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/data/quests.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';

/// One game, and whether it can be played right now.
typedef MiniGameRow = ({
  String kind,
  String titleKey,
  bool unlocked,
  bool ready,
  int waitMs,
  bool playable,

  /// The Training Ground tier that unlocks it, so a locked row can name the
  /// rung rather than saying "coming soon" for two different reasons.
  int unlocksAtTier,
});

/// The catalogue's own order, which is also the order the Training Ground
/// unlocks them in.
const Map<String, String> miniGameTitleKeys = {
  MiniGameKind.penalty: 'game.penalty',
  MiniGameKind.training: 'game.training',
  MiniGameKind.keepyUppys: 'game.keepy_uppys',
  MiniGameKind.throughBall: 'game.through_ball',
  MiniGameKind.whack: 'game.whack',
  MiniGameKind.pairs: 'game.teamwork',
  MiniGameKind.bootRoom: 'game.boot_room',
};

/// The games with a screen behind them today.
///
/// Listing one without a screen would be the menu-row-to-nowhere bug again, so
/// the rest are shown LOCKED with a reason rather than offered.
const Set<String> playableMiniGames = {
  MiniGameKind.penalty,
  MiniGameKind.bootRoom,
  MiniGameKind.throughBall,
  MiniGameKind.whack,
};

final miniGamesProvider = savePick<List<MiniGameRow>>((s) {
  final clubAssets = s['clubAssets'];
  final unlocked = getUnlockedMinigames(
    clubAssets is Map<String, dynamic> ? clubAssets : null,
  ).toSet();

  return [
    for (final entry in miniGameTitleKeys.entries)
      (
        kind: entry.key,
        titleKey: entry.value,
        unlocked: unlocked.contains(entry.key),
        ready: miniGameReady(s, entry.key),
        waitMs: msUntilMiniGame(s, entry.key),
        playable: playableMiniGames.contains(entry.key),
        unlocksAtTier: minigameUnlockTier[entry.key] ?? 0,
      ),
  ];
});

/// Anything ready to play right now, for the Training tab's badge.
final miniGamesReadyProvider = savePick<int>((s) {
  final clubAssets = s['clubAssets'];
  final unlocked = getUnlockedMinigames(
    clubAssets is Map<String, dynamic> ? clubAssets : null,
  ).toSet();
  return miniGameTitleKeys.keys
      .where(
        (k) =>
            unlocked.contains(k) &&
            playableMiniGames.contains(k) &&
            miniGameReady(s, k),
      )
      .length;
});

/// Which rung of the ladder the club is on.
///
/// The penalty keeper's kit is picked from it — Sunday League faces a rookie,
/// the Champions Cup a world-class one — which is the visual half of the
/// smart-dive ramp the engine scales with the same number.
final divisionIndexProvider = savePick<int>((s) {
  final prog = s['progression'];
  final id = prog is Map ? prog['currentDivision'] as String? : null;
  final idx = divisionIndex(id);
  return idx < 0 ? 0 : idx;
});

/// How many free cooldown skips the day has left.
///
/// The ledger, the cap and the wind-back have all been in
/// `mini_games_engine.dart` since M1 with **no UI caller** — which is why a
/// resting drill offered no way out of the wait. See `TrainingView`.
final skipsLeftTodayProvider = savePick<int>(skipAdsLeftToday);
