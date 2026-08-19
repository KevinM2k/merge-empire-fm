/// The Add Player button, and the batch it signs.
///
/// The action the game opens on: a fresh save has an empty grid, and without
/// this there is nothing to merge, nobody to field and no way to start.
///
/// **×1 / ×2 / ×4 sits beside it**, and the sizes offered are only the ones
/// this save can pay for and house. Showing a ×4 that runs out of coins on the
/// third card is the trap that avoids — by the time the player finds out, they
/// have already tapped.
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

/// What a tap will buy, and what the player could pick instead.
final scoutBatchProvider = savePick<int>(effectiveScoutBatch);
final scoutBatchSizesProvider = savePick<String>(
  // A String, not a List: `savePick` compares with `==` and a fresh list every
  // rebuild would never match itself.
  (s) => availableScoutBatchSizes(s).join(','),
);

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

    final batch = ref.watch(scoutBatchProvider);
    final sizes = [
      for (final n in ref.watch(scoutBatchSizesProvider).split(','))
        int.tryParse(n) ?? 1,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                key: const ValueKey('add-player'),
                onPressed: blocked != null
                    ? null
                    : () => game.update((s) => signPlayers(s, batch)),
                icon: const Icon(Icons.person_add, size: 18),
                label: Text(
                  // The price rides on the button rather than sitting in a
                  // tooltip: it changes with the division and the Academy, and
                  // a player deciding whether to sign is deciding whether to
                  // spend. A batch quotes the WHOLE spend, not the unit — the
                  // number on the button is what leaves the wallet.
                  free
                      ? '${t('players.addPlayer')}  ·  ${t('players.free')}'
                      : '${t('players.addPlayer')}  ·  ${formatCoins(cost * batch)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Only shown when there is a choice to make.
            if (sizes.length > 1) ...[
              const SizedBox(width: 8),
              Semantics(
                label: t('players.batch_aria'),
                child: ToggleButtons(
                  key: const ValueKey('scout-batch'),
                  isSelected: [for (final n in sizes) n == batch],
                  constraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 36,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  onPressed: (i) =>
                      game.update((s) => setScoutBatch(s, sizes[i])),
                  children: [
                    for (final n in sizes)
                      Text(
                        '×$n',
                        key: ValueKey('scout-batch-$n'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
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
