/// The tutorial, on screen.
///
/// **Nine steps, and it is Coach Colin's card** — the port's standing rule, and
/// a tutorial IS him explaining the game.
///
/// **BUT A STEP WITH A TARGET IS NOT A MODAL**, and that is the difference
/// between a tutorial and a wall. The JS lays a full-screen blocker over the
/// app with a HOLE in it at the control being taught, so the one thing on
/// screen that can be pressed is the one the step is about. A modal card cannot
/// do that: it eats every tap, including the one the step is waiting for. The
/// three steps that carry a target are exactly the three that wait on the save.
/// See `tutorial_spotlight.dart` and `tutorial_anchor.dart`.
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
///
/// **ONBOARDING OWNS THE SCREEN END TO END**, which is `blockPopups('tutorial')`
/// in the JS and was the whole of the reported break. Without it the DAILY
/// REWARD sheet opened over the welcome card on a brand-new save and absorbed
/// every tap on it — the card stayed visible the entire time, so it read as the
/// tutorial being broken rather than as a sheet being in the way, and a
/// first-time player was stuck on step 0 forever. The queue holds indefinitely
/// rather than expiring, so nothing waiting behind the block is lost.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/engine/tutorial_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart';
import 'package:merge_empire_fc/ui/screens/grid/loan_arrival.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/ui/screens/match/play_button.dart' show matchPopupBlocker;
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'dart:async';

import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/screens/tutorial/tutorial_anchor.dart';
import 'package:merge_empire_fc/ui/screens/tutorial/tutorial_spotlight.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/shell/tab_transition.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';

/// Where the script is, live off the save.
final tutorialStepProvider = savePick<TutorialStep?>(tutorialStepFor);

/// Which of the four `tut.match_reaction.*` pairs this save has earned.
final matchReactionProvider = savePick<String>(matchReactionKind);

/// Whether the current step's condition has been satisfied by the save.
///
/// **This is what moves a condition step on**, and nothing used to: `condition`
/// had no caller in `lib/`, so the three steps that end this way — scout one,
/// scout three, play a match — were each a dead end. Watching it here rather
/// than polling is the same thing without a timer, and it means a step
/// satisfied three screens away still moves on.
final tutorialConditionProvider = savePick<bool>(tutorialConditionMet);

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

/// The blocker tag, and the JS's own string.
const String tutorialPopupBlocker = 'tutorial';

/// The transparent input-eater's key — the JS's `_animBlockerEl`.
const String tutorialInputSeal = 'tutorial-input-seal';

class TutorialHostState extends ConsumerState<TutorialHost> {
  /// The step a card is currently up for, so one is not opened twice.
  String? _showing;
  bool _busy = false;

  /// Whether this host is holding the popup queue.
  bool _blocking = false;

  /// The loan is flying off the grid and NOTHING may be pressed.
  ///
  /// The JS's `_animBlockerEl`: transparent rather than dimmed, because the
  /// player is meant to be watching the grid, not told to look away from it.
  bool _sealing = false;

  /// Test seam: which step has a card up, or null.
  String? get showing => _showing;

  /// The step already sent on by its condition, so one satisfied save does not
  /// queue an advance on every rebuild.
  String? _satisfied;

  /// Where the current step's control is, re-measured after every frame that
  /// anything else draws.
  Rect? _anchor;
  TutorialAnchor? _anchorFor;
  bool _tracking = false;

  /// The match closing is what lets a held card go up. Nothing else on the bus
  /// changes what this widget draws — the save does, and that is watched.
  void _matchClosed(Object? _) {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    on('match:close', _matchClosed);
  }

  @override
  void dispose() {
    off('match:close', _matchClosed);
    _tracking = false;
    // A host that goes away holding the block would strand the queue for the
    // rest of the process — and the welcome-back card in it holds coins that
    // exist nowhere else.
    if (_blocking) unblockPopups(tutorialPopupBlocker);
    super.dispose();
  }

