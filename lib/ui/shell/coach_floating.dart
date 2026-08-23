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
        CoachFace,
        CoachSpeechBubble,
        coachBubbleEdge,
        coachBubbleTextStyle,
        coachLabelStyle,
        coachScrim,
        coachTailSize,
        coachTailTipX;
import 'package:merge_empire_fc/ui/shell/coach_tips.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
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
  /// **Through `update`, so the tree hears about it.** The mute lands in the
  /// save and the head has to go with it — writing the map directly and only
  /// scheduling a save left him standing there, dismissed, until something else
  /// happened to move the revision.
  void _dismiss(FloatingTip tip) {
    ref.read(gameProvider).update((s) => dismissCoachTip(s, tip, now()));
  }

  @override
  Widget build(BuildContext context) {
    // **The REVISION, not the game object.** `gameProvider` hands out the same
    // instance forever, so watching it never rebuilds anything — and the mute
    // this reads is written into that same map. Without this a dismissal left
    // him standing there until something else happened to move the tree.
    ref.watch(saveRevisionProvider);
    final tip = ref.watch(coachFloatingTipProvider(widget.tab));
    if (tip == null) return const SizedBox.shrink();
    if (coachTipMuted(ref.watch(gameProvider).state, tip, now())) {
      return const SizedBox.shrink();
    }
    return CoachCorner(
      // **Keyed on the TAB.** What he said was about the page you were on, so
      // carrying an open bubble to the next screen is a caption for the wrong
      // picture — and the pool it came from is per-tab, so the sentence would
      // not even be one this tab has to offer. A new key is a new corner, which
      // closes the old one without dismissing it: the player has not said they
      // are finished with it, so it must not be muted for ten minutes.
      key: ValueKey('coach-floating-${widget.tab}'),
      idPrefix: 'coach-floating',
      text: tip.text,
      onDismissed: () => _dismiss(tip),
    );
  }
}

/// **THE ONE SHAPE COLIN TAKES when he is annotating a screen** rather than
/// asking a question: a head in the BOTTOM-LEFT corner that says nothing until
/// it is tapped, and his line over it in the bubble every other surface uses.
///
/// One of it, because there were two and they agreed about nothing. The shell's
/// floating coach was this; the League and Training sheets printed a portrait
/// and two lines of grey text at the TOP of the list, so the same man arrived
/// in a different place, in a different size, in a different voice, depending
/// which list you had opened — reported as not liking where he pops on
/// Fixtures, and as wanting him always bottom left in the same format.
///
/// **A sheet is a route, so it covers the shell's own corner** — which is why
/// the sheets cannot simply rely on `CoachFloating` and mount one of these
/// instead. See [withSubTabCoach].
class CoachCorner extends StatefulWidget {
  const CoachCorner({
    required this.text,
    required this.idPrefix,
    this.onDismissed,
    this.pulse = true,
    this.startOpen = false,
    this.bubbleKey,
    super.key,
  });

  /// His line. Captured when the bubble opens and held until it closes —
  /// swapping the sentence under somebody reading it looks like the tip
  /// auto-dismissing after a few seconds.
  final String text;

  /// Names this corner's head, bubble and X, so two of them in one tree are
  /// still separable by a test.
  final String idPrefix;

  /// The player has said they are FINISHED with it, which is a different thing
  /// from the bubble closing. Null simply closes.
  final VoidCallback? onDismissed;

  /// The head's ring, expanding and fading on a loop.
  ///
  /// **Off inside a sheet, and that is not a performance note.** In the shell he
  /// is a NUDGE — something has come up and nobody has looked at it — so the
  /// ring is the whole point. In a sheet the player has just opened the list he
  /// is annotating; he is not interrupting, so he holds still. It also keeps a
  /// perpetual animation out of every screen that mounts one, which is what a
  /// `pumpAndSettle` in any of their tests would otherwise hang on.
  final bool pulse;

  /// Open the bubble the moment it mounts, rather than waiting to be tapped.
  ///
  /// **For a line the player did not ask for.** In the shell and in the sheets
  /// he waits — he is offering advice about a page that is not going anywhere.
  /// During a MATCH he is reacting to something that just happened, so the line
  /// has to arrive on its own or it is not a reaction. Everything else about
  /// the shape is the same, which is what was asked for: it comes up from the
  /// bottom, it dims the page, and a tap anywhere is done with it.
  final bool startOpen;

