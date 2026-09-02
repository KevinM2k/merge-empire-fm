/// This fixture's three objectives, ON the next-match card. Ported from
/// `_matchQuestsHtml` in `ui/screens/LeagueScreen.js`.
///
/// **They belong here, not in the Quests sheet.** The port had them filed under
/// the season track behind the burger, which is the one place they are no use:
/// a match quest is an instruction for the game you are about to press Play on,
/// and it has to be readable at the moment of pressing it. They were a sibling
/// UNDER the card for a while in the JS too — that read as two unrelated things
/// stacked, when they are three objectives for the very game the card announces.
///
/// **Nothing here is claimable.** A match quest pays itself at full time, so a
/// row with a button on it would be a lie. What the rows carry instead is the
/// price: one figure each, and the track's total beside the heading — which is
/// the answer to the question the three rows do not between them answer, whether
/// the block is worth reading before kick-off at all.
///
/// **It collapses**, and the heading keeps the total when it does. "Worth 3,600"
/// is a reason to open it; a bare "MATCH QUESTS" with a chevron is not.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/ui/theme/glass.dart';
import 'package:merge_empire_fc/data/quests.dart';
import 'package:merge_empire_fc/engine/quest_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/util/format.dart';

/// One row: what is asked, and what it pays.
typedef MatchQuestRow = ({
  String id,
  String icon,
  String text,
  int reward,
  num progress,
  num target,
  bool completed,
});

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num _num(Object? v) => v is num ? v : 0;

final matchQuestRowsProvider = savePick<List<MatchQuestRow>>((s) {
  final active = _map(ensureQuests(s)['match'])?['active'];
  if (active is! List) return const [];
  final out = <MatchQuestRow>[];
  for (final entry in active) {
    final inst = _map(entry);
    final id = inst?['id'];
    if (id is! String) continue;
    final def = getQuest(id);
    final target = _num(inst!['target']);
    out.add((
      id: id,
      // The data file stays UI-free and names an icon key; this resolves it.
      icon: def?.icon ?? 'target',
      text: t('quest.$id', {'n': target}),
      reward: def == null ? 0 : questRewardCoins(s, def.reward.coins),
      progress: _num(inst['progress']),
      target: target,
      completed: inst['completed'] == true,
    ));
  }
  return out;
});

/// What the whole track is worth. Summed from the same figures the rows print,
/// so the heading can never disagree with the lines under it.
final matchQuestTotalProvider = savePick<int>((s) {
  var total = 0;
  final active = _map(ensureQuests(s)['match'])?['active'];
  if (active is! List) return 0;
  for (final entry in active) {
    final id = _map(entry)?['id'];
    if (id is! String) continue;
    final def = getQuest(id);
    if (def != null) total += questRewardCoins(s, def.reward.coins);
  }
  return total;
});

/// **This block only READS.** The track is rolled where the fixture actually
/// advances — at boot, at `settleMatch`, and on the way into a match — and never
/// from here. Rolling on mount went through `update`, `update` queues a debounced
/// save, and the card rebuilds on every save revision: so merely looking at the
/// home screen wrote the whole game state to disk. The JS carries the same
/// warning about the same call.
class MatchQuestsBlock extends ConsumerStatefulWidget {
  const MatchQuestsBlock({super.key});

  @override
  ConsumerState<MatchQuestsBlock> createState() => _MatchQuestsBlockState();
}

