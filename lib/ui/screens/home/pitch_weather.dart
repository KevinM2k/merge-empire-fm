/// The weather over the diorama. Ported from the `.ps-clouds` / `.ps-rain` /
/// `.ps-snow` / `.ps-fog` / `.ps-gusts` / `.ps-sun` / `.ps-overcast` /
/// `.ps-lightning` blocks of `../merge-empire-fc/src/ui/styles/league-scene.css`
/// and the node-building at the end of `components/PitchScene.js`.
///
/// **The engine has been able to answer "what is the weather" since M1 and
/// nothing on screen has ever drawn the answer.** `resolveCondition` returns one
/// of eight conditions and every one of them looked identical: a clear sky. This
/// is the missing layer, and it is a layer rather than a fix — eight conditions,
/// each with its own art.
///
/// **ONE PAINTER PER CONDITION, NOT ONE NODE PER PARTICLE.** The JS builds 30
/// raindrops, 50 flakes and 7 gusts as DOM elements and spends most of its
/// comments on the consequences: each one has to ride a translating column so
/// the browser composites instead of relayouting, the `will-change` hints have to
/// be scoped per condition or the GPU pins a layer for every drop forever, and a
/// `filter: blur()` is off the table because it would repaint. None of that
/// survives the port, because none of it is about weather — it is about the DOM.
/// A `CustomPaint` has no layout to invalidate and no layers to pin, so a shower
/// is one painter reading one clock, and the flakes can have the soft edge the
/// CSS had to fake with a gradient.
///
/// **What DOES survive is the geometry**, and it is all in fractions of the
/// scene rather than the JS's mix of `%`, `px` and `vw`: a scene 400px wide and
/// one 1200px wide have to show the same weather, and the JS only gets away with
/// `vw` because its diorama happens to be full-bleed.
///
/// **Nothing here ticks unless it is on screen and moving.** Every layer takes
/// an `active` flag and its clock stops when the flag is false or the platform
/// asks for reduced motion. That is not only politeness: a `Ticker` that never
/// stops keeps a frame scheduled forever, which is what made `pumpAndSettle`
/// time out in every test that so much as opened the penalty screen.
///
/// **Reduced motion still shows you the weather.** The layers hold still and the
/// lightning is switched off entirely, but an overcast sky is still grey and fog
/// is still fog — which is what the stylesheet's own `prefers-reduced-motion`
/// block says it wants. (`LeagueScreen` is stricter than its stylesheet here: it
/// gates the whole cycle on `_sceneInteractive()`, so under reduced motion the JS
/// never leaves `clear` and none of those rules can ever apply. The CSS is the
/// deliberate half of that disagreement, so it is the half ported.)
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:merge_empire_fc/ui/screens/home/kenney_art.dart';
import 'package:merge_empire_fc/ui/theme/sky.dart';

/// The seed every particle field is laid out from.
///
/// Fixed, like the turf's own arrangement: the same shower on every screen size
/// and across every rebuild. A field that reshuffled itself would flicker every
/// time the condition changed.
const int _seed = 0x5EED;

/// Conditions that put rain in the air. A thunderstorm is rain plus lightning.
bool _isWet(String c) => c == 'rain' || c == 'storm';

/// One key per layer, so a test can ask what the sky is showing rather than
/// counting anonymous painters in a `Stack`.
///
/// It is the only handle on any of this: every layer is present in every
/// condition and only its opacity says which one is on, which is exactly the
/// arrangement that makes changing the sky free — and also the one that gives a
/// test nothing to find by type.
ValueKey<String> weatherLayerKey(String layer) => ValueKey('weather-$layer');

// ── The clock ───────────────────────────────────────────────────────────────

/// A monotonic seconds counter for the layers that move, and nothing at all for
/// the layers that do not.
///
/// **Seconds since it started, not a 0→1 phase**, because the particles in one
/// field do not share a period: a raindrop falls in 0.55s and its neighbour in
/// 1.0s. A wrapping controller would have to jump every particle back to the top
/// at once to stay in step with itself; an open-ended count lets each one keep
/// its own speed off one clock.
class _Motion extends StatefulWidget {
  const _Motion({required this.active, required this.builder});

  final bool active;
  final Widget Function(BuildContext context, double seconds) builder;

  @override
  State<_Motion> createState() => _MotionState();
}

class _MotionState extends State<_Motion> with SingleTickerProviderStateMixin {
  /// The painters listen to this rather than the element rebuilding, which is
  /// the same bargain `_MowFan` makes.
  final ValueNotifier<double> _clock = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
    (elapsed) => _clock.value = elapsed.inMicroseconds / 1e6,
  );

  void _sync() {
    final run = widget.active && !MediaQuery.of(context).disableAnimations;
    if (run == _ticker.isActive) return;
    if (run) {
      _ticker.start();
    } else {
      // Held where it froze rather than reset. A shower is still fading out
      // when its clock stops, and a field that jumped back to its laid-out
      // positions mid-fade would be a visible flinch on the way to invisible.
      _ticker.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Motion old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: _clock,
    builder: (context, t, _) => widget.builder(context, t),
  );
}

/// One layer: a painter that fades in when its condition arrives.
///
/// The fade durations are the CSS's own, and they differ on purpose — a shower
/// arrives in under a second, snow takes its time settling in.
class _Layer extends StatelessWidget {
  const _Layer({
    required this.visible,
    required this.fade,
    required this.child,
    super.key,
  });

  final bool visible;
  final Duration fade;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: fade,
      curve: Curves.easeInOut,
      // Nothing to paint at all when it is fully out: an invisible painter still
      // costs a paint, and there are eight of these.
      child: TickerMode(enabled: visible, child: child),
    ),
  );
}

// ── Sky: the sun and the clouds ─────────────────────────────────────────────

/// Everything that belongs to the sky itself, painted with it: the sun for
/// `sunny`, and the clouds, which are always there.
///
/// Placed straight after the sky gradient and before the stand, because the
/// CSS puts both at `z-index: 0`. The sun learned that the hard way — at 1 it
/// sat in front of the terrace and a tier-5 ground had the sun hanging over its
/// floodlight pylons.
class WeatherSky extends StatelessWidget {
  const WeatherSky({required this.condition, super.key});

  final String condition;

