/// The way out of a finished season.
///
/// Sits where the Play button would be. `endSeason` settles everything in one
/// call — the table, the movement, the payout, the ageing, the next campaign —
/// and the takeover reports what it did.
///
/// The season number is captured BEFORE the call, because `endSeason` rolls
/// `seasonCount` on as part of its work and the summary is about the season that
/// just finished, not the one starting.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/season_end.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/season/season_end_screen.dart';

class EndSeasonButton extends ConsumerWidget {
  const EndSeasonButton({super.key});

  Future<void> _end(BuildContext context, WidgetRef ref) async {
    final game = ref.read(gameProvider);
    final finished = ref.read(seasonJustEndedProvider);
    final outcome = game.update(endSeason);
    if (!context.mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (routeContext) => SeasonEndScreen(
          outcome: outcome,
          seasonNumber: finished,
          onContinue: () => Navigator.of(routeContext).maybePop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        key: const ValueKey('end-season'),
        onPressed: () => _end(context, ref),
        child: Text(t('season.end.title', {'n': ref.watch(seasonJustEndedProvider)})),
      ),
    );
  }
}
