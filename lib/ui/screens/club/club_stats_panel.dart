/// What the club has built ITSELF into, at the bottom of the Club screen.
/// Ported from `_renderStats` and `_showStatHint` in `ui/screens/ClubScreen.js`.
///
/// **The cards say what each facility gives; this says what they add up to.**
/// Seven facilities at eight tiers each is a lot of arithmetic to do in your
/// head, and the one question a manager actually has — "what is all this
/// worth?" — had no answer anywhere in the port. Every figure here is the same
/// gate function the game runs on, so the panel cannot claim a multiplier the
/// engine does not apply.
///
/// Each row explains itself on a tap. The hints are written and shipped
/// (`club.stats.*_hint`) and were unreachable.
///
/// Before the first build it is one line — `club.empty` — rather than seven rows
/// of ×1.00, which would read as a club that has done something.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart'
    show semanticInk;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/engine/club_asset_engine.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';

/// One line of the readout.
typedef ClubStat = ({
  String key,
  String label,
  String value,
  String hint,
  String icon,
  Color ink,
});

/// Everything the club's facilities are worth right now.
///
/// A record per row rather than a widget, so the whole panel is testable without
/// a pump and the numbers can be checked against the engines directly.
final clubStatsProvider = savePick<List<ClubStat>>((s) {
  final assets = s['clubAssets'] as Map<String, dynamic>?;

  // **THE FRACTIONAL TIER, and the ENGINE'S OWN FUNCTIONS.** Two faults, one
  // cause: this panel read the whole rung and then re-derived the arithmetic
  // locally — `_atMost(0.40, 0.05 * tier)` beside a `merchIncomeMultiplier`
  // that says exactly that. The engine has paid these per tap since
  // `fractionalAssetTier` went in, so both copies understated what the club
  // actually has, and the panel whose whole job is "what is all this worth?"
  // was the one answering low.
  double live(String key) => fractionalAssetTier(assets, key);

  final cooldownCut = 1 - trainingCooldownMult(live(AssetCategory.training));
  final income = merchIncomeMultiplier(live(AssetCategory.merch));
  // Boosts and season left null: this row is what the FACILITIES are worth, not
  // what a TV deal is adding on top of them this month.
  final matchRev = computeMatchRevenueMultiplier(assets, null, null);
  final minigameCoins = mediaPayoutMult(live(AssetCategory.media));
  final injury = 1 - getInjuryRecoveryMult(s);
  final fatigue = 1 - sponsorStaminaMult(assets);
  final scoutCut = academyScoutDiscount(live(AssetCategory.academy));
  final squad = getMaxPlayers(s);
  final homeAdv = homeAdvantageDisplayFor(
    // Rating POINTS, so the rung and not the funding — see `assetStatsAt`.
    isAssetOwned(s, AssetCategory.fanzone)
        ? assetTier(s, AssetCategory.fanzone)
        : 0,
  );

  return [
    (
      key: 'income',
      label: t('club.stats.income'),
      value: '×${income.toStringAsFixed(2)}',
      hint: t('club.stats.income_hint'),
      icon: 'bag',
      ink: const Color(0xFFFFD700),
    ),
    (
      key: 'matchRev',
      label: t('club.stats.matchRev'),
      value: '×${matchRev.toStringAsFixed(2)}',
      hint: t('club.stats.matchRev_hint'),
      icon: 'club',
      ink: const Color(0xFF76E876),
    ),
    (
      key: 'cooldown',
      label: t('club.stats.cooldown'),
      value: '-${_pct(cooldownCut * 100)}%',
      hint: t('club.stats.cooldown_hint'),
      icon: 'dumbbell',
      ink: const Color(0xFF4ADE80),
    ),
    (
      key: 'trainingCoins',
      label: t('club.stats.trainingCoins'),
      value: '×${minigameCoins.toStringAsFixed(2)}',
      hint: t('club.stats.trainingCoins_hint'),
      icon: 'tv',
      ink: const Color(0xFF7FD4FF),
    ),
    (
      key: 'condition',
      label: t('club.stats.condition'),
      // Two halves of one thing, which is why this row is the documented
      // exception to "one number per facility".
      value:
          '-${(injury * 100).round()}% · '
          '-${(fatigue * 100).round()}%',
      hint: t('club.stats.condition_hint'),
      icon: 'handshake',
      ink: const Color(0xFFF87171),
    ),
    (
      key: 'scoutCost',
      label: t('club.stats.scoutCost'),
      value: scoutCut > 0
          ? '-${(scoutCut * 100).round()}% · $squad max'
          : '$squad max',
      hint: t('club.stats.scoutCost_hint'),
      icon: 'userAdd',
      ink: const Color(0xFFA78BFA),
    ),
    (
      key: 'homeAdv',
      label: t('club.stats.homeAdv'),
      value: '+$homeAdv',
      hint: t('club.stats.homeAdv_hint'),
      icon: 'megaphone',
      ink: const Color(0xFFFB923C),
    ),
  ];
});

/// Whether anything has been built at all.
final anyAssetOwnedProvider = savePick<bool>(
  (s) => AssetCategory.all.any((k) => isAssetOwned(s, k)),
);


/// One decimal place, with a trailing `.0` dropped — Training's -7.5% is why the
/// decimal is kept at all.
String _pct(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

class ClubStatsPanel extends ConsumerWidget {
  const ClubStatsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    if (!ref.watch(anyAssetOwnedProvider)) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          t('club.empty'),
          key: const ValueKey('club-stats-empty'),
          style: TextStyle(color: kit.textMuted, fontSize: 13),
        ),
      );
    }

    final stats = ref.watch(clubStatsProvider);
    return Container(
      key: const ValueKey('club-stats'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: kit.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kit.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < stats.length; i++)
            _StatRow(stat: stats[i], last: i == stats.length - 1, kit: kit),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.stat, required this.last, required this.kit});

  final ClubStat stat;
  final bool last;
  final KitTheme kit;

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('club-stat-${stat.key}'),
    onTap: () => showDialog<void>(
      context: context,
      builder: (_) => _HintCard(stat: stat),
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: kit.border)),
      ),
      child: Row(
        children: [
          GameIcon(stat.icon, size: 13, color: semanticInk(context, stat.ink)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              stat.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: kit.textMuted, fontSize: 13),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.info_outline,
            size: 12,
            color: kit.textMuted.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          Text(
            stat.value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.stat});

  final ClubStat stat;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return AlertDialog(
      key: ValueKey('club-stat-hint-${stat.key}'),
      backgroundColor: kit.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: kit.border),
      ),
      title: Row(
        children: [
          GameIcon(stat.icon, size: 17, color: semanticInk(context, stat.ink)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              stat.label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: Text(
        stat.hint,
        style: TextStyle(color: kit.textMuted, fontSize: 13, height: 1.6),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(t('common.got_it')),
          ),
        ),
      ],
    );
  }
}