  @override
  Widget build(BuildContext context) {
    // **A HOT SUN OVER A FLOODLIT NIGHT.** The scene goes dark with the theme —
    // `nightScene` is the whole of it — and the sunny sky kept painting a
    // blazing yellow disc, rays and a warm bloom into it. What is in the sky at
    // night is the MOON, so the condition keeps its layer and swaps what the
    // layer draws. Same key: `sunny` is the engine's condition and it still owns
    // this layer, which is what `pitch_weather_test` asserts.
    final night = nightSceneOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        _Layer(
          key: weatherLayerKey('sun'),
          visible: condition == 'sunny',
          fade: const Duration(milliseconds: 1600),
          // **The moon does not turn.** The rays are the only thing the clock
          // drove, so at night this is a still painting and there is no reason
          // to tick a frame for it.
          child: night
              ? CustomPaint(
                  key: const ValueKey('pitch-moon'),
                  size: Size.infinite,
                  painter: _MoonPainter(),
                )
              : _Motion(
                  active: condition == 'sunny',
                  builder: (context, t) => CustomPaint(
                    key: const ValueKey('pitch-sun'),
                    size: Size.infinite,
                    painter: _SunPainter(t),
                  ),
                ),
        ),
      // Not a condition's layer: the clouds are always in the sky. What the
      // condition changes is how fast they go and how heavy they read — they
      // race in a gale, crawl in a storm and disappear altogether in fog, which
      // is the same handful of nodes retimed rather than a layer per sky.
        _Layer(
          key: weatherLayerKey('clouds'),
          visible: condition != 'fog',
          fade: const Duration(milliseconds: 1200),
          child: _Motion(
            active: condition != 'fog',
            builder: (context, t) => CustomPaint(
              size: Size.infinite,
              painter: _CloudPainter(
                seconds: t,
                condition: condition,
                night: night,
              ),
            ),
          ),
        ),
        // **BIRDS.** A handful, crossing the sky at their own pace, because a
        // sky with nothing alive in it is a backdrop. Not in rain, snow, fog
        // or a storm, and not at night. Six strokes a frame on a layer of
        // their own, which is as cheap as life gets.
        _Layer(
          key: weatherLayerKey('birds'),
          visible: !night && birdsFlyIn(condition),
          fade: const Duration(milliseconds: 1600),
          child: _Motion(
            active: !night && birdsFlyIn(condition),
            builder: (context, t) => CustomPaint(
              size: Size.infinite,
              painter: _BirdPainter(seconds: t),
            ),
          ),
        ),
      ],
    );
  }
}

/// Whether birds are out in this weather.
bool birdsFlyIn(String condition) =>
    condition != 'rain' &&
    condition != 'storm' &&
    condition != 'snow' &&
    condition != 'fog';

/// One bird's flight: where it starts, how fast, how big, which way.
typedef _Bird = ({double phase, double top, double speed, double size, double flap, bool left});

/// Five birds. Two flying against the world's scroll, three with it, at
/// different heights and speeds so they never bunch.
const List<_Bird> _birds = [
  (phase: 0.10, top: 0.08, speed: 26, size: 5.5, flap: 6.2, left: true),
  (phase: 0.45, top: 0.16, speed: 19, size: 7.0, flap: 5.1, left: true),
  (phase: 0.72, top: 0.05, speed: 33, size: 4.5, flap: 7.3, left: false),
  (phase: 0.30, top: 0.22, speed: 22, size: 6.0, flap: 5.6, left: false),
  (phase: 0.88, top: 0.12, speed: 15, size: 8.0, flap: 4.4, left: true),
];

/// The band of sky the birds keep to — above the clouds' own band's middle.
const double _birdBand = 0.34;

class _BirdPainter extends CustomPainter {
  const _BirdPainter({required this.seconds});

  final double seconds;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final ink = Paint()
      ..color = const Color(0xFF2B3440).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    final span = size.width + 40;
    for (final b in _birds) {
      final along = ((b.phase + seconds * b.speed / span) % 1);
      final x = b.left ? size.width + 20 - along * span : -20 + along * span;
      // A slow rise and fall on top of the flight line, so it soars.
      final y = size.height * _birdBand * (b.top / 0.25) +
          math.sin(seconds * 0.7 + b.phase * 6) * 3;
      final flap = math.sin(seconds * b.flap + b.phase * 9);
      final w = b.size;
      final lift = w * (0.15 + 0.45 * flap);
      final wing = Path()
        ..moveTo(x - w, y - lift)
        ..quadraticBezierTo(x - w * 0.45, y + w * 0.18, x, y)
        ..quadraticBezierTo(x + w * 0.45, y + w * 0.18, x + w, y - lift);
      canvas.drawPath(wing, ink);
    }
  }

  @override
  bool shouldRepaint(_BirdPainter old) => old.seconds != seconds;
}

// ── Air: overcast, rain, snow, fog, wind ────────────────────────────────────

/// The conditions that happen between the camera and the ground.
///
/// Sits above the pitch and BELOW the manager, which is the CSS's z-order
/// (`.ps-overcast` 2, the rest 3, `.ps-walker` 4) rather than an oversight: he
/// is the subject of the shot, so the shower is a curtain behind him. Only the
/// lightning goes over the top of him.
class WeatherAir extends StatelessWidget {
  const WeatherAir({required this.condition, super.key});

  final String condition;

  @override
  Widget build(BuildContext context) {
    final overcast = _overcastGradient(condition);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Not a layer of its own in the JS either: an overcast sky is the light
        // pulled down, and it applies to every wet condition because it never
        // rains out of a clear one.
        _Layer(
          key: weatherLayerKey('overcast'),
          visible: overcast != null,
          fade: const Duration(milliseconds: 1200),
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: overcast ?? _overcastGrey),
          ),
        ),
        _Layer(
          key: weatherLayerKey('rain'),
          visible: _isWet(condition),
          fade: const Duration(milliseconds: 800),
          child: _Motion(
            active: _isWet(condition),
            builder: (context, t) => CustomPaint(
              size: Size.infinite,
              painter: _RainPainter(seconds: t, storm: condition == 'storm'),
            ),
          ),
        ),
        _Layer(
          key: weatherLayerKey('snow'),
          visible: condition == 'snow',
          fade: const Duration(milliseconds: 1200),
          child: _Motion(
            active: condition == 'snow',
            builder: (context, t) =>
                CustomPaint(size: Size.infinite, painter: _SnowPainter(t)),
          ),
        ),
        _Layer(
          key: weatherLayerKey('fog'),
          visible: condition == 'fog',
          fade: const Duration(milliseconds: 1400),
          child: _Motion(
            active: condition == 'fog',
            builder: (context, t) =>
                CustomPaint(size: Size.infinite, painter: _FogPainter(t)),
          ),
        ),
        _Layer(
          key: weatherLayerKey('wind'),
          visible: condition == 'wind',
          fade: const Duration(milliseconds: 900),
          child: _Motion(
            active: condition == 'wind',
            builder: (context, t) =>
                CustomPaint(size: Size.infinite, painter: _GustPainter(t)),
          ),
        ),
      ],
    );
  }
}

// ── Ground: snow lying on the pitch ─────────────────────────────────────────

/// Snow ON the grass, inside the turf and over the mown stripes.
///
/// Falling snow that never settles reads as a screen effect rather than as
/// weather. Deliberately not opaque: the stripes and the park tiers' mud still
/// ghost through, which is what keeps it a snow-covered pitch instead of a white
/// rectangle.
class WeatherGroundSnow extends StatelessWidget {
  const WeatherGroundSnow({required this.condition, super.key});

  final String condition;

