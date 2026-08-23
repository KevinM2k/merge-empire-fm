/// Coach Colin's read on the next fixture. Ported from `_computeManagerTips`
/// and `_openCoachPanel` in `ui/screens/LeagueScreen.js`.
///
/// A bubble anchored to his orb rather than a centred modal, because the tip
/// should read as coming out of Colin rather than as the app interrupting. He
/// is the one thing on the home screen that talks to you, which is exactly why
/// he kept an orb when the other nine moved into the menu.
///
/// **The dot is the point.** It lights when the pool CHANGES — a new fixture, a
/// different tactic call — and clears when the bubble is opened. A coach whose
/// badge never moves is a button nobody presses twice.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/engine/fixture_preview.dart';
import 'package:merge_empire_fc/engine/manager_hint_engine.dart';
import 'package:merge_empire_fc/engine/squad_state_engine.dart';
import 'package:merge_empire_fc/engine/tactic_coach.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/theme/tactic_style.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num _num(Object? v) => v is num ? v : 0;

/// One thing Colin has to say.
typedef CoachTip = ({String id, String text});

/// The tips for the fixture in front of us, best first.
///
/// Deliberately a SHORT pool. He is standing on the touchline before a match,
/// not writing a report, and a list of nine observations is one nobody reads to
/// the end of.
final coachTipsProvider = savePick<List<CoachTip>>((s) {
  final preview = previewFixture(s);
  final tips = <CoachTip>[];

  if (preview != null) {
    final opponent = preview.opponentName;
    final ourRating = preview.effectiveSquadRating;
    final theirRating = preview.effectiveOppRating;

    // A grudge is the one thing that makes a weaker side dangerous, so it
    // outranks the rating comparison rather than sitting under it.
    if (preview.grudgeBoost > 0) {
      tips.add((id: 'grudge', text: t('manager.grudge', {'opp': opponent})));
    }

    // **WHAT HAPPENED LAST TIME THESE TWO MET.** Fourteen `manager_hint.*`
    // strings sat translated in ten catalogues with nothing able to print one,
    // and this file's own header says it is the port of `_computeManagerTips` —
    // the JS function they are the output of. The pool had the grudge and the
    // rating gap and nothing about the fixture itself.
    //
    // Directly under the grudge, and above the rating comparison, because it is
    // the same KIND of thing: both are about this opponent rather than about
    // our squad, and a run of results against a club is what a manager checks
    // before he checks anyone's rating.
    //
    // `{when}` is a phrase inside a sentence, so the engine hands back the key
    // for it and the catalogue layer finishes the job here.
    final history = fixtureHintPool(
      s,
      opponent,
      currentSeason: _num(_map(s['progression'])?['seasonCount']).toInt(),
    );
    if (history != null) {
      // **POOLED copy, and `t()` would have printed the whole pool.** Every
      // `streak.*` and `last_meeting.*` string is three or four sentences
      // separated by pipes, so a straight `t()` reads all of them at the player
      // in one line — which is what the first version of this did, and what the
      // test caught.
      //
      // `tPoolStable` rather than `tPool`: the pool is rebuilt on every change
      // to the save, and a random pick would have Colin rephrasing himself
      // while the bubble is open. Seeded on the fixture and the run, so his
      // wording holds until the thing he is talking about changes.
      //
      // `tPoolStableOf` rather than `tPoolStable` because the pool can be TWO
      // keys: the all-time record joins the fixture's own sentences rather than
      // replacing them, which is the JS's shape — see `fixtureHintPool`.
      final when = history.params['when'];
      tips.add((
        id: 'head_to_head',
        text: tPoolStableOf(
          history.keys,
          '$opponent|${history.keys.join('+')}|${history.params['n'] ?? ''}',
          {
            ...history.params,
            if (when is ManagerHint) 'when': t(when.key, when.params),
          },
        ),
      ));
    }

    if (theirRating != null) {
      final gap = ourRating - theirRating;
      if (gap <= -5) {
        tips.add((
          id: 'gap_higher',
          text: t('manager.rating_gap_higher', {'opp': opponent}),
        ));
      } else if (gap >= 12) {
        // Far enough ahead that the useful advice is about FITNESS rather than
        // about winning — the result is not in doubt, so the cost is.
        tips.add((
          id: 'rotate',
          text: t('manager.rotate_hard', {'opp': opponent}),
        ));
      } else if (gap >= 5) {
        tips.add((
          id: 'gap_lower',
          text: t('manager.rating_gap_lower', {'opp': opponent}),
        ));
      }
    }

    // **WHAT HE WOULD PLAY IS NOT A TIP.** The bubble's own header already
    // reads `COACH COLIN SUGGESTS <TACTIC>` — see [_CoachLabel], which asks
    // [coachSuggestedTacticProvider] the same question — so a tip carrying that
    // sentence put the identical advice in one window twice. The pool is for
    // the things the header cannot say.
  }

  // **HIS READ ON OUR OWN SQUAD, which is thirteen keys and forty-odd
  // sentences that nothing in `lib/` could reach.** Last, and only when there
  // is room, which is the JS's own rule: everything above it is about the
  // fixture in front of us, and a squad note is what he falls back on when
  // there is not enough to say about the opponent. `squadStateHint` is allowed
  // to answer null, and that is a real answer rather than a gap to fill.
  if (tips.length < 3) {
    final squadState = squadStateHint(s);
    if (squadState != null) {
      tips.add((
        id: 'squad_state',
        text: tPoolStable(
          squadState.key,
          squadState.seed,
          squadState.params,
        ),
      ));
    }
  }

  if (tips.isEmpty) {
    tips.add((id: 'default', text: t('manager.default_tip')));
  }
  return tips;
});

