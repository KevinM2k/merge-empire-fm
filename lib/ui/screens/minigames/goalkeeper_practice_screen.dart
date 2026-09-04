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
import 'package:merge_empire_fc/ui/hud/hud.dart'
    show hudBadgeColour, hudBadgeInk, hudCoinInk, hudEnergyInk;
import 'package:merge_empire_fc/ui/screens/minigames/keeper_view.dart';
import 'package:merge_empire_fc/ui/screens/minigames/minigame_countdown.dart';
import 'package:merge_empire_fc/ui/screens/minigames/minigame_header.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/util/time.dart';

/// Small enough that the watch bar moves smoothly and a drill lands on time.
const int trainingTickMs = 100;

/// How long a hit or a miss stays on the stage.
const Duration drillFlash = Duration(milliseconds: 400);

/// **EVERY SHOT IS A FOOTBALL.** It was five faces in rotation — a runner, a
/// target, a bolt, a flame — which is a list of drills rather than a keeper
/// facing shots. There is one thing coming at a goalkeeper.
const String drillFace = '⚽';

/// How wide a ball is when it is struck, against how wide it is when it reaches
/// you.
///
/// **It has to GROW.** A flat scene has exactly one cue for a ball travelling
/// toward the camera and this is it — the same reading the penalty scene got
/// from `_eyeZ`, which this game never had. Starting at a quarter and arriving
/// at full size is a ball hit from the edge of the box.
const double drillStartScale = 0.28;

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