  @override
  Widget build(BuildContext context) => _Layer(
    key: weatherLayerKey('ground-snow'),
    visible: condition == 'snow',
    fade: const Duration(milliseconds: 1800),
    // Static — no clock. Drifts that drifted would be a blizzard on the ground.
    child: const CustomPaint(
      size: Size.infinite,
      painter: _SettledSnowPainter(),
    ),
  );
}

/// His boot prints in that settled snow, and only where he has already been.
///
/// **The prints are not spawned per stride.** They ride the ground at the
/// ground's own speed, which is what makes it structurally impossible for a
/// print to slide against the pitch — the one mistake here the eye catches
/// instantly. What makes them read as HIS is the mask: everything from his boot
/// forward is hidden, so a print can only ever appear directly under his foot,
/// and the oldest fade out to the left where the scene is dissolving anyway.
class WeatherPrints extends StatelessWidget {
  const WeatherPrints({
    required this.condition,
    required this.scrollDuration,
    required this.contactFraction,
    super.key,
  });

  final String condition;

  /// How long the ground takes to travel one [printSegmentWidth]. Handed in
  /// rather than derived, so it can only ever be the number the turf itself uses.
  final Duration scrollDuration;

  /// Where his boot is across the scene, 0–1. The mask's cut-off.
  final double contactFraction;

  @override
  Widget build(BuildContext context) => _Layer(
    key: weatherLayerKey('prints'),
    visible: condition == 'snow',
    fade: const Duration(milliseconds: 1800),
    child: _Motion(
      active: condition == 'snow',
      builder: (context, t) => CustomPaint(
        size: Size.infinite,
        painter: _PrintPainter(
          phase: scrollDuration.inMicroseconds == 0
              ? 0
              : (t * 1e6 / scrollDuration.inMicroseconds) % 1,
          contactFraction: contactFraction,
        ),
      ),
    ),
  );
}

// ── Lightning ───────────────────────────────────────────────────────────────

/// The flash and the fork, and the thunder timed behind them.
///
/// **Scheduled here rather than looped in the layer**, for the reason the JS
/// gives: the gap between the light and the sound is the whole trick. Light
/// arrives instantly and sound does not, so a simultaneous flash and bang reads
/// as a sound effect while half a second of gap reads as distance. A looping
/// animation gives nothing to hang that delay on.
///
/// Strikes stop the moment the storm does, and never start at all under reduced
/// motion — a full-screen white flash is precisely what that setting exists to
/// prevent, and the stylesheet says so twice.
class WeatherLightning extends StatefulWidget {
  const WeatherLightning({
    required this.condition,
    this.onThunder,
    this.random,
    super.key,
  });

  final String condition;

  /// Play the thunder. Called after the strike's own delay, so the caller only
  /// has to own the speaker.
  final void Function()? onThunder;

  /// Injected for the test that wants a chosen bolt rather than a random one.
  final math.Random? random;

  @override
  State<WeatherLightning> createState() => _WeatherLightningState();
}

class _WeatherLightningState extends State<WeatherLightning>
    with SingleTickerProviderStateMixin {
  /// One strike, 620ms. The JS's `timing`.
  late final AnimationController _strike = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  late final math.Random _rand = widget.random ?? math.Random();

  Timer? _nextStrike;
  Timer? _thunder;

  /// Which fork, and how close it was. Both are decided per strike.
  int _bolt = 0;
  bool _near = false;

  bool get _storming => widget.condition == 'storm';

  void _sync() {
    final on = _storming && !MediaQuery.of(context).disableAnimations;
    if (on) {
      _arm();
    } else {
      _disarm();
    }
  }

  /// 4–13 seconds apart, so a strike stays an event rather than a metronome.
  void _arm() {
    if (_nextStrike != null) return;
    _nextStrike = Timer(Duration(milliseconds: 4000 + _rand.nextInt(9000)), () {
      _nextStrike = null;
      if (!mounted || !_storming) return;
      _fire();
      _arm();
    });
  }

  void _disarm() {
    _nextStrike?.cancel();
    _nextStrike = null;
    _thunder?.cancel();
    _thunder = null;
    if (_strike.isAnimating) _strike.stop();
    _strike.value = 0;
  }

  void _fire() {
    setState(() {
      _bolt = _rand.nextInt(_boltPaths.length);
      _near = _rand.nextDouble() < 0.35;
    });
    _strike.forward(from: 0);
    // A near strike cracks almost on top of the flash; a distant one takes its
    // time. Nothing depends on the sound, so a muted player loses nothing.
    _thunder?.cancel();
    _thunder = Timer(
      Duration(
        milliseconds: _near
            ? 150 + _rand.nextInt(350)
            : 700 + _rand.nextInt(1600),
      ),
      () {
        _thunder = null;
        if (mounted && _storming) widget.onThunder?.call();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(WeatherLightning old) {
    super.didUpdateWidget(old);
    if (old.condition != widget.condition) _sync();
  }

  @override
  void dispose() {
    _disarm();
    _strike.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _strike,
      builder: (context, _) => _strike.value == 0
          ? const SizedBox.shrink()
          : CustomPaint(
              size: Size.infinite,
              painter: _LightningPainter(
                phase: _strike.value,
                bolt: _bolt,
                near: _near,
              ),
            ),
    ),
  );
}

// ── Overcast ────────────────────────────────────────────────────────────────

/// Warm-neutral grey, high enough to flatten the sky's own colour.
///
/// It has two jobs at once, which is why it desaturates rather than darkens: the
/// tier skies run from a bright park afternoon to a floodlit purple night, and a
/// tint dark enough to read as overcast at tier 0 just looks like dusk at tier 6.
const LinearGradient _overcastGrey = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0x807A808C), Color(0x42828894), Color(0x1F888E96)],
  stops: [0, 0.62, 1],
);

const LinearGradient _overcastStorm = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0x75141828), Color(0x331A2030), Color(0x331A2030)],
  stops: [0, 0.7, 1],
);

/// A snow sky is PALE and flat, not dark. A white pitch under a summer-blue sky
/// is the one combination that makes the whole scene look broken.
const LinearGradient _overcastSnow = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xC7CBD6E5), Color(0x8FD6E0ED), Color(0x66E4ECF5)],
  stops: [0, 0.52, 1],
);

LinearGradient? _overcastGradient(String condition) => switch (condition) {
  'cloudy' || 'rain' || 'wind' => _overcastGrey,
  'storm' => _overcastStorm,
  'snow' => _overcastSnow,
  _ => null,
};

/// Squash a radial gradient's vertical axis WITHOUT moving its centre.
///
/// A bare scale is about the canvas origin, so a shape halfway down the scene
/// would have its gradient hauled toward the top edge — which reads as the soft
/// middle of a cloud sitting somewhere other than the cloud.
Float64List _squash(Offset centre, double factor) =>
    (Matrix4.identity()
          ..translateByDouble(centre.dx, centre.dy, 0, 1)
          ..scaleByDouble(1, factor, 1, 1)
          ..translateByDouble(-centre.dx, -centre.dy, 0, 1))
        .storage;