/// What the pool currently is, as one string.
///
/// The dot compares this against what was last read. Keyed on the TEXT rather
/// than on the fixture, because the same opponent with a rebuilt squad is a
/// different piece of advice.
final coachTipKeyProvider = savePick<String>((s) {
  final preview = previewFixture(s);
  final opponent = preview?.opponentName ?? '';
  final rating = preview?.effectiveSquadRating.round() ?? 0;
  final matches = _num(_map(s['progression'])?['matchesPlayed']).toInt();
  return '$opponent|$rating|$matches';
});

/// What he would play, when it is not what is already set. Null when the
/// manager has already picked the tactic he would have picked.
final coachSuggestedTacticProvider = savePick<String?>((s) {
  final preview = previewFixture(s);
  if (preview == null) return null;
  final suggestion = suggestTactic(
    preview.effAttack,
    preview.effDefence,
    preview.effOppAttackRating ?? preview.effAttack,
    preview.effOppDefenceRating ?? preview.effDefence,
    oppAttackRatio: preview.oppAttackRatio,
  );
  final current = _map(s['squad'])?['strategyId'];
  return suggestion.id == current ? null : suggestion.id;
});

/// The last pool the player actually opened. Not on the save: an unread badge
/// is a property of this sitting, and a fresh boot showing his newest read is
/// the right behaviour rather than a bug.
final coachSeenKeyProvider = StateProvider<String?>((_) => null);

final coachHasUnreadProvider = Provider<bool>((ref) {
  final current = ref.watch(coachTipKeyProvider);
  return ref.watch(coachSeenKeyProvider) != current;
});

/// The coach dock's own box, so the bubble can sit beside it.
///
/// It is anchored to the BUTTON rather than to the corner of the screen: the tip
/// has to read as coming out of Colin, and a panel floating above him reads as
/// the app talking over him.
final GlobalKey coachDockKey = GlobalKey();

Future<void> showCoachBubble(BuildContext context, WidgetRef ref) {
  ref.read(coachSeenKeyProvider.notifier).state = ref.read(coachTipKeyProvider);
  final box = coachDockKey.currentContext?.findRenderObject() as RenderBox?;
  final anchor = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  return showDialog<void>(
    context: context,
    barrierColor: coachScrim,
    builder: (_) => _CoachBubble(anchor: anchor),
  );
}

class _CoachBubble extends ConsumerStatefulWidget {
  const _CoachBubble({required this.anchor});

  /// The dock button's box in global coordinates, or null when it is not on
  /// screen (a test, or the tab being switched under it).
  final Rect? anchor;

  @override
  ConsumerState<_CoachBubble> createState() => _CoachBubbleState();
}

class _CoachBubbleState extends ConsumerState<_CoachBubble> {
  int _index = 0;
  Timer? _cycle;

