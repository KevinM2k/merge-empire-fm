/// Colin's one-time milestone tips, on screen. The other half of
/// `engine/coach_tip_engine.dart`, and ported from the same
/// `../merge-empire-fc/src/ui/components/CoachTips.js`.
///
/// **Which tip is engine; WHEN to ask is this.** The JS re-checks on a handful
/// of moments rather than on every state change, and the list is deliberate: a
/// match closing, a merge, a scout landing, a season ending, and arriving on a
/// tab. Anything else and Colin is a man who follows you around.
///
/// **A tip is a Coach Colin card**, so it goes on screen through `enqueuePopup`
/// like every other popup and cannot stack over one. That is the port's own rule
/// and it happens to be the JS's too — `_anyOverlayOpen` exists precisely
/// because "Colin talking over Colin is the worst version of this bug".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/coach_tip_engine.dart';
import 'package:merge_empire_fc/providers/bus_providers.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';

/// The JS's tab ids, which are not quite this app's.
///
/// Its `league` is this app's home screen, and the conditions are written
/// against the source, so the mapping lives here rather than in the engine.
String tipTabId(ShellTab tab) => switch (tab) {
  ShellTab.grid => 'grid',
  ShellTab.squad => 'squad',
  ShellTab.home => 'league',
  ShellTab.club => 'club',
  ShellTab.shop => 'shop',
};

/// Popup priority. **Last**, behind the welcome-back card and the daily reward:
/// those two hold things the player has earned, and a lesson can wait for a
/// payout.
const int coachTipPriority = 60;

/// Watches for a milestone and puts Colin on screen when one lands.
///
/// Draws nothing itself.
class CoachTipHost extends ConsumerStatefulWidget {
  const CoachTipHost({required this.tab, required this.child, super.key});

  final ShellTab tab;
  final Widget child;

  @override
  ConsumerState<CoachTipHost> createState() => _CoachTipHostState();
}

class _CoachTipHostState extends ConsumerState<CoachTipHost> {
  /// The id waiting or on screen. One at a time, always.
  String? _pending;

  void _check({bool postMatch = false, String? subtab}) {
    if (!mounted || _pending != null) return;
    // Not over anything else — including the GAP between one popup closing and
    // the next opening, which a bare "is a dialog up" probe would let a tip slip
    // into.
    if (hasPopupWork() || arePopupsBlocked()) return;
    final game = ref.read(gameProvider);
    final state = game.state;
    if (state == null) return;
    final tip = pickCoachTip(state, (
      tab: tipTabId(widget.tab),
      subtab: subtab,
      postMatch: postMatch,
    ));
    if (tip == null) return;
    _show(game, tip);
  }

  void _show(GameState game, CoachTip tip) {
    _pending = tip.id;
    // **Spent on SHOW, not on dismissal.** Even if the player backgrounds the
    // app with it up, the tip has done its job and must not come back.
    game.update((Map<String, dynamic> s) => markTipSeen(s, tip.id));
    enqueuePopup(
      PopupEntry(
        id: 'coach-tip-${tip.id}',
        priority: coachTipPriority,
        show: (done) => _open(tip).whenComplete(() {
          _pending = null;
          done();
        }),
      ),
    );
  }

  Future<void> _open(CoachTip tip) async {
    if (!mounted) return;
    await showCoachCard<void>(
      context,
      titleKey: tip.titleKey,
      bodyKey: tip.bodyKey,
      bodyParams:
          tip.bodyParams?.call(ref.read(gameProvider).state) ?? const {},
      // **SPOKEN.** A milestone tip is the case the voice was added for: he is
      // telling you something rather than asking you something, it fires once
      // per milestone rather than on a timer, and its copy is fixed — no name,
      // no fee, nothing an engine would have to read out as digits.
      speaks: true,
      actions: [
        if (tip.cta != null)
          CoachAction(
            labelKey: tip.ctaLabelKey!,
            tone: CoachTone.confirm,
            onTap: () => _runCta(tip.cta!),
          )
        else
          // No button: the JS says TAP ANYWHERE, and a card with nothing to
          // answer should not grow a fake decision.
          CoachAction(labelKey: 'coachtip.tap_dismiss', onTap: () {}),
      ],
    );
  }

  void _runCta(CoachTipCta cta) {
    final shell = ref.read(shellControllerProvider.notifier);
    switch (cta) {
      case CoachTipCta.squad:
        shell.goTab(ShellTab.squad);
      case CoachTipCta.autoSell:
        // Deep-linked to the row itself rather than dropped at the top of
        // Settings to hunt for it.
        emit('nav:settings', {'tab': 'match', 'highlight': 'auto-tier-row'});
      case CoachTipCta.settings:
        emit('nav:settings');
      case CoachTipCta.connect:
        emit('nav:settings', {'tab': 'account'});
    }
  }

  @override
  void didUpdateWidget(CoachTipHost old) {
    super.didUpdateWidget(old);
    // Arriving on a tab is one of the moments.
    if (old.tab != widget.tab) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  @override
  Widget build(BuildContext context) {
    // The moments worth re-checking, and no others.
    for (final event in const [
      'merge:happened',
      'merge:complete',
      'scout:placed',
    ]) {
      ref.listen(busEventProvider(event), (_, _) => _check());
    }
    // A match CLOSING, not completing: a tip fired on the whistle would land
    // over the result screen. Same for a season.
    for (final event in const ['match:close', 'season:ended']) {
      ref.listen(busEventProvider(event), (_, _) => _check(postMatch: true));
    }
    // The training ground is a route here rather than a sub-tab, so it says so
    // itself when it opens.
    ref.listen(
      busEventProvider('nav:subtab'),
      (_, next) => _check(subtab: next.value as String?),
    );
    // **No `tutorial:complete` listener, and that is deliberate.** The JS banks
    // every already-true tip when onboarding ends, so its forced match and its
    // scouts do not trigger a pile of them the moment it closes. This port has
    // no onboarding tutorial yet, so nothing emits that — and a save with no
    // `tutorial.done` reads as finished, which is what makes the tips live from
    // the first moment here. `baselineCoachTips` is the rule, ported and tested,
    // waiting for the screen that needs it; see the note on it.
    return widget.child;
  }
}