// ── Clouds ──────────────────────────────────────────────────────────────────

/// The band of sky the clouds live in — the open strip below the next-match
/// card, not the very top where the card covers them.
const double _cloudBand = 0.52;

class _Cloud {
  const _Cloud({
    required this.top,
    required this.width,
    required this.seconds,
    required this.phase,
    required this.opacity,
  });

  /// Fraction of the scene height.
  final double top;
  final double width;
  final double seconds;
  final double phase;
  final double opacity;
}

final List<_Cloud> _clouds = _buildClouds();

List<_Cloud> _buildClouds() {
  final rand = math.Random(_seed);
  // 4–5. The JS drops to 2 on a low-end device; there is no such signal here, so
  // the count is the one number in this file that is not the JS's whole story.
  final n = 4 + rand.nextInt(2);
  return [
    for (var i = 0; i < n; i++)
      _Cloud(
        top: 0.12 + rand.nextDouble() * 0.28,
        width: 80 + rand.nextDouble() * 110,
        seconds: 90 + rand.nextDouble() * 90,
        phase: rand.nextDouble(),
        opacity: 0.32 + rand.nextDouble() * 0.24,
      ),
  ];
}

/// One cloud's oval and its shader, built at the ORIGIN so the drift is a canvas
/// translate rather than a fresh gradient a frame.
class _CloudArt {
  const _CloudArt({required this.rect, required this.paint});

  final Rect rect;
  final Paint paint;
}

class _CloudPainter extends CustomPainter {
  _CloudPainter({
    required this.seconds,
    required this.condition,
    required this.night,
  }) : super(repaint: Sprites.version);

  final double seconds;
  final String condition;
  final bool night;

  /// The same nodes, retimed. A gale drives them across in 22s; a storm's are
  /// heavier and slower.
  double? get _forcedSeconds => switch (condition) {
    'wind' => 22,
    'storm' => 30,
    _ => null,
  };

  /// A wet sky's clouds are turned up, because they are the sky's weather. The
  /// CSS states one value rather than scaling the seeded spread, so this does
  /// too — an overcast sky wants an even deck, not a varied one.
  double? get _forcedOpacity => switch (condition) {
    'cloudy' || 'rain' || 'storm' => 0.8,
    _ => null,
  };

  /// No override, as a cache key — the seeded spread is per cloud, not one
  /// number.
  static const double _seededAlpha = -1;

  @override
  void paint(Canvas canvas, Size size) {
    final art = _artFor(_forcedOpacity ?? _seededAlpha);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height * _cloudBand));
    for (var i = 0; i < _clouds.length; i++) {
      final c = _clouds[i];
      final dur = _forcedSeconds ?? c.seconds;
      final phase = (c.phase + seconds / dur) % 1;
      // 108% of the scene to -60% of it: on screen for most of the run and
      // fully clear of both edges at the ends.
      final x = size.width * (1.08 - phase * 1.68);
      if (x + c.width < 0 || x > size.width) continue;
      canvas.save();
      canvas.translate(x, size.height * c.top);
      final sprite = Sprites.of(kenneyClouds[i % kenneyClouds.length]);
      if (sprite == null) {
        canvas.drawOval(art[i].rect, art[i].paint);
      } else {
        // Kenney's cloud, at the width the oval had and its own shape.
        final w = c.width;
        final hgt = w * sprite.height / sprite.width;
        final a = _forcedOpacity ?? c.opacity;
        canvas.drawImageRect(
          sprite,
          Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
          Rect.fromLTWH(0, 0, w, hgt),
          Paint()
            ..color = Color.fromRGBO(255, 255, 255, a)
            ..filterQuality = FilterQuality.medium
            ..colorFilter = night
                ? const ColorFilter.mode(Color(0xFF5A6684), BlendMode.modulate)
                : null,
        );
      }
      canvas.restore();
    }
    canvas.restore();
  }

  /// The clouds as last built, and the opacity they were built at.
  static List<_CloudArt>? _art;
  static double _artAlpha = double.nan;

  static List<_CloudArt> _artFor(double alpha) {
    final held = _art;
    if (held != null && _artAlpha == alpha) return held;
    final built = <_CloudArt>[];
    for (final c in _clouds) {
      final w = c.width;
      final h = w * 0.4;
      final a = alpha == _seededAlpha ? c.opacity : alpha;
      // A cloud is wider than it is tall, so the gradient's radius is the wide
      // axis and the vertical is squashed about the centre it is measured from —
      // squashing about the origin instead would slide every cloud toward the
      // top of the sky as it drifted.
      final centre = Offset(w * 0.5, h * 0.58);
      built.add(
        _CloudArt(
          rect: Rect.fromLTWH(0, 0, w, h),
          paint: Paint()
            ..shader = ui.Gradient.radial(
              centre,
              w * 0.5,
              [
                Color.fromRGBO(255, 255, 255, 0.98 * a),
                Color.fromRGBO(255, 255, 255, 0.6 * a),
                const Color(0x00FFFFFF),
              ],
              const [0, 0.44, 0.74],
              TileMode.clamp,
              _squash(centre, h / w),
            ),
        ),
      );
    }
    _artAlpha = alpha;
    return _art = built;
  }

  @override
  bool shouldRepaint(_CloudPainter old) =>
      old.seconds != seconds || old.condition != condition;
}

// ── Rain ────────────────────────────────────────────────────────────────────

class _Drop {
  const _Drop({
    required this.x,
    required this.length,
    required this.seconds,
    required this.phase,
  });

  /// Fraction of the scene width.
  final double x;
  final double length;
  final double seconds;
  final double phase;
}

final List<_Drop> _drops = _buildDrops();

List<_Drop> _buildDrops() {
  final rand = math.Random(_seed ^ 0x11);
  return [
    for (var i = 0; i < 30; i++)
      _Drop(
        x: rand.nextDouble(),
        length: 7 + rand.nextDouble() * 8,
        seconds: 0.55 + rand.nextDouble() * 0.45,
        phase: rand.nextDouble(),
      ),
  ];
}

/// A drop is a streaklet — faint at the trailing top, bright at the leading tip.
/// One shader per length, built once, because the field never reshuffles.
final Map<bool, Map<int, ui.Shader>> _dropShaders = {};

ui.Shader _dropShader(double length, bool storm) {
  final table = _dropShaders.putIfAbsent(storm, () => {});
  return table.putIfAbsent(length.round(), () {
    final mid = storm ? 0.42 : 0.32;
    final tip = storm ? 0.78 : 0.6;
    return ui.Gradient.linear(
      Offset.zero,
      Offset(0, length.round().toDouble()),
      [
        const Color(0x00FFFFFF),
        Color.fromRGBO(255, 255, 255, mid),
        Color.fromRGBO(255, 255, 255, tip),
      ],
      const [0, 0.55, 1],
    );
  });
}

