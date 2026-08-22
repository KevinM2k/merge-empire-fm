/// Goalkeeper Practice — the drill session.
///
/// A sixteen-second watch bar with drill bubbles that appear one at a time. Tap
/// each inside its window. Both the drill count and the width of that window
/// scale with division, so it stays a session rather than a formality at the
/// top of the pyramid.
///
/// The drills are placed on a SCHEDULE worked out up front rather than spawned
/// at random intervals: a lead-in so the first one does not land before the
/// player is looking, a cool-down over the last tenth so the last one is not cut
/// off, and the rest spread evenly through what is left. That is what makes the
/// count a promise — `game.training.intro` says how many are coming, and a
/// random spawner could not keep to it.
///
/// **The energy grant is zero and the code that reads it stays.** The only
/// energy this game pays comes from the three-day streak milestone; the clamp is
/// the JS's, and it is the reason the preview cannot render "+-4⚡" when a
/// streak bonus has already pushed the tank over its cap.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/divisions.dart'
    show currentDivisionIndex;
import 'package:merge_empire_fc/data/mini_games.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/game_tick.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart' show hudCoinInk;
import 'package:merge_empire_fc/ui/screens/minigames/minigame_header.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/util/time.dart';

/// Small enough that the watch bar moves smoothly and a drill lands on time.
const int trainingTickMs = 100;

/// How long a hit or a miss stays on the stage.
const Duration drillFlash = Duration(milliseconds: 400);

/// The five drill faces, in the order they come round.
const List<String> drillFaces = ['⚽', '🏃', '🎯', '⚡', '🔥'];

/// When each drill is due, in milliseconds from the start of the session.
///
/// The last tenth is a cool-down, so the final drill's window closes inside the
/// session rather than being cut off by the whistle.
List<int> drillTimes(int drillCount) {
  final coolDown = Training.durationMs * 0.1;
  final usable = Training.durationMs - Training.leadInMs - coolDown;
  return [
    for (var i = 0; i < drillCount; i++)
      (Training.leadInMs + ((i + 0.5) / drillCount) * usable).round(),
  ];
}

class GoalkeeperPracticeScreen extends ConsumerStatefulWidget {
  const GoalkeeperPracticeScreen({super.key, this.random});

  /// Injectable so a test gets the same bubble placement twice.
  final math.Random? random;

  @override
  ConsumerState<GoalkeeperPracticeScreen> createState() =>
      GoalkeeperPracticeScreenState();
}

