/// The daily reward, as the player meets it. Ported from
/// `ui/components/DailyRewardPopup.js`.
///
/// The port had a Coach Colin card reading "Day 3" with a Claim button, which
/// threw away everything the popup is FOR: a login reward works because the
/// player can see the week they are part-way through and what is at the end of
/// it. Day seven pays the only recurring gems in the game, and the old card
/// never mentioned it.
///
/// So: the whole cycle, today marked, the streak counted, and the broken-streak
/// branch the engine has always supported. `getDailyRewardPreview` and
/// `canRepairStreak` were both ported with no caller — the shape of this file is
/// what they were ported for.
///
/// A bottom sheet rather than a coach card: it has content to read, which is the
/// line between the two shapes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/ui/popups/sheet_header.dart';
import 'package:merge_empire_fc/engine/daily_reward_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart'
    show hudCoinInk, hudEnergyInk, hudGemInk;
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
import 'package:merge_empire_fc/util/format.dart';

/// One thing a day of the cycle pays: its figure, and the icon that says which
/// wallet it lands in.
///
/// [icon] is a name from `game_icon.dart` — the app's own line art — or null for
/// the two rewards that are not a currency and have no glyph in the set.
typedef DayReward = ({String text, String? icon, Color? ink});

/// What one day of the cycle offers, one entry per reward.
///
/// Coins first because every day has them; the extras follow only when a day
/// actually carries one, so a plain day reads as plain rather than as a list of
/// zeroes.
///
/// **EACH ONE IS ITS OWN BOX ON THE TILE**, which is what [_RewardChips] draws.
/// They were one string joined with middots, so a day paying coins, energy and
/// gems was a single 11px run of three figures the eye had to split up — and
/// the strip has the room for three chips. Asked for from the couch, along with
/// the coin: money is the app's own coin in the coin gold everywhere else, and
/// here it was an emoji money-bag.
List<DayReward> dayRewardParts(DailyRewardPreview reward) => [
  (text: formatCoins(reward.coins), icon: 'coin', ink: hudCoinInk),
  if (reward.energy > 0)
    (text: '${reward.energy}', icon: 'bolt', ink: hudEnergyInk),
  if (reward.gems > 0) (text: '${reward.gems}', icon: 'gem', ink: hudGemInk),
  // Neither of these is a currency, so neither has a glyph in the icon set —
  // the scout day carries its own shipped word and the heal day a plus.
  if (reward.freeScout)
    (text: t('daily.reward_scout_short'), icon: null, ink: null),
  if (reward.healOne) (text: '➕', icon: null, ink: null),
];

/// The same day as ONE LINE, for a screen reader.
///
/// The chips are icons and figures, which say nothing out loud — so the tile
/// keeps the sentence it used to print and hands it to `Semantics` instead.
String dayRewardLine(DailyRewardPreview reward) => [
  for (final part in dayRewardParts(reward)) part.text,
].join(' · ');

/// Show it, and report back once it is gone.
///
/// [onDone] is the popup queue's: the queue holds everything behind this one
/// until it is called, so it must be called on every path out.
Future<void> showDailyRewardSheet(
  BuildContext context, {
  required GameState game,
}) => showBottomSheetPopup<void>(
  context,
  // **IT WAS TWO THIRDS OF THE SCREEN AND USING HALF OF THAT.** Reported from
  // the couch: a week of 76px tiles in 10px type with the page empty under it.
  // The strip is the whole reason the sheet exists, so it gets the room.
  heightFraction: 0.85,
  child: const DailyRewardSheet(),
);

class DailyRewardSheet extends ConsumerStatefulWidget {
  const DailyRewardSheet({super.key});

  @override
  ConsumerState<DailyRewardSheet> createState() => DailyRewardSheetState();
}

class DailyRewardSheetState extends ConsumerState<DailyRewardSheet> {
  /// What the claim paid, once it has been made. The sheet stays up to say so —
  /// a reward that vanishes the moment it is taken is a reward the player never
  /// saw.
  DailyClaim? _claimed;

  /// The player chose to start the week again rather than repair it.
  bool _repairDeclined = false;

  /// A video is up. Both offers go dead together — the sheet is one decision
  /// and two of them in flight is two claims against one day.
  bool _busy = false;

  /// Claim at double, if the video is watched to the end.
  Future<void> _claimDoubled() async {
    setState(() => _busy = true);
    final outcome = await ref.read(rewardedAdsProvider).show(dailyDoublePlacement);
    if (!mounted) return;
    setState(() => _busy = false);
    if (outcome == AdOutcome.unavailable) {
      emit('toast:info', t('toast.no_ad'));
      return;
    }
    // Dismissed early is a choice, not a fault: nothing is owed and nothing is
    // said. The single-rate button is still there.
    if (outcome != AdOutcome.rewarded) return;
    setState(() {
      _claimed = ref
          .read(gameProvider)
          .update((s) => claimDailyReward(s, doubled: true));
    });
  }

