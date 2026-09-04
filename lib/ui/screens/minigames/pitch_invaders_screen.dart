/// Pitch Invaders — whack-a-mole through nine gaps in the hoardings.
///
/// Three things pop up. An invader (tap: +1), the dog on the pitch (tap: +3,
/// rarer), and a steward — the one thing NOT to tap, which costs a catch. The
/// session is a fixed twenty-two seconds at every division; what changes as you
/// climb is how fast they come and go, and how many of them are stewards.
///
/// **The clock is one wall-clock deadline read every frame**, not a counted-down
/// interval. A phone that backgrounds the app for two seconds and comes back
/// gets the right time remaining rather than two free seconds — the JS's note,
/// and it matters more here, where the tab really does stop.
///
/// The pop-out is three explicit layers, back to front: the mouth the figure
/// rises out of, the figure, and then the near rim and turf band that hide it
/// again. The figure is deliberately NOT clipped — it has to be free to paint
/// over the hole on the way up — so the occluder is what makes it disappear.
/// Taking the mouth's WAIST rather than its far rim is what makes a figure sink
/// into the hole along an arc instead of being sliced off by a straight cut.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:merge_empire_fc/ui/screens/minigames/minigame_countdown.dart';
import 'package:merge_empire_fc/ui/screens/minigames/minigame_header.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/util/time.dart';

/// What can be in a hole, and what tapping it is worth.
enum Invader {
  invader('🏃', 1),
  dog('🐕', Whack.dogValue),
  steward('👮', -Whack.foulCost);

  const Invader(this.emoji, this.value);

  final String emoji;
  final int value;
}

/// Which of the three a pop-up is, from one `Math.random()` draw.
///
/// Stewards first, then the dog, then everything else — the same order as the
/// JS, because the order decides which band a given roll lands in.
Invader pickInvader(double roll, double stewardPct, double dogPct) =>
    roll < stewardPct
    ? Invader.steward
    : roll < stewardPct + dogPct
    ? Invader.dog
    : Invader.invader;

/// The mouth of the hole, as a fraction of the tile.
///
/// **BIGGER, because the hole and what came out of it were tiny.** A 28%-tall
/// mouth inset 12% either side leaves a coin of a hole in the middle of a
/// square of grass, and the figure standing in it was a third of the tile
/// wide — reported as needing to fill the boxes they are in.
const double mouthBottom = 0.07;
const double mouthHeight = 0.40;

/// How far in from the tile's sides the mouth starts. The spec's 12%.
///
/// **It had been widened to 5% and that change was never actually visible**:
/// the mouth was drawn with `BoxShape.circle`, which sizes itself off the box's
/// SHORTEST side, so how wide the box was made no difference at all — see
/// [_Mouth]. With the ellipse restored the 12% is back too, because grass
/// either side of the hole is what makes it a hole in a patch of ground rather
/// than a trench across the tile. It is still nearly twice the area the disc
/// covered.
const double mouthInset = 0.12;

/// Where the occluder starts: the mouth's WAIST. Above this line a figure paints
/// over the hole — that is the pop-out; at or below it, nothing of the figure
/// shows at all.
const double occludeTop = mouthBottom + mouthHeight / 2;

/// Where a figure's FEET sit, as a fraction of the tile measured from the
/// bottom — just inside the mouth, so the arc cuts across his ankles.
///
/// **THE HOLE WAS DRAWN OVER A QUARTER OF HIM.** This was `occludeTop + 0.02`
/// and it was not the feet at all: it was fed straight to an `Align`, whose y
/// positions the glyph's BOX inside the leftover space rather than putting its
/// bottom edge anywhere in particular. Measured, the figure's box ran to 0.89 of
/// the tile while the occluder starts at 0.73 — so the near half of the mouth
/// was painted across his shins, and what that reads as is the hole being in
/// front of the thing in it rather than the thing coming out of the hole.
/// Reported from the couch in exactly those words.
///
/// Below the waist line rather than above it, because the cut has to happen: a
/// figure whose feet clear the arc entirely is standing ON the grass.
const double upFeet = occludeTop - 0.05;

