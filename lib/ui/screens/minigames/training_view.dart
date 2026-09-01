/// The list of drills, shown in the Training sheet.
///
/// It was a stub saying "coming soon" while the Club's Training Ground was
/// busy unlocking games it pointed at — two dangling references at once.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/home/sub_tab_coach_line.dart';
import 'package:merge_empire_fc/ui/popups/sheet_header.dart';
import 'package:merge_empire_fc/ui/screens/minigames/minigames_providers.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/ui/screens/minigames/boot_room_screen.dart';
import 'package:merge_empire_fc/ui/screens/minigames/goalkeeper_practice_screen.dart';
import 'package:merge_empire_fc/ui/screens/minigames/keepy_uppys_screen.dart';
import 'package:merge_empire_fc/ui/screens/minigames/penalty_screen.dart';
import 'package:merge_empire_fc/ui/screens/minigames/pitch_invaders_screen.dart';
import 'package:merge_empire_fc/ui/screens/minigames/teamwork_screen.dart';
import 'package:merge_empire_fc/ui/screens/minigames/through_ball_screen.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/util/time.dart';

/// The face of each drill.
///
/// **Seven drills wore the same football.** `Icons.sports_soccer` on every row
/// is a list that says nothing about what is in it — the sheet was reported as
/// having no images and being boring, and one repeated glyph is what that looks
/// like. Each drill gets the thing it is ABOUT, and they are emoji rather than
/// icons for the reason the trait badges are: the glyph is the same in every
/// language and needs no `t()` key, which is a catalogue away from here.
const Map<String, String> drillGlyphs = {
  MiniGameKind.penalty: '🥅',
  MiniGameKind.training: '🧤',
  MiniGameKind.keepyUppys: '⚽',
  MiniGameKind.throughBall: '🎯',
  MiniGameKind.whack: '👟',
  MiniGameKind.pairs: '🃏',
  MiniGameKind.bootRoom: '🏆',
};

/// A tint per drill, so the column is seven cards and not one repeated.
///
/// Off the kit's own accent rather than a fixed palette — the whole scheme is
/// derived from the club's colours, and a fixed hue would be the one tile on
/// screen that is not.
const Map<String, double> _drillHueShift = {
  MiniGameKind.penalty: 0,
  MiniGameKind.training: 42,
  MiniGameKind.keepyUppys: 84,
  MiniGameKind.throughBall: 126,
  MiniGameKind.whack: 168,
  MiniGameKind.pairs: 210,
  MiniGameKind.bootRoom: 252,
};

/// The drill's own colour: the kit's accent, walked round the wheel.
Color drillTint(Color accent, String kind) {
  final hsl = HSLColor.fromColor(accent);
  return hsl
      .withHue((hsl.hue + (_drillHueShift[kind] ?? 0)) % 360)
      .withSaturation(hsl.saturation.clamp(0.35, 0.8))
      .toColor();
}

class TrainingView extends ConsumerWidget {
  const TrainingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final games = ref.watch(miniGamesProvider);

    // **He only speaks here when a cup tie is due.** Training is free, so a tank
    // at nought is not a reason to stay off a sheet full of games that cost
    // none — which is why the JS gives this sub-tab the cup branch alone. In
    // the corner every other screen puts him in; see [withSubTabCoach].
    return withSubTabCoach(
      which: CoachLineFor.minigames,
      child: ListView(
      key: const ValueKey('training-view'),
      // The spec's own example of a sheet that must not leave a void under it.
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: [
        // `mg.drills` is the in-game counter — "Drills: {hit} / {total}" — and
        // asking for it with no parameters rendered those braces to the player.
        // `training.title` is the sheet's name, and it was shipped in all ten
        // catalogues with nothing able to reach it.
        SheetHeader(
          title: t('training.title'),
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
        ),
        const _SkipAll(),
        for (final game in games) _GameRow(game: game),
        // Room at the foot for the corner to sit over.
        const SizedBox(height: 76),
      ],
      ),
    );
  }
}

