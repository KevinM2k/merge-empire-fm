/// Penalty Training — the first playable mini-game.
///
/// A takeover, like the match, and it claims `tickGatesProvider.miniGameOpen`
/// while it is up: a modal over a mini-game would never be dismissed, which is
/// the reason that gate exists.
///
/// The engine decides every shot. This picks a corner and shows what happened.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/mini_games.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/engine/penalty_game_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_tick.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/format.dart';

class PenaltyScreen extends ConsumerStatefulWidget {
  const PenaltyScreen({super.key});

  @override
  ConsumerState<PenaltyScreen> createState() => PenaltyScreenState();
}

class PenaltyScreenState extends ConsumerState<PenaltyScreen> {
  late final StateController<TickGates> _gates;

  final List<PenaltyShot> _taken = [];
  int _coins = 0;

  /// Test seams.
  int get scored => _taken.where((s) => s.scored).length;
  bool get finished => _taken.length >= Penalty.attempts;
  int get coinsWon => _coins;

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
      ref.read(gameProvider).update(
        (s) => startMiniGame(s, MiniGameKind.penalty),
      );
    });
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

  void _shoot(PenaltyCorner corner) {
    if (finished) return;
    final game = ref.read(gameProvider);
    final shot = takePenalty(game.state, corner);
    setState(() => _taken.add(shot));

    if (_taken.length >= Penalty.attempts) {
      // Banked once, at the end, from the engine's own count.
      final coins = game.update(
        (s) => recordPenaltyResult(s, scored: scored, total: Penalty.attempts),
      );
      setState(() => _coins = coins);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final last = _taken.isEmpty ? null : _taken.last;

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
                  last.scored ? t('mg.goal') : t('mg.saved'),
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
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      for (final corner in PenaltyCorner.values)
                        ElevatedButton(
                          key: ValueKey('penalty-${corner.name}'),
                          onPressed: () => _shoot(corner),
                          child: const Icon(Icons.sports_soccer),
                        ),
                    ],
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
