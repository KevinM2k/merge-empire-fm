/// The Boot Room — a match-three over kit tiles. Ported from
/// `ui/components/BootRoomGame.js`.
///
/// Every rule is `boot_room_engine`'s: what matches, how a board collapses and
/// refills, and whether a swap is legal. This is input, painting and animation,
/// which is the same split the JS makes.
///
/// **AND THE ANIMATION IS NOT DECORATION HERE.** The port had none of it: a
/// swap rewrote the board on the next frame, so a three-deep cascade — the
/// whole appeal of the genre, and the reason the engine hands the steps back
/// separately — was a single silent jump. The tiles were flat colour blocks
/// with no faces, a dead board ENDED the session instead of reshuffling, there
/// was no swipe, and the best chain was never counted at all so
/// `bootRoomBestCascade` had been zero in every save ever written. Reported
/// from the couch as the game being wrong, which it was.
///
/// Three clocks, all the JS's own: a swap slides ([bootRoomSwap]), a matched
/// blob pops ([bootRoomClear]), and what replaces it falls in
/// ([bootRoomFall]).
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
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/game_tick.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart' show hudCoinInk;
import 'package:merge_empire_fc/ui/screens/minigames/minigame_header.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/format.dart';

/// One face per kit type, and the JS's own six.
///
/// **No two share a silhouette OR a colour**, which matters far more here than
/// in Pairs: the player is scanning thirty-six of them at a glance, and colour
/// alone is what the port shipped — six plain squares, which is a board you
/// have to decode rather than read.
const List<({String emoji, Color tint})> kitTiles = [
  (emoji: '⚽', tint: Color(0xFFE2E8F0)),
  (emoji: '👟', tint: Color(0xFFFB7185)),
  (emoji: '👕', tint: Color(0xFF38BDF8)),
  (emoji: '🧤', tint: Color(0xFFFACC15)),
  (emoji: '🧦', tint: Color(0xFFA855F7)),
  (emoji: '🚩', tint: Color(0xFF4ADE80)),
];

/// How long a matched blob sits lit before it goes, how long the refill takes
/// to fall in, and how long two neighbours take to change places. `CLEAR_MS`,
/// `FALL_MS` and `SWAP_MS`.
const Duration bootRoomClear = Duration(milliseconds: 260);
const Duration bootRoomFall = Duration(milliseconds: 220);
const Duration bootRoomSwap = Duration(milliseconds: 150);

/// How far a finger has to travel before it is a swipe rather than a tap.
const double _swipeSlop = 18;

/// `cubic-bezier(0.34, 1.2, 0.64, 1)` — the refill lands rather than stopping.
const Curve _fallCurve = Cubic(0.34, 1.2, 0.64, 1);

class BootRoomScreen extends ConsumerStatefulWidget {
  const BootRoomScreen({super.key});

  @override
  ConsumerState<BootRoomScreen> createState() => BootRoomScreenState();
}