  /// **The target MOVES**, so its rectangle is re-measured rather than taken
  /// once: the tab it lives on animates in, the grid scrolls, the play button
  /// grows a cooldown bar. The JS re-positions on the same 600ms poll it uses
  /// to re-check conditions, and this is that poll with the condition half
  /// already handled by watching the save.
  /// **AFTER EVERY FRAME, because the control moves.** The JS repositions on
  /// its own 600ms poll and can afford to: a DOM tooltip that lags a scroll
  /// looks untidy. Here the hole is also the INPUT hole — everything outside it
  /// is absorbed — so a stale one does not look untidy, it eats the tap the
  /// step is waiting for. The scout reveal scrolls the grid to the square the
  /// new card is flying into, which moves the button out from under the hole,
  /// and that is exactly how a player got stuck at two cards of the three the
  /// second step asks for.
  ///
  /// **A post-frame callback rather than a Ticker**, and the difference is not
  /// cosmetic: a Ticker asks for a frame, so the app would draw for ever while
  /// a spotlight step was up — every `pumpAndSettle` in the suite hangs, and a
  /// phone renders continuously to watch a button that is not moving. This
  /// re-registers after each frame SOMEBODY ELSE draws, so it follows a scroll
  /// exactly and sleeps the moment the screen is still. Nothing can move
  /// without a frame, so there is nothing to miss.
  ///
  /// Cheap because [TutorialAnchor] walks the tree once and then re-measures
  /// the render box it found.
  void _track(String key) {
    if (_anchorFor?.id != key) {
      _anchorFor = TutorialAnchor(key);
      _anchor = null;
    }
    if (_tracking) return;
    _tracking = true;
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_tracking) return;
      final rect = _anchorFor?.measure();
      if (rect != _anchor) setState(() => _anchor = rect);
      _scheduleMeasure();
    });
  }

  void _stopTracking() {
    _tracking = false;
    _anchorFor = null;
    _anchor = null;
  }

  /// Hold the queue while the script is running, and let go the moment it is
  /// not. **Both directions matter**: taking the block is what stops a sheet
  /// landing on the card, and giving it back is what lets the daily reward the
  /// player has actually earned finally open.
  void _setBlocking(bool wanted) {
    if (wanted == _blocking) return;
    _blocking = wanted;
    if (wanted) {
      blockPopups(tutorialPopupBlocker);
    } else {
      unblockPopups(tutorialPopupBlocker);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = ref.watch(tutorialStepProvider);
    _setBlocking(step != null);
    // Checked before the null-step return: `skipTutorial` can land mid-flight.
    if (_sealing) {
      return const ModalBarrier(
        key: ValueKey(tutorialInputSeal),
        dismissible: false,
        color: null,
      );
    }
    if (step == null) {
      _showing = null;
      _stopTracking();
      return const SizedBox.shrink();
    }

    // **Satisfied steps advance themselves.** Deferred off the frame like every
    // other write here: a Riverpod write inside a widget lifecycle is refused.
    if (ref.watch(tutorialConditionProvider) && _satisfied != step.id) {
      _satisfied = step.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(gameProvider).update(advanceTutorial);
      });
    }

    if (step.targetKey case final key?) {
      // **Drawn, not pushed.** A spotlight step is a layer over the running
      // app, so it lives in this widget's own tree rather than on the
      // navigator — a route would cover the control it is pointing at.
      if (step.id != _showing) {
        _showing = step.id;
        _anchor = null;
        WidgetsBinding.instance.addPostFrameCallback((_) => _openTab(step));
      }
      _track(key);
      return TutorialSpotlight(
        target: _anchor,
        child: _Tooltip(step: step, target: _anchor, onSkip: _skip),
      );
    }

    _stopTracking();
    // **NOT WHILE THE MATCH OWNS THE SCREEN.**
    //
    // `seasonAwardedPlayed` moves the instant the result settles, which is
    // while the player is still watching full time — so the reaction card went
    // up over the match screen, before the summary, before the money, and the
    // tutorial's own popup block did not cover it because a coach card is a
    // `showDialog` rather than a queued popup. Reported as being stuck on the
    // game screen.
    //
    // `matchPopupBlocker` is held for the whole round trip — the tie, the
    // summary, and the bids and offers on the way out — and `match:close`
    // brings us back here when it is finally let go.
    if (isPopupBlockedBy(matchPopupBlocker)) return const SizedBox.shrink();
    // **Deferred off the frame.** Opening a route inside `build` is navigation
    // during a build, and it is the same fault this port already documents for
    // a Riverpod write inside a widget lifecycle.
    if (step.id != _showing && !_busy) {
      _showing = step.id;
      WidgetsBinding.instance.addPostFrameCallback((_) => run(step));
    }
    // **NOTHING OUTSIDE THE SCRIPT IS PRESSABLE, for the whole of it.**
    //
    // A card step drew nothing here and leaned on the dialog's own barrier,
    // which is a barrier only while the dialog is up. It is not up in three
    // ordinary windows: between the answer to one step and the opening of the
    // next, while a tab slides in under `run`, and — the one a player actually
    // finds — after a tap outside dismisses the card, which left the app fully
    // live with the HUD, the tabs and Add Player all reachable and the
    // tutorial waiting for a rebuild that nothing was going to schedule.
    // Reported from the couch as being able to press the HUD icons mid-script.
    //
    // The seal is the same input-eater the loan flight already uses, held for
    // as long as a step is live. The one thing a player may press is whatever
    // the step itself puts on screen: the card, which is a route ABOVE this,
    // or the control inside a spotlight's hole, which is the branch above.
    return const ModalBarrier(
      key: ValueKey(tutorialInputSeal),
      dismissible: false,
      color: null,
    );
  }

  void _skip() => ref.read(gameProvider).update(skipTutorial);

  /// The tab the step belongs on, so the card — or the hole — is over the thing
  /// it is talking about.
  void _openTab(TutorialStep step) {
    if (!mounted) return;
    switch (step.tab) {
      case TutorialTab.grid:
        ref.read(shellControllerProvider.notifier).goTab(ShellTab.grid);
      case TutorialTab.league:
        ref.read(shellControllerProvider.notifier).goTab(ShellTab.home);
      case TutorialTab.none:
        break;
    }
  }

  /// One step, start to finish. Public so a test can drive it without a shell.
  Future<void> run(TutorialStep step) async {
    if (!mounted) return;
    _busy = true;
    try {
      _openTab(step);
      if (!mounted) return;
      if (step.id == 'loan_depart') {
        // **Nothing is pressable while they fly.** The JS lays a transparent
        // input-eater over the app for exactly this window — the tutorial's
        // own chrome is down, there is no card to absorb taps, and Add Player
        // is sitting right there under the emptying grid.
        setState(() => _sealing = true);
        // **The tab has to have ARRIVED first.** The step is on the grid and
        // the player was on the league screen a frame ago; without this the
        // cards spend their whole flight sliding in from off-screen, and the
        // report was that the loan vanished on the wrong page entirely.
        await Future<void>.delayed(tabSlideDuration);
        if (!mounted) return;
        await departLoan(ref);
        if (!mounted) return;
        setState(() => _sealing = false);
      }
      final answered = await showTutorialCard(context, ref, step);
      if (!mounted) return;
      switch (answered) {
        case TutorialAnswer.skipped:
          ref.read(gameProvider).update(skipTutorial);
        case TutorialAnswer.next:
          await applyStepEffects(ref, step);
          if (!mounted) return;
          ref.read(gameProvider).update(advanceTutorial);
        case null:
          // Dismissed without answering — the step stands, and the next build
          // puts it back up. **The rebuild has to be ASKED for**: clearing the
          // field notifies nothing, so the card stayed down until something
          // else happened to rebuild this widget, and the seal underneath it
          // would have been a tutorial with no way forward.
          if (mounted) setState(() => _showing = null);
      }
    } finally {
      _busy = false;
    }
  }
}

