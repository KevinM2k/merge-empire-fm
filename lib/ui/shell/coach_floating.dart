/// Coach Colin, following the player across every tab. Ported from
/// `../merge-empire-fc/src/ui/components/CoachFloating.js` and its styles.
///
/// **He existed on one screen out of five.** The Play tab had his bubble on a
/// dock orb and the other four had nothing, while the catalogue carried a
/// hundred and twenty things for him to say — see `coach_tips.dart`. This is the
/// surface those go on.
///
/// Three things it does, and each is the JS's:
///
/// - **A quiet head with an attention nudge.** He is not a notification: the
///   head sits in the corner pulsing gently and says nothing until it is tapped.
/// - **Tap to hear it, tap again to be rid of it.** The bubble opens on the
///   first tap; a second tap on the head, the X, or a tap anywhere outside it
///   dismisses. Leaving it open-but-ignorable read as "it will not go away".
/// - **A dismissal MUTES the tip rather than closing a window.** Ten minutes for
///   most, a day for the ones about a decision rather than a moment, and
///   `priority` tips ignore the mute entirely so an urgent signal still gets
///   through. Kept in the save at `ui.coachDismissals`, so it survives a restart
///   the way the player would expect a "not now" to.
///
/// **While the bubble is open, nothing may re-render it.** That is load-bearing
/// in the JS and it is the same here: swapping the text under somebody who is
/// reading it looks like the tip auto-dismissing after a few seconds. The tip is
/// captured when it opens and held until it closes.
///
/// **The ref-counted suppression is not ported, because there is nothing left for
/// it to do.** The JS appends the head to `document.body` at `z-index: 20000`, so
/// every modal in the app has to tell it to step aside — and a COUNT is needed
/// rather than a flag, because a sheet can open a sheet and only the last close
/// should bring him back. All of that is bookkeeping for a decision the DOM made
/// on its behalf. Here he lives in the shell's own `Stack`, below the
/// `Navigator`: every popup in this app is a route (the three shapes all go
/// through `showDialog` or a modal sheet), so a modal covers him by construction
/// and there is no signal to co-ordinate. Porting the counter would have been
/// porting a workaround.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart'
    show
        CoachAlertBadge,
        CoachBubbleTail,
        coachPortrait,
        coachScrim,
        coachTailSize,
        coachTailTipX;
import 'package:merge_empire_fc/ui/shell/coach_tips.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/util/time.dart';

/// The dismissal ledger, if the save has one: tip key to the timestamp it may be
/// said again. Read-only, and it does NOT create the branch — a question about
/// the save must not write to it, or every build leaves a `coachDismissals: {}`
/// behind and the save is dirty for having been looked at.
Map<String, dynamic>? _ledger(Map<String, dynamic>? save) {
  final ui = save?['ui'];
  final out = ui is Map<String, dynamic> ? ui['coachDismissals'] : null;
  return out is Map<String, dynamic> ? out : null;
}

/// Is this tip currently muted?
///
/// Expired entries are pruned when the ledger is read, so it cannot grow without
/// bound over a long session — the JS sweeps the whole thing on every update,
/// which is the same result for a map that only ever holds what a player has
/// actually dismissed.
bool coachTipMuted(Map<String, dynamic>? save, FloatingTip tip, int nowMs) {
  if (tip.priority) return false;
  final ledger = _ledger(save);
  if (ledger == null) return false;
  ledger.removeWhere((_, until) => until is num && until <= nowMs);
  final until = ledger[tip.dismissKey];
  return until is num && until > nowMs;
}

/// Mute a tip for its own cooldown. The one place the branch is created, because
/// this is the one place there is something to put in it.
void dismissCoachTip(Map<String, dynamic>? save, FloatingTip tip, int nowMs) {
  if (save == null) return;
  final ui = save.putIfAbsent('ui', () => <String, dynamic>{});
  if (ui is! Map<String, dynamic>) return;
  final ledger = ui.putIfAbsent('coachDismissals', () => <String, dynamic>{});
  if (ledger is! Map<String, dynamic>) return;
  ledger[tip.dismissKey] = nowMs + tip.cooldown.inMilliseconds;
}

/// What Colin would say on this tab, before the mute is considered.
final coachFloatingTipProvider = Provider.family<FloatingTip?, ShellTab>((
  ref,
  tab,
) {
  ref.watch(saveRevisionProvider);
  return coachTipFor(ref.watch(gameProvider).state, tab);
});

class CoachFloating extends ConsumerStatefulWidget {
  const CoachFloating({required this.tab, super.key});

  /// Which tab is in front of the player. His pool is tab-scoped, and the home
  /// tab has him on a dock orb already so it shows nothing here.
  final ShellTab tab;

  @override
  ConsumerState<CoachFloating> createState() => _CoachFloatingState();
}

class _CoachFloatingState extends ConsumerState<CoachFloating> {
  /// The tip the bubble is showing, captured when it opened.
  ///
  /// **Held, not re-read.** A tip that changed under an open bubble would swap
  /// the sentence somebody is halfway through, which reads as the app losing
  /// interest in its own advice.
  FloatingTip? _open;

  /// The head's own gentle pulse. Its own clock rather than an implicit
  /// animation, because it is a loop.
  late final Widget _head = const _CoachHead();

  @override
  void didUpdateWidget(CoachFloating old) {
    super.didUpdateWidget(old);
    // **WHAT HE SAID WAS ABOUT THE PAGE YOU WERE ON.** Carrying an open bubble
    // to the next screen is a caption for the wrong picture — and the pool it
    // came from is per-tab, so the sentence on screen would not even be one this
    // tab has to offer. Closed rather than dismissed: the player has not said
    // they are finished with it, so it must not be muted for ten minutes.
    if (old.tab != widget.tab && _open != null) {
      setState(() => _open = null);
    }
  }