/// One skip, above all seven drills.
///
/// **A SKIP IS FOR THE WHOLE SHEET, not for one row.** It was a per-drill button
/// in each resting row's trailing slot, so clearing the wait on the penalty game
/// left the other six still on the clock — and the day only has
/// [Minigame.skipCapPerDay] skips to spend. The engine has said so since M1:
/// `skipKinds` is documented as "every kind one skip clears" and had no caller
/// at all, alongside `resetMiniGameCooldown`, `recordSkipAd` and the two shipped
/// strings this now prints. Reported from the couch.
///
/// **It only appears when there is something to skip.** A button offering to
/// clear cooldowns on a sheet where every drill is ready is an offer with no
/// subject; the row it used to live in had that for free by being per-drill.
class _SkipAll extends ConsumerWidget {
  const _SkipAll();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resting = ref
        .watch(miniGamesProvider)
        .where((g) => g.unlocked && g.playable && !g.ready)
        .length;
    if (resting == 0) return const SizedBox.shrink();
    final skipsLeft = ref.watch(skipsLeftTodayProvider);

    return Padding(
      key: const ValueKey('training-skip-all'),
      padding: const EdgeInsets.only(bottom: 8),
      child: StoreButton(
        tone: StoreTone.ad,
        // **FULL SIZE, like every other rewarded-video control in the game.**
        // `small: true` drew it at 11-point type in a short pill while the
        // shop's ad buttons and the summary's 2× are 14 in a full one — so the
        // one on the screen that actually clears the board looked like a
        // footnote. Reported from the couch, naming the height and the font.
        stretch: true,
        // `minigame.skip_all_left` is "{n} left" — the day's ledger, which the
        // player has no other way of seeing.
        label: skipsLeft > 0
            ? '${t('minigame.skip_all_ad')} · '
                  '${t('minigame.skip_all_left', {'n': skipsLeft})}'
            : t('minigame.skip_all_capped'),
        // **IT ACTUALLY SKIPS.** The old one was wired to null and waiting on
        // AdMob. The cap is what bounds it either way — three a day — so
        // spending one before there is a video to watch costs the player
        // nothing they were not already owed, and the plumbing the rewarded ad
        // will hang off is the same call.
        onTap: skipsLeft > 0
            ? () => ref
                  .read(gameProvider)
                  .update((state) => skipAllMiniGameCooldowns(state))
            : null,
      ),
    );
  }
}

class _GameRow extends ConsumerWidget {
  const _GameRow({required this.game});

  final MiniGameRow game;

  /// Why this row cannot be tapped, or null when it can.
  ///
  /// Three different noes, and they mean different things: not unlocked yet,
  /// unlocked but resting, and unlocked but not built here yet. Collapsing them
  /// into one grey row would tell the player nothing about which.
  ///
  /// **THE LOCKED ONE HAS TO NAME THE TIER**, and it did not — it asked for
  /// `club.minigame_unlocked` with no parameters, so the row rendered the
  /// literal `{name} unlocked`. Worse than the missing name: it left "not
  /// unlocked yet" and "no screen for it yet" both saying nothing useful, and a
  /// player who invests in the Training Ground and finds the drill still grey has
  /// no way of telling which of the two they are looking at.
  String? get _reason {
    if (!game.unlocked) {
      return '${t('asset.${AssetCategory.training}.name')} · '
          '${t('club.tier_n', {'n': game.unlocksAtTier})}';
    }
    if (!game.playable) return t('settings.comingSoon');
    if (!game.ready) {
      return t('play.cooldown', {'time': formatDuration(game.waitMs)});
    }
    return null;
  }

  /// A drill that is unlocked, built, and only waiting on the clock.
  ///
  /// The one no that has a way out — see [_SkipAll], which is where the way out
  /// now lives.
  bool get _resting => game.unlocked && game.playable && !game.ready;

