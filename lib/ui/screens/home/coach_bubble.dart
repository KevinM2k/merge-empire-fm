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
import 'package:merge_empire_fc/engine/cup_engine.dart'
    show prepareCupRound;
import 'package:merge_empire_fc/ui/screens/match/cup_launcher.dart'
    show cupDue;
import 'package:merge_empire_fc/engine/booking_engine.dart'
    show suspendedIn;
import 'package:merge_empire_fc/data/players.dart' show getCardName;
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart'
    show gridCells;
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
import 'package:merge_empire_fc/ui/screens/squad/squad_pickers.dart'
    show setStrategy;

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
    // **AND HE TALKS ABOUT THE FIXTURE THAT IS ACTUALLY NEXT.** `previewFixture`
    // only knows the LEAGUE schedule, so on a cup week he was giving a read on
    // a club the player was not about to play — the head-to-head record, the
    // grudge, the rating gap, all about the wrong opponent, and all agreeing
    // with a card that was also wrong. Reported from the couch together.
    //
    // A cup tie has no league history, no grudge and no table position, so the
    // only read that survives is the rating gap — and that is the one that
    // matters before a knockout.
    final cupTie = cupDue(s) ? prepareCupRound(s) : null;
    if (cupTie != null) {
      final gap = preview.effectiveSquadRating - cupTie.opponentRating;
      if (gap <= -5) {
        tips.add((
          id: 'gap_higher',
          text: t('manager.rating_gap_higher', {'opp': cupTie.opponentName}),
        ));
      } else if (gap >= 5) {
        tips.add((
          id: 'gap_lower',
          text: t('manager.rating_gap_lower', {'opp': cupTie.opponentName}),
        ));
      }
    }
    final opponent = preview.opponentName;
    final ourRating = preview.effectiveSquadRating;
    final theirRating = preview.effectiveOppRating;

    // A grudge is the one thing that makes a weaker side dangerous, so it
    // outranks the rating comparison rather than sitting under it.
    //
    // **None of the league reads apply to a cup tie** — the grudge, the
    // head-to-head and the table are all about a fixture that is not the next
    // one. See [cupTie].
    if (cupTie == null && preview.grudgeBoost > 0) {
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

    // **WHO CANNOT PLAY THIS ONE, above every read on the opponent.** Asked
    // for from the couch alongside the red card: he should mention a
    // suspension the way he mentions an injury — and he was mentioning
    // neither, so both went in. It outranks the rating comparison because it
    // is the one thing on this bubble the manager has to ACT on before kick-off:
    // a hole in the eleven is a decision, a rating gap is a mood.
    //
    // Named, and joined, because "someone is banned" is not usable advice. The
    // ban is `booking_engine.suspendedIn`; the injury is the card's own flag.
    final banned = suspendedIn(s);
    final out = <String>[];
    final hurt = <String>[];
    for (final raw in gridCells(s)) {
      final card = CardInstance.from(raw);
      if (card == null) continue;
      final named = getCardName(card.raw, t('common.veteran'));
      if (banned.contains(card.instanceId)) {
        out.add(named);
      } else if (card.injured) {
        hurt.add(named);
      }
    }
    if (out.isNotEmpty) {
      tips.add((
        id: 'suspended',
        text: tPoolStable('manager.suspended', out.join('|'), {
          'names': out.join(', '),
        }),
      ));
    }
    if (hurt.isNotEmpty) {
      tips.add((
        id: 'injured',
        text: tPoolStable('manager.injured_out', hurt.join('|'), {
          'names': hurt.join(', '),
        }),
      ));
    }

    if (theirRating != null && cupTie == null) {
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
/// **THE TACTIC HE WOULD PICK, whether or not it is the one already set.**
///
/// [coachSuggestedTacticProvider] is the same question narrowed to "and it is
/// not what you have" — which is the right question for the match screen, where
/// a suggestion is an offer to CHANGE something. It is the wrong one for his
/// header, which is a statement of his read: a manager already playing the
/// right way should see him agree, not see him fall silent. Reported from the
/// couch, twice — first that the header dropped his name when he had advice,
/// then that it dropped the advice when the advice was already taken.
final coachTacticPickProvider = savePick<String?>(coachTacticPick);

/// The pick itself, as a function — so the narrowed provider below can ask the
/// same question of the same save without a second copy of the arithmetic.
String? coachTacticPick(Map<String, dynamic> s) {
  final preview = previewFixture(s);
  if (preview == null) return null;
  return suggestTactic(
    preview.effAttack,
    preview.effDefence,
    preview.effOppAttackRating ?? preview.effAttack,
    preview.effOppDefenceRating ?? preview.effDefence,
    oppAttackRatio: preview.oppAttackRatio,
  ).id;
}

/// The pick, but only when it is a CHANGE — null when the squad is already set
/// up that way. What the match screen offers a switch for.
final coachSuggestedTacticProvider = savePick<String?>((s) {
  final pick = coachTacticPick(s);
  return pick == null || pick == _map(s['squad'])?['strategyId'] ? null : pick;
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
    // **NOT inside a `SafeArea`, because the anchor is not either.** Every
    // offset below is measured in GLOBAL coordinates off the dock's own box, so
    // a route that insets its child pushes the bubble up by the height of the
    // home indicator — reported as the popup sitting too far away from him,
    // which on a modern phone is thirty-four pixels of daylight between the
    // tail and his head.
    useSafeArea: false,
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
    // The tail hangs ten below the bubble, so ten of gap puts its point on the
    // top of his disc — which is where the floating coach's sits, that one being
    // a `Column` with the head directly under the wedge.
    final bottom = anchor == null
        ? 96.0
        : math.max(8.0, screen.height - anchor.top + 10);
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
      // **The bubble every other screen uses**, rather than a second one that
      // happened to live here — see [CoachSpeechBubble]. This was a translucent
      // panel with a 1px rim and the X hanging off the outside of its corner
      // while the floating coach had a rimmed card with the X in its header, so
      // the same man's advice arrived in two different windows.
      child: CoachSpeechBubble(
        key: const ValueKey('coach-bubble'),
        maxWidth: maxWidth,
        label: const _CoachLabel(),
        dismissLabel: t('manager_hint.aria.dismiss'),
        closeKey: const ValueKey('coach-bubble-close'),
        onClose: () => Navigator.of(context).pop(),
        // NO PORTRAIT. The dock button already IS his face and this springs out
        // of it, so a second head in the bubble was the same man twice — which
        // is exactly what it looked like.
        child: InkWell(
          onTap: tips.length > 1 ? _next : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The line itself fades between tips rather than snapping, so a
              // cycle mid-read is a change you can see coming.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  tip.text,
                  key: ValueKey('coach-tip-${tip.id}'),
                  style: coachBubbleTextStyle(context),
                ),
              ),
              // DOTS, not a "2 / 3" button: the count is the only thing a
              // fraction adds, and it reads as a control rather than as a place
              // in a short list.
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
                    fill: kit.surface.withValues(alpha: 0.96),
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
    // **HIS READ, not only his disagreements** — see
    // [coachTacticPickProvider].
    final suggested = ref.watch(coachTacticPickProvider);

    // **HIS NAME IS ALWAYS THERE, and that reverses a decision.**
    //
    // It used to come OFF whenever there was a tactic to suggest, on the
    // reasoning that `COACH COLIN SUGGESTS COUNTER ATTACK` is him talking about
    // himself in the third person — on a bubble with his face on it, coming out
    // of his own orb, on a card the player opened by tapping him.
    //
    // What that produced is a header that changes its own shape depending on
    // whether he has advice: every other time he appears it says COACH COLIN,
    // and on the one that matters it says SUGGESTS. Reported from the couch —
    // it should always read the same. A name that is redundant is a smaller
    // cost than a title nobody can predict, and the two states were never
    // distinguishable as "the same header with more in it".
    //
    // **Still no new copy**, which was the point of the earlier note too:
    // `coach.label` and `coach.suggestion_label` are both shipped, and this is
    // the two of them in a row.
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          t('coach.label').toUpperCase(),
          style: TextStyle(
            fontSize: 12,
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
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: kit.textMuted,
            ),
          ),
          // **THE TACTIC IS A BUTTON.** He names the one he would pick and the
          // player then has to go and find it in a dropdown on another card —
          // two steps to agree with advice that is already on screen. Asked for
          // from the couch: tapping it should just set it.
          //
          // `setStrategy` is the picker's own writer, so the dropdown that says
          // TACTIC — and the next-match card's own multipliers, and the arrow —
          // all follow from the same key. Nothing here has to tell them.
          //
          // It goes quiet rather than away once it is taken: `coachTacticPick`
          // is his READ, not his disagreements, so he keeps agreeing with you.
          GestureDetector(
            key: ValueKey('coach-take-$suggested'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setStrategy(ref, suggested),
            child: Row(
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
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: tacticColor(context, suggested),
                    // It is a control, so it looks like one — the one mark on
                    // this header that says a finger belongs here.
                    decoration: TextDecoration.underline,
                    decorationColor: tacticColor(
                      context,
                      suggested,
                    ).withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
