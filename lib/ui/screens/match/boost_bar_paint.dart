/// What says a lift is LIVE: the aura on the pitch, the glow round the
/// figures, the figures' own colour, and the one-at-a-time caption under
/// them.
///
/// **The bar burned for a while and does not now.** A window was a flame
/// across the clock, then the whole bar on fire; the pitch's aura says the
/// same thing with more room and — since it empties clockwise as the window
/// runs down — says how long is left, which the bar never could. Asked for
/// from the couch.
///
/// **Nothing here changes SIZE while animating.** A widget that grows every
/// frame relayouts past any `RepaintBoundary` to the route and repaints the
/// whole shell — the HUD coin count-up has already cost this once. The glow
/// moves opacity and colour inside a fixed box; the pill fades; the aura is
/// a painter over a fixed box.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/engine/match_boost_state.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart' show StatTint;

/// The fire the Roar burns in. Not kit colours and deliberately not: a flame
/// is a flame whatever the club wears, the way the level metals on the trait
/// reel are bronze, silver and gold on every kit.
const Color flameHot = Color(0xFFFFE08A);
const Color flameMid = Color(0xFFFF8A3D);
const Color flameDeep = Color(0xFFD9481C);

/// The gold Sharp Shooting burns in: the feed's own colour for a chance
/// converting, so the bar and the line under it agree.
const Color goldHot = Color(0xFFFFF3C4);
const Color goldMid = Color(0xFFFFC542);
const Color goldDeep = Color(0xFFB8860B);

/// The steel a Bus is drawn in: cool where the other two are hot, because it
/// is the tactical opposite — a wall, not a fire.
const Color busSteel = Color(0xFF5B7C99);
const Color busSteelHot = Color(0xFFA9C2D9);

/// The colour a live window paints everything it touches in — its tile, its
/// row on the sheet, its band, and its aura on the grass.
Color liveBoostColour(String id) => switch (id) {
  'crowd_roar' => flameMid,
  'sharp_shooting' => goldMid,
  _ => busSteel,
};

/// **THE PITCH SHOWS IT TOO.** A boost was a band on the clock and a tinted
/// tile; the one thing on the screen with room to say "something is on" is the
/// pitch, so a live window draws an aura along its edge in its own colour,
/// breathing, and two windows are two rings. Asked for from the couch.
/// One ring: the window's id and how much of it is left, 1 → 0.
typedef AuraRing = ({String id, double left});

class BoostAura extends StatefulWidget {
  const BoostAura({
    super.key,
    required this.rings,
    required this.on,
    required this.minute,
  });

  /// How long a match minute takes on the wall clock, so the ring can empty
  /// SMOOTHLY between ticks rather than stepping once a minute. The clock
  /// only says the minute; the ring glides to it over the minute that follows.
  final Duration minute;

  /// The live windows, in the order they were called — the first is the
  /// outermost ring. **Each ring is a clock**: it starts whole and empties
  /// clockwise from the top as its window runs down, so how long is left is
  /// read off the pitch without a number. Asked for from the couch.
  final List<AuraRing> rings;

  /// Animating, or a still frame for reduced motion and tests.
  final bool on;

  @override
  State<BoostAura> createState() => _BoostAuraState();
}

