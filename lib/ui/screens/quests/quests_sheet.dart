/// The quests sheet.
///
/// The toast layer says "Season quest complete — claim it in Quests!" and there
/// was no Quests anywhere in the app: shipped copy pointing at nothing, and a
/// completed quest that could never be claimed.
///
/// A bottom sheet, one of the three shapes. **Only the SEASON track is here.**
/// Match quests live on the next-match card, where the fixture they belong to
/// is: they pay themselves as the match runs, so there was never anything to
/// claim on them, and reading them after choosing to open a menu is reading them
/// too late.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart';
import 'package:merge_empire_fc/ui/popups/sheet_header.dart';
import 'package:merge_empire_fc/data/quests.dart' show getQuest;
import 'package:merge_empire_fc/engine/quest_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
import 'package:merge_empire_fc/util/format.dart';

/// One quest, as a row.
typedef QuestRow = ({
  String id,
  String text,
  num progress,
  num target,
  bool completed,
  bool claimed,

  /// What claiming it pays, in coins, at THIS division.
  ///
  /// **A quest that does not say what it pays is a chore.** The reward is a
  /// percentage of one league win rather than a literal, so it is worth
  /// different money in every division — which is exactly why the row has to
  /// carry the resolved figure rather than the bank's number.
  int coins,
});

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num _num(Object? v) => v is num ? v : 0;

List<QuestRow> _rowsFrom(Map<String, dynamic>? state, List<dynamic> raw) {
  final out = <QuestRow>[];
  for (final entry in raw) {
    final inst = _map(entry);
    final id = inst?['id'];
    if (id is! String) continue;
    final target = _num(inst!['target']);
    out.add((
      id: id,
      // Quest text is a catalogue key built from the id, which is exactly why
      // the i18n guard checks every quest in the bank has one.
      text: t('quest.$id', {'n': target}),
      progress: _num(inst['progress']),
      target: target,
      completed: inst['completed'] == true,
      claimed: inst['claimedAt'] != null,
      coins: questRewardCoins(state, getQuest(id)?.reward.coins),
    ));
  }
  return out;
}

final seasonQuestsProvider = savePick<List<QuestRow>>((s) {
  final season = ensureQuests(s)['season'];
  return _rowsFrom(s, season is List ? season : const []);
});

final matchQuestsProvider = savePick<List<QuestRow>>((s) {
  final active = _map(ensureQuests(s)['match'])?['active'];
  return _rowsFrom(s, active is List ? active : const []);
});

/// How many season quests are sitting there completed and unclaimed.
/// **The ENGINE'S count, not a second one.** `unclaimedCount` in
/// `quest_engine.dart` is "completed and not yet claimed" and had no caller in
/// `lib/`; this provider was the same rule written out again, so the badge on
/// the burger and the badge on the Quests tile were two readings that happened
/// to agree. They are one now — see the standing rule about building a second
/// of anything.
final claimableQuestsProvider = savePick<int>(unclaimedCount);

/// What the WHOLE track is worth, and how much of it is banked.
///
/// The gem is the division capstone: every season quest completed AND claimed
/// pays one, once ever, for that division. `quests.capstone_title` and
/// `quests.capstone_reward` were translated into all ten catalogues with
/// nothing able to reach either — a track whose prize nothing mentions.
final seasonQuestPrizeProvider =
    savePick<({int coins, int gems, int claimed, int total})>((s) {
      final season = ensureQuests(s)['season'];
      final rows = _rowsFrom(s, season is List ? season : const []);
      return (
        coins: rows.fold<int>(0, (sum, q) => sum + q.coins),
        gems: divisionCapstonePending(s) ? capstoneGems : 0,
        claimed: rows.where((q) => q.claimed).length,
        total: rows.length,
      );
    });

/// What a reroll would cost, and whether one is possible at all.
final questRerollProvider = savePick<({bool can, int cost, int free})>(
  (s) => (can: canReroll(s), cost: rerollCost(s), free: freeRerollsLeft(s)),
);

