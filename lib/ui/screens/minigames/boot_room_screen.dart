/// The Boot Room — a match-three over kit tiles.
///
/// Every rule is `boot_room_engine`'s: what matches, how a board collapses and
/// refills, and whether a swap is legal. This picks two cells and plays the
/// cascades back, because watching the second and third clear land is the whole
/// point of a match-three — the engine returns them as separate steps for
/// exactly that reason.
library;

import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/mini_games.dart';
import 'package:merge_empire_fc/engine/boot_room_engine.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_tick.dart';
import 'package:merge_empire_fc/ui/screens/minigames/minigame_header.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/format.dart';

/// One colour per kit type. Six, because the top divisions add a sixth.
const List<Color> kitTileColours = [
  Color(0xFF4CAF50),
  Color(0xFF2196F3),
  Color(0xFFFFC107),
  Color(0xFFE91E63),
  Color(0xFF9C27B0),
  Color(0xFF00BCD4),
];

int divisionIndexOf(Map<String, dynamic>? state) {
  final progression = state?['progression'];
  final id = progression is Map<String, dynamic>
      ? progression['currentDivision']
      : null;
  return math.max(0, divisions.indexWhere((d) => d.id == id));
}

class BootRoomScreen extends ConsumerStatefulWidget {
  const BootRoomScreen({super.key});

  @override
  ConsumerState<BootRoomScreen> createState() => BootRoomScreenState();
}

class BootRoomScreenState extends ConsumerState<BootRoomScreen> {
  late final StateController<TickGates> _gates;
  late final BootRoomDifficulty _difficulty;
  final math.Random _rng = math.Random();

  List<int?> _board = const [];
  int _movesLeft = 0;
  int _cleared = 0;
  int _selected = -1;
  int _coins = 0;
  bool _finished = false;

  /// Test seams.
  int get tilesCleared => _cleared;
  int get movesLeft => _movesLeft;
  bool get finished => _finished;
  int get coinsWon => _coins;
  List<int?> get board => _board;

  @override
  void initState() {
    super.initState();
    _gates = ref.read(tickGatesProvider.notifier);
    final game = ref.read(gameProvider);
    _difficulty = bootRoomDifficulty(divisionIndexOf(game.state));
    _movesLeft = _difficulty.moves;
    // createBoard settles the opening board itself — nothing already matching,
    // so the session starts on the player's move rather than a free cascade.
    _board = createBoard(
      BootRoom.cols,
      BootRoom.rows,
      _difficulty.types,
      _rng.nextDouble,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _gates.state = (
        matchOpen: false,
        miniGameOpen: true,
        transferOpen: false,
        colinOnScreen: false,
      );
      // On entry, like the other drills: leaving mid-session must not farm the
      // reward timer.
      game.update((s) => startMiniGame(s, MiniGameKind.bootRoom));
    });
  }

  void _tap(int index) {
    if (_finished) return;
    if (_selected < 0) {
      setState(() => _selected = index);
      return;
    }
    if (_selected == index) {
      setState(() => _selected = -1);
      return;
    }

    final swapped = trySwap(
      _board,
      BootRoom.cols,
      BootRoom.rows,
      _selected,
      index,
    );
    setState(() => _selected = -1);
    final sound = ref.read(soundServiceProvider);
    // A swap that matches nothing is reverted and costs NO move — the engine's
    // rule, and the genre's. It gets the error cue rather than silence, because
    // a move that changes nothing and says nothing reads as a dropped tap.
    if (swapped == null) {
      unawaited(sound.play('error'));
      return;
    }

    final resolution = resolve(
      swapped,
      BootRoom.cols,
      BootRoom.rows,
      _difficulty.types,
      _rng.nextDouble,
    );
    setState(() {
      _board = resolution.board;
      _cleared += resolution.tilesCleared;
      _movesLeft--;
    });
    // A CASCADE is the thing worth hearing — the second and third clear landing
    // on their own is the whole appeal of the genre, so it gets the goal cue and
    // a plain match gets the tap. The JS makes the same split at the same depth.
    unawaited(sound.play(resolution.cascades >= 2 ? 'goal' : 'tap'));

    if (_movesLeft <= 0 ||
        findMove(_board, BootRoom.cols, BootRoom.rows) == null) {
      _finish();
    }
  }

  void _finish() {
    if (_finished) return;
    final result = ref
        .read(gameProvider)
        .update(
          (s) => recordBootRoomResult(
            s,
            tilesCleared: _cleared,
            target: _difficulty.target,
          ),
        );
    setState(() {
      _finished = true;
      _coins = result.coins;
    });
    if (result.coins > 0) {
      unawaited(ref.read(soundServiceProvider).play('coin'));
    }
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
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;

    return Scaffold(
      key: const ValueKey('boot-room-screen'),
      backgroundColor: kit.bg,
      appBar: const MiniGameHeader(titleKey: 'game.boot_room'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t('game.boot_room.moves', {'n': _movesLeft}),
                    key: const ValueKey('boot-room-moves'),
                    style: TextStyle(color: kit.textMuted),
                  ),
                  Text(
                    t('game.boot_room.tiles', {
                      'n': _cleared,
                      'target': _difficulty.target,
                    }),
                    key: const ValueKey('boot-room-tiles'),
                    style: TextStyle(color: kit.accentBright),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Laid out in full rather than in a lazy grid: a match-three
              // board the player cannot see all of is not a board.
              // No AspectRatio: inside an Expanded it collapsed the board to
              // zero height, which is invisible rather than merely wrong.
              Expanded(
                child: Column(
                  key: const ValueKey('boot-room-board'),
                  children: [
                    for (var y = 0; y < BootRoom.rows; y++)
                      Expanded(
                        child: Row(
                          // stretch, or each row sizes to its tallest child —
                          // and a tile is a childless DecoratedBox with no
                          // intrinsic height at all, so the board vanished.
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var x = 0; x < BootRoom.cols; x++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: _Tile(
                                    index: idxOf(BootRoom.cols, x, y),
                                    type: _board[idxOf(BootRoom.cols, x, y)],
                                    selected:
                                        _selected == idxOf(BootRoom.cols, x, y),
                                    onTap: _tap,
                                    kit: kit,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (_finished) ...[
                Text(
                  _cleared >= _difficulty.target
                      ? t('game.boot_room.target_hit')
                      : t('game.boot_room.out_of_moves'),
                  key: const ValueKey('boot-room-outcome'),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _cleared >= _difficulty.target
                        ? kit.accentBright
                        : kit.textMuted,
                  ),
                ),
                Text(
                  formatCoins(_coins),
                  key: const ValueKey('boot-room-reward'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: kit.accentBright,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const ValueKey('boot-room-done'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(t('common.close')),
                  ),
                ),
              ] else
                Text(
                  t('game.boot_room.instructions'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kit.textMuted, fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.index,
    required this.type,
    required this.selected,
    required this.onTap,
    required this.kit,
  });

  final int index;
  final int? type;
  final bool selected;
  final void Function(int) onTap;
  final KitTheme kit;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: ValueKey('tile-$index'),
    // Opaque, not the default deferToChild: a DecoratedBox with no child is
    // painted but not hit-testable, so every tile would have been untappable.
    behavior: HitTestBehavior.opaque,
    onTap: () => onTap(index),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: type == null
            ? kit.surface2
            : kitTileColours[type! % kitTileColours.length],
        borderRadius: BorderRadius.circular(6),
        border: selected ? Border.all(color: kit.accentBright, width: 3) : null,
      ),
    ),
  );
}
