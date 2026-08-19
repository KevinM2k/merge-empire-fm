/// The button between the fixture list and the match.
///
/// It owns the whole round trip: spend the pip, simulate, push the takeover,
/// commit at full time and pay on dismissal. A screen that wants to offer a
/// match drops one of these in and nothing else.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/cup_engine.dart';
import 'package:merge_empire_fc/engine/match_orchestration.dart';
import 'package:merge_empire_fc/engine/sponsor_engine.dart';
import 'package:merge_empire_fc/engine/transfer_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/match/cup_launcher.dart';
import 'package:merge_empire_fc/ui/screens/match/match_launcher.dart';
import 'package:merge_empire_fc/ui/screens/match/match_screen.dart';
import 'package:merge_empire_fc/ui/screens/season/season_end_button.dart';
import 'package:merge_empire_fc/ui/screens/season/season_end_screen.dart';
import 'package:merge_empire_fc/ui/screens/match/cup_sponsor_offer.dart';
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

/// The round a due cup tie belongs to, or null when the next match is a league
/// one. A String rather than the record, because `savePick` compares with `==`
/// and the cup object is not what the button needs.
final cupRoundProvider = savePick<String?>((s) => nextCupRound(s)?.roundName);

class PlayMatchButton extends ConsumerWidget {
  const PlayMatchButton({super.key, this.fast = false});

  final bool fast;

  Future<void> _play(BuildContext context, WidgetRef ref) async {
    final game = ref.read(gameProvider);
    // A cup tie takes precedence when one is due. Cups sit BETWEEN league games,
    // so this does not cost the league a fixture — it inserts a match.
    if (ref.read(cupRoundProvider) != null) {
      await _playCup(context, ref);
      return;
    }

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

  /// The same round trip for a cup tie.
  ///
  /// Two differences, both the engine's: the prize is paid by `commitCupRound` at
  /// full time rather than deferred — a cup has no doubling offer — and a win can
  /// drop a sponsor, which is offered once the screen is gone.
  Future<void> _playCup(BuildContext context, WidgetRef ref) async {
    final game = ref.read(gameProvider);
    final tie = game.update(beginCupRound);
    if (tie == null || !context.mounted) return;

    CupSponsorDrop? drop;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MatchScreen(
          result: tie.result,
          fast: fast,
          onFinished: (_) => drop = game.update((s) => settleCupRound(s, tie)),
        ),
      ),
    );

    // The cooldown starts once the player is back on the Play screen rather than
    // at the final whistle — `commitCupRound` stamps it too, but only as a floor.
    game.update(startMatchCooldown);
    if (!context.mounted) return;

    final sponsor = drop;
    if (sponsor != null) await showCupSponsorOffer(context, ref, sponsor);
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

    // A due cup tie renames the button, because it is a different match: the
    // round is the headline, and a player who taps Play expecting a league game
    // and gets a semi-final has been ambushed by their own fixture list.
    final cupRound = ref.watch(cupRoundProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const ValueKey('play-match'),
            onPressed: blocked != null ? null : () => _play(context, ref),
            child: Text(
              cupRound == null
                  ? t('nav.play')
                  : '🏆 ${t('cup.play_round_btn', {'round': cupRound})}',
            ),
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
