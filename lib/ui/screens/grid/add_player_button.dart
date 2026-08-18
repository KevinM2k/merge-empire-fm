/// The Add Player button.
///
/// The action the game opens on: a fresh save has an empty grid, and without
/// this there is nothing to merge, nobody to field and no way to start.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/scout_signing_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/format.dart';

final signBlockedProvider = savePick<String?>(signBlocked);
final signCostProvider = savePick<int>(scoutCost);
final signIsFreeProvider = savePick<bool>((s) => scoutCost(s) == 0);

/// Why the button is dead, in copy that already ships.
String signBlockedCopy(String reason) => switch (reason) {
  'insufficient_coins' => t('toast.not_enough_coins'),
  'grid_full' => t('grid.player_count'),
  _ => t('settings.comingSoon'),
};

class AddPlayerButton extends ConsumerWidget {
  const AddPlayerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final blocked = ref.watch(signBlockedProvider);
    final cost = ref.watch(signCostProvider);
    final free = ref.watch(signIsFreeProvider);
    final game = ref.read(gameProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            key: const ValueKey('add-player'),
            onPressed: blocked != null ? null : () => game.update(signPlayer),
            icon: const Icon(Icons.person_add, size: 18),
            label: Text(
              // The price rides on the button rather than sitting in a tooltip:
              // it changes with the division and the Academy, and a player
              // deciding whether to sign is deciding whether to spend.
              free
                  ? '${t('players.addPlayer')}  ·  ${t('players.free')}'
                  : '${t('players.addPlayer')}  ·  ${formatCoins(cost)}',
            ),
          ),
        ),
        if (blocked != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              signBlockedCopy(blocked),
              key: const ValueKey('add-player-blocked'),
              style: TextStyle(color: kit.textMuted, fontSize: 11),
            ),
          ),
      ],
    );
  }
}
