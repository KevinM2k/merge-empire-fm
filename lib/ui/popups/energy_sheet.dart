/// What the HUD's energy `+` opens.
///
/// It emitted `nav:energy` and nothing listened, so it was a button that did
/// nothing — the same class of bug as the cog wired to a stub.
///
/// A bottom sheet, one of the three shapes, rather than a fourth thing. It says
/// where the player stands, when the next pip lands, and what the two routes to
/// more are: a rewarded video (M4's AdMob) or the Shop's energy products (M4's
/// billing). Both are named and dead, as everything else waiting on M4 is.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/engine/energy_engine.dart';
import 'package:merge_empire_fc/engine/gem_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_paid.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/time.dart';

/// Where the player stands on energy.
typedef EnergyStatus = ({int current, int max, int nextPipMs, bool full});

final energyStatusProvider = savePick<EnergyStatus>((s) {
  final energy = s['energy'];
  final currentRaw = energy is Map<String, dynamic> ? energy['current'] : null;
  final current = currentRaw is num ? currentRaw.floor() : 0;
  final max = getEnergyMax(s);
  return (
    current: current,
    max: max,
    nextPipMs: msUntilNextPip(s),
    full: current >= max,
  );
});

Future<void> showEnergySheet(BuildContext context, WidgetRef ref) {
  return showBottomSheetPopup<void>(
    context,
    // Taller since the refill moved onto it: the sheet carries the meter, the
    // countdown, the ad row and now a priced purchase, and at 0.45 the last of
    // those was below the fold on a short phone.
    heightFraction: 0.56,
    child: Consumer(
      builder: (sheetContext, sheetRef, _) {
        final kit = Theme.of(sheetContext).extension<KitTheme>()!;
        final status = sheetRef.watch(energyStatusProvider);

        return ListView(
          key: const ValueKey('energy-sheet'),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              t('shop.section.energy'),
              style: TextStyle(
                color: kit.accentBright,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bolt, color: kit.accent),
                const SizedBox(width: 6),
                Text(
                  '${status.current}/${status.max}',
                  key: const ValueKey('energy-count'),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: kit.accentBright,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                // A full tank has no next pip to wait for, and a countdown to
                // nothing is worse than no countdown.
                status.full
                    ? t('shop.already_ready')
                    : formatDuration(status.nextPipMs),
                key: const ValueKey('energy-next'),
                style: TextStyle(color: kit.textMuted, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              key: const ValueKey('energy-watch-ad'),
              onPressed: null,
              icon: const Icon(Icons.play_circle_outline, size: 18),
              label: Text(
                t('energy.reward.up_to', {
                  'amount': Energy.adReward,
                  'coin': t('shop.section.energy'),
                }),
              ),
            ),
            Center(
              child: Text(
                paidDisabledReason(),
                style: TextStyle(color: kit.textMuted, fontSize: 11),
              ),
            ),
            const SizedBox(height: 12),
            // BUY IT HERE. The refill is a gem item that already exists, is
            // already priced and already works — and the only way to reach it
            // was to close this sheet, land on the Shop's gems shelf, scroll to
            // Boosts and find it. Someone who has opened the energy sheet has
            // already said what they want.
            _RefillButton(sheetContext: sheetContext, sheetRef: sheetRef),
            const SizedBox(height: 6),
            OutlinedButton(
              key: const ValueKey('energy-to-shop'),
              onPressed: () {
                Navigator.of(sheetContext).pop();
                // Where the gems themselves come from, for the case the button
                // above is short of them.
                sheetRef
                    .read(shellControllerProvider.notifier)
                    .deepLinkShop(ShopSection.gems);
              },
              child: Text(t('nav.shop')),
            ),
          ],
        );
      },
    ),
  );
}

/// The energy refill, bought from the sheet that is asking for it.
///
/// Priced on the button and dead with a reason when it cannot be paid for —
/// the same bargain every other purchase in the game makes, rather than a
/// button that fails on the tap.
class _RefillButton extends ConsumerWidget {
  const _RefillButton({required this.sheetContext, required this.sheetRef});

  final BuildContext sheetContext;
  final WidgetRef sheetRef;

  static const String _itemId = 'energy_refill';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final item = getGemItem(_itemId);
    if (item == null) return const SizedBox.shrink();
    final state = ref.watch(gameProvider).state;
    ref.watch(saveRevisionProvider);
    final blocked = gemItemBlocked(state, _itemId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          key: const ValueKey('energy-buy-refill'),
          onPressed: blocked != null
              ? null
              : () {
                  ref.read(gameProvider).update((s) => buyGemItem(s, _itemId));
                  Navigator.of(sheetContext).pop();
                },
          icon: const Icon(Icons.bolt, size: 18),
          label: Text(
            '${t('gem.$_itemId.name')}  ${item.cost}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (blocked != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Center(
              child: Text(
                blocked == 'insufficient_gems'
                    ? t('shop.toast.not_enough_gems')
                    : t('settings.comingSoon'),
                style: TextStyle(color: kit.textMuted, fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }
}