  /// He says the next thing every six seconds, and a tap moves it on. A timer
  /// alone would change a line while it is being read; a tap alone leaves a
  /// second tip nobody finds.
  static const Duration _dwell = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    _restart();
  }

  void _restart() {
    _cycle?.cancel();
    _cycle = Timer.periodic(_dwell, (_) {
      if (mounted) setState(() => _index++);
    });
  }

  void _next() {
    setState(() => _index++);
    _restart();
  }

  @override
  void dispose() {
    _cycle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final tips = ref.watch(coachTipsProvider);
    if (tips.isEmpty) return const SizedBox.shrink();
    final tip = tips[_index % tips.length];
    final screen = MediaQuery.sizeOf(context);
    final anchor = widget.anchor;

    // **DIRECTLY ABOVE HIM**, which is where it is on every other screen.
    //
    // It hung off his RIGHT SHOULDER — `left: anchor.right - 10` — so on this one
    // page the bubble went up and across instead of up, and the tail pointed
    // back at a corner of him rather than at his face. The floating coach every
    // other tab uses stacks the bubble on top of the head and drops the wedge
    // onto it; this now does the same thing with the dock as its anchor.
    final left = anchor == null ? 15.0 : math.max(10.0, anchor.left);
    final bottom = anchor == null
        ? 96.0
        : math.max(8.0, screen.height - anchor.top + 12);
    final maxWidth = math.max(160.0, screen.width - left - 14);
    // **THE POINT sits over the middle of the disc below it, not the box.** It
    // was `- 9`, half the wedge's width — and the wedge leans left, so its tip
    // is at [coachTailTipX] rather than at its centre. Seven pixels off, which
    // is close enough to look deliberate and wrong enough that the bubble reads
    // as pointing past him. Clamped, so a dock near the edge of a narrow screen
    // cannot push it off the bubble.
    final double tailLeft = anchor == null
        ? 12.0
        : (anchor.center.dx - left - coachTailTipX).clamp(
            10.0,
            math.max(10.0, maxWidth - 30),
          );

    final bubble = Material(
      color: Colors.transparent,
      child: Container(
        key: const ValueKey('coach-bubble'),
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.fromLTRB(12, 10, 30, 10),
        decoration: BoxDecoration(
          color: kit.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kit.accent),
        ),
        child: Stack(
          children: [
            // NO PORTRAIT. The dock button already IS his face and this springs
            // out of it, so a second head in the bubble was the same man twice —
            // which is exactly what it looked like.
            InkWell(
              onTap: tips.length > 1 ? _next : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _CoachLabel(),
                  const SizedBox(height: 3),
                  // The line itself fades between tips rather than snapping, so
                  // a cycle mid-read is a change you can see coming.
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      tip.text,
                      key: ValueKey('coach-tip-${tip.id}'),
                      style: TextStyle(
                        // The size every OTHER screen's bubble uses. This one
                        // was the odd one out.
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  // DOTS, not a "2 / 3" button: the count is the only thing a
                  // fraction adds, and it reads as a control rather than as a
                  // place in a short list.
                  if (tips.length > 1) ...[
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < tips.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _index % tips.length
                                    ? kit.accentBright
                                    : Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              top: -4,
              right: -22,
              // **`manager_hint.aria.dismiss`, at last.** It and its sibling
              // are DOM accessibility labels — the last two of the fourteen
              // `manager_hint.*` strings with no caller — and the queue's own
              // note was that they want a Flutter `Semantics` rather than a
              // printed string. This is that: the label a screen reader reads,
              // in the player's own language, where `common.close` is what a
              // pointer gets as a tooltip.
              child: Semantics(
                label: t('manager_hint.aria.dismiss'),
                button: true,
                child: IconButton(
                  key: const ValueKey('coach-bubble-close'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: t('common.close'),
                  icon: const Icon(Icons.close, size: 14),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Stack(
      children: [
        // Anywhere outside closes it.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        Positioned(
          left: left,
          bottom: bottom,
          // **`manager_hint.aria.head`**, which is what the whole panel is
          // called to a screen reader — "Manager hint". Without it the bubble
          // is read out as a pile of unrelated strings with a close button in
          // the middle of them.
          child: Semantics(
            container: true,
            label: t('manager_hint.aria.head'),
            child: Stack(
            clipBehavior: Clip.none,
            children: [
              bubble,
              // The tail, pointing down and back at him. Same fill and same
              // stroke as the bubble, so the two are one shape.
              Positioned(
                left: tailLeft,
                bottom: -10,
                child: CustomPaint(
                  size: coachTailSize,
                  painter: CoachBubbleTail(
                    fill: kit.surface.withValues(alpha: 0.94),
                    edge: kit.accent,
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
      ],
    );
  }
}

/// `COACH COLIN`, and what he would play — the suggested tactic inline on the
/// same row, in ITS OWN colour, so it matches the row you will go and tap in the
/// picker. No fill behind it: the bubble is glass, and a tinted chip on a
/// translucent panel put the tactic's hue behind its own text.
/// The bubble's header, on its own — the label, the suggestion and the tactic.
///
/// Public only so a test can pump it without the bubble's dialog and its
/// anchor: it is one `Wrap` and mounting a route to look at it is the sort of
/// harness that ends up testing the route.
class CoachLabelProbe extends StatelessWidget {
  const CoachLabelProbe({super.key});

  @override
  Widget build(BuildContext context) => const _CoachLabel();
}

class _CoachLabel extends ConsumerWidget {
  const _CoachLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final suggested = ref.watch(coachSuggestedTacticProvider);

    // **HIS NAME IS NOT IN HIS OWN SENTENCE.** The header read `COACH COLIN
    // SUGGESTS COUNTER ATTACK`, which is him talking about himself in the third
    // person — on a bubble with his face on it, coming out of his own orb, on a
    // card the player opened by tapping him. Nobody introduces themselves at
    // the start of every sentence.
    //
    // **And no new copy was needed, which is the point.** Making him say "I
    // suggest" means a new `t()` key in ten catalogues, generated from a repo
    // this one does not own; taking the name OUT needs nothing. `coach.label`
    // is still what the SHEET-level lines are titled with, where there is no
    // face beside them to say who is speaking.
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (suggested == null)
          Text(
            t('coach.label').toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: kit.accentBright,
            ),
          ),
        if (suggested != null) ...[
          Text(
            // CAPS, like the two words either side of it. One line reading
            // `COACH COLIN Suggestion: Counter Attack` is three different
            // treatments of one sentence.
            t('coach.suggestion_label').toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: kit.textMuted,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameIcon(
                tacticIconName(suggested),
                size: 11,
                color: tacticColor(context, suggested),
              ),
              const SizedBox(width: 3),
              Text(
                t('strategy.$suggested.name').toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: tacticColor(context, suggested),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
