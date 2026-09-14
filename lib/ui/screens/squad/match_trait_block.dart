/// The second trait slot — locked behind a gem, spun for coins, and only ever
/// doing anything DURING a match.
///
/// **The same reel as the first slot, not a copy of it.** `TraitReel` is the
/// machine `TraitBlock` spins; this block hands it a different pool and a
/// different answer and pays a different way. A second spinner would have been
/// a spec change, and within a week the two would have disagreed about how
/// long a spin is.
///
/// What is different here, and why:
///
/// - **The gate is a gem, per player.** A full XI is eleven gems — about five
///   weeks of the day-7 daily, or a pack — which is what makes the slot a
///   decision about WHICH player rather than a box everybody ticks. The roll
///   itself is coins, through the first slot's own tier-scaled cost: the gem
///   bought the slot, not the spins.
/// - **There is no `none` in this pool**, so a roll cannot lose. The gamble is
///   which condition you get, not whether you get one.
/// - **The sheet's rating does not move**, because a match trait only exists
///   inside a match — so there is no `TraitHold` to thread through the sheet.
///   The block holds what it was showing until the reels stop, on its own.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/match_traits.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/match_trait_engine.dart';
import 'package:merge_empire_fc/engine/negotiation_engine.dart' show findOurCard;
import 'package:merge_empire_fc/engine/trait_engine.dart' show traitRollCost;
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/popups/feature_unlock.dart';
import 'package:merge_empire_fc/ui/screens/squad/detail_controls.dart';
import 'package:merge_empire_fc/ui/screens/squad/trait_reel.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/trait_copy.dart';
import 'package:merge_empire_fc/util/format.dart';

class MatchTraitBlock extends ConsumerStatefulWidget {
  const MatchTraitBlock({
    super.key,
    required this.instanceId,
    required this.def,
  });

  final String instanceId;
  final PlayerDef def;

  @override
  ConsumerState<MatchTraitBlock> createState() => MatchTraitBlockState();
}

class MatchTraitBlockState extends ConsumerState<MatchTraitBlock> {
  final GlobalKey<TraitReelState> _reel = GlobalKey<TraitReelState>();

  bool _spinning = false;

  /// Test seam.
  bool get spinning => _spinning;

  /// What the badge shows while the reels turn — the trait he HAD, because the
  /// roll writes the save before the reels move and the badge must not answer
  /// a second and a half early. Null when nothing is spinning.
  Map<String, dynamic>? _shown;

  void _unlock() {
    ref.read(gameProvider).update((s) => unlockMatchSlot(s, widget.instanceId));
  }