class _RainPainter extends CustomPainter {
  const _RainPainter({required this.seconds, required this.storm});

  final double seconds;

  /// A storm drives the rain harder and steeper than a shower does.
  final bool storm;

  @override
  void paint(Canvas canvas, Size size) {
    // The shower's own dimming. Faint for rain; a storm is properly dark.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = storm ? const Color(0x290E1426) : const Color(0x0F141E32),
    );

    final lean = (storm ? 15 : 9) * math.pi / 180;
    final fall = storm ? 0.42 : null;
    for (final d in _drops) {
      final phase = (d.phase + seconds / (fall ?? d.seconds)) % 1;
      // The column runs 0 → 116% of the scene and the drop starts 8% above it,
      // which is the JS's -8% → 108% traversal exactly.
      final y = size.height * (phase * 1.16 - 0.08);
      canvas.save();
      canvas.translate(size.width * d.x, y);
      canvas.rotate(lean);
      canvas.drawRect(
        Rect.fromLTWH(-0.8, 0, 1.6, d.length),
        Paint()..shader = _dropShader(d.length, storm),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_RainPainter old) =>
      old.seconds != seconds || old.storm != storm;
}

// ── Snow ────────────────────────────────────────────────────────────────────

class _Flake {
  const _Flake({
    required this.x,
    required this.size,
    required this.fallSeconds,
    required this.phase,
    required this.sway,
    required this.swaySeconds,
    required this.opacity,
    required this.near,
  });

  final double x;
  final double size;
  final double fallSeconds;
  final double phase;
  final double sway;
  final double swaySeconds;
  final double opacity;

  /// Passing close to the camera: bigger, faster, wider drift and out of focus.
  final bool near;
}

final List<_Flake> _flakes = _buildFlakes();

List<_Flake> _buildFlakes() {
  final rand = math.Random(_seed ^ 0x22);
  final out = [
    for (var i = 0; i < 44; i++)
      _Flake(
        x: rand.nextDouble(),
        size: 2.5 + rand.nextDouble() * 4.5,
        // Heavy snow still drifts, but with purpose.
        fallSeconds: 3.8 + rand.nextDouble() * 3.2,
        phase: rand.nextDouble(),
        sway: 7 + rand.nextDouble() * 12,
        swaySeconds: 2.4 + rand.nextDouble() * 2.2,
        opacity: 0.55 + rand.nextDouble() * 0.4,
        near: false,
      ),
  ];
  // **This is what turns a flurry into heavy snow.** A flake crossing the frame
  // in two seconds implies a whole volume of snow between you and the pitch,
  // which no number of extra far-away flakes can say.
  out.addAll([
    for (var i = 0; i < 6; i++)
      _Flake(
        x: rand.nextDouble(),
        size: 9 + rand.nextDouble() * 5,
        fallSeconds: 2.2 + rand.nextDouble() * 1.6,
        phase: rand.nextDouble(),
        sway: 16 + rand.nextDouble() * 18,
        swaySeconds: 1.7 + rand.nextDouble() * 1.5,
        opacity: 0.5 + rand.nextDouble() * 0.28,
        near: true,
      ),
  ]);
  return out;
}

/// One shader per flake, in the flake's own box, so the canvas can be translated
/// under it rather than a gradient rebuilt per frame.
final List<ui.Shader> _flakeShaders = [
  for (final f in _flakes)
    ui.Gradient.radial(
      Offset(f.size * 0.4, f.size * 0.35),
      f.size * (f.near ? 0.62 : 0.5),
      f.near
          // Out of focus, so it falls off to nothing well inside the circle
          // instead of holding an edge. The CSS had to do this with a gradient
          // because a real blur would have been its only repaint; here it could
          // be a blur and the gradient is still the cheaper truth.
          ? [
              Color.fromRGBO(255, 255, 255, 0.88 * f.opacity),
              Color.fromRGBO(255, 255, 255, 0.44 * f.opacity),
              Color.fromRGBO(255, 255, 255, 0.12 * f.opacity),
              const Color(0x00FFFFFF),
            ]
          : [
              Color.fromRGBO(255, 255, 255, 0.98 * f.opacity),
              Color.fromRGBO(255, 255, 255, 0.82 * f.opacity),
              Color.fromRGBO(255, 255, 255, 0.3 * f.opacity),
            ],
      f.near ? const [0, 0.42, 0.72, 1] : const [0, 0.55, 1],
    ),
];

class _SnowPainter extends CustomPainter {
  const _SnowPainter(this.seconds);

  final double seconds;

  @override
  void paint(Canvas canvas, Size size) {
    // **Snow light is flat and cold, not dark — brighten rather than dim.** And
    // heavy snow costs you the far distance, so the veil is strong enough to
    // haze the stand: reduced visibility is half of what makes snowfall read as
    // heavy, and it is cheaper and calmer than throwing more flakes at it.
    //
    // These are the lifted values, not the bare ones: a snow-covered pitch
    // bounces light back up, and without the lift the ground reads brighter than
    // the air above it and the two layers look unrelated.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          const [Color(0x33E8F2FF), Color(0x1CDCEAFC)],
        ),
    );

    for (var i = 0; i < _flakes.length; i++) {
      final f = _flakes[i];
      final phase = (f.phase + seconds / f.fallSeconds) % 1;
      final y = size.height * (phase * 1.12 - 0.06);
      // The column owns the fall and the flake owns the drift. `alternate`, so
      // it sways back and forth rather than snapping back at the wrap.
      final swing = (f.phase + seconds / f.swaySeconds) % 2;
      final tri = swing <= 1 ? swing : 2 - swing;
      final drift = (Curves.easeInOut.transform(tri) - 0.5) * f.sway;
      canvas.save();
      canvas.translate(size.width * f.x + drift, y);
      canvas.drawCircle(
        Offset(f.size / 2, f.size / 2),
        f.size / 2 * (f.near ? 1.24 : 1),
        Paint()..shader = _flakeShaders[i],
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SnowPainter old) => old.seconds != seconds;
}

/// The snow that has settled.
class _SettledSnowPainter extends CustomPainter {
  const _SettledSnowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Base cover, bottom of the stack.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          const [Color(0xF2FAFDFF), Color(0xF0F7FBFF), Color(0xEBF2F8FF)],
          const [0, 0.55, 1],
        ),
    );
    // Drifts: soft patches that break up the flat cover. Static, and that is the
    // point — a drift that drifted would be a blizzard on the ground.
    for (final d in const [
      (0.18, 0.22, 0.34, 0.26, 0.95),
      (0.72, 0.40, 0.30, 0.22, 0.92),
      (0.46, 0.76, 0.26, 0.20, 0.95),
    ]) {
      final cx = size.width * d.$1;
      final cy = size.height * d.$2;
      final rx = size.width * d.$3;
      final ry = size.height * d.$4;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(cx, cy),
            rx,
            [Color.fromRGBO(255, 255, 255, d.$5), const Color(0x00FFFFFF)],
            const [0, 0.7],
            TileMode.clamp,
            _squash(Offset(cx, cy), ry / rx),
          ),
      );
    }
    // Cold shadow pooling at the very front, for depth.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          const [Color(0x00D6E4F6), Color(0x00D6E4F6), Color(0x80C6D6EE)],
          const [0, 0.62, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_SettledSnowPainter old) => false;
}