/// The line for a spotlight step — the same card every other step wears, laid
/// over the dim rather than pushed as a route.
///
/// **It carries SKIP and nothing else.** The step is answered by doing the
/// thing the hole is around; a "next" button beside it would be a second way
/// past a step whose whole point is that the player performs it. `tut.skip` is
/// still here because a tutorial you cannot leave is a trap.
class _Tooltip extends ConsumerWidget {
  const _Tooltip({required this.step, required this.target, required this.onSkip});

  final TutorialStep step;

  /// Where the hole is, so the card can get out of its way.
  final Rect? target;

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) => CoachCardFrame(
    // **THE CARD MOVES OUT OF THE WAY OF THE HOLE — and only when it is in the
    // way.** Colin stands over a box along the bottom of the screen now, and
    // the control a spotlight step points at is sometimes down there too — the
    // kick-off step's PLAY button is, and the card landed squarely on it. The
    // box eats its own taps, so the step could not be completed at all.
    //
    // The hole, not a distance: what to do about it is the card's own
    // arithmetic, and working it out here got the scout steps wrong. See
    // [CoachCardFrame.avoid].
    avoid: target?.inflate(spotlightPad),
    title: t(step.titleKey, tutorialParams(ref)),
    body: t(step.bodyKey, tutorialParams(ref)),
    extraLines: const [
      // The player is being asked to do something rather than to read
      // something, and the card has no button to say so for it.
      (key: 'tut.complete_above', params: <String, Object?>{}, strong: false),
    ],
    // **A LINK, NOT A BUTTON.** Leaving the tutorial and getting on with it are
    // not two answers of equal weight — see [CoachCardFrame.footer].
    //
    // **AND IT DOES NOT DISMISS, because there is nothing to dismiss.** This
    // card is drawn on the host's own tree rather than pushed as a route, so
    // the default `dismisses: true` popped the nearest Navigator — which is the
    // APP's. Skipping from a spotlight step took the game's own route off the
    // stack and left a black screen; reported from the couch in one line. What
    // takes this card down is the script ending, which `onSkip` does.
    footer: CoachAction(
      labelKey: 'tut.skip',
      onTap: onSkip,
      dismisses: false,
    ),
  );
}

