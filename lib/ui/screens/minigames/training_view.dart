/// The list of drills, shown in the Training sheet.
///
/// It was a stub saying "coming soon" while the Club's Training Ground was
/// busy unlocking games it pointed at — two dangling references at once.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/engine/gem_engine.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart'
    show hudBadgeColour, hudBadgeInk, hudCoinInk;
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
import 'package:merge_empire_fc/util/event_bus.dart';
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
/// The mini-game skip's own placement. Keys from `ad_units.dart`, and NOT the
/// shop's `match_cooldown` — the two were sharing an id until this button got
/// its video back.
const String skipCooldownPlacement = 'skip_cooldown';

class _SkipAll extends ConsumerStatefulWidget {
  const _SkipAll();

  @override
  ConsumerState<_SkipAll> createState() => _SkipAllState();
}

class _SkipAllState extends ConsumerState<_SkipAll> {
  /// Dead while the video is up. Two taps is two videos for one skip.
  bool _watching = false;

  @override
  void initState() {
    super.initState();
    // **WARMED, and `shouldPrefetchSkipAd` finally has a caller.** The engine
    // has known when to do this since the skip went in — everything the player
    // owns is cooling down and there is a free video left — and nothing in
    // `lib/` asked it, so the button always paid the full load on the tap.
    // Exactly the dead-engine shape `tool/unreached.sh` is for.
    //
    // Its own note explains the second half of the condition: past the day's
    // three the button is a gem purchase and shows no ad, and the plugin
    // caches ONE rewarded ad globally, so warming this any earlier evicts a
    // placement the player was likelier to reach.
    final save = ref.read(gameProvider).state;
    if (save != null && shouldPrefetchSkipAd(save)) {
      ref.read(rewardedAdsProvider).prepare(skipCooldownPlacement);
    }
  }

  /// **THE VIDEO, which this button never showed.**
  ///
  /// It called `skipAllMiniGameCooldowns` straight off the tap, wearing the ad
  /// tone and the video chip and playing nothing — reported from the couch as
  /// hitting the ad for cooldowns and no ad coming up. The JS has always shown
  /// one: `EnergyBar._onSkipAll` runs `showRewardedAd(..., 'skip_cooldown')`
  /// and only clears the board in the reward callback.
  ///
  /// The placement was there and spoken for: `shop_match_day.dart` had the shop's
  /// match-cooldown tile pointed at `'skip_cooldown'`, which is the JS's name
  /// for THIS button. Both ids are in `ad_units.dart` and the shop has its own.
  Future<void> _watchThenSkip() async {
    setState(() => _watching = true);
    final outcome = await watchRewardedAd(ref, skipCooldownPlacement);
    if (!mounted) return;
    setState(() => _watching = false);
    if (outcome == AdOutcome.rewarded) {
      // The allowance is re-read INSIDE the update rather than trusted from
      // the build that painted the button — the JS makes the same point in its
      // own comment, and a button rendered before the third video must not pay
      // for a fourth. `skipAllMiniGameCooldowns` returns false and touches
      // nothing when the day is spent.
      ref.read(gameProvider).update(skipAllMiniGameCooldowns);
    } else if (outcome == AdOutcome.unavailable) {
      emit('toast:info', t('toast.ad_unavailable'));
    }
  }

  /// **AND PAST THE DAY'S THREE IT REPRICES, rather than dying.**
  ///
  /// `Minigame.skipGemCost`'s own note says so — "past them the button
  /// reprices to gems rather than dying, so this ends the free ride, not the
  /// feature" — and the port had it dying: `onTap: null` and a capped label.
  /// The JS turns the button blue, swaps the "N left" chip for a gem price and
  /// spends `MINIGAME_SKIP_GEM_COST`.
  void _buySkip() {
    var paid = false;
    ref.read(gameProvider).update((state) {
      if (!spendGems(state, Minigame.skipGemCost, 'skip_cooldown')) return;
      paid = true;
      for (final kind in skipKinds) {
        resetMiniGameCooldown(state, kind);
      }
    });
    if (!paid) emit('toast:error', t('shop.toast.not_enough_gems'));
  }