// ── Boot prints ─────────────────────────────────────────────────────────────

/// One tile of the print trail. Must divide by the gap an EVEN number of times
/// or the near/far foot stops alternating across the seam.
const double printSegmentWidth = 420;

/// 70px puts a print under his boot about once per step: the ground moves
/// ~84px/s and a stride is ~1.8s, so he covers ~150px per two steps.
const double _printGap = 70;

class _Print {
  const _Print({required this.x, required this.rotation, required this.far});

  final double x;
  final double rotation;
  final bool far;
}

final List<_Print> _prints = _buildPrints();

List<_Print> _buildPrints() {
  final rand = math.Random(_seed ^ 0x33);
  final n = (printSegmentWidth / _printGap).round();
  return [
    for (var i = 0; i < n; i++)
      _Print(
        // Jitter, kept well inside the tile so the wrap stays seamless.
        x: (i * _printGap + rand.nextDouble() * 7).roundToDouble(),
        rotation: (rand.nextDouble() * 10 - 5) * math.pi / 180,
        far: i.isOdd,
      ),
  ];
}

/// A print is a shallow depression, not a hole: cold shadow in the dip, and a
/// bright lip of snow pushed up on the far edge where the boot compressed it.
/// **That lip is most of the effect** — without it the dip reads as a smudge.
class _PrintPainter extends CustomPainter {
  const _PrintPainter({required this.phase, required this.contactFraction});

  final double phase;
  final double contactFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final cut = size.width * contactFraction;
    canvas.saveLayer(Offset.zero & size, Paint());

    final offset = -phase * printSegmentWidth;
    final tiles = (size.width / printSegmentWidth).ceil() + 2;
    for (var tile = 0; tile < tiles; tile++) {
      for (final p in _prints) {
        final x = offset + tile * printSegmentWidth + p.x;
        if (x < -20 || x > size.width + 20) continue;
        // The far foot's track: a touch higher up the pitch, smaller and
        // fainter, which is all the perspective two tracks 20cm apart need.
        final w = p.far ? 9.0 : 11.0;
        final h = p.far ? 4.0 : 5.0;
        final bottom = size.height - (p.far ? 8 : 3);
        final a = p.far ? 0.78 : 1.0;
        canvas.save();
        canvas.translate(x + w / 2, bottom - h / 2);
        canvas.rotate(p.rotation);
        final box = Rect.fromCenter(center: Offset.zero, width: w, height: h);
        canvas.drawOval(
          box,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset(0, -h * 0.18),
              w * 0.5,
              [
                Color.fromRGBO(142, 166, 198, 0.66 * a),
                Color.fromRGBO(172, 194, 220, 0.44 * a),
                const Color(0x00CEDEF0),
              ],
              const [0, 0.55, 1],
            ),
        );
        // The lip.
        canvas.drawOval(
          box.translate(0, -1),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Color.fromRGBO(255, 255, 255, 0.7 * a),
        );
        canvas.restore();
      }
    }

    // **The mask is what turns a scrolling field of prints into a trail.**
    // Sharp edge under the boot — a print appears, it does not fade in — and a
    // long fade out at the far left where the scene is dissolving anyway.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, 0),
          const [
            Color(0x00000000),
            Color(0xFF000000),
            Color(0xFF000000),
            Color(0x00000000),
          ],
          [
            0,
            0.16,
            math.max(0.17, (cut - 5) / size.width),
            math.min(1, (cut + 3) / size.width),
          ],
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PrintPainter old) =>
      old.phase != phase || old.contactFraction != contactFraction;
}

// ── Fog ─────────────────────────────────────────────────────────────────────

class _FogBand {
  const _FogBand({
    required this.bottom,
    required this.height,
    required this.seconds,
    required this.phase,
    required this.opacity,
  });

  final double bottom;
  final double height;
  final double seconds;
  final double phase;
  final double opacity;
}

final List<_FogBand> _fogBands = _buildFog();

List<_FogBand> _buildFog() {
  final rand = math.Random(_seed ^ 0x44);
  return [
    for (var i = 0; i < 3; i++)
      _FogBand(
        bottom: (6 + i * 13 + rand.nextDouble() * 8) / 100,
        height: 26 + rand.nextDouble() * 22,
        seconds: 46 + rand.nextDouble() * 40,
        phase: rand.nextDouble(),
        opacity: 0.4 + rand.nextDouble() * 0.3,
      ),
  ];
}

/// Volume, not particles. Fog is the one condition that reads better as a few
/// very wide soft bands than as objects, and three composited layers is the
/// entire cost.
class _FogPainter extends CustomPainter {
  const _FogPainter(this.seconds);

  final double seconds;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          const [Color(0x1FC4CCD6), Color(0x52C8D0DA), Color(0x80CED6E0)],
          const [0, 0.55, 1],
        ),
    );

    // 150% of the scene wide, so a band never shows an end.
    final bandWidth = size.width * 1.5;
    for (final b in _fogBands) {
      final phase = (b.phase + seconds / b.seconds) % 1;
      final left = -bandWidth * 0.6 + phase * bandWidth * 1.2;
      final rect = Rect.fromLTWH(
        left,
        size.height * (1 - b.bottom) - b.height,
        bandWidth,
        b.height,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            rect.center,
            bandWidth / 2,
            [
              Color.fromRGBO(226, 232, 240, 0.85 * b.opacity),
              Color.fromRGBO(222, 229, 238, 0.45 * b.opacity),
              const Color(0x00DCE4EE),
            ],
            const [0, 0.45, 0.76],
            TileMode.clamp,
            _squash(rect.center, b.height / bandWidth),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_FogPainter old) => old.seconds != seconds;
}

// ── Wind ────────────────────────────────────────────────────────────────────

class _Gust {
  const _Gust({
    required this.top,
    required this.width,
    required this.seconds,
    required this.phase,
    required this.opacity,
  });

  final double top;
  final double width;
  final double seconds;
  final double phase;
  final double opacity;
}

final List<_Gust> _gusts = _buildGusts();

List<_Gust> _buildGusts() {
  final rand = math.Random(_seed ^ 0x55);
  return [
    for (var i = 0; i < 7; i++)
      _Gust(
        top: 0.1 + rand.nextDouble() * 0.62,
        width: 0.12 + rand.nextDouble() * 0.24,
        seconds: 1.5 + rand.nextDouble() * 1.6,
        phase: rand.nextDouble(),
        opacity: 0.3 + rand.nextDouble() * 0.35,
      ),
  ];
}