  Future<void> _roll() async {
    if (_spinning) return;
    final game = ref.read(gameProvider);
    final was = matchTraitOf(findOurCard(game.state, widget.instanceId));
    final result = game.update((s) => rollMatchTraitForCard(s, widget.instanceId));
    final roll = result.roll;
    if (!result.ok || roll == null) return;
    final landing = matchTraitList.indexWhere((t) => t.id == roll.id);
    if (landing < 0) return;
    final reel = _reel.currentState;
    if (reel == null) return;

    // **Paid and written first**, then shown — see the header.
    setState(() {
      _spinning = true;
      _shown = was ?? const <String, dynamic>{};
    });
    await reel.spinTo(nameIndex: landing, levelRow: (roll.level - 1).clamp(0, 2));
    if (!mounted) return;
    setState(() {
      _spinning = false;
      _shown = null;
    });
    // Always green: there is no losing roll in this pool.
    await reel.flashAnswer(const Color(0xFF00B45A));
    if (!mounted) return;

    final trait = getMatchTrait(roll.id);
    if (trait == null) return;
    await showFeatureUnlock(
      context,
      title: matchTraitTitle({'id': roll.id, 'level': roll.level}),
      subtitle: matchTraitDesc(trait),
      icon: Text(trait.icon, style: const TextStyle(fontSize: 44)),
      accent: Theme.of(context).extension<KitTheme>()!.accentBright,
      starCount: roll.level.clamp(1, 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final card = findOurCard(ref.watch(gameProvider).state, widget.instanceId);
    final open = hasMatchSlot(card);
    final gems = ref.watch(gemsProvider);
    final coins = ref.watch(coinsProvider);
    final cost = traitRollCost(widget.def);

    // Mid-spin this is what he had, not what he just won.
    final shown = _shown ?? matchTraitOf(card);
    final instance = shown == null || shown.isEmpty ? null : shown;
    final held = getMatchTrait(instance?['id'] as String?);
    final lit = open && held != null;

    return Container(
      key: const ValueKey('detail-matchtrait'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // The first slot's rule: a card that HAS one wears the accent, one
        // that does not stays quiet. A LOCKED slot is quieter still.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: lit
              ? [
                  Color.alphaBlend(kit.accent.withValues(alpha: 0.16), kit.surface),
                  kit.surface,
                ]
              : [kit.surface2, kit.surface2],
        ),
        border: Border.all(
          color: lit ? kit.accent : kit.border,
          width: lit ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t('squad.matchtrait').toUpperCase(),
            style: TextStyle(
              color: lit ? kit.accentBright : kit.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          if (!open) ...[
            Row(
              key: const ValueKey('detail-matchtrait-locked'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TraitDisc(
                  glyph: '🔒',
                  colour: kit.textMuted,
                  fill: kit.surface2,
                  levelKey: const ValueKey('detail-matchtrait-level'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t('squad.detail.matchslot.locked'),
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: kit.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            HeroPill(
              buttonKey: const ValueKey('matchslot-unlock'),
              glyph: 'gem',
              label: t('squad.detail.matchslot.unlock', {
                'gems': '$matchSlotGemCost',
              }),
              gold: true,
              onTap: gems >= matchSlotGemCost ? _unlock : null,
            ),
            if (gems < matchSlotGemCost)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  t('squad.detail.matchslot.need_gem'),
                  key: const ValueKey('matchslot-blocked'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: kit.textMuted),
                ),
              ),
          ] else ...[
            Row(
              key: const ValueKey('detail-matchtrait-label'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TraitDisc(
                  glyph: held?.icon ?? '?',
                  colour: held == null ? kit.textMuted : kit.accent,
                  fill: held == null
                      ? kit.surface2
                      : kit.accent.withValues(alpha: 0.18),
                  level: switch ((instance?['level'] as num?)?.toInt() ?? 0) {
                    final l when l > 0 => romanLevels[l.clamp(1, 3) - 1],
                    _ => null,
                  },
                  levelInk: kit.accentInk,
                  levelKey: const ValueKey('detail-matchtrait-level'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: held == null
                      ? Text(
                          t('matchtrait.none'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: kit.textMuted,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              matchTraitTitle(instance),
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                                color: kit.accentBright,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              matchTraitDesc(held),
                              key: const ValueKey('detail-matchtrait-desc'),
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: kit.textMuted,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TraitReel(
              key: _reel,
              keyPrefix: 'matchtrait-reel',
              names: [
                for (final trait in matchTraitList)
                  Text(
                    '${trait.icon} ${matchTraitName(trait)}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
              initialName: _initialName(card),
              initialLevel: _initialLevel(card),
            ),
            const SizedBox(height: 12),
            HeroPill(
              buttonKey: const ValueKey('detail-matchtrait-roll'),
              glyph: 'star',
              label: t('game.trait.cost', {'cost': formatCoins(cost)}),
              gold: true,
              onTap: _spinning || coins < cost ? null : _roll,
            ),
            if (coins < cost)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  t('game.trait.need_coins', {'cost': formatCoins(cost)}),
                  key: const ValueKey('detail-matchtrait-blocked'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: kit.textMuted),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Where the reels start: on what the card already has, or the top of the
  /// pool and the dash for an empty slot. Read once, when the reel is built.
  int _initialName(CardInstance? card) {
    final id = matchTraitOf(card)?['id'] as String?;
    final at = matchTraitList.indexWhere((t) => t.id == id);
    return at < 0 ? 0 : at;
  }

  int _initialLevel(CardInstance? card) {
    final level = (matchTraitOf(card)?['level'] as num?)?.toInt();
    return level == null ? noneRow : (level - 1).clamp(0, 2);
  }
}
