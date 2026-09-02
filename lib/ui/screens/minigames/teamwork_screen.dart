/// Team Work — the memory grid, built on the card art.
///
/// Tap two face-down cards. A match stays up; a mismatch flips back and burns
/// one of five lives. Difficulty is more pairs and a shorter opening peek, and
/// deliberately nothing else — this one is meant to stay casual.
///
/// **The internal mechanic is pair-matching and the identifiers say so.**
/// `pairsDifficulty`, `recordPairsResult` and `MiniGameKind.pairs` all keep the
/// engine's name; only the label the player reads is "Team Work". That split is
/// the JS's and renaming half of it here would break the save key.
///
/// The faces come from the same catalogue and the same art the squad uses, drawn
/// from the tier band around the player's own division — bronze faces at
/// grassroots, gold at the top.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/art_paths.dart';
import 'package:merge_empire_fc/data/divisions.dart'
    show currentDivisionIndex;
import 'package:merge_empire_fc/data/mini_games.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/game_tick.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart' show hudCoinInk;
import 'package:merge_empire_fc/ui/screens/minigames/minigame_header.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/ui/widgets/player_portrait.dart';
import 'package:merge_empire_fc/util/format.dart';

/// The tile's tier tint.
///
/// Cut down from the card palette for tiles this small — flatter, no gradients,
/// because twelve of them at once look busy. It is its OWN table rather than a
/// read of `tierThemes`: the JS's tier 4 and tier 8 do not match the card's
/// accents (`#aaa` against `#999999`, and gold against the card's cyan), and a
/// port that "tidied" that would be changing the art.
const Map<int, Color> tierTint = {
  1: Color(0xFF8B5A00),
  2: Color(0xFFA06820),
  3: Color(0xFF888888),
  4: Color(0xFFAAAAAA),
  5: Color(0xFFC8960C),
  6: Color(0xFFFFB300),
  7: Color(0xFFA040F0),
  8: Color(0xFFFFD700),
};

/// How long one flip takes; the face swaps at the pinch, halfway through.
const Duration pairsFlip = Duration(milliseconds: 320);

/// Columns for a given pair count.
///
/// Four at four pairs (two rows), five at five (two rows), four again at six
/// (three rows) — twelve cards five wide crowded on a narrow phone.
int pairsColumns(int pairs) => pairs == 5 ? 5 : 4;

/// Fisher–Yates, in place, using [roll] as `Math.random()`.
void shuffleInPlace<T>(List<T> list, double Function() roll) {
  for (var i = list.length - 1; i > 0; i--) {
    final j = (roll() * (i + 1)).floor();
    final tmp = list[i];
    list[i] = list[j];
    list[j] = tmp;
  }
}

/// [count] distinct definitions for the board, from the tier band around
/// [divIdx] so the faces feel relevant to where the player actually is.
///
/// The band falls back to the whole catalogue when it cannot fill the board —
/// a division whose band is thin must still get a full grid.
List<PlayerDef> pickPairDefs(int divIdx, int count, double Function() roll) {
  final minTier = math.max(1, divIdx - 1);
  final maxTier = math.min(8, divIdx + 3);
  final pool = players
      .where((p) => p.tier >= minTier && p.tier <= maxTier)
      .toList();
  final arr = List<PlayerDef>.of(pool.length >= count ? pool : players);
  shuffleInPlace(arr, roll);
  return arr.take(count).toList();
}

/// Two tiles per definition, shuffled.
List<PlayerDef> dealTiles(List<PlayerDef> defs, double Function() roll) {
  final tiles = <PlayerDef>[
    for (final def in defs) ...[def, def],
  ];
  shuffleInPlace(tiles, roll);
  return tiles;
}

class TeamworkScreen extends ConsumerStatefulWidget {
  const TeamworkScreen({super.key, this.random});

  /// Injectable so a test gets the same board twice. `Math.random()` in the JS,
  /// so `dart:math` here rather than the seeded gameplay stream.
  final math.Random? random;

  @override
  ConsumerState<TeamworkScreen> createState() => TeamworkScreenState();
}

class TeamworkScreenState extends ConsumerState<TeamworkScreen> {
  late final StateController<TickGates> _gates;
  late final GameState _game;
  late final math.Random _rng = widget.random ?? math.Random();

  late List<PlayerDef> _tiles;
  late int _totalPairs;
  final Set<int> _faceUp = <int>{};
  final Set<int> _matched = <int>{};
  final List<int> _flipped = <int>[];

  int _lives = Pairs.lives;
  int _matchedPairs = 0;

  /// Locked through the opening peek and through the flip-back beat, which is
  /// what stops a third tap landing while two cards are still being compared.
  bool _locked = true;
  bool _over = false;
  bool _cleared = false;
  bool _started = false;
  bool _banked = false;
  int _coins = 0;
  Timer? _peek;
  Timer? _hide;

  /// Test seams.
  int get lives => _lives;
  int get matchedPairs => _matchedPairs;
  int get totalPairs => _totalPairs;
  bool get over => _over;
  bool get cleared => _cleared;
  bool get locked => _locked;
  int get coinsWon => _coins;
  List<PlayerDef> get tiles => List.unmodifiable(_tiles);

