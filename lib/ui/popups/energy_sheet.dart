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
    heightFraction: 0.45,
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
            OutlinedButton(
              key: const ValueKey('energy-to-shop'),
              onPressed: () {
                Navigator.of(sheetContext).pop();
                // The Shop's energy products are real and priced; only their
                // buy buttons wait on M4.
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
