/// The three-two-one-GO a drill kicks off on.
///
/// **A DRILL USED TO START WHILE THE PLAYER WAS STILL FINDING THE BOARD.**
/// Pitch Invaders had a 600ms "here they come" beat, Goalkeeper Practice
/// started its watch bar in `initState`, and Keepy Uppys dropped the ball the
/// instant the arena had been measured — so the first pop-up, the first shot
/// and the first fall were all things that had already happened by the time
/// anybody was looking. Asked for from the couch: count me in.
///
/// **ONE OF THESE, NOT THREE.** The three screens run different loops and
/// nothing else about them is shared, but the beat before the loop starts is
/// the same beat, and three copies of it is three places for it to drift —
/// the same reason [MiniGameStat] lives beside the header.
///
/// The shape of each beat is the one the couch described: the glyph rushes in
/// oversized, settles, then shrinks away as it fades. That is [countdownScale]
/// and [countdownFade] over one controller per beat, which is why the digit
/// reads as coming AT the player rather than merely appearing — a fade alone
/// is a caption, and this is a kick-off.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// One digit, and then the kick-off.
///
/// Three eight-hundreds and a shorter GO is 2.95 seconds — the three-second
/// count that was asked for, with the whistle riding the tail of it rather
/// than adding a fourth second of waiting.
const int countdownBeatMs = 800;
const int countdownGoMs = 550;

/// How long the whole thing takes. **The screens' lead-in is THIS**, not the
/// spec's `leadInMs`: the countdown replaced that beat, and a test that waits
/// for kick-off has to wait for the count. `Whack.leadInMs` stays in
/// `mini_games.dart` because `mini_games_test.dart` pins it against the JS.
const int miniGameCountdownMs = countdownBeatMs * 3 + countdownGoMs;

/// What the digits say. Index 3 — past the end — is the kick-off.
const List<String> countdownBeats = ['3', '2', '1'];

/// The glyph rushes in, settles, then shrinks away.
///
/// The weights are the description read back: the zoom is over in the first
/// third (`easeOutCubic`, so it decelerates into place rather than arriving at
/// speed), it holds long enough to be read, and the last 40% is the shrink the
/// fade rides.
final TweenSequence<double> countdownScale = TweenSequence<double>([
  TweenSequenceItem(
    tween: Tween<double>(
      begin: 2.6,
      end: 1,
    ).chain(CurveTween(curve: Curves.easeOutCubic)),
    weight: 34,
  ),
  TweenSequenceItem(tween: ConstantTween<double>(1), weight: 26),
  TweenSequenceItem(
    tween: Tween<double>(
      begin: 1,
      end: 0.5,
    ).chain(CurveTween(curve: Curves.easeInCubic)),
    weight: 40,
  ),
]);

/// In fast, hold, out with the shrink. The out is the same 40% as the scale's,
/// so the glyph is gone the moment it stops moving.
final TweenSequence<double> countdownFade = TweenSequence<double>([
  TweenSequenceItem(
    tween: Tween<double>(
      begin: 0,
      end: 1,
    ).chain(CurveTween(curve: Curves.easeOut)),
    weight: 14,
  ),
  TweenSequenceItem(tween: ConstantTween<double>(1), weight: 46),
  TweenSequenceItem(
    tween: Tween<double>(
      begin: 1,
      end: 0,
    ).chain(CurveTween(curve: Curves.easeIn)),
    weight: 40,
  ),
]);

/// The scrim's own curve, and it only runs on GO.
///
/// **THE DIM USED TO PULSE ONCE PER DIGIT.** The scrim was `countdownScrim *
/// fade`, and the fade is per-beat — so it went out with the 3 and came back
/// with the 2, and the board flashed brighter three times during a count that
/// is meant to be one held breath. Reported from the couch: keep it on until
/// the countdown is finished. So the digits leave it flat and only GO takes it
/// away, on the same tail the glyph shrinks off — no fade-in on the front,
/// because that front is where the dip was.
final TweenSequence<double> countdownScrimOut = TweenSequence<double>([
  TweenSequenceItem(tween: ConstantTween<double>(1), weight: 60),
  TweenSequenceItem(
    tween: Tween<double>(
      begin: 1,
      end: 0,
    ).chain(CurveTween(curve: Curves.easeIn)),
    weight: 40,
  ),
]);

/// The scrim under the glyph at full opacity. Light enough that the board the
/// player is about to play is still legible behind the count.
const double countdownScrim = 0.34;

/// Lays over the game area. The caller keeps it in the tree until [onDone].
class MiniGameCountdown extends ConsumerStatefulWidget {
  const MiniGameCountdown({super.key, required this.onDone});

  /// Called once, after GO. The caller starts its loop and takes this down.
  final VoidCallback onDone;

  @override
  ConsumerState<MiniGameCountdown> createState() => _MiniGameCountdownState();
}

class _MiniGameCountdownState extends ConsumerState<MiniGameCountdown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: countdownBeatMs),
  );

  /// 0..2 are the digits; [countdownBeats.length] is GO.
  int _step = 0;

  bool get _isGo => _step >= countdownBeats.length;

  @override
  void initState() {
    super.initState();
    _beat.addStatusListener(_onBeat);
    _cue();
    _beat.forward(from: 0);
  }

  void _onBeat(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_isGo) {
      // **NOT FROM INSIDE THE LISTENER.** The caller's answer to this is to
      // take the widget down, which disposes the controller that is currently
      // notifying — so it waits for the frame to be over.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onDone();
      });
      return;
    }
    setState(() => _step++);
    _beat.duration = Duration(
      milliseconds: _isGo ? countdownGoMs : countdownBeatMs,
    );
    _cue();
    _beat.forward(from: 0);
  }

  /// A beep on each digit and the referee's whistle on GO, which is what
  /// actually starts a game of football.
  void _cue() => unawaited(
    ref.read(soundServiceProvider).play(_isGo ? 'whistle' : 'pop'),
  );

  @override
  void dispose() {
    _beat.removeStatusListener(_onBeat);
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final go = _isGo;
    final label = go ? t('mg.countdown_go') : countdownBeats[_step];

    // Nothing under here is tappable yet — the screens gate their own taps on
    // the count as well, because a ball frozen mid-air is still a hit target.
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          // GO is three glyphs where a digit is one, so it is asked to be
          // smaller or it runs off a narrow board.
          final size =
              math.min(112.0, box.biggest.shortestSide * 0.42) *
              (go ? 0.62 : 1);
          return AnimatedBuilder(
            animation: _beat,
            builder: (context, _) {
              final fade = countdownFade.evaluate(_beat).clamp(0.0, 1.0);
              // One dim for the whole count — see [countdownScrimOut].
              final scrim = go
                  ? countdownScrimOut.evaluate(_beat).clamp(0.0, 1.0)
                  : 1.0;
              return ColoredBox(
                color: Colors.black.withValues(
                  alpha: countdownScrim * scrim,
                ),
                child: Center(
                  child: Opacity(
                    opacity: fade,
                    child: Transform.scale(
                      scale: countdownScale.evaluate(_beat),
                      child: Text(
                        label,
                        key: ValueKey(
                          go ? 'mg-countdown-go' : 'mg-countdown-$label',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: size,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          // GO takes the club's accent; the digits stay white
                          // so the one that means "play" is the one that is
                          // coloured.
                          color: go ? kit.accentBright : Colors.white,
                          shadows: const [
                            Shadow(color: Color(0xCC000000), blurRadius: 18),
                            Shadow(
                              color: Color(0x99000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
