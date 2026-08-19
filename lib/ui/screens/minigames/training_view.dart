/// The list of drills, shown in the Training sheet.
///
/// It was a stub saying "coming soon" while the Club's Training Ground was
/// busy unlocking games it pointed at — two dangling references at once.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/minigames/minigames_providers.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/ui/screens/minigames/boot_room_screen.dart';
import 'package:merge_empire_fc/ui/screens/minigames/penalty_screen.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/time.dart';

class TrainingView extends ConsumerWidget {
  const TrainingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final games = ref.watch(miniGamesProvider);

    return ListView(
      key: const ValueKey('training-view'),
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          t('mg.drills'),
          style: TextStyle(color: kit.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 8),
        for (final game in games) _GameRow(game: game),
      ],
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({required this.game});

  final MiniGameRow game;

  /// Why this row cannot be tapped, or null when it can.
  ///
  /// Three different noes, and they mean different things: not unlocked yet,
  /// unlocked but resting, and unlocked but not built here yet. Collapsing them
  /// into one grey row would tell the player nothing about which.
  String? get _reason {
    if (!game.unlocked) return t('club.minigame_unlocked');
    if (!game.playable) return t('settings.comingSoon');
    if (!game.ready) return t('play.cooldown', {'time': formatDuration(game.waitMs)});
    return null;
  }

  void _open(BuildContext context) {
    final screen = switch (game.kind) {
      MiniGameKind.bootRoom => const BootRoomScreen(),
      _ => const PenaltyScreen(),
    };
    Navigator.of(context).push<void>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final reason = _reason;

    return Card(
      key: ValueKey('training-${game.kind}'),
      color: kit.surface,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          Icons.sports_soccer,
          color: reason == null ? kit.accent : kit.textMuted,
        ),
        title: Text(t(game.titleKey)),
        subtitle: reason == null
            ? null
            : Text(reason, style: TextStyle(color: kit.textMuted, fontSize: 11)),
        trailing: reason == null ? const Icon(Icons.play_arrow) : null,
        enabled: reason == null,
        onTap: reason != null ? null : () => _open(context),
      ),
    );
  }
}
