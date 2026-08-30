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
import 'package:merge_empire_fc/engine/cup_engine.dart' show seasonCupRun;
import 'package:merge_empire_fc/engine/league_table.dart' show buildLeagueTable;
import 'package:merge_empire_fc/engine/rating_prompt.dart';
import 'package:merge_empire_fc/engine/season_end.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/services/store_review.dart';
import 'package:merge_empire_fc/ui/popups/champions_card.dart';
import 'package:merge_empire_fc/ui/popups/offseason_report_card.dart';
import 'package:merge_empire_fc/ui/screens/quests/quests_sheet.dart'
    show seasonQuestsProvider;
import 'package:merge_empire_fc/ui/screens/season/season_end_screen.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';

/// Settle the season and show what it did.
///
/// **TOP-LEVEL, because a finished season is not a button.** It was reachable
/// only by pressing one: the fourteenth match ended, the game went back to the
/// Play tab with the season already over, and the player was left holding a
/// save that could do nothing but press End Season. Reported as being allowed
/// to carry on when the season is over — the carrying on is the fault, and the
/// button was the only way out of it.
///
/// So `play_button.dart` runs this the moment the last match's chain is done,
/// and the button stays as what it always was for the one case it is still
/// needed: an app killed between the whistle and the settle comes back to a
/// complete season with nobody left to run this, and pressing it is the way on.
Future<void> runSeasonEnd(BuildContext context, WidgetRef ref) async {
  final game = ref.read(gameProvider);
  final finished = ref.read(seasonJustEndedProvider);
  // **BEFORE the settle, like the season number.** `endSeason` resets the
  // win, draw and loss counters for the new campaign as part of its work, so
  // a summary that reads them afterwards is a summary of nothing. See
  // [seasonRecordOf].
  final record = seasonRecordOf(game.state ?? const {});
  // **AND WHO WON IT, and how the cup went** — both from the season that is
  // about to be settled. `endSeason` rebuilds the table for the new campaign
  // and files the cup's availability, so afterwards neither answer is about
  // the season the page is reporting on.
  final table = buildLeagueTable(game.state ?? <String, dynamic>{});
  final winner = table.isEmpty ? null : table.first;
  // The whole table, for the fold — the same list, captured once.
  final cup = seasonCupRun(game.state);
  // **AND THE SEASON'S QUEST TRACK, before the sweep takes it.** `endSeason`
  // pays out anything completed-but-unclaimed and replaces the track, which
  // is precisely what `season.end.quests_autopay` says on the page.
  final quests = ref.read(seasonQuestsProvider);
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
        record: record,
        winnerName: winner?.name,
        winnerIsUs: winner?.isPlayer ?? false,
        finalTable: table,
        quests: quests,
        cup: cup,
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
    game.update((state) => recordRatingShown(state, trigger: 'promotion'));
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

class EndSeasonButton extends ConsumerWidget {
  const EndSeasonButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        key: const ValueKey('end-season'),
        onPressed: () => runSeasonEnd(context, ref),
        child: Text(t('season.end.title', {'n': ref.watch(seasonJustEndedProvider)})),
      ),
    );
  }
}
