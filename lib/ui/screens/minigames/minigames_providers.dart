/// The mini-games, derived from the save.
///
/// The Club's Training Ground unlocks them one tier at a time and the League's
/// Training tab pointed at them; neither had anywhere to point. This is the
/// list both were talking about.
library;

import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';

/// One game, and whether it can be played right now.
typedef MiniGameRow = ({
  String kind,
  String titleKey,
  bool unlocked,
  bool ready,
  int waitMs,
  bool playable,
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