  /// Put the streak back, if the video is watched to the end.
  Future<void> _repairStreak() async {
    setState(() => _busy = true);
    final outcome = await ref
        .read(rewardedAdsProvider)
        .show(streakRepairPlacement);
    if (!mounted) return;
    setState(() => _busy = false);
    if (outcome == AdOutcome.unavailable) {
      emit('toast:info', t('toast.no_ad'));
      return;
    }
    if (outcome != AdOutcome.rewarded) return;
    // **The engine decides whether it CAN be repaired, not this.** The window
    // is its own — a streak broken long enough ago is gone — and re-deciding it
    // here would be a second answer to the same question.
    final done = ref.read(gameProvider).update((s) => repairStreak(s));
    if (!mounted || !done.ok) return;
    setState(() {});
  }

  /// Test seam.
  DailyClaim? get claimed => _claimed;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final game = ref.read(gameProvider);
    final state = ref.watch(gameProvider).state ?? const <String, dynamic>{};
    final status = getDailyRewardStatus(state);
    final claim = _claimed;

    final showRepair =
        claim == null &&
        status.broken &&
        !_repairDeclined &&
        canRepairStreak(state);

    return ListView(
      key: const ValueKey('daily-reward-sheet'),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      children: [
        SheetHeader(
          title: claim == null ? t('daily.title') : t('daily.congrats'),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 10),
        // **THE STREAK IS THE WHOLE REASON TO COME BACK TOMORROW, and it was a
        // 12px grey caption.** It is the one number on this sheet that is
        // ABOUT the player rather than about the prize — the cycle strip below
        // already says what today pays — and the sheet had room to spare.
        //
        // `getDailyStreak` reads it off the save and had gone through two
        // reachability audits with no caller in `lib/` at all. A claim in
        // flight still wins: the engine has already counted today and the save
        // it is read from has not been written yet.
        _StreakBand(streak: claim?.streak ?? getDailyStreak(state)),
        const SizedBox(height: 14),

        if (showRepair)
          _BrokenStreak(
            streak: status.streak,
            onStartOver: () => setState(() => _repairDeclined = true),
            onRepair: _busy ? null : _repairStreak,
          )
        else ...[
          // The whole week, so the player can see where day seven is. Today is
          // the one that is picked out; the days behind it are what the streak
          // has already banked.
          _CycleStrip(
            state: state,
            today: claim?.day ?? status.day,
            claimedToday: claim != null || status.claimedToday,
          ),
          const SizedBox(height: 14),

          if (status.trainedBonus && claim == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                t('daily.trained_bonus'),
                key: const ValueKey('daily-trained-bonus'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kit.accentBright,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

          if (claim != null)
            _ItemsObtained(claim: claim)
          else if (status.claimedToday)
            Text(
              t('daily.come_back', {'n': (status.day % cycleDays) + 1}),
              key: const ValueKey('daily-come-back'),
              textAlign: TextAlign.center,
              style: TextStyle(color: kit.textMuted, fontSize: 12),
            )
          else
            Column(
              children: [
                StoreButton(
                  key: const ValueKey('daily-claim'),
                  tone: StoreTone.coin,
                  label: t('daily.claim'),
                  leading: const CoinIcon(size: 14, solid: true),
                  onTap: _busy
                      ? null
                      : () => setState(() {
                          _claimed = game.update((s) => claimDailyReward(s));
                        }),
                ),
                const SizedBox(height: 10),
                // **THE AD DOUBLE IS LIVE.** The grant has always been the
                // engine's own `doubled` flag; what was missing was the video,
                // and `daily_double` has been a real unit id in `ad_units.dart`
                // with no caller the whole time.
                //
                // **The claim happens ONLY if the video was watched to the
                // end.** An unavailable ad must not silently claim at the
                // single rate — the player asked for the doubled one, and
                // quietly giving them half of it spends their day's reward on a
                // choice they did not make.
                // **AND IT LOOKS LIKE THE AD IT IS.** An `OutlinedButton` is
                // the theme's moulded face with an empty middle and a grey edge
                // bar, so the one button on the sheet that pays DOUBLE looked
                // like the disabled state of something — reported from the
                // couch, with the fix named: ads are the yellow-orange in this
                // game, here as in the shop, and the button carries the AD
                // chip and the video glyph so the price is on it.
                StoreButton(
                  key: const ValueKey('daily-claim-double'),
                  tone: StoreTone.ad,
                  label: t('daily.claim_double'),
                  leading: const GameIcon('video', size: 14),
                  onTap: _busy ? null : _claimDoubled,
                ),
              ],
            ),
        ],

        // **NO CLOSE BUTTON.** Tapping outside closes the sheet and so does
        // the handle at the top, so a full-width button doing the same thing
        // was a third control competing with the two that pay — and after a
        // claim it was the ONLY thing left, which made a reward screen look
        // like a dialog. Asked for directly. The line stays as a line: it is
        // the sheet saying it is finished, not something to press.
        const SizedBox(height: 12),
        Text(
          claim == null ? t('daily.close') : t('daily.tap_to_close'),
          key: const ValueKey('daily-close'),
          textAlign: TextAlign.center,
          style: TextStyle(color: kit.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

/// The seven days: what each pays, which one is today, and **which are already
/// banked.**
///
/// The strip picked out today and marked nothing else, so a player four days
/// into a streak saw days one to three drawn exactly like days five to seven —
/// a row of seven identical tiles with one border on it. The whole point of a
/// cycle is watching it fill, and the ticks are the only thing that says a
/// streak is a thing you are building rather than a number in a caption.
class _CycleStrip extends StatelessWidget {
  const _CycleStrip({
    required this.state,
    required this.today,
    required this.claimedToday,
  });

  final Map<String, dynamic> state;
  final int today;
  final bool claimedToday;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // **EQUAL BOXES, and the row uses the width it has.** They were fixed at
      // 84px in a `Wrap`, so seven of them broke into a full row and a short
      // one that sat centred under it — and on any phone wider than the four
      // they fitted, the strip left a third of the sheet empty rather than
      // growing. Four and three, each tile a share of the same width, so a day
      // is the same object wherever it is in the week.
      const spacing = 6.0;
      const perRow = 4;
      final width = (box.maxWidth - spacing * (perRow - 1)) / perRow;
      Widget row(Iterable<int> days) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final day in days) ...[
            SizedBox(width: width, child: _tile(context, day)),
            if (day != days.last) const SizedBox(width: spacing),
          ],
        ],
      );
      return Column(
        children: [
          row([for (var d = 1; d <= perRow; d++) d]),
          const SizedBox(height: spacing),
          row([for (var d = perRow + 1; d <= cycleDays; d++) d]),
        ],
      );
    },
  );

  Widget _tile(BuildContext context, int day) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final reward = getDailyRewardPreview(state, day);
    if (reward == null) return const SizedBox.shrink();
    // **Banked is everything BEFORE today, plus today once claimed.** The cycle
    // runs 1 to 7 in order and today's position is how far through it you are —
    // and a broken streak resets that position to 1, so nothing is marked,
    // which is exactly right: a streak that broke has nothing banked.
    final banked = day < today || (day == today && claimedToday);
    final now = day == today;
    return Container(
      key: ValueKey('daily-day-$day'),
      // One height for all seven: a strip whose tiles are as tall as their own
      // reward line is a strip that steps up and down across the week. Taller
      // since the rewards became chips — three of them stacked is what the
      // seventh day needs, and the sheet has the room.
      height: 118,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      decoration: BoxDecoration(
        color: now
            ? kit.surface2
            : banked
            ? kit.accent.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: now
              ? kit.accent
              : banked
              ? kit.accent.withValues(alpha: 0.45)
              : kit.border,
          width: now ? 2 : 1,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                now && !claimedToday
                    ? t('daily.today')
                    : t('daily.day', {'n': day}),
                style: TextStyle(
                  color: now || banked ? kit.accentBright : kit.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              // **A banked day is DIMMED, not hidden.** What it paid is still
              // the answer to "what does this cycle give me", and a strip that
              // blanks its own history teaches nothing.
              Opacity(
                opacity: banked && !now ? 0.5 : 1,
                // The chips are glyphs and figures and say nothing out loud, so
                // the line they replaced is what a screen reader gets.
                child: Semantics(
                  label: dayRewardLine(reward),
                  child: ExcludeSemantics(
                    child: _RewardChips(reward: reward, today: now),
                  ),
                ),
              ),
            ],
          ),
          // **THE TICK CROSSES THE WHOLE BOX.** It was an 11px glyph tucked in
          // front of the day's label, at the size of the caption it sat beside
          // — so a claimed day and an unclaimed one read the same from a foot
          // away. A stamp over the tile is what "done" looks like, and the
          // reward underneath still shows through it.
          if (banked)
            Center(
              key: ValueKey('daily-claimed-$day'),
              child: FittedBox(
                child: Icon(
                  Icons.check,
                  size: 60,
                  color: kit.accentBright.withValues(alpha: 0.55),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One box per reward, inside a day of the strip.
///
/// **A BOX EACH, not one run of text.** The rewards were joined with middots
/// into a single 11px line, so a day paying coins, energy and gems asked the
/// eye to split three figures apart — and the tile has the width for three
/// small pills. Each one is its wallet's own colour, which is the same coding
/// the HUD uses: gold is money, violet is energy, cyan is gems.
class _RewardChips extends StatelessWidget {
  const _RewardChips({required this.reward, required this.today});

  final DailyRewardPreview reward;

  /// Today's tile draws its figures heavier — it is the one being claimed.
  final bool today;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final part in dayRewardParts(reward))
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                // A wash of the wallet's own hue rather than a second grey: the
                // tile behind it is already a surface, and a box that is only a
                // border reads as an empty field.
                color: (part.ink ?? kit.textMuted).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: (part.ink ?? kit.border).withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (part.icon case final name?) ...[
                    // The app's own coin, bolt and gem — the money was an emoji
                    // money-bag, which is the one glyph in the game that was not
                    // drawn in the set everything else is drawn in.
                    GameIcon(name, size: 10, color: part.ink),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    part.text,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.1,
                      color: part.ink,
                      fontWeight: today ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// What the claim actually paid.
class _ItemsObtained extends StatelessWidget {
  const _ItemsObtained({required this.claim});

  final DailyClaim claim;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Column(
      key: const ValueKey('daily-items'),
      children: [
        Text(
          t('daily.items_obtained'),
          style: TextStyle(color: kit.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Text(
          [
            '${t('daily.item_coins')}: ${formatCoins(claim.coins)}',
            if (claim.energy > 0) '${claim.energy}⚡',
            if (claim.gems > 0) '${claim.gems}💎',
            // Pro mode has no pip pool, so an energy day tops the squad up
            // instead. Said as a percentage because that is what moved.
            if (claim.teamEnergyPct > 0)
              '+${(claim.teamEnergyPct * 100).round()}%',
            if (claim.healedCount > 0) '➕ ${claim.healedCount}',
          ].join(' · '),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: kit.accentBright,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

/// How many days in a row, at the size that says it matters.
class _StreakBand extends StatelessWidget {
  const _StreakBand({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Container(
      key: const ValueKey('daily-streak'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            kit.accent.withValues(alpha: 0.30),
            kit.accent.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: kit.accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          // A flame rather than a number in a sentence: a run is a thing that
          // is burning, and the glyph says it in every language — which this
          // sheet needs, because no new `t()` key can be added from here.
          Text(
            streak > 0 ? '🔥' : '·',
            style: const TextStyle(fontSize: 26),
          ),
          const SizedBox(width: 12),
          Text(
            '$streak',
            key: const ValueKey('daily-streak-figure'),
            style: TextStyle(
              fontSize: 34,
              height: 1,
              fontWeight: FontWeight.w900,
              color: kit.accentBright,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t('daily.streak', {'n': streak}),
              style: TextStyle(
                color: kit.textMuted,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The two placements this sheet spends. Keys from `data/ad_units.dart`, both
/// of which have carried a real unit id and no caller since the units landed.
const String dailyDoublePlacement = 'daily_double';
const String streakRepairPlacement = 'streak_repair';

/// The broken-streak branch.
///
/// **The repair is a rewarded video, and it works now.** `streak_repair` has
/// been a real unit id in `ad_units.dart` with no caller since the ad units
/// landed, and `repairStreak` a ported engine function with no caller since
/// before that — so the one way back from a broken streak was present, dead,
/// and explained.
///
/// Reset stays beside it: a player who does not want to watch anything should
/// not have to close the sheet to say so.
class _BrokenStreak extends StatelessWidget {
  const _BrokenStreak({
    required this.streak,
    required this.onStartOver,
    required this.onRepair,
  });

  final int streak;
  final VoidCallback onStartOver;

  /// Null while a video is already up.
  final VoidCallback? onRepair;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Column(
      key: const ValueKey('daily-broken'),
      children: [
        Text(
          t('daily.broken_title'),
          style: const TextStyle(
            color: Colors.redAccent,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          t('daily.broken_body', {'n': streak}),
          textAlign: TextAlign.center,
          style: TextStyle(color: kit.textMuted, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const ValueKey('daily-repair'),
            onPressed: onRepair,
            child: Text(t('daily.repair')),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            key: const ValueKey('daily-start-over'),
            onPressed: onStartOver,
            child: Text(t('daily.start_over')),
          ),
        ),
      ],
    );
  }
}
