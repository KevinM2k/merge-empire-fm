/// The button between the fixture list and the match.
///
/// It owns the whole round trip: spend the pip, simulate, push the takeover,
/// commit at full time and pay on dismissal. A screen that wants to offer a
/// match drops one of these in and nothing else.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/match_orchestration.dart';
import 'package:merge_empire_fc/engine/sponsor_engine.dart';
import 'package:merge_empire_fc/engine/transfer_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/match/match_launcher.dart';
import 'package:merge_empire_fc/ui/screens/match/match_screen.dart';
import 'package:merge_empire_fc/ui/screens/season/season_end_button.dart';
import 'package:merge_empire_fc/ui/screens/season/season_end_screen.dart';
import 'package:merge_empire_fc/ui/screens/transfers/sponsor_offer_card.dart';
import 'package:merge_empire_fc/ui/screens/transfers/transfer_offer_card.dart';
import 'package:merge_empire_fc/util/time.dart';

/// Why the button is dead, in copy that already ships.
String matchBlockedCopy(String reason, Map<String, dynamic>? state) =>
    switch (reason) {
      'no_energy' => t('toast.no_energy'),
      'squad_too_small' => t('squad.no_players'),
      'season_over' => t('play.season_over'),
      'cooldown' => t('play.cooldown', {
        'time': state == null
            ? ''
            : formatDuration(matchCooldownRemaining(state)),
      }),
      _ => t('settings.comingSoon'),
    };

final matchBlockedProvider = savePick<String?>(matchStartBlocked);

class PlayMatchButton extends ConsumerWidget {
  const PlayMatchButton({super.key, this.fast = false});

  final bool fast;

  Future<void> _play(BuildContext context, WidgetRef ref) async {
    final game = ref.read(gameProvider);
    final result = game.update(beginMatch);
    if (result == null || !context.mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MatchScreen(
          result: result,
          fast: fast,
          // Full time, with the screen still up: commit the outcome so the
          // table and the season move on.
          onFinished: (r) => game.update((s) => settleMatch(s, r)),
        ),
      ),
    );

    // Dismissed. The coins land now rather than at full time, because the
    // doubling offer lives on the closing screen and paying before it is
    // answered would make the offer meaningless.
    game.update((s) => payMatch(s, result));

    if (!context.mounted) return;
    await _afterMatch(context, ref, result);
  }

  /// What arrives once the result screen is gone.
  ///
  /// The order is the JS's and it matters: a transfer bid takes the slot if
  /// there is one, and only a match with no bid rolls for a sponsor. Two cards
  /// stacked on one dismissal is how the JS ended up with three surfaces for
  /// one question.
  ///
  /// **`maybeGenerateOffer` had no caller at all.** Post-match bids never fired,
  /// which left the idle roll as the only source — and nothing showed that
  /// either, so it timed out after five minutes and the timeout is scored as a
  /// decline. Players were collecting grudges from bids they were never shown.
  Future<void> _afterMatch(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> result,
  ) async {
    final game = ref.read(gameProvider);

    // This match's fresh roll. Null when one was already pending, in which case
    // the pending one is what gets answered.
    game.update(
      (s) => maybeGenerateOffer(
        s,
        opponentRating: (result['opponentRating'] as num?) ?? 55,
      ),
    );

    if (ref.read(pendingOfferProvider) != null) {
      if (!context.mounted) return;
      await showTransferOffer(context, ref);
      // A bid answered is enough for one match.
      return;
    }

    final sponsor = game.state == null
        ? null
        : maybeGenerateSponsorshipOffer(game.state!);
    if (sponsor == null || !context.mounted) return;
    await showSponsorOffer(
      context,
      ref,
      player: sponsor.player,
      company: sponsor.company,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A finished season is not a refusal to explain, it is a different button:
    // the way on is to close the season, and telling the player "no" without
    // offering it is the dead end this replaced.
    if (ref.watch(seasonCompleteProvider)) return const EndSeasonButton();

    final blocked = ref.watch(matchBlockedProvider);
    final reason = blocked == null
        ? null
        : matchBlockedCopy(blocked, ref.read(gameProvider).state);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const ValueKey('play-match'),
            onPressed: blocked != null ? null : () => _play(context, ref),
            child: Text(t('nav.play')),
          ),
        ),
        if (reason != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              reason,
              key: const ValueKey('play-blocked'),
              style: const TextStyle(fontSize: 11),
            ),
          ),
      ],
    );
  }
}
