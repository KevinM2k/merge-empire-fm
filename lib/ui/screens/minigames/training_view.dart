/// The list of drills, shown in the Training sheet.
///
/// It was a stub saying "coming soon" while the Club's Training Ground was
/// busy unlocking games it pointed at — two dangling references at once.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
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

    return ListView(
      key: const ValueKey('training-view'),
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
        for (final game in games) _GameRow(game: game),
      ],
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

  /// A drill that is unlocked, built, and only waiting on the clock.
  ///
  /// The one no that has a way out — which is what the skip is for, and why the
  /// button appears here and nowhere else.
  bool get _resting => game.unlocked && game.playable && !game.ready;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final reason = _reason;
    final skipsLeft = ref.watch(skipsLeftTodayProvider);

    final tint = drillTint(kit.accent, game.kind);
    final open = reason == null;

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
        subtitle: reason == null
            ? null
            : Text(
                reason,
                style: TextStyle(color: kit.textMuted, fontSize: 11),
              ),
        // **A WAIT GETS AN OFFER; A LOCK DOES NOT.** The skip is only ever shown
        // on a drill that is resting — there is nothing to skip on one that has
        // no screen, and nothing to skip on one the Training Ground has not
        // reached. Dead until AdMob lands, and shown rather than hidden for the
        // same reason the Shop's own ad tiles are: an offer that appears the day
        // it starts working is a surprise, and one that explains itself is a
        // feature that is coming.
        trailing: reason == null
            ? Icon(Icons.play_arrow, color: tint)
            : _resting
            ? StoreButton(
                key: ValueKey('training-skip-${game.kind}'),
                tone: StoreTone.ad,
                small: true,
                stretch: false,
                label: skipsLeft > 0
                    ? t('minigame.skip_ad')
                    : t('minigame.skip_all_capped'),
                onTap: null,
              )
            : null,
        enabled: reason == null,
        onTap: reason != null ? null : () => _open(context),
      ),
    );
  }
}