class GoalkeeperPracticeScreenState
    extends ConsumerState<GoalkeeperPracticeScreen> {
  late final StateController<TickGates> _gates;
  late final GameState _game;
  late final math.Random _rng = widget.random ?? math.Random();
  late final int _drillCount;
  late final int _windowMs;
  late final List<int> _due;

  Timer? _ticker;
  Timer? _clearFlash;
  int _startedAt = 0;
  int _elapsed = 0;
  int _appeared = 0;
  int _hit = 0;

  /// The bubble on the stage, or null between drills.
  ({int index, int expiresAt, double top, double left})? _drill;

  /// '✓', '✗' or null.
  String? _flash;
  bool _flashGood = false;
  bool _done = false;
  bool _banked = false;
  int _coins = 0;

  /// Test seams.
  int get drillsHit => _hit;
  int get drillsAppeared => _appeared;
  int get drillCount => _drillCount;
  bool get done => _done;
  bool get drillUp => _drill != null;
  int get coinsWon => _coins;

  @override
  void initState() {
    super.initState();
    _gates = ref.read(tickGatesProvider.notifier);
    _game = ref.read(gameProvider);
    final difficulty = trainingDifficulty(currentDivisionIndex(_game.state));
    _drillCount = difficulty.drills;
    _windowMs = difficulty.windowMs;
    _due = drillTimes(_drillCount);

    _startedAt = now();
    _ticker = Timer.periodic(
      const Duration(milliseconds: trainingTickMs),
      (_) => _tick(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _gates.state = (
        matchOpen: false,
        miniGameOpen: true,
        transferOpen: false,
        colinOnScreen: false,
      );
      // On entry, like every other drill: walking away mid-session must not
      // farm the reward timer.
      _game.update((s) => startMiniGame(s, MiniGameKind.training));
    });
  }

  void _tick() {
    if (!mounted || _done) return;
    setState(() => _elapsed = now() - _startedAt);

    if (_drill == null && _appeared < _drillCount) {
      if (_elapsed >= _due[_appeared]) _spawn();
    }
    // Checked every tick so the window closes promptly rather than whenever a
    // timer happens to fire.
    final drill = _drill;
    if (drill != null && now() >= drill.expiresAt) _miss();

    if (_elapsed >= Training.durationMs) _finish();
  }

  void _spawn() {
    setState(() {
      _appeared++;
      _flash = null;
      _drill = (
        index: _appeared - 1,
        expiresAt: now() + _windowMs,
        // The same bands as the JS, as fractions of the stage: never against an
        // edge, and never in the same place twice running by luck alone.
        top: 0.15 + _rng.nextDouble() * 0.55,
        left: 0.10 + _rng.nextDouble() * 0.70,
      );
    });
  }

  void _hitDrill() {
    if (_drill == null || _done) return;
    unawaited(ref.read(soundServiceProvider).play('tap'));
    setState(() {
      _drill = null;
      _hit++;
    });
    _showFlash('✓', good: true);
  }

  void _miss() {
    setState(() => _drill = null);
    _showFlash('✗', good: false);
  }

  void _showFlash(String mark, {required bool good}) {
    setState(() {
      _flash = mark;
      _flashGood = good;
    });
    _clearFlash?.cancel();
    _clearFlash = Timer(drillFlash, () {
      if (!mounted) return;
      setState(() => _flash = null);
    });
  }

  void _finish() {
    if (_done) return;
    _ticker?.cancel();
    _clearFlash?.cancel();
    setState(() {
      _done = true;
      _drill = null;
      _flash = null;
      _elapsed = Training.durationMs;
    });
    unawaited(ref.read(soundServiceProvider).play('whistle'));
  }

  /// Bank the session, once.
  int _award() {
    if (_banked) return _coins;
    _banked = true;
    _coins = _game
        .update(
          (s) => recordTrainingComplete(
            s,
            drillsHit: _hit,
            drillTotal: _drillCount,
          ),
        )
        .coins;
    return _coins;
  }

  void _collect() {
    final coins = _award();
    if (coins > 0) unawaited(ref.read(soundServiceProvider).play('coin'));
    Navigator.of(context).maybePop();
  }

  int get _previewCoins => roundCoins(
    miniGameRewardBase(_game.state) *
        Training.rewardBaseMult *
        (_hit / math.max(1, _drillCount)),
  );

  /// Clamped at zero, which is the JS's own guard: a streak bonus can push the
  /// tank OVER its cap, and `max - current` going negative would render the
  /// preview as "+-4⚡".
  int get _previewEnergy {
    final energy = _game.state?['energy'];
    final current = energy is Map<String, dynamic>
        ? (energy['current'] as num?)?.toInt() ?? 0
        : 0;
    return math.max(0, math.min(Training.energyGrant, Energy.max - current));
  }

  @override
  void deactivate() {
    // Closing is not a forfeit — the drills hit are banked on the way out.
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
    _ticker?.cancel();
    _clearFlash?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final pct = math.min(100.0, _elapsed / Training.durationMs * 100);

    return Scaffold(
      key: const ValueKey('goalkeeper-practice-screen'),
      backgroundColor: kit.bg,
      appBar: const MiniGameHeader(titleKey: 'game.training'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          // The summary REPLACES the session rather than stacking under it —
          // the JS hides the bar, the stage and the status line for exactly
          // this reason, so the collect button lands where the drills were.
          child: _done
              ? _Summary(
                  kit: kit,
                  hit: _hit,
                  total: _drillCount,
                  coins: _previewCoins,
                  energy: _previewEnergy,
                  onCollect: _collect,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      t('game.training.intro', {
                        'n': _drillCount,
                        'secs': (_windowMs / 1000).toStringAsFixed(1),
                      }),
                      key: const ValueKey('train-intro'),
                      style: TextStyle(color: kit.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    _WatchBar(kit: kit, pct: pct),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _Stage(
                        kit: kit,
                        drill: _drill,
                        windowMs: _windowMs,
                        flash: _flash,
                        flashGood: _flashGood,
                        idleText: _appeared == 0
                            ? t('mg.warming_up')
                            : t('mg.keep_going'),
                        onHit: _hitDrill,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          t('mg.drills', {'hit': _hit, 'total': _drillCount}),
                          key: const ValueKey('train-drills'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${math.max(0, ((Training.durationMs - _elapsed) / 1000).ceil())}s',
                          key: const ValueKey('train-time'),
                          style: TextStyle(
                            color: kit.textMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
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

class _WatchBar extends StatelessWidget {
  const _WatchBar({required this.kit, required this.pct});

  final KitTheme kit;
  final double pct;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: kit.surface2,
      border: Border.all(color: kit.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 16,
        child: Stack(
          children: [
            // scaleX rather than a width, which is what the JS settled on: this
            // is written every hundred milliseconds for the whole session.
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  key: const ValueKey('train-bar-fill'),
                  widthFactor: (pct / 100).clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kit.accent, kit.accentBright],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: Text(
                '${pct.floor()}%',
                key: const ValueKey('train-bar-label'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Where the drills appear.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.kit,
    required this.drill,
    required this.windowMs,
    required this.flash,
    required this.flashGood,
    required this.idleText,
    required this.onHit,
  });

  final KitTheme kit;
  final ({int index, int expiresAt, double top, double left})? drill;
  final int windowMs;
  final String? flash;
  final bool flashGood;
  final String idleText;
  final VoidCallback onHit;

  @override
  Widget build(BuildContext context) {
    final current = drill;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kit.surface2,
        border: Border.all(color: kit.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            key: const ValueKey('train-stage'),
            children: [
              if (current == null && flash == null)
                Center(
                  child: Text(
                    idleText,
                    style: TextStyle(fontSize: 14, color: kit.textMuted),
                  ),
                ),
              if (flash != null)
                Center(
                  child: Text(
                    flash!,
                    key: const ValueKey('train-flash'),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: flashGood ? kit.accentBright : Colors.red,
                    ),
                  ),
                ),
              if (current != null)
                Positioned(
                  top: current.top * box.maxHeight,
                  left: current.left * box.maxWidth,
                  child: _Bubble(
                    // Keyed by drill, so the ring and the pulse restart with
                    // each one instead of carrying the last one's progress.
                    key: ValueKey('train-bubble-${current.index}'),
                    kit: kit,
                    face: drillFaces[current.index % drillFaces.length],
                    windowMs: windowMs,
                    onTap: onHit,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

const double bubbleSize = 56;

class _Bubble extends StatefulWidget {
  const _Bubble({
    super.key,
    required this.kit,
    required this.face,
    required this.windowMs,
    required this.onTap,
  });

  final KitTheme kit;
  final String face;
  final int windowMs;
  final VoidCallback onTap;

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.windowMs ~/ 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: bubbleSize,
    height: bubbleSize,
    child: Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // The ring closing in, so the window tightening is something the player
        // can SEE rather than something they have to have learnt.
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: Duration(milliseconds: widget.windowMs),
          curve: Curves.linear,
          builder: (context, t, child) => Transform.scale(
            scale: 1.8 - 0.8 * t,
            child: Opacity(opacity: (1 - t).clamp(0.0, 1.0), child: child),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: const SizedBox(width: bubbleSize, height: bubbleSize),
          ),
        ),
        GestureDetector(
          key: const ValueKey('train-bubble'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1, end: 1.15).animate(_pulse),
            child: Container(
              width: bubbleSize,
              height: bubbleSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                gradient: RadialGradient(
                  center: const Alignment(-0.4, -0.4),
                  colors: [widget.kit.accentBright, widget.kit.accent],
                ),
              ),
              child: Text(
                widget.face,
                style: const TextStyle(fontSize: 24, height: 1),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.kit,
    required this.hit,
    required this.total,
    required this.coins,
    required this.energy,
    required this.onCollect,
  });

  final KitTheme kit;
  final int hit, total, coins, energy;
  final VoidCallback onCollect;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('train-summary'),
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Text('🏁', style: TextStyle(fontSize: 26)),
      const SizedBox(height: 8),
      Text(
        t('game.training.session_complete'),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(
        t('game.training.drills_hit', {'hit': hit, 'total': total}),
        key: const ValueKey('train-drills-hit'),
        style: TextStyle(fontSize: 13, color: kit.textMuted),
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Stat(
            kit: kit,
            label: t('game.training.coins'),
            value: '+${formatCoins(coins)} 💰',
            valueKey: const ValueKey('train-reward'),
            colour: hudCoinInk,
          ),
          // Zero today: the only energy this game pays is the streak
          // milestone's, so the block is hidden rather than showing "+0⚡".
          if (energy > 0) ...[
            const SizedBox(width: 18),
            _Stat(
              kit: kit,
              label: t('game.training.energy'),
              value: '+$energy⚡',
              valueKey: const ValueKey('train-energy'),
              colour: kit.accentBright,
            ),
          ],
        ],
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          key: const ValueKey('train-collect'),
          onPressed: onCollect,
          child: Text(t('common.collect')),
        ),
      ),
    ],
  );
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
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: colour,
        ),
      ),
    ],
  );
}