class _MatchQuestsBlockState extends ConsumerState<MatchQuestsBlock> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final rows = ref.watch(matchQuestRowsProvider);
    final total = ref.watch(matchQuestTotalProvider);
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      key: const ValueKey('match-quests'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        // A RECESS, not a black box. On the old near-opaque pane a 20% black wash
        // read as depth; on glass at half opacity it is a dark slab punched
        // through the middle of the card, and the sky behind stops showing where
        // the block is. Same fix as the ATK/DEF well: a whisper, and let the
        // border do the separating.
        color: glassInk(context).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: glassInk(context).withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            key: const ValueKey('match-quests-toggle'),
            onTap: () => setState(() => _collapsed = !_collapsed),
            child: Row(
              children: [
                GameIcon('target', size: 11, color: kit.accentBright),
                const SizedBox(width: 5),
                // **NOTHING IN THIS ROW ELLIPSISES ANY MORE**, and it took two
                // changes rather than one.
                //
                // The heading used to flex and be cut to "MATCH QUEST…", which
                // was the least-bad answer while three things were competing for
                // a 320px row: a heading, the words "TOTAL REWARD", and the
                // figure. Reported straight off the screen.
                //
                // First, the LABEL goes. Every quest row below shows its own
                // payout as a coin and a number with no words on it, so a coin
                // and a number at the end of the header needs none either.
                //
                // Second, what room is left is not enough on its own: "MISIONES
                // DEL PARTIDO" still runs 23px over at 260, so the heading has to
                // give somewhere. It WRAPS. That is the same call `_QuestTile`
                // already makes about the quest text — this is a column that can
                // grow a line, so there is nothing to protect by clipping it, and
                // a wrapped title beats a cut one.
                // **EXPANDED, not Flexible-plus-Spacer, and that pairing is
                // the rest of why the total sat short.** `Flexible` is a LOOSE
                // fit: the heading is given a share of the free space and then
                // sizes to its own content, so whatever it does not use is
                // dead space inside its own slot — space the `Spacer` after it
                // never sees. On a short heading that is most of the row, and
                // the figure at the end stopped sixty points from the edge
                // that every quest reward below it is flush against.
                // **THE CHEVRON GOES WITH THE HEADING, and the total goes to
                // the EDGE.** The chevron used to sit after the figure, which
                // pushed the header's total a chevron's width in from the
                // right while every quest row below it put its own payout hard
                // against that edge — so the one figure that is the SUM of that
                // column did not line up with it. Reported as the total needing
                // to move further right; there was nowhere for it to go until
                // the chevron moved. It reads as well or better beside the
                // heading anyway: a disclosure arrow belongs to the thing it
                // opens.
                //
                // **EXPANDED, not Flexible-plus-Spacer, and that pairing is the
                // rest of why the total sat short.** `Flexible` is a LOOSE fit:
                // the heading is given a share of the free space and then sizes
                // to its own content, so whatever it does not use is dead space
                // inside its own slot — space the `Spacer` after it never sees.
                // On a short heading that is most of the row.
                //
                // The pair goes INSIDE that expanded slot so the arrow hugs the
                // words rather than floating out beside the figure, and the
                // slack falls between them and the total.
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          t('quests.match').toUpperCase(),
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: glassMuted(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      // Down when there is more to see, right when it is shut —
                      // the chevron is the same glyph rotated, so the two
                      // states cannot drift apart as shapes.
                      AnimatedRotation(
                        turns: _collapsed ? 0 : 0.25,
                        duration: const Duration(milliseconds: 160),
                        child: GameIcon(
                          'chevron',
                          size: 12,
                          color: glassMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (total > 0) ...[
                  const CoinIcon(size: 11, onGlass: true),
                  const SizedBox(width: 2),
                  Text(
                    '+${formatCoins(total)}',
                    key: const ValueKey('match-quests-header-total'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      // GOLD, not the kit accent. A coin figure in green asks
                      // the player to work out which currency it is, and the
                      // glyph beside it is already gold — so the number was the
                      // one part of the pair that did not say "coins".
                      //
                      // **ON GLASS**, which in light mode is the difference
                      // between actual yellow and the bronze this read as: the
                      // backdrop here is grass and sky, not paper, and the
                      // contrast comes from a dark backing instead of from the
                      // hue. See [coinFigureShadows].
                      color: coinFigureInk(context, onGlass: true),
                      shadows: coinFigureShadows(context, onGlass: true),
                    ),
                  ),
                ],
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _collapsed
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                for (final row in rows) _QuestTile(row: row),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One quest per row: glyph → ask → reward, matching the season panel.
class _QuestTile extends StatelessWidget {
  const _QuestTile({required this.row});

  final MatchQuestRow row;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    // **THE PANE'S OWN MUTED INK, not the page's full-strength one.**
    // `colorScheme.onSurface` is near-black — rgb(25, 29, 23) in light mode —
    // while the club's asset hints, which are the same KIND of line (a
    // sentence saying what a thing asks of you), are `kit.textMuted` at
    // rgb(91, 97, 107). Reported from the couch: the training-ground copy is
    // the colour that reads right and the match quests look darker than it.
    //
    // `glassMuted` is that same tone arrived at the glass way — `glassText` at
    // 66% over a pane lands within a few points of `kit.textMuted`, which is
    // why it is the right answer here rather than the kit colour: this text is
    // on a pane over the pitch, and the pane is what the alpha is measured
    // against. Size and weight carry the hierarchy against the fraction beside
    // it, which is the same tone at 10.5/w900.
    final ink = glassMuted(context);
    final done = row.completed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        key: ValueKey('match-quest-${row.id}'),
        children: [
          // A completed quest wears the tick rather than its own glyph — it has
          // already paid, and the ask no longer matters.
          GameIcon(
            done ? 'check' : row.icon,
            size: 15,
            color: done ? kit.accentBright : glassMuted(context),
          ),
          const SizedBox(width: 6),
          Expanded(
            // WRAPS, and is not cut off. The ask is the whole content of the
            // row — "Win by two goals or more" truncated to "Win by two goals
            // or…" is a different instruction — and the block is a column that
            // can grow a line, so there is nothing to protect by clipping it.
            child: Text(
              row.text,
              softWrap: true,
              // **THE SAME 11 THE CLUB'S ASSET HINTS ARE SET IN.** This
              // block and those tiles are the same kind of line — a sentence
              // explaining what a thing does — and at 10.5 against their 11
              // the one on the busier card was the smaller. Reported from the
              // couch, naming both.
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: done ? kit.accentBright : ink,
              ),
            ),
          ),
          // Progress, when there is any to show. A quest at 1 of 3 is a
          // different thing to read than one at 0.
          if (row.target > 1 && !done) ...[
            const SizedBox(width: 5),
            Text(
              '${row.progress.toInt()}/${row.target.toInt()}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: glassMuted(context),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
          if (row.reward > 0) ...[
            const SizedBox(width: 6),
            const CoinIcon(size: 10, onGlass: true),
            const SizedBox(width: 2),
            Text(
              formatCoins(row.reward),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: coinFigureInk(context, onGlass: true),
                shadows: coinFigureShadows(context, onGlass: true),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