/// Thin streaks tearing across the scene.
///
/// There is no foliage in the diorama to bend, so the moving air has to carry
/// the gale — that, plus the clouds racing, is what separates a blustery clear
/// day from a calm one. Right to left, like the clouds and the raindrops' lean:
/// the whole scene agrees on one wind direction, and since the manager faces
/// right it is a headwind.
class _GustPainter extends CustomPainter {
  const _GustPainter(this.seconds);

  final double seconds;

  @override
  void paint(Canvas canvas, Size size) {
    for (final g in _gusts) {
      final phase = (g.phase + seconds / g.seconds) % 1;
      final w = size.width * g.width;
      // The row travels exactly the scene, so a streak crosses it whatever its
      // own width — which is the promise the clouds' viewport-relative drift
      // cannot make, and at these speeds a streak that starts its run outside
      // the box is a streak you never see.
      final x = size.width * (1 - phase * 2);
      final rect = Rect.fromLTWH(x, size.height * g.top, w, 2);
      if (rect.right < 0 || rect.left > size.width) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1)),
        Paint()
          ..shader = ui.Gradient.linear(
            rect.centerLeft,
            rect.centerRight,
            [
              const Color(0x00FFFFFF),
              Color.fromRGBO(255, 255, 255, 0.85 * g.opacity),
              const Color(0x00FFFFFF),
            ],
            const [0, 0.45, 1],
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_GustPainter old) => old.seconds != seconds;
}

// ── Sun ─────────────────────────────────────────────────────────────────────

/// `sunny` is not `clear`. Clear is a pleasant day and draws nothing; sunny is a
/// HOT one, and it is the only condition that puts a sun in the sky. The engine
/// guarantees the pair agree — a sunny sky floors the temperature at `sunnyC` —
/// so this is also what makes the manager sweat through his overcoat.
class _SunPainter extends CustomPainter {
  _SunPainter(this.seconds) : super(repaint: Sprites.version);

  final double seconds;

  /// One shared centre for the disc, the bloom and the rays, so the three cannot
  /// drift apart. The CSS's `84% - 22px` / `9% + 22px`.
  static Offset _centre(Size size) =>
      Offset(size.width * 0.84 - 22, size.height * 0.09 + 22);