/// This shot's window, jittered either side of the session's own.
///
/// **Shots that all arrive at exactly the same speed are a metronome**, and
/// after two of them the player is not reacting, they are counting — which is
/// what made this too easy. The division's ramp still sets the middle, so the
/// whole game gets harder as you climb; what changes is that no two shots in a
/// row are the same shot.
///
/// [roll] is 0..1. Pure so the spread can be pinned without a screen.
int drillWindowFor(int sessionMs, double roll) {
  const spread = 0.34;
  // Never longer than the session's own window: a jitter that can make a shot
  // EASIER than the division asked for is a ramp with a hole in it.
  final scale = 1 - spread * roll.clamp(0.0, 1.0);
  return math.max(360, (sessionMs * scale).round());
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
  ///
  /// [windowMs] is per DRILL, not per session: shots that all arrive at exactly
  /// the same speed are a metronome, and a metronome is what made this too
  /// easy — after two you are not reacting, you are counting.
  ({int index, int expiresAt, int windowMs, double top, double left})? _drill;

  /// '✓', '✗' or null.
  String? _flash;
  bool _flashGood = false;

  /// **THE SESSION DOES NOT START UNTIL THE COUNT DOES.** The watch bar and
  /// the shot schedule both run off [_startedAt], and it used to be set in
  /// `initState` — so the first ball was in flight before the player had
  /// looked at the goal. See `MiniGameCountdown`.
  bool _counting = true;
  bool _done = false;
  bool _banked = false;
  int _coins = 0;

  /// Test seams.
  int get drillsHit => _hit;
  int get drillsAppeared => _appeared;
  int get drillCount => _drillCount;
  bool get done => _done;
  bool get drillUp => _drill != null;
  bool get counting => _counting;
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

  /// GO. Everything the session measures starts from here.
  void _kickOff() {
    if (!mounted) return;
    setState(() {
      _counting = false;
      _startedAt = now();
      _elapsed = 0;
    });
    _ticker = Timer.periodic(
      const Duration(milliseconds: trainingTickMs),
      (_) => _tick(),
    );
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

    // **THE WHISTLE IS THE LAST SHOT, not the clock.** Sitting on an empty
    // scene watching a bar run down is the player being made to watch nothing
    // happen; every shot has been faced, so the session is over. The flash is
    // waited out first — the ✓ or ✗ on the last one is the answer to it.
    if (_appeared >= _drillCount && _drill == null && _flash == null) {
      _finish();
      return;
    }
    if (_elapsed >= Training.durationMs) _finish();
  }

  void _spawn() {
    // **A SHOT AT A TIME, not a shot every time.** The window jitters either
    // side of the session's own — which is still the division's ramp, so the
    // whole thing gets harder as you climb; what changes is that two shots in a
    // row are never the same shot.
    final window = drillWindowFor(_windowMs, _rng.nextDouble());
    setState(() {
      _appeared++;
      _flash = null;
      _drill = (
        index: _appeared - 1,
        expiresAt: now() + window,
        windowMs: window,
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
                    // **THE GOAL KEEPS ITS SHAPE; THE SURPLUS BECOMES SCENE.**
                    //
                    // The stage is `keeperStageAspect` and always was, because
                    // the frame IS the goal — `_paintFrame` runs the uprights
                    // from the bar to the foot of the box, so a stage given
                    // the whole column stretches the mouth into a doorway.
                    // That was tried and reported straight back: the goal is
                    // the wrong size.
                    //
                    // What was actually wrong is what surrounded it. A tall
                    // phone left the surplus as two bands of PAGE, over and
                    // under the pitch — reported before that, with the fix
                    // named: sky above, grass below. So the bands take the
                    // scene's own colours and the goal is untouched. See
                    // [_StageSurround].
                    Expanded(
                      child: _StageSurround(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: keeperStageAspect,
                            // The count goes over the GOAL, which is what the
                            // player has to have found before the first ball
                            // is struck.
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: _Stage(
                                    kit: kit,
                                    drill: _drill,
                                    flash: _flash,
                                    flashGood: _flashGood,
                                    idleText: _appeared == 0
                                        ? t('mg.warming_up')
                                        : t('mg.keep_going'),
                                    onHit: _hitDrill,
                                  ),
                                ),
                                if (_counting)
                                  Positioned.fill(
                                    child: MiniGameCountdown(
                                      onDone: _kickOff,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
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
                  fontSize: 12,
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
    required this.flash,
    required this.flashGood,
    required this.idleText,
    required this.onHit,
  });

  final KitTheme kit;
  final ({int index, int expiresAt, int windowMs, double top, double left})?
  drill;
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
              // **THE VIEW FROM THE GOAL, out.** It was the forest backdrop
              // with a ball growing on it — a horizon, which was the previous
              // pass, but nothing between the horizon and the shot. So the one
              // thing in the frame that said where the camera stood was the
              // growth itself. Reported from the couch in as many words: the
              // posts and the pitch in front of us, and then exactly what we do
              // now. [KeeperView] is that scene, and it holds the backdrop —
              // still FOREST, so the two drills with a goal in them are not the
              // same picture with different rules on top — because the treeline
              // has to land on the pitch's own horizon rather than wherever a
              // fit puts it.
              const Positioned.fill(child: KeeperView()),
              if (current == null && flash == null)
                Center(
                  child: Text(
                    idleText,
                    // **WHITE, because the stage is not the page.** This took
                    // `kit.textMuted`, which is chosen against a surface — on
                    // the floodlit pitch behind it that is grey on green.
                    // Reported from the couch.
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Color(0x8C000000), blurRadius: 3),
                      ],
                    ),
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
                _drillBall(
                  kit: kit,
                  drill: current,
                  stage: Size(box.maxWidth, box.maxHeight),
                  onHit: onHit,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

const double bubbleSize = 56;

/// Where a drill's ball goes, from its two rolls and the stage it is on.
///
/// **The bands are FRACTIONS and the ball is 56 points**, and the two only
/// agreed by luck. On a 384-point stage a roll at the top of the left band put
/// the ball's right edge three tenths of a point inside the right post; on a
/// 320-point phone it put fifteen points of it BEHIND the post. Nothing said
/// so while the stage was a photograph — a ball near the edge was just a ball
/// near the edge — and the frame is what makes it a fault.
///
/// So the roll is an aim point and the mouth is what it cannot leave: placed
/// exactly where it has always been placed, then held inside the posts and
/// under the bar by the ball's own radius. The spread is unchanged on a stage
/// wide enough to hold it, which is every phone the bands were tuned on.
///
/// Pure, so the two ends — the bands in `_spawn`, the frame in
/// `keeper_view.dart` — can be checked against each other without a screen.
Offset drillCentre(double top, double left, Size stage) {
  const half = bubbleSize / 2;
  double held(double want, double lo, double hi) =>
      want.clamp(lo, math.max(lo, hi));
  return Offset(
    held(
      left * stage.width + half,
      keeperMouthLeft * stage.width + half,
      keeperMouthRight * stage.width - half,
    ),
    held(
      top * stage.height + half,
      keeperBarBottom * stage.width + half,
      stage.height - half,
    ),
  );
}

/// The ball on its mark.
///
/// A FUNCTION rather than a widget, and that is a Flutter rule rather than a
/// preference: `Positioned` has to be the `Stack`'s own child, so a widget
/// class whose `build` returns one is silently ignored and the ball lands in
/// the top-left corner. A function hands the Stack the `Positioned` itself.
Positioned _drillBall({
  required KitTheme kit,
  required ({int index, int expiresAt, int windowMs, double top, double left})
  drill,
  required Size stage,
  required VoidCallback onHit,
}) {
  final centre = drillCentre(drill.top, drill.left, stage);
  return Positioned(
    top: centre.dy - bubbleSize / 2,
    left: centre.dx - bubbleSize / 2,
    child: _Bubble(
      // Keyed by drill, so the ring and the pulse restart with each one
      // instead of carrying the last one's progress.
      key: ValueKey('train-bubble-${drill.index}'),
      kit: kit,
      face: drillFace,
      windowMs: drill.windowMs,
      onTap: onHit,
    ),
  );
}

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

class _BubbleState extends State<_Bubble> {
  @override
  Widget build(BuildContext context) => SizedBox(
    width: bubbleSize,
    height: bubbleSize,
    child: GestureDetector(
      key: const ValueKey('train-bubble'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      // **THE BALL COMING AT YOU, and nothing round it.** It was a coloured
      // disc with a white rim and a face inside, pulsing — which is a button
      // with a picture on it, not a shot. The rim went with the disc, and the
      // ring that used to close in went with them: the GROWTH is the clock now,
      // and it is the same reading rather than a second one. A flat scene has
      // exactly one cue for a ball travelling toward the camera.
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: drillStartScale, end: 1),
        duration: Duration(milliseconds: widget.windowMs),
        // Eased OUT: a struck ball covers most of the ground early and looms in
        // the last instant, which is also what makes the late save the hard one.
        curve: Curves.easeOutQuad,
        builder: (context, t, child) => Center(
          child: SizedBox(
            width: bubbleSize * t,
            height: bubbleSize * t,
            child: FittedBox(child: child),
          ),
        ),
        child: Text(
          widget.face,
          style: const TextStyle(fontSize: 40, height: 1),
        ),
      ),
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
            value: '+${formatCoins(coins)}',
            icon: 'coin',
            valueKey: const ValueKey('train-reward'),
            colour: hudCoinInk,
          ),
          // Zero today: the only energy this game pays is the streak
          // milestone's, so the block is hidden rather than showing "+0".
          if (energy > 0) ...[
            const SizedBox(width: 18),
            _Stat(
              kit: kit,
              label: t('game.training.energy'),
              value: '+$energy',
              icon: 'bolt',
              // The HUD's energy green, not the club accent: this is a wallet,
              // and a wallet's colour does not change with the kit.
              valueKey: const ValueKey('train-energy'),
              colour: hudEnergyInk,
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

/// Sky over the stage and grass under it, so the letterbox is not the page.
///
/// **THE BANDS WERE THE FAULT, NOT THE RATIO.** The goal has to keep its own
/// shape — the uprights run from the bar to the foot of the stage, so a stage
/// stretched to the column's height is a doorway — and a phone taller than
/// `keeperStageAspect` therefore has height left over. It used to show the
/// page through it, two grey strips clamping the pitch. Asked for from the
/// couch: keep the goal's proper height, put a sky above it and grass below.
///
/// The split is where the stage's own horizon lands, so the turf behind the
/// bottom band continues the turf inside the picture and the seam is only
/// where the stage's rounded corner is.
class _StageSurround extends StatelessWidget {
  const _StageSurround({required this.child});

  final Widget child;

  /// The scene's own sky, taken from the top of the forest backdrop the stage
  /// draws — a band in a different blue would read as a second picture.
  static const Color _sky = Color(0xFF9FC7E8);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // Where the stage sits once it has taken its own shape, and therefore
      // where its horizon lands in the taller box.
      final stageH = math.min(box.maxHeight, box.maxWidth / keeperStageAspect);
      final top = (box.maxHeight - stageH) / 2;
      final horizon = top + keeperHorizon * stageH;
      return Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                SizedBox(height: horizon, child: const ColoredBox(color: _sky)),
                const Expanded(child: ColoredBox(color: drillTurf)),
              ],
            ),
          ),
          Positioned.fill(child: child),
        ],
      );
    },
  );
}

/// One figure the session paid, in its wallet's own badge.
///
/// **A BADGE, not a coloured number with an emoji after it.** It printed
/// `+175 💰` in `hudCoinInk`, which on a light page is the deep bronze
/// `coinFigureInk` answers — reported from the couch as a horrible bronze, and
/// the emoji is a second currency mark beside the app's own. `hudBadgeColour`
/// fills the chip in the wallet's colour and `hudBadgeInk` prints on it, which
/// is what the bar, the pack contents and the season quests all wear.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.kit,
    required this.label,
    required this.value,
    required this.icon,
    required this.valueKey,
    required this.colour,
  });

  final KitTheme kit;
  final String label, value;

  /// A `gameIcons` name — the app's own line art, in place of the emoji.
  final String icon;
  final Key valueKey;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final face = hudBadgeColour(colour);
    final ink = hudBadgeInk(face);
    return Column(
      children: [
        Text(label, style: TextStyle(color: kit.textMuted, fontSize: 12)),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.fromLTRB(9, 3, 11, 3),
          decoration: BoxDecoration(
            color: face,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameIcon(icon, size: 15, color: ink),
              const SizedBox(width: 5),
              Text(
                value,
                key: valueKey,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
