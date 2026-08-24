/// A puff of smoke, from `kenney_smoke-particles`.
///
/// **AN ADDITION, NEVER A REPLACEMENT.** `docs/REMAINING.md` names the trap
/// directly: the merge burst is PROCEDURAL and draws at any size in any tier's
/// colours, which a sprite sheet cannot do. So a sprite may only go where there
/// is no effect at all today, or UNDER one that has to stay — and smoke is the
/// one kind of art that can sit under anything, because it is colourless. It
/// reads as displaced air rather than as a second opinion about what tier the
/// card was.
///
/// **Eight frames, played once, and the asset was already here.** `assets/fx/`
/// has shipped `puff_0` to `puff_7` since the packs were imported and nothing in
/// `lib/` named one — the same class of finding as a translated string with no
/// caller, and this file is its caller.
///
/// **Precached, because a first merge that flickered would be worse than no
/// smoke.** Eight 128px PNGs decoded mid-animation is a stutter on exactly the
/// frame the effect exists to decorate.
library;

import 'package:flutter/material.dart';

/// How many frames the pack ships.
const int smokePuffFrames = 8;

/// One puff, start to finish. Short: it is the air moving, not an event.
const Duration smokePuffDuration = Duration(milliseconds: 420);

/// The frame images, in order.
final List<String> smokePuffAssets = [
  for (var i = 0; i < smokePuffFrames; i++) 'assets/fx/puff_$i.png',
];

/// Decode them once, before anything asks for one.
///
/// Call from a widget that is already on screen; a failure is a no-op, because
/// a missing decoration must never be able to fail a boot.
Future<void> precacheSmokePuff(BuildContext context) async {
  for (final asset in smokePuffAssets) {
    try {
      if (!context.mounted) return;
      await precacheImage(AssetImage(asset), context);
    } catch (_) {
      // No smoke. The thing it was decorating still happens.
    }
  }
}

/// Plays the eight frames once and then draws nothing.
///
/// [playing] flipping true starts it. It reports nothing back: unlike the merge
/// burst, nothing waits on smoke.
class SmokePuff extends StatefulWidget {
  const SmokePuff({
    super.key,
    required this.playing,
    this.size = 96,
    this.tint,
  });

  final bool playing;

  /// How wide the puff is drawn. The frames are square.
  final double size;

  /// **Usually null, and that is the point.** Smoke stays smoke; a tint is for
  /// the one case where it has to sit on a background of nearly its own
  /// brightness. It is applied as a `modulate`, so the frame's own shading and
  /// its alpha both survive.
  final Color? tint;

  @override
  State<SmokePuff> createState() => _SmokePuffState();
}

class _SmokePuffState extends State<SmokePuff>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: smokePuffDuration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _clock.forward();
  }

  @override
  void didUpdateWidget(SmokePuff old) {
    super.didUpdateWidget(old);
    if (widget.playing && !old.playing) _clock.forward(from: 0);
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // **Reduce-motion drops it entirely rather than showing frame eight.** A
    // puff is decoration with no information in it, which is the one kind of
    // effect that should simply not happen.
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          if (_clock.value == 0 || _clock.isCompleted) {
            return const SizedBox.shrink();
          }
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Image.asset(
              smokePuffAssets[frameAt(_clock.value)],
              key: const ValueKey('smoke-puff'),
              color: widget.tint,
              colorBlendMode: BlendMode.modulate,
              // It thins as it spreads, which is what stops the last frame
              // popping off the screen.
              opacity: AlwaysStoppedAnimation(1 - _clock.value * 0.85),
              filterQuality: FilterQuality.medium,
            ),
          );
        },
      ),
    );
  }
}

/// Which frame belongs at [t], 0 to 1.
///
/// The last frame is held rather than overrun: `t == 1` is the end of the
/// eighth frame's slot, not the start of a ninth that does not exist.
int frameAt(double t) =>
    (t.clamp(0.0, 1.0) * smokePuffFrames).floor().clamp(0, smokePuffFrames - 1);
