/// Penalty Training — the first playable mini-game.
///
/// A takeover, like the match, and it claims `tickGatesProvider.miniGameOpen`
/// while it is up: a modal over a mini-game would never be dismissed, which is
/// the reason that gate exists.
///
/// **The goal is the target.** You tap the goalmouth and the ball goes where you
/// put it — the interaction the shipped instruction line has always described
/// ("Tap anywhere — aim for corners or risk hitting the woodwork!") and the one
/// a grid of four corner buttons could not produce: with buttons there is no
/// way to miss, so `penalty.wide_left`, `penalty.post` and `penalty.crossbar`
/// were shipped copy that nothing could reach.
///
/// The engine still decides every ON-TARGET shot. Where the tap lands only
/// chooses which corner it is asked about; whether the keeper gets there is
/// `takePenalty`'s call, and the woodwork and the wayward shots never reach it
/// because the keeper had nothing to do with them.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'package:merge_empire_fc/data/mini_games.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/engine/penalty_game_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_tick.dart';
import 'package:merge_empire_fc/ui/screens/minigames/keeper_figure.dart';
import 'package:merge_empire_fc/ui/screens/minigames/minigames_providers.dart';
import 'package:merge_empire_fc/ui/screens/minigames/penalty_scene.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/format.dart';

class PenaltyScreen extends ConsumerStatefulWidget {
  const PenaltyScreen({super.key});

  @override
  ConsumerState<PenaltyScreen> createState() => PenaltyScreenState();
}

class PenaltyScreenState extends ConsumerState<PenaltyScreen> {
  late final StateController<TickGates> _gates;

  final List<ShotResult> _taken = [];
  int _coins = 0;

  /// True while a strike is playing out, so a second tap cannot fire through
  /// the animation and spend two of the five attempts on one decision.
  bool _shooting = false;
  Timer? _resetTimer;

  /// Where the ball and the keeper are, in scene percent.
  ({double x, double y}) _ball = _spot;
  ({double x, double y}) _keeper = _line;
  bool _ballVisible = true;

  /// Which way he went, so the figure can be POSED rather than slid across.
  KeeperPose _pose = KeeperPose.ready;

  static const ({double x, double y}) _spot = (x: 50, y: 78);

  /// On the goal line, which is the ground — not 34% up the picture, where he
  /// was standing in mid-air under his own crossbar.
  static const ({double x, double y}) _line = (x: 50, y: goalLinePercent);

  /// Test seams.
  int get scored => _taken.where((r) => r.scored).length;
  bool get finished => _taken.length >= Penalty.attempts;
  int get coinsWon => _coins;
  ShotResult? get lastResult => _taken.isEmpty ? null : _taken.last;

  @override
  void initState() {
    super.initState();
    _gates = ref.read(tickGatesProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _gates.state = (
        matchOpen: false,
        miniGameOpen: true,
        transferOpen: false,
        colinOnScreen: false,
      );
      // The cooldown starts when the player STARTS, not when they finish, so
      // walking away mid-round cannot farm the reward timer.
      ref
          .read(gameProvider)
          .update((s) => startMiniGame(s, MiniGameKind.penalty));
    });
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  void deactivate() {
    final gates = _gates;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        gates.state = clearScreen;
      } on StateError {
        // The scope went first; there are no ticks left to gate.
      }
    });
    super.deactivate();
  }

  /// A tap on the goalmouth, in scene percentages.
  void shootAt(double x, double y) {
    if (finished || _shooting) return;
    final game = ref.read(gameProvider);
    final aim = resolveAim(x, y);

    final ShotResult result;
    var keeperTo = _line;
    if (aim.corner == null) {
      // Off target, or off the frame. The keeper stays where he was — he never
      // had to move, and diving at a shot going wide would read as a save.
      result = aim.miss!;
    } else {
      final shot = takePenalty(game.state, aim.corner!);
      keeperTo = keeperLanding(shot.keeper);
      result = shot.scored ? ShotResult.goal : ShotResult.saved;
    }

    // The strike, then whatever became of it — the JS's own pair, and the order
    // matters: the ball is hit before anyone knows where it went.
    final sound = ref.read(soundServiceProvider);
    unawaited(sound.play('shotKick'));
    Timer(const Duration(milliseconds: 260), () {
      if (mounted) {
        unawaited(
          sound.play(result == ShotResult.goal ? 'goal' : 'goalAgainst'),
        );
      }
    });

    setState(() {
      _shooting = true;
      _taken.add(result);
      // The ball goes where it was AIMED, whatever happened to it, so a save
      // and a goal look like the same strike until the keeper gets there.
      _ball = (x: aim.x, y: aim.y);
      _keeper = keeperTo;
      // A dive he never had to make would read as a save he nearly got to.
      _pose = aim.corner == null
          ? KeeperPose.ready
          : poseFor(
              x: keeperTo.x,
              y: keeperTo.y,
              midX: (goalFrame.left + goalFrame.right) / 2,
            );
    });

    if (_taken.length >= Penalty.attempts) {
      // Banked once, at the end, from the engine's own count.
      final coins = game.update(
        (s) => recordPenaltyResult(s, scored: scored, total: Penalty.attempts),
      );
      setState(() => _coins = coins);
      if (coins > 0) unawaited(sound.play('coin'));
    }

    // Back to the spot once the strike has been seen.
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _shooting = false;
        _ballVisible = !finished;
        _ball = _spot;
        _keeper = _line;
        _pose = KeeperPose.ready;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final last = lastResult;

    return Scaffold(
      key: const ValueKey('penalty-screen'),
      backgroundColor: kit.bg,
      appBar: AppBar(title: Text(t('game.penalty'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                '${_taken.length} / ${Penalty.attempts}',
                key: const ValueKey('penalty-progress'),
                style: TextStyle(color: kit.textMuted),
              ),
              const SizedBox(height: 4),
              Text(
                '${t('mg.scored')}: $scored',
                key: const ValueKey('penalty-scored'),
                style: TextStyle(
                  color: kit.accentBright,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (last != null)
                Text(
                  t(last.copyKey),
                  key: const ValueKey('penalty-feedback'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: last.scored ? kit.accent : Colors.redAccent,
                  ),
                ),
              const SizedBox(height: 12),
              if (!finished) ...[
                Text(
                  t('game.penalty.instructions'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kit.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                // Flexible, not fixed: the scene keeps the artwork's aspect and
                // gives up height on a short screen rather than pushing the
                // score line off the top.
                Expanded(
                  child: Center(
                    child: PenaltyScene(
                      onShoot: shootAt,
                      ball: _ball,
                      keeper: _keeper,
                      keeperTier: keeperTierForDivision(
                        ref.watch(divisionIndexProvider),
                      ),
                      keeperPose: _pose,
                      ballVisible: _ballVisible,
                    ),
                  ),
                ),
              ] else ...[
                const Spacer(),
                Text(
                  t('mg.reward'),
                  style: TextStyle(color: kit.textMuted, fontSize: 12),
                ),
                Text(
                  formatCoins(_coins),
                  key: const ValueKey('penalty-reward'),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: kit.accentBright,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const ValueKey('penalty-done'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(t('common.close')),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