/// The `Align` y that puts a glyph box [glyph] tall (as a fraction of the tile)
/// with its BOTTOM on [upFeet].
///
/// `Align` centres the child in what is left over, so the two are not the same
/// number and the difference is what put him a sixth of a tile too low. Derived
/// from the glyph's real height, because the font size is capped on a big tile.
double figureAlign(double glyph) =>
    (2 * ((1 - upFeet) - glyph) / (1 - glyph) - 1).clamp(-1.0, 1.0);

/// The tile's turf gradient, top to bottom.
const List<Color> turfStops = [
  Color(0xFF14682E),
  Color(0xFF0D4A1C),
  Color(0xFF093012),
];
const List<double> turfPositions = [0, 0.55, 1];

// **`bandGradient` HAS GONE WITH THE BAND.** It repainted the slice of the
// tile's own gradient that the occluder covered, so the band's top edge left no
// seam — which is only a problem a full-width occluder has. The figure is
// clipped now and nothing is drawn over the turf, so there is no edge to hide.

const RadialGradient mouthFill = RadialGradient(
  center: Alignment(0, -0.5),
  radius: 0.8,
  colors: [Color(0xFF02170A), Color(0xFF041D0B), Color(0xFF062610)],
  stops: [0, 0.65, 1],
);

/// The far wall of the cavity, in shadow because the light is above it — the
/// mouth's `box-shadow: inset 0 5px 9px rgba(0,0,0,0.9)`.
///
/// **This is the single thing that turns a dark ellipse into a HOLE**, and
/// Flutter has no inset shadow, so it is a gradient clipped to the same oval.
/// Without it the mouth is a flat dark shape lying ON the grass; with it the
/// grass has an edge you can see over.
const LinearGradient mouthInnerShade = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xE6000000), Color(0x00000000)],
  stops: [0, 0.45],
);

/// The tile's own dish — `inset 0 2px 6px rgba(255,255,255,0.06)` at the top
/// and `inset 0 -8px 12px rgba(0,0,0,0.45)` at the foot. Nine flat squares of
/// gradient read as nine tiles; these read as nine patches of ground.
const LinearGradient tileDish = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0x0FFFFFFF),
    Color(0x00FFFFFF),
    Color(0x00000000),
    Color(0x73000000),
  ],
  stops: [0, 0.07, 0.7, 1],
);

/// What a tapped tile flashes, by what was in it.
///
/// **A TAP HAD NO ANSWER AT ALL.** The figure dropped, the counter moved and
/// nothing on the tile said which of the three things had just been hit — so a
/// player who caught the dog and a player who clattered a steward got the same
/// silence off the board, and had to read a number at the top of the page to
/// find out which. Asked for from the couch, and asked for in three colours
/// rather than one, because the three taps do not mean the same thing.
///
/// The man is the club's own accent — a catch, in the kit. The dog is the gold
/// every bonus in the game is written in, which is what makes the rarer, bigger
/// catch land harder than the ordinary one. The steward is [dangerInk], which
/// is the palette's own "something is wrong" and not a red of this screen's:
/// clattering a steward is the one tap that took something away.
///
/// One constant and not three, because the other two already exist — the man's
/// comes off [KitTheme] where a colour of the club belongs. See
/// [whackFlashInk].
const Color whackDogInk = Color(0xFFFBBF24);

/// How long a figure takes to leave the hole — struck, and ducking on its own.
const Duration whackStruckDrop = Duration(milliseconds: 110);
const Duration whackDuck = Duration(milliseconds: 150);

/// How long the ring stays up: exactly as long as the man it is drawn round.
///
/// **IT USED TO OUTLIVE HIM.** 380ms of ring over a 110ms drop, and the gap
/// between pop-ups is [WhackDifficulty.spawnMs] — 420ms at the top divisions —
/// so the tile was still framed when the next figure came out of it, and the
/// ring read as being about him rather than about the tap before. Reported from
/// the couch. It now comes down with the figure, and [PitchInvadersScreenState]
/// clears it outright on a pop-up so a ring can never survive into the next
/// one.
const Duration whackFlash = whackStruckDrop;

/// The ring itself: a border on the tile, not a wash over it. A filled tile
/// would hide the hole the figure just went back down.
const double whackFlashWidth = 3;