  @override
  Widget build(BuildContext context) {
    final resting = ref
        .watch(miniGamesProvider)
        .where((g) => g.unlocked && g.playable && !g.ready)
        .length;
    if (resting == 0) return const SizedBox.shrink();
    final skipsLeft = ref.watch(skipsLeftTodayProvider);
    final byAd = skipsLeft > 0;

    return Padding(
      key: const ValueKey('training-skip-all'),
      padding: const EdgeInsets.only(bottom: 8),
      child: StoreButton(
        // **BLUE IS A PRICE, YELLOW IS AN AD**, and a purchase must never
        // carry an ad disclosure — the JS says exactly that on the line that
        // toggles it. So the tone follows what the tap will actually do.
        tone: byAd ? StoreTone.ad : StoreTone.gem,
        // **FULL SIZE, like every other rewarded-video control in the game.**
        // `small: true` drew it at 11-point type in a short pill while the
        // shop's ad buttons and the summary's 2× are 14 in a full one — so the
        // one on the screen that actually clears the board looked like a
        // footnote. Reported from the couch, naming the height and the font.
        stretch: true,
        leading: _watching
            ? null
            : GameIcon(byAd ? 'video' : 'gem', size: 14),
        // `minigame.skip_all_left` is "{n} left" — the day's ledger, which the
        // player has no other way of seeing. Past it the chip is the price.
        label: _watching
            ? t('common.loading')
            : byAd
            ? '${t('minigame.skip_all_ad')} · '
                  '${t('minigame.skip_all_left', {'n': skipsLeft})}'
            : '${t('minigame.skip_all_ad')} · ${Minigame.skipGemCost}',
        onTap: _watching ? null : (byAd ? _watchThenSkip : _buySkip),
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
    // **THE WORD IS THE ONE [_SkipAll] USES**, because that button is what
    // clears this clock — "Skip all cooldowns" over rows that said "Resting"
    // left the two unconnected. Reported from the couch. Still its own key and
    // not `play.cooldown`: that one is the PLAY BUTTON's, the manager waiting
    // to pick a team again, and it reads "Coach cooldown".
    if (!game.ready) {
      return t('training.resting', {'time': formatDuration(game.waitMs)});
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
        // promise. **Keepy Uppys carries one too now** — the run ends at the
        // full-run target rather than going on for ever, so it has a perfect
        // score like the rest of them and was the one row quoting nothing.
        //
        // **AND IT SAYS "UP TO", which it could not before.** The figure is a
        // PERFECT run — every drill, every shot — and quoted as a bare coin
        // badge it read as the price of playing rather than as a ceiling.
        // Reported from the couch. This carried a note saying there was no
        // catalogue key for the words and none could be added from this repo;
        // `en_copy.dart` and `lib/i18n/copy/` are where copy is written now, so
        // `training.up_to` is theirs and ships in all ten.
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
                  // **AND IT IS A BADGE, not a bare figure.** `coinFigureInk`
                  // answers a deep bronze on a light page — right for gold on
                  // white and reported from the couch as horrible on this
                  // list. The rest of the game fills the chip in the wallet's
                  // colour and prints on it instead: `hudBadgeColour` /
                  // `hudBadgeInk`, which is what the bar, the pack contents,
                  // the season quests and the session summary all wear.
                  if (best != null) ...[
                    Text(
                      t('training.up_to'),
                      style: TextStyle(color: kit.textMuted, fontSize: 12),
                    ),
                    const SizedBox(width: 5),
                    _CoinBadge(amount: best),
                    if (reason != null)
                      Text(
                        ' · ',
                        style: TextStyle(color: kit.textMuted, fontSize: 12),
                      ),
                  ],
                  if (reason != null)
                    Expanded(
                      child: Text(
                        reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: kit.textMuted, fontSize: 12),
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

/// What a drill pays, in the coin wallet's own badge.
///
/// One chip rather than a glyph and a figure loose on the row — see the note
/// at the call site for why the bare figure had to go.
class _CoinBadge extends StatelessWidget {
  const _CoinBadge({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    final face = hudBadgeColour(hudCoinInk);
    final ink = hudBadgeInk(face);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 1.5, 7, 1.5),
      decoration: BoxDecoration(
        color: face,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameIcon('coin', size: 11, color: ink),
          const SizedBox(width: 4),
          Text(
            formatCoins(amount),
            style: TextStyle(
              color: ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
