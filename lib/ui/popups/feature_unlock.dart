/// The centre-screen UNLOCKED splash. Ported from `components/FeatureUnlock.js`.
///
/// **A facility build was silent.** The port took the coins, ticked the tile up
/// and said nothing — so the one moment in the Club screen a player is paying for
/// looked identical to a number changing. This is the payoff beat: the card
/// arrives rotated and undersized, snaps square, and holds for three seconds
/// while a sunray turns behind the icon.
///
/// **A TIER UP is the same card with a different eyebrow**, deliberately: the two
/// are the same kind of event — something the club now has that it did not — and
/// giving them different shapes would make the smaller one read as a lesser
/// thing rather than as the next step of the same thing.
///
/// It dismisses itself, and a tap anywhere dismisses it early. Nothing here is a
/// decision, so nothing here needs a button.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';

/// How long it holds before taking itself away.
const Duration featureUnlockHold = Duration(milliseconds: 3200);

/// Show the splash and return once it is gone.
Future<void> showFeatureUnlock(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Widget icon,
  Color accent = const Color(0xFFFFD700),
  bool isTierUp = false,

  /// A second thing the build unlocked — kit colours, a mini-game. It rides on
  /// the same card rather than queueing a second popup behind this one.
  String? bonus,
  int starCount = 3,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (_) => _FeatureUnlock(
      title: title,
      subtitle: subtitle,
      icon: icon,
      accent: accent,
      isTierUp: isTierUp,
      bonus: bonus,
      starCount: starCount,
    ),
  );
}

class _FeatureUnlock extends StatefulWidget {
  const _FeatureUnlock({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.isTierUp,
    required this.bonus,
    required this.starCount,
  });

  final String title;
  final String? subtitle;
  final Widget icon;
  final Color accent;
  final bool isTierUp;
  final String? bonus;
  final int starCount;

  @override
  State<_FeatureUnlock> createState() => _FeatureUnlockState();
}

class _FeatureUnlockState extends State<_FeatureUnlock>
    with TickerProviderStateMixin {
  /// The arrival: rotated and small, snapping square with an overshoot.
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

  /// The sunray behind the icon, and the glow around the card. One clock for
  /// both, because they are one ornament.
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  Timer? _dismiss;

  @override
  void initState() {
    super.initState();
    _in.forward();
    _dismiss = Timer(featureUnlockHold, _close);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A three-second hold with a turning ray is exactly what reduce-motion is
    // for — the card still arrives and still says what was unlocked.
    if (MediaQuery.of(context).disableAnimations) {
      if (_idle.isAnimating) _idle.stop();
      _in.value = 1;
    } else if (!_idle.isAnimating) {
      _idle.repeat();
    }
  }

  void _close() {
    _dismiss?.cancel();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _dismiss?.cancel();
    _in.dispose();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The card's ground is the ACCENT's own hue darkened, not one dark for all
    // three: a silver tier-up on a gold-tinted card reads as gold.
    final ground = widget.accent == const Color(0xFFAAAAAA)
        ? const [Color(0xFF141414), Color(0xFF222222), Color(0xFF141414)]
        : widget.accent == const Color(0xFFCD7F32)
        ? const [Color(0xFF1A0F00), Color(0xFF2E1A00), Color(0xFF1A0F00)]
        : const [Color(0xFF1A1200), Color(0xFF2E2000), Color(0xFF1A1200)];

    return GestureDetector(
      // Anywhere. Nothing on this card is a decision.
      onTap: _close,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_in, _idle]),
          builder: (context, _) {
            final t = Curves.easeOutBack.transform(_in.value);
            return Transform.rotate(
              angle: (1 - t) * -0.105,
              child: Transform.scale(
                scale: 0.4 + 0.6 * t,
                child: Opacity(
                  opacity: _in.value.clamp(0.0, 1.0),
                  child: _card(ground),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _card(List<Color> ground) {
    // Breathes twice over the hold rather than pulsing continuously — the card is
    // only up for three seconds, and a fast loop reads as an alarm.
    final glow = (math.sin(_idle.value * math.pi * 12) * 0.5 + 0.5) * 0.4;

    return Material(
      color: Colors.transparent,
      child: Container(
        key: const ValueKey('feature-unlock'),
        width: math.min(300, MediaQuery.sizeOf(context).width * 0.84),
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-0.6, -1),
            end: const Alignment(0.6, 1),
            colors: ground,
          ),
          border: Border.all(color: widget.accent, width: 2),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            const BoxShadow(
              color: Color(0xB3000000),
              blurRadius: 60,
              offset: Offset(0, 24),
            ),
            BoxShadow(
              color: widget.accent.withValues(alpha: glow),
              blurRadius: 40,
              spreadRadius: 12,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The sunray, turning behind everything.
              Positioned.fill(
                child: IgnorePointer(
                  child: Transform.rotate(
                    angle: _idle.value * 2 * math.pi,
                    child: CustomPaint(
                      painter: _RayPainter(colour: widget.accent),
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.isTierUp
                        ? '⬆ ${t('feature.tier_up')}'
                        : '🔓 ${t('feature.unlocked')}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
                      color: widget.accent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.4),
                        colors: [
                          widget.accent.withValues(alpha: 0.28),
                          widget.accent.withValues(alpha: 0.06),
                        ],
                      ),
                      border: Border.all(
                        color: widget.accent.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: Center(child: widget.icon),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 21,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Color(0xFFE8D090),
                      ),
                    ),
                  ],
                  // A second unlock rides on the same card rather than queueing
                  // another popup behind this one.
                  if (widget.bonus != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        widget.bonus!,
                        key: const ValueKey('feature-unlock-bonus'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF00E5FF),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < widget.starCount; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            '★',
                            style: TextStyle(
                              fontSize: 14,
                              color: widget.accent.withValues(
                                // Each star lands a beat after the one before,
                                // so the row reads left to right.
                                alpha: (_in.value * 3 - i).clamp(0.0, 1.0),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Twenty-degree spokes of the accent at 7%, which is the JS's
/// `repeating-conic-gradient` — Flutter has no conic gradient, so it is drawn.
class _RayPainter extends CustomPainter {
  const _RayPainter({required this.colour});

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    // Long enough to reach a corner from the centre whatever the card's shape.
    final r = size.longestSide;
    final paint = Paint()..color = colour.withValues(alpha: 0.07);
    for (var deg = 0; deg < 360; deg += 40) {
      final a = deg * math.pi / 180;
      canvas.drawPath(
        Path()
          ..moveTo(centre.dx, centre.dy)
          ..arcTo(
            Rect.fromCircle(center: centre, radius: r),
            a,
            20 * math.pi / 180,
            false,
          )
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RayPainter old) => old.colour != colour;
}
