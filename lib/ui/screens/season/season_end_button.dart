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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/rating_prompt.dart';
import 'package:merge_empire_fc/engine/season_end.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/services/store_review.dart';
import 'package:merge_empire_fc/ui/popups/champions_card.dart';
import 'package:merge_empire_fc/ui/popups/offseason_report_card.dart';
import 'package:merge_empire_fc/ui/screens/season/season_end_screen.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';

class EndSeasonButton extends ConsumerWidget {
  const EndSeasonButton({super.key});

  Future<void> _end(BuildContext context, WidgetRef ref) async {
    final game = ref.read(gameProvider);
    final finished = ref.read(seasonJustEndedProvider);
    final outcome = game.update(endSeason);
    if (!context.mounted) return;

    // **The NAVIGATOR's context, captured before the route goes up.** This
    // button is a `ConsumerWidget` and it is the first thing to disappear —
    // `seasonCompleteProvider` flips false inside `endSeason`, so by the time
    // the summary is dismissed the widget whose context this is has been
    // replaced by the play button. A popup queued against it would be dropped
    // for being unmounted; the navigator outlives both.
    final navigator = Navigator.of(context);

    await navigator.push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (routeContext) => SeasonEndScreen(
          outcome: outcome,
          seasonNumber: finished,
          onContinue: () => Navigator.of(routeContext).maybePop(),
        ),
      ),
    );

    // **GOING UP IS A HIGH-EMOTION MOMENT, which is when to ask.** The JS's
    // own trigger, and the reason it needs no win threshold of its own — a
    // promotion is the good news. `rating_prompt.dart` carries the whole of the
    // restraint: five asks ever, a week apart, and never after an opt-out.
    //
    // **NOT through `enqueuePopup`, deliberately.** The review sheet is a
    // system overlay rather than one of the three popup shapes, so the queue
    // has no way to know when it closed and would drain the offseason report
    // out from under it. Fired here, before the queue has anything in it, for
    // the same reason the JS fires it from this exact line.
    if (outcome.outcome == 'promoted' &&
        shouldPromptRatingOnPromotion(game.state ?? {})) {
      game.update((state) => recordRatingShown(state));
      unawaited(requestNativeReview());
    }

    // **WHAT THE BREAK DID, which the engine has always reported and nothing
    // has ever read.** `endSeason` returns an injury, a sponsor and an ageing
    // report; eleven `offseason.*` strings sat translated in ten catalogues
    // with no caller. The JS shows this straight after the season summary and
    // before anything else in the season-end chain, and skips it outright when
    // the break did nothing.
    if (offseasonHasNews(outcome)) {
      enqueuePopup(
        PopupEntry(
          id: 'offseason-report',
          priority: PopupPriority.offseasonReport,
          canShow: () => navigator.mounted,
          show: (done) => unawaited(
            showOffseasonReport(navigator.context, outcome).then((_) => done()),
          ),
        ),
      );
    }

    // **AND THE NIGHT THE GAME IS WON, behind it.** Nine more `champ.*`
    // strings with no caller, and the queue could not tell from here whether
    // they were the endgame or a second prestige card. They are the
    // celebration the JS fires from this exact point — after the offseason
    // report, once per title, feeding the same prestige flow the dock orb
    // does. The queue's ordering is what keeps the two in the JS's order
    // without either of them knowing about the other.
    if (!wonTheTitle(outcome)) return;
    enqueuePopup(
      PopupEntry(
        id: 'champions-celebration',
        priority: PopupPriority.championsCelebration,
        canShow: () => navigator.mounted,
        show: (done) => unawaited(
          showChampionsCelebration(navigator.context, ref).then((_) => done()),
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
