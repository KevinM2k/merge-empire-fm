/// Keepy Uppys — keep it off the floor.
///
/// The physics is `keepy_uppys_sim.dart`, pinned frame by frame against the
/// JS's own loop. This is the arena, the ball and the scoreboard over it; the
/// screen decides nothing about where the ball goes.
///
/// The ball HARDENS as the run goes on — balloon, then football, then
/// cannonball — and each one falls faster, is smaller, and is worth more per
/// tap. Survive all three and the whole payout doubles.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/mini_games.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/game_tick.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart' show hudCoinInk;
import 'package:merge_empire_fc/ui/screens/minigames/keepy_uppys_sim.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/format.dart';

/// The arena's height, which is also the height the ball's fall is tuned
/// against — the JS's 280px box.
const double keepyArenaHeight = 280;

/// How long the miss card sits before the result, and the bonus card before it.
const Duration keepyMissBeat = Duration(milliseconds: 900);
const Duration keepyBonusBeat = Duration(milliseconds: 1000);

/// One frame at 60fps, which is what a `dt` of 1.0 means.
const double keepyFrameMs = 1000 / 60;

/// The gold the bonus card and its badge are written in.
const Color keepyBonusInk = Color(0xFFFBBF24);

class KeepyUppysScreen extends ConsumerStatefulWidget {
  const KeepyUppysScreen({super.key, this.random});

  final math.Random? random;

  @override
  ConsumerState<KeepyUppysScreen> createState() => KeepyUppysScreenState();
}