/// Every placeholder any step can ask for, supplied for all of them.
///
/// The params a key needs are the union across the steps that share a call
/// site, and a spare costs nothing — the same rule the pooled coach copy taught
/// this repo, learned there as an intermittent failure.
Map<String, Object?> tutorialParams(WidgetRef ref) => {
  'coins': formatCoins(startingCoins),
  'club': ref.read(tutorialClubProvider),
  'count': ref.read(tutorialGridCountProvider),
  'needed': 3,
  'score': ref.read(tutorialScoreProvider),
};

/// The step that DOES something as it is answered.
///
/// Guarded inside the engine on its own save flag, so a card answered twice — a
/// double tap, a rebuild — lends once.
///
/// **AND THE LOAN IS WATCHED, not just applied.** "See My Squad" was a button
/// that rewrote the grid and put the next card up on the same frame, so eight
/// players appeared behind a coach card nobody had asked for yet. The JS drops
/// them in one at a time and holds the script until the last one has landed —
/// see [LoanArrival], and [loanArrivalWindow] for how long that is.
Future<void> applyStepEffects(WidgetRef ref, TutorialStep step) async {
  switch (step.id) {
    case 'loan_boost':
      final lent = ref.read(gameProvider).update(lendTutorialPlayers);
      // Reduce-motion has nothing to wait for: the cards are simply there.
      if (lent == 0 || MediaQuery.disableAnimationsOf(ref.context)) return;
      await Future<void>.delayed(loanArrivalWindow(lent));
  }
}

/// **The loan leaves BEFORE the card that says it has, not after.**
///
/// The port ran `returnTutorialPlayers` when the player answered
/// `tut.loan_depart` — so Colin announced the squad was gone over a grid still
/// full of them, and they vanished a tap later on whatever screen the player
/// happened to be looking at. The JS has always had this the other way round:
/// `loan_depart.onEnterAsync` flies the borrowed cards off the grid, removes
/// them from the save, and only THEN opens the dialog.
///
/// So this is the step's entrance, and it is three things in order — show the
/// grid, empty it, take the loan out of the save. The card follows in [run].
/// Returns once the grid is actually empty.
Future<void> departLoan(WidgetRef ref) async {
  final leaving = ref.read(loanCardIdsProvider).length;
  if (leaving == 0) return;
  if (MediaQuery.disableAnimationsOf(ref.context)) {
    ref.read(gameProvider).update(returnTutorialPlayers);
    return;
  }
  ref.read(loanDepartingProvider.notifier).state = true;
  // **And it makes a noise.** Eleven cards coming apart in silence is the one
  // moment in the script with a real effect on it and nothing to hear. One
  // pop for the lot rather than one each: the stagger is 40ms and the sound
  // service collapses anything inside its 70ms retrigger floor anyway, so
  // eleven would have been two and a rattle. Asked for with the animation.
  playSoundFrom(ref, 'pop');
  try {
    await Future<void>.delayed(loanDepartureWindow(leaving));
  } finally {
    // **The save is rewritten and the flag dropped in that order**, and never
    // one without the other: a flag left set would spend the rest of the
    // session flying every future loan card off the grid.
    ref.read(gameProvider).update(returnTutorialPlayers);
    ref.read(loanDepartingProvider.notifier).state = false;
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
    bodyParams: tutorialParams(ref),
    // **A TAP OUTSIDE DOES NOTHING.** The two ways past a step are the button
    // it offers and Skip; anything else dropped the card and left the player
    // looking at a sealed app. Asked for directly.
    barrierDismissible: false,
    // **SPOKEN.** The walkthrough is the one stretch of the game that is purely
    // him teaching, on the one run where the player has no idea what any of it
    // does — and it happens once, so there is no session in which the voice
    // becomes a thing to sit through twice.
    speaks: true,
    extraLines: [
      // A step waiting on the save says so, or it reads as a card whose button
      // has failed to load.
      if (step.buttonKey == null)
        (key: 'tut.complete_above', params: const {}, strong: false),
    ],
    actions: [
      // **THE ONE THING TO DO, FULL WIDTH.** Skip sat beside it as an equal
      // half, so "Let's go" was half a card wide and leaving looked like the
      // other half of a choice.
      if (step.buttonKey case final key?)
        CoachAction(
          labelKey: key,
          tone: CoachTone.confirm,
          onTap: () {},
          result: TutorialAnswer.next,
        ),
    ],
    // **Skippable at every step.** A tutorial you cannot leave is a trap, and
    // the JS puts this in the CORNER of every one of them — a way out, not an
    // answer.
    footer: CoachAction(
      labelKey: 'tut.skip',
      onTap: () {},
      result: TutorialAnswer.skipped,
    ),
  );
}