class BootRoomScreenState extends ConsumerState<BootRoomScreen>
    with TickerProviderStateMixin {
  late final StateController<TickGates> _gates;
  late final GameState _game;
  late final BootRoomDifficulty _difficulty;
  final math.Random _rng = math.Random();

  late final AnimationController _swap;
  late final AnimationController _pop;
  late final AnimationController _fall;
  late final AnimationController _flash;

  List<int?> _board = const [];
  int _movesLeft = 0;
  int _cleared = 0;
  int _bestCascade = 0;
  int _selected = -1;
  int _coins = 0;
  bool _finished = false;
  bool _banked = false;

  /// True while a swap, a pop or a fall is playing. **Input is closed for the
  /// whole of it**, because a second swap landing mid-cascade is a board being
  /// rewritten under an animation that is still describing the old one.
  bool _busy = false;

  /// The two cells changing places, and whether they are coming back.
  int _swapA = -1;
  int _swapB = -1;
  bool _swapRevert = false;

  /// The matched blob, mid-pop.
  Set<int> _clearing = const {};

  /// Cell → how many rows it has just travelled, so the refill drops in from
  /// where it came rather than appearing.
  Map<int, int> _falling = const {};

  /// Where a finger went down, so a drag can be told from a tap.
  ({int index, Offset at, bool swiped})? _drag;

  /// Test seams.
  int get tilesCleared => _cleared;
  int get movesLeft => _movesLeft;
  int get bestCascade => _bestCascade;
  bool get finished => _finished;
  int get coinsWon => _coins;
  List<int?> get board => _board;
  int get selected => _selected;

  @override
  void initState() {
    super.initState();
    _gates = ref.read(tickGatesProvider.notifier);
    _game = ref.read(gameProvider);
    _difficulty = bootRoomDifficulty(currentDivisionIndex(_game.state));
    _movesLeft = _difficulty.moves;
    _swap = AnimationController(vsync: this, duration: bootRoomSwap);
    _pop = AnimationController(vsync: this, duration: bootRoomClear);
    _fall = AnimationController(vsync: this, duration: bootRoomFall);
    _flash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
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
      _game.update((s) => startMiniGame(s, MiniGameKind.bootRoom));
    });
  }

  @override
  void dispose() {
    _swap.dispose();
    _pop.dispose();
    _fall.dispose();
    _flash.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- input --

  void _down(int index, Offset at) {
    if (_busy || _finished) return;
    _drag = (index: index, at: at, swiped: false);
  }

  /// **A swipe swaps in the direction of travel; a clean tap selects.** Both
  /// idioms, because a match-three player reaches for the swipe and someone who
  /// has just played Pairs reaches for the tap — and the shipped instructions
  /// have said "Swipe or tap" in ten languages the whole time the port
  /// supported only one of them.
  void _move(int index, Offset at) {
    final drag = _drag;
    if (drag == null || drag.swiped || drag.index != index) return;
    final delta = at - drag.at;
    if (delta.dx.abs() < _swipeSlop && delta.dy.abs() < _swipeSlop) return;
    _drag = (index: drag.index, at: drag.at, swiped: true);

    var x = xOf(BootRoom.cols, index);
    var y = yOf(BootRoom.cols, index);
    if (delta.dx.abs() > delta.dy.abs()) {
      x += delta.dx > 0 ? 1 : -1;
    } else {
      y += delta.dy > 0 ? 1 : -1;
    }
    if (x < 0 || y < 0 || x >= BootRoom.cols || y >= BootRoom.rows) return;
    setState(() => _selected = -1);
    unawaited(_attemptSwap(index, idxOf(BootRoom.cols, x, y)));
  }

  void _up(int index) {
    final drag = _drag;
    _drag = null;
    if (drag == null || drag.swiped || drag.index != index) return;
    _tap(index);
  }

  void _tap(int index) {
    if (_busy || _finished) return;
    final sound = ref.read(soundServiceProvider);
    if (_selected < 0) {
      setState(() => _selected = index);
      unawaited(sound.play('tap'));
      return;
    }
    if (_selected == index) {
      setState(() => _selected = -1);
      return;
    }
    final from = _selected;
    setState(() => _selected = -1);
    // **NOT A NEIGHBOUR IS A NEW PICK, not a miss.** The port played the error
    // cue and dropped the tap, so reaching across the board to change your mind
    // buzzed at you and left nothing selected.
    if (!areAdjacent(BootRoom.cols, from, index)) {
      setState(() => _selected = index);
      unawaited(sound.play('tap'));
      return;
    }
    unawaited(_attemptSwap(from, index));
  }

  // ------------------------------------------------------------- the play --

  Future<void> _attemptSwap(int a, int b) async {
    if (_busy || _finished) return;
    _busy = true;
    try {
      final sound = ref.read(soundServiceProvider);
      final swapped = trySwap(_board, BootRoom.cols, BootRoom.rows, a, b);
      // A swap that matches nothing is reverted and costs NO move — the
      // engine's rule, and the genre's. It nudges the two at each other and
      // snaps back, which says "not that one" without spending anything.
      if (swapped == null) {
        unawaited(sound.play('error'));
        await _playSwap(a, b, revert: true);
        return;
      }

      await _playSwap(a, b, revert: false);
      if (!mounted) return;
      setState(() {
        _board = swapped;
        _movesLeft--;
      });
      await _settle();
      if (!mounted) return;

      // **A DEAD BOARD IS RESHUFFLED, NOT A LOSS.** The port ended the session
      // the moment no legal swap was left, so a player with moves in hand was
      // stopped on a technicality the engine already has the answer to.
      if (_movesLeft > 0 && !hasAnyMove(_board, BootRoom.cols, BootRoom.rows)) {
        setState(() {
          _board = reshuffle(
            _board,
            BootRoom.cols,
            BootRoom.rows,
            _difficulty.types,
            _rng.nextDouble,
          );
        });
        await _flash.forward(from: 0);
      }
    } finally {
      _busy = false;
    }
    if (_movesLeft <= 0) _finish();
  }

  /// Slides two neighbours past each other. [revert] plays it out and back.
  Future<void> _playSwap(int a, int b, {required bool revert}) async {
    setState(() {
      _swapA = a;
      _swapB = b;
      _swapRevert = revert;
    });
    _swap.duration = revert ? bootRoomSwap * 2 : bootRoomSwap;
    await _swap.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _swapA = -1;
      _swapB = -1;
    });
  }

  /// Runs every cascade the swap set off, **one visible step at a time**.
  ///
  /// The engine returns them separately for exactly this: the board is only
  /// advanced to a step's own result once that step's blob has finished
  /// popping, so the second and third clear are things the player watches
  /// happen rather than a number that has already changed.
  Future<void> _settle() async {
    final sound = ref.read(soundServiceProvider);
    final resolution = resolve(
      _board,
      BootRoom.cols,
      BootRoom.rows,
      _difficulty.types,
      _rng.nextDouble,
    );
    for (final step in resolution.steps) {
      setState(() => _clearing = step.cleared.toSet());
      // A CASCADE is the thing worth hearing — the second and third clear
      // landing on their own is the whole appeal of the genre, so it gets the
      // goal cue and a plain match gets the tap. The JS splits it at the same
      // depth.
      unawaited(sound.play(step.cascade >= 2 ? 'goal' : 'tap'));
      await _pop.forward(from: 0);
      if (!mounted) return;

      setState(() {
        _board = step.board;
        _clearing = const {};
        // Everything that moved or spawned falls in from where it came.
        _falling = {
          for (final move in step.moves)
            move.to: yOf(BootRoom.cols, move.to) - yOf(BootRoom.cols, move.from),
          for (final spawn in step.spawned) spawn.cell: spawn.height,
        };
      });
      await _fall.forward(from: 0);
      if (!mounted) return;

      setState(() {
        _falling = const {};
        _cleared += step.cleared.length;
        _bestCascade = math.max(_bestCascade, step.cascade);
      });
    }
  }

  void _finish() {
    if (_finished) return;
    setState(() => _finished = true);
    unawaited(ref.read(soundServiceProvider).play('whistle'));
  }

  /// What the session is worth, before it is banked. The same arithmetic
  /// `recordBootRoomResult` does, and the same figure it will pay.
  int get _preview {
    // `miniGameRewardBase` already carries the coin multiplier, which is what
    // `recordBootRoomResult` multiplies by too — so this is the figure it will
    // pay rather than a second guess at it.
    var amount = roundCoins(
      miniGameRewardBase(_game.state) * BootRoom.rewardPerTileMult * _cleared,
    );
    if (_cleared >= _difficulty.target) {
      amount = roundCoins(amount * BootRoom.targetBonusMult);
    }
    return amount;
  }

  bool get _hitTarget => _cleared >= _difficulty.target;

  int _award() {
    if (_banked) return _coins;
    _banked = true;
    _coins = _game
        .update(
          (s) => recordBootRoomResult(
            s,
            tilesCleared: _cleared,
            target: _difficulty.target,
            // **The half nothing ever passed.** `bootRoomBestCascade` has been
            // in the engine and in every save since the drill landed, and the
            // screen never counted a chain, so the stat was zero for everybody.
            bestCascade: _bestCascade,
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

  @override
  void deactivate() {
    // Walking away does not un-play the session, so bank what it was worth
    // rather than letting the player forfeit it by closing.
    if (_finished) _award();
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

  // ------------------------------------------------------------- painting --

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
              Text(
                t('game.boot_room.instructions'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kit.textMuted,
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t('game.boot_room.moves', {'n': _movesLeft}),
                    key: const ValueKey('boot-room-moves'),
                    style: TextStyle(
                      color: kit.textMuted,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    t('game.boot_room.tiles', {
                      'n': _cleared,
                      'target': _difficulty.target,
                    }),
                    key: const ValueKey('boot-room-tiles'),
                    style: TextStyle(
                      color: kit.accentBright,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // **THE TARGET, AS A BAR.** The figure beside it is a pair of
              // numbers to compare; the bar is the answer at a glance, and the
              // JS has carried one since the drill shipped.
              ClipRRect(
                key: const ValueKey('boot-room-target-bar'),
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: _difficulty.target <= 0
                      ? 0
                      : (_cleared / _difficulty.target).clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: kit.textMuted.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation(kit.accentBright),
                ),
              ),
              const SizedBox(height: 10),
              // Laid out in full rather than in a lazy grid: a match-three
              // board the player cannot see all of is not a board.
              Expanded(
                child: FadeTransition(
                  // The reshuffle dips the whole board, so the tiles moving
                  // under it reads as the shelf being restacked rather than as
                  // the game glitching.
                  opacity: Tween<double>(begin: 1, end: 1).animate(
                    _flash.drive(
                      TweenSequence<double>([
                        TweenSequenceItem(tween: Tween(begin: 1, end: 0.35), weight: 1),
                        TweenSequenceItem(tween: Tween(begin: 0.35, end: 1), weight: 1),
                      ]),
                    ),
                  ),
                  // **THE TILES ARE SQUARE.** The board took the whole of
                  // whatever height the column had left, so a boot on a tall
                  // phone was drawn tall and the same boot on a short one was
                  // drawn wide — a match-three board whose pieces are not the
                  // shape of the thing on them. The board is its own square
                  // now and the room it gives back is the column's; rows and
                  // cols are equal, and the gutters and the padding are
                  // symmetric, so one aspect covers all of it. Asked for from
                  // the couch, smaller on screen included.
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: BootRoom.cols / BootRoom.rows,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF241A12), Color(0xFF15100B)],
                          ),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: AnimatedBuilder(
                            animation: Listenable.merge([_swap, _pop, _fall]),
                            builder: (context, _) => Column(
                              key: const ValueKey('boot-room-board'),
                              children: [
                                for (var y = 0; y < BootRoom.rows; y++) ...[
                                  if (y > 0) const SizedBox(height: 4),
                                  Expanded(
                                    child: Row(
                                      // stretch, or each row sizes to its tallest
                                      // child and a childless box has no height.
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        for (var x = 0; x < BootRoom.cols; x++) ...[
                                          // **THE GUTTER IS BETWEEN THE COLUMNS**,
                                          // not inside each `Expanded` — see Pairs
                                          // and Pitch Invaders for what that did.
                                          if (x > 0) const SizedBox(width: 4),
                                          Expanded(
                                            child: _tileAt(
                                              idxOf(BootRoom.cols, x, y),
                                              kit,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_finished) ...[
                Text(
                  _hitTarget
                      ? '🎉 ${t('game.boot_room.target_hit')}'
                      : '🏁 ${t('game.boot_room.out_of_moves')}',
                  key: const ValueKey('boot-room-outcome'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _hitTarget ? kit.accentBright : null,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MiniGameStat(
                      kit: kit,
                      label: t('game.boot_room.cleared_label'),
                      value: '$_cleared',
                      valueKey: const ValueKey('boot-room-cleared'),
                      colour: kit.accentBright,
                    ),
                    const SizedBox(width: 18),
                    // `game.boot_room.best_chain` sat translated in all ten
                    // catalogues with nothing counting a chain to print in it.
                    MiniGameStat(
                      kit: kit,
                      label: t('game.boot_room.best_chain'),
                      value: '×$_bestCascade',
                      valueKey: const ValueKey('boot-room-chain'),
                      colour: kit.textMuted,
                    ),
                    const SizedBox(width: 18),
                    MiniGameStat(
                      kit: kit,
                      label: t('mg.reward'),
                      value: '+${formatCoins(_preview)} 💰',
                      valueKey: const ValueKey('boot-room-reward'),
                      colour: hudCoinInk,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  key: const ValueKey('boot-room-done'),
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

  /// One cell, with whichever of the three clocks it is currently on.
  Widget _tileAt(int index, KitTheme kit) {
    var offset = Offset.zero;
    var scale = 1.0;
    var opacity = 1.0;

    if (index == _swapA || index == _swapB) {
      final other = index == _swapA ? _swapB : _swapA;
      final away = Offset(
        (xOf(BootRoom.cols, other) - xOf(BootRoom.cols, index)).toDouble(),
        (yOf(BootRoom.cols, other) - yOf(BootRoom.cols, index)).toDouble(),
      );
      // A revert plays out and back on one controller: the first half is the
      // nudge, the second is the snap.
      final t = _swapRevert
          ? 1 - (_swap.value * 2 - 1).abs()
          : _swap.value;
      offset = away * Curves.easeInOut.transform(t.clamp(0.0, 1.0));
    } else if (_clearing.contains(index)) {
      // `br-pop`: 0% scale 1, 45% scale 1.18, 100% scale 0.25 and gone.
      final t = _pop.value;
      if (t <= 0.45) {
        scale = 1 + 0.18 * (t / 0.45);
      } else {
        final e = (t - 0.45) / 0.55;
        scale = 1.18 - 0.93 * e;
        opacity = 1 - e;
      }
    } else if (_falling[index] case final rows? when rows > 0) {
      offset = Offset(0, -rows * (1 - _fallCurve.transform(_fall.value)));
    }

    return _Tile(
      index: index,
      type: _board[index],
      selected: _selected == index,
      offset: offset,
      scale: scale,
      opacity: opacity,
      kit: kit,
      onDown: _down,
      onMove: _move,
      onUp: _up,
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.index,
    required this.type,
    required this.selected,
    required this.offset,
    required this.scale,
    required this.opacity,
    required this.kit,
    required this.onDown,
    required this.onMove,
    required this.onUp,
  });

  final int index;
  final int? type;
  final bool selected;

  /// In CELLS, not pixels — the tile does not know how big a cell is, and a
  /// `FractionalTranslation` does.
  final Offset offset;
  final double scale;
  final double opacity;
  final KitTheme kit;
  final void Function(int, Offset) onDown;
  final void Function(int, Offset) onMove;
  final void Function(int) onUp;

  @override
  Widget build(BuildContext context) {
    final face = type == null ? null : kitTiles[type! % kitTiles.length];
    return Listener(
      key: ValueKey('tile-$index'),
      // The board owns the gesture; a raw `Listener` rather than a
      // `GestureDetector` because a swipe here is a direction rather than a
      // drag, and the arena would hand it to a scroll first.
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => onDown(index, e.position),
      onPointerMove: (e) => onMove(index, e.position),
      onPointerUp: (_) => onUp(index),
      onPointerCancel: (_) => onUp(-1),
      child: FractionalTranslation(
        translation: offset,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: face == null
                    ? null
                    : LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomRight,
                        colors: [
                          face.tint.withValues(alpha: 0.25),
                          face.tint.withValues(alpha: 0.09),
                        ],
                      ),
                color: face == null ? kit.surface2 : null,
                border: Border.all(
                  color: selected
                      ? kit.accentBright
                      : (face?.tint ?? kit.border).withValues(alpha: 0.4),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  face?.emoji ?? '',
                  // A selected tile brightens as well as gaining a ring:
                  // `filter: brightness(1.45)` on `[data-selected]`.
                  style: TextStyle(
                    fontSize: 22,
                    height: 1,
                    shadows: selected
                        ? [
                            Shadow(color: kit.accentBright, blurRadius: 12),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