  void _dismiss(FloatingTip tip) {
    dismissCoachTip(ref.read(gameProvider).state, tip, now());
    ref.read(gameProvider).scheduleSave();
    setState(() => _open = null);
  }

  @override
  Widget build(BuildContext context) {
    final tip = ref.watch(coachFloatingTipProvider(widget.tab));
    // Once it is open it stays open, whatever the pool does underneath.
    final showing = _open ?? tip;
    if (showing == null) return const SizedBox.shrink();
    if (_open == null &&
        coachTipMuted(ref.watch(gameProvider).state, showing, now())) {
      return const SizedBox.shrink();
    }

    final kit = Theme.of(context).extension<KitTheme>()!;
    return Stack(
      key: const ValueKey('coach-floating'),
      children: [
        // The tap-outside catcher, and only while the bubble is open: an
        // unrelated tap must not clear the quiet nudge, only a read one.
        if (_open != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _dismiss(_open!),
              // **AND IT DIMS THE PAGE, like the home one.** This was a fully
              // transparent layer, so the same speech bubble pushed the page
              // back on the home tab and floated on a live screen everywhere
              // else — see [coachScrim].
              child: const ColoredBox(
                color: coachScrim,
                child: SizedBox.expand(),
              ),
            ),
          ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 10,
          child: SafeArea(
            top: false,
            // **ABOVE HIM, NOT BESIDE HIM**, and the tail is why. The wedge
            // drops out of the bubble's bottom-left toward his face — beside him
            // it was pointing past his shoulder into the HUD, which is a bubble
            // attributed to the coin counter. He goes at the foot of the stack
            // and what he says goes over his head, the way the home page has it.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_open != null) ...[
                  _Bubble(
                    key: const ValueKey('coach-floating-bubble'),
                    text: _open!.text,
                    accent: kit.accent,
                    onClose: () => _dismiss(_open!),
                  ),
                  // **The tail, so it reads as him SAYING it.** Every screen but
                  // the home page had a plain panel with no speaker, which is a
                  // caption rather than a line of dialogue. Same wedge the home
                  // page draws — see [CoachBubbleTail].
                  Padding(
                    // **The POINT over the middle of the head below it**, which
                    // is the wedge's [coachTailTipX] rather than its box — the
                    // disc is 44 across and its middle is 22 in, so the box
                    // starts at 22 minus the tip's own offset.
                    padding: const EdgeInsets.only(left: 22 - coachTailTipX),
                    child: CustomPaint(
                      key: const ValueKey('coach-floating-tail'),
                      size: coachTailSize,
                      painter: CoachBubbleTail(
                        fill: kit.surface,
                        edge: kit.accent,
                      ),
                    ),
                  ),
                ],
                Semantics(
                  button: true,
                  label: t('coach.aria.has_message'),
                  child: GestureDetector(
                    key: const ValueKey('coach-floating-head'),
                    onTap: () => _open == null
                        // Reading it is a state change; being finished with it
                        // is a dismissal. Same as the X.
                        ? setState(() => _open = showing)
                        : _dismiss(_open!),
                    child: _head,
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

/// The head: his portrait in a ringed disc, pulsing so it reads as waiting to be
/// tapped rather than as furniture.
class _CoachHead extends StatefulWidget {
  const _CoachHead();

  @override
  State<_CoachHead> createState() => _CoachHeadState();
}

class _CoachHeadState extends State<_CoachHead>
    with SingleTickerProviderStateMixin {
  static const double _size = 56;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    // The JS's 1.8s. Slow enough to read as breathing rather than as an alarm.
    duration: const Duration(milliseconds: 1800),
  );

  void _sync() {
    final run = !MediaQuery.of(context).disableAnimations;
    if (run == _pulse.isAnimating) return;
    if (run) {
      _pulse.repeat();
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value;
        return SizedBox(
          width: _size + 12,
          height: _size + 12,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The expanding ring. It leaves the disc and fades, which is what
              // says "look at me" without moving the thing you have to hit.
              Opacity(
                opacity: (1 - t) * 0.55,
                child: Container(
                  width: _size + t * 12,
                  height: _size + t * 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: kit.accent, width: 2),
                  ),
                ),
              ),
              Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kit.surface,
                  border: Border.all(color: kit.accent, width: 2.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x8C000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                // Clipped INSIDE the ring rather than on the same box: the disc
                // needs to clip his portrait and the ring needs to escape, and
                // one box cannot do both.
                child: ClipOval(
                  child: ArtImage(
                    path: coachPortrait,
                    fit: BoxFit.cover,
                    fallback: Center(
                      child: Icon(Icons.sports, size: 24, color: kit.accent),
                    ),
                  ),
                ),
              ),
              // The badge. A single character, because a count would imply
              // there is a list of them — and it is the DOCK's badge, shared,
              // because there were two of these and only the dock's moved.
              const Positioned(
                right: 0,
                top: 0,
                child: CoachAlertBadge(),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// What he actually says.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.accent,
    required this.onClose,
    super.key,
  });

  final String text;
  final Color accent;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kit.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x8C000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    // His name over the line, so the voice is attributed and the
                    // copy is free to speak in the first person — the same
                    // decision `coach_card.dart` makes.
                    t('coach.label').toUpperCase(),
                    style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: t('coach.aria.dismiss'),
                  child: GestureDetector(
                    key: const ValueKey('coach-floating-close'),
                    onTap: onClose,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 16, color: kit.textMuted),
                    ),
                  ),
                ),
              ],
            ),
            Text(
              text,
              style: TextStyle(
                color: kit.textMuted,
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
