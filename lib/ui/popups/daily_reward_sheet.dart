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
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/format.dart';

/// What one day of the cycle offers, in one line.
///
/// Coins first because every day has them; the extras follow only when a day
/// actually carries one, so a plain day reads as plain rather than as a list of
/// zeroes.
String dayRewardLine(DailyRewardPreview reward) {
  final parts = <String>[
    formatCoins(reward.coins),
    if (reward.energy > 0) '${reward.energy}⚡',
    if (reward.gems > 0) '${reward.gems}💎',
    if (reward.freeScout) t('daily.reward_scout_short'),
    if (reward.healOne) '➕',
  ];
  return parts.join(' · ');
}

/// Show it, and report back once it is gone.
///
/// [onDone] is the popup queue's: the queue holds everything behind this one
/// until it is called, so it must be called on every path out.
Future<void> showDailyRewardSheet(
  BuildContext context, {
  required GameState game,
}) => showBottomSheetPopup<void>(
  context,
  heightFraction: 0.62,
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
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      children: [
        SheetHeader(
          title: claim == null ? t('daily.title') : t('daily.congrats'),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 4),
        Text(
          t('daily.streak', {'n': claim?.streak ?? status.streak}),
          key: const ValueKey('daily-streak'),
          textAlign: TextAlign.center,
          style: TextStyle(color: kit.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 14),

        if (showRepair)
          _BrokenStreak(
            streak: status.streak,
            onStartOver: () => setState(() => _repairDeclined = true),
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const ValueKey('daily-claim'),
                    onPressed: () => setState(() {
                      _claimed = game.update((s) => claimDailyReward(s));
                    }),
                    child: Text(t('daily.claim')),
                  ),
                ),
                const SizedBox(height: 6),
                // The ad double, present and dead: the grant is the engine's
                // `doubled` flag and the ad is AdMob's, which M4 has not
                // delivered. Shown rather than hidden, so the offer is not a
                // surprise the day it starts working.
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: const ValueKey('daily-claim-double'),
                    onPressed: null,
                    child: Text(t('daily.claim_double')),
                  ),
                ),
              ],
            ),
        ],

        const SizedBox(height: 10),
        TextButton(
          key: const ValueKey('daily-close'),
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(
            claim == null ? t('daily.close') : t('daily.tap_to_close'),
          ),
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
      // reward line is a strip that steps up and down across the week.
      height: 76,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              // **A banked day is DIMMED, not hidden.** What it paid is still
              // the answer to "what does this cycle give me", and a strip that
              // blanks its own history teaches nothing.
              Opacity(
                opacity: banked && !now ? 0.5 : 1,
                child: Text(
                  dayRewardLine(reward),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.25,
                    fontWeight: now ? FontWeight.w900 : FontWeight.w400,
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

/// The broken-streak branch.
///
/// A repair needs a rewarded ad, which M4 has not delivered — so the offer is
/// present and dead, and Reset is live. The alternative was to hide the repair
/// and reset the streak silently, which is the same outcome with none of the
/// explanation.
class _BrokenStreak extends StatelessWidget {
  const _BrokenStreak({required this.streak, required this.onStartOver});

  final int streak;
  final VoidCallback onStartOver;

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
            onPressed: null,
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
