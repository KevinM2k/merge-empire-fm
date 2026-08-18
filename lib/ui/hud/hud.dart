/// The floating resource bar.
///
/// It is not a bar: the JS removed the header background so the scene shows
/// through, and each stat is its own chip. Every value comes off a derived
/// provider, so a coin landing rebuilds the coin label and nothing else.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/energy_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/hud/coin_counter.dart';
import 'package:merge_empire_fc/ui/hud/hud_chip.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/shell/shell_quick_nav.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

/// The pip cap, which the Energy Director upgrade raises from 10 to 15. Reading
/// it rather than hardcoding 10 is what stops an upgraded player seeing "15/10".
final energyMaxProvider = savePick<int>(getEnergyMax);

class Hud extends ConsumerWidget {
  const Hud({super.key, this.onSettings});

  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final shell = ref.read(shellControllerProvider.notifier);
    final valueStyle = TextStyle(
      color: kit.accentBright,
      fontWeight: FontWeight.w600,
      fontSize: 13,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const QuickNavButton(),
          HudChip(
            key: const ValueKey('hud-coins'),
            icon: Icons.monetization_on,
            semanticLabel: t('hud.aria.income_breakdown'),
            trailing: HudPlus(
              key: const ValueKey('hud-coins-plus'),
              label: t('nav.shop'),
              onTap: () => shell.deepLinkShop(ShopSection.coins),
            ),
            child: CoinCounter(value: ref.watch(coinsProvider), style: valueStyle),
          ),
          const SizedBox(width: 6),
          HudChip(
            key: const ValueKey('hud-energy'),
            icon: Icons.bolt,
            semanticLabel: t('hud.aria.energy'),
            trailing: HudPlus(
              key: const ValueKey('hud-energy-plus'),
              label: t('hud.aria.energy'),
              // The energy popup owns what happens next; the HUD only says the
              // player asked for it.
              onTap: () => emit('nav:energy'),
            ),
            child: Text(
              '${ref.watch(energyProvider).floor()}/${ref.watch(energyMaxProvider)}',
              style: valueStyle,
            ),
          ),
          const SizedBox(width: 6),
          HudChip(
            key: const ValueKey('hud-gems'),
            icon: Icons.diamond,
            semanticLabel: t('shop.section.gems'),
            // No + of its own: the whole chip deep-links, which keeps a third
            // resource from widening the row by another mini-badge.
            onTap: () => shell.deepLinkShop(ShopSection.gems),
            child: Text('${ref.watch(gemsProvider)}', style: valueStyle),
          ),
          const SizedBox(width: 6),
          HudChip(
            key: const ValueKey('hud-cog'),
            icon: Icons.settings,
            semanticLabel: t('hud.aria.settings'),
            onTap: onSettings,
            child: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