Future<void> showQuestsSheet(BuildContext context, WidgetRef ref) {
  // The track for the next match, rolled on the way in. Guarded on the fixture
  // key, so opening the sheet twice shows the same three quests rather than
  // redrawing the set the player has just read.
  ref.read(gameProvider).update(ensureMatchQuests);
  return showBottomSheetPopup<void>(
    context,
    heightFraction: 0.8,
    child: Consumer(
      builder: (sheetContext, sheetRef, _) {
        final kit = Theme.of(sheetContext).extension<KitTheme>()!;
        final season = sheetRef.watch(seasonQuestsProvider);
        final game = sheetRef.read(gameProvider);

        return ListView(
          key: const ValueKey('quests-sheet'),
          // **THE SHEET IS AS TALL AS THE TRACK, and a track is three quests.**
          // A `ListView` fills what it is given, so this one was 80% of the
          // phone with three tiles at the top of it — reported as the season
          // quests popup being too big with too much room at the bottom.
          // `showBottomSheetPopup` caps it; what it needs from here is a height.
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            // **THE HEADER IS THE TRACK'S NAME.** `quests.title` is the bare
            // word "Quests" and `quests.season` sat under it as a subtitle
            // saying "Season Quests" — two headings for one list, on a sheet
            // that only ever shows the season track since the match one moved
            // to the next-match card. The subtitle wins and the label goes.
            SheetHeader(title: t('quests.season'), padding: EdgeInsets.zero),
            const SizedBox(height: 12),
            if (season.isEmpty)
              Text(
                t('quests.none_season'),
                key: const ValueKey('quests-none-season'),
                style: TextStyle(color: kit.textMuted, fontSize: 12),
              ),
            for (final quest in season)
              _QuestTile(
                quest: quest,
                track: 'season',
                onClaim: quest.completed && !quest.claimed
                    ? () => game.update((s) => claimQuest(s, quest.id))
                    : null,
              ),
            // **WHAT THE WHOLE TRACK IS WORTH.** The sheet listed the work and
            // never the pay — not for one quest and not for the set — so a
            // season's quests read as a chore list rather than as a prize with
            // a number on it.
            if (season.isNotEmpty) const _TrackPrize(),
            if (season.isNotEmpty) _RerollRow(),
            // The MATCH track is not here. It belongs on the next-match card —
            // a match quest is an instruction for the game you are about to
            // press Play on, and behind the burger with the season track it was
            // filed in the one place it is no use. See `MatchQuestsBlock`.
            // The line that used to head it stays worth saying, so the card
            // carries the fact that these pay themselves instead.
          ],
        );
      },
    ),
  );
}

/// The prize for the whole track: the coins it pays, and the division's gem.
///
/// The gem is `checkDivisionCapstone` — every season quest completed AND
/// claimed pays one, once ever, for that division. It is the only gem route in
/// the game that is not a purchase, and nothing on screen mentioned it:
/// `quests.capstone_title` and `quests.capstone_reward` sat translated in all
/// ten catalogues with no caller.
class _TrackPrize extends ConsumerWidget {
  const _TrackPrize();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final prize = ref.watch(seasonQuestPrizeProvider);
    if (prize.total == 0) return const SizedBox.shrink();
    final done = prize.claimed >= prize.total;

    return Container(
      key: const ValueKey('quests-track-prize'),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: kit.accent.withValues(alpha: done ? 0.18 : 0.08),
        border: Border.all(
          color: kit.accent.withValues(alpha: done ? 0.7 : 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('quests.capstone_title').toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: kit.textMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${prize.claimed} / ${prize.total}',
                  key: const ValueKey('quests-track-progress'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: done ? kit.accentBright : null,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          if (prize.coins > 0)
            _RewardChip(
              key: const ValueKey('quests-track-coins'),
              icon: 'coin',
              ink: gameGold,
              // **FORMATTED, not printed.** `{n}` was the raw integer, so a
              // capstone read "52000 coins" — a figure the eye has to count
              // digits on, on a chip 40px wide. Trimmed, because a reward that
              // lands on a whole thousand has nothing to say after the dot.
              label: t('quests.reward_coins', {
                'n': formatCoins(prize.coins, trim: true),
              }),
            ),
          // The gem only while it is still there to be earned: a division that
          // has already paid it would be advertising a prize that cannot come
          // twice.
          if (prize.gems > 0) ...[
            const SizedBox(width: 6),
            _RewardChip(
              key: const ValueKey('quests-track-gem'),
              icon: 'gem',
              // **THE HUD'S OWN GEM BLUE.** This was a hand-picked
              // `0xFF7FD4FF`, which `hudBadgeColour` does not recognise — it
              // maps the wallet hues by value — so the chip came back tinted
              // in the literal rather than in the shop's `storeGemFace`, and
              // the season's gem was a different blue from the one in the bar
              // above it. Reported from the couch.
              ink: hudGemInk,
              label: t('quests.capstone_reward', {'n': prize.gems}),
            ),
          ],
        ],
      ),
    );
  }
}