  /// Names the line inside the bubble, for a caller whose test asks for it.
  final Key? bubbleKey;

  @override
  State<CoachCorner> createState() => _CoachCornerState();
}

class _CoachCornerState extends State<CoachCorner> {
  String? _open;

  @override
  void initState() {
    super.initState();
    if (widget.startOpen) _open = widget.text;
  }

  void _dismiss() {
    setState(() => _open = null);
    widget.onDismissed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Stack(
      children: [
        // The tap-outside catcher, and only while the bubble is open: an
        // unrelated tap must not clear the quiet nudge, only a read one.
        if (_open != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismiss,
              // **AND IT DIMS THE PAGE.** This was a fully transparent layer,
              // so the same speech bubble pushed the page back on the home tab
              // and floated on a live screen everywhere else — see
              // [coachScrim].
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
            // drops out of the bubble's bottom-left toward his face — beside
            // him it was pointing past his shoulder into the HUD, which is a
            // bubble attributed to the coin counter.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_open != null) ...[
                  _Bubble(
                    key: ValueKey('${widget.idPrefix}-bubble'),
                    textKey: widget.bubbleKey,
                    text: _open!,
                    onClose: _dismiss,
                  ),
                  // **The tail, so it reads as him SAYING it.** Same wedge the
                  // home page draws — see [CoachBubbleTail].
                  //
                  // **AND IT OVERLAPS THE BUBBLE'S BORDER, which is the "little
                  // tick has a top border" report.** The bubble is rimmed on all
                  // four sides; a wedge sitting directly under it in a `Column`
                  // has that rim running straight across its own top edge, so
                  // the tail reads as a separate shape stuck to the bubble
                  // rather than as part of it. The home page never had it
                  // because its tail is a `Positioned` at `bottom: -10` and has
                  // overlapped all along. Lifted by the border's own width, and
                  // the wedge's fill is opaque so it covers what it is over.
                  Transform.translate(
                    offset: const Offset(0, -coachBubbleEdge),
                    child: Padding(
                      // **The POINT over the middle of the head below it**,
                      // which is the wedge's [coachTailTipX] rather than its
                      // box — the disc is 44 across and its middle is 22 in, so
                      // the box starts at 22 minus the tip's own offset.
                      padding: const EdgeInsets.only(left: 22 - coachTailTipX),
                      child: CustomPaint(
                        key: ValueKey('${widget.idPrefix}-tail'),
                        size: coachTailSize,
                        painter: CoachBubbleTail(
                          fill: kit.surface,
                          edge: kit.accent,
                        ),
                      ),
                    ),
                  ),
                ],
                Semantics(
                  button: true,
                  label: t('coach.aria.has_message'),
                  child: GestureDetector(
                    key: ValueKey('${widget.idPrefix}-head'),
                    // Reading it is a state change; being finished with it is a
                    // dismissal. Same as the X.
                    onTap: () => _open == null
                        ? setState(() => _open = widget.text)
                        : _dismiss(),
                    child: _CoachHead(pulse: widget.pulse),
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
  const _CoachHead({this.pulse = true});

  final bool pulse;

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
    final run = widget.pulse && !MediaQuery.of(context).disableAnimations;
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
                child: const CoachFace(),
              ),
              // The badge. A single character, because a count would imply
              // there is a list of them — and it is the DOCK's badge, shared,
              // because there were two of these and only the dock's moved.
              //
              // **On the same switch as the ring**, and for the same reason: an
              // unread mark on a line the player opened a list to see is a
              // notification for something they are already looking at. It
              // bounces on a loop of its own, so it is also the second thing a
              // `pumpAndSettle` in a sheet's test would hang on.
              if (widget.pulse)
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

/// What he actually says, in the bubble every screen uses — see
/// [CoachSpeechBubble].
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.onClose,
    this.textKey,
    super.key,
  });

  final String text;
  final VoidCallback onClose;
  final Key? textKey;

  @override
  Widget build(BuildContext context) => CoachSpeechBubble(
    // His name over the line, so the voice is attributed and the copy is free
    // to speak in the first person — the same decision `coach_card.dart` makes.
    label: Text(t('coach.label').toUpperCase(), style: coachLabelStyle(context)),
    dismissLabel: t('coach.aria.dismiss'),
    closeKey: const ValueKey('coach-floating-close'),
    onClose: onClose,
    child: Text(text, key: textKey, style: coachBubbleTextStyle(context)),
  );
}