  void _open(BuildContext context) {
    final screen = switch (game.kind) {
      MiniGameKind.bootRoom => const BootRoomScreen(),
      MiniGameKind.throughBall => const ThroughBallScreen(),
      MiniGameKind.whack => const PitchInvadersScreen(),
      MiniGameKind.pairs => const TeamworkScreen(),
      MiniGameKind.training => const GoalkeeperPracticeScreen(),
      MiniGameKind.keepyUppys => const KeepyUppysScreen(),
      _ => const PenaltyScreen(),
    };
    Navigator.of(context).push<void>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final reason = _reason;

    final tint = drillTint(kit.accent, game.kind);
    final open = reason == null;
    // Only for a drill the player can actually reach: a ceiling on a locked
    // row is a price tag on a door.
    final best = game.unlocked && game.playable
        ? ref.watch(miniGameBestProvider(game.kind))
        : null;

    return Card(
      key: ValueKey('training-${game.kind}'),
      color: kit.surface,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        // **A TILE, not a repeated icon.** The drill's own glyph on its own
        // wash of the kit's accent — a locked one keeps the glyph and loses the
        // colour, which is the difference between "not yet" and "not for you"
        // said without a word of copy.
        leading: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: open
                  ? [tint.withValues(alpha: 0.34), tint.withValues(alpha: 0.14)]
                  : [
                      kit.textMuted.withValues(alpha: 0.14),
                      kit.textMuted.withValues(alpha: 0.06),
                    ],
            ),
            border: Border.all(
              color: open
                  ? tint.withValues(alpha: 0.55)
                  : kit.border.withValues(alpha: 0.8),
            ),
          ),
          child: Opacity(
            // A drill that is resting is still YOURS: it dims, it does not
            // grey out the way a locked one does.
            opacity: open ? 1 : (_resting ? 0.75 : 0.4),
            child: Text(
              drillGlyphs[game.kind] ?? '⚽',
              style: const TextStyle(fontSize: 22),
            ),
          ),
        ),
        title: Text(
          t(game.titleKey),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        // **WHAT A SESSION IS WORTH**, which the tab never said — the one
        // figure a player deciding whether to spend three minutes on a drill
        // wants, and `miniGameRewardBase`'s own doc says it exists for exactly
        // this preview. A perfect run, so it is a ceiling rather than a
        // promise; null for Keepy Uppys, whose taps have no ceiling to quote.
        //
        // A COIN AND A NUMBER, no copy: there is no catalogue key for "up to",
        // and none can be added from this repo.
        subtitle: reason == null && best == null
            ? null
            : Row(
                children: [
                  // **MONEY IS GOLD, not the drill's own hue.** The figure and
                  // the coin beside it wore `tint` — the kit's accent walked up
                  // to 252° round the wheel — so seven drills quoted their
                  // money in seven colours and the ones that landed near the
                  // card's own surface could not be read at all. Reported as
                  // not being able to see the money on the training sessions.
                  // `coinFigureInk` is the pair the rest of the game uses and
                  // carries its own light-theme shade.
                  if (best != null) ...[
                    GameIcon('coin', size: 11, color: coinFigureInk(context)),
                    const SizedBox(width: 3),
                    Text(
                      formatCoins(best),
                      style: TextStyle(
                        color: coinFigureInk(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (reason != null)
                      Text(
                        ' · ',
                        style: TextStyle(color: kit.textMuted, fontSize: 11),
                      ),
                  ],
                  if (reason != null)
                    Expanded(
                      child: Text(
                        reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: kit.textMuted, fontSize: 11),
                      ),
                    ),
                ],
              ),
        trailing: reason == null
            // **WHITE IN DARK MODE.** The little arrow took the drill's own
            // hue, and a hue that reads on a light card is a hue that sinks
            // into a dark one — asked for directly. In light mode the tint is
            // what tells the seven rows apart and it stays.
            ? Icon(
                Icons.play_arrow,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : tint,
              )
            : null,
        enabled: reason == null,
        onTap: reason != null ? null : () => _open(context),
      ),
    );
  }
}