  /// The two board positions of the pair [def] is on.
  List<int> positionsOf(PlayerDef def) => [
    for (var i = 0; i < _tiles.length; i++)
      if (_tiles[i].id == def.id) i,
  ];

  @override
  void initState() {
    super.initState();
    _gates = ref.read(tickGatesProvider.notifier);
    _game = ref.read(gameProvider);
    final divIdx = currentDivisionIndex(_game.state);
    final difficulty = pairsDifficulty(divIdx);
    _totalPairs = difficulty.pairs;
    _tiles = dealTiles(
      pickPairDefs(divIdx, _totalPairs, _rng.nextDouble),
      _rng.nextDouble,
    );
    // The opening peek: every face up, then all of them down together.
    _faceUp.addAll(List.generate(_tiles.length, (i) => i));
    _peek = Timer(Duration(milliseconds: difficulty.peekMs), _startPlay);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _gates.state = (
        matchOpen: false,
        miniGameOpen: true,
        transferOpen: false,
        colinOnScreen: false,
      );
    });
  }

  void _startPlay() {
    if (!mounted) return;
    // The attempt is spent when play starts, not when the screen opens: the
    // peek is not a session.
    _game.update((s) => startMiniGame(s, MiniGameKind.pairs));
    setState(() {
      _faceUp.removeWhere((i) => !_matched.contains(i));
      _locked = false;
      _started = true;
    });
  }

  void _tapTile(int index) {
    if (_locked || _over) return;
    if (_matched.contains(index)) return;
    // Already face up and waiting on its partner — a second tap on it is not a
    // second card.
    if (_faceUp.contains(index)) return;
    if (_flipped.length >= 2) return;

    final sound = ref.read(soundServiceProvider);
    unawaited(sound.play('tap'));
    setState(() {
      _faceUp.add(index);
      _flipped.add(index);
    });
    if (_flipped.length < 2) return;

    _locked = true;
    final a = _flipped[0];
    final b = _flipped[1];
    if (_tiles[a].id == _tiles[b].id) {
      setState(() {
        _matched.addAll([a, b]);
        _matchedPairs++;
        _flipped.clear();
        _locked = false;
      });
      unawaited(sound.play('goal'));
      if (_matchedPairs >= _totalPairs) _finish(cleared: true);
      return;
    }

    setState(() => _lives--);
    unawaited(sound.play('goalAgainst'));
    _hide = Timer(const Duration(milliseconds: Pairs.mismatchHideMs), () {
      if (!mounted) return;
      setState(() {
        _faceUp.removeAll([a, b]);
        _flipped.clear();
      });
      // Out of lives is checked AFTER the flip back, so the player sees the
      // two cards that cost them the game.
      if (_lives <= 0) {
        _finish(cleared: false);
      } else {
        setState(() => _locked = false);
      }
    });
  }

  void _finish({required bool cleared}) {
    if (_over) return;
    setState(() {
      _over = true;
      _cleared = cleared;
      _locked = true;
      // Everything face up, so the board can be read at the end.
      _faceUp.addAll(List.generate(_tiles.length, (i) => i));
    });
  }

  /// Bank the session, once. Nothing to bank if the peek never ended.
  int _award() {
    if (_banked || !_started) return _coins;
    _banked = true;
    _coins = _game.update(
      (s) => recordPairsResult(
        s,
        pairsMatched: _matchedPairs,
        totalPairs: _totalPairs,
        cleared: _matchedPairs >= _totalPairs,
      ),
    );
    return _coins;
  }

  void _collect() {
    final coins = _award();
    if (coins > 0) unawaited(ref.read(soundServiceProvider).play('coin'));
    Navigator.of(context).maybePop();
  }

  int get _preview {
    var amount = roundCoins(
      miniGameRewardBase(_game.state) * Pairs.rewardPerPairMult * _matchedPairs,
    );
    if (_cleared) amount = roundCoins(amount * Pairs.clearBonusMult);
    return amount;
  }

  @override
  void deactivate() {
    // Closing is not a forfeit — the pairs found are banked on the way out.
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
    _peek?.cancel();
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final cols = pairsColumns(_totalPairs);

    return Scaffold(
      key: const ValueKey('teamwork-screen'),
      backgroundColor: kit.bg,
      appBar: const MiniGameHeader(titleKey: 'game.teamwork'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t('game.teamwork.instructions'),
                style: TextStyle(
                  color: kit.textMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    key: const ValueKey('pairs-lives'),
                    children: [
                      for (var i = 0; i < Pairs.lives; i++)
                        Text(
                          '♥',
                          key: ValueKey(
                            i < _lives ? 'pairs-life-$i' : 'pairs-life-lost-$i',
                          ),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: i < _lives
                                ? const Color(0xFFFF6B6B)
                                : Colors.white24,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    t('game.teamwork.pairs_count', {
                      'matched': _matchedPairs,
                      'total': _totalPairs,
                    }),
                    key: const ValueKey('pairs-score'),
                    style: TextStyle(
                      color: kit.accentBright,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Laid out in full rather than in a lazy grid, for the same
              // reason as the Boot Room: a memory board the player cannot all
              // see is not a memory board.
              Column(
                key: const ValueKey('pairs-board'),
                children: [
                  for (var row = 0; row * cols < _tiles.length; row++)
                    Padding(
                      padding: EdgeInsets.only(top: row == 0 ? 0 : 6),
                      // **THE GUTTER IS BETWEEN THE COLUMNS, not inside
                      // them.** It was `Padding(left: 6)` INSIDE each
                      // `Expanded`, which divides the row evenly and then takes
                      // the gutter out of every share but the first — so the
                      // left column's card was six points wider than the rest,
                      // and because the card is an `AspectRatio` it was six
                      // points taller too. Reported from the couch, and it is
                      // the same fault Pitch Invaders had.
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var col = 0; col < cols; col++) ...[
                            if (col > 0) const SizedBox(width: 6),
                            Expanded(
                              child: row * cols + col < _tiles.length
                                  ? _Tile(
                                      index: row * cols + col,
                                      def: _tiles[row * cols + col],
                                      faceUp: _faceUp.contains(
                                        row * cols + col,
                                      ),
                                      matched: _matched.contains(
                                        row * cols + col,
                                      ),
                                      onTap: _tapTile,
                                    )
                                  : const AspectRatio(
                                      aspectRatio: 3 / 4,
                                      child: SizedBox.shrink(),
                                    ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_over) ...[
                Text(
                  _cleared
                      ? '🎉 ${t('game.teamwork.cleared')}'
                      : '💔 ${t('game.teamwork.out_of_lives')}',
                  key: const ValueKey('pairs-outcome'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _cleared ? kit.accentBright : Colors.red,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MiniGameStat(
                      kit: kit,
                      label: t('game.teamwork.pairs'),
                      value: '$_matchedPairs/$_totalPairs',
                      valueKey: const ValueKey('pairs-found'),
                      colour: kit.accentBright,
                    ),
                    const SizedBox(width: 18),
                    MiniGameStat(
                      kit: kit,
                      label: t('mg.reward'),
                      value: '+${formatCoins(_preview)} 💰',
                      valueKey: const ValueKey('pairs-reward'),
                      colour: hudCoinInk,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  key: const ValueKey('pairs-collect'),
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

/// One card, back or face.
///
/// The flip is a horizontal PINCH — scaleX 1 → 0 → 1 with the face swapped at
/// the waist — rather than a rotation about Y. It reads as a card turning over
/// and it is the JS's own choice, taken there to dodge Safari's
/// backface-visibility bugs; here it stays because the pinch is what the art
/// was drawn against.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.index,
    required this.def,
    required this.faceUp,
    required this.matched,
    required this.onTap,
  });

  final int index;
  final PlayerDef def;
  final bool faceUp, matched;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final tint = tierTint[def.tier] ?? const Color(0xFF888888);
    return GestureDetector(
      key: ValueKey('pairs-tile-$index'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: TweenAnimationBuilder<double>(
          // 0 is fully back, 1 is fully face — the tween IS the flip, so a
          // tile interrupted mid-turn carries on from where it was rather than
          // snapping.
          tween: Tween<double>(begin: 0, end: faceUp ? 1 : 0),
          duration: pairsFlip,
          curve: Curves.easeInOut,
          builder: (context, t, _) {
            // The pinch: widest at the ends, closed at the waist.
            final pinch = (2 * t - 1).abs().clamp(0.02, 1.0);
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(pinch, 1, 1),
              child: t >= 0.5
                  ? _Face(def: def, tint: tint, matched: matched)
                  : const _Back(),
            );
          },
        ),
      ),
    );
  }
}

class _Back extends StatelessWidget {
  const _Back();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF1D8A3A), width: 2),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0A3D1A), Color(0xFF0D5524), Color(0xFF0A3D1A)],
        stops: [0, 0.35, 1],
      ),
    ),
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('⚽', style: TextStyle(fontSize: 26, height: 1)),
        SizedBox(height: 4),
        Text(
          'MEFC',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: Color(0xFFFFD700),
          ),
        ),
      ],
    ),
  );
}

class _Face extends StatelessWidget {
  const _Face({required this.def, required this.tint, required this.matched});

  final PlayerDef def;
  final Color tint;
  final bool matched;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: tint, width: 2),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
      ),
      boxShadow: matched
          ? const [
              BoxShadow(
                color: Color(0x8C4CAF50),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ]
          : null,
    ),
    child: Column(
      children: [
        // The tier stripe, which is the only thing that says how good the face
        // on the card is.
        Container(height: 3, color: tint),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(3, 4, 3, 3),
            child: ArtImage(
              key: ValueKey('pairs-art-${def.id}'),
              path: playerImagePath(def.position, def.tier),
              fit: BoxFit.cover,
              fallback: PlayerPortrait(variantIndex: 0, kitColor: tint),
            ),
          ),
        ),
      ],
    ),
  );
}