class _BoostAuraState extends State<BoostAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  /// Where each ring is gliding from and to, and when it set off.
  final Map<String, ({double from, double to, DateTime at})> _glide = {};

  @override
  void initState() {
    super.initState();
    if (widget.on) _t.repeat();
    _retarget();
  }

  @override
  void didUpdateWidget(BoostAura oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.on && !_t.isAnimating) _t.repeat();
    if (!widget.on && _t.isAnimating) _t.stop();
    _retarget();
  }

  /// A new minute: each ring glides from where it is now to the new figure
  /// over the coming minute. A ring that just appeared starts whole.
  void _retarget() {
    final now = DateTime.now();
    final seen = <String>{};
    for (final r in widget.rings) {
      if (seen.contains(r.id)) continue;
      seen.add(r.id);
      final g = _glide[r.id];
      final current = g == null ? 1.0 : _shownOf(g, now);
      if (g == null || g.to != r.left) {
        _glide[r.id] = (from: current, to: r.left, at: now);
      }
    }
    _glide.removeWhere((id, _) => !seen.contains(id));
  }

  double _shownOf(({double from, double to, DateTime at}) g, DateTime now) {
    final ms = widget.minute.inMilliseconds;
    if (ms <= 0 || !widget.on) return g.to;
    final f = (now.difference(g.at).inMilliseconds / ms).clamp(0.0, 1.0);
    return g.from + (g.to - g.from) * f;
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        key: const ValueKey('match-boost-aura'),
        painter: _AuraPainter(
          _t,
          widget.rings,
          (id) => switch (_glide[id]) {
            final g? => _shownOf(g, DateTime.now()),
            null => 1.0,
          },
        ),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _AuraPainter extends CustomPainter {
  _AuraPainter(this.t, this.rings, this.shownOf) : super(repaint: t);

  final Animation<double> t;
  final List<AuraRing> rings;

  /// The ring's fraction as it is being SHOWN — gliding, not stepped.
  final double Function(String id) shownOf;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = t.value * 2 * math.pi;
    // One ring per window id: a second Roar stacked on the first keeps the
    // later end, which is what the strip shows too.
    final order = <String>[];
    for (final r in rings) {
      if (!order.contains(r.id)) order.add(r.id);
    }
    // Each ring sits inside the last, so stacked windows read as stacked.
    for (var i = 0; i < order.length; i++) {
      final id = order[i];
      final colour = liveBoostColour(id);
      final left = shownOf(id).clamp(0.0, 1.0);
      final breathe = 0.5 + 0.5 * math.sin(phase + i * 1.3);
      final inset = 4.0 + i * 10.0;
      final band = 30.0 + 10.0 * breathe;
      final rect = Rect.fromLTWH(
        inset,
        inset,
        size.width - inset * 2,
        size.height - inset * 2,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
      // **THE RING IS A CLOCK.** The path starts at the top centre and runs
      // clockwise; what is drawn is the fraction of the window still to
      // play, so the gap opens from twelve o'clock and eats round.
      final whole = Path()..addRRect(rrect);
      final metric = whole.computeMetrics().first;
      final total = metric.length;
      // `addRRect` starts a quarter of the way round the top edge's corner;
      // shift the start to the top centre so the clock reads from twelve.
      final start = size.width / 2 - inset - rrect.tlRadiusX;
      final drawn = Path();
      final len = total * left;
      final endAt = start + len;
      if (endAt <= total) {
        drawn.addPath(metric.extractPath(start, endAt), Offset.zero);
      } else {
        drawn.addPath(metric.extractPath(start, total), Offset.zero);
        drawn.addPath(metric.extractPath(0, endAt - total), Offset.zero);
      }
      // **THE WHOLE RING GLOWS, and the glow MOVES.** A wide soft wash and
      // a tighter hot one under a hard edge, so it reads as light on the
      // grass rather than a line drawn on it; and the lit part is drawn in
      // segments whose brightness is a slow wave travelling round it, so the
      // glow is alive along its whole length rather than a spot running
      // round a dull line. Asked for from the couch, three times.
      canvas.drawPath(
        drawn,
        Paint()
          ..color = colour.withValues(alpha: 0.32 + 0.18 * breathe)
          ..style = PaintingStyle.stroke
          ..strokeWidth = band
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, band * 0.7),
      );
      if (len > 0) {
        const segments = 36;
        final seg = len / segments;
        for (var k = 0; k < segments; k++) {
          final a = start + seg * k;
          final b = a + seg + 1.0; // a hair of overlap, or the joins show
          final piece = Path();
          if (b <= total) {
            piece.addPath(metric.extractPath(a, b), Offset.zero);
          } else if (a >= total) {
            piece.addPath(metric.extractPath(a - total, b - total), Offset.zero);
          } else {
            piece.addPath(metric.extractPath(a, total), Offset.zero);
            piece.addPath(metric.extractPath(0, b - total), Offset.zero);
          }
          // Two waves of different lengths, so the pattern never reads as a
          // loop, travelling against the clock's direction.
          final u = k / segments;
          final wave = 0.5 +
              0.3 * math.sin(u * 2 * math.pi * 2 + phase) +
              0.2 * math.sin(u * 2 * math.pi * 5 - phase * 1.7);
          canvas.drawPath(
            piece,
            Paint()
              ..color = Color.lerp(colour, Colors.white, 0.35 * wave)!
                  .withValues(alpha: 0.45 + 0.45 * wave)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 9
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
        }
      }
      // And a hard line on it, so the ring has an edge to read.
      canvas.drawPath(
        drawn,
        Paint()
          ..color = colour.withValues(alpha: 0.85 + 0.15 * breathe)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      // The rest of the way round, faint: the ring's outline, so what has
      // burned off is still legible as "this much gone".
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = colour.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_AuraPainter old) => true;
}

/// Which board figures the live windows are moving, in whose colour — see
/// `StatTint`. The leading window's colour where two touch one figure.
({StatTint ours, StatTint theirs}) boardTints(List<LiveBoost> windows) {
  final ids = {for (final b in windows) b.id};
  final roar = ids.contains('crowd_roar') ? liveBoostColour('crowd_roar') : null;
  final sharp = ids.contains('sharp_shooting') ? liveBoostColour('sharp_shooting') : null;
  final bus = ids.contains('park_the_bus') ? liveBoostColour('park_the_bus') : null;
  return (
    ours: (atk: roar ?? sharp ?? bus, def: roar, rating: roar),
    theirs: (atk: bus, def: null, rating: null),
  );
}

/// The window that leads the others on the tile and the arrow: the Roar's
/// fire over the gold over the steel.
String? leadBoost(List<LiveBoost> windows) {
  final ids = {for (final b in windows) b.id};
  if (ids.contains('crowd_roar')) return 'crowd_roar';
  if (ids.contains('sharp_shooting')) return 'sharp_shooting';
  return windows.isEmpty ? null : windows.first.id;
}

/// A soft pulse round the figures while anything temporary lifts the side.
///
/// Opacity only. The box the child sits in does not change size, so the
/// scoreboard's layout is untouched by the pulse.
class LiveGlow extends StatelessWidget {
  const LiveGlow({
    super.key,
    required this.on,
    required this.glow,
    required this.child,
  });

  final bool on;
  final Animation<double>? glow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!on) return child;
    final kit = Theme.of(context).extension<KitTheme>()!;
    final anim = glow;
    Widget halo(double t) => DecoratedBox(
      key: const ValueKey('match-live-glow'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: kit.accentBright.withValues(alpha: 0.18 + 0.22 * t),
            blurRadius: 14 + 6 * t,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
    if (anim == null) return halo(0.5);
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => halo(anim.value),
    );
  }
}

/// The caption naming what just changed — `🔄 Super Sub`, `📣 Crowd Roar`.
///
/// **One, transient, and only on a CHANGE.** Five lifts can hold at once and
/// five captions is not a board; the glow carries the persistent state and
/// this explains the moment, then fades. The box reserves its height whether
/// or not a caption is up, so its arrival and departure move nothing.
class LiveSourcePill extends StatelessWidget {
  const LiveSourcePill({super.key, required this.text});

  /// Null when nothing has just changed.
  final String? text;

  static const double height = 18;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return SizedBox(
      height: height,
      child: AnimatedOpacity(
        opacity: text == null ? 0 : 1,
        duration: const Duration(milliseconds: 220),
        child: text == null
            ? const SizedBox.shrink()
            : Center(
                child: Container(
                  key: const ValueKey('match-live-source-pill'),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: kit.accent.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    text!,
                    key: const ValueKey('match-live-source-pill-text'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                      color: kit.accentBright,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