/// A figure with the currency's own glyph on it.
class _RewardChip extends StatelessWidget {
  const _RewardChip({
    required this.icon,
    required this.ink,
    required this.label,
    super.key,
  });

  final String icon;

  /// **THE BRIGHT ink, in both themes**, because this chip's surface is dark in
  /// both — see the decoration below.
  final Color ink;
  final String label;

  @override
  Widget build(BuildContext context) {
    // **THE WALLET'S OWN FACE, which is how the rest of the game draws these
    // now.** This chip solved "yellow on yellow in light mode" by painting
    // itself a dark plate and printing the bright gold on that — the
    // scoreboard move. The HUD settled the same question the other way and
    // everything else followed it: FILL the chip in the wallet's colour and
    // print in a tint of it, which is what `hudBadgeColour`/`hudBadgeInk` are
    // and what the pack contents, the shop shelves and the bar all wear.
    //
    // Reported from the couch as the season quests still doing it the old way:
    // gold ground for coins, blue for gems.
    final face = hudBadgeColour(ink);
    final print = hudBadgeInk(face);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: face,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameIcon(icon, size: 13, color: print),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: print,
            ),
          ),
        ],
      ),
    );
  }
}

/// Swap the unfinished season quests for different ones.
///
/// Two free a season, then gems. It refuses when every quest is already done —
/// there would be nothing to swap, and charging for that would be theft.
class _RerollRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final reroll = ref.watch(questRerollProvider);
    final game = ref.read(gameProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // **THE COLOUR ANSWERS "WHAT DOES THIS COST ME?"** — see [StoreButton].
          // This was an `OutlinedButton`, which the theme moulds with an empty
          // face and a grey edge bar, so the one control on the sheet a player
          // might press looked like the disabled state of something. Free is
          // the club's accent; gems are blue and wear the gem, the same as
          // every other gem price in the game.
          StoreButton(
            key: const ValueKey('quests-reroll'),
            tone: reroll.cost == 0 ? StoreTone.neutral : StoreTone.gem,
            leading: reroll.cost == 0
                ? null
                : const GameIcon('gem', size: 15),
            label:
                '${t('quests.reroll_all')} · '
                '${reroll.cost == 0 ? t('quests.reroll_free') : t('quests.reroll_cost', {'n': reroll.cost})}',
            onTap: reroll.can
                ? () => game.update((s) => rerollQuests(s))
                : null,
          ),
          if (reroll.free > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                t('quests.reroll_note_free', {'n': reroll.free}),
                key: const ValueKey('quests-reroll-free'),
                textAlign: TextAlign.center,
                style: TextStyle(color: kit.textMuted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuestTile extends StatelessWidget {
  const _QuestTile({required this.quest, required this.track, this.onClaim});

  final QuestRow quest;

  /// `season` or `match`. In the key, because the two tracks are drawn in the
  /// same tree and a duplicate `ValueKey` is a widget-test trap waiting to be
  /// stepped in.
  final String track;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final pct = quest.target <= 0
        ? 0.0
        : (quest.progress / quest.target).clamp(0.0, 1.0);

    // **THE STATE IS THE DESIGN.** The tile was a line of text, a full-width
    // bar and a fraction — one shape for a quest you have not started, one you
    // are halfway through and one with money waiting on it, which is why a
    // season's worth of them read as a chore list. There are three states and
    // they look like three things now: live, READY (the only one anybody has to
    // act on, so it is the only one with colour in the card), and claimed.
    final ready = onClaim != null && !quest.claimed;
    final ink = quest.claimed
        ? kit.textMuted
        : ready
        ? kit.accentBright
        : kit.accent;

    return Card(
      key: ValueKey('quest-$track-${quest.id}'),
      // A claimable quest is the one thing on this sheet with something owed on
      // it. Same surface as the other two and it has to be hunted for.
      color: ready ? kit.accentBright.withValues(alpha: 0.11) : kit.surface,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: ready
              ? kit.accentBright.withValues(alpha: 0.55)
              : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        child: Row(
          // Top-aligned, so the quest, the dial and the state all start on the
          // same line however many lines the ask runs to — see the note on the
          // right-hand column.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // **THE BAR IS A RING, round the thing it describes.** A full-width
            // bar under the text is a second row saying what the fraction beside
            // it already said; wrapped round the quest's own medallion it is the
            // same reading in no extra height, and it leaves the tile one row
            // rather than three.
            _QuestDial(
              pct: pct,
              ink: ink,
              track: kit.surface2,
              claimed: quest.claimed,
              ready: ready,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    quest.text,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: quest.claimed ? kit.textMuted : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${quest.progress.toInt()} / ${quest.target.toInt()}',
                    style: TextStyle(color: kit.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // **THE STATE ON THE QUEST'S OWN LINE, AND WHAT IT PAYS UNDER IT.**
            //
            // "In Play" was centred against the whole tile, so on a two-line
            // quest it floated between the ask and the count and read as a
            // caption for neither — and the reward chip sat down in the left
            // column beside the fraction, which put the money on the row about
            // PROGRESS. Asked for from the couch: the state inline with the
            // quest, and the coins to the right underneath it.
            //
            // One column, right-aligned: what this quest is doing, then what
            // it is worth. The row is `start`-aligned so the first line of
            // each column shares a baseline however many lines the ask takes.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (quest.claimed)
                  Text(
                    t('quests.done'),
                    key: ValueKey('quest-done-$track-${quest.id}'),
                    style: TextStyle(color: kit.textMuted, fontSize: 12),
                  )
                else if (onClaim != null)
                  ElevatedButton(
                    key: ValueKey('quest-claim-$track-${quest.id}'),
                    onPressed: onClaim,
                    child: Text(t('quests.claim')),
                  )
                else
                  Text(
                    quest.completed ? t('quests.done') : t('quests.live'),
                    style: TextStyle(color: kit.textMuted, fontSize: 12),
                  ),
                if (quest.coins > 0) ...[
                  const SizedBox(height: 4),
                  // **WHAT IT PAYS.** The figure is a percentage of one league
                  // win rather than a literal, so it is worth different money
                  // in every division — which is why it has to be shown at all.
                  Opacity(
                    opacity: quest.claimed ? 0.5 : 1,
                    child: _RewardChip(
                      key: ValueKey('quest-reward-$track-${quest.id}'),
                      icon: 'coin',
                      ink: gameGold,
                      label: t('quests.reward_coins', {
                        'n': formatCoins(quest.coins, trim: true),
                      }),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A quest's medallion: how far through it you are, drawn round its own face.
///
/// Three faces for three states, and each is a glyph rather than a string — the
/// catalogues are generated from the JS repo and no new `t()` key can be added
/// from here, which is also why none is needed: a tick, a parcel and a
/// percentage say it in every language.
class _QuestDial extends StatelessWidget {
  const _QuestDial({
    required this.pct,
    required this.ink,
    required this.track,
    required this.claimed,
    required this.ready,
  });

  final double pct;
  final Color ink;
  final Color track;
  final bool claimed;
  final bool ready;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 44,
    height: 44,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: pct,
            strokeWidth: 4,
            backgroundColor: track,
            valueColor: AlwaysStoppedAnimation(ink),
          ),
        ),
        if (claimed)
          Icon(Icons.check, size: 20, color: ink)
        else if (ready)
          // **THE GAME'S OWN GIFT, not the platform's.** A 🎁 is Noto Color
          // Emoji — somebody else's drawing, in somebody else's palette, in the
          // middle of a ring the app painted. Reported from the couch about a
          // won season quest. `gift` is the same mark the daily reward and the
          // shop already use for the same idea.
          GameIcon('gift', size: 18, color: ink)
        else
          Text(
            '${(pct * 100).round()}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    ),
  );
}