/// Public so the three readings can be pinned without waiting on the dog: it
/// is a rarer draw than a whole session is long, so an integration test that
/// waits for one is a test that fails on a bad roll.
Color whackFlashInk(KitTheme kit, Invader what) => switch (what) {
  Invader.invader => kit.accentBright,
  Invader.dog => whackDogInk,
  Invader.steward => dangerInk,
};

/// The turf band's own `inset 0 -8px 12px rgba(0,0,0,0.45)`.
const LinearGradient bandFoot = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0x00000000), Color(0x73000000)],
  stops: [0.45, 1],
);

class PitchInvadersScreen extends ConsumerStatefulWidget {
  const PitchInvadersScreen({super.key, this.random});

  /// Injectable so a test gets the same pop-ups twice. `Math.random()` in the
  /// JS, so `dart:math` here rather than the seeded gameplay stream.
  final math.Random? random;

  @override
  ConsumerState<PitchInvadersScreen> createState() =>
      PitchInvadersScreenState();
}

class PitchInvadersScreenState extends ConsumerState<PitchInvadersScreen>
    with SingleTickerProviderStateMixin {
  late final StateController<TickGates> _gates;
  late final GameState _game;
  late final WhackDifficulty _difficulty;
  late final Ticker _ticker;
  late final math.Random _rng = widget.random ?? math.Random();

  /// One slot per hole: what is up in it, or null.
  final List<Invader?> _holes = List<Invader?>.filled(Whack.holes, null);
  final List<Timer?> _ducks = List<Timer?>.filled(Whack.holes, null);

  /// Which hole was just hit, so it drops with the shrink rather than the walk.
  final Set<int> _struck = <int>{};

  /// What each hole was flashing for, and the timer that takes it back down.
  ///
  /// **A SECOND MAP RATHER THAN A FLAG ON [_struck]**, because the two are on
  /// different clocks: `_struck` lives until something else pops out of that
  /// hole, which may be seconds away or may be never, and a ring that sits
  /// there until the next pop-up is not feedback on a tap. See [whackFlash].
  final Map<int, Invader> _flash = <int, Invader>{};
  final List<Timer?> _flashOff = List<Timer?>.filled(Whack.holes, null);

  Timer? _spawn;

  /// One wall-clock deadline, read every frame. `now()` rather than
  /// `DateTime.now()` because it is the port's `Date.now()` — the single seam
  /// every engine's timestamps already go through, so a test can move it.
  int? _endsAt;
  int _msLeft = Whack.durationMs;
  int _catches = 0;
  int _fouls = 0;
  int _dogs = 0;
  bool _running = false;
  bool _over = false;
  bool _banked = false;
  int _coins = 0;

  /// Test seams.
  int get catches => _catches;
  int get fouls => _fouls;
  int get dogs => _dogs;
  bool get over => _over;
  bool get running => _running;
  int get coinsWon => _coins;
  List<Invader?> get holes => List.unmodifiable(_holes);
  Map<int, Invader> get flashes => Map.unmodifiable(_flash);

  @override
  void initState() {
    super.initState();
    _gates = ref.read(tickGatesProvider.notifier);
    _game = ref.read(gameProvider);
    _difficulty = whackDifficulty(currentDivisionIndex(_game.state));
    _ticker = createTicker(_onFrame);

    // **THE LEAD-IN IS THE COUNTDOWN NOW.** It was a silent 600ms beat
    // (`Whack.leadInMs`, the JS's) and it was not long enough to be read as
    // anything — the first pop-up simply arrived. `MiniGameCountdown` calls
    // [_begin] on GO. `Whack.leadInMs` stays in `mini_games.dart` because
    // `mini_games_test.dart` pins it against the JS.

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

  /// Whether the count is still running. Nothing pops and nothing scores while
  /// it is — the tiles are live widgets behind the overlay.
  bool _counting = true;

  bool get counting => _counting;

  void _begin() {
    if (!mounted) return;
    setState(() => _counting = false);
    // The attempt is spent HERE — at the kick-off, not at the payout — so a
    // player who walks out at second three has still used the session.
    _game.update((s) => startMiniGame(s, MiniGameKind.whack));
    setState(() {
      _running = true;
      _endsAt = now() + Whack.durationMs;
    });
    if (!_ticker.isActive) _ticker.start();
    _scheduleSpawn();
  }

  void _scheduleSpawn() {
    if (!_running) return;
    _spawn = Timer(Duration(milliseconds: _difficulty.spawnMs), () {
      _popOne();
      _scheduleSpawn();
    });
  }

  void _popOne() {
    if (!_running) return;
    final free = [
      for (var i = 0; i < _holes.length; i++)
        if (_holes[i] == null) i,
    ];
    // Every hole busy is a no-op, not a queue: the board is as full as it gets.
    if (free.isEmpty) return;
    final index = free[_rng.nextInt(free.length)];
    _flashOff[index]?.cancel();
    _flashOff[index] = null;
    final what = pickInvader(
      _rng.nextDouble(),
      _difficulty.stewardPct,
      _difficulty.dogPct,
    );

    setState(() {
      _holes[index] = what;
      _struck.remove(index);
      // The ring belongs to the tap before this one — see [whackFlash].
      _flash.remove(index);
    });
    // Ducks back down on its own if nobody taps it. A missed invader costs
    // nothing but the catch you did not get — no lives, no fail state.
    _ducks[index] = Timer(
      Duration(milliseconds: _difficulty.upMs),
      () => _clear(index),
    );
  }

  void _clear(int index) {
    _ducks[index]?.cancel();
    _ducks[index] = null;
    if (!mounted) return;
    setState(() => _holes[index] = null);
  }

  void _tapHole(int index) {
    final what = _holes[index];
    if (!_running || _over || what == null) return;
    setState(() {
      _struck.add(index);
      // The answer to the tap, on the tile that was tapped — see [_flashInk].
      _flash[index] = what;
    });
    _flashOff[index]?.cancel();
    _flashOff[index] = Timer(whackFlash, () {
      if (!mounted) return;
      setState(() => _flash.remove(index));
    });
    _clear(index);

    final sound = ref.read(soundServiceProvider);
    setState(() {
      switch (what) {
        case Invader.steward:
          _fouls++;
          // Floored at zero: a bad first tap should not put the player in debt
          // for the rest of the session.
          _catches = math.max(0, _catches - Whack.foulCost);
          unawaited(sound.play('goalAgainst'));
        case Invader.dog:
          _catches += what.value;
          _dogs++;
          unawaited(sound.play('goal'));
        case Invader.invader:
          _catches += what.value;
          unawaited(sound.play('pop'));
      }
    });
  }

  void _onFrame(Duration _) {
    if (!_running) return;
    final endsAt = _endsAt;
    if (endsAt == null) return;
    final left = math.max(0, endsAt - now());
    if (left != _msLeft) setState(() => _msLeft = left);
    if (left <= 0) _finish();
  }

  void _finish() {
    if (_over) return;
    _spawn?.cancel();
    _ticker.stop();
    for (var i = 0; i < _holes.length; i++) {
      _ducks[i]?.cancel();
      _ducks[i] = null;
    }
    for (var i = 0; i < _flashOff.length; i++) {
      _flashOff[i]?.cancel();
      _flashOff[i] = null;
    }
    setState(() {
      _running = false;
      _over = true;
      _msLeft = 0;
      _flash.clear();
      _holes.setAll(0, List<Invader?>.filled(Whack.holes, null));
    });
    unawaited(ref.read(soundServiceProvider).play('whistle'));
  }

  /// Bank the session, once.
  int _award() {
    if (_banked || !_started) return _coins;
    _banked = true;
    _coins = _game.update(
      (s) =>
          recordWhackResult(s, catches: _catches, fouls: _fouls, dogs: _dogs),
    );
    return _coins;
  }

  /// Whether the session actually kicked off. Leaving during the lead-in has
  /// not spent anything, so there is nothing to bank.
  bool get _started => _endsAt != null;

  void _collect() {
    final coins = _award();
    if (coins > 0) unawaited(ref.read(soundServiceProvider).play('coin'));
    Navigator.of(context).maybePop();
  }

  int get _preview => roundCoins(
    miniGameRewardBase(_game.state) * Whack.rewardPerCatchMult * _catches,
  );

  /// Nothing tapped that should not have been, and something actually caught —
  /// sitting the session out is not a clean sheet.
  bool get _clean => _fouls == 0 && _catches > 0;

  @override
  void deactivate() {
    // Walking away does not un-play the session, so bank what it was worth
    // rather than letting the player forfeit it by closing.
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
    _spawn?.cancel();
    for (final duck in _ducks) {
      duck?.cancel();
    }
    for (final off in _flashOff) {
      off?.cancel();
    }
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;

    return Scaffold(
      key: const ValueKey('pitch-invaders-screen'),
      backgroundColor: kit.bg,
      appBar: const MiniGameHeader(titleKey: 'game.whack'),
      body: SafeArea(
        // **THE BOARD IS THE GAME, so it gets the room.** Sixteen either side
        // plus an instruction paragraph plus a score row plus a bar left the
        // nine tiles sharing what was over — and a tile is a target you have
        // seven hundred milliseconds to hit. Asked for twice: bigger boxes.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The instructions are for the first round, not the twentieth:
              // two lines at most, and they give their height back to the
              // board rather than holding it for a paragraph nobody re-reads.
              Text(
                t('game.whack.instructions'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: kit.textMuted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t('game.whack.caught', {'n': _catches}),
                    key: const ValueKey('pi-score'),
                    style: TextStyle(
                      color: kit.accentBright,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${(_msLeft / 1000).ceil()}s',
                    key: const ValueKey('pi-clock'),
                    style: TextStyle(
                      color: kit.textMuted,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  key: const ValueKey('pi-timer'),
                  value: _msLeft / Whack.durationMs,
                  minHeight: 5,
                  backgroundColor: kit.surface2,
                  valueColor: AlwaysStoppedAnimation<Color>(kit.accentBright),
                ),
              ),
              const SizedBox(height: 12),
              // **THE COUNT GOES OVER THE BOARD, not in place of it.** Three
              // seconds of an empty page is three seconds of not knowing what
              // is about to be asked of you; the nine holes are what the
              // player needs to have found by GO.
              Stack(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0D4A1C), Color(0xFF0A3614)],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      // Laid out in full rather than in a lazy grid: nine holes the
                      // player cannot all see is not a board.
                      child: Column(
                        key: const ValueKey('pi-board'),
                        children: [
                          for (var row = 0; row < 3; row++)
                            Padding(
                              padding: EdgeInsets.only(top: row == 0 ? 0 : 6),
                              // **THE GUTTER IS BETWEEN THE COLUMNS, not inside
                              // them.** It was `Padding(left: 8)` inside each
                              // `Expanded`, so the first column's tile was eight
                              // points wider than the other two — and the tile is an
                              // `AspectRatio`, so it was eight points TALLER as
                              // well. Reported as the left boxes being bigger than
                              // the rest.
                              child: Row(
                                children: [
                                  for (var col = 0; col < 3; col++) ...[
                                    if (col > 0) const SizedBox(width: 6),
                                    Expanded(
                                      child: _Hole(
                                        index: row * 3 + col,
                                        occupant: _holes[row * 3 + col],
                                        struck: _struck.contains(row * 3 + col),
                                        flash: _flash[row * 3 + col],
                                        onTap: _tapHole,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_counting)
                    Positioned.fill(
                      child: MiniGameCountdown(onDone: _begin),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (_over) ...[
                Text(
                  _clean
                      ? '✨ ${t('game.whack.clean')}'
                      : '🏁 ${t('game.whack.full_time')}',
                  key: const ValueKey('pi-outcome'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _clean ? kit.accentBright : null,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MiniGameStat(
                      kit: kit,
                      label: t('game.whack.caught_label'),
                      value: '$_catches',
                      valueKey: const ValueKey('pi-caught'),
                      colour: kit.accentBright,
                    ),
                    const SizedBox(width: 18),
                    MiniGameStat(
                      kit: kit,
                      label: t('game.whack.fouls'),
                      value: '$_fouls',
                      valueKey: const ValueKey('pi-fouls'),
                      colour: _fouls > 0 ? Colors.red : kit.textMuted,
                    ),
                    const SizedBox(width: 18),
                    MiniGameStat(
                      kit: kit,
                      label: t('mg.reward'),
                      value: '+${formatCoins(_preview)} 💰',
                      valueKey: const ValueKey('pi-reward'),
                      colour: hudCoinInk,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  key: const ValueKey('pi-collect'),
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

/// One gap in the hoardings.
/// The mouth, as an ELLIPSE.
///
/// **`BoxShape.circle` was the whole of "it does not look like a hole".** The
/// spec's `.pi-mouth` is `left:12%;right:12%;height:40%` with `border-radius:
/// 50%`, and in CSS that is an ellipse filling the box — wide and flat, which
/// is what a hole in the ground looks like from a low angle. Flutter's
/// `BoxShape.circle` is not that: it draws a circle of the box's SHORTEST side,
/// centred. So the mouth was a small round disc floating in the middle of a
/// square of grass, and the inset either side — widened from the spec's 12% to
/// 5% in a pass that reported the hole as too small — had no effect at all,
/// because a circle does not care how wide its box is.
///
/// The shading is the other half. The spec's mouth carries `inset 0 5px 9px
/// rgba(0,0,0,0.9)` for the far wall and `0 -2px 7px rgba(0,0,0,0.55)` OUTSIDE
/// and above it for the lip of turf, and the port had drawn a flat radial fill
/// with neither.
class _Mouth extends StatelessWidget {
  const _Mouth({required this.lip});

  /// The shadow cast up onto the grass above the rim. The near half drawn back
  /// over the occluder does not get one — it would darken the band it is
  /// supposed to be cut into.
  final bool lip;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      shape: const OvalBorder(),
      gradient: mouthFill,
      shadows: lip
          ? const [
              BoxShadow(
                color: Color(0x8C000000),
                blurRadius: 7,
                offset: Offset(0, -2),
              ),
            ]
          : null,
    ),
    child: const DecoratedBox(
      decoration: ShapeDecoration(
        shape: OvalBorder(),
        gradient: mouthInnerShade,
      ),
      child: SizedBox.expand(),
    ),
  );
}

class _Hole extends StatelessWidget {
  const _Hole({
    required this.index,
    required this.occupant,
    required this.struck,
    required this.flash,
    required this.onTap,
  });

  final int index;
  final Invader? occupant;
  final bool struck;

  /// What this tile was tapped on, while the ring is up. Null the rest of the
  /// time — see [whackFlash].
  final Invader? flash;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: ValueKey('pi-hole-$index'),
    // Down, not up: waiting for the tap to be ruled out as a scroll is the
    // difference between a catch and a miss on a 700ms pop-up.
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => onTap(index),
    child: AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, box) {
          final h = box.maxHeight;
          final w = box.maxWidth;
          final f = flash;
          final ink = f == null
              ? null
              : whackFlashInk(Theme.of(context).extension<KitTheme>()!, f);
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // The tile.
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: turfStops,
                        stops: turfPositions,
                      ),
                    ),
                  ),
                ),
                // The tile's dish — see [tileDish]. Over the grass and under
                // everything else, which is where an inset shadow paints.
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: tileDish),
                  ),
                ),
                // 1. THE WHOLE MOUTH, once, and UNDER the figure.
                //
                // **NOTHING IS PAINTED OVER HIM ANY MORE, and that is the
                // change.** It used to be three layers: the far wall here, the
                // figure, then a full-width turf band and the mouth's near half
                // drawn back over him. The band is the one that did the damage
                // — it is a straight edge across the whole tile at the mouth's
                // waist, so what actually cut him was a horizontal line at his
                // shins with the arc sitting harmlessly BELOW it. Reported from
                // the couch: the hole is in front of the thing coming out of
                // it, and the thing should be in front of the hole.
                //
                // So the cut moved into a CLIP. The mouth is drawn once,
                // whole, underneath; the figure is clipped to everything above
                // the mouth's near arc. Same silhouette — he still sinks into
                // the hole along a curve — with the hole behind him where it
                // belongs, and one ellipse instead of one and a half.
                Positioned(
                  left: w * mouthInset,
                  right: w * mouthInset,
                  bottom: h * mouthBottom,
                  height: h * mouthHeight,
                  child: const _Mouth(lip: true),
                ),
                // 2. The tile's own foot shadow, which is what stops the
                // ground in front of the hole reading as flat.
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: bandFoot),
                  ),
                ),
                // 3. The figure, cut along the arc rather than under it.
                Positioned.fill(
                  child: ClipPath(
                    clipper: _AboveTheMouth(size: Size(w, h)),
                    child: AnimatedSlide(
                      offset: occupant == null
                          ? const Offset(0, 0.8)
                          : Offset.zero,
                      duration: struck ? whackStruckDrop : whackDuck,
                      curve: Curves.easeOut,
                      child: AnimatedScale(
                        scale: struck && occupant == null ? 0.7 : 1,
                        duration: whackStruckDrop,
                        child: Builder(
                          builder: (context) {
                            // It stands IN the mouth, so it is sized off the
                            // mouth rather than off the tile.
                            final glyph = math.min(96.0, w * 0.62);
                            return Align(
                              alignment: Alignment(0, figureAlign(glyph / h)),
                              child: Text(
                                occupant?.emoji ?? '',
                                key: ValueKey('pi-figure-$index'),
                                style: TextStyle(fontSize: glyph, height: 1),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                // 4. THE ANSWER TO THE TAP — over everything, because it is a
                // frame round the whole tile and not part of the scene in it.
                //
                // Always mounted and animated to transparent rather than added
                // and removed, so the ring eases off the tile in the ~120ms
                // after the flash instead of blinking out of existence. The
                // fill is faint: a wash heavy enough to notice on its own
                // would hide the hole the figure has just dropped back into.
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedContainer(
                      key: ValueKey('pi-flash-$index'),
                      duration: const Duration(milliseconds: 120),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ink ?? Colors.transparent,
                          width: whackFlashWidth,
                        ),
                        color:
                            ink?.withValues(alpha: 0.18) ?? Colors.transparent,
                      ),
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


/// Everything on a tile that is NOT behind the ground in front of the hole.
///
/// The figure is clipped to this instead of having the hole painted back over
/// him — see the note on the stack in [_Hole]. The rule is one sentence: below
/// the mouth's WAIST — its widest line, which is the ground plane — the only
/// thing you can see is what is inside the mouth. Everything else down there
/// is turf, and turf is in front of a man standing in a hole.
///
/// **IT USED TO SUBTRACT THE MOUTH'S LOWER HALF AND LEAVE THE REST OF THAT
/// BAND ALONE**, which is the two faults reported from the couch as one: the
/// bite it took was a half-ellipse whose top edge is a STRAIGHT CHORD, so the
/// figure was cut off along a horizontal line rather than along the rim; and
/// the turf either side of that half-ellipse — the two lunes inside the
/// mouth's box, and the strips of grass outside it — was still in the clip, so
/// a figure ducking slid down through it in full view. "They go through the
/// hole ok but you see them under the hole."
///
/// Subtracting the whole band and punching the mouth's lower half back OUT of
/// it fixes both at once: he is cut along the arc, and there is nothing left
/// beside the arc for him to show through.
///
/// The size comes from the tile's own `LayoutBuilder` rather than from the clip
/// call, so the two cannot disagree about where the mouth is.
class _AboveTheMouth extends CustomClipper<Path> {
  const _AboveTheMouth({required this.size});

  final Size size;

  Rect get _mouth => Rect.fromLTRB(
    size.width * mouthInset,
    size.height * (1 - mouthBottom - mouthHeight),
    size.width * (1 - mouthInset),
    size.height * (1 - mouthBottom),
  );

  @override
  Path getClip(Size _) {
    final mouth = _mouth;
    // The near half of the mouth: the opening you can still see down into,
    // bounded below by the rim the figure sinks past.
    final opening = Path.combine(
      PathOperation.intersect,
      Path()..addOval(mouth),
      Path()
        ..addRect(
          Rect.fromLTRB(mouth.left, mouth.center.dy, mouth.right, mouth.bottom),
        ),
    );
    // Everything at or below the ground plane, full width — the grass either
    // side of the hole as well as the strip in front of it.
    final ground = Path()
      ..addRect(
        Rect.fromLTRB(0, mouth.center.dy, size.width, size.height),
      );
    final occluder = Path.combine(PathOperation.difference, ground, opening);
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      occluder,
    );
  }

  @override
  bool shouldReclip(_AboveTheMouth old) => old.size != size;
}
