/// Every tier of one facility at a glance. Ported from `_openTierLadder` in
/// `ui/screens/ClubScreen.js`.
///
/// **This is where the detail lives**, which is what lets the card stay one
/// height in all ten languages: the card answers "what have I got, what's next",
/// and the whole eight-tier ladder is one tap away on the art or the name.
///
/// It opens on the tier the club is actually on rather than at tier one — with
/// eight rows the current one is usually below the fold on a phone, and a sheet
/// that opens somewhere the player has already been is a sheet they have to
/// scroll before it says anything.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/ui/popups/sheet_header.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/engine/club_asset_engine.dart';
import 'package:merge_empire_fc/engine/club_asset_tiers.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/screens/club/asset_tier_copy.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';

Future<void> showAssetLadderSheet(BuildContext context, String assetKey) =>
    showBottomSheetPopup<void>(
      context,
      heightFraction: 0.82,
      child: AssetLadderSheet(assetKey: assetKey),
    );

class AssetLadderSheet extends ConsumerStatefulWidget {
  const AssetLadderSheet({super.key, required this.assetKey});

  final String assetKey;

  @override
  ConsumerState<AssetLadderSheet> createState() => AssetLadderSheetState();
}

class AssetLadderSheetState extends ConsumerState<AssetLadderSheet> {
  final ScrollController _scroll = ScrollController();

  /// Roughly one row, for the opening scroll. Measured rather than guessed would
  /// mean laying the whole ladder out twice; the rows are near enough uniform
  /// that a row height gets the player to their own tier.
  static const double _rowHeight = 62;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final tier = assetTier(ref.read(gameProvider).state, widget.assetKey);
      // One row ABOVE the current tier, so it is not flush against the heading
      // and the ladder reads as something the club has climbed.
      final to = (tier - 2).clamp(0, maxAssetTier) * _rowHeight;
      _scroll.jumpTo(to.clamp(0.0, _scroll.position.maxScrollExtent));
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final tier = ref.watch(assetTierProvider(widget.assetKey));
    final ladder = assetLadder(widget.assetKey);

    return Column(
      key: ValueKey('asset-ladder-${widget.assetKey}'),
      // Eight tiers is the whole ladder, so the sheet is that tall and no more.
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
          child: Row(
            children: [
              GameIcon(
                assetCategoryIcon[widget.assetKey] ?? 'club',
                size: 20,
                color: assetTierColour(tier),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SheetHeader(
                  title: t('asset.${widget.assetKey}.name'),
                  padding: EdgeInsets.zero,
                ),
              ),
              IconButton(
                key: const ValueKey('asset-ladder-close'),
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: t('common.close'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            t('asset.${widget.assetKey}.hint'),
            style: TextStyle(color: kit.textMuted, fontSize: 12, height: 1.5),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            t('club.upgrade_path').toUpperCase(),
            style: TextStyle(
              color: kit.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Flexible(
          child: ListView.builder(
            controller: _scroll,
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
            itemCount: ladder.length,
            itemBuilder: (context, i) =>
                _LadderRow(entry: ladder[i], at: tier, kit: kit),
          ),
        ),
      ],
    );
  }
}

/// The tier the club is on, watched so the ladder's "NOW" marker follows an
/// investment made while the sheet is open.
///
/// A family rather than one of `savePick`'s: it is asked per facility, and the
/// ladder is the only thing that asks.
final assetTierProvider = Provider.family<int, String>((ref, key) {
  ref.watch(saveRevisionProvider);
  return assetTier(ref.watch(gameProvider).state, key);
});

class _LadderRow extends StatelessWidget {
  const _LadderRow({required this.entry, required this.at, required this.kit});

  final TierEntry entry;

  /// The tier the club is on.
  final int at;
  final KitTheme kit;

  @override
  Widget build(BuildContext context) {
    final reached = at >= entry.tier;
    final isNow = at == entry.tier;
    final ink = reached ? assetTierColour(entry.tier) : kit.border;
    final unlocks = [
      for (final line in entry.unlocks)
        ?unlockLine(line, voice: UnlockVoice.ladder),
    ];

    return Opacity(
      // A tier not yet reached is knocked back rather than hidden: the point of
      // the ladder is seeing where it goes.
      opacity: reached ? 1 : 0.45,
      child: Container(
        key: ValueKey('asset-ladder-row-${entry.tier}'),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        decoration: BoxDecoration(
          border: entry.tier < maxAssetTier
              ? Border(bottom: BorderSide(color: kit.border))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                color: reached ? ink : Colors.transparent,
                border: Border.all(color: ink, width: 1.5),
              ),
              child: Text(
                '${entry.tier}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: reached ? Colors.white : kit.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.stats.map(statText).join(' · '),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  if (unlocks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          for (final unlock in unlocks)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (unlock.icon != null) ...[
                                  GameIcon(
                                    unlock.icon!,
                                    size: 12,
                                    color: kit.accentBright,
                                  ),
                                  const SizedBox(width: 3),
                                ],
                                Text(
                                  unlock.text,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: kit.accentBright,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (isNow)
              Container(
                key: const ValueKey('asset-ladder-now'),
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: kit.accent,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  t('club.ladder.now'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: kit.accentInk,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
