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
    barrierColor: Colors.black26,
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
    // The wedge sits over the middle of the disc below it. Clamped, so a dock
    // near the edge of a narrow screen cannot push it off the bubble.
    final double tailLeft = anchor == null
        ? 12.0
        : (anchor.center.dx - left - 9).clamp(
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
              child: IconButton(
                key: const ValueKey('coach-bubble-close'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: t('common.close'),
                icon: const Icon(Icons.close, size: 14),
                onPressed: () => Navigator.of(context).pop(),
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
                  size: const Size(18, 11),
                  painter: CoachBubbleTail(
                    fill: kit.surface.withValues(alpha: 0.94),
                    edge: kit.accent,
                  ),
                ),
              ),
            ],
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
class _CoachLabel extends ConsumerWidget {
  const _CoachLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final suggested = ref.watch(coachSuggestedTacticProvider);

    return Wrap(
      spacing: 4,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
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
