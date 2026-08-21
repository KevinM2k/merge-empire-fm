/// Penalty Training — rebuilt as a simulation.
///
/// **The old game was a coin flip with a picture over it.** You tapped one of
/// four corners, the engine rolled `keeperSmartChance`, and a read was an
/// automatic save — so aim was a menu and everything else was luck. The scene was
/// a flat photograph with a keeper sprite slid across it, which meant a ball could
/// not hit a post, a net could not move, and three of the shipped outcome lines
/// were unreachable.
///
/// Now: one swipe carries the aim, the power and the curl; the ball is integrated
/// under gravity, drag and spin; and whether it goes in is where it ends up. See
/// `engine/penalty_physics.dart` for the simulation and `penalty_view.dart` for
/// the camera and the net.
///
/// A takeover, like the match, and it claims `tickGatesProvider.miniGameOpen`
/// while it is up: a modal over a mini-game would never be dismissed, which is
/// the reason that gate exists.
///
/// What is UNCHANGED is the banking: five attempts, and `recordPenaltyResult`
/// takes the count at the end. The engine that decided a shot is gone; the one
/// that pays for them is untouched.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'package:merge_empire_fc/data/mini_games.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_tick.dart';
import 'package:merge_empire_fc/engine/penalty_game_engine.dart'
    show keeperSmartChanceFor;
import 'package:merge_empire_fc/engine/penalty_physics.dart';
import 'package:merge_empire_fc/ui/screens/minigames/penalty_view.dart';
import 'package:merge_empire_fc/ui/screens/minigames/minigame_header.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/format.dart';

class PenaltyScreen extends ConsumerStatefulWidget {
  const PenaltyScreen({super.key});

  @override
  ConsumerState<PenaltyScreen> createState() => PenaltyScreenState();
}

class PenaltyScreenState extends ConsumerState<PenaltyScreen> {
  late final StateController<TickGates> _gates;

  /// One entry per attempt: what happened, and where the ball finished.
  final List<({PenaltyResult result, FramePart? frame, double x})> _taken = [];
  int _coins = 0;
  Timer? _clearFeedback;

  /// Test seams.
  int get scored => _taken.where((r) => r.result == PenaltyResult.goal).length;
  bool get finished => _taken.length >= Penalty.attempts;
  ({PenaltyResult result, FramePart? frame, double x})? get lastResult =>
      _taken.isEmpty ? null : _taken.last;

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
  void deactivate() {
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
    _clearFeedback?.cancel();
    super.dispose();
  }

  /// One kick, resolved by the simulation.
  ///
  /// **The screen does not decide anything.** It is handed the outcome and its
  /// only jobs are to count it, say it, and bank the round — which is what lets
  /// the whole simulation be tested without a frame being drawn.
  void _onResult(PenaltyResult result, FramePart? frame, double ballX) {
    if (!mounted || finished) return;
    final sound = ref.read(soundServiceProvider);
    unawaited(
      sound.play(result == PenaltyResult.goal ? 'goal' : 'goalAgainst'),
    );
    setState(() {
      _taken.add((result: result, frame: frame, x: ballX));
    });

    if (_taken.length >= Penalty.attempts) {
      // Banked once, at the end, from the engine's own count.
      final game = ref.read(gameProvider);
      final coins = game.update(
        (s) => recordPenaltyResult(s, scored: scored, total: Penalty.attempts),
      );
      setState(() => _coins = coins);
      if (coins > 0) unawaited(sound.play('coin'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final last = lastResult;

    return Scaffold(
      key: const ValueKey('penalty-screen'),
      backgroundColor: kit.bg,
      appBar: const MiniGameHeader(titleKey: 'game.penalty'),
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
                  t(penaltyCopyKey(last.result, last.frame, last.x)),
                  key: const ValueKey('penalty-feedback'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: last.result == PenaltyResult.goal
                        ? kit.accent
                        : Colors.redAccent,
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
                // Flexible, not fixed: the scene gives up height on a short
                // screen rather than pushing the score line off the top.
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: PenaltyView(
                      key: const ValueKey('penalty-view'),
                      readChance: keeperSmartChanceFor(
                        ref.read(gameProvider).state,
                      ),
                      turf: const Color(0xFF3A8C41),
                      onResult: _onResult,
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