  @override
  void paint(Canvas canvas, Size size) {
    final art = _artFor(size);

    canvas.drawRect(Offset.zero & size, art.bloom);

    // Only the rays move: a 3°/sec turn about the shared centre.
    canvas.save();
    canvas.translate(art.centre.dx, art.centre.dy);
    canvas.rotate(seconds / 120 * 2 * math.pi);
    final sprite = Sprites.of(kenneySun);
    if (sprite != null) {
      // Kenney's sun, rays and all, turning as the fan did.
      const half = 36.0;
      canvas.drawImageRect(
        sprite,
        Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
        const Rect.fromLTWH(-half, -half, half * 2, half * 2),
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
      return;
    }
    canvas.drawPath(art.fan, art.rays);
    canvas.restore();

    canvas.drawCircle(art.centre, 27, art.halo);
    canvas.drawCircle(art.centre, 22, art.disc);
  }

  /// The sun as last built, and the scene size it was built for.
  static _SunArt? _art;

  /// **THE SUN IS STILL; ONLY THE RAYS TURN.** Three gradients, a blur and
  /// twelve wedges were rebuilt every frame at 120Hz to drive that one rotation
  /// — the same bargain `_MowPainter._fanFor` makes with the mown lanes.
  static _SunArt _artFor(Size size) {
    final held = _art;
    if (held != null && held.size == size) return held;
    final c = _centre(size);
    const rayRadius = 59.0;
    // The twelve wedges as ONE path: they never overlap, so a single fill is
    // the same picture in a twelfth of the draw calls.
    final fan = Path();
    for (var i = 0; i < 12; i++) {
      fan
        ..moveTo(0, 0)
        ..arcTo(
          Rect.fromCircle(center: Offset.zero, radius: rayRadius),
          i * 30 * math.pi / 180,
          3.5 * math.pi / 180,
          false,
        )
        ..close();
    }
    return _art = _SunArt(
      size: size,
      centre: c,
      // **The bloom is what makes the sky read as hot; the disc alone reads as
      // a sticker.** Painted across the WHOLE scene rather than into a box
      // around the sun: 240px of soft gradient in a box its own size has
      // straight edges running through the middle of the sky, and a gradient
      // still faintly warm where it meets one draws that edge as a visible
      // rectangle.
      bloom: Paint()
        ..shader = ui.Gradient.radial(
          c,
          240,
          const [
            Color(0x80FFE49C),
            Color(0x57FFE094),
            Color(0x33FFDA8A),
            Color(0x1CFFD682),
            Color(0x0EFFD27C),
            Color(0x06FFCE76),
            Color(0x02FFCA70),
            Color(0x00FFCA70),
          ],
          const [0, 0.2, 0.36, 0.52, 0.66, 0.8, 0.9, 1],
        ),
      fan: fan,
      // Rays: one repeating conic, faded out radially before its own edge or
      // they end in a hard circle. Behind the disc, so the disc's rim stays
      // crisp.
      rays: Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          rayRadius,
          const [
            Color(0x6BFFE8A8),
            Color(0x6BFFE8A8),
            Color(0x25FFE8A8),
            Color(0x00FFE8A8),
          ],
          const [0, 0.16, 0.46, 0.94],
        ),
      // The halo the disc throws into the sky around it.
      halo: Paint()
        ..color = const Color(0x8CFFD87E)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      disc: Paint()
        ..shader = ui.Gradient.radial(
          c + const Offset(-3.5, -5.3),
          22,
          const [
            Color(0xFFFFFDF2),
            Color(0xFFFFEDA6),
            Color(0xFFFFCF58),
            Color(0xFFFFB62B),
          ],
          const [0, 0.4, 0.76, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_SunPainter old) => old.seconds != seconds;
}

/// The sun at rest, and the scene size it was built for.
class _SunArt {
  const _SunArt({
    required this.size,
    required this.centre,
    required this.bloom,
    required this.fan,
    required this.rays,
    required this.halo,
    required this.disc,
  });

  final Size size;
  final Offset centre;
  final Paint bloom;

  /// The twelve wedges, about the origin — the canvas turns, not these.
  final Path fan;
  final Paint rays;
  final Paint halo;
  final Paint disc;
}

// ── Moon ────────────────────────────────────────────────────────────────────

/// The sun's place in the sky, at night.
///
/// **The scene is dark and the sun was still up in it.** `nightScene` turns the
/// whole diorama over to the floodlights, and the `sunny` layer went on painting
/// a warm bloom, twelve turning rays and a yellow-white disc into it — a hot
/// noon sky behind a lit stadium.
///
/// Everything structural is the sun's, deliberately: the same centre, the same
/// layer, the same fade. What changes is that the light is COLD and there is no
/// corona — a moon lights nothing, so the bloom shrinks to a close halo and the
/// rays go entirely. The craters are what stop a plain pale disc reading as a
/// dimmed sun.
class _MoonPainter extends CustomPainter {
  _MoonPainter() : super(repaint: Sprites.version);

  /// The sun's own centre, so the sky's one bright thing does not move when the
  /// theme changes. See [_SunPainter._centre].
  Offset _centre(Size size) =>
      Offset(size.width * 0.84 - 22, size.height * 0.09 + 22);

  @override
  void paint(Canvas canvas, Size size) {
    final c = _centre(size);

    // A close, cold halo. Across the whole scene for the same reason the sun's
    // is — a soft gradient in a box its own size draws its own edges — but a
    // third of the reach and a fraction of the strength, because moonlight does
    // not warm a sky.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          96,
          const [
            Color(0x33CFE2FF),
            Color(0x1FC7DBFA),
            Color(0x0FC0D5F5),
            Color(0x00BCD1F0),
          ],
          const [0, 0.38, 0.68, 1],
        ),
    );

    // The disc, lit from the same upper left the sun is.
    canvas.drawCircle(
      c,
      24,
      Paint()
        ..color = const Color(0x59D7E6FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    final sprite = Sprites.of(kenneyMoon);
    if (sprite != null) {
      // Kenney's crescent, inside the glow the disc had.
      canvas.drawImageRect(
        sprite,
        Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
        Rect.fromCenter(center: c, width: 46, height: 46),
        Paint()..filterQuality = FilterQuality.medium,
      );
      return;
    }
    canvas.drawCircle(
      c,
      20,
      Paint()
        ..shader = ui.Gradient.radial(
          c + const Offset(-3.5, -5),
          20,
          const [
            Color(0xFFFDFEFF),
            Color(0xFFE9F0FA),
            Color(0xFFCBD8EA),
            Color(0xFFA9BACF),
          ],
          const [0, 0.42, 0.78, 1],
        ),
    );

    // Craters. Clipped to the disc so one near the rim cannot spill off it, and
    // flat grey rather than shaded — at twenty pixels a lit crater rim is a
    // smudge, and three plain dents are what read as a moon.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: 20)));
    const craters = [
      (Offset(5.5, -6.5), 5.0),
      (Offset(-6.0, 3.5), 3.6),
      (Offset(4.0, 7.5), 2.8),
      (Offset(-1.5, -2.0), 2.0),
    ];
    for (final crater in craters) {
      canvas.drawCircle(
        c + crater.$1,
        crater.$2,
        Paint()..color = const Color(0x2E6E7F96),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MoonPainter old) => false;
}

// ── Lightning ───────────────────────────────────────────────────────────────

/// Three forks, each a jagged trunk down the sky with a branch splitting off
/// partway. The JS's `BOLT_PATHS`, as the polygons they are: straight segments
/// only, in a tall thin 50×120 box that gets stretched to the strike's height,
/// so the fork stays sharp at any scene size.
const List<List<List<Offset>>> _boltPaths = [
  [
    [
      Offset(34, 0),
      Offset(14, 46),
      Offset(27, 48),
      Offset(8, 104),
      Offset(30, 60),
      Offset(17, 57),
    ],
    [
      Offset(27, 48),
      Offset(38, 78),
      Offset(30, 79),
      Offset(44, 108),
      Offset(36, 74),
      Offset(33, 73),
    ],
  ],
  [
    [
      Offset(30, 0),
      Offset(12, 40),
      Offset(24, 43),
      Offset(14, 96),
      Offset(32, 54),
      Offset(20, 51),
    ],
    [
      Offset(24, 43),
      Offset(10, 66),
      Offset(18, 68),
      Offset(6, 92),
      Offset(21, 71),
      Offset(16, 69),
    ],
  ],
  [
    [
      Offset(28, 0),
      Offset(10, 52),
      Offset(25, 54),
      Offset(16, 112),
      Offset(34, 62),
      Offset(20, 59),
    ],
    [
      Offset(25, 54),
      Offset(40, 84),
      Offset(31, 85),
      Offset(42, 116),
      Offset(37, 82),
      Offset(33, 81),
    ],
  ],
];

/// Where each fork hangs and how far down it reaches. Seeded once, so a bolt is
/// always in the same place — it is the CHOICE of bolt that varies per strike.
final List<(double left, double height)> _boltPlacement = () {
  final rand = math.Random(_seed ^ 0x66);
  return [
    for (var i = 0; i < _boltPaths.length; i++)
      (
        (10 + i * 28 + rand.nextDouble() * 14) / 100,
        0.34 + rand.nextDouble() * 0.14,
      ),
  ];
}();

/// **The flash double-flickers because real lightning almost never fires once.**
/// The JS's five keyframes, read off the strike's own 0→1.
///
/// The fork's are not the flash's: it comes back harder on the second flicker
/// (0.9 against the flash's 0.8) and never drops as far between them, because
/// the channel is still ionised while the sky has already gone dark.
const List<double> _flashStops = [0, 1, 0.08, 0.8, 0];
const List<double> _forkStops = [0, 1, 0.15, 0.9, 0];

double _flicker(List<double> stops, double phase, double peak) {
  final scaled = phase * (stops.length - 1);
  final i = scaled.floor().clamp(0, stops.length - 2);
  return (stops[i] + (stops[i + 1] - stops[i]) * (scaled - i)) * peak;
}

class _LightningPainter extends CustomPainter {
  const _LightningPainter({
    required this.phase,
    required this.bolt,
    required this.near,
  });

  final double phase;
  final int bolt;

  /// Near strikes are brighter, and their thunder cracks sooner.
  final bool near;

  @override
  void paint(Canvas canvas, Size size) {
    final flash = _flicker(_flashStops, phase, near ? 0.85 : 0.45);
    if (flash > 0.001) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Color.fromRGBO(226, 236, 255, flash * 0.92),
      );
    }

    final forkAlpha = _flicker(_forkStops, phase, 1);
    if (forkAlpha <= 0.001) return;

    final (left, height) = _boltPlacement[bolt];
    final box = Rect.fromLTWH(
      size.width * left,
      0,
      size.width * 0.12,
      size.height * height,
    );
    final path = Path();
    for (final poly in _boltPaths[bolt]) {
      for (var i = 0; i < poly.length; i++) {
        // The 50×120 box, stretched into place — `preserveAspectRatio="none"`.
        final p = Offset(
          box.left + poly[i].dx / 50 * box.width,
          box.top + poly[i].dy / 120 * box.height,
        );
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
    }
    // **The glow is what stops the fork reading as a white paper cut-out.** Two
    // passes: a wide cold bloom into the sky, then a tight hot core.
    canvas.drawPath(
      path,
      Paint()
        ..color = Color.fromRGBO(150, 190, 255, 0.75 * forkAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Color.fromRGBO(214, 232, 255, 0.95 * forkAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawPath(
      path,
      Paint()..color = Color.fromRGBO(242, 247, 255, forkAlpha),
    );
  }

  @override
  bool shouldRepaint(_LightningPainter old) =>
      old.phase != phase || old.bolt != bolt || old.near != near;
}