class KeepyUppysScreenState extends ConsumerState<KeepyUppysScreen>
    with SingleTickerProviderStateMixin {
  late final StateController<TickGates> _gates;
  late final GameState _game;
  late final math.Random _rng = widget.random ?? math.Random();
  late final Ticker _ticker;

  KeepyUppysSim? _sim;
  Duration _lastTick = Duration.zero;
  bool _over = false;
  bool _banked = false;
  int _coins = 0;
  Timer? _beat;

  /// Test seams.
  KeepyUppysSim? get sim => _sim;
  bool get over => _over;
  int get coinsWon => _coins;
  int get taps => _sim?.taps ?? 0;

  @override
  void initState() {
    super.initState();
    _gates = ref.read(tickGatesProvider.notifier);
    _game = ref.read(gameProvider);
    _ticker = createTicker(_onTick);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _gates.state = (
        matchOpen: false,
        miniGameOpen: true,
        transferOpen: false,
        colinOnScreen: false,
      );
      _game.update((s) => startMiniGame(s, MiniGameKind.keepyUppys));
    });
  }

  /// The arena's real size is not known until it is laid out, and the ball is
  /// placed against it — so the sim is built on the first layout rather than in
  /// `initState`.
  void _ensureSim(Size arena) {
    if (_sim != null) return;
    _sim = KeepyUppysSim(
      arenaW: arena.width,
      arenaH: arena.height,
      random: _rng.nextDouble,
    );
    if (!_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final sim = _sim;
    if (sim == null || _over) return;
    // dt is 1.0 at 60fps and capped at 3, so a frame lost to the app going away
    // teleports the ball a little rather than through the floor.
    final dt = math.min(
      (elapsed - _lastTick).inMicroseconds / 1000 / keepyFrameMs,
      3.0,
    );
    _lastTick = elapsed;
    if (dt <= 0) return;

    final alive = sim.step(dt);
    setState(() {});
    if (alive) return;
    if (sim.bonus) {
      _endWith(keepyBonusBeat, 'coin');
    } else {
      _endWith(keepyMissBeat, 'goalAgainst');
    }
  }

  /// Hold the card up for a beat, then show the result.
  void _endWith(Duration beat, String cue) {
    _ticker.stop();
    unawaited(ref.read(soundServiceProvider).play(cue));
    _beat = Timer(beat, () {
      if (!mounted) return;
      setState(() => _over = true);
    });
  }

  void _tapArena(Offset at) {
    final sim = _sim;
    if (sim == null || _over || sim.missed || sim.bonus) return;
    if (!sim.tap(at.dx, at.dy)) return;
    unawaited(ref.read(soundServiceProvider).play('tap'));
    setState(() {});
    // The full run stops the ball where it is — the run is complete and there
    // is nothing left to survive.
    if (sim.bonus) _endWith(keepyBonusBeat, 'coin');
  }

  /// Bank the session, once. Nothing to bank before the arena exists.
  int _award() {
    final sim = _sim;
    if (_banked || sim == null) return _coins;
    _banked = true;
    _coins = _game.update(
      (s) => recordKeepyUppysResult(s, taps: sim.bankedTaps),
    );
    return _coins;
  }

  void _collect() {
    final coins = _award();
    if (coins > 0) unawaited(ref.read(soundServiceProvider).play('coin'));
    Navigator.of(context).maybePop();
  }

  int get _preview => roundCoins(
    miniGameRewardBase(_game.state) *
        KeepyUppys.rewardPerTapMult *
        (_sim?.bankedTaps ?? 0),
  );

  @override
  void deactivate() {
    // Closing is not a forfeit — the taps made are banked on the way out.
    _award();
    final gates = _gates;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        gates.state = clearScreen;
      } on StateError {
        // The scope went first; nothing left to gate.
      }
    });
    super.deactivate();
  }

  @override
  void dispose() {
    _beat?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final sim = _sim;
    final stage = sim?.stage ?? keepyStages.first;

    return Scaffold(
      key: const ValueKey('keepy-uppys-screen'),
      backgroundColor: kit.bg,
      appBar: AppBar(title: Text(t('game.keepy_uppys'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t('game.keepy.taps', {'n': sim?.taps ?? 0}),
                    key: const ValueKey('ku-taps'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${stage.emoji ?? '⚫'} ${t(stage.labelKey)}'
                    '${stage.rewardMult > 1 ? ' ×${stage.rewardMult}' : ''}',
                    key: const ValueKey('ku-stage'),
                    style: TextStyle(fontSize: 11, color: kit.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: keepyArenaHeight,
                child: _Arena(
                  kit: kit,
                  sim: sim,
                  onLayout: _ensureSim,
                  onTap: _tapArena,
                  showHint: (sim?.taps ?? 0) == 0,
                ),
              ),
              const SizedBox(height: 10),
              if (_over) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Stat(
                      kit: kit,
                      label: t('game.keepy.taps_label'),
                      value: '${sim?.taps ?? 0}',
                      valueKey: const ValueKey('ku-total'),
                      colour: kit.accentBright,
                    ),
                    const SizedBox(width: 24),
                    Column(
                      children: [
                        _Stat(
                          kit: kit,
                          label: t('mg.reward'),
                          value: '+${formatCoins(_preview)} 💰',
                          valueKey: const ValueKey('ku-reward'),
                          colour: hudCoinInk,
                        ),
                        if (sim?.bonus ?? false)
                          Text(
                            '🏆 ×$keepyBonusMult ${t('game.keepy.bonus')}',
                            key: const ValueKey('ku-bonus-badge'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: keepyBonusInk,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  key: const ValueKey('ku-collect'),
                  onPressed: _collect,
                  child: Text(t('common.collect')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Arena extends StatelessWidget {
  const _Arena({
    required this.kit,
    required this.sim,
    required this.onLayout,
    required this.onTap,
    required this.showHint,
  });

  final KitTheme kit;
  final KeepyUppysSim? sim;
  final void Function(Size) onLayout;
  final void Function(Offset) onTap;
  final bool showHint;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFF1D8FE8),
      border: Border.all(color: kit.border, width: 2),
      borderRadius: BorderRadius.circular(12),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: LayoutBuilder(
        builder: (context, box) {
          final size = Size(box.maxWidth, box.maxHeight);
          // The ball is placed against the arena, so the sim cannot exist
          // before the arena has been measured.
          WidgetsBinding.instance.addPostFrameCallback((_) => onLayout(size));
          final ball = sim;
          return GestureDetector(
            key: const ValueKey('ku-arena'),
            behavior: HitTestBehavior.opaque,
            // Down, not up: the ball is falling, and waiting for the tap to be
            // ruled out as a scroll costs the player the reach.
            onTapDown: (details) => onTap(details.localPosition),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/bg/keepyuppy.jpg',
                    fit: BoxFit.cover,
                    // A missing backdrop leaves the sky behind it rather than
                    // an error box over the game.
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                const _Clouds(),
                if (ball != null)
                  Positioned(
                    left: ball.x - ball.stage.size / 2,
                    top: ball.y - ball.stage.size / 2,
                    width: ball.stage.size,
                    height: ball.stage.size,
                    child: Transform.rotate(
                      angle: ball.angle * math.pi / 180,
                      child: _Ball(
                        key: const ValueKey('ku-ball'),
                        stage: ball.stage,
                      ),
                    ),
                  ),
                if (ball != null && ball.missed)
                  Center(
                    child: Text(
                      t('game.keepy.missed'),
                      key: const ValueKey('ku-missed'),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFF87171),
                      ),
                    ),
                  ),
                if (ball != null && ball.bonus)
                  Center(
                    child: Text(
                      '🏆 ${t('game.keepy.bonus')}',
                      key: const ValueKey('ku-bonus'),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: keepyBonusInk,
                      ),
                    ),
                  ),
                if (showHint)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 10,
                    child: Text(
                      t('game.keepy.hint'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

/// The ball, whichever one it currently is.
class _Ball extends StatelessWidget {
  const _Ball({super.key, required this.stage});

  final KeepyStage stage;

  @override
  Widget build(BuildContext context) {
    final emoji = stage.emoji;
    if (emoji != null) {
      return Center(
        child: Text(emoji, style: TextStyle(fontSize: stage.size, height: 1)),
      );
    }
    // The cannonball is drawn rather than typed: there is no emoji for it, and
    // the JS hand-rolls an SVG for the same reason.
    return const DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFF888888), Color(0xFF444444), Color(0xFF111111)],
          stops: [0, 0.5, 1],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

/// Two clouds drifting across, on the JS's own periods.
class _Clouds extends StatefulWidget {
  const _Clouds();

  @override
  State<_Clouds> createState() => _CloudsState();
}

class _CloudsState extends State<_Clouds> with TickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 44),
  )..repeat();
  late final AnimationController _b = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 62),
    // The JS's -22s delay, as a starting phase: the two must not cross the sky
    // in step.
    value: 22 / 62,
  )..repeat();

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Stack(
      children: [
        _drift(_a, top: 0.05, widthFraction: 0.38, from: -0.34, box: box),
        _drift(_b, top: 0.18, widthFraction: 0.28, from: -0.24, box: box),
      ],
    ),
  );

  Widget _drift(
    Animation<double> t, {
    required double top,
    required double widthFraction,
    required double from,
    required BoxConstraints box,
  }) => AnimatedBuilder(
    animation: t,
    builder: (context, child) => Positioned(
      top: top * box.maxHeight,
      left: (from + (1.10 - from) * t.value) * box.maxWidth,
      width: widthFraction * box.maxWidth,
      child: child!,
    ),
    child: const _Cloud(),
  );
}

class _Cloud extends StatelessWidget {
  const _Cloud();

  @override
  Widget build(BuildContext context) => const AspectRatio(
    aspectRatio: 90 / 36,
    child: CustomPaint(painter: _CloudPainter()),
  );
}

class _CloudPainter extends CustomPainter {
  const _CloudPainter();

  /// The JS's own path, in its 90×36 viewBox, scaled to whatever it is given.
  @override
  void paint(Canvas canvas, Size size) {
    // Everything below is the viewBox's own coordinates times `k`.
    final k = size.width / 90;
    final path = Path()
      ..moveTo(18 * k, 28 * k)
      ..quadraticBezierTo(6 * k, 28 * k, 6 * k, 20 * k)
      ..quadraticBezierTo(6 * k, 12 * k, 14 * k, 12 * k)
      ..quadraticBezierTo(13 * k, 4 * k, 22 * k, 4 * k)
      ..quadraticBezierTo(30 * k, 2 * k, 33 * k, 9 * k)
      ..quadraticBezierTo(39 * k, 6 * k, 44 * k, 10 * k)
      ..quadraticBezierTo(52 * k, 7 * k, 55 * k, 14 * k)
      ..quadraticBezierTo(65 * k, 11 * k, 67 * k, 20 * k)
      ..quadraticBezierTo(72 * k, 27 * k, 64 * k, 28 * k)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_CloudPainter oldDelegate) => false;
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.kit,
    required this.label,
    required this.value,
    required this.valueKey,
    required this.colour,
  });

  final KitTheme kit;
  final String label, value;
  final Key valueKey;
  final Color colour;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: TextStyle(color: kit.textMuted, fontSize: 11)),
      Text(
        value,
        key: valueKey,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: colour,
        ),
      ),
    ],
  );
}
