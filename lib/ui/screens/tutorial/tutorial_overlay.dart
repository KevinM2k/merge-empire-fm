/// The tutorial, on screen.
///
/// **Nine steps, and it is Coach Colin's card** — which is the port's standing
/// rule and happens to be right here for a second reason: the JS anchors each
/// step to a DOM selector and draws a tooltip beside it, and a selector is not
/// a thing this port has. What it does have is the one character who explains
/// the game, and a tutorial IS him explaining the game.
///
/// **A step ends one of two ways and never both.** Either it carries a button
/// and the player taps to move on, or it waits on the SAVE — and the card says
/// `tut.complete_above` under it so the player knows they are being asked to do
/// something rather than to read something. `tut.skip` is on every step,
/// because a tutorial you cannot leave is a trap.
///
/// **It watches the save rather than the screen.** The JS polls every 600ms and
/// re-checks the condition; here the step is re-read whenever the save changes,
/// which is the same thing without a timer — and it means a step satisfied by
/// something happening three screens away still moves on.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/engine/tutorial_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';
import 'package:merge_empire_fc/util/format.dart';

/// Where the script is, live off the save.
final tutorialStepProvider = savePick<TutorialStep?>(tutorialStepFor);

/// Which of the four `tut.match_reaction.*` pairs this save has earned.
final matchReactionProvider = savePick<String>(matchReactionKind);

/// The club's name, for the welcome. Falls back to the catalogue's own.
final tutorialClubProvider = savePick<String>((s) {
  final name = s['clubName'];
  return name is String && name.isNotEmpty
      ? name
      : t('tut.welcome.default_club');
});

/// How many cards are on the grid, for `tut.scout_2`'s "{count} of {needed}".
final tutorialGridCountProvider = savePick<int>((s) {
  final cells = (s['grid'] as Map<String, dynamic>?)?['cells'];
  return cells is List ? cells.where((c) => c != null).length : 0;
});

/// The last result's scoreline, for the three reactions that quote it.
final tutorialScoreProvider = savePick<String>((s) {
  final result = (s['progression'] as Map<String, dynamic>?)?['lastMatchResult'];
  if (result is! Map) return '';
  final score = result['score'];
  return score is String ? score : '';
});

/// What a step's card came back with.
enum TutorialAnswer { next, skipped }

/// Drives the script. Draws nothing itself.
///
/// Mounted once, in the shell, above the tabs — a step can switch tabs and the
/// thing doing the switching cannot live on a tab.
class TutorialHost extends ConsumerStatefulWidget {
  const TutorialHost({super.key});

  @override
  ConsumerState<TutorialHost> createState() => TutorialHostState();
}

class TutorialHostState extends ConsumerState<TutorialHost> {
  /// The step a card is currently up for, so one is not opened twice.
  String? _showing;
  bool _busy = false;

  /// Test seam: which step has a card up, or null.
  String? get showing => _showing;

  @override
  Widget build(BuildContext context) {
    final step = ref.watch(tutorialStepProvider);
    // **Deferred off the frame.** Opening a route inside `build` is navigation
    // during a build, and it is the same fault this port already documents for
    // a Riverpod write inside a widget lifecycle.
    if (step != null && step.id != _showing && !_busy) {
      _showing = step.id;
      WidgetsBinding.instance.addPostFrameCallback((_) => run(step));
    }
    if (step == null) _showing = null;
    return const SizedBox.shrink();
  }

  /// One step, start to finish. Public so a test can drive it without a shell.
  Future<void> run(TutorialStep step) async {
    if (!mounted) return;
    _busy = true;
    try {
      // The tab first, so the card opens over the thing it is talking about.
      switch (step.tab) {
        case TutorialTab.grid:
          ref.read(shellControllerProvider.notifier).goTab(ShellTab.grid);
        case TutorialTab.league:
          ref.read(shellControllerProvider.notifier).goTab(ShellTab.home);
        case TutorialTab.none:
          break;
      }
      if (!mounted) return;
      final answered = await showTutorialCard(context, ref, step);
      if (!mounted) return;
      switch (answered) {
        case TutorialAnswer.skipped:
          ref.read(gameProvider).update(skipTutorial);
        case TutorialAnswer.next:
          applyStepEffects(ref, step);
          ref.read(gameProvider).update(advanceTutorial);
        case null:
          // Dismissed without answering — the step stands, and the next build
          // puts it back up.
          _showing = null;
      }
    } finally {
      _busy = false;
    }
  }
}

/// The two steps that DO something as they are answered.
///
/// Both are guarded inside the engine on their own save flags, so a card
/// answered twice — a double tap, a rebuild — lends and takes back once.
void applyStepEffects(WidgetRef ref, TutorialStep step) {
  switch (step.id) {
    case 'loan_boost':
      ref.read(gameProvider).update(lendTutorialPlayers);
    case 'loan_depart':
      ref.read(gameProvider).update(returnTutorialPlayers);
  }
}

/// One step, as his card.
Future<TutorialAnswer?> showTutorialCard(
  BuildContext context,
  WidgetRef ref,
  TutorialStep step,
) {
  final kind = ref.read(matchReactionProvider);
  final isReaction = step.id == 'match_result_reaction';
  final titleKey = isReaction
      ? 'tut.match_reaction.${kind}_title'
      : step.titleKey;
  final bodyKey = isReaction ? 'tut.match_reaction.${kind}_body' : step.bodyKey;

  return showCoachCard<TutorialAnswer>(
    context,
    titleKey: titleKey,
    bodyKey: bodyKey,
    // **Every placeholder any step can ask for, supplied for all of them.** The
    // params a key needs are the union across the steps that share this call
    // site, and a spare costs nothing — the same rule the pooled coach copy
    // taught this repo, learned there as an intermittent failure.
    bodyParams: {
      'coins': formatCoins(startingCoins),
      'club': ref.read(tutorialClubProvider),
      'count': ref.read(tutorialGridCountProvider),
      'needed': 3,
      'score': ref.read(tutorialScoreProvider),
    },
    extraLines: [
      // A step waiting on the save says so, or it reads as a card whose button
      // has failed to load.
      if (step.buttonKey == null)
        (key: 'tut.complete_above', params: const {}, strong: false),
    ],
    actions: [
      // **Skippable at every step.** A tutorial you cannot leave is a trap, and
      // the JS puts this in the corner of every one of them.
      CoachAction(
        labelKey: 'tut.skip',
        onTap: () {},
        result: TutorialAnswer.skipped,
      ),
      if (step.buttonKey case final key?)
        CoachAction(
          labelKey: key,
          tone: CoachTone.confirm,
          onTap: () {},
          result: TutorialAnswer.next,
        ),
    ],
  );
}
